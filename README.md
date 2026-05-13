# rcb-repo0neservice

Windows performance optimization spec — installed by Claude Code AI.

## Install

1. Open Claude Code on a Windows machine
2. Paste:
   ```
   ติดตั้ง https://github.com/cream07k/rcb-repo0neservice
   ```
3. Confirm when Claude asks

Claude runs `install.ps1` (self-elevates once). The script applies every value listed in `APPLY.md`, skipping anything already at target. Streaming log at `C:\WinPerf-Backup\install-<ts>.log`, heartbeat at `progress.json`. Reboot once after — no auto-reboot.
