#include <YSI_Coding\y_hooks>

// San Andreas Bank - Los Santos Branch, directly managed by Government/Admin.
#define LSBANK_COMPANY_ID            (900002)
#define LSBANK_COMPANY_TYPE          (4)
#define LSBANK_REGULATORY_CAPITAL    (20000000)
#define LSBANK_LOAN_TERM_DAYS        (12)
#define LSBANK_MAX_BILLS             (100)
#define LSBANK_MAX_LOANS             (50)

new g_LSBankPendingLoan[MAX_PLAYERS];
new g_LSBankPendingInterest[MAX_PLAYERS];
new g_LSBankBillRows[MAX_PLAYERS];
new g_LSBankBillID[MAX_PLAYERS][LSBANK_MAX_BILLS];
new g_LSBankBillAmount[MAX_PLAYERS][LSBANK_MAX_BILLS];
new g_LSBankBillLoan[MAX_PLAYERS][LSBANK_MAX_BILLS];
new g_LSBankBillType[MAX_PLAYERS][LSBANK_MAX_BILLS];
new bool:g_LSBankBillDue[MAX_PLAYERS][LSBANK_MAX_BILLS];
new g_LSBankLoanRows[MAX_PLAYERS];
new g_LSBankLoanID[MAX_PLAYERS][LSBANK_MAX_LOANS];

forward public LSBank_OnStateLoaded();
forward public LSBank_OnDashboardLoaded(playerid);
forward public LSBank_OnBankLoansLoaded(playerid);
forward public LSBank_OnLoanDetailLoaded(playerid);
forward public LSBank_OnLoanCreated(playerid);
forward public LSBank_OnBillsLoaded(playerid);
forward public LSBank_OnBillPaid(playerid, billid, loanid, amount, billtype);
forward public LSBank_OnDueLoansLoaded();
forward public LSBank_OnLoanDayLoaded(loanid);
forward LSBank_ProcessDueLoans();

stock LSBank_FormatMoney(value, output[], size)
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

public LSBank_RecordRevenue(const source[], amount, actorCharacterID)
{
    if (amount <= 0) return 0;
    Company_AddRuntimeBalance(LSBANK_COMPANY_ID, amount);
    new query[768];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `companies` SET `bank_balance`=`bank_balance`+%d WHERE `company_id`=%d",
        amount, LSBANK_COMPANY_ID);
    mysql_tquery(g_DatabaseHandle, query);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `ls_bank_state` SET `tax_revenue`=`tax_revenue`+%d,`updated_at`=CURRENT_TIMESTAMP WHERE `state_id`=1",
        amount);
    mysql_tquery(g_DatabaseHandle, query);
    // Retail tax is still credited to LS Bank but omitted from detailed logs because
    // individual convenience-store receipts are too small and would flood the ledger.
    if (strcmp(source, "retail_tax", true))
    {
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "INSERT INTO `ls_bank_transactions` (`source`,`actor_character_id`,`amount`,`details`) VALUES ('%e',%d,%d,'Nguon thu thue 5%% tu hoat dong kinh doanh chuyen vao LS Bank')",
            source, actorCharacterID, amount);
        mysql_tquery(g_DatabaseHandle, query);
        new details[192];
        format(details, sizeof(details), "Thu thue 5%%; source=%s; actor_character=%d", source, actorCharacterID);
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "INSERT INTO `company_logs` (`company_id`,`actor_character_id`,`action`,`details`,`amount`) VALUES (%d,%d,'business_tax_received','%e',%d)",
            LSBANK_COMPANY_ID, actorCharacterID, details, amount);
        mysql_tquery(g_DatabaseHandle, query);
    }
    return 1;
}

public LSBank_ShowCompanyFinance(playerid)
{
    if (g_PlayerCompanyRank[playerid] < 5)
        return SendClientMessage(playerid, COLOR_RED, "Chi chu doanh nghiep hoac Admin quan ly moi duoc su dung nghiep vu tin dung.");
    if (g_PlayerCompanyID[playerid] == LSBANK_COMPANY_ID)
    {
        ShowPlayerDialog(playerid, DIALOG_LSBANK_MAIN, DIALOG_STYLE_LIST,
            "San Andreas Bank | Quan tri Chinh phu",
            "Bao cao von dieu le va tai san\nDanh sach cac khoan vay doanh nghiep",
            "Chon", "Quay lai");
        return 1;
    }
    ShowPlayerDialog(playerid, DIALOG_LSBANK_MAIN, DIALOG_STYLE_LIST,
        "San Andreas Bank | Tin dung doanh nghiep",
        "Hop dong vay von\nDanh sach hop dong\nThanh toan lai suat\nDieu khoan",
        "Chon", "Quay lai");
    return 1;
}

stock LSBank_GetInterestBP(level)
{
    if (level <= 3) return 500;
    if (level <= 7) return 400;
    if (level == 8) return 300;
    if (level == 9) return 200;
    return 100;
}

stock LSBank_LoadCompanyLoans(playerid)
{
    new query[384];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT l.*,c.`name` FROM `company_loans` l LEFT JOIN `companies` c ON c.`company_id`=l.`borrower_company_id` WHERE l.`borrower_company_id`=%d ORDER BY l.`loan_id` DESC LIMIT 50",
        g_PlayerCompanyID[playerid]);
    mysql_tquery(g_DatabaseHandle, query, "LSBank_OnBankLoansLoaded", "d", playerid);
    return 1;
}

stock LSBank_LoadDashboard(playerid)
{
    mysql_tquery(g_DatabaseHandle,
        "SELECT s.`regulatory_capital`,s.`tax_revenue`,s.`interest_revenue`,s.`updated_at`,c.`bank_balance`,COALESCE(SUM(CASE WHEN l.`status` IN ('ACTIVE','MATURED') THEN l.`outstanding_principal` ELSE 0 END),0) AS `loan_assets`,COUNT(CASE WHEN l.`status` IN ('ACTIVE','MATURED') THEN 1 END) AS `active_loans` FROM `ls_bank_state` s INNER JOIN `companies` c ON c.`company_id`=900002 LEFT JOIN `company_loans` l ON 1=1 WHERE s.`state_id`=1 GROUP BY s.`state_id`,c.`bank_balance`",
        "LSBank_OnDashboardLoaded", "d", playerid);
    return 1;
}

stock LSBank_LoadBankLoans(playerid)
{
    mysql_tquery(g_DatabaseHandle,
        "SELECT l.*,c.`name` FROM `company_loans` l LEFT JOIN `companies` c ON c.`company_id`=l.`borrower_company_id` ORDER BY l.`loan_id` DESC LIMIT 50",
        "LSBank_OnBankLoansLoaded", "d", playerid);
    return 1;
}

public LSBank_OnBankLoansLoaded(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    new body[3800], rows = cache_num_rows();
    g_LSBankLoanRows[playerid] = rows;
    format(body, sizeof(body), "ID\tDoanh nghiep\tGoc vay\tDu no\tKy/Lai\tTrang thai\n");
    for (new i; i < rows; i++)
    {
        new id, principal, outstanding, rate, day, name[48], status[16];
        new principalText[24], outstandingText[24], displayStatus[48], rowColor[12];
        cache_get_value_name_int(i, "loan_id", id);
        cache_get_value_name_int(i, "principal", principal);
        cache_get_value_name_int(i, "outstanding_principal", outstanding);
        cache_get_value_name_int(i, "daily_interest_bp", rate);
        cache_get_value_name_int(i, "current_day", day);
        cache_get_value_name(i, "name", name, sizeof(name));
        cache_get_value_name(i, "status", status, sizeof(status));
        LSBank_FormatMoney(principal, principalText, sizeof(principalText));
        LSBank_FormatMoney(outstanding, outstandingText, sizeof(outstandingText));
        if (!strcmp(status, "PAID", true))
        {
            format(displayStatus, sizeof(displayStatus), "Da thanh toan");
            format(rowColor, sizeof(rowColor), "{68C83B}");
        }
        else if (day >= LSBANK_LOAN_TERM_DAYS || !strcmp(status, "MATURED", true))
        {
            format(displayStatus, sizeof(displayStatus), "Chua thanh toan");
            format(rowColor, sizeof(rowColor), "{E74C3C}");
        }
        else
        {
            format(displayStatus, sizeof(displayStatus), "Dang thu lai suat");
            format(rowColor, sizeof(rowColor), "{35AEE2}");
        }
        g_LSBankLoanID[playerid][i] = id;
        format(body, sizeof(body), "%s%s#%d\t%s\t$%s\t$%s\t%d/12 - %d%%\t%s\n",
            body, rowColor, id, name, principalText, outstandingText, day, rate / 100, displayStatus);
    }
    if (!rows) format(body, sizeof(body), "LS Bank chua phat hanh khoan vay nao.");
    ShowPlayerDialog(playerid, DIALOG_LSBANK_LOANS, DIALOG_STYLE_TABLIST_HEADERS,
        "LS Bank | Danh muc khoan vay", body, "Xem hop dong", "Quay lai");
    return 1;
}

stock LSBank_LoadLoanDetail(playerid, row)
{
    if (row < 0 || row >= g_LSBankLoanRows[playerid]) return 0;
    new query[640];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT l.*,c.`name`,COALESCE((SELECT SUM(b.`amount`) FROM `company_loan_bills` b WHERE b.`loan_id`=l.`loan_id` AND b.`bill_type`='INTEREST' AND b.`status`='PAID'),0) AS `interest_paid`,COALESCE((SELECT COUNT(*) FROM `company_loan_bills` b WHERE b.`loan_id`=l.`loan_id` AND b.`status` IN ('UNPAID','OVERDUE')),0) AS `unpaid_bills` FROM `company_loans` l LEFT JOIN `companies` c ON c.`company_id`=l.`borrower_company_id` WHERE l.`loan_id`=%d LIMIT 1",
        g_LSBankLoanID[playerid][row]);
    mysql_tquery(g_DatabaseHandle, query, "LSBank_OnLoanDetailLoaded", "d", playerid);
    return 1;
}

public LSBank_OnLoanDetailLoaded(playerid)
{
    if (!IsPlayerConnected(playerid) || !cache_num_rows()) return 1;
    new id, principal, outstanding, rate, term, day, interestPaid, unpaidBills;
    new company[48], director[32], bank[32], status[16], started[24], maturity[24], body[1800];
    cache_get_value_name_int(0, "loan_id", id);
    cache_get_value_name_int(0, "principal", principal);
    cache_get_value_name_int(0, "outstanding_principal", outstanding);
    cache_get_value_name_int(0, "daily_interest_bp", rate);
    cache_get_value_name_int(0, "term_days", term);
    cache_get_value_name_int(0, "current_day", day);
    cache_get_value_name_int(0, "interest_paid", interestPaid);
    cache_get_value_name_int(0, "unpaid_bills", unpaidBills);
    cache_get_value_name(0, "name", company, sizeof(company));
    cache_get_value_name(0, "director_signature", director, sizeof(director));
    cache_get_value_name(0, "bank_signature", bank, sizeof(bank));
    cache_get_value_name(0, "status", status, sizeof(status));
    cache_get_value_name(0, "started_at", started, sizeof(started));
    cache_get_value_name(0, "maturity_at", maturity, sizeof(maturity));
    new principalText[24], outstandingText[24], installmentText[24], interestPaidText[24];
    LSBank_FormatMoney(principal, principalText, sizeof(principalText));
    LSBank_FormatMoney(outstanding, outstandingText, sizeof(outstandingText));
    LSBank_FormatMoney((principal * rate + 9999) / 10000, installmentText, sizeof(installmentText));
    LSBank_FormatMoney(interestPaid, interestPaidText, sizeof(interestPaidText));
    format(body, sizeof(body),
        "HOP DONG TIN DUNG #%d\n\nBen vay: %s\nChu ky Giam doc Company: %s\nBen cho vay: San Andreas Bank - Chi nhanh Los Santos\nChu ky Giam doc ngan hang: %s\n\nTien goc: $%s\nDu no goc con lai: $%s\nLai suat: %d%% moi ky ngay\nKy han: %d thang IC (%d ngay that)\nTien lai du kien moi ky: $%s\nTien lai da thanh toan: $%s\nBill chua thanh toan: %d\nTien do hop dong: ky %d/%d\nNgay ky: %s\nNgay dao han: %s\nTrang thai: %s\n\nMau do trong danh sach bill: da den han thanh toan.\nMau xanh la: chua den han thanh toan.",
        id, company, director, bank, principalText, outstandingText, rate / 100,
        term, term, installmentText, interestPaidText,
        unpaidBills, day, term, started, maturity, status);
    ShowPlayerDialog(playerid, DIALOG_LSBANK_LOAN_DETAIL, DIALOG_STYLE_MSGBOX,
        "LS Bank | Chi tiet hop dong", body, "Quay lai", "Dong");
    return 1;
}

public LSBank_OnDashboardLoaded(playerid)
{
    if (!IsPlayerConnected(playerid) || !cache_num_rows()) return 1;
    new capital, balance, taxes, interest, assets, active, updated[24], body[1000];
    new capitalText[24], balanceText[24], taxesText[24], interestText[24], assetsText[24];
    cache_get_value_name_int(0, "regulatory_capital", capital);
    cache_get_value_name_int(0, "bank_balance", balance);
    cache_get_value_name_int(0, "tax_revenue", taxes);
    cache_get_value_name_int(0, "interest_revenue", interest);
    cache_get_value_name_int(0, "loan_assets", assets);
    cache_get_value_name_int(0, "active_loans", active);
    cache_get_value_name(0, "updated_at", updated, sizeof(updated));
    LSBank_FormatMoney(capital, capitalText, sizeof(capitalText));
    LSBank_FormatMoney(balance, balanceText, sizeof(balanceText));
    LSBank_FormatMoney(taxes, taxesText, sizeof(taxesText));
    LSBank_FormatMoney(interest, interestText, sizeof(interestText));
    LSBank_FormatMoney(assets, assetsText, sizeof(assetsText));
    format(body, sizeof(body),
        "SAN ANDREAS BANK - CHI NHANH LOS SANTOS\nCo quan chu quan: Chinh phu Los Santos / Admin\n\nVon dieu le: $%s\nThanh khoan hien tai: $%s\nDu no cho vay: $%s\nKhoan vay dang hoat dong: %d\nTong thue/phi da tiep nhan: $%s\nTong lai vay da thu: $%s\nCap nhat: %s\n\nToan bo thue Job, thue Company va phi chuyen khoan duoc dieu chuyen vao ngan hang.",
        capitalText, balanceText, assetsText, active, taxesText, interestText, updated);
    ShowPlayerDialog(playerid, DIALOG_LSBANK_LOANS, DIALOG_STYLE_MSGBOX,
        "LS Bank | Bao cao von va tin dung", body, "Quay lai", "Dong");
    return 1;
}

stock LSBank_CreateLoan(playerid, amount)
{
    if (amount < 10000 || amount > 2000000)
        return SendClientMessage(playerid, COLOR_RED, "Han muc vay doanh nghiep tu $10,000 den $2,000,000.");
    if (Company_GetBalance(LSBANK_COMPANY_ID) < amount)
        return SendClientMessage(playerid, COLOR_RED, "LS Bank hien khong du thanh khoan de giai ngan khoan vay nay.");
    new rate = LSBank_GetInterestBP(g_PlayerCompanyLevel[playerid]), body[1400];
    new amountText[24], installmentText[24];
    LSBank_FormatMoney(amount, amountText, sizeof(amountText));
    LSBank_FormatMoney((amount * rate + 9999) / 10000, installmentText, sizeof(installmentText));
    g_LSBankPendingLoan[playerid] = amount;
    g_LSBankPendingInterest[playerid] = rate;
    format(body, sizeof(body),
        "HOP DONG TIN DUNG DOANH NGHIEP\n\nBen vay: %s\nDai dien/Giam doc: %s\nBen cho vay: San Andreas Bank - Chi nhanh Los Santos\nGiam doc ngan hang: Cuozg\n\nSo tien vay: $%s\nKy han: 12 thang IC (12 ngay that)\nLai suat theo Company cap %d: %d%%/ky ngay\nHan muc hop dong dang hoat dong: %d\nTien lai du kien moi ky: $%s\nNgay tat toan bat buoc: ky thu 12\n\nChu ky Giam doc Company: %s - CHO KY\nChu ky Giam doc ngan hang: Cuozg - DA KY\n\nBam Ky hop dong de xac nhan toan bo dieu khoan va yeu cau giai ngan.",
        g_PlayerCompanyName[playerid], s_CharacterName[playerid], amountText,
        g_PlayerCompanyLevel[playerid], rate / 100, g_PlayerCompanyLevel[playerid],
        installmentText, s_CharacterName[playerid]);
    ShowPlayerDialog(playerid, DIALOG_LSBANK_CONTRACT_CONFIRM, DIALOG_STYLE_MSGBOX,
        "LS Bank | Ky hop dong tin dung", body, "Ky hop dong", "Tu choi");
    return 1;
}

stock LSBank_FinalizeLoan(playerid)
{
    new amount = g_LSBankPendingLoan[playerid], rate = g_LSBankPendingInterest[playerid];
    if (amount <= 0) return 0;
    new query[768];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT INTO `company_loans` (`lender_company_id`,`borrower_company_id`,`principal`,`outstanding_principal`,`daily_interest_bp`,`term_days`,`director_signature`,`bank_signature`,`next_due_at`,`maturity_at`) SELECT %d,%d,%d,%d,%d,%d,'%e','Cuozg',DATE_ADD(NOW(),INTERVAL 1 DAY),DATE_ADD(NOW(),INTERVAL %d DAY) WHERE (SELECT COUNT(*) FROM `company_loans` WHERE `borrower_company_id`=%d AND `status` IN ('ACTIVE','MATURED'))<%d",
        LSBANK_COMPANY_ID, g_PlayerCompanyID[playerid], amount, amount,
        rate, LSBANK_LOAN_TERM_DAYS, s_CharacterName[playerid], LSBANK_LOAN_TERM_DAYS,
        g_PlayerCompanyID[playerid], g_PlayerCompanyLevel[playerid]);
    mysql_tquery(g_DatabaseHandle, query, "LSBank_OnLoanCreated", "d", playerid);
    return 1;
}

public LSBank_OnLoanCreated(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    new loanid = cache_insert_id(), amount = g_LSBankPendingLoan[playerid], rate = g_LSBankPendingInterest[playerid];
    g_LSBankPendingLoan[playerid] = 0;
    g_LSBankPendingInterest[playerid] = 0;
    if (!loanid)
        return SendClientMessage(playerid, COLOR_RED, "Company da dat gioi han hop dong vay theo cap hien tai; hay tat toan hoac nang cap Company.");
    Company_AddRuntimeBalance(LSBANK_COMPANY_ID, -amount);
    Company_AddRuntimeBalance(g_PlayerCompanyID[playerid], amount);
    new query[1200], details[160];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `companies` SET `bank_balance`=CASE WHEN `company_id`=%d THEN `bank_balance`-%d WHEN `company_id`=%d THEN `bank_balance`+%d ELSE `bank_balance` END WHERE `company_id` IN (%d,%d)",
        LSBANK_COMPANY_ID, amount, g_PlayerCompanyID[playerid], amount,
        LSBANK_COMPANY_ID, g_PlayerCompanyID[playerid]);
    mysql_tquery(g_DatabaseHandle, query);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT IGNORE INTO `company_loan_bills` (`loan_id`,`company_id`,`bill_type`,`due_day`,`amount`,`due_at`) SELECT %d,%d,'INTEREST',d,CEIL(%d*%d/10000),DATE_ADD(NOW(),INTERVAL d DAY) FROM (SELECT 1 d UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10 UNION SELECT 11 UNION SELECT 12) schedule",
        loanid, g_PlayerCompanyID[playerid], amount, rate);
    mysql_tquery(g_DatabaseHandle, query);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT IGNORE INTO `company_loan_bills` (`loan_id`,`company_id`,`bill_type`,`due_day`,`amount`,`due_at`) VALUES (%d,%d,'FINAL',12,%d,DATE_ADD(NOW(),INTERVAL 12 DAY))",
        loanid, g_PlayerCompanyID[playerid], amount);
    mysql_tquery(g_DatabaseHandle, query);
    new amountText[24];
    LSBank_FormatMoney(amount, amountText, sizeof(amountText));
    format(details, sizeof(details), "Giai ngan khoan vay #%d ky han 12 ngay, goc $%s", loanid, amountText);
    Company_LogByID(g_PlayerCompanyID[playerid], playerid, "bank_loan_disbursed", details, amount);
    Company_LogByID(LSBANK_COMPANY_ID, playerid, "loan_asset_created", details, -amount);
    SendClientMessage(playerid, 0x68C83BFF, "LS Bank da giai ngan vao tai khoan Company. Moi ngay se phat sinh bill lai; ngay 12 bat buoc tat toan goc.");
    return 1;
}

stock LSBank_LoadBills(playerid)
{
    new query[640];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT b.`bill_id`,b.`loan_id`,b.`bill_type`,b.`amount`,b.`due_day`,b.`status`,b.`due_at`,(b.`due_at`<=NOW()) AS `is_due` FROM `company_loan_bills` b WHERE b.`company_id`=%d AND b.`status` IN ('UNPAID','OVERDUE') ORDER BY b.`loan_id`,b.`due_day`,b.`bill_id` LIMIT %d",
        g_PlayerCompanyID[playerid], LSBANK_MAX_BILLS);
    mysql_tquery(g_DatabaseHandle, query, "LSBank_OnBillsLoaded", "d", playerid);
    return 1;
}

public LSBank_OnBillsLoaded(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;
    new rows = cache_num_rows(), body[2500];
    g_LSBankBillRows[playerid] = rows;
    format(body, sizeof(body), "Bill\tKhoan vay\tKy\tLoai\tSo tien\tHan thanh toan\n");
    for (new i; i < rows; i++)
    {
        new billid, loanid, day, amount, isDue, type[16], status[16], dueAt[24];
        cache_get_value_name_int(i, "bill_id", billid);
        cache_get_value_name_int(i, "loan_id", loanid);
        cache_get_value_name_int(i, "due_day", day);
        cache_get_value_name_int(i, "amount", amount);
        cache_get_value_name_int(i, "is_due", isDue);
        cache_get_value_name(i, "bill_type", type, sizeof(type));
        cache_get_value_name(i, "status", status, sizeof(status));
        cache_get_value_name(i, "due_at", dueAt, sizeof(dueAt));
        g_LSBankBillID[playerid][i] = billid;
        g_LSBankBillLoan[playerid][i] = loanid;
        g_LSBankBillAmount[playerid][i] = amount;
        g_LSBankBillType[playerid][i] = !strcmp(type, "FINAL", true) ? 2 : 1;
        g_LSBankBillDue[playerid][i] = isDue != 0;
        new amountText[24];
        LSBank_FormatMoney(amount, amountText, sizeof(amountText));
        format(body, sizeof(body), "%s%s#%d\t#%d\tNgay %d/12\t%s\t$%s\t%s\n",
            body, isDue ? "{E74C3C}" : "{68C83B}", billid, loanid, day, type, amountText, dueAt);
    }
    if (!rows) format(body, sizeof(body), "Company hien khong co bill lai hoac bill tat toan nao.");
    ShowPlayerDialog(playerid, DIALOG_LSBANK_BILLS, DIALOG_STYLE_TABLIST_HEADERS,
        "LS Bank | Chon bill de thanh toan", body, "Thanh toan", "Quay lai");
    return 1;
}

stock LSBank_PayBill(playerid, row)
{
    if (row < 0 || row >= g_LSBankBillRows[playerid]) return 0;
    if (!g_LSBankBillDue[playerid][row])
        return SendClientMessage(playerid, COLOR_RED, "Bill nay chua den han thanh toan; dong mau xanh chi dung de theo doi lich thanh toan.");
    new amount = g_LSBankBillAmount[playerid][row];
    if (Company_GetBalance(g_PlayerCompanyID[playerid]) < amount)
        return SendClientMessage(playerid, COLOR_RED, "Tai khoan Company khong du tien; bill khong the thanh toan.");
    new query[512];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `company_loan_bills` SET `status`='PAID',`paid_at`=CURRENT_TIMESTAMP WHERE `bill_id`=%d AND `company_id`=%d AND `status` IN ('UNPAID','OVERDUE')",
        g_LSBankBillID[playerid][row], g_PlayerCompanyID[playerid]);
    mysql_tquery(g_DatabaseHandle, query, "LSBank_OnBillPaid", "ddddd",
        playerid, g_LSBankBillID[playerid][row], g_LSBankBillLoan[playerid][row],
        amount, g_LSBankBillType[playerid][row]);
    return 1;
}

public LSBank_OnBillPaid(playerid, billid, loanid, amount, billtype)
{
    if (!IsPlayerConnected(playerid) || cache_affected_rows() != 1)
        return SendClientMessage(playerid, COLOR_RED, "Bill da duoc xu ly hoac khong con hop le.");
    Company_AddRuntimeBalance(g_PlayerCompanyID[playerid], -amount);
    Company_AddRuntimeBalance(LSBANK_COMPANY_ID, amount);
    new query[640], details[160];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `companies` SET `bank_balance`=CASE WHEN `company_id`=%d THEN `bank_balance`-%d WHEN `company_id`=%d THEN `bank_balance`+%d ELSE `bank_balance` END WHERE `company_id` IN (%d,%d)",
        g_PlayerCompanyID[playerid], amount, LSBANK_COMPANY_ID, amount,
        g_PlayerCompanyID[playerid], LSBANK_COMPANY_ID);
    mysql_tquery(g_DatabaseHandle, query);
    if (billtype == 2)
    {
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "UPDATE `company_loans` SET `outstanding_principal`=0,`status`='PAID',`closed_at`=CURRENT_TIMESTAMP WHERE `loan_id`=%d",
            loanid);
        mysql_tquery(g_DatabaseHandle, query);
    }
    else
    {
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "UPDATE `ls_bank_state` SET `interest_revenue`=`interest_revenue`+%d WHERE `state_id`=1", amount);
        mysql_tquery(g_DatabaseHandle, query);
    }
    format(details, sizeof(details), "Thanh toan bill #%d cua khoan vay #%d", billid, loanid);
    Company_LogByID(g_PlayerCompanyID[playerid], playerid, "loan_bill_paid", details, -amount);
    Company_LogByID(LSBANK_COMPANY_ID, playerid, "loan_payment_received", details, amount);
    SendClientMessage(playerid, 0x68C83BFF, "Thanh toan bill thanh cong. Giao dich da ghi vao tai khoan va nhat ky hai Company.");
    return LSBank_LoadBills(playerid);
}

stock LSBank_AdvanceLoanDay(loanid)
{
    new query[384];
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "SELECT `loan_id`,`borrower_company_id`,`outstanding_principal`,`daily_interest_bp`,`current_day`,`status` FROM `company_loans` WHERE `loan_id`=%d AND `status` IN ('ACTIVE','MATURED') LIMIT 1", loanid);
    mysql_tquery(g_DatabaseHandle, query, "LSBank_OnLoanDayLoaded", "d", loanid);
    return 1;
}

public LSBank_OnLoanDayLoaded(loanid)
{
    if (!cache_num_rows()) return 1;
    new companyid, principal, interestBP, day, status[16], query[900];
    cache_get_value_name_int(0, "borrower_company_id", companyid);
    cache_get_value_name_int(0, "outstanding_principal", principal);
    cache_get_value_name_int(0, "daily_interest_bp", interestBP);
    cache_get_value_name_int(0, "current_day", day);
    cache_get_value_name(0, "status", status, sizeof(status));
    if (day >= LSBANK_LOAN_TERM_DAYS || principal <= 0) return 1;
    day++;
    new interest = (principal * interestBP + 9999) / 10000;
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "INSERT IGNORE INTO `company_loan_bills` (`loan_id`,`company_id`,`bill_type`,`due_day`,`amount`,`due_at`) VALUES (%d,%d,'INTEREST',%d,%d,NOW())",
        loanid, companyid, day, interest);
    mysql_tquery(g_DatabaseHandle, query);
    mysql_format(g_DatabaseHandle, query, sizeof(query),
        "UPDATE `company_loan_bills` SET `due_at`=NOW() WHERE `loan_id`=%d AND `due_day`=%d AND `status`='UNPAID'",
        loanid, day);
    mysql_tquery(g_DatabaseHandle, query);
    if (day >= LSBANK_LOAN_TERM_DAYS)
    {
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "INSERT IGNORE INTO `company_loan_bills` (`loan_id`,`company_id`,`bill_type`,`due_day`,`amount`,`due_at`) VALUES (%d,%d,'FINAL',12,%d,NOW())",
            loanid, companyid, principal);
        mysql_tquery(g_DatabaseHandle, query);
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "UPDATE `company_loans` SET `current_day`=12,`status`='MATURED',`next_due_at`=NULL WHERE `loan_id`=%d", loanid);
    }
    else
    {
        mysql_format(g_DatabaseHandle, query, sizeof(query),
            "UPDATE `company_loans` SET `current_day`=%d,`next_due_at`=DATE_ADD(NOW(),INTERVAL 1 DAY) WHERE `loan_id`=%d",
            day, loanid);
    }
    mysql_tquery(g_DatabaseHandle, query);
    for (new playerid; playerid < MAX_PLAYERS; playerid++)
    {
        if (IsPlayerConnected(playerid) && g_PlayerCompanyID[playerid] == companyid &&
            g_PlayerCompanyRank[playerid] >= 5)
        {
            new notice[192], interestText[24];
            LSBank_FormatMoney(interest, interestText, sizeof(interestText));
            format(notice, sizeof(notice),
                "[LS BANK] Khoan vay #%d da sang ky %d/12, bill lai $%s da gui vao /company > Tai chinh > Tin dung.",
                loanid, day, interestText);
            SendClientMessage(playerid, 0x68C83BFF, notice);
            if (day == LSBANK_LOAN_TERM_DAYS)
                SendClientMessage(playerid, COLOR_RED,
                    "[LS BANK] Khoan vay da den han. Bill FINAL bat buoc thanh toan toan bo du no goc da duoc phat hanh.");
        }
    }
    return 1;
}

public LSBank_ProcessDueLoans()
{
    mysql_tquery(g_DatabaseHandle,
        "SELECT `loan_id` FROM `company_loans` WHERE `status`='ACTIVE' AND `next_due_at`<=NOW() LIMIT 100",
        "LSBank_OnDueLoansLoaded");
    return 1;
}

public LSBank_OnDueLoansLoaded()
{
    new rows = cache_num_rows();
    for (new i; i < rows; i++)
    {
        new loanid;
        cache_get_value_name_int(i, "loan_id", loanid);
        LSBank_AdvanceLoanDay(loanid);
    }
    return 1;
}

CMD:skiploanday(playerid, params[])
{
    if (!Admin_RequireLevel(playerid, ADMIN_LEVEL_ADMIN)) return 1;
    if (!strlen(params))
    {
        mysql_tquery(g_DatabaseHandle,
            "SELECT `loan_id` FROM `company_loans` WHERE `status`='ACTIVE' AND `current_day`<12 ORDER BY `loan_id` LIMIT 100",
            "LSBank_OnDueLoansLoaded");
        SendClientMessage(playerid, COLOR_ADMIN_CHAT,
            "[ADMIN TEST] Da skip 1 ngay LS Bank cho toan bo khoan vay dang hoat dong; moi khoan se tao dung 1 ky bill.");
        return 1;
    }
    new loanid = strval(params);
    if (loanid <= 0)
        return SendClientMessage(playerid, COLOR_WHITE, "Su dung: /skiploanday hoac /skiploanday [loanid].");
    LSBank_AdvanceLoanDay(loanid);
    SendClientMessage(playerid, COLOR_ADMIN_CHAT,
        "[ADMIN TEST] Da skip 1 ngay rieng cho khoan vay duoc chon; bill ky tiep theo se duoc tao.");
    return 1;
}

hook OnGameModeInit()
{
    mysql_tquery(g_DatabaseHandle, "ALTER TABLE `companies` ADD COLUMN IF NOT EXISTS `government_owned` TINYINT UNSIGNED NOT NULL DEFAULT 0,ADD COLUMN IF NOT EXISTS `admin_managed` TINYINT UNSIGNED NOT NULL DEFAULT 0");
    mysql_tquery(g_DatabaseHandle,
        "INSERT INTO `companies` (`company_id`,`name`,`company_type`,`owner_character_id`,`bank_balance`,`member_limit`,`vehicle_limit`,`government_owned`,`admin_managed`) VALUES (900002,'San Andreas Bank - Los Santos',4,0,20000000,100,20,1,1) ON DUPLICATE KEY UPDATE `name`=VALUES(`name`),`company_type`=4,`government_owned`=1,`admin_managed`=1");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `ls_bank_state` (`state_id` TINYINT UNSIGNED NOT NULL,`regulatory_capital` BIGINT NOT NULL DEFAULT 20000000,`tax_revenue` BIGINT NOT NULL DEFAULT 0,`interest_revenue` BIGINT NOT NULL DEFAULT 0,`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,PRIMARY KEY (`state_id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle, "INSERT IGNORE INTO `ls_bank_state` (`state_id`,`regulatory_capital`) VALUES (1,20000000)");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `company_loans` (`loan_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,`lender_company_id` INT UNSIGNED NOT NULL,`borrower_company_id` INT UNSIGNED NOT NULL,`principal` BIGINT UNSIGNED NOT NULL,`outstanding_principal` BIGINT UNSIGNED NOT NULL,`daily_interest_bp` INT UNSIGNED NOT NULL DEFAULT 100,`term_days` TINYINT UNSIGNED NOT NULL DEFAULT 12,`current_day` TINYINT UNSIGNED NOT NULL DEFAULT 0,`status` ENUM('ACTIVE','MATURED','PAID','DEFAULTED','CANCELLED') NOT NULL DEFAULT 'ACTIVE',`started_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,`next_due_at` DATETIME NULL,`maturity_at` DATETIME NOT NULL,`closed_at` DATETIME NULL,PRIMARY KEY (`loan_id`),KEY (`borrower_company_id`,`status`),KEY (`next_due_at`,`status`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "ALTER TABLE `company_loans` ADD COLUMN IF NOT EXISTS `director_signature` VARCHAR(32) NOT NULL DEFAULT '',ADD COLUMN IF NOT EXISTS `bank_signature` VARCHAR(32) NOT NULL DEFAULT 'Cuozg'");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `company_loan_bills` (`bill_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,`loan_id` BIGINT UNSIGNED NOT NULL,`company_id` INT UNSIGNED NOT NULL,`bill_type` ENUM('INTEREST','FINAL') NOT NULL,`due_day` TINYINT UNSIGNED NOT NULL,`amount` BIGINT UNSIGNED NOT NULL,`status` ENUM('UNPAID','PAID','OVERDUE') NOT NULL DEFAULT 'UNPAID',`due_at` DATETIME NOT NULL,`paid_at` DATETIME NULL,`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY (`bill_id`),UNIQUE KEY (`loan_id`,`bill_type`,`due_day`),KEY (`company_id`,`status`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "INSERT IGNORE INTO `company_loan_bills` (`loan_id`,`company_id`,`bill_type`,`due_day`,`amount`,`due_at`) SELECT l.`loan_id`,l.`borrower_company_id`,'INTEREST',s.d,CEIL(l.`principal`*l.`daily_interest_bp`/10000),DATE_ADD(l.`started_at`,INTERVAL s.d DAY) FROM `company_loans` l JOIN (SELECT 1 d UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10 UNION SELECT 11 UNION SELECT 12) s WHERE l.`status` IN ('ACTIVE','MATURED')");
    mysql_tquery(g_DatabaseHandle,
        "INSERT IGNORE INTO `company_loan_bills` (`loan_id`,`company_id`,`bill_type`,`due_day`,`amount`,`due_at`) SELECT `loan_id`,`borrower_company_id`,'FINAL',12,`outstanding_principal`,`maturity_at` FROM `company_loans` WHERE `status` IN ('ACTIVE','MATURED')");
    mysql_tquery(g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `ls_bank_transactions` (`transaction_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,`source` VARCHAR(40) NOT NULL,`actor_character_id` INT UNSIGNED NOT NULL DEFAULT 0,`amount` BIGINT NOT NULL,`details` VARCHAR(255) NOT NULL DEFAULT '',`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY (`transaction_id`),KEY (`source`,`created_at`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mysql_tquery(g_DatabaseHandle,
        "SELECT `bank_balance` FROM `companies` WHERE `company_id`=900002 LIMIT 1",
        "LSBank_OnStateLoaded");
    SetTimer("LSBank_ProcessDueLoans", 3600000, true);
    return 1;
}

public LSBank_OnStateLoaded()
{
    new balance = LSBANK_REGULATORY_CAPITAL;
    if (cache_num_rows()) cache_get_value_name_int(0, "bank_balance", balance);
    Company_EnsureBalance(LSBANK_COMPANY_ID, balance);
    LSBank_ProcessDueLoans();
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if (dialogid == DIALOG_LSBANK_MAIN)
    {
        if (!response) return Company_ShowMain(playerid);
        if (g_PlayerCompanyID[playerid] == LSBANK_COMPANY_ID)
        {
            if (listitem == 0) LSBank_LoadDashboard(playerid);
            else if (listitem == 1) LSBank_LoadBankLoans(playerid);
            return 1;
        }
        switch (listitem)
        {
            case 0:
            {
                new rate = LSBank_GetInterestBP(g_PlayerCompanyLevel[playerid]), prompt[640];
                format(prompt, sizeof(prompt),
                    "Nhap so tien can vay ($10,000-$2,000,000).\nCompany cap %d duoc phep co toi da %d hop dong dang hoat dong.\nLai suat ap dung: %d%% moi ky ngay.\nKy han: 12 thang IC, tuong duong 12 ngay that.\nSau khi nhap so tien, ban phai doc va ky hop dong chi tiet.",
                    g_PlayerCompanyLevel[playerid], g_PlayerCompanyLevel[playerid], rate / 100);
                ShowPlayerDialog(playerid, DIALOG_LSBANK_LOAN_APPLY, DIALOG_STYLE_INPUT,
                    "LS Bank | Lap ho so vay doanh nghiep", prompt, "Lap hop dong", "Quay lai");
            }
            case 1: LSBank_LoadCompanyLoans(playerid);
            case 2: LSBank_LoadBills(playerid);
            case 3:
            {
                new body[1000], rate = LSBank_GetInterestBP(g_PlayerCompanyLevel[playerid]);
                format(body, sizeof(body),
                    "Moi cap Company duoc mo so hop dong bang chinh cap cua doanh nghiep.\nCap 1-3: 5%%/ky; cap 4-7: 4%%/ky; cap 8: 3%%/ky; cap 9: 2%%/ky; cap 10: 1%%/ky.\n\nCompany cua ban: cap %d, toi da %d hop dong, lai suat hien tai %d%%/ky.\nKy han moi hop dong la 12 ngay that. Lai duoc lap bill moi ngay; ky 12 phai thanh toan toan bo goc.\nMoi hop dong chi co hieu luc sau khi co chu ky Giam doc Company va Giam doc ngan hang Cuozg.",
                    g_PlayerCompanyLevel[playerid], g_PlayerCompanyLevel[playerid], rate / 100);
                ShowPlayerDialog(playerid, DIALOG_LSBANK_LOANS, DIALOG_STYLE_MSGBOX,
                    "LS Bank | Dieu khoan tin dung", body, "Quay lai", "Dong");
            }
        }
        return 1;
    }
    if (dialogid == DIALOG_LSBANK_LOAN_APPLY)
    {
        if (response) LSBank_CreateLoan(playerid, strval(inputtext));
        else LSBank_ShowCompanyFinance(playerid);
        return 1;
    }
    if (dialogid == DIALOG_LSBANK_CONTRACT_CONFIRM)
    {
        if (response) LSBank_FinalizeLoan(playerid);
        else
        {
            g_LSBankPendingLoan[playerid] = 0;
            g_LSBankPendingInterest[playerid] = 0;
            LSBank_ShowCompanyFinance(playerid);
        }
        return 1;
    }
    if (dialogid == DIALOG_LSBANK_BILLS)
    {
        if (response) LSBank_PayBill(playerid, listitem);
        else LSBank_ShowCompanyFinance(playerid);
        return 1;
    }
    if (dialogid == DIALOG_LSBANK_LOANS)
    {
        if (response) LSBank_LoadLoanDetail(playerid, listitem);
        else LSBank_ShowCompanyFinance(playerid);
        return 1;
    }
    if (dialogid == DIALOG_LSBANK_LOAN_DETAIL)
    {
        if (response)
        {
            if (g_PlayerCompanyID[playerid] == LSBANK_COMPANY_ID) LSBank_LoadBankLoans(playerid);
            else LSBank_LoadCompanyLoans(playerid);
        }
        return 1;
    }
    return 0;
}
