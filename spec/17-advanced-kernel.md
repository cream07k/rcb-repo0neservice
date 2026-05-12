---
section: 17-advanced-kernel
applies_to: [Win10, Win11]
order: 170
risk: high
ac_safe: false
opt_in: true
---

# Advanced kernel — opt-in only

This section trades kernel-level safety nets for additional FPS. Anti-cheats that verify Memory Integrity (Vanguard, FACEIT) will detect changes here.

## When to apply

Only when ALL of the following are true:
1. User explicitly says "ใช้ advanced profile" / "apply advanced kernel"
2. No `vgc` (Vanguard) service present
3. No `FACEITService` present
4. User re-confirms after Claude shows the risk warning

## Confirmation prompt (Thai)

```
คุณกำลังจะ apply ADVANCED KERNEL profile — ปิด:
  - Memory Integrity (HVCI)
  - VBS (Virtualization-Based Security)
  - GPU TDR auto-recovery
  - Speculative execution mitigations (Spectre/Meltdown family)
  - HPET / dynamic tick (via BCD)
  - Page combining
  - Kernel pinning

ผลที่ได้: FPS +15-30%, latency -5ms เพิ่ม
ผลเสีย:
  - ถ้าเล่น Valorant หรือ FACEIT → ถูก ban
  - ถ้า GPU ค้าง = BSOD แทนการ recover
  - security mitigations ที่ป้องกัน Spectre/Meltdown หายไป

ยืนยันหรือไม่? (พิมพ์ "ยืนยัน advanced")
```

Apply only after the user types the exact phrase "ยืนยัน advanced".

## Backup metadata

In the backup JSON, set `mode = "aggressive"` so restore knows to also re-enable HVCI/VBS.

## Settings

### GPU TDR

Path: `HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers`

| Name | Type | Value | Note |
|------|------|-------|------|
| TdrLevel | DWord | 0 | GPU never auto-recovers — BSOD on hang |

### HVCI / Memory Integrity off

Path: `HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard`

| Name | Type | Value |
|------|------|-------|
| EnableVirtualizationBasedSecurity | DWord | 0 |
| RequirePlatformSecurityFeatures | DWord | 0 |
| HypervisorEnforcedCodeIntegrity | DWord | 0 |
| LsaCfgFlags | DWord | 0 |

Path: `HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity`

| Name | Type | Value |
|------|------|-------|
| Enabled | DWord | 0 |

### Speculative execution mitigations

Path: `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management`

| Name | Type | Value |
|------|------|-------|
| FeatureSettingsOverride | DWord | 3 |
| FeatureSettingsOverrideMask | DWord | 3 |

### BCD boot tweaks

```cmd
bcdedit /deletevalue useplatformclock
bcdedit /set disabledynamictick yes
bcdedit /set useplatformtick no
bcdedit /set tscsyncpolicy Enhanced
```

## Restore for advanced mode

If `mode = "aggressive"` in backup:
1. Restore TdrLevel to Windows default (delete the value)
2. Re-enable HVCI: `Enabled = 1`
3. Re-enable VBS: `EnableVirtualizationBasedSecurity = 1`
4. Reset speculation mitigations: delete `FeatureSettingsOverride*`
5. Reset BCD: `bcdedit /deletevalue useplatformclock`, `bcdedit /set disabledynamictick no`, `bcdedit /deletevalue useplatformtick`, `bcdedit /deletevalue tscsyncpolicy`
6. Reboot
