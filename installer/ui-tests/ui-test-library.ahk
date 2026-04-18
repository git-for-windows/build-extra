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

; Launch Git Bash via the Start Menu, wait for a mintty window to appear,
; and return the window handle.
LaunchGitBashViaStartMenu() {
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
    if A_TickCount >= deadline
        ExitWithError 'Start Menu did not appear'
    Info 'Start Menu opened'

    SendInput('Git Bash')
    Sleep 500
    SendEvent('{Enter}')

    ; Wait for a new mintty window to appear.
    hwnd := 0
    deadline := A_TickCount + 10000
    while A_TickCount < deadline
    {
        for h in WinGetList(minttyClass)
        {
            if !existing.Has(h)
            {
                hwnd := h
                break 2
            }
        }
        Sleep 100
    }
    if !hwnd
        ExitWithError 'Git Bash (mintty) window did not appear after Start Menu launch'
    WinActivate('ahk_id ' hwnd)
    Info 'Git Bash launched, mintty hwnd: ' hwnd
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

; Capture a window screenshot that has stabilized (no longer changing).
; Takes successive thumbnails until two consecutive ones match, then
; compares against a reference image. Returns the diff ratio (0.0 = identical).
; Exits with error if the window never stabilizes within the timeout.
CaptureStableScreenshot(hwnd, thumbW, thumbH, outFile, timeout := 30000) {
    prev := outFile . '.prev.png'
    deadline := A_TickCount + timeout
    CaptureAndDownscaleWindow(hwnd, thumbW, thumbH, outFile)
    while A_TickCount < deadline
    {
        Sleep 1000
        if FileExist(prev)
            FileDelete prev
        FileMove outFile, prev
        CaptureAndDownscaleWindow(hwnd, thumbW, thumbH, outFile)
        if CompareImages(outFile, prev, 2) == 0.0
        {
            FileDelete prev
            return
        }
        ; Still changing; wait a bit longer before the next attempt.
        Sleep 2000
    }
    if FileExist(prev)
        FileDelete prev
    ExitWithError 'Window screenshot did not stabilize within ' timeout 'ms'
}
