#include <YSI_Coding\y_hooks>

// Need values are percentages. One timer tick is one real minute, which keeps
// eating/drinking important without forcing players to consume items too often.
#define NEEDS_TICK_MS (60000)
#define NEEDS_EMPTY_DAMAGE (4.0)

new s_NeedsHunger[MAX_PLAYERS], s_NeedsThirst[MAX_PLAYERS];
new s_NeedsPendingSlot[MAX_PLAYERS];
new E_ITEM_ID:s_NeedsPendingItem[MAX_PLAYERS];
new s_NeedsTimer;

forward Needs_OnLoaded(playerid, characterID);
forward Needs_FinishConsume(playerid);
forward Needs_Tick();

stock Needs_GetHunger(playerid) return s_NeedsHunger[playerid];
stock Needs_GetThirst(playerid) return s_NeedsThirst[playerid];


stock Needs_Save(playerid)
{
    if (!IsPlayerCharacterLoaded(playerid)) return 0;
    new query[256];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `character_needs` (`character_id`,`hunger`,`thirst`) VALUES (%d,%d,%d) ON DUPLICATE KEY UPDATE `hunger`=VALUES(`hunger`),`thirst`=VALUES(`thirst`)",
        GetPlayerCharacterID(playerid), s_NeedsHunger[playerid], s_NeedsThirst[playerid]);
    mysql_tquery(g_DatabaseHandle, query); return 1;
}

// Returns true only for food/drink. This lets the inventory keep weapon and
// ammo behavior unchanged while adding real use behavior for consumables.
stock bool:Needs_GetItemEffect(E_ITEM_ID:itemID, &hunger, &thirst, &duration)
{
    hunger = 0; thirst = 0; duration = 1800;
    switch (itemID)
    {
        case ITEM_WATER_BOTTLE: { thirst = 35; duration = 1400; }
        case ITEM_SANDWICH: { hunger = 25; duration = 2200; }
        case ITEM_BURGER: { hunger = 35; thirst = -5; duration = 2600; }
        case ITEM_SODA: { hunger = 5; thirst = 22; duration = 1600; }
        case ITEM_COFFEE: { hunger = 4; thirst = 15; duration = 1800; }
        case ITEM_DONUT: { hunger = 15; thirst = -3; duration = 1700; }
        case ITEM_PIZZA_SLICE: { hunger = 30; thirst = -4; duration = 2400; }
        default: return false;
    }
    return true;
}

stock Needs_Clamp(&value) { if (value < 0) value = 0; if (value > 100) value = 100; return 1; }

stock bool:Needs_TryUseConsumable(playerid, slot)
{
    if (Progress_IsActive(playerid) || slot < 0 || slot >= MAX_INVENTORY_SLOTS || !PlayerInventory[playerid][slot][invExists]) return false;
    new const E_ITEM_ID:itemID = PlayerInventory[playerid][slot][invItemID];
    new hunger, thirst, duration;
    if (!Needs_GetItemEffect(itemID, hunger, thirst, duration)) return false;
    s_NeedsPendingSlot[playerid] = slot; s_NeedsPendingItem[playerid] = itemID;
    InventoryUI_Close(playerid);
    new label[64]; format(label, sizeof(label), "DANG SU DUNG %s", g_ItemData[itemID][itemName]);
    ApplyAnimation(playerid, "FOOD", "EAT_Burger", 4.0, false, false, false, false, duration, t_FORCE_SYNC:0);
    Progress_Start(playerid, label, duration, "Needs_FinishConsume");
    SendClientMessage(playerid, COLOR_WHITE, "Ban dang su dung vat pham. Hay doi thanh progress hoan tat de cap nhat doi va khat.");
    return true;
}

public Needs_FinishConsume(playerid)
{
    new const slot = s_NeedsPendingSlot[playerid]; new const E_ITEM_ID:itemID = s_NeedsPendingItem[playerid];
    s_NeedsPendingSlot[playerid] = INVALID_INVENTORY_SLOT;
    if (!IsPlayerConnected(playerid) || slot < 0 || !PlayerInventory[playerid][slot][invExists] || PlayerInventory[playerid][slot][invItemID] != itemID) return 1;
    new hunger, thirst, duration; Needs_GetItemEffect(itemID, hunger, thirst, duration);
    s_NeedsHunger[playerid] += hunger; s_NeedsThirst[playerid] += thirst; Needs_Clamp(s_NeedsHunger[playerid]); Needs_Clamp(s_NeedsThirst[playerid]);
    Inventory_RemoveFromSlot(playerid, slot, 1); Inventory_MarkDirty(playerid); Needs_Save(playerid); ClearAnimations(playerid, t_FORCE_SYNC:0);
    InventoryUI_Open(playerid);
    new message[144]; format(message, sizeof(message), "Da su dung %s. Doi: %d%% | Khat: %d%%. Mo /inv de xem va su dung cac vat pham khac.", g_ItemData[itemID][itemName], s_NeedsHunger[playerid], s_NeedsThirst[playerid]); SendClientMessage(playerid, 0x68C83BFF, message);
    return 1;
}

public Needs_OnLoaded(playerid, characterID)
{
    if (!IsPlayerConnected(playerid) || GetPlayerCharacterID(playerid) != characterID) return 1;
    s_NeedsHunger[playerid] = 100; s_NeedsThirst[playerid] = 100;
    if (cache_num_rows()) { cache_get_value_name_int(0, "hunger", s_NeedsHunger[playerid]); cache_get_value_name_int(0, "thirst", s_NeedsThirst[playerid]); Needs_Clamp(s_NeedsHunger[playerid]); Needs_Clamp(s_NeedsThirst[playerid]); }
    else Needs_Save(playerid);
    return 1;
}

public Needs_Tick()
{
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        if (!IsPlayerConnected(playerid) || !IsPlayerCharacterLoaded(playerid)) continue;
        s_NeedsHunger[playerid]--; s_NeedsThirst[playerid]--; Needs_Clamp(s_NeedsHunger[playerid]); Needs_Clamp(s_NeedsThirst[playerid]);
        if (s_NeedsHunger[playerid] == 0 || s_NeedsThirst[playerid] == 0)
        {
            new Float:health; GetPlayerHealth(playerid, health); SetPlayerHealth(playerid, health - NEEDS_EMPTY_DAMAGE);
            SendClientMessage(playerid, COLOR_RED, "Nhan vat cua ban dang kiet suc do doi hoac khat. Hay mo /inv va su dung do an hoac do uong ngay.");
        }
        Needs_Save(playerid);
    }
    return 1;
}

hook OnGameModeInit()
{
    mysql_tquery(g_DatabaseHandle, "CREATE TABLE IF NOT EXISTS `character_needs` (`character_id` INT UNSIGNED NOT NULL,`hunger` TINYINT UNSIGNED NOT NULL DEFAULT 100,`thirst` TINYINT UNSIGNED NOT NULL DEFAULT 100,`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,PRIMARY KEY (`character_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    s_NeedsTimer = SetTimer("Needs_Tick", NEEDS_TICK_MS, true); return 1;
}
hook OnGameModeExit() { if (s_NeedsTimer) KillTimer(s_NeedsTimer); return 1; }
hook OnPlayerConnect(playerid)
{
    s_NeedsHunger[playerid] = 100; s_NeedsThirst[playerid] = 100; s_NeedsPendingSlot[playerid] = INVALID_INVENTORY_SLOT;
    return 1;
}
hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    Needs_Save(playerid);
    return 1;
}
hook OnCharacterLoaded(playerid)
{
    new query[160]; mysql_format(g_DatabaseHandle, query, sizeof(query), "SELECT `hunger`,`thirst` FROM `character_needs` WHERE `character_id`=%d LIMIT 1", GetPlayerCharacterID(playerid));
    mysql_tquery(g_DatabaseHandle, query, "Needs_OnLoaded", "dd", playerid, GetPlayerCharacterID(playerid)); return 1;
}

CMD:needs(playerid, params[])
{
    #pragma unused params
    new message[128]; format(message, sizeof(message), "Trang thai nhu cau: Doi %d%% | Khat %d%%. Su dung /inv > DUNG voi do an hoac do uong de hoi phuc.", s_NeedsHunger[playerid], s_NeedsThirst[playerid]); SendClientMessage(playerid, COLOR_WHITE, message); return 1;
}
