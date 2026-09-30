# Framework Detection

## Overview

DayZ mods can target three levels:
1. **Vanilla** - No external dependencies
2. **Community Framework (CF)** - Adds RPC, modules, networking utilities
3. **DayZ Expansion** - Full framework (requires CF) with market, quests, AI, basebuilding

## Detection Priority

### 1. Check config.cpp Dependencies (Highest Priority)

```cpp
// Vanilla only
requiredAddons[] = {"DZ_Data"};

// Community Framework
requiredAddons[] = {"DZ_Data", "JM_CF_Scripts"};

// Expansion (always includes CF)
requiredAddons[] = {"DZ_Data", "JM_CF_Scripts", "DayZExpansion_Core"};
// Expansion sub-modules:
//   "DayZExpansion_Market"    - Market/trading
//   "DayZExpansion_Quests"    - Quest system
//   "DayZExpansion_AI"        - AI system
//   "DayZExpansion_BaseBuilding" - Basebuilding
//   "DayZExpansion_Vehicles"  - Vehicle extensions
```

### 2. Check Code Patterns (Secondary)

```c
// CF indicators
GetRPCManager()           // CF RPC system
CF_ModuleWorld            // CF Module base class
ModStorage                // CF 1.5.5+ storage

// Expansion indicators
ExpansionMarketModule     // Expansion Market
ExpansionQuestModule      // Expansion Quests
eAIBase                   // Expansion AI
ExpansionTerritory        // Expansion Basebuilding
```

### 3. Check mod.cpp / meta.cpp (Fallback)

```
// CF dependency
dependency[] = {"Community Framework"};

// Expansion dependency
dependency[] = {"DayZ Expansion Core", "DayZ Expansion Scripts"};
```

## Runtime Detection

```c
// Check at runtime if frameworks are loaded
bool HasCF()
{
    return (GetModuleManager() != null);
    // Or check for CF-specific class existence
}

bool HasExpansion()
{
    // Check if Expansion core is loaded
    return GetGame().ConfigIsExisting("CfgPatches DayZExpansion_Core");
}
```

## Framework Compatibility Matrix

| Feature | Vanilla | + CF | + Expansion |
|---------|---------|------|-------------|
| ScriptRPC | Yes | Yes | Yes |
| Named RPC (RPCManager) | No | Yes | Yes |
| Modules (CF_ModuleWorld) | No | Yes | Yes |
| NetworkedVariables | No | Yes | Yes |
| ModStorage | No | Yes (1.5.5+) | Yes |
| Market/Trading | No | No | Yes |
| Quest System | No | No | Yes |
| AI System | No | No | Yes |
| Territory/Basebuilding | No | No | Yes |
| Vehicle Extensions | No | No | Yes |

## Version Requirements

For DayZ 1.29 use the current CF / Expansion releases (no verified minimum versions are recorded here yet);
check the Workshop / GitHub changelogs for 1.29 support.

### DayZ 1.28

| Framework | Minimum Version | Notes |
|-----------|----------------|-------|
| Community Framework | 1.5.7 | ModStorage simplified |
| Expansion Core | 1.9.28 | Animation graph updated |
| Expansion Scripts | 1.9.28 | CTD workarounds |

## When to Use Each

### Vanilla Only
- Maximum compatibility (works on all servers)
- No dependency management
- Limited networking (ScriptRPC only)
- Good for: Simple items, basic actions, config-only mods

### Community Framework
- Named RPCs with namespacing
- Module system for organized code
- NetworkedVariables for easy sync
- Good for: Intermediate mods, multi-system mods, mods that need clean networking

### Expansion
- Full game systems (market, quests, AI)
- Advanced vehicle support
- Territory and basebuilding
- Good for: Server-side content mods, economy mods, mission systems
