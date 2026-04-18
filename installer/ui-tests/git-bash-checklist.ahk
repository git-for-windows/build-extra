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
; mintty appends .html to the SaveFilename value.
; If the path looks like a Unix path, resolve it via cygpath.
if SubStr(saveFilename, 1, 1) == '/'
{
    gitExe := 'C:\Program Files\Git\cmd\git.exe'
    if !FileExist(gitExe)
        ExitWithError 'Cannot resolve Unix path "' saveFilename '": git not found at ' gitExe
    exportFile := RunWaitOne('"' gitExe '" -c alias.cygpath="!cygpath" cygpath -aw "' saveFilename '"') . '.html'
}
else
    exportFile := StrReplace(saveFilename, '/', '\') . '.html'
Info 'Export file: ' exportFile

Info 'All prerequisites met.'

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

; Close the Git Bash window.
CloseMinTTYWindow(winId)

Info '=== Tests complete ==='
ExitApp 0
