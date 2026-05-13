---
section: 15-services
applies_to: [Win10, Win11, Server]
order: 150
risk: low
ac_safe: true
---

# Services — disable bloat (with Game Pass + anti-cheat detection)

## Implementation

```powershell
function Disable-SvcSafe {
    param([string]$Name, [string[]]$NeverTouch)
    if ($Name -in $NeverTouch) { Write-Host "skip $Name (never-touch)"; return }
    try {
        $svc = Get-Service -Name $Name -ErrorAction Stop
        Set-Service -Name $Name -StartupType Disabled -ErrorAction SilentlyContinue
        Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        Write-Host "[DISABLED] $Name"
    } catch {
        Write-Host "[ABSENT] $Name (not on this SKU)"
    }
}
```

## Telemetry / diagnostic services

```
DiagTrack
dmwappushservice
DPS
WdiServiceHost
WdiSystemHost
DiagSvc
diagnosticshub.standardcollector.service
DcpSvc
WerSvc
PcaSvc
```

## Bloat / unused on gaming PCs

```
Fax
RetailDemo
MapsBroker
WMPNetworkSvc
TrkWks
WpcMonSvc
Spooler                # disable only if no printer
PrintNotify            # same
WbioSrvc
TabletInputService
PhoneSvc
MessagingService
PimIndexMaintenanceSvc
OneSyncSvc
UnistoreSvc
UserDataSvc
wisvc
lfsvc
SCardSvr               # disable if no smart-card
ScDeviceEnum
SCPolicySvc
SensrSvc
SensorService
SensorDataService
SharedAccess
RemoteRegistry
RemoteAccess
SessionEnv
TermService            # disable if not using RDP
UmRdpService
QWAVE
SSDPSRV
upnphost
HomeGroupListener
HomeGroupProvider
TapiSrv
ALG
SNMP
SNMPTrap
Browser
NetTcpPortSharing
PolicyAgent
RasMan
RasAuto
```

## RAM-gated (only if RAM ≥ 16GB)

```
WSearch
SysMain
```

## Game Pass-gated (skip if XboxGamePass installed)

```
XblAuthManager
XblGameSave
XboxNetApiSvc
XboxGipSvc             # keep if Xbox controller in use
```

## Vendor telemetry

```
NvTelemetryContainer
NvContainerLocalSystem      # set to Manual not Disabled (parent service)
NvStreamSvc
NvBroadcast.ContainerLocalSystem
NVDisplay.ContainerLocalSystem    # set to Manual not Disabled
AMD External Events Utility
AMD User Experience Program
```

## Bluetooth (disable if no BT devices)

```
bthserv
BthAvctpSvc
BluetoothUserService
```

## NEVER TOUCH (security/boot/anti-cheat critical)

```
WinDefend
MpsSvc
wuauserv
BFE
EventLog
Sense
SecurityHealthService
SgrmBroker
vgc
vgk
EasyAntiCheat
EasyAntiCheat_EOS
BEService
BEDaisy
FACEITService
DcomLaunch
RpcEptMapper
RpcSs
LSM
Power
PlugPlay
```

## Scheduled tasks to disable

```powershell
$tasks = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
    "\Microsoft\Windows\Application Experience\StartupAppTask",
    "\Microsoft\Windows\Application Experience\PcaPatchDbTask",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
    "\Microsoft\Windows\Customer Experience Improvement Program\Uploader",
    "\Microsoft\Windows\Autochk\Proxy",
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
    "\Microsoft\Windows\Maintenance\WinSAT",
    "\Microsoft\Windows\Feedback\Siuf\DmClient",
    "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",
    "\Microsoft\Windows\Windows Error Reporting\QueueReporting",
    "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",
    "\Microsoft\Windows\InstallService\ScanForUpdates",
    "\Microsoft\Windows\Defrag\ScheduledDefrag",
    "\Microsoft\Windows\Diagnosis\Scheduled",
    "\Microsoft\Windows\NetTrace\GatherNetworkInfo",
    "\Microsoft\Windows\PI\Sqm-Tasks"
)
foreach ($t in $tasks) {
    schtasks /Change /TN $t /Disable 2>$null | Out-Null
}
```
