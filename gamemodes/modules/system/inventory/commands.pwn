//-----------------------------------------------------------------------------
// LS:RP Inventory - Commands
//-----------------------------------------------------------------------------

stock bool:Inventory_ParseThreeInts(const params[], &a, &b, &c)
{
    new values[3], found, index, len = strlen(params);

    while (found < 3)
    {
        while (index < len && params[index] == ' ') index++;
        if (index >= len) return false;

        new token[16], t;
        while (index < len && params[index] != ' ' && t < sizeof(token) - 1)
        {
            token[t++] = params[index++];
        }
        token[t] = EOS;
        values[found++] = strval(token);
    }

    a = values[0];
    b = values[1];
    c = values[2];
    return true;
}

CMD:inventory(playerid, params[])
{
    #pragma unused params
    InventoryUI_Open(playerid);
    return 1;
}

CMD:inv(playerid, params[])
{
    #pragma unused params
    InventoryUI_Open(playerid);
    return 1;
}

// /additemtest [playerid] [itemid 1-50] [amount]
CMD:additemtest(playerid, params[])
{
    if (!Admin_RequireLevel(playerid, ADMIN_LEVEL_ADMIN))
    {
        return 1;
    }

    new targetid, itemIndex, amount;

    if (!Inventory_ParseThreeInts(params, targetid, itemIndex, amount))
    {
        SendClientMessage(playerid, COLOR_RED,
            "Su dung: /additemtest [playerid] [itemid 1-50] [amount]");
        return 1;
    }

    if (!IsPlayerConnected(targetid) ||
        !IsPlayerCharacterLoaded(targetid) ||
        !Inventory_IsLoaded(targetid))
    {
        SendClientMessage(playerid, COLOR_RED,
            "Player muc tieu khong hop le hoac inventory chua load.");
        return 1;
    }

    if (itemIndex < 1 || itemIndex > 50 || amount <= 0)
    {
        SendClientMessage(playerid, COLOR_RED,
            "Item ID phai tu 1 den 50 va amount phai lon hon 0.");
        return 1;
    }

    new const E_ITEM_ID:itemID = E_ITEM_ID:itemIndex;

    if (!Inventory_AddItem(targetid, itemID, amount))
    {
        SendClientMessage(playerid, COLOR_RED,
            "Add that bai: het slot, qua 25kg hoac item khong hop le.");
        return 1;
    }

    new msg[144];
    format(msg, sizeof(msg),
        "Da add %s x%d cho player %d. Item ID %d.",
        g_ItemData[itemID][itemName], amount, targetid, itemIndex);
    SendClientMessage(playerid, COLOR_WHITE, msg);

    if (g_InventoryUIOpen[targetid])
    {
        InventoryUI_Refresh(targetid);
    }
    return 1;
}

// Reload the active LEFT/RIGHT firearm from compatible inventory ammo.
CMD:reload(playerid, params[])
{
    #pragma unused params

    if (!IsPlayerCharacterLoaded(playerid) || !Inventory_IsLoaded(playerid))
    {
        SendClientMessage(playerid, COLOR_RED,
            "Inventory cua nhan vat chua san sang.");
        return 1;
    }

    InventoryWeapon_ReloadActive(playerid);

    if (g_InventoryUIOpen[playerid])
    {
        InventoryUI_Refresh(playerid);
    }
    return 1;
}

// /itemlist [1/2]
CMD:itemlist(playerid, params[])
{
    new page = 1;
    if (params[0] != EOS) page = strval(params);
    if (page < 1 || page > 2) page = 1;

    new body[2048], line[72];
    format(body, sizeof(body), "ID\tITEM\tTYPE\n");

    new const start = (page - 1) * 25 + 1;
    new end = start + 24;
    if (end > 50) end = 50;

    for (new index = start; index <= end; index++)
    {
        new const E_ITEM_ID:itemID = E_ITEM_ID:index;
        new typeName[12];

        switch (g_ItemData[itemID][itemType])
        {
            case ITEM_TYPE_WEAPON: format(typeName, sizeof(typeName), "WEAPON");
            case ITEM_TYPE_AMMO: format(typeName, sizeof(typeName), "AMMO");
            default: format(typeName, sizeof(typeName), "ITEM");
        }

        format(line, sizeof(line), "%d\t%s\t%s\n",
            index, g_ItemData[itemID][itemName], typeName);
        strcat(body, line, sizeof(body));
    }

    ShowPlayerDialog(
        playerid,
        19990,
        DIALOG_STYLE_TABLIST_HEADERS,
        page == 1 ? "Inventory Item List 1/2" : "Inventory Item List 2/2",
        body,
        "Dong",
        ""
    );
    return 1;
}
