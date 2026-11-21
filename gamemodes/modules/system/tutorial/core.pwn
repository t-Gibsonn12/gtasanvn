#include <YSI_Coding\y_hooks>

#define TUTORIAL_CITYHALL_X (1481.0859)
#define TUTORIAL_CITYHALL_Y (-1771.7139)
#define TUTORIAL_CITYHALL_Z (18.7958)
#define TUTORIAL_BANK_X     (1462.2285)
#define TUTORIAL_BANK_Y     (-1011.1547)
#define TUTORIAL_BANK_Z     (26.8438)
#define TUTORIAL_IDCARD_FEE (30)
#define TUTORIAL_BANK_FEE   (30)
#define TUTORIAL_START_CASH (1100)

new s_TutorialStage[MAX_PLAYERS];
new s_TutorialSerial[MAX_PLAYERS][24];
new s_TutorialBank[MAX_PLAYERS][24];
new bool:s_TutorialLoaded[MAX_PLAYERS];
new bool:s_TutorialCharacterReady[MAX_PLAYERS];
new bool:s_TutorialApplied[MAX_PLAYERS];
new bool:s_TutorialNewCharacter[MAX_PLAYERS];
forward Tutorial_OnLoaded(playerid, characterID);

stock Tutorial_ApplyAfterSpawn(playerid)
{
    if (!IsPlayerConnected(playerid) || !s_TutorialLoaded[playerid] ||
        !s_TutorialCharacterReady[playerid] || s_TutorialApplied[playerid])
    {
        return 0;
    }

    s_TutorialApplied[playerid] = true;

    // The starting cash is granted only after SpawnPlayer/Cinematic has set
    // the authoritative character money. Otherwise the spawn flow overwrites it.
    // Older first-character attempts could have a tutorial row saved before
    // their spawn restored cash to $0. Keep the starter grant recoverable.
    if (s_TutorialNewCharacter[playerid] ||
        (s_TutorialStage[playerid] == 0 && s_CharacterCash[playerid] < TUTORIAL_START_CASH))
    {
        new grantAmount = TUTORIAL_START_CASH - s_CharacterCash[playerid];
        if (grantAmount < 1) grantAmount = TUTORIAL_START_CASH;
        GivePlayerMoney(playerid, grantAmount);
        Economy_SaveBalances(playerid);
        Economy_LogTransaction(playerid, "tutorial_starter", grantAmount, 0, "Starter support for required Bobcat purchase");
        Tutorial_Save(playerid);
        SendClientMessage(playerid, 0x68C83BFF, "Tutorial [1/4]: Ban da nhan $1,100 ho tro. Dung /dealers de tim dai ly Company va mua Bobcat gia $1,000.");
        ShowPlayerDialog(playerid, DIALOG_TUTORIAL_IDCARD, DIALOG_STYLE_MSGBOX, "Tutorial - Buoc 1/4", "Chao mung den Los Santos.\n\nBan can mua {68C83B}Bobcat ($1,000){FFFFFF} tai mot dai ly do nguoi choi dieu hanh.\nDung /dealers de danh dau dai ly dang hoat dong; den door va bam Y.\nSau khi mua, checkpoint se dan ban den City Hall lam ID Card.", "Da hieu", "");
    }
    else if (s_TutorialStage[playerid] == 0)
    {
        SendClientMessage(playerid, 0x68C83BFF, "Tutorial [1/4]: Hay dung /dealers, den door dai ly Company va mua Bobcat gia $1,000 de bat dau.");
    }

    if (!s_TutorialNewCharacter[playerid] && s_TutorialStage[playerid] == 1)
    {
        SendClientMessage(playerid, 0x68C83BFF, "Tutorial [2/4]: Hay den City Hall theo checkpoint de dang ky ID Card.");
    }
    else if (!s_TutorialNewCharacter[playerid] && s_TutorialStage[playerid] == 2)
    {
        SendClientMessage(playerid, 0x68C83BFF, "Tutorial [3/4]: Hay den LS Bank theo checkpoint de mo tai khoan ngan hang.");
    }

    Tutorial_SetCheckpoint(playerid);
    return 1;
}

stock Tutorial_OnCharacterReady(playerid)
{
    s_TutorialCharacterReady[playerid] = true;
    return Tutorial_ApplyAfterSpawn(playerid);
}

stock Tutorial_Save(playerid)
{
    new query[320]; mysql_format(g_DatabaseHandle, query, sizeof(query), "INSERT INTO `character_tutorial` (`character_id`,`stage`,`id_serial`,`bank_account`,`starter_granted`) VALUES (%d,%d,'%e','%e',1) ON DUPLICATE KEY UPDATE `stage`=VALUES(`stage`),`id_serial`=VALUES(`id_serial`),`bank_account`=VALUES(`bank_account`)", GetPlayerCharacterID(playerid), s_TutorialStage[playerid], s_TutorialSerial[playerid], s_TutorialBank[playerid]); mysql_tquery(g_DatabaseHandle, query); return 1;
}
stock Tutorial_SetCheckpoint(playerid)
{
    if (s_TutorialStage[playerid] == 1) SetPlayerCheckpoint(playerid, TUTORIAL_CITYHALL_X, TUTORIAL_CITYHALL_Y, TUTORIAL_CITYHALL_Z, 3.0);
    else if (s_TutorialStage[playerid] == 2) SetPlayerCheckpoint(playerid, TUTORIAL_BANK_X, TUTORIAL_BANK_Y, TUTORIAL_BANK_Z, 3.0);
    else DisablePlayerCheckpoint(playerid); return 1;
}
stock bool:Tutorial_HasIDCard(playerid)
{
    for (new slot; slot < MAX_INVENTORY_SLOTS; slot++) if (PlayerInventory[playerid][slot][invExists] && PlayerInventory[playerid][slot][invItemID] == ITEM_ID_CARD) return true;
    return false;
}
// ID Card is a protected identity document. Its only use action is viewing
// the owner's profile; inventory GIVE/DROP has no backend action for it.
stock bool:Tutorial_TryUseIDCard(playerid, E_ITEM_ID:itemID)
{
    if (itemID != ITEM_ID_CARD) return false;
    if (!s_TutorialSerial[playerid][0]) return true;
    new body[384];
    format(body, sizeof(body), "{68C83B}LOS SANTOS ID CARD\n\n{FFFFFF}Ho ten: %s\nMa nhan vat: %d\nSerial: %s\nNgay sinh: %02d/%02d/%d\nGioi tinh: %s\nNoi sinh: %s\n\nGiay to nay la dinh danh ca nhan va khong the chuyen nhuong.", s_CharacterName[playerid], GetPlayerCharacterID(playerid), s_TutorialSerial[playerid], s_CharacterBirthDay[playerid], s_CharacterBirthMonth[playerid], s_CharacterBirthYear[playerid], s_CharacterGender[playerid] == 0 ? "Nam" : "Nu", g_BirthPlaceNames[s_CharacterBirthPlace[playerid]]);
    ShowPlayerDialog(playerid, DIALOG_TUTORIAL_IDCARD, DIALOG_STYLE_MSGBOX, "ID Card", body, "Dong", "");
    return true;
}
public Tutorial_OnLoaded(playerid, characterID)
{
    if (!IsPlayerConnected(playerid) || GetPlayerCharacterID(playerid) != characterID) return 1;
    s_TutorialStage[playerid] = 0; s_TutorialSerial[playerid][0] = 0; s_TutorialBank[playerid][0] = 0;
    s_TutorialNewCharacter[playerid] = !cache_num_rows();
    if (!s_TutorialNewCharacter[playerid]) { cache_get_value_name_int(0, "stage", s_TutorialStage[playerid]); cache_get_value_name(0, "id_serial", s_TutorialSerial[playerid], 24); cache_get_value_name(0, "bank_account", s_TutorialBank[playerid], 24); }
    s_TutorialLoaded[playerid] = true;
    Tutorial_ApplyAfterSpawn(playerid);
    return 1;
}
stock Tutorial_OnBobcatPurchased(playerid, model)
{
    if (s_TutorialStage[playerid] != 0 || model != 422) return 1;
    s_TutorialStage[playerid] = 1; Tutorial_Save(playerid); Tutorial_SetCheckpoint(playerid);
    SendClientMessage(playerid, 0x68C83BFF, "Tutorial: Da mua Bobcat. Hay den City Hall theo checkpoint de dang ky giay to cu tru."); return 1;
}
hook OnGameModeInit()
{
    mysql_tquery(g_DatabaseHandle, "CREATE TABLE IF NOT EXISTS `character_tutorial` (`character_id` INT UNSIGNED NOT NULL,`stage` TINYINT UNSIGNED NOT NULL DEFAULT 0,`id_serial` VARCHAR(24) NOT NULL DEFAULT '',`bank_account` VARCHAR(24) NOT NULL DEFAULT '',`starter_granted` TINYINT UNSIGNED NOT NULL DEFAULT 0,PRIMARY KEY (`character_id`),UNIQUE KEY `uq_id` (`id_serial`),UNIQUE KEY `uq_bank` (`bank_account`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    CreatePickup(1239, 1, TUTORIAL_CITYHALL_X, TUTORIAL_CITYHALL_Y, TUTORIAL_CITYHALL_Z, 0); Create3DTextLabel("{68C83B}CITY HALL\n{FFFFFF}Bam Y de dang ky ID Card ($30)", COLOR_WHITE, TUTORIAL_CITYHALL_X, TUTORIAL_CITYHALL_Y, TUTORIAL_CITYHALL_Z + 0.7, 12.0, 0, false);
    CreatePickup(1239, 1, TUTORIAL_BANK_X, TUTORIAL_BANK_Y, TUTORIAL_BANK_Z, 0); Create3DTextLabel("{68C83B}LS BANK\n{FFFFFF}Bam Y de mo tai khoan ($30)", COLOR_WHITE, TUTORIAL_BANK_X, TUTORIAL_BANK_Y, TUTORIAL_BANK_Z + 0.7, 12.0, 0, false); return 1;
}
stock Tutorial_LoadForCharacter(playerid)
{
    if (!IsPlayerConnected(playerid) || !IsPlayerCharacterLoaded(playerid))
    {
        return 0;
    }

    s_TutorialLoaded[playerid] = false;
    s_TutorialCharacterReady[playerid] = false;
    s_TutorialApplied[playerid] = false;
    s_TutorialNewCharacter[playerid] = false;
    new query[160]; mysql_format(g_DatabaseHandle, query, sizeof(query), "SELECT `stage`,`id_serial`,`bank_account` FROM `character_tutorial` WHERE `character_id`=%d LIMIT 1", GetPlayerCharacterID(playerid)); mysql_tquery(g_DatabaseHandle, query, "Tutorial_OnLoaded", "dd", playerid, GetPlayerCharacterID(playerid)); return 1;
}
hook OnPlayerConnect(playerid)
{
    s_TutorialStage[playerid] = 0;
    s_TutorialSerial[playerid][0] = 0;
    s_TutorialBank[playerid][0] = 0;
    s_TutorialLoaded[playerid] = false;
    s_TutorialCharacterReady[playerid] = false;
    s_TutorialApplied[playerid] = false;
    s_TutorialNewCharacter[playerid] = false;
    return 1;
}
hook OnPlayerEnterCheckpoint(playerid)
{
    if (s_TutorialStage[playerid] == 1 && IsPlayerInRangeOfPoint(playerid, 5.0, TUTORIAL_CITYHALL_X, TUTORIAL_CITYHALL_Y, TUTORIAL_CITYHALL_Z))
    {
        DisablePlayerCheckpoint(playerid);
        SendClientMessage(playerid, 0x68C83BFF, "Tutorial [2/4]: Ban da den City Hall. Bam Y gan quay de dang ky ID Card ($30).");
        return 1;
    }
    if (s_TutorialStage[playerid] == 2 && IsPlayerInRangeOfPoint(playerid, 5.0, TUTORIAL_BANK_X, TUTORIAL_BANK_Y, TUTORIAL_BANK_Z))
    {
        DisablePlayerCheckpoint(playerid);
        SendClientMessage(playerid, 0x68C83BFF, "Tutorial [3/4]: Ban da den LS Bank. Bam Y gan quay de mo tai khoan ($30).");
    }
    return 1;
}
hook OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys)
{
    #pragma unused oldkeys
    if (!(newkeys & KEY_YES) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT) return 1;
    if (s_TutorialStage[playerid] == 1 && IsPlayerInRangeOfPoint(playerid, 3.0, TUTORIAL_CITYHALL_X, TUTORIAL_CITYHALL_Y, TUTORIAL_CITYHALL_Z))
    {
        ShowPlayerDialog(playerid, DIALOG_TUTORIAL_IDCARD_REGISTER, DIALOG_STYLE_MSGBOX, "Dang ky ID Card", "Phi dang ky ID Card: {68C83B}$30\n\nBan co muon thanh toan va dang ky khong?", "Dang ky", "Dong");
        return 1;
    }
    if (s_TutorialStage[playerid] == 2 && IsPlayerInRangeOfPoint(playerid, 3.0, TUTORIAL_BANK_X, TUTORIAL_BANK_Y, TUTORIAL_BANK_Z))
    {
        ShowPlayerDialog(playerid, DIALOG_TUTORIAL_BANK_REGISTER, DIALOG_STYLE_MSGBOX, "Mo tai khoan ngan hang", "Phi mo tai khoan: {68C83B}$30\n\nBan co muon thanh toan va dang ky khong?", "Dang ky", "Dong");
        return 1;
    }
    return 1;
}
hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    #pragma unused listitem
    #pragma unused inputtext
    if (dialogid == DIALOG_TUTORIAL_IDCARD_REGISTER)
    {
        if (!response) return 1;
        if (s_TutorialStage[playerid] != 1 || !IsPlayerInRangeOfPoint(playerid, 3.0, TUTORIAL_CITYHALL_X, TUTORIAL_CITYHALL_Y, TUTORIAL_CITYHALL_Z)) return SendClientMessage(playerid, COLOR_RED, "Ban phai dung tai quay City Hall de dang ky.");
        if (GetPlayerMoney(playerid) < TUTORIAL_IDCARD_FEE) return SendClientMessage(playerid, COLOR_RED, "Ban khong du $30 tien mat de dang ky ID Card.");
        GivePlayerMoney(playerid, -TUTORIAL_IDCARD_FEE); Economy_SaveBalances(playerid); Economy_LogTransaction(playerid, "idcard_registration", -TUTORIAL_IDCARD_FEE, 0, "City Hall ID Card registration");
        format(s_TutorialSerial[playerid], 24, "LSID-%06d-%04d", GetPlayerCharacterID(playerid), GetPlayerCharacterID(playerid) * 37 % 10000);
        if (!Tutorial_HasIDCard(playerid)) Inventory_AddItem(playerid, ITEM_ID_CARD, 1);
        s_TutorialStage[playerid] = 2; Tutorial_Save(playerid); Tutorial_SetCheckpoint(playerid); SendClientMessage(playerid, 0x68C83BFF, "Da cap ID Card. Hay den LS Bank theo checkpoint de dang ky tai khoan ngan hang.");
        return 1;
    }
    if (dialogid == DIALOG_TUTORIAL_BANK_REGISTER)
    {
        if (!response) return 1;
        if (s_TutorialStage[playerid] != 2 || !IsPlayerInRangeOfPoint(playerid, 3.0, TUTORIAL_BANK_X, TUTORIAL_BANK_Y, TUTORIAL_BANK_Z)) return SendClientMessage(playerid, COLOR_RED, "Ban phai dung tai quay LS Bank de dang ky.");
        if (!Tutorial_HasIDCard(playerid)) return SendClientMessage(playerid, COLOR_RED, "Ban can ID Card trong tui do de mo tai khoan ngan hang.");
        if (GetPlayerMoney(playerid) < TUTORIAL_BANK_FEE) return SendClientMessage(playerid, COLOR_RED, "Ban khong du $30 tien mat de mo tai khoan.");
        GivePlayerMoney(playerid, -TUTORIAL_BANK_FEE); Economy_SaveBalances(playerid); Economy_LogTransaction(playerid, "bank_registration", -TUTORIAL_BANK_FEE, 0, "LS Bank account registration");
        if (!Phone_HasItem(playerid)) Inventory_AddItem(playerid, ITEM_PHONE, 1);
        format(s_TutorialBank[playerid], 24, "LS-%08d", GetPlayerCharacterID(playerid)); s_TutorialStage[playerid] = 3; Tutorial_Save(playerid); Tutorial_SetCheckpoint(playerid); new msg[128]; format(msg, sizeof(msg), "Tutorial hoan tat. STK cua ban: %s. Hay dung /job de bat dau tim viec.", s_TutorialBank[playerid]); SendClientMessage(playerid, 0x68C83BFF, msg);
        SendClientMessage(playerid, 0x68C83BFF, "Ban da duoc cap mot dien thoai. Mo tui do va su dung vat pham Phone de bat dau.");
        return 1;
    }
    return 0;
}
