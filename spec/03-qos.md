---
section: 03-qos
applies_to: [Win10, Win11, Server]
order: 30
risk: none
ac_safe: true
---

# QoS Packet Scheduler

Path: `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched`

| Name | Type | Value | Impact |
|------|------|-------|--------|
| NonBestEffortLimit | DWord | 0 | Release 20% bandwidth reserve to apps |
| TimerResolution | DWord | 1 | 1ms scheduler resolution |
| TcpWindowSize | DWord | 0 | No QoS-imposed window cap |
| DefaultTOSValue | DWord | 0 | |
