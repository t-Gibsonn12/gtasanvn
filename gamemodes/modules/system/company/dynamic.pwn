#include <YSI_Coding\y_hooks>

// Dynamic Company core:
// - the owner chooses a business type and places every door;
// - each branch owns its own inventory while money belongs to the Company;
// - retail and vehicle sales pay 5% into the persistent server treasury.
#define COMPANY_TYPE_CONVENIENCE       (1)
#define COMPANY_TYPE_DEALER            (2)
#define COMPANY_TYPE_TRUCKING          (3)
#define COMPANY_TYPE_BANK              (4)
#define COMPANY_MAX_BRANCHES           (100)
#define COMPANY_BRANCH_RANGE           (2.5)
#define COMPANY_WORLD_BASE             (32000)
#define COMPANY_CREATE_COST            (2000000)
#define COMPANY_STORE_BRANCH_COST      (5000000)
#define COMPANY_DEALER_BRANCH_COST     (25000000)
#define COMPANY_TAX_PERCENT            (5)
#define COMPANY_STORE_INTERIOR         (6)
#define COMPANY_STORE_X                (-26.6916)
#define COMPANY_STORE_Y                (-55.7149)
#define COMPANY_STORE_Z                (1003.5469)
#define COMPANY_STORE_EXIT_Y           (-58.0000)
#define COMPANY_MAX_SHOP_ROWS          (32)
#define COMPANY_MAX_RUNTIME_BALANCES   (256)
#define COMPANY_MAX_APPLICATIONS       (100)
#define COMPANY_MAX_PUBLIC_ROWS        (50)

new const E_ITEM_ID:g_CompanySupplierItems[] =
{
    ITEM_WATER_BOTTLE, ITEM_SANDWICH, ITEM_BURGER, ITEM_SODA,
    ITEM_COFFEE, ITEM_DONUT, ITEM_PIZZA_SLICE, ITEM_CIGARETTE,
    ITEM_LIGHTER, ITEM_BANDAGE, ITEM_PAINKILLERS, ITEM_PHONE,
    ITEM_FLASHLIGHT, ITEM_NOTEBOOK, ITEM_PEN
};
new const g_CompanySupplierPrices[] =
{
    8, 12, 15, 8, 10, 6, 12, 2, 15, 15, 20, 150, 40, 8, 2
};

enum E_COMPANY_BRANCH_RUNTIME
{
    cbDatabaseID,
    cbCompanyID,
    cbType,
    cbName[64],
    Float:cbX,
    Float:cbY,
    Float:cbZ,
    Float:cbA,
    cbPickup,
    Text3D:cbLabel
};
new g_CompanyBranch[COMPANY_MAX_BRANCHES][E_COMPANY_BRANCH_RUNTIME];
new g_CompanyBranchCount;

new g_PlayerCompanyID[MAX_PLAYERS];
new g_PlayerCompanyRank[MAX_PLAYERS];
new g_PlayerCompanyType[MAX_PLAYERS];
new g_PlayerCompanyLevel[MAX_PLAYERS];
new g_PlayerCompanyName[MAX_PLAYERS][48];
new g_PlayerCompanyBranch[MAX_PLAYERS] = {-1, ...};

new g_CompanyPendingType[MAX_PLAYERS];
new g_CompanyPendingName[MAX_PLAYERS][48];
new Float:g_CompanyPendingX[MAX_PLAYERS];
new Float:g_CompanyPendingY[MAX_PLAYERS];
new Float:g_CompanyPendingZ[MAX_PLAYERS];
new Float:g_CompanyPendingA[MAX_PLAYERS];

new g_CompanyShopRowID[MAX_PLAYERS][COMPANY_MAX_SHOP_ROWS];
new g_CompanyShopItemID[MAX_PLAYERS][COMPANY_MAX_SHOP_ROWS];
new g_CompanyShopPrice[MAX_PLAYERS][COMPANY_MAX_SHOP_ROWS];
new g_CompanyShopStock[MAX_PLAYERS][COMPANY_MAX_SHOP_ROWS];
new g_CompanyShopRows[MAX_PLAYERS];
new g_CompanySelectedShopRow[MAX_PLAYERS];
new g_CompanyPendingBuyAmount[MAX_PLAYERS];
new E_ITEM_ID:g_CompanyRestockItemID[MAX_PLAYERS];
new g_CompanySelectedVehicleIndex[MAX_PLAYERS];
new g_CompanyVehicleStock[MAX_PLAYERS][DEALERSHIP_VEHICLE_COUNT];
new bool:g_AdminCompanyOverride[MAX_PLAYERS];
new g_CompanyBalanceID[COMPANY_MAX_RUNTIME_BALANCES];
new g_CompanyBalanceValue[COMPANY_MAX_RUNTIME_BALANCES];
new g_CompanyBalanceCount;
new bool:g_CompanyApplicationActive[COMPANY_MAX_APPLICATIONS];
new g_CompanyApplicationCompany[COMPANY_MAX_APPLICATIONS];
new g_CompanyApplicationPlayer[COMPANY_MAX_APPLICATIONS];
new g_CompanyApplicationCharacter[COMPANY_MAX_APPLICATIONS];
new g_CompanyApplicationName[COMPANY_MAX_APPLICATIONS][32];
new g_CompanyPublicRows[MAX_PLAYERS];
new g_CompanyPublicID[MAX_PLAYERS][COMPANY_MAX_PUBLIC_ROWS];
new g_CompanyApplicationRows[MAX_PLAYERS];
new g_CompanyApplicationSlot[MAX_PLAYERS][COMPANY_MAX_APPLICATIONS];

forward public Company_OnMembershipLoaded(playerid);
forward public Company_OnCreated(playerid);
forward public Company_OnBranchCreated(playerid);
forward public Company_OnBranchesLoaded();
forward public Company_OnShopLoaded(playerid, manage);
forward public Company_OnPurchaseStockReserved(playerid);
forward public Company_OnRestockSaved(playerid, itemid, amount, wholesaleCost);
forward public Company_OnTaxLoaded(playerid);
forward public Company_OnDealerStockLoaded(playerid, openShowroom);
forward public Company_OnVehicleImported(playerid, vehicleIndex, amount, totalCost);
forward public Company_OnVehicleLogsLoaded(playerid);
forward public Company_OnAdminOverrideLoaded(playerid);
forward public Company_OnOwnerMembersLoaded(playerid);
forward public Company_OnOwnerContractsLoaded(playerid);
forward public Company_OnOwnerLogsLoaded(playerid);
forward public Company_OnOwnerFleetLoaded(playerid);
forward public Company_OnPublicListLoaded(playerid);
forward public Company_OnApplicationApproved(ownerid, applicantid, companyid);
forward public Company_OnGeneralInfoLoaded(playerid);
forward public Company_OnOfficeInfoLoaded(playerid);
forward public Company_OnRevenueLoaded(playerid);
forward public Company_OnBDSUnitsLoaded(playerid);
forward public Company_OnTruckSummaryLoaded(playerid);
forward Company_LoadBranches();

stock Company_ResetPlayer(playerid)
{
    g_PlayerCompanyID[playerid] = 0;
    g_PlayerCompanyRank[playerid] = 0;
    g_PlayerCompanyType[playerid] = 0;
    g_PlayerCompanyLevel[playerid] = 0;
    g_PlayerCompanyName[playerid][0] = EOS;
    g_PlayerCompanyBranch[playerid] = -1;
    g_CompanyPendingType[playerid] = 0;
    g_CompanyShopRows[playerid] = 0;
    g_AdminCompanyOverride[playerid] = false;
    return 1;
}

stock Company_FindBalanceSlot(companyid)
{
    for (new slot; slot < g_CompanyBalanceCount; slot++)
        if (g_CompanyBalanceID[slot] == companyid) return slot;
    return -1;
}

stock Company_EnsureBalance(companyid, balance)
{
    new slot = Company_FindBalanceSlot(companyid);
    if (slot >= 0)
    {
        g_CompanyBalanceValue[slot] = balance;
        return slot;
    }
    if (companyid <= 0 || g_CompanyBalanceCount >= COMPANY_MAX_RUNTIME_BALANCES) return -1;
    slot = g_CompanyBalanceCount++;
    g_CompanyBalanceID[slot] = companyid;
    g_CompanyBalanceValue[slot] = balance;
    return slot;
}

stock Company_GetBalance(companyid)
{
    new slot = Company_FindBalanceSlot(companyid);
    return slot >= 0 ? g_CompanyBalanceValue[slot] : 0;
}

stock Company_GetTypeName(type, output[], size)
{
    switch (type)
    {
        case COMPANY_TYPE_CONVENIENCE: format(output, size, "Cua hang tien loi");
        case COMPANY_TYPE_DEALER: format(output, size, "Dai ly phuong tien");
        case COMPANY_TYPE_TRUCKING: format(output, size, "Cong ty van tai");
        case COMPANY_TYPE_BANK: format(output, size, "Ngan hang Chinh phu");
        case 5: format(output, size, "Bat dong san");
        default: format(output, size, "Chua xac dinh");
    }
    return 1;
}

stock Company_LoadForCharacter(playerid)
{
    Company_ResetPlayer(playerid);
    if (!IsPlayerCharacterLoaded(playerid)) return 0;
    new query[512];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT c.`company_id`,c.`name`,c.`company_type`,c.`level`,c.`bank_balance`,m.`rank` FROM `company_members` m INNER JOIN `companies` c ON c.`company_id`=m.`company_id` WHERE m.`character_id`=%d LIMIT 1", GetPlayerCharacterID(playerid));
    mysql_tquery(g_DatabaseHandle, query, "Company_OnMembershipLoaded", "d", playerid);
    return 1;
}

public Company_OnMembershipLoaded(playerid)
{
    if (!IsPlayerConnected(playerid) || !cache_num_rows()) return 1;
    cache_get_value_name_int(0, "company_id", g_PlayerCompanyID[playerid]);
    cache_get_value_name_int(0, "rank", g_PlayerCompanyRank[playerid]);
    cache_get_value_name_int(0, "company_type", g_PlayerCompanyType[playerid]);
    cache_get_value_name_int(0, "level", g_PlayerCompanyLevel[playerid]);
    new companyBalance;
    cache_get_value_name_int(0, "bank_balance", companyBalance);
    Company_EnsureBalance(g_PlayerCompanyID[playerid], companyBalance);
    cache_get_value_name(0, "name", g_PlayerCompanyName[playerid], 48);
    return 1;
}

stock Company_CreateRuntimeBranch(id, companyid, type, const name[], Float:x, Float:y, Float:z, Float:a)
{
    if (g_CompanyBranchCount >= COMPANY_MAX_BRANCHES) return -1;
    new slot = g_CompanyBranchCount++;
    g_CompanyBranch[slot][cbDatabaseID] = id;
    g_CompanyBranch[slot][cbCompanyID] = companyid;
    g_CompanyBranch[slot][cbType] = type;
    format(g_CompanyBranch[slot][cbName], 64, "%s", name);
    g_CompanyBranch[slot][cbX] = x;
    g_CompanyBranch[slot][cbY] = y;
    g_CompanyBranch[slot][cbZ] = z;
    g_CompanyBranch[slot][cbA] = a;
    g_CompanyBranch[slot][cbPickup] = CreatePickup(1318, 1, x, y, z, 0);
    new typeName[32], label[192];
    Company_GetTypeName(type, typeName, sizeof(typeName));
    format(label, sizeof(label), "{68C83B}%s\n{FFFFFF}%s\nBam {68C83B}Y {FFFFFF}de tuong tac", name, typeName);
    g_CompanyBranch[slot][cbLabel] = Create3DTextLabel(label, COLOR_WHITE, x, y, z + 0.55, 18.0, 0, false);
    if (type == COMPANY_TYPE_CONVENIENCE)
    {
        new world = COMPANY_WORLD_BASE + id;
        CreatePickup(1318, 1, COMPANY_STORE_X, COMPANY_STORE_EXIT_Y, COMPANY_STORE_Z, world);
        Create3DTextLabel("{FFFFFF}LOI RA\nBam {68C83B}Y {FFFFFF}de roi chi nhanh",
            COLOR_WHITE, COMPANY_STORE_X, COMPANY_STORE_EXIT_Y, COMPANY_STORE_Z + 0.5, 12.0, world, false);
    }
    return slot;
}

public Company_LoadBranches()
{
    mysql_tquery(g_DatabaseHandle,
        "SELECT `branch_id`,`company_id`,`branch_type_id`,`name`,`exterior_x`,`exterior_y`,`exterior_z`,`exterior_a` FROM `company_branches` WHERE `status`=1 ORDER BY `branch_id` LIMIT 100",
        "Company_OnBranchesLoaded");
    return 1;
}

public Company_OnBranchesLoaded()
{
    new rows = cache_num_rows();
    for (new row = 0; row < rows; row++)
    {
        new id, companyid, type, name[64];
        new Float:x, Float:y, Float:z, Float:a;
        cache_get_value_name_int(row, "branch_id", id);
        cache_get_value_name_int(row, "company_id", companyid);
        cache_get_value_name_int(row, "branch_type_id", type);
        cache_get_value_name(row, "name", name, sizeof(name));
        cache_get_value_name_float(row, "exterior_x", x);
        cache_get_value_name_float(row, "exterior_y", y);
        cache_get_value_name_float(row, "exterior_z", z);
        cache_get_value_name_float(row, "exterior_a", a);
        Company_CreateRuntimeBranch(id, companyid, type, name, x, y, z, a);
    }
    return 1;
}

stock Company_FindNearestBranch(playerid)
{
    if (GetPlayerInterior(playerid) != 0 || GetPlayerVirtualWorld(playerid) != 0) return -1;
    for (new i = 0; i < g_CompanyBranchCount; i++)
        if (IsPlayerInRangeOfPoint(playerid, COMPANY_BRANCH_RANGE,
            g_CompanyBranch[i][cbX], g_CompanyBranch[i][cbY], g_CompanyBranch[i][cbZ])) return i;
    return -1;
}

stock Company_MoveDoor(playerid, branchID)
{
    if (g_PlayerCompanyRank[playerid] < 5)
        return SendClientMessage(playerid, COLOR_RED, "Chi chu Company moi duoc thay doi vi tri door.");
    new slot = -1;
    for (new i = 0; i < g_CompanyBranchCount; i++)
        if (g_CompanyBranch[i][cbDatabaseID] == branchID &&
            g_CompanyBranch[i][cbCompanyID] == g_PlayerCompanyID[playerid]) { slot = i; break; }
    if (slot == -1)
        return SendClientMessage(playerid, COLOR_RED, "Khong tim thay chi nhanh thuoc Company voi ID nay.");
    if (GetPlayerInterior(playerid) != 0 || GetPlayerVirtualWorld(playerid) != 0)
        return SendClientMessage(playerid, COLOR_RED, "Ban phai dung o exterior tai vi tri door moi.");
    new Float:x, Float:y, Float:z, Float:a;
    GetPlayerPos(playerid, x, y, z);
    GetPlayerFacingAngle(playerid, a);
    DestroyPickup(g_CompanyBranch[slot][cbPickup]);
    Delete3DTextLabel(g_CompanyBranch[slot][cbLabel]);
    g_CompanyBranch[slot][cbX] = x;
    g_CompanyBranch[slot][cbY] = y;
    g_CompanyBranch[slot][cbZ] = z;
    g_CompanyBranch[slot][cbA] = a;
    g_CompanyBranch[slot][cbPickup] = CreatePickup(1318, 1, x, y, z, 0);
    new typeName[32], label[192];
    Company_GetTypeName(g_CompanyBranch[slot][cbType], typeName, sizeof(typeName));
    format(label, sizeof(label), "{68C83B}%s\n{FFFFFF}%s\nBam {68C83B}Y {FFFFFF}de tuong tac",
        g_CompanyBranch[slot][cbName], typeName);
    g_CompanyBranch[slot][cbLabel] = Create3DTextLabel(label, COLOR_WHITE, x, y, z + 0.55, 18.0, 0, false);
    new query[384];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `company_branches` SET `exterior_x`=%f,`exterior_y`=%f,`exterior_z`=%f,`exterior_a`=%f WHERE `branch_id`=%d AND `company_id`=%d",
        x, y, z, a, branchID, g_PlayerCompanyID[playerid]);
    mysql_tquery(g_DatabaseHandle, query);
    Company_LogByID(g_PlayerCompanyID[playerid], playerid, "branch_door_moved", "Thay doi vi tri exterior door", 0);
    SendClientMessage(playerid, 0x68C83BFF, "Da di chuyen pickup va door chi nhanh den vi tri hien tai.");
    return 1;
}

stock Company_LoadDealerStock(playerid, bool:openShowroom)
{
    new branch = g_PlayerCompanyBranch[playerid];
    if (branch < 0 || g_CompanyBranch[branch][cbType] != COMPANY_TYPE_DEALER) return 0;
    new query[384];
    if (openShowroom)
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "SELECT `model_id`,`amount`,`sale_price` FROM `company_vehicle_stock` WHERE `branch_id`=%d AND `amount`>0",
            g_CompanyBranch[branch][cbDatabaseID]);
    else
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "SELECT `model_id`,`amount`,`sale_price` FROM `company_vehicle_stock` WHERE `branch_id`=%d",
            g_CompanyBranch[branch][cbDatabaseID]);
    mysql_tquery(g_DatabaseHandle, query, "Company_OnDealerStockLoaded", "dd", playerid, openShowroom);
    return 1;
}

public Company_OnDealerStockLoaded(playerid, openShowroom)
{
    if (!IsPlayerConnected(playerid)) return 1;
    for (new index = 0; index < DEALERSHIP_VEHICLE_COUNT; index++)
    {
        g_DealershipBranchStock[playerid][index] = 0;
        g_DealershipBranchPrice[playerid][index] = 0;
        g_CompanyVehicleStock[playerid][index] = 0;
    }
    new rows = cache_num_rows();
    for (new row = 0; row < rows; row++)
    {
        new model, amount, price;
        cache_get_value_name_int(row, "model_id", model);
        cache_get_value_name_int(row, "amount", amount);
        cache_get_value_name_int(row, "sale_price", price);
        for (new index = 0; index < DEALERSHIP_VEHICLE_COUNT; index++)
        {
            if (g_DealershipVehicles[index][dvModelID] != model) continue;
            g_DealershipBranchStock[playerid][index] = amount;
            g_DealershipBranchPrice[playerid][index] = price;
            g_CompanyVehicleStock[playerid][index] = amount;
            break;
        }
    }
    if (openShowroom) return Dealership_Open(playerid);
    new body[1800], modelName[32];
    for (new index = 0; index < DEALERSHIP_VEHICLE_COUNT; index++)
    {
        Dealership_GetModelName(g_DealershipVehicles[index][dvModelID], modelName, sizeof(modelName));
        new salePrice = g_DealershipBranchPrice[playerid][index] > 0 ?
            g_DealershipBranchPrice[playerid][index] : g_DealershipVehicles[index][dvPrice];
        format(body, sizeof(body), "%s%s\tTon: %d\tGia ban: $%d\tGia nhap: $%d\n",
            body, modelName, g_CompanyVehicleStock[playerid][index],
            salePrice, g_DealershipVehicles[index][dvPrice] * 70 / 100);
    }
    ShowPlayerDialog(playerid, DIALOG_COMPANY_VEHICLE_WAREHOUSE, DIALOG_STYLE_LIST,
        "Company | Quan ly kho phuong tien", body, "Quan ly", "Thoat");
    return 1;
}

stock Company_ShowVehicleWarehouse(playerid)
{
    new branch = Company_FindNearestBranch(playerid);
    if (branch < 0 || g_CompanyBranch[branch][cbType] != COMPANY_TYPE_DEALER ||
        g_CompanyBranch[branch][cbCompanyID] != g_PlayerCompanyID[playerid])
        return SendClientMessage(playerid, COLOR_RED, "Ban phai dung tai exterior door cua chi nhanh dai ly thuoc Company.");
    g_PlayerCompanyBranch[playerid] = branch;
    return Company_LoadDealerStock(playerid, false);
}

stock Company_ImportVehicle(playerid, vehicleIndex, amount)
{
    if (vehicleIndex < 0 || vehicleIndex >= DEALERSHIP_VEHICLE_COUNT || amount <= 0 || amount > 1000)
        return SendClientMessage(playerid, COLOR_RED, "So luong xe nhap phai tu 1 den 1,000.");
    new branch = g_PlayerCompanyBranch[playerid];
    if (branch < 0 || g_CompanyBranch[branch][cbCompanyID] != g_PlayerCompanyID[playerid])
        return SendClientMessage(playerid, COLOR_RED, "Chi nhanh dai ly khong hop le.");
    new unitCost = g_DealershipVehicles[vehicleIndex][dvPrice] * 70 / 100;
    new totalCost = unitCost * amount;
    if (Company_GetBalance(g_PlayerCompanyID[playerid]) < totalCost)
        return SendClientMessage(playerid, COLOR_RED, "Tai khoan Company khong du thanh toan lo phuong tien nay.");
    return Trucking_CreateVehicleOrder(playerid, vehicleIndex, amount, totalCost);
}

public Company_OnVehicleImported(playerid, vehicleIndex, amount, totalCost)
{
    if (!IsPlayerConnected(playerid) || cache_affected_rows() < 1)
        return SendClientMessage(playerid, COLOR_RED, "Khong the cap nhat kho phuong tien; Company chua bi tru tien.");
    if (Company_GetBalance(g_PlayerCompanyID[playerid]) < totalCost)
    {
        new branch = g_PlayerCompanyBranch[playerid], rollback[320];
        if (branch >= 0)
        {
            mysql_format(g_DatabaseHandle, rollback, sizeof(rollback),
                "UPDATE `company_vehicle_stock` SET `amount`=GREATEST(`amount`-%d,0) WHERE `branch_id`=%d AND `model_id`=%d",
                amount, g_CompanyBranch[branch][cbDatabaseID],
                g_DealershipVehicles[vehicleIndex][dvModelID]);
            mysql_tquery(g_DatabaseHandle, rollback);
        }
        return SendClientMessage(playerid, COLOR_RED, "So du Company da thay doi trong luc xu ly; lo nhap xe da duoc hoan tac.");
    }
    Company_AddRuntimeBalance(g_PlayerCompanyID[playerid], -totalCost);
    new query[256], details[192];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `companies` SET `bank_balance`=`bank_balance`-%d WHERE `company_id`=%d",
        totalCost, g_PlayerCompanyID[playerid]);
    mysql_tquery(g_DatabaseHandle, query);
    format(details, sizeof(details), "Nhap model=%d amount=%d cost=$%d",
        g_DealershipVehicles[vehicleIndex][dvModelID], amount, totalCost);
    Company_LogByID(g_PlayerCompanyID[playerid], playerid, "vehicle_import", details, -totalCost);
    SendClientMessage(playerid, 0x68C83BFF, "Da nhap lo phuong tien vao kho chi nhanh va tru gia von tu tai khoan Company.");
    Company_LoadDealerStock(playerid, false);
    return 1;
}

stock Company_SetVehicleSalePrice(playerid, vehicleIndex, salePrice)
{
    new branch = g_PlayerCompanyBranch[playerid];
    if (g_PlayerCompanyRank[playerid] < 4)
        return SendClientMessage(playerid, COLOR_RED, "Ban khong co quyen dieu chinh gia ban phuong tien.");
    if (branch < 0 || g_CompanyBranch[branch][cbCompanyID] != g_PlayerCompanyID[playerid] ||
        g_CompanyBranch[branch][cbType] != COMPANY_TYPE_DEALER)
        return SendClientMessage(playerid, COLOR_RED, "Ban phai dung tai exterior chi nhanh Dealer thuoc Company.");
    if (vehicleIndex < 0 || vehicleIndex >= DEALERSHIP_VEHICLE_COUNT) return 0;
    new wholesale = g_DealershipVehicles[vehicleIndex][dvPrice] * 70 / 100;
    if (salePrice < wholesale || salePrice < 1000 || salePrice > 100000)
        return SendClientMessage(playerid, COLOR_RED, "Gia ban phai tu $1,000-$100,000 va khong duoc thap hon gia nhap.");
    new query[512];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `company_vehicle_stock` (`company_id`,`branch_id`,`model_id`,`amount`,`sale_price`,`wholesale_price`) VALUES (%d,%d,%d,0,%d,%d) ON DUPLICATE KEY UPDATE `sale_price`=VALUES(`sale_price`)",
        g_PlayerCompanyID[playerid], g_CompanyBranch[branch][cbDatabaseID],
        g_DealershipVehicles[vehicleIndex][dvModelID], salePrice, wholesale);
    mysql_tquery(g_DatabaseHandle, query);
    g_DealershipBranchPrice[playerid][vehicleIndex] = salePrice;
    new details[160];
    format(details, sizeof(details), "model=%d new_sale_price=$%d",
        g_DealershipVehicles[vehicleIndex][dvModelID], salePrice);
    Company_LogByID(g_PlayerCompanyID[playerid], playerid, "vehicle_price_changed", details, 0);
    SendClientMessage(playerid, 0x68C83BFF, "Da cap nhat gia ban showroom cho mau xe tai chi nhanh nay.");
    return Company_LoadDealerStock(playerid, false);
}

stock Company_ShowVehicleLogs(playerid)
{
    new branch = g_PlayerCompanyBranch[playerid];
    if (branch < 0 || g_CompanyBranch[branch][cbCompanyID] != g_PlayerCompanyID[playerid])
        return SendClientMessage(playerid, COLOR_RED, "Chi nhanh Dealer khong hop le.");
    new query[384];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT `model_id`,`buyer_character_id`,`gross_amount`,`tax_amount`,`net_amount`,`created_at` FROM `company_vehicle_transactions` WHERE `branch_id`=%d ORDER BY `transaction_id` DESC LIMIT 30",
        g_CompanyBranch[branch][cbDatabaseID]);
    mysql_tquery(g_DatabaseHandle, query, "Company_OnVehicleLogsLoaded", "d", playerid);
    return 1;
}

public Company_OnVehicleLogsLoaded(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    new rows = cache_num_rows(), body[1900];
    for (new row = 0; row < rows; row++)
    {
        new model, buyer, gross, tax, net, created[24], modelName[32];
        cache_get_value_name_int(row, "model_id", model);
        cache_get_value_name_int(row, "buyer_character_id", buyer);
        cache_get_value_name_int(row, "gross_amount", gross);
        cache_get_value_name_int(row, "tax_amount", tax);
        cache_get_value_name_int(row, "net_amount", net);
        cache_get_value_name(row, "created_at", created, sizeof(created));
        Dealership_GetModelName(model, modelName, sizeof(modelName));
        format(body, sizeof(body), "%s[%s] %s | Buyer #%d | $%d | Thue $%d | Company $%d\n",
            body, created, modelName, buyer, gross, tax, net);
    }
    if (!rows) format(body, sizeof(body), "Chi nhanh chua co giao dich mua xe nao.");
    ShowPlayerDialog(playerid, DIALOG_COMPANY_VEHICLE_LOGS, DIALOG_STYLE_MSGBOX,
        "Company Dealer | Lich su giao dich", body, "Quay lai", "Dong");
    return 1;
}

stock Company_LogByID(companyid, playerid, const action[], const details[], amount = 0)
{
    new query[640];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `company_logs` (`company_id`,`actor_character_id`,`action`,`details`,`amount`) VALUES (%d,%d,'%e','%e',%d)", companyid,
        IsPlayerCharacterLoaded(playerid) ? GetPlayerCharacterID(playerid) : 0,
        action, details, amount);
    mysql_tquery(g_DatabaseHandle, query);
    return 1;
}

stock Company_AddRuntimeBalance(companyid, amount)
{
    new slot = Company_FindBalanceSlot(companyid);
    if (slot < 0) slot = Company_EnsureBalance(companyid, 0);
    if (slot >= 0) g_CompanyBalanceValue[slot] += amount;
    return 1;
}

stock Company_ShowCreateTypes(playerid)
{
    ShowPlayerDialog(playerid, DIALOG_COMPANY_TYPE, DIALOG_STYLE_LIST,
        "Company - Chon loai hinh kinh doanh",
        "Cua hang tien loi\tKho item, ban le, nhieu chi nhanh\nDai ly phuong tien\tShowroom, ban xe, giao xe tai chi nhanh",
        "Chon", "Dong");
    return 1;
}

stock Company_ShowGuestMenu(playerid)
{
    ShowPlayerDialog(playerid, DIALOG_COMPANY_GUEST, DIALOG_STYLE_LIST,
        "Company | Thi truong lao dong",
        "Danh sach doanh nghiep va nop don xin viec\nThanh lap doanh nghiep moi",
        "Chon", "Dong");
    return 1;
}

stock Company_LoadPublicList(playerid)
{
    mysql_tquery(g_DatabaseHandle,
        "SELECT `company_id`,`name`,`company_type`,`level` FROM `companies` ORDER BY `level` DESC,`name` ASC LIMIT 50",
        "Company_OnPublicListLoaded", "d", playerid);
    return 1;
}

public Company_OnPublicListLoaded(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    new rows = cache_num_rows(), body[3600], name[48], typeName[32], id, type, level;
    g_CompanyPublicRows[playerid] = rows;
    format(body, sizeof(body), "Doanh nghiep\tLoai hinh\tCap\n");
    for (new i; i < rows; i++)
    {
        cache_get_value_name_int(i, "company_id", id);
        cache_get_value_name_int(i, "company_type", type);
        cache_get_value_name_int(i, "level", level);
        cache_get_value_name(i, "name", name, sizeof(name));
        g_CompanyPublicID[playerid][i] = id;
        Company_GetTypeName(type, typeName, sizeof(typeName));
        format(body, sizeof(body), "%s%s\t%s\t%d\n", body, name, typeName, level);
    }
    if (!rows) format(body, sizeof(body), "Chua co doanh nghiep nao dang hoat dong.");
    ShowPlayerDialog(playerid, DIALOG_COMPANY_PUBLIC_LIST, DIALOG_STYLE_TABLIST_HEADERS,
        "Company | Chon noi nop don xin viec", body, "Nop don", "Quay lai");
    return 1;
}

stock Company_SubmitApplication(playerid, companyid)
{
    for (new i; i < COMPANY_MAX_APPLICATIONS; i++)
        if (g_CompanyApplicationActive[i] && g_CompanyApplicationCharacter[i] == GetPlayerCharacterID(playerid))
            return SendClientMessage(playerid, COLOR_RED, "Ban dang co mot don xin viec tam thoi; hay cho doanh nghiep phan hoi hoac /q de huy don.");
    new slot = -1;
    for (new i; i < COMPANY_MAX_APPLICATIONS; i++) if (!g_CompanyApplicationActive[i]) { slot = i; break; }
    if (slot < 0) return SendClientMessage(playerid, COLOR_RED, "He thong don xin viec dang day, vui long thu lai sau.");
    g_CompanyApplicationActive[slot] = true;
    g_CompanyApplicationCompany[slot] = companyid;
    g_CompanyApplicationPlayer[slot] = playerid;
    g_CompanyApplicationCharacter[slot] = GetPlayerCharacterID(playerid);
    format(g_CompanyApplicationName[slot], 32, "%s", s_CharacterName[playerid]);
    SendClientMessage(playerid, 0x68C83BFF, "Don xin viec da gui. Don chi ton tai trong phien choi hien tai va se tu dong mat khi ban /q.");
    for (new i; i < MAX_PLAYERS; i++) if (IsPlayerConnected(i) && g_PlayerCompanyID[i] == companyid && g_PlayerCompanyRank[i] >= 5)
        SendClientMessage(i, 0xF5C542FF, "Company vua nhan mot don xin viec moi. Su dung /company > Thanh vien > Don xin viec de xem.");
    return 1;
}

stock Company_ShowApplications(playerid)
{
    new body[3000], count;
    format(body, sizeof(body), "Nguoi nop don\tTrang thai luu tru\n");
    for (new i; i < COMPANY_MAX_APPLICATIONS; i++) if (g_CompanyApplicationActive[i] && g_CompanyApplicationCompany[i] == g_PlayerCompanyID[playerid])
    {
        g_CompanyApplicationSlot[playerid][count++] = i;
        format(body, sizeof(body), "%s%s\tTam thoi - mat khi /q\n", body, g_CompanyApplicationName[i]);
    }
    g_CompanyApplicationRows[playerid] = count;
    if (!count) format(body, sizeof(body), "Khong co don xin viec nao dang cho.");
    ShowPlayerDialog(playerid, DIALOG_COMPANY_APPLICATIONS, DIALOG_STYLE_TABLIST_HEADERS,
        "Company | Phe duyet don xin viec", body, "Phe duyet", "Quay lai");
    return 1;
}

public Company_OnApplicationApproved(ownerid, applicantid, companyid)
{
    if (!IsPlayerConnected(ownerid)) return 1;
    if (cache_affected_rows() != 1)
        return SendClientMessage(ownerid, COLOR_RED, "Khong the phe duyet: nhan vat da thuoc Company hoac du lieu khong hop le.");
    SendClientMessage(ownerid, 0x68C83BFF, "Da phe duyet don xin viec va them nhan vien vao Company.");
    if (IsPlayerConnected(applicantid))
    {
        Company_LoadForCharacter(applicantid);
        SendClientMessage(applicantid, 0x68C83BFF, "Don xin viec cua ban da duoc phe duyet. Ban da tro thanh nhan vien Company.");
        if (companyid == 900001) Trucking_ApproveCompanyApplicant(applicantid);
    }
    return 1;
}

stock Company_GetDevelopmentName(level, output[], size)
{
    switch (level)
    {
        case 1: format(output, size, "Khoi nghiep - Street Venture");
        case 2: format(output, size, "Dang phat trien - Rising Enterprise");
        case 3: format(output, size, "Da thanh danh - Established Corporation");
        case 4: format(output, size, "Tap doan lon - Metropolitan Holdings");
        default: format(output, size, "De che kinh doanh - Los Santos Business Empire");
    }
    return 1;
}

stock Company_FormatMoney(value, output[], size)
{
    new raw[24], reversed[32], length, out;
    format(raw, sizeof(raw), "%d", value);
    length = strlen(raw);
    for (new i = length - 1, digits; i >= 0 && out < sizeof(reversed) - 1; i--, digits++)
    {
        if (digits && digits % 3 == 0) reversed[out++] = '.';
        reversed[out++] = raw[i];
    }
    for (new i; i < out && i < size - 1; i++) output[i] = reversed[out - i - 1];
    output[out < size ? out : size - 1] = EOS;
    return 1;
}

stock Company_GetFinancialStatus(balance, output[], size)
{
    if (balance < 100000) format(output, size, "Bao dong - thieu thanh khoan");
    else if (balance < 1000000) format(output, size, "Quy mo nho - tai chinh han che");
    else if (balance < 5000000) format(output, size, "On dinh - dang mo rong");
    else if (balance < 20000000) format(output, size, "Thinh vuong - tiem luc tai chinh manh");
    else format(output, size, "Dan dau thi truong - tai san quy mo lon");
    return 1;
}

stock Company_LoadGeneralInfo(playerid)
{
    new query[640];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT c.*,COALESCE(ch.`name`,'Chua bo nhiem') AS `owner_name`,(SELECT COUNT(*) FROM `company_members` m WHERE m.`company_id`=c.`company_id`) AS `employee_count` FROM `companies` c LEFT JOIN `player_characters` ch ON ch.`character_id`=c.`owner_character_id` WHERE c.`company_id`=%d LIMIT 1",
        g_PlayerCompanyID[playerid]);
    mysql_tquery(g_DatabaseHandle, query, "Company_OnGeneralInfoLoaded", "d", playerid);
    return 1;
}

public Company_OnGeneralInfoLoaded(playerid)
{
    if (!IsPlayerConnected(playerid) || !cache_num_rows()) return 1;
    new level, balance, employees, owner[32], created[24], website[80], taxCode[32];
    new development[64], financial[64], balanceText[24], body[1500], typeName[32];
    cache_get_value_name_int(0, "level", level);
    cache_get_value_name_int(0, "bank_balance", balance);
    cache_get_value_name_int(0, "employee_count", employees);
    cache_get_value_name(0, "owner_name", owner, sizeof(owner));
    cache_get_value_name(0, "created_at", created, sizeof(created));
    cache_get_value_name(0, "website", website, sizeof(website));
    cache_get_value_name(0, "tax_code", taxCode, sizeof(taxCode));
    if (!strlen(website)) format(website, sizeof(website), "www.company-%d.ls", g_PlayerCompanyID[playerid]);
    if (!strlen(taxCode)) format(taxCode, sizeof(taxCode), "LS-%06d", g_PlayerCompanyID[playerid]);
    Company_GetDevelopmentName(level, development, sizeof(development));
    Company_GetFinancialStatus(balance, financial, sizeof(financial));
    Company_GetTypeName(g_PlayerCompanyType[playerid], typeName, sizeof(typeName));
    Company_FormatMoney(balance, balanceText, sizeof(balanceText));
    format(body, sizeof(body),
        "HO SO PHAP LY DOANH NGHIEP\n\nTen doanh nghiep: %s\nLoai hinh: %s\nPhan hang: %s\nTinh trang tai chinh: %s\nCap doanh nghiep: %d/5\nNgay thanh lap: %s\nChu so huu/Giam doc: %s\nTong nhan su: %d nguoi\nMa so thue: %s\nWebsite: %s\nNgan sach hien tai: $%s\n\nThong tin nay duoc su dung trong hop dong, hoa don va cac giao dich Company.",
        g_PlayerCompanyName[playerid], typeName, development, financial, level > 5 ? 5 : level,
        created, owner, employees, taxCode, website, balanceText);
    ShowPlayerDialog(playerid, DIALOG_COMPANY_GENERAL_INFO, DIALOG_STYLE_MSGBOX,
        "Company | Thong tin doanh nghiep", body, "Quay lai", "Dong");
    return 1;
}

stock Company_GetBuildingAddress(building, output[], size)
{
    switch (building)
    {
        case 1: format(output, size, "1734 West Market Avenue, Downtown Los Santos");
        case 2: format(output, size, "1684 Commerce Boulevard, Los Santos");
        case 3: format(output, size, "1569 Crown Plaza, Downtown Los Santos");
        case 4: format(output, size, "1564 Temple Financial District, Los Santos");
        case 5: format(output, size, "1495 Kingsley Avenue, Downtown Los Santos");
        case 6: format(output, size, "1499 Arcadia Street, Los Santos");
        default: format(output, size, "Vi tri van phong tu chon, Los Santos");
    }
    return 1;
}

stock Company_LoadOfficeInfo(playerid)
{
    new query[1800];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "(SELECT b.`building_id`,b.`building_name`,b.`owner_company_id`,b.`total_floors`,COALESCE(u.`floor_number`,b.`total_floors`) AS `floor_number`,COALESCE(u.`unit_number`,0) AS `unit_number`,IF(b.`owner_company_id`=%d,1,0) AS `is_hq`,owner.`name` AS `manager_name`,b.`exterior_x`,b.`exterior_y`,b.`exterior_z` FROM `real_estate_buildings` b LEFT JOIN `real_estate_units` u ON u.`building_id`=b.`building_id` AND u.`occupant_company_id`=%d LEFT JOIN `companies` owner ON owner.`company_id`=b.`owner_company_id` WHERE b.`owner_company_id`=%d OR u.`occupant_company_id`=%d) UNION ALL (SELECT 0,'Van phong tu chon',o.`company_id`,1,1,1,0,c.`name`,o.`exterior_x`,o.`exterior_y`,o.`exterior_z` FROM `real_estate_custom_offices` o INNER JOIN `companies` c ON c.`company_id`=o.`company_id` WHERE o.`company_id`=%d) LIMIT 1",
        g_PlayerCompanyID[playerid], g_PlayerCompanyID[playerid], g_PlayerCompanyID[playerid], g_PlayerCompanyID[playerid], g_PlayerCompanyID[playerid]);
    mysql_tquery(g_DatabaseHandle, query, "Company_OnOfficeInfoLoaded", "d", playerid);
    return 1;
}

public Company_OnOfficeInfoLoaded(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    new body[1200];
    if (!cache_num_rows())
    {
        format(body, sizeof(body),
            "Company dang su dung van phong tu chon ngoai he thong toa nha.\n\nChu so huu: %s\nLoai quyen su dung: Van phong phap ly rieng\nTinh trang: Dang hoat dong\n\nVi tri chi tiet da duoc luu trong ho so Company.",
            g_PlayerCompanyName[playerid]);
    }
    else
    {
        new building, floor, unit, floors, isHQ, buildingName[64], manager[48], address[128], officeCode[24];
        new Float:officeX, Float:officeY, Float:officeZ;
        cache_get_value_name_int(0, "building_id", building);
        cache_get_value_name_int(0, "floor_number", floor);
        cache_get_value_name_int(0, "unit_number", unit);
        cache_get_value_name_int(0, "total_floors", floors);
        cache_get_value_name_int(0, "is_hq", isHQ);
        cache_get_value_name(0, "building_name", buildingName, sizeof(buildingName));
        cache_get_value_name(0, "manager_name", manager, sizeof(manager));
        cache_get_value_name_float(0, "exterior_x", officeX);
        cache_get_value_name_float(0, "exterior_y", officeY);
        cache_get_value_name_float(0, "exterior_z", officeZ);
        if (building) Company_GetBuildingAddress(building, address, sizeof(address));
        else format(address, sizeof(address), "Van phong rieng tai %.2f, %.2f, %.2f, Los Santos", officeX, officeY, officeZ);
        if (isHQ) format(officeCode, sizeof(officeCode), "HEADQUARTERS-%02d", floor);
        else format(officeCode, sizeof(officeCode), "PA%d-%02d%02d", building, floor, unit);
        format(body, sizeof(body),
            "THONG TIN VAN PHONG COMPANY\n\nMa van phong: %s\nToa nha: %s Tower\nDia chi: %s\nTang: %d/%d\nPhong: %s\nCompany quan ly toa nha: %s\nQuyen su dung: %s\nHop dong: 99 nam - quyen su dung vinh vien\nTinh trang: Dang hoat dong\n\nHop dong 99 nam chi la ten phap ly; Company so huu quyen su dung van phong khong thoi han.",
            officeCode, buildingName, address, floor, floors, isHQ ? "Tru so chinh" : officeCode,
            manager, isHQ ? "Tru so Company bat dong san" : "Da so huu");
    }
    ShowPlayerDialog(playerid, DIALOG_COMPANY_OFFICE_INFO, DIALOG_STYLE_MSGBOX,
        "Company | Van phong va tru so", body, "Quay lai", "Dong");
    return 1;
}

stock Company_LoadRevenue(playerid)
{
    new query[384];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT COALESCE(SUM(CASE WHEN `amount`>0 THEN `amount` ELSE 0 END),0) AS `revenue`,COALESCE(SUM(CASE WHEN `amount`<0 THEN -`amount` ELSE 0 END),0) AS `expense`,COUNT(*) AS `transactions` FROM `company_logs` WHERE `company_id`=%d",
        g_PlayerCompanyID[playerid]);
    mysql_tquery(g_DatabaseHandle, query, "Company_OnRevenueLoaded", "d", playerid);
    return 1;
}

public Company_OnRevenueLoaded(playerid)
{
    if (!IsPlayerConnected(playerid) || !cache_num_rows()) return 1;
    new revenue, expense, transactions, revenueText[24], expenseText[24], netText[24], body[640];
    cache_get_value_name_int(0, "revenue", revenue);
    cache_get_value_name_int(0, "expense", expense);
    cache_get_value_name_int(0, "transactions", transactions);
    Company_FormatMoney(revenue, revenueText, sizeof(revenueText));
    Company_FormatMoney(expense, expenseText, sizeof(expenseText));
    Company_FormatMoney(revenue - expense, netText, sizeof(netText));
    format(body, sizeof(body), "Tong doanh thu da ghi nhan: $%s\nTong chi phi da ghi nhan: $%s\nKet qua kinh doanh: $%s\nSo giao dich/hoat dong: %d\n\nChi tiet tung giao dich nam trong Ho so luu tru.",
        revenueText, expenseText, netText, transactions);
    ShowPlayerDialog(playerid, DIALOG_COMPANY_PAGE, DIALOG_STYLE_MSGBOX,
        "Company | Bao cao doanh thu", body, "Quay lai", "Dong");
    return 1;
}

stock Company_CountBranches(companyid)
{
    new count;
    for (new i; i < g_CompanyBranchCount; i++)
        if (g_CompanyBranch[i][cbCompanyID] == companyid) count++;
    return count;
}

stock Company_ShowBusinessMenu(playerid)
{
    new title[96], branches = Company_CountBranches(g_PlayerCompanyID[playerid]);
    format(title, sizeof(title), "Hoat dong kinh doanh | %s", g_PlayerCompanyName[playerid]);
    switch (g_PlayerCompanyType[playerid])
    {
        case COMPANY_TYPE_CONVENIENCE:
            ShowPlayerDialog(playerid, DIALOG_COMPANY_BUSINESS, DIALOG_STYLE_LIST, title,
                branches ? "Mo them chi nhanh\tChi phi $5.000.000\nXem ton kho va nhap hang\tPhai o trong chi nhanh\nChinh sua gia san pham\tPhai o trong chi nhanh\nNhat ky hoat dong\tTat ca chi nhanh" :
                "{68C83B}Mo chi nhanh dau tien\tChi phi $5.000.000\nXem ton kho va nhap hang\tChua co chi nhanh\nChinh sua gia san pham\tChua co chi nhanh\nNhat ky hoat dong\tChua co giao dich",
                "Chon", "Quay lai");
        case COMPANY_TYPE_DEALER:
            ShowPlayerDialog(playerid, DIALOG_COMPANY_BUSINESS, DIALOG_STYLE_LIST, title,
                branches ? "Mo them chi nhanh Dealer\tChi phi $25.000.000\nKho phuong tien va nhap xe\tTai exterior Dealer\nChinh sua gia ban xe\tTai exterior Dealer\nNhat ky ban xe\tTheo tung chi nhanh" :
                "{68C83B}Mo chi nhanh Dealer dau tien\tChi phi $25.000.000\nKho phuong tien va nhap xe\tChua co chi nhanh\nChinh sua gia ban xe\tChua co chi nhanh\nNhat ky ban xe\tChua co giao dich",
                "Chon", "Quay lai");
        case COMPANY_TYPE_TRUCKING:
            ShowPlayerDialog(playerid, DIALOG_COMPANY_BUSINESS, DIALOG_STYLE_LIST, title,
                "Tong quan don hang da van chuyen\nDon hang Business dang cho van chuyen\nNhat ky van tai Company",
                "Chon", "Quay lai");
        case COMPANY_TYPE_BANK:
            ShowPlayerDialog(playerid, DIALOG_COMPANY_BUSINESS, DIALOG_STYLE_LIST, title,
                "Quan ly tai chinh va tin dung\nBao cao doanh thu thue/lai suat\nNhat ky hoat dong ngan hang",
                "Chon", "Quay lai");
        default:
            ShowPlayerDialog(playerid, DIALOG_COMPANY_BUSINESS, DIALOG_STYLE_LIST, title,
                "Quan ly tai san\tCan ho / Nha / Garage / Nong nghiep\nXay dung nha\tSmall / Medium / Big\nNhat ky giao dich bat dong san",
                "Chon", "Quay lai");
    }
    return 1;
}

stock Company_LoadBDSUnits(playerid)
{
    new query[640];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT u.`floor_number`,u.`unit_number`,u.`status`,u.`monthly_price`,b.`building_name`,COALESCE(c.`name`,'Chua co') AS `occupant_name` FROM `real_estate_units` u INNER JOIN `real_estate_buildings` b ON b.`building_id`=u.`building_id` LEFT JOIN `companies` c ON c.`company_id`=u.`occupant_company_id` WHERE u.`owner_company_id`=%d ORDER BY u.`floor_number`,u.`unit_number` LIMIT 100",
        g_PlayerCompanyID[playerid]);
    mysql_tquery(g_DatabaseHandle, query, "Company_OnBDSUnitsLoaded", "d", playerid);
    return 1;
}

public Company_OnBDSUnitsLoaded(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    new rows = cache_num_rows(), body[5000];
    format(body, sizeof(body), "Van phong\tKhach hang\tGia\tTinh trang\n");
    for (new i; i < rows; i++)
    {
        new floor, unit, price, status[12], building[48], occupant[48], priceText[24], display[32], color[12];
        cache_get_value_name_int(i, "floor_number", floor);
        cache_get_value_name_int(i, "unit_number", unit);
        cache_get_value_name_int(i, "monthly_price", price);
        cache_get_value_name(i, "status", status, sizeof(status));
        cache_get_value_name(i, "building_name", building, sizeof(building));
        cache_get_value_name(i, "occupant_name", occupant, sizeof(occupant));
        Company_FormatMoney(price, priceText, sizeof(priceText));
        if (!strcmp(status, "VACANT", true)) { format(display, sizeof(display), "Dang rao ban"); format(color, sizeof(color), "{F5C542}"); }
        else if (!strcmp(status, "OWNED", true)) { format(display, sizeof(display), "Da duoc mua (99 nam)"); format(color, sizeof(color), "{68C83B}"); }
        else { format(display, sizeof(display), "Da duoc thue"); format(color, sizeof(color), "{35AEE2}"); }
        format(body, sizeof(body), "%s%s%s %02d-%02d\t%s\t$%s\t%s\n", body, color, building, floor, unit, occupant, priceText, display);
    }
    if (!rows) format(body, sizeof(body), "Company bat dong san nay chua so huu toa nha/van phong nao.");
    ShowPlayerDialog(playerid, DIALOG_COMPANY_BDS_UNITS, DIALOG_STYLE_TABLIST_HEADERS,
        "Company BDS | Danh muc tai san", body, "Quay lai", "Dong");
    return 1;
}

stock Company_LoadTruckSummary(playerid)
{
    mysql_tquery(g_DatabaseHandle,
        "SELECT COUNT(CASE WHEN `status`='COMPLETED' THEN 1 END) AS `completed`,COUNT(CASE WHEN `status`='OPEN' AND `contract_type`='BUSINESS' THEN 1 END) AS `business_open`,COUNT(CASE WHEN `status`='ASSIGNED' THEN 1 END) AS `assigned`,COALESCE(SUM(CASE WHEN `status`='COMPLETED' THEN `reward` ELSE 0 END),0) AS `completed_value` FROM `trucking_contracts`",
        "Company_OnTruckSummaryLoaded", "d", playerid);
    return 1;
}

public Company_OnTruckSummaryLoaded(playerid)
{
    if (!IsPlayerConnected(playerid) || !cache_num_rows()) return 1;
    new completed, businessOpen, assigned, value, valueText[24], body[640];
    cache_get_value_name_int(0, "completed", completed);
    cache_get_value_name_int(0, "business_open", businessOpen);
    cache_get_value_name_int(0, "assigned", assigned);
    cache_get_value_name_int(0, "completed_value", value);
    Company_FormatMoney(value, valueText, sizeof(valueText));
    format(body, sizeof(body), "Tong don hang da van chuyen: %d\nDon Business dang cho tai xe: %d\nDon dang duoc van chuyen: %d\nTong gia tri don hoan thanh: $%s\n\nDon Business duoc tao khi Company 24/7/Dealer dat lo hang va yeu cau Los Santos Logistics van chuyen.",
        completed, businessOpen, assigned, valueText);
    ShowPlayerDialog(playerid, DIALOG_COMPANY_TRUCK_SUMMARY, DIALOG_STYLE_MSGBOX,
        "Company Truck | Tong quan van tai", body, "Quay lai", "Dong");
    return 1;
}

stock Company_ShowMain(playerid)
{
    if (!IsPlayerCharacterLoaded(playerid))
        return SendClientMessage(playerid, COLOR_RED, "Ban phai tai nhan vat truoc khi su dung Company.");
    if (!g_PlayerCompanyID[playerid]) return Company_ShowGuestMenu(playerid);
    new typeName[32], title[128];
    Company_GetTypeName(g_PlayerCompanyType[playerid], typeName, sizeof(typeName));
    format(title, sizeof(title), "%s | %s | Cap %d", g_PlayerCompanyName[playerid], typeName, g_PlayerCompanyLevel[playerid]);
    if (g_PlayerCompanyRank[playerid] < 5 && !g_AdminCompanyOverride[playerid])
        ShowPlayerDialog(playerid, DIALOG_COMPANY_MAIN, DIALOG_STYLE_LIST, title,
            "Thong tin doanh nghiep\nVan phong va tru so", "Chon", "Dong");
    else
        ShowPlayerDialog(playerid, DIALOG_COMPANY_MAIN, DIALOG_STYLE_LIST, title,
            "Thong tin doanh nghiep\nVan phong va tru so\nHoat dong kinh doanh\nTai chinh\nHo so luu tru\nNhan vien",
            "Chon", "Dong");
    return 1;
}

stock Company_ShowOwnerMembers(playerid)
{
    new query[640];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT m.`rank`,m.`title`,m.`joined_at`,ch.`name`,COALESCE(e.`kpi_points`,0) AS `kpi_points`,COALESCE(e.`completed_orders`,0) AS `completed_orders`,COALESCE(e.`payroll_balance`,0) AS `payroll_balance` FROM `company_members` m LEFT JOIN `player_characters` ch ON ch.`character_id`=m.`character_id` LEFT JOIN `company_employee_profiles` e ON e.`company_id`=m.`company_id` AND e.`character_id`=m.`character_id` WHERE m.`company_id`=%d ORDER BY m.`rank` DESC,e.`kpi_points` DESC LIMIT 60",
        g_PlayerCompanyID[playerid]);
    mysql_tquery(g_DatabaseHandle, query, "Company_OnOwnerMembersLoaded", "d", playerid);
    return 1;
}

public Company_OnOwnerMembersLoaded(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    new body[3600], rows = cache_num_rows();
    format(body, sizeof(body), "Nhan vien\tChuc danh\tRank\tKPI\tDon\tTK luong\n");
    for (new i; i < rows; i++)
    {
        new name[32], title[32], rank, kpi, orders, payroll;
        cache_get_value_name(i, "name", name, sizeof(name));
        cache_get_value_name(i, "title", title, sizeof(title));
        cache_get_value_name_int(i, "rank", rank);
        cache_get_value_name_int(i, "kpi_points", kpi);
        cache_get_value_name_int(i, "completed_orders", orders);
        cache_get_value_name_int(i, "payroll_balance", payroll);
        format(body, sizeof(body), "%s%s\t%s\t%d\t%d\t%d\t$%d\n",
            body, name, title, rank, kpi, orders, payroll);
    }
    if (!rows) format(body, sizeof(body), "Company chua co thanh vien.");
    ShowPlayerDialog(playerid, DIALOG_COMPANY_PAGE, DIALOG_STYLE_TABLIST_HEADERS,
        "Quan ly thanh vien Company", body, "Quay lai", "Dong");
    return 1;
}

stock Company_ShowOwnerContracts(playerid)
{
    new query[640];
    if (g_PlayerCompanyID[playerid] == 900001)
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "SELECT `contract_id`,`contract_type`,`cargo_kind`,`cargo_amount`,`reward`,`status`,`created_by`,`created_at` FROM `trucking_contracts` ORDER BY `contract_id` DESC LIMIT 40");
    else
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "SELECT `work_id` AS `contract_id`,'WORK' AS `contract_type`,`work_type` AS `cargo_kind`,1 AS `cargo_amount`,`total_income` AS `reward`,'COMPLETED' AS `status`,'Company' AS `created_by`,`created_at` FROM `company_work_logs` WHERE `company_id`=%d ORDER BY `work_id` DESC LIMIT 40",
            g_PlayerCompanyID[playerid]);
    mysql_tquery(g_DatabaseHandle, query, "Company_OnOwnerContractsLoaded", "d", playerid);
    return 1;
}

public Company_OnOwnerContractsLoaded(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    new body[3600], rows = cache_num_rows();
    format(body, sizeof(body), "ID\tLoai\tHang\tSo luong\tGia tri\tTrang thai\n");
    for (new i; i < rows; i++)
    {
        new id, amount, reward, type[16], cargo[32], status[16];
        cache_get_value_name_int(i, "contract_id", id);
        cache_get_value_name_int(i, "cargo_amount", amount);
        cache_get_value_name_int(i, "reward", reward);
        cache_get_value_name(i, "contract_type", type, sizeof(type));
        cache_get_value_name(i, "cargo_kind", cargo, sizeof(cargo));
        cache_get_value_name(i, "status", status, sizeof(status));
        format(body, sizeof(body), "%s#%d\t%s\t%s\t%d\t$%d\t%s\n",
            body, id, type, cargo, amount, reward, status);
    }
    if (!rows) format(body, sizeof(body), "Company chua co hop dong hoac cong viec nao.");
    ShowPlayerDialog(playerid, DIALOG_COMPANY_PAGE, DIALOG_STYLE_TABLIST_HEADERS,
        "Hop dong va cong viec Company", body, "Quay lai", "Dong");
    return 1;
}

stock Company_ShowOwnerLogs(playerid)
{
    new query[384];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT `actor_character_id`,`action`,`details`,`amount`,`created_at` FROM `company_logs` WHERE `company_id`=%d ORDER BY `log_id` DESC LIMIT 50",
        g_PlayerCompanyID[playerid]);
    mysql_tquery(g_DatabaseHandle, query, "Company_OnOwnerLogsLoaded", "d", playerid);
    return 1;
}

public Company_OnOwnerLogsLoaded(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    new body[3900], rows = cache_num_rows();
    for (new i; i < rows; i++)
    {
        new actor, amount, action[40], details[220], created[24], amountText[24];
        cache_get_value_name_int(i, "actor_character_id", actor);
        cache_get_value_name_int(i, "amount", amount);
        cache_get_value_name(i, "action", action, sizeof(action));
        cache_get_value_name(i, "details", details, sizeof(details));
        cache_get_value_name(i, "created_at", created, sizeof(created));
        Company_FormatMoney(amount, amountText, sizeof(amountText));
        format(body, sizeof(body), "%s[%s] #%d | %s | %s | $%s\n",
            body, created, actor, action, details, amountText);
    }
    if (!rows) format(body, sizeof(body), "Company chua co nhat ky quan ly.");
    ShowPlayerDialog(playerid, DIALOG_COMPANY_PAGE, DIALOG_STYLE_MSGBOX,
        "Company | Ho so luu tru giao dich va hoat dong", body, "Quay lai", "Dong");
    return 1;
}

stock Company_ShowOwnerUpgrade(playerid)
{
    new cost = g_PlayerCompanyLevel[playerid] * 10000, body[512];
    format(body, sizeof(body),
        "NANG CAP COMPANY\n\nCap hien tai: %d\nCap sau nang cap: %d\nChi phi: $%d\n\nMoi cap tang:\n- +5 gioi han thanh vien\n- +3 phuong tien Company\n- +100 suc chua kho\n- Mo rong nang luc hop dong va chi nhanh\n\nChi phi se tru tu tai khoan Company.",
        g_PlayerCompanyLevel[playerid], g_PlayerCompanyLevel[playerid] + 1, cost);
    ShowPlayerDialog(playerid, DIALOG_COMPANY_UPGRADE, DIALOG_STYLE_MSGBOX,
        "Nang cap Company", body, "Nang cap", "Quay lai");
    return 1;
}

stock Company_ShowOwnerFleet(playerid)
{
    new query[512];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT v.`vehicle_id`,v.`model_id`,v.`plate`,v.`storage_state`,v.`company_note`,ch.`name` FROM `player_vehicles` v LEFT JOIN `player_characters` ch ON ch.`character_id`=v.`owner_character_id` WHERE v.`company_vehicle`=1 AND v.`company_id`=%d AND v.`deleted_at` IS NULL ORDER BY v.`vehicle_id` DESC LIMIT 60",
        g_PlayerCompanyID[playerid]);
    mysql_tquery(g_DatabaseHandle, query, "Company_OnOwnerFleetLoaded", "d", playerid);
    return 1;
}

public Company_OnOwnerFleetLoaded(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    new body[3000], rows = cache_num_rows();
    format(body, sizeof(body), "DB ID\tModel\tBien so\tNhan vien\tTrang thai\n");
    for (new i; i < rows; i++)
    {
        new id, model, storage, plate[18], name[32];
        cache_get_value_name_int(i, "vehicle_id", id);
        cache_get_value_name_int(i, "model_id", model);
        cache_get_value_name_int(i, "storage_state", storage);
        cache_get_value_name(i, "plate", plate, sizeof(plate));
        cache_get_value_name(i, "name", name, sizeof(name));
        format(body, sizeof(body), "%s%d\t%d\t%s\t%s\t%s\n",
            body, id, model, plate, name, storage == SIMPLE_VEHICLE_STORED ? "Trong garage" : "Dang hoat dong");
    }
    if (!rows) format(body, sizeof(body), "Company chua cap phuong tien nao cho nhan vien.");
    ShowPlayerDialog(playerid, DIALOG_COMPANY_PAGE, DIALOG_STYLE_TABLIST_HEADERS,
        "Danh sach phuong tien Company", body, "Quay lai", "Dong");
    return 1;
}

stock Company_ShowPlaceConfirmation(playerid, bool:isBranch)
{
    GetPlayerPos(playerid, g_CompanyPendingX[playerid], g_CompanyPendingY[playerid], g_CompanyPendingZ[playerid]);
    GetPlayerFacingAngle(playerid, g_CompanyPendingA[playerid]);
    new body[768], typeName[32];
    Company_GetTypeName(g_CompanyPendingType[playerid], typeName, sizeof(typeName));
    if (isBranch)
    {
        if (g_CompanyPendingType[playerid] == COMPANY_TYPE_DEALER)
            format(body, sizeof(body),
                "HO SO MO CHI NHANH VEHICLE DEALER\n\nPhi mat bang va showroom: $9.000.000\nHa tang, bai xe va an ninh: $4.000.000\nNoi that, bien hieu va thiet bi: $2.500.000\nGiay phep dai ly va dang ki xe: $2.000.000\nBao hiem thuong mai: $1.500.000\nHop dong Logistics: $1.000.000\nTon kho khai truong ngau nhien - 5 xe/mau: $5.000.000\n\nTONG CHI PHI: $25.000.000\nDealer duoc dat tai vi tri hien tai.");
        else
            format(body, sizeof(body),
                "HO SO MO CHI NHANH %s\n\nPhi mat bang va tien coc: $1.500.000\nLap dat ha tang, dien nuoc: $600.000\nThue va thi cong noi that: $550.000\nVan chuyen thiet bi/hang hoa: $350.000\nTon kho khai truong - 30 moi mat hang: $800.000\nGiay phep kinh doanh: $300.000\nGiay phep an toan thuc pham/PCCC: $250.000\nHop dong van chuyen Logistics: $200.000\nBao hiem tai san va lao dong: $200.000\nKiem dinh, bien hieu va phi hanh chinh: $250.000\n\nTONG CHI PHI: $5.000.000\nDoor se dat tai vi tri hien tai; chi phi tru tu ngan sach Company.",
                typeName);
    }
    else
        format(body, sizeof(body),
            "THANH LAP %s\n\nVi tri hien tai se tro thanh door tru so/chi nhanh dau tien.\nDang ky phap nhan: $2,500\nGiay phep nganh nghe: $750\nCoc va thue mat bang: $7,500\nThiet ke - noi that ban dau: $5,000\n\nTONG CHI PHI: $%d (tien mat)\nHay dung chinh xac tai cua toa nha ban muon su dung.",
            typeName, COMPANY_CREATE_COST);
    ShowPlayerDialog(playerid, isBranch ? DIALOG_COMPANY_BRANCH_PLACE : DIALOG_COMPANY_PLACE,
        DIALOG_STYLE_MSGBOX, "Company - Xac nhan vi tri door", body, "Xac nhan", "Huy");
    return 1;
}

stock Company_CreateAtPendingPosition(playerid)
{
    if (GetPlayerMoney(playerid) < COMPANY_CREATE_COST)
        return SendClientMessage(playerid, COLOR_RED, "Ban khong du $2.000.000 von thanh lap Company.");
    new query[640];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `companies` (`name`,`company_type`,`owner_character_id`,`bank_balance`) VALUES ('%e',%d,%d,%d)",
        g_CompanyPendingName[playerid], g_CompanyPendingType[playerid], GetPlayerCharacterID(playerid), COMPANY_CREATE_COST);
    mysql_tquery(g_DatabaseHandle, query, "Company_OnCreated", "d", playerid);
    return 1;
}

public Company_OnCreated(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    new companyid = cache_insert_id();
    if (!companyid) return SendClientMessage(playerid, COLOR_RED, "Khong the tao Company; ten co the da ton tai.");
    GivePlayerMoney(playerid, -COMPANY_CREATE_COST);
    Economy_SaveBalances(playerid);
    g_PlayerCompanyID[playerid] = companyid;
    g_PlayerCompanyRank[playerid] = 5;
    g_PlayerCompanyType[playerid] = g_CompanyPendingType[playerid];
    g_PlayerCompanyLevel[playerid] = 1;
    Company_EnsureBalance(companyid, COMPANY_CREATE_COST);
    format(g_PlayerCompanyName[playerid], 48, "%s", g_CompanyPendingName[playerid]);
    new query[768];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `company_members` (`company_id`,`character_id`,`rank`,`title`) VALUES (%d,%d,5,'Chu doanh nghiep')",
        companyid, GetPlayerCharacterID(playerid));
    mysql_tquery(g_DatabaseHandle, query);
    Company_LogByID(companyid, playerid, "company_created", "Gop von dieu le va thanh lap phap nhan; chua mo chi nhanh kinh doanh", COMPANY_CREATE_COST);
    RealEstate_FinalizeCompanyOffice(playerid, companyid);
    SendClientMessage(playerid, 0x68C83BFF, "Da thanh lap phap nhan Company. Cua hang 24/7/Dealer chua duoc tao; hay mo tung chi nhanh trong /company.");
    return 1;
}

stock Company_CreateBranchAtPendingPosition(playerid)
{
    new cost = g_PlayerCompanyType[playerid] == COMPANY_TYPE_DEALER ? COMPANY_DEALER_BRANCH_COST : COMPANY_STORE_BRANCH_COST;
    if (g_PlayerCompanyRank[playerid] < 5)
        return SendClientMessage(playerid, COLOR_RED, "Chi chu doanh nghiep moi duoc mo chi nhanh.");
    if (Company_GetBalance(g_PlayerCompanyID[playerid]) < cost)
        return SendClientMessage(playerid, COLOR_RED, "Tai khoan Company khong du chi phi mat bang va noi that cho chi nhanh.");
    Company_AddRuntimeBalance(g_PlayerCompanyID[playerid], -cost);
    new branchName[64];
    format(branchName, sizeof(branchName), "%s - Chi nhanh moi", g_PlayerCompanyName[playerid]);
    new query[768];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `company_branches` (`company_id`,`branch_type_id`,`name`,`branch_type`,`exterior_x`,`exterior_y`,`exterior_z`,`exterior_a`) VALUES (%d,%d,'%e','%s',%f,%f,%f,%f)",
        g_PlayerCompanyID[playerid], g_PlayerCompanyType[playerid], branchName,
        g_PlayerCompanyType[playerid] == COMPANY_TYPE_DEALER ? "DEALER" : "24/7",
        g_CompanyPendingX[playerid], g_CompanyPendingY[playerid], g_CompanyPendingZ[playerid], g_CompanyPendingA[playerid]);
    mysql_tquery(g_DatabaseHandle, query, "Company_OnBranchCreated", "d", playerid);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `companies` SET `bank_balance`=`bank_balance`-%d WHERE `company_id`=%d", cost, g_PlayerCompanyID[playerid]);
    mysql_tquery(g_DatabaseHandle, query);
    Company_LogByID(g_PlayerCompanyID[playerid], playerid, "branch_opened",
        "Thanh toan tron goi mo chi nhanh: mat bang, lap dat, noi that, van chuyen, giay phep va ton kho khai truong", -cost);
    return 1;
}

public Company_OnBranchCreated(playerid)
{
    new id = cache_insert_id();
    if (!id || !IsPlayerConnected(playerid)) return 1;
    new name[64];
    if (g_PlayerCompanyID[playerid] && Company_GetBalance(g_PlayerCompanyID[playerid]) >= 0)
        format(name, sizeof(name), "%s - Chi nhanh #%d", g_PlayerCompanyName[playerid], id);
    Company_CreateRuntimeBranch(id, g_PlayerCompanyID[playerid], g_PlayerCompanyType[playerid], name,
        g_CompanyPendingX[playerid], g_CompanyPendingY[playerid], g_CompanyPendingZ[playerid], g_CompanyPendingA[playerid]);
    new query[640];
    if (g_PlayerCompanyType[playerid] == COMPANY_TYPE_CONVENIENCE)
    {
        for (new i; i < sizeof(g_CompanySupplierItems); i++)
        {
            new E_ITEM_ID:itemid = g_CompanySupplierItems[i];
            mysql_format(g_DatabaseHandle, query, sizeof(query),
                "INSERT INTO `company_warehouse` (`company_id`,`branch_id`,`item_id`,`item_name`,`amount`,`unit_price`) VALUES (%d,%d,%d,'%e',30,%d) ON DUPLICATE KEY UPDATE `amount`=GREATEST(`amount`,30),`unit_price`=VALUES(`unit_price`)",
                g_PlayerCompanyID[playerid], id, _:itemid, g_ItemData[itemid][itemName], g_CompanySupplierPrices[i] * 2);
            mysql_tquery(g_DatabaseHandle, query);
        }
    }
    else if (g_PlayerCompanyType[playerid] == COMPANY_TYPE_DEALER)
    {
        for (new i; i < DEALERSHIP_VEHICLE_COUNT; i++)
        {
            if (!random(2)) continue;
            new wholesale = g_DealershipVehicles[i][dvPrice] * 70 / 100;
            mysql_format(g_DatabaseHandle, query, sizeof(query),
                "INSERT INTO `company_vehicle_stock` (`company_id`,`branch_id`,`model_id`,`amount`,`sale_price`,`wholesale_price`) VALUES (%d,%d,%d,5,%d,%d) ON DUPLICATE KEY UPDATE `amount`=GREATEST(`amount`,5),`sale_price`=VALUES(`sale_price`),`wholesale_price`=VALUES(`wholesale_price`)",
                g_PlayerCompanyID[playerid], id, g_DealershipVehicles[i][dvModelID],
                g_DealershipVehicles[i][dvPrice], wholesale);
            mysql_tquery(g_DatabaseHandle, query);
        }
    }
    new openingDetails[224];
    format(openingDetails, sizeof(openingDetails),
        "Chi nhanh #%d - %s: hoan tat giay phep, noi that, van chuyen va cap ton kho khai truong theo loai hinh kinh doanh",
        id, name);
    Company_LogByID(g_PlayerCompanyID[playerid], playerid, "opening_inventory_granted", openingDetails, 0);
    SendClientMessage(playerid, 0x68C83BFF, "Chi nhanh da hoat dong. 24/7 duoc cap 30 moi mat hang; Dealer duoc chon ngau nhien mau classic va cap 5 xe/mau.");
    return 1;
}

stock Company_ShowBranches(playerid)
{
    new body[1400], typeName[32], found;
    for (new i = 0; i < g_CompanyBranchCount; i++)
    {
        if (g_CompanyBranch[i][cbCompanyID] != g_PlayerCompanyID[playerid]) continue;
        Company_GetTypeName(g_CompanyBranch[i][cbType], typeName, sizeof(typeName));
        format(body, sizeof(body), "%s#%d - %s | %s\n", body,
            g_CompanyBranch[i][cbDatabaseID], g_CompanyBranch[i][cbName], typeName);
        found++;
    }
    if (!found) format(body, sizeof(body), "Chua co chi nhanh nao.\n");
    strcat(body, "\n{68C83B}MO CHI NHANH MOI TAI VI TRI HIEN TAI\n{FFFFFF}Doi door: /company movedoor [branch ID]", sizeof(body));
    ShowPlayerDialog(playerid, DIALOG_COMPANY_BRANCH_MENU, DIALOG_STYLE_MSGBOX,
        "Company - Danh sach chi nhanh", body, "Mo chi nhanh", "Quay lai");
    return 1;
}

stock Company_ShowWarehouse(playerid)
{
    new branch = g_PlayerCompanyBranch[playerid];
    if (branch < 0 ||
        g_CompanyBranch[branch][cbCompanyID] != g_PlayerCompanyID[playerid] ||
        g_CompanyBranch[branch][cbType] != COMPANY_TYPE_CONVENIENCE ||
        GetPlayerInterior(playerid) != COMPANY_STORE_INTERIOR ||
        GetPlayerVirtualWorld(playerid) != COMPANY_WORLD_BASE + g_CompanyBranch[branch][cbDatabaseID])
        return SendClientMessage(playerid, COLOR_RED, "Ban phai dung ben trong mot chi nhanh thuoc Company de quan ly kho.");
    new query[384];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT `id`,`item_id`,`amount`,`unit_price` FROM `company_warehouse` WHERE `branch_id`=%d ORDER BY `item_id` LIMIT 32",
        g_CompanyBranch[branch][cbDatabaseID]);
    mysql_tquery(g_DatabaseHandle, query, "Company_OnShopLoaded", "dd", playerid, 1);
    return 1;
}

stock Company_ShowShop(playerid)
{
    new branch = g_PlayerCompanyBranch[playerid];
    if (branch < 0 || g_CompanyBranch[branch][cbType] != COMPANY_TYPE_CONVENIENCE)
        return SendClientMessage(playerid, COLOR_RED, "Ban phai o ben trong mot chi nhanh cua hang tien loi de su dung /mua.");
    new query[384];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT `id`,`item_id`,`amount`,`unit_price` FROM `company_warehouse` WHERE `branch_id`=%d AND `amount`>0 AND `unit_price`>0 ORDER BY `item_id` LIMIT 32",
        g_CompanyBranch[branch][cbDatabaseID]);
    mysql_tquery(g_DatabaseHandle, query, "Company_OnShopLoaded", "dd", playerid, 0);
    return 1;
}

public Company_OnShopLoaded(playerid, manage)
{
    if (!IsPlayerConnected(playerid)) return 1;
    new rows = cache_num_rows(), body[1600];
    new dbID[COMPANY_MAX_SHOP_ROWS], dbItem[COMPANY_MAX_SHOP_ROWS];
    new dbStock[COMPANY_MAX_SHOP_ROWS], dbPrice[COMPANY_MAX_SHOP_ROWS];
    for (new row = 0; row < rows; row++)
    {
        cache_get_value_name_int(row, "id", dbID[row]);
        cache_get_value_name_int(row, "item_id", dbItem[row]);
        cache_get_value_name_int(row, "amount", dbStock[row]);
        cache_get_value_name_int(row, "unit_price", dbPrice[row]);
    }
    if (manage)
    {
        g_CompanyShopRows[playerid] = sizeof(g_CompanySupplierItems);
        for (new catalog = 0; catalog < sizeof(g_CompanySupplierItems); catalog++)
        {
            new E_ITEM_ID:itemid = g_CompanySupplierItems[catalog];
            g_CompanyShopRowID[playerid][catalog] = 0;
            g_CompanyShopItemID[playerid][catalog] = _:itemid;
            g_CompanyShopStock[playerid][catalog] = 0;
            g_CompanyShopPrice[playerid][catalog] = g_CompanySupplierPrices[catalog] * 2;
            for (new row = 0; row < rows; row++)
            {
                if (dbItem[row] != _:itemid) continue;
                g_CompanyShopRowID[playerid][catalog] = dbID[row];
                g_CompanyShopStock[playerid][catalog] = dbStock[row];
                if (dbPrice[row] > 0) g_CompanyShopPrice[playerid][catalog] = dbPrice[row];
                break;
            }
            format(body, sizeof(body), "%s%s\tTon: %d\tGia ban: $%d\tGia si: $%d\n", body,
                g_ItemData[itemid][itemName], g_CompanyShopStock[playerid][catalog],
                g_CompanyShopPrice[playerid][catalog], g_CompanySupplierPrices[catalog]);
        }
        ShowPlayerDialog(playerid, DIALOG_COMPANY_WAREHOUSE, DIALOG_STYLE_LIST,
            "Kho chi nhanh | Danh muc nha cung cap", body, "Nhap kho", "Thoat");
    }
    else
    {
        g_CompanyShopRows[playerid] = rows;
        for (new row = 0; row < rows; row++)
        {
            g_CompanyShopRowID[playerid][row] = dbID[row];
            g_CompanyShopItemID[playerid][row] = dbItem[row];
            g_CompanyShopStock[playerid][row] = dbStock[row];
            g_CompanyShopPrice[playerid][row] = dbPrice[row];
            new E_ITEM_ID:itemid = E_ITEM_ID:dbItem[row];
            if (itemid <= ITEM_NONE || itemid >= ITEM_COUNT) continue;
            format(body, sizeof(body), "%s%s\tTon: %d\t$%d\n", body,
                g_ItemData[itemid][itemName], dbStock[row], dbPrice[row]);
        }
        if (!rows) format(body, sizeof(body), "Cua hang hien dang het hang.");
        ShowPlayerDialog(playerid, DIALOG_COMPANY_SHOP, DIALOG_STYLE_LIST,
            "Cua hang tien loi | /mua", body, "Mua", "Dong");
    }
    return 1;
}

stock Company_Restock(playerid, E_ITEM_ID:itemid, amount, price)
{
    new branch = g_PlayerCompanyBranch[playerid];
    if (branch < 0 || g_CompanyBranch[branch][cbCompanyID] != g_PlayerCompanyID[playerid])
        return SendClientMessage(playerid, COLOR_RED, "Ban khong o trong chi nhanh cua Company.");
    if (amount <= 0 || amount > 100000 || price <= 0 || price > 1000000)
        return SendClientMessage(playerid, COLOR_RED, "So luong phai tu 1-100,000 va gia ban phai tu $1-$1,000,000.");
    new supplierIndex = -1;
    for (new i = 0; i < sizeof(g_CompanySupplierItems); i++)
        if (g_CompanySupplierItems[i] == itemid) { supplierIndex = i; break; }
    if (supplierIndex == -1)
        return SendClientMessage(playerid, COLOR_RED, "San pham nay khong nam trong danh muc nha cung cap 24/7.");
    new wholesaleCost = g_CompanySupplierPrices[supplierIndex] * amount;
    if (wholesaleCost <= 0 || Company_GetBalance(g_PlayerCompanyID[playerid]) < wholesaleCost)
        return SendClientMessage(playerid, COLOR_RED, "Tai khoan Company khong du tien thanh toan don hang cho nha cung cap.");
    return Trucking_CreateRetailOrder(playerid, _:itemid, amount, price, wholesaleCost);
}

public Company_OnRestockSaved(playerid, itemid, amount, wholesaleCost)
{
    if (!IsPlayerConnected(playerid)) return 1;
    if (cache_affected_rows() < 1)
        return SendClientMessage(playerid, COLOR_RED, "Nha cung cap khong the cap nhat don hang; Company chua bi tru tien.");
    if (Company_GetBalance(g_PlayerCompanyID[playerid]) < wholesaleCost)
    {
        new branch = g_PlayerCompanyBranch[playerid], query[256];
        if (branch >= 0)
        {
            mysql_format(g_DatabaseHandle, query, sizeof(query),
                "UPDATE `company_warehouse` SET `amount`=GREATEST(`amount`-%d,0) WHERE `branch_id`=%d AND `item_id`=%d",
                amount, g_CompanyBranch[branch][cbDatabaseID], itemid);
            mysql_tquery(g_DatabaseHandle, query);
        }
        return SendClientMessage(playerid, COLOR_RED, "So du Company thay doi trong luc xu ly; don nhap kho da duoc hoan tac.");
    }
    Company_AddRuntimeBalance(g_PlayerCompanyID[playerid], -wholesaleCost);
    new query[256], details[192];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `companies` SET `bank_balance`=`bank_balance`-%d WHERE `company_id`=%d",
        wholesaleCost, g_PlayerCompanyID[playerid]);
    mysql_tquery(g_DatabaseHandle, query);
    format(details, sizeof(details), "Nhap hang nha cung cap item=%d amount=%d wholesale=$%d", itemid, amount, wholesaleCost);
    Company_LogByID(g_PlayerCompanyID[playerid], playerid, "supplier_restock", details, -wholesaleCost);
    SendClientMessage(playerid, 0x68C83BFF, "Nhap kho thanh cong: hang da vao kho chi nhanh va gia von da tru tu tai khoan Company.");
    Company_ShowWarehouse(playerid);
    return 1;
}

stock Company_ReservePurchase(playerid, amount)
{
    new row = g_CompanySelectedShopRow[playerid];
    if (row < 0 || row >= g_CompanyShopRows[playerid] || amount <= 0) return 0;
    new total = g_CompanyShopPrice[playerid][row] * amount;
    if (total <= 0 || GetPlayerMoney(playerid) < total)
        return SendClientMessage(playerid, COLOR_RED, "Ban khong du tien mat de mua so luong nay.");
    new E_ITEM_ID:itemid = E_ITEM_ID:g_CompanyShopItemID[playerid][row];
    if (!Inventory_CanCarry(playerid, E_ITEM_ID:itemid, amount) || !Inventory_HasSlotCapacity(playerid, E_ITEM_ID:itemid, amount))
        return SendClientMessage(playerid, COLOR_RED, "Inventory khong du trong luong hoac slot cho so luong nay.");
    g_CompanyPendingBuyAmount[playerid] = amount;
    new query[256];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `company_warehouse` SET `amount`=`amount`-%d WHERE `id`=%d AND `amount`>=%d",
        amount, g_CompanyShopRowID[playerid][row], amount);
    mysql_tquery(g_DatabaseHandle, query, "Company_OnPurchaseStockReserved", "d", playerid);
    return 1;
}

public Company_OnPurchaseStockReserved(playerid)
{
    if (!IsPlayerConnected(playerid) || cache_affected_rows() != 1)
        return SendClientMessage(playerid, COLOR_RED, "So luong ton kho vua thay doi; vui long mo /mua va thu lai.");
    new branch = g_PlayerCompanyBranch[playerid], row = g_CompanySelectedShopRow[playerid];
    if (branch < 0 || row < 0 || row >= g_CompanyShopRows[playerid]) return 1;
    new amount = g_CompanyPendingBuyAmount[playerid];
    new E_ITEM_ID:itemid = E_ITEM_ID:g_CompanyShopItemID[playerid][row];
    new gross = g_CompanyShopPrice[playerid][row] * amount;
    new tax = gross * COMPANY_TAX_PERCENT / 100;
    new net = gross - tax;
    GivePlayerMoney(playerid, -gross);
    Economy_SaveBalances(playerid);
    Inventory_AddItem(playerid, itemid, amount);
    Inventory_SaveCharacter(playerid, true);
    new companyid = g_CompanyBranch[branch][cbCompanyID], query[768], details[256];
    Company_AddRuntimeBalance(companyid, net);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `companies` SET `bank_balance`=`bank_balance`+%d WHERE `company_id`=%d", net, companyid);
    mysql_tquery(g_DatabaseHandle, query);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `server_treasury` SET `tax_balance`=`tax_balance`+%d,`lifetime_tax`=`lifetime_tax`+%d WHERE `treasury_id`=1", tax, tax);
    mysql_tquery(g_DatabaseHandle, query);
    LSBank_RecordRevenue("retail_tax", tax, GetPlayerCharacterID(playerid));
    format(details, sizeof(details), "Chi nhanh #%d - %s; mua %s x%d; gross=$%d; tax5=$%d; company_net=$%d",
        g_CompanyBranch[branch][cbDatabaseID], g_CompanyBranch[branch][cbName],
        g_ItemData[itemid][itemName], amount, gross, tax, net);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `server_tax_transactions` (`company_id`,`character_id`,`source`,`gross_amount`,`tax_amount`,`details`) VALUES (%d,%d,'retail_sale',%d,%d,'%e')", companyid, GetPlayerCharacterID(playerid), gross, tax, details);
    mysql_tquery(g_DatabaseHandle, query);
    Company_LogByID(companyid, playerid, "retail_sale", details, net);
    Economy_LogTransaction(playerid, "company_store_purchase", -gross, 0, details);
    SendClientMessage(playerid, 0x68C83BFF, "Mua hang thanh cong. Vat pham da vao inventory; 95% doanh thu vao Company va 5% da nop thue.");
    return 1;
}

public bool:Company_IsPlayerInDealerBranch(playerid)
{
    new branch = g_PlayerCompanyBranch[playerid];
    return branch >= 0 && g_CompanyBranch[branch][cbType] == COMPANY_TYPE_DEALER;
}

public Company_GetDealerDelivery(playerid, &Float:x, &Float:y, &Float:z, &Float:a)
{
    new branch = g_PlayerCompanyBranch[playerid];
    if (branch < 0)
    {
        x = 0.0; y = 0.0; z = 3.0; a = 0.0;
        return 0;
    }
    x = g_CompanyBranch[branch][cbX] + (5.0 * floatsin(-g_CompanyBranch[branch][cbA], degrees));
    y = g_CompanyBranch[branch][cbY] + (5.0 * floatcos(-g_CompanyBranch[branch][cbA], degrees));
    z = g_CompanyBranch[branch][cbZ];
    a = g_CompanyBranch[branch][cbA];
    return 1;
}

public Company_RecordDealerSale(playerid, grossAmount, modelid)
{
    new branch = g_PlayerCompanyBranch[playerid];
    if (branch < 0 || grossAmount <= 0) return 0;
    new tax = grossAmount * COMPANY_TAX_PERCENT / 100, net = grossAmount - tax;
    new companyid = g_CompanyBranch[branch][cbCompanyID], query[768], details[256];
    Company_AddRuntimeBalance(companyid, net);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `companies` SET `bank_balance`=`bank_balance`+%d WHERE `company_id`=%d", net, companyid);
    mysql_tquery(g_DatabaseHandle, query);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `server_treasury` SET `tax_balance`=`tax_balance`+%d,`lifetime_tax`=`lifetime_tax`+%d WHERE `treasury_id`=1", tax, tax);
    mysql_tquery(g_DatabaseHandle, query);
    LSBank_RecordRevenue("dealer_tax", tax, GetPlayerCharacterID(playerid));
    format(details, sizeof(details), "Chi nhanh #%d - %s; buyer_character=%d model=%d gross=$%d tax5=$%d company_net=$%d",
        g_CompanyBranch[branch][cbDatabaseID], g_CompanyBranch[branch][cbName], GetPlayerCharacterID(playerid),
        modelid, grossAmount, tax, net);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `server_tax_transactions` (`company_id`,`character_id`,`source`,`gross_amount`,`tax_amount`,`details`) VALUES (%d,%d,'vehicle_sale',%d,%d,'%e')", companyid, GetPlayerCharacterID(playerid), grossAmount, tax, details);
    mysql_tquery(g_DatabaseHandle, query);
    Company_LogByID(companyid, playerid, "vehicle_sale", details, net);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `company_vehicle_stock` SET `amount`=GREATEST(`amount`-1,0) WHERE `branch_id`=%d AND `model_id`=%d AND `amount`>0",
        g_CompanyBranch[branch][cbDatabaseID], modelid);
    mysql_tquery(g_DatabaseHandle, query);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `company_vehicle_transactions` (`company_id`,`branch_id`,`buyer_character_id`,`model_id`,`gross_amount`,`tax_amount`,`net_amount`) VALUES (%d,%d,%d,%d,%d,%d,%d)",
        companyid, g_CompanyBranch[branch][cbDatabaseID], GetPlayerCharacterID(playerid),
        modelid, grossAmount, tax, net);
    mysql_tquery(g_DatabaseHandle, query);
    for (new index = 0; index < DEALERSHIP_VEHICLE_COUNT; index++)
        if (g_DealershipVehicles[index][dvModelID] == modelid)
        {
            if (g_DealershipBranchStock[playerid][index] > 0)
                g_DealershipBranchStock[playerid][index]--;
            break;
        }
    return 1;
}

stock Company_EnterBranch(playerid, branch)
{
    g_PlayerCompanyBranch[playerid] = branch;
    if (g_CompanyBranch[branch][cbType] == COMPANY_TYPE_DEALER)
    {
        SendClientMessage(playerid, COLOR_WHITE, "Dang tai ton kho showroom. Chi cac mau xe con hang moi duoc hien thi.");
        return Company_LoadDealerStock(playerid, true);
    }
    SetPlayerInterior(playerid, COMPANY_STORE_INTERIOR);
    SetPlayerVirtualWorld(playerid, COMPANY_WORLD_BASE + g_CompanyBranch[branch][cbDatabaseID]);
    SetPlayerPos(playerid, COMPANY_STORE_X, COMPANY_STORE_Y, COMPANY_STORE_Z);
    SetPlayerFacingAngle(playerid, 0.0);
    SetCameraBehindPlayer(playerid);
    SendClientMessage(playerid, COLOR_WHITE, "Bam Y tai cua de ra; su dung /mua de mua hang. Chu Company dung /company > Kho hang de quan ly ton kho.");
    return 1;
}

stock Company_LeaveBranch(playerid)
{
    new branch = g_PlayerCompanyBranch[playerid];
    if (branch < 0) return 0;
    SetPlayerInterior(playerid, 0);
    SetPlayerVirtualWorld(playerid, 0);
    SetPlayerPos(playerid, g_CompanyBranch[branch][cbX], g_CompanyBranch[branch][cbY] - 1.2, g_CompanyBranch[branch][cbZ]);
    SetPlayerFacingAngle(playerid, g_CompanyBranch[branch][cbA]);
    g_PlayerCompanyBranch[playerid] = -1;
    SetCameraBehindPlayer(playerid);
    return 1;
}

stock Company_RecoverBranchContext(playerid)
{
    new databaseID = GetPlayerVirtualWorld(playerid) - COMPANY_WORLD_BASE;
    if (databaseID <= 0) return -1;
    for (new i; i < g_CompanyBranchCount; i++)
        if (g_CompanyBranch[i][cbDatabaseID] == databaseID)
        {
            g_PlayerCompanyBranch[playerid] = i;
            return i;
        }
    return -1;
}

CMD:company(playerid, params[])
{
    if (!strlen(params)) return Company_ShowMain(playerid);
    if (!strcmp(params, "create", true)) return Company_ShowCreateTypes(playerid);
    if (!g_PlayerCompanyID[playerid]) return Company_ShowCreateTypes(playerid);
    if (!strcmp(params, "branches", true)) return Company_ShowBranches(playerid);
    if (!strcmp(params, "warehouse", true)) return Company_ShowWarehouse(playerid);
    if (!strcmp(params, "vehicles", true)) return Company_ShowVehicleWarehouse(playerid);
    if (strfind(params, "movedoor ", true) == 0)
        return Company_MoveDoor(playerid, strval(params[9]));
    return Company_ShowMain(playerid);
}

stock Company_ReadCommandToken(const input[], &offset, output[], size)
{
    while (input[offset] == ' ') offset++;
    if (input[offset] == EOS) return 0;
    new index;
    while (input[offset] != EOS && input[offset] != ' ' && index < size - 1)
        output[index++] = input[offset++];
    output[index] = EOS;
    return index > 0;
}

CMD:gotoco(playerid, params[])
{
    if (!IsPlayerCharacterLoaded(playerid))
        return SendClientMessage(playerid, COLOR_RED, "Ban phai dang nhap nhan vat truoc khi su dung /gotoco.");
    new Float:x, Float:y, Float:z, interior, offset, sx[24], sy[24], sz[24], sint[12];
    if (!Company_ReadCommandToken(params, offset, sx, sizeof(sx)) ||
        !Company_ReadCommandToken(params, offset, sy, sizeof(sy)) ||
        !Company_ReadCommandToken(params, offset, sz, sizeof(sz)) ||
        !Company_ReadCommandToken(params, offset, sint, sizeof(sint)))
        return SendClientMessage(playerid, COLOR_WHITE, "Su dung: /gotoco [x] [y] [z] [interior]. Vi du: /gotoco 223.0439 1289.2599 1082.1999 1");
    x = floatstr(sx);
    y = floatstr(sy);
    z = floatstr(sz);
    interior = strval(sint);
    if (interior < 0 || interior > 255)
        return SendClientMessage(playerid, COLOR_RED, "Interior ID phai nam trong khoang 0-255.");
    SetPlayerInterior(playerid, interior);
    SetPlayerVirtualWorld(playerid, 0);
    SetPlayerPos(playerid, x, y, z);
    SetCameraBehindPlayer(playerid);
    new notice[160];
    format(notice, sizeof(notice), "Da di chuyen den %.4f, %.4f, %.4f | Interior: %d | Virtual World: 0.", x, y, z, interior);
    SendClientMessage(playerid, 0x68C83BFF, notice);
    return 1;
}

CMD:acompany(playerid, params[])
{
    if (!Admin_RequireLevel(playerid, ADMIN_LEVEL_ADMIN)) return 1;
    if (!strlen(params))
        return SendClientMessage(playerid, COLOR_WHITE, "Su dung: /acompany [companyid/exit]");
    if (!strcmp(params, "exit", true))
    {
        g_AdminCompanyOverride[playerid] = false;
        Company_LoadForCharacter(playerid);
        SendClientMessage(playerid, COLOR_WHITE, "Da thoat quyen quan ly Company va khoi phuc Company cua nhan vat.");
        return 1;
    }
    new companyid = strval(params);
    if (companyid <= 0)
        return SendClientMessage(playerid, COLOR_RED, "Company ID khong hop le.");
    new query[384];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT `company_id`,`name`,`company_type`,`level`,`bank_balance` FROM `companies` WHERE `company_id`=%d LIMIT 1",
        companyid);
    mysql_tquery(g_DatabaseHandle, query, "Company_OnAdminOverrideLoaded", "d", playerid);
    return 1;
}

public Company_OnAdminOverrideLoaded(playerid)
{
    if (!IsPlayerConnected(playerid) || !cache_num_rows())
        return SendClientMessage(playerid, COLOR_RED, "Khong tim thay Company de Admin quan ly.");
    cache_get_value_name_int(0, "company_id", g_PlayerCompanyID[playerid]);
    cache_get_value_name_int(0, "company_type", g_PlayerCompanyType[playerid]);
    cache_get_value_name_int(0, "level", g_PlayerCompanyLevel[playerid]);
    new companyBalance;
    cache_get_value_name_int(0, "bank_balance", companyBalance);
    Company_EnsureBalance(g_PlayerCompanyID[playerid], companyBalance);
    cache_get_value_name(0, "name", g_PlayerCompanyName[playerid], 48);
    g_PlayerCompanyRank[playerid] = 5;
    g_PlayerCompanyBranch[playerid] = -1;
    g_AdminCompanyOverride[playerid] = true;
    SendClientMessage(playerid, 0x68C83BFF,
        "Da truy cap Company voi quyen Chu doanh nghiep cua Chinh phu. Su dung /company de quan ly, /acompany exit de thoat.");
    return Company_ShowMain(playerid);
}

CMD:mua(playerid, params[])
{
    #pragma unused params
    return Company_ShowShop(playerid);
}

CMD:vao(playerid, params[])
{
    #pragma unused params
    new branch = Company_FindNearestBranch(playerid);
    if (branch >= 0) return Company_EnterBranch(playerid, branch);
    new house = REHouse_FindNearest(playerid);
    if (house >= 0) return REHouse_Enter(playerid, house);
    return SendClientMessage(playerid, COLOR_RED, "Ban khong dung gan door chi nhanh Company hoac mot can nha.");
}

CMD:ra(playerid, params[])
{
    #pragma unused params
    if (g_PlayerCompanyBranch[playerid] >= 0) return Company_LeaveBranch(playerid);
    if (Company_RecoverBranchContext(playerid) >= 0) return Company_LeaveBranch(playerid);
    if (REHouse_IsInside(playerid)) return REHouse_Leave(playerid);
    if (RE_TryLeaveRecoveredInterior(playerid)) return 1;
    return SendClientMessage(playerid, COLOR_RED, "Ban khong o ben trong chi nhanh Company hoac can nha nao.");
}

CMD:dealers(playerid, params[])
{
    #pragma unused params
    for (new branch = 0; branch < g_CompanyBranchCount; branch++)
    {
        if (g_CompanyBranch[branch][cbType] != COMPANY_TYPE_DEALER) continue;
        SetPlayerCheckpoint(playerid, g_CompanyBranch[branch][cbX],
            g_CompanyBranch[branch][cbY], g_CompanyBranch[branch][cbZ], 4.0);
        new message[160];
        format(message, sizeof(message), "GPS da danh dau dai ly %s. Den door va bam Y de mo showroom; /dealer khong con duoc su dung.",
            g_CompanyBranch[branch][cbName]);
        SendClientMessage(playerid, 0x68C83BFF, message);
        return 1;
    }
    SendClientMessage(playerid, COLOR_RED, "Hien tai chua co Company dai ly phuong tien nao hoat dong tren server.");
    return 1;
}

CMD:servertax(playerid, params[])
{
    #pragma unused params
    if (!Admin_RequireLevel(playerid, ADMIN_LEVEL_ADMIN)) return 1;
    mysql_tquery(g_DatabaseHandle,
        "SELECT `tax_balance`,`lifetime_tax`,`updated_at` FROM `server_treasury` WHERE `treasury_id`=1 LIMIT 1",
        "Company_OnTaxLoaded", "d", playerid);
    return 1;
}

public Company_OnTaxLoaded(playerid)
{
    if (!IsPlayerConnected(playerid) || !cache_num_rows()) return 1;
    new balance, lifetime, updated[32], body[384];
    cache_get_value_name_int(0, "tax_balance", balance);
    cache_get_value_name_int(0, "lifetime_tax", lifetime);
    cache_get_value_name(0, "updated_at", updated, sizeof(updated));
    format(body, sizeof(body), "Quy thue hien tai: $%d\nTong thue da thu: $%d\nCap nhat gan nhat: %s\n\nChi Admin tro len moi xem duoc du lieu nay.", balance, lifetime, updated);
    ShowPlayerDialog(playerid, DIALOG_COMPANY_TAX_INFO, DIALOG_STYLE_MSGBOX, "Server Treasury - Tax Audit", body, "Dong", "");
    return 1;
}

hook OnGameModeInit()
{
    // Fresh-install schema. ALTER statements below migrate the first Company prototype safely.
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `companies` (`company_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,`name` VARCHAR(48) NOT NULL,`company_type` TINYINT UNSIGNED NOT NULL DEFAULT 1,`level` TINYINT UNSIGNED NOT NULL DEFAULT 1,`owner_character_id` INT UNSIGNED NOT NULL,`bank_balance` INT NOT NULL DEFAULT 0,`warehouse_capacity` INT UNSIGNED NOT NULL DEFAULT 100,`vehicle_limit` INT UNSIGNED NOT NULL DEFAULT 3,`member_limit` INT UNSIGNED NOT NULL DEFAULT 5,`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY (`company_id`),UNIQUE KEY (`name`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "ALTER TABLE `companies` ADD COLUMN IF NOT EXISTS `tax_code` VARCHAR(32) NOT NULL DEFAULT '',ADD COLUMN IF NOT EXISTS `website` VARCHAR(80) NOT NULL DEFAULT ''");
    mysql_tquery(g_DatabaseHandle,
        "UPDATE `companies` SET `tax_code`=IF(`tax_code`='',CONCAT('LS-',LPAD(`company_id`,6,'0')),`tax_code`),`website`=IF(`website`='',CONCAT('www.company-',`company_id`,'.ls'),`website`)");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `company_members` (`company_id` INT UNSIGNED NOT NULL,`character_id` INT UNSIGNED NOT NULL,`rank` TINYINT UNSIGNED NOT NULL DEFAULT 1,`title` VARCHAR(32) NOT NULL DEFAULT 'Nhan vien',`joined_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY (`company_id`,`character_id`),UNIQUE KEY (`character_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `company_branches` (`branch_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,`company_id` INT UNSIGNED NOT NULL,`branch_type_id` TINYINT UNSIGNED NOT NULL DEFAULT 1,`name` VARCHAR(64) NOT NULL,`branch_type` VARCHAR(24) NOT NULL DEFAULT '24/7',`exterior_x` FLOAT NOT NULL,`exterior_y` FLOAT NOT NULL,`exterior_z` FLOAT NOT NULL,`exterior_a` FLOAT NOT NULL,`interior_id` INT NOT NULL DEFAULT 6,`virtual_world` INT NOT NULL DEFAULT 0,`status` TINYINT NOT NULL DEFAULT 1,`cash_balance` INT NOT NULL DEFAULT 0,PRIMARY KEY (`branch_id`),KEY (`company_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle, "ALTER TABLE `company_branches` ADD COLUMN IF NOT EXISTS `branch_type_id` TINYINT UNSIGNED NOT NULL DEFAULT 1 AFTER `company_id`");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `company_warehouse` (`id` INT UNSIGNED NOT NULL AUTO_INCREMENT,`company_id` INT UNSIGNED NOT NULL,`branch_id` INT UNSIGNED NOT NULL,`item_id` INT UNSIGNED NOT NULL,`item_name` VARCHAR(64) NOT NULL,`amount` INT UNSIGNED NOT NULL DEFAULT 0,`unit_price` INT UNSIGNED NOT NULL DEFAULT 0,PRIMARY KEY (`id`),UNIQUE KEY `uq_branch_item` (`branch_id`,`item_id`),KEY (`company_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle, "ALTER TABLE `company_warehouse` ADD COLUMN IF NOT EXISTS `branch_id` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `company_id`,ADD COLUMN IF NOT EXISTS `item_id` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `branch_id`,ADD COLUMN IF NOT EXISTS `unit_price` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `amount`");
    mysql_tquery(g_DatabaseHandle, "CREATE UNIQUE INDEX IF NOT EXISTS `uq_branch_item` ON `company_warehouse` (`branch_id`,`item_id`)");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `company_logs` (`log_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,`company_id` INT UNSIGNED NOT NULL,`actor_character_id` INT UNSIGNED NOT NULL,`action` VARCHAR(32) NOT NULL,`details` VARCHAR(255) NOT NULL DEFAULT '',`amount` INT NOT NULL DEFAULT 0,`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY (`log_id`),KEY (`company_id`,`created_at`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `server_treasury` (`treasury_id` TINYINT UNSIGNED NOT NULL,`tax_balance` BIGINT NOT NULL DEFAULT 0,`lifetime_tax` BIGINT NOT NULL DEFAULT 0,`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,PRIMARY KEY (`treasury_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle, "INSERT IGNORE INTO `server_treasury` (`treasury_id`) VALUES (1)");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `server_tax_transactions` (`tax_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,`company_id` INT UNSIGNED NOT NULL,`character_id` INT UNSIGNED NOT NULL,`source` VARCHAR(32) NOT NULL,`gross_amount` INT NOT NULL,`tax_amount` INT NOT NULL,`details` VARCHAR(255) NOT NULL DEFAULT '',`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY (`tax_id`),KEY (`company_id`,`created_at`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `company_vehicle_stock` (`id` INT UNSIGNED NOT NULL AUTO_INCREMENT,`company_id` INT UNSIGNED NOT NULL,`branch_id` INT UNSIGNED NOT NULL,`model_id` SMALLINT UNSIGNED NOT NULL,`amount` INT UNSIGNED NOT NULL DEFAULT 0,`sale_price` INT UNSIGNED NOT NULL,`wholesale_price` INT UNSIGNED NOT NULL,`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,PRIMARY KEY (`id`),UNIQUE KEY `uq_branch_model` (`branch_id`,`model_id`),KEY (`company_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `company_vehicle_transactions` (`transaction_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,`company_id` INT UNSIGNED NOT NULL,`branch_id` INT UNSIGNED NOT NULL,`buyer_character_id` INT UNSIGNED NOT NULL,`model_id` SMALLINT UNSIGNED NOT NULL,`gross_amount` INT NOT NULL,`tax_amount` INT NOT NULL,`net_amount` INT NOT NULL,`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY (`transaction_id`),KEY `idx_vehicle_tx_branch` (`branch_id`,`created_at`),KEY `idx_vehicle_tx_company` (`company_id`,`created_at`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    // Remove only the exact fixed prototype requested to be retired.
    mysql_tquery(g_DatabaseHandle, "DELETE FROM `company_branches` WHERE `name`='Unity 24/7 - Taxi HQ' AND `exterior_x` BETWEEN 1833.3 AND 1833.5 AND `exterior_y` BETWEEN -1842.8 AND -1842.6");
    SetTimer("Company_LoadBranches", 1500, false);
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
    for (new i; i < COMPANY_MAX_APPLICATIONS; i++)
        if (g_CompanyApplicationActive[i] && g_CompanyApplicationPlayer[i] == playerid)
            g_CompanyApplicationActive[i] = false;
    Company_ResetPlayer(playerid);
    return 1;
}

hook OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys)
{
    #pragma unused oldkeys
    if (!(newkeys & KEY_YES) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT) return 1;
    if (g_PlayerCompanyBranch[playerid] >= 0 &&
        GetPlayerInterior(playerid) == COMPANY_STORE_INTERIOR &&
        IsPlayerInRangeOfPoint(playerid, 3.0, COMPANY_STORE_X, COMPANY_STORE_EXIT_Y, COMPANY_STORE_Z))
        return Company_LeaveBranch(playerid);
    if (GetPlayerInterior(playerid) == COMPANY_STORE_INTERIOR &&
        IsPlayerInRangeOfPoint(playerid, 3.0, COMPANY_STORE_X, COMPANY_STORE_EXIT_Y, COMPANY_STORE_Z) &&
        Company_RecoverBranchContext(playerid) >= 0)
        return Company_LeaveBranch(playerid);
    new branch = Company_FindNearestBranch(playerid);
    if (branch >= 0) return Company_EnterBranch(playerid, branch);
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if (dialogid == DIALOG_COMPANY_GUEST)
    {
        if (!response) return 1;
        if (listitem == 0) return Company_LoadPublicList(playerid);
        return Company_ShowCreateTypes(playerid);
    }
    if (dialogid == DIALOG_COMPANY_PUBLIC_LIST)
    {
        if (!response) return Company_ShowGuestMenu(playerid);
        if (listitem < 0 || listitem >= g_CompanyPublicRows[playerid]) return 1;
        return Company_SubmitApplication(playerid, g_CompanyPublicID[playerid][listitem]);
    }
    if (dialogid == DIALOG_COMPANY_MEMBER_MANAGE)
    {
        if (!response) return Company_ShowMain(playerid);
        if (g_PlayerCompanyRank[playerid] < 5)
            return SendClientMessage(playerid, COLOR_RED, "Chi Giam doc Company hoac Admin quan ly moi duoc truy cap nhan su.");
        if (listitem == 0) return Company_ShowOwnerMembers(playerid);
        return Company_ShowApplications(playerid);
    }
    if (dialogid == DIALOG_COMPANY_APPLICATIONS)
    {
        if (!response) return Company_ShowMain(playerid);
        if (g_PlayerCompanyRank[playerid] < 5)
            return SendClientMessage(playerid, COLOR_RED, "Ban khong co quyen phe duyet don xin viec.");
        if (listitem < 0 || listitem >= g_CompanyApplicationRows[playerid]) return 1;
        new slot = g_CompanyApplicationSlot[playerid][listitem];
        if (!g_CompanyApplicationActive[slot]) return SendClientMessage(playerid, COLOR_RED, "Don xin viec nay khong con ton tai.");
        new applicantid = g_CompanyApplicationPlayer[slot], query[512];
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "INSERT IGNORE INTO `company_members` (`company_id`,`character_id`,`rank`,`title`) VALUES (%d,%d,1,'Nhan vien')",
            g_PlayerCompanyID[playerid], g_CompanyApplicationCharacter[slot]);
        mysql_tquery(g_DatabaseHandle, query, "Company_OnApplicationApproved", "ddd",
            playerid, applicantid, g_PlayerCompanyID[playerid]);
        g_CompanyApplicationActive[slot] = false;
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_TYPE)
    {
        if (!response) return 1;
        g_CompanyPendingType[playerid] = listitem == 1 ? COMPANY_TYPE_DEALER : COMPANY_TYPE_CONVENIENCE;
        ShowPlayerDialog(playerid, DIALOG_COMPANY_NAME, DIALOG_STYLE_INPUT,
            "Company - Dat ten doanh nghiep", "Nhap ten phap ly cua Company (3-40 ky tu):", "Tiep tuc", "Huy");
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_NAME)
    {
        if (!response) return 1;
        if (strlen(inputtext) < 3 || strlen(inputtext) > 40)
            return SendClientMessage(playerid, COLOR_RED, "Ten Company phai co tu 3 den 40 ky tu.");
        format(g_CompanyPendingName[playerid], 48, "%s", inputtext);
        if (GetPlayerMoney(playerid) < COMPANY_CREATE_COST)
            return SendClientMessage(playerid, COLOR_RED, "Ban can toi thieu $2.000.000 von thanh lap de dang ky phap nhan va thue/mua van phong Company.");
        return RealEstate_ShowOfficeChoice(playerid);
    }
    if (dialogid == DIALOG_COMPANY_PLACE)
    {
        if (response) Company_CreateAtPendingPosition(playerid);
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_MAIN)
    {
        if (!response) return 1;
        if (listitem > 1 && g_PlayerCompanyRank[playerid] < 5 && !g_AdminCompanyOverride[playerid])
            return SendClientMessage(playerid, COLOR_RED, "Nhan vien chi duoc xem Thong tin doanh nghiep va Van phong. Cac muc quan tri danh cho Giam doc rank 5.");
        switch (listitem)
        {
            case 0: Company_LoadGeneralInfo(playerid);
            case 1: Company_LoadOfficeInfo(playerid);
            case 2: Company_ShowBusinessMenu(playerid);
            case 3:
            {
                new title[96], balanceText[24];
                Company_FormatMoney(Company_GetBalance(g_PlayerCompanyID[playerid]), balanceText, sizeof(balanceText));
                format(title, sizeof(title), "Tai chinh Company | $%s", balanceText);
                ShowPlayerDialog(playerid, DIALOG_COMPANY_FINANCE, DIALOG_STYLE_LIST, title,
                    "Doanh thu va ket qua kinh doanh\nNgan sach Company - Rut/Gui\nTin dung San Andreas Bank", "Chon", "Quay lai");
            }
            case 4: Company_ShowOwnerLogs(playerid);
            case 5:
            {
                if (g_PlayerCompanyRank[playerid] >= 5)
                    ShowPlayerDialog(playerid, DIALOG_COMPANY_MEMBER_MANAGE, DIALOG_STYLE_LIST,
                        "Company | Nhan su", "Danh sach tat ca nhan vien\nDon xin viec dang cho", "Chon", "Quay lai");
                else Company_ShowOwnerMembers(playerid);
            }
        }
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_GENERAL_INFO || dialogid == DIALOG_COMPANY_OFFICE_INFO)
    {
        if (response) Company_ShowMain(playerid);
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_BUSINESS)
    {
        if (!response) return Company_ShowMain(playerid);
        switch (g_PlayerCompanyType[playerid])
        {
            case COMPANY_TYPE_CONVENIENCE:
            {
                if (listitem == 0) return Company_ShowBranches(playerid);
                if (listitem == 1 || listitem == 2) return Company_ShowWarehouse(playerid);
                return Company_ShowOwnerLogs(playerid);
            }
            case COMPANY_TYPE_DEALER:
            {
                if (listitem == 0) return Company_ShowBranches(playerid);
                if (listitem == 1 || listitem == 2) return Company_ShowVehicleWarehouse(playerid);
                return Company_ShowOwnerLogs(playerid);
            }
            case COMPANY_TYPE_TRUCKING:
            {
                if (listitem == 0) return Company_LoadTruckSummary(playerid);
                if (listitem == 1) return Company_ShowOwnerContracts(playerid);
                return Company_ShowOwnerLogs(playerid);
            }
            case COMPANY_TYPE_BANK:
            {
                if (listitem == 0) return LSBank_ShowCompanyFinance(playerid);
                if (listitem == 1) return Company_LoadRevenue(playerid);
                return Company_ShowOwnerLogs(playerid);
            }
            default:
            {
                if (listitem == 0) return RealEstateHouse_ShowAssets(playerid);
                if (listitem == 1) return RealEstateHouse_ShowBuildMenu(playerid);
                return Company_ShowOwnerLogs(playerid);
            }
        }
    }
    if (dialogid == DIALOG_COMPANY_BDS_UNITS || dialogid == DIALOG_COMPANY_TRUCK_SUMMARY)
    {
        if (response) Company_ShowBusinessMenu(playerid);
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_PAGE)
    {
        if (response) Company_ShowMain(playerid);
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_UPGRADE)
    {
        if (!response) return Company_ShowMain(playerid);
        if (g_PlayerCompanyRank[playerid] < 5)
            return SendClientMessage(playerid, COLOR_RED, "Chi chu Company hoac Admin quan ly moi duoc nang cap.");
        if (g_PlayerCompanyLevel[playerid] >= 10)
            return SendClientMessage(playerid, COLOR_RED, "Company da dat cap toi da.");
        new cost = g_PlayerCompanyLevel[playerid] * 10000;
        if (Company_GetBalance(g_PlayerCompanyID[playerid]) < cost)
            return SendClientMessage(playerid, COLOR_RED, "Tai khoan Company khong du chi phi nang cap.");
        Company_AddRuntimeBalance(g_PlayerCompanyID[playerid], -cost);
        g_PlayerCompanyLevel[playerid]++;
        new query[512], details[128];
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "UPDATE `companies` SET `level`=%d,`bank_balance`=`bank_balance`-%d,`member_limit`=`member_limit`+5,`vehicle_limit`=`vehicle_limit`+3,`warehouse_capacity`=`warehouse_capacity`+100 WHERE `company_id`=%d",
            g_PlayerCompanyLevel[playerid], cost, g_PlayerCompanyID[playerid]);
        mysql_tquery(g_DatabaseHandle, query);
        format(details, sizeof(details), "Nang cap Company len cap %d", g_PlayerCompanyLevel[playerid]);
        Company_LogByID(g_PlayerCompanyID[playerid], playerid, "company_upgraded", details, -cost);
        SendClientMessage(playerid, 0x68C83BFF, "Nang cap Company thanh cong; gioi han thanh vien, xe va kho da tang.");
        return Company_ShowMain(playerid);
    }
    if (dialogid == DIALOG_COMPANY_BRANCH_MENU)
    {
        if (!response) return Company_ShowMain(playerid);
        g_CompanyPendingType[playerid] = g_PlayerCompanyType[playerid];
        return Company_ShowPlaceConfirmation(playerid, true);
    }
    if (dialogid == DIALOG_COMPANY_BRANCH_PLACE)
    {
        if (response) Company_CreateBranchAtPendingPosition(playerid);
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_FINANCE)
    {
        if (!response) return Company_ShowMain(playerid);
        if (listitem == 0) return Company_LoadRevenue(playerid);
        if (listitem == 1)
        {
            ShowPlayerDialog(playerid, DIALOG_COMPANY_BUDGET, DIALOG_STYLE_LIST,
                "Company | Quan ly ngan sach", "Gui tien mat vao Company\nRut tien khoi Company", "Chon", "Quay lai");
            return 1;
        }
        if (listitem == 2) return LSBank_ShowCompanyFinance(playerid);
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_BUDGET)
    {
        if (!response) return Company_ShowMain(playerid);
        ShowPlayerDialog(playerid, listitem ? DIALOG_COMPANY_WITHDRAW : DIALOG_COMPANY_DEPOSIT,
            DIALOG_STYLE_INPUT, listitem ? "Company - Rut tien" : "Company - Gui tien",
            "Nhap so tien:", listitem ? "Rut" : "Gui", "Huy");
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_DEPOSIT || dialogid == DIALOG_COMPANY_WITHDRAW)
    {
        if (!response) return 1;
        new amount = strval(inputtext), query[256];
        if (amount <= 0) return SendClientMessage(playerid, COLOR_RED, "So tien phai lon hon 0.");
        if (dialogid == DIALOG_COMPANY_DEPOSIT)
        {
            if (GetPlayerMoney(playerid) < amount) return SendClientMessage(playerid, COLOR_RED, "Ban khong du tien mat.");
            GivePlayerMoney(playerid, -amount);
            Company_AddRuntimeBalance(g_PlayerCompanyID[playerid], amount);
            mysql_format(g_DatabaseHandle, query, sizeof(query), "UPDATE `companies` SET `bank_balance`=`bank_balance`+%d WHERE `company_id`=%d", amount, g_PlayerCompanyID[playerid]);
            Company_LogByID(g_PlayerCompanyID[playerid], playerid, "finance_deposit", "Gui tien vao Company", amount);
        }
        else
        {
            if (g_PlayerCompanyRank[playerid] < 4 || Company_GetBalance(g_PlayerCompanyID[playerid]) < amount)
                return SendClientMessage(playerid, COLOR_RED, "Khong du quyen hoac Company khong du tien.");
            GivePlayerMoney(playerid, amount);
            Company_AddRuntimeBalance(g_PlayerCompanyID[playerid], -amount);
            mysql_format(g_DatabaseHandle, query, sizeof(query), "UPDATE `companies` SET `bank_balance`=`bank_balance`-%d WHERE `company_id`=%d", amount, g_PlayerCompanyID[playerid]);
            Company_LogByID(g_PlayerCompanyID[playerid], playerid, "finance_withdraw", "Rut tien Company", -amount);
        }
        mysql_tquery(g_DatabaseHandle, query);
        Economy_SaveBalances(playerid);
        SendClientMessage(playerid, 0x68C83BFF, "Giao dich Company thanh cong va da duoc ghi log.");
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_WAREHOUSE)
    {
        if (!response) return 1;
        if (listitem < 0 || listitem >= g_CompanyShopRows[playerid]) return 1;
        new prompt[320], wholesale = g_CompanySupplierPrices[listitem];
        format(prompt, sizeof(prompt),
            "San pham: %s\nTon hien tai: %d\nGia ban hien tai: $%d\nGia nhap tu nha cung cap: $%d/san pham\n\nNhap: SO_LUONG GIA_BAN\nVi du: 100 25",
            g_ItemData[g_CompanySupplierItems[listitem]][itemName],
            g_CompanyShopStock[playerid][listitem], g_CompanyShopPrice[playerid][listitem], wholesale);
        g_CompanySelectedShopRow[playerid] = listitem;
        g_CompanyRestockItemID[playerid] = E_ITEM_ID:g_CompanyShopItemID[playerid][listitem];
        ShowPlayerDialog(playerid, DIALOG_COMPANY_RESTOCK, DIALOG_STYLE_INPUT,
            "Kho - Dat hang nha cung cap", prompt, "Nhap kho", "Thoat");
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_INVENTORY_STOCK)
    {
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_RESTOCK)
    {
        if (!response) return 1;
        new separator = strfind(inputtext, " ");
        if (separator <= 0)
            return SendClientMessage(playerid, COLOR_RED, "Nhap theo dinh dang: SO_LUONG GIA_BAN. Vi du: 5 25");
        new amountText[12];
        strmid(amountText, inputtext, 0, separator, sizeof(amountText));
        new amount = strval(amountText), price = strval(inputtext[separator + 1]);
        return Company_Restock(playerid, g_CompanyRestockItemID[playerid], amount, price);
    }
    if (dialogid == DIALOG_COMPANY_SHOP)
    {
        if (!response || listitem < 0 || listitem >= g_CompanyShopRows[playerid]) return 1;
        g_CompanySelectedShopRow[playerid] = listitem;
        new prompt[192], E_ITEM_ID:itemid = E_ITEM_ID:g_CompanyShopItemID[playerid][listitem];
        format(prompt, sizeof(prompt), "%s | Ton: %d | Gia: $%d moi san pham\nNhap so luong muon mua:",
            g_ItemData[itemid][itemName],
            g_CompanyShopStock[playerid][listitem], g_CompanyShopPrice[playerid][listitem]);
        ShowPlayerDialog(playerid, DIALOG_COMPANY_BUY_AMOUNT, DIALOG_STYLE_INPUT, "Cua hang - Xac nhan mua", prompt, "Mua", "Huy");
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_BUY_AMOUNT)
    {
        if (response) Company_ReservePurchase(playerid, strval(inputtext));
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_VEHICLE_WAREHOUSE)
    {
        if (!response) return 1;
        if (listitem < 0 || listitem >= DEALERSHIP_VEHICLE_COUNT) return 1;
        g_CompanySelectedVehicleIndex[playerid] = listitem;
        new modelName[32], title[128];
        Dealership_GetModelName(g_DealershipVehicles[listitem][dvModelID], modelName, sizeof(modelName));
        format(title, sizeof(title), "Company Dealer | %s | Ton %d",
            modelName, g_CompanyVehicleStock[playerid][listitem]);
        ShowPlayerDialog(playerid, DIALOG_COMPANY_VEHICLE_ACTION, DIALOG_STYLE_LIST,
            title, "Nhap them phuong tien\nDieu chinh gia ban\nXem lich su giao dich mua xe",
            "Chon", "Quay lai");
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_VEHICLE_ACTION)
    {
        if (!response) return Company_LoadDealerStock(playerid, false);
        new index = g_CompanySelectedVehicleIndex[playerid], modelName[32], prompt[384];
        Dealership_GetModelName(g_DealershipVehicles[index][dvModelID], modelName, sizeof(modelName));
        switch (listitem)
        {
            case 0:
            {
                format(prompt, sizeof(prompt),
                    "Mau xe: %s (Model %d)\nTon hien tai: %d\nGia nhap: $%d/xe\n\nNhap so luong muon nhap (1-1,000):",
                    modelName, g_DealershipVehicles[index][dvModelID],
                    g_CompanyVehicleStock[playerid][index],
                    g_DealershipVehicles[index][dvPrice] * 70 / 100);
                ShowPlayerDialog(playerid, DIALOG_COMPANY_VEHICLE_IMPORT, DIALOG_STYLE_INPUT,
                    "Company Dealer - Nhap phuong tien", prompt, "Nhap xe", "Thoat");
            }
            case 1:
            {
                new currentPrice = g_DealershipBranchPrice[playerid][index] > 0 ?
                    g_DealershipBranchPrice[playerid][index] : g_DealershipVehicles[index][dvPrice];
                format(prompt, sizeof(prompt),
                    "Mau xe: %s\nGia hien tai: $%d\nGia von: $%d\n\nNhap gia ban moi ($1,000-$100,000).\nGia ban khong duoc thap hon gia von:",
                    modelName, currentPrice, g_DealershipVehicles[index][dvPrice] * 70 / 100);
                ShowPlayerDialog(playerid, DIALOG_COMPANY_VEHICLE_PRICE, DIALOG_STYLE_INPUT,
                    "Company Dealer - Dieu chinh gia", prompt, "Luu gia", "Thoat");
            }
            case 2: Company_ShowVehicleLogs(playerid);
        }
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_VEHICLE_IMPORT)
    {
        if (response)
            Company_ImportVehicle(playerid, g_CompanySelectedVehicleIndex[playerid], strval(inputtext));
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_VEHICLE_PRICE)
    {
        if (response)
            Company_SetVehicleSalePrice(playerid, g_CompanySelectedVehicleIndex[playerid], strval(inputtext));
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_VEHICLE_LOGS)
    {
        if (response) Company_LoadDealerStock(playerid, false);
        return 1;
    }
    if (dialogid == DIALOG_COMPANY_TAX_INFO) return 1;
    return 0;
}
