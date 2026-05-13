---
section: 16-fivem
applies_to: [Win10, Win11]
order: 160
risk: none
ac_safe: true
opt_in: true
---

# FiveM client + server config (user opt-in)

Only apply if user confirms FiveM is the target.

## Client citizen.cfg

Path: `%LOCALAPPDATA%\FiveM\FiveM.app\citizen.cfg`

```
sv_pure_verify 0
con_disableNonImportantTraces 1
net_packetWindowSize 1500
net_compressionThreshold 1200
profile_preferDefaultSpawnpoint 1
profile_singleplayer_disablestream 1
net_clientUpdateRate 50
cl_inputBufferSize 1
cl_predictBuffer 1
```

## FiveM.exe runtime priority

After FiveM launches, raise process priority to High so input/anim thread gets CPU first. Run on next launch via:

```powershell
$p = Get-Process FiveM -ErrorAction SilentlyContinue
if ($p) { $p | ForEach-Object { try { $_.PriorityClass = 'High' } catch {} } }
```

Skip RealTime priority — it starves OS thread and causes audio crackle.

## Client-side density / LOD resource

Create resource at `<server-resources>/perf/`:

**fxmanifest.lua**
```lua
fx_version 'cerulean'
game 'gta5'
client_script 'client.lua'
```

**client.lua**
```lua
CreateThread(function()
    while true do
        Wait(0)
        SetPedDensityMultiplierThisFrame(0.4)
        SetVehicleDensityMultiplierThisFrame(0.4)
        SetRandomVehicleDensityMultiplierThisFrame(0.4)
        SetParkedVehicleDensityMultiplierThisFrame(0.3)
        SetScenarioPedDensityMultiplierThisFrame(0.3, 0.3)
        SetGarbageTrucks(false)
        SetRandomBoats(false)
        SetCreateRandomCops(false)
        SetCreateRandomCopsNotOnScenarios(false)
        SetCreateRandomCopsOnScenarios(false)
    end
end)

CreateThread(function()
    while true do
        Wait(2000)
        SetPedLodMultiplier(0.5)
        SetEntityLoadDistance(150.0)
    end
end)
```

Add to `server.cfg`:
```
ensure perf
```

## Server.cfg recommendations

```
set onesync on
set onesync_population true
set onesync_workaround763185 true
set onesync_distanceCullVehicles true
sv_maxClients 64
set sv_enforceGameBuild 2944
set sv_maxPacketsPerSecond 4096
set sv_routingbucketCount 64
```
