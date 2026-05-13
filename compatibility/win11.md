---
profile: Win11
applies_to_builds: [22000, 22621, 22631, 26100, 26200]
---

# Windows 11 overrides

## Add on Win11

- §06 Power: also set `PlatformAoAcOverride = 0` to fully disable Modern Standby
- §06 Power: `CsEnabled = 0` (Connected Standby disable)
- §07 GPU: HAGS always available — apply unconditionally
- §15 Services: also disable `WaaSMedicSvc` (Update Medic Service — buggy on 22H2+)

## Win11 24H2 (build 26100+) specifics

- `DODownloadMode = 0` registry may be overridden by Settings UI — also set via PolicyManager:
  ```powershell
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\DeliveryOptimization\DODownloadMode" -Name value -Value 0 -Type DWord -Force
  ```
- Game Bar `UseNexusForGameBarEnabled` was renamed to `UseNexus` in some builds — set both for safety

## Win11 sudo (if installed)

- `HKLM:\SYSTEM\CurrentControlSet\Control\Sudo!Enabled = 0` if user doesn't use Win11 sudo

## Pinned apps cleanup (optional UI tweak)

```powershell
# Remove pinned default apps from Start menu (24H2)
$startLayout = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\TempState"
Remove-Item "$startLayout\*.tmp" -Force -ErrorAction SilentlyContinue
```

## Apply anyway (same as Win10)

- §01-§05 Network/QoS/MMCSS/CPU: identical
- §08-§14 Memory/NTFS/Input/Display/Game DVR/Visual/Telemetry: identical
- §15 Services: same list (with WaaSMedicSvc addition above)
