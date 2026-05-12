---
section: 08-memory
applies_to: [Win10, Win11, Server]
order: 80
risk: low
ac_safe: true
---

# Memory manager tuning

Path: `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management`

| Name | Type | Value | Impact |
|------|------|-------|--------|
| DisablePagingExecutive | DWord | 1 | Kernel paged code stays in RAM. Faster kernel calls. |
| LargeSystemCache | DWord | 0 | 0 = workstation cache profile (smaller, faster) |
| IoPageLockLimit | DWord | 0x10000 | 64KB IO pages locked |
| PoolUsageMaximum | DWord | 96 | Pool can use 96% of pages |
| DisablePageCombining | DWord | 1 | Skip CPU work of finding identical pages |
| ClearPageFileAtShutdown | DWord | 0 | Don't zero the page file at shutdown |
| MoveImages | DWord | 0 | Don't relocate kernel images at boot |
| NonPagedPoolQuota | DWord | 0 | Auto |
| NonPagedPoolSize | DWord | 0 | Auto |
| PagedPoolQuota | DWord | 0 | Auto |
| PagedPoolSize | DWord | 0 | Auto |
| PhysicalAddressExtension | DWord | 1 | PAE on |
| SecondLevelDataCache | DWord | 1024 | Hint to scheduler about L2 cache (KB) |

## Working set behavior

Path: `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer`

| Name | Type | Value |
|------|------|-------|
| AutoEndTasks | String | "1" |
