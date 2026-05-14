# rcb-repo0neservice

Windows performance + input-latency optimizer for FiveM / RedM. Applies the spec in `APPLY.md` — registry, services, BCD kernel edits, FiveM IFEO priority, daemon + scheduled task, citizen.cfg cvars.

## Two install paths

### A. GUI installer (double-click)

Download `WinPerfInstaller.exe`, double-click → UAC → modern browser UI shows live progress. Reboot when finished.

- Dark theme, animated progress, 23-stage pipeline visible
- All work runs in a background runspace; HTTP server on a random loopback port
- Backup written to `C:\WinPerf-Backup\backup-<ts>.json` for rollback reference

To enable the Hyper-V kill (breaks Vanguard on Win11 22H2+):
```powershell
$env:WINPERF_DISABLE_HYPERV='1'; .\WinPerfInstaller.exe
```

### B. Headless / Claude-driven

```
ติดตั้ง https://github.com/cream07k/rcb-repo0neservice
```

Paste into Claude Code on Windows. Claude reads `APPLY.md` + runs `install.ps1` (self-elevates). Streaming log at `C:\WinPerf-Backup\install-<ts>.log`. Reboot once after.

## What it changes

`APPLY.md` is the single source of truth — every value, every path, every type.

## Files

- `APPLY.md` — spec (only thing that matters)
- `WinPerfInstaller.exe` — compiled GUI installer (PS2EXE-built from the `.ps1`, requires admin)
- `WinPerfInstaller.ps1` — GUI installer source
- `install.ps1` — headless installer (used by the Claude flow)
- `compatibility/` — per-OS overrides
- `spec/` — extended documentation

## Logs

- `C:\WinPerf-Backup\install-<ts>.log` — line-by-line transcript (streams during run)
- `C:\WinPerf-Backup\backup-<ts>.json` — every old/new value pair for rollback
- `C:\WinPerf-Backup\progress.json` — current step heartbeat (headless path)
- `C:\WinPerf-Backup\.in-progress` — marker present only while installer is running
