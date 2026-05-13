---
section: 18-process-pinning
applies_to: [Win10, Win11]
order: 180
risk: low
ac_safe: true
opt_in: false
---

# Per-process scheduling, affinity, timer resolution

Pins FiveM and its sub-processes to High priority + High I/O on every launch, excludes core 0 (kernel IRQ core) from affinity on 4+ core systems, and requests sub-millisecond timer resolution while FiveM is running.

## Image File Execution Options — auto-High on launch

For each known FiveM image name, set `PerfOptions`:

| Name | Type | Value | Meaning |
|------|------|-------|---------|
| CpuPriorityClass | DWord | 3 | High |
| IoPriority | DWord | 3 | High |
| PagePriority | DWord | 5 | Normal+1 |

Apply at the following paths:

- `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\FiveM.exe\PerfOptions`
- `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\FiveM_GTAProcess.exe\PerfOptions`
- `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\FiveM_b2944_GTAProcess.exe\PerfOptions`
- `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\FiveM_b2189_GTAProcess.exe\PerfOptions`
- `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\FiveM_b3095_GTAProcess.exe\PerfOptions`
- `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\CitizenFX_SubProcess_game.exe\PerfOptions`

## Affinity — exclude core 0 on ≥4-core systems

Core 0 services kernel IRQs (xHCI, NIC, timer). Letting the game thread land there causes input jitter when an IRQ fires. The FiveM helper script bumps process affinity to mask off core 0:

```powershell
if ($cores -ge 4) {
    $mask = [int]([Math]::Pow(2, $cores) - 1) -band -bnot 1   # all cores EXCEPT core 0
    $p.ProcessorAffinity = [IntPtr]$mask
}
```

For ≤3 cores, leave affinity alone (no headroom to give up a core).

## Timer resolution — 0.5ms while FiveM runs

Default Windows timer = 1ms (10000 × 100ns units). Drop to 0.5ms = 5000 units so `Sleep(1)` and frame pacing become twice as granular.

Use `NtSetTimerResolution`:

```csharp
[DllImport("ntdll.dll")] static extern int NtSetTimerResolution(int desiredResolution, bool setResolution, out int currentResolution);
```

Called from the FiveM priority helper:

```powershell
$src = '[DllImport("ntdll.dll", EntryPoint="NtSetTimerResolution")] public static extern int Set(int desired, bool set, out int current);'
$ntdll = Add-Type -MemberDefinition $src -Name 'NtRes' -Namespace 'W' -PassThru
$cur = 0
[void]$ntdll::Set(5000, $true, [ref]$cur)
```

The resolution stays active for the lifetime of the process that called it. Run the helper *after* FiveM is launched and keep its window open.

## Notes

- IFEO entries are global — affect any FiveM build, but only run when that exact image name launches.
- `CpuPriorityClass = 4` (RealTime) is **forbidden** — starves audio + kernel threads.
- Timer res below 0.5ms (e.g., 5000 → 1000) wastes CPU and causes battery + audio crackle.
