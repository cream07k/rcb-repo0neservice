---
section: 02-network-nic
applies_to: [Win10, Win11, Server]
order: 20
risk: low
ac_safe: true
---

# NIC advanced properties — disable all offloading + power saving

For each `Get-NetAdapter -Physical | Where Status -eq 'Up'`, apply via:
```powershell
Set-NetAdapterAdvancedProperty -Name $a.Name -DisplayName <Name> -DisplayValue <Value> -ErrorAction SilentlyContinue
```

Properties may not exist on every NIC — use SilentlyContinue and log applied vs skipped.

## Power management

```powershell
Set-NetAdapterPowerManagement -Name $a.Name -AllowComputerToTurnOff Disabled
Set-NetAdapterPowerManagement -Name $a.Name -ArpOffload Disabled
Set-NetAdapterPowerManagement -Name $a.Name -NSOffload Disabled
Set-NetAdapterPowerManagement -Name $a.Name -SelectiveSuspend Disabled
Set-NetAdapterPowerManagement -Name $a.Name -WakeOnMagicPacket Disabled
Set-NetAdapterPowerManagement -Name $a.Name -WakeOnPattern Disabled
```

## Energy / Green Ethernet OFF

| Property | Value |
|----------|-------|
| Energy Efficient Ethernet | Disabled |
| Green Ethernet | Disabled |
| Auto Disable Gigabit | Disabled |
| Advanced EEE | Disabled |
| Ultra Low Power Mode | Disabled |
| EEE Max Wake Time | 0 |
| Gigabit Lite | Disabled |

## Flow control + offloading OFF

| Property | Value |
|----------|-------|
| Flow Control | Disabled |
| Interrupt Moderation | Disabled |
| Interrupt Moderation Rate | Off |
| Jumbo Packet | Disabled |
| Jumbo Frame | Disabled |
| Large Send Offload V2 (IPv4) | Disabled |
| Large Send Offload V2 (IPv6) | Disabled |
| Large Send Offload (IPv4) | Disabled |
| TCP Checksum Offload (IPv4) | Disabled |
| TCP Checksum Offload (IPv6) | Disabled |
| UDP Checksum Offload (IPv4) | Disabled |
| UDP Checksum Offload (IPv6) | Disabled |
| IPv4 Checksum Offload | Disabled |
| Recv Segment Coalescing (IPv4) | Disabled |
| Recv Segment Coalescing (IPv6) | Disabled |
| ARP Offload | Disabled |
| NS Offload | Disabled |
| PME | Disabled |

## Buffer sizes — maximize

| Property | Value |
|----------|-------|
| Receive Buffers | 2048 |
| Transmit Buffers | 2048 |

## RSS multi-core scaling

| Property | Value |
|----------|-------|
| Receive Side Scaling | Enabled |
| Maximum Number of RSS Queues | 8 |
| RSS Profile | NUMA Static (or ClosestStatic if non-NUMA) |
| Number of RSS Queues | 8 |

## Realtek-specific (only if Realtek NIC detected)

| Property | Value |
|----------|-------|
| Disable HARDPS Algorithm | Enabled |
| WOL Speed | 10 Mbps |
| Shutdown WOL | Disabled |
| Priority & VLAN | Disabled |

## Intel-specific (only if Intel NIC detected)

| Property | Value |
|----------|-------|
| Adaptive Inter-Frame Spacing | Disabled |
| DMA Coalescing | Disabled |
| Wait for Link | Off |
| Reduce Speed On Power Down | Disabled |
| Gigabit Master Slave Mode | Auto Detect |
