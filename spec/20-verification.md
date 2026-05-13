---
section: 20-verification
applies_to: [Win10, Win11, Server]
order: 200
risk: none
ac_safe: true
---

# Verification — run after applying

## TCP

```powershell
Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" |
    Select TCPNoDelay, TcpAckFrequency, TcpDelAckTicks, DisableTaskOffload, MaxUserPort
```

Expected:
```
TCPNoDelay      : 1
TcpAckFrequency : 1
TcpDelAckTicks  : 0
DisableTaskOffload : 1
MaxUserPort     : 65534
```

## NetSH

```powershell
netsh int tcp show global
```

Expected: chimney=disabled, RSS=enabled, congestionprovider=ctcp, ECN=disabled, timestamps=disabled, heuristics=disabled.

## Power scheme

```powershell
powercfg /getactivescheme
```

Expected: "Ultimate Performance" (or "High Performance" fallback).

## Services state

```powershell
$keyServices = @('DiagTrack','WSearch','SysMain','Fax','MapsBroker','RetailDemo','WerSvc')
Get-Service $keyServices -ErrorAction SilentlyContinue | Select Name, Status, StartType
```

Expected: StartType=Disabled.

## GPU MSI mode

```powershell
Get-PnpDevice -Class Display | ForEach-Object {
    $p = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
    $v = (Get-ItemProperty $p -Name MSISupported -ErrorAction SilentlyContinue).MSISupported
    "$($_.FriendlyName): MSI=$v"
}
```

Expected: each GPU shows MSI=1.

## NIC offloading

```powershell
Get-NetAdapter -Physical | Where Status -eq Up | ForEach-Object {
    Get-NetAdapterAdvancedProperty -Name $_.Name -DisplayName "Energy Efficient Ethernet","Flow Control","Interrupt Moderation" -ErrorAction SilentlyContinue |
        Select Name, DisplayName, DisplayValue
}
```

Expected: each property = Disabled.

## NTFS state

```cmd
fsutil behavior query disable8dot3
fsutil behavior query disablelastaccess
fsutil behavior query memoryusage
```

Expected: 8dot3=1, lastaccess=1, memoryusage=2.

## Hibernate

```powershell
powercfg /availablesleepstates
```

Expected: "The following sleep states are not available on this system: Hibernate."

## HVCI (only if §17 advanced applied)

```powershell
Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard |
    Select-Object SecurityServicesRunning
```

Expected: empty array (HVCI off).

## Final report to user

```
Verification: <N> checks passed, <N> failed
Failed items: <list>

Backup file: C:\WinPerf-Backup\backup-<timestamp>.json

REBOOT NOW for full effect:
  shutdown /r /t 0
```
