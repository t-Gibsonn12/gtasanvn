#include <YSI_Coding\y_hooks>

#define ATM_COUNT             (4)
#define ATM_USE_RANGE         (2.5)
#define ATM_OBJECT_MODEL      (2942)

enum E_ATM_DATA
{
    atmName[32],
    Float:atmX,
    Float:atmY,
    Float:atmZ,
    Float:atmA
};

new const g_ATMData[ATM_COUNT][E_ATM_DATA] =
{
    {"Unity Station", 1833.2291, -1848.2380, 13.5781, 96.6227},
    {"All Saints Hospital", 1172.0739, -1323.3495, 15.4031, 270.0000},
    {"Market", 1081.3014, -1703.6708, 13.5469, 90.0000},
    {"Jefferson", 2228.4661, -1721.8734, 13.5612, 90.0000}
};

stock Economy_SaveBalances(playerid)
{
    if (!IsPlayerCharacterLoaded(playerid))
    {
        return 0;
    }

    s_CharacterCash[playerid] = GetPlayerMoney(playerid);
    new query[256];
    mysql_format(
        g_DatabaseHandle,
        query,
        sizeof(query),
        "UPDATE `player_characters` SET `cash`=%d,`bank`=%d WHERE `character_id`=%d AND `account_id`=%d LIMIT 1",
        s_CharacterCash[playerid],
        s_CharacterBank[playerid],
        GetPlayerCharacterID(playerid),
        GetPlayerAccountID(playerid)
    );
    mysql_tquery(g_DatabaseHandle, query);
    return 1;
}

stock Economy_LogTransaction(
    playerid,
    const transactionType[],
    amount,
    targetCharacterID = 0,
    const details[] = ""
)
{
    if (!IsPlayerCharacterLoaded(playerid))
    {
        return 0;
    }

    new query[640];
    if (targetCharacterID > 0)
    {
        mysql_format(
            g_DatabaseHandle,
            query,
            sizeof(query),
            "INSERT INTO `economy_transactions` (`character_id`,`target_character_id`,`transaction_type`,`amount`,`cash_balance`,`bank_balance`,`details`) VALUES (%d,%d,'%e',%d,%d,%d,'%e')",
            GetPlayerCharacterID(playerid), targetCharacterID, transactionType,
            amount, GetPlayerMoney(playerid), s_CharacterBank[playerid], details
        );
    }
    else
    {
        mysql_format(
            g_DatabaseHandle,
            query,
            sizeof(query),
            "INSERT INTO `economy_transactions` (`character_id`,`target_character_id`,`transaction_type`,`amount`,`cash_balance`,`bank_balance`,`details`) VALUES (%d,NULL,'%e',%d,%d,%d,'%e')",
            GetPlayerCharacterID(playerid), transactionType, amount,
            GetPlayerMoney(playerid), s_CharacterBank[playerid], details
        );
    }
    mysql_tquery(g_DatabaseHandle, query);
    return 1;
}

stock Economy_GetNearestATM(playerid)
{
    new nearest = -1;
    new Float:nearestDistance = ATM_USE_RANGE;
    for (new i = 0; i < ATM_COUNT; i++)
    {
        new Float:distance = GetPlayerDistanceFromPoint(
            playerid,
            g_ATMData[i][atmX],
            g_ATMData[i][atmY],
            g_ATMData[i][atmZ]
        );
        if (distance <= nearestDistance)
        {
            nearest = i;
            nearestDistance = distance;
        }
    }
    return nearest;
}

stock Economy_ShowATM(playerid)
{
    if (!IsPlayerCharacterLoaded(playerid) ||
        GetPlayerInterior(playerid) != 0 ||
        GetPlayerVirtualWorld(playerid) != 0 ||
        Economy_GetNearestATM(playerid) == -1)
    {
        SendClientMessage(playerid, COLOR_RED, "Ban phai dung gan mot may ATM de thao tac.");
        return 0;
    }

    new title[96];
    format(
        title,
        sizeof(title),
        "LS Bank | Bank: $%d | Tien mat: $%d",
        s_CharacterBank[playerid],
        GetPlayerMoney(playerid)
    );
    ShowPlayerDialog(playerid, DIALOG_ATM_MENU, DIALOG_STYLE_LIST, title, "Gui tien\nRut tien\nChuyen tien", "Chon", "Dong");
    return 1;
}

stock bool:Economy_ParseTransfer(const input[], &targetid, &amount)
{
    new separator = strfind(input, " ");
    if (separator <= 0)
    {
        return false;
    }

    new targetText[12], amountText[16];
    strmid(targetText, input, 0, separator, sizeof(targetText));
    while (input[separator] == ' ')
    {
        separator++;
    }
    strmid(amountText, input, separator, strlen(input), sizeof(amountText));
    targetid = strval(targetText);
    amount = strval(amountText);
    return true;
}

hook OnGameModeInit()
{
    mysql_tquery(
        g_DatabaseHandle,
        "CREATE TABLE IF NOT EXISTS `economy_transactions` (\
        `transaction_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,\
        `character_id` INT UNSIGNED NOT NULL,\
        `target_character_id` INT UNSIGNED NULL DEFAULT NULL,\
        `transaction_type` VARCHAR(32) NOT NULL,\
        `amount` INT NOT NULL,\
        `cash_balance` INT NOT NULL DEFAULT 0,\
        `bank_balance` INT NOT NULL DEFAULT 0,\
        `details` VARCHAR(255) NOT NULL DEFAULT '',\
        `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,\
        PRIMARY KEY (`transaction_id`),\
        KEY `idx_economy_character_created` (`character_id`,`created_at`),\
        KEY `idx_economy_target_created` (`target_character_id`,`created_at`)\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci"
    );

    for (new i = 0; i < ATM_COUNT; i++)
    {
        CreateObject(
            ATM_OBJECT_MODEL,
            g_ATMData[i][atmX],
            g_ATMData[i][atmY],
            g_ATMData[i][atmZ] - 1.0,
            0.0,
            0.0,
            g_ATMData[i][atmA]
        );
        Create3DTextLabel(
            "{68C83B}ATM\n{FFFFFF}Bam {68C83B}Y {FFFFFF}de giao dich",
            COLOR_WHITE,
            g_ATMData[i][atmX],
            g_ATMData[i][atmY],
            g_ATMData[i][atmZ] + 0.65,
            12.0,
            0,
            false
        );
    }
    return 1;
}

hook OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys)
{
    #pragma unused oldkeys
    if ((newkeys & KEY_YES) && GetPlayerState(playerid) == PLAYER_STATE_ONFOOT)
    {
        if (Economy_GetNearestATM(playerid) != -1)
        {
            Economy_ShowATM(playerid);
        }
    }
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if (dialogid == DIALOG_ATM_MENU)
    {
        if (!response)
        {
            return 1;
        }
        if (Economy_GetNearestATM(playerid) == -1)
        {
            SendClientMessage(playerid, COLOR_RED, "Ban da roi khoi khu vuc ATM.");
            return 1;
        }
        switch (listitem)
        {
            case 0: ShowPlayerDialog(playerid, DIALOG_ATM_DEPOSIT, DIALOG_STYLE_INPUT, "ATM - Gui tien", "Nhap so tien muon gui:", "Gui", "Quay lai");
            case 1: ShowPlayerDialog(playerid, DIALOG_ATM_WITHDRAW, DIALOG_STYLE_INPUT, "ATM - Rut tien", "Nhap so tien muon rut:", "Rut", "Quay lai");
            case 2: ShowPlayerDialog(playerid, DIALOG_ATM_TRANSFER, DIALOG_STYLE_INPUT, "ATM - Chuyen tien", "Nhap theo dinh dang: ID SoTien\nVi du: 12 5000", "Chuyen", "Quay lai");
            default: Economy_ShowATM(playerid);
        }
        return 1;
    }

    if (dialogid == DIALOG_ATM_DEPOSIT || dialogid == DIALOG_ATM_WITHDRAW)
    {
        if (!response)
        {
            Economy_ShowATM(playerid);
            return 1;
        }
        if (Economy_GetNearestATM(playerid) == -1)
        {
            SendClientMessage(playerid, COLOR_RED, "Ban da roi khoi khu vuc ATM.");
            return 1;
        }

        new amount = strval(inputtext);
        if (amount <= 0)
        {
            SendClientMessage(playerid, COLOR_RED, "So tien phai lon hon 0.");
            Economy_ShowATM(playerid);
            return 1;
        }

        if (dialogid == DIALOG_ATM_DEPOSIT)
        {
            if (GetPlayerMoney(playerid) < amount)
            {
                SendClientMessage(playerid, COLOR_RED, "Ban khong du tien mat.");
                Economy_ShowATM(playerid);
                return 1;
            }
            GivePlayerMoney(playerid, -amount);
            s_CharacterBank[playerid] += amount;
            Economy_SaveBalances(playerid);
            Economy_LogTransaction(playerid, "atm_deposit", amount);
            SendClientMessage(playerid, 0x68C83BFF, "Gui tien vao ngan hang thanh cong.");
        }
        else
        {
            if (s_CharacterBank[playerid] < amount)
            {
                SendClientMessage(playerid, COLOR_RED, "Tai khoan ngan hang khong du tien.");
                Economy_ShowATM(playerid);
                return 1;
            }
            s_CharacterBank[playerid] -= amount;
            GivePlayerMoney(playerid, amount);
            Economy_SaveBalances(playerid);
            Economy_LogTransaction(playerid, "atm_withdraw", amount);
            SendClientMessage(playerid, 0x68C83BFF, "Rut tien mat thanh cong.");
        }
        Economy_ShowATM(playerid);
        return 1;
    }

    if (dialogid == DIALOG_ATM_TRANSFER)
    {
        if (!response)
        {
            Economy_ShowATM(playerid);
            return 1;
        }
        new targetid, amount;
        if (!Economy_ParseTransfer(inputtext, targetid, amount) ||
            targetid == playerid ||
            amount <= 0 ||
            !IsPlayerConnected(targetid) ||
            !IsPlayerCharacterLoaded(targetid))
        {
            SendClientMessage(playerid, COLOR_RED, "Nguoi nhan hoac so tien khong hop le.");
            Economy_ShowATM(playerid);
            return 1;
        }
        new transferTax = amount / 100;
        if (transferTax < 1) transferTax = 1;
        if (Economy_GetNearestATM(playerid) == -1 || s_CharacterBank[playerid] < amount + transferTax)
        {
            SendClientMessage(playerid, COLOR_RED, "So du khong du hoac ban da roi khoi ATM.");
            return 1;
        }

        s_CharacterBank[playerid] -= amount + transferTax;
        s_CharacterBank[targetid] += amount;
        LSBank_RecordRevenue("bank_transfer_tax", transferTax, GetPlayerCharacterID(playerid));
        Economy_SaveBalances(playerid);
        Economy_SaveBalances(targetid);
        Economy_LogTransaction(playerid, "bank_transfer_out", -amount, GetPlayerCharacterID(targetid));
        Economy_LogTransaction(targetid, "bank_transfer_in", amount, GetPlayerCharacterID(playerid));

        new message[128];
        format(message, sizeof(message), "Ban da chuyen $%d cho %s. Phi giao dich LS Bank: $%d.", amount, s_CharacterName[targetid], transferTax);
        SendClientMessage(playerid, 0x68C83BFF, message);
        format(message, sizeof(message), "Ban da nhan $%d qua ngan hang tu %s.", amount, s_CharacterName[playerid]);
        SendClientMessage(targetid, 0x68C83BFF, message);
        Economy_ShowATM(playerid);
        return 1;
    }

    if (dialogid == DIALOG_ATM_GOTO)
    {
        if (!response || listitem < 0 || listitem >= ATM_COUNT)
        {
            return 1;
        }
        SetPlayerInterior(playerid, 0);
        SetPlayerVirtualWorld(playerid, 0);
        SetPlayerPos(playerid, g_ATMData[listitem][atmX] + 1.5, g_ATMData[listitem][atmY], g_ATMData[listitem][atmZ]);
        SetPlayerFacingAngle(playerid, g_ATMData[listitem][atmA]);
        return 1;
    }
    return 0;
}

CMD:atm(playerid, params[])
{
    #pragma unused params
    return Economy_ShowATM(playerid);
}

CMD:gotoatm(playerid, params[])
{
    #pragma unused params
    if (!IsPlayerCharacterLoaded(playerid))
    {
        return SendClientMessage(playerid, COLOR_RED, "Ban chua dang nhap nhan vat.");
    }

    new list[256];
    for (new i = 0; i < ATM_COUNT; i++)
    {
        format(list, sizeof(list), "%s%s\n", list, g_ATMData[i][atmName]);
    }
    ShowPlayerDialog(playerid, DIALOG_ATM_GOTO, DIALOG_STYLE_LIST, "Di chuyen den ATM", list, "Di", "Dong");
    return 1;
}
