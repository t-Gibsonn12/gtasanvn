#include <YSI_Coding\y_hooks>

// Houses are developed and permanently managed by real-estate companies.
// Every house has a unique virtual world, while ownership belongs to a character.
#define RE_HOUSE_MAX                 (300)
#define RE_HOUSE_WORLD_BASE          (50000)
#define RE_HOUSE_RANGE               (2.5)
#define RE_HOUSE_SMALL_COST          (1000000)
#define RE_HOUSE_MEDIUM_COST         (5000000)
#define RE_HOUSE_BIG_COST            (10000000)

enum E_RE_HOUSE
{
    rhDatabaseID,
    rhCompanyID,
    rhOwnerCharacter,
    rhSize,
    rhInterior,
    rhConstructionCost,
    rhPrice,
    rhStatus,
    rhSalesCharacter,
    rhCompanyName[48],
    rhSalesName[32],
    Float:rhX,
    Float:rhY,
    Float:rhZ,
    Float:rhA,
    rhPickup,
    Text3D:rhLabel
};
new g_REHouse[RE_HOUSE_MAX][E_RE_HOUSE];
new g_REHouseCount;
new g_REHouseInside[MAX_PLAYERS] = {-1, ...};
new g_REHousePendingSize[MAX_PLAYERS];
new g_REHousePendingCost[MAX_PLAYERS];
new g_REHousePendingPrice[MAX_PLAYERS];
new Float:g_REHousePendingX[MAX_PLAYERS];
new Float:g_REHousePendingY[MAX_PLAYERS];
new Float:g_REHousePendingZ[MAX_PLAYERS];
new Float:g_REHousePendingA[MAX_PLAYERS];
new g_REHouseBuySlot[MAX_PLAYERS] = {-1, ...};

forward public REHouse_OnLoaded();
forward public REHouse_OnCreated(playerid);
forward public REHouse_OnCompanyListLoaded(playerid);
forward public REHouse_OnPurchased(playerid, slot);
forward public REHouse_OnSalesAgentLoaded(playerid, slot, characterid);

stock REHouse_IsInside(playerid)
{
    if (g_REHouseInside[playerid] < 0)
    {
        new databaseID = GetPlayerVirtualWorld(playerid) - RE_HOUSE_WORLD_BASE;
        if (databaseID > 0)
            for (new i; i < g_REHouseCount; i++)
                if (g_REHouse[i][rhDatabaseID] == databaseID)
                {
                    g_REHouseInside[playerid] = i;
                    break;
                }
    }
    return g_REHouseInside[playerid] >= 0;
}

stock REHouse_GetTemplate(size, &interior, &Float:x, &Float:y, &Float:z, &Float:a)
{
    switch (size)
    {
        case 1: { interior = 1; x = 223.0439; y = 1289.2599; z = 1082.1999; a = 180.0; }
        case 2: { interior = 5; x = 226.2939; y = 1114.1260; z = 1080.9952; a = 270.0; }
        default: { interior = 5; x = 140.3679; y = 1366.2177; z = 1083.8594; a = 0.0; }
    }
    return 1;
}

stock REHouse_GetSizeName(size, output[], length)
{
    switch (size)
    {
        case 1: format(output, length, "SMALL");
        case 2: format(output, length, "MEDIUM");
        default: format(output, length, "BIG");
    }
    return 1;
}

stock REHouse_UpdateLabel(slot)
{
    if (slot < 0 || slot >= g_REHouseCount) return 0;
    if (_:g_REHouse[slot][rhLabel] != _:Text3D:INVALID_3DTEXT_ID)
        Delete3DTextLabel(g_REHouse[slot][rhLabel]);
    new sizeName[16], priceText[24], label[384], salesDisplay[64];
    REHouse_GetSizeName(g_REHouse[slot][rhSize], sizeName, sizeof(sizeName));
    Company_FormatMoney(g_REHouse[slot][rhPrice], priceText, sizeof(priceText));
    if (g_REHouse[slot][rhSalesCharacter] > 0)
        format(salesDisplay, sizeof(salesDisplay), "%s (#%d)",
            g_REHouse[slot][rhSalesName], g_REHouse[slot][rhSalesCharacter]);
    else format(salesDisplay, sizeof(salesDisplay), "Phong kinh doanh");
    if (g_REHouse[slot][rhStatus] == 1)
        format(label, sizeof(label), "{68C83B}NHA DANG RAO BAN #%d\n{FFFFFF}%s | Gia: {68C83B}$%s\n{FFFFFF}Cong ty chu quan: %s\nNhan vien kinh doanh: %s\n/muanha de mua | Bam Y de xem",
            g_REHouse[slot][rhDatabaseID], sizeName, priceText,
            g_REHouse[slot][rhCompanyName], salesDisplay);
    else
        format(label, sizeof(label), "{35AEE2}NHA RIENG #%d\n{FFFFFF}%s | Chu so huu: #%d\nBam Y de vao",
            g_REHouse[slot][rhDatabaseID], sizeName, g_REHouse[slot][rhOwnerCharacter]);
    g_REHouse[slot][rhLabel] = Create3DTextLabel(label, COLOR_WHITE,
        g_REHouse[slot][rhX], g_REHouse[slot][rhY], g_REHouse[slot][rhZ] + 0.55, 18.0, 0, false);
    return 1;
}

stock REHouse_CreateRuntime(id, companyid, owner, size, interior, constructionCost, price, status,
    salesCharacter, const companyName[], const salesName[], Float:x, Float:y, Float:z, Float:a)
{
    if (g_REHouseCount >= RE_HOUSE_MAX) return -1;
    new slot = g_REHouseCount++;
    g_REHouse[slot][rhDatabaseID] = id;
    g_REHouse[slot][rhCompanyID] = companyid;
    g_REHouse[slot][rhOwnerCharacter] = owner;
    g_REHouse[slot][rhSize] = size;
    g_REHouse[slot][rhInterior] = interior;
    g_REHouse[slot][rhConstructionCost] = constructionCost;
    g_REHouse[slot][rhPrice] = price;
    g_REHouse[slot][rhStatus] = status;
    g_REHouse[slot][rhSalesCharacter] = salesCharacter;
    format(g_REHouse[slot][rhCompanyName], 48, "%s", companyName);
    format(g_REHouse[slot][rhSalesName], 32, "%s", salesName);
    g_REHouse[slot][rhX] = x;
    g_REHouse[slot][rhY] = y;
    g_REHouse[slot][rhZ] = z;
    g_REHouse[slot][rhA] = a;
    g_REHouse[slot][rhPickup] = CreatePickup(1273, 1, x, y, z, 0);
    g_REHouse[slot][rhLabel] = Text3D:INVALID_3DTEXT_ID;
    REHouse_UpdateLabel(slot);
    new Float:ix, Float:iy, Float:iz, Float:ia, templateInterior;
    REHouse_GetTemplate(size, templateInterior, ix, iy, iz, ia);
    CreatePickup(1318, 1, ix, iy, iz, RE_HOUSE_WORLD_BASE + id);
    Create3DTextLabel("{FFFFFF}CUA RA\nBam {68C83B}Y {FFFFFF}de tro ra exterior",
        COLOR_WHITE, ix, iy, iz + 0.45, 10.0, RE_HOUSE_WORLD_BASE + id, false);
    return slot;
}

stock REHouse_FindNearest(playerid)
{
    if (GetPlayerInterior(playerid) != 0 || GetPlayerVirtualWorld(playerid) != 0) return -1;
    for (new i; i < g_REHouseCount; i++)
        if (IsPlayerInRangeOfPoint(playerid, RE_HOUSE_RANGE,
            g_REHouse[i][rhX], g_REHouse[i][rhY], g_REHouse[i][rhZ])) return i;
    return -1;
}

stock RealEstateHouse_ShowAssets(playerid)
{
    ShowPlayerDialog(playerid, DIALOG_RE_ASSET_TYPES, DIALOG_STYLE_LIST,
        "Company BDS | Quan ly danh muc tai san",
        "Can ho / van phong\tHe thong toa nha\nNha o\tHouse do Company xay dung\nGarage\tSe hoan thien o phien ban sau\nKhu dat nong nghiep\tSe hoan thien o phien ban sau",
        "Xem", "Quay lai");
    return 1;
}

stock RealEstateHouse_ShowBuildMenu(playerid)
{
    if (g_PlayerCompanyType[playerid] != 5 || g_PlayerCompanyRank[playerid] < 5)
        return SendClientMessage(playerid, COLOR_RED, "Chi Giam doc Company bat dong san moi duoc phe duyet du an nha o.");
    if (GetPlayerInterior(playerid) != 0 || GetPlayerVirtualWorld(playerid) != 0)
        return SendClientMessage(playerid, COLOR_RED, "Hay dung tai exterior vi tri dat door can nha truoc khi xay dung.");
    GetPlayerPos(playerid, g_REHousePendingX[playerid], g_REHousePendingY[playerid], g_REHousePendingZ[playerid]);
    GetPlayerFacingAngle(playerid, g_REHousePendingA[playerid]);
    ShowPlayerDialog(playerid, DIALOG_RE_HOUSE_SIZE, DIALOG_STYLE_TABLIST_HEADERS,
        "Company BDS | Chon quy mo va noi that",
        "Quy mo\tNoi that\tChi phi xay dung\nSMALL\tCan ho nho, noi that co ban\t$1.000.000\nMEDIUM\tNha gia dinh, noi that tieu chuan\t$5.000.000\nBIG\tBiet thu, noi that cao cap\t$10.000.000",
        "Chon", "Quay lai");
    return 1;
}

stock REHouse_LoadCompanyList(playerid)
{
    new query[384];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT `house_id`,`size`,`sale_price`,`status`,`owner_character_id`,`salesperson_character_id`,`exterior_x`,`exterior_y`,`exterior_z` FROM `real_estate_houses` WHERE `manager_company_id`=%d ORDER BY `house_id` DESC LIMIT 100",
        g_PlayerCompanyID[playerid]);
    mysql_tquery(g_DatabaseHandle, query, "REHouse_OnCompanyListLoaded", "d", playerid);
    return 1;
}

public REHouse_OnCompanyListLoaded(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    new rows = cache_num_rows(), body[5000];
    format(body, sizeof(body), "Nha\tQuy mo\tGia ban\tTinh trang\n");
    for (new i; i < rows; i++)
    {
        new id, size, price, owner, status[16], sizeName[16], priceText[24], display[32], color[12];
        cache_get_value_name_int(i, "house_id", id);
        cache_get_value_name_int(i, "size", size);
        cache_get_value_name_int(i, "sale_price", price);
        cache_get_value_name_int(i, "owner_character_id", owner);
        cache_get_value_name(i, "status", status, sizeof(status));
        REHouse_GetSizeName(size, sizeName, sizeof(sizeName));
        Company_FormatMoney(price, priceText, sizeof(priceText));
        if (!strcmp(status, "FOR_SALE", true)) { format(color, sizeof(color), "{F5C542}"); format(display, sizeof(display), "Dang rao ban"); }
        else { format(color, sizeof(color), "{68C83B}"); format(display, sizeof(display), "Da duoc mua (#%d)", owner); }
        format(body, sizeof(body), "%s%s#%d\t%s\t$%s\t%s\n", body, color, id, sizeName, priceText, display);
    }
    if (!rows) format(body, sizeof(body), "Company chua xay dung can nha nao.");
    ShowPlayerDialog(playerid, DIALOG_RE_HOUSE_LIST, DIALOG_STYLE_TABLIST_HEADERS,
        "Company BDS | Danh sach nha dang quan ly", body, "Quay lai", "Dong");
    return 1;
}

stock REHouse_Enter(playerid, slot)
{
    if (slot < 0 || slot >= g_REHouseCount) return 0;
    if (g_REHouse[slot][rhStatus] == 1)
        SendClientMessage(playerid, 0xF5C542FF, "Day la nha mau dang rao ban. Su dung /muanha tai exterior neu ban muon ky hop dong mua.");
    new Float:x, Float:y, Float:z, Float:a, interior;
    REHouse_GetTemplate(g_REHouse[slot][rhSize], interior, x, y, z, a);
    g_REHouseInside[playerid] = slot;
    SetPlayerInterior(playerid, interior);
    SetPlayerVirtualWorld(playerid, RE_HOUSE_WORLD_BASE + g_REHouse[slot][rhDatabaseID]);
    SetPlayerPos(playerid, x, y, z);
    SetPlayerFacingAngle(playerid, a);
    SetCameraBehindPlayer(playerid);
    return 1;
}

stock REHouse_Leave(playerid)
{
    new slot = g_REHouseInside[playerid];
    if (slot < 0 || slot >= g_REHouseCount) return 0;
    SetPlayerInterior(playerid, 0);
    SetPlayerVirtualWorld(playerid, 0);
    SetPlayerPos(playerid, g_REHouse[slot][rhX], g_REHouse[slot][rhY] - 1.2, g_REHouse[slot][rhZ]);
    SetPlayerFacingAngle(playerid, g_REHouse[slot][rhA]);
    SetCameraBehindPlayer(playerid);
    g_REHouseInside[playerid] = -1;
    return 1;
}

CMD:muanha(playerid, params[])
{
    #pragma unused params
    if (!IsPlayerCharacterLoaded(playerid))
        return SendClientMessage(playerid, COLOR_RED, "Ban phai dang nhap nhan vat truoc khi mua nha.");
    new slot = REHouse_FindNearest(playerid);
    if (slot < 0 || g_REHouse[slot][rhStatus] != 1)
        return SendClientMessage(playerid, COLOR_RED, "Ban khong dung tai mot can nha dang duoc Company bat dong san rao ban.");
    if (GetPlayerMoney(playerid) < g_REHouse[slot][rhPrice])
        return SendClientMessage(playerid, COLOR_RED, "Tien mat cua ban khong du de thanh toan toan bo gia tri can nha.");
    g_REHouseBuySlot[playerid] = slot;
    new priceText[24], body[512];
    Company_FormatMoney(g_REHouse[slot][rhPrice], priceText, sizeof(priceText));
    format(body, sizeof(body), "HOP DONG MUA BAN NHA #%d\n\nGia niem yet: $%s\nThue giao dich: 5%% do ben ban chiu\nQuyen so huu: Vinh vien\nDon vi quan ly: Company BDS #%d\n\nXac nhan ky hop dong va thanh toan?",
        g_REHouse[slot][rhDatabaseID], priceText, g_REHouse[slot][rhCompanyID]);
    ShowPlayerDialog(playerid, DIALOG_RE_HOUSE_BUY_CONFIRM, DIALOG_STYLE_MSGBOX,
        "Los Santos Property Registry", body, "Ky hop dong", "Huy");
    return 1;
}

CMD:setnvbanhang(playerid, params[])
{
    if (g_PlayerCompanyType[playerid] != 5 || g_PlayerCompanyRank[playerid] < 5)
        return SendClientMessage(playerid, COLOR_RED, "Chi Giam doc Company BDS moi duoc phan cong nhan vien kinh doanh.");
    new offset, houseText[16], characterText[16];
    if (!Company_ReadCommandToken(params, offset, houseText, sizeof(houseText)) ||
        !Company_ReadCommandToken(params, offset, characterText, sizeof(characterText)))
        return SendClientMessage(playerid, COLOR_WHITE, "Su dung: /setnvbanhang [house ID] [character ID]. Nhap character ID 0 de giao cho Phong kinh doanh.");
    new houseid = strval(houseText), characterid = strval(characterText), slot = -1;
    for (new i; i < g_REHouseCount; i++)
        if (g_REHouse[i][rhDatabaseID] == houseid &&
            g_REHouse[i][rhCompanyID] == g_PlayerCompanyID[playerid]) { slot = i; break; }
    if (slot < 0)
        return SendClientMessage(playerid, COLOR_RED, "Khong tim thay can nha thuoc Company BDS cua ban.");
    if (g_REHouse[slot][rhStatus] != 1)
        return SendClientMessage(playerid, COLOR_RED, "Chi co the phan cong nhan vien cho nha dang rao ban.");
    if (characterid == 0)
    {
        new query[256];
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "UPDATE `real_estate_houses` SET `salesperson_character_id`=0 WHERE `house_id`=%d", houseid);
        mysql_tquery(g_DatabaseHandle, query);
        g_REHouse[slot][rhSalesCharacter] = 0;
        format(g_REHouse[slot][rhSalesName], 32, "Phong kinh doanh");
        REHouse_UpdateLabel(slot);
        Company_LogByID(g_PlayerCompanyID[playerid], playerid, "house_sales_assignment",
            "Chuyen can nha ve Phong kinh doanh phu trach", 0);
        return SendClientMessage(playerid, 0x68C83BFF, "Can nha da duoc giao lai cho Phong kinh doanh.");
    }
    new query[512];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT ch.`name` FROM `company_members` m INNER JOIN `player_characters` ch ON ch.`character_id`=m.`character_id` WHERE m.`company_id`=%d AND m.`character_id`=%d LIMIT 1",
        g_PlayerCompanyID[playerid], characterid);
    mysql_tquery(g_DatabaseHandle, query, "REHouse_OnSalesAgentLoaded", "ddd", playerid, slot, characterid);
    return 1;
}

public REHouse_OnSalesAgentLoaded(playerid, slot, characterid)
{
    if (!IsPlayerConnected(playerid) || slot < 0 || slot >= g_REHouseCount) return 1;
    if (!cache_num_rows())
        return SendClientMessage(playerid, COLOR_RED, "Character ID nay khong phai nhan vien cua Company BDS.");
    new name[32], query[256], details[192];
    cache_get_value_name(0, "name", name, sizeof(name));
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `real_estate_houses` SET `salesperson_character_id`=%d WHERE `house_id`=%d AND `status`='FOR_SALE'",
        characterid, g_REHouse[slot][rhDatabaseID]);
    mysql_tquery(g_DatabaseHandle, query);
    g_REHouse[slot][rhSalesCharacter] = characterid;
    format(g_REHouse[slot][rhSalesName], 32, "%s", name);
    REHouse_UpdateLabel(slot);
    format(details, sizeof(details), "Phan cong %s (#%d) phu trach kinh doanh nha #%d",
        name, characterid, g_REHouse[slot][rhDatabaseID]);
    Company_LogByID(g_PlayerCompanyID[playerid], playerid, "house_sales_assignment", details, 0);
    SendClientMessage(playerid, 0x68C83BFF, "Da phan cong nhan vien kinh doanh; ten nhan vien da hien tren label nha.");
    return 1;
}

hook OnGameModeInit()
{
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `real_estate_houses` (`house_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,`manager_company_id` INT UNSIGNED NOT NULL,`owner_character_id` INT UNSIGNED NOT NULL DEFAULT 0,`salesperson_character_id` INT UNSIGNED NOT NULL DEFAULT 0,`size` TINYINT UNSIGNED NOT NULL,`interior_id` TINYINT UNSIGNED NOT NULL,`construction_cost` INT UNSIGNED NOT NULL,`sale_price` INT UNSIGNED NOT NULL,`status` ENUM('FOR_SALE','OWNED') NOT NULL DEFAULT 'FOR_SALE',`exterior_x` FLOAT NOT NULL,`exterior_y` FLOAT NOT NULL,`exterior_z` FLOAT NOT NULL,`exterior_a` FLOAT NOT NULL,`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,`sold_at` DATETIME NULL,PRIMARY KEY (`house_id`),KEY (`manager_company_id`,`status`),KEY (`owner_character_id`),KEY (`salesperson_character_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "ALTER TABLE `real_estate_houses` ADD COLUMN IF NOT EXISTS `salesperson_character_id` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `owner_character_id`");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `real_estate_house_transactions` (`transaction_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,`house_id` INT UNSIGNED NOT NULL,`buyer_character_id` INT UNSIGNED NOT NULL,`seller_company_id` INT UNSIGNED NOT NULL,`salesperson_character_id` INT UNSIGNED NOT NULL DEFAULT 0,`gross_amount` INT UNSIGNED NOT NULL,`tax_amount` INT UNSIGNED NOT NULL,`commission_amount` INT UNSIGNED NOT NULL DEFAULT 0,`net_amount` INT UNSIGNED NOT NULL,`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY (`transaction_id`),KEY (`house_id`,`created_at`),KEY (`seller_company_id`,`created_at`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "ALTER TABLE `real_estate_house_transactions` ADD COLUMN IF NOT EXISTS `salesperson_character_id` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `seller_company_id`,ADD COLUMN IF NOT EXISTS `commission_amount` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `tax_amount`");
    mysql_tquery(g_DatabaseHandle,
        "SELECT h.`house_id`,h.`manager_company_id`,h.`owner_character_id`,h.`salesperson_character_id`,h.`size`,h.`interior_id`,h.`construction_cost`,h.`sale_price`,IF(h.`status`='FOR_SALE',1,2) AS `runtime_status`,h.`exterior_x`,h.`exterior_y`,h.`exterior_z`,h.`exterior_a`,c.`name` AS `company_name`,COALESCE(ch.`name`,'Phong kinh doanh') AS `sales_name` FROM `real_estate_houses` h INNER JOIN `companies` c ON c.`company_id`=h.`manager_company_id` LEFT JOIN `player_characters` ch ON ch.`character_id`=h.`salesperson_character_id` ORDER BY h.`house_id` LIMIT 300",
        "REHouse_OnLoaded");
    return 1;
}

public REHouse_OnLoaded()
{
    new rows = cache_num_rows();
    for (new i; i < rows; i++)
    {
        new id, companyid, owner, salesperson, size, interior, constructionCost, price, status;
        new companyName[48], salesName[32];
        new Float:x, Float:y, Float:z, Float:a;
        cache_get_value_name_int(i, "house_id", id);
        cache_get_value_name_int(i, "manager_company_id", companyid);
        cache_get_value_name_int(i, "owner_character_id", owner);
        cache_get_value_name_int(i, "salesperson_character_id", salesperson);
        cache_get_value_name_int(i, "size", size);
        cache_get_value_name_int(i, "interior_id", interior);
        cache_get_value_name_int(i, "construction_cost", constructionCost);
        cache_get_value_name_int(i, "sale_price", price);
        cache_get_value_name_int(i, "runtime_status", status);
        cache_get_value_name(i, "company_name", companyName, sizeof(companyName));
        cache_get_value_name(i, "sales_name", salesName, sizeof(salesName));
        cache_get_value_name_float(i, "exterior_x", x);
        cache_get_value_name_float(i, "exterior_y", y);
        cache_get_value_name_float(i, "exterior_z", z);
        cache_get_value_name_float(i, "exterior_a", a);
        REHouse_CreateRuntime(id, companyid, owner, size, interior, constructionCost, price, status,
            salesperson, companyName, salesName, x, y, z, a);
    }
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    g_REHouseInside[playerid] = -1;
    g_REHouseBuySlot[playerid] = -1;
    return 1;
}

hook OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys)
{
    #pragma unused oldkeys
    if (!(newkeys & KEY_YES) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT) return 1;
    if (REHouse_IsInside(playerid))
    {
        new slot = g_REHouseInside[playerid], Float:x, Float:y, Float:z, Float:a, interior;
        REHouse_GetTemplate(g_REHouse[slot][rhSize], interior, x, y, z, a);
        if (GetPlayerVirtualWorld(playerid) == RE_HOUSE_WORLD_BASE + g_REHouse[slot][rhDatabaseID] &&
            IsPlayerInRangeOfPoint(playerid, 3.0, x, y, z)) return REHouse_Leave(playerid);
    }
    new slot = REHouse_FindNearest(playerid);
    if (slot >= 0) return REHouse_Enter(playerid, slot);
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if (dialogid == DIALOG_RE_ASSET_TYPES)
    {
        if (!response) return Company_ShowBusinessMenu(playerid);
        if (listitem == 0) return Company_LoadBDSUnits(playerid);
        if (listitem == 1) return REHouse_LoadCompanyList(playerid);
        return SendClientMessage(playerid, 0xF5C542FF, "Danh muc nay da hien trong he thong quan ly nhung se duoc hoan thien o phien ban sau.");
    }
    if (dialogid == DIALOG_RE_HOUSE_LIST)
    {
        if (response) return RealEstateHouse_ShowAssets(playerid);
        return 1;
    }
    if (dialogid == DIALOG_RE_HOUSE_SIZE)
    {
        if (!response) return Company_ShowBusinessMenu(playerid);
        g_REHousePendingSize[playerid] = listitem + 1;
        switch (g_REHousePendingSize[playerid])
        {
            case 1: g_REHousePendingCost[playerid] = RE_HOUSE_SMALL_COST;
            case 2: g_REHousePendingCost[playerid] = RE_HOUSE_MEDIUM_COST;
            default: g_REHousePendingCost[playerid] = RE_HOUSE_BIG_COST;
        }
        new costText[24], prompt[384];
        Company_FormatMoney(g_REHousePendingCost[playerid], costText, sizeof(costText));
        format(prompt, sizeof(prompt), "Chi phi xay dung va noi that: $%s\nNhap gia rao ban cua can nha.\nGia ban phai bang hoac cao hon chi phi xay dung:", costText);
        ShowPlayerDialog(playerid, DIALOG_RE_HOUSE_PRICE, DIALOG_STYLE_INPUT,
            "Company BDS | Dinh gia ban", prompt, "Xay dung", "Huy");
        return 1;
    }
    if (dialogid == DIALOG_RE_HOUSE_PRICE)
    {
        if (!response) return Company_ShowBusinessMenu(playerid);
        new price = strval(inputtext), cost = g_REHousePendingCost[playerid];
        if (price < cost || price > 2000000000)
            return SendClientMessage(playerid, COLOR_RED, "Gia rao ban phai cao hon chi phi xay dung va khong vuot qua $2.000.000.000.");
        if (Company_GetBalance(g_PlayerCompanyID[playerid]) < cost)
            return SendClientMessage(playerid, COLOR_RED, "Ngan sach Company khong du thanh toan chi phi xay dung va noi that.");
        g_REHousePendingPrice[playerid] = price;
        new interior, Float:ix, Float:iy, Float:iz, Float:ia, query[768];
        REHouse_GetTemplate(g_REHousePendingSize[playerid], interior, ix, iy, iz, ia);
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "INSERT INTO `real_estate_houses` (`manager_company_id`,`size`,`interior_id`,`construction_cost`,`sale_price`,`exterior_x`,`exterior_y`,`exterior_z`,`exterior_a`) VALUES (%d,%d,%d,%d,%d,%f,%f,%f,%f)",
            g_PlayerCompanyID[playerid], g_REHousePendingSize[playerid], interior, cost, price,
            g_REHousePendingX[playerid], g_REHousePendingY[playerid], g_REHousePendingZ[playerid], g_REHousePendingA[playerid]);
        mysql_tquery(g_DatabaseHandle, query, "REHouse_OnCreated", "d", playerid);
        return 1;
    }
    if (dialogid == DIALOG_RE_HOUSE_BUY_CONFIRM)
    {
        if (!response) { g_REHouseBuySlot[playerid] = -1; return 1; }
        new slot = g_REHouseBuySlot[playerid];
        if (slot < 0 || slot >= g_REHouseCount || g_REHouse[slot][rhStatus] != 1 ||
            GetPlayerMoney(playerid) < g_REHouse[slot][rhPrice])
            return SendClientMessage(playerid, COLOR_RED, "Giao dich khong con hop le hoac so du cua ban da thay doi.");
        new query[384];
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "UPDATE `real_estate_houses` SET `status`='OWNED',`owner_character_id`=%d,`sold_at`=NOW() WHERE `house_id`=%d AND `status`='FOR_SALE'",
            GetPlayerCharacterID(playerid), g_REHouse[slot][rhDatabaseID]);
        mysql_tquery(g_DatabaseHandle, query, "REHouse_OnPurchased", "dd", playerid, slot);
        return 1;
    }
    return 0;
}

public REHouse_OnCreated(playerid)
{
    new id = cache_insert_id();
    if (!id || !IsPlayerConnected(playerid)) return 1;
    new cost = g_REHousePendingCost[playerid], companyid = g_PlayerCompanyID[playerid], query[512];
    Company_AddRuntimeBalance(companyid, -cost);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `companies` SET `bank_balance`=`bank_balance`-%d WHERE `company_id`=%d", cost, companyid);
    mysql_tquery(g_DatabaseHandle, query);
    new interior, Float:ix, Float:iy, Float:iz, Float:ia;
    REHouse_GetTemplate(g_REHousePendingSize[playerid], interior, ix, iy, iz, ia);
    REHouse_CreateRuntime(id, companyid, 0, g_REHousePendingSize[playerid], interior,
        cost, g_REHousePendingPrice[playerid], 1, 0, g_PlayerCompanyName[playerid], "Phong kinh doanh",
        g_REHousePendingX[playerid], g_REHousePendingY[playerid],
        g_REHousePendingZ[playerid], g_REHousePendingA[playerid]);
    new details[240];
    format(details, sizeof(details), "Xay dung nha #%d, quy mo %d, chi phi $%d, gia rao ban $%d",
        id, g_REHousePendingSize[playerid], cost, g_REHousePendingPrice[playerid]);
    Company_LogByID(companyid, playerid, "house_constructed", details, -cost);
    SendClientMessage(playerid, 0x68C83BFF, "Can nha da duoc khoi tao, co virtual world rieng va dang duoc niem yet tren thi truong.");
    return 1;
}

public REHouse_OnPurchased(playerid, slot)
{
    if (!IsPlayerConnected(playerid) || slot < 0 || slot >= g_REHouseCount || cache_affected_rows() != 1)
        return SendClientMessage(playerid, COLOR_RED, "Can nha vua duoc nguoi khac mua; giao dich cua ban da huy va khong bi tru tien.");
    new gross = g_REHouse[slot][rhPrice], tax = gross * 5 / 100;
    new profit = gross - g_REHouse[slot][rhConstructionCost];
    if (profit < 0) profit = 0;
    new salesperson = g_REHouse[slot][rhSalesCharacter];
    new commission = salesperson > 0 ? profit * 15 / 100 : 0;
    new net = gross - tax - commission;
    new companyid = g_REHouse[slot][rhCompanyID], characterid = GetPlayerCharacterID(playerid), query[1024], details[320];
    GivePlayerMoney(playerid, -gross);
    Economy_SaveBalances(playerid);
    Company_AddRuntimeBalance(companyid, net);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `companies` SET `bank_balance`=`bank_balance`+%d WHERE `company_id`=%d", net, companyid);
    mysql_tquery(g_DatabaseHandle, query);
    LSBank_RecordRevenue("real_estate_house_tax", tax, characterid);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `real_estate_house_transactions` (`house_id`,`buyer_character_id`,`seller_company_id`,`salesperson_character_id`,`gross_amount`,`tax_amount`,`commission_amount`,`net_amount`) VALUES (%d,%d,%d,%d,%d,%d,%d,%d)",
        g_REHouse[slot][rhDatabaseID], characterid, companyid, salesperson, gross, tax, commission, net);
    mysql_tquery(g_DatabaseHandle, query);
    if (salesperson > 0)
    {
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "INSERT INTO `company_employee_profiles` (`company_id`,`character_id`,`kpi_points`,`completed_orders`,`payroll_balance`,`bonus_total`) VALUES (%d,%d,1,1,%d,%d) ON DUPLICATE KEY UPDATE `kpi_points`=`kpi_points`+1,`completed_orders`=`completed_orders`+1,`payroll_balance`=`payroll_balance`+%d,`bonus_total`=`bonus_total`+%d",
            companyid, salesperson, commission, commission, commission, commission);
        mysql_tquery(g_DatabaseHandle, query);
    }
    new salesLogName[32];
    if (salesperson > 0) format(salesLogName, sizeof(salesLogName), "%s", g_REHouse[slot][rhSalesName]);
    else format(salesLogName, sizeof(salesLogName), "Phong kinh doanh");
    format(details, sizeof(details), "Ban nha #%d cho character #%d; nhan vien=%s (#%d); gross=$%d; gia_xay=$%d; loi_nhuan=$%d; hoa_hong15=$%d; tax5=$%d; company_net=$%d",
        g_REHouse[slot][rhDatabaseID], characterid,
        salesLogName, salesperson,
        gross, g_REHouse[slot][rhConstructionCost], profit, commission, tax, net);
    Company_LogByID(companyid, playerid, "house_sold", details, net);
    g_REHouse[slot][rhOwnerCharacter] = characterid;
    g_REHouse[slot][rhStatus] = 2;
    REHouse_UpdateLabel(slot);
    g_REHouseBuySlot[playerid] = -1;
    SendClientMessage(playerid, 0x68C83BFF, "Mua nha thanh cong. Quyen so huu vinh vien da duoc dang ky; Company BDS tiep tuc quan ly ho so can nha.");
    return 1;
}
