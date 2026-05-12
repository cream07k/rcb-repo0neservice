---
profile: Win10
applies_to_builds: [19041, 19042, 19043, 19044, 19045]
---

# Windows 10 overrides

## Skip on Win10 < build 19041

- §07 GPU section: skip `HwSchMode` (HAGS introduced in build 19041 / 2004)
- §06 Power: Ultimate Performance plan only on Win10 Pro for Workstations + Enterprise
- §17 Advanced: skip `HVCI Scenarios` key on Win10 < 1903 (different path)

## Different on Win10

- DNS over HTTPS not available pre-2004 — skip if attempting (we don't enable DoH in the spec)
- Modern Standby (S0) — most Win10 builds use S3 standby, so `PlatformAoAcOverride` is a no-op (still safe to set)

## Apply anyway

- §16 Services: same list works, but some services have different names on Win10:
  - `WSearch` → same
  - `SysMain` → on Win10 1709+ same name; older = `Superfetch`
  - `XblGameSave` → same on Win10 Pro/Home
- §13 Visual Effects: `UserPreferencesMask` value 0x90120380 works identically
