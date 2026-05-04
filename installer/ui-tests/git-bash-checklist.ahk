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
; Usage: git-bash-checklist.ahk [--git-bash] [--git-cmd]
runAll := A_Args.Length == 0
runGitBash := runAll
runGitCMD := runAll
for arg in A_Args
{
    switch arg {
    case '--git-bash': runGitBash := true
    case '--git-cmd': runGitCMD := true
    default: ExitWithError 'Unknown argument: ' arg
    }
}

; Validate minttyrc prerequisites (only needed for Git Bash).
if runGitBash
{
    minttyrc := ReadMinTTYRC()
    RequireMinTTYRCSetting(minttyrc, 'KeyFunctions', 'C+F5:export-html')
    RequireMinTTYRCSetting(minttyrc, 'SaveFilename', '/tmp/mintty-export')
    exportHtmlBinding := FindMinTTYKeyFunction(minttyrc['KeyFunctions'], 'export-html')
    if exportHtmlBinding == ''
        ExitWithError 'KeyFunctions in ~/.minttyrc does not bind `export-html`.`n'
            . 'Please add `export-html` to KeyFunctions, e.g.`n  KeyFunctions=C+F5:export-html'
    exportHtmlHotkey := MinTTYKeyToAHK(exportHtmlBinding)
    Info 'export-html bound to ' exportHtmlBinding ' (AHK: ' exportHtmlHotkey ')'
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
; Build a temporary repo for use in subsequent tests.
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
RunWaitOne('"' gitExe '" -c alias.sh="!sh" sh "' scriptDirUnix '/generate-test-repo.sh" "' testRepoWin '"')
Info 'Test repository created at ' testRepoWin

if runGitBash
{

; === Test: Git Bash starts via Start Menu ===
Info '=== Git Bash starts via Start Menu ==='
hwnd := LaunchViaStartMenu('Git Bash', 'mintty')
winId := 'ahk_id ' hwnd

; Wait for the bash prompt to appear.
deadline := A_TickCount + 30000
while A_TickCount < deadline
{
    capture := CaptureBufferFromMintty(exportFile, exportHtmlHotkey, winId)
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
WaitForRegExInMintty(exportFile, exportHtmlHotkey, 's)\(main\).*\$ ', 'Prompt does not show branch name after cd into test repo', 'Prompt shows branch (main)', 10000, winId)

; === Test: git log is colorful and stops after first page ===
Info '=== git log colorful and paged ==='
WinActivate(winId)
SetKeyDelay 20, 20
SendEvent('{Text}git log')
SendEvent('{Enter}')
Sleep 2000
; The pager (less) shows a colon prompt at the bottom when there is more
; content. Check for it in the plain text.
WaitForRegExInMintty(exportFile, exportHtmlHotkey, '\n:', 'Timed out waiting for git log pager prompt', 'git log pager is active', 10000, winId)
; Now check the raw HTML for colored text. git log uses colors for
; commit hashes, author names, dates, and decorations. mintty writes
; them as inline styles in the body; its <style> header always defines
; every color, so it must not be searched.
rawHtml := CaptureRawHtmlFromMintty(exportFile, exportHtmlHotkey, winId)
if !RegExMatch(rawHtml, "s)<body.*[' ]color: #")
    ExitWithError 'git log output has no color'
Info 'git log output is colorful'
; Quit the pager.
QuitPager(winId)

; === Test: gitk runs and shows history ===
Info '=== gitk shows history ==='
WinActivate(winId)
SetKeyDelay 20, 20
tk := WinGetList('ahk_class TkTopLevel')
SendEvent('{Text}gitk; echo $? >gitk-exit.code')
SendEvent('{Enter}')
VerifyGitkLayout('gitk', A_ScriptDir . '\gitk-thumb.png', tk)
WaitForExitCode('gitk', testRepoWin . '\gitk-exit.code')

; === Test: git gui runs without error ===
Info '=== git gui no error ==='
WinActivate(winId)
SetKeyDelay 20, 20
tk := WinGetList('ahk_class TkTopLevel')
SendEvent('{Text}git gui; echo $? >git-gui-exit.code')
SendEvent('{Enter}')
VerifyGitGuiLayout('git gui', A_ScriptDir . '\git-gui-thumb.png', tk)
WaitForExitCode('git gui', testRepoWin . '\git-gui-exit.code')

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
    cmdHwnd := LaunchViaStartMenu('Git CMD', 'CASCADIA_HOSTING_WINDOW_CLASS', 'Git CMD')
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
    diffRatio := CaptureUntilMatchesReference(cmdHwnd, 80, 60, A_ScriptDir . '\cmd-git-log-thumb.png', A_ScriptDir . '\cmd-git-log-reference.png', 0.15)
    Info 'git log (CMD) screenshot diff ratio: ' diffRatio
    ; The reference comparison alone would accept a colorless rendering.
    bands := CountColoredRowBands(A_ScriptDir . '\cmd-git-log-thumb.png')
    if bands < 3
        ExitWithError 'git log (CMD) is not colorful (' bands ' colored row bands)'
    Info 'git log (CMD) colored row bands: ' bands
    WaitForRegExInWindowsTerminal(wtExportFile, wtHotkey, ':\s*$', 'Timed out waiting for git log pager (CMD)', 'git log pager is active (CMD)', 10000, cmdWinId)
    WinActivate(cmdWinId)
    QuitPager(cmdWinId)

    ; === Test: gitk runs and shows history (Git CMD) ===
    Info '=== gitk shows history (Git CMD) ==='
    WinActivate(cmdWinId)
    SetKeyDelay 20, 20
    tk := WinGetList('ahk_class TkTopLevel')
    SendEvent('{Text}gitk')
    SendEvent('{Enter}')
    ; gitk.exe returns immediately to CMD (it is a GUI wrapper).
    WaitForRegExInWindowsTerminal(wtExportFile, wtHotkey, 's)>gitk\R.*>\s*$', 'CMD prompt did not return after gitk', 'gitk returned to CMD prompt', 10000, cmdWinId)
    VerifyGitkLayout('gitk (CMD)', A_ScriptDir . '\cmd-gitk-thumb.png', tk)

    ; === Test: git gui runs without error (Git CMD) ===
    Info '=== git gui no error (Git CMD) ==='
    WinActivate(cmdWinId)
    SetKeyDelay 20, 20
    tk := WinGetList('ahk_class TkTopLevel')
    SendEvent('{Text}git gui')
    SendEvent('{Enter}')
    VerifyGitGuiLayout('git gui (CMD)', A_ScriptDir . '\cmd-git-gui-thumb.png', tk)

    ; Close the Git CMD window.
    WinClose(cmdWinId)
    WinWaitClose(cmdWinId, , 5)
}

} ; end runGitCMD

Info '=== Tests complete ==='
ExitApp 0
