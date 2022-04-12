[Code]

type
    HANDLE = LongInt;
    SECURITY_ATTRIBUTES = record
        nLength:DWORD;
        lpSecurityDescriptor:LongInt;
        bInheritHandle:BOOL;
    end;

function CreatePipe(var hReadPipe,hWritePipe:HANDLE;var lpPipeAttributes:SECURITY_ATTRIBUTES;nSize:DWORD):BOOL;
external 'CreatePipe@kernel32.dll stdcall';

const 
    HANDLE_FLAG_INHERIT=$00000001;

function SetHandleInformation(hObject:HANDLE;dwMask,dwFlags:DWORD):integer;
external 'SetHandleInformation@kernel32.dll stdcall';

type
    PROCESS_INFORMATION = record
        hProcess:HANDLE;
        hThread:HANDLE;
        dwProcessId:DWORD;
        dwThreadId:DWORD;
    end;
    LPSTR = LongInt;
    LPBYTE = LongInt;
    STARTUPINFO = record
        cb:DWORD;
        lpReserved:LPSTR;
        lpDesktop:LPSTR;
        lpTitle:LPSTR;
        dwX:DWORD;
        dwY:DWORD;
        dwXSize:DWORD;
        dwYSize:DWORD;
        dwXCountChars:DWORD;
        dwYCountChars:DWORD;
        dwFillAttribute:DWORD;
        dwFlags:DWORD;
        wShowWindow:WORD;
        cbReserved2:WORD;
        lpReserved2:LPBYTE;
        hStdInput:HANDLE;
        hStdOutput:HANDLE;
        hStdError:HANDLE;
    end;

const
    STARTF_USESTDHANDLES=$00000100;
    STARTF_USESHOWWINDOW=$00000001;
    NORMAL_PRIORITY_CLASS=$00000020;

function CreateProcess(lpApplicationName:LongInt;lpCommandLine:AnsiString;lpProcessAttributes,lpThreadAttributes:LongInt;bInheritHandles:LongInt;dwCreationFlags:DWORD;lpEnvironment,lpCurrentDirectory:LongInt;var lpStartupInfo:STARTUPINFO;var lpProcessInformation:PROCESS_INFORMATION):BOOL;
external 'CreateProcessA@kernel32.dll stdcall';

function ReadFile(hFile:HANDLE;lpBuffer:AnsiString;nNumberOfBytesToRead:DWORD;var lpNumberOfBytesRead:DWORD;lpOverlapped:LongInt):BOOL;
external 'ReadFile@kernel32.dll stdcall';

const
    WAIT_OBJECT_0=$00000000;

type
    TMsg = record
        hwnd:HWND;
        message:UINT;
        wParam:LongInt;
        lParam:LongInt;
        time:DWORD;
        pt:TPoint;
    end;

const
    PM_REMOVE=1;

function PeekMessage(var lpMsg:TMsg;hWnd:HWND;wMsgFilterMin,wMsgFilterMax,wRemoveMsg:UINT):BOOL;
external 'PeekMessageA@user32.dll stdcall';

function TranslateMessage(const lpMsg:TMsg):BOOL;
external 'TranslateMessage@user32.dll stdcall';

function DispatchMessage(const lpMsg:TMsg):LongInt;
external 'DispatchMessageA@user32.dll stdcall';

function PeekNamedPipe(hNamedPipe:HANDLE;lpBuffer:LongInt;nBufferSize:DWORD;lpBytesRead:LongInt;var lpTotalBytesAvail:DWORD;lpBytesLeftThisMessage:LongInt):BOOL;
external 'PeekNamedPipe@kernel32.dll stdcall';

const
    STILL_ACTIVE=$00000103;

function GetExitCodeProcess(hProcess:HANDLE;var lpExitCode:DWORD):BOOL;
external 'GetExitCodeProcess@kernel32.dll stdcall';

const
    ERROR_BROKEN_PIPE=109;

function GetLastError():DWORD;
external 'GetLastError@kernel32.dll stdcall';

function CaptureToString(var Handle:HANDLE;var Buffer:AnsiString;Length:DWORD;var Output:String):Boolean;
var
    Available:DWORD;
begin
    Result:=True;
    if (Handle=INVALID_HANDLE_VALUE) then
        Exit;

    if not PeekNamedPipe(Handle,0,0,0,Available,0) then begin
        if (GetLastError()<>ERROR_BROKEN_PIPE) then
            Result:=False;
        CloseHandle(Handle);
        Handle:=INVALID_HANDLE_VALUE;
        Exit;
    end;

    if (Available>0) then begin
        if not ReadFile(Handle,Buffer,Length,Length,0) then begin
            Result:=False;
            CloseHandle(Handle);
            Handle:=INVALID_HANDLE_VALUE;
            Exit;
        end;
        if (Length>0) then
            Output:=Output+Copy(Buffer,0,Length)
        else begin
            // EOF
            CloseHandle(Handle);
            Handle:=INVALID_HANDLE_VALUE;
        end;
    end;
end;

function ExecWithCapture(CommandLine:String;var StdOut,StdErr:String;var ExitCode:DWORD):Boolean;
var
    SecurityAttributes:SECURITY_ATTRIBUTES;
    StartupInfo:STARTUPINFO;
    ProcessInformation:PROCESS_INFORMATION;
    StdOutReadHandle,StdOutWriteHandle,StdErrReadHandle,StdErrWriteHandle:HANDLE;
    Buffer:AnsiString;
    BufferLength:DWORD;
    Msg:TMsg;
begin
    Result:=False;
    ExitCode:=-1;

    SecurityAttributes.nLength:=sizeof(SecurityAttributes);
    SecurityAttributes.bInheritHandle:=True;

    if not CreatePipe(StdOutReadHandle,StdOutWriteHandle,SecurityAttributes,0) then
        Exit;
    SetHandleInformation(StdOutReadHandle,HANDLE_FLAG_INHERIT,0);
    if not CreatePipe(StdErrReadHandle,StdErrWriteHandle,SecurityAttributes,0) then
        Exit;
    SetHandleInformation(StdErrReadHandle,HANDLE_FLAG_INHERIT,0);

    StartupInfo.cb:=sizeof(StartupInfo);
    StartupInfo.dwFlags:=STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    StartupInfo.wShowWindow:=SW_HIDE;
    StartupInfo.hStdOutput:=StdOutWriteHandle;
    StartupInfo.hStdError:=StdErrWriteHandle;

    if not CreateProcess(0,CommandLine,0,0,1,NORMAL_PRIORITY_CLASS,0,0,StartupInfo,ProcessInformation) then begin
        CloseHandle(StdOutReadHandle);
        CloseHandle(StdErrReadHandle);
        CloseHandle(StdOutWriteHandle);
        CloseHandle(StdErrWriteHandle);
        Exit;
    end;
    CloseHandle(ProcessInformation.hThread);

    // unblock read pipes
    CloseHandle(StdOutWriteHandle);
    CloseHandle(StdErrWriteHandle);

    BufferLength:=16384;
    Buffer:=StringOfChar('c',BufferLength);
    while (WaitForSingleObject(ProcessInformation.hProcess,50)=WAIT_TIMEOUT) do begin
        // pump messages
        if Assigned(WizardForm) then begin
            while PeekMessage(Msg,WizardForm.Handle,0,0,PM_REMOVE) do begin
                TranslateMessage(Msg);
                DispatchMessage(Msg);
            end;

            // allow the window to be rendered
            WizardForm.Refresh();
        end;

        // capture stdout/stderr (non-blocking)
        if not CaptureToString(StdOutReadHandle,Buffer,BufferLength,StdOut) then
            Exit;
        if not CaptureToString(StdErrReadHandle,Buffer,BufferLength,StdErr) then
            Exit;
    end;

    // drain stdout/stderr
    while (StdOutReadHandle<>INVALID_HANDLE_VALUE) do
        if not CaptureToString(StdOutReadHandle,Buffer,BufferLength,StdOut) then
            Exit;
    while (StdErrReadHandle<>INVALID_HANDLE_VALUE) do
        if not CaptureToString(StdErrReadHandle,Buffer,BufferLength,StdErr) then
            Exit;

    if (WaitForSingleObject(ProcessInformation.hProcess,50)=WAIT_OBJECT_0) then
        if GetExitCodeProcess(ProcessInformation.hProcess,ExitCode) then
            if (ExitCode<>STILL_ACTIVE) then
                Result:=True;

    CloseHandle(ProcessInformation.hProcess);
end;