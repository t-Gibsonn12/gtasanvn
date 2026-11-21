#include <YSI_Coding\y_hooks>

// Company is the legal entity. A company may own many physical branches.
// The first branch is a 24/7 opposite Taxi HQ and uses a private interior world.
#define COMPANY_BRANCH_X              (1833.4200)
#define COMPANY_BRANCH_Y              (-1842.7200)
#define COMPANY_BRANCH_Z              (13.5781)
#define COMPANY_BRANCH_A              (180.0000)
#define COMPANY_BRANCH_RANGE          (2.5)
#define COMPANY_BRANCH_INTERIOR       (6)
#define COMPANY_BRANCH_WORLD          (31001)
#define COMPANY_STORE_X               (-26.6916)
#define COMPANY_STORE_Y               (-55.7149)
#define COMPANY_STORE_Z               (1003.5469)
#define COMPANY_STORE_A               (0.0000)
#define COMPANY_STORE_EXIT_X          (-26.6916)
#define COMPANY_STORE_EXIT_Y          (-58.0000)
#define COMPANY_STORE_EXIT_Z          (1003.5469)

new g_PlayerCompanyID[MAX_PLAYERS];
new g_PlayerCompanyRank[MAX_PLAYERS];
new g_PlayerCompanyLevel[MAX_PLAYERS];
new g_PlayerCompanyBalance[MAX_PLAYERS];
new g_PlayerCompanyName[MAX_PLAYERS][48];
new bool:g_PlayerInsideCompanyBranch[MAX_PLAYERS];

forward public Company_OnMembershipLoaded(playerid);
forward public Company_OnCreated(playerid);
forward public Company_OnPageLoaded(playerid, page);
forward public Company_OnFinanceLoaded(playerid);

stock Company_ResetPlayer(playerid)
{
    g_PlayerCompanyID[playerid] = 0;
    g_PlayerCompanyRank[playerid] = 0;
    g_PlayerCompanyLevel[playerid] = 0;
    g_PlayerCompanyBalance[playerid] = 0;
    g_PlayerCompanyName[playerid][0] = EOS;
    g_PlayerInsideCompanyBranch[playerid] = false;
    return 1;
}

stock Company_LoadForCharacter(playerid)
{
    Company_ResetPlayer(playerid);
    if (!IsPlayerCharacterLoaded(playerid)) return 0;
    new query[512];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT c.`company_id`,c.`name`,c.`level`,c.`bank_balance`,m.`rank` \
        FROM `company_members` m INNER JOIN `companies` c ON c.`company_id`=m.`company_id` \
        WHERE m.`character_id`=%d LIMIT 1",
        GetPlayerCharacterID(playerid));
    mysql_tquery(g_DatabaseHandle, query, "Company_OnMembershipLoaded", "d", playerid);
    return 1;
}

public Company_OnMembershipLoaded(playerid)
{
    if (!IsPlayerConnected(playerid) || !IsPlayerCharacterLoaded(playerid)) return 1;
    if (!cache_num_rows()) return 1;
    cache_get_value_name_int(0, "company_id", g_PlayerCompanyID[playerid]);
    cache_get_value_name_int(0, "rank", g_PlayerCompanyRank[playerid]);
    cache_get_value_name_int(0, "level", g_PlayerCompanyLevel[playerid]);
    cache_get_value_name_int(0, "bank_balance", g_PlayerCompanyBalance[playerid]);
    cache_get_value_name(0, "name", g_PlayerCompanyName[playerid], 48);
    return 1;
}

stock Company_Log(playerid, const action[], const details[], amount = 0)
{
    if (!g_PlayerCompanyID[playerid]) return 0;
    new query[640];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `company_logs` (`company_id`,`actor_character_id`,`action`,`details`,`amount`) \
        VALUES (%d,%d,'%e','%e',%d)",
        g_PlayerCompanyID[playerid], GetPlayerCharacterID(playerid), action, details, amount);
    mysql_tquery(g_DatabaseHandle, query);
    return 1;
}

stock Company_ShowMain(playerid)
{
    if (!IsPlayerCharacterLoaded(playerid))
        return SendClientMessage(playerid, COLOR_RED, "Ban phai chon va tai nhan vat truoc khi su dung he thong Company.");
    if (!g_PlayerCompanyID[playerid])
    {
        ShowPlayerDialog(playerid, DIALOG_COMPANY_CREATE, DIALOG_STYLE_INPUT,
            "Company - Tao doanh nghiep",
            "Nhan vat cua ban chua thuoc Company nao.\nNhap ten Company (3-40 ky tu).\nCompany dau tien se nhan chi nhanh 24/7 mau doi dien HQ Taxi.",
            "Tao", "Dong");
        return 1;
    }
    new title[96];
    format(title, sizeof(title), "Company - %s | Cap %d", g_PlayerCompanyName[playerid], g_PlayerCompanyLevel[playerid]);
    ShowPlayerDialog(playerid, DIALOG_COMPANY_MAIN, DIALOG_STYLE_LIST, title,
        "Thong tin Company\nChi nhanh\nThanh vien\nPhuong tien\nTai chinh\nKho hang\nHop dong\nNang cap\nNhat ky hoat dong",
        "Chon", "Dong");
    return 1;
}

stock Company_Create(playerid, const name[])
{
    if (g_PlayerCompanyID[playerid])
        return SendClientMessage(playerid, COLOR_RED, "Nhan vat cua ban da thuoc mot Company, khong the tao them.");
    new length = strlen(name);
    if (length < 3 || length > 40)
        return SendClientMessage(playerid, COLOR_RED, "Ten Company phai co tu 3 den 40 ky tu.");
    new query[512];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `companies` (`name`,`company_type`,`owner_character_id`) VALUES ('%e',1,%d)",
        name, GetPlayerCharacterID(playerid));
    mysql_tquery(g_DatabaseHandle, query, "Company_OnCreated", "d", playerid);
    return 1;
}

public Company_OnCreated(playerid)
{
    if (!IsPlayerConnected(playerid) || !IsPlayerCharacterLoaded(playerid)) return 1;
    new companyid = cache_insert_id();
    if (!companyid)
        return SendClientMessage(playerid, COLOR_RED, "Khong the tao Company. Ten nay co the da duoc su dung.");
    g_PlayerCompanyID[playerid] = companyid;
    g_PlayerCompanyRank[playerid] = 5;
    g_PlayerCompanyLevel[playerid] = 1;
    g_PlayerCompanyBalance[playerid] = 0;

    new query[768];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `company_members` (`company_id`,`character_id`,`rank`,`title`) VALUES (%d,%d,5,'Chu doanh nghiep')",
        companyid, GetPlayerCharacterID(playerid));
    mysql_tquery(g_DatabaseHandle, query);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `company_branches` SET `company_id`=%d WHERE `branch_id`=1 AND `company_id`=0 LIMIT 1", companyid);
    mysql_tquery(g_DatabaseHandle, query);
    Company_LoadForCharacter(playerid);
    SendClientMessage(playerid, 0x68C83BFF, "Company da duoc tao. Su dung /company de mo toan bo bang quan ly.");
    return 1;
}

stock Company_QueryPage(playerid, page)
{
    new query[640];
    switch (page)
    {
        case 0:
            mysql_format(g_DatabaseHandle, query, sizeof(query),
                "SELECT c.*, (SELECT COUNT(*) FROM `company_members` WHERE `company_id`=c.`company_id`) AS `member_count`, \
                (SELECT COUNT(*) FROM `company_branches` WHERE `company_id`=c.`company_id`) AS `branch_count` \
                FROM `companies` c WHERE c.`company_id`=%d LIMIT 1", g_PlayerCompanyID[playerid]);
        case 1:
            mysql_format(g_DatabaseHandle, query, sizeof(query),
                "SELECT `name`,`branch_type`,`status`,`cash_balance` FROM `company_branches` WHERE `company_id`=%d ORDER BY `branch_id`", g_PlayerCompanyID[playerid]);
        case 2:
            mysql_format(g_DatabaseHandle, query, sizeof(query),
                "SELECT pc.`name`,m.`title`,m.`rank` FROM `company_members` m INNER JOIN `player_characters` pc ON pc.`character_id`=m.`character_id` WHERE m.`company_id`=%d ORDER BY m.`rank` DESC", g_PlayerCompanyID[playerid]);
        case 3:
            mysql_format(g_DatabaseHandle, query, sizeof(query),
                "SELECT `vehicle_id`,`note` FROM `company_vehicles` WHERE `company_id`=%d ORDER BY `id`", g_PlayerCompanyID[playerid]);
        case 5:
            mysql_format(g_DatabaseHandle, query, sizeof(query),
                "SELECT `item_name`,`amount` FROM `company_warehouse` WHERE `company_id`=%d ORDER BY `item_name`", g_PlayerCompanyID[playerid]);
        case 6:
            mysql_format(g_DatabaseHandle, query, sizeof(query),
                "SELECT `title`,`status`,`reward` FROM `company_contracts` WHERE `company_id`=%d ORDER BY `contract_id` DESC LIMIT 20", g_PlayerCompanyID[playerid]);
        case 8:
            mysql_format(g_DatabaseHandle, query, sizeof(query),
                "SELECT `action`,`details`,`amount`,`created_at` FROM `company_logs` WHERE `company_id`=%d ORDER BY `log_id` DESC LIMIT 20", g_PlayerCompanyID[playerid]);
    }
    mysql_tquery(g_DatabaseHandle, query, "Company_OnPageLoaded", "dd", playerid, page);
    return 1;
}

public Company_OnPageLoaded(playerid, page)
{
    if (!IsPlayerConnected(playerid) || !g_PlayerCompanyID[playerid]) return 1;
    new body[1800], rows = cache_num_rows();
    if (page == 0 && rows)
    {
        new owner, level, balance, members, branches, capacity, vehicles;
        cache_get_value_name_int(0, "owner_character_id", owner);
        cache_get_value_name_int(0, "level", level);
        cache_get_value_name_int(0, "bank_balance", balance);
        cache_get_value_name_int(0, "member_count", members);
        cache_get_value_name_int(0, "branch_count", branches);
        cache_get_value_name_int(0, "warehouse_capacity", capacity);
        cache_get_value_name_int(0, "vehicle_limit", vehicles);
        format(body, sizeof(body),
            "Ten: %s\nLoai hinh: Doanh nghiep 24/7\nCap do: %d\nChu so huu ID: %d\nChi nhanh: %d\nThanh vien: %d\nTai khoan Company: $%d\nSuc chua kho: %d\nGioi han phuong tien: %d",
            g_PlayerCompanyName[playerid], level, owner, branches, members, balance, capacity, vehicles);
    }
    else
    {
        for (new row = 0; row < rows; row++)
        {
            new first[64], second[128], number, extra[32];
            switch (page)
            {
                case 1:
                {
                    cache_get_value_name(row, "name", first, sizeof(first));
                    cache_get_value_name_int(row, "status", number);
                    format(second, sizeof(second), "%s - %s\n", first, number ? "Dang hoat dong" : "Tam dong");
                }
                case 2:
                {
                    cache_get_value_name(row, "name", first, sizeof(first));
                    cache_get_value_name(row, "title", extra, sizeof(extra));
                    cache_get_value_name_int(row, "rank", number);
                    format(second, sizeof(second), "%s - %s (Rank %d)\n", first, extra, number);
                }
                case 3:
                {
                    cache_get_value_name_int(row, "vehicle_id", number);
                    cache_get_value_name(row, "note", first, sizeof(first));
                    format(second, sizeof(second), "Vehicle database #%d - %s\n", number, first);
                }
                case 5:
                {
                    cache_get_value_name(row, "item_name", first, sizeof(first));
                    cache_get_value_name_int(row, "amount", number);
                    format(second, sizeof(second), "%s x%d\n", first, number);
                }
                case 6:
                {
                    cache_get_value_name(row, "title", first, sizeof(first));
                    cache_get_value_name(row, "status", extra, sizeof(extra));
                    cache_get_value_name_int(row, "reward", number);
                    format(second, sizeof(second), "%s - %s - $%d\n", first, extra, number);
                }
                case 8:
                {
                    new details[128];
                    cache_get_value_name(row, "action", first, sizeof(first));
                    cache_get_value_name(row, "details", details, sizeof(details));
                    cache_get_value_name_int(row, "amount", number);
                    cache_get_value_name(row, "created_at", extra, sizeof(extra));
                    format(second, sizeof(second), "[%s] %s: %s ($%d)\n", extra, first, details, number);
                }
            }
            strcat(body, second, sizeof(body));
        }
        if (!rows)
        {
            switch (page)
            {
                case 1: format(body, sizeof(body), "Company chua so huu chi nhanh nao.");
                case 2: format(body, sizeof(body), "Company chua co thanh vien.");
                case 3: format(body, sizeof(body), "Company chua co phuong tien.");
                case 5: format(body, sizeof(body), "Kho Company hien dang trong.");
                case 6: format(body, sizeof(body), "Company chua co hop dong.");
                case 8: format(body, sizeof(body), "Company chua co nhat ky hoat dong.");
            }
        }
    }
    new title[96];
    format(title, sizeof(title), "Company - %s", g_PlayerCompanyName[playerid]);
    ShowPlayerDialog(playerid, DIALOG_COMPANY_PAGE, DIALOG_STYLE_MSGBOX, title, body, "Quay lai", "Dong");
    return 1;
}

stock Company_ShowFinance(playerid)
{
    new query[160];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT `bank_balance` FROM `companies` WHERE `company_id`=%d LIMIT 1", g_PlayerCompanyID[playerid]);
    mysql_tquery(g_DatabaseHandle, query, "Company_OnFinanceLoaded", "d", playerid);
    return 1;
}

public Company_OnFinanceLoaded(playerid)
{
    if (!IsPlayerConnected(playerid) || !cache_num_rows()) return 1;
    cache_get_value_name_int(0, "bank_balance", g_PlayerCompanyBalance[playerid]);
    new title[128];
    format(title, sizeof(title), "Tai chinh Company | So du: $%d | Tien mat: $%d", g_PlayerCompanyBalance[playerid], GetPlayerMoney(playerid));
    ShowPlayerDialog(playerid, DIALOG_COMPANY_FINANCE, DIALOG_STYLE_LIST, title,
        "Gui tien mat vao Company\nRut tien khoi Company", "Chon", "Quay lai");
    return 1;
}

stock Company_ShowUpgrade(playerid)
{
    if (g_PlayerCompanyRank[playerid] < 5)
        return SendClientMessage(playerid, COLOR_RED, "Chi chu Company moi co quyen nang cap.");
    if (g_PlayerCompanyLevel[playerid] >= 4)
        return SendClientMessage(playerid, COLOR_RED, "Company da dat cap toi da.");
    new cost = g_PlayerCompanyLevel[playerid] == 1 ? 5000 : (g_PlayerCompanyLevel[playerid] == 2 ? 25000 : 100000);
    new body[384];
    format(body, sizeof(body),
        "Nang Company tu cap %d len cap %d?\nChi phi: $%d tu tai khoan Company.\nMoi cap tang gioi han thanh vien, phuong tien va suc chua kho.",
        g_PlayerCompanyLevel[playerid], g_PlayerCompanyLevel[playerid] + 1, cost);
    ShowPlayerDialog(playerid, DIALOG_COMPANY_UPGRADE, DIALOG_STYLE_MSGBOX, "Company - Nang cap", body, "Nang cap", "Quay lai");
    return 1;
}

stock Company_EnterBranch(playerid)
{
    g_PlayerInsideCompanyBranch[playerid] = true;
    SetPlayerVirtualWorld(playerid, COMPANY_BRANCH_WORLD);
    SetPlayerInterior(playerid, COMPANY_BRANCH_INTERIOR);
    SetPlayerPos(playerid, COMPANY_STORE_X, COMPANY_STORE_Y, COMPANY_STORE_Z);
    SetPlayerFacingAngle(playerid, COMPANY_STORE_A);
    SetCameraBehindPlayer(playerid);
    SendClientMessage(playerid, COLOR_WHITE, "Ban da vao chi nhanh Unity 24/7. Bam Y tai cua de tro ra.");
    return 1;
}

stock Company_LeaveBranch(playerid)
{
    g_PlayerInsideCompanyBranch[playerid] = false;
    SetPlayerInterior(playerid, 0);
    SetPlayerVirtualWorld(playerid, 0);
    SetPlayerPos(playerid, COMPANY_BRANCH_X, COMPANY_BRANCH_Y - 1.5, COMPANY_BRANCH_Z);
    SetPlayerFacingAngle(playerid, COMPANY_BRANCH_A);
    SetCameraBehindPlayer(playerid);
    return 1;
}

CMD:company(playerid, params[])
{
    if (!strlen(params)) return Company_ShowMain(playerid);
    new command[24], value[48], separator = strfind(params, " ");
    if (separator == -1) format(command, sizeof(command), "%s", params);
    else
    {
        strmid(command, params, 0, separator, sizeof(command));
        strmid(value, params, separator + 1, strlen(params), sizeof(value));
    }
    if (!strcmp(command, "create", true))
    {
        if (!strlen(value))
            return ShowPlayerDialog(playerid, DIALOG_COMPANY_CREATE, DIALOG_STYLE_INPUT,
                "Company - Tao doanh nghiep", "Nhap ten Company (3-40 ky tu):", "Tao", "Dong");
        return Company_Create(playerid, value);
    }
    if (!g_PlayerCompanyID[playerid]) return Company_ShowMain(playerid);
    if (!strcmp(command, "info", true)) return Company_QueryPage(playerid, 0);
    if (!strcmp(command, "branches", true)) return Company_QueryPage(playerid, 1);
    if (!strcmp(command, "members", true)) return Company_QueryPage(playerid, 2);
    if (!strcmp(command, "vehicles", true)) return Company_QueryPage(playerid, 3);
    if (!strcmp(command, "finance", true)) return Company_ShowFinance(playerid);
    if (!strcmp(command, "warehouse", true)) return Company_QueryPage(playerid, 5);
    if (!strcmp(command, "contracts", true)) return Company_QueryPage(playerid, 6);
    if (!strcmp(command, "upgrade", true)) return Company_ShowUpgrade(playerid);
    if (!strcmp(command, "logs", true)) return Company_QueryPage(playerid, 8);
    SendClientMessage(playerid, COLOR_RED, "Su dung: /company [create/info/branches/members/vehicles/finance/warehouse/contracts/upgrade/logs]");
    return 1;
}

CMD:gotocompany(playerid, params[])
{
    #pragma unused params
    SetPlayerInterior(playerid, 0);
    SetPlayerVirtualWorld(playerid, 0);
    SetPlayerPos(playerid, COMPANY_BRANCH_X, COMPANY_BRANCH_Y, COMPANY_BRANCH_Z);
    SetPlayerFacingAngle(playerid, COMPANY_BRANCH_A);
    SendClientMessage(playerid, COLOR_WHITE, "Da dich chuyen den chi nhanh Unity 24/7 doi dien HQ Taxi.");
    return 1;
}

hook OnGameModeInit()
{
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `companies` (`company_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,`name` VARCHAR(48) NOT NULL,`company_type` TINYINT UNSIGNED NOT NULL DEFAULT 1,`level` TINYINT UNSIGNED NOT NULL DEFAULT 1,`owner_character_id` INT UNSIGNED NOT NULL,`bank_balance` INT NOT NULL DEFAULT 0,`warehouse_capacity` INT UNSIGNED NOT NULL DEFAULT 100,`vehicle_limit` INT UNSIGNED NOT NULL DEFAULT 3,`member_limit` INT UNSIGNED NOT NULL DEFAULT 5,`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY (`company_id`),UNIQUE KEY `uq_company_name` (`name`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `company_members` (`company_id` INT UNSIGNED NOT NULL,`character_id` INT UNSIGNED NOT NULL,`rank` TINYINT UNSIGNED NOT NULL DEFAULT 1,`title` VARCHAR(32) NOT NULL DEFAULT 'Nhan vien',`joined_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY (`company_id`,`character_id`),UNIQUE KEY `uq_company_character` (`character_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `company_branches` (`branch_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,`company_id` INT UNSIGNED NOT NULL DEFAULT 0,`name` VARCHAR(64) NOT NULL,`branch_type` VARCHAR(24) NOT NULL DEFAULT '24/7',`exterior_x` FLOAT NOT NULL,`exterior_y` FLOAT NOT NULL,`exterior_z` FLOAT NOT NULL,`exterior_a` FLOAT NOT NULL,`interior_id` INT NOT NULL DEFAULT 6,`virtual_world` INT NOT NULL DEFAULT 0,`status` TINYINT NOT NULL DEFAULT 1,`cash_balance` INT NOT NULL DEFAULT 0,PRIMARY KEY (`branch_id`),KEY `idx_branch_company` (`company_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `company_vehicles` (`id` INT UNSIGNED NOT NULL AUTO_INCREMENT,`company_id` INT UNSIGNED NOT NULL,`vehicle_id` INT UNSIGNED NOT NULL,`note` VARCHAR(64) NOT NULL DEFAULT '',PRIMARY KEY (`id`),KEY `idx_company_vehicle` (`company_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `company_warehouse` (`id` INT UNSIGNED NOT NULL AUTO_INCREMENT,`company_id` INT UNSIGNED NOT NULL,`item_name` VARCHAR(64) NOT NULL,`amount` INT UNSIGNED NOT NULL DEFAULT 0,PRIMARY KEY (`id`),KEY `idx_warehouse_company` (`company_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `company_contracts` (`contract_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,`company_id` INT UNSIGNED NOT NULL,`title` VARCHAR(96) NOT NULL,`status` VARCHAR(24) NOT NULL DEFAULT 'Moi',`reward` INT NOT NULL DEFAULT 0,PRIMARY KEY (`contract_id`),KEY `idx_contract_company` (`company_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `company_logs` (`log_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,`company_id` INT UNSIGNED NOT NULL,`actor_character_id` INT UNSIGNED NOT NULL,`action` VARCHAR(32) NOT NULL,`details` VARCHAR(255) NOT NULL DEFAULT '',`amount` INT NOT NULL DEFAULT 0,`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY (`log_id`),KEY `idx_company_logs` (`company_id`,`created_at`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "INSERT IGNORE INTO `company_branches` (`branch_id`,`company_id`,`name`,`branch_type`,`exterior_x`,`exterior_y`,`exterior_z`,`exterior_a`,`interior_id`,`virtual_world`) VALUES (1,0,'Unity 24/7 - Taxi HQ','24/7',1833.4200,-1842.7200,13.5781,180.0,6,31001)");

    CreatePickup(1318, 1, COMPANY_BRANCH_X, COMPANY_BRANCH_Y, COMPANY_BRANCH_Z, 0);
    CreatePickup(1318, 1, COMPANY_STORE_EXIT_X, COMPANY_STORE_EXIT_Y, COMPANY_STORE_EXIT_Z, COMPANY_BRANCH_WORLD);
    Create3DTextLabel("{68C83B}UNITY 24/7\n{FFFFFF}Bam {68C83B}Y {FFFFFF}de vao cua hang", COLOR_WHITE,
        COMPANY_BRANCH_X, COMPANY_BRANCH_Y, COMPANY_BRANCH_Z + 0.5, 15.0, 0, false);
    Create3DTextLabel("{FFFFFF}LOI RA\nBam {68C83B}Y {FFFFFF}de tro ra", COLOR_WHITE,
        COMPANY_STORE_EXIT_X, COMPANY_STORE_EXIT_Y, COMPANY_STORE_EXIT_Z + 0.5, 12.0, COMPANY_BRANCH_WORLD, false);
    return 1;
}

hook OnPlayerConnect(playerid)
{
    Company_ResetPlayer(playerid);
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    Company_ResetPlayer(playerid);
    return 1;
}

hook OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys)
{
    #pragma unused oldkeys
    if (!(newkeys & KEY_YES) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT) return 1;
    if (!g_PlayerInsideCompanyBranch[playerid] &&
        GetPlayerInterior(playerid) == 0 && GetPlayerVirtualWorld(playerid) == 0 &&
        IsPlayerInRangeOfPoint(playerid, COMPANY_BRANCH_RANGE, COMPANY_BRANCH_X, COMPANY_BRANCH_Y, COMPANY_BRANCH_Z))
        return Company_EnterBranch(playerid);
    if (g_PlayerInsideCompanyBranch[playerid] &&
        GetPlayerInterior(playerid) == COMPANY_BRANCH_INTERIOR &&
        GetPlayerVirtualWorld(playerid) == COMPANY_BRANCH_WORLD &&
        IsPlayerInRangeOfPoint(playerid, COMPANY_BRANCH_RANGE, COMPANY_STORE_EXIT_X, COMPANY_STORE_EXIT_Y, COMPANY_STORE_EXIT_Z))
        return Company_LeaveBranch(playerid);
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if (dialogid == DIALOG_COMPANY_CREATE)
    {
        if (response) Company_Create(playerid, inputtext);
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_MAIN)
    {
        if (!response) return 1;
        switch (listitem)
        {
            case 0: Company_QueryPage(playerid, 0);
            case 1: Company_QueryPage(playerid, 1);
            case 2: Company_QueryPage(playerid, 2);
            case 3: Company_QueryPage(playerid, 3);
            case 4: Company_ShowFinance(playerid);
            case 5: Company_QueryPage(playerid, 5);
            case 6: Company_QueryPage(playerid, 6);
            case 7: Company_ShowUpgrade(playerid);
            case 8: Company_QueryPage(playerid, 8);
        }
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_PAGE)
    {
        if (response) Company_ShowMain(playerid);
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_FINANCE)
    {
        if (!response) return Company_ShowMain(playerid);
        if (listitem == 0)
            ShowPlayerDialog(playerid, DIALOG_COMPANY_DEPOSIT, DIALOG_STYLE_INPUT, "Company - Gui tien", "Nhap so tien mat muon gui vao Company:", "Gui", "Quay lai");
        else
            ShowPlayerDialog(playerid, DIALOG_COMPANY_WITHDRAW, DIALOG_STYLE_INPUT, "Company - Rut tien", "Nhap so tien muon rut khoi Company:", "Rut", "Quay lai");
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_DEPOSIT)
    {
        if (!response) return Company_ShowFinance(playerid);
        new amount = strval(inputtext);
        if (amount <= 0 || GetPlayerMoney(playerid) < amount)
            return SendClientMessage(playerid, COLOR_RED, "So tien khong hop le hoac ban khong du tien mat.");
        GivePlayerMoney(playerid, -amount);
        Economy_SaveBalances(playerid);
        g_PlayerCompanyBalance[playerid] += amount;
        new query[192];
        mysql_format(g_DatabaseHandle, query, sizeof(query), "UPDATE `companies` SET `bank_balance`=`bank_balance`+%d WHERE `company_id`=%d", amount, g_PlayerCompanyID[playerid]);
        mysql_tquery(g_DatabaseHandle, query);
        Company_Log(playerid, "finance_deposit", "Gui tien mat vao Company", amount);
        SendClientMessage(playerid, 0x68C83BFF, "Da gui tien vao tai khoan Company. Giao dich da duoc ghi nhat ky.");
        return Company_ShowFinance(playerid);
    }
    if (dialogid == DIALOG_COMPANY_WITHDRAW)
    {
        if (!response) return Company_ShowFinance(playerid);
        if (g_PlayerCompanyRank[playerid] < 4)
            return SendClientMessage(playerid, COLOR_RED, "Ban khong co quyen rut tien Company.");
        new amount = strval(inputtext);
        if (amount <= 0 || amount > g_PlayerCompanyBalance[playerid])
            return SendClientMessage(playerid, COLOR_RED, "So tien rut khong hop le hoac tai khoan Company khong du.");
        GivePlayerMoney(playerid, amount);
        Economy_SaveBalances(playerid);
        g_PlayerCompanyBalance[playerid] -= amount;
        new query[192];
        mysql_format(g_DatabaseHandle, query, sizeof(query), "UPDATE `companies` SET `bank_balance`=`bank_balance`-%d WHERE `company_id`=%d", amount, g_PlayerCompanyID[playerid]);
        mysql_tquery(g_DatabaseHandle, query);
        Company_Log(playerid, "finance_withdraw", "Rut tien khoi Company", -amount);
        SendClientMessage(playerid, 0x68C83BFF, "Da rut tien khoi tai khoan Company. Giao dich da duoc ghi nhat ky.");
        return Company_ShowFinance(playerid);
    }
    if (dialogid == DIALOG_COMPANY_UPGRADE)
    {
        if (!response) return Company_ShowMain(playerid);
        new cost = g_PlayerCompanyLevel[playerid] == 1 ? 5000 : (g_PlayerCompanyLevel[playerid] == 2 ? 25000 : 100000);
        if (g_PlayerCompanyBalance[playerid] < cost)
            return SendClientMessage(playerid, COLOR_RED, "Tai khoan Company khong du tien de nang cap.");
        g_PlayerCompanyBalance[playerid] -= cost;
        g_PlayerCompanyLevel[playerid]++;
        new memberLimit = 5 + ((g_PlayerCompanyLevel[playerid] - 1) * 5);
        new vehicleLimit = 3 + ((g_PlayerCompanyLevel[playerid] - 1) * 3);
        new capacity = 100 * g_PlayerCompanyLevel[playerid];
        new query[384];
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "UPDATE `companies` SET `level`=%d,`bank_balance`=`bank_balance`-%d,`member_limit`=%d,`vehicle_limit`=%d,`warehouse_capacity`=%d WHERE `company_id`=%d",
            g_PlayerCompanyLevel[playerid], cost, memberLimit, vehicleLimit, capacity, g_PlayerCompanyID[playerid]);
        mysql_tquery(g_DatabaseHandle, query);
        Company_Log(playerid, "company_upgrade", "Nang cap quy mo Company", -cost);
        SendClientMessage(playerid, 0x68C83BFF, "Company da duoc nang cap, cac gioi han thanh vien/phuong tien/kho da tang.");
        return Company_ShowMain(playerid);
    }
    return 0;
}
