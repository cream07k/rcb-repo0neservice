#requires -Version 5.1
<#
  install-delta.ps1 — applies ONLY the missing HKLM/IFEO/MMAgent/IRQ/HID pieces
  Skips the heavy/slow modules (NIC advanced, services, Defender, DISM, network)
  Heavy checkpoint logging — pinpoints any hang within seconds
#>

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')
if (-not $isAdmin) {
    Write-Host "Re-launching elevated..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`""
    exit 0
}

$ts = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$log = "C:\WinPerf-Backup\delta-$ts.log"
if (-not (Test-Path 'C:\WinPerf-Backup')) { New-Item -ItemType Directory -Path 'C:\WinPerf-Backup' -Force | Out-Null }
Start-Transcript -Path $log -Force | Out-Null

function Step { param([string]$m); Write-Host "[$((Get-Date).ToString('HH:mm:ss.fff'))] $m" -ForegroundColor Cyan }
function OK   { param([string]$m); Write-Host "  [OK] $m" -ForegroundColor Green }
function Skip { param([string]$m); Write-Host "  [skip] $m" -ForegroundColor DarkGray }
function Warn { param([string]$m); Write-Host "  [WARN] $m" -ForegroundColor Yellow }

function SetVal {
    param([string]$Path, [string]$Name, $Value, [string]$Type='DWord')
    if (-not (Test-Path $Path)) { try { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null } catch { Warn "create $Path : $($_.Exception.Message)"; return } }
    $old = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
    if ("$old" -eq "$Value") { Skip "$Name (already $old)"; return }
    try {
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
        OK "$Name : $old -> $Value"
    } catch {
        try { Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction SilentlyContinue } catch {}
        try { New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null; OK "$Name : (new) $Value" } catch { Warn "$Name : $($_.Exception.Message)" }
    }
}

Step "DELTA START — applies missing pieces only"
$os = Get-CimInstance Win32_OperatingSystem
$cores = ($env:NUMBER_OF_PROCESSORS -as [int]); if (-not $cores) { $cores = 8 }
$ramGB = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 0)
Write-Host "  Cores=$cores RAM=${ramGB}GB"

# ---- 04. MMCSS Games Priority 6 -> 8 -------------------------------------
Step "MODULE 04 — MMCSS Games Priority"
$games = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
SetVal $games 'Priority' 8
SetVal $games 'Scheduling Category' 'High' 'String'
SetVal $games 'SFIO Priority' 'High' 'String'
SetVal $games 'Background Only' 'False' 'String'
SetVal $games 'Clock Rate' 10000
SetVal $games 'GPU Priority' 8
SetVal 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'SystemResponsiveness' 0
SetVal 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'NetworkThrottlingIndex' 0xffffffff

# ---- 05. CPU IRQ priorities ----------------------------------------------
Step "MODULE 05 — IRQ priorities"
$pc = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
SetVal $pc 'Win32PrioritySeparation' 38
SetVal $pc 'IRQ1Priority' 1
SetVal $pc 'IRQ12Priority' 1
SetVal $pc 'IRQ16Priority' 1
SetVal $pc 'IRQ8Priority' 2
SetVal 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'DistributeTimers' 1
SetVal 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'ThreadDpcEnable' 1

# ---- 08. Memory Manager + MMAgent ----------------------------------------
Step "MODULE 08 — Memory + MMAgent"
$mm = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
SetVal $mm 'DisablePagingExecutive' 1
SetVal $mm 'LargeSystemCache' 0
SetVal $mm 'IoPageLockLimit' 0x10000
SetVal $mm 'PoolUsageMaximum' 96
SetVal $mm 'DisablePageCombining' 1
SetVal $mm 'ClearPageFileAtShutdown' 0
SetVal $mm 'MoveImages' 0
SetVal $mm 'PhysicalAddressExtension' 1
SetVal $mm 'SecondLevelDataCache' 1024

if ($ramGB -ge 16) {
    Step "  MMAgent disable (RAM >= 16GB)"
    try { Disable-MMAgent -MemoryCompression -ErrorAction Stop; OK 'MemoryCompression off' } catch { Warn "MemoryCompression: $($_.Exception.Message)" }
    try { Disable-MMAgent -PageCombining -ErrorAction Stop; OK 'PageCombining off' } catch { Warn "PageCombining: $($_.Exception.Message)" }
    try { Disable-MMAgent -ApplicationLaunchPrefetching -ErrorAction Stop; OK 'ApplicationLaunchPrefetching off' } catch { Warn "AppLaunchPrefetching: $($_.Exception.Message)" }
    try { Disable-MMAgent -ApplicationPreLaunch -ErrorAction Stop; OK 'ApplicationPreLaunch off' } catch { Warn "AppPreLaunch: $($_.Exception.Message)" }
}

# ---- 10. Input chain (HKLM portion — HKCU already applied) ---------------
Step "MODULE 10 — Input drivers (HKLM)"
SetVal 'HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters' 'MouseDataQueueSize' 20
SetVal 'HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters' 'KeyboardDataQueueSize' 20
SetVal 'HKLM:\SYSTEM\CurrentControlSet\Services\mouhid\Parameters' 'MouseDataQueueSize' 20
SetVal 'HKLM:\SYSTEM\CurrentControlSet\Services\kbdhid\Parameters' 'KeyboardDataQueueSize' 20

Step "  HID device IdleEnable off"
$hidCount = 0; $hidOK = 0
Get-PnpDevice -Class HIDClass -PresentOnly -ErrorAction SilentlyContinue | ForEach-Object {
    $hidCount++
    $instance = $_.InstanceId
    $devPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$instance\Device Parameters"
    if (Test-Path $devPath) {
        try { Set-ItemProperty -Path $devPath -Name 'IdleEnable' -Value 0 -Type DWord -Force -ErrorAction Stop; $hidOK++ } catch {}
        try { Set-ItemProperty -Path $devPath -Name 'EnhancedPowerManagementEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue } catch {}
    }
}
Write-Host "    HID devices processed: $hidOK/$hidCount"

# ---- 18. FiveM IFEO PerfOptions ------------------------------------------
Step "MODULE 18 — FiveM process pinning (IFEO)"
$ifeoRoot = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
$images = @('FiveM.exe','FiveM_GTAProcess.exe','FiveM_b2944_GTAProcess.exe','FiveM_b2189_GTAProcess.exe','FiveM_b3095_GTAProcess.exe','CitizenFX_SubProcess_game.exe')
foreach ($img in $images) {
    $p = "$ifeoRoot\$img\PerfOptions"
    SetVal $p 'CpuPriorityClass' 3
    SetVal $p 'IoPriority' 3
    SetVal $p 'PagePriority' 5
}

# ---- 18b. FiveM helper script (per-user, no UAC needed at runtime) -------
Step "MODULE 18b — Write FiveM priority helper"
$helperDir = "$env:LOCALAPPDATA\WinPerf"
if (-not (Test-Path $helperDir)) { New-Item -ItemType Directory -Path $helperDir -Force | Out-Null }
$helperPath = "$helperDir\FiveM-priority.ps1"
$cores = ($env:NUMBER_OF_PROCESSORS -as [int]); if (-not $cores) { $cores = 8 }
$helperBody = @'
# FiveM priority + timer-resolution helper
# Run after launching FiveM. Keep window open for the duration of play.
$cores = __CORES__
$src = '[DllImport("ntdll.dll", EntryPoint="NtSetTimerResolution")] public static extern int Set(int desired, bool set, out int current);'
$ntdll = Add-Type -MemberDefinition $src -Name 'NtRes' -Namespace 'W' -PassThru
$cur = 0
[void]$ntdll::Set(5000, $true, [ref]$cur)
Write-Host "[timer] requested 0.5ms, current $cur (100ns units)" -ForegroundColor Green
while ($true) {
    Get-Process FiveM,FiveM_GTAProcess,FiveM_b2944_GTAProcess,CitizenFX_SubProcess_game -ErrorAction SilentlyContinue | ForEach-Object {
        try { $_.PriorityClass = 'High' } catch {}
        try {
            if ($cores -ge 4) {
                $mask = [int]([Math]::Pow(2, $cores) - 1) -band -bnot 1
                $_.ProcessorAffinity = [IntPtr]$mask
            }
        } catch {}
    }
    Start-Sleep -Seconds 5
}
'@
$helperBody = $helperBody.Replace('__CORES__', $cores)
Set-Content -Path $helperPath -Value $helperBody -Encoding UTF8 -Force
OK "Helper written: $helperPath"

# ---- 16. FiveM citizen.cfg additions -------------------------------------
Step "MODULE 16 — FiveM citizen.cfg"
$cfgPath = "$env:LOCALAPPDATA\FiveM\FiveM.app\citizen.cfg"
$cfgDir = Split-Path $cfgPath -Parent
if (-not (Test-Path $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null }
$wantedLines = @(
    'sv_pure_verify 0',
    'con_disableNonImportantTraces 1',
    'net_packetWindowSize 1500',
    'net_compressionThreshold 1200',
    'profile_preferDefaultSpawnpoint 1',
    'profile_singleplayer_disablestream 1',
    'net_clientUpdateRate 50',
    'cl_inputBufferSize 1',
    'cl_predictBuffer 1'
)
$existing = if (Test-Path $cfgPath) { Get-Content $cfgPath } else { @() }
$added = 0
foreach ($line in $wantedLines) {
    $key = ($line -split ' ')[0]
    if ($existing | Where-Object { $_ -match "^\s*$key\b" }) { Skip "$key present" } else { $existing += $line; $added++ }
}
if ($added -gt 0) { Set-Content -Path $cfgPath -Value $existing -Encoding UTF8 -Force; OK "Added $added lines to citizen.cfg" } else { Skip "citizen.cfg already complete" }

# ---- VERIFY ---------------------------------------------------------------
Step "VERIFY — re-read all target keys"
$verify = @(
    @{P=$games;N='Priority';E=8;Tag='MMCSS Games Priority'},
    @{P=$games;N='GPU Priority';E=8;Tag='MMCSS GPU Priority'},
    @{P=$pc;N='IRQ1Priority';E=1;Tag='IRQ1 (keyboard)'},
    @{P=$pc;N='IRQ12Priority';E=1;Tag='IRQ12 (PS/2 mouse)'},
    @{P=$pc;N='IRQ16Priority';E=1;Tag='IRQ16 (USB)'},
    @{P=$mm;N='DisablePagingExecutive';E=1;Tag='Mem: keep kernel in RAM'},
    @{P='HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters';N='MouseDataQueueSize';E=20;Tag='mouclass queue'},
    @{P='HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters';N='KeyboardDataQueueSize';E=20;Tag='kbdclass queue'},
    @{P="$ifeoRoot\FiveM.exe\PerfOptions";N='CpuPriorityClass';E=3;Tag='FiveM.exe IFEO high'},
    @{P="$ifeoRoot\CitizenFX_SubProcess_game.exe\PerfOptions";N='CpuPriorityClass';E=3;Tag='CitizenFX IFEO high'}
)
$pass = 0; $fail = 0
foreach ($v in $verify) {
    $got = (Get-ItemProperty -Path $v.P -Name $v.N -ErrorAction SilentlyContinue).$($v.N)
    if ("$got" -eq "$($v.E)") { OK "$($v.Tag) = $got"; $pass++ } else { Warn "$($v.Tag) = $got (want $($v.E))"; $fail++ }
}

Step "MMAgent state"
try { Get-MMAgent | Format-List MemoryCompression, PageCombining, ApplicationLaunchPrefetching, ApplicationPreLaunch | Out-String | Write-Host } catch { Warn "MMAgent read: $($_.Exception.Message)" }

Step "DELTA DONE — pass=$pass fail=$fail"
Write-Host ""
Write-Host "Log: $log" -ForegroundColor Yellow

Stop-Transcript | Out-Null
Write-Host "`n=== ALL DONE — press any key to close ===" -ForegroundColor Green
try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch {}
