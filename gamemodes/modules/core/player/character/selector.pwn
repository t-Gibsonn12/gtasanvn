#include <YSI_Coding\y_hooks>

//-----------------------------------------------------------------------------
// LS:RP Character Selector - Dialog Edition
//-----------------------------------------------------------------------------
//
// The slot list uses a wide room camera without a preview model. Selecting a
// slot creates a static actor and smoothly zooms the camera toward it.
//-----------------------------------------------------------------------------

#define SELECTOR_INTERIOR       (3)
#define SELECTOR_WORLD_BASE     (15000)
#define SELECTOR_CENTER_X       (2496.0549)
#define SELECTOR_CENTER_Y       (-1693.6500)
#define SELECTOR_CENTER_Z       (1014.7422)
#define SELECTOR_CAMERA_X       (2496.0549)
#define SELECTOR_CAMERA_Y       (-1696.6000)
#define SELECTOR_CAMERA_Z       (1015.5500)
#define SELECTOR_CAMERA_FAR_Y   (-1700.2000)
#define SELECTOR_CAMERA_FAR_Z   (1016.0500)
#define SELECTOR_ZOOM_TIME      (700)

new s_SelectorPreviewSlot[MAX_PLAYERS];
new s_SelectorWalkTimer[MAX_PLAYERS];
new s_SelectorActor[MAX_PLAYERS];
new bool:s_SelectorWalkingOut[MAX_PLAYERS];

forward CharacterSelector_FinishWalk(playerid);
forward CharacterSelector_FinishZoom(playerid);
forward CharacterSelector_OnInfoLoaded(playerid, characterID, slot);
forward CharacterSelector_ApplyRoomCameraDelayed(playerid);

stock CharacterSelector_RequestFullInfo(playerid, slot)
{
    if (slot < 0 || slot >= MAX_CHARACTER_SLOTS ||
        s_CharacterSlotID[playerid][slot] == INVALID_CHARACTER_ID)
    {
        return CharacterSelector_ShowActions(playerid);
    }

    new query[768];
    mysql_format(
        g_DatabaseHandle,
        query,
        sizeof(query),
        "SELECT `character_id`,`slot`,`name`,`character_created`,`gender`,`birth_day`,`birth_month`,`birth_year`,`skin_tone`,`skin`,`voice`,`height_cm`,`weight_kg`,`birth_place`,`personality`,`cash`,`bank`,`level`,`job`,`job_hired_at`,`job_salary`,`job_allowance`,`health`,`armour`,`pos_x`,`pos_y`,`pos_z`,`pos_a`,`interior_id`,`virtual_world`,DATE_FORMAT(`created_at`,'%%d/%%m/%%Y %%H:%%i') AS `created_text`,COALESCE(DATE_FORMAT(`last_played`,'%%d/%%m/%%Y %%H:%%i'),'Chua tham gia') AS `last_played_text` FROM `player_characters` WHERE `character_id`=%d AND `account_id`=%d LIMIT 1",
        s_CharacterSlotID[playerid][slot],
        GetPlayerAccountID(playerid)
    );
    mysql_tquery(
        g_DatabaseHandle,
        query,
        "CharacterSelector_OnInfoLoaded",
        "ddd",
        playerid,
        s_CharacterSlotID[playerid][slot],
        slot
    );
    SendClientMessage(playerid, COLOR_WHITE, "Dang tai toan bo thong tin ho so nhan vat, vui long cho trong giay lat.");
    return 1;
}

public CharacterSelector_OnInfoLoaded(playerid, characterID, slot)
{
    if (!IsPlayerConnected(playerid) ||
        slot != s_SelectorPreviewSlot[playerid] ||
        slot < 0 ||
        slot >= MAX_CHARACTER_SLOTS ||
        s_CharacterSlotID[playerid][slot] != characterID)
    {
        return 1;
    }
    if (cache_num_rows() == 0)
    {
        SendClientMessage(playerid, COLOR_RED, "Khong the tai ho so nhan vat nay. Du lieu co the da thay doi, hay quay lai danh sach va thu lai.");
        return CharacterSelector_ShowActions(playerid);
    }

    new name[CHARACTER_NAME_LENGTH], personality[CHARACTER_PERSONALITY_LENGTH];
    new createdText[24], lastPlayedText[24];
    new gender, birthDay, birthMonth, birthYear, skinTone, skin, voice;
    new height, weight, birthPlace, cash, bank, level, job;
    new jobSalary, jobAllowance, interior, world;
    new Float:health, Float:armour, Float:x, Float:y, Float:z, Float:a;

    cache_get_value_name(0, "name", name);
    cache_get_value_name(0, "personality", personality);
    cache_get_value_name(0, "created_text", createdText);
    cache_get_value_name(0, "last_played_text", lastPlayedText);
    cache_get_value_name_int(0, "gender", gender);
    cache_get_value_name_int(0, "birth_day", birthDay);
    cache_get_value_name_int(0, "birth_month", birthMonth);
    cache_get_value_name_int(0, "birth_year", birthYear);
    cache_get_value_name_int(0, "skin_tone", skinTone);
    cache_get_value_name_int(0, "skin", skin);
    cache_get_value_name_int(0, "voice", voice);
    cache_get_value_name_int(0, "height_cm", height);
    cache_get_value_name_int(0, "weight_kg", weight);
    cache_get_value_name_int(0, "birth_place", birthPlace);
    cache_get_value_name_int(0, "cash", cash);
    cache_get_value_name_int(0, "bank", bank);
    cache_get_value_name_int(0, "level", level);
    cache_get_value_name_int(0, "job", job);
    cache_get_value_name_int(0, "job_salary", jobSalary);
    cache_get_value_name_int(0, "job_allowance", jobAllowance);
    cache_get_value_name_int(0, "interior_id", interior);
    cache_get_value_name_int(0, "virtual_world", world);
    cache_get_value_name_float(0, "health", health);
    cache_get_value_name_float(0, "armour", armour);
    cache_get_value_name_float(0, "pos_x", x);
    cache_get_value_name_float(0, "pos_y", y);
    cache_get_value_name_float(0, "pos_z", z);
    cache_get_value_name_float(0, "pos_a", a);

    if (skinTone < 0 || skinTone >= sizeof(g_SkinToneNames)) skinTone = 1;
    if (voice < 0 || voice >= sizeof(g_VoiceNames)) voice = 0;
    if (birthPlace < 0 || birthPlace >= sizeof(g_BirthPlaceNames)) birthPlace = 0;

    new genderName[8], jobName[24];
    format(genderName, sizeof(genderName), gender == 0 ? "Nam" : "Nu");
    switch (job)
    {
        case 1: format(jobName, sizeof(jobName), "Giao pizza");
        default: format(jobName, sizeof(jobName), "Chua co nghe nghiep");
    }

    new title[72], body[1800];
    format(title, sizeof(title), "Ho so day du - %s", name);
    format(
        body,
        sizeof(body),
        "{68C83B}THONG TIN CO BAN\n{FFFFFF}ID nhan vat: %d\nSlot: %d/3\nTen nhan vat: %s\nGioi tinh: %s\nNgay sinh: %02d/%02d/%d\nTuoi: %d\nNoi sinh: %s\nTinh cach: %s\n\n{68C83B}NGOAI HINH\n{FFFFFF}Ngoai hinh/Skin: %d\nMau da: %s\nGiong noi: %s\nChieu cao: %d cm\nCan nang: %d kg\nSuc khoe: %.1f\nGiap: %.1f\n\n{68C83B}TAI CHINH VA TIEN TRINH\n{FFFFFF}Cap do: %d\nTien mat: $%d\nNgan hang: $%d\nNghe nghiep: %s\nLuong: $%d\nPhu cap: $%d\n\n{68C83B}VI TRI CUOI CUNG\n{FFFFFF}X: %.4f\nY: %.4f\nZ: %.4f\nGoc quay: %.4f\nInterior: %d\nVirtual World: %d\n\n{68C83B}HO SO HE THONG\n{FFFFFF}Ngay tao: %s\nLan choi cuoi: %s",
        characterID, slot + 1, name, genderName,
        birthDay, birthMonth, birthYear,
        birthYear > 0 ? GAME_CONTEXT_YEAR - birthYear : 0,
        g_BirthPlaceNames[birthPlace],
        personality[0] ? personality : "Chua co mo ta tinh cach",
        skin, g_SkinToneNames[skinTone], g_VoiceNames[voice],
        height, weight, health, armour,
        level, cash, bank, jobName, jobSalary, jobAllowance,
        x, y, z, a, interior, world, createdText, lastPlayedText
    );
    ShowPlayerDialog(
        playerid,
        DIALOG_CHARACTER_SELECTOR_INFO,
        DIALOG_STYLE_MSGBOX,
        title,
        body,
        "Quay lai",
        ""
    );
    return 1;
}

stock CharacterSelector_ApplyRoomCamera(playerid)
{
    SetPlayerInterior(playerid, SELECTOR_INTERIOR);
    SetPlayerVirtualWorld(playerid, SELECTOR_WORLD_BASE + playerid);
    // Interior streaming follows the player's actual position, not only the
    // camera. This must run during login too: spectate state is not always
    // updated yet on the same OnPlayerConnect tick.
    SetPlayerPos(playerid, SELECTOR_CENTER_X, SELECTOR_CENTER_Y, SELECTOR_CENTER_Z);
    SetPlayerCameraPos(playerid, SELECTOR_CAMERA_X, SELECTOR_CAMERA_FAR_Y, SELECTOR_CAMERA_FAR_Z);
    SetPlayerCameraLookAt(playerid, SELECTOR_CENTER_X, SELECTOR_CENTER_Y, SELECTOR_CENTER_Z + 0.60, CAMERA_CUT);
    // Some SA-MP clients reset the camera once more immediately after connect.
    // Re-apply after the client has entered spectate mode so login/register
    // always streams the interior room instead of the blue void.
    SetTimerEx("CharacterSelector_ApplyRoomCameraDelayed", 250, false, "d", playerid);
    return 1;
}

public CharacterSelector_ApplyRoomCameraDelayed(playerid)
{
    if (!IsPlayerConnected(playerid) || IsPlayerLoggedIn(playerid))
    {
        return 0;
    }

    SetPlayerInterior(playerid, SELECTOR_INTERIOR);
    SetPlayerVirtualWorld(playerid, SELECTOR_WORLD_BASE + playerid);
    SetPlayerPos(playerid, SELECTOR_CENTER_X, SELECTOR_CENTER_Y, SELECTOR_CENTER_Z);
    SetPlayerCameraPos(playerid, SELECTOR_CAMERA_X, SELECTOR_CAMERA_FAR_Y, SELECTOR_CAMERA_FAR_Z);
    SetPlayerCameraLookAt(playerid, SELECTOR_CENTER_X, SELECTOR_CENTER_Y, SELECTOR_CENTER_Z + 0.60, CAMERA_CUT);
    return 1;
}

CharacterSelector_OpenUI(playerid)
{
    if (!IsPlayerConnected(playerid) || !IsPlayerLoggedIn(playerid))
    {
        return 0;
    }

    TogglePlayerSpectating(playerid, true);
    CharacterSelector_ApplyRoomCamera(playerid);
    Character_ShowSelectionDialog(playerid);
    return 1;
}

stock CharacterSelector_SelectSlot(playerid, slot)
{
    if (slot < 0 || slot >= MAX_CHARACTER_SLOTS || s_SelectorWalkTimer[playerid])
    {
        return 0;
    }

    s_SelectorPreviewSlot[playerid] = slot;
    s_SelectorWalkingOut[playerid] = false;
    new skin = s_CharacterSlotSkin[playerid][slot];
    if (s_CharacterSlotID[playerid][slot] == INVALID_CHARACTER_ID || skin <= 0)
    {
        skin = 21;
    }

    if (s_SelectorActor[playerid] != INVALID_ACTOR_ID &&
        IsValidActor(s_SelectorActor[playerid]))
    {
        DestroyActor(s_SelectorActor[playerid]);
    }

    s_SelectorActor[playerid] =
        CreateActor(skin, SELECTOR_CENTER_X, SELECTOR_CENTER_Y, SELECTOR_CENTER_Z, 180.0);
    if (s_SelectorActor[playerid] == INVALID_ACTOR_ID)
    {
        Character_ShowSelectionDialog(playerid);
        return 0;
    }
    SetActorVirtualWorld(
        s_SelectorActor[playerid],
        SELECTOR_WORLD_BASE + playerid
    );
    CharacterSelector_ApplyRoomCamera(playerid);
    InterpolateCameraPos(
        playerid,
        SELECTOR_CAMERA_X, SELECTOR_CAMERA_FAR_Y, SELECTOR_CAMERA_FAR_Z,
        SELECTOR_CAMERA_X, SELECTOR_CAMERA_Y, SELECTOR_CAMERA_Z,
        SELECTOR_ZOOM_TIME,
        CAMERA_MOVE
    );
    s_SelectorWalkTimer[playerid] =
        SetTimerEx("CharacterSelector_FinishZoom", SELECTOR_ZOOM_TIME + 20, false, "d", playerid);
    return 1;
}

stock CharacterSelector_ShowActions(playerid)
{
    new const slot = s_SelectorPreviewSlot[playerid];
    new title[64];
    format(title, sizeof(title), "Slot %d - %s", slot + 1, s_CharacterSlotName[playerid][slot]);
    ShowPlayerDialog(
        playerid,
        DIALOG_CHARACTER_SELECTOR_ACTIONS,
        DIALOG_STYLE_LIST,
        title,
        "Tham gia\nThong tin\nXoa nhan vat\nQuay lai",
        "Chon",
        "Quay lai"
    );
    return 1;
}

stock CharacterSelector_WalkOut(playerid)
{
    if (s_SelectorWalkTimer[playerid])
    {
        return 0;
    }
    s_SelectorWalkingOut[playerid] = true;
    if (s_SelectorActor[playerid] != INVALID_ACTOR_ID &&
        IsValidActor(s_SelectorActor[playerid]))
    {
        DestroyActor(s_SelectorActor[playerid]);
    }
    s_SelectorActor[playerid] = INVALID_ACTOR_ID;
    InterpolateCameraPos(
        playerid,
        SELECTOR_CAMERA_X, SELECTOR_CAMERA_Y, SELECTOR_CAMERA_Z,
        SELECTOR_CAMERA_X, SELECTOR_CAMERA_FAR_Y, SELECTOR_CAMERA_FAR_Z,
        SELECTOR_ZOOM_TIME,
        CAMERA_MOVE
    );
    s_SelectorWalkTimer[playerid] =
        SetTimerEx("CharacterSelector_FinishWalk", SELECTOR_ZOOM_TIME + 20, false, "d", playerid);
    return 1;
}

public CharacterSelector_FinishWalk(playerid)
{
    s_SelectorWalkTimer[playerid] = 0;
    if (!IsPlayerConnected(playerid))
    {
        return 1;
    }

    if (s_SelectorWalkingOut[playerid])
    {
        s_SelectorWalkingOut[playerid] = false;
        CharacterSelector_ApplyRoomCamera(playerid);
        Character_ShowSelectionDialog(playerid);
        return 1;
    }
    return 1;
}

public CharacterSelector_FinishZoom(playerid)
{
    s_SelectorWalkTimer[playerid] = 0;
    if (!IsPlayerConnected(playerid))
    {
        return 1;
    }
    new const slot = s_SelectorPreviewSlot[playerid];
    if (s_CharacterSlotID[playerid][slot] == INVALID_CHARACTER_ID)
    {
        if (s_SelectorActor[playerid] != INVALID_ACTOR_ID &&
            IsValidActor(s_SelectorActor[playerid]))
        {
            DestroyActor(s_SelectorActor[playerid]);
            s_SelectorActor[playerid] = INVALID_ACTOR_ID;
        }
        format(
            s_PendingCharacterName[playerid],
            CHARACTER_NAME_LENGTH,
            "TMP%d_%d",
            GetPlayerAccountID(playerid),
            slot + 1
        );
        s_SelectedCharacterSlot[playerid] = slot + 1;
        Character_Create(playerid);
        return 1;
    }

    CharacterSelector_ShowActions(playerid);
    return 1;
}

CharacterSelector_CloseUI(playerid)
{
    if (s_SelectorActor[playerid] != INVALID_ACTOR_ID &&
        IsValidActor(s_SelectorActor[playerid]))
    {
        DestroyActor(s_SelectorActor[playerid]);
        s_SelectorActor[playerid] = INVALID_ACTOR_ID;
    }
    // Cinematic_StartSpawn calls this after the character has finished loading.
    // Clear authentication / selection chat right before gameplay begins.
    Character_ClearChat(playerid);
    return 1;
}

hook OnPlayerConnect(playerid)
{
    s_SelectedCharacterSlot[playerid] = 0;
    s_SelectorPreviewSlot[playerid] = -1;
    s_SelectorWalkTimer[playerid] = 0;
    s_SelectorActor[playerid] = INVALID_ACTOR_ID;
    s_SelectorWalkingOut[playerid] = false;
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    if (s_SelectorWalkTimer[playerid])
    {
        KillTimer(s_SelectorWalkTimer[playerid]);
        s_SelectorWalkTimer[playerid] = 0;
    }
    if (s_SelectorActor[playerid] != INVALID_ACTOR_ID &&
        IsValidActor(s_SelectorActor[playerid]))
    {
        DestroyActor(s_SelectorActor[playerid]);
        s_SelectorActor[playerid] = INVALID_ACTOR_ID;
    }
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    #pragma unused inputtext

    if (dialogid == DIALOG_CHARACTER_SELECTOR_ACTIONS)
    {
        if (!response)
        {
            CharacterSelector_WalkOut(playerid);
            return 1;
        }

        new const slot = s_SelectorPreviewSlot[playerid];
        switch (listitem)
        {
            case 0:
            {
                Character_LoadByID(playerid, s_CharacterSlotID[playerid][slot]);
            }
            case 1:
            {
                CharacterSelector_RequestFullInfo(playerid, slot);
            }
            case 2:
            {
                ShowPlayerDialog(playerid, DIALOG_CHARACTER_SELECTOR_DELETE, DIALOG_STYLE_MSGBOX, "Xoa nhan vat", "Ban chac chan muon xoa vinh vien nhan vat nay?", "Xoa", "Huy");
            }
            default:
            {
                CharacterSelector_WalkOut(playerid);
            }
        }
        return 1;
    }

    if (dialogid == DIALOG_CHARACTER_SELECTOR_INFO)
    {
        CharacterSelector_ShowActions(playerid);
        return 1;
    }

    if (dialogid == DIALOG_CHARACTER_SELECTOR_DELETE)
    {
        if (!response)
        {
            CharacterSelector_ShowActions(playerid);
            return 1;
        }

        new const slot = s_SelectorPreviewSlot[playerid];
        new query[192];
        mysql_format(
            g_DatabaseHandle,
            query,
            sizeof(query),
            "DELETE FROM `player_characters` WHERE `character_id`=%d AND `account_id`=%d LIMIT 1",
            s_CharacterSlotID[playerid][slot],
            GetPlayerAccountID(playerid)
        );
        mysql_tquery(g_DatabaseHandle, query);
        s_CharacterSlotID[playerid][slot] = INVALID_CHARACTER_ID;
        s_CharacterSlotName[playerid][slot][0] = 0;
        s_CharacterSlotLevel[playerid][slot] = 0;
        s_CharacterSlotSkin[playerid][slot] = 0;
        CharacterSelector_WalkOut(playerid);
        return 1;
    }
    return 0;
}
