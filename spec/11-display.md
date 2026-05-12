---
section: 11-display
applies_to: [Win10, Win11]
order: 110
risk: low
ac_safe: true
---

# Display + per-app fullscreen optimization

## FiveM exe — disable fullscreen optimization + HighDPI

Path: `HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers`

| Name | Type | Value |
|------|------|-------|
| `<user>\AppData\Local\FiveM\FiveM.exe` | String | "~ HIGHDPIAWARE DISABLEDXMAXIMIZEDWINDOWEDMODE" |

## HDR off for gaming (lower input lag)

Path: `HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers`

| Name | Type | Value |
|------|------|-------|
| DWMSeparatedGdiSurface | DWord | 0 |

## Refresh rate — verify max (informational)

Claude should run after applying:
```powershell
Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBasicDisplayParams |
    Select InstanceName, MaxHorizontalImageSize, MaxVerticalImageSize
```

And inform the user: "ตรวจ Display Settings → Advanced display → เลือก refresh rate สูงสุด"
