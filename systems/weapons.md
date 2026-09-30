# DayZ Weapon System

## Weapon Class Hierarchy
```
Weapon_Base
├── Rifle_Base
│   ├── BoltActionRifle_Base (Mosin, CR527, etc.)
│   └── BoltRifle_Base
├── Pistol_Base
│   ├── Pistol_CZ75, Pistol_Deagle, etc.
│   └── Derringer_Base
└── Weapon_BaseRifle
    ├── AKM, M4A1, FAL, etc.
    └── SMG variants
```

## Weapon Config (config.cpp)

```cpp
class CfgWeapons
{
    class Rifle_Base;

    class MyCustomRifle : Rifle_Base
    {
        scope = 2;
        displayName = "My Custom Rifle";
        descriptionShort = "A custom weapon";
        model = "\MyMod\data\mycustomrifle.p3d";
        weight = 3600;                    // grams

        // Weapon properties
        chamberSize = 1;
        chamberedRound = "";
        magazines[] = {"Mag_MyRifle_30Rnd"};
        chamberableFrom[] = {"Ammo_556x45"};

        // Firing
        modes[] = {"Single", "Fullauto"};
        class Single
        {
            begin1[] = {"MyRifle_Shot_SoundSet", 1};
            soundBegin[] = {"begin1", 1};
            reloadTime = 0.1;
            dispersion = 0.002;
            aiRateOfFire = 3;
        };
        class Fullauto : Single
        {
            reloadTime = 0.075;
            burst = 0;
        };

        // Recoil
        recoilModifier[] = {1, 1, 1};

        // Optics/Attachments
        class Attachments
        {
            class Slot_Optics
            {
                slotName = "weaponOptics";
                displayName = "Optics";
            };
            class Slot_Magazine
            {
                slotName = "magazine";
            };
            class Slot_Suppressor
            {
                slotName = "suppressorImpro";
            };
        };

        class DamageSystem
        {
            class GlobalHealth
            {
                class Health
                {
                    hitpoints = 400;
                };
            };
        };
    };
};
```

## Magazine Config

```cpp
class CfgMagazines
{
    class Magazine_Base;

    class Mag_MyRifle_30Rnd : Magazine_Base
    {
        scope = 2;
        displayName = "30Rnd Mag";
        model = "\MyMod\data\mag30.p3d";
        weight = 200;
        itemSize[] = {1, 2};
        count = 30;                       // Capacity
        ammo = "Bullet_556x45";           // Ammo type
        tracersEvery = 0;
        lastRoundsTracer = 0;

        class DamageSystem
        {
            class GlobalHealth
            {
                class Health
                {
                    hitpoints = 100;
                };
            };
        };
    };
};
```

## Weapon FSM (Finite State Machine)

The weapon system uses a state machine for chambering, firing, and reloading.

### Key States
| State | Description |
|-------|-------------|
| `Empty` | No round chambered, no magazine |
| `Loaded` | Round chambered, ready to fire |
| `Jammed` | Weapon jammed, needs clearing |
| `Reloading` | Magazine swap in progress |
| `Chambering` | Bolt cycling/chambering round |

### Weapon Flags
```c
enum WeaponWithAmmoFlags
{
    NONE = 0,
    CHAMBER = 1,          // Chamber a round
    CHAMBER_RNG = 2,      // Random chance to chamber
    MAGAZINE = 4,          // Attach magazine
    MAGAZINE_RNG = 8,      // Random chance for magazine
    QUANTITY_RNG = 16,     // Random ammo quantity
    MAX = 32
}
```

## Scripting Weapons

### Getting Player's Current Weapon
```c
EntityAI weaponEntity = player.GetItemInHands();
Weapon_Base weapon = Weapon_Base.Cast(weaponEntity);
if (weapon)
{
    // Check ammo
    int ammoCount = weapon.GetInternalMagazineCartridgeCount(0);

    // Check magazine
    Magazine mag = weapon.GetMagazine(0);
    if (mag)
    {
        int magAmmo = mag.GetAmmoCount();
    }

    // Check if jammed
    if (weapon.IsJammed())
    {
        // Handle jam
    }
}
```

### Weapon Events
```c
modded class Weapon_Base
{
    override void OnFire(int muzzle_index)
    {
        super.OnFire(muzzle_index);
        // Called when weapon fires
    }

    override void EEFired(int muzzleType, int mode, string ammoType)
    {
        super.EEFired(muzzleType, mode, ammoType);
        // Called after firing event
    }

    override bool CanFire()
    {
        if (!super.CanFire()) return false;
        // Custom fire conditions
        return true;
    }
}
```

## Firearm Actions
```
FirearmActionBase
├── FirearmActionLoadBullet
├── FirearmActionLoadMultiBullet
├── FirearmActionMechanicManipulate
├── FirearmActionAttachMagazine
├── FirearmActionDetachMagazine
└── FirearmActionChamberFromAttMag
```

## 1.29 Weapon Changes

- **New weapon**: SCR17 (`SCARH_Base : RifleBoltLock_Base`, recoil class `ScarhRecoil`) plus black/tan variants,
  20rd magazine, buttstocks and Holo Sights variants (Road to Badlands updates)
- **Per-class type objects**: `Weapon_BaseType : WeaponType : ItemBaseType`, `MagazineType`, `ItemOpticsType`
  (2D optics textures/materials are set through `ItemOpticsType`) - see `compatibility/version-129.md`
- **Assault rifle and pistol gunshot sounds reworked**; melee damage for crafted/blunt weapons increased
- **Known issue (1.29.163709)**: bolt-action weapons can glitch out of hands when reloading; Derringer cannot be
  reloaded by holding R

## 1.28 Weapon Changes

- **Weapon raise/pullback mechanic reworked** - New "pullback" state when weapons contact obstacles
- **Global recoil/dispersion rebalance** - Sway decreased, recoil slightly increased, dispersion moderately increased
- **Prone sway reduction** - Sway decreased when prone
- **Scope damage states** - Scopes show cracked glass when damaged
- **Illuminated reticles** - Some scopes now support illumination
- **Muzzle flash size reduced** for better visibility
