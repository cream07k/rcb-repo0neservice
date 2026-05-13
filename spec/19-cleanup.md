---
section: 19-cleanup
applies_to: [Win10, Win11, Server]
order: 190
risk: medium
ac_safe: true
---

# Cleanup — junk files + recycle bin

Run AFTER all other sections. Frees disk space.

On modern SSDs with TRIM enabled (default), emptying the recycle bin makes the data unrecoverable within seconds (the SSD firmware zeros the freed blocks during background garbage collection). No additional "secure wipe" step is needed for SSDs.

## 1. Temp folders

```powershell
$tempPaths = @(
    "$env:TEMP\*",
    "$env:LOCALAPPDATA\Temp\*",
    "C:\Windows\Temp\*",
    "C:\Windows\Prefetch\*",
    "C:\Windows\SoftwareDistribution\Download\*",
    "C:\Windows\Logs\CBS\*.log",
    "C:\Windows\Logs\DISM\*.log",
    "C:\Windows\Panther\*",
    "C:\Windows\Downloaded Program Files\*",
    "C:\Windows\System32\LogFiles\WMI\RtBackup\*",
    "$env:LOCALAPPDATA\CrashDumps\*",
    "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db",
    "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache_*.db",
    "$env:LOCALAPPDATA\Microsoft\Windows\WebCache\*",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*",
    "$env:LOCALAPPDATA\Microsoft\Windows\Caches\*"
)
foreach ($path in $tempPaths) {
    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
}
```

## 2. Browser caches

```powershell
# Chrome
Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache\*" -Recurse -Force -ErrorAction SilentlyContinue

# Edge
Remove-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache\*" -Recurse -Force -ErrorAction SilentlyContinue

# Firefox
Get-ChildItem "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item "$($_.FullName)\*" -Recurse -Force -ErrorAction SilentlyContinue
}
```

## 3. Crash dumps

```powershell
Remove-Item "C:\Windows\Minidump\*.dmp" -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Windows\MEMORY.DMP" -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Windows\LiveKernelReports\*" -Recurse -Force -ErrorAction SilentlyContinue
```

## 4. DISM component store cleanup

```cmd
DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase /Quiet
DISM /Online /Cleanup-Image /SPSuperseded /Quiet
```

## 5. Disk Cleanup (cleanmgr) silent

```powershell
$cleanmgrKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
Get-ChildItem $cleanmgrKey | ForEach-Object {
    Set-ItemProperty -Path $_.PSPath -Name "StateFlags0001" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
}
Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait -WindowStyle Hidden
```

## 6. Empty Recycle Bin (all drives)

```powershell
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
```

After this step + TRIM (automatic on SSD), data is unrecoverable on SSD.

## 7. Font + icon cache rebuild

```powershell
Stop-Service -Name FontCache -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\FNTCACHE.DAT" -Force -ErrorAction SilentlyContinue
Start-Service -Name FontCache -ErrorAction SilentlyContinue

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -ErrorAction SilentlyContinue
Start-Process explorer
```

## 8. Force TRIM on SSDs (makes deletes unrecoverable immediately)

```powershell
# Run optimize-volume which triggers TRIM on SSDs
Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' } | ForEach-Object {
    $disk = Get-Partition -DriveLetter $_.DriveLetter | Get-Disk
    $physDisk = Get-PhysicalDisk -DeviceNumber $disk.Number -ErrorAction SilentlyContinue
    if ($physDisk.MediaType -eq 'SSD') {
        Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim -Verbose
    }
}
```

TRIM on SSD = firmware-level secure delete of unused blocks. After this completes, deleted files cannot be recovered.

## 9. Report

```
Cleanup summary:
  Temp folders cleared:    X.X GB
  Browser caches:          X.X GB
  Crash dumps:             X.X MB
  DISM cleanup:            X.X GB
  Disk Cleanup:            X.X GB
  Recycle Bin:             X.X GB (emptied)
  TRIM forced on SSDs:     C:, D:

Free space before:  X GB
Free space after:   Y GB
Recovered:          Z GB

SSD security: TRIM completed — deleted data is now firmware-erased (unrecoverable).
HDD security: For HDDs, deleted data may be recoverable until overwritten.
              If user needs HDD secure wipe, use vendor tool (HDDErase) on a per-drive basis.
```
