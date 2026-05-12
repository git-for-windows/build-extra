; Reusable library functions for the Git for Windows installer UI tests.
;
; Adapted from the MSYS2 runtime's ui-test-library.ahk, trimmed to only
; what is needed for mintty and Windows Terminal based testing of an
; installed Git for Windows.

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

minttyToClose := 0
childPid := 0
ExitWithError(error) {
    Info 'Error: ' error
    if minttyToClose != 0
        CloseMinTTYWindow('ahk_id ' minttyToClose)
    else if childPid != 0
        ProcessClose childPid
    ExitApp 1
}

RunWaitOne(command) {
    SavedClipboard := ClipboardAll()
    shell := ComObject("WScript.Shell")
    exec := shell.Run(A_ComSpec ' /S /C "' command ' | clip"', 0, true)
    if exec != 0
        ExitWithError 'Error executing command: ' command
    Result := RegExReplace(A_Clipboard, '`r?`n$', '')
    A_Clipboard := SavedClipboard
    return Result
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

; Trigger Ctrl+F5 to export mintty screen as HTML, return the raw HTML.
CaptureRawHtmlFromMintty(exportFile, winTitle := '') {
    if FileExist(exportFile)
        FileDelete exportFile
    if winTitle != ''
        WinActivate winTitle
    Send '^{F5}'
    deadline := A_TickCount + 3000
    while !FileExist(exportFile) && A_TickCount < deadline
        Sleep 50
    if !FileExist(exportFile)
        return ''
    Sleep 100
    return FileRead(exportFile)
}

; Capture mintty screen as plain text (HTML tags stripped, entities decoded).
CaptureBufferFromMintty(exportFile, winTitle := '') {
    html := CaptureRawHtmlFromMintty(exportFile, winTitle)
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
WaitForRegExInMintty(exportFile, regex, errorMessage, successMessage, timeout := 5000, winTitle := '') {
    deadline := timeout + A_TickCount
    while true
    {
        capturedText := CaptureBufferFromMintty(exportFile, winTitle)
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
    minttyToClose := 0
}

; Wait for a new TkTopLevel window to appear, set a fixed size,
; verify its screenshot matches a reference image, then close it.
; Returns the window handle (already closed).
VerifyTkScreenshot(label, thumbFile, referenceFile, maxDiff := 0.15) {
    hwnd := WinWait('ahk_class TkTopLevel', , 15)
    if !hwnd
        ExitWithError label ': Tk window did not appear'
    Info label ': window appeared'
    WinMove(100, 100, 800, 600, 'ahk_id ' hwnd)
    WinActivate('ahk_id ' hwnd)
    diffRatio := CaptureUntilMatchesReference(hwnd, 80, 60, thumbFile, referenceFile, maxDiff)
    Info label ': screenshot diff ratio: ' diffRatio
    WinClose('ahk_id ' hwnd)
    WinWaitClose('ahk_id ' hwnd, , 5)
    Info label ': closed'
    return hwnd
}

; Launch an application via the Start Menu and wait for a new window
; of the given class to appear. Returns the window handle.
; titleFilter, if non-empty, requires the new window's title to contain
; the given substring.
LaunchViaStartMenu(searchText, windowClass, titleFilter := '', timeout := 20000) {
    winSpec := 'ahk_class ' windowClass
    existing := Map()
    for h in WinGetList(winSpec)
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
    if A_TickCount >= deadline
        ExitWithError 'Start Menu did not appear'
    Info 'Start Menu opened'

    SendInput(searchText)
    ; Give the search index time to find and highlight the result,
    ; then send Enter. Retry up to twice if the target window has
    ; not appeared, but wait substantially between retries to avoid
    ; launching multiple instances on a busy machine.
    hwnd := 0
    retries := 3
    deadline := A_TickCount + timeout
    loop retries
    {
        Sleep 2000
        SendEvent('{Enter}')
        ; Wait up to 5 seconds for the window to appear after each Enter.
        innerDeadline := A_TickCount + 5000
        while A_TickCount < innerDeadline && A_TickCount < deadline
        {
            for h in WinGetList(winSpec)
            {
                if !existing.Has(h)
                && (titleFilter == '' || InStr(WinGetTitle('ahk_id ' h), titleFilter))
                {
                    hwnd := h
                    break 3
                }
            }
            Sleep 200
        }
        ; If SearchHost is no longer active, the Start Menu closed
        ; without launching anything (user may have pressed Escape).
        try {
            if WinGetProcessName('A') != 'SearchHost.exe'
                break
        }
    }
    if !hwnd
        ExitWithError searchText ' window did not appear after Start Menu launch'
    WinActivate('ahk_id ' hwnd)
    Info searchText ' launched, hwnd: ' hwnd
    return hwnd
}

; --- Windows Terminal support ---

; Read the Windows Terminal settings.json and extract the exportBuffer
; configuration. Returns a Map with keys 'exportFile' and 'hotkey'.
; Returns an empty Map if exportBuffer is not configured with a path.
ReadWindowsTerminalExportBufferConfig() {
    result := Map()
    localAppData := EnvGet('LOCALAPPDATA')
    ; Check all known settings.json locations per
    ; https://learn.microsoft.com/en-us/windows/terminal/install
    for settingsPath in [
        localAppData . '\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json',
        localAppData . '\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json',
        localAppData . '\Microsoft\Windows Terminal\settings.json'
    ]
    {
        if !FileExist(settingsPath)
            continue
        json := FileRead(settingsPath)

        ; Find the exportBuffer action and extract its path.
        if !RegExMatch(json, 's)"action"\s*:\s*"exportBuffer"[^}]*"path"\s*:\s*"([^"]+)"', &m)
            continue
        exportPath := m[1]

        ; Find the id for this action.
        if !RegExMatch(json, 's)"action"\s*:\s*"exportBuffer"[^}]*\}[^}]*"id"\s*:\s*"([^"]+)"', &idMatch)
            continue
        actionId := idMatch[1]

        ; Find the key binding for this id.
        if !RegExMatch(json, '"id"\s*:\s*"' actionId '"[^}]*"keys"\s*:\s*"([^"]+)"', &keyMatch)
        && !RegExMatch(json, '"keys"\s*:\s*"([^"]+)"[^}]*"id"\s*:\s*"' actionId '"', &keyMatch)
            continue

        result['exportFile'] := StrReplace(exportPath, '/', '\')
        result['hotkey'] := keyMatch[1]
        return result
    }
    return result
}

; Convert a Windows Terminal key binding string (e.g., "ctrl+shift+e")
; to an AHK Send string (e.g., "^+e").
WindowsTerminalHotkeyToAHK(wtKey) {
    ahk := ''
    parts := StrSplit(wtKey, '+')
    key := parts[parts.Length]
    loop parts.Length - 1
    {
        switch StrLower(parts[A_Index]) {
        case 'ctrl': ahk .= '^'
        case 'shift': ahk .= '+'
        case 'alt': ahk .= '!'
        case 'win': ahk .= '#'
        }
    }
    ; Handle function keys and special keys.
    if RegExMatch(key, '^f\d+$')
        ahk .= '{' key '}'
    else
        ahk .= key
    return ahk
}

; Capture the Windows Terminal buffer via the exportBuffer action.
CaptureBufferFromWindowsTerminal(exportFile, hotkey, winTitle := '') {
    if FileExist(exportFile)
        FileDelete exportFile
    if winTitle != ''
        WinActivate winTitle
    Sleep 200
    Send hotkey
    deadline := A_TickCount + 3000
    while !FileExist(exportFile) && A_TickCount < deadline
        Sleep 50
    if !FileExist(exportFile)
        return ''
    Sleep 100
    return FileRead(exportFile)
}

; Wait for a regex to match in the Windows Terminal buffer.
WaitForRegExInWindowsTerminal(exportFile, hotkey, regex, errorMessage, successMessage, timeout := 5000, winTitle := '') {
    deadline := timeout + A_TickCount
    while true
    {
        capturedText := CaptureBufferFromWindowsTerminal(exportFile, hotkey, winTitle)
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

; Compare two PNG files pixel-by-pixel. Returns a value 0.0..1.0
; representing the fraction of pixels that differ by more than
; `tolerance` (0-255) in any channel.
CompareImages(file1, file2, tolerance := 10) {
    gdipToken := StartupGdiPlus()
    pBmp1 := 0
    pBmp2 := 0
    DllCall('gdiplus\GdipCreateBitmapFromFile', 'wstr', file1, 'ptr*', &pBmp1)
    DllCall('gdiplus\GdipCreateBitmapFromFile', 'wstr', file2, 'ptr*', &pBmp2)
    w1 := 0
    h1 := 0
    w2 := 0
    h2 := 0
    DllCall('gdiplus\GdipGetImageWidth', 'ptr', pBmp1, 'uint*', &w1)
    DllCall('gdiplus\GdipGetImageHeight', 'ptr', pBmp1, 'uint*', &h1)
    DllCall('gdiplus\GdipGetImageWidth', 'ptr', pBmp2, 'uint*', &w2)
    DllCall('gdiplus\GdipGetImageHeight', 'ptr', pBmp2, 'uint*', &h2)
    if w1 != w2 || h1 != h2
    {
        DllCall('gdiplus\GdipDisposeImage', 'ptr', pBmp1)
        DllCall('gdiplus\GdipDisposeImage', 'ptr', pBmp2)
        ShutdownGdiPlus(gdipToken)
        return 1.0
    }
    diffCount := 0
    loop h1 {
        y := A_Index - 1
        loop w1 {
            x := A_Index - 1
            c1 := 0
            c2 := 0
            DllCall('gdiplus\GdipBitmapGetPixel', 'ptr', pBmp1, 'int', x, 'int', y, 'uint*', &c1)
            DllCall('gdiplus\GdipBitmapGetPixel', 'ptr', pBmp2, 'int', x, 'int', y, 'uint*', &c2)
            r1 := (c1 >> 16) & 0xFF
            g1 := (c1 >> 8) & 0xFF
            b1 := c1 & 0xFF
            r2 := (c2 >> 16) & 0xFF
            g2 := (c2 >> 8) & 0xFF
            b2 := c2 & 0xFF
            if Abs(r1 - r2) > tolerance || Abs(g1 - g2) > tolerance || Abs(b1 - b2) > tolerance
                diffCount++
        }
    }
    DllCall('gdiplus\GdipDisposeImage', 'ptr', pBmp1)
    DllCall('gdiplus\GdipDisposeImage', 'ptr', pBmp2)
    ShutdownGdiPlus(gdipToken)
    return diffCount / (w1 * h1)
}

; Capture a window screenshot, retrying until it matches a reference
; image within the given diff threshold. This handles applications that
; render progressively (like gitk loading commits) by comparing each
; capture against what we expect rather than against the previous frame
; (which would falsely stabilize on two identical loading screens).
; Returns the actual diff ratio on success.
CaptureUntilMatchesReference(hwnd, thumbW, thumbH, outFile, referenceFile, maxDiff, timeout := 30000) {
    deadline := A_TickCount + timeout
    while A_TickCount < deadline
    {
        CaptureAndDownscaleWindow(hwnd, thumbW, thumbH, outFile)
        diffRatio := CompareImages(outFile, referenceFile, 10)
        if diffRatio <= maxDiff
            return diffRatio
        Sleep 2000
    }
    ExitWithError 'Window screenshot did not match reference within ' timeout 'ms (last diff=' diffRatio ')'
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
VerifyGitkLayout(label, thumbFile, timeout := 30000) {
    hwnd := WinWait('ahk_class TkTopLevel', , 15)
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
