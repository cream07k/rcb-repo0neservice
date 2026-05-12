---
section: 12-game-dvr
applies_to: [Win10, Win11]
order: 120
risk: none
ac_safe: true
---

# Game DVR off + Game Mode on

## Game DVR off

Path: `HKCU:\System\GameConfigStore`

| Name | Type | Value |
|------|------|-------|
| GameDVR_Enabled | DWord | 0 |
| GameDVR_FSEBehaviorMode | DWord | 2 |
| GameDVR_HonorUserFSEBehaviorMode | DWord | 1 |
| GameDVR_DXGIHonorFSEWindowsCompatible | DWord | 1 |
| GameDVR_EFSEFeatureFlags | DWord | 0 |

Path: `HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR`

| Name | Type | Value |
|------|------|-------|
| AppCaptureEnabled | DWord | 0 |
| HistoricalCaptureEnabled | DWord | 0 |
| AudioEncodingBitrate | DWord | 0 |
| VideoEncodingBitrate | DWord | 0 |

Path: `HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR`

| Name | Type | Value |
|------|------|-------|
| AllowGameDVR | DWord | 0 |

## Xbox Game Bar off

Path: `HKCU:\Software\Microsoft\GameBar`

| Name | Type | Value |
|------|------|-------|
| ShowStartupPanel | DWord | 0 |
| GamePanelStartupTipIndex | DWord | 3 |
| UseNexusForGameBarEnabled | DWord | 0 |
| ExitOnDBClick | DWord | 0 |

## Game Mode on

Path: `HKCU:\Software\Microsoft\GameBar`

| Name | Type | Value |
|------|------|-------|
| AllowAutoGameMode | DWord | 1 |
| AutoGameModeEnabled | DWord | 1 |
