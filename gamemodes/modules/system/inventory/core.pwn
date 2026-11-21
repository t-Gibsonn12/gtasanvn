//-----------------------------------------------------------------------------
// LS:RP Inventory - Core
//-----------------------------------------------------------------------------

#include <YSI_Coding\y_hooks>

// Mark the currently loaded character inventory for the next autosave.
// Calls before load completion are intentionally ignored.
stock Inventory_MarkDirty(playerid)
{
    if (g_InventoryLoaded[playerid])
    {
        g_InventoryDirty[playerid] = true;
    }
    return 1;
}

stock bool:Inventory_IsLoaded(playerid)
{
    return (
        g_InventoryLoaded[playerid] &&
        g_InventoryCharacterID[playerid] == GetPlayerCharacterID(playerid)
    );
}

stock Inventory_ClearWeaponData(playerid, slot)
{
    InventoryWeaponData[playerid][slot][iwExists] = false;
    InventoryWeaponData[playerid][slot][iwWeaponSerial] = 0;
    InventoryWeaponData[playerid][slot][iwWeaponID] = WEAPON_FIST;
    InventoryWeaponData[playerid][slot][iwAmmoType] = AMMO_NONE;
    InventoryWeaponData[playerid][slot][iwLoadedAmmo] = 0;
    InventoryWeaponData[playerid][slot][iwCondition] = 0;
    return 1;
}

// Remove one slot from runtime. Hand references are cleared here too so future
// item-removal systems cannot leave a LEFT/RIGHT pointer to a deleted weapon.
stock Inventory_ClearSlot(playerid, slot)
{
    if (slot < 0 || slot >= MAX_INVENTORY_SLOTS) return 0;

    for (new handIndex = 0; handIndex < _:WEAPON_HAND_COUNT; handIndex++)
    {
        new const E_WEAPON_HAND:hand = E_WEAPON_HAND:handIndex;
        if (g_WeaponHandSlot[playerid][hand] == slot)
        {
            g_WeaponHandSlot[playerid][hand] = INVALID_INVENTORY_SLOT;
            if (g_WeaponActiveHand[playerid] == hand)
            {
                g_WeaponActiveHand[playerid] = WEAPON_HAND_NONE;
            }
        }
    }

    PlayerInventory[playerid][slot][invExists] = false;
    PlayerInventory[playerid][slot][invDatabaseID] = 0;
    PlayerInventory[playerid][slot][invItemID] = ITEM_NONE;
    PlayerInventory[playerid][slot][invAmount] = 0;
    Inventory_ClearWeaponData(playerid, slot);
    return 1;
}

// Reset only runtime state. Persistence load calls this before hydrating rows.
stock Inventory_Reset(playerid)
{
    for (new slot = 0; slot < MAX_INVENTORY_SLOTS; slot++)
    {
        Inventory_ClearSlot(playerid, slot);
    }

    for (new handIndex = 0; handIndex < _:WEAPON_HAND_COUNT; handIndex++)
    {
        g_WeaponHandSlot[playerid][E_WEAPON_HAND:handIndex] = INVALID_INVENTORY_SLOT;
    }

    g_WeaponActiveHand[playerid] = WEAPON_HAND_NONE;
    g_InventoryPendingWeaponSlot[playerid] = INVALID_INVENTORY_SLOT;

    g_InventoryPage[playerid] = 0;
    g_InventoryCategory[playerid] = ITEM_CATEGORY_ALL;
    g_InventorySelectedSlot[playerid] = INVALID_INVENTORY_SLOT;
    g_InventoryVisibleCount[playerid] = 0;
    g_InventoryUIOpen[playerid] = false;

    g_InventoryLoaded[playerid] = false;
    g_InventoryLoading[playerid] = false;
    g_InventoryDirty[playerid] = false;
    g_InventoryCharacterID[playerid] = INVALID_CHARACTER_ID;
    return 1;
}

stock bool:Inventory_IsValidItem(E_ITEM_ID:itemID)
{
    return (_:itemID > _:ITEM_NONE && _:itemID < _:ITEM_COUNT);
}

stock Float:Inventory_GetWeight(playerid)
{
    new Float:weight;

    for (new slot = 0; slot < MAX_INVENTORY_SLOTS; slot++)
    {
        if (!PlayerInventory[playerid][slot][invExists]) continue;

        new const E_ITEM_ID:itemID = PlayerInventory[playerid][slot][invItemID];
        weight += g_ItemData[itemID][itemWeight] *
            float(PlayerInventory[playerid][slot][invAmount]);
    }
    return weight;
}

stock Inventory_GetUsedSlots(playerid)
{
    new count;
    for (new slot = 0; slot < MAX_INVENTORY_SLOTS; slot++)
    {
        if (PlayerInventory[playerid][slot][invExists]) count++;
    }
    return count;
}

stock Inventory_GetFreeSlot(playerid)
{
    for (new slot = 0; slot < MAX_INVENTORY_SLOTS; slot++)
    {
        if (!PlayerInventory[playerid][slot][invExists]) return slot;
    }
    return INVALID_INVENTORY_SLOT;
}

stock Inventory_GetFreeSlotCount(playerid)
{
    return MAX_INVENTORY_SLOTS - Inventory_GetUsedSlots(playerid);
}

stock bool:Inventory_CanStackSlot(playerid, slot, E_ITEM_ID:itemID)
{
    if (!PlayerInventory[playerid][slot][invExists]) return false;
    if (PlayerInventory[playerid][slot][invItemID] != itemID) return false;
    if (g_ItemData[itemID][itemType] == ITEM_TYPE_WEAPON) return false;

    return PlayerInventory[playerid][slot][invAmount] <
        g_ItemData[itemID][itemMaxStack];
}

stock bool:Inventory_CanCarry(playerid, E_ITEM_ID:itemID, amount)
{
    if (!Inventory_IsValidItem(itemID) || amount <= 0) return false;

    new const Float:futureWeight =
        Inventory_GetWeight(playerid) +
        g_ItemData[itemID][itemWeight] * float(amount);

    return futureWeight <= INVENTORY_MAX_WEIGHT;
}

// Preflight slot capacity before mutating runtime. This prevents partial adds
// when an admin/test command requests more items than the inventory can hold.
stock bool:Inventory_HasSlotCapacity(playerid, E_ITEM_ID:itemID, amount)
{
    if (g_ItemData[itemID][itemType] == ITEM_TYPE_WEAPON)
    {
        return Inventory_GetFreeSlotCount(playerid) >= amount;
    }

    new capacity;
    for (new slot = 0; slot < MAX_INVENTORY_SLOTS; slot++)
    {
        if (!Inventory_CanStackSlot(playerid, slot, itemID)) continue;
        capacity += g_ItemData[itemID][itemMaxStack] -
            PlayerInventory[playerid][slot][invAmount];
    }

    capacity += Inventory_GetFreeSlotCount(playerid) *
        g_ItemData[itemID][itemMaxStack];
    return capacity >= amount;
}

stock Inventory_CreateWeaponData(playerid, slot, E_ITEM_ID:itemID)
{
    if (g_ItemData[itemID][itemType] != ITEM_TYPE_WEAPON) return 0;

    // Never issue a new persistent serial before MAX(serial) has loaded.
    if (!g_InventorySerialReady) return 0;

    InventoryWeaponData[playerid][slot][iwExists] = true;
    InventoryWeaponData[playerid][slot][iwWeaponSerial] =
        g_InventoryNextWeaponSerial++;
    InventoryWeaponData[playerid][slot][iwWeaponID] =
        g_ItemData[itemID][itemWeaponID];
    InventoryWeaponData[playerid][slot][iwAmmoType] =
        g_ItemData[itemID][itemAmmoType];
    InventoryWeaponData[playerid][slot][iwLoadedAmmo] =
        g_ItemData[itemID][itemMagazineSize];
    InventoryWeaponData[playerid][slot][iwCondition] = 100;
    return 1;
}

stock Inventory_AddItem(playerid, E_ITEM_ID:itemID, amount)
{
    if (!Inventory_IsValidItem(itemID) || amount <= 0) return 0;
    if (!Inventory_CanCarry(playerid, itemID, amount)) return 0;
    if (!Inventory_HasSlotCapacity(playerid, itemID, amount)) return 0;

    if (g_ItemData[itemID][itemType] == ITEM_TYPE_WEAPON &&
        !g_InventorySerialReady)
    {
        return 0;
    }

    new remaining = amount;

    if (g_ItemData[itemID][itemType] == ITEM_TYPE_WEAPON)
    {
        while (remaining > 0)
        {
            new const slot = Inventory_GetFreeSlot(playerid);
            if (slot == INVALID_INVENTORY_SLOT) return 0;

            PlayerInventory[playerid][slot][invExists] = true;
            PlayerInventory[playerid][slot][invItemID] = itemID;
            PlayerInventory[playerid][slot][invAmount] = 1;

            if (!Inventory_CreateWeaponData(playerid, slot, itemID))
            {
                Inventory_ClearSlot(playerid, slot);
                return 0;
            }
            remaining--;
        }

        Inventory_MarkDirty(playerid);
        return 1;
    }

    for (new slot = 0; slot < MAX_INVENTORY_SLOTS && remaining > 0; slot++)
    {
        if (!Inventory_CanStackSlot(playerid, slot, itemID)) continue;

        new const capacity =
            g_ItemData[itemID][itemMaxStack] -
            PlayerInventory[playerid][slot][invAmount];

        new addAmount = remaining;
        if (addAmount > capacity) addAmount = capacity;

        PlayerInventory[playerid][slot][invAmount] += addAmount;
        remaining -= addAmount;
    }

    while (remaining > 0)
    {
        new const slot = Inventory_GetFreeSlot(playerid);
        if (slot == INVALID_INVENTORY_SLOT) return 0;

        new addAmount = remaining;
        if (addAmount > g_ItemData[itemID][itemMaxStack])
        {
            addAmount = g_ItemData[itemID][itemMaxStack];
        }

        PlayerInventory[playerid][slot][invExists] = true;
        PlayerInventory[playerid][slot][invItemID] = itemID;
        PlayerInventory[playerid][slot][invAmount] = addAmount;
        remaining -= addAmount;
    }

    Inventory_MarkDirty(playerid);
    return 1;
}

stock Inventory_RemoveFromSlot(playerid, slot, amount)
{
    if (slot < 0 || slot >= MAX_INVENTORY_SLOTS ||
        !PlayerInventory[playerid][slot][invExists] ||
        amount <= 0)
    {
        return 0;
    }

    if (amount >= PlayerInventory[playerid][slot][invAmount])
    {
        Inventory_ClearSlot(playerid, slot);
        Inventory_MarkDirty(playerid);
        return 1;
    }

    PlayerInventory[playerid][slot][invAmount] -= amount;
    Inventory_MarkDirty(playerid);
    return 1;
}

// Return whether an inventory slot is currently assigned to LEFT/RIGHT HAND.
// Equipped weapons stay as real inventory instances but are hidden from the
// normal item list while equipped.
stock bool:Inventory_IsSlotEquipped(playerid, slot)
{
    if (slot < 0 || slot >= MAX_INVENTORY_SLOTS)
    {
        return false;
    }

    for (new handIndex = 0; handIndex < _:WEAPON_HAND_COUNT; handIndex++)
    {
        new const E_WEAPON_HAND:hand = E_WEAPON_HAND:handIndex;
        if (g_WeaponHandSlot[playerid][hand] == slot)
        {
            return true;
        }
    }

    return false;
}

stock Inventory_CountCategory(playerid, E_ITEM_CATEGORY:category)
{
    new count;

    for (new slot = 0; slot < MAX_INVENTORY_SLOTS; slot++)
    {
        if (!PlayerInventory[playerid][slot][invExists]) continue;
        if (Inventory_IsSlotEquipped(playerid, slot)) continue;

        new const E_ITEM_ID:itemID =
            PlayerInventory[playerid][slot][invItemID];

        if (category == ITEM_CATEGORY_ALL ||
            g_ItemData[itemID][itemCategory] == category)
        {
            count++;
        }
    }
    return count;
}

stock Inventory_RebuildVisibleSlots(playerid)
{
    for (new row = 0; row < INVENTORY_UI_ROWS; row++)
    {
        g_InventoryVisibleSlot[playerid][row] = INVALID_INVENTORY_SLOT;
    }

    new matched, visible;
    new const startIndex = g_InventoryPage[playerid] * INVENTORY_UI_ROWS;

    for (new slot = 0; slot < MAX_INVENTORY_SLOTS; slot++)
    {
        if (!PlayerInventory[playerid][slot][invExists]) continue;
        if (Inventory_IsSlotEquipped(playerid, slot)) continue;

        new const E_ITEM_ID:itemID =
            PlayerInventory[playerid][slot][invItemID];

        if (g_InventoryCategory[playerid] != ITEM_CATEGORY_ALL &&
            g_ItemData[itemID][itemCategory] != g_InventoryCategory[playerid])
        {
            continue;
        }

        if (matched++ < startIndex) continue;
        if (visible >= INVENTORY_UI_ROWS) break;

        g_InventoryVisibleSlot[playerid][visible++] = slot;
    }

    g_InventoryVisibleCount[playerid] = visible;
    return visible;
}

stock Inventory_GetAmmoCode(E_AMMO_TYPE:ammoType, destination[], size)
{
    for (new index = 1; index < _:ITEM_COUNT; index++)
    {
        new const E_ITEM_ID:itemID = E_ITEM_ID:index;

        if (g_ItemData[itemID][itemType] == ITEM_TYPE_AMMO &&
            g_ItemData[itemID][itemAmmoType] == ammoType)
        {
            format(destination, size, "%s", g_ItemData[itemID][itemCode]);
            return 1;
        }
    }

    format(destination, size, "N/A");
    return 0;
}

hook OnPlayerConnect(playerid)
{
    Inventory_Reset(playerid);
    return 1;
}
