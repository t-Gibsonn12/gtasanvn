//-----------------------------------------------------------------------------
// LS:RP Inventory - Data
// 50 item definitions + weapon/ammo instance metadata.
//-----------------------------------------------------------------------------

#define MAX_INVENTORY_SLOTS        (50)
#define INVENTORY_UI_ROWS          (8)
#define INVENTORY_MAX_WEIGHT       (25.0)
#define INVALID_INVENTORY_SLOT     (-1)

// Persistence/save cadence. Inventory changes are marked dirty and flushed
// periodically plus once more on disconnect.
#define INVENTORY_AUTOSAVE_MS       (30000)

// Dialog used when a weapon is first assigned to LEFT/RIGHT HAND.
#define DIALOG_INVENTORY_WEAPON_HAND (19991)

enum E_ITEM_TYPE
{
    ITEM_TYPE_NORMAL = 0,
    ITEM_TYPE_WEAPON,
    ITEM_TYPE_AMMO
};

enum E_ITEM_CATEGORY
{
    ITEM_CATEGORY_ALL = 0,
    ITEM_CATEGORY_WEAPONS,
    ITEM_CATEGORY_AMMUNITION,
    ITEM_CATEGORY_FOOD_DRINK,
    ITEM_CATEGORY_MEDICAL,
    ITEM_CATEGORY_ELECTRONICS,
    ITEM_CATEGORY_DOCS_KEYS,
    ITEM_CATEGORY_OTHER,
    ITEM_CATEGORY_COUNT
};

enum E_AMMO_TYPE
{
    AMMO_NONE = 0,
    AMMO_9MM,
    AMMO_45ACP,
    AMMO_50AE,
    AMMO_12GA,
    AMMO_556,
    AMMO_762,
    AMMO_RIFLE,
    AMMO_SNIPER
};

// LEFT/RIGHT are server loadout positions. Only one hand is active in GTA at
// any moment; the other remains holstered but keeps its own serial/ammo data.
enum E_WEAPON_HAND
{
    WEAPON_HAND_NONE = -1,
    WEAPON_HAND_LEFT = 0,
    WEAPON_HAND_RIGHT,
    WEAPON_HAND_COUNT
};

enum E_ITEM_ID
{
    ITEM_NONE,
    ITEM_WATER_BOTTLE,
    ITEM_SANDWICH,
    ITEM_BURGER,
    ITEM_SODA,
    ITEM_COFFEE,
    ITEM_DONUT,
    ITEM_PIZZA_SLICE,
    ITEM_CIGARETTE,
    ITEM_LIGHTER,
    ITEM_BANDAGE,
    ITEM_FIRST_AID_KIT,
    ITEM_PAINKILLERS,
    ITEM_MEDICAL_PACK,
    ITEM_PHONE,
    ITEM_RADIO,
    ITEM_FLASHLIGHT,
    ITEM_CAMERA,
    ITEM_NOTEBOOK,
    ITEM_PEN,
    ITEM_ID_CARD,
    ITEM_DRIVER_LICENSE,
    ITEM_VEHICLE_KEY,
    ITEM_HOUSE_KEY,
    ITEM_ROPE,
    ITEM_TOOLKIT,
    ITEM_REPAIR_KIT,
    ITEM_FUEL_CAN,
    ITEM_LOCKPICK,
    ITEM_MATERIALS,
    ITEM_PACKAGE,
    ITEM_DICE,
    ITEM_BASEBALL_BAT,
    ITEM_KNIFE,
    ITEM_GLOCK_17,
    ITEM_COLT_M1911,
    ITEM_DESERT_EAGLE,
    ITEM_SHOTGUN,
    ITEM_MP5,
    ITEM_AK47,
    ITEM_M4,
    ITEM_RIFLE,
    ITEM_SNIPER_RIFLE,
    ITEM_AMMO_9MM,
    ITEM_AMMO_45ACP,
    ITEM_AMMO_50AE,
    ITEM_AMMO_12GA,
    ITEM_AMMO_556,
    ITEM_AMMO_762,
    ITEM_AMMO_RIFLE,
    ITEM_AMMO_SNIPER,
    ITEM_COUNT
};

// Implemented by the tutorial module; declared here because inventory USE is
// compiled before tutorial is included in main.pwn.
forward bool:Tutorial_TryUseIDCard(playerid, E_ITEM_ID:itemID);
forward bool:Phone_TryUseItem(playerid, E_ITEM_ID:itemID);

enum E_ITEM_DEFINITION
{
    itemName[32],
    itemDescription[72],
    E_ITEM_TYPE:itemType,
    E_ITEM_CATEGORY:itemCategory,
    Float:itemWeight,
    itemMaxStack,
    bool:itemUsable,
    WEAPON:itemWeaponID,
    E_AMMO_TYPE:itemAmmoType,
    itemMagazineSize,
    itemCode[16]
};

new const g_ItemData[ITEM_COUNT][E_ITEM_DEFINITION] =
{
    {"None", "", ITEM_TYPE_NORMAL, ITEM_CATEGORY_OTHER, 0.00, 1, false, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Water Bottle", "A bottle of fresh drinking water.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_FOOD_DRINK, 0.500, 10, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Sandwich", "A simple prepared sandwich.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_FOOD_DRINK, 0.350, 5, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Burger", "A wrapped fast-food burger.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_FOOD_DRINK, 0.400, 5, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Soda", "A cold can of soda.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_FOOD_DRINK, 0.330, 10, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Coffee", "A cup of hot coffee.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_FOOD_DRINK, 0.300, 5, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Donut", "A glazed donut.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_FOOD_DRINK, 0.150, 10, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Pizza Slice", "A single slice of pizza.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_FOOD_DRINK, 0.250, 8, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Cigarette", "A single cigarette.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_OTHER, 0.020, 20, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Lighter", "A small pocket lighter.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_OTHER, 0.080, 1, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Bandage", "Basic supplies used for minor wounds.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_MEDICAL, 0.100, 5, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"First Aid Kit", "A compact first aid kit.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_MEDICAL, 1.200, 2, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Painkillers", "A small packet of pain relief medication.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_MEDICAL, 0.100, 5, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Medical Pack", "A larger package of emergency medical supplies.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_MEDICAL, 2.200, 1, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Phone", "A mobile telephone.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_ELECTRONICS, 0.300, 1, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Portable Radio", "A handheld portable radio.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_ELECTRONICS, 0.600, 1, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Flashlight", "A compact battery-powered flashlight.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_ELECTRONICS, 0.450, 1, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Camera", "A portable camera.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_ELECTRONICS, 0.800, 1, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Notebook", "A small paper notebook.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_DOCS_KEYS, 0.200, 3, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Pen", "A standard ballpoint pen.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_DOCS_KEYS, 0.030, 5, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"ID Card", "A government-issued identification card.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_DOCS_KEYS, 0.020, 1, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Driver License", "A state-issued driver license.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_DOCS_KEYS, 0.020, 1, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Vehicle Key", "A key assigned to a vehicle.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_DOCS_KEYS, 0.050, 1, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"House Key", "A key assigned to a property.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_DOCS_KEYS, 0.050, 1, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Rope", "A length of utility rope.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_OTHER, 1.000, 2, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Toolkit", "A compact toolkit.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_OTHER, 3.000, 1, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Repair Kit", "Supplies used for basic vehicle repairs.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_OTHER, 4.000, 1, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Fuel Can", "A portable fuel container.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_OTHER, 5.000, 1, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Lockpick", "A small lock manipulation tool.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_OTHER, 0.100, 5, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Materials", "A bundle of general-purpose materials.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_OTHER, 0.100, 100, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Package", "A sealed generic package.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_OTHER, 1.000, 5, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Dice", "A pair of small dice.", ITEM_TYPE_NORMAL, ITEM_CATEGORY_OTHER, 0.050, 1, true, WEAPON_FIST, AMMO_NONE, 0, ""},
    {"Baseball Bat", "A wooden baseball bat.", ITEM_TYPE_WEAPON, ITEM_CATEGORY_WEAPONS, 1.200, 1, true, WEAPON_BAT, AMMO_NONE, 0, ""},
    {"Knife", "A fixed-blade knife.", ITEM_TYPE_WEAPON, ITEM_CATEGORY_WEAPONS, 0.450, 1, true, WEAPON_KNIFE, AMMO_NONE, 0, ""},
    {"Glock 17", "A compact 9mm semi-automatic pistol.", ITEM_TYPE_WEAPON, ITEM_CATEGORY_WEAPONS, 0.900, 1, true, WEAPON_COLT45, AMMO_9MM, 17, ""},
    {"Colt M1911", "A .45 ACP semi-automatic pistol.", ITEM_TYPE_WEAPON, ITEM_CATEGORY_WEAPONS, 1.100, 1, true, WEAPON_SILENCED, AMMO_45ACP, 7, ""},
    {"Desert Eagle", "A large-frame .50 AE pistol.", ITEM_TYPE_WEAPON, ITEM_CATEGORY_WEAPONS, 1.800, 1, true, WEAPON_DEAGLE, AMMO_50AE, 7, ""},
    {"Shotgun", "A pump-action 12 gauge shotgun.", ITEM_TYPE_WEAPON, ITEM_CATEGORY_WEAPONS, 3.500, 1, true, WEAPON_SHOTGUN, AMMO_12GA, 8, ""},
    {"MP5", "A compact 9mm submachine gun.", ITEM_TYPE_WEAPON, ITEM_CATEGORY_WEAPONS, 2.600, 1, true, WEAPON_MP5, AMMO_9MM, 30, ""},
    {"AK-47", "A 7.62mm select-fire rifle.", ITEM_TYPE_WEAPON, ITEM_CATEGORY_WEAPONS, 4.300, 1, true, WEAPON_AK47, AMMO_762, 30, ""},
    {"M4 Carbine", "A 5.56mm carbine.", ITEM_TYPE_WEAPON, ITEM_CATEGORY_WEAPONS, 3.200, 1, true, WEAPON_M4, AMMO_556, 30, ""},
    {"Rifle", "A civilian shoulder-fired rifle.", ITEM_TYPE_WEAPON, ITEM_CATEGORY_WEAPONS, 3.400, 1, true, WEAPON_RIFLE, AMMO_RIFLE, 5, ""},
    {"Sniper Rifle", "A scoped precision rifle.", ITEM_TYPE_WEAPON, ITEM_CATEGORY_WEAPONS, 5.000, 1, true, WEAPON_SNIPER, AMMO_SNIPER, 5, ""},
    {"9mm Ammunition", "9mm cartridges for compatible firearms.", ITEM_TYPE_AMMO, ITEM_CATEGORY_AMMUNITION, 0.012, 100, true, WEAPON_FIST, AMMO_9MM, 0, "AMMO-9MM"},
    {".45 ACP Ammunition", ".45 ACP cartridges for compatible firearms.", ITEM_TYPE_AMMO, ITEM_CATEGORY_AMMUNITION, 0.015, 100, true, WEAPON_FIST, AMMO_45ACP, 0, "AMMO-45ACP"},
    {".50 AE Ammunition", ".50 AE cartridges for compatible firearms.", ITEM_TYPE_AMMO, ITEM_CATEGORY_AMMUNITION, 0.020, 50, true, WEAPON_FIST, AMMO_50AE, 0, "AMMO-50AE"},
    {"12 Gauge Shells", "12 gauge shells for compatible shotguns.", ITEM_TYPE_AMMO, ITEM_CATEGORY_AMMUNITION, 0.040, 30, true, WEAPON_FIST, AMMO_12GA, 0, "AMMO-12GA"},
    {"5.56mm Ammunition", "5.56mm cartridges for compatible rifles.", ITEM_TYPE_AMMO, ITEM_CATEGORY_AMMUNITION, 0.013, 120, true, WEAPON_FIST, AMMO_556, 0, "AMMO-556"},
    {"7.62mm Ammunition", "7.62mm cartridges for compatible rifles.", ITEM_TYPE_AMMO, ITEM_CATEGORY_AMMUNITION, 0.018, 100, true, WEAPON_FIST, AMMO_762, 0, "AMMO-762"},
    {"Rifle Ammunition", "Cartridges for civilian rifles.", ITEM_TYPE_AMMO, ITEM_CATEGORY_AMMUNITION, 0.020, 50, true, WEAPON_FIST, AMMO_RIFLE, 0, "AMMO-RIFLE"},
    {"Sniper Ammunition", "Precision cartridges for sniper rifles.", ITEM_TYPE_AMMO, ITEM_CATEGORY_AMMUNITION, 0.025, 30, true, WEAPON_FIST, AMMO_SNIPER, 0, "AMMO-SNIPER"}
};

enum E_PLAYER_INVENTORY_DATA
{
    bool:invExists,
    invDatabaseID,
    E_ITEM_ID:invItemID,
    invAmount
};

new PlayerInventory[MAX_PLAYERS][MAX_INVENTORY_SLOTS][E_PLAYER_INVENTORY_DATA];

enum E_INVENTORY_WEAPON_DATA
{
    bool:iwExists,
    iwWeaponSerial,
    WEAPON:iwWeaponID,
    E_AMMO_TYPE:iwAmmoType,
    iwLoadedAmmo,
    iwCondition
};

new InventoryWeaponData[MAX_PLAYERS][MAX_INVENTORY_SLOTS][E_INVENTORY_WEAPON_DATA];

// Serial counter is seeded from MAX(weapon_serial) in MySQL on gamemode init.
// This keeps WPN-100001 style serials stable across server restarts.
new g_InventoryNextWeaponSerial = 100001;
new bool:g_InventorySerialReady;

// Per-character persistence state. Save code ignores players until a character
// inventory has completed loading, preventing an empty runtime reset from
// overwriting real database rows.
new bool:g_InventoryLoaded[MAX_PLAYERS];
new bool:g_InventoryLoading[MAX_PLAYERS];
new bool:g_InventoryDirty[MAX_PLAYERS];
new g_InventoryCharacterID[MAX_PLAYERS];

// LEFT/RIGHT weapon loadout. Values are inventory slot indexes, not copies of
// weapon data, so serial/ammo/condition always have one authoritative source.
new g_WeaponHandSlot[MAX_PLAYERS][WEAPON_HAND_COUNT];
new E_WEAPON_HAND:g_WeaponActiveHand[MAX_PLAYERS];
new g_InventoryPendingWeaponSlot[MAX_PLAYERS];

new
    bool:g_InventoryUIOpen[MAX_PLAYERS],
    bool:g_InventoryUICreated[MAX_PLAYERS],
    g_InventoryPage[MAX_PLAYERS],
    E_ITEM_CATEGORY:g_InventoryCategory[MAX_PLAYERS],
    g_InventorySelectedSlot[MAX_PLAYERS],
    g_InventoryVisibleCount[MAX_PLAYERS];

new g_InventoryVisibleSlot[MAX_PLAYERS][INVENTORY_UI_ROWS];

new const g_InventoryCategoryName[ITEM_CATEGORY_COUNT][] =
{
    "ALL ITEMS",
    "WEAPONS",
    "AMMUNITION",
    "FOOD & DRINK",
    "MEDICAL",
    "ELECTRONICS",
    "DOCS & KEYS",
    "OTHER"
};
