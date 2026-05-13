---
section: 04-mmcss
applies_to: [Win10, Win11, Server]
order: 40
risk: low
ac_safe: true
---

# MMCSS (Multimedia Class Scheduler)

## System profile

Path: `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile`

| Name | Type | Value | Impact |
|------|------|-------|--------|
| NetworkThrottlingIndex | DWord | 0xFFFFFFFF | Throttling off (default 10 pkt/ms — bad for games) |
| SystemResponsiveness | DWord | 0 | 0% reserved for background; all to foreground |

## Games task profile

Path: `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games`

| Name | Type | Value |
|------|------|-------|
| GPU Priority | DWord | 8 |
| Priority | DWord | 8 |
| Scheduling Category | String | "High" |
| SFIO Priority | String | "High" |
| Background Only | String | "False" |
| Clock Rate | DWord | 10000 |
| Latency Sensitive | String | "True" |
| Affinity | DWord | 0 |
| NoLazyMode | DWord | 1 |

## Audio task profile

Path: `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio`

| Name | Type | Value |
|------|------|-------|
| Scheduling Category | String | "High" |
| SFIO Priority | String | "Normal" |
| Clock Rate | DWord | 10000 |
| Priority | DWord | 5 |
| GPU Priority | DWord | 2 |

## Pro Audio task profile

Path: `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio`

| Name | Type | Value |
|------|------|-------|
| Scheduling Category | String | "High" |
| SFIO Priority | String | "High" |
| Priority | DWord | 6 |
| Clock Rate | DWord | 10000 |
| Latency Sensitive | String | "True" |
