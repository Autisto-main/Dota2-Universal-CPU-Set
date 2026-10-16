Dota 2 Universal CPU Sets v1.6
================================
Requirements: Windows 10/11, Windows PowerShell 5.1.

WHAT IT DOES
- Detects Windows CPU Sets and available efficiency classes after Dota starts.
- Includes parked CPU Sets in the selection because parking is temporary.
- Excludes CPU Sets flagged as exclusively allocated.
- Makes no changes when only one efficiency class is detected.
- Measures CPU time for each Dota 2 thread over 12 seconds.
- Selects the busiest thread only if it used at least 2.4 seconds of CPU
  time and exceeded the second-busiest thread by at least 25%.
- Leaves any existing thread-level CPU Sets unchanged.
- Writes decisions and errors to:
  %LOCALAPPDATA%\DotaUniversalCpuSets\DotaCpuSets.log

IMPORTANT
The busiest thread is not necessarily Dota 2's main or render thread.
Identifying faster CPU cores does not guarantee an FPS improvement.
CPU Sets are scheduling preferences, not strict CPU affinity.
This script has not been tested with Windows and Dota 2 in a live session.

INSTALL
1. Extract the ZIP into a folder.
2. Open Windows PowerShell 5.1 in that folder.
3. Run:
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\DotaCpuSets.ps1 -Mode Install
4. Launch Dota 2 and play a live match while the script samples threads.
   After Dota is detected, it waits 20 seconds before detecting CPU classes.

Installation creates a Windows Task Scheduler task for your current user.
The task starts at sign-in, watches for Dota 2 and works automatically.
CPU class detection does not run at sign-in; it runs after Dota starts.
You do not need to activate it manually each time you launch the game.

CHECK STATUS
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\DotaCpuSets.ps1 -Mode Status

TEMPORARILY DISABLE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\DotaCpuSets.ps1 -Mode Disable

RE-ENABLE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\DotaCpuSets.ps1 -Mode Enable

UNINSTALL
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\DotaCpuSets.ps1 -Mode Uninstall

After disabling or uninstalling, fully close and restart Dota 2 to make
sure its thread-level CPU Set selection has been cleared.
Logs and copied script files remain in:
%LOCALAPPDATA%\DotaUniversalCpuSets
You can delete that folder after uninstalling.

SAFETY AND COMPATIBILITY
- The script does not request administrator privileges; Windows may deny
  access to some threads or scheduled-task operations.
- Avoid running this alongside other Dota 2 CPU-affinity or CPU-Set tools.
- Installation does not search for or modify other users' tuning tasks.
- No network requests, BIOS changes or GPU settings changes are made.
- Review the PowerShell source before running it.

LICENSE
This project is released under GNU GPL version 3 only (GPL-3.0-only).
Copyright (C) 2026 Sam Main (Autisto.). See LICENCE approved from Sam Main (Autisto.).txt for the complete terms.
You may use, modify, and redistribute the software under GPLv3.
If you distribute modifications, keep applicable copyright notices,
mark your changes, and provide the corresponding source code.
No warranty or performance guarantee is provided.
