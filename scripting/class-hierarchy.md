# DayZ Class Hierarchy

## Core Entity Chain
Verified against DayZ 1.29 scripts (`Pawn`/`Person` are in the chain because retail defines
`FEATURE_NETWORK_RECONCILIATION`).
```
Managed
└── IEntity
    └── Object
        └── ObjectTyped
            └── Entity
                └── EntityAI
                    ├── DayZCreature
                    │   └── DayZCreatureAI
                    │       ├── DayZAnimal -> AnimalBase (Animal_BosTaurus, Animal_CanisLupus, ...)
                    │       └── DayZInfected -> ZombieBase (ZmbM_*, ZmbF_*)
                    ├── Pawn
                    │   ├── Person
                    │   │   └── Man
                    │   │       └── Human
                    │   │           └── DayZPlayer
                    │   │               └── DayZPlayerImplement
                    │   │                   └── ManBase
                    │   │                       └── PlayerBase
                    │   │                           └── PlayerBaseClient
                    │   │                               └── SurvivorBase (SurvivorM_*, SurvivorF_*)
                    │   └── Transport
                    │       ├── Car
                    │       │   └── CarScript (OffroadHatchback, CivilianSedan, Hatchback_02, ...)
                    │       └── Boat -> BoatScript
                    ├── InventoryItem
                    │   └── ItemBase (typedef Inventory_Base, InventoryItemSuper)
                    │       ├── Edible_Base (food, drinks)
                    │       ├── Clothing_Base (all wearables)
                    │       ├── Container_Base (storage containers)
                    │       ├── BaseBuildingBase
                    │       │   └── Fence, Watchtower, ...
                    │       └── Weapon
                    │           └── Weapon_Base
                    │               ├── Rifle_Base
                    │               └── Pistol_Base
                    └── Building
                        └── BuildingBase
                            └── House (typedef BuildingSuper)
                                └── BuildingWithFireplace
```

### Per-class type objects (1.29)
Every config class has a shared `EntityType` instance (`Object.GetEntityType()`), e.g.
`EntityType -> EntityAIType -> InventoryItemType -> ItemBaseType -> WeaponType / ClothingType / ...`,
plus `ManType`, `TransportType`, `BuildingType`, `DayZCreatureType`. See `compatibility/version-129.md`.

## Key IEntity Methods (20+)
```c
vector GetPosition();
void SetPosition(vector pos);
vector GetOrientation();        // yaw, pitch, roll
void SetOrientation(vector ori);
vector GetDirection();          // forward direction
vector GetSpeed();              // velocity
void GetTransform(out vector mat[4]);
void SetTransform(vector mat[4]);
bool IsMan();
bool IsBuilding();
bool IsItemBase();
bool IsTransport();
bool IsAnimal();
bool IsZombie();
```

## Key EntityAI Methods
```c
GameInventory GetInventory();
void SetHealth(string zone, string system, float value);
float GetHealth(string zone, string system);
float GetHealth01(string zone, string system);  // 0-1 range
void ProcessDirectDamage(int damageType, EntityAI source, string component, string ammo, vector modelPos, float damageCoef);
void SetLifetime(float seconds);
float GetLifetimeMax();
bool IsAlive();
bool IsDamageDestroyed();
bool IsRuined();
void AddAction(typename actionType, out TInputActionMap map);
void RemoveAction(typename actionType);
void Delete();
```

## Key PlayerBase Methods
```c
// Identity & State
PlayerIdentity GetIdentity();
string GetIdentity().GetId();       // Steam64 ID
string GetIdentity().GetName();     // Player name
bool IsAlive();
bool IsUnconscious();

// Inventory
ItemBase GetItemInHands();           // PlayerBase helper
EntityAI GetEntityInHands();         // native on Man (1.29+)
GameInventory GetInventory();
EntityAI GetInventory().CreateInInventory(string className);
void PredictiveTakeEntityToHands(EntityAI item);

// Position & Movement
vector GetPosition();
void SetPosition(vector pos);
float GetDirection();
bool IsInVehicle();
Transport GetCommand_Vehicle().GetTransport();

// Stats & State
void SetHealth(string zone, string system, float val);
float GetStatWater().Get();
float GetStatEnergy().Get();
float GetStatHeatComfort().Get();
int GetBrokenLegs();

// Context
bool IsControlledPlayer();
bool HasItem(EntityAI item);
```

## Action System Hierarchy
```
ActionBase
├── ActionSingleUseBase (one-time actions)
│   └── ActionSingleUseBase subtypes
├── ActionContinuousBase (hold actions)
│   └── ActionContinuousBase subtypes
├── ActionInteractBase (interact key)
│   └── ActionInteractBase subtypes
└── FirearmActionBase (weapon actions)
    └── FirearmActionBase subtypes
```

### Key Action Methods
```c
class MyAction extends ActionInteractBase
{
    override void CreateConditionComponents()
    {
        m_ConditionItem = new CCINone();
        m_ConditionTarget = new CCTObject(UAMaxDistances.DEFAULT);
    }

    override string GetText() { return "My Action"; }

    override bool ActionCondition(PlayerBase player, ActionTarget target, ItemBase item)
    {
        return true; // when action is available
    }

    override void OnExecuteServer(ActionData action_data)
    {
        // server-side logic
    }

    override void OnExecuteClient(ActionData action_data)
    {
        // client-side logic
    }
}
```

## GameInventory System
```c
// InventoryLocation types
enum InventoryLocationType
{
    UNKNOWN,        // freshly created object
    GROUND,         // on the ground
    ATTACHMENT,     // attached to parent
    CARGO,          // in cargo of parent
    HANDS,          // in player hands
    PROXYCARGO,     // cargo of a large object (building, ...)
    VEHICLE,        // player in vehicle (seat index stored)
    TEMP            // 1.29+: client-side limbo during inventory desync
}

// Key GameInventory methods
EntityAI CreateInInventory(string type);
bool CanAddEntityInCargo(EntityAI e, bool flip);
bool CanAddAttachment(EntityAI item);
EntityAI CreateEntityInCargo(string type);
EntityAI CreateAttachment(string type);
bool TakeEntityToCargo(InventoryMode mode, EntityAI item);
bool TakeEntityToInventory(InventoryMode mode, FindInventoryLocationType flags, EntityAI item);
bool FindFreeLocationFor(EntityAI item, FindInventoryLocationType flags, out InventoryLocation loc);
int CountInventory();                // number of items in this inventory
```

## Key Singletons
```c
// Game
DayZGame g_Game             // preferred; GetGame() is a wrapper returning it (1.29)
DayZGame GetDayZGame()

// Player (client only)
Man GetPlayer()             // local player
PlayerBase.Cast(GetGame().GetPlayer())  // typed local player

// World
World GetGame().GetWorld()

// Mission
MissionBase GetGame().GetMission()

// Weather
Weather GetGame().GetWeather()

// CF (requires Community Framework)
RPCManager GetRPCManager()
```

## Widget/UI System
```c
// Creating UI
Widget root = GetGame().GetWorkspace().CreateWidgets("path/layout.layout");
TextWidget text = TextWidget.Cast(root.FindAnyWidget("TextName"));
text.SetText("Hello");

// Event handling
class MyHandler extends ScriptedWidgetEventHandler
{
    override bool OnClick(Widget w, int x, int y, int button)
    {
        if (w.GetName() == "MyButton")
        {
            // handle click
            return true;
        }
        return false;
    }
}
```

## Effect System
```c
// Sound
SEffectManager.PlaySound("MySoundSet", position);
SEffectManager.PlaySoundOnObject("MySoundSet", object);

// Particles
Particle.PlayInWorld(ParticleList.PARTICLE_ID, position);
Particle.PlayOnObject(ParticleList.PARTICLE_ID, object);
```

## Weather System
```c
Weather weather = GetGame().GetWeather();
weather.GetOvercast().Set(0.8, 300, 600);    // value, time, duration
weather.GetRain().Set(0.5, 60, 120);
weather.GetFog().Set(0.3, 120, 240);
weather.GetWindSpeed().Set(15.0, 60, 120);
weather.GetWindDirection().Set(2.5, 60, 120);
weather.SetStorm(1.0, 0.8, 30);             // density, threshold, timeout
```
