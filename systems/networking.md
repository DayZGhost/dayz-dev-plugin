# DayZ Networking Systems

## Overview

DayZ provides multiple networking mechanisms, from vanilla ScriptRPC to CF's RPCManager and NetworkedVariables. Choose based on your mod's dependencies.

## 1. Vanilla ScriptRPC

The built-in RPC system. No mod dependencies required.

### Sending RPCs
```c
// Server -> Specific Client
void SendToClient(PlayerBase player, int rpcId, string data)
{
    ScriptRPC rpc = new ScriptRPC();
    rpc.Write(data);
    rpc.Send(player, rpcId, true, player.GetIdentity());
}

// Server -> All Clients
void SendToAll(int rpcId, float value)
{
    ScriptRPC rpc = new ScriptRPC();
    rpc.Write(value);
    // Send to null target with guaranteed delivery
    rpc.Send(null, rpcId, true);
}

// Client -> Server
void SendToServer(PlayerBase player, int rpcId, int data)
{
    ScriptRPC rpc = new ScriptRPC();
    rpc.Write(data);
    rpc.Send(player, rpcId, true);
}
```

### Receiving RPCs (on entities)
```c
modded class PlayerBase
{
    override void OnRPC(PlayerIdentity sender, int rpc_type, ParamsReadContext ctx)
    {
        super.OnRPC(sender, rpc_type, ctx);

        switch (rpc_type)
        {
            case MY_RPC_ID:
            {
                string data;
                if (ctx.Read(data))
                {
                    ProcessData(data);
                }
                break;
            }
        }
    }
}
```

### Writing Multiple Values
```c
ScriptRPC rpc = new ScriptRPC();
rpc.Write(intValue);      // int
rpc.Write(floatValue);    // float
rpc.Write(stringValue);   // string
rpc.Write(boolValue);     // bool
rpc.Write(vectorValue);   // vector
rpc.Send(target, rpcId, true, identity);

// Reading (same order!)
int intVal; ctx.Read(intVal);
float floatVal; ctx.Read(floatVal);
string strVal; ctx.Read(strVal);
bool boolVal; ctx.Read(boolVal);
vector vecVal; ctx.Read(vecVal);
```

## 2. CF RPCManager (Recommended with Community Framework)

Provides named RPCs with automatic cross-mod namespacing.

### Setup
```c
class MyModRPCHandler
{
    void MyModRPCHandler()
    {
        // Register RPCs (do this in constructor or init)
        GetRPCManager().AddRPC("MyMod", "RPC_SendData", this, SingleplayerExecutionType.Both);
        GetRPCManager().AddRPC("MyMod", "RPC_RequestData", this, SingleplayerExecutionType.Server);
    }

    // Server-bound RPC handler
    void RPC_RequestData(CallType type, ParamsReadContext ctx, PlayerIdentity sender, Object target)
    {
        if (type != CallType.Server) return;
        if (!sender) return;

        Param1<string> data;
        if (!ctx.Read(data)) return;

        // Process request, send response
        string response = ProcessRequest(data.param1);

        // Send back to requesting client
        GetRPCManager().SendRPC("MyMod", "RPC_SendData",
            new Param1<string>(response), true, sender);
    }

    // Client-side RPC handler
    void RPC_SendData(CallType type, ParamsReadContext ctx, PlayerIdentity sender, Object target)
    {
        if (type != CallType.Client) return;

        Param1<string> data;
        if (!ctx.Read(data)) return;

        // Update client-side display
        UpdateUI(data.param1);
    }
}
```

### Sending with Params
```c
// Single parameter
GetRPCManager().SendRPC("MyMod", "RPC_Name",
    new Param1<string>("value"), true, identity);

// Two parameters
GetRPCManager().SendRPC("MyMod", "RPC_Name",
    new Param2<string, int>("value", 42), true, identity);

// Three parameters
GetRPCManager().SendRPC("MyMod", "RPC_Name",
    new Param3<string, int, float>("value", 42, 3.14), true, identity);

// To server (identity = null)
GetRPCManager().SendRPC("MyMod", "RPC_Name",
    new Param1<string>("value"), true, null);
```

## 3. RegisterNetSyncVariable (Vanilla Entity Sync)

Automatically syncs entity member variables from server to clients.

### Supported Types
```c
RegisterNetSyncVariableInt("m_VarName", min, max);           // int with range
RegisterNetSyncVariableBool("m_VarName");                     // bool
RegisterNetSyncVariableFloat("m_VarName", min, max, precision); // float with precision
```
> Before 1.29.163451, quantized floats whose range + precision needed more than 32 bits were synced
> incorrectly (T198078). Keep range/precision reasonable if you must support older servers.

### Complete Example
```c
class MySyncedItem extends ItemBase
{
    protected int m_State;        // 0-10
    protected bool m_IsActive;
    protected float m_Temperature; // -50 to 100

    void MySyncedItem()
    {
        RegisterNetSyncVariableInt("m_State", 0, 10);
        RegisterNetSyncVariableBool("m_IsActive");
        RegisterNetSyncVariableFloat("m_Temperature", -50, 100, 2); // 2 decimal precision
    }

    // Server-side setters
    void SetState(int state)
    {
        if (!GetGame().IsServer()) return;
        m_State = state;
        SetSynchDirty();  // MUST call to trigger sync
    }

    void SetActive(bool active)
    {
        if (!GetGame().IsServer()) return;
        m_IsActive = active;
        SetSynchDirty();
    }

    // Client-side receiver
    override void OnVariablesSynchronized()
    {
        super.OnVariablesSynchronized();
        // All registered vars are now up to date
        UpdateVisuals();
    }

    void UpdateVisuals()
    {
        if (m_IsActive)
        {
            // Show active state
        }
    }
}
```

### Precision Notes
- Int: Uses bit packing based on min/max range
- Float: `precision` parameter controls decimal places (higher = more bits used)
- Bool: Uses 1 bit
- Call `SetSynchDirty()` ONCE after changing multiple vars (batches the sync)

## 4. CF NetworkedVariables

Higher-level abstraction over CF's networking layer.

```c
class MyModule : CF_ModuleWorld
{
    CF_NetworkedVariable<int> m_GlobalScore;
    CF_NetworkedVariable<string> m_ServerMessage;

    override void OnInit()
    {
        super.OnInit();
        m_GlobalScore = new CF_NetworkedVariable<int>(0);
        m_ServerMessage = new CF_NetworkedVariable<string>("");
    }

    void SetScore(int val)
    {
        m_GlobalScore.Set(val);  // Automatically synced to all clients
    }
}
```

**Note:** CF NetworkedVariables have a **nesting depth limit** - don't nest them too deeply in complex data structures.

## 5. CF Modules

Event-driven modules that register with the CF module system.

```c
[CF_RegisterModule(MyModule)]
class MyModule : CF_ModuleWorld
{
    override void OnInit()
    {
        super.OnInit();
        // Module initialization
    }

    override void OnUpdate(CF_EventUpdateArgs args)
    {
        // Called every frame - use args.DeltaTime for timing
        // Note: In 1.28+ avoid creating new CF_EventUpdateArgs in OnUpdate loops
    }

    override void OnMissionStart(Class sender, CF_EventArgs args)
    {
        // Mission started
    }

    override void OnMissionFinish(Class sender, CF_EventArgs args)
    {
        // Mission ending - save data
    }

    override void OnClientReady(Class sender, CF_EventArgs args)
    {
        // Client fully loaded
    }
}
```

## Choosing a Networking Approach

| Approach | Dependencies | Best For |
|----------|-------------|----------|
| ScriptRPC | None (vanilla) | Simple messages, wide compatibility |
| CF RPCManager | Community Framework | Named RPCs, multi-mod environments |
| NetSyncVariable | None (vanilla) | Entity state synchronization |
| CF NetworkedVariables | Community Framework | Module-level state sync |
| CF Modules | Community Framework | Event-driven server logic |
