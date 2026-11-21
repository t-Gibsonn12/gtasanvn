#include <YSI_Coding\y_hooks>

#define RE_PARENT_BANK_ID             (900002)
#define RE_TOWER_RENT                 (250000)
#define RE_TAX_PERCENT                (5)
#define RE_HALL_X                     (1289.6561)
#define RE_HALL_Y                     (4.5879)
#define RE_HALL_Z                     (1001.0078)
#define RE_HALL_A                     (176.1505)
#define RE_HALL_INTERIOR              (18)
#define RE_OFFICE_X                   (2333.0330)
#define RE_OFFICE_Y                   (-1073.9600)
#define RE_OFFICE_Z                   (1049.1000)
#define RE_OFFICE_INTERIOR            (6)
#define RE_WORLD_BASE                 (41000)
#define RE_BUILDING_COUNT             (5)
#define RE_COMPANY_COUNT              (6)
#define RE_APARTMENT_X                (1499.9048)
#define RE_APARTMENT_Y                (-1379.6538)
#define RE_APARTMENT_Z                (14.0254)
#define RE_APARTMENT_A                (119.3944)

enum E_RE_BUILDING
{
    reCompanyID,
    reName[48],
    reFloors,
    Float:reX,
    Float:reY,
    Float:reZ,
    Float:reA
};
new const g_REBuilding[RE_BUILDING_COUNT][E_RE_BUILDING] =
{
    {900003, "Westbridge Realty Group",       15, 1734.9081, -1265.5187, 13.5420, 292.8434},
    {900004, "Sterling Heights Properties",   15, 1684.4510, -1340.1721, 17.4409, 267.3335},
    {900005, "Pacific Crown Properties",      20, 1569.6294, -1334.7303, 16.4844, 147.8718},
    {900006, "Redwood Commercial Holdings",   16, 1564.6221, -1274.6573, 17.4063, 355.8702},
    {900007, "Kingsley Urban Estates",        18, 1495.1992, -1280.7034, 14.5814, 199.0367}
};

new g_REOfficeMode[MAX_PLAYERS]; // 1 = custom exterior, 2 = Pacific Crown tower.
new g_RESelectedUnit[MAX_PLAYERS];
new g_RESelectedBuilding[MAX_PLAYERS];
new g_RESelectedSeller[MAX_PLAYERS];
new g_RESelectedRent[MAX_PLAYERS];
new g_REUnitRows[MAX_PLAYERS];
new g_REUnitID[MAX_PLAYERS][152];
new g_REUnitFloor[MAX_PLAYERS][152];
new g_REUnitNumber[MAX_PLAYERS][152];
new g_RESelectedFloor[MAX_PLAYERS];
new g_RESelectedNumber[MAX_PLAYERS];
new g_REPlayerFloor[MAX_PLAYERS];
new g_REPlayerBuilding[MAX_PLAYERS];
new g_REInsideUnit[MAX_PLAYERS];
new g_REPendingDoor[MAX_PLAYERS];
new const Float:g_REDoorPos[8][3] =
{
    {1292.8401, -19.4681, 1001.0248},
    {1284.4944, -19.7059, 1001.0156},
    {1274.9279, -19.6285, 1001.0242},
    {1265.3372, -19.8919, 1001.0234},
    {1256.2972, -19.7993, 1001.0234},
    {1255.9634,  -5.8325, 1001.0234},
    {1264.4208,  -5.3850, 1001.0234},
    {1292.0300,  -5.8241, 1001.0240}
};

forward public RE_OnUnitsLoaded(playerid);
forward public RE_OnDoorAccess(playerid, floor, unit);
forward public RE_OnRecoveredUnitExit(playerid);

stock RE_TryLeaveRecoveredInterior(playerid)
{
    new world = GetPlayerVirtualWorld(playerid);
    if (world < RE_WORLD_BASE) return 0;

    // Hallway worlds encode building and floor and can therefore be restored
    // without relying on session-only player variables.
    for (new building; building < RE_BUILDING_COUNT; building++)
    {
        for (new floor = 1; floor <= g_REBuilding[building][reFloors]; floor++)
        {
            if (world != RE_WORLD_BASE + building * 100 + floor) continue;
            SetPlayerInterior(playerid, 0);
            SetPlayerVirtualWorld(playerid, 0);
            SetPlayerPos(playerid, g_REBuilding[building][reX], g_REBuilding[building][reY], g_REBuilding[building][reZ]);
            SetPlayerFacingAngle(playerid, g_REBuilding[building][reA]);
            g_REPlayerBuilding[playerid] = building;
            g_REPlayerFloor[playerid] = 0;
            g_REInsideUnit[playerid] = 0;
            SendClientMessage(playerid, COLOR_WHITE, "Ban da roi toa nha va tro ve exterior chinh.");
            return 1;
        }
        if (world == RE_WORLD_BASE + 900 + building)
        {
            SetPlayerInterior(playerid, RE_HALL_INTERIOR);
            SetPlayerVirtualWorld(playerid, RE_WORLD_BASE + building * 100 + g_REBuilding[building][reFloors]);
            SetPlayerPos(playerid, RE_HALL_X, RE_HALL_Y, RE_HALL_Z);
            SetPlayerFacingAngle(playerid, RE_HALL_A);
            g_REPlayerBuilding[playerid] = building;
            g_REPlayerFloor[playerid] = g_REBuilding[building][reFloors];
            g_REInsideUnit[playerid] = 0;
            return 1;
        }
    }

    // Office worlds encode unit_id. Resolve its building/floor/door from SQL,
    // allowing /ra to work even after /q and a fresh login.
    if (world >= RE_WORLD_BASE + 1000 && GetPlayerInterior(playerid) == RE_OFFICE_INTERIOR)
    {
        new unitid = world - (RE_WORLD_BASE + 1000), query[384];
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "SELECT `building_id`,`floor_number`,`unit_number` FROM `real_estate_units` WHERE `unit_id`=%d LIMIT 1", unitid);
        mysql_tquery(g_DatabaseHandle, query, "RE_OnRecoveredUnitExit", "d", playerid);
        return 1;
    }
    return 0;
}

stock RE_RecoverHallContext(playerid)
{
    new world = GetPlayerVirtualWorld(playerid);
    for (new building; building < RE_BUILDING_COUNT; building++)
        for (new floor = 1; floor <= g_REBuilding[building][reFloors]; floor++)
            if (world == RE_WORLD_BASE + building * 100 + floor)
            {
                g_REPlayerBuilding[playerid] = building;
                g_REPlayerFloor[playerid] = floor;
                return 1;
            }
    return 0;
}

public RE_OnRecoveredUnitExit(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    if (!cache_num_rows())
        return SendClientMessage(playerid, COLOR_RED, "Khong the nhan dien ho so can van phong tu Virtual World hien tai.");
    new buildingID, floor, unit;
    cache_get_value_name_int(0, "building_id", buildingID);
    cache_get_value_name_int(0, "floor_number", floor);
    cache_get_value_name_int(0, "unit_number", unit);
    new building = buildingID - 1;
    if (building < 0 || building >= RE_BUILDING_COUNT || unit < 1 || unit > 8) return 1;
    g_REPlayerBuilding[playerid] = building;
    g_REPlayerFloor[playerid] = floor;
    g_REPendingDoor[playerid] = unit;
    g_REInsideUnit[playerid] = 0;
    SetPlayerInterior(playerid, RE_HALL_INTERIOR);
    SetPlayerVirtualWorld(playerid, RE_WORLD_BASE + building * 100 + floor);
    SetPlayerPos(playerid, g_REDoorPos[unit - 1][0],
        g_REDoorPos[unit - 1][1] + (unit <= 5 ? 1.0 : -1.0), g_REDoorPos[unit - 1][2]);
    SendClientMessage(playerid, COLOR_WHITE, "He thong da khoi phuc door van phong va dua ban tro lai dung tang.");
    return 1;
}

public RealEstate_ShowOfficeChoice(playerid)
{
    ShowPlayerDialog(playerid, DIALOG_RE_OFFICE_CHOICE, DIALOG_STYLE_LIST,
        "Company | Chon van phong phap ly",
        "Tu chon vi tri van phong\tDat door tai vi tri hien tai\nThue van phong tu Company bat dong san\tChon 1 trong 5 toa nha",
        "Chon", "Huy");
    return 1;
}

stock RE_ShowBuildings(playerid)
{
    new body[700], floorsForRent;
    format(body, sizeof(body), "Toa nha\tChu so huu\tSo tang\tVan phong\n");
    for (new i; i < RE_BUILDING_COUNT; i++)
    {
        floorsForRent = g_REBuilding[i][reFloors] - 1;
        format(body, sizeof(body), "%s%s Tower\t%s\t%d\t%d phong\n", body,
            g_REBuilding[i][reName], g_REBuilding[i][reName],
            g_REBuilding[i][reFloors], floorsForRent * 8);
    }
    ShowPlayerDialog(playerid, DIALOG_RE_BUILDINGS, DIALOG_STYLE_TABLIST_HEADERS,
        "Thi truong van phong Los Santos", body, "Chon toa", "Quay lai");
    return 1;
}

stock RE_LoadVacantUnits(playerid)
{
    new query[512];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT u.`unit_id`,u.`floor_number`,u.`unit_number`,u.`monthly_price`,u.`owner_company_id`,b.`building_name` FROM `real_estate_units` u INNER JOIN `real_estate_buildings` b ON b.`building_id`=u.`building_id` WHERE u.`status`='VACANT' AND u.`building_id`=%d ORDER BY u.`floor_number`,u.`unit_number` LIMIT 152",
        g_RESelectedBuilding[playerid] + 1);
    mysql_tquery(g_DatabaseHandle, query, "RE_OnUnitsLoaded", "d", playerid);
    return 1;
}

public RE_OnUnitsLoaded(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    new rows = cache_num_rows(), body[5000], id, floor, unit, price, seller, priceText[24], building[48];
    g_REUnitRows[playerid] = rows;
    format(body, sizeof(body), "Van phong\tTinh trang\tGia hop dong\n");
    for (new i; i < rows; i++)
    {
        cache_get_value_name_int(i, "unit_id", id);
        cache_get_value_name_int(i, "floor_number", floor);
        cache_get_value_name_int(i, "unit_number", unit);
        cache_get_value_name_int(i, "monthly_price", price);
        cache_get_value_name_int(i, "owner_company_id", seller);
        cache_get_value_name(i, "building_name", building, sizeof(building));
        g_REUnitID[playerid][i] = id;
        g_REUnitFloor[playerid][i] = floor;
        g_REUnitNumber[playerid][i] = unit;
        if (i == 0)
        {
            g_RESelectedSeller[playerid] = seller;
            g_RESelectedRent[playerid] = price;
        }
        LSBank_FormatMoney(price, priceText, sizeof(priceText));
        format(body, sizeof(body), "%s%s | Tang %02d - Phong %02d\tCon trong\t$%s\n", body, building, floor, unit, priceText);
    }
    if (!rows) format(body, sizeof(body), "Toa nha nay hien khong con van phong trong.");
    ShowPlayerDialog(playerid, DIALOG_RE_UNITS, DIALOG_STYLE_TABLIST_HEADERS,
        "Van phong cho thue | Moi tang 8 phong", body, "Thue", "Quay lai");
    return 1;
}

stock RE_CheckDoorAccess(playerid, building, floor, unit)
{
    new query[384];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT `unit_id`,`occupant_company_id`,`status` FROM `real_estate_units` WHERE `building_id`=%d AND `floor_number`=%d AND `unit_number`=%d LIMIT 1",
        building + 1, floor, unit);
    mysql_tquery(g_DatabaseHandle, query, "RE_OnDoorAccess", "ddd", playerid, floor, unit);
    return 1;
}

public RE_OnDoorAccess(playerid, floor, unit)
{
    if (!IsPlayerConnected(playerid) || !cache_num_rows()) return 1;
    new unitid, companyid, status[12];
    cache_get_value_name_int(0, "unit_id", unitid);
    cache_get_value_name_int(0, "occupant_company_id", companyid);
    cache_get_value_name(0, "status", status, sizeof(status));
    if (!strcmp(status, "VACANT", true))
        return SendClientMessage(playerid, COLOR_RED, "Van phong nay dang trong. Company co the thue qua Pacific Crown Properties khi thanh lap.");
    if (g_PlayerCompanyID[playerid] != companyid && !g_AdminCompanyOverride[playerid])
        return SendClientMessage(playerid, COLOR_RED, "Van phong nay thuoc mot doanh nghiep khac; ban khong co quyen truy cap.");
    g_REInsideUnit[playerid] = unitid;
    g_REPendingDoor[playerid] = unit;
    SetPlayerInterior(playerid, RE_OFFICE_INTERIOR);
    SetPlayerVirtualWorld(playerid, RE_WORLD_BASE + 1000 + unitid);
    SetPlayerPos(playerid, RE_OFFICE_X, RE_OFFICE_Y, RE_OFFICE_Z);
    SetPlayerFacingAngle(playerid, 0.0);
    new notice[128];
    format(notice, sizeof(notice), "Ban da vao van phong tang %d, phong %d. Bam Y tai cua de quay lai hanh lang.", floor, unit);
    SendClientMessage(playerid, 0x35AEE2FF, notice);
    return 1;
}

public RealEstate_FinalizeCompanyOffice(playerid, companyid)
{
    new query[1000];
    if (g_REOfficeMode[playerid] == 2)
    {
        new seller = g_RESelectedSeller[playerid], gross = g_RESelectedRent[playerid];
        new tax = gross * RE_TAX_PERCENT / 100, net = gross - tax;
        Company_AddRuntimeBalance(companyid, -gross);
        Company_AddRuntimeBalance(seller, net);
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "UPDATE `companies` SET `bank_balance`=CASE WHEN `company_id`=%d THEN `bank_balance`-%d WHEN `company_id`=%d THEN `bank_balance`+%d ELSE `bank_balance` END WHERE `company_id` IN (%d,%d)",
            companyid, gross, seller, net, companyid, seller);
        mysql_tquery(g_DatabaseHandle, query);
        LSBank_RecordRevenue("real_estate_office_tax", tax, GetPlayerCharacterID(playerid));
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "UPDATE `real_estate_units` SET `status`='OWNED',`occupant_company_id`=%d,`lease_started_at`=NOW(),`lease_expires_at`=NULL WHERE `unit_id`=%d AND `status`='VACANT'",
            companyid, g_RESelectedUnit[playerid]);
        mysql_tquery(g_DatabaseHandle, query);
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "INSERT INTO `real_estate_transactions` (`contract_code`,`unit_id`,`buyer_company_id`,`seller_company_id`,`transaction_type`,`gross_amount`,`tax_amount`,`net_amount`,`actor_character_id`) VALUES (CONCAT('RE-',%d,'-',UNIX_TIMESTAMP()),%d,%d,%d,'PURCHASE',%d,%d,%d,%d)",
            companyid, g_RESelectedUnit[playerid], companyid, seller, gross, tax, net, GetPlayerCharacterID(playerid));
        mysql_tquery(g_DatabaseHandle, query);
        new expenseDetails[220], revenueDetails[220], building = g_RESelectedBuilding[playerid];
        format(expenseDetails, sizeof(expenseDetails), "Company %s da mua quyen su dung van phong %s Tower, tang %d phong %d theo hop dong 99 nam",
            g_PlayerCompanyName[playerid], g_REBuilding[building][reName], g_RESelectedFloor[playerid], g_RESelectedNumber[playerid]);
        format(revenueDetails, sizeof(revenueDetails), "Company %s da thue van phong %s Tower, tang %d phong %d; doanh thu sau thue",
            g_PlayerCompanyName[playerid], g_REBuilding[building][reName], g_RESelectedFloor[playerid], g_RESelectedNumber[playerid]);
        Company_LogByID(companyid, playerid, "office_purchase_expense", expenseDetails, -gross);
        Company_LogByID(seller, playerid, "office_rental_revenue", revenueDetails, net);
        SendClientMessage(playerid, 0x68C83BFF, "Da ky hop dong thue van phong. Phi thue da chuyen dung Company bat dong san so huu toa nha va ghi lich su giao dich.");
    }
    else
    {
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "INSERT INTO `real_estate_custom_offices` (`company_id`,`exterior_x`,`exterior_y`,`exterior_z`,`exterior_a`) VALUES (%d,%f,%f,%f,%f)",
            companyid, g_CompanyPendingX[playerid], g_CompanyPendingY[playerid],
            g_CompanyPendingZ[playerid], g_CompanyPendingA[playerid]);
        mysql_tquery(g_DatabaseHandle, query);
        Company_LogByID(companyid, playerid, "custom_office_registered", "Dang ky van phong rieng tai vi tri tu chon", 0);
    }
    g_REOfficeMode[playerid] = 0;
    g_RESelectedUnit[playerid] = 0;
    g_RESelectedSeller[playerid] = 0;
    g_RESelectedRent[playerid] = 0;
    return 1;
}

stock RE_ShowElevator(playerid)
{
    new building = g_REPlayerBuilding[playerid], body[900], floors = g_REBuilding[building][reFloors];
    for (new floor = 1; floor <= floors; floor++)
        format(body, sizeof(body), "%sTang %02d%s\n", body, floor, floor == floors ? "\tTru so chinh Company BDS" : "\t8 van phong");
    format(body, sizeof(body), "%sRoi toa nha\tTro lai Downtown Los Santos", body);
    new title[96];
    format(title, sizeof(title), "%s Tower | Thang may", g_REBuilding[building][reName]);
    ShowPlayerDialog(playerid, DIALOG_RE_ELEVATOR, DIALOG_STYLE_LIST,
        title, body, "Di chuyen", "Thoat");
    return 1;
}

CMD:gototower(playerid, params[])
{
    if (!IsPlayerCharacterLoaded(playerid))
        return SendClientMessage(playerid, COLOR_RED, "Ban phai dang nhap nhan vat truoc khi di chuyen den toa nha.");
    new building = strval(params) - 1;
    if (building < 0 || building > RE_BUILDING_COUNT)
        return SendClientMessage(playerid, COLOR_WHITE, "Su dung: /gototower [1-6]. ID 1-5 la toa van phong; ID 6 la du an apartment Arcadia.");
    SetPlayerInterior(playerid, 0);
    SetPlayerVirtualWorld(playerid, 0);
    if (building == RE_BUILDING_COUNT)
    {
        SetPlayerPos(playerid, RE_APARTMENT_X, RE_APARTMENT_Y, RE_APARTMENT_Z);
        SetPlayerFacingAngle(playerid, RE_APARTMENT_A);
        SendClientMessage(playerid, 0x35AEE2FF, "Ban da di chuyen den door Arcadia Residential Group. He thong apartment se duoc phat trien o giai doan tiep theo.");
        return 1;
    }
    SetPlayerPos(playerid, g_REBuilding[building][reX], g_REBuilding[building][reY], g_REBuilding[building][reZ]);
    SetPlayerFacingAngle(playerid, g_REBuilding[building][reA]);
    g_REPlayerFloor[playerid] = 0;
    g_REInsideUnit[playerid] = 0;
    new notice[144];
    format(notice, sizeof(notice), "Ban da di chuyen den %s Tower. Den gan pickup va bam Y de vao toa nha.", g_REBuilding[building][reName]);
    SendClientMessage(playerid, 0x35AEE2FF, notice);
    return 1;
}

CMD:gotobds(playerid, params[])
{
    return cmd_gototower(playerid, params);
}

hook OnGameModeInit()
{
    for (new i; i < RE_COMPANY_COUNT; i++)
        Company_EnsureBalance(900003 + i, i == 2 ? 10000000 : 5000000);
    mysql_tquery(g_DatabaseHandle,
        "ALTER TABLE `companies` ADD COLUMN IF NOT EXISTS `parent_company_id` INT UNSIGNED NOT NULL DEFAULT 0");
    mysql_tquery(g_DatabaseHandle,
        "INSERT INTO `companies` (`company_id`,`name`,`company_type`,`owner_character_id`,`bank_balance`,`member_limit`,`vehicle_limit`,`parent_company_id`,`government_owned`,`admin_managed`) VALUES (900003,'Westbridge Realty Group',5,0,5000000,50,10,0,0,1),(900004,'Sterling Heights Properties',5,0,5000000,50,10,0,0,1),(900005,'Pacific Crown Properties',5,0,10000000,80,20,900002,0,1),(900006,'Redwood Commercial Holdings',5,0,5000000,50,10,0,0,1),(900007,'Kingsley Urban Estates',5,0,5000000,50,10,0,0,1),(900008,'Arcadia Residential Group',5,0,5000000,50,10,0,0,1) ON DUPLICATE KEY UPDATE `name`=VALUES(`name`),`company_type`=5,`parent_company_id`=VALUES(`parent_company_id`),`admin_managed`=1");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `real_estate_buildings` (`building_id` TINYINT UNSIGNED NOT NULL,`owner_company_id` INT UNSIGNED NOT NULL,`building_name` VARCHAR(64) NOT NULL,`total_floors` TINYINT UNSIGNED NOT NULL,`rooms_per_floor` TINYINT UNSIGNED NOT NULL DEFAULT 8,`exterior_x` FLOAT NOT NULL,`exterior_y` FLOAT NOT NULL,`exterior_z` FLOAT NOT NULL,`exterior_a` FLOAT NOT NULL,`building_type` ENUM('OFFICE','APARTMENT') NOT NULL DEFAULT 'OFFICE',PRIMARY KEY (`building_id`),KEY (`owner_company_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "INSERT INTO `real_estate_buildings` (`building_id`,`owner_company_id`,`building_name`,`total_floors`,`rooms_per_floor`,`exterior_x`,`exterior_y`,`exterior_z`,`exterior_a`,`building_type`) VALUES (6,900008,'Arcadia Residential Group',1,0,1499.9048,-1379.6538,14.0254,119.3944,'APARTMENT') ON DUPLICATE KEY UPDATE `owner_company_id`=900008,`building_name`='Arcadia Residential Group',`exterior_x`=1499.9048,`exterior_y`=-1379.6538,`exterior_z`=14.0254,`exterior_a`=119.3944,`building_type`='APARTMENT'");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `real_estate_units` (`unit_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,`building_id` TINYINT UNSIGNED NOT NULL DEFAULT 3,`owner_company_id` INT UNSIGNED NOT NULL DEFAULT 900005,`floor_number` TINYINT UNSIGNED NOT NULL,`unit_number` TINYINT UNSIGNED NOT NULL,`status` ENUM('VACANT','LEASED','OWNED') NOT NULL DEFAULT 'VACANT',`occupant_company_id` INT UNSIGNED NOT NULL DEFAULT 0,`monthly_price` INT UNSIGNED NOT NULL DEFAULT 250000,`lease_started_at` DATETIME NULL,`lease_expires_at` DATETIME NULL,PRIMARY KEY (`unit_id`),UNIQUE KEY `uq_building_unit` (`building_id`,`floor_number`,`unit_number`),KEY (`occupant_company_id`,`status`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "ALTER TABLE `real_estate_units` ADD COLUMN IF NOT EXISTS `building_id` TINYINT UNSIGNED NOT NULL DEFAULT 3 AFTER `unit_id`,ADD COLUMN IF NOT EXISTS `owner_company_id` INT UNSIGNED NOT NULL DEFAULT 900005 AFTER `building_id`");
    mysql_tquery(g_DatabaseHandle, "DROP INDEX IF EXISTS `floor_number` ON `real_estate_units`");
    mysql_tquery(g_DatabaseHandle, "CREATE UNIQUE INDEX IF NOT EXISTS `uq_building_unit` ON `real_estate_units` (`building_id`,`floor_number`,`unit_number`)");
    mysql_tquery(g_DatabaseHandle, "UPDATE `real_estate_units` SET `status`='OWNED',`lease_expires_at`=NULL WHERE `status`='LEASED'");
    for (new building; building < RE_BUILDING_COUNT; building++)
    {
        new query[640];
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "INSERT INTO `real_estate_buildings` (`building_id`,`owner_company_id`,`building_name`,`total_floors`,`exterior_x`,`exterior_y`,`exterior_z`,`exterior_a`) VALUES (%d,%d,'%e',%d,%f,%f,%f,%f) ON DUPLICATE KEY UPDATE `owner_company_id`=VALUES(`owner_company_id`),`building_name`=VALUES(`building_name`),`total_floors`=VALUES(`total_floors`),`exterior_x`=VALUES(`exterior_x`),`exterior_y`=VALUES(`exterior_y`),`exterior_z`=VALUES(`exterior_z`),`exterior_a`=VALUES(`exterior_a`)",
            building + 1, g_REBuilding[building][reCompanyID], g_REBuilding[building][reName],
            g_REBuilding[building][reFloors], g_REBuilding[building][reX], g_REBuilding[building][reY],
            g_REBuilding[building][reZ], g_REBuilding[building][reA]);
        mysql_tquery(g_DatabaseHandle, query);
        for (new floor = 1; floor < g_REBuilding[building][reFloors]; floor++) for (new unit = 1; unit <= 8; unit++)
        {
            mysql_format(g_DatabaseHandle, query, sizeof(query),
                "INSERT IGNORE INTO `real_estate_units` (`building_id`,`owner_company_id`,`floor_number`,`unit_number`,`monthly_price`) VALUES (%d,%d,%d,%d,%d)",
                building + 1, g_REBuilding[building][reCompanyID], floor, unit, RE_TOWER_RENT);
            mysql_tquery(g_DatabaseHandle, query);
        }
        CreatePickup(1239, 1, g_REBuilding[building][reX], g_REBuilding[building][reY], g_REBuilding[building][reZ], 0);
        new exteriorLabel[180];
        format(exteriorLabel, sizeof(exteriorLabel), "%s TOWER\n%d tang - Company bat dong san\nBam Y de vao sanh", g_REBuilding[building][reName], g_REBuilding[building][reFloors]);
        Create3DTextLabel(exteriorLabel, 0x35AEE2FF, g_REBuilding[building][reX], g_REBuilding[building][reY], g_REBuilding[building][reZ] + 0.5, 20.0, 0, bool:true);
        for (new floor = 1; floor < g_REBuilding[building][reFloors]; floor++) for (new unit; unit < 8; unit++)
        {
            new label[64], world = RE_WORLD_BASE + building * 100 + floor;
            format(label, sizeof(label), "Van phong %02d-%02d\nBam Y de vao", floor, unit + 1);
            Create3DTextLabel(label, 0xFFFFFFFF, g_REDoorPos[unit][0], g_REDoorPos[unit][1], g_REDoorPos[unit][2] + 0.35, 8.0, world, bool:true);
        }
        new hqLabel[96], hqWorld = RE_WORLD_BASE + building * 100 + g_REBuilding[building][reFloors];
        format(hqLabel, sizeof(hqLabel), "%s\nTru so chinh - Tang %d", g_REBuilding[building][reName], g_REBuilding[building][reFloors]);
        Create3DTextLabel(hqLabel, 0x35AEE2FF, g_REDoorPos[0][0], g_REDoorPos[0][1], g_REDoorPos[0][2] + 0.35, 10.0, hqWorld, bool:true);
    }
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `real_estate_transactions` (`transaction_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,`contract_code` VARCHAR(48) NOT NULL,`unit_id` INT UNSIGNED NOT NULL,`buyer_company_id` INT UNSIGNED NOT NULL,`seller_company_id` INT UNSIGNED NOT NULL,`transaction_type` ENUM('LEASE','PURCHASE','RENEWAL') NOT NULL,`gross_amount` INT UNSIGNED NOT NULL,`tax_amount` INT UNSIGNED NOT NULL,`net_amount` INT UNSIGNED NOT NULL,`actor_character_id` INT UNSIGNED NOT NULL,`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY (`transaction_id`),KEY (`buyer_company_id`,`created_at`),KEY (`seller_company_id`,`created_at`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `real_estate_custom_offices` (`office_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,`company_id` INT UNSIGNED NOT NULL,`exterior_x` FLOAT NOT NULL,`exterior_y` FLOAT NOT NULL,`exterior_z` FLOAT NOT NULL,`exterior_a` FLOAT NOT NULL,PRIMARY KEY (`office_id`),UNIQUE KEY (`company_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    CreatePickup(1239, 1, RE_APARTMENT_X, RE_APARTMENT_Y, RE_APARTMENT_Z, 0);
    Create3DTextLabel("ARCADIA RESIDENTIAL GROUP\nApartment Development Division\nBam Y de xem thong tin du an", 0x35AEE2FF, RE_APARTMENT_X, RE_APARTMENT_Y, RE_APARTMENT_Z + 0.5, 20.0, 0, bool:true);
    return 1;
}

hook OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys)
{
    #pragma unused oldkeys
    if (!(newkeys & KEY_YES) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT) return 1;
    if (g_REInsideUnit[playerid] > 0 && GetPlayerInterior(playerid) == RE_OFFICE_INTERIOR &&
        IsPlayerInRangeOfPoint(playerid, 4.0, RE_OFFICE_X, RE_OFFICE_Y, RE_OFFICE_Z))
    {
        SetPlayerInterior(playerid, RE_HALL_INTERIOR);
        SetPlayerVirtualWorld(playerid, RE_WORLD_BASE + g_REPlayerBuilding[playerid] * 100 + g_REPlayerFloor[playerid]);
        new door = g_REPendingDoor[playerid] - 1;
        SetPlayerPos(playerid, g_REDoorPos[door][0],
            g_REDoorPos[door][1] + (door < 5 ? 1.0 : -1.0), g_REDoorPos[door][2]);
        g_REInsideUnit[playerid] = 0;
        return 1;
    }
    if (!g_REInsideUnit[playerid] && GetPlayerInterior(playerid) == RE_OFFICE_INTERIOR &&
        GetPlayerVirtualWorld(playerid) >= RE_WORLD_BASE + 900 &&
        IsPlayerInRangeOfPoint(playerid, 4.0, RE_OFFICE_X, RE_OFFICE_Y, RE_OFFICE_Z))
        return RE_TryLeaveRecoveredInterior(playerid);
    if (GetPlayerInterior(playerid) == 0)
    {
        if (IsPlayerInRangeOfPoint(playerid, 2.5, RE_APARTMENT_X, RE_APARTMENT_Y, RE_APARTMENT_Z))
            return SendClientMessage(playerid, 0x35AEE2FF, "Arcadia Residential Group dang hoan thien ho so va thiet ke du an apartment. Door da hoat dong; noi that va can ho se duoc mo sau.");
        for (new building; building < RE_BUILDING_COUNT; building++)
            if (IsPlayerInRangeOfPoint(playerid, 2.5, g_REBuilding[building][reX], g_REBuilding[building][reY], g_REBuilding[building][reZ]))
            {
                g_REPlayerBuilding[playerid] = building;
                g_REPlayerFloor[playerid] = 1;
                SetPlayerInterior(playerid, RE_HALL_INTERIOR);
                SetPlayerVirtualWorld(playerid, RE_WORLD_BASE + building * 100 + 1);
                SetPlayerPos(playerid, RE_HALL_X, RE_HALL_Y, RE_HALL_Z);
                SetPlayerFacingAngle(playerid, RE_HALL_A);
                return RE_ShowElevator(playerid);
            }
    }
    if (GetPlayerInterior(playerid) == RE_HALL_INTERIOR && GetPlayerVirtualWorld(playerid) >= RE_WORLD_BASE)
    {
        RE_RecoverHallContext(playerid);
        if (IsPlayerInRangeOfPoint(playerid, 4.0, RE_HALL_X, RE_HALL_Y, RE_HALL_Z))
            return RE_ShowElevator(playerid);
        for (new unit; unit < 8; unit++) if (IsPlayerInRangeOfPoint(playerid, 2.0, g_REDoorPos[unit][0], g_REDoorPos[unit][1], g_REDoorPos[unit][2]))
        {
            new building = g_REPlayerBuilding[playerid];
            if (g_REPlayerFloor[playerid] == g_REBuilding[building][reFloors])
            {
                if (g_PlayerCompanyID[playerid] != g_REBuilding[building][reCompanyID] && !g_AdminCompanyOverride[playerid])
                    return SendClientMessage(playerid, COLOR_RED, "Tang cao nhat la tru so rieng cua Company bat dong san so huu toa nha.");
                g_REInsideUnit[playerid] = 999999;
                g_REPendingDoor[playerid] = 1;
                SetPlayerInterior(playerid, RE_OFFICE_INTERIOR);
                SetPlayerVirtualWorld(playerid, RE_WORLD_BASE + 900 + building);
                SetPlayerPos(playerid, RE_OFFICE_X, RE_OFFICE_Y, RE_OFFICE_Z);
                SetPlayerFacingAngle(playerid, 0.0);
                return 1;
            }
            return RE_CheckDoorAccess(playerid, building, g_REPlayerFloor[playerid], unit + 1);
        }
    }
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    #pragma unused inputtext
    if (dialogid == DIALOG_RE_OFFICE_CHOICE)
    {
        if (!response) return 1;
        if (listitem == 0)
        {
            g_REOfficeMode[playerid] = 1;
            GetPlayerPos(playerid, g_CompanyPendingX[playerid], g_CompanyPendingY[playerid], g_CompanyPendingZ[playerid]);
            GetPlayerFacingAngle(playerid, g_CompanyPendingA[playerid]);
            return Company_CreateAtPendingPosition(playerid);
        }
        g_REOfficeMode[playerid] = 2;
        return RE_ShowBuildings(playerid);
    }
    if (dialogid == DIALOG_RE_BUILDINGS)
    {
        if (!response) return RealEstate_ShowOfficeChoice(playerid);
        if (listitem < 0 || listitem >= RE_BUILDING_COUNT) return 1;
        g_RESelectedBuilding[playerid] = listitem;
        return RE_LoadVacantUnits(playerid);
    }
    if (dialogid == DIALOG_RE_UNITS)
    {
        if (!response) return RealEstate_ShowOfficeChoice(playerid);
        if (listitem < 0 || listitem >= g_REUnitRows[playerid]) return 1;
        g_RESelectedUnit[playerid] = g_REUnitID[playerid][listitem];
        g_RESelectedFloor[playerid] = g_REUnitFloor[playerid][listitem];
        g_RESelectedNumber[playerid] = g_REUnitNumber[playerid][listitem];
        g_RESelectedSeller[playerid] = g_REBuilding[g_RESelectedBuilding[playerid]][reCompanyID];
        g_RESelectedRent[playerid] = RE_TOWER_RENT;
        return Company_CreateAtPendingPosition(playerid);
    }
    if (dialogid == DIALOG_RE_ELEVATOR)
    {
        if (!response) return 1;
        new building = g_REPlayerBuilding[playerid], floors = g_REBuilding[building][reFloors];
        if (listitem == floors)
        {
            SetPlayerInterior(playerid, 0);
            SetPlayerVirtualWorld(playerid, 0);
            SetPlayerPos(playerid, g_REBuilding[building][reX], g_REBuilding[building][reY], g_REBuilding[building][reZ]);
            g_REPlayerFloor[playerid] = 0;
            return 1;
        }
        new floor = listitem + 1;
        if (floor < 1 || floor > floors) return 1;
        g_REPlayerFloor[playerid] = floor;
        SetPlayerInterior(playerid, RE_HALL_INTERIOR);
        SetPlayerVirtualWorld(playerid, RE_WORLD_BASE + building * 100 + floor);
        SetPlayerPos(playerid, RE_HALL_X, RE_HALL_Y, RE_HALL_Z);
        SetPlayerFacingAngle(playerid, RE_HALL_A);
        new notice[144];
        format(notice, sizeof(notice), "Thang may da dua ban den tang %d/%d cua %s Tower. Tang cao nhat la tru so; moi tang con lai co 8 van phong.", floor, floors, g_REBuilding[building][reName]);
        SendClientMessage(playerid, 0x35AEE2FF, notice);
        return 1;
    }
    return 0;
}
