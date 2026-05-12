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

hwnd := LaunchViaStartMenu('Git Bash', 'mintty')
Info 'Step 8: mintty hwnd=' . hwnd

WinClose('ahk_id ' hwnd)
Info 'All steps passed'
ExitApp 0
