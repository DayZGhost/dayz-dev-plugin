# DayZ Inventory System

## InventoryLocation Types
```c
enum InventoryLocationType
{
    UNKNOWN,        // Freshly created object, no location yet
    GROUND,         // On the ground
    ATTACHMENT,     // Attached to parent entity (e.g., scope on rifle)
    CARGO,          // In cargo space of parent
    HANDS,          // In player's hands
    PROXYCARGO,     // Cargo of a large object (building, ...)
    VEHICLE,        // Player in vehicle, seat index stored
    TEMP            // 1.29+: client-side only, item held in limbo during inventory desync
}
```
Values are overwritten from C++ - always use the names. Code that `switch`es over the type should
tolerate `TEMP` on 1.29+.

## Creating Items

### In Player Inventory
```c
// Create item in any free inventory slot
EntityAI item = player.GetInventory().CreateInInventory("ItemClassName");
if (item)
{
    // Item created successfully
    item.SetHealth("", "", 100);  // Set health
}
```

### In Player Hands
```c
EntityAI item = player.GetHumanInventory().CreateInHands("ItemClassName");
```

### On the Ground
```c
vector pos = player.GetPosition();
EntityAI item = GetGame().CreateObjectEx("ItemClassName", pos, ECE_PLACE_ON_SURFACE);
```

### As Attachment
```c
// Attach magazine to weapon
EntityAI mag = weapon.GetInventory().CreateAttachment("Mag_AKM_30Rnd");
```

### In Entity Cargo
```c
EntityAI item = container.GetInventory().CreateEntityInCargo("ItemClassName");
```

## Checking Inventory Space

```c
// Can item fit in cargo?
bool canFit = entity.GetInventory().CanAddEntityInCargo(item);

// Can item be attached?
bool canAttach = entity.GetInventory().CanAddAttachment(item);

// Find any free location
InventoryLocation loc = new InventoryLocation();
if (player.GetInventory().FindFreeLocationFor(item, FindInventoryLocationType.ANY, loc))
{
    // loc now contains where the item can go
    player.GetInventory().TakeEntityToInventory(InventoryMode.SERVER, loc.GetType(), item);
}
```

## Moving Items

```c
// To player inventory (predictive - client + server)
player.PredictiveTakeEntityToInventory(FindInventoryLocationType.ANY, item);

// To player hands
player.PredictiveTakeEntityToHands(item);

// To specific location
InventoryLocation loc = new InventoryLocation();
loc.SetCargo(targetEntity, item, idx, row, col, flipped);
player.PredictiveTakeToDst(loc, item);

// Server-side move (authoritative)
player.ServerTakeEntityToInventory(item);
```

## Removing Items

```c
// Remove from inventory and delete
if (GetGame().IsServer())
{
    // Deleting removes it from its parent inventory as well
    g_Game.ObjectDelete(item);

    // or, if the item may be in the middle of an inventory operation:
    // item.DeleteSafe();
}
```

## Iterating Inventory

```c
// Get all items in cargo
int cargoCount = entity.GetInventory().GetCargo().GetItemCount();
for (int i = 0; i < cargoCount; i++)
{
    EntityAI cargoItem = entity.GetInventory().GetCargo().GetItem(i);
    if (cargoItem)
    {
        Print(cargoItem.GetType());
    }
}

// Get all attachments
int attCount = entity.GetInventory().AttachmentCount();
for (int i = 0; i < attCount; i++)
{
    EntityAI att = entity.GetInventory().GetAttachmentFromIndex(i);
    if (att)
    {
        Print(att.GetType());
    }
}

// Check if player has specific item type
bool hasItem = false;
array<EntityAI> items = new array<EntityAI>;
player.GetInventory().EnumerateInventory(InventoryTraversalType.PREORDER, items);
foreach (EntityAI invItem : items)
{
    if (invItem.IsKindOf("Bandage_Basic"))
    {
        hasItem = true;
        break;
    }
}
```

## Item Health & Condition

```c
// Get health (0 = ruined, hitpoints = pristine)
float health = item.GetHealth("", "");
float health01 = item.GetHealth01("", "");  // Normalized 0-1

// Set health
item.SetHealth("", "", 100);

// Check damage state
if (item.IsDamageDestroyed())  // Ruined
if (item.IsRuined())           // Also ruined

// Damage zones (e.g., for clothing)
float zoneHealth = item.GetHealth("Zone_Head", "Health");
item.SetHealth("Zone_Chest", "Health", 50);
```

## Quantity System

```c
// Items with quantity (food, drinks, ammo boxes)
float quantity = item.GetQuantity();
float maxQuantity = item.GetQuantityMax();

item.SetQuantity(50);
item.AddQuantity(10);

// Magazines
Magazine mag = Magazine.Cast(item);
if (mag)
{
    int ammoCount = mag.GetAmmoCount();
    mag.ServerSetAmmoCount(30);
}
```

## Inventory Events (Override in ItemBase)

```c
modded class ItemBase
{
    // Called when item is placed in inventory
    override void OnInventoryEnter(Man player)
    {
        super.OnInventoryEnter(player);
        // Item was picked up or moved into inventory
    }

    // Called when item is removed from inventory
    override void OnInventoryExit(Man player)
    {
        super.OnInventoryExit(player);
        // Item was dropped or moved out
    }

    // Called when item is moved within inventory
    override void OnMovedWithinCargo(EntityAI container)
    {
        super.OnMovedWithinCargo(container);
    }

    // Called when item is attached to parent
    override void OnWasAttached(EntityAI parent, int slot_id)
    {
        super.OnWasAttached(parent, slot_id);
    }

    // Called when item is detached from parent
    override void OnWasDetached(EntityAI parent, int slot_id)
    {
        super.OnWasDetached(parent, slot_id);
    }
}
```

## Common Patterns

### Check if Player Has Item Type
```c
bool PlayerHasItem(PlayerBase player, string className)
{
    array<EntityAI> items = new array<EntityAI>;
    player.GetInventory().EnumerateInventory(InventoryTraversalType.PREORDER, items);
    foreach (EntityAI item : items)
    {
        if (item.IsKindOf(className))
            return true;
    }
    return false;
}
```

### Count Items of Type
```c
int CountItems(PlayerBase player, string className)
{
    int count = 0;
    array<EntityAI> items = new array<EntityAI>;
    player.GetInventory().EnumerateInventory(InventoryTraversalType.PREORDER, items);
    foreach (EntityAI item : items)
    {
        if (item.IsKindOf(className))
            count++;
    }
    return count;
}
```

### Remove First Item of Type
```c
bool RemoveFirstItem(PlayerBase player, string className)
{
    array<EntityAI> items = new array<EntityAI>;
    player.GetInventory().EnumerateInventory(InventoryTraversalType.PREORDER, items);
    foreach (EntityAI item : items)
    {
        if (item.IsKindOf(className))
        {
            GetGame().ObjectDelete(item);
            return true;
        }
    }
    return false;
}
```
