# DayZ Enforce Script Style Guide

## Code Style

### Naming Conventions
- **Classes**: PascalCase (`PlayerBase`, `ItemBase`, `MyCustomItem`)
- **Methods**: PascalCase (`GetInventory()`, `SetHealth()`, `OnVariablesSynchronized()`)
- **Member variables**: `m_` prefix with PascalCase (`m_Health`, `m_MyValue`, `m_IsActive`)
- **Local variables**: camelCase (`player`, `itemCount`, `entityList`)
- **Constants/Enums**: ALL_CAPS or PascalCase (`ERPCs`, `AT_INTERACT`, `CALL_CATEGORY_SYSTEM`)

### File Organization
- Place scripts in the correct module: `3_Game/`, `4_World/`, `5_Mission/`
- One class per file when practical
- Use `modded class` for extending existing classes (never copy entire classes)

### Mandatory Safety Checks
```c
// ALWAYS null-check Cast results
PlayerBase player = PlayerBase.Cast(entity);
if (!player) return;

// ALWAYS null-check GetInventory
if (!player.GetInventory()) return;

// ALWAYS null-check GetIdentity on server
PlayerIdentity identity = player.GetIdentity();
if (!identity) return;

// ALWAYS call super in overrides
override void OnVariablesSynchronized()
{
    super.OnVariablesSynchronized();
    // your code
}
```

### Server/Client Separation
- Use `GetGame().IsServer()` before server-only logic
- Use `!GetGame().IsDedicatedServer()` for client checks (NOT `IsClient()` during init)
- Mark sync variables with `RegisterNetSyncVariable*` in constructor
- Call `SetSynchDirty()` after modifying sync variables (server-side only)

### Memory Management
- Use `ref` only for class member variables, never in function parameters
- Inherit from `Managed` for reference counting
- Use `autoptr` for scope-based automatic cleanup
- Never manually call `delete` - Enforce Script is garbage collected

### Performance
- Use `g_Game` instead of `GetGame()` (1.29 vanilla does this everywhere)
- Assign getter results to local variables before `foreach` loops
- Methods must not exceed 16 parameters (enforced in 1.28)
- Avoid empty `#ifdef`/`#endif` blocks (causes segfaults)
- Parenthesize all bitwise operations: `(flags & FLAG) == FLAG`

### Config.cpp Style
- Always include `CfgPatches` with correct `requiredAddons`
- Use `scope = 2` for items visible in game
- Use `scope = 1` for internal/parent classes
- Use `scope = 0` for hidden/abstract classes
- Reference `hiddenSelections` with matching `hiddenSelectionsTextures`

### RPC Security
- Always validate sender identity in RPC handlers
- Never trust client-provided data without server-side validation
- Use `GetGame().IsServer()` guards in RPC handler logic
- Rate-limit player-triggered RPCs when possible
