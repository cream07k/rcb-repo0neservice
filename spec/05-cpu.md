---
section: 05-cpu
applies_to: [Win10, Win11, Server]
order: 50
risk: low
ac_safe: true
---

# CPU priority + scheduling

## Priority control

Path: `HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl`

| Name | Type | Value | Impact |
|------|------|-------|--------|
| Win32PrioritySeparation | DWord | 38 | Short quantum + 2x foreground boost |
| IRQ1Priority | DWord | 1 | Keyboard IRQ priority (PS/2 + legacy emulated) |
| IRQ8Priority | DWord | 1 | RTC IRQ priority |
| IRQ12Priority | DWord | 1 | Mouse IRQ priority (PS/2 + legacy emulated) |
| IRQ16Priority | DWord | 2 | GPU IRQ priority on some chipsets |

Bit breakdown for Win32PrioritySeparation=38 (0x26):
- bits 0-1: foreground quantum = 10 (short)
- bits 2-3: quantum length = 0 (fixed)
- bits 4-5: foreground boost = 2 (max)

## Process scheduler

Path: `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Executive`

| Name | Type | Value |
|------|------|-------|
| AdditionalCriticalWorkerThreads | DWord | 16 |
| AdditionalDelayedWorkerThreads | DWord | 16 |

## Session manager — heap tuning

Path: `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager`

| Name | Type | Value |
|------|------|-------|
| ProtectionMode | DWord | 1 |
| HeapDeCommitFreeBlockThreshold | DWord | 0x40000 |
| HeapDeCommitTotalFreeThreshold | DWord | 0x40000 |
| HeapSegmentCommit | DWord | 0x40000 |
| HeapSegmentReserve | DWord | 0x100000 |
