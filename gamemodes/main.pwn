/*===============================================================================
    Project        : A simple open.mp base gamemode
    Author         : Mido
    Date           : June 11, 2025
    Target Server  : open multiplayer (open.mp)

    Description    :
    --------------------------------------------------------------------
    This is a simple yet useful base for an open.mp gamemode.  Its purpose
    is to assist new scripters, whether they're just getting started or
    returning to the SA:MP scene after a break.

    For additional details, refer to the README.md file.

    Dependencies   :
    --------------------------------------------------------------------
    - open.mp server (latest version)
    - Plugin: MySQL by maddinat0r and blueG (R41-4)
    - Plugin: BCrypt by Sreyas-Sreelal (0.4.1)
    - Library: YSI by Y_Less (v5.10.0006)

    Thanks to      :
    --------------------------------------------------------------------
    - SA:MP and open.mp Teams past, present and future.
    - Mido - Writing this gamemode.
    - Kevin - Highly constructive suggestions and insights.
    - itsneufox - Testing the script.

    Repository     :
    --------------------------------------------------------------------
    - GitHub: https://github.com/midosvt/omp-base-script

===============================================================================*/

//-----------------------------------------------------------------------------
// Predefinitions
//-----------------------------------------------------------------------------

// Redefine `MAX_PLAYERS` to match our player slot.  This value must align with
// the `max_players` setting in the `config.json` file to prevent any issues.
#define MAX_PLAYERS (50)

// Several dialog/report callbacks build detailed Company and vehicle text.
// The Pawn default is only 4096 cells (16 KB), which is below the compiler's
// measured call-stack requirement and causes every unrelated timer to fail
// once stack/heap collide. Reserve 32768 cells (128 KB) for safe runtime use.
#pragma dynamic 32768

// Allows both American and British English spellings.  It is required to
// preserve compatibility with how it was in SA:MP.
#define MIXED_SPELLINGS

//-----------------------------------------------------------------------------
// Script Dependencies
//-----------------------------------------------------------------------------

// Core
#include <open.mp>

// Plugins
#include <a_mysql>
#if defined GTASANVN_CEF_PHONE
    #include <cef>
#endif
#include <samp_bcrypt>

// YSI
#include <YSI_Coding\y_hooks>
#include <zcmd>

// Dealer must restore the real-world position before character disconnect save.
forward Dealership_RestoreForDisconnect(playerid);
// Tutorial starts only once the character cinematic has returned control.
forward Tutorial_OnCharacterReady(playerid);
forward Tutorial_LoadForCharacter(playerid);
forward Phone_LoadForCharacter(playerid);
forward Company_LoadForCharacter(playerid);
forward bool:Company_IsPlayerInDealerBranch(playerid);
forward Company_RecordDealerSale(playerid, grossAmount, modelid);
forward Company_GetDealerDelivery(playerid, &Float:x, &Float:y, &Float:z, &Float:a);
forward Trucking_CreateRetailOrder(playerid, itemid, amount, salePrice, supplierCost);
forward Trucking_CreateVehicleOrder(playerid, vehicleIndex, amount, supplierCost);
forward bool:Trucking_CanStoreCompanyVehicle(playerid, slot);
forward Trucking_AttachCompanyVehicleLabel(playerid, slot, vehicleid);
forward Trucking_RemoveCompanyVehicleLabel(vehicleid);
forward Trucking_ShowEmployeeCompanyMenu(playerid);
forward Company_RecordEmployeeWork(playerid, companyid, contractid, baseReward, const workType[], const routeFrom[], const routeTo[]);
forward LSBank_RecordRevenue(const source[], amount, actorCharacterID);
forward LSBank_ShowCompanyFinance(playerid);
forward Trucking_ApproveCompanyApplicant(playerid);
forward RealEstate_ShowOfficeChoice(playerid);
forward RealEstate_FinalizeCompanyOffice(playerid, companyid);
forward Trucking_ShowEmployeeCompanyMenu(playerid);

//-----------------------------------------------------------------------------
// Script Modules
//-----------------------------------------------------------------------------

// Definitions and Utilities
#include "modules/utils/colors.pwn"
#include "modules/utils/dialogs.pwn"
#include "modules/utils/shownotifytext.pwn"
#include "modules/utils/progress.pwn"

// Server
#include "modules/core/server/database.pwn"
#include "modules/core/server/settings.pwn"

// Player Account + Characters
#include "modules/core/player/account/utils.pwn"

#include "modules/core/player/character/utils.pwn"

// Server-authoritative health must load before systems that consume character health.
#include "modules/core/player/health.pwn"
#include "modules/system/medical/core.pwn"
#include "modules/system/medical/commands.pwn"
#include "modules/system/admin/data.pwn"
#include "modules/core/player/chat.pwn"
#include "modules/core/player/character/cinematic.pwn"
#include "modules/core/player/character/creator.pwn"
#include "modules/core/player/stats.pwn"
#include "modules/core/player/character/selector.pwn"
#include "modules/core/player/character/core.pwn"

#include "modules/core/player/account/core.pwn"


#include "modules/system/job/data.pwn"
#include "modules/system/job/persistence.pwn"
#include "modules/system/job/core.pwn"

#include "modules/system/job/pizza/data.pwn"
#include "modules/system/job/pizza/vehicle.pwn"
#include "modules/system/job/pizza/ui.pwn"
#include "modules/system/job/pizza/core.pwn"
#include "modules/system/job/pizza/commands.pwn"



#include "modules/system/job/commands.pwn"
#include "modules/system/admin/admin_patch.pwn"
#include "modules/system/admin/persistence.pwn"
#include "modules/system/admin/commands.pwn"

// Player inventory.
#include "modules/system/inventory/data.pwn"
#include "modules/system/inventory/core.pwn"
#include "modules/system/needs/core.pwn"
#include "modules/system/inventory/weapon.pwn"
#include "modules/system/inventory/persistence.pwn"
#include "modules/system/inventory/ui.pwn"
#include "modules/system/inventory/commands.pwn"
#include "modules/system/help/commands.pwn"
#include "modules/system/economy/core.pwn"
#include "modules/system/phone/core.pwn"

// Character-owned vehicles.
//
// The previous vehicle implementation is kept in
// modules/system/vehicles/ as a legacy reference, but is not included here.
// Start with the small load/list flow and add features one at a time.
#include "modules/system/vehicles/simple.pwn"
#if defined GTASANVN_CEF_PHONE
    #include "modules/system/phone/cef.pwn"
#endif
#include "modules/system/vehicles/controls.pwn"
#include "modules/system/vehicles/dealership.pwn"
#include "modules/system/tutorial/core.pwn"
#include "modules/system/interaction/core.pwn"
#include "modules/system/company/dynamic.pwn"
#include "modules/system/company/ls_bank.pwn"
#include "modules/system/company/real_estate.pwn"
#include "modules/system/company/house.pwn"
#include "modules/system/trucking/core.pwn"
#include "modules/system/vehicles/service_stations.pwn"

#if defined GTASANVN_CEF_PHONE
    #include "modules/system/menu/cef.pwn"
#endif

// This fallback must remain after every command module.
#include "modules/system/help/unknown.pwn"

