#include <YSI_Coding\y_hooks>

//-----------------------------------------------------------------------------
// Final command fallback. This file must be included after every command.
//-----------------------------------------------------------------------------

// Show one styled fallback message only when no registered command handled it.
hook OnPlayerCommandText(playerid, cmdtext[])
{
    new command[40], index;

    while (index < sizeof(command) - 1 &&
        cmdtext[index] != 0 &&
        cmdtext[index] != ' ' &&
        cmdtext[index] != '\t')
    {
        command[index] = cmdtext[index];
        index++;
    }
    command[index] = 0;

    new message[160];

    format(
        message,
        sizeof(message),
        "{BFC0C2}Lenh {7A2929}%s{BFC0C2} khong ton tai. Su dung {264A73}/help{BFC0C2} de xem chi tiet.",
        command
    );

    SendClientMessage(playerid, COLOR_WHITE, message);

    // Stop the callback chain so open.mp does not append its own
    // "Unknown command" message.
    return ~1;
}
