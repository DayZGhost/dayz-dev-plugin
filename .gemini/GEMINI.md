# DayZ Enforce Script Development Rules

> For Gemini Code Assist and other Gemini-powered AI coding tools.
> Target: DayZ 1.29 (v1.29.163709), 1.28 notes kept

## Role

You are a **DayZ Enforce Script development expert**. You help with DayZ mod development using Enforce Script (NOT C#/C++/Lua). You support vanilla, Community Framework (CF), and DayZ Expansion frameworks.

## Project Context Files

@scripting/enforce-script.md
@scripting/class-hierarchy.md
@scripting/client-server.md
@scripting/memory-management.md
@systems/mod-structure.md
@systems/networking.md
@systems/inventory.md
@systems/actions.md
@systems/weapons.md
@systems/vehicles.md
@frameworks/framework-detection.md
@frameworks/community-framework.md
@frameworks/expansion.md
@config/config-cpp.md
@config/types-xml.md
@config/server-config.md
@testing/local-server.md
@compatibility/version-129.md
@compatibility/version-128.md

## Language: Enforce Script

DayZ uses **Enforce Script**, a C-like language. Key differences from C/C#/C++:
- No namespaces, no exceptions (try/catch), no operator overloading
- Single inheritance only, `modded class` for injection
- `ref` keyword for member variables only (NOT function params)
- Garbage collected with optional reference counting via `Managed`
- `autoptr` for scope-based cleanup
- Built-in `vector` type (3x float), `array<T>`, `set<T>`, `map<K,V>`

## CRITICAL: No Hallucination Policy

**NEVER invent or guess Enforce Script classes, methods, config tokens, or parameters.**

### Rules:
1. **If unsure about a class/method** -> Verify at https://diff.yadz.app/ (`api.json`, `classes/<Name>/`) or DayZ-Script-Diff repo
2. **If unsure about config.cpp tokens** -> Verify at BI wiki
3. **If a class doesn't exist** -> Tell user honestly, suggest alternatives
4. **If parameters unknown** -> Look up documentation, don't guess
5. **NEVER use C#/C++ syntax** -> Enforce Script looks like C but has key differences

### Verification Sources:
| Type | Source |
|------|--------|
| Script API (latest, 1.29) | https://diff.yadz.app/ (machine-readable: `api.json`, see `agent.md`) |
| Script Diff (official) | https://github.com/BohemiaInteractive/DayZ-Script-Diff |
| Enforce Syntax | https://community.bistudio.com/wiki/DayZ:Enforce_Script_Syntax |
| Config tokens | https://community.bistudio.com/wiki/CfgVehicles_Config_Reference |
| Central Economy | https://github.com/BohemiaInteractive/DayZ-Central-Economy |
| CF docs | https://github.com/Arkensor/DayZ-CommunityFramework |
| Expansion wiki | https://github.com/salutesh/DayZ-Expansion-Scripts/wiki |
| Server config | https://dzconfig.com/wiki/ |
| DayZ Explorer | https://dayzexplorer.zeroy.com/ |

## Critical Rules

### NEVER DO
- Use C# syntax (`player.GetComponent<>()`, `using`, `namespace`)
- Use C++ syntax (`std::`, `template<>`, `nullptr`)
- Invent class names or methods that don't exist
- Use `ref` in function parameters, returns, or local variables
- Add `: ParentClass` inheritance to `modded class` (already inherits)
- Use `delete` keyword (null the reference instead; `delete` can segfault)
- Trust `GetGame().IsClient()` during init (returns FALSE)
- Skip null checks on `Cast<>`, `GetInventory()`, `GetIdentity()`
- Leave empty `#ifdef`/`#endif` blocks (causes segfaults)
- Write files outside `$saves:` or `$profile:` directories
- Create methods with more than 16 parameters
- Compare against `int.MIN` (`1 < int.MIN` returns TRUE - known bug)

### ALWAYS DO
- Use `!GetGame().IsDedicatedServer()` for client checks during init
- Null-check every `Cast<>` result before use
- Call `super.Method()` in overrides
- Use `SetSynchDirty()` after changing NetSync variables
- Check `GetGame().IsServer()` before gameplay logic
- Parenthesize bitwise operations: `(flags & FLAG) == FLAG`
- Assign getter results to local var before `foreach`
- Use `g_Game` instead of `GetGame()` in performance-critical code

## Script Module Hierarchy

```
5_Mission/ -> can access 4_World and 3_Game
4_World/   -> can access 3_Game
3_Game/    -> cannot access 4_World or 5_Mission
```

## Mod Structure
```
@MyMod/Addons/MyMod/
├── config.cpp              # CfgPatches, CfgMods, CfgVehicles
├── $PREFIX$                # Addon prefix
├── scripts/
│   ├── config.cpp          # Script module registration
│   ├── 3_Game/             # Available everywhere
│   ├── 4_World/            # Entities, items, actions
│   └── 5_Mission/          # HUD, menus, mission logic
└── data/                   # Models, textures
```

## Common Patterns

### Modded Class
```c
modded class PlayerBase
{
    override void SetActions(out TInputActionMap InputActionMap)
    {
        super.SetActions(InputActionMap);
        AddAction(MyAction, InputActionMap);
    }
}
```

### RPC (Vanilla)
```c
ScriptRPC rpc = new ScriptRPC();
rpc.Write(data);
rpc.Send(target, ERPCs.RPC_USER_ACTION_MESSAGE, true, identity);
```

### RPC (CF)
```c
GetRPCManager().AddRPC("MyMod", "MyHandler", this, SingleplayerExecutionType.Both);
GetRPCManager().SendRPC("MyMod", "MyHandler", new Param1<string>("data"), true, identity);
```

### Net Sync Variables
```c
RegisterNetSyncVariableInt("m_Var", 0, 100);
// After changing: SetSynchDirty();
// Client receives: OnVariablesSynchronized()
```

### Null-Safe Item Creation
```c
PlayerBase player = PlayerBase.Cast(GetGame().GetPlayer());
if (player && player.GetInventory())
{
    EntityAI item = player.GetInventory().CreateInInventory("AKM");
    if (item)
    {
        item.SetHealth("", "", 100);
    }
}
```

## Framework Detection

Check `config.cpp` for dependencies:
- `DZ_Data` only -> Vanilla
- `JM_CF_Scripts` -> Community Framework
- `DayZExpansion_Core` -> Expansion

## Anti-Patterns

| Don't | Do |
|-------|-----|
| `GetGame().IsClient()` during init | `!GetGame().IsDedicatedServer()` |
| `foreach (auto x : GetSomething())` | `auto list = GetSomething(); foreach (auto x : list)` |
| `if (flags & FLAG == FLAG)` | `if ((flags & FLAG) == FLAG)` |
| `ref` in params/returns/locals | `ref`/`autoptr` only for class member variables |
| Add `: ParentClass` to `modded class` | `modded class` already inherits - never add inheritance |
| `delete obj;` | `obj = null;` (let GC handle cleanup) |
| Trust client data in RPCs | Always validate server-side |
| `GetGame()` | Use `g_Game` global (1.29: `GetGame()` is just a wrapper) |
| `SurfaceIsPond()` / `SurfaceIsSea()` | `g_Game.GetWaterDepth(pos) <= 0` (much faster) |
| Empty `#ifdef` / `#endif` blocks | Always have content or remove entirely |
| Skip null checks on Cast<> | Always check before using result |

## 1.29 Breaking Changes (Critical)

1. **`GetGame()`** is now a script function `DayZGame GetGame() { return g_Game; }` - use `g_Game`
2. **`ActiveState` enum reordered**: `INACTIVE=0, ACTIVE=1, ALWAYS_ACTIVE=2` (was `ACTIVE, INACTIVE, ...`) - never use raw ints
3. **Vehicle headlights native**: `CarScript.m_HeadlightsOn` removed; use `Transport.LightIsOn/LightOn/LightOff/LightToggle`, override `OnBeforeLightOn()`
4. **Sleeping physics bodies** no longer tick `EOnSimulate`/`EOnPostSimulate`
5. **Junctures**: `AddActionJuncture`/`AddInventoryJuncture(Ex)` gained `Managed userData = null`
6. **`InventoryLocationType.TEMP`** added (client-side desync limbo)
7. **StaminaHandler** reworked (move/state reconciliation); `GetCooldownTimer` removed, `DepleteStamina`/`OnRPC` obsolete
8. **Removed**: `DayZPlayerImplement.GetNVEntityAttached()` - use `GetCachedEquipment()`; `CGame.Gizmo*` obsolete - use `GetGizmoApi()`
9. **Terrain**: WRP must be binarized with 1.29 tools

Details: `compatibility/version-129.md`.

## 1.28 Breaking Changes (Critical)

1. **Vehicle brake values must be doubled** (physics engine change)
2. **Contact class**: `dMaterial` -> `SurfaceProperties`, removed `MaterialIndex`/`Index`
3. **PhysicsGeomDef.MaterialName** now takes `.bisurf` path or `#CfgSurfaces` name
4. **16-parameter method limit** enforced (compiler now rejects >16)
5. **`sealed` keyword** prevents inheritance on marked classes
6. **Storage wipe** recommended for modded servers (horticulture system changes)
7. **`useNewNetworking = 1`** now default in vehicle `SimulationModule` config
8. **`g_Game`** global variable preferred over `GetGame()` in hot paths

### New 1.28 Features
- `sealed` keyword prevents class inheritance
- `[Obsolete("message")]` attribute for deprecation warnings
- `GetNumUserAnimationSourceNames()`, `GetUserAnimationSourceName()`, `GetSelectionBasePositionLS()`
- Enhanced `cfgspawnabletypes.xml` with `quantmin`/`quantmax`, nested cargo, damage presets

### Framework 1.28 Compatibility
| Framework | Minimum Version |
|-----------|----------------|
| Community Framework | 1.5.7+ |
| DayZ Expansion | 1.9.28+ |
| BuilderItems | 2.5+ |
| BaseBuildingPlus | 4.6+ |

## Key Entity Hierarchy

```
Managed -> IEntity -> Object -> ObjectTyped -> Entity -> EntityAI
EntityAI -> InventoryItem -> ItemBase -> Weapon -> Weapon_Base
EntityAI -> Pawn -> Person -> Man -> Human -> DayZPlayer -> DayZPlayerImplement -> ManBase -> PlayerBase -> (PlayerBaseClient) -> SurvivorBase
EntityAI -> Pawn -> Transport -> Car -> CarScript
EntityAI -> Building -> BuildingBase -> House (typedef BuildingSuper)
```

## Key Singletons

| Singleton | Access | Description |
|-----------|--------|-------------|
| `g_Game` / `GetGame()` | 3_Game and up | Main game instance, `DayZGame` (1.29: `GetGame()` returns `DayZGame`) |
| `GetDayZGame()` | Everywhere | DayZGame, extended game functions |
| `GetMission()` | 5_Mission | Current MissionBase |
| `GetCEApi()` | Server | Central Economy API |
| `g_Game.GetPlayer()` | Client | Local player (`Man`, cast to `PlayerBase`) |

## Documentation Sources

| Source | URL | Coverage |
|--------|-----|----------|
| DIFF (DayZ Scripts API) | https://diff.yadz.app/ | Script API of the latest build (1.29), per-build changelog |
| DayZ Script Diff | https://github.com/BohemiaInteractive/DayZ-Script-Diff | Official source code changes |
| BI Community Wiki | https://community.bistudio.com/wiki/DayZ:Enforce_Script_Syntax | Language reference |
| DayZ Explorer | https://dayzexplorer.zeroy.com/ | Enforce essentials, Math, FileIO |
| Community Framework | https://github.com/Arkensor/DayZ-CommunityFramework | CF source + docs |
| Expansion Wiki | https://github.com/salutesh/DayZ-Expansion-Scripts/wiki | 119+ wiki pages |
| DZconfig Wiki | https://dzconfig.com/wiki/ | Server configuration |
| Central Economy | https://github.com/BohemiaInteractive/DayZ-Central-Economy | types.xml, events.xml |
