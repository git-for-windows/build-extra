; Reusable library functions for the Git for Windows installer UI tests.
;
; Adapted from the MSYS2 runtime's ui-test-library.ahk, trimmed to only
; what is needed for mintty-based testing of an installed Git for Windows.

logFile := ''

; Timeout in milliseconds for a Tk window to appear. On ARM64
; runners, wish.exe under x64 emulation can take over 130 seconds
; for a cold start.
tkWaitTimeout := 180000

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

; Wait for a regex to match in the mintty buffer. Returns the match object
; on success, exits with error on timeout.
WaitForRegExInMintty(exportFile, hotkey, regex, errorMessage, successMessage, timeout := 5000, winTitle := '') {
    deadline := timeout + A_TickCount
    while true
    {
        capturedText := CaptureBufferFromMintty(exportFile, hotkey, winTitle)
        if RegExMatch(capturedText, regex, &matchObj)
        {
            Info(successMessage)
            return matchObj
        }
        Sleep 200
        if A_TickCount > deadline {
            Info('Captured text:`n' . capturedText)
            ExitWithError errorMessage
        }
    }
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

; Wait for an exit-code file to appear on disk (written by a shell
; command like `echo $? >file`), read it, and verify it is '0'.
WaitForExitCode(label, exitFile, timeout := 5000) {
    code := ''
    deadline := A_TickCount + timeout
    while code = '' && A_TickCount < deadline {
        Sleep 200
        try code := Trim(FileRead(exitFile), ' `t`r`n')
    }
    if code = ''
        ExitWithError label ' exit code file was not written'
    if code != '0'
        ExitWithError label ' exited with code ' code
    Info label ' closed with exit code 0'
}

; Quit a pager (less) running inside a terminal window. On ARM64
; runners, SendEvent('{Text}q') (VK_PACKET) has been observed to be
; swallowed by less's alternate-screen mode under x64 emulation.
; Send (SendInput / real VK_Q) is more reliable.
QuitPager(winId) {
    WinActivate(winId)
    Send 'q'
    Sleep 500
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

; Initialize GDI+ and return the token. Call ShutdownGdiPlus(token)
; when done.
StartupGdiPlus() {
    DllCall('LoadLibrary', 'str', 'gdiplus')
    input := Buffer(24, 0)
    NumPut('uint', 1, input)
    token := 0
    DllCall('gdiplus\GdiplusStartup', 'ptr*', &token, 'ptr', input, 'ptr', 0)
    return token
}

ShutdownGdiPlus(token) {
    DllCall('gdiplus\GdiplusShutdown', 'ptr', token)
}

; Get the CLSID for the GDI+ PNG encoder.
; This is a well-known constant: {557cf406-1a04-11d3-9a73-0000f81ef32e}
GetPngEncoderClsid() {
    clsid := Buffer(16)
    NumPut('uint', 0x557cf406, clsid, 0)
    NumPut('ushort', 0x1a04, clsid, 4)
    NumPut('ushort', 0x11d3, clsid, 6)
    NumPut('uchar', 0x9a, clsid, 8)
    NumPut('uchar', 0x73, clsid, 9)
    NumPut('uchar', 0x00, clsid, 10)
    NumPut('uchar', 0x00, clsid, 11)
    NumPut('uchar', 0xf8, clsid, 12)
    NumPut('uchar', 0x1e, clsid, 13)
    NumPut('uchar', 0xf3, clsid, 14)
    NumPut('uchar', 0x2e, clsid, 15)
    return clsid
}

; Capture a window, downscale to thumbW x thumbH, and save as PNG.
; Uses GDI+ HighQualityBicubic interpolation for Lanczos-like quality.
; The window must be visible and unobscured since we capture from screen
; (Tk windows do not support PrintWindow).
CaptureAndDownscaleWindow(hwnd, thumbW, thumbH, outFile) {
    ; Get window rectangle on screen.
    rc := Buffer(16)
    DllCall('GetWindowRect', 'ptr', hwnd, 'ptr', rc)
    x := NumGet(rc, 0, 'int')
    y := NumGet(rc, 4, 'int')
    w := NumGet(rc, 8, 'int') - x
    h := NumGet(rc, 12, 'int') - y
    if w <= 0 || h <= 0
        ExitWithError 'Window has zero size'

    ; Capture from the screen DC via BitBlt.
    hdcScreen := DllCall('GetDC', 'ptr', 0, 'ptr')
    hdcMem := DllCall('CreateCompatibleDC', 'ptr', hdcScreen, 'ptr')
    hbm := DllCall('CreateCompatibleBitmap', 'ptr', hdcScreen, 'int', w, 'int', h, 'ptr')
    hOld := DllCall('SelectObject', 'ptr', hdcMem, 'ptr', hbm, 'ptr')
    ; SRCCOPY = 0x00CC0020
    DllCall('BitBlt', 'ptr', hdcMem, 'int', 0, 'int', 0, 'int', w, 'int', h,
        'ptr', hdcScreen, 'int', x, 'int', y, 'uint', 0x00CC0020)
    DllCall('SelectObject', 'ptr', hdcMem, 'ptr', hOld)
    DllCall('DeleteDC', 'ptr', hdcMem)
    DllCall('ReleaseDC', 'ptr', 0, 'ptr', hdcScreen)

    ; Convert HBITMAP to GDI+ Bitmap.
    gdipToken := StartupGdiPlus()
    pBitmap := 0
    DllCall('gdiplus\GdipCreateBitmapFromHBITMAP', 'ptr', hbm, 'ptr', 0, 'ptr*', &pBitmap)
    DllCall('DeleteObject', 'ptr', hbm)

    ; Create a thumbnail bitmap and draw with high quality.
    pThumb := 0
    DllCall('gdiplus\GdipCreateBitmapFromScan0', 'int', thumbW, 'int', thumbH,
        'int', 0, 'int', 0x26200A, 'ptr', 0, 'ptr*', &pThumb)
    pGraphics := 0
    DllCall('gdiplus\GdipGetImageGraphicsContext', 'ptr', pThumb, 'ptr*', &pGraphics)
    ; InterpolationModeHighQualityBicubic = 7
    DllCall('gdiplus\GdipSetInterpolationMode', 'ptr', pGraphics, 'int', 7)
    DllCall('gdiplus\GdipDrawImageRectI', 'ptr', pGraphics, 'ptr', pBitmap,
        'int', 0, 'int', 0, 'int', thumbW, 'int', thumbH)

    ; Save as PNG.
    pngClsid := GetPngEncoderClsid()
    DllCall('gdiplus\GdipSaveImageToFile', 'ptr', pThumb, 'wstr', outFile, 'ptr', pngClsid, 'ptr', 0)

    ; Cleanup.
    DllCall('gdiplus\GdipDeleteGraphics', 'ptr', pGraphics)
    DllCall('gdiplus\GdipDisposeImage', 'ptr', pThumb)
    DllCall('gdiplus\GdipDisposeImage', 'ptr', pBitmap)
    ShutdownGdiPlus(gdipToken)
}

; Verify a gitk window by analyzing its screenshot structurally rather
; than comparing pixel-by-pixel against a reference image. This makes
; the test independent of system-specific font metrics, window chrome,
; and theme colors that vary across Windows versions.
;
; Checks performed on the 80x60 thumbnail:
;  1. Window rendered (not blank/uniform)
;  2. Commit graph decorations visible (colored pixels on the left)
;  3. Commit list text visible (darker-than-background rows in center)
;  4. At least minCommitRows commit entries rendered
;  5. A selection highlight row exists
;
; existingTk is WinGetList('ahk_class TkTopLevel'), taken before gitk
; was launched, so that only a new window is checked.
VerifyGitkLayout(label, thumbFile, existingTk, timeout := 30000) {
    hwnd := WaitForNewWindow('ahk_class TkTopLevel', existingTk, tkWaitTimeout)
    if !hwnd
        ExitWithError label ': Tk window did not appear'
    Info label ': window appeared'
    WinMove(100, 100, 800, 600, 'ahk_id ' hwnd)
    WinActivate('ahk_id ' hwnd)

    thumbW := 80
    thumbH := 60
    deadline := A_TickCount + timeout
    lastErr := 'no capture attempted'
    while A_TickCount < deadline {
        CaptureAndDownscaleWindow(hwnd, thumbW, thumbH, thumbFile)
        lastErr := CheckGitkStructure(thumbFile, thumbW, thumbH)
        if lastErr = '' {
            Info label ': layout verification passed'
            WinClose('ahk_id ' hwnd)
            WinWaitClose('ahk_id ' hwnd, , 5)
            Info label ': closed'
            return hwnd
        }
        Info label ': retry (' lastErr ')'
        Sleep 2000
    }
    ExitWithError label ': layout check failed after ' timeout 'ms: ' lastErr
}

; Analyze a gitk screenshot for expected structure.
; Returns empty string on success, or an error description.
CheckGitkStructure(file, w, h) {
    gdipToken := StartupGdiPlus()
    pBitmap := 0
    DllCall('gdiplus\GdipCreateBitmapFromFile', 'wstr', file, 'ptr*', &pBitmap)
    if !pBitmap {
        ShutdownGdiPlus(gdipToken)
        return 'failed to load ' file
    }

    ; Per-row analysis over the thumbnail.
    graphRows := 0
    textRows := 0
    highlightRows := 0
    nonBlankRows := 0

    loop h {
        y := A_Index - 1
        leftColored := false
        centerTextPixels := 0
        highlightPixels := 0
        rowIsBlank := true

        loop w {
            x := A_Index - 1
            argb := 0
            DllCall('gdiplus\GdipBitmapGetPixel', 'ptr', pBitmap,
                'int', x, 'int', y, 'uint*', &argb)
            r := (argb >> 16) & 0xFF
            g := (argb >> 8) & 0xFF
            b := argb & 0xFF
            avg := (r + g + b) // 3
            chroma := Max(Abs(r - g), Abs(g - b), Abs(r - b))

            if avg < 230 || chroma > 25
                rowIsBlank := false

            ; Left 10 columns: graph decorations are distinctly colored.
            if x < 10 && chroma > 40
                leftColored := true

            ; Center columns 15..65: commit text is darker than white
            ; background but lighter than a selection highlight.
            if x >= 15 && x <= 65 {
                if avg >= 140 && avg <= 210
                    centerTextPixels++
                if avg < 130
                    highlightPixels++
            }
        }

        if !rowIsBlank
            nonBlankRows++
        if leftColored
            graphRows++
        ; A row counts as "text" when enough center pixels are text-like.
        if centerTextPixels >= 10
            textRows++
        if highlightPixels >= 10
            highlightRows++
    }

    DllCall('gdiplus\GdipDisposeImage', 'ptr', pBitmap)
    ShutdownGdiPlus(gdipToken)

    if nonBlankRows < h * 0.3
        return 'window mostly blank (' nonBlankRows '/' h ' non-blank rows)'
    if graphRows < 3
        return 'too few graph rows (' graphRows '), need >= 3'
    if textRows < 5
        return 'too few commit text rows (' textRows '), need >= 5'
    if highlightRows < 1
        return 'no selection highlight found'

    return ''
}

; Verify a git gui window by analyzing its screenshot structurally.
; Checks that the window has rendered content typical of git gui:
;  1. Window is not blank/uniform
;  2. Colored staging area visible (yellow/green region on the left)
;  3. Distinct horizontal regions (menu bar, staging, commit area)
;  4. Title names the test repository (the repository chooser, or an
;     error window, would otherwise pass the checks above)
;
; existingTk is as in VerifyGitkLayout.
VerifyGitGuiLayout(label, thumbFile, existingTk, timeout := 30000) {
    hwnd := WaitForNewWindow('ahk_class TkTopLevel', existingTk, tkWaitTimeout)
    if !hwnd
        ExitWithError label ': Tk window did not appear'
    Info label ': window appeared'

    if !WinWait('git-bash-checklist-test-repo ahk_id ' hwnd, , 30)
        ExitWithError label ': title does not name the test repository: ' WinGetTitle('ahk_id ' hwnd)

    WinMove(100, 100, 800, 600, 'ahk_id ' hwnd)
    WinActivate('ahk_id ' hwnd)

    thumbW := 80
    thumbH := 60
    deadline := A_TickCount + timeout
    lastErr := 'no capture attempted'
    while A_TickCount < deadline {
        CaptureAndDownscaleWindow(hwnd, thumbW, thumbH, thumbFile)
        lastErr := CheckGitGuiStructure(thumbFile, thumbW, thumbH)
        if lastErr = '' {
            Info label ': layout verification passed'
            WinClose('ahk_id ' hwnd)
            WinWaitClose('ahk_id ' hwnd, , 5)
            Info label ': closed'
            return hwnd
        }
        Info label ': retry (' lastErr ')'
        Sleep 2000
    }
    ExitWithError label ': layout check failed after ' timeout 'ms: ' lastErr
}

; Analyze a git gui screenshot for expected structure.
; Returns empty string on success, or an error description.
CheckGitGuiStructure(file, w, h) {
    gdipToken := StartupGdiPlus()
    pBitmap := 0
    DllCall('gdiplus\GdipCreateBitmapFromFile', 'wstr', file, 'ptr*', &pBitmap)
    if !pBitmap {
        ShutdownGdiPlus(gdipToken)
        return 'failed to load ' file
    }

    ; Analyze the thumbnail for git gui's characteristic layout:
    ; - Colored rows (yellow/green staging area)
    ; - Light rows (white diff/commit area)
    ; - Dark or text-like rows (menu bar, labels)
    nonBlankRows := 0
    coloredRows := 0
    lightRows := 0

    loop h {
        y := A_Index - 1
        rowIsBlank := true
        coloredPixels := 0
        lightPixels := 0

        loop w {
            x := A_Index - 1
            argb := 0
            DllCall('gdiplus\GdipBitmapGetPixel', 'ptr', pBitmap,
                'int', x, 'int', y, 'uint*', &argb)
            r := (argb >> 16) & 0xFF
            g := (argb >> 8) & 0xFF
            b := argb & 0xFF
            avg := (r + g + b) // 3
            chroma := Max(Abs(r - g), Abs(g - b), Abs(r - b))

            if avg < 230 || chroma > 25
                rowIsBlank := false

            ; Colored pixels: staging area has yellow/green hues
            if chroma > 30 && avg > 100 && avg < 230
                coloredPixels++

            ; Light pixels: white/near-white areas (diff pane, empty areas)
            if avg > 230 && chroma < 15
                lightPixels++
        }

        if !rowIsBlank
            nonBlankRows++
        if coloredPixels >= 5
            coloredRows++
        if lightPixels >= w // 2
            lightRows++
    }

    DllCall('gdiplus\GdipDisposeImage', 'ptr', pBitmap)
    ShutdownGdiPlus(gdipToken)

    if nonBlankRows < h * 0.3
        return 'window mostly blank (' nonBlankRows '/' h ' non-blank rows)'
    if coloredRows < 2
        return 'too few colored rows (' coloredRows '), need >= 2 (staging area)'
    if lightRows < 3
        return 'too few light rows (' lightRows '), need >= 3 (diff/commit area)'

    return ''
}
