---
section: 10-input
applies_to: [Win10, Win11, Server]
order: 100
risk: none
ac_safe: true
---

# Mouse + keyboard + accessibility input chain

## Mouse — full linear mode

Path: `HKCU:\Control Panel\Mouse`

| Name | Type | Value |
|------|------|-------|
| MouseSpeed | String | "0" |
| MouseThreshold1 | String | "0" |
| MouseThreshold2 | String | "0" |
| MouseSensitivity | String | "10" |
| DoubleClickSpeed | String | "200" |
| DoubleClickHeight | String | "4" |
| DoubleClickWidth | String | "4" |
| MouseHoverHeight | String | "4" |
| MouseHoverWidth | String | "4" |
| MouseHoverTime | String | "1" |
| ActiveWindowTracking | DWord | 0 |

## Keyboard — max response

Path: `HKCU:\Control Panel\Keyboard`

| Name | Type | Value |
|------|------|-------|
| KeyboardDelay | String | "0" |
| KeyboardSpeed | String | "31" |
| InitialKeyboardIndicators | String | "2" |

## Accessibility — disable Sticky/Filter/Toggle Keys

Path: `HKCU:\Control Panel\Accessibility\StickyKeys`

| Name | Type | Value |
|------|------|-------|
| Flags | String | "506" |

Path: `HKCU:\Control Panel\Accessibility\Keyboard Response`

| Name | Type | Value |
|------|------|-------|
| Flags | String | "122" |

Path: `HKCU:\Control Panel\Accessibility\ToggleKeys`

| Name | Type | Value |
|------|------|-------|
| Flags | String | "58" |

## SystemParametersInfo — enhance pointer precision off

```powershell
$sig = '[DllImport("user32.dll")] public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);'
$type = Add-Type -MemberDefinition $sig -Name "MouseParam" -Namespace "Win32" -PassThru
$mouseParams = New-Object int[] 3
$mouseParams[0] = 0; $mouseParams[1] = 0; $mouseParams[2] = 0
$ptr = [System.Runtime.InteropServices.Marshal]::AllocCoTaskMem([System.Runtime.InteropServices.Marshal]::SizeOf([int]0) * 3)
[System.Runtime.InteropServices.Marshal]::Copy($mouseParams, 0, $ptr, 3)
$type::SystemParametersInfo(0x0004, 0, $ptr, 0x03)
[System.Runtime.InteropServices.Marshal]::FreeCoTaskMem($ptr)
```

## Desktop timeouts — foreground responsiveness

Path: `HKCU:\Control Panel\Desktop`

| Name | Type | Value | Default |
|------|------|-------|---------|
| MenuShowDelay | String | "0" | 400 |
| AutoEndTasks | String | "1" | 0 |
| HungAppTimeout | String | "500" | 5000 |
| WaitToKillAppTimeout | String | "1000" | 20000 |
| LowLevelHooksTimeout | String | "100" | 5000 |
| ForegroundLockTimeout | DWord | 0 | 200000 |
| ForegroundFlashCount | DWord | 0 | |
| CaretWidth | DWord | 2 | |

## Service kill timeout

Path: `HKLM:\SYSTEM\CurrentControlSet\Control`

| Name | Type | Value | Default |
|------|------|-------|---------|
| WaitToKillServiceTimeout | String | "2000" | 5000 |

## Driver queue depth — shorten input chain

Lower queue = lower latency between physical click and event delivery. Default 100 → 20.

Path: `HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters`

| Name | Type | Value | Default |
|------|------|-------|---------|
| MouseDataQueueSize | DWord | 20 | 100 |

Path: `HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters`

| Name | Type | Value | Default |
|------|------|-------|---------|
| KeyboardDataQueueSize | DWord | 20 | 100 |

## HID idle off — no wake-up delay after pause

```powershell
Get-PnpDevice -Class HIDClass,Keyboard,Mouse -ErrorAction SilentlyContinue |
    Where-Object Status -EQ 'OK' | ForEach-Object {
        $p = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.InstanceId)\Device Parameters"
        if (Test-Path $p) {
            New-ItemProperty -Path $p -Name 'IdleEnable' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
            New-ItemProperty -Path $p -Name 'EnhancedPowerManagementEnabled' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
```

Prevents mouse/keyboard from entering selective suspend after a few seconds idle — kill that "first click feels laggy" feel.
