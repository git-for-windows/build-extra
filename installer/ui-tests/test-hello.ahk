#Requires AutoHotkey v2.0
FileAppend 'Step 1: basic output works' . '`n', '*'

FileAppend 'Step 2: trying ComObject...' . '`n', '*'
shell := ComObject("WScript.Shell")
FileAppend 'Step 3: ComObject created' . '`n', '*'

FileAppend 'Step 4: trying RunWaitOne...' . '`n', '*'
exec := shell.Run(A_ComSpec ' /S /C "git version | clip"', 0, true)
FileAppend 'Step 5: RunWaitOne done, exit=' . exec . '`n', '*'
FileAppend 'Step 6: clipboard=' . A_Clipboard . '`n', '*'

FileAppend 'Step 7: trying SendEvent...' . '`n', '*'
SendEvent('{LWin}')
Sleep 2000
FileAppend 'Step 8: sent Win key' . '`n', '*'
Send('{Escape}')

FileAppend 'All steps passed' . '`n', '*'
ExitApp 0
