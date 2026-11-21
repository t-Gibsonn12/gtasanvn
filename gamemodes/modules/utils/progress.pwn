#include <YSI_Coding\y_hooks>

#define PROGRESS_TICK_MS       (100)
#define PROGRESS_CALLBACK_LEN  (40)

new bool:g_ProgressActive[MAX_PLAYERS];
new g_ProgressElapsed[MAX_PLAYERS];
new g_ProgressDuration[MAX_PLAYERS];
new g_ProgressTimer[MAX_PLAYERS];
new g_ProgressCallback[MAX_PLAYERS][PROGRESS_CALLBACK_LEN];
new PlayerText:g_ProgressBackground[MAX_PLAYERS];
new PlayerText:g_ProgressFill[MAX_PLAYERS];
new PlayerText:g_ProgressLabel[MAX_PLAYERS];

forward Progress_Tick(playerid);

stock bool:Progress_IsActive(playerid)
{
    return g_ProgressActive[playerid];
}

stock Progress_Stop(playerid)
{
    if (g_ProgressTimer[playerid])
    {
        KillTimer(g_ProgressTimer[playerid]);
    }
    g_ProgressTimer[playerid] = 0;
    g_ProgressActive[playerid] = false;
    g_ProgressElapsed[playerid] = 0;
    g_ProgressDuration[playerid] = 0;
    g_ProgressCallback[playerid][0] = 0;
    PlayerTextDrawHide(playerid, g_ProgressBackground[playerid]);
    PlayerTextDrawHide(playerid, g_ProgressFill[playerid]);
    PlayerTextDrawHide(playerid, g_ProgressLabel[playerid]);
    return 1;
}

stock Progress_Start(playerid, const label[], duration, const callback[])
{
    if (g_ProgressActive[playerid] || duration < PROGRESS_TICK_MS)
    {
        return 0;
    }

    g_ProgressActive[playerid] = true;
    g_ProgressElapsed[playerid] = 0;
    g_ProgressDuration[playerid] = duration;
    format(g_ProgressCallback[playerid], PROGRESS_CALLBACK_LEN, "%s", callback);

    PlayerTextDrawSetString(playerid, g_ProgressLabel[playerid], label);
    PlayerTextDrawTextSize(playerid, g_ProgressFill[playerid], 220.0, 0.0);
    PlayerTextDrawShow(playerid, g_ProgressBackground[playerid]);
    PlayerTextDrawShow(playerid, g_ProgressFill[playerid]);
    PlayerTextDrawShow(playerid, g_ProgressLabel[playerid]);
    g_ProgressTimer[playerid] = SetTimerEx("Progress_Tick", PROGRESS_TICK_MS, true, "d", playerid);
    return 1;
}

public Progress_Tick(playerid)
{
    if (!IsPlayerConnected(playerid) || !g_ProgressActive[playerid])
    {
        return Progress_Stop(playerid);
    }

    g_ProgressElapsed[playerid] += PROGRESS_TICK_MS;
    new Float:ratio = float(g_ProgressElapsed[playerid]) / float(g_ProgressDuration[playerid]);
    if (ratio > 1.0)
    {
        ratio = 1.0;
    }
    PlayerTextDrawTextSize(playerid, g_ProgressFill[playerid], 220.0 + (200.0 * ratio), 0.0);
    PlayerTextDrawShow(playerid, g_ProgressFill[playerid]);

    if (g_ProgressElapsed[playerid] >= g_ProgressDuration[playerid])
    {
        new callback[PROGRESS_CALLBACK_LEN];
        format(callback, sizeof(callback), "%s", g_ProgressCallback[playerid]);
        Progress_Stop(playerid);
        CallLocalFunction(callback, "d", playerid);
    }
    return 1;
}

hook OnPlayerConnect(playerid)
{
    g_ProgressActive[playerid] = false;
    g_ProgressTimer[playerid] = 0;

    g_ProgressBackground[playerid] = CreatePlayerTextDraw(playerid, 220.0, 381.0, "_");
    PlayerTextDrawUseBox(playerid, g_ProgressBackground[playerid], true);
    PlayerTextDrawBoxColor(playerid, g_ProgressBackground[playerid], 0x111820DD);
    PlayerTextDrawTextSize(playerid, g_ProgressBackground[playerid], 420.0, 0.0);
    PlayerTextDrawLetterSize(playerid, g_ProgressBackground[playerid], 0.0, 1.25);

    g_ProgressFill[playerid] = CreatePlayerTextDraw(playerid, 220.0, 381.0, "_");
    PlayerTextDrawUseBox(playerid, g_ProgressFill[playerid], true);
    PlayerTextDrawBoxColor(playerid, g_ProgressFill[playerid], 0x68C83BEE);
    PlayerTextDrawTextSize(playerid, g_ProgressFill[playerid], 220.0, 0.0);
    PlayerTextDrawLetterSize(playerid, g_ProgressFill[playerid], 0.0, 1.25);

    g_ProgressLabel[playerid] = CreatePlayerTextDraw(playerid, 320.0, 366.0, "DANG XU LY...");
    PlayerTextDrawAlignment(playerid, g_ProgressLabel[playerid], TEXT_DRAW_ALIGN_CENTER);
    PlayerTextDrawFont(playerid, g_ProgressLabel[playerid], TEXT_DRAW_FONT_2);
    PlayerTextDrawLetterSize(playerid, g_ProgressLabel[playerid], 0.20, 0.95);
    PlayerTextDrawColor(playerid, g_ProgressLabel[playerid], COLOR_WHITE);
    PlayerTextDrawSetOutline(playerid, g_ProgressLabel[playerid], 1);
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    if (g_ProgressTimer[playerid])
    {
        KillTimer(g_ProgressTimer[playerid]);
    }
    g_ProgressTimer[playerid] = 0;
    g_ProgressActive[playerid] = false;
    return 1;
}
