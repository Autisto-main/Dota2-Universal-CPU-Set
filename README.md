# Dota 2 Universal CPU Sets v1.6

Automatic CPU thread optimization for Dota 2 using Windows CPU Sets.

Created by Sam Main (Autisto.).

## Download + My scan example

[Download latest release v1.6](https://github.com/Autisto-main/Dota2-Universal-CPU-Sets/releases/tag/v1.6)

[VirusTotal Security Scan](https://www.virustotal.com/gui/file/00e99d6465458fa159c0115740c376aa63047dfcf95237533e987ffb74da4ef2)

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1
- Dota 2 installed through Steam

## What It Does

- Automatically detects Dota 2 when it starts.
- Waits 20 seconds before detecting CPU efficiency classes.
- Detects available Windows CPU Sets and faster CPU cores.
- Includes parked CPU cores because parking is temporary.
- Excludes CPU Sets marked as exclusively allocated.
- Measures CPU usage per Dota 2 thread over 12 seconds.
- Selects the busiest thread when it meets the configured thresholds.
- Assigns that thread to the fastest available CPU efficiency class.
- Leaves existing thread-level CPU Set assignments unchanged.
- Automatically operates through Windows Task Scheduler.
- Records actions and errors in a log file.

The script changes scheduling preferences for one Dota 2 thread. It does not change process-wide CPU affinity.

## CPU Compatibility

Intel processors with P-cores and E-cores are the primary target.

The script automatically detects the available CPU topology rather than assuming a fixed number of cores.

AMD processors and Intel processors with only one reported CPU efficiency class can run the script, but no CPU Set optimization will be applied.

## Installation

1. Download the ZIP from the latest GitHub release.
2. Extract the ZIP into a folder.
3. Open Windows PowerShell 5.1 in that folder.
4. Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\DotaCpuSets.ps1 -Mode Install
```

5. Start Dota 2 normally through Steam.

After installation, Windows Task Scheduler starts the optimization automatically. You do not need to run PowerShell manually every time you play.

## Check Status

```powershell
.\DotaCpuSets.ps1 -Mode Status
```

## Temporarily Disable

```powershell
.\DotaCpuSets.ps1 -Mode Disable
```

## Enable Again

```powershell
.\DotaCpuSets.ps1 -Mode Enable
```

## Uninstall

```powershell
.\DotaCpuSets.ps1 -Mode Uninstall
```

Restart Dota 2 after disabling or uninstalling to ensure a clean comparison.

## Logging

The script stores its log at:

```text
%LOCALAPPDATA%\DotaUniversalCpuSets\DotaCpuSets.log
```

The log records CPU detection, thread selection, changes and errors.

## Important Information

- CPU Sets are scheduling preferences, not strict CPU affinity.
- The busiest thread is not guaranteed to be Dota 2's main or render thread.
- The script does not require core parking to be disabled.
- It does not modify Dota 2 files, BIOS settings or GPU settings.
- It does not download additional software or require a network connection.
- Avoid running multiple CPU scheduling tools that modify the same Dota 2 threads.
- Performance results depend on CPU architecture, Windows scheduling and game workload.
- The universal version has not yet been validated across different hardware configurations.

## Security

The full PowerShell source code is publicly available in this repository.

You can inspect `DotaCpuSets.ps1` before running it.

The VirusTotal report linked above corresponds to the v1.6 release ZIP. Antivirus scan results do not guarantee that software is completely safe.

## License

GNU General Public License v3.0.

Copyright (C) 2026 Sam Main (Autisto.).

See the LICENSE file for the full terms.
