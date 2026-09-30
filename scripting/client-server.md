# Client-Server Architecture

## Script Module Hierarchy

DayZ scripts are organized into three modules with strict access rules:

```
5_Mission/    (highest level - HUD, menus, mission logic)
    ↓ can access
4_World/      (entities, items, players, actions)
    ↓ can access
3_Game/       (game-level utilities, available everywhere)
```

**Rules:**
- Higher modules CAN access lower modules
- Lower modules CANNOT access higher modules
- `3_Game/` scripts are available everywhere (game, world, mission)
- `4_World/` scripts are available in world and mission contexts
- `5_Mission/` scripts are only available in mission context

## Server vs Client Detection

### During Runtime (After Init)
```c
if (GetGame().IsServer())
{
    // Server-side code
}

if (GetGame().IsClient())
{
    // Client-side code (WARNING: false during init!)
}

if (GetGame().IsMultiplayer())
{
    // Multiplayer context
}
```

### During Init (CRITICAL!)
```c
// WRONG - IsClient() returns FALSE during init!
if (GetGame().IsClient())
{
    // This code NEVER runs during init!
}

// RIGHT - Use IsDedicatedServer() check
if (!GetGame().IsDedicatedServer())
{
    // This runs on client AND in singleplayer
}
```

## Player Lifecycle (MissionServer)

```
1. OnInit()                    - Mission initialization
2. OnClientPrepareEvent()      - Before the character is loaded/created (DB use, spawn pos)
3. OnClientNewEvent()          - New character creation
4. OnClientRespawnEvent()      - Character respawn
5. OnClientReadyEvent()        - Existing character loaded, client ready
6. OnClientReconnectEvent()    - Player reconnected to a still-present character
7. InvokeOnConnect()           - Player connected (after new/ready)
8. OnUpdate()                  - Per-frame update (mission level)
9. OnClientDisconnectedEvent() - Player started disconnecting (logout timer)
10. PlayerDisconnected()       - Logout timer done (identity may already be deleted!)
11. InvokeOnDisconnect()       - Final disconnect processing
12. OnMissionFinish()          - Mission ending
13. OnEvent(EventType, ...)    - Generic event handler (ClientNewEventTypeID, ClientReadyEventTypeID, ...)
```

### MissionServer Key Methods
```c
modded class MissionServer
{
    override void OnInit()
    {
        super.OnInit();
        // One-time server initialization
    }

    override PlayerBase CreateCharacter(PlayerIdentity identity, vector pos, ParamsReadContext ctx, string characterName)
    {
        // Create and configure new player entity
        PlayerBase player = super.CreateCharacter(identity, pos, ctx, characterName);
        return player;
    }

    override void InvokeOnConnect(PlayerBase player, PlayerIdentity identity)
    {
        super.InvokeOnConnect(player, identity);
        // Player just connected - identity available
        string steamId = identity.GetId();
        string name = identity.GetName();
    }

    override void OnClientReadyEvent(PlayerIdentity identity, PlayerBase player)
    {
        super.OnClientReadyEvent(identity, player);
        // Player fully loaded - safe to send RPCs
    }

    override void PlayerDisconnected(PlayerBase player, PlayerIdentity identity, string uid)
    {
        // Player disconnecting - save data here
        super.PlayerDisconnected(player, identity, uid);
    }
}
```

### MissionGameplay Key Methods (Client)
```c
modded class MissionGameplay
{
    override void OnInit()
    {
        super.OnInit();
        // Client-side initialization
    }

    override void OnUpdate(float timeslice)
    {
        super.OnUpdate(timeslice);
        // Per-frame client update
    }

    override void OnKeyPress(int key)
    {
        super.OnKeyPress(key);
        // Handle key input
    }
}
```

## Communication Patterns

### 1. Vanilla ScriptRPC
```c
// === SENDING (Server -> Client) ===
void SendDataToClient(PlayerBase player, string data)
{
    ScriptRPC rpc = new ScriptRPC();
    rpc.Write(data);
    rpc.Send(player, ERPCs.RPC_USER_ACTION_MESSAGE, true, player.GetIdentity());
}

// === RECEIVING (Client) ===
// Register in MissionGameplay.OnInit or similar
override void OnRPC(PlayerIdentity sender, Object target, int rpc_type, ParamsReadContext ctx)
{
    super.OnRPC(sender, target, rpc_type, ctx);
    if (rpc_type == ERPCs.RPC_USER_ACTION_MESSAGE)
    {
        string data;
        if (ctx.Read(data))
        {
            // Process data
        }
    }
}
```

### 2. CF RPCManager (Recommended with CF)
```c
// === REGISTER (both sides, in init) ===
GetRPCManager().AddRPC("MyMod", "RPC_MyFunction", this, SingleplayerExecutionType.Both);

// === SEND ===
// Server to specific client
GetRPCManager().SendRPC("MyMod", "RPC_MyFunction",
    new Param1<string>("hello"), true, player.GetIdentity());

// Client to server
GetRPCManager().SendRPC("MyMod", "RPC_MyFunction",
    new Param1<string>("hello"), true, null);

// === HANDLER ===
void RPC_MyFunction(CallType type, ParamsReadContext ctx, PlayerIdentity sender, Object target)
{
    Param1<string> data;
    if (!ctx.Read(data)) return;

    if (type == CallType.Server)
    {
        // Running on server - sender is the calling player
        // VALIDATE sender identity!
    }
    else if (type == CallType.Client)
    {
        // Running on client
    }
}
```

### 3. RegisterNetSyncVariable
```c
class MyItem extends ItemBase
{
    protected int m_SyncedValue;
    protected bool m_SyncedFlag;

    void MyItem()
    {
        // Register in constructor - integer with range
        RegisterNetSyncVariableInt("m_SyncedValue", 0, 100);
        RegisterNetSyncVariableBool("m_SyncedFlag");
        // Also: RegisterNetSyncVariableFloat("var", min, max, precision)
    }

    // Call on server when value changes
    void SetSyncedValue(int val)
    {
        if (GetGame().IsServer())
        {
            m_SyncedValue = val;
            SetSynchDirty();  // Triggers sync to clients
        }
    }

    // Called on clients when synced values arrive
    override void OnVariablesSynchronized()
    {
        super.OnVariablesSynchronized();
        // m_SyncedValue and m_SyncedFlag are now up to date
        UpdateVisuals();
    }
}
```

### 4. CF NetworkedVariables
```c
class MyModule : CF_ModuleWorld
{
    // Declare networked variable
    CF_NetworkedVariable<int> m_Score;

    override void OnInit()
    {
        super.OnInit();
        m_Score = new CF_NetworkedVariable<int>(0);
    }

    void SetScore(int val)
    {
        m_Score.Set(val);  // Automatically synced
    }
}
```

## Security Best Practices

1. **NEVER trust client data** - Always validate on server
2. **Check player identity** in every server RPC handler
3. **Validate distances** - Ensure player is close enough for actions
4. **Rate limit** - Prevent RPC spam
5. **Validate item existence** - Check items exist before operations
6. **Use server authoritative** model - Server decides, client renders

```c
// Example: Secure RPC handler
void RPC_GiveItem(CallType type, ParamsReadContext ctx, PlayerIdentity sender, Object target)
{
    if (type != CallType.Server) return;  // Server only
    if (!sender) return;                   // Must have identity

    Param1<string> data;
    if (!ctx.Read(data)) return;

    // Find the actual player from identity
    PlayerBase player = PlayerBase.Cast(sender.GetPlayer());
    if (!player) return;
    if (!player.IsAlive()) return;

    // Validate the request
    string itemClass = data.param1;
    if (!GetGame().IsKindOf(itemClass, "ItemBase")) return;

    // Execute
    player.GetInventory().CreateInInventory(itemClass);
}
```
