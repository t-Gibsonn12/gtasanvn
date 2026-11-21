#include <YSI_Coding\y_hooks>

// Exclusive city logistics company / Truck Job.
#define TRUCK_HQ_X                 (2187.8900)
#define TRUCK_HQ_Y                 (-2265.5200)
#define TRUCK_HQ_Z                 (13.5469)
#define TRUCK_HQ_A                 (225.0000)
#define TRUCK_HQ_RANGE             (5.0)
#define TRUCK_GARAGE_RANGE         (35.0)
#define TRUCK_COMPANY_SYSTEM_ID    (900001)
#define TRUCK_RENTAL_MODEL         (515)
#define TRUCK_CONTRACT_ROWS        (30)
#define TRUCK_AUTO_REWARD          (700)

new g_TruckContractID[MAX_PLAYERS];
new g_TruckContractStage[MAX_PLAYERS];
new g_TruckContractType[MAX_PLAYERS];
new g_TruckCargoKind[MAX_PLAYERS];
new g_TruckCargoItem[MAX_PLAYERS];
new g_TruckCargoModel[MAX_PLAYERS];
new g_TruckCargoAmount[MAX_PLAYERS];
new g_TruckCargoSalePrice[MAX_PLAYERS];
new g_TruckContractReward[MAX_PLAYERS];
new g_TruckDestinationBranch[MAX_PLAYERS];
new g_TruckMode[MAX_PLAYERS];
new g_TruckTrailer[MAX_PLAYERS] = {INVALID_VEHICLE_ID, ...};
new Float:g_TruckDestinationX[MAX_PLAYERS];
new Float:g_TruckDestinationY[MAX_PLAYERS];
new Float:g_TruckDestinationZ[MAX_PLAYERS];
new g_TruckListID[MAX_PLAYERS][TRUCK_CONTRACT_ROWS];
new g_TruckListRows[MAX_PLAYERS];
new bool:g_TruckAdminComplete[MAX_PLAYERS];
new Text3D:g_TruckCompanyLabel[MAX_VEHICLES] = {Text3D:INVALID_3DTEXT_ID, ...};

forward public Trucking_OnContractsLoaded(playerid);
forward public Trucking_OnContractAccepted(playerid, contractid);
forward public Trucking_OnEmployeeVehicleCreated(playerid);
forward public Trucking_OnEmploymentSigned(playerid);
forward public Trucking_OnDirectContractLoaded(playerid);
forward public Trucking_OnEmployeeProfileLoaded(playerid, page);
forward public Trucking_OnEmployeeMembersLoaded(playerid);
forward public Trucking_OnEmployeeHistoryLoaded(playerid);
forward public Trucking_OnAdminLogsLoaded(playerid);
forward Trucking_LoadCompleted(playerid);
forward Trucking_UnloadCompleted(playerid);
forward Trucking_PickupCompleted(playerid);
forward Trucking_ReturnCompleted(playerid);
forward Trucking_EnsureTrailerAttached(playerid, truckid);
forward Trucking_GenerateAutoContract();
forward bool:Trucking_IsDrivingCompanyVehicle(playerid);

stock Trucking_GetRoleName(kpi, output[], size)
{
    if (kpi <= 0) format(output, size, "Chua co KPI - chua xep vai tro");
    else if (kpi >= 100) format(output, size, "Tai xe truong");
    else if (kpi >= 60) format(output, size, "Tai xe cao cap");
    else if (kpi >= 30) format(output, size, "Tai xe chinh thuc");
    else if (kpi >= 10) format(output, size, "Tai xe tap su");
    else format(output, size, "Nhan vien thu viec");
    return 1;
}

stock Company_ApplyEmployeeDailySettlement(playerid, companyid, insuranceDaily, vehicleFeeDaily)
{
    new query[512];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `company_employee_profiles` SET `payroll_balance`=`payroll_balance`+%d-%d,`insurance_paid_total`=`insurance_paid_total`+%d,`vehicle_fee_total`=`vehicle_fee_total`+%d,`last_daily_settlement`=CURRENT_DATE WHERE `character_id`=%d AND `company_id`=%d AND (`last_daily_settlement` IS NULL OR `last_daily_settlement`<CURRENT_DATE)",
        insuranceDaily, vehicleFeeDaily, insuranceDaily, vehicleFeeDaily,
        GetPlayerCharacterID(playerid), companyid);
    mysql_tquery(g_DatabaseHandle, query);
    return 1;
}

public Company_RecordEmployeeWork(playerid, companyid, contractid, baseReward, const workType[], const routeFrom[], const routeTo[])
{
    // Five IC bonus categories. Labor is $1-$5 and the complete bonus package is always $30.
    new labor = 1 + random(5);
    new safety = 5 + random(3);
    new punctual = 4 + random(3);
    new cargoCare = 4 + random(3);
    new routeBonus = 30 - labor - safety - punctual - cargoCare;
    new kpi = 1 + random(2);
    new grossIncome = baseReward + 30;
    new incomeTax = grossIncome * 2 / 100;
    if (incomeTax < 1) incomeTax = 1;
    new totalIncome = grossIncome - incomeTax;
    new companyProfit = 300 + random(201);
    new orderRef = contractid ? contractid : gettime();
    new taxCode[32], query[1200], details[256];
    format(taxCode, sizeof(taxCode), "LSL-%08d", orderRef);

    Company_ApplyEmployeeDailySettlement(playerid, companyid, 20, 99);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `company_employee_profiles` (`character_id`,`company_id`,`contract_signed_at`) VALUES (%d,%d,CURRENT_TIMESTAMP) ON DUPLICATE KEY UPDATE `kpi_points`=`kpi_points`+%d,`completed_orders`=`completed_orders`+1,`base_salary_total`=`base_salary_total`+%d,`bonus_total`=`bonus_total`+30,`payroll_balance`=`payroll_balance`+%d",
        GetPlayerCharacterID(playerid), companyid, kpi, baseReward, totalIncome);
    mysql_tquery(g_DatabaseHandle, query);
    LSBank_RecordRevenue("company_job_income_tax", incomeTax, GetPlayerCharacterID(playerid));
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `company_work_logs` (`company_id`,`character_id`,`contract_id`,`tax_code`,`work_type`,`route_from`,`route_to`,`base_reward`,`labor_bonus`,`safety_bonus`,`punctual_bonus`,`cargo_care_bonus`,`route_bonus`,`total_income`,`company_profit`,`kpi_earned`) VALUES (%d,%d,%d,'%e','%e','%e','%e',%d,%d,%d,%d,%d,%d,%d,%d,%d)",
        companyid, GetPlayerCharacterID(playerid), contractid,
        taxCode, workType, routeFrom, routeTo, baseReward, labor, safety, punctual,
        cargoCare, routeBonus, totalIncome, companyProfit, kpi);
    mysql_tquery(g_DatabaseHandle, query);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `companies` SET `bank_balance`=`bank_balance`+%d WHERE `company_id`=%d",
        companyProfit, companyid);
    mysql_tquery(g_DatabaseHandle, query);
    Company_AddRuntimeBalance(companyid, companyProfit);
    format(details, sizeof(details), "Don #%d | %s | %s -> %s | loi nhuan $%d | KPI +%d",
        orderRef, workType, routeFrom, routeTo, companyProfit, kpi);
    Company_LogByID(companyid, playerid, "employee_work_profit", details, companyProfit);
    format(details, sizeof(details),
        "Hoan tat don #%d: luong $%d + goi 5 thuong $30 - thue Job $%d = $%d da cong tai khoan luong Company; KPI +%d.",
        orderRef, baseReward, incomeTax, totalIncome, kpi);
    SendClientMessage(playerid, 0x68C83BFF, details);
    return 1;
}

public Trucking_ShowEmployeeCompanyMenu(playerid)
{
    Company_ApplyEmployeeDailySettlement(playerid, TRUCK_COMPANY_SYSTEM_ID, 20, 99);
    ShowPlayerDialog(playerid, DIALOG_TRUCKING_EMPLOYEE_COMPANY, DIALOG_STYLE_LIST,
        "Los Santos Logistics | Cong thong tin nhan vien IC",
        "Thong tin doanh nghiep\nDanh sach thanh vien\nXem hop dong va KPI\nXin nghi viec",
        "Chon", "Dong");
    return 1;
}

stock Trucking_LoadEmployeeProfile(playerid, page)
{
    new query[512];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT e.*,m.`title`,c.`name`,c.`bank_balance` FROM `company_employee_profiles` e INNER JOIN `company_members` m ON m.`character_id`=e.`character_id` AND m.`company_id`=e.`company_id` INNER JOIN `companies` c ON c.`company_id`=e.`company_id` WHERE e.`character_id`=%d AND e.`company_id`=%d LIMIT 1",
        GetPlayerCharacterID(playerid), TRUCK_COMPANY_SYSTEM_ID);
    mysql_tquery(g_DatabaseHandle, query, "Trucking_OnEmployeeProfileLoaded", "dd", playerid, page);
    return 1;
}

public Trucking_OnEmployeeProfileLoaded(playerid, page)
{
    if (!IsPlayerConnected(playerid) || !cache_num_rows())
        return SendClientMessage(playerid, COLOR_RED, "Khong tim thay ho so lao dong Company cua nhan vat.");
    new kpi, orders, payroll, baseTotal, bonusTotal, insurance, vehicleFee, companyBalance;
    new signedAt[24], title[32], companyName[48], role[32], kpiText[48], body[1400];
    cache_get_value_name_int(0, "kpi_points", kpi);
    cache_get_value_name_int(0, "completed_orders", orders);
    cache_get_value_name_int(0, "payroll_balance", payroll);
    cache_get_value_name_int(0, "base_salary_total", baseTotal);
    cache_get_value_name_int(0, "bonus_total", bonusTotal);
    cache_get_value_name_int(0, "insurance_paid_total", insurance);
    cache_get_value_name_int(0, "vehicle_fee_total", vehicleFee);
    cache_get_value_name_int(0, "bank_balance", companyBalance);
    cache_get_value_name(0, "contract_signed_at", signedAt, sizeof(signedAt));
    cache_get_value_name(0, "title", title, sizeof(title));
    cache_get_value_name(0, "name", companyName, sizeof(companyName));
    Trucking_GetRoleName(kpi, role, sizeof(role));
    if (kpi > 0) format(kpiText, sizeof(kpiText), "%d diem", kpi);
    else format(kpiText, sizeof(kpiText), "Chua co KPI");
    if (page == 0)
        format(body, sizeof(body), "TEN PHAP LY: %s\nLoai hinh: Van tai va Logistics\nMa so thue: LSL-900001\nCo quan chu quan: Chinh phu Los Santos / Admin\nTru so: Los Santos Logistics HQ, khu cang Los Santos\nTai khoan doanh nghiep: $%d\n\nLinh vuc IC:\n- Van chuyen hang hoa cho 24/7 va Dealer.\n- Dieu phoi don AUTO va BUSINESS.\n- Cho thue dau keo Roadtrain cho nhan vien hop dong.\n- Bao hiem lao dong va quan ly KPI tai xe.",
            companyName, companyBalance);
    else
        format(body, sizeof(body), "HO SO HOP DONG CA NHAN\nChuc danh: %s\nVai tro hien tai: %s\nKy hop dong luc: %s\nThoi han: Khong xac dinh\n\nKPI: %s\nDon da giao: %d\nTai khoan luong Company: $%d\nTong luong co ban: $%d\nTong thuong lao dong: $%d\nBao hiem Company da chi: $%d\nPhi gia han/thue Roadtrain da tru: $%d\n\nQUY DINH HANG NGAY\nBao hiem lao dong: +$20/ngay\nGia han xe Company: -$99/ngay\nMoi don: luong hop dong + 5 loai thuong tong $30\nKPI moi don: +1 hoac +2 diem.",
            title, role, signedAt, kpiText, orders, payroll, baseTotal, bonusTotal, insurance, vehicleFee);
    ShowPlayerDialog(playerid, DIALOG_TRUCKING_EMPLOYEE_PAGE, DIALOG_STYLE_MSGBOX,
        page == 0 ? "Thong tin doanh nghiep IC" : "Hop dong ca nhan va KPI",
        body, "Quay lai", "Dong");
    return 1;
}

stock Trucking_LoadMembers(playerid)
{
    mysql_tquery(g_DatabaseHandle,
        "SELECT m.`title`,e.`kpi_points`,e.`completed_orders`,e.`contract_signed_at`,ch.`name` FROM `company_members` m LEFT JOIN `company_employee_profiles` e ON e.`character_id`=m.`character_id` AND e.`company_id`=m.`company_id` LEFT JOIN `player_characters` ch ON ch.`character_id`=m.`character_id` WHERE m.`company_id`=900001 ORDER BY m.`rank` DESC,e.`kpi_points` DESC LIMIT 50",
        "Trucking_OnEmployeeMembersLoaded", "d", playerid);
    return 1;
}

public Trucking_OnEmployeeMembersLoaded(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    new body[1900], rows = cache_num_rows();
    format(body, sizeof(body), "Nhan vien\tChuc danh\tKPI\tDon hang\n");
    for (new i; i < rows; i++)
    {
        new name[32], title[32], kpi, orders;
        cache_get_value_name(i, "name", name, sizeof(name));
        cache_get_value_name(i, "title", title, sizeof(title));
        cache_get_value_name_int(i, "kpi_points", kpi);
        cache_get_value_name_int(i, "completed_orders", orders);
        format(body, sizeof(body), "%s%s\t%s\t%d\t%d\n", body, name, title, kpi, orders);
    }
    ShowPlayerDialog(playerid, DIALOG_TRUCKING_EMPLOYEE_PAGE, DIALOG_STYLE_TABLIST_HEADERS,
        "Los Santos Logistics | Danh sach nhan su IC", body, "Quay lai", "Dong");
    return 1;
}

stock Trucking_LoadEmployeeHistory(playerid)
{
    new query[384];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT *,`work_id` AS `delivery_id`,`work_type` AS `cargo_type` FROM `company_work_logs` WHERE `character_id`=%d AND `company_id`=%d ORDER BY `work_id` DESC LIMIT 30",
        GetPlayerCharacterID(playerid), TRUCK_COMPANY_SYSTEM_ID);
    mysql_tquery(g_DatabaseHandle, query, "Trucking_OnEmployeeHistoryLoaded", "d", playerid);
    return 1;
}

public Trucking_OnEmployeeHistoryLoaded(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    new body[3900], rows = cache_num_rows();
    for (new i; i < rows; i++)
    {
        new id, basePay, labor, safety, punctual, care, route, total, kpi;
        new tax[32], cargo[32], from[64], to[64], created[24];
        cache_get_value_name_int(i, "delivery_id", id);
        cache_get_value_name_int(i, "base_reward", basePay);
        cache_get_value_name_int(i, "labor_bonus", labor);
        cache_get_value_name_int(i, "safety_bonus", safety);
        cache_get_value_name_int(i, "punctual_bonus", punctual);
        cache_get_value_name_int(i, "cargo_care_bonus", care);
        cache_get_value_name_int(i, "route_bonus", route);
        cache_get_value_name_int(i, "total_income", total);
        cache_get_value_name_int(i, "kpi_earned", kpi);
        cache_get_value_name(i, "tax_code", tax, sizeof(tax));
        cache_get_value_name(i, "cargo_type", cargo, sizeof(cargo));
        cache_get_value_name(i, "route_from", from, sizeof(from));
        cache_get_value_name(i, "route_to", to, sizeof(to));
        cache_get_value_name(i, "created_at", created, sizeof(created));
        format(body, sizeof(body), "%sDON HANG #%02d | %s\nMa so thue: %s | Loai hang: %s\nGiao tu %s den %s\nLuong: $%d | Thuong lao dong $%d, an toan $%d, dung gio $%d, bao quan $%d, tuyen duong $%d\nTong nhan: $%d | KPI +%d | %s\n\n",
            body, id, tax, tax, cargo, from, to, basePay, labor, safety, punctual, care, route, total, kpi, created);
    }
    if (!rows) format(body, sizeof(body), "Ban chua hoan tat don hang nao cho Company.");
    ShowPlayerDialog(playerid, DIALOG_TRUCKING_EMPLOYEE_HISTORY, DIALOG_STYLE_MSGBOX,
        "Lich su don hang va giao dich ca nhan", body, "Quay lai", "Dong");
    return 1;
}

stock Trucking_ResignEmployment(playerid)
{
    if (g_TruckContractStage[playerid])
        return SendClientMessage(playerid, COLOR_RED, "Hay hoan thanh chuyen hang dang thuc hien truoc khi xin nghi viec.");
    Job_Resign(playerid, JOB_TRUCK);
    new query[384];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "DELETE FROM `company_members` WHERE `company_id`=%d AND `character_id`=%d",
        TRUCK_COMPANY_SYSTEM_ID, GetPlayerCharacterID(playerid));
    mysql_tquery(g_DatabaseHandle, query);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `company_employee_profiles` SET `contract_ended_at`=CURRENT_TIMESTAMP WHERE `character_id`=%d AND `company_id`=%d",
        GetPlayerCharacterID(playerid), TRUCK_COMPANY_SYSTEM_ID);
    mysql_tquery(g_DatabaseHandle, query);
    Company_LogByID(TRUCK_COMPANY_SYSTEM_ID, playerid, "employee_contract_ended",
        "Nhan vien gui don xin nghi va cham dut hop dong dai han", 0);
    Company_ResetPlayer(playerid);
    Trucking_RevokeVehicles(playerid);
    SendClientMessage(playerid, COLOR_WHITE,
        "Don xin nghi da duoc chap thuan. Hop dong da cham dut, xe Company da thu hoi; ho so va lich su van duoc luu.");
    return 1;
}

stock Trucking_LoadAdminLogs(playerid)
{
    mysql_tquery(g_DatabaseHandle,
        "SELECT l.*,l.`work_id` AS `delivery_id`,l.`work_type` AS `cargo_type`,ch.`name` FROM `company_work_logs` l LEFT JOIN `player_characters` ch ON ch.`character_id`=l.`character_id` WHERE l.`company_id`=900001 ORDER BY l.`work_id` DESC LIMIT 30",
        "Trucking_OnAdminLogsLoaded", "d", playerid);
    return 1;
}

public Trucking_OnAdminLogsLoaded(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    new body[3900], rows = cache_num_rows(), totalProfit;
    for (new i; i < rows; i++)
    {
        new id, income, profit, kpi, name[32], tax[32], cargo[32], created[24];
        cache_get_value_name_int(i, "delivery_id", id);
        cache_get_value_name_int(i, "total_income", income);
        cache_get_value_name_int(i, "company_profit", profit);
        cache_get_value_name_int(i, "kpi_earned", kpi);
        cache_get_value_name(i, "name", name, sizeof(name));
        cache_get_value_name(i, "tax_code", tax, sizeof(tax));
        cache_get_value_name(i, "cargo_type", cargo, sizeof(cargo));
        cache_get_value_name(i, "created_at", created, sizeof(created));
        totalProfit += profit;
        format(body, sizeof(body), "%s#%02d | %s | %s | %s | Luong $%d | Loi nhuan $%d | KPI +%d | %s\n",
            body, id, name, tax, cargo, income, profit, kpi, created);
    }
    new title[128];
    format(title, sizeof(title), "Admin Logistics | 30 don gan nhat | Loi nhuan $%d", totalProfit);
    if (!rows) format(body, sizeof(body), "Chua co du lieu giao hang.");
    ShowPlayerDialog(playerid, DIALOG_TRUCKING_ADMIN_LOGS, DIALOG_STYLE_MSGBOX,
        title, body, "Dong", "");
    return 1;
}

stock Trucking_ResetPlayer(playerid)
{
    if (g_TruckTrailer[playerid] != INVALID_VEHICLE_ID &&
        IsValidVehicle(g_TruckTrailer[playerid]))
    {
        DestroyVehicle(g_TruckTrailer[playerid]);
    }
    g_TruckTrailer[playerid] = INVALID_VEHICLE_ID;
    g_TruckMode[playerid] = 0;
    g_TruckAdminComplete[playerid] = false;
    g_TruckContractID[playerid] = 0;
    g_TruckContractStage[playerid] = 0;
    g_TruckListRows[playerid] = 0;
    return 1;
}

stock Trucking_AttachCargoTrailer(playerid)
{
    if (!Trucking_IsDrivingCompanyVehicle(playerid)) return 0;
    new truckid = GetPlayerVehicleID(playerid);
    new Float:x, Float:y, Float:z, Float:a;
    GetVehiclePos(truckid, x, y, z);
    GetVehicleZAngle(truckid, a);
    x -= floatsin(a, degrees) * 7.0;
    y -= floatcos(a, degrees) * 7.0;
    g_TruckTrailer[playerid] = CreateVehicle(435, x, y, z + 0.3, a, 1, 1, -1);
    if (g_TruckTrailer[playerid] == INVALID_VEHICLE_ID) return 0;
    AttachTrailerToVehicle(g_TruckTrailer[playerid], truckid);
    SetTimerEx("Trucking_EnsureTrailerAttached", 750, false, "dd", playerid, truckid);
    return 1;
}

public Trucking_EnsureTrailerAttached(playerid, truckid)
{
    if (!IsPlayerConnected(playerid) || !IsValidVehicle(truckid) ||
        g_TruckTrailer[playerid] == INVALID_VEHICLE_ID ||
        !IsValidVehicle(g_TruckTrailer[playerid])) return 1;
    AttachTrailerToVehicle(g_TruckTrailer[playerid], truckid);
    if (GetVehicleTrailer(truckid) == g_TruckTrailer[playerid])
        SendClientMessage(playerid, 0x68C83BFF, "Trailer Company da duoc gan tu dong vao dau keo, hay kiem tra hang truoc khi khoi hanh.");
    return 1;
}

public Trucking_AttachCompanyVehicleLabel(playerid, slot, vehicleid)
{
    if (vehicleid < 1 || vehicleid >= MAX_VEHICLES ||
        !PlayerVehicle[playerid][slot][pvCompanyVehicle] ||
        PlayerVehicle[playerid][slot][pvCompanyID] != TRUCK_COMPANY_SYSTEM_ID) return 1;
    Trucking_RemoveCompanyVehicleLabel(vehicleid);
    new label[160];
    format(label, sizeof(label),
        "{68C83B}LOS SANTOS LOGISTICS\n{FFFFFF}COMPANY VEHICLE\nBien so: {68C83B}%s",
        PlayerVehicle[playerid][slot][pvPlate]);
    g_TruckCompanyLabel[vehicleid] = Create3DTextLabel(label, COLOR_WHITE,
        0.0, 0.0, 0.0, 18.0, PlayerVehicle[playerid][slot][pvVirtualWorld], false);
    Attach3DTextLabelToVehicle(g_TruckCompanyLabel[vehicleid], vehicleid, 0.0, 0.0, 1.7);
    return 1;
}

public Trucking_RemoveCompanyVehicleLabel(vehicleid)
{
    if (vehicleid < 1 || vehicleid >= MAX_VEHICLES) return 1;
    if (g_TruckCompanyLabel[vehicleid] != Text3D:INVALID_3DTEXT_ID)
    {
        Delete3DTextLabel(g_TruckCompanyLabel[vehicleid]);
        g_TruckCompanyLabel[vehicleid] = Text3D:INVALID_3DTEXT_ID;
    }
    return 1;
}

stock bool:Trucking_HasCargoTrailer(playerid)
{
    if (!Trucking_IsDrivingCompanyVehicle(playerid) ||
        g_TruckTrailer[playerid] == INVALID_VEHICLE_ID ||
        !IsValidVehicle(g_TruckTrailer[playerid]))
    {
        return false;
    }
    return GetVehicleTrailer(GetPlayerVehicleID(playerid)) == g_TruckTrailer[playerid];
}

stock bool:Trucking_IsAtHQ(playerid)
{
    return GetPlayerInterior(playerid) == 0 && GetPlayerVirtualWorld(playerid) == 0 &&
        IsPlayerInRangeOfPoint(playerid, TRUCK_HQ_RANGE, TRUCK_HQ_X, TRUCK_HQ_Y, TRUCK_HQ_Z);
}

stock bool:Trucking_IsCompanyEmployee(playerid)
{
    // Company membership is the long-term employment source of truth.
    // Job progress may still be loading for a few moments after character login.
    return g_PlayerCompanyID[playerid] == TRUCK_COMPANY_SYSTEM_ID &&
        g_PlayerCompanyRank[playerid] >= 1;
}

public bool:Trucking_CanStoreCompanyVehicle(playerid, slot)
{
    #pragma unused slot
    if (GetPlayerInterior(playerid) == 0 &&
        GetPlayerVirtualWorld(playerid) == 0 &&
        IsPlayerInRangeOfPoint(playerid, TRUCK_GARAGE_RANGE, TRUCK_HQ_X, TRUCK_HQ_Y, TRUCK_HQ_Z))
    {
        return true;
    }
    SendClientMessage(playerid, COLOR_RED,
        "Roadtrain la tai san Company, chi duoc do va cat tai garage Los Santos Logistics o HQ Truck.");
    return false;
}

stock Trucking_ShowEmploymentContract(playerid)
{
    new body[1200];
    format(body, sizeof(body),
        "{68C83B}HOP DONG LAO DONG DAI HAN - LOS SANTOS LOGISTICS\n\n{FFFFFF}Chuc danh: Tai xe van tai\nThoi han: Khong xac dinh, co hieu luc den khi nhan vien nghi viec hoac bi quan ly cham dut.\nQuan ly: Company do doi ngu Admin dieu hanh; quyen quan ly co the duoc giao cho nguoi choi sau.\n\n{68C83B}PHUONG TIEN THUE\n{FFFFFF}Company cap 01 Roadtrain model 515, khong thu tien dat coc va khong thu phi thue co dinh.\nXe van nam trong /vehicles voi nhan COMPANY VEHICLE nhung van thuoc tai san Company.\nRoadtrain chi duoc do/cat tai garage HQ Truck; khi cham dut hop dong xe se bi thu hoi.\n\n{68C83B}DON HANG VA THU NHAP\n{FFFFFF}AUTO: don do server tao, muc thuong co ban $%d.\nBUSINESS: don that tu Company 24/7/Dealer, thuong cao hon tuy gia tri lo hang.\nHang chi vao kho doanh nghiep sau khi giao thanh cong.\nTai xe phai dung dung COMPANY VEHICLE de boc va do hang.\n\n{FFFFFF}Bam {68C83B}KY HOP DONG {FFFFFF}de dong y toan bo dieu khoan.",
        TRUCK_AUTO_REWARD);
    ShowPlayerDialog(playerid, DIALOG_TRUCKING_CONTRACT_CONFIRM, DIALOG_STYLE_MSGBOX,
        "Los Santos Logistics | Hop dong lao dong", body, "Ky hop dong", "Tu choi");
    return 1;
}

stock Trucking_SignEmploymentContract(playerid)
{
    if (g_PlayerCompanyID[playerid] && g_PlayerCompanyID[playerid] != TRUCK_COMPANY_SYSTEM_ID)
        return SendClientMessage(playerid, COLOR_RED,
            "Ban dang thuoc mot Company khac, khong the ky hop dong doc quyen voi Los Santos Logistics.");
    if (!Job_Hire(playerid, JOB_TRUCK, 0, 0))
        return SendClientMessage(playerid, COLOR_RED,
            "Du lieu nghe nghiep chua san sang hoac hop dong Truck Job da ton tai.");

    new query[512];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT IGNORE INTO `company_members` (`company_id`,`character_id`,`rank`,`title`) VALUES (%d,%d,1,'Tai xe van tai')",
        TRUCK_COMPANY_SYSTEM_ID, GetPlayerCharacterID(playerid));
    mysql_tquery(g_DatabaseHandle, query, "Trucking_OnEmploymentSigned", "d", playerid);
    return 1;
}

public Trucking_OnEmploymentSigned(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    new query[384];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `company_employee_profiles` (`character_id`,`company_id`,`contract_signed_at`) VALUES (%d,%d,CURRENT_TIMESTAMP) ON DUPLICATE KEY UPDATE `contract_signed_at`=CURRENT_TIMESTAMP,`contract_ended_at`=NULL",
        GetPlayerCharacterID(playerid), TRUCK_COMPANY_SYSTEM_ID);
    mysql_tquery(g_DatabaseHandle, query);
    Company_LoadForCharacter(playerid);
    Trucking_ProvisionVehicle(playerid);
    Company_LogByID(TRUCK_COMPANY_SYSTEM_ID, playerid, "employee_contract_signed",
        "Ky hop dong dai han, chuc danh Tai xe van tai", 0);
    SendClientMessage(playerid, 0x68C83BFF,
        "Da ky hop dong dai han va gia nhap Company Los Santos Logistics. Roadtrain da duoc cap trong /vehicles.");
    return 1;
}

stock bool:Trucking_IsDrivingCompanyVehicle(playerid)
{
    if (GetPlayerState(playerid) != PLAYER_STATE_DRIVER) return false;

    new vehicleid = GetPlayerVehicleID(playerid);
    new ownerid, slot;
    if (!SimpleVehicle_GetRuntimeOwner(vehicleid, ownerid, slot) || ownerid != playerid)
        return false;

    return PlayerVehicle[playerid][slot][pvCompanyVehicle] == 1 &&
        PlayerVehicle[playerid][slot][pvCompanyID] == TRUCK_COMPANY_SYSTEM_ID;
}

stock Trucking_ShowMain(playerid)
{
    new body[256];
    if (!Trucking_IsCompanyEmployee(playerid))
        format(body, sizeof(body), "Xin viec tai Los Santos Logistics\nXem gioi thieu cong viec");
    else
        format(body, sizeof(body), "Danh sach don van chuyen\nHop dong dang thuc hien\nThong tin xe Company\nNghi viec va tra xe");
    ShowPlayerDialog(playerid, DIALOG_TRUCKING_MAIN, DIALOG_STYLE_LIST,
        "Los Santos Logistics | Truck Job", body, "Chon", "Dong");
    return 1;
}

public Trucking_ApproveCompanyApplicant(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    Job_Hire(playerid, JOB_TRUCK, 0, 0);
    return Trucking_OnEmploymentSigned(playerid);
}

stock Trucking_ProvisionVehicle(playerid)
{
    new query[768], plate[17];
    format(plate, sizeof(plate), "LSL-%05d", GetPlayerCharacterID(playerid) % 100000);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `player_vehicles` (`owner_character_id`,`model_id`,`plate`,`color_1`,`color_2`,`park_x`,`park_y`,`park_z`,`park_a`,`interior_id`,`virtual_world`,`health`,`fuel_liters`,`storage_state`,`is_locked`,`company_vehicle`,`company_id`,`company_note`) SELECT %d,%d,'%e',1,1,%f,%f,%f,%f,0,0,1000.0,100.0,0,0,1,%d,'LOS SANTOS LOGISTICS' WHERE NOT EXISTS (SELECT 1 FROM `player_vehicles` WHERE `owner_character_id`=%d AND `company_vehicle`=1 AND `company_id`=%d AND `deleted_at` IS NULL)",
        GetPlayerCharacterID(playerid), TRUCK_RENTAL_MODEL, plate,
        TRUCK_HQ_X + 8.0, TRUCK_HQ_Y, TRUCK_HQ_Z, TRUCK_HQ_A,
        TRUCK_COMPANY_SYSTEM_ID, GetPlayerCharacterID(playerid), TRUCK_COMPANY_SYSTEM_ID);
    mysql_tquery(g_DatabaseHandle, query, "Trucking_OnEmployeeVehicleCreated", "d", playerid);
    return 1;
}

public Trucking_OnEmployeeVehicleCreated(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    SimpleVehicle_Load(playerid);
    SendClientMessage(playerid, 0x68C83BFF, "Los Santos Logistics da cap Roadtrain vao /vehicles voi ghi chu COMPANY VEHICLE.");
    return 1;
}

stock Trucking_RevokeVehicles(playerid)
{
    new query[384];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `player_vehicles` SET `deleted_at`=CURRENT_TIMESTAMP,`storage_state`=0 WHERE `owner_character_id`=%d AND `company_vehicle`=1 AND `company_id`=%d AND `deleted_at` IS NULL",
        GetPlayerCharacterID(playerid), TRUCK_COMPANY_SYSTEM_ID);
    mysql_tquery(g_DatabaseHandle, query);
    SimpleVehicle_Load(playerid);
    return 1;
}

stock Trucking_ShowContracts(playerid)
{
    mysql_tquery(g_DatabaseHandle,
        "SELECT `contract_id`,`contract_type`,`cargo_kind`,`cargo_amount`,`reward`,`created_by` FROM `trucking_contracts` WHERE `status`='OPEN' ORDER BY (`contract_type`='BUSINESS') DESC,`reward` DESC LIMIT 30",
        "Trucking_OnContractsLoaded", "d", playerid);
    return 1;
}

public Trucking_OnContractsLoaded(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    new rows = cache_num_rows(), body[1800];
    g_TruckListRows[playerid] = rows;
    for (new row = 0; row < rows; row++)
    {
        new id, amount, reward, type[16], kind[16], creator[32];
        cache_get_value_name_int(row, "contract_id", id);
        cache_get_value_name_int(row, "cargo_amount", amount);
        cache_get_value_name_int(row, "reward", reward);
        cache_get_value_name(row, "contract_type", type, sizeof(type));
        cache_get_value_name(row, "cargo_kind", kind, sizeof(kind));
        cache_get_value_name(row, "created_by", creator, sizeof(creator));
        g_TruckListID[playerid][row] = id;
        format(body, sizeof(body), "%s#%d\t%s\t%s x%d\t$%d\t%s\n",
            body, id, type, kind, amount, reward, creator);
    }
    if (!rows) format(body, sizeof(body), "Hien khong co don van chuyen dang cho.");
    ShowPlayerDialog(playerid, DIALOG_TRUCKING_CONTRACTS, DIALOG_STYLE_TABLIST,
        "Truck Contracts | BUSINESS tra cao hon AUTO", body, "Nhan don", "Dong");
    return 1;
}

stock Trucking_AcceptContract(playerid, contractid)
{
    if (g_TruckContractID[playerid])
        return SendClientMessage(playerid, COLOR_RED, "Ban dang thuc hien mot hop dong van tai khac.");
    new query[384];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `trucking_contracts` SET `status`='ASSIGNED',`driver_character_id`=%d,`accepted_at`=CURRENT_TIMESTAMP WHERE `contract_id`=%d AND `status`='OPEN'",
        GetPlayerCharacterID(playerid), contractid);
    mysql_tquery(g_DatabaseHandle, query, "Trucking_OnContractAccepted", "dd", playerid, contractid);
    return 1;
}

public Trucking_OnContractAccepted(playerid, contractid)
{
    if (!IsPlayerConnected(playerid) || cache_affected_rows() != 1)
        return SendClientMessage(playerid, COLOR_RED, "Don nay da duoc tai xe khac nhan.");
    new query[384];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT * FROM `trucking_contracts` WHERE `contract_id`=%d AND `driver_character_id`=%d LIMIT 1",
        contractid, GetPlayerCharacterID(playerid));
    new Cache:result = mysql_query(g_DatabaseHandle, query);
    if (!cache_num_rows())
    {
        cache_delete(result);
        return 1;
    }
    new type[16], kind[16];
    cache_get_value_name(0, "contract_type", type, sizeof(type));
    cache_get_value_name(0, "cargo_kind", kind, sizeof(kind));
    g_TruckContractType[playerid] = !strcmp(type, "BUSINESS", true) ? 1 : 0;
    g_TruckCargoKind[playerid] = !strcmp(kind, "VEHICLE", true) ? 2 : (!strcmp(kind, "RETAIL", true) ? 1 : 0);
    cache_get_value_name_int(0, "item_id", g_TruckCargoItem[playerid]);
    cache_get_value_name_int(0, "model_id", g_TruckCargoModel[playerid]);
    cache_get_value_name_int(0, "cargo_amount", g_TruckCargoAmount[playerid]);
    cache_get_value_name_int(0, "sale_price", g_TruckCargoSalePrice[playerid]);
    cache_get_value_name_int(0, "reward", g_TruckContractReward[playerid]);
    cache_get_value_name_int(0, "destination_branch_id", g_TruckDestinationBranch[playerid]);
    cache_get_value_name_float(0, "destination_x", g_TruckDestinationX[playerid]);
    cache_get_value_name_float(0, "destination_y", g_TruckDestinationY[playerid]);
    cache_get_value_name_float(0, "destination_z", g_TruckDestinationZ[playerid]);
    cache_delete(result);
    g_TruckContractID[playerid] = contractid;
    g_TruckContractStage[playerid] = 1;
    SetPlayerCheckpoint(playerid, TRUCK_HQ_X, TRUCK_HQ_Y, TRUCK_HQ_Z, 5.0);
    SendClientMessage(playerid, 0x68C83BFF, "Da nhan don. Lay COMPANY VEHICLE trong /vehicles, lai den bai hang HQ va bam Y de boc hang.");
    return 1;
}

public Trucking_LoadCompleted(playerid)
{
    if (!IsPlayerConnected(playerid) || g_TruckContractStage[playerid] != 1) return 1;
    if (!Trucking_AttachCargoTrailer(playerid))
        return SendClientMessage(playerid, COLOR_RED, "Khong the gan trailer hang. Hay ngoi dung Roadtrain Company va thu lai.");
    g_TruckContractStage[playerid] = 2;
    SetPlayerCheckpoint(playerid, g_TruckDestinationX[playerid], g_TruckDestinationY[playerid], g_TruckDestinationZ[playerid], 6.0);
    SendClientMessage(playerid, 0x68C83BFF, "Da boc hang. GPS da danh dau diem giao; den noi va bam Y de do hang.");
    return 1;
}

public Trucking_UnloadCompleted(playerid)
{
    if (!IsPlayerConnected(playerid) || g_TruckContractStage[playerid] != 2) return 1;
    if (!g_TruckAdminComplete[playerid] && !Trucking_HasCargoTrailer(playerid))
        return SendClientMessage(playerid, COLOR_RED, "Trailer hang khong con gan voi Roadtrain, khong the hoan tat giao hang.");
    new query[768];
    if (g_TruckCargoKind[playerid] == 1)
    {
        new E_ITEM_ID:itemid = E_ITEM_ID:g_TruckCargoItem[playerid];
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "INSERT INTO `company_warehouse` (`company_id`,`branch_id`,`item_id`,`item_name`,`amount`,`unit_price`) SELECT `company_id`,%d,%d,'%e',%d,%d FROM `company_branches` WHERE `branch_id`=%d ON DUPLICATE KEY UPDATE `amount`=`amount`+VALUES(`amount`),`unit_price`=VALUES(`unit_price`)",
            g_TruckDestinationBranch[playerid], _:itemid, g_ItemData[itemid][itemName],
            g_TruckCargoAmount[playerid], g_TruckCargoSalePrice[playerid], g_TruckDestinationBranch[playerid]);
        mysql_tquery(g_DatabaseHandle, query);
    }
    else if (g_TruckCargoKind[playerid] == 2)
    {
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "INSERT INTO `company_vehicle_stock` (`company_id`,`branch_id`,`model_id`,`amount`,`sale_price`,`wholesale_price`) SELECT `company_id`,%d,%d,%d,%d,%d FROM `company_branches` WHERE `branch_id`=%d ON DUPLICATE KEY UPDATE `amount`=`amount`+VALUES(`amount`)",
            g_TruckDestinationBranch[playerid], g_TruckCargoModel[playerid],
            g_TruckCargoAmount[playerid], g_TruckCargoSalePrice[playerid],
            g_TruckCargoSalePrice[playerid] * 70 / 100, g_TruckDestinationBranch[playerid]);
        mysql_tquery(g_DatabaseHandle, query);
    }
    new routeTo[64], cargoName[32];
    format(routeTo, sizeof(routeTo), "%s",
        g_TruckDestinationBranch[playerid] ? "Chi nhanh Company dat hang" : "Cua hang ngau nhien Los Santos");
    format(cargoName, sizeof(cargoName), "%s",
        g_TruckCargoKind[playerid] == 2 ? "Lo phuong tien" :
        (g_TruckCargoKind[playerid] == 1 ? "Hang hoa 24/7" : "Hang tong hop"));
    Company_RecordEmployeeWork(playerid, TRUCK_COMPANY_SYSTEM_ID, g_TruckContractID[playerid],
        g_TruckContractReward[playerid], cargoName, "Kho Los Santos Logistics HQ", routeTo);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `trucking_contracts` SET `status`='COMPLETED',`completed_at`=CURRENT_TIMESTAMP WHERE `contract_id`=%d AND `driver_character_id`=%d",
        g_TruckContractID[playerid], GetPlayerCharacterID(playerid));
    mysql_tquery(g_DatabaseHandle, query);
    Job_AddExperience(playerid, JOB_TRUCK, 20);
    DisablePlayerCheckpoint(playerid);
    SendClientMessage(playerid, 0x68C83BFF, "Giao hang thanh cong. Checkpoint da duoc xoa, trailer da ban giao va tien cong da thanh toan.");
    Trucking_ResetPlayer(playerid);
    return 1;
}

public Trucking_PickupCompleted(playerid)
{
    if (!IsPlayerConnected(playerid) || g_TruckMode[playerid] != 2 ||
        g_TruckContractStage[playerid] != 3) return 1;
    if (!Trucking_AttachCargoTrailer(playerid))
        return SendClientMessage(playerid, COLOR_RED, "Khong the gan container. Hay ngoi dung Roadtrain Company va thu lai.");
    g_TruckContractStage[playerid] = 4;
    DisablePlayerCheckpoint(playerid);
    SetPlayerCheckpoint(playerid, TRUCK_HQ_X, TRUCK_HQ_Y, TRUCK_HQ_Z, 7.0);
    SendClientMessage(playerid, 0x68C83BFF, "Da nhan container. Mang trailer ve garage HQ Truck va bam Y de ban giao.");
    return 1;
}

public Trucking_ReturnCompleted(playerid)
{
    if (!IsPlayerConnected(playerid) || g_TruckMode[playerid] != 2 ||
        g_TruckContractStage[playerid] != 4) return 1;
    if (!g_TruckAdminComplete[playerid] && !Trucking_HasCargoTrailer(playerid))
        return SendClientMessage(playerid, COLOR_RED, "Ban phai mang dung container da nhan ve HQ Truck.");
    Company_RecordEmployeeWork(playerid, TRUCK_COMPANY_SYSTEM_ID, 0, g_TruckContractReward[playerid],
        "Container nhap kho", "Diem cung ung ngoai thanh", "Kho Los Santos Logistics HQ");
    Job_AddExperience(playerid, JOB_TRUCK, 15);
    DisablePlayerCheckpoint(playerid);
    SendClientMessage(playerid, 0x68C83BFF, "Da ban giao container tai HQ. Checkpoint da xoa va tien cong da thanh toan.");
    Trucking_ResetPlayer(playerid);
    return 1;
}

stock Trucking_StartPickupRoute(playerid)
{
    static const Float:pickupRoutes[][3] =
    {
        {2744.9150, -2453.8201, 13.6484},
        {1012.1559, -2117.6118, 13.0938},
        {-77.4362, -1136.4066, 1.0781},
        {1654.3087, -1840.4694, 13.5469}
    };
    new route = random(sizeof(pickupRoutes));
    g_TruckMode[playerid] = 2;
    g_TruckContractStage[playerid] = 3;
    g_TruckContractReward[playerid] = 850 + random(651);
    g_TruckDestinationX[playerid] = pickupRoutes[route][0];
    g_TruckDestinationY[playerid] = pickupRoutes[route][1];
    g_TruckDestinationZ[playerid] = pickupRoutes[route][2];
    DisablePlayerCheckpoint(playerid);
    SetPlayerCheckpoint(playerid, g_TruckDestinationX[playerid], g_TruckDestinationY[playerid], g_TruckDestinationZ[playerid], 7.0);
    SendClientMessage(playerid, 0x68C83BFF, "Don LAY HANG da bat dau. GPS da danh dau diem nhan container; den do va bam Y.");
    return 1;
}

stock Trucking_StartDeliveryRoute(playerid)
{
    mysql_tquery(g_DatabaseHandle,
        "SELECT `contract_id` FROM `trucking_contracts` WHERE `status`='OPEN' ORDER BY (`contract_type`='BUSINESS') DESC,`reward` DESC LIMIT 1",
        "Trucking_OnDirectContractLoaded", "d", playerid);
    SendClientMessage(playerid, COLOR_WHITE, "Dang tim don giao hang phu hop tu he thong va cac Company...");
    return 1;
}

stock Trucking_ShowWorkDialog(playerid)
{
    ShowPlayerDialog(playerid, DIALOG_TRUCKING_WORK, DIALOG_STYLE_LIST,
        "Los Santos Logistics | Chon chuyen hang",
        "Giao hang\tHQ Truck -> Cua hang/Company\nLay hang\tDiem nhan -> HQ Truck",
        "Chon", "Dong");
    return 1;
}

public Trucking_OnDirectContractLoaded(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    if (!cache_num_rows())
        return SendClientMessage(playerid, COLOR_RED, "Hien khong co don giao hang. Hay thu lai sau khi AUTO tao don moi.");
    new contractid;
    cache_get_value_name_int(0, "contract_id", contractid);
    g_TruckMode[playerid] = 1;
    return Trucking_AcceptContract(playerid, contractid);
}

public Trucking_CreateRetailOrder(playerid, itemid, amount, salePrice, supplierCost)
{
    new branch = g_PlayerCompanyBranch[playerid];
    if (branch < 0) return 0;
    new reward = supplierCost * 15 / 100;
    if (reward < 1500) reward = 1500;
    new total = supplierCost + reward;
    if (Company_GetBalance(g_PlayerCompanyID[playerid]) < total)
        return SendClientMessage(playerid, COLOR_RED, "Company khong du tien thanh toan gia hang va phi van chuyen.");
    Company_AddRuntimeBalance(g_PlayerCompanyID[playerid], -total);
    new query[768];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `companies` SET `bank_balance`=`bank_balance`-%d WHERE `company_id`=%d", total, g_PlayerCompanyID[playerid]);
    mysql_tquery(g_DatabaseHandle, query);
    new details[160];
    format(details, sizeof(details), "Dat lo hang 24/7 x%d, gia hang $%d, phi van chuyen $%d",
        amount, supplierCost, reward);
    Company_LogByID(g_PlayerCompanyID[playerid], playerid, "transport_order_created", details, -total);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `trucking_contracts` (`contract_type`,`created_by`,`source_company_id`,`destination_branch_id`,`cargo_kind`,`item_id`,`cargo_amount`,`sale_price`,`supplier_cost`,`reward`,`destination_x`,`destination_y`,`destination_z`) VALUES ('BUSINESS','%e',%d,%d,'RETAIL',%d,%d,%d,%d,%d,%f,%f,%f)",
        g_PlayerCompanyName[playerid], g_PlayerCompanyID[playerid], g_CompanyBranch[branch][cbDatabaseID],
        itemid, amount, salePrice, supplierCost, reward,
        g_CompanyBranch[branch][cbX], g_CompanyBranch[branch][cbY], g_CompanyBranch[branch][cbZ]);
    mysql_tquery(g_DatabaseHandle, query);
    SendClientMessage(playerid, 0x68C83BFF, "Da dat lo hang. Hang chi vao kho sau khi tai xe Los Santos Logistics giao thanh cong.");
    return 1;
}

public Trucking_CreateVehicleOrder(playerid, vehicleIndex, amount, supplierCost)
{
    new branch = g_PlayerCompanyBranch[playerid];
    if (branch < 0) return 0;
    new reward = supplierCost * 12 / 100;
    if (reward < 2500) reward = 2500;
    new total = supplierCost + reward;
    if (Company_GetBalance(g_PlayerCompanyID[playerid]) < total)
        return SendClientMessage(playerid, COLOR_RED, "Company khong du tien thanh toan lo xe va phi van chuyen.");
    Company_AddRuntimeBalance(g_PlayerCompanyID[playerid], -total);
    new query[768];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `companies` SET `bank_balance`=`bank_balance`-%d WHERE `company_id`=%d", total, g_PlayerCompanyID[playerid]);
    mysql_tquery(g_DatabaseHandle, query);
    new details[160];
    format(details, sizeof(details), "Dat lo xe model %d x%d, gia lo $%d, phi van chuyen $%d",
        g_DealershipVehicles[vehicleIndex][dvModelID], amount, supplierCost, reward);
    Company_LogByID(g_PlayerCompanyID[playerid], playerid, "vehicle_transport_order_created", details, -total);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `trucking_contracts` (`contract_type`,`created_by`,`source_company_id`,`destination_branch_id`,`cargo_kind`,`model_id`,`cargo_amount`,`sale_price`,`supplier_cost`,`reward`,`destination_x`,`destination_y`,`destination_z`) VALUES ('BUSINESS','%e',%d,%d,'VEHICLE',%d,%d,%d,%d,%d,%f,%f,%f)",
        g_PlayerCompanyName[playerid], g_PlayerCompanyID[playerid], g_CompanyBranch[branch][cbDatabaseID],
        g_DealershipVehicles[vehicleIndex][dvModelID], amount,
        g_DealershipVehicles[vehicleIndex][dvPrice], supplierCost, reward,
        g_CompanyBranch[branch][cbX], g_CompanyBranch[branch][cbY], g_CompanyBranch[branch][cbZ]);
    mysql_tquery(g_DatabaseHandle, query);
    SendClientMessage(playerid, 0x68C83BFF, "Da dat lo xe. Ton kho Dealer chi tang sau khi Truck Job giao thanh cong.");
    return 1;
}

public Trucking_GenerateAutoContract()
{
    static const Float:storeRoutes[][3] =
    {
        {1833.2291, -1848.2380, 13.5781},
        {1315.4928, -897.6826, 39.5781},
        {2421.4000, -1508.2000, 23.9900},
        {1000.5317, -920.1849, 42.3281}
    };
    new route = random(sizeof(storeRoutes)), query[640];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `trucking_contracts` (`contract_type`,`created_by`,`cargo_kind`,`cargo_amount`,`reward`,`destination_x`,`destination_y`,`destination_z`) SELECT 'AUTO','SERVER AUTO','GENERAL',100,700,%f,%f,%f WHERE (SELECT COUNT(*) FROM `trucking_contracts` WHERE `status`='OPEN' AND `contract_type`='AUTO')<3",
        storeRoutes[route][0], storeRoutes[route][1], storeRoutes[route][2]);
    mysql_tquery(g_DatabaseHandle, query);
    return 1;
}

CMD:truck(playerid, params[])
{
    if (!Trucking_IsCompanyEmployee(playerid))
        return SendClientMessage(playerid, COLOR_RED, "Ban chua ky hop dong lao dong voi Los Santos Logistics.");
    if (!Trucking_IsDrivingCompanyVehicle(playerid))
        return SendClientMessage(playerid, COLOR_RED, "Ban phai ngoi ghe lai Roadtrain COMPANY VEHICLE de su dung /truck.");
    if (g_TruckContractStage[playerid])
        return SendClientMessage(playerid, COLOR_RED, "Ban dang thuc hien mot chuyen hang, hay hoan thanh truoc khi nhan don moi.");
    if (!strlen(params))
        return Trucking_ShowWorkDialog(playerid);
    if (!strcmp(params, "giaohang", true) || !strcmp(params, "giao hang", true))
        return Trucking_StartDeliveryRoute(playerid);
    if (!strcmp(params, "layhang", true) || !strcmp(params, "lay hang", true))
        return Trucking_StartPickupRoute(playerid);
    return SendClientMessage(playerid, COLOR_WHITE, "Su dung: /truck [giaohang/layhang]");
}

CMD:gototruck(playerid, params[])
{
    #pragma unused params
    SetPlayerInterior(playerid, 0);
    SetPlayerVirtualWorld(playerid, 0);
    SetPlayerPos(playerid, TRUCK_HQ_X, TRUCK_HQ_Y, TRUCK_HQ_Z);
    return 1;
}

CMD:truckadmin(playerid, params[])
{
    #pragma unused params
    if (!Admin_RequireLevel(playerid, ADMIN_LEVEL_ADMIN)) return 1;
    return Trucking_LoadAdminLogs(playerid);
}

CMD:truckcomplete(playerid, params[])
{
    #pragma unused params
    if (!Admin_RequireLevel(playerid, ADMIN_LEVEL_ADMIN)) return 1;
    if (!g_TruckContractStage[playerid])
        return SendClientMessage(playerid, COLOR_RED, "Ban khong co chuyen Truck nao de hoan thanh nhanh.");
    g_TruckAdminComplete[playerid] = true;
    if (g_TruckMode[playerid] == 2)
    {
        g_TruckContractStage[playerid] = 4;
        SendClientMessage(playerid, COLOR_ADMIN_CHAT, "[ADMIN TEST] Dang hoan tat nhanh don lay container ve HQ.");
        return Trucking_ReturnCompleted(playerid);
    }
    g_TruckContractStage[playerid] = 2;
    SendClientMessage(playerid, COLOR_ADMIN_CHAT, "[ADMIN TEST] Dang hoan tat nhanh don giao hang va ghi day du KPI/log/loi nhuan.");
    return Trucking_UnloadCompleted(playerid);
}

hook OnGameModeInit()
{
    Job_Register(JOB_TRUCK, "Truck Driver");
    mysql_tquery(g_DatabaseHandle, "ALTER TABLE `companies` ADD COLUMN IF NOT EXISTS `government_owned` TINYINT UNSIGNED NOT NULL DEFAULT 0,ADD COLUMN IF NOT EXISTS `admin_managed` TINYINT UNSIGNED NOT NULL DEFAULT 0");
    mysql_tquery(g_DatabaseHandle,
        "INSERT INTO `companies` (`company_id`,`name`,`company_type`,`owner_character_id`,`bank_balance`,`member_limit`,`vehicle_limit`,`government_owned`,`admin_managed`) VALUES (900001,'Los Santos Logistics',3,0,0,500,500,1,1) ON DUPLICATE KEY UPDATE `name`=VALUES(`name`),`company_type`=3,`government_owned`=1,`admin_managed`=1");
    mysql_tquery(g_DatabaseHandle, "ALTER TABLE `player_vehicles` ADD COLUMN IF NOT EXISTS `company_vehicle` TINYINT UNSIGNED NOT NULL DEFAULT 0,ADD COLUMN IF NOT EXISTS `company_id` INT UNSIGNED NOT NULL DEFAULT 0,ADD COLUMN IF NOT EXISTS `company_note` VARCHAR(32) NOT NULL DEFAULT ''");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `trucking_contracts` (`contract_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,`contract_type` ENUM('AUTO','BUSINESS') NOT NULL,`created_by` VARCHAR(48) NOT NULL,`source_company_id` INT UNSIGNED NOT NULL DEFAULT 0,`destination_branch_id` INT UNSIGNED NOT NULL DEFAULT 0,`cargo_kind` VARCHAR(16) NOT NULL,`item_id` INT UNSIGNED NOT NULL DEFAULT 0,`model_id` INT UNSIGNED NOT NULL DEFAULT 0,`cargo_amount` INT UNSIGNED NOT NULL,`sale_price` INT UNSIGNED NOT NULL DEFAULT 0,`supplier_cost` INT UNSIGNED NOT NULL DEFAULT 0,`reward` INT UNSIGNED NOT NULL,`destination_x` FLOAT NOT NULL,`destination_y` FLOAT NOT NULL,`destination_z` FLOAT NOT NULL,`status` ENUM('OPEN','ASSIGNED','COMPLETED','FAILED','CANCELLED') NOT NULL DEFAULT 'OPEN',`driver_character_id` INT UNSIGNED NOT NULL DEFAULT 0,`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,`accepted_at` DATETIME NULL,`completed_at` DATETIME NULL,PRIMARY KEY (`contract_id`),KEY (`status`,`contract_type`),KEY (`destination_branch_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `company_employee_profiles` (`company_id` INT UNSIGNED NOT NULL,`character_id` INT UNSIGNED NOT NULL,`contract_signed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,`contract_ended_at` DATETIME NULL,`kpi_points` INT UNSIGNED NOT NULL DEFAULT 0,`completed_orders` INT UNSIGNED NOT NULL DEFAULT 0,`payroll_balance` INT NOT NULL DEFAULT 0,`base_salary_total` INT UNSIGNED NOT NULL DEFAULT 0,`bonus_total` INT UNSIGNED NOT NULL DEFAULT 0,`insurance_paid_total` INT UNSIGNED NOT NULL DEFAULT 0,`vehicle_fee_total` INT UNSIGNED NOT NULL DEFAULT 0,`last_daily_settlement` DATE NULL,PRIMARY KEY (`company_id`,`character_id`),KEY (`company_id`,`kpi_points`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `company_work_logs` (`work_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,`company_id` INT UNSIGNED NOT NULL,`character_id` INT UNSIGNED NOT NULL,`contract_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,`tax_code` VARCHAR(32) NOT NULL,`work_type` VARCHAR(32) NOT NULL,`route_from` VARCHAR(64) NOT NULL,`route_to` VARCHAR(64) NOT NULL,`base_reward` INT UNSIGNED NOT NULL,`labor_bonus` INT UNSIGNED NOT NULL,`safety_bonus` INT UNSIGNED NOT NULL,`punctual_bonus` INT UNSIGNED NOT NULL,`cargo_care_bonus` INT UNSIGNED NOT NULL,`route_bonus` INT UNSIGNED NOT NULL,`total_income` INT UNSIGNED NOT NULL,`company_profit` INT UNSIGNED NOT NULL,`kpi_earned` TINYINT UNSIGNED NOT NULL,`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY (`work_id`),KEY (`character_id`,`created_at`),KEY (`company_id`,`created_at`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    CreatePickup(1239, 1, TRUCK_HQ_X, TRUCK_HQ_Y, TRUCK_HQ_Z, 0);
    Create3DTextLabel("{68C83B}LOS SANTOS LOGISTICS\n{FFFFFF}Truck Job doc quyen\nBam {68C83B}Y {FFFFFF}hoac /truck",
        COLOR_WHITE, TRUCK_HQ_X, TRUCK_HQ_Y, TRUCK_HQ_Z + 0.6, 20.0, 0, false);
    Trucking_GenerateAutoContract();
    SetTimer("Trucking_GenerateAutoContract", 600000, true);
    return 1;
}

hook OnPlayerConnect(playerid)
{
    Trucking_ResetPlayer(playerid);
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    if (g_TruckContractID[playerid])
    {
        new query[320];
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "UPDATE `trucking_contracts` SET `status`='OPEN',`driver_character_id`=0,`accepted_at`=NULL WHERE `contract_id`=%d AND `driver_character_id`=%d AND `status`='ASSIGNED'",
            g_TruckContractID[playerid], GetPlayerCharacterID(playerid));
        mysql_tquery(g_DatabaseHandle, query);
    }
    Trucking_ResetPlayer(playerid);
    return 1;
}

hook OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys)
{
    #pragma unused oldkeys
    if (!(newkeys & KEY_YES)) return 1;
    if (Trucking_IsAtHQ(playerid) && g_TruckContractStage[playerid] == 0) return Trucking_ShowMain(playerid);
    if (g_TruckContractStage[playerid] == 1 &&
        IsPlayerInRangeOfPoint(playerid, 7.0, TRUCK_HQ_X, TRUCK_HQ_Y, TRUCK_HQ_Z))
    {
        if (!Trucking_IsDrivingCompanyVehicle(playerid))
            return SendClientMessage(playerid, COLOR_RED, "Ban phai lai dung COMPANY VEHICLE cua Los Santos Logistics de boc lo hang.");
        return Progress_Start(playerid, "DANG BOC LO HANG...", 8000, "Trucking_LoadCompleted");
    }
    if (g_TruckContractStage[playerid] == 2 &&
        IsPlayerInRangeOfPoint(playerid, 8.0, g_TruckDestinationX[playerid], g_TruckDestinationY[playerid], g_TruckDestinationZ[playerid]))
    {
        if (!Trucking_IsDrivingCompanyVehicle(playerid))
            return SendClientMessage(playerid, COLOR_RED, "Ban phai lai dung COMPANY VEHICLE dang cho lo hang nay de giao hang.");
        return Progress_Start(playerid, "DANG DO LO HANG...", 8000, "Trucking_UnloadCompleted");
    }
    if (g_TruckMode[playerid] == 2 && g_TruckContractStage[playerid] == 3 &&
        IsPlayerInRangeOfPoint(playerid, 8.0, g_TruckDestinationX[playerid], g_TruckDestinationY[playerid], g_TruckDestinationZ[playerid]))
    {
        if (!Trucking_IsDrivingCompanyVehicle(playerid))
            return SendClientMessage(playerid, COLOR_RED, "Ban phai lai Roadtrain Company de nhan container.");
        return Progress_Start(playerid, "DANG GAN CONTAINER...", 6000, "Trucking_PickupCompleted");
    }
    if (g_TruckMode[playerid] == 2 && g_TruckContractStage[playerid] == 4 &&
        IsPlayerInRangeOfPoint(playerid, 9.0, TRUCK_HQ_X, TRUCK_HQ_Y, TRUCK_HQ_Z))
        return Progress_Start(playerid, "DANG BAN GIAO CONTAINER...", 6000, "Trucking_ReturnCompleted");
    return 1;
}

hook OnPlayerEnterCheckpoint(playerid)
{
    switch (g_TruckContractStage[playerid])
    {
        case 1:
        {
            DisablePlayerCheckpoint(playerid);
            SendClientMessage(playerid, 0x68C83BFF,
                "Ban da den bai tap ket hang cua HQ Truck. Hay tien hanh lay hang, bam phim 'Y' de bat dau boc hang va tu dong gan trailer Company vao dau keo.");
        }
        case 2:
        {
            DisablePlayerCheckpoint(playerid);
            SendClientMessage(playerid, 0x68C83BFF,
                "Ban da den dia diem giao hang. Hay dua Roadtrain va trailer vao vi tri an toan, sau do bam phim 'Y' de tien hanh do hang va hoan tat hop dong.");
        }
        case 3:
        {
            DisablePlayerCheckpoint(playerid);
            SendClientMessage(playerid, 0x68C83BFF,
                "Ban da den diem nhan container. Hay tien hanh lay hang, bam phim 'Y' de kiem tra lo hang va tu dong gan trailer vao Roadtrain Company.");
        }
        case 4:
        {
            DisablePlayerCheckpoint(playerid);
            SendClientMessage(playerid, 0x68C83BFF,
                "Container da duoc dua ve dung garage HQ Truck. Hay bam phim 'Y' de ban giao trailer, hoan tat bien ban van chuyen va nhan tien cong.");
        }
    }
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    #pragma unused inputtext
    if (dialogid == DIALOG_TRUCKING_EMPLOYEE_COMPANY)
    {
        if (!response) return 1;
        switch (listitem)
        {
            case 0: Trucking_LoadEmployeeProfile(playerid, 0);
            case 1: Trucking_LoadMembers(playerid);
            case 2: Trucking_LoadEmployeeProfile(playerid, 1);
            case 3:
            {
                ShowPlayerDialog(playerid, DIALOG_TRUCKING_EMPLOYEE_RESIGN, DIALOG_STYLE_MSGBOX,
                    "Don xin nghi viec",
                    "Ban co chac muon cham dut hop dong dai han voi Los Santos Logistics?\nRoadtrain Company se bi thu hoi ngay lap tuc.\nTai khoan luong, KPI va lich su don hang van duoc luu trong ho so IC.",
                    "Xin nghi", "Huy");
            }
        }
        return 1;
    }
    if (dialogid == DIALOG_TRUCKING_EMPLOYEE_PAGE ||
        dialogid == DIALOG_TRUCKING_EMPLOYEE_HISTORY)
    {
        if (response) Trucking_ShowEmployeeCompanyMenu(playerid);
        return 1;
    }
    if (dialogid == DIALOG_TRUCKING_EMPLOYEE_RESIGN)
    {
        if (response) Trucking_ResignEmployment(playerid);
        else Trucking_ShowEmployeeCompanyMenu(playerid);
        return 1;
    }
    if (dialogid == DIALOG_TRUCKING_ADMIN_LOGS) return 1;
    if (dialogid == DIALOG_TRUCKING_WORK)
    {
        if (!response) return 1;
        if (!Trucking_IsCompanyEmployee(playerid))
            return SendClientMessage(playerid, COLOR_RED, "Hop dong Truck Job cua ban khong con hieu luc.");
        if (!Trucking_IsDrivingCompanyVehicle(playerid))
            return SendClientMessage(playerid, COLOR_RED, "Ban phai ngoi ghe lai Roadtrain COMPANY VEHICLE.");
        if (g_TruckContractStage[playerid])
            return SendClientMessage(playerid, COLOR_RED, "Ban dang thuc hien mot chuyen hang khac.");
        switch (listitem)
        {
            case 0: Trucking_StartDeliveryRoute(playerid);
            case 1: Trucking_StartPickupRoute(playerid);
        }
        return 1;
    }
    if (dialogid == DIALOG_TRUCKING_MAIN)
    {
        if (!response) return 1;
        if (!Trucking_IsCompanyEmployee(playerid))
        {
            if (listitem == 0)
            {
                Trucking_ShowEmploymentContract(playerid);
            }
            else ShowPlayerDialog(playerid, DIALOG_TRUCKING_CONTRACT_CONFIRM, DIALOG_STYLE_MSGBOX,
                "Truck Job - Gioi thieu", "AUTO do server tao de duy tri viec lam.\nBUSINESS do 24/7/Dealer dat lo hang that va thuong tra cao hon.\nHang chi vao kho khi tai xe giao thanh cong.", "Dong", "");
            return 1;
        }
        switch (listitem)
        {
            case 0: Trucking_ShowContracts(playerid);
            case 1:
            {
                new message[160];
                format(message, sizeof(message), "Hop dong hien tai: #%d | Giai doan: %d | Thuong: $%d",
                    g_TruckContractID[playerid], g_TruckContractStage[playerid], g_TruckContractReward[playerid]);
                SendClientMessage(playerid, COLOR_WHITE, message);
            }
            case 2: SendClientMessage(playerid, COLOR_WHITE, "Roadtrain nam trong /vehicles va duoc ghi chu COMPANY VEHICLE.");
            case 3:
            {
                if (g_TruckContractID[playerid]) return SendClientMessage(playerid, COLOR_RED, "Hay hoan thanh hop dong dang nhan truoc khi nghi viec.");
                Job_Resign(playerid, JOB_TRUCK);
                new query[256];
                mysql_format(g_DatabaseHandle, query, sizeof(query),
                    "DELETE FROM `company_members` WHERE `company_id`=%d AND `character_id`=%d",
                    TRUCK_COMPANY_SYSTEM_ID, GetPlayerCharacterID(playerid));
                mysql_tquery(g_DatabaseHandle, query);
                Company_LogByID(TRUCK_COMPANY_SYSTEM_ID, playerid, "employee_contract_ended",
                    "Nhan vien tu cham dut hop dong Truck Job", 0);
                Company_ResetPlayer(playerid);
                Trucking_RevokeVehicles(playerid);
                SendClientMessage(playerid, COLOR_WHITE, "Da nghi Truck Job; toan bo COMPANY VEHICLE da bi thu hoi.");
            }
        }
        return 1;
    }
    if (dialogid == DIALOG_TRUCKING_CONTRACTS)
    {
        if (response && listitem >= 0 && listitem < g_TruckListRows[playerid])
            Trucking_AcceptContract(playerid, g_TruckListID[playerid][listitem]);
        return 1;
    }
    if (dialogid == DIALOG_TRUCKING_CONTRACT_CONFIRM)
    {
        if (response) Trucking_SignEmploymentContract(playerid);
        return 1;
    }
    return 0;
}
