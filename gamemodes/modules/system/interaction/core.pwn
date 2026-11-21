#include <YSI_Coding\y_hooks>

#define INTERACTION_RANGE (3.0)

new g_InteractionTarget[MAX_PLAYERS];
new g_InteractionVehicleInvite[MAX_PLAYERS];
new g_InteractionDragging[MAX_PLAYERS];
new g_InteractionDragTimer;

forward Interaction_DragTick();

stock bool:Interaction_IsNear(playerid, targetid)
{
    if (targetid == playerid || !IsPlayerConnected(targetid) ||
        !IsPlayerCharacterLoaded(targetid) ||
        GetPlayerInterior(targetid) != GetPlayerInterior(playerid) ||
        GetPlayerVirtualWorld(targetid) != GetPlayerVirtualWorld(playerid)) return false;
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    return GetPlayerDistanceFromPoint(targetid, x, y, z) <= INTERACTION_RANGE;
}

stock Interaction_GetNearest(playerid)
{
    new nearest = INVALID_PLAYER_ID;
    new Float:best = INTERACTION_RANGE + 0.01;
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    for (new targetid = 0; targetid < MAX_PLAYERS; targetid++)
    {
        if (!Interaction_IsNear(playerid, targetid)) continue;
        new Float:distance = GetPlayerDistanceFromPoint(targetid, x, y, z);
        if (distance < best)
        {
            best = distance;
            nearest = targetid;
        }
    }
    return nearest;
}

stock Interaction_Open(playerid, targetid)
{
    if (!Interaction_IsNear(playerid, targetid))
        return SendClientMessage(playerid, COLOR_RED, "Nguoi choi khong hop le hoac khong dung gan ban.");
    g_InteractionTarget[playerid] = targetid;
    new title[96];
    format(title, sizeof(title), "Tuong tac - %s [%d]", s_CharacterName[targetid], targetid);
    ShowPlayerDialog(playerid, DIALOG_INTERACT_MAIN, DIALOG_STYLE_LIST, title,
        "Xem mo ta nhan vat\nDua tien\nDua vat pham\nCho xem ID Card\nCho xem bang lai\nTrao doi so dien thoai\nMoi len xe\nKham nguoi bat tinh\nKeo/cong nguoi bat tinh",
        "Chon", "Dong");
    return 1;
}

stock Interaction_ShowID(ownerid, viewerid)
{
    if (!Tutorial_HasIDCard(ownerid) || !s_TutorialSerial[ownerid][0])
        return SendClientMessage(viewerid, COLOR_RED, "Nguoi nay khong co ID Card hop le.");
    new body[512];
    format(body, sizeof(body),
        "{68C83B}LOS SANTOS ID CARD\n\n{FFFFFF}Ho ten: %s\nSerial: %s\nNgay sinh: %02d/%02d/%d\nGioi tinh: %s\nNoi sinh: %s",
        s_CharacterName[ownerid], s_TutorialSerial[ownerid],
        s_CharacterBirthDay[ownerid], s_CharacterBirthMonth[ownerid],
        s_CharacterBirthYear[ownerid],
        s_CharacterGender[ownerid] == 0 ? "Nam" : "Nu",
        g_BirthPlaceNames[s_CharacterBirthPlace[ownerid]]);
    ShowPlayerDialog(viewerid, DIALOG_TUTORIAL_IDCARD, DIALOG_STYLE_MSGBOX,
        "Giay to duoc xuat trinh", body, "Dong", "");
    return 1;
}

stock bool:Interaction_HasLicense(playerid)
{
    for (new slot = 0; slot < MAX_INVENTORY_SLOTS; slot++)
    {
        if (PlayerInventory[playerid][slot][invExists] &&
            PlayerInventory[playerid][slot][invItemID] == ITEM_DRIVER_LICENSE) return true;
    }
    return false;
}

stock Interaction_Search(playerid, targetid)
{
    if (!Medical_IsIncapacitated(targetid))
        return SendClientMessage(playerid, COLOR_RED, "Chi co the kham nguoi dang bat tinh/khong con kha nang phan khang.");
    new body[1600], count;
    for (new slot = 0; slot < MAX_INVENTORY_SLOTS; slot++)
    {
        if (!PlayerInventory[targetid][slot][invExists]) continue;
        new const E_ITEM_ID:itemID = PlayerInventory[targetid][slot][invItemID];
        format(body, sizeof(body), "%s%s x%d\n", body,
            g_ItemData[itemID][itemName], PlayerInventory[targetid][slot][invAmount]);
        count++;
    }
    if (!count) format(body, sizeof(body), "Khong tim thay vat pham nao.");
    ShowPlayerDialog(playerid, DIALOG_INTERACT_VIEW, DIALOG_STYLE_MSGBOX,
        "Ket qua kham nguoi", body, "Dong", "");
    new message[160];
    format(message, sizeof(message), "%s da kham nguoi cua %s.", s_CharacterName[playerid], s_CharacterName[targetid]);
    RP_SendLocalMessage(playerid, message, COLOR_RP_ME, RP_CHAT_RADIUS);
    return 1;
}

stock Interaction_ToggleDrag(playerid, targetid)
{
    if (g_InteractionDragging[playerid] != INVALID_PLAYER_ID)
    {
        new oldTarget = g_InteractionDragging[playerid];
        g_InteractionDragging[playerid] = INVALID_PLAYER_ID;
        if (IsPlayerConnected(oldTarget)) SendClientMessage(oldTarget, COLOR_WHITE, "Nguoi choi da ngung keo/cong ban.");
        return SendClientMessage(playerid, COLOR_WHITE, "Ban da ngung keo/cong nguoi choi.");
    }
    if (!Medical_IsIncapacitated(targetid))
        return SendClientMessage(playerid, COLOR_RED, "Chi co the keo/cong nguoi dang bat tinh.");
    g_InteractionDragging[playerid] = targetid;
    SendClientMessage(playerid, COLOR_WHITE, "Ban dang keo/cong nguoi choi. Dung /stopdrag de dung.");
    SendClientMessage(targetid, COLOR_WHITE, "Ban dang duoc mot nguoi choi keo/cong.");
    return 1;
}

public Interaction_DragTick()
{
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        new const targetid = g_InteractionDragging[playerid];
        if (targetid == INVALID_PLAYER_ID) continue;
        if (!IsPlayerConnected(playerid) || !IsPlayerConnected(targetid) ||
            !Medical_IsIncapacitated(targetid) ||
            GetPlayerInterior(playerid) != GetPlayerInterior(targetid) ||
            GetPlayerVirtualWorld(playerid) != GetPlayerVirtualWorld(targetid))
        {
            g_InteractionDragging[playerid] = INVALID_PLAYER_ID;
            continue;
        }
        new Float:x, Float:y, Float:z, Float:a;
        GetPlayerPos(playerid, x, y, z);
        GetPlayerFacingAngle(playerid, a);
        x -= floatsin(-a, degrees) * 0.8;
        y -= floatcos(-a, degrees) * 0.8;
        SetPlayerPos(targetid, x, y, z);
        SetPlayerInterior(targetid, GetPlayerInterior(playerid));
        SetPlayerVirtualWorld(targetid, GetPlayerVirtualWorld(playerid));
    }
    return 1;
}

hook OnGameModeInit()
{
    g_InteractionDragTimer = SetTimer("Interaction_DragTick", 400, true);
    return 1;
}

hook OnGameModeExit()
{
    if (g_InteractionDragTimer) KillTimer(g_InteractionDragTimer);
    return 1;
}

hook OnPlayerConnect(playerid)
{
    g_InteractionTarget[playerid] = INVALID_PLAYER_ID;
    g_InteractionVehicleInvite[playerid] = INVALID_PLAYER_ID;
    g_InteractionDragging[playerid] = INVALID_PLAYER_ID;
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (g_InteractionVehicleInvite[i] == playerid) g_InteractionVehicleInvite[i] = INVALID_PLAYER_ID;
        if (g_InteractionDragging[i] == playerid) g_InteractionDragging[i] = INVALID_PLAYER_ID;
    }
    return 1;
}

CMD:interact(playerid, params[])
{
    new targetid = params[0] ? strval(params) : Interaction_GetNearest(playerid);
    return Interaction_Open(playerid, targetid);
}

CMD:stopdrag(playerid, params[])
{
    #pragma unused params
    if (g_InteractionDragging[playerid] == INVALID_PLAYER_ID)
        return SendClientMessage(playerid, COLOR_RED, "Ban khong keo/cong ai.");
    return Interaction_ToggleDrag(playerid, g_InteractionDragging[playerid]);
}

CMD:accept(playerid, params[])
{
    #pragma unused params
    new const inviter = g_InteractionVehicleInvite[playerid];
    if (inviter == INVALID_PLAYER_ID || !IsPlayerConnected(inviter))
        return SendClientMessage(playerid, COLOR_RED, "Ban khong co loi moi nao can chap nhan.");
    new const vehicleid = GetPlayerVehicleID(inviter);
    if (!Interaction_IsNear(playerid, inviter) || GetPlayerState(inviter) != PLAYER_STATE_DRIVER ||
        vehicleid == INVALID_VEHICLE_ID)
    {
        g_InteractionVehicleInvite[playerid] = INVALID_PLAYER_ID;
        return SendClientMessage(playerid, COLOR_RED, "Loi moi da het han hoac xe khong con hop le.");
    }
    PutPlayerInVehicle(playerid, vehicleid, 1);
    g_InteractionVehicleInvite[playerid] = INVALID_PLAYER_ID;
    return 1;
}

CMD:cancel(playerid, params[])
{
    #pragma unused params
    g_InteractionVehicleInvite[playerid] = INVALID_PLAYER_ID;
    return SendClientMessage(playerid, COLOR_WHITE, "Ban da huy loi moi dang cho.");
}

hook OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys)
{
    #pragma unused oldkeys
    if ((newkeys & KEY_NO) && GetPlayerState(playerid) == PLAYER_STATE_ONFOOT)
    {
        new const targetid = Interaction_GetNearest(playerid);
        if (targetid != INVALID_PLAYER_ID) Interaction_Open(playerid, targetid);
    }
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    new const targetid = g_InteractionTarget[playerid];
    if (dialogid == DIALOG_INTERACT_MAIN)
    {
        if (!response) return 1;
        if (!Interaction_IsNear(playerid, targetid))
            return SendClientMessage(playerid, COLOR_RED, "Nguoi choi da roi khoi pham vi tuong tac.");
        switch (listitem)
        {
            case 0:
            {
                new body[384];
                format(body, sizeof(body), "Ten: %s\nNgoai hinh: Skin %d\nChieu cao: %d cm\nCan nang: %d kg\nTinh cach/mo ta: %s",
                    s_CharacterName[targetid], s_CharacterSkin[targetid],
                    s_CharacterHeight[targetid], s_CharacterWeight[targetid],
                    s_CharacterPersonality[targetid][0] ? s_CharacterPersonality[targetid] : "Chua co mo ta");
                ShowPlayerDialog(playerid, DIALOG_INTERACT_VIEW, DIALOG_STYLE_MSGBOX, "Mo ta nhan vat", body, "Dong", "");
            }
            case 1: ShowPlayerDialog(playerid, DIALOG_INTERACT_PAY, DIALOG_STYLE_INPUT, "Dua tien", "Nhap so tien mat muon dua:", "Dua", "Huy");
            case 2: ShowPlayerDialog(playerid, DIALOG_INTERACT_ITEM, DIALOG_STYLE_INPUT, "Dua vat pham", "Nhap: SLOT SOLUONG\nVi du: 3 1\nID Card va vu khi khong the dua bang menu nhanh.", "Dua", "Huy");
            case 3:
            {
                Interaction_ShowID(playerid, targetid);
                new message[128];
                format(message, sizeof(message), "%s cho ban xem ID Card.", s_CharacterName[playerid]);
                SendClientMessage(targetid, COLOR_WHITE, message);
            }
            case 4:
            {
                if (!Interaction_HasLicense(playerid)) return SendClientMessage(playerid, COLOR_RED, "Ban khong co bang lai trong tui do.");
                new body[192];
                format(body, sizeof(body), "Chu so huu: %s\nTrang thai: Con hieu luc\nLoai: Bang lai xe co gioi", s_CharacterName[playerid]);
                ShowPlayerDialog(targetid, DIALOG_INTERACT_VIEW, DIALOG_STYLE_MSGBOX, "Bang lai duoc xuat trinh", body, "Dong", "");
                SendClientMessage(playerid, COLOR_WHITE, "Ban da cho nguoi choi xem bang lai.");
            }
            case 5:
            {
                if (!Phone_Require(playerid)) return 1;
                new command[16];
                format(command, sizeof(command), "%d", targetid);
                cmd_number(playerid, command);
            }
            case 6:
            {
                if (GetPlayerState(playerid) != PLAYER_STATE_DRIVER)
                    return SendClientMessage(playerid, COLOR_RED, "Ban phai dang lai xe de moi nguoi choi len xe.");
                g_InteractionVehicleInvite[targetid] = playerid;
                SendClientMessage(targetid, 0x68C83BFF, "Ban nhan duoc loi moi len xe. Dung /accept hoac /cancel.");
                SendClientMessage(playerid, COLOR_WHITE, "Da gui loi moi len xe.");
            }
            case 7: Interaction_Search(playerid, targetid);
            case 8: Interaction_ToggleDrag(playerid, targetid);
        }
        return 1;
    }
    if (dialogid == DIALOG_INTERACT_PAY)
    {
        if (!response) return 1;
        if (!Interaction_IsNear(playerid, targetid)) return SendClientMessage(playerid, COLOR_RED, "Nguoi choi da roi khoi pham vi.");
        new const amount = strval(inputtext);
        if (amount <= 0 || amount > 1000000) return SendClientMessage(playerid, COLOR_RED, "So tien phai tu $1 den $1,000,000.");
        if (GetPlayerMoney(playerid) < amount) return SendClientMessage(playerid, COLOR_RED, "Ban khong du tien mat.");
        GivePlayerMoney(playerid, -amount);
        GivePlayerMoney(targetid, amount);
        Economy_SaveBalances(playerid);
        Economy_SaveBalances(targetid);
        Economy_LogTransaction(playerid, "player_cash_give", -amount, GetPlayerCharacterID(targetid), "Interaction cash transfer");
        Economy_LogTransaction(targetid, "player_cash_receive", amount, GetPlayerCharacterID(playerid), "Interaction cash transfer");
        new message[160];
        format(message, sizeof(message), "Ban da dua $%d cho %s.", amount, s_CharacterName[targetid]);
        SendClientMessage(playerid, 0x68C83BFF, message);
        format(message, sizeof(message), "%s da dua cho ban $%d.", s_CharacterName[playerid], amount);
        SendClientMessage(targetid, 0x68C83BFF, message);
        return 1;
    }
    if (dialogid == DIALOG_INTERACT_ITEM && response)
    {
        if (!Interaction_IsNear(playerid, targetid)) return SendClientMessage(playerid, COLOR_RED, "Nguoi choi da roi khoi pham vi.");
        new separator = strfind(inputtext, " ");
        if (separator <= 0) return SendClientMessage(playerid, COLOR_RED, "Nhap theo dinh dang: SLOT SOLUONG");
        new slotText[12];
        strmid(slotText, inputtext, 0, separator, sizeof(slotText));
        new slot = strval(slotText) - 1, amount = strval(inputtext[separator + 1]);
        if (slot < 0 || slot >= MAX_INVENTORY_SLOTS || amount <= 0 ||
            !PlayerInventory[playerid][slot][invExists] ||
            PlayerInventory[playerid][slot][invAmount] < amount)
            return SendClientMessage(playerid, COLOR_RED, "Slot hoac so luong khong hop le.");
        new const E_ITEM_ID:itemID = PlayerInventory[playerid][slot][invItemID];
        if (itemID == ITEM_ID_CARD || g_ItemData[itemID][itemType] == ITEM_TYPE_WEAPON)
            return SendClientMessage(playerid, COLOR_RED, "Vat pham nay khong the chuyen bang menu tuong tac nhanh.");
        if (!Inventory_CanCarry(targetid, itemID, amount) || !Inventory_HasSlotCapacity(targetid, itemID, amount))
            return SendClientMessage(playerid, COLOR_RED, "Tui do nguoi nhan khong du cho trong hoac vuot qua trong luong.");
        if (!Inventory_AddItem(targetid, itemID, amount)) return SendClientMessage(playerid, COLOR_RED, "Khong the them vat pham cho nguoi nhan.");
        Inventory_RemoveFromSlot(playerid, slot, amount);
        Inventory_SaveCharacter(playerid, true);
        Inventory_SaveCharacter(targetid, true);
        new message[160];
        format(message, sizeof(message), "Ban da dua %s x%d cho %s.", g_ItemData[itemID][itemName], amount, s_CharacterName[targetid]);
        SendClientMessage(playerid, 0x68C83BFF, message);
        format(message, sizeof(message), "%s da dua cho ban %s x%d.", s_CharacterName[playerid], g_ItemData[itemID][itemName], amount);
        SendClientMessage(targetid, 0x68C83BFF, message);
        return 1;
    }
    if (dialogid == DIALOG_INTERACT_VIEW) return 1;
    return 0;
}
