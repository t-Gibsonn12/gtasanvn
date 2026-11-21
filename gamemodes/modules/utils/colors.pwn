//-----------------------------------------------------------------------------
// Normal Colors
//-----------------------------------------------------------------------------

#define COLOR_WHITE              (0xFFFFFFFF)
#define COLOR_RED                (0x7A2929FF)
#define COLOR_GRAY               (0xBFC0C2FF)
#define COLOR_DARK_GRAY          (0x858585FF)

// LS:RP client-message palette.
// Base text stays light gray; these colors are reserved for highlighted words.
#define COLOR_LSRP_GREEN_DARK    (0x2E6B4FFF)
#define COLOR_LSRP_RED           (0x7A2929FF)
#define COLOR_LSRP_BLUE_LIGHT    (0x6C9BC3FF)
#define COLOR_LSRP_BLUE_DARK     (0x264A73FF)
#define COLOR_LSRP_GOLD          (0xC89B3CFF)

// Backward-compatible color name used by older modules.
#define COLOR_LSRP_BLUE          COLOR_LSRP_BLUE_DARK

//-----------------------------------------------------------------------------
// Roleplay chat colors
//-----------------------------------------------------------------------------

#define COLOR_RP_CHAT (0xFFFFFFFF)
#define COLOR_RP_ME   (0xC2A2DAFF)
#define COLOR_RP_DO   (0xD7A86EFF)
#define COLOR_RP_OOC  (0xB0B0B0FF)
#define COLOR_RP_SHOUT (0xFFE08AFF)
#define COLOR_RP_TRY  (0xC2A2DAFF)

//-----------------------------------------------------------------------------
// Embedded Colors
//-----------------------------------------------------------------------------

#define EMBED_WHITE                  "{FFFFFF}"
#define EMBED_RED                    "{7A2929}"
#define EMBED_LSRP_WHITE             "{FFFFFF}"

// Default body color for normal SendClientMessage output.
#define EMBED_LSRP_GRAY              "{BFC0C2}"
#define EMBED_LSRP_DARKGRAY          "{858585}"

// Approved highlight palette for normal LS:RP client messages.
#define EMBED_LSRP_GREEN_DARK        "{2E6B4F}"
#define EMBED_LSRP_RED               "{7A2929}"
#define EMBED_LSRP_BLUE_LIGHT        "{6C9BC3}"
#define EMBED_LSRP_BLUE_DARK         "{264A73}"
#define EMBED_LSRP_GOLD              "{C89B3C}"

// Backward-compatible aliases for existing modules.
#define EMBED_LSRP_BLUE              EMBED_LSRP_BLUE_DARK
#define EMBED_RP_LIGHT_GRAY          EMBED_LSRP_GRAY
#define EMBED_RP_DARK_RED            EMBED_LSRP_RED
#define EMBED_RP_DARK_BLUE           EMBED_LSRP_BLUE_DARK
