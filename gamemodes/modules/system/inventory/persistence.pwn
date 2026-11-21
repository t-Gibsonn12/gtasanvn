//-----------------------------------------------------------------------------
// LS:RP Inventory - MySQL Persistence
// Character-owned inventory + weapon instance metadata + LEFT/RIGHT assignment.
//-----------------------------------------------------------------------------

#include <YSI_Coding\y_hooks>

new g_InventoryAutosaveTimer;

// Large SQL buffers are stored outside the Pawn stack.
// This prevents Inventory_AutosaveTick -> Inventory_SaveCharacter from
// causing stack/heap collision when the inventory UPSERT is built.
static g_InventorySaveUpsert[16384];
static g_InventorySaveCleanup[1024];
static g_InventorySaveSlotList[512];
static g_InventorySaveRowText[320];
static g_InventorySaveSlotText[12];

forward InventoryPersistence_Init();

forward public OnInventorySerialLoaded();
forward public OnInventoryCharacterLoaded(playerid, characterID);

// Convert runtime hand enum to compact database representation.
// 0 = none, 1 = left, 2 = right.
stock InventoryPersistence_HandToDatabase(E_WEAPON_HAND:hand)
{
    switch (hand)
    {
        case WEAPON_HAND_LEFT:
        {
            return 1;
        }

        case WEAPON_HAND_RIGHT:
        {
            return 2;
        }

        case WEAPON_HAND_NONE,
             WEAPON_HAND_COUNT:
        {
            return 0;
        }
    }

    return 0;
}

stock E_WEAPON_HAND:InventoryPersistence_DatabaseToHand(value)
{
    switch (value)
    {
        case 1: return WEAPON_HAND_LEFT;
        case 2: return WEAPON_HAND_RIGHT;
    }
    return WEAPON_HAND_NONE;
}

stock Inventory_LoadCharacter(playerid)
{
    if (!IsPlayerConnected(playerid) || !IsPlayerCharacterLoaded(playerid))
    {
        return 0;
    }

    new const characterID = GetPlayerCharacterID(playerid);
    if (characterID == INVALID_CHARACTER_ID) return 0;

    if (g_InventoryLoading[playerid]) return 0;
    if (g_InventoryLoaded[playerid] &&
        g_InventoryCharacterID[playerid] == characterID)
    {
        return 1;
    }

    // Reset the old character/runtime before issuing the new async load.
    Inventory_Reset(playerid);
    g_InventoryLoading[playerid] = true;
    g_InventoryCharacterID[playerid] = characterID;

    new query[512];
    mysql_format(
        g_DatabaseHandle,
        query,
        sizeof(query),
        "SELECT `inventory_id`,`slot_index`,`item_id`,`amount`,IFNULL(`weapon_serial`,0) AS `weapon_serial`,`weapon_id`,`ammo_type`,`loaded_ammo`,`weapon_condition`,`equipped_hand` FROM `player_inventory` WHERE `character_id`=%d ORDER BY `slot_index` ASC;",
        characterID
    );

    mysql_tquery(
        g_DatabaseHandle,
        query,
        "OnInventoryCharacterLoaded",
        "dd",
        playerid,
        characterID
    );
    return 1;
}

public OnInventoryCharacterLoaded(playerid, characterID)
{
    if (!IsPlayerConnected(playerid) ||
        !IsPlayerCharacterLoaded(playerid) ||
        GetPlayerCharacterID(playerid) != characterID)
    {
        return 1;
    }

    // The query result is authoritative for this character.
    for (new slot = 0; slot < MAX_INVENTORY_SLOTS; slot++)
    {
        Inventory_ClearSlot(playerid, slot);
    }
    for (new handIndex = 0; handIndex < _:WEAPON_HAND_COUNT; handIndex++)
    {
        g_WeaponHandSlot[playerid][E_WEAPON_HAND:handIndex] = INVALID_INVENTORY_SLOT;
    }
    g_WeaponActiveHand[playerid] = WEAPON_HAND_NONE;

    new const rows = cache_num_rows();
    for (new row = 0; row < rows; row++)
    {
        new inventoryID, slot, itemIndex, amount;
        new weaponSerial, weaponID, ammoType, loadedAmmo, condition, equippedHand;

        cache_get_value_name_int(row, "inventory_id", inventoryID);
        cache_get_value_name_int(row, "slot_index", slot);
        cache_get_value_name_int(row, "item_id", itemIndex);
        cache_get_value_name_int(row, "amount", amount);
        cache_get_value_name_int(row, "weapon_serial", weaponSerial);
        cache_get_value_name_int(row, "weapon_id", weaponID);
        cache_get_value_name_int(row, "ammo_type", ammoType);
        cache_get_value_name_int(row, "loaded_ammo", loadedAmmo);
        cache_get_value_name_int(row, "weapon_condition", condition);
        cache_get_value_name_int(row, "equipped_hand", equippedHand);

        if (slot < 0 || slot >= MAX_INVENTORY_SLOTS) continue;
        if (itemIndex <= _:ITEM_NONE || itemIndex >= _:ITEM_COUNT) continue;
        if (amount <= 0) continue;

        new const E_ITEM_ID:itemID = E_ITEM_ID:itemIndex;
        PlayerInventory[playerid][slot][invExists] = true;
        PlayerInventory[playerid][slot][invDatabaseID] = inventoryID;
        PlayerInventory[playerid][slot][invItemID] = itemID;
        PlayerInventory[playerid][slot][invAmount] = amount;

        if (g_ItemData[itemID][itemType] == ITEM_TYPE_WEAPON)
        {
            InventoryWeaponData[playerid][slot][iwExists] = true;
            InventoryWeaponData[playerid][slot][iwWeaponSerial] = weaponSerial;
            InventoryWeaponData[playerid][slot][iwWeaponID] = WEAPON:weaponID;
            InventoryWeaponData[playerid][slot][iwAmmoType] = E_AMMO_TYPE:ammoType;
            InventoryWeaponData[playerid][slot][iwLoadedAmmo] = loadedAmmo;
            InventoryWeaponData[playerid][slot][iwCondition] = condition;

            if (weaponSerial >= g_InventoryNextWeaponSerial)
            {
                g_InventoryNextWeaponSerial = weaponSerial + 1;
            }

            new const E_WEAPON_HAND:hand =
                InventoryPersistence_DatabaseToHand(equippedHand);
            if (hand != WEAPON_HAND_NONE &&
                g_WeaponHandSlot[playerid][hand] == INVALID_INVENTORY_SLOT)
            {
                g_WeaponHandSlot[playerid][hand] = slot;
            }
        }
    }

    g_InventoryLoading[playerid] = false;
    g_InventoryLoaded[playerid] = true;
    g_InventoryDirty[playerid] = false;
    g_InventoryCharacterID[playerid] = characterID;

    SendClientMessage(playerid, COLOR_WHITE,
        "Tui do cua nhan vat da duoc tai.");
    return 1;
}

// Save current runtime with one upsert query plus one stale-slot cleanup query.
// The two queries are order-safe: cleanup uses NOT IN(current slots), so it can
// execute before or after the upsert without deleting rows that still exist.
stock Inventory_SaveCharacter(playerid, bool:force = false)
{
    if (!g_InventoryLoaded[playerid]) return 0;
    if (!force && !g_InventoryDirty[playerid]) return 0;

    new const characterID = g_InventoryCharacterID[playerid];
    if (characterID == INVALID_CHARACTER_ID) return 0;

    InventoryWeapon_SyncActive(playerid);

    new bool:hasRows;

    // Reuse static buffers so this function has a small stack frame.
    g_InventorySaveUpsert[0] = EOS;
    g_InventorySaveCleanup[0] = EOS;
    g_InventorySaveSlotList[0] = EOS;
    g_InventorySaveRowText[0] = EOS;
    g_InventorySaveSlotText[0] = EOS;

    format(g_InventorySaveUpsert, sizeof(g_InventorySaveUpsert),
        "INSERT INTO `player_inventory` (`character_id`,`slot_index`,`item_id`,`amount`,`weapon_serial`,`weapon_id`,`ammo_type`,`loaded_ammo`,`weapon_condition`,`equipped_hand`) VALUES ");

    for (new slot = 0; slot < MAX_INVENTORY_SLOTS; slot++)
    {
        if (!PlayerInventory[playerid][slot][invExists]) continue;

        new weaponSerial, weaponID, ammoType, loadedAmmo, condition, dbHand;
        if (InventoryWeaponData[playerid][slot][iwExists])
        {
            weaponSerial = InventoryWeaponData[playerid][slot][iwWeaponSerial];
            weaponID = _:InventoryWeaponData[playerid][slot][iwWeaponID];
            ammoType = _:InventoryWeaponData[playerid][slot][iwAmmoType];
            loadedAmmo = InventoryWeaponData[playerid][slot][iwLoadedAmmo];
            condition = InventoryWeaponData[playerid][slot][iwCondition];
            dbHand = InventoryPersistence_HandToDatabase(
                InventoryWeapon_GetHandForSlot(playerid, slot)
            );
        }

        format(g_InventorySaveRowText, sizeof(g_InventorySaveRowText),
            "%s(%d,%d,%d,%d,NULLIF(%d,0),%d,%d,%d,%d,%d)",
            hasRows ? "," : "",
            characterID,
            slot,
            _:PlayerInventory[playerid][slot][invItemID],
            PlayerInventory[playerid][slot][invAmount],
            weaponSerial,
            weaponID,
            ammoType,
            loadedAmmo,
            condition,
            dbHand
        );
        strcat(g_InventorySaveUpsert, g_InventorySaveRowText, sizeof(g_InventorySaveUpsert));

        format(g_InventorySaveSlotText, sizeof(g_InventorySaveSlotText), "%s%d", hasRows ? "," : "", slot);
        strcat(g_InventorySaveSlotList, g_InventorySaveSlotText, sizeof(g_InventorySaveSlotList));
        hasRows = true;
    }

    if (hasRows)
    {
        strcat(g_InventorySaveUpsert,
            " ON DUPLICATE KEY UPDATE `item_id`=VALUES(`item_id`),`amount`=VALUES(`amount`),`weapon_serial`=VALUES(`weapon_serial`),`weapon_id`=VALUES(`weapon_id`),`ammo_type`=VALUES(`ammo_type`),`loaded_ammo`=VALUES(`loaded_ammo`),`weapon_condition`=VALUES(`weapon_condition`),`equipped_hand`=VALUES(`equipped_hand`);",
            sizeof(g_InventorySaveUpsert)
        );
        mysql_tquery(g_DatabaseHandle, g_InventorySaveUpsert);

        mysql_format(
            g_DatabaseHandle,
            g_InventorySaveCleanup,
            sizeof(g_InventorySaveCleanup),
            "DELETE FROM `player_inventory` WHERE `character_id`=%d AND `slot_index` NOT IN (%s);",
            characterID,
            g_InventorySaveSlotList
        );
    }
    else
    {
        mysql_format(
            g_DatabaseHandle,
            g_InventorySaveCleanup,
            sizeof(g_InventorySaveCleanup),
            "DELETE FROM `player_inventory` WHERE `character_id`=%d;",
            characterID
        );
    }

    mysql_tquery(g_DatabaseHandle, g_InventorySaveCleanup);
    g_InventoryDirty[playerid] = false;
    return 1;
}

public OnInventorySerialLoaded()
{
    new maxSerial = 100000;
    if (cache_num_rows() > 0)
    {
        cache_get_value_name_int(0, "max_serial", maxSerial);
    }

    if (maxSerial < 100000) maxSerial = 100000;
    g_InventoryNextWeaponSerial = maxSerial + 1;
    g_InventorySerialReady = true;
    return 1;
}

forward Inventory_AutosaveTick();
public Inventory_AutosaveTick()
{
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        if (!IsPlayerConnected(playerid)) continue;
        if (!g_InventoryLoaded[playerid]) continue;
        if (!g_InventoryDirty[playerid]) continue;
        Inventory_SaveCharacter(playerid);
    }
    return 1;
}

public InventoryPersistence_Init()
{
    // Database module connects during OnGameModeInit. Delay this query so hook
    // ordering can never race the connection setup.
    mysql_tquery(
        g_DatabaseHandle,
        "SELECT COALESCE(MAX(`weapon_serial`),100000) AS `max_serial` FROM `player_inventory`;",
        "OnInventorySerialLoaded"
    );
    return 1;
}

hook OnGameModeInit()
{
    SetTimer("InventoryPersistence_Init", 1000, false);

    g_InventoryAutosaveTimer = SetTimer(
        "Inventory_AutosaveTick",
        INVENTORY_AUTOSAVE_MS,
        true
    );
    return 1;
}

hook OnGameModeExit()
{
    // Players are saved in OnPlayerDisconnect. Avoid issuing queries here
    // because the database module may already be closing its connection.
    if (g_InventoryAutosaveTimer)
    {
        KillTimer(g_InventoryAutosaveTimer);
        g_InventoryAutosaveTimer = 0;
    }
    return 1;
}

// Character spawn is the first reliable gameplay point after character load.
// Re-spawns do not re-query unless character identity changed.
hook OnPlayerSpawn(playerid)
{
    if (!IsPlayerCharacterLoaded(playerid)) return 1;

    if (!g_InventoryLoaded[playerid] ||
        g_InventoryCharacterID[playerid] != GetPlayerCharacterID(playerid))
    {
        Inventory_LoadCharacter(playerid);
    }
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason

    // Callback still has runtime state available here; sync ammo before query.
    if (g_InventoryLoaded[playerid])
    {
        Inventory_SaveCharacter(playerid, true);
    }
    return 1;
}
