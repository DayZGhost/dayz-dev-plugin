# DayZ Action System

## Action Hierarchy

```
ActionBase
├── ActionSingleUseBase          # Instant one-shot actions
├── ActionContinuousBase         # Hold to complete (progress bar)
├── ActionInteractBase           # Press to interact (F key)
└── FirearmActionBase            # Weapon-specific actions
```

## Creating a Custom Action

### Step 1: Define the Action Class

```c
// scripts/4_World/Actions/MyCustomAction.c

class MyCustomAction extends ActionInteractBase
{
    // Define conditions for when action appears
    override void CreateConditionComponents()
    {
        // Item in hand requirement (CCINone = no item needed)
        m_ConditionItem = new CCINone();

        // Target requirement (CCTObject = must target an object)
        m_ConditionTarget = new CCTObject(UAMaxDistances.DEFAULT);
    }

    // Display text
    override string GetText()
    {
        return "Do Something";
    }

    // When is this action available?
    override bool ActionCondition(PlayerBase player, ActionTarget target, ItemBase item)
    {
        // Check any custom conditions
        Object targetObj = target.GetObject();
        if (!targetObj) return false;

        // Example: only on specific item type
        if (targetObj.IsKindOf("MyTargetItem"))
            return true;

        return false;
    }

    // Can this action be interrupted?
    override bool CanBeUsedInVehicle() { return false; }

    // Execute on server
    override void OnExecuteServer(ActionData action_data)
    {
        PlayerBase player = action_data.m_Player;
        Object target = action_data.m_Target.GetObject();

        // Server-side logic here
        // e.g., modify item, spawn something, update state
    }

    // Execute on client (optional - for UI/effects)
    override void OnExecuteClient(ActionData action_data)
    {
        // Client-side effects (sounds, particles, UI)
    }
}
```

### Step 2: Register the Action

```c
// scripts/4_World/ModdedClasses/MyModdedPlayer.c

modded class PlayerBase
{
    override void SetActions(out TInputActionMap InputActionMap)
    {
        super.SetActions(InputActionMap);
        AddAction(MyCustomAction, InputActionMap);
    }
}
```

### Alternative: Register on Specific Item
```c
modded class Inventory_Base
{
    override void SetActions()
    {
        super.SetActions();
        AddAction(MyCustomAction);
    }
}

// Or on a specific item class
modded class KitchenKnife
{
    override void SetActions()
    {
        super.SetActions();
        AddAction(MyKnifeAction);
    }
}
```

## Condition Components

### Item Conditions (m_ConditionItem)
| Class | Description |
|-------|-------------|
| `CCINone` | No item in hand required |
| `CCINotPresent` | Must NOT have item in hand |
| `CCINonRuined` | Item must not be ruined |
| `CCIWaterBottle` | Must be a water container |

### Target Conditions (m_ConditionTarget)
| Class | Description |
|-------|-------------|
| `CCTNone` | No target required |
| `CCTObject(dist)` | Must target an object within distance |
| `CCTSelf` | Target is the player themselves |
| `CCTCursor(dist)` | Cursor-based targeting |
| `CCTMan(dist)` | Must target another player |
| `CCTWaterSurface` | Must target water |

## Continuous Actions (Hold Actions)

```c
// Duration is defined by the callback's action component, not by a method on the action
class MyContinuousActionCB : ActionContinuousBaseCB
{
    override void CreateActionComponent()
    {
        m_ActionData.m_ActionComponent = new CAContinuousTime(5.0);  // seconds (see UATimeSpent for vanilla values)
    }
}

class MyContinuousAction extends ActionContinuousBase
{
    void MyContinuousAction()
    {
        m_CallbackClass = MyContinuousActionCB;
        m_CommandUID = DayZPlayerConstants.CMD_ACTIONFB_INTERACT;
        m_FullBody = true;
        m_StanceMask = DayZPlayerConstants.STANCEMASK_ERECT | DayZPlayerConstants.STANCEMASK_CROUCH;
    }

    override void CreateConditionComponents()
    {
        m_ConditionItem = new CCINone();
        m_ConditionTarget = new CCTObject(UAMaxDistances.DEFAULT);
    }

    override string GetText() { return "Building..."; }

    override bool ActionCondition(PlayerBase player, ActionTarget target, ItemBase item)
    {
        return true;
    }

    // Called when action completes successfully
    override void OnFinishProgressServer(ActionData action_data)
    {
        // Action completed on server
        PlayerBase player = action_data.m_Player;
        // Do the thing
    }

    // Called if action is interrupted
    override void OnEndServer(ActionData action_data)
    {
        super.OnEndServer(action_data);
        // Cleanup if needed
    }
}
```

## Single Use Actions (Instant)

```c
class MyInstantAction extends ActionSingleUseBase
{
    override void CreateConditionComponents()
    {
        m_ConditionItem = new CCINonRuined();  // Needs non-ruined item
        m_ConditionTarget = new CCTNone();     // No target needed
    }

    override string GetText() { return "Use Item"; }

    override bool ActionCondition(PlayerBase player, ActionTarget target, ItemBase item)
    {
        return (item && !item.IsDamageDestroyed());
    }

    override void OnExecuteServer(ActionData action_data)
    {
        ItemBase item = action_data.m_MainItem;
        PlayerBase player = action_data.m_Player;

        // Use the item
        ApplyEffect(player);

        // Optionally destroy the item after use
        if (item)
        {
            item.SetQuantity(item.GetQuantity() - 1);
            if (item.GetQuantity() <= 0)
            {
                GetGame().ObjectDelete(item);
            }
        }
    }
}
```

## ActionData Members

| Member | Type | Description |
|--------|------|-------------|
| `m_Player` | `PlayerBase` | The player performing the action |
| `m_MainItem` | `ItemBase` | Item in player's hands |
| `m_Target` | `ActionTarget` | The targeted object/entity |
| `m_Target.GetObject()` | `Object` | The actual target object |
| `m_Target.GetParent()` | `Object` | Parent of target |

## Action Lifecycle

```
ActionCondition() → true
  → CreateActionComponent()
    → OnStartServer() / OnStartClient()
      → [Progress for continuous actions]
        → OnFinishProgressServer() (continuous only)
      → OnExecuteServer() / OnExecuteClient() (single/interact)
    → OnEndServer() / OnEndClient()
```

## Common Patterns

### Action on Specific Item with Target
```c
class ActionRepairWithCB : ActionContinuousBaseCB
{
    override void CreateActionComponent()
    {
        m_ActionData.m_ActionComponent = new CAContinuousTime(8.0);
    }
}

class ActionRepairWith extends ActionContinuousBase
{
    void ActionRepairWith()
    {
        m_CallbackClass = ActionRepairWithCB;
        m_CommandUID = DayZPlayerConstants.CMD_ACTIONFB_INTERACT;
        m_FullBody = true;
    }

    override void CreateConditionComponents()
    {
        m_ConditionItem = new CCINonRuined();   // Need tool in hand
        m_ConditionTarget = new CCTObject(2.0); // Target within 2m
    }

    override bool ActionCondition(PlayerBase player, ActionTarget target, ItemBase item)
    {
        if (!item || !target) return false;

        // Must have repair kit in hand
        if (!item.IsKindOf("RepairKit")) return false;

        // Target must be damageable
        EntityAI targetEntity = EntityAI.Cast(target.GetObject());
        if (!targetEntity) return false;
        if (targetEntity.GetHealth01("", "") >= 1.0) return false;  // Already pristine

        return true;
    }

    override void OnFinishProgressServer(ActionData action_data)
    {
        EntityAI target = EntityAI.Cast(action_data.m_Target.GetObject());
        if (target)
        {
            target.SetHealth("", "", target.GetHealth("", "") + 25);
        }

        // Degrade the repair kit
        ItemBase item = action_data.m_MainItem;
        if (item)
        {
            item.AddQuantity(-1);
        }
    }
}
```
