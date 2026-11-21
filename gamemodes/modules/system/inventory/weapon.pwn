//-----------------------------------------------------------------------------
// LS:RP Inventory - Weapon Usage
// LEFT HAND / RIGHT HAND loadout + runtime ammo synchronization.
//-----------------------------------------------------------------------------

#include <YSI_Coding\y_hooks>

// Deferred post-shot check used to sync actual GTA ammo and trigger auto reload.
new bool:g_InventoryWeaponShotCheckPending[MAX_PLAYERS];

forward public InventoryWeapon_AfterShot(playerid);

// Return the hand currently pointing at an inventory weapon slot.
stock E_WEAPON_HAND:InventoryWeapon_GetHandForSlot(playerid, slot)
{
    for (new handIndex = 0; handIndex < _:WEAPON_HAND_COUNT; handIndex++)
    {
        new const E_WEAPON_HAND:hand = E_WEAPON_HAND:handIndex;
        if (g_WeaponHandSlot[playerid][hand] == slot)
        {
            return hand;
        }
    }
    return WEAPON_HAND_NONE;
}

stock InventoryWeapon_GetSlotByHand(playerid, E_WEAPON_HAND:hand)
{
    if (_:hand < _:WEAPON_HAND_LEFT || _:hand >= _:WEAPON_HAND_COUNT)
    {
        return INVALID_INVENTORY_SLOT;
    }
    return g_WeaponHandSlot[playerid][hand];
}

stock bool:InventoryWeapon_IsValidSlot(playerid, slot)
{
    if (slot < 0 || slot >= MAX_INVENTORY_SLOTS) return false;
    if (!PlayerInventory[playerid][slot][invExists]) return false;
    if (!InventoryWeaponData[playerid][slot][iwExists]) return false;

    new const E_ITEM_ID:itemID = PlayerInventory[playerid][slot][invItemID];
    return g_ItemData[itemID][itemType] == ITEM_TYPE_WEAPON;
}

stock bool:InventoryWeapon_IsFirearmSlot(playerid, slot)
{
    if (!InventoryWeapon_IsValidSlot(playerid, slot)) return false;
    new const E_ITEM_ID:itemID = PlayerInventory[playerid][slot][invItemID];
    return g_ItemData[itemID][itemMagazineSize] > 0;
}

// Resolve the native GTA weapon slot for one inventory weapon instance.
// LEFT/RIGHT may never contain two weapons that occupy the same native slot,
// because GTA stores only one weapon entry per weapon slot.
stock WEAPON_SLOT:InventoryWeapon_GetNativeSlot(playerid, inventorySlot)
{
    if (!InventoryWeapon_IsValidSlot(playerid, inventorySlot))
    {
        return WEAPON_SLOT_UNKNOWN;
    }

    return GetWeaponSlot(
        InventoryWeaponData[playerid][inventorySlot][iwWeaponID]
    );
}

// Validate that assigning a weapon to a hand will not conflict with the
// weapon already assigned to the opposite hand.
stock bool:InventoryWeapon_CanAssignHand(
    playerid,
    inventorySlot,
    E_WEAPON_HAND:targetHand
)
{
    if (!InventoryWeapon_IsValidSlot(playerid, inventorySlot))
    {
        return false;
    }

    new const WEAPON_SLOT:newNativeSlot =
        InventoryWeapon_GetNativeSlot(playerid, inventorySlot);

    for (new handIndex = 0; handIndex < _:WEAPON_HAND_COUNT; handIndex++)
    {
        new const E_WEAPON_HAND:otherHand =
            E_WEAPON_HAND:handIndex;

        if (otherHand == targetHand)
        {
            continue;
        }

        new const otherInventorySlot =
            g_WeaponHandSlot[playerid][otherHand];

        if (!InventoryWeapon_IsValidSlot(playerid, otherInventorySlot))
        {
            continue;
        }

        new const WEAPON_SLOT:otherNativeSlot =
            InventoryWeapon_GetNativeSlot(
                playerid,
                otherInventorySlot
            );

        if (newNativeSlot != WEAPON_SLOT_UNKNOWN &&
            newNativeSlot == otherNativeSlot)
        {
            return false;
        }
    }

    return true;
}

stock InventoryWeapon_GetHandName(E_WEAPON_HAND:hand, destination[], size)
{
    switch (hand)
    {
        case WEAPON_HAND_LEFT: format(destination, size, "LEFT HAND");
        case WEAPON_HAND_RIGHT: format(destination, size, "RIGHT HAND");
        default: format(destination, size, "TRONG TUI");
    }
    return 1;
}

// Read total GTA ammo for the exact active weapon. Because LS:RP gives the
// runtime weapon only its loaded-magazine amount, GTA total ammo is the
// authoritative number of rounds currently left in that magazine.
stock InventoryWeapon_ReadRuntimeAmmo(playerid, WEAPON:expectedWeapon)
{
    for (new gtaSlot = 0; gtaSlot < 13; gtaSlot++)
    {
        new WEAPON:weaponID, ammo;
        GetPlayerWeaponData(playerid, WEAPON_SLOT:gtaSlot, weaponID, ammo);
        if (weaponID == expectedWeapon)
        {
            return ammo;
        }
    }
    return 0;
}

// Persist ammo from the currently active GTA weapon back into its inventory
// instance before switching, holstering, saving or disconnecting.
stock InventoryWeapon_SyncActive(playerid)
{
    new const E_WEAPON_HAND:hand = g_WeaponActiveHand[playerid];
    if (hand == WEAPON_HAND_NONE) return 1;

    new const slot = InventoryWeapon_GetSlotByHand(playerid, hand);
    if (!InventoryWeapon_IsValidSlot(playerid, slot))
    {
        g_WeaponActiveHand[playerid] = WEAPON_HAND_NONE;
        return 0;
    }

    if (!InventoryWeapon_IsFirearmSlot(playerid, slot)) return 1;

    new const E_ITEM_ID:itemID = PlayerInventory[playerid][slot][invItemID];
    new ammo = InventoryWeapon_ReadRuntimeAmmo(
        playerid,
        InventoryWeaponData[playerid][slot][iwWeaponID]
    );

    if (ammo < 0) ammo = 0;
    if (ammo > g_ItemData[itemID][itemMagazineSize])
    {
        ammo = g_ItemData[itemID][itemMagazineSize];
    }

    if (InventoryWeaponData[playerid][slot][iwLoadedAmmo] != ammo)
    {
        InventoryWeaponData[playerid][slot][iwLoadedAmmo] = ammo;
        Inventory_MarkDirty(playerid);
    }
    return 1;
}

// Remove an invalid duplicate native-slot assignment from RIGHT HAND.
// This also protects characters saved with an old pre-fix LEFT/RIGHT pair.
stock InventoryWeapon_SanitizeHands(playerid)
{
    new const leftSlot =
        g_WeaponHandSlot[playerid][WEAPON_HAND_LEFT];

    new const rightSlot =
        g_WeaponHandSlot[playerid][WEAPON_HAND_RIGHT];

    if (!InventoryWeapon_IsValidSlot(playerid, leftSlot) ||
        !InventoryWeapon_IsValidSlot(playerid, rightSlot))
    {
        return 1;
    }

    new const WEAPON_SLOT:leftNativeSlot =
        InventoryWeapon_GetNativeSlot(playerid, leftSlot);

    new const WEAPON_SLOT:rightNativeSlot =
        InventoryWeapon_GetNativeSlot(playerid, rightSlot);

    if (leftNativeSlot != WEAPON_SLOT_UNKNOWN &&
        leftNativeSlot == rightNativeSlot)
    {
        // Keep LEFT for deterministic migration and return RIGHT to inventory.
        g_WeaponHandSlot[playerid][WEAPON_HAND_RIGHT] =
            INVALID_INVENTORY_SLOT;

        if (g_WeaponActiveHand[playerid] == WEAPON_HAND_RIGHT)
        {
            g_WeaponActiveHand[playerid] = WEAPON_HAND_LEFT;
        }

        Inventory_MarkDirty(playerid);

        SendClientMessage(
            playerid,
            COLOR_RED,
            "Loadout cu co 2 vu khi cung weapon slot. RIGHT HAND da duoc dua ve tui do."
        );
    }

    return 1;
}

// GTA receives only one weapon at a time. LEFT/RIGHT remain server-side
// loadout slots, avoiding native weapon-slot conflicts and making ammo state
// deterministic.
stock InventoryWeapon_ApplyActive(playerid)
{
    InventoryWeapon_SanitizeHands(playerid);
    ResetPlayerWeapons(playerid);

    new const E_WEAPON_HAND:hand = g_WeaponActiveHand[playerid];
    if (hand == WEAPON_HAND_NONE) return 1;

    new const slot = InventoryWeapon_GetSlotByHand(playerid, hand);
    if (!InventoryWeapon_IsValidSlot(playerid, slot))
    {
        g_WeaponActiveHand[playerid] = WEAPON_HAND_NONE;
        return 0;
    }

    new const WEAPON:weaponID =
        InventoryWeaponData[playerid][slot][iwWeaponID];

    if (InventoryWeapon_IsFirearmSlot(playerid, slot))
    {
        new const loadedAmmo =
            InventoryWeaponData[playerid][slot][iwLoadedAmmo];

        // A firearm with zero loaded rounds remains assigned to the hand but
        // is not spawned with a fake bullet. Reloading will apply it again.
        if (loadedAmmo <= 0)
        {
            SendClientMessage(playerid, COLOR_WHITE,
                "Vu khi dang het dan. Hay nap dung loai dan trong tui do.");
            return 1;
        }

        GivePlayerWeapon(playerid, weaponID, loadedAmmo);
    }
    else
    {
        // Melee natives still expect a positive ammo/count value when granted.
        GivePlayerWeapon(playerid, weaponID, 1);
    }

    SetPlayerArmedWeapon(playerid, weaponID);
    return 1;
}

stock InventoryWeapon_ActivateHand(playerid, E_WEAPON_HAND:hand)
{
    if (!Medical_RequireAction(playerid, MEDICAL_ACTION_WEAPON)) return 0;

    new const slot = InventoryWeapon_GetSlotByHand(playerid, hand);
    if (!InventoryWeapon_IsValidSlot(playerid, slot))
    {
        SendClientMessage(playerid, COLOR_RED,
            "Hand nay khong co vu khi hop le.");
        return 0;
    }

    InventoryWeapon_SyncActive(playerid);
    g_WeaponActiveHand[playerid] = hand;
    InventoryWeapon_ApplyActive(playerid);
    return 1;
}

// Assign a weapon instance to LEFT/RIGHT. Replacing a hand never deletes the
// previous item; it simply returns that item to normal inventory state.
stock InventoryWeapon_EquipToHand(playerid, slot, E_WEAPON_HAND:hand)
{
    if (!Medical_RequireAction(playerid, MEDICAL_ACTION_WEAPON)) return 0;
    if (!InventoryWeapon_IsValidSlot(playerid, slot)) return 0;
    if (_:hand < _:WEAPON_HAND_LEFT || _:hand >= _:WEAPON_HAND_COUNT) return 0;

    // GTA supports only one weapon per native weapon slot. Prevent pairs such
    // as Glock + M1911 in LEFT/RIGHT because both occupy the pistol slot.
    if (!InventoryWeapon_CanAssignHand(playerid, slot, hand))
    {
        new const WEAPON_SLOT:nativeSlot =
            InventoryWeapon_GetNativeSlot(playerid, slot);

        new msg[144];
        format(
            msg,
            sizeof(msg),
            "Khong the trang bi 2 vu khi cung weapon slot (%d). Hay thao vu khi o hand con lai truoc.",
            _:nativeSlot
        );
        SendClientMessage(playerid, COLOR_RED, msg);
        return 0;
    }

    InventoryWeapon_SyncActive(playerid);

    // A weapon can belong to exactly one hand.
    new const E_WEAPON_HAND:oldHand =
        InventoryWeapon_GetHandForSlot(playerid, slot);
    if (oldHand != WEAPON_HAND_NONE && oldHand != hand)
    {
        g_WeaponHandSlot[playerid][oldHand] = INVALID_INVENTORY_SLOT;
    }

    g_WeaponHandSlot[playerid][hand] = slot;
    g_WeaponActiveHand[playerid] = hand;

    // Once equipped, the item is represented by LEFT/RIGHT HAND rather than
    // the normal item row.
    if (g_InventorySelectedSlot[playerid] == slot)
    {
        g_InventorySelectedSlot[playerid] =
            INVALID_INVENTORY_SLOT;
    }

    Inventory_MarkDirty(playerid);
    InventoryWeapon_ApplyActive(playerid);
    return 1;
}

stock InventoryWeapon_UnequipSlot(playerid, slot)
{
    new const E_WEAPON_HAND:hand =
        InventoryWeapon_GetHandForSlot(playerid, slot);
    if (hand == WEAPON_HAND_NONE) return 0;

    if (g_WeaponActiveHand[playerid] == hand)
    {
        InventoryWeapon_SyncActive(playerid);
        g_WeaponActiveHand[playerid] = WEAPON_HAND_NONE;
        ResetPlayerWeapons(playerid);
    }

    g_WeaponHandSlot[playerid][hand] = INVALID_INVENTORY_SLOT;
    Inventory_MarkDirty(playerid);
    return 1;
}

stock InventoryWeapon_ShowHandDialog(playerid, slot)
{
    if (!InventoryWeapon_IsValidSlot(playerid, slot)) return 0;

    new leftName[48] = "TRONG", rightName[48] = "TRONG";
    new const leftSlot = g_WeaponHandSlot[playerid][WEAPON_HAND_LEFT];
    new const rightSlot = g_WeaponHandSlot[playerid][WEAPON_HAND_RIGHT];

    if (InventoryWeapon_IsValidSlot(playerid, leftSlot))
    {
        new const E_ITEM_ID:leftItem =
            PlayerInventory[playerid][leftSlot][invItemID];
        format(leftName, sizeof(leftName), "%s", g_ItemData[leftItem][itemName]);
    }

    if (InventoryWeapon_IsValidSlot(playerid, rightSlot))
    {
        new const E_ITEM_ID:rightItem =
            PlayerInventory[playerid][rightSlot][invItemID];
        format(rightName, sizeof(rightName), "%s", g_ItemData[rightItem][itemName]);
    }

    new body[192];
    format(body, sizeof(body),
        "HAND\tHIEN TAI\nLEFT HAND\t%s\nRIGHT HAND\t%s",
        leftName,
        rightName
    );

    g_InventoryPendingWeaponSlot[playerid] = slot;
    ShowPlayerDialog(
        playerid,
        DIALOG_INVENTORY_WEAPON_HAND,
        DIALOG_STYLE_TABLIST_HEADERS,
        "Trang bi vu khi",
        body,
        "Chon",
        "Huy"
    );
    return 1;
}

// Main UI action for a weapon item.
// - unassigned: choose LEFT/RIGHT;
// - assigned but inactive: make that hand active;
// - assigned and active: holster/remove it from that hand.
stock InventoryWeapon_UseSlot(playerid, slot)
{
    if (!InventoryWeapon_IsValidSlot(playerid, slot)) return 0;

    new const E_WEAPON_HAND:hand =
        InventoryWeapon_GetHandForSlot(playerid, slot);

    if (hand == WEAPON_HAND_NONE)
    {
        return InventoryWeapon_ShowHandDialog(playerid, slot);
    }

    if (g_WeaponActiveHand[playerid] == hand)
    {
        InventoryWeapon_UnequipSlot(playerid, slot);
        SendClientMessage(playerid, COLOR_WHITE,
            "Da cat vu khi khoi hand va dua ve tui do.");
        return 1;
    }

    InventoryWeapon_ActivateHand(playerid, hand);
    return 1;
}

// Find one reserve ammo stack compatible with the equipped firearm.
stock InventoryWeapon_FindCompatibleAmmo(playerid, weaponSlot)
{
    if (!InventoryWeapon_IsFirearmSlot(playerid, weaponSlot))
    {
        return INVALID_INVENTORY_SLOT;
    }

    new const E_AMMO_TYPE:ammoType =
        InventoryWeaponData[playerid][weaponSlot][iwAmmoType];

    for (new slot = 0; slot < MAX_INVENTORY_SLOTS; slot++)
    {
        if (!PlayerInventory[playerid][slot][invExists]) continue;

        new const E_ITEM_ID:itemID =
            PlayerInventory[playerid][slot][invItemID];

        if (g_ItemData[itemID][itemType] != ITEM_TYPE_AMMO) continue;
        if (g_ItemData[itemID][itemAmmoType] != ammoType) continue;
        if (PlayerInventory[playerid][slot][invAmount] <= 0) continue;

        return slot;
    }

    return INVALID_INVENTORY_SLOT;
}

// Reload an active firearm from one explicitly selected ammo stack.
stock InventoryWeapon_ReloadFromAmmoSlot(playerid, ammoSlot)
{
    if (!Medical_RequireAction(playerid, MEDICAL_ACTION_WEAPON)) return 0;

    if (ammoSlot < 0 || ammoSlot >= MAX_INVENTORY_SLOTS ||
        !PlayerInventory[playerid][ammoSlot][invExists])
    {
        return 0;
    }

    new const E_ITEM_ID:ammoItem =
        PlayerInventory[playerid][ammoSlot][invItemID];
    if (g_ItemData[ammoItem][itemType] != ITEM_TYPE_AMMO) return 0;

    new const E_WEAPON_HAND:hand = g_WeaponActiveHand[playerid];
    if (hand == WEAPON_HAND_NONE)
    {
        SendClientMessage(playerid, COLOR_RED,
            "Ban chua cam vu khi o LEFT/RIGHT HAND.");
        return 0;
    }

    new const weaponSlot = InventoryWeapon_GetSlotByHand(playerid, hand);
    if (!InventoryWeapon_IsFirearmSlot(playerid, weaponSlot))
    {
        SendClientMessage(playerid, COLOR_RED,
            "Vu khi dang cam khong the nap dan.");
        return 0;
    }

    if (g_ItemData[ammoItem][itemAmmoType] !=
        InventoryWeaponData[playerid][weaponSlot][iwAmmoType])
    {
        SendClientMessage(playerid, COLOR_RED,
            "Loai dan nay khong phu hop voi vu khi dang cam.");
        return 0;
    }

    InventoryWeapon_SyncActive(playerid);

    new const E_ITEM_ID:weaponItem =
        PlayerInventory[playerid][weaponSlot][invItemID];
    new const magazineSize = g_ItemData[weaponItem][itemMagazineSize];
    new const loaded = InventoryWeaponData[playerid][weaponSlot][iwLoadedAmmo];
    new need = magazineSize - loaded;

    if (need <= 0)
    {
        SendClientMessage(playerid, COLOR_WHITE,
            "Bang dan da day.");
        return 0;
    }

    new take = PlayerInventory[playerid][ammoSlot][invAmount];
    if (take > need) take = need;

    InventoryWeaponData[playerid][weaponSlot][iwLoadedAmmo] += take;
    Inventory_RemoveFromSlot(playerid, ammoSlot, take);
    Inventory_MarkDirty(playerid);
    InventoryWeapon_ApplyActive(playerid);

    new msg[128];
    format(msg, sizeof(msg),
        "Da nap %d vien. Bang dan hien tai: %d/%d.",
        take,
        InventoryWeaponData[playerid][weaponSlot][iwLoadedAmmo],
        magazineSize
    );
    SendClientMessage(playerid, COLOR_WHITE, msg);
    return 1;
}

// Convenience reload used by /reload. It consumes compatible ammo stacks in
// inventory order until the active magazine is full or ammo runs out.
stock InventoryWeapon_ReloadActive(playerid)
{
    new const E_WEAPON_HAND:hand = g_WeaponActiveHand[playerid];
    if (hand == WEAPON_HAND_NONE)
    {
        SendClientMessage(playerid, COLOR_RED,
            "Ban chua cam vu khi o LEFT/RIGHT HAND.");
        return 0;
    }

    new const weaponSlot = InventoryWeapon_GetSlotByHand(playerid, hand);
    if (!InventoryWeapon_IsFirearmSlot(playerid, weaponSlot))
    {
        SendClientMessage(playerid, COLOR_RED,
            "Vu khi dang cam khong su dung dan.");
        return 0;
    }

    InventoryWeapon_SyncActive(playerid);

    new const E_ITEM_ID:weaponItem =
        PlayerInventory[playerid][weaponSlot][invItemID];
    new const magazineSize = g_ItemData[weaponItem][itemMagazineSize];
    new need = magazineSize -
        InventoryWeaponData[playerid][weaponSlot][iwLoadedAmmo];
    if (need <= 0)
    {
        SendClientMessage(playerid, COLOR_WHITE, "Bang dan da day.");
        return 0;
    }

    new totalTaken;
    for (new slot = 0; slot < MAX_INVENTORY_SLOTS && need > 0; slot++)
    {
        if (!PlayerInventory[playerid][slot][invExists]) continue;

        new const E_ITEM_ID:itemID = PlayerInventory[playerid][slot][invItemID];
        if (g_ItemData[itemID][itemType] != ITEM_TYPE_AMMO) continue;
        if (g_ItemData[itemID][itemAmmoType] !=
            InventoryWeaponData[playerid][weaponSlot][iwAmmoType]) continue;

        new take = PlayerInventory[playerid][slot][invAmount];
        if (take > need) take = need;

        InventoryWeaponData[playerid][weaponSlot][iwLoadedAmmo] += take;
        Inventory_RemoveFromSlot(playerid, slot, take);
        totalTaken += take;
        need -= take;
    }

    if (totalTaken <= 0)
    {
        SendClientMessage(playerid, COLOR_RED,
            "Khong co dan phu hop trong tui do.");
        return 0;
    }

    Inventory_MarkDirty(playerid);
    InventoryWeapon_ApplyActive(playerid);

    new msg[128];
    format(msg, sizeof(msg),
        "Da nap %d vien. Bang dan hien tai: %d/%d.",
        totalTaken,
        InventoryWeaponData[playerid][weaponSlot][iwLoadedAmmo],
        magazineSize
    );
    SendClientMessage(playerid, COLOR_WHITE, msg);
    return 1;
}

// Unified inventory USE action. Non-weapon systems intentionally remain a
// placeholder so they can be integrated later without inventing side effects.
stock Inventory_UseSelected(playerid)
{
    new const slot = g_InventorySelectedSlot[playerid];
    if (slot < 0 || slot >= MAX_INVENTORY_SLOTS ||
        !PlayerInventory[playerid][slot][invExists])
    {
        SendClientMessage(playerid, COLOR_RED,
            "Hay chon mot vat pham truoc.");
        return 0;
    }

    new const E_ITEM_ID:itemID = PlayerInventory[playerid][slot][invItemID];
    switch (g_ItemData[itemID][itemType])
    {
        case ITEM_TYPE_WEAPON:
        {
            return InventoryWeapon_UseSlot(playerid, slot);
        }

        case ITEM_TYPE_AMMO:
        {
            return InventoryWeapon_ReloadFromAmmoSlot(playerid, slot);
        }

        case ITEM_TYPE_NORMAL:
        {
            if (Phone_TryUseItem(playerid, itemID))
            {
                return 1;
            }
            if (Tutorial_TryUseIDCard(playerid, itemID))
            {
                return 1;
            }
            if (Needs_TryUseConsumable(playerid, slot))
            {
                return 1;
            }
            SendClientMessage(
                playerid,
                COLOR_WHITE,
                "Vat pham nay chua duoc tich hop chuc nang su dung."
            );
            return 1;
        }
    }

    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    #pragma unused inputtext

    if (dialogid != DIALOG_INVENTORY_WEAPON_HAND) return 0;

    new const slot = g_InventoryPendingWeaponSlot[playerid];
    g_InventoryPendingWeaponSlot[playerid] = INVALID_INVENTORY_SLOT;

    if (!response) return 1;
    if (!InventoryWeapon_IsValidSlot(playerid, slot)) return 1;
    if (listitem < 0 || listitem >= _:WEAPON_HAND_COUNT) return 1;

    InventoryWeapon_EquipToHand(
        playerid,
        slot,
        E_WEAPON_HAND:listitem
    );

    if (g_InventoryUIOpen[playerid])
    {
        InventoryUI_Refresh(playerid);
    }
    return 1;
}

// Detect firearm shots and check the real remaining ammo immediately after
// GTA processes the shot.
public OnPlayerWeaponShot(
    playerid,
    WEAPON:weaponid,
    BULLET_HIT_TYPE:hittype,
    hitid,
    Float:fX,
    Float:fY,
    Float:fZ
)
{
    #pragma unused hittype
    #pragma unused hitid
    #pragma unused fX
    #pragma unused fY
    #pragma unused fZ

    new const E_WEAPON_HAND:hand =
        g_WeaponActiveHand[playerid];

    if (hand == WEAPON_HAND_NONE)
    {
        return 1;
    }

    new const slot =
        InventoryWeapon_GetSlotByHand(playerid, hand);

    if (!InventoryWeapon_IsFirearmSlot(playerid, slot))
    {
        return 1;
    }

    if (InventoryWeaponData[playerid][slot][iwWeaponID] != weaponid)
    {
        return 1;
    }

    if (!g_InventoryWeaponShotCheckPending[playerid])
    {
        g_InventoryWeaponShotCheckPending[playerid] = true;

        SetTimerEx(
            "InventoryWeapon_AfterShot",
            60,
            false,
            "d",
            playerid
        );
    }

    return 1;
}

public InventoryWeapon_AfterShot(playerid)
{
    g_InventoryWeaponShotCheckPending[playerid] = false;

    if (!IsPlayerConnected(playerid) ||
        !IsPlayerCharacterLoaded(playerid) ||
        !Inventory_IsLoaded(playerid))
    {
        return 1;
    }

    new const E_WEAPON_HAND:hand =
        g_WeaponActiveHand[playerid];

    if (hand == WEAPON_HAND_NONE)
    {
        return 1;
    }

    new const weaponSlot =
        InventoryWeapon_GetSlotByHand(playerid, hand);

    if (!InventoryWeapon_IsFirearmSlot(playerid, weaponSlot))
    {
        return 1;
    }

    InventoryWeapon_SyncActive(playerid);

    new const loadedAmmo =
        InventoryWeaponData[playerid][weaponSlot][iwLoadedAmmo];

    if (loadedAmmo > 1)
    {
        if (g_InventoryUIOpen[playerid])
        {
            InventoryUI_RenderHands(playerid);
        }

        return 1;
    }

    new const reserveSlot =
        InventoryWeapon_FindCompatibleAmmo(
            playerid,
            weaponSlot
        );

    // One round left + reserve ammo => automatic reload.
    if (loadedAmmo == 1 &&
        reserveSlot != INVALID_INVENTORY_SLOT)
    {
        InventoryWeapon_ReloadFromAmmoSlot(
            playerid,
            reserveSlot
        );

        if (g_InventoryUIOpen[playerid])
        {
            InventoryUI_Refresh(playerid);
        }

        return 1;
    }

    // No loaded round remains. Reload if reserve appeared; otherwise make the
    // weapon unusable until compatible ammo is obtained.
    if (loadedAmmo <= 0)
    {
        if (reserveSlot != INVALID_INVENTORY_SLOT)
        {
            InventoryWeapon_ReloadFromAmmoSlot(
                playerid,
                reserveSlot
            );
        }
        else
        {
            ResetPlayerWeapons(playerid);

            SendClientMessage(
                playerid,
                COLOR_RED,
                "Sung dang het dan. Ban khong con dan phu hop de nap."
            );
        }
    }

    if (g_InventoryUIOpen[playerid])
    {
        InventoryUI_Refresh(playerid);
    }

    return 1;
}

// Death clears only GTA runtime weapon state. LEFT/RIGHT assignments and
// instance ammo remain persisted; the player must actively draw a hand again.
hook OnPlayerDeath(playerid, killerid, WEAPON:reason)
{
    #pragma unused killerid
    #pragma unused reason

    InventoryWeapon_SyncActive(playerid);
    g_InventoryWeaponShotCheckPending[playerid] = false;
    g_WeaponActiveHand[playerid] = WEAPON_HAND_NONE;
    ResetPlayerWeapons(playerid);
    return 1;
}
