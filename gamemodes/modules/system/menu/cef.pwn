#include <YSI_Coding\y_hooks>

#define MAIN_MENU_BROWSER (52311)
#define MAIN_MENU_KEY (0x48)

static bool:s_MainMenuReady[MAX_PLAYERS];
static bool:s_MainMenuOpen[MAX_PLAYERS];

stock MainMenu_Close(playerid)
{
    s_MainMenuOpen[playerid] = false;
    CEF_EmitEvent(playerid, MAIN_MENU_BROWSER, "mainMenu:hide");
    CEF_FocusBrowser(playerid, MAIN_MENU_BROWSER, false);
    CEF_SetBrowserVisible(playerid, MAIN_MENU_BROWSER, false);
    return 1;
}

stock MainMenu_Toggle(playerid)
{
    if (!IsPlayerCharacterLoaded(playerid)) return 1;
    if (gtPhoneOpen[playerid] || GetPlayerDialogID(playerid) != INVALID_DIALOG_ID) return 1;
    if (s_MainMenuOpen[playerid]) return MainMenu_Close(playerid);
    if (!s_MainMenuReady[playerid])
        return SendClientMessage(playerid, COLOR_WHITE, "Menu CEF chua san sang. Dung /help de xem huong dan.");

    s_MainMenuOpen[playerid] = true;
    CEF_SetBrowserVisible(playerid, MAIN_MENU_BROWSER, true);
    CEF_FocusBrowser(playerid, MAIN_MENU_BROWSER, true);
    new stage = s_TutorialLoaded[playerid] ? s_TutorialStage[playerid] : -1;
    CEF_EmitEvent(playerid, MAIN_MENU_BROWSER, "mainMenu:show", CEF_INT(stage));
    return 1;
}

CMD:menu(playerid, params[])
{
    #pragma unused params
    return MainMenu_Toggle(playerid);
}

forward MainMenu_Action(playerid, action);
public MainMenu_Action(playerid, action)
{
    if (!s_MainMenuOpen[playerid] || !IsPlayerCharacterLoaded(playerid)) return 1;

    new empty[1];
    switch (action)
    {
        case 0: return MainMenu_Close(playerid);
        case 1:
        {
            new stage = s_TutorialLoaded[playerid] ? s_TutorialStage[playerid] : -1;
            CEF_EmitEvent(playerid, MAIN_MENU_BROWSER, "mainMenu:stage", CEF_INT(stage));
        }
        case 2:
        {
            if (!s_TutorialLoaded[playerid] || s_TutorialStage[playerid] >= 3) return 1;
            if (GetPlayerInterior(playerid) || GetPlayerVirtualWorld(playerid))
            {
                CEF_EmitEvent(playerid, MAIN_MENU_BROWSER, "mainMenu:notice", CEF_STR("Ra ngoài trước khi đặt GPS."));
                return 1;
            }
            MainMenu_Close(playerid);
            if (s_TutorialStage[playerid] == 0) return cmd_dealers(playerid, empty);
            return Tutorial_SetCheckpoint(playerid);
        }
        case 3:
        {
            MainMenu_Close(playerid);
            return cmd_help(playerid, empty);
        }
        case 4:
        {
            MainMenu_Close(playerid);
            return cmd_inv(playerid, empty);
        }
        case 5:
        {
            MainMenu_Close(playerid);
            return Phone_OpenMenu(playerid);
        }
    }
    return 1;
}

hook OnGameModeInit()
{
    CEF_AddResource("gtasanvn_menu");
    CEF_RegisterEvent("mainMenu:action", "MainMenu_Action", Argument_Integer);
    return 1;
}

hook OnCefReady(playerid)
{
    CEF_CreateBrowser(playerid, MAIN_MENU_BROWSER, "http://cef/gtasanvn_menu/index.html", false);
    CEF_SetBrowserVisible(playerid, MAIN_MENU_BROWSER, false);
    CEF_EnableKey(playerid, MAIN_MENU_KEY, true);
    CEF_SetKeyCapture(playerid, true);
    return 1;
}

hook OnCefBrowserCreated(playerid, browserid, bool:success, E_CEF_CREATE_STATUS:code, const reason[])
{
    #pragma unused code, reason
    if (browserid != MAIN_MENU_BROWSER || !success) return 1;
    s_MainMenuReady[playerid] = true;
    CEF_SetBrowserLayer(playerid, MAIN_MENU_BROWSER, 31);
    CEF_SetBrowserVisible(playerid, MAIN_MENU_BROWSER, false);
    return 1;
}

hook OnCefPressKey(playerid, key, scancode, modifiers, bool:down, bool:repeat)
{
    #pragma unused scancode, modifiers
    if (key == MAIN_MENU_KEY && down && !repeat && !CEF_IsChatInputOpen(playerid))
        MainMenu_Toggle(playerid);
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    s_MainMenuOpen[playerid] = false;
    s_MainMenuReady[playerid] = false;
    return 1;
}
