# DayZ 1.29 Compatibility Guide

> **Released:** April 8, 2026 (PC Stable 1.29.162510)
> **Latest build covered:** 1.29.163709 ("Road to Badlands Update 2", Aug 12, 2026, Scripts Rev. 125372)
> **Source of truth:** DayZ-Script-Diff commits `51146416` (1.28.161464) → `86974a0f` (1.29.163709),
> plus the official PC changelogs as collected at https://diff.yadz.app/release-notes/

Diff 1.28 → 1.29: 934 files changed, ~18k insertions, ~9k deletions. Most of the churn is the vanilla
`GetGame()` → `g_Game` migration and UI work; the changes below are the ones that affect mods.
To compare any two builds interactively use https://diff.yadz.app/changelog/.

## CRITICAL / Likely to Break Mods

### 1. `GetGame()` is now a script wrapper returning `DayZGame`
```c
// 1.28 (3_Game/gameplay.c)
proto native CGame GetGame();

// 1.29 (3_Game/gameplay.c)
DayZGame GetGame() { return g_Game; }
```
- Existing `GetGame().X()` calls still compile and work.
- The return type is now `DayZGame`, so `GetGame().SomeDayZGameMethod()` no longer needs `GetDayZGame()`.
- It is an extra script call - BI replaced ~4,600 vanilla `GetGame()` calls with the `g_Game` global
  (official note: "Prioritized usage of variables such as g_Game instead of function calls such as GetGame()").
- **Recommendation:** use `g_Game` in new code everywhere, not only in hot paths. `g_Game` is declared as
  `DayZGame g_Game;` in `3_Game/dayzgame.c`, so it is available from 3_Game upward.

### 2. `ActiveState` enum reordered
Physics bindings moved from `1_Core/proto/enphysics.c` into the new `1_Core/physics/` folder, and the enum
order changed:
```c
// 1.28                      // 1.29
enum ActiveState             enum ActiveState
{                            {
    ACTIVE,        // 0          INACTIVE,      // 0 - body sleeps
    INACTIVE,      // 1          ACTIVE,        // 1 - simulated
    ALWAYS_ACTIVE  // 2          ALWAYS_ACTIVE, // 2 - simulated, cannot sleep
};                           }
```
Always use the named values. Any mod that stored, compared or sent `ActiveState` as a raw `int` must be fixed.

### 3. Vehicle headlights moved to native (`Transport`)
`CarScript.m_HeadlightsOn` (and its `RegisterNetSyncVariableBool("m_HeadlightsOn")`) is **gone**.
`m_HeadlightsState` and `m_RearLightType` changed from `bool` to `int`.

New on `Transport` (so available to cars and boats):
```c
proto native bool LightIsOn();
proto native void LightOn();
proto native void LightOff();
proto native void LightToggle();
bool OnBeforeLightOn();          // native asks script whether the light may turn on (default: true)
void OnUpdateLight();            // native tick, calls UpdateLights()
void UpdateLights(int new_gear = -1);
```
`CarScript.ToggleHeadlights()` now calls `LightToggle()`; `IsScriptedLightsOn()` returns `LightIsOn()`;
`CarScript.OnBeforeLightOn()` requires a non-ruined battery with energy.

```c
// BEFORE (1.28) - modded car forcing lights on
m_HeadlightsOn = true;
SetSynchDirty();

// AFTER (1.29)
LightOn();

// Custom light requirement (e.g. no lights without a working alternator)
modded class CarScript
{
    override bool OnBeforeLightOn()
    {
        if (!super.OnBeforeLightOn())
            return false;
        return MyMod_HasAlternator();
    }
}
```

### 4. Inactive physics bodies no longer tick `EOnSimulate` / `EOnPostSimulate`
If a mod relied on those events while the body sleeps, keep the body awake
(`GetPhysics().SetActive(ActiveState.ALWAYS_ACTIVE)` / `dBodyActive`) or move the logic elsewhere.
For custom `Transport` vehicles use the new `EntityAI.SetRequiredSimulation(bool)` / `IsRequiredSimulation()`.

### 5. Terrain Builder: WRP needs the 1.29 binarization
Terrain mods must be re-binarized with the 1.29 tools. Objects with a persistent ID are now saved into the WRP
instead of being regenerated each build.

## Important Changes (Should Review)

### 6. Juncture user data
`CGame.AddActionJuncture`, `AddInventoryJuncture` and `AddInventoryJunctureEx` gained a trailing
`Managed userData = null` parameter. Overrides / modded versions must add it:
```c
// 1.29 signature
bool AddInventoryJuncture(Man player, notnull EntityAI item, InventoryLocation dst,
                          bool test_dst_occupancy, int timeout_ms, Managed userData = null);
```
Related: `ActionData.OnJunctureTimedOut()` is new; `ActionManagerBase.RefreshActionJuncture` is
`[Obsolete("Handled by 'ActionData.OnJunctureTimedOut' now")]`; `GameInventory.OnInventoryJunctureRepairFromServer`
was removed; `HumanInventory.OnInventoryCheck(int userDataType, ParamsReadContext ctx)` was added.

### 7. New inventory location type `TEMP`
```c
enum InventoryLocationType
{
    UNKNOWN, GROUND, ATTACHMENT, CARGO, HANDS, PROXYCARGO, VEHICLE,
    TEMP,   // NEW - client-side limbo while inventory is desynced, until the server sends the real location
};
```
`switch` statements over `InventoryLocationType` should handle (or at least not crash on) `TEMP`.

### 8. Stamina is predicted / synced via junctures
`StaminaHandler` was reworked (+519 lines) to use the Pawn move/state reconciliation
(`ObtainMove`, `ObtainState`, `ReplayMove`, `RewindState`, `SyncStaminaEx`, `RecalculateStaminaCap`, `MarkLoadDirty`).
- `StaminaHandler.GetCooldownTimer(int)` - **removed**
- `StaminaHandler.DepleteStamina(...)` - `[Obsolete("No replacement")]`
- `StaminaHandler.OnRPC(float, float, bool)` - `[Obsolete]`, stamina uses SyncJunctures now
- `PlayerBase.SetPlayerLoad` / `AddPlayerLoad` - `[Obsolete]` (planned removal 1.30); use `NotifyPlayerLoadChanged()` /
  `GetOnPlayerLoadChanged()`

Stamina mods that modded `StaminaHandler` internals need a full re-check against the 1.29 source.

### 9. `EntityType` script classes (per config class)
`Object.GetEntityType()` returns a shared, per-config-class `EntityType` instance, meant for caching shared
data and expensive init logic once per class instead of once per entity. Hierarchy:
```
EntityType
├── WindSockType
└── EntityAIType
    ├── BuildingType, ManType, TransportType, DayZCreatureType, ScriptedEntityType
    └── InventoryItemType
        └── ItemBaseType (typedef Inventory_BaseType)
            └── ClothingType, WeaponType, MagazineType, ItemOpticsType, CarWheelType, ...
```
`EntityType` exposes `GetName()` plus `ConfigGetString/Int/Float/Vector/Bool`, `ConfigGetTextArray(Raw)`,
`ConfigGetFloatArray`, `ConfigGetIntArray`, `ConfigIsExisting`.
```c
ItemBaseType t = ItemBaseType.Cast(item.GetEntityType());
if (t)
{
    float weight = t.ConfigGetFloat("weight");
}
```
Vanilla pairs `Foo` with `FooType` (e.g. `ItemOptics`/`ItemOpticsType`). How the engine binds a custom
`MyItemType` to `MyItem` is not documented in the scripts - verify before relying on custom Type classes.
`InventoryItemType` now owns attach/detach/drop sound sets (`InventoryItemSoundAttach/Detach`), and
`ItemBase.StartItemSoundServer` gained an overload `(int id, int slotId)`.

### 10. Hands and cached equipment helpers
```c
EntityAI inHands = player.GetEntityInHands();   // NEW: native on Man (1.29)
// was: player.GetHumanInventory().GetEntityInHands()  - still works
ItemBase ib = player.GetItemInHands();          // PlayerBase helper, unchanged, returns ItemBase

// NEW: category cache of equipped items (lights, NVG, optics, short/long firearms)
CachedEquipmentStorageBase cache = player.GetCachedEquipment();
if (cache)
{
    array<Entity> lights = cache.GetEntitiesByCategory(ECachedEquipmentItemCategory.LIGHT);
}
```
`EntityAI.GetCachedEquipmentCategory()` decides which category an item falls into.
`DayZPlayerImplement.GetNVEntityAttached()` was **removed** - use the cache with `ECachedEquipmentItemCategory.NVG`.

### 11. Gizmo API moved to `GizmoApi`
`CGame.GizmoGetCount/GizmoGetInstance/GizmoGetTracker/GizmoFindByTracker/...` are `[Obsolete]`.
Use the global `GetGizmoApi()` (vanilla always null-checks it; it can be null e.g. before `CreateGizmoApi()`):
```c
if (GetGizmoApi())
    GetGizmoApi().SelectObject(this);
```
Objects can restrict gizmo modes via `Object.Gizmo_IsAllowedTransformMode(GizmoTransformMode)` and
`Gizmo_IsAllowedSpaceMode(GizmoSpaceMode)`.

### 12. `RegisterNetSyncVariableFloat` fix (1.29 "Road to Badlands Update 1", build 1.29.163451)
Quantized floats whose range+precision needed more than 32 bits were synchronized incorrectly (T198078).
If you worked around this by lowering precision, you can revert it on 1.29.163451+.

### 13. `ScriptInputUserData` size limit temporarily increased
To fit larger Network IDs. Do not rely on the new limit - keep input user data small.

### 14. Other official modding notes (1.29)
- `DayZPlayer.IsAuthority()` now returns true in singleplayer
- `Inventory.CreateEntity` honours the flip flag
- `Object.IsAnyInherited` returns on first match (and is faster)
- Assigning a `typename` of a base type (`string`, `int`) to a variable works now
- Initial update of the animation system to Enfusion 2021; Animation Editor gained a live debugger
  (in-game diag "Animation > Enable debugger")
- Bullet physics multithreading enabled on servers
- Server `-doScriptLogs=1` compile failure on retail fixed
- Connection/disconnection logs now include player location
- Items in the CE ignore list no longer spawn via `cfgspawnabletypes.xml` or player inventory
- Animated parts of objects regained collisions (1.29 Update 2)
- Crash with `SurfaceUnderObjectByBone` on some animals fixed
- Forcing objects into other objects from script (barrel in barrel) is now blocked

## New Features

### Scripted physics API (`1_Core/physics/`)
`Physics` is now a full class (bodies, geometry, forces, velocities, interaction layers):
```c
Physics phys = GetPhysics();
if (phys)
{
    phys.ApplyImpulse("0 500 0");
    vector vel = phys.GetVelocity();
    string geomName = phys.GetGeomName(0);   // NEW in 1.29
}
```
Also new: `PhysicsGeom` (`CreateBox/Sphere/Capsule/Cylinder/TriMesh`), `PhysicsWorld` (gravity, update rate,
dynamic bodies), joints (`PhysicsJoint.CreateHinge/BallSocket/Fixed/ConeTwist/Slider/6DOF/6DOFSpring`),
`PhysicsBlock`, `SimulationState`. The legacy `dBody*` global functions still exist.
> The doc comments in these files show Enfusion-style `{GUID}.gamemat` materials copied from Reforger -
> for DayZ, keep using `.bisurf` paths / `#CfgSurfaces` names (see version-128.md).

### Transport physics
```c
// On Transport (cars, boats, custom vehicles) - deterministic physics
proto void ApplyForce(vector force);
proto void ApplyForceAt(vector pos, vector force);
proto void ApplyTorque(vector force);
proto void ApplyCentralImpulse(vector centralImpulse);
proto void ApplyTorqueImpulse(vector torqueImpulse);
proto void ApplyImpulseAt(vector pos, vector force);
```
Transport also gained input gathering and dynamic collision resolution (previously cars only), and
`CarScript.OnInput(float dt)` is new.

### Pawn networking hooks
`Pawn.GetOwnerState()` and `Pawn.GetNextMove()` let a CommandHandler preload/predict data;
`PlayerBase`, `CarScript`, `BoatScript` override `GetOwnerStateType()`. `Man` extends `Person` → `Pawn`
(under `FEATURE_NETWORK_RECONCILIATION`, defined in retail).

### Debug text
```c
DebugTextScreenSpace.Create("hello", DebugTextFlags.ONCE, 100, 100);
DebugTextWorldSpace.Create("here", DebugTextFlags.ONCE, pos[0], pos[1], pos[2]);
```
(check `1_Core/debug/debugtextflags.c` for the flag values)

### Small additions
- `int.ToHex()` → `"0xA"`
- `Math3D.BoxCenter(a, b)`, `Math3D.BoxSize(a, b)`
- `PLATFORM_MSSTORE` define (included in `PLATFORM_CONSOLE`)
- `PlayerBase.GetWaterSurfaceHeightNoFakeWave/WithFakeWave`, `SurfaceGetSeaWaveCurrent/Max`
- `MissionServer` input-exclude helpers (`AddActiveInputExcludes`, `RemoveActiveInputExcludes`, `IsControlDisabled`, ...)
- `MissionGameplay.Get/SetExitButtonDisabledRemainingTime`
- `CarWheel.GetRuinedReplacement()`
- New classes: `SCARH`, `T56TankerHelmet`, `Headdress_Fox`, `MilitaryCap_ColorBase`, `PilotJacket_ColorBase`,
  `WinterMilitaryCoat_ColorBase`, new recipes (`RepairWithSewingKit`, `RepairWithTireKit`, ...)

## Newly Obsolete in 1.29
| Obsolete | Replacement |
|----------|-------------|
| `CGame.Gizmo*` | `GetGizmoApi()` / `GizmoApi` |
| `UndergroundBunkerHandlerClient`, `GetUndergroundBunkerHandler()` | `UndergroundHandlerClient`, `GetUndergroundHandler()` |
| `UndergroundBunkerTrigger` | `JsonUndergroundTriggers` |
| `StaminaHandler.DepleteStamina`, `StaminaHandler.OnRPC` | none (SyncJunctures) |
| `ActionManagerBase.RefreshActionJuncture` | `ActionData.OnJunctureTimedOut` |
| `PlayerBase.SetPlayerLoad`, `AddPlayerLoad` | `NotifyPlayerLoadChanged` |
| `GPSReceiver.UpdateDisplayState(bool)` | overloaded `UpdateDisplayState` |
| `ItemBase.PlayAttachSound(string)` | `ItemSoundHandler` |
| `SetNVGWorking`, `AntibioticsAttack`, `PopulateDlcFrame`, `FilterDLCs`, `ValidateDestroy` | none |
Full list: https://diff.yadz.app/deprecated/

## Migration Checklist
```
[ ] Rebuild against 1.29 scripts and fix compile errors
[ ] Replace GetGame() with g_Game (at least in modded vanilla classes and hot paths)
[ ] Search for raw int use of ActiveState
[ ] Vehicle mods: remove m_HeadlightsOn, use LightOn/LightOff/LightToggle/OnBeforeLightOn
[ ] Vehicle mods: m_HeadlightsState / m_RearLightType are int now
[ ] Physics mods: EOnSimulate/EOnPostSimulate no longer fire on sleeping bodies
[ ] Update overrides of AddActionJuncture / AddInventoryJuncture(Ex) (new userData param)
[ ] Handle InventoryLocationType.TEMP in switches
[ ] Stamina mods: re-check against the new StaminaHandler
[ ] Replace GetNVEntityAttached() with GetCachedEquipment()
[ ] Replace CGame.Gizmo* with GetGizmoApi()
[ ] Terrain mods: re-binarize WRP with 1.29 tools
[ ] Check [Obsolete] warnings in the script log
[ ] Use https://diff.yadz.app/mod-check/ to check a mod against current signatures
```

## Framework Compatibility
Check the current CF and Expansion releases on the Workshop / GitHub before release; this file does not pin
framework versions for 1.29 (no verified minimum available at time of writing).

## Looking Ahead: 1.30
1.30 Experimental (1.30.164014, Sep 16, 2026) is browsable on diff.yadz.app (`/v/experimental/`); its
mod-check uses the DayZ Script Diff Experimental snapshot. `SetPlayerLoad`/`AddPlayerLoad` are flagged for removal in 1.30.
