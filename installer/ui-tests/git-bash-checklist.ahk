#Requires AutoHotkey v2.0
#Include ui-test-library.ahk

; Automated UI tests for the Git for Windows installer checklist.
; See installer/checklist.txt for the manual steps this script automates.
;
; Prerequisites:
;   ~/.minttyrc must contain:
;     KeyFunctions=C+F5:export-html
;     SaveFilename=<path>    (mintty appends .html to this)

SetLogFile(A_ScriptDir . '\git-bash-checklist.log')
Info '=== Git Bash checklist UI tests ==='
Info 'Date: ' A_Now

; Parse command-line arguments to select which phases to run.
; With no arguments, all phases run. Otherwise only named phases run.
; Usage: git-bash-checklist.ahk [--git-bash] [--git-cmd] [--git-gui]
runAll := A_Args.Length == 0
runGitBash := runAll
runGitCMD := runAll
runGitGUI := runAll
for arg in A_Args
{
    switch arg {
    case '--git-bash': runGitBash := true
    case '--git-cmd': runGitCMD := true
    case '--git-gui': runGitGUI := true
    default: ExitWithError 'Unknown argument: ' arg
    }
}

; Validate minttyrc prerequisites (only needed for Git Bash).
if runGitBash
{
    minttyrc := ReadMinTTYRC()
    RequireMinTTYRCSetting(minttyrc, 'KeyFunctions', 'C+F5:export-html')
    RequireMinTTYRCSetting(minttyrc, 'SaveFilename', '/tmp/mintty-export')
}

; We need git.exe for cygpath conversions throughout the script.
gitExe := 'C:\Program Files\Git\cmd\git.exe'
if !FileExist(gitExe)
    ExitWithError 'Git for Windows not found at ' gitExe

; Derive the mintty export file path (only needed for Git Bash).
if runGitBash
{
    saveFilename := minttyrc['SaveFilename']
    ; mintty appends .html to the SaveFilename value.
    ; If the path looks like a Unix path, resolve it via cygpath.
    if SubStr(saveFilename, 1, 1) == '/'
        exportFile := RunWaitOne('"' gitExe '" -c alias.cygpath="!cygpath" cygpath -aw "' saveFilename '"') . '.html'
    else
        exportFile := StrReplace(saveFilename, '/', '\') . '.html'
    Info 'Export file: ' exportFile
}

Info 'All prerequisites met.'

; === Create test repository ===
; Build a temporary repo via fast-import for use in subsequent tests.
; This runs outside the UI, before launching Git Bash.
Info '=== Create test repository ==='
scriptDirUnix := RunWaitOne('"' gitExe '" -c alias.cygpath="!cygpath" cygpath -u "' A_ScriptDir '"')
testRepo := '/tmp/git-bash-checklist-test-repo'
testRepoWin := RunWaitOne('"' gitExe '" -c alias.cygpath="!cygpath" cygpath -aw "' testRepo '"')
if DirExist(testRepoWin)
{
    try
        DirDelete(testRepoWin, true)
    catch as e
        ExitWithError 'Could not clean up old test repo at ' testRepoWin ': ' e.Message
}
RunWaitOne('"' gitExe '" -c alias.sh="!sh" sh "' scriptDirUnix '/generate-test-repo.sh" --create-test-repo=' testRepo)
Info 'Test repository created at ' testRepoWin

if runGitBash
{

; === Test: Git Bash starts via Start Menu ===
Info '=== Git Bash starts via Start Menu ==='
hwnd := LaunchViaStartMenu('Git Bash', 'mintty')
winId := 'ahk_id ' hwnd
minttyToClose := hwnd

; Wait for the bash prompt to appear.
deadline := A_TickCount + 30000
while A_TickCount < deadline
{
    capture := CaptureBufferFromMintty(exportFile, winId)
    if InStr(capture, '$ ')
        break
    Sleep 500
}
if !InStr(capture, '$ ')
    ExitWithError 'Timed out waiting for bash prompt'
Info 'Bash prompt appeared'

; === Test: Prompt shows branch ===
Info '=== Prompt shows branch ==='
WinActivate(winId)
SetKeyDelay 20, 20
SendEvent('{Text}cd ' testRepo)
SendEvent('{Enter}')
Sleep 1000
; The Git for Windows prompt shows the branch in parentheses, e.g. (main).
WaitForRegExInMintty(exportFile, 's)\(main\).*\$ ', 'Prompt does not show branch name after cd into test repo', 'Prompt shows branch (main)', 10000, winId)

; === Test: git log is colorful and stops after first page ===
Info '=== git log colorful and paged ==='
WinActivate(winId)
SetKeyDelay 20, 20
SendEvent('{Text}git log')
SendEvent('{Enter}')
Sleep 2000
; The pager (less) shows a colon prompt at the bottom when there is more
; content. Check for it in the plain text.
WaitForRegExInMintty(exportFile, '\n:', 'Timed out waiting for git log pager prompt', 'git log pager is active', 10000, winId)
; Now check the raw HTML for color CSS classes. git log uses colors for
; commit hashes, author names, dates, and decorations.
rawHtml := CaptureRawHtmlFromMintty(exportFile, winId)
if !RegExMatch(rawHtml, 'fg-color')
    ExitWithError 'git log output has no color (no fg-color CSS classes in HTML)'
Info 'git log output is colorful'
; Quit the pager.
WinActivate(winId)
SendEvent('{Text}q')
Sleep 500

; === Test: gitk runs and shows history ===
Info '=== gitk shows history ==='
WinActivate(winId)
SetKeyDelay 20, 20
SendEvent('{Text}gitk; echo $? >gitk-exit.code')
SendEvent('{Enter}')
VerifyGitkLayout('gitk', testRepoWin . '\gitk-thumb.png')
; Verify gitk exited with code 0 (bash was blocked while gitk ran).
gitkExitFile := testRepoWin . '\gitk-exit.code'
deadline := A_TickCount + 5000
while !FileExist(gitkExitFile) && A_TickCount < deadline
    Sleep 200
if !FileExist(gitkExitFile)
    ExitWithError 'gitk exit code file was not written'
gitkExitCode := Trim(FileRead(gitkExitFile), ' `t`r`n')
if gitkExitCode != '0'
    ExitWithError 'gitk exited with code ' gitkExitCode
Info 'gitk closed with exit code 0'

; === Test: git gui runs without error ===
Info '=== git gui no error ==='
WinActivate(winId)
SetKeyDelay 20, 20
SendEvent('{Text}git gui; echo $? >git-gui-exit.code')
SendEvent('{Enter}')
VerifyTkScreenshot('git gui', testRepoWin . '\git-gui-thumb.png', A_ScriptDir . '\git-gui-reference.png')
; Verify git gui exited with code 0.
gitGuiExitFile := testRepoWin . '\git-gui-exit.code'
deadline := A_TickCount + 5000
while !FileExist(gitGuiExitFile) && A_TickCount < deadline
    Sleep 200
if !FileExist(gitGuiExitFile)
    ExitWithError 'git gui exit code file was not written'
gitGuiExitCode := Trim(FileRead(gitGuiExitFile), ' `t`r`n')
if gitGuiExitCode != '0'
    ExitWithError 'git gui exited with code ' gitGuiExitCode
Info 'git gui closed with exit code 0'

; Close the Git Bash window.
CloseMinTTYWindow(winId)

} ; end runGitBash

if runGitCMD
{

; === Git CMD tests ===
; These require Windows Terminal with exportBuffer configured.
wtConfig := ReadWindowsTerminalExportBufferConfig()
if wtConfig.Count == 0
{
    Info 'NOTE: Windows Terminal exportBuffer not configured; skipping Git CMD tests.'
    Info 'See installer/checklist.txt for manual verification steps.'
}
else
{
    wtExportFile := wtConfig['exportFile']
    wtHotkey := WindowsTerminalHotkeyToAHK(wtConfig['hotkey'])
    Info 'Windows Terminal export file: ' wtExportFile
    Info 'Windows Terminal hotkey: ' wtConfig['hotkey'] ' (AHK: ' wtHotkey ')'

    ; === Test: Git CMD starts via Start Menu ===
    Info '=== Git CMD starts via Start Menu ==='
    cmdHwnd := LaunchViaStartMenu('Git CMD', 'CASCADIA_HOSTING_WINDOW_CLASS')
    cmdWinId := 'ahk_id ' cmdHwnd
    WaitForRegExInWindowsTerminal(wtExportFile, wtHotkey, '>\s*$', 'Timed out waiting for CMD prompt', 'CMD prompt appeared', 30000, cmdWinId)

    ; cd into the test repo.
    WinActivate(cmdWinId)
    SetKeyDelay 20, 20
    SendEvent('{Text}cd /d ' testRepoWin)
    SendEvent('{Enter}')
    Sleep 1000

    ; === Test: git log is colorful and paged (Git CMD) ===
    Info '=== git log colorful and paged (Git CMD) ==='
    WinActivate(cmdWinId)
    WinMove(100, 100, 800, 600, cmdWinId)
    SetKeyDelay 20, 20
    SendEvent('{Text}git log')
    SendEvent('{Enter}')
    Sleep 2000
    cmdLogRef := A_ScriptDir . '\cmd-git-log-reference.png'
    if FileExist(cmdLogRef)
    {
        diffRatio := CaptureUntilMatchesReference(cmdHwnd, 80, 60, testRepoWin . '\cmd-git-log-thumb.png', cmdLogRef, 0.15)
        Info 'git log (CMD) screenshot diff ratio: ' diffRatio
    }
    else
        Info 'WARNING: cmd-git-log-reference.png not found; skipping screenshot check'
    WaitForRegExInWindowsTerminal(wtExportFile, wtHotkey, ':\s*$', 'Timed out waiting for git log pager (CMD)', 'git log pager is active (CMD)', 10000, cmdWinId)
    WinActivate(cmdWinId)
    SendEvent('{Text}q')
    Sleep 500

    ; === Test: gitk runs and shows history (Git CMD) ===
    Info '=== gitk shows history (Git CMD) ==='
    WinActivate(cmdWinId)
    SetKeyDelay 20, 20
    SendEvent('{Text}gitk')
    SendEvent('{Enter}')
    ; gitk.exe returns immediately to CMD (it is a GUI wrapper).
    WaitForRegExInWindowsTerminal(wtExportFile, wtHotkey, '>\s*$', 'CMD prompt did not return after gitk', 'gitk returned to CMD prompt', 10000, cmdWinId)
    VerifyGitkLayout('gitk (CMD)', testRepoWin . '\cmd-gitk-thumb.png')

    ; === Test: git gui runs without error (Git CMD) ===
    Info '=== git gui no error (Git CMD) ==='
    WinActivate(cmdWinId)
    SetKeyDelay 20, 20
    SendEvent('{Text}git gui')
    SendEvent('{Enter}')
    VerifyTkScreenshot('git gui (CMD)', testRepoWin . '\cmd-git-gui-thumb.png', A_ScriptDir . '\git-gui-reference.png')

    ; Close the Git CMD window.
    WinClose(cmdWinId)
    WinWaitClose(cmdWinId, , 5)
}

} ; end runGitCMD

if runGitGUI
{

; === Git GUI standalone tests ===
Info '=== Git GUI standalone ==='
; Temporarily replace .gitconfig so the chooser shows only the test repo.
gitconfigPath := EnvGet('USERPROFILE') . '\.gitconfig'
gitconfigBackup := gitconfigPath . '.ui-test-backup'
if FileExist(gitconfigBackup)
    FileDelete gitconfigBackup
FileMove gitconfigPath, gitconfigBackup
; Ensure .gitconfig is restored on any exit.
OnExit((*) => (FileExist(gitconfigBackup) && (FileDelete(gitconfigPath), FileMove(gitconfigBackup, gitconfigPath))))
testRepoUnix := StrReplace(testRepoWin, '\', '/')
FileAppend '[gui]`n`trecentrepo = ' testRepoUnix '`n', gitconfigPath

; Launch Git GUI via Start Menu (opens the chooser dialog).
Info '=== Git GUI starts via Start Menu ==='
gitGuiChooserHwnd := LaunchViaStartMenu('Git GUI', 'TkTopLevel', 'Git Gui')

; Verify the chooser via screenshot.
WinMove(100, 100, 500, 400, 'ahk_id ' gitGuiChooserHwnd)
WinActivate('ahk_id ' gitGuiChooserHwnd)
chooserRef := A_ScriptDir . '\git-gui-chooser-reference.png'
if FileExist(chooserRef)
{
    diffRatio := CaptureUntilMatchesReference(gitGuiChooserHwnd, 80, 60, testRepoWin . '\git-gui-chooser-thumb.png', chooserRef, 0.20, 15000)
    Info 'Git GUI chooser screenshot diff ratio: ' diffRatio
}
else
    Info 'WARNING: git-gui-chooser-reference.png not found; skipping screenshot check'

; Click the first (only) recent repo entry to open it.
; Use window-relative coordinates to avoid DPI scaling mismatches.
CoordMode 'Mouse', 'Window'
WinActivate('ahk_id ' gitGuiChooserHwnd)
Sleep 500
Click(250, 220)
Sleep 3000
CoordMode 'Mouse', 'Screen'

; A Git GUI window should have opened for the test repo.
gitGuiRepoHwnd := 0
for h in WinGetList('ahk_class TkTopLevel')
{
    if InStr(WinGetTitle('ahk_id ' h), 'git-bash-checklist-test-repo')
    {
        gitGuiRepoHwnd := h
        break
    }
}
if !gitGuiRepoHwnd
    ExitWithError 'Git GUI did not open the test repository from the recent list'
Info 'Git GUI opened the test repo: ' WinGetTitle('ahk_id ' gitGuiRepoHwnd)

; Verify it matches the existing git-gui-reference.png.
WinMove(100, 100, 800, 600, 'ahk_id ' gitGuiRepoHwnd)
WinActivate('ahk_id ' gitGuiRepoHwnd)
diffRatio := CaptureUntilMatchesReference(gitGuiRepoHwnd, 80, 60, testRepoWin . '\git-gui-standalone-thumb.png', A_ScriptDir . '\git-gui-reference.png', 0.15)
Info 'Git GUI repo screenshot diff ratio: ' diffRatio

; Close all Tk windows.
for h in WinGetList('ahk_class TkTopLevel')
    WinClose('ahk_id ' h)
Sleep 1000

; Restore original .gitconfig (also handled by OnExit).
FileDelete gitconfigPath
FileMove gitconfigBackup, gitconfigPath
Info 'Restored .gitconfig'

} ; end runGitGUI

Info '=== Tests complete ==='
ExitApp 0
