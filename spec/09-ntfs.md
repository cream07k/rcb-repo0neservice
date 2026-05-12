---
section: 09-ntfs
applies_to: [Win10, Win11, Server]
order: 90
risk: low
ac_safe: true
---

# NTFS filesystem tuning

## fsutil behaviors

```cmd
fsutil behavior set disable8dot3 1
fsutil behavior set disablelastaccess 1
fsutil behavior set memoryusage 2
fsutil behavior set mftzone 2
fsutil behavior set quotanotify 86400
fsutil behavior set encryptpagingfile 0
fsutil behavior set symlinkevaluation L2L:1 L2R:1 R2L:0 R2R:1
fsutil behavior set bugcheckOnCorrupt 0
fsutil behavior set DisableDeleteNotify 0
fsutil behavior set DisableCompression 1
fsutil behavior set DisableEncryption 1
fsutil resource setautoreset true C:\
```

## Disable indexing on data drives (keep C: indexed for OS)

```powershell
Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveLetter -ne 'C' -and $_.FileSystem -eq 'NTFS' } | ForEach-Object {
    fsutil 8dot3name set $_.DriveLetter 1
    attrib +I "$($_.DriveLetter):\" /D /S 2>$null
}
```

## USN journal + chkdsk

```cmd
fsutil usn deletejournal /D /N C:
chkntfs /x C:
```

## TRIM verify (don't touch — must stay enabled for SSD)

```powershell
# Verify TRIM is on (should report 0)
fsutil behavior query disabledeletenotify
```
