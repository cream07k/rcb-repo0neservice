---
section: 07-gpu
applies_to: [Win10, Win11]
order: 70
risk: low
ac_safe: true
---

# GPU scheduling, MSI mode, vendor tweaks

## Hardware GPU Scheduling (HAGS) — Win10 2004+ / Win11

Path: `HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers`

| Name | Type | Value | Note |
|------|------|-------|------|
| HwSchMode | DWord | 2 | 2=on, 1=off. Skip on Win10 <2004 |
| TdrDelay | DWord | 60 | 60s GPU timeout (safe value) |
| TdrDdiDelay | DWord | 60 | |

NOTE: TdrLevel intentionally NOT touched in standard profile. Only §17 (advanced) modifies it.

## GPU MSI mode (interrupt latency reduction)

For each display device, enable MSI:

```powershell
Get-PnpDevice -Class Display | Where-Object {$_.Status -eq 'OK'} | ForEach-Object {
    $p = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    Set-ItemProperty -Path $p -Name "MSISupported" -Value 1 -Type DWord -Force

    $aff = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.InstanceId)\Device Parameters\Interrupt Management\Affinity Policy"
    if (-not (Test-Path $aff)) { New-Item -Path $aff -Force | Out-Null }
    Set-ItemProperty -Path $aff -Name "DevicePriority" -Value 3 -Type DWord -Force
}
```

## NVIDIA registry (if NVIDIA detected)

Path: `HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm`

| Name | Type | Value |
|------|------|-------|
| PowerMizerEnable | DWord | 1 |
| PowerMizerLevel | DWord | 1 |
| PowerMizerLevelAC | DWord | 1 |
| PerfLevelSrc | DWord | 0x2222 |
| DisableDynamicPstate | DWord | 1 |
| RMHdcpKeyglobZero | DWord | 1 |
| RMDeferredSwitching | DWord | 1 |

## AMD registry (if AMD detected)

Iterate `HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000`, `0001`, ... until no key:

| Name | Type | Value |
|------|------|-------|
| EnableUlps | DWord | 0 |
| EnableUlps_NA | DWord | 0 |
| PP_ThermalAutoThrottlingEnable | DWord | 0 |
| PP_GPUPowerDownEnable | DWord | 0 |
| DisableDMACopy | DWord | 1 |

## Per-app GPU preference for FiveM

Path: `HKCU:\Software\Microsoft\DirectX\UserGpuPreferences`

| Name | Type | Value |
|------|------|-------|
| `<full path to FiveM.exe>` | String | "GpuPreference=2;" |

GpuPreference=2 = High Performance (dGPU on hybrid laptops).

## DWM (Desktop Window Manager) tuning

Path: `HKCU:\Software\Microsoft\Windows\DWM`

| Name | Type | Value |
|------|------|-------|
| DisallowAnimations | DWord | 1 |
| EnableAeroPeek | DWord | 0 |
| AlwaysHibernateThumbnails | DWord | 0 |
