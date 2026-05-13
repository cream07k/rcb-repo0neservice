---
section: 01-network-tcp
applies_to: [Win10, Win11, Server]
order: 10
risk: low
ac_safe: true
---

# TCP/IP stack tuning

## Registry: HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters

| Name | Type | Value | Impact |
|------|------|-------|--------|
| TCPNoDelay | DWord | 1 | Nagle off — saves ~40ms batch latency |
| TcpAckFrequency | DWord | 1 | Immediate ACK — saves ~10-15ms per RTT |
| TcpDelAckTicks | DWord | 0 | No 200ms delayed-ACK timer |
| DefaultTTL | DWord | 64 | Linux-compatible TTL |
| EnableTCPA | DWord | 0 | TCP-A off (buggy on some drivers) |
| EnableWsd | DWord | 0 | WSD off |
| DisableTaskOffload | DWord | 1 | CPU TCP processing (avoid NIC bugs) |
| MaxUserPort | DWord | 65534 | Max ephemeral port range |
| TcpTimedWaitDelay | DWord | 30 | Faster port reuse (default 120s) |
| KeepAliveTime | DWord | 7200000 | 2hr keep-alive idle (default) |
| KeepAliveInterval | DWord | 1000 | 1s keep-alive interval once started |
| TcpMaxDataRetransmissions | DWord | 5 | Default |
| MaxFreeTcbs | DWord | 65535 | Max TCB entries |
| MaxHashTableSize | DWord | 65535 | Hash table for TCB lookup |
| Tcp1323Opts | DWord | 1 | Enable window scaling |
| TCPInitialRtt | DWord | 2000 | 2s initial RTO |
| MaxConnectRetries | DWord | 2 | Fast fail-and-retry |
| EnablePMTUDiscovery | DWord | 1 | Path MTU Discovery on |
| EnablePMTUBHDetect | DWord | 0 | Don't auto-detect black-hole routers |

## Per-interface registry

For each `Get-NetAdapter -Physical | Where Status -eq 'Up'`:

Path: `HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\<InterfaceGUID>`

| Name | Type | Value |
|------|------|-------|
| TcpAckFrequency | DWord | 1 |
| TCPNoDelay | DWord | 1 |
| TcpDelAckTicks | DWord | 0 |
| TcpInitialRtt | DWord | 2000 |
| UseZeroBroadcast | DWord | 0 |
| EnableDeadGWDetect | DWord | 0 |

## NetSH global parameters

```
netsh int tcp set global autotuninglevel=normal
netsh int tcp set global rss=enabled
netsh int tcp set global chimney=disabled
netsh int tcp set global ecncapability=disabled
netsh int tcp set global timestamps=disabled
netsh int tcp set global initialRto=2000
netsh int tcp set global congestionprovider=ctcp
netsh int tcp set global rsc=disabled
netsh int tcp set heuristics disabled
netsh int tcp set supplemental internet congestionprovider=ctcp
netsh int tcp set supplemental datacenter congestionprovider=ctcp
netsh int tcp set supplemental compat congestionprovider=ctcp
netsh int ip set global taskoffload=disabled
netsh int ip set global icmpredirects=disabled
netsh int ip set global sourceroutingbehavior=drop
netsh int ip set global multicastforwarding=disabled
```

## IPv6 deprioritize (don't disable — apps may break)

Path: `HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters`

| Name | Type | Value | Note |
|------|------|-------|------|
| DisabledComponents | DWord | 0x20 | Prefer IPv4 in DNS resolution; IPv6 stack stays available |

## NetBIOS off per adapter

Same path as per-interface above:

| Name | Type | Value |
|------|------|-------|
| NetbiosOptions | DWord | 2 |

## LLMNR + mDNS off

Path: `HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient`

| Name | Type | Value |
|------|------|-------|
| EnableMulticast | DWord | 0 |

## DNS Cache tuning

Path: `HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters`

| Name | Type | Value | Note |
|------|------|-------|------|
| MaxCacheTtl | DWord | 86400 | 24h cache on success |
| MaxNegativeCacheTtl | DWord | 5 | 5s cache on failure |
| NegativeSOACacheTime | DWord | 0 | |
| NetFailureCacheTime | DWord | 0 | |

## DNS = Cloudflare per adapter

```powershell
Get-NetAdapter -Physical | Where {$_.Status -eq 'Up'} | ForEach-Object {
    Set-DnsClientServerAddress -InterfaceAlias $_.Name -ServerAddresses '1.1.1.1','1.0.0.1'
}
```

## ARP cache tuning

Path: `HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters`

| Name | Type | Value |
|------|------|-------|
| ArpCacheLife | DWord | 600 |
| ArpCacheMinReferencedLife | DWord | 600 |
| ArpRetryCount | DWord | 2 |

## AFD (Winsock backend) tuning

Path: `HKLM:\SYSTEM\CurrentControlSet\Services\AFD\Parameters`

| Name | Type | Value |
|------|------|-------|
| DefaultReceiveWindow | DWord | 65536 |
| DefaultSendWindow | DWord | 65536 |
| FastSendDatagramThreshold | DWord | 1024 |
| TransmitWorker | DWord | 0x20 |
| LargeBufferSize | DWord | 81920 |
| MediumBufferSize | DWord | 15360 |
| SmallBufferSize | DWord | 256 |

## HTTP connection limits

Path: `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings`

| Name | Type | Value |
|------|------|-------|
| MaxConnectionsPerServer | DWord | 16 |
| MaxConnectionsPer1_0Server | DWord | 16 |
