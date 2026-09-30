# Enforce Script Quick Reference

> DayZ uses **Enforce Script** - a C-like language. NOT C#, NOT C++, NOT Lua.

## Primitive Types
| Type | Size | Example |
|------|------|---------|
| `int` | 32-bit signed | `int x = 42;` |
| `float` | 32-bit IEEE | `float f = 3.14;` |
| `bool` | true/false | `bool b = true;` |
| `string` | UTF-8 | `string s = "hello";` |
| `vector` | 3x float (x,y,z) | `vector v = "1 2 3";` or `Vector(1,2,3)` |
| `typename` | Type reference | `typename t = int;` |
| `Class` | Base of all classes | Root type |

## Collections
```c
// Dynamic array
array<string> names = new array<string>;
array<string> shorthand = {};              // Shorthand (preferred)
names.Insert("item");
names.Count();      // size
names.Get(0);       // access
names.Remove(0);    // remove by index
names.Clear();      // empty

// Static array
int fixed[10];      // fixed-size, stack-allocated

// Set (unique values)
set<string> unique = new set<string>;
unique.Insert("a"); // returns false if duplicate

// Map
map<string, int> lookup = new map<string, int>;
lookup.Insert("key", 42);
lookup.Get("key");  // returns 42
lookup.Contains("key"); // true/false
```

## Type Aliases (Common)
| Alias | Actual Type |
|-------|-------------|
| `TStringArray` | `array<string>` |
| `TFloatArray` | `array<float>` |
| `TIntArray` | `array<int>` |
| `TVectorArray` | `array<vector>` |
| `TStringStringMap` | `map<string, string>` |
| `TIntStringMap` | `map<int, string>` |

## Constants & Globals
```c
const float FLT_MAX = 3.402823e+38;
const float FLT_MIN = 1.175494e-38;
float ftime;        // frame delta time (seconds)
```

## Operators
| Category | Operators |
|----------|-----------|
| Arithmetic | `+  -  *  /  %` |
| Comparison | `==  !=  <  >  <=  >=` |
| Logical | `&&  \|\|  !` |
| Bitwise | `&  \|  ^  ~  <<  >>` |
| Assignment | `=  +=  -=  *=  /=  &=  \|=` |

**WARNING:** Bitwise ops have LOWER precedence than comparisons!
```c
// WRONG: compares b == b first, then ANDs
if (flags & FLAG == FLAG)

// RIGHT: parenthesize bitwise
if ((flags & FLAG) == FLAG)
```

## Control Flow
```c
// If/else
if (condition) { } else if (other) { } else { }

// Switch
// WARNING: Compiler requires explicit return even with default case
// Move final return OUTSIDE switch as workaround
switch (value)
{
    case 1: /* ... */ break;
    case 2: /* ... */ break;
    default: break;
}

// For loop
for (int i = 0; i < count; i++) { }

// While loop
while (condition) { }

// Foreach
foreach (string item : myArray) { }
// WARNING: Never foreach on a getter return directly!
// WRONG:  foreach (auto x : GetSomething())
// RIGHT:  auto list = GetSomething(); foreach (auto x : list)
```

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase, mod prefix recommended | `ExpansionGarageSettings`, `PlayerBase` |
| Methods | PascalCase | `SetDefaultLootingBehaviour()` |
| Member vars | `m_` prefix + PascalCase | `m_IsLoaded`, `m_CustomData` |
| Static vars | `s_` prefix + PascalCase | `s_Expansion_DangerousAreas` |
| Local vars | camelCase | `bitmask`, `lootingBehavior` |
| Parameters | camelCase | `void Log(string msg)` |
| Constants | `const` keyword | `const float MY_VALUE = 1.0;` |
| Enums | PascalCase or ALL_CAPS (be consistent) | `VALUE_A`, `MyEnumValue` |
| Preprocessor | UPPERCASE | `#define EXPANSION_MARKER_VIS_WORLD` |

**Modded classes:** Always prefix your member variables with your mod name to avoid conflicts with other mods (e.g., `m_MyMod_CustomValue` instead of `m_CustomValue`).

## Classes & Inheritance
```c
class MyClass extends ParentClass
{
    // Access modifiers: private, protected, public (default)
    private int m_Value;
    protected string m_Name;
    float m_PublicFloat;  // public by default

    // Non-serialized attribute (excluded from serialization)
    [NonSerialized()]
    bool m_IsLoaded;

    // Constructor
    void MyClass()
    {
        m_Value = 0;
    }

    // Destructor
    void ~MyClass()
    {
        // cleanup
    }

    // Methods - use override keyword when overriding
    override void SetValue(int val) { m_Value = val; }
    int GetValue() { return m_Value; }

    // Static methods
    static MyClass Create() { return new MyClass(); }
}
```

## Modded Classes (DayZ Injection Pattern)

**CRITICAL:** NEVER add `: ParentClass` inheritance to modded classes. The modded class already inherits from the original - adding inheritance is silently ignored and causes confusion.

```c
// WRONG - never add inheritance to modded class!
modded class PlayerBase : ManBase  // BAD! `: ManBase` is ignored
{
}

// RIGHT - modded class inherits automatically
modded class PlayerBase
{
    private int m_MyMod_CustomData;  // Prefix with mod name!

    override void Init()
    {
        super.Init();  // ALWAYS call super!
        m_MyMod_CustomData = 0;
    }

    override void SetActions(out TInputActionMap InputActionMap)
    {
        super.SetActions(InputActionMap);
        AddAction(MyAction, InputActionMap);
    }
}
```

## Templates (Generics)
```c
class Container<Class T>
{
    T m_Item;
    void Set(T item) { m_Item = item; }
    T Get() { return m_Item; }
}
```

## Enums
```c
enum MyEnum
{
    VALUE_A,        // 0
    VALUE_B,        // 1
    VALUE_C = 10,   // 10
    VALUE_D         // 11
}
```

## Casting
```c
// Safe downcast (returns null if invalid)
PlayerBase player = PlayerBase.Cast(entity);
if (player)
{
    // safe to use
}

// Alternative CastTo (out parameter)
PlayerBase player;
if (CastTo(player, entity))
{
    // safe to use
}

// Type checking
if (entity.IsInherited(PlayerBase))
{
    // entity IS a PlayerBase
}

// Get type name
string typeName = entity.ClassName();  // Script class name "PlayerBase"
string configType = entity.GetType();  // Config class name (for entities, use this!)
typename type = entity.Type();

// NOTE: For entities, GetType() returns the config class name.
// ClassName() returns the script class name. These can differ.
```

## Known Quirks

```c
// BUG: 1 < int.MIN returns TRUE in Enforce Script!
// Be careful with int boundary comparisons
int val = int.MIN;
if (1 < val)  // This is TRUE, which is wrong!

// Compiler error line numbers can be misleading when:
// - A class is undefined or has a name conflict
// - Error may actually be in the PREVIOUS file in the compile order
// Check the file BEFORE the reported location

// Complex array assignments can segfault - use intermediate variables
// RISKY: someArray[GetIndex()] = ComputeValue();
// SAFER: int idx = GetIndex(); int val = ComputeValue(); someArray[idx] = val;
```

## String Methods
| Method | Returns | Notes |
|--------|---------|-------|
| `s.Length()` | `int` | String length |
| `s.IndexOf(substr)` | `int` | First occurrence, -1 if not found |
| `s.Substring(start, len)` | `string` | Extract substring |
| `s.Replace(old, new)` | `int` | Replaces in-place, returns count |
| `s.ToLower()` | `int` | Modifies in-place! Returns LENGTH not string |
| `s.ToUpper()` | `int` | Modifies in-place! Returns LENGTH not string |
| `s.Trim()` | `string` | Remove whitespace |
| `s.Split(delim, out arr)` | `void` | Split into array |
| `s.Contains(substr)` | `bool` | Check contains |

**WARNING:** `ToLower()` and `ToUpper()` modify the string in-place AND return the length (int), NOT the modified string!

## Preprocessor
```c
#define MY_CONSTANT 42
#ifdef SERVER
    // server-only code
#endif
#ifndef CLIENT
    // not client
#endif
#include "path/to/file.c"
```

**WARNING:** Empty preprocessor blocks can cause segfaults. Always have content or remove the block entirely.

## Function Parameters
```c
// Normal parameter
void Foo(int x) { }

// Out parameter (modified by callee)
void GetValues(out int x, out int y) { x = 1; y = 2; }

// Default parameter
void Bar(int x, int y = 0, string s = "") { }

// notnull - guarantees parameter is never null (caller checked)
void Process(notnull MyClass data) { /* data is guaranteed non-null */ }

// WARNING: ref in params is WRONG - ref is for member variables only!
// WRONG: void Bad(ref int x)
// RIGHT: void Good(out int x)
```

## Key Singletons
```c
GetGame()           // DayZGame (1.29: script wrapper that returns g_Game - prefer g_Game)
GetDayZGame()       // DayZGame - DayZ-specific game
GetPlayer()         // Man - local player (client only)
GetRPCManager()     // CF RPCManager (requires Community Framework)
g_Game              // DayZGame global - what vanilla uses everywhere since 1.29
```

## Performance Notes

```c
// AVOID: GetObjectsAtPosition / GetObjectsAtPosition3D - very expensive
// USE: Cache results, use triggers, or keep your own registry of relevant objects

// AVOID: g_Game.SurfaceIsPond() and g_Game.SurfaceIsSea() - remarkably slow
// USE: g_Game.GetWaterDepth(position) <= 0 for water checks

// Proto methods have call overhead; script methods are faster for simple operations
// Use proto methods only when their engine-side functionality is needed
```

## Config Defines (1.26+)

Since DayZ 1.26, you can define preprocessor symbols in `config.cpp`:
```cpp
class CfgPatches
{
    class MyMod
    {
        // These become available as #ifdef symbols in scripts
        defines[] = {"MYMOD_ENABLED", "MYMOD_VERSION_2"};
    };
};
```
```c
#ifdef MYMOD_ENABLED
    // Code only compiled when MyMod is loaded
#endif
```

## Credits

Style conventions referenced from [TrueDolphin's EnScript Style Guide](https://github.com/TrueDolphin/references/wiki/EnScript-(Enforce-Script)-Style-Guide).
