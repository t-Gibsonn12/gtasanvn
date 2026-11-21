//-----------------------------------------------------------------------------
// LS:RP Inventory - TextDraw UI
//
// 3-panel layout:
// CATEGORIES | ALL ITEMS | ITEM DETAILS
//-----------------------------------------------------------------------------

#include <YSI_Coding\y_hooks>

#define INV_UI_BG          (0x101010EE)
#define INV_UI_PANEL       (0x181818F2)
#define INV_UI_ROW         (0x222222F2)
#define INV_UI_SELECTED    (0x542020F2)
#define INV_UI_RED         (0xB73434FF)
#define INV_UI_WHITE       (0xFFFFFFFF)
#define INV_UI_GRAY        (0xBFC0C2FF)

new PlayerText:g_InvBG[MAX_PLAYERS];
new PlayerText:g_InvTitle[MAX_PLAYERS];
new PlayerText:g_InvClose[MAX_PLAYERS];
new PlayerText:g_InvCategoryTitle[MAX_PLAYERS];
new PlayerText:g_InvListTitle[MAX_PLAYERS];
new PlayerText:g_InvSlots[MAX_PLAYERS];
new PlayerText:g_InvDetailTitle[MAX_PLAYERS];

new PlayerText:g_InvCategory[MAX_PLAYERS][ITEM_CATEGORY_COUNT];
new PlayerText:g_InvRow[MAX_PLAYERS][INVENTORY_UI_ROWS];

// Dedicated transparent hitboxes. Visible row TextDraws are display-only.
new PlayerText:g_InvCategoryClick[MAX_PLAYERS][ITEM_CATEGORY_COUNT];
new PlayerText:g_InvRowClick[MAX_PLAYERS][INVENTORY_UI_ROWS];

// Large model preview is only used in the selected-item detail panel.
new PlayerText:g_InvDetailPreview[MAX_PLAYERS];

new PlayerText:g_InvDetailName[MAX_PLAYERS];
new PlayerText:g_InvDetailDesc[MAX_PLAYERS];
new PlayerText:g_InvDetailMeta[MAX_PLAYERS];

new PlayerText:g_InvUse[MAX_PLAYERS];
new PlayerText:g_InvGive[MAX_PLAYERS];
new PlayerText:g_InvDrop[MAX_PLAYERS];
new PlayerText:g_InvExamine[MAX_PLAYERS];

new PlayerText:g_InvWeight[MAX_PLAYERS];

// LEFT/RIGHT loadout slots shown below inventory weight.
new PlayerText:g_InvHand[MAX_PLAYERS][WEAPON_HAND_COUNT];
new PlayerText:g_InvHandClick[MAX_PLAYERS][WEAPON_HAND_COUNT];

new PlayerText:g_InvPrev[MAX_PLAYERS];
new PlayerText:g_InvNext[MAX_PLAYERS];

stock PlayerText:InventoryUI_Text(
    playerid,
    Float:x,
    Float:y,
    const text[],
    Float:sizeX,
    Float:sizeY,
    color
)
{
    new PlayerText:td = CreatePlayerTextDraw(playerid, x, y, text);
    PlayerTextDrawFont(playerid, td, TEXT_DRAW_FONT:1);
    PlayerTextDrawLetterSize(playerid, td, sizeX, sizeY);
    PlayerTextDrawColor(playerid, td, color);
    PlayerTextDrawSetOutline(playerid, td, 0);
    PlayerTextDrawSetShadow(playerid, td, 0);
    return td;
}

stock PlayerText:InventoryUI_Box(
    playerid,
    Float:x,
    Float:y,
    Float:right,
    Float:height,
    color
)
{
    new PlayerText:td = CreatePlayerTextDraw(playerid, x, y, "_");
    PlayerTextDrawLetterSize(playerid, td, 0.0, height);
    PlayerTextDrawTextSize(playerid, td, right, 0.0);
    PlayerTextDrawUseBox(playerid, td, true);
    PlayerTextDrawBoxColor(playerid, td, color);
    return td;
}

stock InventoryUI_Selectable(playerid, PlayerText:td, Float:right, Float:bottom)
{
    PlayerTextDrawTextSize(playerid, td, right, bottom);
    PlayerTextDrawSetSelectable(playerid, td, true);
    return 1;
}

// Separate click area for filter/item rows. This keeps the selectable region
// independent from the visible TextDraw's font and box dimensions.
stock PlayerText:InventoryUI_ClickArea(
    playerid,
    Float:x,
    Float:y,
    Float:right,
    Float:bottom
)
{
    new PlayerText:td = CreatePlayerTextDraw(playerid, x, y, "_");

    PlayerTextDrawFont(playerid, td, TEXT_DRAW_FONT:1);
    PlayerTextDrawLetterSize(playerid, td, 0.10, 0.30);
    PlayerTextDrawTextSize(playerid, td, right, bottom);
    PlayerTextDrawColor(playerid, td, 0x00000000);
    PlayerTextDrawBackgroundColor(playerid, td, 0x00000000);
    PlayerTextDrawSetOutline(playerid, td, 0);
    PlayerTextDrawSetShadow(playerid, td, 0);
    PlayerTextDrawSetSelectable(playerid, td, true);
    return td;
}

// Return a GTA model suitable for a TextDraw preview.
// Weapons use their GTA weapon model IDs directly. Generic objects use a
// representative SA object so every inventory row still has visual identity.
stock InventoryUI_GetPreviewModel(E_ITEM_ID:itemID)
{
    switch (itemID)
    {
        // Sentinel values are never real inventory entries.
        case ITEM_NONE,
             ITEM_COUNT:
        {
            return 1271;
        }

        // Only retain generic object models that are known to preview cleanly.
        case ITEM_WATER_BOTTLE: return 1484;
        case ITEM_PHONE: return 18867;
        case ITEM_CAMERA: return 367;
        case ITEM_FLASHLIGHT: return 18641;
        case ITEM_FUEL_CAN: return 1650;

        // GTA weapon object models are stable in model previews.
        case ITEM_BASEBALL_BAT: return 336;
        case ITEM_KNIFE: return 335;
        case ITEM_GLOCK_17: return 346;
        case ITEM_COLT_M1911: return 347;
        case ITEM_DESERT_EAGLE: return 348;
        case ITEM_SHOTGUN: return 349;
        case ITEM_MP5: return 353;
        case ITEM_AK47: return 355;
        case ITEM_M4: return 356;
        case ITEM_RIFLE: return 357;
        case ITEM_SNIPER_RIFLE: return 358;

        // Unsupported/uncertain models intentionally use one neutral package.
        default:
        {
            return 1271;
        }
    }
}

stock InventoryUI_SetPreview(
    playerid,
    PlayerText:textdraw,
    E_ITEM_ID:itemID,
    Float:zoom
)
{
    PlayerTextDrawSetPreviewModel(
        playerid,
        textdraw,
        InventoryUI_GetPreviewModel(itemID)
    );

    PlayerTextDrawSetPreviewRot(
        playerid,
        textdraw,
        -12.0,
        0.0,
        -18.0,
        zoom
    );
    return 1;
}

stock InventoryUI_Create(playerid)
{
    if (g_InventoryUICreated[playerid]) return 1;

    // Compact three-column layout centered on screen.
    g_InvBG[playerid] =
        InventoryUI_Box(playerid, 82.0, 94.0, 558.0, 23.5, INV_UI_BG);

    g_InvTitle[playerid] =
        InventoryUI_Text(playerid, 96.0, 103.0, "TUI DO", 0.25, 1.05, INV_UI_WHITE);

    g_InvClose[playerid] =
        InventoryUI_Text(playerid, 541.0, 103.0, "X", 0.22, 0.95, INV_UI_RED);

    InventoryUI_Selectable(
        playerid,
        g_InvClose[playerid],
        555.0,
        118.0
    );

    g_InvCategoryTitle[playerid] =
        InventoryUI_Text(
            playerid,
            96.0,
            127.0,
            "DANH MUC",
            0.158,
            0.72,
            INV_UI_RED
        );

    g_InvListTitle[playerid] =
        InventoryUI_Text(
            playerid,
            184.0,
            127.0,
            "TAT CA",
            0.158,
            0.72,
            INV_UI_RED
        );

    g_InvSlots[playerid] =
        InventoryUI_Text(
            playerid,
            352.0,
            127.0,
            "0 / 50 O",
            0.125,
            0.64,
            INV_UI_GRAY
        );

    g_InvDetailTitle[playerid] =
        InventoryUI_Text(
            playerid,
            398.0,
            127.0,
            "CHI TIET VAT PHAM",
            0.145,
            0.68,
            INV_UI_RED
        );

    // Categories are intentionally packed tightly.
    for (new categoryIndex = 0;
        categoryIndex < _:ITEM_CATEGORY_COUNT;
        categoryIndex++)
    {
        new const E_ITEM_CATEGORY:category =
            E_ITEM_CATEGORY:categoryIndex;

        new Float:y = 142.0 + float(categoryIndex * 14);

        g_InvCategory[playerid][category] =
            InventoryUI_Text(
                playerid,
                94.0,
                y,
                "_",
                0.156,
                0.95,
                INV_UI_WHITE
            );

        PlayerTextDrawUseBox(
            playerid,
            g_InvCategory[playerid][category],
            true
        );

        // TextSize here only defines the visible UseBox bounds.
        // Clicks are handled by g_InvCategoryClick, so this cannot overlap input.
        PlayerTextDrawTextSize(
            playerid,
            g_InvCategory[playerid][category],
            181.0,
            y + 10.0
        );

        PlayerTextDrawBoxColor(
            playerid,
            g_InvCategory[playerid][category],
            INV_UI_ROW
        );

        // Keep the visible filter row display-only. A separate transparent
        // TextDraw handles clicks with a fixed, non-overlapping hitbox.
        g_InvCategoryClick[playerid][category] =
            InventoryUI_ClickArea(
                playerid,
                94.0,
                y,
                181.0,
                y + 8.0
            );
    }

    // Item list uses text only. Removing row previews prevents incorrect
    // repeated weapon/object models from polluting the interface.
    for (new row = 0; row < INVENTORY_UI_ROWS; row++)
    {
        new Float:y = 142.0 + float(row * 14);

        g_InvRow[playerid][row] =
            InventoryUI_Text(
                playerid,
                184.0,
                y,
                "_",
                0.156,
                0.95,
                INV_UI_WHITE
            );

        PlayerTextDrawUseBox(
            playerid,
            g_InvRow[playerid][row],
            true
        );

        // Keep the visible item background inside the middle column.
        // This TextDraw is display-only; the transparent clickbox handles input.
        PlayerTextDrawTextSize(
            playerid,
            g_InvRow[playerid][row],
            390.0,
            y + 10.0
        );

        PlayerTextDrawBoxColor(
            playerid,
            g_InvRow[playerid][row],
            INV_UI_ROW
        );

        // Keep the visible item row display-only. Its click region is a
        // dedicated transparent TextDraw smaller than the 14-unit row spacing.
        g_InvRowClick[playerid][row] =
            InventoryUI_ClickArea(
                playerid,
                184.0,
                y,
                390.0,
                y + 8.0
            );
    }

    // Keep one large preview in the details panel.
    g_InvDetailPreview[playerid] =
        CreatePlayerTextDraw(playerid, 410.0, 139.0, "_");

    PlayerTextDrawFont(
        playerid,
        g_InvDetailPreview[playerid],
        TEXT_DRAW_FONT_MODEL_PREVIEW
    );

    PlayerTextDrawBackgroundColor(
        playerid,
        g_InvDetailPreview[playerid],
        0x171717FF
    );

    PlayerTextDrawColor(
        playerid,
        g_InvDetailPreview[playerid],
        0xFFFFFFFF
    );

    PlayerTextDrawTextSize(
        playerid,
        g_InvDetailPreview[playerid],
        112.0,
        68.0
    );

    PlayerTextDrawSetPreviewModel(
        playerid,
        g_InvDetailPreview[playerid],
        1271
    );

    PlayerTextDrawSetPreviewRot(
        playerid,
        g_InvDetailPreview[playerid],
        -12.0,
        0.0,
        -18.0,
        0.90
    );

    g_InvDetailName[playerid] =
        InventoryUI_Text(
            playerid,
            398.0,
            218.0,
            "CHON VAT PHAM",
            0.220,
            0.90,
            INV_UI_WHITE
        );

    g_InvDetailDesc[playerid] =
        InventoryUI_Text(
            playerid,
            398.0,
            234.0,
            "Chon mot vat pham trong danh sach.",
            0.125,
            0.58,
            INV_UI_GRAY
        );

    g_InvDetailMeta[playerid] =
        InventoryUI_Text(
            playerid,
            398.0,
            250.0,
            "_",
            0.128,
            0.60,
            INV_UI_GRAY
        );

    // Buttons are compact and aligned on one row.
    g_InvUse[playerid] =
        InventoryUI_Text(playerid, 398.0, 286.0, "DUNG", 0.135, 0.62, INV_UI_WHITE);

    g_InvGive[playerid] =
        InventoryUI_Text(playerid, 438.0, 286.0, "DUA", 0.135, 0.62, INV_UI_WHITE);

    g_InvDrop[playerid] =
        InventoryUI_Text(playerid, 478.0, 286.0, "THA", 0.135, 0.62, INV_UI_WHITE);

    g_InvExamine[playerid] =
        InventoryUI_Text(playerid, 518.0, 286.0, "XEM", 0.135, 0.62, INV_UI_WHITE);

    new PlayerText:buttons[4];
    buttons[0] = g_InvUse[playerid];
    buttons[1] = g_InvGive[playerid];
    buttons[2] = g_InvDrop[playerid];
    buttons[3] = g_InvExamine[playerid];

    new const Float:buttonRight[4] =
    {
        432.0,
        472.0,
        512.0,
        550.0
    };

    for (new button = 0; button < 4; button++)
    {
        PlayerTextDrawUseBox(playerid, buttons[button], true);
        PlayerTextDrawBoxColor(playerid, buttons[button], INV_UI_ROW);

        InventoryUI_Selectable(
            playerid,
            buttons[button],
            buttonRight[button],
            301.0
        );
    }

    g_InvWeight[playerid] =
        InventoryUI_Text(
            playerid,
            96.0,
            258.0,
            "TRONG LUONG  0.0 / 25.0 KG",
            0.135,
            0.62,
            INV_UI_WHITE
        );

    // LEFT/RIGHT HAND are two equal boxes on the SAME horizontal row.
    // Visible boxes are display-only; transparent TextDraws handle clicks.
    for (new handIndex = 0; handIndex < _:WEAPON_HAND_COUNT; handIndex++)
    {
        new const E_WEAPON_HAND:hand = E_WEAPON_HAND:handIndex;

        // Same Y for both boxes. LEFT occupies the left half, RIGHT the right.
        new const Float:x =
            hand == WEAPON_HAND_LEFT ? 96.0 : 246.0;

        new const Float:right =
            hand == WEAPON_HAND_LEFT ? 240.0 : 390.0;

        new label[24];

        if (hand == WEAPON_HAND_LEFT)
        {
            format(label, sizeof(label), "LEFT HAND~n~TRONG");
        }
        else
        {
            format(label, sizeof(label), "RIGHT HAND~n~TRONG");
        }

        g_InvHand[playerid][hand] =
            InventoryUI_Text(
                playerid,
                x,
                275.0,
                label,
                0.112,
                0.46,
                INV_UI_WHITE
            );

        PlayerTextDrawUseBox(
            playerid,
            g_InvHand[playerid][hand],
            true
        );

        PlayerTextDrawTextSize(
            playerid,
            g_InvHand[playerid][hand],
            right,
            300.0
        );

        PlayerTextDrawBoxColor(
            playerid,
            g_InvHand[playerid][hand],
            INV_UI_ROW
        );

        g_InvHandClick[playerid][hand] =
            InventoryUI_ClickArea(
                playerid,
                x,
                275.0,
                right,
                300.0
            );
    }

    g_InvPrev[playerid] =
        InventoryUI_Text(
            playerid,
            282.0,
            258.0,
            "< TRUOC",
            0.13,
            0.62,
            INV_UI_GRAY
        );

    g_InvNext[playerid] =
        InventoryUI_Text(
            playerid,
            338.0,
            258.0,
            "SAU >",
            0.13,
            0.62,
            INV_UI_GRAY
        );

    InventoryUI_Selectable(
        playerid,
        g_InvPrev[playerid],
        340.0,
        273.0
    );

    InventoryUI_Selectable(
        playerid,
        g_InvNext[playerid],
        382.0,
        273.0
    );

    g_InventoryUICreated[playerid] = true;
    return 1;
}

stock InventoryUI_ShowAll(playerid, bool:show)
{
    #define INV_VIS(%0) \
        if (show) PlayerTextDrawShow(playerid, %0); \
        else PlayerTextDrawHide(playerid, %0)

    INV_VIS(g_InvBG[playerid]);
    INV_VIS(g_InvTitle[playerid]);
    INV_VIS(g_InvClose[playerid]);
    INV_VIS(g_InvCategoryTitle[playerid]);
    INV_VIS(g_InvListTitle[playerid]);
    INV_VIS(g_InvSlots[playerid]);
    INV_VIS(g_InvDetailTitle[playerid]);

    for (new categoryIndex = 0;
        categoryIndex < _:ITEM_CATEGORY_COUNT;
        categoryIndex++)
    {
        new const E_ITEM_CATEGORY:category =
            E_ITEM_CATEGORY:categoryIndex;

        INV_VIS(g_InvCategory[playerid][category]);
        INV_VIS(g_InvCategoryClick[playerid][category]);
    }

    for (new row = 0; row < INVENTORY_UI_ROWS; row++)
    {
        INV_VIS(g_InvRow[playerid][row]);
        INV_VIS(g_InvRowClick[playerid][row]);
    }

    if (show)
    {
        new const selectedSlot = g_InventorySelectedSlot[playerid];

        if (selectedSlot >= 0 &&
            selectedSlot < MAX_INVENTORY_SLOTS &&
            PlayerInventory[playerid][selectedSlot][invExists])
        {
            PlayerTextDrawShow(
                playerid,
                g_InvDetailPreview[playerid]
            );
        }
        else
        {
            PlayerTextDrawHide(
                playerid,
                g_InvDetailPreview[playerid]
            );
        }
    }
    else
    {
        PlayerTextDrawHide(
            playerid,
            g_InvDetailPreview[playerid]
        );
    }
    INV_VIS(g_InvDetailName[playerid]);
    INV_VIS(g_InvDetailDesc[playerid]);
    INV_VIS(g_InvDetailMeta[playerid]);
    INV_VIS(g_InvUse[playerid]);
    INV_VIS(g_InvGive[playerid]);
    INV_VIS(g_InvDrop[playerid]);
    INV_VIS(g_InvExamine[playerid]);
    INV_VIS(g_InvWeight[playerid]);

    for (new handIndex = 0; handIndex < _:WEAPON_HAND_COUNT; handIndex++)
    {
        new const E_WEAPON_HAND:hand = E_WEAPON_HAND:handIndex;
        INV_VIS(g_InvHand[playerid][hand]);
        INV_VIS(g_InvHandClick[playerid][hand]);
    }

    INV_VIS(g_InvPrev[playerid]);
    INV_VIS(g_InvNext[playerid]);

    #undef INV_VIS
    return 1;
}

stock InventoryUI_GetCategoryName(
    E_ITEM_CATEGORY:category,
    destination[],
    size
)
{
    switch (category)
    {
        case ITEM_CATEGORY_ALL:
            format(destination, size, "TAT CA");

        case ITEM_CATEGORY_WEAPONS:
            format(destination, size, "VU KHI");

        case ITEM_CATEGORY_AMMUNITION:
            format(destination, size, "DAN DUOC");

        case ITEM_CATEGORY_FOOD_DRINK:
            format(destination, size, "DO AN & NUOC");

        case ITEM_CATEGORY_MEDICAL:
            format(destination, size, "Y TE");

        case ITEM_CATEGORY_ELECTRONICS:
            format(destination, size, "DIEN TU");

        case ITEM_CATEGORY_DOCS_KEYS:
            format(destination, size, "GIAY TO & CHIA KHOA");

        case ITEM_CATEGORY_OTHER:
            format(destination, size, "KHAC");

        default:
            format(destination, size, "KHAC");
    }
    return 1;
}

stock InventoryUI_RenderCategories(playerid)
{
    for (new categoryIndex = 0;
        categoryIndex < _:ITEM_CATEGORY_COUNT;
        categoryIndex++)
    {
        new const E_ITEM_CATEGORY:category =
            E_ITEM_CATEGORY:categoryIndex;

        new categoryName[32], text[48];

        InventoryUI_GetCategoryName(
            category,
            categoryName,
            sizeof(categoryName)
        );

        format(
            text,
            sizeof(text),
            "%s  %d",
            categoryName,
            Inventory_CountCategory(playerid, category)
        );

        PlayerTextDrawSetString(
            playerid,
            g_InvCategory[playerid][category],
            text
        );

        // The active category is always shown with the red selected box.
        PlayerTextDrawBoxColor(
            playerid,
            g_InvCategory[playerid][category],
            g_InventoryCategory[playerid] == category ?
                INV_UI_SELECTED :
                INV_UI_ROW
        );

        // Box-color changes need a redraw while the inventory is already open.
        if (g_InventoryUIOpen[playerid])
        {
            PlayerTextDrawHide(
                playerid,
                g_InvCategory[playerid][category]
            );

            PlayerTextDrawShow(
                playerid,
                g_InvCategory[playerid][category]
            );
        }
    }

    new selectedCategoryName[32];

    InventoryUI_GetCategoryName(
        g_InventoryCategory[playerid],
        selectedCategoryName,
        sizeof(selectedCategoryName)
    );

    PlayerTextDrawSetString(
        playerid,
        g_InvListTitle[playerid],
        selectedCategoryName
    );
    return 1;
}

stock InventoryUI_RenderRows(playerid)
{
    Inventory_RebuildVisibleSlots(playerid);

    for (new row = 0; row < INVENTORY_UI_ROWS; row++)
    {
        new const slot = g_InventoryVisibleSlot[playerid][row];

        if (slot == INVALID_INVENTORY_SLOT)
        {
            PlayerTextDrawSetString(
                playerid,
                g_InvRow[playerid][row],
                "_"
            );

            PlayerTextDrawBoxColor(
                playerid,
                g_InvRow[playerid][row],
                0x00000000
            );

            if (g_InventoryUIOpen[playerid])
            {
                PlayerTextDrawHide(
                    playerid,
                    g_InvRow[playerid][row]
                );

                PlayerTextDrawHide(
                    playerid,
                    g_InvRowClick[playerid][row]
                );
            }
            continue;
        }

        new const E_ITEM_ID:itemID =
            PlayerInventory[playerid][slot][invItemID];

        new text[96];

        format(
            text,
            sizeof(text),
            "%s  x%d",
            g_ItemData[itemID][itemName],
            PlayerInventory[playerid][slot][invAmount]
        );

        PlayerTextDrawSetString(
            playerid,
            g_InvRow[playerid][row],
            text
        );

        if (g_InventoryUIOpen[playerid])
        {
            PlayerTextDrawShow(
                playerid,
                g_InvRow[playerid][row]
            );

            PlayerTextDrawShow(
                playerid,
                g_InvRowClick[playerid][row]
            );
        }

        PlayerTextDrawBoxColor(
            playerid,
            g_InvRow[playerid][row],
            slot == g_InventorySelectedSlot[playerid] ?
                INV_UI_SELECTED :
                INV_UI_ROW
        );

        if (g_InventoryUIOpen[playerid])
        {
            PlayerTextDrawHide(
                playerid,
                g_InvRow[playerid][row]
            );

            PlayerTextDrawShow(
                playerid,
                g_InvRow[playerid][row]
            );
        }
    }
    return 1;
}

stock InventoryUI_RenderDetails(playerid)
{
    new const slot = g_InventorySelectedSlot[playerid];

    if (slot < 0 || slot >= MAX_INVENTORY_SLOTS ||
        !PlayerInventory[playerid][slot][invExists])
    {
        if (g_InventoryUIOpen[playerid])
        {
            PlayerTextDrawHide(
                playerid,
                g_InvDetailPreview[playerid]
            );
        }

        PlayerTextDrawSetString(playerid, g_InvDetailName[playerid], "CHON VAT PHAM");
        PlayerTextDrawSetString(playerid, g_InvDetailDesc[playerid], "Chon mot vat pham trong danh sach.");
        PlayerTextDrawSetString(playerid, g_InvDetailMeta[playerid], "_");
        PlayerTextDrawSetString(playerid, g_InvUse[playerid], "DUNG");
        return 1;
    }

    new const E_ITEM_ID:itemID = PlayerInventory[playerid][slot][invItemID];

    InventoryUI_SetPreview(
        playerid,
        g_InvDetailPreview[playerid],
        itemID,
        0.85
    );

    if (g_InventoryUIOpen[playerid])
    {
        PlayerTextDrawShow(
            playerid,
            g_InvDetailPreview[playerid]
        );
    }

    PlayerTextDrawSetString(playerid, g_InvDetailName[playerid], g_ItemData[itemID][itemName]);
    PlayerTextDrawSetString(playerid, g_InvDetailDesc[playerid], g_ItemData[itemID][itemDescription]);

    new meta[224];

    switch (g_ItemData[itemID][itemType])
    {
        case ITEM_TYPE_WEAPON:
        {
            new handName[16];
            InventoryWeapon_GetHandName(
                InventoryWeapon_GetHandForSlot(playerid, slot),
                handName,
                sizeof(handName)
            );

            // Melee weapons still have a unique serial, but showing ammo and a
            // 0/0 magazine makes no sense. Firearms keep the full ammo details.
            if (g_ItemData[itemID][itemMagazineSize] <= 0)
            {
                format(
                    meta,
                    sizeof(meta),
                    "SERIAL: WPN-%06d~n~TINH TRANG: %d%%~n~VI TRI: %s",
                    InventoryWeaponData[playerid][slot][iwWeaponSerial],
                    InventoryWeaponData[playerid][slot][iwCondition],
                    handName
                );
            }
            else
            {
                new ammoCode[16];
                Inventory_GetAmmoCode(
                    InventoryWeaponData[playerid][slot][iwAmmoType],
                    ammoCode,
                    sizeof(ammoCode)
                );

                format(
                    meta,
                    sizeof(meta),
                    "MA SUNG: WPN-%06d  |  DAN: %s~n~BANG DAN: %d/%d  |  TINH TRANG: %d%%~n~VI TRI: %s",
                    InventoryWeaponData[playerid][slot][iwWeaponSerial],
                    ammoCode,
                    InventoryWeaponData[playerid][slot][iwLoadedAmmo],
                    g_ItemData[itemID][itemMagazineSize],
                    InventoryWeaponData[playerid][slot][iwCondition],
                    handName
                );
            }

            new const E_WEAPON_HAND:hand =
                InventoryWeapon_GetHandForSlot(playerid, slot);

            if (hand == WEAPON_HAND_NONE)
            {
                PlayerTextDrawSetString(
                    playerid,
                    g_InvUse[playerid],
                    "TRANG BI"
                );
            }
            else if (g_WeaponActiveHand[playerid] == hand)
            {
                PlayerTextDrawSetString(
                    playerid,
                    g_InvUse[playerid],
                    "CAT VU KHI"
                );
            }
            else
            {
                PlayerTextDrawSetString(
                    playerid,
                    g_InvUse[playerid],
                    "CAM TAY"
                );
            }
        }

        case ITEM_TYPE_AMMO:
        {
            format(meta, sizeof(meta),
                "MA DAN: %s  |  SO LUONG: %d~n~TRONG LUONG: %.2f KG",
                g_ItemData[itemID][itemCode],
                PlayerInventory[playerid][slot][invAmount],
                g_ItemData[itemID][itemWeight] *
                    float(PlayerInventory[playerid][slot][invAmount]));

            PlayerTextDrawSetString(playerid, g_InvUse[playerid], "NAP DAN");
        }

        default:
        {
            format(meta, sizeof(meta),
                "TRONG LUONG: %.2f KG  |  SO LUONG: %d~n~XEP CHONG: %d",
                g_ItemData[itemID][itemWeight],
                PlayerInventory[playerid][slot][invAmount],
                g_ItemData[itemID][itemMaxStack]);

            PlayerTextDrawSetString(playerid, g_InvUse[playerid], "DUNG");
        }
    }

    PlayerTextDrawSetString(playerid, g_InvDetailMeta[playerid], meta);
    return 1;
}

// Refresh LEFT/RIGHT boxes from authoritative inventory/weapon data.
stock InventoryUI_RenderHands(playerid)
{
    for (new handIndex = 0; handIndex < _:WEAPON_HAND_COUNT; handIndex++)
    {
        new const E_WEAPON_HAND:hand = E_WEAPON_HAND:handIndex;
        new const slot = g_WeaponHandSlot[playerid][hand];

        new prefix[12];
        if (hand == WEAPON_HAND_LEFT)
        {
            format(prefix, sizeof(prefix), "LEFT HAND");
        }
        else
        {
            format(prefix, sizeof(prefix), "RIGHT HAND");
        }

        new text[80];

        if (!InventoryWeapon_IsValidSlot(playerid, slot))
        {
            format(text, sizeof(text), "%s~n~TRONG", prefix);
        }
        else
        {
            new const E_ITEM_ID:itemID =
                PlayerInventory[playerid][slot][invItemID];

            if (InventoryWeapon_IsFirearmSlot(playerid, slot))
            {
                format(
                    text,
                    sizeof(text),
                    "%s~n~%s %d/%d",
                    prefix,
                    g_ItemData[itemID][itemName],
                    InventoryWeaponData[playerid][slot][iwLoadedAmmo],
                    g_ItemData[itemID][itemMagazineSize]
                );
            }
            else
            {
                format(
                    text,
                    sizeof(text),
                    "%s~n~%s",
                    prefix,
                    g_ItemData[itemID][itemName]
                );
            }
        }

        PlayerTextDrawSetString(
            playerid,
            g_InvHand[playerid][hand],
            text
        );

        PlayerTextDrawBoxColor(
            playerid,
            g_InvHand[playerid][hand],
            g_WeaponActiveHand[playerid] == hand ?
                INV_UI_SELECTED :
                INV_UI_ROW
        );

        if (g_InventoryUIOpen[playerid])
        {
            PlayerTextDrawHide(playerid, g_InvHand[playerid][hand]);
            PlayerTextDrawShow(playerid, g_InvHand[playerid][hand]);
        }
    }

    return 1;
}

stock InventoryUI_Refresh(playerid)
{
    InventoryUI_RenderCategories(playerid);
    InventoryUI_RenderRows(playerid);
    InventoryUI_RenderDetails(playerid);
    InventoryUI_RenderHands(playerid);

    new text[64];
    format(text, sizeof(text), "%d / %d O",
        Inventory_GetUsedSlots(playerid), MAX_INVENTORY_SLOTS);
    PlayerTextDrawSetString(playerid, g_InvSlots[playerid], text);

    format(text, sizeof(text), "TRONG LUONG  %.1f / %.1f KG",
        Inventory_GetWeight(playerid), INVENTORY_MAX_WEIGHT);
    PlayerTextDrawSetString(playerid, g_InvWeight[playerid], text);
    return 1;
}

stock InventoryUI_Open(playerid)
{
    if (!IsPlayerCharacterLoaded(playerid)) return 0;

    // Never expose an empty runtime inventory while the character rows are
    // still loading from MySQL.
    if (!Inventory_IsLoaded(playerid))
    {
        Inventory_LoadCharacter(playerid);
        SendClientMessage(playerid, COLOR_WHITE,
            "Tui do dang duoc tai, hay mo lai sau mot chut.");
        return 0;
    }

    if (!Medical_RequireAction(playerid, MEDICAL_ACTION_INVENTORY))
    {
        return 0;
    }

    InventoryUI_Create(playerid);

    g_InventoryCategory[playerid] = ITEM_CATEGORY_ALL;
    g_InventoryPage[playerid] = 0;
    g_InventorySelectedSlot[playerid] = INVALID_INVENTORY_SLOT;

    InventoryUI_Refresh(playerid);
    InventoryUI_ShowAll(playerid, true);
    g_InventoryUIOpen[playerid] = true;
    SelectTextDraw(playerid, INV_UI_RED);
    return 1;
}

stock InventoryUI_Close(playerid)
{
    if (!g_InventoryUICreated[playerid]) return 0;
    InventoryUI_ShowAll(playerid, false);
    CancelSelectTextDraw(playerid);
    g_InventoryUIOpen[playerid] = false;
    return 1;
}

hook OnPlayerClickPlayerTextDraw(playerid, PlayerText:playertextid)
{
    if (!g_InventoryUIOpen[playerid]) return 1;

    if (playertextid == g_InvClose[playerid])
    {
        InventoryUI_Close(playerid);
        return 1;
    }

    for (new categoryIndex = 0; categoryIndex < _:ITEM_CATEGORY_COUNT; categoryIndex++)
    {
        new const E_ITEM_CATEGORY:category =
            E_ITEM_CATEGORY:categoryIndex;

        if (playertextid == g_InvCategoryClick[playerid][category])
        {
            g_InventoryCategory[playerid] = category;

            g_InventoryPage[playerid] = 0;
            g_InventorySelectedSlot[playerid] = INVALID_INVENTORY_SLOT;

            InventoryUI_Refresh(playerid);
            return 1;
        }
    }

    for (new row = 0; row < INVENTORY_UI_ROWS; row++)
    {
        if (playertextid == g_InvRowClick[playerid][row])
        {
            new const slot = g_InventoryVisibleSlot[playerid][row];
            if (slot != INVALID_INVENTORY_SLOT)
            {
                g_InventorySelectedSlot[playerid] = slot;
                InventoryUI_RenderRows(playerid);
                InventoryUI_RenderDetails(playerid);
            }
            return 1;
        }
    }

    // Clicking an occupied LEFT/RIGHT box unequips that weapon back into
    // the normal inventory list.
    for (new handIndex = 0; handIndex < _:WEAPON_HAND_COUNT; handIndex++)
    {
        new const E_WEAPON_HAND:hand = E_WEAPON_HAND:handIndex;

        if (playertextid == g_InvHandClick[playerid][hand])
        {
            new const slot = g_WeaponHandSlot[playerid][hand];

            if (InventoryWeapon_IsValidSlot(playerid, slot))
            {
                InventoryWeapon_UnequipSlot(playerid, slot);
                g_InventorySelectedSlot[playerid] =
                    INVALID_INVENTORY_SLOT;

                SendClientMessage(
                    playerid,
                    COLOR_WHITE,
                    "Da thao vu khi khoi hand va dua ve tui do."
                );

                InventoryUI_Refresh(playerid);
            }

            return 1;
        }
    }

    if (playertextid == g_InvPrev[playerid])
    {
        if (g_InventoryPage[playerid] > 0)
        {
            g_InventoryPage[playerid]--;
            g_InventorySelectedSlot[playerid] = INVALID_INVENTORY_SLOT;
            InventoryUI_Refresh(playerid);
        }
        return 1;
    }

    if (playertextid == g_InvNext[playerid])
    {
        new const total = Inventory_CountCategory(
            playerid, g_InventoryCategory[playerid]);

        if ((g_InventoryPage[playerid] + 1) * INVENTORY_UI_ROWS < total)
        {
            g_InventoryPage[playerid]++;
            g_InventorySelectedSlot[playerid] = INVALID_INVENTORY_SLOT;
            InventoryUI_Refresh(playerid);
        }
        return 1;
    }

    if (playertextid == g_InvUse[playerid])
    {
        Inventory_UseSelected(playerid);
        InventoryUI_Refresh(playerid);
        return 1;
    }

    if (playertextid == g_InvGive[playerid])
    {
        SendClientMessage(playerid, COLOR_WHITE,
            "Chuc nang dua vat pham se duoc noi backend o phase tiep theo.");
        return 1;
    }

    if (playertextid == g_InvDrop[playerid])
    {
        SendClientMessage(playerid, COLOR_WHITE,
            "Chuc nang tha vat pham chua duoc tich hop; khong tao item tren mat dat.");
        return 1;
    }

    if (playertextid == g_InvExamine[playerid])
    {
        new const slot = g_InventorySelectedSlot[playerid];
        if (slot != INVALID_INVENTORY_SLOT &&
            PlayerInventory[playerid][slot][invExists])
        {
            new const E_ITEM_ID:itemID =
                PlayerInventory[playerid][slot][invItemID];

            new msg[128];
            format(msg, sizeof(msg), "Item: %s | Item ID: %d | Amount: %d",
                g_ItemData[itemID][itemName],
                _:itemID,
                PlayerInventory[playerid][slot][invAmount]);

            SendClientMessage(playerid, COLOR_WHITE, msg);
        }
        return 1;
    }

    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    g_InventoryUICreated[playerid] = false;
    g_InventoryUIOpen[playerid] = false;
    return 1;
}
