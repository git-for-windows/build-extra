; Reusable library functions for the Git for Windows installer UI tests.
;
; Adapted from the MSYS2 runtime's ui-test-library.ahk, trimmed to only
; what is needed for mintty-based testing of an installed Git for Windows.

logFile := ''

SetLogFile(path) {
    global logFile
    logFile := path
}

Info(text) {
    global logFile, cannotWriteToStdout
    if logFile != ''
        FileAppend text '`n', logFile
    if !IsSet(cannotWriteToStdout)
    {
        try
            FileAppend text '`n', '*'
        catch as e {
            if e.__Class == 'OSError' && e.Number == 6
                cannotWriteToStdout := false
            else
                throw e
        }
    }
}

ExitWithError(error) {
    Info 'Error: ' error
    ExitApp 1
}

; An unhandled error would show a modal dialog and hang an unattended run.
OnError(ExitOnError)
ExitOnError(e, *) {
    try ExitWithError(e.Message ' at ' e.File ':' e.Line)
    ExitApp 1
}

RunWaitOne(command) {
    outFile := A_Temp '\ui-test-output.txt'
    if RunWait(A_ComSpec ' /S /C "' command ' >"' outFile '""', , 'Hide') != 0
        ExitWithError 'Error executing command: ' command
    result := RegExReplace(FileRead(outFile, 'UTF-8'), '`r?`n$', '')
    FileDelete outFile
    return result
}

; Read ~/.minttyrc and return a Map of key=value pairs.
ReadMinTTYRC() {
    home := EnvGet('HOME')
    if home == ''
        home := EnvGet('USERPROFILE')
    path := home . '\.minttyrc'
    if !FileExist(path)
        ExitWithError '~/.minttyrc not found at: ' path '`n'
            . 'The UI tests require KeyFunctions and SaveFilename settings in ~/.minttyrc.'
    settings := Map()
    Loop Read path
    {
        line := Trim(A_LoopReadLine)
        if line == '' || SubStr(line, 1, 1) == '#'
            continue
        eq := InStr(line, '=')
        if eq > 0
            settings[SubStr(line, 1, eq - 1)] := SubStr(line, eq + 1)
    }
    return settings
}

; Verify that a required setting exists in the minttyrc Map.
; If missing, exit with a clear error message showing the expected format.
RequireMinTTYRCSetting(settings, key, example) {
    if !settings.Has(key)
        ExitWithError 'Missing required setting in ~/.minttyrc: ' key '`n'
            . 'Please add a line like:`n  ' key '=' example
}

; Parse mintty's KeyFunctions value to find the key bound to the named
; function. mintty's KeyFunctions format is
; `key:function[;key:function...]`, where `key` is e.g. `C+F5` (Ctrl+F5).
; Returns the binding string (e.g. `C+F5`) if found, or `` if the
; function is not bound. Whitespace around entries is tolerated.
FindMinTTYKeyFunction(keyFunctionsValue, functionName) {
    for entry in StrSplit(keyFunctionsValue, ';')
    {
        entry := Trim(entry)
        colon := InStr(entry, ':')
        if colon == 0
            continue
        if Trim(SubStr(entry, colon + 1)) == functionName
            return Trim(SubStr(entry, 1, colon - 1))
    }
    return ''
}

; Convert a mintty key binding (e.g. `C+F5`, `CS+a`) to the AHK Send
; sequence (e.g. `^{F5}`, `^+a`). mintty modifier letters are
; concatenated before the `+` separator: C=Ctrl, A=Alt, S=Shift,
; W=Win. After the `+` comes the key name: a function key like
; `F1`-`F24`, a named key like `Space`/`Tab`/`Enter`, or a single
; character. Exits on an unrecognised modifier or a missing `+`.
MinTTYKeyToAHK(minttyKey) {
    plus := InStr(minttyKey, '+')
    if plus == 0
        ExitWithError 'mintty key binding does not contain `+`: ' minttyKey
    modifiers := SubStr(minttyKey, 1, plus - 1)
    key := SubStr(minttyKey, plus + 1)
    ahk := ''
    loop StrLen(modifiers)
    {
        m := SubStr(modifiers, A_Index, 1)
        switch StrUpper(m) {
        case 'C': ahk .= '^'
        case 'A': ahk .= '!'
        case 'S': ahk .= '+'
        case 'W': ahk .= '#'
        default: ExitWithError 'Unrecognised mintty modifier "' m '" in: ' minttyKey
        }
    }
    if RegExMatch(key, 'i)^F\d+$')
        || RegExMatch(key, 'i)^(Space|Tab|Enter|Esc|Escape|Backspace|Delete|Insert|Home|End|PgUp|PgDn|Up|Down|Left|Right)$')
        ahk .= '{' key '}'
    else
        ahk .= key
    return ahk
}

; Trigger the export-html function to write the mintty screen as HTML,
; then return the raw HTML. The hotkey must be the AHK Send sequence
; that mintty has bound to export-html (see FindMinTTYKeyFunction and
; MinTTYKeyToAHK in this file).
CaptureRawHtmlFromMintty(exportFile, hotkey, winTitle := '') {
    if FileExist(exportFile)
        FileDelete exportFile
    if winTitle != ''
        WinActivate winTitle
    Send hotkey
    deadline := A_TickCount + 3000
    while !FileExist(exportFile) && A_TickCount < deadline
        Sleep 50
    if !FileExist(exportFile)
        return ''
    Sleep 100
    return FileRead(exportFile)
}

; Capture mintty screen as plain text (HTML tags stripped, entities decoded).
CaptureBufferFromMintty(exportFile, hotkey, winTitle := '') {
    html := CaptureRawHtmlFromMintty(exportFile, hotkey, winTitle)
    if html == ''
        return ''
    ; Extract body content only (skip CSS in <style>)
    if RegExMatch(html, 'si)<body[^>]*>(.*)</body>', &m)
        html := m[1]
    ; Replace <br> (including <br\n>) with newlines before stripping tags.
    text := RegExReplace(html, '<br\s*/?>', '`n')
    ; Strip remaining HTML tags
    text := RegExReplace(text, '<[^>]+>', '')
    ; Decode common HTML entities
    text := StrReplace(text, '&lt;', '<')
    text := StrReplace(text, '&gt;', '>')
    text := StrReplace(text, '&amp;', '&')
    return text
}

; Close a MinTTY window, handling the "close running processes?"
; confirmation dialog if it appears.
CloseMinTTYWindow(winId) {
    minttyPid := WinGetPID(winId)
    WinClose(winId)
    Sleep 500
    ; Click the OK button repeatedly until the dialog is gone.
    ; A single ControlClick sometimes visually activates the button
    ; but does not dismiss the dialog, likely a Tk/Win32 focus race.
    deadline := A_TickCount + 5000
    while A_TickCount < deadline
    {
        dialogHwnd := WinExist('ahk_class #32770 ahk_pid ' minttyPid)
        if !dialogHwnd
            break
        ControlClick('Button1', 'ahk_id ' dialogHwnd)
        Sleep 150
    }
    WinWaitClose(winId, , 3)
}

; Wait up to timeout ms for a window matching winSpec that is not in
; existing (a list from WinGetList) and whose title contains titleFilter
; (if non-empty). Returns the window handle, or 0 on timeout.
WaitForNewWindow(winSpec, existing, timeout, titleFilter := '') {
    old := Map()
    for h in existing
        old[h] := true
    deadline := A_TickCount + timeout
    while A_TickCount < deadline
    {
        for h in WinGetList(winSpec)
            if !old.Has(h)
            && (titleFilter == '' || InStr(WinGetTitle('ahk_id ' h), titleFilter))
                return h
        Sleep 200
    }
    return 0
}

; Launch an application via the Start Menu and wait for a new window
; of the given class to appear. Returns the window handle.
; titleFilter, if non-empty, requires the new window's title to contain
; the given substring.
LaunchViaStartMenu(searchText, windowClass, titleFilter := '', timeout := 20000) {
    winSpec := 'ahk_class ' windowClass
    existing := WinGetList(winSpec)

    ; Dismiss any stale Start Menu state before opening a fresh one.
    SendEvent('{Escape}')
    Sleep 500

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
    if A_TickCount >= deadline
    {
        ; Retry once: the shell may need a nudge.
        Info 'Start Menu did not appear on first try, retrying...'
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
    }
    if A_TickCount >= deadline
        ExitWithError 'Start Menu did not appear'
    Info 'Start Menu opened'

    SendInput(searchText)
    ; Give the search index time to find and highlight the result.
    Sleep 5000
    SendEvent('{Enter}')
    hwnd := WaitForNewWindow(winSpec, existing, timeout, titleFilter)
    if !hwnd
        ExitWithError searchText ' window did not appear after Start Menu launch'
    WinActivate('ahk_id ' hwnd)
    Info searchText ' launched, hwnd: ' hwnd
    return hwnd
}
