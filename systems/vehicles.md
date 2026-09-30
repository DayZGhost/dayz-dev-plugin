# DayZ Vehicle System

## Vehicle Class Hierarchy
```
CarScript (extends EntityAI)
├── OffroadHatchback
├── CivilianSedan
├── Hatchback_02
├── Sedan_02
├── Truck_01_Base (V3S)
├── Offroad_02 (Sarka)
└── ExpansionVehicleBase (Expansion vehicles)
    ├── ExpansionHelicopterScript
    ├── ExpansionBoatScript
    └── ExpansionBikeScript
```

## Vehicle Config (config.cpp)

```cpp
class CfgVehicles
{
    class CarScript;

    class MyCustomCar : CarScript
    {
        scope = 2;
        displayName = "My Custom Vehicle";
        model = "\MyMod\data\mycar.p3d";

        // Crew positions
        crewsize = 4;
        crew[] = {"driver", "codriver", "cargo1", "cargo2"};

        // Physics
        class SimulationModule
        {
            drive = "DRIVE_RWD";       // RWD, FWD, AWD
            airDragFrontTotal = 0.95;

            class Steering
            {
                maxSteeringAngle = 35;
                increaseSpeed[] = {0, 45, 60, 23, 100, 12};
                decreaseSpeed[] = {0, 80, 60, 40, 90, 20};
            };

            class Throttle
            {
                reactionTime = 1.0;
                defaultThrust = 0.85;
                gentleThrust = 0.7;
                turboCoef = 4.0;
                gentleCoef = 0.75;
            };

            class Brakes
            {
                maxBrakeTorque = 4000;       // DOUBLED in 1.28!
                maxHandbrakeTorque = 3200;   // DOUBLED in 1.28!
            };

            class Engine
            {
                inertia = 0.15;
                torqueMax = 114;
                torqueRpm = 3400;
                powerMax = 53.7;
                powerRpm = 5400;
                rpmIdle = 850;
                rpmMin = 900;
                rpmClutch = 1400;
                rpmRedline = 6000;
            };

            class Gearbox
            {
                type = "GEARBOX_AUTOMATIC";   // or GEARBOX_MANUAL
                reverse = 3.526;
                ratios[] = {3.667, 2.1, 1.361, 1.0};
            };

            class Axles
            {
                class Front
                {
                    maxSteeringAngle = 35;
                    finalRatio = 4.1;
                    brakeBias = 0.6;
                    brakeForce = 4000;         // DOUBLED in 1.28!
                    wheelHubMass = 5;
                    wheelHubRadius = 0.15;
                    // NEW in 1.28:
                    wheelHubFriction = 0.1;    // Axle drag without wheels

                    class Suspension
                    {
                        stiffness = 40000;
                        compression = 2100;
                        damping = 7500;
                        travelMaxUp = 0.0882;
                        travelMaxDown = 0.0833;
                    };

                    class Wheels
                    {
                        class Left { inventorySlot = "NivaWheel_1_1"; };
                        class Right { inventorySlot = "NivaWheel_1_2"; };
                    };
                };

                class Rear
                {
                    // Similar to Front but with rear settings
                    maxSteeringAngle = 0;
                    finalRatio = 4.1;
                    brakeBias = 0.4;
                };
            };

            // NEW in 1.28: Vehicle networking mode
            useNewNetworking = 1;  // Default: 1 (uses Reforger tech)
            // Set to 0 if custom physics outside SimulationModule
        };

        // Inventory cargo
        class Cargo
        {
            itemsCargoSize[] = {10, 50};
            allowOwnedCargoManipulation = 1;
        };

        // Damage
        class DamageSystem
        {
            class GlobalHealth
            {
                class Health
                {
                    hitpoints = 1000;
                };
            };
            class DamageZones
            {
                class Engine
                {
                    class Health { hitpoints = 500; };
                    fatalInjuryCoef = -1;
                    componentNames[] = {"engine"};
                };
                class FuelTank
                {
                    class Health { hitpoints = 300; };
                    fatalInjuryCoef = -1;
                    componentNames[] = {"fueltank"};
                };
            };
        };
    };
};
```

## Vehicle Scripting

### Getting Vehicle Reference
```c
// Check if player is in vehicle
if (player.IsInVehicle())
{
    Transport transport = player.GetCommand_Vehicle().GetTransport();
    CarScript car = CarScript.Cast(transport);
    if (car)
    {
        // Work with vehicle
    }
}
```

### Vehicle State
```c
// Speed
float speed = car.GetSpeedometer();

// Fuel
float fuel = car.GetFluidFraction(CarFluid.FUEL);
car.Fill(CarFluid.FUEL, 100);  // Add fuel
car.Leak(CarFluid.FUEL, 10);   // Remove fuel

// Fluids
car.GetFluidFraction(CarFluid.OIL);
car.GetFluidFraction(CarFluid.BRAKE);
car.GetFluidFraction(CarFluid.COOLANT);

// Engine
bool engineOn = car.EngineIsOn();
car.EngineStart();
car.EngineStop();

// Doors
car.OpenDoor(0);    // Open door by index
car.CloseDoor(0);   // Close door by index
```

### Vehicle Events
```c
modded class CarScript
{
    override void OnEngineStart()
    {
        super.OnEngineStart();
        // Engine started
    }

    override void OnEngineStop()
    {
        super.OnEngineStop();
        // Engine stopped
    }

    override void EOnContact(IEntity other, Contact extra)
    {
        super.EOnContact(other, extra);
        // Collision detected
        // NOTE: Contact class changed in 1.28!
        // extra.Material1 is now SurfaceProperties, not dMaterial
    }

    override void OnUpdate(float dt)
    {
        super.OnUpdate(dt);
        // Per-frame update while vehicle is active
    }
}
```

## 1.29 Vehicle Changes (CRITICAL)

### Headlights are native now
`m_HeadlightsOn` was removed from `CarScript`; `m_HeadlightsState` and `m_RearLightType` are `int` now.
Light state lives on `Transport` (cars and boats):
```c
car.LightIsOn();     // replaces reading m_HeadlightsOn / IsScriptedLightsOn()
car.LightOn();
car.LightOff();
car.LightToggle();   // what ToggleHeadlights() calls now

modded class CarScript
{
    // Native asks before turning lights on. Vanilla requires a non-ruined battery with energy.
    override bool OnBeforeLightOn()
    {
        if (!super.OnBeforeLightOn())
            return false;
        return true; // add your own condition
    }

    // Called by native when lights need an update (visuals, reverse/brake lights)
    override void UpdateLights(int new_gear = -1)
    {
        super.UpdateLights(new_gear);
    }
}
```

### Other 1.29 changes
- New `CarScript.OnInput(float dt)` (input handling split out of `OnUpdate`)
- `Transport` gained deterministic physics helpers: `ApplyForce`, `ApplyForceAt`, `ApplyTorque`,
  `ApplyCentralImpulse`, `ApplyTorqueImpulse`, `ApplyImpulseAt`
- `EntityAI.SetRequiredSimulation(bool)` / `IsRequiredSimulation()` to control the active state of custom
  `Transport` vehicles; sleeping bodies no longer tick `EOnSimulate`/`EOnPostSimulate`
- `Transport` now gathers inputs and has dynamic collision resolution (previously only `Car`)
- `CarScript`/`BoatScript` override `GetOwnerStateType()` for Pawn state reconciliation
- `CarWheel.GetRuinedReplacement()` added
- Fixed: players sent to random coordinates when exiting vehicles with improper geometry

See `compatibility/version-129.md` for details.

## 1.28 Vehicle Changes (CRITICAL)

### Breaking Changes
1. **Brake values DOUBLED**: `maxBrakeTorque` and `maxHandbrakeTorque` must be doubled
2. **`useNewNetworking`**: Defaults to 1 (Arma Reforger networking)
3. **Contact class changed**:
   - `Material1`/`Material2` now `SurfaceProperties` (was `dMaterial`)
   - `MaterialIndex1`/`MaterialIndex2`/`Index1`/`Index2` **REMOVED**
   - `ShapeIndex1`/`ShapeIndex2` **ADDED**
   - `VelocityBefore1`/`VelocityBefore2` **ADDED**
   - `VelocityAfter1`/`VelocityAfter2` **ADDED**

### New Features
- `wheelHubFriction` parameter for axle drag without wheels
- Improved vehicle synchronization at higher ping
- Suspension remains active while vehicle is awake regardless of wheel attachment
- Reverse lights toggle correctly during gear changes
- Automatic gearbox simulation improved

### Migration Checklist
```
[ ] Double maxBrakeTorque values
[ ] Double maxHandbrakeTorque values
[ ] Double brakeForce values in Axles
[ ] Update any Contact class usage for new API
[ ] Test with useNewNetworking = 1 (default)
[ ] Set useNewNetworking = 0 if using custom physics outside SimulationModule
[ ] Update PhysicsGeomDef.MaterialName to use .bisurf paths
```
