# Prompt for Copilot CI debugging session (--yolo mode)

## Context

You are running on a GitHub Actions `windows-latest` runner where
AutoHotkey-based UI tests for the Git for Windows installer just failed.
Git for Windows is already installed at `C:\Program Files\Git`.
AutoHotkey v2 is already in PATH. The `~/.minttyrc` is already
configured with the required `KeyFunctions` and `SaveFilename` settings.

Your working directory is the root of the `build-extra` checkout. ALL
files you create (scripts, screenshots, logs, results) MUST be written
somewhere inside this directory tree. Do NOT write files outside it;
they will be lost when the runner is reaped. The entire working
directory will be uploaded as a build artifact.

Your final findings MUST be written to
`installer/ui-tests/copilot-diagnosis.md`.

## What fails

The **Git GUI standalone** phase of
`installer/ui-tests/git-bash-checklist.ahk` fails. The test does:

1. Writes a temp `~/.gitconfig` with a single `gui.recentrepo` entry
   pointing to a test repo.
2. Launches "Git GUI" via the Start Menu. The Git GUI chooser window
   (class `TkTopLevel`, title `Git Gui`) appears.
3. Moves the chooser to position 100,100 size 500x400.
4. Captures a full-resolution screenshot and scans for a blue link row
   using `FindChooserLinkRow()` (in `installer/ui-tests/ui-test-library.ahk`).
5. Clicks at the detected y position (center x) using AHK's `Click`
   with `CoordMode 'Mouse', 'Window'`.

**THE BUG:** The link is detected at the correct y position (y=200 on
CI, y=207 locally), but clicking it does not open the repository.
Both mouse click and keyboard Tab+Enter fallback fail. The test then
hangs waiting for a new TkTopLevel window. It works perfectly locally.

## Your task

Diagnose WHY the click does not work on this runner. Do NOT modify
the existing test scripts (`git-bash-checklist.ahk`,
`ui-test-library.ahk`). Instead, write a standalone diagnostic AHK
script (`installer/ui-tests/diagnose-click.ahk`) that:

1. Creates a test repo using `installer/ui-tests/generate-test-repo.sh
   --create-test-repo=<dir>` (use a temp directory).
2. Backs up `~/.gitconfig`, writes a temp one with `gui.recentrepo`
   pointing to the test repo. Restores it via an `OnExit` handler.
3. Launches `git-gui.exe` directly (no Start Menu needed; just `Run`
   the exe).
4. Waits for the chooser window (`ahk_class TkTopLevel` with title
   containing `Git Gui`).
5. Moves it to 100,100 size 500x400, waits for it to settle.
6. Captures a full-size screenshot (using the library functions or
   your own BitBlt code) to `installer/ui-tests/diag-chooser.png`.
7. Finds the blue link row (copy `FindChooserLinkRow` from the library
   or `#Include` the library).
8. Logs extensively to `installer/ui-tests/diagnose-click.log`:
   window rect, client rect, title bar height, DPI scaling,
   `CoordMode` settings, detected link y, active window info before
   and after each click attempt.
9. Tries multiple click strategies, checking after each for a new
   `TkTopLevel` window whose title contains the test repo name:
   a. `MouseMove` to target coordinates, `Sleep 500`, then `Click`
   b. `ControlClick` with window-relative coordinates
   c. `PostMessage` with `WM_LBUTTONDOWN` + `WM_LBUTTONUP`
   d. `SendMessage` with `WM_LBUTTONDOWN` + `WM_LBUTTONUP`
   e. Direct invocation: run `git gui` with the repo path as argument
      (bypassing the chooser entirely)
10. Captures a screenshot after each attempt to
    `installer/ui-tests/diag-attempt-N.png`.
11. Logs which strategy (if any) worked.

Run the diagnostic script, then write `installer/ui-tests/copilot-diagnosis.md`
with your findings: which strategies worked, all logged measurements,
your diagnosis of the root cause, and a concrete suggested fix for
`installer/ui-tests/git-bash-checklist.ahk`.

## Important AHK notes

- AHK v2 syntax (not v1).
- Invoke AHK with `/ErrorStdOut /force` AND pipe output (e.g.
  `| tee installer/ui-tests/diag-output.log`). Without a pipe,
  `FileAppend` to stdout silently fails.
- Use `MSYS2_ARG_CONV_EXCL='*'` when calling AHK from bash to prevent
  MSYS2 from converting `/ErrorStdOut` to a Unix path.
- The chooser window class is `TkTopLevel`, title starts with `Git Gui`.
- `CoordMode 'Mouse', 'Window'` makes `Click` relative to the window's
  upper-left corner. Verify whether this includes the title bar
  (non-client area) or only the client area, because the screenshot
  capture via `GetWindowRect` + `BitBlt` includes the title bar.
- Tk text widget links respond to `<Enter>` (mouse-enter) + `<Button-1>`
  events. AHK's `Click` may not send the mouse-enter event that Tk
  needs to activate the link binding. This is a leading hypothesis.

## Key source files

- `installer/ui-tests/git-bash-checklist.ahk` lines 342-417: the failing click logic
- `installer/ui-tests/ui-test-library.ahk` lines 797-837: `FindChooserLinkRow`
- `installer/ui-tests/ui-test-library.ahk` lines 405-458: `CaptureAndDownscaleWindow`
- `installer/ui-tests/generate-test-repo.sh`: creates a test repo via `git fast-import`
