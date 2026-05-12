# rcb-repo0neservice

Windows performance optimization spec — designed to be installed by Claude Code AI.

## How to install

1. Open Claude Code on a Windows machine
2. Paste:
   ```
   ติดตั้ง https://github.com/cream07k/rcb-repo0neservice
   ```
3. Confirm when Claude asks
4. Reboot when finished

Claude reads the spec files in this repo, detects your OS (Win10 / Win11 / custom build), adapts where needed, applies every value with backup + verify + restore support.

## What it does

Applies aggressive performance tuning across:
- TCP/IP stack and per-interface tuning
- NIC advanced properties (all offloading off)
- QoS bandwidth reserve release
- MMCSS multimedia priority (Games / Audio / Pro Audio profiles)
- CPU priority + scheduling
- Power plan (Ultimate Performance) + processor states
- GPU Hardware Scheduling + MSI mode
- Memory manager paging behavior
- NTFS filesystem behavior
- Mouse + keyboard input chain
- Display + audio chain
- Game DVR / Game Mode
- Visual effects = Performance
- Telemetry / Cortana / Privacy
- Services bloat removal (60+ services)
- FiveM client + server config

Total: ~327 individual changes.

## Compatibility

- Windows 10 build 19045+
- Windows 11 build 22000+
- Windows 11 Pro for Workstations (Ultimate Performance plan)
- Windows Server 2019/2022
- Custom builds: AtlasOS, Tiny11, Ghost Spectre, ReviOS (delta-aware)

## Reversibility

Claude writes `C:\WinPerf-Backup\backup-<timestamp>.json` before applying. Paste this same URL again and say "restore" — Claude replays the backup in reverse order.

## Anti-cheat compatibility (standard profile)

| AC | Standard sections (§01-§16) |
|----|-----------------------------|
| Vanguard | SAFE |
| FACEIT | SAFE |
| EAC | SAFE |
| BattlEye | SAFE |
| Ricochet | SAFE |
| VAC | SAFE |
| CitizenFX (FiveM) | SAFE |

Section §17 (advanced kernel) is opt-in and gated on user explicit confirmation.

## Repo structure

```
rcb-repo0neservice/
├── README.md
├── spec/                                  # Tweak specs (read in order)
│   ├── 00-preflight.md
│   ├── 01-network-tcp.md
│   ├── 02-network-nic.md
│   ├── 03-qos.md
│   ├── 04-mmcss.md
│   ├── 05-cpu.md
│   ├── 06-power.md
│   ├── 07-gpu.md
│   ├── 08-memory.md
│   ├── 09-ntfs.md
│   ├── 10-input.md
│   ├── 11-display.md
│   ├── 12-game-dvr.md
│   ├── 13-visual-effects.md
│   ├── 14-telemetry.md
│   ├── 15-services.md
│   ├── 16-fivem.md
│   ├── 17-advanced-kernel.md              # Opt-in
│   └── 20-verification.md
└── compatibility/                         # Per-OS overrides
    ├── win10.md
    ├── win11.md
    └── custom-os.md                       # AtlasOS / Tiny11 / Ghost Spectre
```

## Updating the spec

Edit the `.md` files in `spec/` and `compatibility/`. Push. On any machine that previously installed, paste the URL again and say "update" — Claude diffs current state vs new spec and applies the delta.
