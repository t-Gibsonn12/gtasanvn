#include <YSI_Coding\y_hooks>

//-----------------------------------------------------------------------------
// LS:RP Character Creator - Dialog Edition
//-----------------------------------------------------------------------------

#define CREATOR_INTERIOR             (3)
#define CREATOR_WORLD_BASE           (15000)

// Johnson House is only used as a private preview room while editing the profile.
#define CREATOR_POS_X                (2496.0549)
#define CREATOR_POS_Y                (-1693.6500)
#define CREATOR_POS_Z                (1014.7422)
#define CREATOR_POS_A                (180.0)

#define CREATOR_CAMERA_X             (2496.0549)
#define CREATOR_CAMERA_Y             (-1696.6000)
#define CREATOR_CAMERA_Z             (1015.5500)

#define CREATOR_CAMERA_LOOK_X        (2496.0549)
#define CREATOR_CAMERA_LOOK_Y        (-1693.6500)
#define CREATOR_CAMERA_LOOK_Z        (1015.3500)

#define CREATOR_SKINS_PER_GROUP      (6)

// First completed-character spawn: LS Taxi HQ / Unity Station area.
#define TAXI_HQ_SPAWN_X              (1813.3513)
#define TAXI_HQ_SPAWN_Y              (-1873.2487)
#define TAXI_HQ_SPAWN_Z              (13.5704)
#define TAXI_HQ_SPAWN_A              (276.3542)

//-----------------------------------------------------------------------------
// Character profile definitions
//-----------------------------------------------------------------------------

new const g_CreatorSkins[2][3][CREATOR_SKINS_PER_GROUP] =
{
    {
        {20, 46, 98, 147, 186, 187},
        {28, 29, 47, 48, 60, 120},
        {7, 21, 22, 25, 26, 67}
    },
    {
        {12, 40, 41, 55, 56, 91},
        {13, 69, 76, 89, 138, 139},
        {9, 10, 11, 63, 64, 190}
    }
};

new const g_SkinToneNames[][] =
{
    "Sang",
    "Trung binh",
    "Toi"
};

new const g_CreatorAppearanceNames[][] =
{
    "Ao khoac denim", "Ao thun duong pho", "Ao so mi co dien",
    "Trang phuc gangs", "Ao khoac bomber", "Trang phuc casual"
};

new const g_BirthPlaceNames[][] =
{
    "Los Santos",
    "San Fierro",
    "Las Venturas",
    "Noi khac"
};

new const g_VoiceNames[][] =
{
    "American",
    "Mexican",
    "African-American",
    "Southern"
};

new
    bool:s_CreatorActive[MAX_PLAYERS],
    bool:s_CreatorSaving[MAX_PLAYERS],
    s_CreatorSkinIndex[MAX_PLAYERS];

forward public OnCharacterCreatorSaved(playerid);

//-----------------------------------------------------------------------------
// Shared chat cleanup
//-----------------------------------------------------------------------------

Character_ClearChat(playerid)
{
    for (new line = 0; line < 30; line++)
    {
        SendClientMessage(playerid, COLOR_WHITE, " ");
    }
    return 1;
}

//-----------------------------------------------------------------------------
// Validation / profile helpers
//-----------------------------------------------------------------------------

stock bool:Creator_IsLeapYear(year)
{
    if ((year % 400) == 0) return true;
    if ((year % 100) == 0) return false;
    return (year % 4) == 0;
}

stock Creator_GetDaysInMonth(month, year)
{
    switch (month)
    {
        case 2:
        {
            return Creator_IsLeapYear(year) ? 29 : 28;
        }
        case 4, 6, 9, 11:
        {
            return 30;
        }
    }
    return 31;
}

stock Creator_ClampBirthDay(playerid)
{
    new const maxDay = Creator_GetDaysInMonth(
        s_CharacterBirthMonth[playerid],
        s_CharacterBirthYear[playerid]
    );

    if (s_CharacterBirthDay[playerid] < 1)
    {
        s_CharacterBirthDay[playerid] = 1;
    }
    else if (s_CharacterBirthDay[playerid] > maxDay)
    {
        s_CharacterBirthDay[playerid] = maxDay;
    }
    return 1;
}

stock Creator_FindSkinIndex(playerid)
{
    new const gender = s_CharacterGender[playerid];
    new const tone = s_CharacterSkinTone[playerid];

    for (new index = 0; index < CREATOR_SKINS_PER_GROUP; index++)
    {
        if (g_CreatorSkins[gender][tone][index] == s_CharacterSkin[playerid])
        {
            return index;
        }
    }
    return 0;
}

stock Creator_ApplySkin(playerid)
{
    s_CharacterSkin[playerid] =
        g_CreatorSkins
        [s_CharacterGender[playerid]]
        [s_CharacterSkinTone[playerid]]
        [s_CreatorSkinIndex[playerid]];

    if (IsPlayerConnected(playerid))
    {
        SetPlayerSkin(playerid, s_CharacterSkin[playerid]);
        ApplyAnimation(
            playerid,
            "PED",
            "WALK_player",
            4.1,
            false,
            true,
            true,
            true,
            0,
            SYNC_ALL
        );
    }
    return 1;
}

stock Creator_NormalizeProfile(playerid)
{
    if (s_CharacterGender[playerid] < 0 ||
        s_CharacterGender[playerid] > 1)
    {
        s_CharacterGender[playerid] = 0;
    }

    if (s_CharacterBirthYear[playerid] == 0)
    {
        s_CharacterBirthDay[playerid] = 0;
        s_CharacterBirthMonth[playerid] = 0;
    }
    else if (s_CharacterBirthMonth[playerid] < 1 ||
        s_CharacterBirthMonth[playerid] > 12)
    {
        s_CharacterBirthMonth[playerid] = 1;
    }

    if (s_CharacterBirthYear[playerid] != 0 && (s_CharacterBirthYear[playerid] < CHARACTER_MIN_BIRTH_YEAR ||
        s_CharacterBirthYear[playerid] > CHARACTER_MAX_BIRTH_YEAR))
    {
        s_CharacterBirthYear[playerid] = 0;
    }

    if (s_CharacterSkinTone[playerid] < 0 ||
        s_CharacterSkinTone[playerid] > 2)
    {
        s_CharacterSkinTone[playerid] = 1;
    }

    if (s_CharacterVoice[playerid] < 0 ||
        s_CharacterVoice[playerid] > 3)
    {
        s_CharacterVoice[playerid] = 0;
    }

    if (s_CharacterHeight[playerid] < 150 ||
        s_CharacterHeight[playerid] > 210)
    {
        s_CharacterHeight[playerid] = 175;
    }

    if (s_CharacterWeight[playerid] < 45 ||
        s_CharacterWeight[playerid] > 150)
    {
        s_CharacterWeight[playerid] = 70;
    }

    if (s_CharacterBirthPlace[playerid] < 0 ||
        s_CharacterBirthPlace[playerid] > 3)
    {
        s_CharacterBirthPlace[playerid] = 0;
    }

    Creator_ClampBirthDay(playerid);
    s_CreatorSkinIndex[playerid] = Creator_FindSkinIndex(playerid);
    Creator_ApplySkin(playerid);
    return 1;
}

stock Creator_GetGenderName(playerid, output[], size)
{
    if (s_CharacterGender[playerid] == 0)
    {
        format(output, size, "Nam");
    }
    else
    {
        format(output, size, "Nu");
    }
    return 1;
}

stock Creator_GetVoiceName(playerid, output[], size)
{
    format(output, size, "%s", g_VoiceNames[s_CharacterVoice[playerid]]);
    return 1;
}

stock bool:Creator_ParseBirthDate(
    const input[],
    &day,
    &month,
    &year
)
{
    new const firstSlash = strfind(input, "/");
    if (firstSlash <= 0)
    {
        return false;
    }

    new const secondSlash = strfind(
        input,
        "/",
        false,
        firstSlash + 1
    );

    if (secondSlash <= firstSlash + 1)
    {
        return false;
    }

    new part[8];

    strmid(part, input, 0, firstSlash, sizeof(part));
    day = strval(part);

    strmid(
        part,
        input,
        firstSlash + 1,
        secondSlash,
        sizeof(part)
    );
    month = strval(part);

    strmid(
        part,
        input,
        secondSlash + 1,
        strlen(input),
        sizeof(part)
    );
    year = strval(part);

    if (month < 1 || month > 12)
    {
        return false;
    }

    if (year < CHARACTER_MIN_BIRTH_YEAR ||
        year > CHARACTER_MAX_BIRTH_YEAR)
    {
        return false;
    }

    if (day < 1 || day > Creator_GetDaysInMonth(month, year))
    {
        return false;
    }

    new const age = GAME_CONTEXT_YEAR - year;
    return age >= CHARACTER_MIN_AGE && age <= CHARACTER_MAX_AGE;
}

//-----------------------------------------------------------------------------
// Dialog rendering
//-----------------------------------------------------------------------------

Creator_ShowMainDialog(playerid)
{
    if (!s_CreatorActive[playerid])
    {
        return 0;
    }

    new genderName[8];
    new voiceName[24];

    Creator_GetGenderName(playerid, genderName, sizeof(genderName));
    Creator_GetVoiceName(playerid, voiceName, sizeof(voiceName));

    new birthText[32], ageText[48], body[768];
    if (s_CharacterBirthYear[playerid] == 0)
    {
        format(birthText, sizeof(birthText), "Chua chon ngay sinh");
        format(ageText, sizeof(ageText), "Chon ngay/thang/nam sinh cho nhan vat");
    }
    else
    {
        format(birthText, sizeof(birthText), "%02d/%02d/%d", s_CharacterBirthDay[playerid], s_CharacterBirthMonth[playerid], s_CharacterBirthYear[playerid]);
        format(ageText, sizeof(ageText), "%d tuoi", GAME_CONTEXT_YEAR - s_CharacterBirthYear[playerid]);
    }

    format(
        body,
        sizeof(body),
        "Ten nhan vat: %s\nGioi tinh: %s\nNgay sinh: %s\nTuoi: %s\nMau da: %s\nNgoai hinh: %d\nGiong noi: %s\nChieu cao: %d cm\nCan nang: %d kg\nNoi sinh: %s\nTinh cach: %s\n{39A06B}HOAN TAT HO SO",
        s_CharacterName[playerid], genderName, birthText, ageText,
        g_SkinToneNames[s_CharacterSkinTone[playerid]],
        s_CharacterSkin[playerid],
        voiceName,
        s_CharacterHeight[playerid],
        s_CharacterWeight[playerid],
        g_BirthPlaceNames[s_CharacterBirthPlace[playerid]],
        s_CharacterPersonality[playerid][0] ? s_CharacterPersonality[playerid] : "Chua mo ta"
    );

    ShowPlayerDialog(
        playerid,
        DIALOG_CHARACTER_CREATOR,
        DIALOG_STYLE_LIST,
        "LS:RP - Tao ho so nhan vat",
        body,
        "Chinh sua",
        "Dong"
    );
    return 1;
}

Creator_ShowSkinDialog(playerid)
{
    new body[160];

    format(
        body,
        sizeof(body),
        "%s\n%s\n%s\n%s\n%s\n%s",
        g_CreatorAppearanceNames[0], g_CreatorAppearanceNames[1],
        g_CreatorAppearanceNames[2], g_CreatorAppearanceNames[3],
        g_CreatorAppearanceNames[4], g_CreatorAppearanceNames[5]
    );

    ShowPlayerDialog(
        playerid,
        DIALOG_CHARACTER_CREATOR_SKIN,
        DIALOG_STYLE_LIST,
        "Chon ngoai hinh",
        body,
        "Chon",
        "Quay lai"
    );
    return 1;
}

Creator_ShowVoiceDialog(playerid)
{
    new body[128];

    if (s_CharacterGender[playerid] == 0)
    {
        format(
            body,
            sizeof(body),
            "%s\n%s\n%s\n%s",
            g_VoiceNames[0], g_VoiceNames[1], g_VoiceNames[2], g_VoiceNames[3]
        );
    }
    else
    {
        format(
            body,
            sizeof(body),
            "%s\n%s\n%s\n%s",
            g_VoiceNames[0], g_VoiceNames[1], g_VoiceNames[2], g_VoiceNames[3]
        );
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_CHARACTER_CREATOR_VOICE,
        DIALOG_STYLE_LIST,
        "Chon giong noi",
        body,
        "Chon",
        "Quay lai"
    );
    return 1;
}

//-----------------------------------------------------------------------------
// World / Camera
//-----------------------------------------------------------------------------

CharacterCreator_ApplyWorld(playerid)
{
    // Re-assert the fixed creator camera every time the player spawns here.
    // This also cancels any camera movement that was already interpolating.
    Cinematic_StopSelector(playerid);

    SetPlayerInterior(playerid, CREATOR_INTERIOR);
    SetPlayerVirtualWorld(playerid, CREATOR_WORLD_BASE + playerid);

    SetPlayerPos(
        playerid,
        CREATOR_POS_X,
        CREATOR_POS_Y,
        CREATOR_POS_Z
    );

    SetPlayerFacingAngle(playerid, CREATOR_POS_A);
    SetPlayerSkin(playerid, s_CharacterSkin[playerid]);
    ResetPlayerWeapons(playerid);
    TogglePlayerControllable(playerid, false);

    SetPlayerCameraPos(
        playerid,
        CREATOR_CAMERA_X,
        CREATOR_CAMERA_Y,
        CREATOR_CAMERA_Z
    );

    SetPlayerCameraLookAt(
        playerid,
        CREATOR_CAMERA_LOOK_X,
        CREATOR_CAMERA_LOOK_Y,
        CREATOR_CAMERA_LOOK_Z,
        CAMERA_CUT
    );

    Creator_ShowMainDialog(playerid);
    return 1;
}

//-----------------------------------------------------------------------------
// Start / state
//-----------------------------------------------------------------------------

stock bool:CharacterCreator_IsActive(playerid)
{
    return s_CreatorActive[playerid];
}

CharacterCreator_Start(playerid)
{
    if (!IsPlayerCharacterLoaded(playerid))
    {
        return 0;
    }

    // Character creation starts from the selector flow. Stop its camera timer
    // and interpolation before spawning the player into the private creator
    // room, otherwise the selector keeps moving the camera in the background.
    Cinematic_StopSelector(playerid);

    Creator_NormalizeProfile(playerid);

    if (!Character_SetPlayerICName(playerid))
    {
        Kick(playerid);
        return 0;
    }

    s_CreatorActive[playerid] = true;
    s_CreatorSaving[playerid] = false;

    SetSpawnInfo(
        playerid,
        NO_TEAM,
        s_CharacterSkin[playerid],
        CREATOR_POS_X,
        CREATOR_POS_Y,
        CREATOR_POS_Z,
        CREATOR_POS_A
    );

    if (GetPlayerState(playerid) == PLAYER_STATE_SPECTATING)
    {
        TogglePlayerSpectating(playerid, false);
    }
    else
    {
        SpawnPlayer(playerid);
    }

    return 1;
}

//-----------------------------------------------------------------------------
// Save profile + first spawn
//-----------------------------------------------------------------------------

CharacterCreator_Confirm(playerid)
{
    if (!s_CreatorActive[playerid] ||
        s_CreatorSaving[playerid])
    {
        return 0;
    }

    new const age = GetPlayerCharacterAge(playerid);

    if (age < CHARACTER_MIN_AGE || age > CHARACTER_MAX_AGE)
    {
        SendClientMessage(
            playerid,
            COLOR_RED,
            "Do tuoi nhan vat khong hop le."
        );

        Creator_ShowMainDialog(playerid);
        return 0;
    }

    if (!IsValidCharacterName(s_CharacterName[playerid]) ||
        strfind(s_CharacterName[playerid], "TMP", true) == 0 ||
        strlen(s_CharacterPersonality[playerid]) < 3)
    {
        SendClientMessage(playerid, COLOR_RED, "Hay nhap ten va mo ta tinh cach truoc khi hoan tat.");
        Creator_ShowMainDialog(playerid);
        return 0;
    }

    if (!Character_SetPlayerICName(playerid))
    {
        Creator_ShowMainDialog(playerid);
        return 0;
    }

    s_CreatorSaving[playerid] = true;

    // Persist the first gameplay spawn at LS Taxi HQ.
    s_CharacterPosX[playerid] = TAXI_HQ_SPAWN_X;
    s_CharacterPosY[playerid] = TAXI_HQ_SPAWN_Y;
    s_CharacterPosZ[playerid] = TAXI_HQ_SPAWN_Z;
    s_CharacterPosA[playerid] = TAXI_HQ_SPAWN_A;
    s_CharacterInterior[playerid] = 0;
    s_CharacterVirtualWorld[playerid] = 0;

    new query[1280];

    mysql_format(
        g_DatabaseHandle,
        query,
        sizeof(query),
        "UPDATE `player_characters` SET `name`='%e',`character_created`=1,`gender`=%d,`birth_day`=%d,`birth_month`=%d,`birth_year`=%d,`skin_tone`=%d,`skin`=%d,`voice`=%d,`height_cm`=%d,`weight_kg`=%d,`birth_place`=%d,`personality`='%e',`pos_x`=%f,`pos_y`=%f,`pos_z`=%f,`pos_a`=%f,`interior_id`=0,`virtual_world`=0 WHERE `character_id`=%d AND `account_id`=%d LIMIT 1;",
        s_CharacterName[playerid],
        s_CharacterGender[playerid],
        s_CharacterBirthDay[playerid],
        s_CharacterBirthMonth[playerid],
        s_CharacterBirthYear[playerid],
        s_CharacterSkinTone[playerid],
        s_CharacterSkin[playerid],
        s_CharacterVoice[playerid],
        s_CharacterHeight[playerid],
        s_CharacterWeight[playerid],
        s_CharacterBirthPlace[playerid],
        s_CharacterPersonality[playerid],
        TAXI_HQ_SPAWN_X,
        TAXI_HQ_SPAWN_Y,
        TAXI_HQ_SPAWN_Z,
        TAXI_HQ_SPAWN_A,
        s_CharacterID[playerid],
        GetPlayerAccountID(playerid)
    );

    mysql_tquery(
        g_DatabaseHandle,
        query,
        "OnCharacterCreatorSaved",
        "d",
        playerid
    );

    return 1;
}

public OnCharacterCreatorSaved(playerid)
{
    if (!IsPlayerConnected(playerid) ||
        !IsPlayerCharacterLoaded(playerid))
    {
        return 1;
    }

    s_CharacterCreated[playerid] = 1;
    s_CreatorSaving[playerid] = false;
    s_CreatorActive[playerid] = false;

    TogglePlayerControllable(playerid, false);

    Character_ClearChat(playerid);

    SendClientMessage(
        playerid,
        COLOR_WHITE,
        "Ho so nhan vat da duoc khoi tao thanh cong."
    );

    Cinematic_StartNewCharacter(playerid);
    return 1;
}

//-----------------------------------------------------------------------------
// Dialog handling
//-----------------------------------------------------------------------------

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if (!s_CreatorActive[playerid] ||
        s_CreatorSaving[playerid])
    {
        return 0;
    }

    switch (dialogid)
    {
        case DIALOG_CHARACTER_CREATOR:
        {
            if (!response)
            {
                Creator_ShowMainDialog(playerid);
                return 1;
            }

            switch (listitem)
            {
                case 1:
                {
                    ShowPlayerDialog(
                        playerid,
                        DIALOG_CHARACTER_CREATOR_GENDER,
                        DIALOG_STYLE_LIST,
                        "Gioi tinh",
                        "Nam\nNu",
                        "Chon",
                        "Quay lai"
                    );
                }

                case 2:
                {
                    new body[128];

                    format(
                        body,
                        sizeof(body),
                        "Nhap ngay sinh theo DD/MM/YYYY. Nam hien tai: 1992.\nTuoi hop le: 18-80."
                    );

                    ShowPlayerDialog(
                        playerid,
                        DIALOG_CHARACTER_CREATOR_BIRTHDATE,
                        DIALOG_STYLE_INPUT,
                        "Ngay sinh",
                        body,
                        "Luu",
                        "Quay lai"
                    );
                }

                case 4:
                {
                    ShowPlayerDialog(
                        playerid,
                        DIALOG_CHARACTER_CREATOR_TONE,
                        DIALOG_STYLE_LIST,
                        "Mau da",
                        "Sang\nTrung binh\nToi",
                        "Chon",
                        "Quay lai"
                    );
                }

                case 5:
                {
                    Creator_ShowSkinDialog(playerid);
                }

                case 6:
                {
                    Creator_ShowVoiceDialog(playerid);
                }

                case 7:
                {
                    new body[96];

                    format(
                        body,
                        sizeof(body),
                        "Nhap chieu cao tu 150 den 210 cm.\nHien tai: %d cm",
                        s_CharacterHeight[playerid]
                    );

                    ShowPlayerDialog(
                        playerid,
                        DIALOG_CHARACTER_CREATOR_HEIGHT,
                        DIALOG_STYLE_INPUT,
                        "Chieu cao",
                        body,
                        "Luu",
                        "Quay lai"
                    );
                }

                case 8:
                {
                    new body[96];

                    format(
                        body,
                        sizeof(body),
                        "Nhap can nang tu 45 den 150 kg.\nHien tai: %d kg",
                        s_CharacterWeight[playerid]
                    );

                    ShowPlayerDialog(
                        playerid,
                        DIALOG_CHARACTER_CREATOR_WEIGHT,
                        DIALOG_STYLE_INPUT,
                        "Can nang",
                        body,
                        "Luu",
                        "Quay lai"
                    );
                }

                case 9:
                {
                    ShowPlayerDialog(
                        playerid,
                        DIALOG_CHARACTER_CREATOR_BIRTHPLACE,
                        DIALOG_STYLE_LIST,
                        "Noi sinh",
                        "Los Santos\nSan Fierro\nLas Venturas\nNoi khac",
                        "Chon",
                        "Quay lai"
                    );
                }

                case 0:
                {
                    ShowPlayerDialog(
                        playerid,
                        DIALOG_CHARACTER_CREATOR_NAME,
                        DIALOG_STYLE_INPUT,
                        "Ten nhan vat",
                        "Nhap ten theo dinh dang First_Last.\nVi du: Michael_Johnson",
                        "Luu",
                        "Quay lai"
                    );
                }

                case 10:
                {
                    ShowPlayerDialog(
                        playerid,
                        DIALOG_CHARACTER_CREATOR_PERSONALITY,
                        DIALOG_STYLE_INPUT,
                        "Tinh cach nhan vat",
                        "Mo ta ngan ve tinh cach nhan vat (toi da 127 ky tu).",
                        "Luu",
                        "Quay lai"
                    );
                }

                case 11:
                {
                    new genderName[8];

                    Creator_GetGenderName(
                        playerid,
                        genderName,
                        sizeof(genderName)
                    );

                    new body[512];

                    format(
                        body,
                        sizeof(body),
                        "Xac nhan ho so cho %s?\n\nGioi tinh: %s\nNgay sinh: %02d/%02d/%d\nNgoai hinh: %d\nGiong noi: %s\nTinh cach: %s\nChieu cao: %d cm\nCan nang: %d kg\nNoi sinh: %s",
                        s_CharacterName[playerid],
                        genderName,
                        s_CharacterBirthDay[playerid],
                        s_CharacterBirthMonth[playerid],
                        s_CharacterBirthYear[playerid],
                        s_CharacterSkin[playerid],
                        g_VoiceNames[s_CharacterVoice[playerid]],
                        s_CharacterPersonality[playerid][0] ? s_CharacterPersonality[playerid] : "Chua mo ta",
                        s_CharacterHeight[playerid],
                        s_CharacterWeight[playerid],
                        g_BirthPlaceNames[s_CharacterBirthPlace[playerid]]
                    );

                    ShowPlayerDialog(
                        playerid,
                        DIALOG_CHARACTER_CREATOR_CONFIRM,
                        DIALOG_STYLE_MSGBOX,
                        "Xac nhan ho so",
                        body,
                        "Xac nhan",
                        "Quay lai"
                    );
                }

                default:
                {
                    Creator_ShowMainDialog(playerid);
                }
            }

            return 1;
        }

        case DIALOG_CHARACTER_CREATOR_GENDER:
        {
            if (!response)
            {
                Creator_ShowMainDialog(playerid);
                return 1;
            }

            if (listitem < 0 || listitem > 1)
            {
                Creator_ShowMainDialog(playerid);
                return 1;
            }

            s_CharacterGender[playerid] = listitem;
            s_CreatorSkinIndex[playerid] = 0;
            Creator_ApplySkin(playerid);
            Creator_ShowMainDialog(playerid);
            return 1;
        }

        case DIALOG_CHARACTER_CREATOR_BIRTHDATE:
        {
            if (!response)
            {
                Creator_ShowMainDialog(playerid);
                return 1;
            }

            new day, month, year;

            if (!Creator_ParseBirthDate(
                inputtext,
                day,
                month,
                year
            ))
            {
                SendClientMessage(
                    playerid,
                    COLOR_RED,
                    "Ngay sinh khong hop le. Dung DD/MM/YYYY va tuoi 18-80."
                );

                Creator_ShowMainDialog(playerid);
                return 1;
            }

            s_CharacterBirthDay[playerid] = day;
            s_CharacterBirthMonth[playerid] = month;
            s_CharacterBirthYear[playerid] = year;

            Creator_ShowMainDialog(playerid);
            return 1;
        }

        case DIALOG_CHARACTER_CREATOR_TONE:
        {
            if (!response)
            {
                Creator_ShowMainDialog(playerid);
                return 1;
            }

            if (listitem < 0 || listitem > 2)
            {
                Creator_ShowMainDialog(playerid);
                return 1;
            }

            s_CharacterSkinTone[playerid] = listitem;
            s_CreatorSkinIndex[playerid] = 0;
            Creator_ApplySkin(playerid);
            Creator_ShowMainDialog(playerid);
            return 1;
        }

        case DIALOG_CHARACTER_CREATOR_SKIN:
        {
            if (!response)
            {
                Creator_ShowMainDialog(playerid);
                return 1;
            }

            if (listitem < 0 ||
                listitem >= CREATOR_SKINS_PER_GROUP)
            {
                Creator_ShowMainDialog(playerid);
                return 1;
            }

            s_CreatorSkinIndex[playerid] = listitem;
            Creator_ApplySkin(playerid);
            Creator_ShowMainDialog(playerid);
            return 1;
        }

        case DIALOG_CHARACTER_CREATOR_VOICE:
        {
            if (!response)
            {
                Creator_ShowMainDialog(playerid);
                return 1;
            }

            if (listitem < 0 || listitem > 3)
            {
                Creator_ShowMainDialog(playerid);
                return 1;
            }

            s_CharacterVoice[playerid] = listitem;
            Creator_ShowMainDialog(playerid);
            return 1;
        }

        case DIALOG_CHARACTER_CREATOR_HEIGHT:
        {
            if (!response)
            {
                Creator_ShowMainDialog(playerid);
                return 1;
            }

            new const value = strval(inputtext);

            if (value < 150 || value > 210)
            {
                SendClientMessage(
                    playerid,
                    COLOR_RED,
                    "Chieu cao phai trong khoang 150-210 cm."
                );

                Creator_ShowMainDialog(playerid);
                return 1;
            }

            s_CharacterHeight[playerid] = value;
            Creator_ShowMainDialog(playerid);
            return 1;
        }

        case DIALOG_CHARACTER_CREATOR_WEIGHT:
        {
            if (!response)
            {
                Creator_ShowMainDialog(playerid);
                return 1;
            }

            new const value = strval(inputtext);

            if (value < 45 || value > 150)
            {
                SendClientMessage(
                    playerid,
                    COLOR_RED,
                    "Can nang phai trong khoang 45-150 kg."
                );

                Creator_ShowMainDialog(playerid);
                return 1;
            }

            s_CharacterWeight[playerid] = value;
            Creator_ShowMainDialog(playerid);
            return 1;
        }

        case DIALOG_CHARACTER_CREATOR_BIRTHPLACE:
        {
            if (!response)
            {
                Creator_ShowMainDialog(playerid);
                return 1;
            }

            if (listitem < 0 || listitem > 3)
            {
                Creator_ShowMainDialog(playerid);
                return 1;
            }

            s_CharacterBirthPlace[playerid] = listitem;
            Creator_ShowMainDialog(playerid);
            return 1;
        }

        case DIALOG_CHARACTER_CREATOR_NAME:
        {
            if (!response)
            {
                Creator_ShowMainDialog(playerid);
                return 1;
            }
            if (!IsValidCharacterName(inputtext))
            {
                SendClientMessage(playerid, COLOR_RED, "Ten khong hop le. Vi du: Michael_Johnson.");
                Creator_ShowMainDialog(playerid);
                return 1;
            }
            format(s_CharacterName[playerid], CHARACTER_NAME_LENGTH, "%s", inputtext);
            Creator_ShowMainDialog(playerid);
            return 1;
        }

        case DIALOG_CHARACTER_CREATOR_PERSONALITY:
        {
            if (!response)
            {
                Creator_ShowMainDialog(playerid);
                return 1;
            }
            if (strlen(inputtext) < 3)
            {
                SendClientMessage(playerid, COLOR_RED, "Mo ta tinh cach phai co it nhat 3 ky tu.");
                Creator_ShowMainDialog(playerid);
                return 1;
            }
            format(
                s_CharacterPersonality[playerid],
                CHARACTER_PERSONALITY_LENGTH,
                "%s",
                inputtext
            );
            Creator_ShowMainDialog(playerid);
            return 1;
        }

        case DIALOG_CHARACTER_CREATOR_CONFIRM:
        {
            if (!response)
            {
                Creator_ShowMainDialog(playerid);
                return 1;
            }

            CharacterCreator_Confirm(playerid);
            return 1;
        }
    }

    return 0;
}

//-----------------------------------------------------------------------------
// Global player presentation
//-----------------------------------------------------------------------------

// Use the standard pedestrian walking set for every skin.
// open.mp requires UsePlayerPedAnims to be called from OnGameModeInit.
hook OnGameModeInit()
{
    UsePlayerPedAnims();
    return 1;
}

// Keep every player's nametag/radar color neutral white on every spawn.
// Running this on spawn also restores white if another temporary system
// changed the player color during the previous life/session.
hook OnPlayerSpawn(playerid)
{
    SetPlayerColor(playerid, COLOR_WHITE);
    return 1;
}

//-----------------------------------------------------------------------------
// Runtime cleanup
//-----------------------------------------------------------------------------

hook OnPlayerConnect(playerid)
{
    s_CreatorActive[playerid] = false;
    s_CreatorSaving[playerid] = false;
    s_CreatorSkinIndex[playerid] = 0;
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason

    s_CreatorActive[playerid] = false;
    s_CreatorSaving[playerid] = false;
    s_CreatorSkinIndex[playerid] = 0;
    return 1;
}
