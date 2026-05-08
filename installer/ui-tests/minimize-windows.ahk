; Minimize all visible windows so the UI tests have a clean desktop.
; This is important in CI where a log/console window may occlude the
; windows that the tests launch.

#Requires AutoHotkey v2.0

for hwnd in WinGetList()
{
    title := WinGetTitle(hwnd)
    if title != ""
    {
        try {
            exe := WinGetProcessName(hwnd)
        } catch {
            exe := "<unknown>"
        }
        FileAppend 'Minimizing: ' . exe . ' - ' . title . '`n', '*'
        WinMinimize(hwnd)
    }
}
