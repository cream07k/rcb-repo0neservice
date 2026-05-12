---
section: 00-preflight
applies_to: [Win10, Win11, Server, Custom]
order: 0
risk: none
ac_safe: true
---

# Pre-flight checks

Claude must run these checks BEFORE applying any tweak.

## 1. Admin elevation

```powershell
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
if (-not $isAdmin) {
    Start-Process powershell -Verb RunAs -ArgumentList "-NoExit -Command <inline payload>"
    exit
}
```

## 2. System detection

```powershell
$os = Get-CimInstance Win32_OperatingSystem
$build = [int]$os.BuildNumber
$profile = @{
    OSType    = if ($build -ge 22000) {'Win11'} elseif ($build -ge 10240) {'Win10'} else {'Unknown'}
    IsServer  = $os.Caption -match "Server"
    Build     = $build
    Edition   = $os.Caption
    CPUCores  = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
    RAMGB     = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 0)
    GPUs      = (Get-CimInstance Win32_VideoController | Where Name -notmatch "Microsoft Basic").Name
    HasGamePass = $null -ne (Get-AppxPackage *XboxGamePass* -ErrorAction SilentlyContinue)
}
```

## 3. Anti-cheat detection

```powershell
$acPresent = @()
@('vgc','vgk','EasyAntiCheat','EasyAntiCheat_EOS','BEService','BEDaisy','FACEITService','Ricochet') |
    ForEach-Object { if (Get-Service -Name $_ -ErrorAction SilentlyContinue) { $acPresent += $_ } }
```

If `vgc` (Vanguard) or `FACEITService` present, REFUSE section §17 (advanced kernel) unconditionally.

## 4. Custom OS detection

```powershell
$customMarkers = @{
    'AtlasOS'      = 'HKLM:\SOFTWARE\AtlasOS'
    'Tiny11'       = 'HKLM:\SOFTWARE\Tiny11'
    'GhostSpectre' = 'HKLM:\SOFTWARE\GhostSpectre'
    'ReviOS'       = 'HKLM:\SOFTWARE\ReviOS'
}
foreach ($name in $customMarkers.Keys) {
    if (Test-Path $customMarkers[$name]) { $profile.CustomOS = $name; break }
}
```

When custom OS detected, read `compatibility/custom-os.md` and respect `already_applied` markers.

## 5. System Restore point

```powershell
$srp = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
Set-ItemProperty -Path $srp -Name "SystemRestorePointCreationFrequency" -Value 0 -Type DWord -Force
Checkpoint-Computer -Description "WinPerf-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')" -RestorePointType MODIFY_SETTINGS
```

## 6. Backup directory + state capture

```powershell
$backupDir = "C:\WinPerf-Backup"
if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
$backupFile = "$backupDir\backup-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').json"

$state = @{
    Profile = $profile
    AntiCheats = $acPresent
    Registry = @{}
    Services = @{}
    NetSH = @{}
    PowerCfg = @{}
    Mode = "standard"   # or "aggressive" if §17 is in scope
}

# Capture every registry key listed in spec/*.md before changes
# Capture every service status before changes
# Capture netsh int tcp show global output
# Capture powercfg /getactivescheme

$state | ConvertTo-Json -Depth 20 | Set-Content $backupFile
```

## 7. In-progress marker

```powershell
$marker = "$backupDir\.in-progress"
Set-Content -Path $marker -Value "$(Get-Date -Format O)|$repoUrl"
```

If marker exists on a future run, ask the user "previous run crashed; restore first?" before proceeding.

Remove marker only after successful verification.

## 8. Report profile back

Show the user:
```
System detected:
  OS:         {OSType} build {Build} ({Edition})
  CPU:        {Cores} logical cores
  RAM:        {RAMGB} GB
  GPU:        {GPUs joined with ', '}
  Game Pass:  {Yes/No}
  Anti-cheat: {present or "none detected"}
  Custom OS:  {CustomOS or "stock"}

Plan: sections 01-16 = standard profile (anti-cheat safe)
      section 17 = aggressive (will ask separately if applicable)
```

Then ask: "ยืนยันเริ่ม apply?"
