#Requires AutoHotkey v2.0
FileAppend 'Step 0: before include' . '`n', '*'

#Include ui-test-library.ahk

FileAppend 'Step 1: after include' . '`n', '*'

SetLogFile(A_ScriptDir . '\test-diag.log')
Info 'Step 2: Info works'

minttyrc := ReadMinTTYRC()
Info 'Step 3: minttyrc read, keys=' . minttyrc.Count

RequireMinTTYRCSetting(minttyrc, 'KeyFunctions', 'C+F5:export-html')
RequireMinTTYRCSetting(minttyrc, 'SaveFilename', '/tmp/mintty-export')
Info 'Step 4: minttyrc validated'

gitExe := 'C:\Program Files\Git\cmd\git.exe'
if !FileExist(gitExe)
    ExitWithError 'Git not found at ' gitExe
Info 'Step 5: git found'

saveFilename := minttyrc['SaveFilename']
if SubStr(saveFilename, 1, 1) == '/'
    exportFile := RunWaitOne('"' gitExe '" -c alias.cygpath="!cygpath" cygpath -aw "' saveFilename '"') . '.html'
else
    exportFile := StrReplace(saveFilename, '/', '\') . '.html'
Info 'Step 6: export file=' . exportFile

Info 'Step 7: about to launch via Start Menu'

; Verify Start Menu shortcuts exist
smDir := 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Git'
Info 'Step 7a: checking ' . smDir
if DirExist(smDir)
{
    loop files smDir . '\*.*'
        Info '  found: ' . A_LoopFileName
}
else
    Info '  directory does not exist!'

; Also check user Start Menu
userSmDir := EnvGet('APPDATA') . '\Microsoft\Windows\Start Menu\Programs\Git'
Info 'Step 7b: checking ' . userSmDir
if DirExist(userSmDir)
{
    loop files userSmDir . '\*.*'
        Info '  found: ' . A_LoopFileName
}
else
    Info '  directory does not exist!'

Info 'Step 7c: trying to launch'

; Instead of LaunchViaStartMenu, do it manually with more logging
minttyClass := 'ahk_class mintty'
existing := Map()
for h in WinGetList(minttyClass)
    existing[h] := true

SendEvent('{LWin}')
deadline := A_TickCount + 5000
while A_TickCount < deadline
{
    try {
        if WinGetProcessName('A') == 'SearchHost.exe'
            break
    }
    Sleep 100
}
Info 'Step 7d: active window after Win key: ' . WinGetProcessName('A') . ' title=' . WinGetTitle('A')

SendInput('Git Bash')
Sleep 3000
Info 'Step 7e: typed Git Bash, active: ' . WinGetProcessName('A') . ' title=' . WinGetTitle('A')

SendEvent('{Enter}')
Sleep 5000
Info 'Step 7f: pressed Enter, active: ' . WinGetProcessName('A') . ' title=' . WinGetTitle('A')

; Check all windows
for h in WinGetList()
{
    try {
        title := WinGetTitle(h)
        exe := WinGetProcessName(h)
        if title != '' && (InStr(exe, 'mintty') || InStr(title, 'Git') || InStr(title, 'Bash'))
            Info '  window: ' . exe . ' - ' . title
    }
}

hwnd := 0
for h in WinGetList(minttyClass)
{
    if !existing.Has(h)
    {
        hwnd := h
        break
    }
}
if !hwnd
    ExitWithError 'No new mintty window'
Info 'Step 8: mintty hwnd=' . hwnd
Info 'Step 8: mintty hwnd=' . hwnd

WinClose('ahk_id ' hwnd)
Info 'All steps passed'
ExitApp 0
