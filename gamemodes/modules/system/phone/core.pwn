#include <YSI_Coding\y_hooks>

#define PHONE_START_NUMBER (5550000)
#define PHONE_ATTACH_SLOT  (7)
#define PHONE_OBJECT_MODEL (330)

new bool:g_PhoneLoaded[MAX_PLAYERS];
new g_PhoneNumber[MAX_PLAYERS];
new g_PhoneBattery[MAX_PLAYERS];
new bool:g_PhonePowered[MAX_PLAYERS];
new bool:g_PhoneSilent[MAX_PLAYERS];
new g_PhonePeer[MAX_PLAYERS];
new bool:g_PhoneConnected[MAX_PLAYERS];
#if defined GTASANVN_CEF_PHONE
forward GTPhoneCallState(playerid);
forward GTPhoneCefOpen(playerid);
#endif
new bool:g_PhoneIncoming[MAX_PLAYERS];
new g_PhoneContactCount[MAX_PLAYERS];
new g_PhoneContactNumber[MAX_PLAYERS][50];
new g_PhoneContactName[MAX_PLAYERS][50][32];
new g_PhoneSelectedContactNumber[MAX_PLAYERS];
new g_PhoneSelectedContactName[MAX_PLAYERS][32];
new g_PhonePendingContactNumber[MAX_PLAYERS];

forward Phone_OnLoaded(playerid, characterID);
forward Phone_OnContactsLoaded(playerid, characterID);
forward Phone_ApplyTalkAnimation(playerid);
forward Phone_RemoveHandset(playerid);

stock Phone_AttachHandset(playerid)
{
    if (IsPlayerAttachedObjectSlotUsed(playerid, PHONE_ATTACH_SLOT))
    {
        RemovePlayerAttachedObject(playerid, PHONE_ATTACH_SLOT);
    }
    SetPlayerAttachedObject(playerid, PHONE_ATTACH_SLOT, PHONE_OBJECT_MODEL, 6,
        0.090, 0.015, -0.015, -90.0, 0.0, 0.0, 0.85, 0.85, 0.85);
    ApplyAnimation(playerid, "PED", "phone_in", 4.1, false, false, false, true, 800, SYNC_ALL);
    SetTimerEx("Phone_ApplyTalkAnimation", 800, false, "d", playerid);
    return 1;
}

public Phone_ApplyTalkAnimation(playerid)
{
    if (!IsPlayerConnected(playerid) || g_PhonePeer[playerid] == INVALID_PLAYER_ID)
        return 0;
    ApplyAnimation(playerid, "PED", "phone_talk", 4.1, true, false, false, true, 0, SYNC_ALL);
    return 1;
}

stock Phone_DetachHandset(playerid)
{
    if (!IsPlayerConnected(playerid)) return 0;
    ApplyAnimation(playerid, "PED", "phone_out", 4.1, false, false, false, true, 650, SYNC_ALL);
    SetTimerEx("Phone_RemoveHandset", 650, false, "d", playerid);
    return 1;
}

public Phone_RemoveHandset(playerid)
{
    if (!IsPlayerConnected(playerid)) return 0;
    if (IsPlayerAttachedObjectSlotUsed(playerid, PHONE_ATTACH_SLOT))
    {
        RemovePlayerAttachedObject(playerid, PHONE_ATTACH_SLOT);
    }
    ClearAnimations(playerid, SYNC_ALL);
    return 1;
}

stock bool:Phone_HasItem(playerid)
{
    if (!Inventory_IsLoaded(playerid)) return false;
    for (new slot = 0; slot < MAX_INVENTORY_SLOTS; slot++)
    {
        if (PlayerInventory[playerid][slot][invExists] &&
            PlayerInventory[playerid][slot][invItemID] == ITEM_PHONE) return true;
    }
    return false;
}

stock Phone_Save(playerid)
{
    if (!g_PhoneLoaded[playerid]) return 0;
    new query[256];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `character_phone_profiles` SET `powered`=%d,`silent`=%d,`battery`=%d WHERE `character_id`=%d LIMIT 1",
        g_PhonePowered[playerid], g_PhoneSilent[playerid], g_PhoneBattery[playerid],
        GetPlayerCharacterID(playerid));
    mysql_tquery(g_DatabaseHandle, query);
    return 1;
}

stock Phone_Log(playerid, const eventType[], targetNumber, const content[] = "")
{
    if (!g_PhoneLoaded[playerid]) return 0;
    new query[640];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `phone_communication_logs` (`character_id`,`phone_number`,`target_number`,`event_type`,`content`) VALUES (%d,%d,%d,'%e','%e')",
        GetPlayerCharacterID(playerid), g_PhoneNumber[playerid], targetNumber,
        eventType, content);
    mysql_tquery(g_DatabaseHandle, query);
    return 1;
}

stock bool:Phone_Require(playerid)
{
    if (!IsPlayerCharacterLoaded(playerid) || !g_PhoneLoaded[playerid])
    {
        SendClientMessage(playerid, COLOR_RED, "Du lieu dien thoai cua nhan vat chua tai xong.");
        return false;
    }
    if (!Phone_HasItem(playerid))
    {
        SendClientMessage(playerid, COLOR_RED, "Ban can co vat pham Phone trong tui do de su dung.");
        return false;
    }
    if (!g_PhonePowered[playerid])
    {
        SendClientMessage(playerid, COLOR_RED, "Dien thoai dang tat. Dung /phone de bat lai.");
        return false;
    }
    if (g_PhoneBattery[playerid] <= 0)
    {
        SendClientMessage(playerid, COLOR_RED, "Dien thoai da het pin.");
        return false;
    }
    return true;
}

stock Phone_FindByNumber(number)
{
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        if (IsPlayerConnected(playerid) && g_PhoneLoaded[playerid] &&
            g_PhoneNumber[playerid] == number) return playerid;
    }
    return INVALID_PLAYER_ID;
}

stock Phone_ClearCall(playerid, bool:notifyPeer = true)
{
    new const peer = g_PhonePeer[playerid];
    g_PhonePeer[playerid] = INVALID_PLAYER_ID;
    g_PhoneConnected[playerid] = false;
    g_PhoneIncoming[playerid] = false;
    g_PhoneContactCount[playerid] = 0;
    g_PhoneSelectedContactNumber[playerid] = 0;
    g_PhoneSelectedContactName[playerid][0] = 0;
    g_PhonePendingContactNumber[playerid] = 0;
    Phone_DetachHandset(playerid);
    #if defined GTASANVN_CEF_PHONE
    GTPhoneCallState(playerid);
    #endif
    if (peer != INVALID_PLAYER_ID && IsPlayerConnected(peer) && g_PhonePeer[peer] == playerid)
    {
        g_PhonePeer[peer] = INVALID_PLAYER_ID;
        g_PhoneConnected[peer] = false;
        g_PhoneIncoming[peer] = false;
        #if defined GTASANVN_CEF_PHONE
        GTPhoneCallState(peer);
        #endif
        Phone_DetachHandset(peer);
        if (notifyPeer) SendClientMessage(peer, 0xFFD966FF, "Cuoc goi da ket thuc.");
    }
    return 1;
}

stock Phone_OpenMenu(playerid)
{
    if (!IsPlayerCharacterLoaded(playerid) || !g_PhoneLoaded[playerid])
        return SendClientMessage(playerid, COLOR_RED, "Du lieu dien thoai chua san sang.");
    if (!Phone_HasItem(playerid))
        return SendClientMessage(playerid, COLOR_RED, "Ban khong co vat pham Phone trong tui do.");

    #if defined GTASANVN_CEF_PHONE
    if (GTPhoneCefOpen(playerid)) return 1;
    #endif
    new title[96], body[192];
    format(title, sizeof(title), "Dien thoai %d | Pin %d%%", g_PhoneNumber[playerid], g_PhoneBattery[playerid]);
    format(body, sizeof(body), "%s dien thoai\n%s che do im lang\nDanh ba\nHuong dan lenh",
        g_PhonePowered[playerid] ? "Tat" : "Bat", g_PhoneSilent[playerid] ? "Tat" : "Bat");
    ShowPlayerDialog(playerid, DIALOG_PHONE_MAIN, DIALOG_STYLE_LIST, title, body, "Chon", "Dong");
    return 1;
}

stock bool:Phone_TryUseItem(playerid, E_ITEM_ID:itemID)
{
    if (itemID != ITEM_PHONE) return false;
    InventoryUI_Close(playerid);
    Phone_OpenMenu(playerid);
    return true;
}

stock Phone_LoadForCharacter(playerid)
{
    if (!IsPlayerCharacterLoaded(playerid)) return 0;
    g_PhoneLoaded[playerid] = false;
    g_PhoneNumber[playerid] = 0;
    g_PhonePeer[playerid] = INVALID_PLAYER_ID;
    g_PhoneConnected[playerid] = false;
    g_PhoneIncoming[playerid] = false;
    new query[192];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT `phone_number`,`powered`,`silent`,`battery` FROM `character_phone_profiles` WHERE `character_id`=%d LIMIT 1",
        GetPlayerCharacterID(playerid));
    mysql_tquery(g_DatabaseHandle, query, "Phone_OnLoaded", "dd",
        playerid, GetPlayerCharacterID(playerid));
    return 1;
}

public Phone_OnLoaded(playerid, characterID)
{
    if (!IsPlayerConnected(playerid) || GetPlayerCharacterID(playerid) != characterID) return 1;
    if (cache_num_rows())
    {
        cache_get_value_name_int(0, "phone_number", g_PhoneNumber[playerid]);
        cache_get_value_name_int(0, "powered", g_PhonePowered[playerid]);
        cache_get_value_name_int(0, "silent", g_PhoneSilent[playerid]);
        cache_get_value_name_int(0, "battery", g_PhoneBattery[playerid]);
    }
    else
    {
        g_PhoneNumber[playerid] = PHONE_START_NUMBER + characterID;
        g_PhonePowered[playerid] = true;
        g_PhoneSilent[playerid] = false;
        g_PhoneBattery[playerid] = 100;
        new query[320];
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "INSERT INTO `character_phone_profiles` (`character_id`,`phone_number`,`powered`,`silent`,`battery`) VALUES (%d,%d,1,0,100) ON DUPLICATE KEY UPDATE `phone_number`=VALUES(`phone_number`)",
            characterID, g_PhoneNumber[playerid]);
        mysql_tquery(g_DatabaseHandle, query);
    }
    g_PhoneLoaded[playerid] = true;
    return 1;
}

hook OnGameModeInit()
{
    mysql_tquery(g_DatabaseHandle, "CREATE TABLE IF NOT EXISTS `character_phone_profiles` (`character_id` INT UNSIGNED NOT NULL,`phone_number` INT UNSIGNED NOT NULL,`powered` TINYINT UNSIGNED NOT NULL DEFAULT 1,`silent` TINYINT UNSIGNED NOT NULL DEFAULT 0,`battery` TINYINT UNSIGNED NOT NULL DEFAULT 100,PRIMARY KEY (`character_id`),UNIQUE KEY `uq_phone_profile_number` (`phone_number`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle, "CREATE TABLE IF NOT EXISTS `phone_contact_entries` (`contact_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,`character_id` INT UNSIGNED NOT NULL,`contact_name` VARCHAR(32) NOT NULL,`phone_number` INT UNSIGNED NOT NULL,PRIMARY KEY (`contact_id`),UNIQUE KEY `uq_phone_contact_owner_number` (`character_id`,`phone_number`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle, "CREATE TABLE IF NOT EXISTS `phone_communication_logs` (`log_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,`character_id` INT UNSIGNED NOT NULL,`phone_number` INT UNSIGNED NOT NULL,`target_number` INT UNSIGNED NOT NULL,`event_type` VARCHAR(24) NOT NULL,`content` VARCHAR(160) NOT NULL DEFAULT '',`created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY (`log_id`),KEY `idx_phone_log_character` (`character_id`,`created_at`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    return 1;
}

hook OnPlayerConnect(playerid)
{
    g_PhoneLoaded[playerid] = false;
    g_PhoneNumber[playerid] = 0;
    g_PhoneBattery[playerid] = 0;
    g_PhonePowered[playerid] = false;
    g_PhoneSilent[playerid] = false;
    g_PhonePeer[playerid] = INVALID_PLAYER_ID;
    g_PhoneConnected[playerid] = false;
    g_PhoneIncoming[playerid] = false;
    if (IsPlayerAttachedObjectSlotUsed(playerid, PHONE_ATTACH_SLOT))
        RemovePlayerAttachedObject(playerid, PHONE_ATTACH_SLOT);
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    Phone_ClearCall(playerid);
    Phone_Save(playerid);
    return 1;
}

CMD:phone(playerid, params[])
{
    #pragma unused params
    return Phone_OpenMenu(playerid);
}

CMD:call(playerid, params[])
{
    if (!Phone_Require(playerid)) return 1;
    new const number = strval(params);
    if (number <= 0) return SendClientMessage(playerid, COLOR_RED, "Su dung: /call [so dien thoai]");
    if (g_PhonePeer[playerid] != INVALID_PLAYER_ID) return SendClientMessage(playerid, COLOR_RED, "Ban dang co mot cuoc goi khac.");
    new const targetid = Phone_FindByNumber(number);
    if (targetid == INVALID_PLAYER_ID || targetid == playerid || !g_PhonePowered[targetid] || !Phone_HasItem(targetid))
    {
        Phone_Log(playerid, "call_failed", number);
        return SendClientMessage(playerid, COLOR_RED, "Thue bao khong lien lac duoc.");
    }
    if (g_PhonePeer[targetid] != INVALID_PLAYER_ID) return SendClientMessage(playerid, COLOR_RED, "Thue bao dang ban.");
    g_PhonePeer[playerid] = targetid;
    g_PhonePeer[targetid] = playerid;
    g_PhoneIncoming[targetid] = true;
    #if defined GTASANVN_CEF_PHONE
    GTPhoneCallState(targetid);
    GTPhoneCallState(playerid);
    #endif
    Phone_AttachHandset(playerid);
    g_PhoneBattery[playerid]--;
    Phone_Save(playerid);
    Phone_Log(playerid, "call_outgoing", number);
    Phone_Log(targetid, "call_incoming", g_PhoneNumber[playerid]);
    SendClientMessage(playerid, 0xFFD966FF, "Dang goi... Dung /hangup de huy.");
    new message[128];
    format(message, sizeof(message), "%sCuoc goi den tu so %d. Dung /pickup de nghe.",
        g_PhoneSilent[targetid] ? "[Im lang] " : "", g_PhoneNumber[playerid]);
    SendClientMessage(targetid, 0xFFD966FF, message);
    return 1;
}

CMD:pickup(playerid, params[])
{
    #pragma unused params
    if (!Phone_Require(playerid)) return 1;
    new const peer = g_PhonePeer[playerid];
    if (peer == INVALID_PLAYER_ID || !IsPlayerConnected(peer) || g_PhoneConnected[playerid] || !g_PhoneIncoming[playerid])
        return SendClientMessage(playerid, COLOR_RED, "Ban khong co cuoc goi den nao de nghe.");
    g_PhoneConnected[playerid] = true;
    g_PhoneConnected[peer] = true;
    #if defined GTASANVN_CEF_PHONE
    GTPhoneCallState(peer);
    GTPhoneCallState(playerid);
    #endif
    Phone_AttachHandset(playerid);
    Phone_ApplyTalkAnimation(peer);
    SendClientMessage(playerid, 0xFFD966FF, "Ban dang nghe dien thoai, su dung /p [text] de noi chuyen, /hangup de tat may.");
    SendClientMessage(peer, 0xFFD966FF, "Ban dang nghe dien thoai, su dung /p [text] de noi chuyen, /hangup de tat may.");
    return 1;
}

CMD:hangup(playerid, params[])
{
    #pragma unused params
    if (g_PhonePeer[playerid] == INVALID_PLAYER_ID) return SendClientMessage(playerid, COLOR_RED, "Ban khong co cuoc goi nao.");
    Phone_Log(playerid, "call_ended", IsPlayerConnected(g_PhonePeer[playerid]) ? g_PhoneNumber[g_PhonePeer[playerid]] : 0);
    Phone_ClearCall(playerid);
    return SendClientMessage(playerid, 0xFFD966FF, "Ban da ket thuc cuoc goi.");
}

CMD:p(playerid, params[])
{
    if (!Phone_Require(playerid)) return 1;
    new const peer = g_PhonePeer[playerid];
    if (peer == INVALID_PLAYER_ID || !IsPlayerConnected(peer) || !g_PhoneConnected[playerid])
        return SendClientMessage(playerid, COLOR_RED, "Ban chua ket noi cuoc goi.");
    if (!params[0]) return SendClientMessage(playerid, COLOR_RED, "Su dung: /p [noi dung]");
    new message[192];
    format(message, sizeof(message), "[Dien thoai] %s: %s", s_CharacterName[playerid], params);
    SendClientMessage(playerid, 0xFFF2CCFF, message);
    SendClientMessage(peer, 0xFFF2CCFF, message);
    return 1;
}

CMD:sms(playerid, params[])
{
    if (!Phone_Require(playerid)) return 1;
    new separator = strfind(params, " ");
    if (separator <= 0) return SendClientMessage(playerid, COLOR_RED, "Su dung: /sms [so dien thoai] [noi dung]");
    new numberText[16], content[160];
    strmid(numberText, params, 0, separator, sizeof(numberText));
    while (params[separator] == ' ') separator++;
    format(content, sizeof(content), "%s", params[separator]);
    new const number = strval(numberText), targetid = Phone_FindByNumber(number);
    if (number <= 0 || !content[0]) return SendClientMessage(playerid, COLOR_RED, "So dien thoai hoac noi dung khong hop le.");
    if (targetid == INVALID_PLAYER_ID || !g_PhonePowered[targetid] || !Phone_HasItem(targetid))
    {
        Phone_Log(playerid, "sms_failed", number, content);
        return SendClientMessage(playerid, COLOR_RED, "Tin nhan khong gui duoc.");
    }
    g_PhoneBattery[playerid]--;
    Phone_Save(playerid);
    Phone_Log(playerid, "sms_outgoing", number, content);
    Phone_Log(targetid, "sms_incoming", g_PhoneNumber[playerid], content);
    new message[224];
    format(message, sizeof(message), "[SMS den %d] %s", number, content);
    SendClientMessage(playerid, 0xB4C6E7FF, message);
    format(message, sizeof(message), "%s[SMS tu %d] %s", g_PhoneSilent[targetid] ? "[Im lang] " : "", g_PhoneNumber[playerid], content);
    SendClientMessage(targetid, 0xB4C6E7FF, message);
    return 1;
}

CMD:number(playerid, params[])
{
    if (!Phone_Require(playerid)) return 1;
    new const targetid = strval(params);
    if (targetid == playerid || !IsPlayerConnected(targetid) || !IsPlayerCharacterLoaded(targetid))
        return SendClientMessage(playerid, COLOR_RED, "Su dung: /number [id]");
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    if (GetPlayerInterior(targetid) != GetPlayerInterior(playerid) ||
        GetPlayerVirtualWorld(targetid) != GetPlayerVirtualWorld(playerid) ||
        GetPlayerDistanceFromPoint(targetid, x, y, z) > 3.0)
        return SendClientMessage(playerid, COLOR_RED, "Nguoi choi phai dung gan ban.");
    if (!g_PhoneLoaded[targetid] || !Phone_HasItem(targetid))
        return SendClientMessage(playerid, COLOR_RED, "Nguoi choi nay khong co dien thoai de trao doi so.");
    new message[160];
    format(message, sizeof(message), "Ban da trao doi so voi %s. So cua ho: %d.", s_CharacterName[targetid], g_PhoneNumber[targetid]);
    SendClientMessage(playerid, COLOR_WHITE, message);
    format(message, sizeof(message), "Ban da trao doi so voi %s. So cua ho: %d.", s_CharacterName[playerid], g_PhoneNumber[playerid]);
    return SendClientMessage(targetid, COLOR_WHITE, message);
}

stock Phone_ShowContacts(playerid)
{
    new query[192];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT `contact_name`,`phone_number` FROM `phone_contact_entries` WHERE `character_id`=%d ORDER BY `contact_name` LIMIT 50",
        GetPlayerCharacterID(playerid));
    mysql_tquery(g_DatabaseHandle, query, "Phone_OnContactsLoaded", "dd",
        playerid, GetPlayerCharacterID(playerid));
    return 1;
}

CMD:contact(playerid, params[])
{
    if (!Phone_Require(playerid)) return 1;
    if (!params[0] || !strcmp(params, "list", true))
    {
        return Phone_ShowContacts(playerid);
    }
    if (!strcmp(params, "add ", true, 4))
    {
        new separator = strfind(params[4], " ");
        if (separator <= 0) return SendClientMessage(playerid, COLOR_RED, "Su dung: /contact add [so] [ten]");
        new numberText[16], name[32];
        strmid(numberText, params[4], 0, separator, sizeof(numberText));
        separator += 5;
        format(name, sizeof(name), "%s", params[separator]);
        new const number = strval(numberText);
        if (number <= 0 || !name[0]) return SendClientMessage(playerid, COLOR_RED, "Du lieu lien he khong hop le.");
        new query[384];
        mysql_format(g_DatabaseHandle, query, sizeof(query), "INSERT INTO `phone_contact_entries` (`character_id`,`contact_name`,`phone_number`) VALUES (%d,'%e',%d) ON DUPLICATE KEY UPDATE `contact_name`=VALUES(`contact_name`)", GetPlayerCharacterID(playerid), name, number);
        mysql_tquery(g_DatabaseHandle, query);
        return SendClientMessage(playerid, 0x68C83BFF, "Da luu lien he vao danh ba.");
    }
    if (!strcmp(params, "del ", true, 4))
    {
        new const number = strval(params[4]);
        if (number <= 0) return SendClientMessage(playerid, COLOR_RED, "Su dung: /contact del [so]");
        new query[192];
        mysql_format(g_DatabaseHandle, query, sizeof(query), "DELETE FROM `phone_contact_entries` WHERE `character_id`=%d AND `phone_number`=%d LIMIT 1", GetPlayerCharacterID(playerid), number);
        mysql_tquery(g_DatabaseHandle, query);
        return SendClientMessage(playerid, 0x68C83BFF, "Da xoa lien he.");
    }
    return SendClientMessage(playerid, COLOR_RED, "Su dung: /contact [list/add/del]");
}

public Phone_OnContactsLoaded(playerid, characterID)
{
    if (!IsPlayerConnected(playerid) || GetPlayerCharacterID(playerid) != characterID) return 1;
    new rows = cache_num_rows(), list[1500], name[32], number;
    g_PhoneContactCount[playerid] = rows;
    if (g_PhoneContactCount[playerid] > 50) g_PhoneContactCount[playerid] = 50;
    format(list, sizeof(list), "{68C83B}[+] Them lien he moi{FFFFFF}\t\n");
    for (new row = 0; row < g_PhoneContactCount[playerid]; row++)
    {
        cache_get_value_name(row, "contact_name", name);
        cache_get_value_name_int(row, "phone_number", number);
        g_PhoneContactNumber[playerid][row] = number;
        format(g_PhoneContactName[playerid][row], 32, "%s", name);
        format(list, sizeof(list), "%s%s\t%d\n", list, name, number);
    }
    ShowPlayerDialog(playerid, DIALOG_PHONE_CONTACTS, DIALOG_STYLE_TABLIST, "Danh ba dien thoai", list, "Chon", "Dong");
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if (dialogid == DIALOG_PHONE_MAIN)
    {
        if (!response) return 1;
        switch (listitem)
        {
            case 0: { g_PhonePowered[playerid] = !g_PhonePowered[playerid]; Phone_Save(playerid); Phone_OpenMenu(playerid); }
            case 1: { g_PhoneSilent[playerid] = !g_PhoneSilent[playerid]; Phone_Save(playerid); Phone_OpenMenu(playerid); }
            case 2:
            {
                new contactCommand[8] = "list";
                cmd_contact(playerid, contactCommand);
            }
            case 3: ShowPlayerDialog(playerid, DIALOG_PHONE_HELP, DIALOG_STYLE_MSGBOX, "Huong dan dien thoai", "/call [so]\n/pickup\n/p [noi dung]\n/hangup\n/sms [so] [noi dung]\n/contact add [so] [ten]\n/contact del [so]\n/contact list\n/number [id]", "Dong", "");
        }
        return 1;
    }
    if (dialogid == DIALOG_PHONE_CONTACTS)
    {
        if (!response) return Phone_OpenMenu(playerid);
        if (listitem == 0)
        {
            ShowPlayerDialog(playerid, DIALOG_PHONE_CONTACT_ADD_NUMBER,
                DIALOG_STYLE_INPUT, "Them lien he - So dien thoai",
                "Nhap so dien thoai muon luu vao danh ba:", "Tiep tuc", "Quay lai");
            return 1;
        }
        new const contactIndex = listitem - 1;
        if (contactIndex < 0 || contactIndex >= g_PhoneContactCount[playerid]) return 1;
        g_PhoneSelectedContactNumber[playerid] = g_PhoneContactNumber[playerid][contactIndex];
        format(g_PhoneSelectedContactName[playerid], 32, "%s",
            g_PhoneContactName[playerid][contactIndex]);
        new title[96];
        format(title, sizeof(title), "%s - %d",
            g_PhoneSelectedContactName[playerid], g_PhoneSelectedContactNumber[playerid]);
        ShowPlayerDialog(playerid, DIALOG_PHONE_CONTACT_ACTIONS,
            DIALOG_STYLE_LIST, title,
            "Goi dien\nNhan tin SMS\nXem thong tin\nDoi ten lien he\nXoa lien he",
            "Chon", "Quay lai");
        return 1;
    }
    if (dialogid == DIALOG_PHONE_CONTACT_ACTIONS)
    {
        if (!response) return Phone_ShowContacts(playerid);
        new numberText[16];
        format(numberText, sizeof(numberText), "%d", g_PhoneSelectedContactNumber[playerid]);
        switch (listitem)
        {
            case 0: cmd_call(playerid, numberText);
            case 1: ShowPlayerDialog(playerid, DIALOG_PHONE_CONTACT_SMS,
                DIALOG_STYLE_INPUT, "Gui SMS", "Nhap noi dung tin nhan:", "Gui", "Quay lai");
            case 2:
            {
                new body[192];
                format(body, sizeof(body), "Ten lien he: %s\nSo dien thoai: %d",
                    g_PhoneSelectedContactName[playerid], g_PhoneSelectedContactNumber[playerid]);
                ShowPlayerDialog(playerid, DIALOG_PHONE_CONTACT_INFO,
                    DIALOG_STYLE_MSGBOX, "Thong tin lien he", body, "Quay lai", "");
            }
            case 3: ShowPlayerDialog(playerid, DIALOG_PHONE_CONTACT_RENAME,
                DIALOG_STYLE_INPUT, "Doi ten lien he", "Nhap ten moi cho lien he:", "Luu", "Quay lai");
            case 4:
            {
                new body[192];
                format(body, sizeof(body), "Ban co chac muon xoa %s (%d) khoi danh ba?",
                    g_PhoneSelectedContactName[playerid], g_PhoneSelectedContactNumber[playerid]);
                ShowPlayerDialog(playerid, DIALOG_PHONE_CONTACT_DELETE,
                    DIALOG_STYLE_MSGBOX, "Xoa lien he", body, "Xoa", "Huy");
            }
        }
        return 1;
    }
    if (dialogid == DIALOG_PHONE_CONTACT_ADD_NUMBER)
    {
        if (!response) return Phone_ShowContacts(playerid);
        new const number = strval(inputtext);
        if (number <= 0)
        {
            SendClientMessage(playerid, COLOR_RED, "So dien thoai khong hop le.");
            return ShowPlayerDialog(playerid, DIALOG_PHONE_CONTACT_ADD_NUMBER,
                DIALOG_STYLE_INPUT, "Them lien he - So dien thoai",
                "Nhap so dien thoai hop le:", "Tiep tuc", "Quay lai");
        }
        g_PhonePendingContactNumber[playerid] = number;
        ShowPlayerDialog(playerid, DIALOG_PHONE_CONTACT_ADD_NAME,
            DIALOG_STYLE_INPUT, "Them lien he - Ten",
            "Nhap ten hien thi cho lien he:", "Luu", "Quay lai");
        return 1;
    }
    if (dialogid == DIALOG_PHONE_CONTACT_ADD_NAME)
    {
        if (!response) return Phone_ShowContacts(playerid);
        if (!inputtext[0] || strlen(inputtext) > 31)
            return SendClientMessage(playerid, COLOR_RED, "Ten lien he phai co tu 1 den 31 ky tu.");
        new query[384];
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "INSERT INTO `phone_contact_entries` (`character_id`,`contact_name`,`phone_number`) VALUES (%d,'%e',%d) ON DUPLICATE KEY UPDATE `contact_name`=VALUES(`contact_name`)",
            GetPlayerCharacterID(playerid), inputtext, g_PhonePendingContactNumber[playerid]);
        mysql_tquery(g_DatabaseHandle, query);
        SendClientMessage(playerid, 0x68C83BFF, "Da them lien he vao danh ba.");
        return Phone_ShowContacts(playerid);
    }
    if (dialogid == DIALOG_PHONE_CONTACT_SMS)
    {
        if (!response) return Phone_ShowContacts(playerid);
        if (!inputtext[0]) return SendClientMessage(playerid, COLOR_RED, "Noi dung SMS khong duoc de trong.");
        new smsParams[192];
        format(smsParams, sizeof(smsParams), "%d %s",
            g_PhoneSelectedContactNumber[playerid], inputtext);
        cmd_sms(playerid, smsParams);
        return 1;
    }
    if (dialogid == DIALOG_PHONE_CONTACT_RENAME)
    {
        if (!response) return Phone_ShowContacts(playerid);
        if (!inputtext[0] || strlen(inputtext) > 31)
            return SendClientMessage(playerid, COLOR_RED, "Ten lien he phai co tu 1 den 31 ky tu.");
        new query[320];
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "UPDATE `phone_contact_entries` SET `contact_name`='%e' WHERE `character_id`=%d AND `phone_number`=%d LIMIT 1",
            inputtext, GetPlayerCharacterID(playerid), g_PhoneSelectedContactNumber[playerid]);
        mysql_tquery(g_DatabaseHandle, query);
        SendClientMessage(playerid, 0x68C83BFF, "Da doi ten lien he.");
        return Phone_ShowContacts(playerid);
    }
    if (dialogid == DIALOG_PHONE_CONTACT_DELETE)
    {
        if (!response) return Phone_ShowContacts(playerid);
        new query[240];
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "DELETE FROM `phone_contact_entries` WHERE `character_id`=%d AND `phone_number`=%d LIMIT 1",
            GetPlayerCharacterID(playerid), g_PhoneSelectedContactNumber[playerid]);
        mysql_tquery(g_DatabaseHandle, query);
        SendClientMessage(playerid, 0x68C83BFF, "Da xoa lien he khoi danh ba.");
        return Phone_ShowContacts(playerid);
    }
    if (dialogid == DIALOG_PHONE_CONTACT_INFO)
    {
        new title[96];
        format(title, sizeof(title), "%s - %d",
            g_PhoneSelectedContactName[playerid], g_PhoneSelectedContactNumber[playerid]);
        ShowPlayerDialog(playerid, DIALOG_PHONE_CONTACT_ACTIONS,
            DIALOG_STYLE_LIST, title,
            "Goi dien\nNhan tin SMS\nXem thong tin\nDoi ten lien he\nXoa lien he",
            "Chon", "Quay lai");
        return 1;
    }
    if (dialogid == DIALOG_PHONE_HELP)
    {
        return Phone_OpenMenu(playerid);
    }
    return 0;
}
