---
section: 13-visual-effects
applies_to: [Win10, Win11, Server]
order: 130
risk: none
ac_safe: true
---

# Visual effects = Best Performance

## Master toggle

Path: `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects`

| Name | Type | Value |
|------|------|-------|
| VisualFXSetting | DWord | 2 |

## Desktop animations off

Path: `HKCU:\Control Panel\Desktop`

| Name | Type | Value |
|------|------|-------|
| UserPreferencesMask | Binary | `90 12 03 80 10 00 00 00` |
| DragFullWindows | String | "0" |
| FontSmoothing | String | "2" |
| MenuShowDelay | String | "0" |

Path: `HKCU:\Control Panel\Desktop\WindowMetrics`

| Name | Type | Value |
|------|------|-------|
| MinAnimate | String | "0" |

## Explorer animations

Path: `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`

| Name | Type | Value |
|------|------|-------|
| ListviewAlphaSelect | DWord | 0 |
| ListviewShadow | DWord | 0 |
| TaskbarAnimations | DWord | 0 |
| TaskbarSmallIcons | DWord | 1 |
| ExtendedUIHoverTime | DWord | 1 |
| ShowInfoTip | DWord | 0 |
| ShowCompColor | DWord | 1 |

## Transparency off

Path: `HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize`

| Name | Type | Value |
|------|------|-------|
| EnableTransparency | DWord | 0 |
