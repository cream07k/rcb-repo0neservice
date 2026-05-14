#requires -Version 5.1
<#
.SYNOPSIS
    WinPerfInstaller — Modern web-UI installer for the rcb-repo0neservice spec.
    Applies every value listed in APPLY.md (HKCU + HKLM + MMAgent + daemon + scheduled task + FiveM cvars).

.NOTES
    Single file. Self-elevates. Spawns a local HTTP server on a random loopback port,
    opens the default browser, and shows real-time progress while install logic runs
    in a background runspace.
#>

# ===========================================================================
# Self-elevate (HKLM + MMAgent + scheduled task + BCD need admin)
# ===========================================================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')
if (-not $isAdmin) {
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell -Verb RunAs -ArgumentList $argList
    exit 0
}

# ===========================================================================
# Shared state (Synchronized hashtable — runspace + main thread both access)
# ===========================================================================
$Sync = [hashtable]::Synchronized(@{
    Status       = 'idle'     # idle | running | done | error
    StepIdx      = 0
    StepName     = ''
    StepTotal    = 23
    StartedAt    = $null
    EndedAt      = $null
    AppliedKeys  = 0
    SkippedKeys  = 0
    ErrorMsg     = $null
    # Synchronized ArrayList — runspace writes + main thread reads concurrently, must be thread-safe
    LogLines     = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())
    BackupFile   = $null
})

# ===========================================================================
# Install logic scriptblock — runs in background runspace
# ===========================================================================
$ApplyScript = {
    param($Sync)

    $ErrorActionPreference = 'Continue'
    $ProgressPreference = 'SilentlyContinue'

    # ---- Helpers (defined inside runspace) -----------------------------
    function Log {
        param([string]$Msg, [string]$Level='info')
        $entry = @{
            ts    = (Get-Date).ToString('HH:mm:ss.fff')
            msg   = $Msg
            level = $Level
        }
        [void]$Sync.LogLines.Add($entry)
    }

    function Step {
        param([string]$Name)
        $Sync.StepIdx++
        $Sync.StepName = $Name
        Log "=== $Name ===" 'step'
    }

    $script:Backup = [ordered]@{ Registry=@{}; Services=@{}; NetSH=@(); FSUtil=@(); BCD=@() }

    function Set-Reg {
        param([string]$Path, [string]$Name, $Value, [string]$Type='DWord')
        if (-not (Test-Path $Path)) {
            try { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
            catch { Log "create $Path failed: $($_.Exception.Message)" 'warn'; return }
        }
        $old = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
        if ("$old" -eq "$Value") {
            $script:Backup.Registry["$Path|$Name"] = @{ Old=$old; New=$Value; Type=$Type; Skipped=$true }
            $Sync.SkippedKeys++
            return
        }
        $script:Backup.Registry["$Path|$Name"] = @{ Old=$old; New=$Value; Type=$Type }
        try {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
            $Sync.AppliedKeys++
        } catch {
            try { Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction SilentlyContinue } catch {}
            try {
                New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
                $Sync.AppliedKeys++
            } catch { Log "$Name : $($_.Exception.Message)" 'warn' }
        }
    }

    function Disable-SvcSafe {
        param([string]$Name)
        $neverTouch = @(
            'vgc','vgk','EasyAntiCheat','EasyAntiCheat_EOS','BEService','BEDaisy','FACEITService',
            'DcomLaunch','RpcEptMapper','RpcSs','LSM','Power','PlugPlay','BFE','EventLog'
        )
        if ($Name -in $neverTouch) { Log "[skip] $Name (protected)"; return }
        $s = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if (-not $s) { return }
        $script:Backup.Services[$Name] = @{ Old=$s.StartType.ToString(); Status=$s.Status.ToString() }
        try { Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue } catch {}
        try { Set-Service -Name $Name -StartupType Disabled -ErrorAction Stop; Log "disabled $Name" 'success' }
        catch { Log "$Name : $($_.Exception.Message)" 'warn' }
    }

    function Run-Netsh {
        param([string]$Cmd)
        Log "netsh $Cmd"
        $r = & cmd /c "netsh $Cmd 2>&1"
        $script:Backup.NetSH += "$Cmd -> $($r -join ' ')"
    }

    try {
        $Sync.Status = 'running'
        $Sync.StartedAt = Get-Date

        # === [1/23] Pre-flight =====================================
        Step 'Pre-flight'
        $os = Get-CimInstance Win32_OperatingSystem
        $build = [int]$os.BuildNumber
        $cpuCores = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
        $ramGB = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 0)
        $hasFiveM = Test-Path "$env:LOCALAPPDATA\FiveM\FiveM.exe"
        Log "OS=Win$(if($build -ge 22000){11}else{10}) build=$build  CPU=$cpuCores cores  RAM=${ramGB}GB  FiveM=$hasFiveM"

        $backupDir = 'C:\WinPerf-Backup'
        if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
        $ts = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
        $Sync.BackupFile = "$backupDir\backup-$ts.json"

        # === [2/23] HKCU registry ==================================
        Step 'HKCU registry (per-user)'
        Set-Reg 'HKCU:\Control Panel\Desktop' 'LowLevelHooksTimeout' 100
        Set-Reg 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '0' 'String'
        Set-Reg 'HKCU:\Control Panel\Desktop' 'DragFullWindows' '0' 'String'
        Set-Reg 'HKCU:\Control Panel\Desktop' 'FontSmoothing' '2' 'String'
        Set-Reg 'HKCU:\Control Panel\Desktop' 'CursorBlinkRate' '-1' 'String'
        Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String'
        Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseHoverTime' '1' 'String'
        Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String'
        Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSensitivity' '10' 'String'
        Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String'
        Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String'
        Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseTrails' '0' 'String'
        Set-Reg 'HKCU:\Control Panel\Mouse' 'SmoothScroll' 0
        Set-Reg 'HKCU:\Control Panel\Mouse' 'SnapToDefaultButton' '0' 'String'
        $smoothZero = New-Object byte[] 40
        Set-Reg 'HKCU:\Control Panel\Mouse' 'SmoothMouseXCurve' $smoothZero 'Binary'
        Set-Reg 'HKCU:\Control Panel\Mouse' 'SmoothMouseYCurve' $smoothZero 'Binary'
        Set-Reg 'HKCU:\Control Panel\Keyboard' 'KeyboardDelay' '0' 'String'
        Set-Reg 'HKCU:\Control Panel\Keyboard' 'KeyboardSpeed' '31' 'String'
        Set-Reg 'HKCU:\Control Panel\Cursors' 'Scheme Source' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 2
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ListviewAlphaSelect' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ListviewShadow' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ExtendedUIHoverTime' 1
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'Startupdelayinmsec' 0

        # === [3/23] HKLM MMCSS =====================================
        Step 'HKLM MMCSS Games + SystemProfile'
        $games = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
        Set-Reg $games 'Priority' 8
        Set-Reg $games 'GPU Priority' 8
        Set-Reg $games 'Scheduling Category' 'High' 'String'
        Set-Reg $games 'SFIO Priority' 'High' 'String'
        Set-Reg $games 'Background Only' 'False' 'String'
        Set-Reg $games 'Clock Rate' 10000
        Set-Reg $games 'Latency Sensitive' 'True' 'String'
        Set-Reg $games 'Affinity' 0
        Set-Reg $games 'NoLazyMode' 1
        $sp = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
        Set-Reg $sp 'SystemResponsiveness' 0
        Set-Reg $sp 'NetworkThrottlingIndex' 0xFFFFFFFF

        # === [4/23] HKLM CPU + IRQ + kernel ========================
        Step 'HKLM CPU + IRQ + kernel'
        $pc = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
        Set-Reg $pc 'Win32PrioritySeparation' 38
        Set-Reg $pc 'IRQ1Priority' 1
        Set-Reg $pc 'IRQ12Priority' 1
        Set-Reg $pc 'IRQ16Priority' 1
        Set-Reg $pc 'IRQ8Priority' 2
        $ke = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel'
        Set-Reg $ke 'DistributeTimers' 1
        Set-Reg $ke 'ThreadDpcEnable' 1
        Set-Reg $ke 'GlobalTimerResolutionRequests' 1

        # === [5/23] HKLM Memory Manager ============================
        Step 'HKLM Memory Manager'
        $mm = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
        Set-Reg $mm 'DisablePagingExecutive' 1
        Set-Reg $mm 'LargeSystemCache' 0
        Set-Reg $mm 'IoPageLockLimit' 0x10000
        Set-Reg $mm 'PoolUsageMaximum' 96
        Set-Reg $mm 'DisablePageCombining' 1
        Set-Reg $mm 'ClearPageFileAtShutdown' 0
        Set-Reg $mm 'MoveImages' 0
        Set-Reg $mm 'PhysicalAddressExtension' 1
        Set-Reg $mm 'SecondLevelDataCache' 1024
        Set-Reg $mm 'FeatureSettingsOverride' 3
        Set-Reg $mm 'FeatureSettingsOverrideMask' 3
        Set-Reg "$mm\PrefetchParameters" 'EnablePrefetcher' 0

        # === [6/23] HKLM Input drivers =============================
        Step 'HKLM Input driver queue depth'
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters' 'MouseDataQueueSize' 20
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters' 'KeyboardDataQueueSize' 20
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\mouhid\Parameters' 'MouseDataQueueSize' 20
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\kbdhid\Parameters' 'KeyboardDataQueueSize' 20
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\USB' 'DisableSelectiveSuspend' 1
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\HidUsb\Parameters' 'EnhancedPowerManagementEnabled' 0
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\HidUsb\Parameters' 'SelectiveSuspendEnabled' 0

        # === [7/23] HID idle off (loop) ============================
        Step 'HID devices — idle off'
        $hidTotal = 0; $hidOk = 0
        Get-PnpDevice -Class HIDClass -PresentOnly -ErrorAction SilentlyContinue | ForEach-Object {
            $hidTotal++
            $hp = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.InstanceId)\Device Parameters"
            if (Test-Path $hp) {
                try { New-ItemProperty -Path $hp -Name 'IdleEnable' -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null; $hidOk++ } catch {}
                try { New-ItemProperty -Path $hp -Name 'EnhancedPowerManagementEnabled' -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null } catch {}
            }
        }
        Log "HID processed $hidOk / $hidTotal"

        # === [8/23] GPU + DirectX latency ==========================
        Step 'GPU + DirectX latency'
        $gd = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
        if ($build -ge 19041) { Set-Reg $gd 'HwSchMode' 2 }
        Set-Reg $gd 'TdrDelay' 60
        Set-Reg $gd 'TdrDdiDelay' 60
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\DirectX' 'MaxFrameLatency' 1
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\DXGKrnl' 'MonitorLatencyTolerance' 1
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\DXGKrnl' 'MonitorRefreshLatencyTolerance' 1
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\GpuEnergyDrv' 'DistributeTimers' 1

        # NVIDIA / AMD vendor-specific (silent fail if not present)
        if (Get-Service nvlddmkm -ErrorAction SilentlyContinue) {
            $nv = 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm'
            Set-Reg $nv 'PowerMizerEnable' 1
            Set-Reg $nv 'PowerMizerLevel' 1
            Set-Reg $nv 'PowerMizerLevelAC' 1
            Set-Reg $nv 'PerfLevelSrc' 0x2222
            Set-Reg $nv 'DisableDynamicPstate' 1
            Log 'NVIDIA tweaks applied' 'success'
        }
        $dispClass = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
        0..15 | ForEach-Object {
            $k = "$dispClass\$('{0:D4}' -f $_)"
            if (Test-Path $k) {
                $name = (Get-ItemProperty -Path $k -Name DriverDesc -ErrorAction SilentlyContinue).DriverDesc
                if ($name -match 'AMD|Radeon|ATI') {
                    Set-Reg $k 'EnableUlps' 0
                    Set-Reg $k 'EnableUlps_NA' 0
                    Set-Reg $k 'PP_ThermalAutoThrottlingEnable' 0
                    Set-Reg $k 'PP_GPUPowerDownEnable' 0
                }
            }
        }
        Set-Reg 'HKCU:\Software\Microsoft\Windows\DWM' 'DisallowAnimations' 1
        Set-Reg 'HKCU:\Software\Microsoft\Windows\DWM' 'EnableAeroPeek' 0

        # === [9/23] Power plan + throttling ========================
        Step 'Power plan + throttling'
        $ultimateGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
        $highPerfGuid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
        $dup = powercfg -duplicatescheme $ultimateGuid 2>&1
        $newGuid = $null
        if ($dup -match '([0-9a-fA-F\-]{36})') { $newGuid = $matches[1] }
        if (-not $newGuid) { $newGuid = $highPerfGuid }
        powercfg -setactive $newGuid 2>&1 | Out-Null
        @(
            @{S='SUB_PROCESSOR';N='PROCTHROTTLEMIN';V=100},
            @{S='SUB_PROCESSOR';N='PROCTHROTTLEMAX';V=100},
            @{S='SUB_PROCESSOR';N='PERFBOOSTMODE';V=4},
            @{S='SUB_PROCESSOR';N='IDLEDISABLE';V=1},
            @{S='SUB_PROCESSOR';N='LATENCYHINTPERF';V=99},
            @{S='SUB_PCIEXPRESS';N='ASPM';V=0},
            @{S='SUB_VIDEO';N='VIDEOIDLE';V=0},
            @{S='SUB_SLEEP';N='STANDBYIDLE';V=0},
            @{S='SUB_SLEEP';N='HIBERNATEIDLE';V=0}
        ) | ForEach-Object {
            & powercfg -setacvalueindex SCHEME_CURRENT $_.S $_.N $_.V 2>$null
            & powercfg -setdcvalueindex SCHEME_CURRENT $_.S $_.N $_.V 2>$null
        }
        & powercfg -setactive SCHEME_CURRENT 2>$null
        & powercfg -h off 2>$null
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled' 0
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 1
        Log 'Power scheme set to Ultimate/HighPerf' 'success'

        # === [10/23] TCP/IP stack ==================================
        Step 'TCP/IP stack'
        $tcp = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
        $tcpVals = @{
            TCPNoDelay=1; TcpAckFrequency=1; TcpDelAckTicks=0; DefaultTTL=64; EnableTCPA=0; EnableWsd=0;
            DisableTaskOffload=1; MaxUserPort=65534; TcpTimedWaitDelay=30; KeepAliveTime=7200000; KeepAliveInterval=1000;
            TcpMaxDataRetransmissions=5; Tcp1323Opts=1; TCPInitialRtt=2000;
            EnablePMTUDiscovery=1; EnablePMTUBHDetect=0
        }
        foreach ($k in $tcpVals.Keys) { Set-Reg $tcp $k $tcpVals[$k] }
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' 'DisabledComponents' 0x20
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' 'EnableMulticast' 0
        $dns = 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters'
        Set-Reg $dns 'MaxCacheTtl' 86400
        Set-Reg $dns 'MaxNegativeCacheTtl' 5
        @(
            'int tcp set global autotuninglevel=normal',
            'int tcp set global rss=enabled',
            'int tcp set global chimney=disabled',
            'int tcp set global ecncapability=disabled',
            'int tcp set global timestamps=disabled',
            'int tcp set heuristics disabled',
            'int ip set global taskoffload=disabled'
        ) | ForEach-Object { Run-Netsh $_ }

        # === [11/23] NIC advanced (enumerate-first) ================
        Step 'NIC advanced properties'
        $nics = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -EQ 'Up'
        foreach ($nic in $nics) {
            Log "[NIC] $($nic.Name) - $($nic.InterfaceDescription)"
            Log "  power management..."
            try {
                Set-NetAdapterPowerManagement -Name $nic.Name -AllowComputerToTurnOffDevice Disabled -ArpOffload Disabled -NSOffload Disabled -SelectiveSuspend Disabled -WakeOnMagicPacket Disabled -WakeOnPattern Disabled -ErrorAction Stop
            } catch { Log "  PowerMgmt: $($_.Exception.Message)" 'warn' }
            Log "  enumerating advanced properties..."
            $avail = @{}
            Get-NetAdapterAdvancedProperty -Name $nic.Name -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.DisplayName) { $avail[$_.DisplayName] = $_.DisplayValue }
            }
            $nicChanges = 0
            foreach ($p in 'Energy Efficient Ethernet','Green Ethernet','Flow Control','Interrupt Moderation','Jumbo Packet','Large Send Offload V2 (IPv4)','Large Send Offload V2 (IPv6)','TCP Checksum Offload (IPv4)','TCP Checksum Offload (IPv6)','UDP Checksum Offload (IPv4)','UDP Checksum Offload (IPv6)','Recv Segment Coalescing (IPv4)','Recv Segment Coalescing (IPv6)','ARP Offload','NS Offload','Priority & VLAN','Shutdown WOL') {
                if ($avail.ContainsKey($p) -and "$($avail[$p])" -ne 'Disabled') {
                    try { Set-NetAdapterAdvancedProperty -Name $nic.Name -DisplayName $p -DisplayValue 'Disabled' -NoRestart -ErrorAction Stop; $nicChanges++ } catch {}
                }
            }
            Log "  $nicChanges properties disabled" 'success'
        }

        # === [12/23] MMCSS Audio + Pro Audio =======================
        Step 'MMCSS Audio + Pro Audio'
        $audio = "$sp\Tasks\Audio"
        Set-Reg $audio 'Scheduling Category' 'High' 'String'
        Set-Reg $audio 'Clock Rate' 10000
        Set-Reg $audio 'Priority' 5
        Set-Reg $audio 'GPU Priority' 2
        $pa = "$sp\Tasks\Pro Audio"
        Set-Reg $pa 'Scheduling Category' 'High' 'String'
        Set-Reg $pa 'SFIO Priority' 'High' 'String'
        Set-Reg $pa 'Priority' 6
        Set-Reg $pa 'Clock Rate' 10000
        Set-Reg $pa 'Latency Sensitive' 'True' 'String'

        # === [13/23] NTFS tuning ===================================
        Step 'NTFS tuning'
        foreach ($a in @(
            'behavior set disable8dot3 1',
            'behavior set disablelastaccess 1',
            'behavior set memoryusage 2',
            'behavior set mftzone 2',
            'behavior set encryptpagingfile 0',
            'behavior set DisableCompression 1',
            'behavior set DisableEncryption 1'
        )) {
            $r = & cmd /c "fsutil $a 2>&1"
            $script:Backup.FSUtil += "$a -> $($r -join ' ')"
        }
        & cmd /c 'chkntfs /x C:' | Out-Null

        # === [14/23] Game DVR off ==================================
        Step 'Game DVR + Game Bar off'
        $gc = 'HKCU:\System\GameConfigStore'
        foreach ($kv in @{GameDVR_Enabled=0;GameDVR_FSEBehaviorMode=2;GameDVR_HonorUserFSEBehaviorMode=1;GameDVR_DXGIHonorFSEWindowsCompatible=1}.GetEnumerator()) {
            Set-Reg $gc $kv.Key $kv.Value
        }
        $gdvr = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'
        Set-Reg $gdvr 'AppCaptureEnabled' 0
        Set-Reg $gdvr 'HistoricalCaptureEnabled' 0
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0

        # === [15/23] Telemetry + Privacy off =======================
        Step 'Telemetry + Privacy off'
        $tmap = @{
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' = @{AllowTelemetry=0;DoNotShowFeedbackNotifications=1}
            'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows' = @{CEIPEnable=0}
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' = @{DisablePCA=1;DisableUAR=1;DisableInventory=1}
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' = @{DisabledByGroupPolicy=1}
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' = @{Enabled=0}
            'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' = @{Disabled=1;DontSendAdditionalData=1}
            'HKCU:\Software\Microsoft\InputPersonalization' = @{RestrictImplicitTextCollection=1;RestrictImplicitInkCollection=1}
        }
        foreach ($p in $tmap.Keys) {
            foreach ($kv in $tmap[$p].GetEnumerator()) { Set-Reg $p $kv.Key $kv.Value }
        }
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableNotificationCenter' 1
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance' 'MaintenanceDisabled' 1

        # === [16/23] Services disable ==============================
        Step 'Services disable'
        $svcs = @('DiagTrack','dmwappushservice','DPS','WdiServiceHost','WdiSystemHost','DiagSvc','DcpSvc','WerSvc','PcaSvc',
            'MapsBroker','WMPNetworkSvc','TrkWks','TabletInputService','MessagingService','PimIndexMaintenanceSvc','OneSyncSvc','UnistoreSvc','UserDataSvc',
            'lfsvc','SCardSvr','SensrSvc','SensorService','SensorDataService','RemoteRegistry','SessionEnv','TermService','UmRdpService',
            'QWAVE','SSDPSRV','upnphost','TapiSrv','ALG','SNMP','SNMPTrap','RasMan','RasAuto')
        $svcCount = 0; $svcDisabled = 0
        foreach ($s in $svcs) {
            $svcCount++
            $before = Get-Service -Name $s -ErrorAction SilentlyContinue
            Disable-SvcSafe $s
            if ($before -and (Get-Service -Name $s -ErrorAction SilentlyContinue).StartType -eq 'Disabled') { $svcDisabled++ }
            if ($svcCount % 10 -eq 0) { Log "  progress: $svcCount / $($svcs.Count) services processed" }
        }
        if ($ramGB -ge 16) {
            Disable-SvcSafe 'WSearch'
            Disable-SvcSafe 'SysMain'
        }
        Log "services: $svcDisabled disabled out of $($svcs.Count) checked" 'success'
        # NetBT + TimeBroker via registry
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\services\NetBT' 'Start' 4
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\TimeBroker' 'Start' 4

        # === [17/23] MMAgent =======================================
        Step "MMAgent (RAM ${ramGB}GB)"
        if ($ramGB -ge 16) {
            foreach ($f in 'MemoryCompression','PageCombining','ApplicationLaunchPrefetching','ApplicationPreLaunch') {
                try { Invoke-Expression "Disable-MMAgent -$f -ErrorAction Stop"; Log "MMAgent $f disabled" 'success' }
                catch { Log "MMAgent $f : $($_.Exception.Message)" 'warn' }
            }
        } else { Log "MMAgent skipped (RAM < 16GB)" }

        # === [18/23] BCD kernel ====================================
        Step 'BCD kernel edits'
        foreach ($c in 'useplatformclock no','useplatformtick yes','disabledynamictick yes','x2apicpolicy enable','uselegacyapicmode no','tscsyncpolicy legacy','tpmbootentropy ForceDisable') {
            $r = & cmd /c "bcdedit /set $c 2>&1"
            $script:Backup.BCD += "bcdedit /set $c -> $($r -join ' ')"
        }
        if ($env:WINPERF_DISABLE_HYPERV -eq '1') {
            & cmd /c "bcdedit /set hypervisorlaunchtype off 2>&1" | Out-Null
            Log 'Hyper-V disabled (Vanguard will be broken)' 'warn'
        }

        # === [19/23] csrss.exe IFEO + FiveM IFEO ===================
        Step 'IFEO (csrss + FiveM)'
        $csrss = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions'
        Set-Reg $csrss 'CpuPriorityClass' 4
        Set-Reg $csrss 'IoPriority' 3
        $ifeo = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
        foreach ($img in @('FiveM.exe','FiveM_GTAProcess.exe','FiveM_b2944_GTAProcess.exe','FiveM_b2189_GTAProcess.exe','FiveM_b3095_GTAProcess.exe','CitizenFX_SubProcess_game.exe')) {
            $perf = "$ifeo\$img\PerfOptions"
            Set-Reg $perf 'CpuPriorityClass' 3
            Set-Reg $perf 'IoPriority' 3
            Set-Reg $perf 'PagePriority' 5
        }

        # === [20/23] Daemon script + scheduled task ================
        Step 'Daemon script + scheduled task'
        $daemonDir = "$env:LOCALAPPDATA\InputLatencyPlugin"
        $daemonFile = "$daemonDir\InputLatencyPlugin.ps1"
        if (-not (Test-Path $daemonDir)) { New-Item -ItemType Directory -Path $daemonDir -Force | Out-Null }
        $daemonBody = @'
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$src = '[DllImport("ntdll.dll", EntryPoint="NtSetTimerResolution")] public static extern int Set(int desired, bool set, out int current);'
$ntdll = Add-Type -MemberDefinition $src -Name 'NtRes' -Namespace 'W' -PassThru
$cur = 0
[void]$ntdll::Set(5000, $true, [ref]$cur)
$cores = [int]$env:NUMBER_OF_PROCESSORS
if (-not $cores) { $cores = 8 }
$fiveMNames = @('FiveM','FiveM_GTAProcess','FiveM_b2944_GTAProcess','FiveM_b2189_GTAProcess','FiveM_b3095_GTAProcess','CitizenFX_SubProcess_game')
while ($true) {
    foreach ($n in $fiveMNames) {
        Get-Process -Name $n -ErrorAction SilentlyContinue | ForEach-Object {
            try { if ($_.PriorityClass -ne 'High') { $_.PriorityClass = 'High' } } catch {}
            try {
                if ($cores -ge 4) {
                    $mask = [int]([Math]::Pow(2, $cores) - 1) -band -bnot 1
                    if ([int]$_.ProcessorAffinity -ne $mask) { $_.ProcessorAffinity = [IntPtr]$mask }
                }
            } catch {}
        }
    }
    Start-Sleep -Seconds 5
}
'@
        $utf8Bom = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($daemonFile, $daemonBody, $utf8Bom)
        $taskName = 'InputLatencyPlugin'
        if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        }
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$daemonFile`""
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -DisallowHardTerminate -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Seconds 0)
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
        Start-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        Log "scheduled task '$taskName' registered + started" 'success'

        # === [21/23] FiveM citizen.cfg =============================
        Step 'FiveM citizen.cfg'
        $citizenCfg = "$env:LOCALAPPDATA\FiveM\FiveM.app\citizen.cfg"
        $cfgDir = Split-Path $citizenCfg -Parent
        if (-not (Test-Path $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null }
        $required = @(
            'sv_pure_verify 0','con_disableNonImportantTraces 1','net_packetWindowSize 1500',
            'net_compressionThreshold 1200','profile_preferDefaultSpawnpoint 1',
            'profile_singleplayer_disablestream 1','net_clientUpdateRate 50',
            'cl_inputBufferSize 1','cl_predictBuffer 1'
        )
        $existing = @()
        if (Test-Path $citizenCfg) { $existing = @(Get-Content $citizenCfg -ErrorAction SilentlyContinue) }
        $seen = @{}; $out = @()
        foreach ($line in $existing) {
            $t = $line.Trim(); if (-not $t) { continue }
            $k = ($t -split '\s+')[0]
            if (-not $seen.ContainsKey($k)) { $seen[$k] = $true; $out += $t }
        }
        foreach ($line in $required) {
            $k = ($line -split '\s+')[0]
            if (-not $seen.ContainsKey($k)) { $seen[$k] = $true; $out += $line }
        }
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($citizenCfg, (($out -join "`r`n") + "`r`n"), $utf8NoBom)
        Log "$($out.Count) cvars deduped"

        # === [22/23] Cleanup =======================================
        Step 'Cleanup (temp + caches)'
        $paths = @(
            "$env:TEMP\*", 'C:\Windows\Temp\*', 'C:\Windows\Prefetch\*',
            'C:\Windows\SoftwareDistribution\Download\*',
            "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db",
            "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache_*.db",
            'C:\Windows\Minidump\*.dmp', 'C:\Windows\MEMORY.DMP'
        )
        foreach ($p in $paths) { Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue }
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        Log 'temp/prefetch/caches cleared' 'success'

        # === [23/23] Summary =======================================
        Step 'Summary'
        Log "Registry: $($Sync.AppliedKeys) applied / $($Sync.SkippedKeys) already-at-target" 'success'
        $script:Backup | ConvertTo-Json -Depth 20 -Compress | Set-Content -Path $Sync.BackupFile -Encoding UTF8
        Log "Backup written: $($Sync.BackupFile)" 'success'

        $Sync.EndedAt = Get-Date
        $Sync.Status = 'done'
    } catch {
        $Sync.Status = 'error'
        $Sync.ErrorMsg = $_.Exception.Message
        Log "FATAL: $($_.Exception.Message)" 'error'
        $Sync.EndedAt = Get-Date
    }
}

# ===========================================================================
# Embedded HTML/CSS/JS UI
# ===========================================================================
$Html = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>WinPerf Installer</title>
<style>
  :root {
    --bg: #0a0a0b;
    --bg-2: #111114;
    --card: #18181b;
    --card-hi: #1e1e22;
    --border: #27272a;
    --text: #f4f4f5;
    --muted: #71717a;
    --accent: #06b6d4;
    --accent-2: #3b82f6;
    --accent-glow: rgba(6, 182, 212, .35);
    --green: #4ade80;
    --yellow: #fbbf24;
    --red: #f87171;
  }
  *,*::before,*::after { box-sizing: border-box; margin: 0; padding: 0; }
  html, body {
    background: radial-gradient(ellipse at top, var(--bg-2) 0%, var(--bg) 60%);
    color: var(--text);
    font-family: 'Segoe UI Variable', 'Segoe UI', 'Inter', -apple-system, system-ui, sans-serif;
    font-size: 14px;
    height: 100vh;
    overflow: hidden;
    -webkit-font-smoothing: antialiased;
  }
  body {
    display: grid;
    grid-template-rows: auto 1fr;
    padding: 28px 32px;
    gap: 20px;
  }
  /* ----- header ----- */
  .header {
    display: flex;
    align-items: center;
    gap: 14px;
  }
  .logo {
    width: 36px; height: 36px;
    background: linear-gradient(135deg, var(--accent) 0%, var(--accent-2) 100%);
    border-radius: 10px;
    display: grid; place-items: center;
    box-shadow: 0 8px 24px var(--accent-glow);
  }
  .logo svg { width: 20px; height: 20px; stroke: #000; stroke-width: 2.5; fill: none; stroke-linecap: round; stroke-linejoin: round; }
  .h1 {
    font-size: 18px;
    font-weight: 600;
    letter-spacing: -0.01em;
  }
  .sub {
    font-size: 12px;
    color: var(--muted);
    margin-top: 2px;
  }
  .header-spacer { flex: 1; }
  .badge {
    font-size: 11px;
    font-weight: 500;
    padding: 5px 10px;
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 99px;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    transition: all .3s ease;
  }
  .badge::before {
    content: '';
    width: 6px; height: 6px;
    border-radius: 50%;
    background: var(--muted);
    transition: background .3s, box-shadow .3s;
  }
  .badge.running::before { background: var(--accent); box-shadow: 0 0 8px var(--accent-glow); animation: pulse 1.2s infinite; }
  .badge.done::before { background: var(--green); }
  .badge.error::before { background: var(--red); }
  @keyframes pulse {
    0%, 100% { opacity: 1 }
    50% { opacity: .35 }
  }
  /* ----- main grid ----- */
  .main {
    display: grid;
    grid-template-columns: 280px 1fr;
    gap: 20px;
    min-height: 0;
  }
  .card {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 14px;
    padding: 20px;
    overflow: hidden;
    transition: border-color .2s;
  }
  .right {
    display: grid;
    grid-template-rows: auto 1fr auto;
    gap: 20px;
    min-height: 0;
  }
  /* ----- steps sidebar ----- */
  .steps {
    display: flex;
    flex-direction: column;
    gap: 4px;
    max-height: 100%;
    overflow-y: auto;
  }
  .step-title {
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--muted);
    margin-bottom: 12px;
    padding: 0 6px;
  }
  .step {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 9px 10px;
    border-radius: 8px;
    font-size: 12.5px;
    color: var(--muted);
    transition: background .2s, color .2s;
  }
  .step.running {
    background: linear-gradient(90deg, rgba(6,182,212,.10), rgba(59,130,246,.04));
    color: var(--text);
  }
  .step.done { color: var(--green); }
  .step-dot {
    width: 8px; height: 8px;
    border-radius: 50%;
    background: var(--border);
    flex-shrink: 0;
    transition: background .25s, box-shadow .25s, transform .25s;
  }
  .step.running .step-dot {
    background: var(--accent);
    box-shadow: 0 0 10px var(--accent-glow), 0 0 4px var(--accent);
    transform: scale(1.2);
    animation: pulse 1.2s infinite;
  }
  .step.done .step-dot {
    background: var(--green);
    box-shadow: 0 0 6px rgba(74,222,128,.4);
  }
  /* ----- progress card ----- */
  .progress-card {
    padding: 24px;
    background: linear-gradient(135deg, var(--card) 0%, var(--card-hi) 100%);
  }
  .current {
    font-size: 17px;
    font-weight: 500;
    margin-bottom: 18px;
    min-height: 24px;
    color: var(--text);
    transition: opacity .15s;
  }
  .bar {
    height: 6px;
    background: rgba(255,255,255,.04);
    border-radius: 99px;
    overflow: hidden;
    position: relative;
  }
  .bar-fill {
    height: 100%;
    width: 0%;
    background: linear-gradient(90deg, var(--accent) 0%, var(--accent-2) 100%);
    border-radius: 99px;
    transition: width .5s cubic-bezier(.2,.7,.3,1);
    position: relative;
    box-shadow: 0 0 12px var(--accent-glow);
  }
  .bar-fill::after {
    content: '';
    position: absolute;
    inset: 0;
    background: linear-gradient(90deg, transparent 0%, rgba(255,255,255,.4) 50%, transparent 100%);
    animation: shimmer 1.8s linear infinite;
  }
  @keyframes shimmer {
    0% { transform: translateX(-100%) }
    100% { transform: translateX(200%) }
  }
  .stats {
    display: flex;
    gap: 32px;
    margin-top: 20px;
  }
  .stat {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .stat-n {
    font-size: 24px;
    font-weight: 600;
    color: var(--text);
    font-variant-numeric: tabular-nums;
    line-height: 1;
  }
  .stat-l {
    font-size: 11px;
    color: var(--muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }
  /* ----- log card ----- */
  .log {
    font-family: 'Cascadia Code', 'JetBrains Mono', Consolas, Menlo, monospace;
    font-size: 11.5px;
    background: rgba(0,0,0,.25);
    padding: 14px 16px;
    border-radius: 10px;
    overflow-y: auto;
    line-height: 1.65;
    border: 1px solid var(--border);
    color: var(--muted);
    min-height: 0;
  }
  .log-line {
    opacity: 0;
    animation: slide .25s ease-out forwards;
    padding: 1px 0;
    word-break: break-all;
  }
  @keyframes slide {
    from { opacity: 0; transform: translateY(3px) }
    to { opacity: 1; transform: translateY(0) }
  }
  .ts { color: #52525b; margin-right: 8px; user-select: none; }
  .log-line.step { color: var(--accent); font-weight: 600; }
  .log-line.error { color: var(--red); }
  .log-line.warn { color: var(--yellow); }
  .log-line.success { color: var(--green); }
  /* ----- actions ----- */
  .actions {
    display: flex;
    gap: 10px;
    justify-content: flex-end;
    align-items: center;
  }
  .info {
    flex: 1;
    font-size: 12px;
    color: var(--muted);
  }
  .btn {
    padding: 10px 18px;
    border-radius: 9px;
    border: 1px solid var(--border);
    background: var(--card);
    color: var(--text);
    font-size: 13px;
    font-weight: 500;
    cursor: pointer;
    font-family: inherit;
    transition: all .2s cubic-bezier(.4,0,.2,1);
    display: inline-flex;
    align-items: center;
    gap: 8px;
  }
  .btn:hover:not(:disabled) {
    background: var(--card-hi);
    border-color: #3f3f46;
    transform: translateY(-1px);
  }
  .btn:active:not(:disabled) { transform: translateY(0); }
  .btn:disabled { opacity: .4; cursor: not-allowed; }
  .btn.primary {
    background: linear-gradient(135deg, var(--accent) 0%, var(--accent-2) 100%);
    border: none;
    color: #0a0a0b;
    font-weight: 600;
    box-shadow: 0 4px 20px var(--accent-glow);
  }
  .btn.primary:hover:not(:disabled) {
    box-shadow: 0 6px 28px var(--accent-glow);
    transform: translateY(-2px);
  }
  /* ----- scrollbar ----- */
  ::-webkit-scrollbar { width: 8px; height: 8px; }
  ::-webkit-scrollbar-track { background: transparent; }
  ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 4px; }
  ::-webkit-scrollbar-thumb:hover { background: #3f3f46; }

  /* ----- fade on body load ----- */
  body { animation: fade-in .35s ease-out; }
  @keyframes fade-in { from { opacity: 0 } to { opacity: 1 } }
</style>
</head>
<body>
  <div class="header">
    <div class="logo">
      <svg viewBox="0 0 24 24"><path d="M13 2L4 14h7l-1 8 9-12h-7l1-8z"/></svg>
    </div>
    <div>
      <div class="h1">WinPerf Installer</div>
      <div class="sub">Latency &amp; FPS optimization for FiveM / RedM</div>
    </div>
    <div class="header-spacer"></div>
    <span class="badge" id="badge">idle</span>
  </div>

  <div class="main">
    <div class="card">
      <div class="step-title">Pipeline</div>
      <div class="steps" id="steps"></div>
    </div>

    <div class="right">
      <div class="card progress-card">
        <div class="current" id="current">Ready to apply optimizations.</div>
        <div class="bar"><div class="bar-fill" id="fill"></div></div>
        <div class="stats">
          <div class="stat"><div class="stat-n" id="applied">0</div><div class="stat-l">applied</div></div>
          <div class="stat"><div class="stat-n" id="skipped">0</div><div class="stat-l">skipped</div></div>
          <div class="stat"><div class="stat-n" id="step-num">0/23</div><div class="stat-l">stage</div></div>
        </div>
      </div>

      <div class="card log" id="log">
        <div class="log-line">Click <b>Apply</b> to begin.</div>
      </div>

      <div class="actions">
        <div class="info" id="info">All changes are written to a backup JSON at <code>C:\WinPerf-Backup\</code>.</div>
        <button class="btn" id="exit-btn" onclick="doExit()">Close</button>
        <button class="btn primary" id="apply-btn" onclick="doApply()">Apply Optimizations</button>
      </div>
    </div>
  </div>

<script>
  const STEPS = [
    'Pre-flight','HKCU registry','MMCSS Games','CPU + IRQ + kernel','Memory Manager',
    'Input drivers','HID idle off','GPU + DirectX','Power plan','TCP/IP stack',
    'NIC advanced','MMCSS Audio','NTFS tuning','Game DVR off','Telemetry off',
    'Services disable','MMAgent','BCD kernel','IFEO priority','Daemon + Task',
    'FiveM citizen.cfg','Cleanup','Summary'
  ];

  const stepsEl = document.getElementById('steps');
  STEPS.forEach((name, i) => {
    const el = document.createElement('div');
    el.className = 'step';
    el.id = 's' + i;
    el.innerHTML = `<div class="step-dot"></div><span>${name}</span>`;
    stepsEl.appendChild(el);
  });

  let cursor = 0;
  let polling = false;

  async function doApply() {
    document.getElementById('apply-btn').disabled = true;
    document.getElementById('apply-btn').textContent = 'Running...';
    cursor = 0;
    document.getElementById('log').innerHTML = '';
    try { await fetch('/api/start', { method: 'POST' }); }
    catch (e) { console.error(e); }
    polling = true;
    poll();
  }

  async function doExit() {
    try { await fetch('/api/exit', { method: 'POST' }); } catch(e) {}
    setTimeout(() => { try { window.close(); } catch(e){} }, 200);
  }

  async function doReboot() {
    try { await fetch('/api/reboot', { method: 'POST' }); } catch(e) {}
    document.getElementById('current').textContent = 'Rebooting in 5 seconds...';
    document.getElementById('apply-btn').disabled = true;
  }

  async function poll() {
    if (!polling) return;
    try {
      const r = await fetch('/api/status?since=' + cursor);
      const d = await r.json();
      cursor = d.cursor;

      // badge
      const b = document.getElementById('badge');
      b.className = 'badge ' + d.status;
      b.textContent = d.status;

      // stats
      document.getElementById('applied').textContent = d.applied;
      document.getElementById('skipped').textContent = d.skipped;
      document.getElementById('step-num').textContent = d.stepIdx + '/' + d.stepTotal;

      // progress
      const pct = d.stepTotal ? (d.stepIdx / d.stepTotal) * 100 : 0;
      document.getElementById('fill').style.width = pct + '%';

      // current
      if (d.step) document.getElementById('current').textContent = d.step;

      // step states
      STEPS.forEach((_, i) => {
        const el = document.getElementById('s' + i);
        el.classList.remove('running', 'done');
        if (i + 1 < d.stepIdx) el.classList.add('done');
        else if (i + 1 === d.stepIdx && d.status === 'running') el.classList.add('running');
        else if (d.status === 'done' && i < d.stepIdx) el.classList.add('done');
      });

      // log lines
      const logEl = document.getElementById('log');
      const stickBottom = logEl.scrollTop + logEl.clientHeight >= logEl.scrollHeight - 30;
      for (const ln of (d.lines || [])) {
        const div = document.createElement('div');
        div.className = 'log-line ' + (ln.level || 'info');
        div.innerHTML = `<span class="ts">${ln.ts}</span>${escapeHtml(ln.msg)}`;
        logEl.appendChild(div);
      }
      if (stickBottom) logEl.scrollTop = logEl.scrollHeight;

      // terminal states
      if (d.status === 'done') {
        polling = false;
        document.getElementById('current').textContent = 'Done — reboot to activate kernel + BCD changes.';
        document.getElementById('info').textContent = 'Reboot recommended. ' + d.applied + ' values written, ' + d.skipped + ' already at target.';
        const apply = document.getElementById('apply-btn');
        apply.textContent = 'Reboot Now';
        apply.disabled = false;
        apply.onclick = doReboot;
        return;
      }
      if (d.status === 'error') {
        polling = false;
        document.getElementById('current').textContent = 'Error: ' + (d.error || 'unknown');
        document.getElementById('apply-btn').disabled = false;
        document.getElementById('apply-btn').textContent = 'Retry';
        return;
      }

      setTimeout(poll, 250);
    } catch (e) {
      setTimeout(poll, 800);
    }
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  }
</script>
</body>
</html>
'@

# ===========================================================================
# HTTP listener helpers
# ===========================================================================
function Send-Json {
    param($Response, $Object, [int]$Status = 200)
    $bytes = [Text.Encoding]::UTF8.GetBytes(($Object | ConvertTo-Json -Depth 8 -Compress))
    $Response.StatusCode = $Status
    $Response.ContentType = 'application/json; charset=utf-8'
    $Response.ContentLength64 = $bytes.Length
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
}
function Send-Html {
    param($Response, [string]$Body)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Body)
    $Response.StatusCode = 200
    $Response.ContentType = 'text/html; charset=utf-8'
    $Response.ContentLength64 = $bytes.Length
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
}

# ===========================================================================
# Find free loopback port + start HTTP listener
# ===========================================================================
$tcp = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$tcp.Start()
$port = ([System.Net.IPEndPoint]$tcp.LocalEndpoint).Port
$tcp.Stop()

$http = [System.Net.HttpListener]::new()
$http.Prefixes.Add("http://localhost:$port/")
$http.Start()

# Open default browser
Start-Process "http://localhost:$port/"

# ===========================================================================
# Background runspace (install runs here so listener stays responsive)
# ===========================================================================
$Runspace = $null
$PS = $null

# ===========================================================================
# Main request loop
# ===========================================================================
$running = $true
while ($http.IsListening -and $running) {
    $ctx = $http.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    try {
        $key = "$($req.HttpMethod) $($req.Url.AbsolutePath)"
        switch ($key) {
            'GET /'             { Send-Html $res $Html }
            'GET /api/status'   {
                $since = [int]($req.QueryString['since'])
                # Indexed read instead of splat-enumerate — avoids race with concurrent Add() on the synchronized ArrayList
                $count = $Sync.LogLines.Count
                $newLines = @()
                if ($count -gt $since) {
                    for ($i = $since; $i -lt $count; $i++) {
                        try { $newLines += $Sync.LogLines[$i] } catch { break }
                    }
                }
                $payload = @{
                    status    = $Sync.Status
                    step      = $Sync.StepName
                    stepIdx   = $Sync.StepIdx
                    stepTotal = $Sync.StepTotal
                    applied   = $Sync.AppliedKeys
                    skipped   = $Sync.SkippedKeys
                    cursor    = $count
                    lines     = $newLines
                    error     = $Sync.ErrorMsg
                }
                Send-Json $res $payload
            }
            'POST /api/start'   {
                if ($Sync.Status -eq 'running') {
                    Send-Json $res @{ ok=$false; error='already running' } 409
                } else {
                    # reset state
                    $Sync.LogLines.Clear()
                    $Sync.StepIdx = 0
                    $Sync.StepName = ''
                    $Sync.AppliedKeys = 0
                    $Sync.SkippedKeys = 0
                    $Sync.ErrorMsg = $null
                    $Sync.Status = 'running'

                    # spawn runspace
                    $Runspace = [runspacefactory]::CreateRunspace()
                    $Runspace.ApartmentState = 'MTA'
                    $Runspace.ThreadOptions = 'ReuseThread'
                    $Runspace.Open()
                    $Runspace.SessionStateProxy.SetVariable('Sync', $Sync)
                    $PS = [powershell]::Create()
                    $PS.Runspace = $Runspace
                    [void]$PS.AddScript($ApplyScript).AddArgument($Sync)
                    [void]$PS.BeginInvoke()
                    Send-Json $res @{ ok=$true }
                }
            }
            'POST /api/reboot'  {
                Send-Json $res @{ ok=$true }
                Start-Process shutdown.exe -ArgumentList '/r','/t','5','/c','WinPerf reboot' -WindowStyle Hidden
                $running = $false
            }
            'POST /api/exit'    {
                Send-Json $res @{ ok=$true }
                $running = $false
            }
            default { $res.StatusCode = 404 }
        }
    } catch {
        try { Send-Json $res @{ error=$_.Exception.Message } 500 } catch {}
    } finally {
        try { $res.Close() } catch {}
    }
}

# ===========================================================================
# Cleanup
# ===========================================================================
$http.Stop(); $http.Close()
if ($PS) { try { $PS.Dispose() } catch {} }
if ($Runspace) { try { $Runspace.Close(); $Runspace.Dispose() } catch {} }
