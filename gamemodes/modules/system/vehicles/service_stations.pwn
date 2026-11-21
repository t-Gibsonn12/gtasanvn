#include <YSI_Coding\y_hooks>

#define FUEL_STATION_COUNT       (4)
#define MECH_STATION_COUNT       (3)
#define SERVICE_RANGE            (5.0)
#define FUEL_PRICE_PER_LITER     (4)
#define FUEL_MS_PER_LITER        (350)

enum E_SERVICE_POINT
{
    serviceName[36],
    Float:serviceX,
    Float:serviceY,
    Float:serviceZ
};

new const g_FuelStations[FUEL_STATION_COUNT][E_SERVICE_POINT] =
{
    {"Unity Station", 1941.7015, -1778.3616, 13.3906},
    {"Temple Gas", 1004.2750, -939.3102, 42.1797},
    {"Flint Intersection", -90.5515, -1169.4578, 2.4213},
    {"Montgomery", 1382.9686, 462.6956, 20.1987}
};

new const g_MechStations[MECH_STATION_COUNT][E_SERVICE_POINT] =
{
    {"TransFender", 1041.3315, -1027.5234, 32.1016},
    {"Loco Low Co.", 2644.2522, -2038.6141, 13.5500},
    {"Pay'n'Spray Idlewood", 2074.5786, -1831.1649, 13.5469}
};

new g_FuelPickup[FUEL_STATION_COUNT];
new g_MechPickup[MECH_STATION_COUNT];
new g_FuelVehicle[MAX_PLAYERS];
new g_FuelStation[MAX_PLAYERS];
new Float:g_FuelLiters[MAX_PLAYERS];
new g_FuelPrice[MAX_PLAYERS];

forward FuelStation_Complete(playerid);

stock FuelStation_GetNearest(playerid)
{
    for (new i = 0; i < FUEL_STATION_COUNT; i++)
    {
        if (IsPlayerInRangeOfPoint(
            playerid,
            SERVICE_RANGE,
            g_FuelStations[i][serviceX],
            g_FuelStations[i][serviceY],
            g_FuelStations[i][serviceZ]
        ))
        {
            return i;
        }
    }
    return -1;
}

stock FuelStation_Reset(playerid)
{
    g_FuelVehicle[playerid] = INVALID_VEHICLE_ID;
    g_FuelStation[playerid] = -1;
    g_FuelLiters[playerid] = 0.0;
    g_FuelPrice[playerid] = 0;
    return 1;
}

stock FuelStation_Start(playerid)
{
    if (Progress_IsActive(playerid))
    {
        SendClientMessage(playerid, COLOR_RED, "Ban dang thuc hien mot thao tac khac.");
        return 0;
    }

    new const station = FuelStation_GetNearest(playerid);
    if (station == -1 || GetPlayerInterior(playerid) != 0 || GetPlayerVirtualWorld(playerid) != 0)
    {
        SendClientMessage(playerid, COLOR_RED, "Ban khong o trong khu vuc bom xang.");
        return 0;
    }
    if (GetPlayerState(playerid) != PLAYER_STATE_DRIVER)
    {
        SendClientMessage(playerid, COLOR_RED, "Ban phai ngoi o ghe lai cua xe.");
        return 0;
    }

    new const vehicleid = GetPlayerVehicleID(playerid);
    new engine, lights, alarm, doors, bonnet, boot, objective;
    GetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
    if (engine == VEHICLE_PARAMS_ON)
    {
        SendClientMessage(playerid, COLOR_RED, "Hay tat dong co truoc khi bom xang.");
        return 0;
    }

    new Float:currentFuel = Vehicle_GetFuel(vehicleid);
    new Float:needed = SIMPLE_VEHICLE_MAX_FUEL - currentFuel;
    if (needed < 0.1)
    {
        SendClientMessage(
            playerid,
            COLOR_WHITE,
            "Binh xang cua ban da day, khong the do them nua. Su dung /vehicles > Thong tin de xem chi tiet nhien lieu."
        );
        return 0;
    }

    new price = floatround(needed * float(FUEL_PRICE_PER_LITER), floatround_ceil);
    if (GetPlayerMoney(playerid) < price)
    {
        new message[96];
        format(message, sizeof(message), "Ban can $%d de bom day binh.", price);
        SendClientMessage(playerid, COLOR_RED, message);
        return 0;
    }

    new duration = floatround(needed * float(FUEL_MS_PER_LITER));
    if (duration < 1500) duration = 1500;
    if (duration > 30000) duration = 30000;

    g_FuelVehicle[playerid] = vehicleid;
    g_FuelStation[playerid] = station;
    g_FuelLiters[playerid] = needed;
    g_FuelPrice[playerid] = price;

    new label[96];
    format(label, sizeof(label), "DANG BOM %.1f LIT XANG - $%d", needed, price);
    Progress_Start(playerid, label, duration, "FuelStation_Complete");
    SendClientMessage(playerid, COLOR_WHITE, "Dang bom xang, hay giu xe tai cho va tat dong co.");
    return 1;
}

public FuelStation_Complete(playerid)
{
    new const vehicleid = g_FuelVehicle[playerid];
    new const station = g_FuelStation[playerid];
    new const price = g_FuelPrice[playerid];
    new Float:liters = g_FuelLiters[playerid];

    if (!IsPlayerConnected(playerid) ||
        station < 0 ||
        station >= FUEL_STATION_COUNT ||
        !IsValidVehicle(vehicleid) ||
        GetPlayerState(playerid) != PLAYER_STATE_DRIVER ||
        GetPlayerVehicleID(playerid) != vehicleid ||
        !IsPlayerInRangeOfPoint(
            playerid,
            SERVICE_RANGE,
            g_FuelStations[station][serviceX],
            g_FuelStations[station][serviceY],
            g_FuelStations[station][serviceZ]
        ))
    {
        if (IsPlayerConnected(playerid))
        {
            SendClientMessage(playerid, COLOR_RED, "Bom xang bi huy vi xe da roi khoi tram.");
        }
        FuelStation_Reset(playerid);
        return 1;
    }

    new engine, lights, alarm, doors, bonnet, boot, objective;
    GetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
    if (engine == VEHICLE_PARAMS_ON || GetPlayerMoney(playerid) < price)
    {
        SendClientMessage(playerid, COLOR_RED, "Bom xang that bai: hay tat may va dam bao du tien.");
        FuelStation_Reset(playerid);
        return 1;
    }

    Vehicle_SetFuel(vehicleid, SIMPLE_VEHICLE_MAX_FUEL);
    GivePlayerMoney(playerid, -price);
    Economy_SaveBalances(playerid);

    new ownerid, slot, databaseID;
    if (SimpleVehicle_GetRuntimeOwner(vehicleid, ownerid, slot))
    {
        SimpleVehicle_SaveState(
            ownerid,
            slot,
            false,
            PlayerVehicle[ownerid][slot][pvStorage]
        );
        databaseID = PlayerVehicle[ownerid][slot][pvDatabaseID];
    }
    new details[128];
    format(details, sizeof(details), "vehicle_db=%d server_id=%d liters=%.1f station=%s",
        databaseID, vehicleid, liters, g_FuelStations[station][serviceName]);
    Economy_LogTransaction(playerid, "fuel_purchase", -price, 0, details);

    new message[112];
    format(message, sizeof(message), "Da bom %.1f lit xang, chi phi $%d.", liters, price);
    SendClientMessage(playerid, 0x68C83BFF, message);
    FuelStation_Reset(playerid);
    return 1;
}

hook OnGameModeInit()
{
    for (new i = 0; i < FUEL_STATION_COUNT; i++)
    {
        g_FuelPickup[i] = CreatePickup(
            1239, 1,
            g_FuelStations[i][serviceX],
            g_FuelStations[i][serviceY],
            g_FuelStations[i][serviceZ],
            0
        );
        Create3DTextLabel(
            "{68C83B}TRAM XANG\n{FFFFFF}Dung xe tai day va bam {68C83B}Y {FFFFFF}de bom xang",
            COLOR_WHITE,
            g_FuelStations[i][serviceX],
            g_FuelStations[i][serviceY],
            g_FuelStations[i][serviceZ] + 0.7,
            18.0, 0, false
        );
    }
    for (new i = 0; i < MECH_STATION_COUNT; i++)
    {
        g_MechPickup[i] = CreatePickup(
            1239, 1,
            g_MechStations[i][serviceX],
            g_MechStations[i][serviceY],
            g_MechStations[i][serviceZ],
            0
        );
        Create3DTextLabel(
            "{264A73}TRAM SUA XE\n{FFFFFF}Diem dich vu mechanic",
            COLOR_WHITE,
            g_MechStations[i][serviceX],
            g_MechStations[i][serviceY],
            g_MechStations[i][serviceZ] + 0.7,
            18.0, 0, false
        );
    }
    return 1;
}

hook OnPlayerConnect(playerid)
{
    FuelStation_Reset(playerid);
    return 1;
}

hook OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys)
{
    #pragma unused oldkeys
    if ((newkeys & KEY_YES) && FuelStation_GetNearest(playerid) != -1)
    {
        FuelStation_Start(playerid);
    }
    return 1;
}

hook OnPlayerStateChange(playerid, PLAYER_STATE:newState, PLAYER_STATE:oldState)
{
    #pragma unused oldState
    if (g_FuelVehicle[playerid] != INVALID_VEHICLE_ID && newState != PLAYER_STATE_DRIVER)
    {
        Progress_Stop(playerid);
        FuelStation_Reset(playerid);
        SendClientMessage(playerid, COLOR_RED, "Da huy bom xang vi ban roi ghe lai.");
    }
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    FuelStation_Reset(playerid);
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    #pragma unused inputtext
    if (dialogid == DIALOG_FUEL_GOTO)
    {
        if (response && listitem >= 0 && listitem < FUEL_STATION_COUNT)
        {
            SetPlayerInterior(playerid, 0);
            SetPlayerVirtualWorld(playerid, 0);
            SetPlayerPos(playerid,
                g_FuelStations[listitem][serviceX],
                g_FuelStations[listitem][serviceY] + 3.0,
                g_FuelStations[listitem][serviceZ]);
        }
        return 1;
    }
    if (dialogid == DIALOG_MECH_GOTO)
    {
        if (response && listitem >= 0 && listitem < MECH_STATION_COUNT)
        {
            SetPlayerInterior(playerid, 0);
            SetPlayerVirtualWorld(playerid, 0);
            SetPlayerPos(playerid,
                g_MechStations[listitem][serviceX],
                g_MechStations[listitem][serviceY] + 3.0,
                g_MechStations[listitem][serviceZ]);
        }
        return 1;
    }
    return 0;
}

CMD:gotofuel(playerid, params[])
{
    #pragma unused params
    new list[256];
    for (new i = 0; i < FUEL_STATION_COUNT; i++)
    {
        format(list, sizeof(list), "%s%s\n", list, g_FuelStations[i][serviceName]);
    }
    ShowPlayerDialog(playerid, DIALOG_FUEL_GOTO, DIALOG_STYLE_LIST, "Danh sach tram xang", list, "Di", "Dong");
    return 1;
}

CMD:gotomech(playerid, params[])
{
    #pragma unused params
    new list[256];
    for (new i = 0; i < MECH_STATION_COUNT; i++)
    {
        format(list, sizeof(list), "%s%s\n", list, g_MechStations[i][serviceName]);
    }
    ShowPlayerDialog(playerid, DIALOG_MECH_GOTO, DIALOG_STYLE_LIST, "Danh sach tram sua xe", list, "Di", "Dong");
    return 1;
}

CMD:setxang(playerid, params[])
{
    if (GetPlayerState(playerid) != PLAYER_STATE_DRIVER)
    {
        return SendClientMessage(playerid, COLOR_RED, "Ban phai ngoi ghe lai.");
    }
    if (!strlen(params))
    {
        return SendClientMessage(playerid, COLOR_WHITE, "Su dung: /setxang [0-100]");
    }

    new Float:amount = floatstr(params);
    if (amount < 0.0 || amount > SIMPLE_VEHICLE_MAX_FUEL)
    {
        return SendClientMessage(playerid, COLOR_RED, "Muc xang phai tu 0 den 100 lit.");
    }

    new const vehicleid = GetPlayerVehicleID(playerid);
    Vehicle_SetFuel(vehicleid, amount);
    new ownerid, slot;
    if (SimpleVehicle_GetRuntimeOwner(vehicleid, ownerid, slot))
    {
        SimpleVehicle_SaveState(ownerid, slot, false, PlayerVehicle[ownerid][slot][pvStorage]);
    }
    new message[80];
    format(message, sizeof(message), "Da dat muc xang xe thanh %.1f lit.", amount);
    SendClientMessage(playerid, 0x68C83BFF, message);
    return 1;
}

CMD:getcar(playerid, params[])
{
    if (!strlen(params))
    {
        return SendClientMessage(playerid, COLOR_WHITE, "Su dung: /getcar [vehicleid]");
    }

    new const vehicleid = strval(params);
    if (vehicleid <= 0 || vehicleid >= MAX_VEHICLES || !IsValidVehicle(vehicleid))
    {
        return SendClientMessage(playerid, COLOR_RED, "ID xe khong ton tai.");
    }

    new Float:x, Float:y, Float:z, Float:a;
    GetPlayerPos(playerid, x, y, z);
    GetPlayerFacingAngle(playerid, a);
    x += 4.0 * floatsin(-a, degrees);
    y += 4.0 * floatcos(-a, degrees);

    LinkVehicleToInterior(vehicleid, GetPlayerInterior(playerid));
    SetVehicleVirtualWorld(vehicleid, GetPlayerVirtualWorld(playerid));
    SetVehiclePos(vehicleid, x, y, z + 0.5);
    SetVehicleZAngle(vehicleid, a);

    new message[96];
    format(message, sizeof(message), "Da dua vehicle ID %d den vi tri cua ban.", vehicleid);
    SendClientMessage(playerid, 0x68C83BFF, message);
    return 1;
}
