# Prompt for tmate debugging session (--yolo mode)

## Context

You are debugging a CI failure in a Git for Windows PR that adds
AutoHotkey-based UI tests for the installer checklist. The tests run on
a GitHub Actions `windows-latest` runner (headless, no real user session).

**Repository:** git-for-windows/build-extra
**Branch:** run-remaining-installer-tests-via-autohotkey
**PR:** https://github.com/git-for-windows/build-extra/pull/696
**Working directory:** D:\git-sdk-64\usr\src\build-extra

## What works

- Git Bash phase passes completely on CI: Start Menu launch, mintty
  opens, prompt shows branch, git log colorful+paged, gitk structural
  verification, git gui structural verification, exit codes checked.
- Git CMD phase is skipped (no Windows Terminal on the runner, expected).
- ALL phases pass locally.

## What fails on CI

The **Git GUI standalone** phase fails. The sequence is:

1. After Git Bash phase completes, we restart Explorer (kill
   Shell_TrayWnd process, wait for Shell_TrayWnd to reappear, then
   sleep 5 seconds). This is at lines 280-302 of
   `installer/ui-tests/git-bash-checklist.ahk`.

2. We launch "Git GUI" via the Start Menu using `LaunchViaStartMenu()`
   (line 331). This sends Win key, waits for SearchHost.exe, types
   "Git GUI", presses Enter.

3. The Git GUI chooser window (TkTopLevel, title "Git Gui") appears.
   We move it to 100,100 size 500x400, capture it at full resolution,
   and scan for a blue link row using `FindChooserLinkRow()`.

4. **THE BUG:** The link is detected at the correct y position (y=200
   on CI, y=207 locally), but clicking it does not open the repository.
   Both mouse click (Click at ww//2, clickY with CoordMode Window) and
   keyboard fallback (15x Tab + Enter) fail. The script then hangs
   waiting for a new TkTopLevel window with the test repo name in its
   title, and eventually the 10-minute timeout kills it.

Latest CI log excerpt (run 26001578002):
```
20:21:52  CI: restarting Explorer...
20:21:52  before-restart: window: cls=Progman exe=explorer.exe title=Program Manager
20:21:57  after-restart: window: cls=Progman exe=explorer.exe title=Program Manager
20:22:14  Git GUI chooser: pixel click failed, trying keyboard
20:31:24  ##[error]The action 'validate' has timed out after 10 minutes.
```

Note: only `Progman` shows in the after-restart window list, meaning
Shell_TrayWnd did NOT reappear. The Explorer restart may have failed
or Explorer came back as desktop-only (no taskbar). Yet the Start Menu
search DID work to launch Git GUI (the chooser appeared). The issue is
purely that clicking the link inside the Tk chooser widget does not work.

## Key files

- `installer/ui-tests/git-bash-checklist.ahk` - main test script
  - Lines 272-457: Git GUI standalone section
  - Lines 280-302: Explorer restart on CI
  - Lines 328-331: LaunchViaStartMenu for Git GUI
  - Lines 342-393: Full-size capture + FindChooserLinkRow + click logic
  - Lines 395-417: Keyboard Tab+Enter fallback

- `installer/ui-tests/ui-test-library.ahk` - library functions
  - Lines 182-270: LaunchViaStartMenu
  - Lines 405-458: CaptureAndDownscaleWindow (BitBlt from screen DC)
  - Lines 797-837: FindChooserLinkRow (scans for blue pixels)

- `.github/workflows/main.yml` - CI workflow
  - Lines 236-249: Explorer restart + minimize-windows step
  - Lines 250-264: validate step (runs run-checklist.sh)
  - Lines 265-285: Screenshot on failure + artifact upload

- `installer/run-checklist.sh` - Lines 106-134: AHK invocation with
  MSYS2_ARG_CONV_EXCL='*' and tee pipe

## Hypotheses to investigate

1. **Tk link binding requires mouse-enter event.** Tk text widget links
   respond to `<Enter>` (mouse enter) + `<Button-1>` events. AHK's
   `Click` may send `WM_LBUTTONDOWN`/`WM_LBUTTONUP` without a prior
   `WM_MOUSEMOVE` into the widget. Try: send `MouseMove` to the target
   coordinates first, sleep briefly, then `Click`.

2. **Window not truly focused despite WinActivate.** On the headless
   runner, `WinActivate` may return before the window is truly in the
   foreground. The click might go to Explorer's desktop instead.
   Try: verify `WinActive('ahk_id ' hwnd)` returns true after
   WinActivate, or use `ControlClick` which delivers directly to the
   HWND.

3. **CoordMode 'Mouse', 'Window' coordinates off by title bar.** The
   capture uses `GetWindowRect` which includes the title bar, but
   `Click` with CoordMode Window uses client area. The y offset is
   the title bar height. Try: use `DllCall('GetClientRect')` or offset
   by the title bar height (typically ~30px on Windows Server 2025).

4. **DPI scaling mismatch.** The runner may have 100% scaling (unlike
   local 125%), but `GetWindowRect` and `Click` should both be in the
   same coordinate space. Verify with `SysGet(SM_CYCAPTION)`.

## What to do in the tmate session

You have direct interactive access to the runner. The goal is to
diagnose WHY the click does not work. Steps:

1. Install Git for Windows from the built installer (same as CI does).
2. Set up AutoHotkey (extract from cached zip).
3. Configure ~/.minttyrc with KeyFunctions and SaveFilename.
4. Create a test repo using `installer/ui-tests/generate-test-repo.sh`.
5. Write a minimal AHK diagnostic script that:
   a. Writes a temp .gitconfig with gui.recentrepo pointing to test repo
   b. Launches git-gui.exe (directly, no Start Menu needed)
   c. Waits for the chooser window (TkTopLevel, title "Git Gui")
   d. Moves to 100,100 size 500x400
   e. Captures full-size screenshot
   f. Runs FindChooserLinkRow to find the blue link row
   g. Logs: window rect, client rect, title bar height, DPI,
      CoordMode settings, detected link y
   h. Tries multiple click strategies:
      - MouseMove first, then Click
      - ControlClick with coordinates
      - PostMessage WM_LBUTTONDOWN/WM_LBUTTONUP
      - SendMessage WM_LBUTTONDOWN/WM_LBUTTONUP
   i. After each strategy, checks for new TkTopLevel window
   j. Logs which strategy (if any) worked
   k. Captures screenshots after each attempt

6. Run the diagnostic script and examine output.
7. Once the working click strategy is identified, update
   `git-bash-checklist.ahk` accordingly.

## Important AHK notes

- Always invoke AHK with `/ErrorStdOut /force` AND pipe output (e.g.
  `| Out-File` or `| tee`). Without a pipe, FileAppend to stdout fails.
- Use `MSYS2_ARG_CONV_EXCL='*'` when calling from bash to prevent
  MSYS2 from converting /ErrorStdOut to a path.
- AHK v2 syntax (not v1).
- The chooser window class is `TkTopLevel`, title starts with "Git Gui".
- CoordMode 'Mouse', 'Window' makes Click relative to the window's
  top-left corner including the title bar (not client area).
  Actually, verify this: AHK v2 docs say Window mode coordinates are
  relative to the window's upper-left corner INCLUDING the non-client
  area (title bar, borders).

## Commit conventions

- One commit per logical change.
- Always commit with a pathspec (e.g. `git commit -F msg.txt -- path/`).
- No bullet points in commit messages; use flowing prose.
- Include `Assisted-by:` and `Signed-off-by:` trailers (in that order).
- Include `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`.
