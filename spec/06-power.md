---
section: 06-power
applies_to: [Win10, Win11, Server]
order: 60
risk: low
ac_safe: true
---

# Power plan + processor states

## Activate Ultimate Performance

```powershell
$out = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1 | Out-String
if ($out -match "([a-fA-F0-9-]{36})") {
    powercfg -setactive $matches[1]
} else {
    # Fallback for Home/older SKUs
    powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c   # High Performance
}
```

## Processor settings — no throttle

```powershell
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPCONCURRENCY 100
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE 4
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTPOL 100
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFINCPOL 2
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFDECPOL 1
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFINCTHRESHOLD 10
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFDECTHRESHOLD 80
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFINCTIME 1
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFDECTIME 1
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFAUTONOMOUS 0
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR IDLEDISABLE 1
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR LATENCYHINTPERF 99
```

## PCIe ASPM off

```powershell
powercfg -setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0
```

## USB selective suspend off

```powershell
powercfg -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
```

## Disk timeout off (NVMe)

```powershell
powercfg -setacvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0
```

## Display + sleep off

```powershell
powercfg -setacvalueindex SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 0
powercfg -setacvalueindex SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 0
powercfg -setacvalueindex SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE 0
```

## Apply + disable hibernate

```powershell
powercfg -setactive SCHEME_CURRENT
powercfg -h off
```

## Modern Standby off (Win11)

Path: `HKLM:\SYSTEM\CurrentControlSet\Control\Power`

| Name | Type | Value | Applies |
|------|------|-------|---------|
| PlatformAoAcOverride | DWord | 0 | Win11 22H2+ |
| HibernateEnabled | DWord | 0 | Win10+Win11 |
| CsEnabled | DWord | 0 | Win11 |
