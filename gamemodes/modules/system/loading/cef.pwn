#include <YSI_Coding\y_hooks>

#define LOADING_BROWSER (52312)
#define LOADING_RESOURCE "gtasanvn_loading"
#define LOADING_DISPLAY_MS (3700)

static Text:s_LoadingBackdrop = Text:INVALID_TEXT_DRAW;

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
    if (s_LoadingBackdrop != Text:INVALID_TEXT_DRAW) TextDrawHideForPlayer(playerid, s_LoadingBackdrop);
    if (s_LoadingBrowser[playerid])
    {
        s_LoadingBrowser[playerid] = false;
        CEF_DestroyBrowser(playerid, LOADING_BROWSER);
    }
    if (!IsPlayerLoggedIn(playerid)) Account_ShowUsernameDialog(playerid);
    return 1;
}

stock Loading_Wait(playerid, milliseconds)
{
    s_LoadingSession[playerid]++;
    SetTimerEx("Loading_Finish", milliseconds, false, "dd", playerid, s_LoadingSession[playerid]);
}

stock Loading_Begin(playerid)
{
    s_LoadingPending[playerid] = true;
    s_LoadingBrowser[playerid] = false;
    s_LoadingEnding[playerid] = false;
    if (s_LoadingBackdrop != Text:INVALID_TEXT_DRAW) TextDrawShowForPlayer(playerid, s_LoadingBackdrop);
    Loading_Wait(playerid, 4500);
    return 1;
}

hook OnGameModeInit()
{
    // The client can render this before its CEF browser is ready.
    s_LoadingBackdrop = TextDrawCreate(0.0, 0.0, "LD_SPAC:white");
    TextDrawFont(s_LoadingBackdrop, TEXT_DRAW_FONT_SPRITE_DRAW);
    TextDrawTextSize(s_LoadingBackdrop, 640.0, 480.0);
    TextDrawColor(s_LoadingBackdrop, 0x000000FF);
    CEF_AddResource(LOADING_RESOURCE);
    CEF_RegisterEvent("loading:assetReady", "Loading_AssetReady");
    return 1;
}

hook OnCefReady(playerid)
{
    if (!s_LoadingPending[playerid] || s_LoadingBrowser[playerid]) return 1;
    s_LoadingBrowser[playerid] = true;
    Loading_Wait(playerid, 5000);
    CEF_CreateBrowser(playerid, LOADING_BROWSER, "http://cef/gtasanvn_loading/index.html", false, false);
    return 1;
}

hook OnCefInitialize(playerid, bool:success, E_CEF_INIT_REASON:reason, const message[])
{
    #pragma unused reason, message
    if (!success) Loading_Finish(playerid, s_LoadingSession[playerid]);
    else if (s_LoadingPending[playerid] && !s_LoadingBrowser[playerid]) Loading_Wait(playerid, 20000);
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
    if (s_LoadingBackdrop != Text:INVALID_TEXT_DRAW) TextDrawHideForPlayer(playerid, s_LoadingBackdrop);
    CEF_EmitEvent(playerid, LOADING_BROWSER, "loading:complete");
    Loading_Wait(playerid, LOADING_DISPLAY_MS);
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
