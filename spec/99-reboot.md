---
section: 99-reboot
applies_to: [Win10, Win11, Server]
order: 999
risk: medium
ac_safe: true
---

# Final step — Reboot

After every section above is applied AND verification (§20) passes, automatically reboot to make all changes active.

## Why mandatory

Many tweaks require reboot to take effect:
- §06 Power scheme + processor settings
- §08 Memory manager (DisablePagingExecutive, page combining)
- §09 NTFS behavior (disable8dot3, disablelastaccess)
- §15 Services (disabled services keep running until reboot)
- §17 Advanced kernel — HVCI/VBS/BCD changes (boot-time features)
- §19 Cleanup — Explorer restart, font/icon cache rebuild

Without reboot, the user won't see the actual perf gain. The system stays in a half-applied state until reboot.

## Implementation

After §20 verification reports success:

```powershell
# 1. Show summary to user
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  ALL TWEAKS APPLIED + VERIFIED" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "REBOOT REQUIRED for full effect." -ForegroundColor Yellow
Write-Host ""

# 2. Remove in-progress marker (set during §00)
Remove-Item "C:\WinPerf-Backup\.in-progress" -Force -ErrorAction SilentlyContinue

# 3. 30-second countdown with cancel option
Write-Host "เครื่องจะ reboot ใน 30 วินาที" -ForegroundColor Cyan
Write-Host "กด CTRL+C เพื่อยกเลิก (ไฟล์ทุกอย่างถูก save แล้ว)" -ForegroundColor Cyan
Write-Host ""

for ($i = 30; $i -gt 0; $i--) {
    Write-Host -NoNewline "`r  Rebooting in $i seconds... "
    Start-Sleep -Seconds 1
}
Write-Host ""

# 4. Reboot
shutdown.exe /r /t 0 /f /c "WinPerf reboot — applying max performance tweaks"
```

## If user cancels (CTRL+C)

If user cancels the countdown:
- Tell user to manually reboot when ready: `shutdown /r /t 0`
- Note: tweaks are saved on disk; only reboot needed to activate

## After reboot

Skill can detect post-reboot state by checking `(Get-CimInstance Win32_OperatingSystem).LastBootUpTime`. If < 5 min ago AND `.in-progress` marker is gone AND a backup file exists from earlier today, skill can:
- Greet the user: "Reboot สำเร็จ — running post-reboot verification..."
- Re-run §20 verification queries
- Report final results with measured gains vs baseline (if user provided baseline ping/FPS)

## Skip reboot ONLY when

- User explicitly says "ไม่ต้อง reboot" / "skip reboot" / "I'll reboot later"
- Pre-flight detected that user is mid-task (e.g. unsaved Office files, ongoing download) — Claude should ask first instead of forcing
- Running in a remote session (RDP) where reboot would disconnect the operator
