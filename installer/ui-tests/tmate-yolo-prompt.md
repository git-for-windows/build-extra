# Prompt for Copilot CI debugging session (--yolo mode)

## Context

You are running on a GitHub Actions Windows runner where AutoHotkey-based
UI tests for the Git for Windows installer just failed. Git for Windows
is already installed at `C:\Program Files\Git`. AutoHotkey v2 is already
in PATH. The `~/.minttyrc` is already configured with the required
`KeyFunctions` and `SaveFilename` settings.

The runner may be either `windows-latest` (x86_64) or `windows-11-arm`
(aarch64). Check `runner.os`/`$env:PROCESSOR_ARCHITECTURE` if it matters.
On ARM64 there is no native AutoHotkey build; `AutoHotkey64.exe` (x64)
runs under Windows 11 ARM64's x64 emulation layer. This generally works
but DllCall/keyboard-hook behavior may differ subtly. See the "ARM64
considerations" section below.

Your working directory is the root of the `build-extra` checkout. ALL
files you create (scripts, screenshots, logs, results) MUST be written
somewhere inside this directory tree. Do NOT write files outside it;
they will be lost when the runner is reaped. The entire working
directory will be uploaded as a build artifact.

Your final findings MUST be written to
`installer/ui-tests/copilot-diagnosis.md`. Be specific: which file and
line is the root cause, what evidence points to it, what concrete change
fixes it. Do NOT propose changes that you have not verified work.

## Operating principles (READ FIRST, mandatory)

### Verify, do not guess

Every factual claim you make, whether in the diagnosis, in chat, or in
the proposed fix, must be backed by concrete evidence: a log line you
just read, a source line you just opened, the output of a diagnostic
script you just ran. "It looks like X" is not a diagnosis; "I ran Y
at step Z, output was W" is. If you cannot verify a claim, abandon it.
Never hallucinate.

### Predict before you test

Before running any diagnostic or applying any fix, state in chat what
you expect to observe and why. If the result diverges from the
prediction, your mental model is wrong: investigate the divergence.
Do NOT patch the next visible symptom. Do NOT call unexpected
behaviour "normal", "an edge case", or "a test artifact" until you
can explain its exact mechanism.

### Apply and verify end-to-end before reporting

A "candidate fix" is a fix only after the full
`installer/ui-tests/git-bash-checklist.ahk` script (Step 5 below) has
run to completion with exit code 0 AND the log shows the completion
lines for all three phases (Git Bash, Git CMD, Git GUI). A diagnostic
snippet that exercises only the suspect code path proves only that
snippet works; it does NOT prove the full test passes. Do NOT write
`copilot-diagnosis.md` until this end-to-end gate has been passed.

### Iterate until proven

The first plausible hypothesis is rarely the root cause. Your session
budget is approximately 90 minutes; use all of it if needed. A failed
end-to-end verification is information, not defeat: refine the
hypothesis, refine the fix, re-apply, re-run. Stopping at "diagnosis
without verified fix" is equivalent to no fix at all from the
perspective of the workflow that triggered this session.

### Geometry-may-change pattern

A window having appeared does NOT mean it has reached its final state.
Data may still be loading, child controls may still be positioning, the
title bar may not be set yet. Treat "window appeared" as the START of a
polling loop: sample the geometric property you care about (size,
child-control rect, title text) until it stabilises across several
consecutive samples OR a timeout fires. If the timeout fires before
the property settles, the test FAILS with a clear log line naming the
property and its last value. If a click lands in the wrong place, the
cause is almost always missing settle-time on the target geometry,
not the click code itself.

### AutoHotkey invocation (no exceptions)

Every AHK invocation (script, helper, one-off diagnostic) MUST include
all three of:

1. `/ErrorStdOut` flag.
2. `/force` flag.
3. `2>&1` plus a stdout consumer: `| tee log.txt`, `| cat`,
   `| Out-File <path>`, or `| Out-Default`.

In MSYS2 bash, additionally set `MSYS2_ARG_CONV_EXCL='*'` so the
`/ErrorStdOut` argument is not path-converted. Missing any one of
the three triggers a modal MsgBox (AHK's fallback for
`FileAppend('*')` failures and unhandled parse errors) that BLOCKS
the AHK process until manually dismissed. In CI that means the
helper hangs until job timeout with no output. If a helper you just
launched produced no output, check this BEFORE concluding the script
has a bug.

## Your task

The validate step of the workflow timed out (20 minute hard limit) or
exited non-zero. The Git for Windows installer ran to completion; the
failure is in the AutoHotkey UI tests (`installer/ui-tests/`).

Diagnose the **root cause**. Do not guess. Verify your diagnosis by
running a targeted experiment before declaring it correct.

### Step 1: Read the AHK log

Look at `installer/ui-tests/git-bash-checklist.log`. Find the LAST
`Info` line that was written. The hang or crash happened immediately
AFTER that point in the script. Note the exact timestamp of the last
log line, and the timestamp of the validate-step timeout, so you know
how long the script was stuck.

The AHK script's logging is its `Info()` function (defined in
`ui-test-library.ahk`); calls to `Info ...` append to the log file
with no flush issues. If the log has no entries near the timeout, the
script crashed before initializing logging; check for AHK error
dialogs (see Step 4).

### Step 2: Locate the failure site in source

`grep -n "<last log message>" installer/ui-tests/git-bash-checklist.ahk
installer/ui-tests/ui-test-library.ahk` to find which line emitted
that last log message. Read the source from that line forward,
following the control flow. The hang is somewhere in the code that
runs AFTER the last logged line and BEFORE the next `Info` call (which
never fired).

### Step 3: Hypothesize the cause

Common AHK v2 hang patterns on a headless CI runner:

- **Uncaught exception raises an invisible error dialog.** AHK v2
  shows a modal `ErrorDialog` on unhandled exceptions. On a runner
  with no interactive session, the dialog is invisible but blocks
  the script forever. Suspect any `FileMove`/`FileDelete`/`FileOpen`
  that may target a missing or locked file; any `WinGetXxx` on a
  window that no longer exists; any DllCall with bad arguments.
- **WinClose on a window that prompts to save.** `WinClose` returns
  immediately but the window may show a "Save changes?" modal that
  blocks subsequent cleanup. Use `WinKill` or send `Escape` first.
- **`WinWait`/`WinWaitClose` with no timeout.** Default is no timeout
  and infinite hang. Always pass a timeout.
- **A `loop` or `while` with a condition that never becomes false.**
- **A subprocess started via `Run`/`RunWait` that never exits.**

For each hypothesis, write down the predicted symptom and how you
would confirm it.

### Step 4: Verify the hypothesis

Write a SMALL standalone AHK script at
`installer/ui-tests/diagnose-hang.ahk` that reproduces ONLY the
suspect step(s). It must log every action to
`installer/ui-tests/diagnose-hang.log` AND wrap each operation in
`try`/`catch` so any exception is logged rather than raised.

Run it via:
```
MSYS2_ARG_CONV_EXCL='*' "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" \
  /ErrorStdOut /force installer/ui-tests/diagnose-hang.ahk \
  2>&1 | tee installer/ui-tests/diagnose-hang.stdout.log
```

If the AHK script silently produces no output, the most likely cause
is `MSYS2_ARG_CONV_EXCL` not being set (so `/ErrorStdOut` got
converted to a Unix path).

### Step 5: Apply the fix and verify it end-to-end

Apply your proposed fix DIRECTLY to the test files in the working
tree (`installer/ui-tests/ui-test-library.ahk`,
`installer/ui-tests/git-bash-checklist.ahk`, etc.). The runner
workspace is ephemeral, so editing files here cannot contaminate
anything; you will write the final verified diff to the diagnosis
file after Step 6.

Then re-run the FULL test exactly as the workflow does. From the
build-extra checkout root:

```
MSYS2_ARG_CONV_EXCL='*' "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" \
  /ErrorStdOut /force installer/ui-tests/git-bash-checklist.ahk \
  2>&1 | tee installer/ui-tests/git-bash-checklist-verify.log
```

The fix is verified ONLY if BOTH conditions hold:

1. The AHK process exits with code 0.
2. `git-bash-checklist-verify.log` contains the completion lines for
   ALL THREE phases (Git Bash, Git CMD, Git GUI). Confirm by grepping
   for the per-phase "done" / completion `Info` lines that the script
   emits at the end of each phase.

If EITHER condition fails: refine the hypothesis, refine the fix,
re-apply, re-run. You have ~90 minutes of CI budget; do NOT stop
until either green or every plausible strategy has been exhausted
with its failure log captured. Do NOT report a fix you have not
actually verified end-to-end with the full `git-bash-checklist.ahk`
script - a diagnostic snippet that exercises only the suspect code
path is NOT sufficient evidence of a working fix.

CI cycles are expensive and slow. Make this one count: every
hypothesis must be verified in this session before reporting.

### Step 6: Record the verified fix

Only after Step 5 is green, write to
`installer/ui-tests/copilot-diagnosis.md`:

1. **The exact root cause**: file:line, with the line of code that
   hangs/throws.
2. **The evidence**: the last log line from the original failing run,
   what the source says runs next, what your diagnostic confirmed,
   and the matching success lines from the verification run.
3. **The fix**: a unified diff (`git diff` format) of the changes you
   applied to the test files. Keep it minimal and surgical; do not
   refactor. Do NOT commit; the user will review the diagnosis file
   and commit themselves.
4. **The verification excerpt**: paste the relevant lines from
   `git-bash-checklist-verify.log` inline (start banner, the per-phase
   completion lines, the final exit) so a human reviewer can confirm
   end-to-end success without chasing artifacts.

## Important AHK v2 notes

- AHK v2 syntax (not v1). `MsgBox 'text'` not `MsgBox, text`.
- Invoke AHK with `/ErrorStdOut /force` AND pipe output (e.g.
  `| tee diag.log`). Without a pipe, `FileAppend` to `*` silently
  fails (handle 6 error).
- Use `MSYS2_ARG_CONV_EXCL='*'` when calling AHK from bash to prevent
  MSYS2 from converting `/ErrorStdOut` to a Unix path.
- AHK v2 function-local scope: bare `x := 1` inside a function creates
  a LOCAL `x`. To write a global, declare `global x` at the function
  top. To read a global, simply reference it (read-only access is
  implicit) UNLESS the same function also writes it locally.
- `WinGetTitle`/`WinGetClass`/`WinGetProcessName` throw if the hwnd
  no longer exists. Always wrap in `try`/`catch` when iterating.
- File operations throw on missing source. `FileMove src, dst` raises
  if `src` does not exist. Use `if FileExist(src)` first or wrap in
  try/catch.

## Key source files

- `installer/ui-tests/git-bash-checklist.ahk`: the main test script.
- `installer/ui-tests/ui-test-library.ahk`: shared library
  (`Info`, `ExitWithError`, `CloseMinTTYWindow`, `LaunchViaStartMenu`,
  `CaptureAndDownscaleWindow`, `VerifyGitGuiLayout`,
  `CheckGitGuiStructure`, `FindChooserLinkRow`, etc.).
- `installer/ui-tests/run-checklist.sh`: the bash wrapper that runs
  the AHK script.
- `installer/ui-tests/generate-test-repo.sh`: creates a test repo via
  `git fast-import`.

## ARM64 considerations

When running on `windows-11-arm`, additional failure modes are
possible. Check these BEFORE diving into the AHK script if you see
symptoms that don't match anything in `git-bash-checklist.log`:

- **OOBE / "welcome screen" instead of a desktop.** Fresh Windows 11
  ARM64 runner images have been observed to surface the Out-Of-Box
  Experience setup screen rather than a logged-in desktop (commonly
  stuck on "Choose privacy settings for your device"). The test now
  calls `DismissOOBE()` from `ui-test-library.ahk` at the top of the
  run to walk through OOBE with `{Enter}` and then taskkill the OOBE
  host processes, but it is best-effort: if the page sequence ever
  diverges (Microsoft account sign-in, Wi-Fi setup, etc.) or a new
  build of Windows changes the window class away from
  `Shell_OOBEProxy`, dismissal will fail and the subsequent
  `LaunchViaStartMenu()` will throw "Start Menu did not appear".

  **DO NOT stop and report.** Reboot is not an option (the runner is
  ephemeral; rebooting kills the runner agent). Exhaust every option
  below in order, capturing a screenshot (`CaptureScreen` exists in
  the library; or `installer/ui-tests/screenshot.png` is captured
  automatically on the existing failure path) AND a full window list
  (`Get-Process | Where MainWindowTitle -ne '' | Select Id, ProcessName, MainWindowTitle`
  in pwsh, or `LogAllWindows` if you launch your own AHK helper)
  after EACH attempt. Only declare defeat once every step below has
  been tried and its outcome captured.

  1. Inspect `installer/ui-tests/oobe-before.png`,
     `installer/ui-tests/oobe-after-keyboard.png`, and
     `installer/ui-tests/oobe-after-taskkill.png` (whichever exist)
     to see where `DismissOOBE()` got stuck.
  2. If OOBE is on a Microsoft-account sign-in page, the runner has
     no real account to sign in with. Try `Run "ms-cxh:localonly"`
     from an AHK helper to jump to the local-account branch, or
     `start ms-cxh:localonly` from pwsh.
  3. Identify the actual OOBE process via
     `Get-CimInstance Win32_Process | Where Name -match 'oobe|wwahost|useroobebroker' | Select ProcessId, ParentProcessId, Name, CommandLine`
     and kill its parent process, not just the leaf.
  4. Send keyboard input with finer granularity: a small AHK helper
     that does `Send '{Tab 5}'; Send '{Enter}'` to focus the
     skip/Next button explicitly rather than relying on the default
     button.
  5. If the OOBE has truly stuck, `Stop-Process -Name explorer
     -Force; Start-Sleep 5; Start-Process explorer.exe` and retry.

- **Start Menu does not open (LaunchViaStartMenu fails).** On ARM64
  runners the Start Menu (`{LWin}` / SearchHost.exe) has been
  observed to never respond, even after Explorer was restarted in
  the workflow's setup step. Do NOT simply work around this with a
  shortcut fallback and move on. Investigate the root cause:
  1. Check whether `SearchHost.exe` and `StartMenuExperienceHost.exe`
     are running (`Get-Process SearchHost,StartMenuExperienceHost`).
  2. If they are not running, restart Explorer
     (`Stop-Process -Name explorer -Force; Start-Sleep 10`) and check
     again. Log what happens.
  3. If they ARE running but `{LWin}` does not bring up the Start
     Menu, try `Ctrl+Esc` as an alternative, then try launching
     `explorer.exe shell:::{4234d49b-0245-4df3-b780-3893943456e1}`
     (the Applications folder CLSID). Log each attempt.
  4. Only after root-causing the failure and documenting what does
     and does not work should you consider a shortcut-based fallback
     as a TEMPORARY measure that still lets the rest of the test
     proceed.

- **Tk-based tests are slow (gitk, git gui).** On ARM64, wish.exe
  runs under x64 emulation and a cold start has been measured at
  137 seconds. The test already uses a 180-second WinWait timeout
  (`tkWaitTimeout` in `ui-test-library.ahk`). If the test still
  times out waiting for TkTopLevel:
  1. Measure the ACTUAL time wish.exe takes by launching gitk in a
     standalone diagnostic and polling for the window with
     timestamps. Log the elapsed time.
  2. Test whether a WARM run (second invocation after the first has
     completed) is significantly faster. If it is, the timeout only
     needs to cover the cold start; subsequent invocations will be
     fast. If it is not, every Tk invocation needs the full timeout
     and the validate step timeout must be increased accordingly.
  3. If wish.exe never shows a window even after 5 minutes, check
     whether the process is alive (`Get-Process wish`) and whether
     it is consuming CPU. A zombie wish.exe that is alive but idle
     is a different problem from one that is slowly rendering.

- **Unexplained modal blocking the script (especially a small
  AutoHotkey-style MsgBox).** If a screenshot or window-list scan
  shows a modal you can't account for, identify the spawning process
  BEFORE doing anything else:
  ```
  Get-CimInstance Win32_Process |
    Where-Object { $_.Name -like 'AutoHotkey*' -or $_.CommandLine -like '*AutoHotkey*' } |
    Select-Object ProcessId, ParentProcessId, Name, CommandLine | Format-List
  ```
  Walk the `ParentProcessId` chain up to find the script that
  launched it. The most common cause is an AHK invocation missing
  `/ErrorStdOut` AND a stdout consumer (`| tee` / `| Out-File`); in
  that case AHK falls back to a modal error MsgBox. Document the
  offending invocation site in `copilot-diagnosis.md` before
  dismissing the dialog with `Stop-Process -Id <PID>` and retrying.

- **MSYS2 is not pre-installed.** The workflow installs it via
  `msys2/setup-msys2@v2` before the upterm step. If that step failed,
  `pacman`/`tmux` won't be available and upterm itself may have
  failed, but our validate step would still proceed. Check whether
  the setup-msys2 step succeeded.
- **AHK x64 binary under ARM64 emulation.** No native ARM64 build
  exists for AutoHotkey v2 (verified for v2.0.19 and v2.0.26 on
  2026-05-19; both releases ship only `AutoHotkey32.exe` and
  `AutoHotkey64.exe`). The x64 binary runs under Windows 11 ARM64's
  emulation, which generally works but may exhibit subtle differences
  in keyboard hooks, low-level mouse events, and `DllCall` timing.
  If a test that passes on x86_64 hangs on ARM64 at a specific
  `Send` or `Click`, this is the prime suspect: try replacing
  `SendInput`/`Send` with `SendEvent` (slower but goes through the
  same APIs as user input), or insert short `Sleep`s.
- **Different Git for Windows binary location.** On ARM64, the
  installed Git is the ARM64 build under `C:\Program Files\Git`
  with `clangarm64\` instead of `mingw64\` for the MinGW prefix.
  Anything that hard-codes `mingw64` will be broken on ARM64. Check
  `matrix.architecture.mingw-prefix` is being used consistently.
- **DPI / scaling.** ARM64 runners may have a different default DPI
  than x86_64 runners. If the chooser image matcher fails to find a
  link at the expected pixel coordinates, but a screenshot shows the
  link IS visible, suspect DPI scaling. `VerifyGitGuiLayout` and
  `FindChooserLinkRow` should be scale-tolerant, but verify.

