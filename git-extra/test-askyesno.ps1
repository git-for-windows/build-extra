param(
    [Parameter(Mandatory = $true)]
    [string] $Executable
)

$ErrorActionPreference = 'Stop'
$Executable = (Resolve-Path -LiteralPath $Executable).Path
$mutexName = 'Local\GitAskYesNo.Test.' + [guid]::NewGuid().ToString('N')
$processes = New-Object 'System.Collections.Generic.List[System.Diagnostics.Process]'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class AskYesNoTest {
    private delegate bool EnumProc(IntPtr window, IntPtr parameter);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumProc callback, IntPtr parameter);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] private static extern IntPtr GetDlgItem(IntPtr window, int id);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetClassNameW(IntPtr window, StringBuilder name, int count);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool PostMessageW(IntPtr window, uint message, IntPtr wparam, IntPtr lparam);
    public static IntPtr Find(int pid) {
        IntPtr match = IntPtr.Zero;
        EnumWindows(delegate(IntPtr window, IntPtr parameter) {
            uint owner;
            GetWindowThreadProcessId(window, out owner);
            if (owner != pid) return true;
            var name = new StringBuilder(32);
            GetClassNameW(window, name, name.Capacity);
            if (name.ToString() != "#32770") return true;
            if (!IsWindowVisible(window)) return true;
            if (GetDlgItem(window, 6) == IntPtr.Zero &&
                GetDlgItem(window, 1) == IntPtr.Zero &&
                GetDlgItem(window, 2) == IntPtr.Zero) return true;
            match = window;
            return false;
        }, IntPtr.Zero);
        return match;
    }
    public static void Respond(IntPtr window, int button) {
        if (!PostMessageW(window, 0x111, new IntPtr(button), IntPtr.Zero))
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
    }
    public static void DismissError(IntPtr window) {
        Respond(window, GetDlgItem(window, 1) != IntPtr.Zero ? 1 : 2);
    }
}
'@

function Start-Prompt([string] $Mutex = '', [switch] $MutexFirst) {
    $arguments = @('--title', 'git askyesno regression test')
    if ($Mutex) {
        if ($MutexFirst) { $arguments = @('--mutex', $Mutex) + $arguments }
        else { $arguments += @('--mutex', $Mutex) }
    }
    $arguments += @('Test', 'prompt:', 'choose No.')
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $Executable
    $info.UseShellExecute = $false
    $info.Arguments = ($arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $process = [System.Diagnostics.Process]::Start($info)
    $processes.Add($process)
    return $process
}

function Wait-Prompt([System.Diagnostics.Process] $Process) {
    $deadline = [datetime]::UtcNow.AddSeconds(10)
    do {
        $window = [AskYesNoTest]::Find($Process.Id)
        if ($window -ne [IntPtr]::Zero) { return $window }
        if ($Process.HasExited) { throw "Prompt exited with $($Process.ExitCode)" }
        Start-Sleep -Milliseconds 25
    } while ([datetime]::UtcNow -lt $deadline)
    throw "Prompt PID $($Process.Id) did not show a dialog"
}

function Assert-Exit([System.Diagnostics.Process] $Process, [int] $Code) {
    if (-not $Process.WaitForExit(10000)) { throw "Prompt PID $($Process.Id) did not exit" }
    if ($Process.ExitCode -ne $Code) { throw "Expected exit $Code, got $($Process.ExitCode)" }
}

function Close-Prompt([System.Diagnostics.Process] $Process) {
    [AskYesNoTest]::Respond((Wait-Prompt $Process), 7)
    Assert-Exit $Process 1
}

try {
    $first = Start-Prompt
    $second = Start-Prompt
    $null = Wait-Prompt $first
    $null = Wait-Prompt $second
    Close-Prompt $first
    Close-Prompt $second
    Write-Output 'PASS: legacy callers can show independent dialogs'

    $first = Start-Prompt $mutexName
    $null = Wait-Prompt $first
    $second = Start-Prompt $mutexName -MutexFirst
    Assert-Exit $second 2
    $null = Wait-Prompt $first
    Write-Output 'PASS: a duplicate returns 2 and leaves the original dialog open'

    $other = Start-Prompt ($mutexName + '.Other')
    $null = Wait-Prompt $other
    Close-Prompt $other
    Close-Prompt $first
    Write-Output 'PASS: different mutex names do not suppress each other'

    $later = Start-Prompt $mutexName
    $null = Wait-Prompt $later
    Close-Prompt $later
    Write-Output 'PASS: the mutex disappears after the original prompt closes'

    $crashed = Start-Prompt $mutexName
    $null = Wait-Prompt $crashed
    Stop-Process -Id $crashed.Id
    if (-not $crashed.WaitForExit(10000)) { throw 'Terminated prompt did not exit' }
    $later = Start-Prompt $mutexName
    $null = Wait-Prompt $later
    Close-Prompt $later
    Write-Output 'PASS: process termination does not leave a stale mutex'

    $invalid = Start-Prompt ($mutexName + '\invalid')
    [AskYesNoTest]::DismissError((Wait-Prompt $invalid))
    Assert-Exit $invalid 3
    Write-Output 'PASS: a mutex error returns 3 instead of a user decline'
} finally {
    foreach ($process in $processes) {
        if (-not $process.HasExited) { Stop-Process -Id $process.Id }
        $process.Dispose()
    }
}
