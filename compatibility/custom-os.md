---
profile: CustomOS
applies_to: [AtlasOS, Tiny11, GhostSpectre, ReviOS]
---

# Custom OS overrides

When Claude detects a custom Windows build, many tweaks are already in place. Use this delta to avoid re-applying / fighting the build.

## AtlasOS (detected via `HKLM:\SOFTWARE\AtlasOS`)

Already applied by Atlas:
- §15 Services: most bloat services already disabled or removed
- §14 Telemetry: most telemetry off via policy
- §13 Visual Effects: best-performance preset already set
- §12 Game DVR: disabled
- §06 Power: high-performance plan, sometimes Ultimate Performance

Claude should:
- Mark Atlas-managed items as `already-applied` in the log, don't fight them
- Still apply: §01 Network TCP, §02 NIC, §04 MMCSS Games, §07 GPU HAGS+MSI, §17 (only if user opts in)
- Skip: removing services Atlas already removed (Get-Service will return null, log [ABSENT])

## Tiny11 (detected via `HKLM:\SOFTWARE\Tiny11`)

Already applied by Tiny11:
- §15 Services: aggressive removal of Edge, OneDrive, Cortana, telemetry
- §14 Telemetry: most off
- Game Pass / Xbox usually still installed unless "Tiny11 Core" — check `Get-AppxPackage *XboxGamePass*`

Claude should:
- Same delta logic as Atlas
- Don't try to reinstall removed components

## Ghost Spectre (detected via `HKLM:\SOFTWARE\GhostSpectre`)

Spectre Superlite removes many Windows apps. Telemetry already off. Game DVR off. Power plan varies.

Claude should:
- Apply §01-§13, §14 partial (most already done)
- §16 FiveM: works the same
- §17: works the same — Spectre doesn't manage HVCI

## ReviOS (detected via `HKLM:\SOFTWARE\ReviOS`)

ReviOS focuses on gaming performance. Most §15 services already disabled. §07 GPU + §06 Power already tuned.

Claude should:
- Verify don't over-write Revi's tuning where it differs from spec — the spec values win when they're more aggressive
- Don't touch ReviOS's custom power plan if it's already named "ReviOS" — set Ultimate Performance instead and let Revi's plan stay available

## Server SKU

Detected via `(Get-CimInstance Win32_OperatingSystem).Caption -match "Server"`.

Apply with these adjustments:
- §12 Game DVR: skip (no Xbox Game Bar on Server)
- §06 Power: Ultimate Performance plan typically already available
- §07 GPU: HAGS usually not relevant (Server is rarely a game host on a desktop GPU)
- §15 Services: be extra careful — Server roles like AD/DNS/DHCP must NEVER touch additional services

## Generic "already-applied" detection

For any custom OS, before applying a service disable:

```powershell
$svc = Get-Service -Name $name -ErrorAction SilentlyContinue
if (-not $svc) {
    # Service doesn't exist on this build — it was removed
    Write-Host "[ABSENT] $name — already removed by custom build"
    continue
}
if ($svc.StartType -eq 'Disabled') {
    Write-Host "[NOOP] $name — already disabled"
    continue
}
```

For registry keys, read-before-write:

```powershell
$current = (Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue).$name
if ($current -eq $targetValue) {
    Write-Host "[NOOP] $path!$name — already $targetValue"
    continue
}
```

This keeps the log honest and avoids "apply -> noop -> apply -> noop" thrashing.
