#include <YSI_Coding\y_hooks>

#define GT_PHONE_BROWSER (52310)
#define GT_PHONE_URL "http://cef/gtasanvn_phone/index.html"
#define GT_PHONE_MAX_CONTACTS (50)
new bool:gtPhoneCreated[MAX_PLAYERS], bool:gtPhoneOpen[MAX_PLAYERS];
new bool:gtPhoneHasWaypoint[MAX_PLAYERS], Float:gtPhoneWaypoint[MAX_PLAYERS][3];
new gtPhoneQueryToken[MAX_PLAYERS], gtPhoneLastAction[MAX_PLAYERS], gtPhoneAlertToken[MAX_PLAYERS];

stock GTPhoneRowCount() { return cache_num_rows(); }

stock GTPhoneError(playerid, const message[])
{
    if (gtPhoneCreated[playerid]) CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "phone:error", CEF_STR(message));
    return 1;
}
stock GTPhoneAllowed(playerid) { return Phone_Require(playerid); }

stock bool:GTPhoneSession(playerid, uid, token)
{
    return IsPlayerConnected(playerid) && gtPhoneCreated[playerid] &&
        IsPlayerCharacterLoaded(playerid) && GetPlayerCharacterID(playerid) == uid &&
        gtPhoneQueryToken[playerid] == token;
}

stock bool:GTPhoneAction(playerid)
{
    if (!gtPhoneOpen[playerid] || !GTPhoneAllowed(playerid)) return false;
    new now = GetTickCount();
    if (gtPhoneLastAction[playerid] && now - gtPhoneLastAction[playerid] < 650)
    {
        GTPhoneError(playerid, "Hay doi mot chut roi thu lai.");
        return false;
    }
    gtPhoneLastAction[playerid] = now;
    return true;
}

stock GTPhoneState(playerid)
{
    if (!gtPhoneCreated[playerid] || !IsPlayerCharacterLoaded(playerid)) return 0;
    CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "phone:state", CEF_INT(g_PhoneNumber[playerid]), CEF_INT(s_CharacterBank[playerid]), CEF_STR(s_CharacterName[playerid]));
    return 1;
}
public GTPhoneCefOpen(playerid)
{
    if (!gtPhoneCreated[playerid] || !g_PhonePowered[playerid] || !GTPhoneAllowed(playerid)) return 0;
    if (gtPhoneOpen[playerid]) return GTPhoneClose(playerid);
    gtPhoneOpen[playerid] = true;
    CEF_SetBrowserVisible(playerid, GT_PHONE_BROWSER, true);
    CEF_FocusBrowser(playerid, GT_PHONE_BROWSER, true);
    CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "phone:open");
    GTPhoneState(playerid);
    GTPhoneCallState(playerid);
    return 1;
}
stock GTPhoneClose(playerid)
{
    gtPhoneOpen[playerid] = false;
    if (gtPhoneCreated[playerid])
    {
        CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "phone:closed");
        CEF_FocusBrowser(playerid, GT_PHONE_BROWSER, false);
        CEF_SetBrowserVisible(playerid, GT_PHONE_BROWSER, false);
    }
    return 1;
}
CMD:dienthoai(playerid, params[])
{
    if (gtPhoneOpen[playerid]) GTPhoneClose(playerid);
    else return Phone_OpenMenu(playerid);
    return 1;
}
CMD:phonecef(playerid, params[]) return cmd_dienthoai(playerid, params);

hook OnGameModeInit()
{
    CEF_AddResource("gtasanvn_phone");
    CEF_RegisterEvent("iphone:feed", "GTIPhoneFeed");
    CEF_RegisterEvent("iphone:post", "GTIPhonePost", Argument_String, Argument_String);
    CEF_RegisterEvent("phone:ready", "GTPhoneOnReady");
    CEF_RegisterEvent("phone:close", "GTPhoneOnClose");
    CEF_RegisterEvent("phone:contacts", "GTPhoneContacts");
    CEF_RegisterEvent("phone:contactAdd", "GTPhoneContactAdd", Argument_String, Argument_Integer);
    CEF_RegisterEvent("phone:contactDelete", "GTPhoneContactDelete", Argument_Integer);
    CEF_RegisterEvent("phone:sms", "GTPhoneSMS", Argument_Integer, Argument_String);
    CEF_RegisterEvent("phone:history", "GTPhoneHistory");
    CEF_RegisterEvent("phone:call", "GTPhoneCall", Argument_Integer);
    CEF_RegisterEvent("phone:pickup", "GTPhonePickup");
    CEF_RegisterEvent("phone:hangup", "GTPhoneHangup");
    CEF_RegisterEvent("phone:refresh", "GTPhoneRefresh");
    CEF_RegisterEvent("phone:profile", "GTPhoneProfile");
    CEF_RegisterEvent("phone:settings", "GTPhoneSetting", Argument_Integer);
    CEF_RegisterEvent("phone:jobs", "GTPhoneJobs");
    CEF_RegisterEvent("phone:pizza", "GTPhonePizza", Argument_Integer);
    CEF_RegisterEvent("phone:vehicles", "GTPhoneVehicles");
    CEF_RegisterEvent("phone:vehicleLocate", "GTPhoneVehicleLocate", Argument_Integer, Argument_Integer);
    CEF_RegisterEvent("phone:vehiclePark", "GTPhoneVehiclePark", Argument_Integer, Argument_Integer);
    CEF_RegisterEvent("phone:vehicleStorage", "GTPhoneVehicleStorage", Argument_Integer, Argument_Integer, Argument_Integer);
    CEF_RegisterEvent("phone:sendPosition", "GTPhoneSendPosition", Argument_Integer);
    CEF_RegisterEvent("phone:waypoint", "GTPhoneWaypoint", Argument_Integer);
    CEF_RegisterEvent("iphone:like", "GTPhoneLike", Argument_Integer);
    CEF_RegisterEvent("iphone:comments", "GTPhoneComments", Argument_Integer);
    CEF_RegisterEvent("iphone:comment", "GTPhoneComment", Argument_Integer, Argument_String);
    return 1;
}
hook OnPlayerConnect(playerid)
{
    gtPhoneHasWaypoint[playerid] = false;
    gtPhoneCreated[playerid] = false;
    gtPhoneOpen[playerid] = false;
    gtPhoneQueryToken[playerid]++;
    gtPhoneLastAction[playerid] = 0;
    gtPhoneAlertToken[playerid]++;
    return 1;
}
hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    gtPhoneHasWaypoint[playerid] = false;
    gtPhoneCreated[playerid] = false;
    gtPhoneOpen[playerid] = false;
    gtPhoneQueryToken[playerid]++;
    gtPhoneLastAction[playerid] = 0;
    gtPhoneAlertToken[playerid]++;
    return 1;
}
hook OnCefReady(playerid)
{
    CEF_CreateBrowser(playerid, GT_PHONE_BROWSER, GT_PHONE_URL, false);
    return 1;
}
hook OnCefBrowserCreated(playerid, browserid, bool:success, E_CEF_CREATE_STATUS:code, const reason[])
{
    if (browserid != GT_PHONE_BROWSER) return 1;
    #pragma unused code
    if (!success) { printf("[GT PHONE] Browser error player=%d reason=%s", playerid, reason); return 1; }
    gtPhoneCreated[playerid] = true;
    CEF_SetBrowserLayer(playerid, GT_PHONE_BROWSER, 30);
    CEF_SetBrowserVisible(playerid, GT_PHONE_BROWSER, false);
    return 1;
}
forward GTPhoneOnReady(playerid);
public GTPhoneOnReady(playerid)
{
    if (!gtPhoneOpen[playerid]) return 1;
    CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "phone:open");
    GTPhoneState(playerid);
    GTPhoneCallState(playerid);
    return 1;
}
forward GTPhoneOnClose(playerid);
public GTPhoneOnClose(playerid) { GTPhoneClose(playerid); return 1; }
forward GTPhoneRefresh(playerid);
public GTPhoneRefresh(playerid) { if (GTPhoneAllowed(playerid)) GTPhoneState(playerid); return 1; }

forward GTPhoneContacts(playerid);
public GTPhoneContacts(playerid)
{
    if (!GTPhoneAllowed(playerid)) return 1;
    new query[256];
    mysql_format(g_DatabaseHandle, query, sizeof query, "SELECT contact_id AS id,contact_name AS name,phone_number AS number FROM phone_contact_entries WHERE character_id=%d ORDER BY contact_name LIMIT 50", GetPlayerCharacterID(playerid));
    mysql_tquery(g_DatabaseHandle, query, "GTPhoneContactsLoaded", "iii", playerid, GetPlayerCharacterID(playerid), gtPhoneQueryToken[playerid]);
    return 1;
}
forward GTPhoneContactsLoaded(playerid, uid, token);
public GTPhoneContactsLoaded(playerid, uid, token)
{
    if (!IsPlayerConnected(playerid) || !gtPhoneCreated[playerid] || GetPlayerCharacterID(playerid) != uid || gtPhoneQueryToken[playerid] != token) return 1;
    new rows=GTPhoneRowCount(), id, number, name[32];
    CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "phone:contactsClear");
    for (new i=0; i<rows; i++)
    {
        cache_get_value_name_int(i, "id", id);
        cache_get_value_name_int(i, "number", number);
        cache_get_value_name(i, "name", name);
        CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "phone:contactItem", CEF_INT(id), CEF_STR(name), CEF_INT(number));
    }
    CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "phone:contactsDone");
    return 1;
}
forward GTPhoneContactAdd(playerid, const name[], number);
public GTPhoneContactAdd(playerid, const name[], number)
{
    if (!GTPhoneAction(playerid)) return 1;
    if (strlen(name) < 1 || strlen(name) > 31 || number < 1000 || number > 999999999) return GTPhoneError(playerid, "Ten hoac so dien thoai khong hop le.");
    new query[300];
    mysql_format(g_DatabaseHandle, query, sizeof query, "INSERT INTO phone_contact_entries(character_id,contact_name,phone_number) SELECT %d,'%e',%d WHERE (SELECT COUNT(*) FROM phone_contact_entries WHERE character_id=%d)<50 ON DUPLICATE KEY UPDATE contact_name=VALUES(contact_name)", GetPlayerCharacterID(playerid), name, number, GetPlayerCharacterID(playerid));
    mysql_tquery(g_DatabaseHandle, query, "GTPhoneAfterContact", "iii", playerid, GetPlayerCharacterID(playerid), gtPhoneQueryToken[playerid]);
    return 1;
}
forward GTPhoneContactDelete(playerid, id);
public GTPhoneContactDelete(playerid, id)
{
    if (!GTPhoneAction(playerid) || id <= 0) return 1;
    new query[180];
    mysql_format(g_DatabaseHandle, query, sizeof query, "DELETE FROM phone_contact_entries WHERE contact_id=%d AND character_id=%d", id, GetPlayerCharacterID(playerid));
    mysql_tquery(g_DatabaseHandle, query, "GTPhoneAfterContact", "iii", playerid, GetPlayerCharacterID(playerid), gtPhoneQueryToken[playerid]);
    return 1;
}
forward GTPhoneAfterContact(playerid, uid, token);
public GTPhoneAfterContact(playerid, uid, token)
{
    if (IsPlayerConnected(playerid) && GetPlayerCharacterID(playerid) == uid && gtPhoneQueryToken[playerid] == token) GTPhoneContacts(playerid);
    return 1;
}
forward GTPhoneSMS(playerid, number, const message[]);
public GTPhoneSMS(playerid, number, const message[])
{
    if (strlen(message) < 1 || strlen(message) > 240) return GTPhoneError(playerid, "Tin nhan tu 1 den 240 byte.");
    return GTPhoneSendMessage(playerid, number, message, false);
}
forward GTPhoneCall(playerid, number);
public GTPhoneCall(playerid, number)
{
    if (!GTPhoneAction(playerid) || number < 1) return 1;
    new params[16]; format(params, sizeof params, "%d", number);
    cmd_call(playerid, params);
    GTPhoneCallState(playerid);
    return 1;
}
forward GTPhonePickup(playerid);
public GTPhonePickup(playerid)
{
    new empty[1];
    if (GTPhoneAction(playerid)) cmd_pickup(playerid, empty);
    return 1;
}
forward GTPhoneHangup(playerid);
public GTPhoneHangup(playerid)
{
    new empty[1];
    if (GTPhoneAction(playerid)) cmd_hangup(playerid, empty);
    return 1;
}
forward GTPhoneHistory(playerid);
public GTPhoneHistory(playerid)
{
    if (!gtPhoneOpen[playerid] || !GTPhoneAllowed(playerid)) return 1;
    new query[320], uid = GetPlayerCharacterID(playerid);
    mysql_format(g_DatabaseHandle, query, sizeof query,
        "SELECT id,sender_number,recipient_number,body,has_position FROM gt_phone_messages WHERE sender_uid=%d OR recipient_uid=%d ORDER BY id DESC LIMIT 50", uid, uid);
    mysql_tquery(g_DatabaseHandle, query, "GTPhoneHistoryLoaded", "iii", playerid, uid, gtPhoneQueryToken[playerid]);
    return 1;
}
forward GTPhoneHistoryLoaded(playerid, uid, token);
public GTPhoneHistoryLoaded(playerid, uid, token)
{
    if (!GTPhoneSession(playerid, uid, token) || !gtPhoneOpen[playerid]) return 1;
    new rows = GTPhoneRowCount(), msg[241], id, from, to, position;
    CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "phone:historyClear");
    for (new i; i < rows; i++)
    {
        cache_get_value_name(i, "body", msg);
        cache_get_value_name_int(i, "id", id);
        cache_get_value_name_int(i, "sender_number", from);
        cache_get_value_name_int(i, "recipient_number", to);
        cache_get_value_name_int(i, "has_position", position);
        CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "phone:historyItem", CEF_INT(id), CEF_INT(from), CEF_INT(to), CEF_STR(msg), CEF_INT(position));
    }
    CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "phone:historyDone");
    return 1;
}

// iPhone extensions: social feed and existing bank transfer command.
forward GTIPhoneFeed(playerid);
public GTIPhoneFeed(playerid)
{
    if (!gtPhoneOpen[playerid] || !GTPhoneAllowed(playerid)) return 1;
    new q[384];
    mysql_format(g_DatabaseHandle, q, sizeof q,
        "SELECT p.id,p.author,p.body,p.photo_url,(SELECT COUNT(*) FROM gt_iphone_likes WHERE post_id=p.id) AS likes,(SELECT COUNT(*) FROM gt_iphone_likes WHERE post_id=p.id AND user_uid=%d) AS liked FROM gt_iphone_posts p ORDER BY p.id DESC LIMIT 30", GetPlayerCharacterID(playerid));
    mysql_tquery(g_DatabaseHandle, q, "GTIPhoneFeedLoaded", "iii", playerid, GetPlayerCharacterID(playerid), gtPhoneQueryToken[playerid]);
    return 1;
}
forward GTIPhoneFeedLoaded(playerid, uid, token);
public GTIPhoneFeedLoaded(playerid, uid, token)
{
    if (!IsPlayerConnected(playerid) || !gtPhoneCreated[playerid] || !IsPlayerCharacterLoaded(playerid) || GetPlayerCharacterID(playerid) != uid || gtPhoneQueryToken[playerid] != token) return 1;
    new rows=GTPhoneRowCount(), author[25], body[241], photo[501], id, likes, liked;
    CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "iphone:feedClear");
    for (new i=0; i<rows; i++)
    {
        cache_get_value_name(i, "author", author);
        cache_get_value_name(i, "body", body);
        cache_get_value_name(i, "photo_url", photo);
        cache_get_value_name_int(i, "id", id);
        cache_get_value_name_int(i, "likes", likes);
        cache_get_value_name_int(i, "liked", liked);
        CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "iphone:postItem", CEF_INT(id), CEF_STR(author), CEF_STR(body), CEF_STR(photo), CEF_INT(likes), CEF_INT(liked));
    }
    CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "iphone:feedDone");
    return 1;
}
forward GTIPhonePost(playerid, const body[], const photo[]);
public GTIPhonePost(playerid, const body[], const photo[])
{
    if (!GTPhoneAction(playerid)) return 1;
    if ((strlen(body) == 0 && strlen(photo) == 0) || strlen(body) > 240 || strlen(photo) > 500)
        return GTPhoneError(playerid, "Noi dung hoac anh khong hop le.");
    if (strlen(photo) && strfind(photo, "https://", true) != 0)
        return GTPhoneError(playerid, "Anh phai su dung lien ket HTTPS.");
    new q[1600];
    mysql_format(g_DatabaseHandle, q, sizeof q, "INSERT INTO gt_iphone_posts(author_uid, author, body, photo_url) VALUES(%d,'%e','%e','%e')", GetPlayerCharacterID(playerid), s_CharacterName[playerid], body, photo);
    printf("[GT SOCIAL] POST request player=%d uid=%d", playerid, GetPlayerCharacterID(playerid));
    if (!mysql_tquery(g_DatabaseHandle, q, "GTIPhoneAfterPost", "iii", playerid, GetPlayerCharacterID(playerid), gtPhoneQueryToken[playerid]))
        return GTPhoneError(playerid, "Khong the gui bai viet.");
    return 1;
}
forward GTIPhoneAfterPost(playerid, uid, token);
public GTIPhoneAfterPost(playerid, uid, token)
{
    if (!IsPlayerConnected(playerid) || !IsPlayerCharacterLoaded(playerid) || GetPlayerCharacterID(playerid) != uid || gtPhoneQueryToken[playerid] != token) return 1;
    new affected = cache_affected_rows();
    printf("[GT SOCIAL] POST result player=%d affected=%d", playerid, affected);
    CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "iphone:postResult", CEF_BOOL(affected > 0), CEF_STR(affected > 0 ? "Dang bai thanh cong!" : "Khong luu duoc bai viet. Kiem tra bang MySQL."));
    if (affected > 0) GTIPhoneFeed(playerid);
    return 1;
}


stock GTPhoneNotice(playerid, const message[])
{
    CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "phone:notice", CEF_STR(message));
    return 1;
}

stock GTPhoneMarkLocation(playerid, Float:x, Float:y, Float:z)
{
    if (GetPlayerVirtualWorld(playerid) || GetPlayerInterior(playerid))
        return GTPhoneError(playerid, "Hay ra ngoai truoc khi bat GPS.");
    if (IsPlayerCheckpointActive(playerid))
        return GTPhoneError(playerid, "Dang co checkpoint. Hay hoan thanh hoac dung /cancelcp truoc.");
    gtPhoneWaypoint[playerid][0] = x;
    gtPhoneWaypoint[playerid][1] = y;
    gtPhoneWaypoint[playerid][2] = z;
    gtPhoneHasWaypoint[playerid] = true;
    SetPlayerCheckpoint(playerid, x, y, z, 4.0);

    SendClientMessage(playerid, -1, "[GPS] Da dat diem den.");
    GTPhoneClose(playerid);
    return 1;
}

forward GTPhoneProfile(playerid);
public GTPhoneProfile(playerid)
{
    if (!gtPhoneOpen[playerid] || !GTPhoneAllowed(playerid)) return 1;
    GTPhoneState(playerid);
    CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "phone:profileData",
        CEF_INT(GetPlayerMoney(playerid)), CEF_INT(GetPlayerScore(playerid)),
        CEF_INT(g_PhoneBattery[playerid]), CEF_INT(0));
    return 1;
}

forward GTPhoneJobs(playerid);
public GTPhoneJobs(playerid)
{
    if (!gtPhoneOpen[playerid] || !GTPhoneAllowed(playerid)) return 1;
    new job[32];
    Job_GetName(pJob[playerid], job, sizeof job);
    CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "phone:jobData", CEF_STR(job), CEF_STR(""),
        CEF_BOOL(Pizza_IsEmployee(playerid)), CEF_INT(s_PizzaShiftDeliveries[playerid]),
        CEF_BOOL(Pizza_IsOnShift(playerid)), CEF_INT(s_PlayerJobShiftEarnings[playerid]));
    return 1;
}

forward GTPhonePizza(playerid, action);
public GTPhonePizza(playerid, action)
{
    if (!GTPhoneAction(playerid)) return 1;
    if (!action) return GTPhoneMarkLocation(playerid, PIZZA_NPC_X, PIZZA_NPC_Y, PIZZA_NPC_Z);
    if (action != 1 || !Pizza_IsEmployee(playerid)) return 1;
    GTPhoneClose(playerid);
    return Pizza_HandleYInteraction(playerid);
}

stock bool:GTPhoneVehicleSlot(playerid, slot, id)
{
    return SimpleVehicle_IsValidSlot(playerid, slot) && id > 0 &&
        PlayerVehicle[playerid][slot][pvDatabaseID] == id &&
        !PlayerVehicle[playerid][slot][pvCompanyVehicle] &&
        s_SimpleVehicleCharacterID[playerid] == GetPlayerCharacterID(playerid);
}

forward GTPhoneVehicles(playerid);
public GTPhoneVehicles(playerid)
{
    if (!gtPhoneOpen[playerid] || !GTPhoneAllowed(playerid)) return 1;
    CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "phone:vehiclesClear");
    new name[32], db, storage, id;
    for (new slot; slot < s_SimpleVehicleCount[playerid]; slot++)
    {
        db = PlayerVehicle[playerid][slot][pvDatabaseID];
        if (!GTPhoneVehicleSlot(playerid, slot, db)) continue;
        storage = PlayerVehicle[playerid][slot][pvStorage];
        id = PlayerVehicle[playerid][slot][pvServerID];
        SimpleVehicle_GetModelName(PlayerVehicle[playerid][slot][pvModelID], name, sizeof name);
        CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "phone:vehicleItem", CEF_INT(slot),
            CEF_INT(db), CEF_STR(name), CEF_STR(PlayerVehicle[playerid][slot][pvPlate]),
            CEF_INT(floatround(PlayerVehicle[playerid][slot][pvFuel])),
            CEF_BOOL(id != INVALID_VEHICLE_ID && GetPlayerVehicleID(playerid) == id && GetPlayerState(playerid) == PLAYER_STATE_DRIVER),
            CEF_INT(storage));
    }
    CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "phone:vehiclesDone");
    return 1;
}

forward GTPhoneVehicleLocate(playerid, slot, db);
public GTPhoneVehicleLocate(playerid, slot, db)
{
    if (!GTPhoneAction(playerid) || !GTPhoneVehicleSlot(playerid, slot, db)) return 1;
    if (IsPlayerCheckpointActive(playerid) || GetPlayerInterior(playerid) || GetPlayerVirtualWorld(playerid) ||
        PlayerVehicle[playerid][slot][pvInterior] || PlayerVehicle[playerid][slot][pvVirtualWorld])
        return GTPhoneError(playerid, "Khong the dat GPS tai day hoac dang co checkpoint.");
    SimpleVehicle_ShowGPS(playerid, slot);
    return GTPhoneClose(playerid);
}

forward GTPhoneVehiclePark(playerid, slot, db);
public GTPhoneVehiclePark(playerid, slot, db)
{
    if (!GTPhoneAction(playerid) || !GTPhoneVehicleSlot(playerid, slot, db)) return 1;
    SimpleVehicle_Park(playerid, slot);
    return GTPhoneVehicles(playerid);
}

forward GTPhoneVehicleStorage(playerid, slot, db, retrieve);
public GTPhoneVehicleStorage(playerid, slot, db, retrieve)
{
    if (!GTPhoneAction(playerid) || !GTPhoneVehicleSlot(playerid, slot, db)) return 1;
    if (retrieve == 1) SimpleVehicle_Spawn(playerid, slot);
    else if (retrieve == 0) SimpleVehicle_Store(playerid, slot, true, true);
    return GTPhoneVehicles(playerid);
}

forward GTPhoneSendPosition(playerid, number);
public GTPhoneSendPosition(playerid, number)
{
    if (GetPlayerInterior(playerid) || GetPlayerVirtualWorld(playerid))
        return GTPhoneError(playerid, "Chi gui vi tri khi dang o ben ngoai.");
    return GTPhoneSendMessage(playerid, number, "", true);
}

stock GTPhoneSendMessage(playerid, number, const message[], bool:position)
{
    if (!GTPhoneAction(playerid)) return 1;
    new ownNumber = g_PhoneNumber[playerid], uid = GetPlayerCharacterID(playerid), query[1050];
    if (number <= 0 || number == ownNumber) return GTPhoneError(playerid, "So dien thoai khong hop le.");
    new Float:x, Float:y, Float:z;
    if (position) GetPlayerPos(playerid, x, y, z);
    mysql_format(g_DatabaseHandle, query, sizeof query,
        "INSERT INTO gt_phone_messages(sender_uid,recipient_uid,sender_number,recipient_number,body,has_position,x,y,z) SELECT %d,character_id,%d,phone_number,'%e',%d,%f,%f,%f FROM character_phone_profiles WHERE phone_number=%d AND character_id<>%d AND powered=1 LIMIT 1",
        uid, ownNumber, message, _:position, x, y, z, number, uid);
    if (!mysql_tquery(g_DatabaseHandle, query, "GTPhoneAfterMessage", "iiii",
        playerid, uid, gtPhoneQueryToken[playerid], number)) return GTPhoneError(playerid, "Khong the gui tin nhan.");
    return 1;
}

forward GTPhoneAfterMessage(playerid, uid, token, number);
public GTPhoneAfterMessage(playerid, uid, token, number)
{
    if (cache_affected_rows() != 1)
    {
        if (GTPhoneSession(playerid, uid, token)) GTPhoneError(playerid, "So nay khong nhan duoc tin nhan.");
        return 1;
    }
    if (GTPhoneSession(playerid, uid, token) && gtPhoneOpen[playerid])
    {
        GTPhoneNotice(playerid, "Da gui tin nhan.");
        GTPhoneHistory(playerid);
    }
    for (new target; target < MAX_PLAYERS; target++)
    {
        if (!IsPlayerConnected(target) || !IsPlayerCharacterLoaded(target) || g_PhoneNumber[target] != number) continue;
        if (g_PhonePowered[target] && !g_PhoneSilent[target]) GTPhoneAlert(target, "Tin nhan moi", "Mo /dienthoai de xem.");
        if (gtPhoneOpen[target]) GTPhoneHistory(target);
        break;
    }
    return 1;
}

forward GTPhoneWaypoint(playerid, id);
public GTPhoneWaypoint(playerid, id)
{
    if (!GTPhoneAction(playerid) || id <= 0) return 1;
    new uid = GetPlayerCharacterID(playerid), query[240];
    mysql_format(g_DatabaseHandle, query, sizeof query,
        "SELECT x,y,z FROM gt_phone_messages WHERE id=%d AND has_position=1 AND (sender_uid=%d OR recipient_uid=%d) LIMIT 1",
        id, uid, uid);
    mysql_tquery(g_DatabaseHandle, query, "GTPhoneWaypointLoaded", "iii", playerid, uid, gtPhoneQueryToken[playerid]);
    return 1;
}

forward GTPhoneWaypointLoaded(playerid, uid, token);
public GTPhoneWaypointLoaded(playerid, uid, token)
{
    if (!GTPhoneSession(playerid, uid, token) || !gtPhoneOpen[playerid] || !GTPhoneAllowed(playerid)) return 1;
    if (!GTPhoneRowCount()) return GTPhoneError(playerid, "Khong tim thay vi tri.");
    new Float:x, Float:y, Float:z;
    cache_get_value_name_float(0, "x", x);
    cache_get_value_name_float(0, "y", y);
    cache_get_value_name_float(0, "z", z);
    return GTPhoneMarkLocation(playerid, x, y, z);
}

forward GTPhoneCallState(playerid);
public GTPhoneCallState(playerid)
{
    if (!gtPhoneCreated[playerid] || !IsPlayerCharacterLoaded(playerid)) return 1;
    new peer = g_PhonePeer[playerid], stage = g_PhoneConnected[playerid] ? 2 : g_PhoneIncoming[playerid] ? 1 : 0, number;
    if (peer >= 0 && peer < MAX_PLAYERS && IsPlayerConnected(peer)) number = g_PhoneNumber[peer];
    new callState = peer == INVALID_PLAYER_ID ? -1 : stage;
    CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "phone:callState", CEF_INT(callState), CEF_INT(number));
    if (stage == 1 && number > 0 && !gtPhoneOpen[playerid] && !g_PhoneSilent[playerid]) GTPhoneAlert(playerid, "Cuoc goi den", "Dung /pickup de nghe hoac /hangup de tu choi.");
    return 1;
}

stock GTPhoneAlert(playerid, const title[], const body[])
{
    if (!gtPhoneCreated[playerid]) return SendClientMessage(playerid, -1, body);
    CEF_SetBrowserVisible(playerid, GT_PHONE_BROWSER, true);
    CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "phone:alert", CEF_STR(title), CEF_STR(body));
    SetTimerEx("GTPhoneHideAlert", 6500, false, "ii", playerid, ++gtPhoneAlertToken[playerid]);
    return 1;
}

forward GTPhoneHideAlert(playerid, token);
public GTPhoneHideAlert(playerid, token)
{
    if (!IsPlayerConnected(playerid) || !gtPhoneCreated[playerid] || gtPhoneAlertToken[playerid] != token) return 1;
    CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "phone:alertClear");
    if (!gtPhoneOpen[playerid]) CEF_SetBrowserVisible(playerid, GT_PHONE_BROWSER, false);
    return 1;
}

forward GTPhoneLike(playerid, post);
public GTPhoneLike(playerid, post)
{
    if (!GTPhoneAction(playerid) || post <= 0) return 1;
    new query[240];
    mysql_format(g_DatabaseHandle, query, sizeof query,
        "INSERT IGNORE INTO gt_iphone_likes(post_id,user_uid) SELECT id,%d FROM gt_iphone_posts WHERE id=%d", GetPlayerCharacterID(playerid), post);
    mysql_tquery(g_DatabaseHandle, query, "GTPhoneSocialChanged", "iiii", playerid, GetPlayerCharacterID(playerid), gtPhoneQueryToken[playerid], 0);
    return 1;
}

forward GTPhoneComments(playerid, post);
public GTPhoneComments(playerid, post)
{
    if (post <= 0 || !gtPhoneOpen[playerid] || !GTPhoneAllowed(playerid)) return 1;
    new query[220];
    mysql_format(g_DatabaseHandle, query, sizeof query,
        "SELECT author,body FROM gt_iphone_comments WHERE post_id=%d ORDER BY id DESC LIMIT 25", post);
    mysql_tquery(g_DatabaseHandle, query, "GTPhoneCommentsLoaded", "iiii", playerid, GetPlayerCharacterID(playerid), gtPhoneQueryToken[playerid], post);
    return 1;
}

forward GTPhoneCommentsLoaded(playerid, uid, token, post);
public GTPhoneCommentsLoaded(playerid, uid, token, post)
{
    if (!GTPhoneSession(playerid, uid, token) || !gtPhoneOpen[playerid]) return 1;
    CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "iphone:commentsClear", CEF_INT(post));
    new rows = GTPhoneRowCount(), author[25], body[241];
    for (new i = rows - 1; i >= 0; i--)
    {
        cache_get_value_name(i, "author", author);
        cache_get_value_name(i, "body", body);
        CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "iphone:commentItem", CEF_INT(post), CEF_STR(author), CEF_STR(body));
    }
    CEF_EmitEvent(playerid, GT_PHONE_BROWSER, "iphone:commentsDone", CEF_INT(post));
    return 1;
}

forward GTPhoneComment(playerid, post, const body[]);
public GTPhoneComment(playerid, post, const body[])
{
    if (!GTPhoneAction(playerid) || post <= 0) return 1;
    if (!strlen(body) || strlen(body) > 240) return GTPhoneError(playerid, "Binh luan tu 1 den 240 byte.");
    new query[800];
    mysql_format(g_DatabaseHandle, query, sizeof query,
        "INSERT INTO gt_iphone_comments(post_id,author_uid,author,body) SELECT id,%d,'%e','%e' FROM gt_iphone_posts WHERE id=%d",
        GetPlayerCharacterID(playerid), s_CharacterName[playerid], body, post);
    mysql_tquery(g_DatabaseHandle, query, "GTPhoneSocialChanged", "iiii", playerid, GetPlayerCharacterID(playerid), gtPhoneQueryToken[playerid], post);
    return 1;
}

forward GTPhoneSocialChanged(playerid, uid, token, post);
public GTPhoneSocialChanged(playerid, uid, token, post)
{
    if (!GTPhoneSession(playerid, uid, token) || !gtPhoneOpen[playerid]) return 1;
    if (post > 0)
    {
        if (cache_affected_rows() != 1) return GTPhoneError(playerid, "Khong luu duoc binh luan.");
        return GTPhoneComments(playerid, post);
    }
    return GTIPhoneFeed(playerid);
}

forward GTPhoneSetting(playerid, action);
public GTPhoneSetting(playerid, action)
{
    if (!GTPhoneAction(playerid)) return 1;
    if (action == 0)
    {
        g_PhoneSilent[playerid] = !g_PhoneSilent[playerid];
        Phone_Save(playerid);
        return GTPhoneNotice(playerid, g_PhoneSilent[playerid] ? "Da bat im lang." : "Da tat im lang.");
    }
    if (action == 1)
    {
        g_PhonePowered[playerid] = false;
        Phone_ClearCall(playerid);
        Phone_Save(playerid);
        GTPhoneClose(playerid);
        return Phone_OpenMenu(playerid);
    }
    return 1;
}

stock GTPhoneClearWaypoint(playerid)
{
    if (!gtPhoneHasWaypoint[playerid]) return 0;
    gtPhoneHasWaypoint[playerid] = false;
    new Float:x, Float:y, Float:z, Float:radius;
    if (IsPlayerCheckpointActive(playerid) && GetPlayerCheckpoint(playerid, x, y, z, radius) && radius == 4.0 &&
        x == gtPhoneWaypoint[playerid][0] && y == gtPhoneWaypoint[playerid][1] && z == gtPhoneWaypoint[playerid][2])
    {
        DisablePlayerCheckpoint(playerid);
        return 1;
    }
    return 0;
}

hook OnPlayerEnterCheckpoint(playerid)
{
    GTPhoneClearWaypoint(playerid);
    return 1;
}

CMD:phonegpsclear(playerid, params[])
{
    #pragma unused params
    if (GTPhoneClearWaypoint(playerid)) SendClientMessage(playerid, COLOR_WHITE, "Da huy GPS dien thoai.");
    return 1;
}
