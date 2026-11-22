#include <YSI_Coding\y_hooks>

#define LOADING_BROWSER (52312)
#define LOADING_RESOURCE "gtasanvn_loading"

static bool:s_LoadingPending[MAX_PLAYERS];
static bool:s_LoadingBrowser[MAX_PLAYERS];
static bool:s_LoadingEnding[MAX_PLAYERS];
static s_LoadingSession[MAX_PLAYERS];

forward Loading_Finish(playerid, session);
public Loading_Finish(playerid, session)
{
    if (!IsPlayerConnected(playerid) || !s_LoadingPending[playerid] ||
        s_LoadingSession[playerid] != session) return 1;

    s_LoadingPending[playerid] = false;
    if (s_LoadingBrowser[playerid])
    {
        s_LoadingBrowser[playerid] = false;
        CEF_DestroyBrowser(playerid, LOADING_BROWSER);
    }
    if (!IsPlayerLoggedIn(playerid)) Account_ShowUsernameDialog(playerid);
    return 1;
}

stock Loading_Begin(playerid)
{
    s_LoadingSession[playerid]++;
    s_LoadingPending[playerid] = true;
    s_LoadingBrowser[playerid] = false;
    s_LoadingEnding[playerid] = false;
    SetTimerEx("Loading_Finish", 4500, false, "dd", playerid, s_LoadingSession[playerid]);
    return 1;
}

hook OnGameModeInit()
{
    CEF_AddResource(LOADING_RESOURCE);
    CEF_RegisterEvent("loading:assetReady", "Loading_AssetReady");
    return 1;
}

hook OnCefReady(playerid)
{
    if (!s_LoadingPending[playerid] || s_LoadingBrowser[playerid]) return 1;
    s_LoadingBrowser[playerid] = true;
    CEF_CreateBrowser(playerid, LOADING_BROWSER, "http://cef/gtasanvn_loading/index.html", false, false);
    return 1;
}

hook OnCefInitialize(playerid, bool:success, E_CEF_INIT_REASON:reason, const message[])
{
    #pragma unused reason, message
    if (!success) Loading_Finish(playerid, s_LoadingSession[playerid]);
    return 1;
}

hook OnCefBrowserCreated(playerid, browserid, bool:success, E_CEF_CREATE_STATUS:code, const reason[])
{
    #pragma unused code, reason
    if (browserid != LOADING_BROWSER || !s_LoadingPending[playerid]) return 1;
    if (!success)
    {
        s_LoadingBrowser[playerid] = false;
        return Loading_Finish(playerid, s_LoadingSession[playerid]);
    }
    CEF_SetBrowserLayer(playerid, LOADING_BROWSER, 32);
    return 1;
}

forward Loading_AssetReady(playerid);
public Loading_AssetReady(playerid)
{
    if (!s_LoadingPending[playerid] || !s_LoadingBrowser[playerid] ||
        s_LoadingEnding[playerid]) return 1;
    s_LoadingEnding[playerid] = true;
    CEF_EmitEvent(playerid, LOADING_BROWSER, "loading:complete");
    SetTimerEx("Loading_Finish", 800, false, "dd", playerid, s_LoadingSession[playerid]);
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    s_LoadingPending[playerid] = false;
    s_LoadingBrowser[playerid] = false;
    s_LoadingEnding[playerid] = false;
    s_LoadingSession[playerid]++;
    return 1;
}
