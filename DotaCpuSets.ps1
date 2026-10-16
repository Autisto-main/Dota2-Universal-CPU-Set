# Dota 2 Universal CPU Sets
# Copyright (C) 2026 Sam Main (Autisto.)
# SPDX-License-Identifier: GPL-3.0-only
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3.
# This program is distributed WITHOUT ANY WARRANTY; see LICENSE.
# Modifications distributed by others must retain copyright notices
# and clearly mark changes as required by the GPL.
#
# Dota 2 CPU Sets helper - v1.6
# Supports Windows 10/11 PowerShell 5.1, homogeneous CPUs left unchanged.
# Modes: Install, Start, Status, Disable, Enable, Uninstall
param(
    [ValidateSet('Install','Start','Status','Disable','Enable','Uninstall')]
    [string]$Mode = 'Status',
    [ValidateRange(5,120)][int]$StartupDelaySeconds = 20
)

$ErrorActionPreference = 'Stop'
$taskName = 'Dota2 Universal CPU Sets'
$homeDir = Join-Path $env:LOCALAPPDATA 'DotaUniversalCpuSets'
$installedScript = Join-Path $homeDir 'DotaCpuSets.ps1'
$logPath = Join-Path $homeDir 'DotaCpuSets.log'
$statePath = Join-Path $homeDir 'active.json'

function Log([string]$msg) {
    if (-not (Test-Path $homeDir)) { New-Item -ItemType Directory -Force -Path $homeDir | Out-Null }
    $line = "$(Get-Date -Format s) $msg"
    Add-Content -Path $logPath -Value $line -Encoding UTF8
    Write-Host $line
}

function TaskExists {
    return [bool](Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)
}

function Get-DotaProcess {
    return Get-Process -Name 'dota2' -ErrorAction SilentlyContinue | Select-Object -First 1
}

# The native API changes CPU Sets of ONE thread, NOT process affinity, priority or power limits.
$nativeCode = @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
public static class DotaCpuNative {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool GetSystemCpuSetInformation(IntPtr information, int bufferLength, out int returnedLength, IntPtr process, uint flags);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr OpenThread(uint access, bool inherit, uint threadId);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool SetThreadSelectedCpuSets(IntPtr thread, [In] uint[] cpuSetIds, uint cpuSetIdCount);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool GetThreadSelectedCpuSets(IntPtr thread, [Out] uint[] ids, uint capacity, out uint required);
    public static uint[] Read(uint threadId) {
        IntPtr handle = OpenThread(0x0800, false, threadId); // THREAD_QUERY_LIMITED_INFORMATION
        if (handle == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error(), "OpenThread read failed");
        try {
            uint required;
            // Read with a generous buffer to avoid ERROR_INSUFFICIENT_BUFFER.
            uint[] result = new uint[4096];
            if (!GetThreadSelectedCpuSets(handle, result, (uint)result.Length, out required))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "GetThreadSelectedCpuSets failed");
            if (required > result.Length) throw new Exception("Too many existing thread CPU Sets");
            Array.Resize(ref result, (int)required);
            return result;
        } finally { CloseHandle(handle); }
    }
    public static Dictionary<byte, List<uint>> GetCpuClasses() {
        int length;
        GetSystemCpuSetInformation(IntPtr.Zero, 0, out length, IntPtr.Zero, 0);
        if (length <= 0 || length > 1048576) throw new Win32Exception(Marshal.GetLastWin32Error(), "CPU Sets unavailable");
        IntPtr buffer = Marshal.AllocHGlobal(length);
        try {
            if (!GetSystemCpuSetInformation(buffer, length, out length, IntPtr.Zero, 0))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "GetSystemCpuSetInformation failed");
            var classes = new Dictionary<byte, List<uint>>();
            int pos = 0;
            while (pos + 8 <= length) {
                IntPtr item = IntPtr.Add(buffer, pos);
                int size = Marshal.ReadInt32(item, 0);
                int type = Marshal.ReadInt32(item, 4);
                if (size < 8 || pos + size > length) throw new Exception("Invalid CPU Set record");
                if (type == 0 && size >= 24) {
                    uint id = unchecked((uint)Marshal.ReadInt32(item, 8));
                    byte efficiency = Marshal.ReadByte(item, 18);
                    byte flags = Marshal.ReadByte(item, 19);
                    // Core parking is temporary. Include parked CPU Sets so that
                    // fast cores parked at idle remain eligible during gameplay.
                    // Continue to skip CPU Sets reserved for exclusive allocation.
                    bool allocated = (flags & 2) != 0;
                    if (!allocated) {
                        if (!classes.ContainsKey(efficiency)) classes[efficiency] = new List<uint>();
                        classes[efficiency].Add(id);
                    }
                }
                pos += size;
            }
            return classes;
        } finally { Marshal.FreeHGlobal(buffer); }
    }
    public static void Assign(uint threadId, uint[] ids) {
        // THREAD_SET_INFORMATION | THREAD_SET_LIMITED_INFORMATION
        IntPtr handle = OpenThread(0x0420, false, threadId);
        if (handle == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error(), "OpenThread failed");
        try {
            uint count = ids == null ? 0u : (uint)ids.Length;
            if (!SetThreadSelectedCpuSets(handle, ids, count))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "SetThreadSelectedCpuSets failed");
        } finally { CloseHandle(handle); }
    }
}
'@

function InitNative {
    if (-not ('DotaCpuNative' -as [type])) { Add-Type -TypeDefinition $nativeCode -Language CSharp }
}

function RestoreActive {
    if (-not (Test-Path $statePath)) { return }
    try {
        $state = Get-Content -Raw -Path $statePath | ConvertFrom-Json
        $p = Get-Process -Id ([int]$state.Pid) -ErrorAction SilentlyContinue
        if ($p -and ([long]$p.StartTime.ToFileTimeUtc()) -eq [long]$state.StartTimeUtc) {
            InitNative
            $original = [uint32[]]@($state.OriginalIds)
            [DotaCpuNative]::Assign([uint32]$state.ThreadId, $original)
            Log "Restored original CPU Sets for PID $($state.Pid), thread $($state.ThreadId)."
        }
    } catch { Log "Restore not completed: $($_.Exception.Message). Restart Dota to clear the setting." }
    finally { Remove-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue }
}

switch ($Mode) {
    'Install' {
        New-Item -ItemType Directory -Force -Path $homeDir | Out-Null
        $source = $MyInvocation.MyCommand.Path
        if ([IO.Path]::GetFullPath($source) -ne [IO.Path]::GetFullPath($installedScript)) { Copy-Item -LiteralPath $source -Destination $installedScript -Force }
        $exe = (Get-Command powershell.exe).Source
        $action = New-ScheduledTaskAction -Execute $exe -Argument ('-NoProfile -NonInteractive -WindowStyle Hidden -File "{0}" -Mode Start -StartupDelaySeconds {1}' -f $installedScript, $StartupDelaySeconds)
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User ([Security.Principal.WindowsIdentity]::GetCurrent().Name)
        $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Seconds 0) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description 'Apply CPU Sets to one Dota 2 thread, only on mixed-efficiency CPUs.' -Force | Out-Null
        Start-ScheduledTask -TaskName $taskName
        Log 'Installed and enabled. Starts at user logon.'
        break
    }
    'Status' {
        if (TaskExists) {
            Get-ScheduledTask -TaskName $taskName | Select-Object TaskName,State,@{Name='Enabled';Expression={$_.Settings.Enabled}} | Format-Table -AutoSize
        } else { Write-Host 'Not installed.' }
        if (Test-Path $statePath) { Write-Host "Active state file: $statePath" }
        Write-Host "Log: $logPath"
        break
    }
    'Disable' {
        if (TaskExists) {
            Disable-ScheduledTask -TaskName $taskName | Out-Null
            Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        }
        RestoreActive
        Log 'Disabled. No automatic changes until enabled.'
        break
    }
    'Enable' {
        if (-not (TaskExists)) { throw 'Not installed. Use -Mode Install first.' }
        Enable-ScheduledTask -TaskName $taskName | Out-Null
        Start-ScheduledTask -TaskName $taskName
        Log 'Enabled.'
        break
    }
    'Uninstall' {
        if (TaskExists) {
            Disable-ScheduledTask -TaskName $taskName | Out-Null
            Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        }
        RestoreActive
        Log 'Uninstalled. Logs are retained; folder may be deleted manually.'
        break
    }
    'Start' {
        InitNative
        Log 'Watching for Dota. CPU efficiency classes will be detected after the game starts.'
        $appliedPid = 0
        # Recover a setting from an interrupted previous run, before sampling again.
        if (Test-Path $statePath) { RestoreActive }
        while ($true) {
            try {
                $p = Get-DotaProcess
                if (-not $p) {
                    if ($appliedPid -ne 0) { RestoreActive; $appliedPid = 0; Log 'Dota exited.' }
                    Start-Sleep -Seconds 3
                    continue
                }
                if ($appliedPid -eq $p.Id) {
                    $still = @($p.Threads | Where-Object { $_.Id -eq $threadId }).Count -gt 0
                    if ($still) { Start-Sleep -Seconds 3; continue }
                    RestoreActive
                    $appliedPid = 0
                    Log 'Selected thread exited. Resampling.'
                    continue
                }
                if ($appliedPid -ne 0) { RestoreActive; $appliedPid = 0 }
                # Delay after first observation; check process identity to avoid PID reuse.
                $stamp = [long]$p.StartTime.ToFileTimeUtc()
                Start-Sleep -Seconds $StartupDelaySeconds
                $fresh = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
                if (-not $fresh -or [long]$fresh.StartTime.ToFileTimeUtc() -ne $stamp) { continue }
                # Detect CPU classes only after Dota has been running for the startup delay.
                # Do not exclude cores just because they were parked at the time of detection.
                $classes = [DotaCpuNative]::GetCpuClasses()
                if ($classes.Count -lt 2) {
                    Log 'Only one eligible efficiency class detected after Dota start. No changes made; retrying in 30 seconds.'
                    Start-Sleep -Seconds 30
                    continue
                }
                $best = [byte](($classes.Keys | Measure-Object -Maximum).Maximum)
                $ids = [uint32[]]@($classes[$best])
                if ($ids.Count -eq 0) {
                    Log 'No eligible CPU Sets detected. Retrying in 30 seconds.'
                    Start-Sleep -Seconds 30
                    continue
                }
                Log "Dota running; efficiency classes: $($classes.Count); selected class: $best; CPU Sets: $($ids.Count)."
                # Sample per-thread CPU TIME deltas, not thread creation order.
                # Do not force an assignment when the measurement is too ambiguous.
                Log 'Sampling active Dota threads for 12 seconds. Play a live match during measurement.'
                $samples = @{}
                for ($round = 0; $round -lt 12; $round++) {
                    $before = @{}
                    $probe = Get-Process -Id $fresh.Id -ErrorAction Stop
                    foreach ($t in $probe.Threads) {
                        try { $before[[int]$t.Id] = [long]$t.TotalProcessorTime.Ticks } catch { }
                    }
                    Start-Sleep -Seconds 1
                    $probe = Get-Process -Id $fresh.Id -ErrorAction Stop
                    if ([long]$probe.StartTime.ToFileTimeUtc() -ne $stamp) { throw 'Dota process restarted while measuring.' }
                    foreach ($t in $probe.Threads) {
                        $tid = [int]$t.Id
                        if (-not $before.ContainsKey($tid)) { continue }
                        try {
                            $delta = [long]$t.TotalProcessorTime.Ticks - $before[$tid]
                            if ($delta -lt 0) { continue }
                            if (-not $samples.ContainsKey($tid)) { $samples[$tid] = [pscustomobject]@{Total = [long]0; Rounds = 0} }
                            $samples[$tid].Total += $delta
                            $samples[$tid].Rounds++
                        } catch { }
                    }
                }
                $ranking = @($samples.GetEnumerator() | Where-Object { $_.Value.Rounds -ge 8 } |
                    Sort-Object @{Expression={$_.Value.Total};Descending=$true})
                if ($ranking.Count -lt 2) {
                    Log 'Not enough reliable thread samples; no adjustment. Retrying after 30 seconds.'
                    Start-Sleep -Seconds 30
                    continue
                }
                $top = $ranking[0]
                $second = $ranking[1]
                $cpuSeconds = [double]$top.Value.Total / [timespan]::TicksPerSecond
                $ratio = if ($second.Value.Total -gt 0) { [double]$top.Value.Total / $second.Value.Total } else { 999.0 }
                Log ('Candidate TID {0}: CPU {1:N2}s / 12s, second: {2:N2}s, ratio: {3:N2}' -f $top.Key, $cpuSeconds, ([double]$second.Value.Total / [timespan]::TicksPerSecond), $ratio)
                if ($cpuSeconds -lt 2.4 -or $ratio -lt 1.25) {
                    Log 'No dominant busy thread identified. No change made; retrying in 30 seconds.'
                    Start-Sleep -Seconds 30
                    continue
                }
                $threadId = [uint32]$top.Key
                $live = Get-Process -Id $fresh.Id -ErrorAction Stop
                if ([long]$live.StartTime.ToFileTimeUtc() -ne $stamp -or -not @($live.Threads | Where-Object { $_.Id -eq $threadId }).Count) { continue }
                $originalIds = [uint32[]]@([DotaCpuNative]::Read($threadId))
                if ($originalIds.Count -gt 0) {
                    Log "Candidate TID $threadId already has an explicit CPU Sets assignment. Skipping to avoid overwriting it."
                    Start-Sleep -Seconds 30
                    continue
                }
                # Save original empty assignment before applying, so an interrupted run can recover.
                @{Pid=$fresh.Id;ThreadId=$threadId;StartTimeUtc=$stamp;OriginalIds=@()} | ConvertTo-Json | Set-Content -Path $statePath -Encoding UTF8
                [DotaCpuNative]::Assign($threadId, $ids)
                $appliedPid = $fresh.Id
                Log "Applied to PID $appliedPid, candidate TID $threadId. Dominant CPU use is not proof this is the game thread."
            } catch {
                Log "Watch error: $($_.Exception.Message)"
                Start-Sleep -Seconds 5
            }
        }
    }
}
