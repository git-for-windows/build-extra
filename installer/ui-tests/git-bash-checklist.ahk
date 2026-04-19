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

; Validate minttyrc prerequisites.
minttyrc := ReadMinTTYRC()
RequireMinTTYRCSetting(minttyrc, 'KeyFunctions', 'C+F5:export-html')
RequireMinTTYRCSetting(minttyrc, 'SaveFilename', '/tmp/mintty-export')

; Derive the export file path from SaveFilename.
saveFilename := minttyrc['SaveFilename']
; We need git.exe for cygpath conversions throughout the script.
gitExe := 'C:\Program Files\Git\cmd\git.exe'
if !FileExist(gitExe)
    ExitWithError 'Git for Windows not found at ' gitExe
; mintty appends .html to the SaveFilename value.
; If the path looks like a Unix path, resolve it via cygpath.
if SubStr(saveFilename, 1, 1) == '/'
    exportFile := RunWaitOne('"' gitExe '" -c alias.cygpath="!cygpath" cygpath -aw "' saveFilename '"') . '.html'
else
    exportFile := StrReplace(saveFilename, '/', '\') . '.html'
Info 'Export file: ' exportFile

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

; Close the Git Bash window.
CloseMinTTYWindow(winId)

Info '=== Tests complete ==='
ExitApp 0
