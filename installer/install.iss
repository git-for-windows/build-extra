; Uncomment the line below to be able to compile the script from within the IDE.
;#define COMPILE_FROM_IDE

#include "config.iss"

#if !defined(APP_VERSION) || !defined(BITNESS)
#error "config.iss should define APP_VERSION and BITNESS"
#endif

#define APP_NAME      'Git'
#ifdef COMPILE_FROM_IDE
#undef APP_VERSION
#define APP_VERSION   'Snapshot'
#endif
#define MINGW_BITNESS 'mingw'+BITNESS
#define APP_CONTACT_URL 'https://github.com/git-for-windows/git/wiki/Contact'
#define APP_URL       'https://git-for-windows.github.io/'
#define APP_BUILTINS  'share\git\builtins.txt'
#define APP_BINDIMAGE 'share\git\bindimage.txt'

#define PLINK_PATH_ERROR_MSG 'Please enter a valid path to a Plink executable.'

#define DROP_HANDLER_GUID '{{60254CA5-953B-11CF-8C96-00AA00B8708C}'

[Setup]
; Compiler-related
Compression=lzma2/ultra64
LZMAUseSeparateProcess=yes
#ifdef OUTPUT_TO_TEMP
OutputBaseFilename={#FILENAME_VERSION}
OutputDir={#GetEnv('TEMP')}
#else
OutputBaseFilename={#APP_NAME+'-'+FILENAME_VERSION}-{#BITNESS}-bit
#ifdef OUTPUT_DIRECTORY
OutputDir={#OUTPUT_DIRECTORY}
#else
OutputDir={#GetEnv('USERPROFILE')}
#endif
#endif
SolidCompression=yes
SourceDir={#SourcePath}\..\..\..\..
#if BITNESS=='64'
ArchitecturesInstallIn64BitMode=x64
#endif
#ifdef SIGNTOOL
SignTool=signtool
#endif

; Installer-related
AllowNoIcons=yes
AppName={#APP_NAME}
AppPublisher=The Git Development Community
AppPublisherURL={#APP_URL}
AppSupportURL={#APP_CONTACT_URL}
AppVersion={#APP_VERSION}
ChangesAssociations=yes
ChangesEnvironment=yes
CloseApplications=no
DefaultDirName={pf}\{#APP_NAME}
DisableDirPage=auto
DefaultGroupName={#APP_NAME}
DisableProgramGroupPage=auto
DisableReadyPage=yes
InfoBeforeFile={#SourcePath}\..\gpl-2.0.rtf
#ifdef OUTPUT_TO_TEMP
PrivilegesRequired=lowest
#else
PrivilegesRequired=none
#endif
UninstallDisplayIcon={app}\{#MINGW_BITNESS}\share\git\git-for-windows.ico
#ifndef COMPILE_FROM_IDE
#if Pos('-',APP_VERSION)>0
VersionInfoVersion={#Copy(APP_VERSION,1,Pos('-',APP_VERSION)-1)}
#else
VersionInfoVersion={#APP_VERSION}
#endif
#endif

; Cosmetic
SetupIconFile={#SourcePath}\..\git.ico
WizardImageBackColor=clWhite
WizardImageStretch=no
WizardImageFile={#SourcePath}\git.bmp
WizardSmallImageFile={#SourcePath}\gitsmall.bmp
MinVersion=0,5.01sp3

[Types]
; Define a custom type to avoid getting the three default types.
Name: default; Description: Default installation; Flags: iscustom

[Components]
Name: icons; Description: Additional icons
Name: icons\quicklaunch; Description: In the Quick Launch; Check: not IsAdminLoggedOn
Name: icons\desktop; Description: On the Desktop
Name: ext; Description: Windows Explorer integration; Types: default
Name: ext\shellhere; Description: Git Bash Here; Types: default
Name: ext\guihere; Description: Git GUI Here; Types: default
Name: assoc; Description: Associate .git* configuration files with the default text editor; Types: default
Name: assoc_sh; Description: Associate .sh files to be run with Bash; Types: default
Name: consolefont; Description: Use a TrueType font in all console windows

[Run]
Filename: {app}\git-bash.exe; Parameters: --cd-to-home; Description: Launch Git Bash; Flags: nowait postinstall skipifsilent runasoriginaluser unchecked
Filename: {app}\ReleaseNotes.html; Description: View Release Notes; Flags: shellexec skipifdoesntexist postinstall skipifsilent

[Files]
; Install files that might be in use during setup under a different name.
#include "file-list.iss"
Source: {#SourcePath}\ReleaseNotes.html; DestDir: {app}; Flags: replacesameversion; AfterInstall: DeleteFromVirtualStore
Source: {#SourcePath}\..\LICENSE.txt; DestDir: {app}; Flags: replacesameversion; AfterInstall: DeleteFromVirtualStore
Source: {#SourcePath}\NOTICE.txt; DestDir: {app}; Flags: replacesameversion; AfterInstall: DeleteFromVirtualStore; Check: ParamIsSet('VSNOTICE')
Source: {#SourcePath}\..\edit-git-bash.exe; Flags: dontcopy

[Dirs]
Name: "{app}\tmp"

[Icons]
Name: {group}\Git GUI; Filename: {app}\cmd\git-gui.exe; Parameters: ""; WorkingDir: %HOMEDRIVE%%HOMEPATH%; IconFilename: {app}\{#MINGW_BITNESS}\share\git\git-for-windows.ico
Name: {group}\Git Bash; Filename: {app}\git-bash.exe; Parameters: "--cd-to-home"; WorkingDir: %HOMEDRIVE%%HOMEPATH%; IconFilename: {app}\{#MINGW_BITNESS}\share\git\git-for-windows.ico
Name: {group}\Git CMD; Filename: {app}\git-cmd.exe; Parameters: "--cd-to-home"; WorkingDir: %HOMEDRIVE%%HOMEPATH%; IconFilename: {app}\{#MINGW_BITNESS}\share\git\git-for-windows.ico

[Messages]
BeveledLabel={#APP_URL}
#ifdef WINDOW_TITLE_VERSION
SetupAppTitle={#APP_NAME} {#WINDOW_TITLE_VERSION} Setup
SetupWindowTitle={#APP_NAME} {#WINDOW_TITLE_VERSION} Setup
#else
SetupAppTitle={#APP_NAME} {#APP_VERSION} Setup
SetupWindowTitle={#APP_NAME} {#APP_VERSION} Setup
#endif

[Registry]
; Aides installing third-party (credential, remote, etc) helpers
Root: HKLM; Subkey: Software\GitForWindows; ValueType: string; ValueName: CurrentVersion; ValueData: {#APP_VERSION}; Flags: uninsdeletevalue uninsdeletekeyifempty; Check: IsAdminLoggedOn
Root: HKLM; Subkey: Software\GitForWindows; ValueType: string; ValueName: InstallPath; ValueData: {app}; Flags: uninsdeletevalue uninsdeletekeyifempty; Check: IsAdminLoggedOn
Root: HKLM; Subkey: Software\GitForWindows; ValueType: string; ValueName: LibexecPath; ValueData: {app}\{#MINGW_BITNESS}\libexec\git-core; Flags: uninsdeletevalue uninsdeletekeyifempty; Check: IsAdminLoggedOn
Root: HKCU; Subkey: Software\GitForWindows; ValueType: string; ValueName: CurrentVersion; ValueData: {#APP_VERSION}; Flags: uninsdeletevalue uninsdeletekeyifempty; Check: not IsAdminLoggedOn
Root: HKCU; Subkey: Software\GitForWindows; ValueType: string; ValueName: InstallPath; ValueData: {app}; Flags: uninsdeletevalue uninsdeletekeyifempty; Check: not IsAdminLoggedOn
Root: HKCU; Subkey: Software\GitForWindows; ValueType: string; ValueName: LibexecPath; ValueData: {app}\{#MINGW_BITNESS}\libexec\git-core; Flags: uninsdeletevalue uninsdeletekeyifempty; Check: not IsAdminLoggedOn

; There is no "Console" key in HKLM.
Root: HKCU; Subkey: Console; ValueType: string; ValueName: FaceName; ValueData: Lucida Console; Flags: uninsclearvalue; Components: consolefont
Root: HKCU; Subkey: Console; ValueType: dword; ValueName: FontFamily; ValueData: $00000036; Components: consolefont
Root: HKCU; Subkey: Console; ValueType: dword; ValueName: FontSize; ValueData: $000e0000; Components: consolefont
Root: HKCU; Subkey: Console; ValueType: dword; ValueName: FontWeight; ValueData: $00000190; Components: consolefont

Root: HKCU; Subkey: Console\Git Bash; ValueType: string; ValueName: FaceName; ValueData: Lucida Console; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty
Root: HKCU; Subkey: Console\Git Bash; ValueType: dword; ValueName: FontFamily; ValueData: $00000036; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty
Root: HKCU; Subkey: Console\Git Bash; ValueType: dword; ValueName: FontSize; ValueData: $000e0000; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty
Root: HKCU; Subkey: Console\Git Bash; ValueType: dword; ValueName: FontWeight; ValueData: $00000190; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty

Root: HKCU; Subkey: Console\Git CMD; ValueType: string; ValueName: FaceName; ValueData: Lucida Console; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty
Root: HKCU; Subkey: Console\Git CMD; ValueType: dword; ValueName: FontFamily; ValueData: $00000036; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty
Root: HKCU; Subkey: Console\Git CMD; ValueType: dword; ValueName: FontSize; ValueData: $000e0000; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty
Root: HKCU; Subkey: Console\Git CMD; ValueType: dword; ValueName: FontWeight; ValueData: $00000190; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty

; Note that we write the Registry values below either to HKLM or to HKCU depending on whether the user running the installer
; is a member of the local Administrators group or not (see the "Check" argument).

; File associations for configuration files that may be contained in a repository (so this does not include ".gitconfig").
Root: HKLM; Subkey: Software\Classes\.gitattributes; ValueType: string; ValueData: txtfile; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty; Check: IsAdminLoggedOn; Components: assoc
Root: HKLM; Subkey: Software\Classes\.gitattributes; ValueType: string; ValueName: Content Type; ValueData: text/plain; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty; Check: IsAdminLoggedOn; Components: assoc
Root: HKLM; Subkey: Software\Classes\.gitattributes; ValueType: string; ValueName: PerceivedType; ValueData: text; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty; Check: IsAdminLoggedOn; Components: assoc
Root: HKCU; Subkey: Software\Classes\.gitattributes; ValueType: string; ValueData: txtfile; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty; Check: not IsAdminLoggedOn; Components: assoc
Root: HKCU; Subkey: Software\Classes\.gitattributes; ValueType: string; ValueName: Content Type; ValueData: text/plain; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty; Check: not IsAdminLoggedOn; Components: assoc
Root: HKCU; Subkey: Software\Classes\.gitattributes; ValueType: string; ValueName: PerceivedType; ValueData: text; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty; Check: not IsAdminLoggedOn; Components: assoc

Root: HKLM; Subkey: Software\Classes\.gitignore; ValueType: string; ValueData: txtfile; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty; Check: IsAdminLoggedOn; Components: assoc
Root: HKLM; Subkey: Software\Classes\.gitignore; ValueType: string; ValueName: Content Type; ValueData: text/plain; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty; Check: IsAdminLoggedOn; Components: assoc
Root: HKLM; Subkey: Software\Classes\.gitignore; ValueType: string; ValueName: PerceivedType; ValueData: text; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty; Check: IsAdminLoggedOn; Components: assoc
Root: HKCU; Subkey: Software\Classes\.gitignore; ValueType: string; ValueData: txtfile; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty; Check: not IsAdminLoggedOn; Components: assoc
Root: HKCU; Subkey: Software\Classes\.gitignore; ValueType: string; ValueName: Content Type; ValueData: text/plain; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty; Check: not IsAdminLoggedOn; Components: assoc
Root: HKCU; Subkey: Software\Classes\.gitignore; ValueType: string; ValueName: PerceivedType; ValueData: text; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty; Check: not IsAdminLoggedOn; Components: assoc

Root: HKLM; Subkey: Software\Classes\.gitmodules; ValueType: string; ValueData: txtfile; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty; Check: IsAdminLoggedOn; Components: assoc
Root: HKLM; Subkey: Software\Classes\.gitmodules; ValueType: string; ValueName: Content Type; ValueData: text/plain; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty; Check: IsAdminLoggedOn; Components: assoc
Root: HKLM; Subkey: Software\Classes\.gitmodules; ValueType: string; ValueName: PerceivedType; ValueData: text; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty; Check: IsAdminLoggedOn; Components: assoc
Root: HKCU; Subkey: Software\Classes\.gitmodules; ValueType: string; ValueData: txtfile; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty; Check: not IsAdminLoggedOn; Components: assoc
Root: HKCU; Subkey: Software\Classes\.gitmodules; ValueType: string; ValueName: Content Type; ValueData: text/plain; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty; Check: not IsAdminLoggedOn; Components: assoc
Root: HKCU; Subkey: Software\Classes\.gitmodules; ValueType: string; ValueName: PerceivedType; ValueData: text; Flags: createvalueifdoesntexist uninsdeletevalue uninsdeletekeyifempty; Check: not IsAdminLoggedOn; Components: assoc

; Associate .sh extension with sh.exe so those files are double-clickable,
; startable from cmd.exe, and when files are dropped on them they are passed
; as arguments to the script.

; Install under HKEY_LOCAL_MACHINE if an administrator is installing.
Root: HKLM; Subkey: Software\Classes\.sh; ValueType: string; ValueData: sh_auto_file; Flags: createvalueifdoesntexist uninsdeletekeyifempty uninsdeletevalue; Check: IsAdminLoggedOn; Components: assoc_sh
Root: HKLM; Subkey: Software\Classes\sh_auto_file; ValueType: string; ValueData: "Shell Script"; Flags: createvalueifdoesntexist uninsdeletekeyifempty uninsdeletevalue; Check: IsAdminLoggedOn; Components: assoc_sh
Root: HKLM; Subkey: Software\Classes\sh_auto_file\shell\open\command; ValueType: string; ValueData: """{app}\git-bash.exe"" --no-cd ""%L"" %*"; Flags: uninsdeletekeyifempty uninsdeletevalue; Check: IsAdminLoggedOn; Components: assoc_sh
Root: HKLM; Subkey: Software\Classes\sh_auto_file\DefaultIcon; ValueType: string; ValueData: "%SystemRoot%\System32\shell32.dll,-153"; Flags: createvalueifdoesntexist uninsdeletekeyifempty uninsdeletevalue; Check: IsAdminLoggedOn; Components: assoc_sh
Root: HKLM; Subkey: Software\Classes\sh_auto_file\ShellEx\DropHandler; ValueType: string; ValueData: {#DROP_HANDLER_GUID}; Flags: uninsdeletekeyifempty uninsdeletevalue; Check: IsAdminLoggedOn; Components: assoc_sh

; Install under HKEY_CURRENT_USER if a non-administrator is installing.
Root: HKCU; Subkey: Software\Classes\.sh; ValueType: string; ValueData: sh_auto_file; Flags: createvalueifdoesntexist uninsdeletekeyifempty uninsdeletevalue; Check: not IsAdminLoggedOn; Components: assoc_sh
Root: HKCU; Subkey: Software\Classes\sh_auto_file; ValueType: string; ValueData: "Shell Script"; Flags: createvalueifdoesntexist uninsdeletekeyifempty uninsdeletevalue; Check: not IsAdminLoggedOn; Components: assoc_sh
Root: HKCU; Subkey: Software\Classes\sh_auto_file\shell\open\command; ValueType: string; ValueData: """{app}\git-bash.exe"" --no-cd ""%L"" %*"; Flags: uninsdeletekeyifempty uninsdeletevalue; Check: not IsAdminLoggedOn; Components: assoc_sh
Root: HKCU; Subkey: Software\Classes\sh_auto_file\DefaultIcon; ValueType: string; ValueData: "%SystemRoot%\System32\shell32.dll,-153"; Flags: createvalueifdoesntexist uninsdeletekeyifempty uninsdeletevalue; Check: not IsAdminLoggedOn; Components: assoc_sh
Root: HKCU; Subkey: Software\Classes\sh_auto_file\ShellEx\DropHandler; ValueType: string; ValueData: {#DROP_HANDLER_GUID}; Flags: uninsdeletekeyifempty uninsdeletevalue; Check: not IsAdminLoggedOn; Components: assoc_sh

[UninstallDelete]
; Delete the built-ins.
Type: files; Name: {app}\{#MINGW_BITNESS}\bin\git-*.exe
Type: files; Name: {app}\{#MINGW_BITNESS}\libexec\git-core\git-*.exe
Type: files; Name: {app}\{#MINGW_BITNESS}\libexec\git-core\git.exe

; Delete copied *.dll files
Type: files; Name: {app}\{#MINGW_BITNESS}\libexec\git-core\*.dll

; Delete the dynamical generated MSYS2 files
Type: files; Name: {app}\etc\hosts
Type: files; Name: {app}\etc\mtab
Type: files; Name: {app}\etc\networks
Type: files; Name: {app}\etc\protocols
Type: files; Name: {app}\etc\services
Type: files; Name: {app}\dev\fd
Type: files; Name: {app}\dev\stderr
Type: files; Name: {app}\dev\stdin
Type: files; Name: {app}\dev\stdout
Type: dirifempty; Name: {app}\dev\mqueue
Type: dirifempty; Name: {app}\dev\shm
Type: dirifempty; Name: {app}\dev

; Delete any manually created shortcuts.
Type: files; Name: {userappdata}\Microsoft\Internet Explorer\Quick Launch\Git Bash.lnk
Type: files; Name: {code:GetShellFolder|desktop}\Git Bash.lnk
Type: files; Name: {app}\Git Bash.lnk

; Delete a home directory inside the Git for Windows directory.
Type: dirifempty; Name: {app}\home\{username}
Type: dirifempty; Name: {app}\home

#if BITNESS=='32'
; Delete the files required for rebaseall
Type: files; Name: {app}\bin\msys-2.0.dll
Type: files; Name: {app}\bin\rebase.exe
Type: dirifempty; Name: {app}\bin
Type: files; Name: {app}\etc\rebase.db.i386
Type: dirifempty; Name: {app}\etc
#endif

; Delete recorded install options
Type: files; Name: {app}\etc\install-options.txt
Type: dirifempty; Name: {app}\etc
Type: dirifempty; Name: {app}\{#MINGW_BITNESS}\libexec\git-core
Type: dirifempty; Name: {app}\{#MINGW_BITNESS}\libexec
Type: dirifempty; Name: {app}\{#MINGW_BITNESS}
Type: dirifempty; Name: {app}

[Code]
#include "helpers.inc.iss"
#include "environment.inc.iss"
#include "putty.inc.iss"
#include "modules.inc.iss"

procedure LogError(Msg:String);
begin
    SuppressibleMsgBox(Msg,mbError,MB_OK,IDOK);
    Log(Msg);
end;

function ParamIsSet(Key:String):Boolean;
begin
    Result:=CompareStr('0',ExpandConstant('{param:'+Key+'|0}'))<>0;
end;

function CreateHardLink(lpFileName,lpExistingFileName:String;lpSecurityAttributes:Integer):Boolean;
#ifdef UNICODE
external 'CreateHardLinkW@Kernel32.dll stdcall delayload setuponly';
#else
external 'CreateHardLinkA@Kernel32.dll stdcall delayload setuponly';
#endif

function OverrideGitBashCommandLine(GitBashPath:String;CommandLine:String):Integer;
var
    Msg:String;
begin
    if not FileExists(ExpandConstant('{tmp}\edit-git-bash.exe')) then
        ExtractTemporaryFile('edit-git-bash.exe');
    StringChangeEx(GitBashPath,'"','\"',True);
    StringChangeEx(CommandLine,'"','\"',True);
    CommandLine:='"'+GitBashPath+'" "'+CommandLine+'"';
    Exec(ExpandConstant('{tmp}\edit-git-bash.exe'),CommandLine,'',SW_HIDE,ewWaitUntilTerminated,Result);
    if Result<>0 then begin
        if Result=1 then begin
            Msg:='Unable to edit '+GitBashPath+' (out of memory).';
        end else if Result=2 then begin
            Msg:='Unable to open '+GitBashPath+' for editing.';
        end else if Result=3 then begin
            Msg:='Unable to edit the command-line of '+GitBashPath+'.';
        end else if Result=4 then begin
            Msg:='Unable to close '+GitBashPath+' after editing.';
        end;
        LogError(Msg);
    end;
end;

function BindImageEx(Flags:DWORD;ImageName,DllPath,SymbolPath:AnsiString;StatusRoutine:Integer):Boolean;
external 'BindImageEx@Imagehlp.dll stdcall delayload setuponly';

const
    // Git Path options.
    GP_BashOnly       = 1;
    GP_Cmd            = 2;
    GP_CmdTools       = 3;

    // Git SSH options.
    GS_OpenSSH        = 1;
    GS_Plink          = 2;

    // Git HTTPS (cURL) options.
    GC_OpenSSL        = 1;
    GC_WinSSL         = 2;

    // Git line ending conversion options.
    GC_LFOnly         = 1;
    GC_CRLFAlways     = 2;
    GC_CRLFCommitAsIs = 3;

    // Git Bash terminal settings.
    GB_MinTTY         = 1;
    GB_ConHost        = 2;

    // Extra options
    GP_FSCache        = 1;
    GP_GCM            = 2;
    GP_Symlinks       = 3;

#ifdef WITH_EXPERIMENTAL_BUILTIN_DIFFTOOL
    // Experimental options
    GP_BuiltinDifftool = 1;
#endif

    // BindImageEx API constants.
    BIND_NO_BOUND_IMPORTS  = $00000001;
    BIND_NO_UPDATE         = $00000002;
    BIND_ALL_IMAGES        = $00000004;
    BIND_CACHE_IMPORT_DLLS = $00000008;

var
    // The options chosen at install time, to be written to /etc/install-options.txt
    ChosenOptions:String;

    // Wizard page and variables for the Path options.
    PathPage:TWizardPage;
    RdbPath:array[GP_BashOnly..GP_CmdTools] of TRadioButton;

    // Wizard page and variables for the SSH options.
    PuTTYPage:TWizardPage;
    RdbSSH:array[GS_OpenSSH..GS_Plink] of TRadioButton;
    EdtPlink:TEdit;

    // Wizard page and variables for the HTTPS implementation (cURL) settings.
    CurlVariantPage:TWizardPage;
    RdbCurlVariant:array[GC_OpenSSL..GC_WinSSL] of TRadioButton;

    // Wizard page and variables for the line ending conversion options.
    CRLFPage:TWizardPage;
    RdbCRLF:array[GC_LFOnly..GC_CRLFCommitAsIs] of TRadioButton;

    // Wizard page and variables for the terminal emulator settings.
    BashTerminalPage:TWizardPage;
    RdbBashTerminal:array[GB_MinTTY..GB_ConHost] of TRadioButton;

    // Wizard page and variables for the extra options.
    ExtraOptionsPage:TWizardPage;
    RdbExtraOptions:array[GP_FSCache..GP_Symlinks] of TCheckBox;

#ifdef WITH_EXPERIMENTAL_BUILTIN_DIFFTOOL
    // Wizard page and variables for the experimental options.
    ExperimentalOptionsPage:TWizardPage;
    RdbExperimentalOptions:array[GP_BuiltinDifftool..GP_BuiltinDifftool] of TCheckBox;
#endif

    // Wizard page and variables for the processes page.
    SessionHandle:DWORD;
    Processes:ProcessList;
    ProcessesPage:TWizardPage;
    ProcessesListBox:TListBox;
    ProcessesRefresh,ContinueButton:TButton;
    PageIDBeforeInstall:Integer;
#ifdef DEBUG_WIZARD_PAGE
    DebugWizardPage:Integer;
#endif

{
    Specific helper functions
}

procedure BrowseForPuTTYFolder(Sender:TObject);
var
    Name:String;
begin
    if GetOpenFileName(
        'Please select a Plink executable'
    ,   Name
    ,   ExtractFilePath(EdtPlink.Text)
    ,   'Executable Files|*.exe'
    ,   'exe'
    )
    then begin
        if IsPlinkExecutable(Name) then begin
            EdtPlink.Text:=Name;
            RdbSSH[GS_Plink].Checked:=True;
        end else begin
            // This message box only gets triggered on interactive use, so it
            // does not need to be suppressible for silent installations.
            MsgBox('{#PLINK_PATH_ERROR_MSG}',mbError,MB_OK);
        end;
    end;
end;

procedure DeleteContextMenuEntries;
var
    AppDir,Command:String;
    RootKey,i:Integer;
    Keys:TArrayOfString;
begin
    AppDir:=ExpandConstant('{app}');

    if IsAdminLoggedOn then begin
        RootKey:=HKEY_LOCAL_MACHINE;
    end else begin
        RootKey:=HKEY_CURRENT_USER;
    end;

    SetArrayLength(Keys,4);
    Keys[0]:='SOFTWARE\Classes\Directory\shell\git_shell';
    Keys[1]:='SOFTWARE\Classes\Directory\Background\shell\git_shell';
    Keys[2]:='SOFTWARE\Classes\Directory\shell\git_gui';
    Keys[3]:='SOFTWARE\Classes\Directory\Background\shell\git_gui';

    for i:=0 to Length(Keys)-1 do begin
        Command:='';
        RegQueryStringValue(RootKey,Keys[i]+'\command','',Command);
        if Pos(AppDir,Command)>0 then begin
            if not RegDeleteKeyIncludingSubkeys(RootKey,Keys[i]) then begin
                LogError('Line {#__LINE__}: Unable to remove "Git Bash / GUI Here" shell extension.');
            end;
        end;
    end;
end;

procedure RefreshProcessList(Sender:TObject);
var
    Version:TWindowsVersion;
    Modules:TArrayOfString;
    ProcsCloseRequired,ProcsCloseOptional:ProcessList;
    i:Longint;
    Caption:String;
    ManualClosingRequired:Boolean;
begin
    GetWindowsVersionEx(Version);

    // Use the Restart Manager API when installing the shell extension on Windows Vista and above.
    if Version.Major>=6 then begin
        SetArrayLength(Modules,7);
        Modules[0]:=ExpandConstant('{app}\usr\bin\msys-2.0.dll');
        Modules[1]:=ExpandConstant('{app}\{#MINGW_BITNESS}\bin\tcl85.dll');
        Modules[2]:=ExpandConstant('{app}\{#MINGW_BITNESS}\bin\tk85.dll');
        Modules[3]:=ExpandConstant('{app}\{#MINGW_BITNESS}\bin\tcl86.dll');
        Modules[4]:=ExpandConstant('{app}\{#MINGW_BITNESS}\bin\tk86.dll');
        Modules[5]:=ExpandConstant('{app}\git-cheetah\git_shell_ext.dll');
        Modules[6]:=ExpandConstant('{app}\git-cheetah\git_shell_ext64.dll');
        SessionHandle:=FindProcessesUsingModules(Modules,Processes);
    end else begin
        SetArrayLength(Modules,5);
        Modules[0]:=ExpandConstant('{app}\usr\bin\msys-2.0.dll');
        Modules[1]:=ExpandConstant('{app}\{#MINGW_BITNESS}\bin\tcl85.dll');
        Modules[2]:=ExpandConstant('{app}\{#MINGW_BITNESS}\bin\tk85.dll');
        Modules[3]:=ExpandConstant('{app}\{#MINGW_BITNESS}\bin\tcl86.dll');
        Modules[4]:=ExpandConstant('{app}\{#MINGW_BITNESS}\bin\tk86.dll');
        SessionHandle:=FindProcessesUsingModules(Modules,ProcsCloseRequired);

        SetArrayLength(Modules,2);
        Modules[0]:=ExpandConstant('{app}\git-cheetah\git_shell_ext.dll');
        Modules[1]:=ExpandConstant('{app}\git-cheetah\git_shell_ext64.dll');
        SessionHandle:=FindProcessesUsingModules(Modules,ProcsCloseOptional) or SessionHandle;

        // Misuse the "Restartable" flag to indicate which processes are required
        // to be closed before setup can continue, and which just should be closed
        // in order to make changes take effect immediately.
        SetArrayLength(Processes,GetArrayLength(ProcsCloseRequired)+GetArrayLength(ProcsCloseOptional));
        for i:=0 to GetArrayLength(ProcsCloseRequired)-1 do begin
            Processes[i]:=ProcsCloseRequired[i];
            Processes[i].Restartable:=False;
        end;
        for i:=0 to GetArrayLength(ProcsCloseOptional)-1 do begin
            Processes[GetArrayLength(ProcsCloseRequired)+i]:=ProcsCloseOptional[i];
            Processes[GetArrayLength(ProcsCloseRequired)+i].Restartable:=True;
        end;
    end;

    ManualClosingRequired:=False;

    ProcessesListBox.Items.Clear;
    if (Sender=NIL) or (SessionHandle>0) then begin
        for i:=0 to GetArrayLength(Processes)-1 do begin
            Caption:=Processes[i].Name+' (PID '+IntToStr(Processes[i].ID);
            if Processes[i].Restartable then begin
                Caption:=Caption+', closing is optional';
            end else if Processes[i].ToTerminate then begin
                Caption:=Caption+', will be terminated';
            end else begin
                Caption:=Caption+', closing is required';
                ManualClosingRequired:=True;
            end;
            Caption:=Caption+')';
            ProcessesListBox.Items.Append(Caption);
        end;
    end;

    if ContinueButton<>NIL then begin
        ContinueButton.Enabled:=not ManualClosingRequired;
    end;
end;

procedure SetAndMarkEnvString(Name,Value:String;Expandable:Boolean);
var
    Env:TArrayOfString;
    FileName:String;
begin
    SetArrayLength(Env,1);
    Env[0]:=Value;

    // Try to set the variable as specified by the user.
    if not SetEnvStrings(Name,Env,Expandable,IsAdminLoggedOn,True) then
        LogError('Line {#__LINE__}: Unable to set the '+Name+' environment variable.')
    else begin
        // Mark that we have changed the variable by writing its value to a file.
        FileName:=ExpandConstant('{app}')+'\setup.ini';
        if not SetIniString('Environment',Name,Value,FileName) then
            LogError('Line {#__LINE__}: Unable to write to file "'+FileName+'".');
    end;
end;

procedure DeleteMarkedEnvString(Name:String);
var
   Env:TArrayOfString;
   FileName:String;
begin
    Env:=GetEnvStrings(Name,IsAdminLoggedOn);
    FileName:=ExpandConstant('{app}')+'\setup.ini';

    if (GetArrayLength(Env)=1) and
       (CompareStr(RemoveQuotes(Env[0]),GetIniString('Environment',Name,'',FileName))=0) then begin
        if not SetEnvStrings(Name,[],False,IsAdminLoggedOn,True) then
            LogError('Line {#__LINE__}: Unable to delete the '+Name+' environment variable.');
    end;
end;

{
    Setup event functions
}

function NextNumber(Str:String;var Pos:Integer):Integer;
var
    From:Integer;
begin
    From:=Pos;
    while (Pos<=Length(Str)) and (Str[Pos]>=#48) and (Str[Pos]<=#57) do
        Pos:=Pos+1;
    if Pos>From then
        Result:=StrToInt(Copy(Str,From,Pos-From))
    else
        Result:=-1;
end;

function IsDowngrade(CurrentVersion,PreviousVersion:String):Boolean;
var
    i,j,Current,Previous:Integer;
begin
    Result:=False;
    i:=1;
    j:=1;
    while True do begin
        if j>Length(PreviousVersion) then
            Exit;
        if i>Length(CurrentVersion) then begin
            Result:=True;
            Exit;
        end;
        Previous:=NextNumber(PreviousVersion,j);
        if Previous<0 then
            Exit;
        Current:=NextNumber(CurrentVersion,i);
        if Current<0 then begin
            Result:=True;
            Exit;
        end;
        if Current>Previous then
            Exit;
        if Current<Previous then begin
            Result:=True;
            Exit;
        end;
        if j>Length(PreviousVersion) then
            Exit;
        if i>Length(CurrentVersion) then begin
            Result:=True;
            Exit;
        end;
        if CurrentVersion[i]<>PreviousVersion[j] then begin
            Result:=PreviousVersion[j]='.';
            Exit;
        end;
        if CurrentVersion[i]<>'.' then
            Exit;
        i:=i+1;
        j:=j+1;
    end;
end;

procedure ExitProcess(uExitCode:Integer);
external 'ExitProcess@kernel32.dll stdcall';

procedure ExitEarlyWithSuccess();
begin
    DelTree(ExpandConstant('{tmp}'),True,True,True);
    ExitProcess(0);
end;

function InitializeSetup:Boolean;
var
    CurrentVersion,PreviousVersion,Msg:String;
    Version:TWindowsVersion;
    ErrorCode:Integer;
begin
    GetWindowsVersionEx(Version);
    if (Version.Major<6) then begin
        if SuppressibleMsgBox('Git for Windows requires Windows Vista or later.'+#13+'Click "Yes" for more details.',mbError,MB_YESNO,IDNO)=IDYES then
	    ShellExec('open','https://git-for-windows.github.io/requirements.html','','',SW_SHOW,ewNoWait,ErrorCode);
	Result:=False;
	Exit;
    end;
    UpdateInfFilenames;
#if BITNESS=='32'
    Result:=True;
#else
    if not IsWin64 then begin
        LogError('The 64-bit version of Git requires a 64-bit Windows. Aborting.');
        Result:=False;
    end else begin
        Result:=True;
    end;
#endif
#if APP_VERSION!='0-test'
    if Result and not ParamIsSet('ALLOWDOWNGRADE') and RegQueryStringValue(HKEY_LOCAL_MACHINE,'Software\GitForWindows','CurrentVersion',PreviousVersion) then begin
        CurrentVersion:=ExpandConstant('{#APP_VERSION}');
        if (IsDowngrade(CurrentVersion,PreviousVersion)) then begin
            if WizardSilent() and (ParamIsSet('SKIPDOWNGRADE') or ParamIsSet('VSNOTICE')) then begin
                Msg:='Skipping downgrade from '+PreviousVersion+' to '+CurrentVersion;
                if ParamIsSet('SKIPDOWNGRADE') or (ExpandConstant('{log}')='') then
                    LogError(Msg)
                else
                    Log(Msg);
                ExitEarlyWithSuccess();
            end;
            if SuppressibleMsgBox('Git for Windows '+PreviousVersion+' is currently installed.'+#13+'Do you really want to downgrade to Git for Windows '+CurrentVersion+'?',mbConfirmation,MB_YESNO or MB_DEFBUTTON2,IDNO)=IDNO then
                Result:=False;
        end;
    end;
#endif
end;

procedure RecordChoice(PreviousDataKey:Integer;Key,Data:String);
begin
    ChosenOptions:=ChosenOptions+Key+': '+Data+#13#10;
    SetPreviousData(PreviousDataKey,Key,Data);
    if ShouldSaveInf then begin
        // .inf files do not like keys with spaces.
        StringChangeEx(Key,' ','',True);
        SaveInfString('Setup',Key,Data);
    end;
end;

function ReplayChoice(Key,Default:String):String;
var
    NoSpaces:String;
begin
    NoSpaces:=Key;
    StringChangeEx(NoSpaces,' ','',True);

    // Interpret /o:PathOption=Cmd and friends
    Result:=ExpandConstant('{param:o:'+NoSpaces+'| }');
    if Result<>' ' then
        Log('Parameter '+Key+'='+Result+' set via command-line')
    else if ShouldLoadInf then
        // Use settings from the user provided INF.
        // .inf files do not like keys with spaces.
        Result:=LoadInfString('Setup',NoSpaces,Default)
    else
        // Restore the settings chosen during a previous install.
        Result:=GetPreviousData(Key,Default);
end;

function ReadFileAsString(Path:String):String;
var
    Contents:AnsiString;
begin
    if not LoadStringFromFile(Path,Contents) then
        Result:='(no output)'
    else
        Result:=Contents;
end;

function DetectNetFxVersion:Cardinal;
begin
    // We are only interested in version v4.5.1 or later, therefore it
    // is enough to only use the 4.5 method described in
    // https://msdn.microsoft.com/en-us/library/hh925568
    if not RegQueryDWordValue(HKEY_LOCAL_MACHINE,'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full','Release',Result) then
        Result:=0;
end;

procedure OpenGCMHomepage(Sender:TObject);
var
  ExitStatus:Integer;
begin
  ShellExec('','https://github.com/Microsoft/Git-Credential-Manager-for-Windows','','',SW_SHOW,ewNoWait,ExitStatus);
end;

procedure OpenSymlinksWikiPage(Sender:TObject);
var
  ExitStatus:Integer;
begin
  ShellExec('','https://github.com/git-for-windows/git/wiki/Symbolic-Links','','',SW_SHOW,ewNoWait,ExitStatus);
end;

function EnableSymlinksByDefault():Boolean;
var
    ResultCode:Integer;
    Output:AnsiString;
begin
    if IsAdminLoggedOn then begin
        // The only way to tell whether non-admin users can create symbolic
	// links is to try using a non-admin user.
        Result:=False;
	Exit;
    end;

    ExecAsOriginalUser(ExpandConstant('{cmd}'),ExpandConstant('/c mklink /d "{tmp}\symbolic link" "{tmp}" >"{tmp}\symlink test.txt"'),'',SW_HIDE,ewWaitUntilTerminated,ResultCode);
    Result:=DirExists(ExpandConstant('{tmp}\symbolic link'));
end;

function GetTextWidth(Text:String;Font:TFont):Integer;
var
    DummyBitmap:TBitmap;
begin
    DummyBitmap:=TBitmap.Create();
    DummyBitmap.Canvas.Font.Assign(Font);
    Result:=DummyBitmap.Canvas.TextWidth(Text);
    DummyBitmap.Free();
end;

procedure InitializeWizard;
var
    PrevPageID:Integer;
    LblGitBash,LblGitCmd,LblGitCmdTools,LblGitCmdToolsWarn:TLabel;
    LblOpenSSH,LblPlink:TLabel;
    LblCurlOpenSSL,LblCurlWinSSL:TLabel;
    PuTTYSessions,EnvSSH:TArrayOfString;
    LblLFOnly,LblCRLFAlways,LblCRLFCommitAsIs:TLabel;
    LblMinTTY,LblConHost:TLabel;
    LblFSCache,LblGCM,LblGCMLink,LblSymlinks,LblSymlinksLink:TLabel;
#ifdef WITH_EXPERIMENTAL_BUILTIN_DIFFTOOL
    LblBuiltinDifftool:TLabel;
#endif
    BtnPlink:TButton;
    Data:String;
begin

    ChosenOptions:='';

    PrevPageID:=wpSelectProgramGroup;

    (*
     * Create a custom page for modifying the environment.
     *)

    PathPage:=CreateCustomPage(
        PrevPageID
    ,   'Adjusting your PATH environment'
    ,   'How would you like to use Git from the command line?'
    );
    PrevPageID:=PathPage.ID;

    // 1st choice
    RdbPath[GP_BashOnly]:=TRadioButton.Create(PathPage);
    with RdbPath[GP_BashOnly] do begin
        Parent:=PathPage.Surface;
        Caption:='Use Git from Git Bash only';
        Left:=ScaleX(4);
        Top:=ScaleY(8);
        Width:=ScaleX(405);
        Height:=ScaleY(17);
        Font.Style:=[fsBold];
        TabOrder:=0;
    end;
    LblGitBash:=TLabel.Create(PathPage);
    with LblGitBash do begin
        Parent:=PathPage.Surface;
        Caption:=
            'This is the safest choice as your PATH will not be modified at all. You will only be' + #13 +
            'able to use the Git command line tools from Git Bash.';
        Left:=ScaleX(28);
        Top:=ScaleY(32);
        Width:=ScaleX(405);
        Height:=ScaleY(26);
    end;

    // 2nd choice
    RdbPath[GP_Cmd]:=TRadioButton.Create(PathPage);
    with RdbPath[GP_Cmd] do begin
        Parent:=PathPage.Surface;
        Caption:='Use Git from the Windows Command Prompt';
        Left:=ScaleX(4);
        Top:=ScaleY(76);
        Width:=ScaleX(405);
        Height:=ScaleY(17);
        Font.Style:=[fsBold];
        TabOrder:=1;
        Checked:=True;
    end;
    LblGitCmd:=TLabel.Create(PathPage);
    with LblGitCmd do begin
        Parent:=PathPage.Surface;
        Caption:=
            'This option is considered safe as it only adds some minimal Git wrappers to your' + #13 +
            'PATH to avoid cluttering your environment with optional Unix tools. You will be' + #13 +
            'able to use Git from both Git Bash and the Windows Command Prompt.';
        Left:=ScaleX(28);
        Top:=ScaleY(100);
        Width:=ScaleX(405);
        Height:=ScaleY(39);
    end;

    // 3rd choice
    RdbPath[GP_CmdTools]:=TRadioButton.Create(PathPage);
    with RdbPath[GP_CmdTools] do begin
        Parent:=PathPage.Surface;
        Caption:='Use Git and optional Unix tools from the Windows Command Prompt';
        Left:=ScaleX(4);
        Top:=ScaleY(152);
        Width:=ScaleX(405);
        Height:=ScaleY(17);
        Font.Style:=[fsBold];
        TabOrder:=2;
    end;
    LblGitCmdTools:=TLabel.Create(PathPage);
    with LblGitCmdTools do begin
        Parent:=PathPage.Surface;
        Caption:='Both Git and the optional Unix tools will be added to your PATH.';
        Left:=ScaleX(28);
        Top:=ScaleY(176);
        Width:=ScaleX(405);
        Height:=ScaleY(13);
    end;
    LblGitCmdToolsWarn:=TLabel.Create(PathPage);
    with LblGitCmdToolsWarn do begin
        Parent:=PathPage.Surface;
        Caption:=
            'Warning: This will override Windows tools like "find" and "sort". Only' + #13 +
            'use this option if you understand the implications.';
        Left:=ScaleX(28);
        Top:=ScaleY(192);
        Width:=ScaleX(405);
        Height:=ScaleY(26);
        Font.Color:=255;
        Font.Style:=[fsBold];
    end;

    // Restore the setting chosen during a previous install.
    Data:=ReplayChoice('Path Option','Cmd');

    if Data='BashOnly' then begin
        RdbPath[GP_BashOnly].Checked:=True;
    end else if Data='Cmd' then begin
        RdbPath[GP_Cmd].Checked:=True;
    end else if Data='CmdTools' then begin
        RdbPath[GP_CmdTools].Checked:=True;
    end;

    (*
     * Create a custom page for using (Tortoise)Plink instead of OpenSSH
     * if at least one PuTTY session is found in the Registry.
     *)

    if RegGetSubkeyNames(HKEY_CURRENT_USER,'Software\SimonTatham\PuTTY\Sessions',PuTTYSessions) and (GetArrayLength(PuTTYSessions)>0) then begin
        PuTTYPage:=CreateCustomPage(
            PrevPageID
        ,   'Choosing the SSH executable'
        ,   'Which Secure Shell client program would you like Git to use?'
        );
        PrevPageID:=PuTTYPage.ID;

        // 1st choice
        RdbSSH[GS_OpenSSH]:=TRadioButton.Create(PuTTYPage);
        with RdbSSH[GS_OpenSSH] do begin
            Parent:=PuTTYPage.Surface;
            Caption:='Use OpenSSH';
            Left:=ScaleX(4);
            Top:=ScaleY(8);
            Width:=ScaleX(405);
            Height:=ScaleY(17);
            Font.Style:=[fsBold];
            TabOrder:=0;
            Checked:=True;
        end;
        LblOpenSSH:=TLabel.Create(PuTTYPage);
        with LblOpenSSH do begin
            Parent:=PuTTYPage.Surface;
            Caption:=
                'This uses ssh.exe that comes with Git. The GIT_SSH and SVN_SSH' + #13 +
                'environment variables will not be modified.';
            Left:=ScaleX(28);
            Top:=ScaleY(32);
            Width:=ScaleX(405);
            Height:=ScaleY(26);
        end;

        // 2nd choice
        RdbSSH[GS_Plink]:=TRadioButton.Create(PuTTYPage);
        with RdbSSH[GS_Plink] do begin
            Parent:=PuTTYPage.Surface;
            Caption:='Use (Tortoise)Plink';
            Left:=ScaleX(4);
            Top:=ScaleY(76);
            Width:=ScaleX(405);
            Height:=ScaleY(17);
            Font.Style:=[fsBold];
            TabOrder:=1;
        end;
        LblPlink:=TLabel.Create(PuTTYPage);
        with LblPlink do begin
            Parent:=PuTTYPage.Surface;
            Caption:=
                'PuTTY sessions were found in your Registry. You may specify the path' + #13 +
                'to an existing copy of (Tortoise)Plink.exe from the TortoiseGit/SVN/CVS' + #13 +
                'or PuTTY applications. The GIT_SSH and SVN_SSH environment' + #13 +
                'variables will be adjusted to point to the following executable:';
            Left:=ScaleX(28);
            Top:=ScaleY(100);
            Width:=ScaleX(405);
            Height:=ScaleY(52);
        end;
        EdtPlink:=TEdit.Create(PuTTYPage);
        with EdtPlink do begin
            Parent:=PuTTYPage.Surface;

            EnvSSH:=GetEnvStrings('GIT_SSH',IsAdminLoggedOn);
            if (GetArrayLength(EnvSSH)=1) and IsPlinkExecutable(EnvSSH[0]) then begin
                Text:=EnvSSH[0];
            end;
            if not FileExists(Text) then begin
                Text:=GetPreviousData('Plink Path','');
            end;
            if not FileExists(Text) then begin
                Text:=GuessPlinkExecutable;
            end;
            if not FileExists(Text) then begin
                Text:='';
            end;

            Left:=ScaleX(28);
            Top:=ScaleY(161);
            Width:=ScaleX(316);
            Height:=ScaleY(13);
        end;
        BtnPlink:=TButton.Create(PuTTYPage);
        with BtnPlink do begin
            Parent:=PuTTYPage.Surface;
            Caption:='...';
            OnClick:=@BrowseForPuTTYFolder;
            Left:=ScaleX(348);
            Top:=ScaleY(161);
            Width:=ScaleX(21);
            Height:=ScaleY(21);
        end;

        // Restore the setting chosen during a previous install.
        Data:=ReplayChoice('SSH Option','OpenSSH');

        if Data='OpenSSH' then begin
            RdbSSH[GS_OpenSSH].Checked:=True;
        end else if Data='Plink' then begin
            RdbSSH[GS_Plink].Checked:=True;
        end;
    end else begin
        PuTTYPage:=NIL;
    end;

    (*
     * Create a custom page for HTTPS implementation (cURL) setting.
     *)

    CurlVariantPage:=CreateCustomPage(
        PrevPageID
    ,   'Choosing HTTPS transport backend'
    ,   'Which SSL/TLS library would you like Git to use for HTTPS connections?'
    );
    PrevPageID:=CurlVariantPage.ID;

    // 1st choice
    RdbCurlVariant[GC_OpenSSL]:=TRadioButton.Create(CurlVariantPage);
    with RdbCurlVariant[GC_OpenSSL] do begin
        Parent:=CurlVariantPage.Surface;
        Caption:='Use the OpenSSL library';
        Left:=ScaleX(4);
        Top:=ScaleY(8);
        Width:=ScaleX(405);
        Height:=ScaleY(17);
        Font.Style:=[fsBold];
        TabOrder:=0;
        Checked:=True;
    end;
    LblCurlOpenSSL:=TLabel.Create(CurlVariantPage);
    with LblCurlOpenSSL do begin
        Parent:=CurlVariantPage.Surface;
        Caption:='Server certificates will be validated using the ca-bundle.crt file.';
        Left:=ScaleX(28);
        Top:=ScaleY(32);
        Width:=ScaleX(405);
        Height:=ScaleY(47);
    end;

    // 2nd choice
    RdbCurlVariant[GC_WinSSL]:=TRadioButton.Create(CurlVariantPage);
    with RdbCurlVariant[GC_WinSSL] do begin
        Parent:=CurlVariantPage.Surface;
        Caption:='Use the native Windows Secure Channel library';
        Left:=ScaleX(4);
        Top:=ScaleY(76);
        Width:=ScaleX(405);
        Height:=ScaleY(17);
        Font.Style:=[fsBold];
        TabOrder:=1;
        Checked:=False;
    end;
    LblCurlWinSSL:=TLabel.Create(CurlVariantPage);
    with LblCurlWinSSL do begin
        Parent:=CurlVariantPage.Surface;
        Caption:='Server certificates will be validated using Windows Certificate Stores.' + #13 +
            'This option also allows you to use your company''s internal Root CA certificates' + #13 +
            'distributed e.g. via Active Directory Domain Services.';
        Left:=ScaleX(28);
        Top:=ScaleY(100);
        Width:=ScaleX(405);
        Height:=ScaleY(67);
    end;

    // Restore the setting chosen during a previous install.
    Data:=ReplayChoice('CURL Option','OpenSSL');

    if Data='OpenSSL' then begin
        RdbCurlVariant[GC_OpenSSL].Checked:=True;
    end else if Data='WinSSL' then begin
        RdbCurlVariant[GC_WinSSL].Checked:=True;
    end;

    (*
     * Create a custom page for the core.autocrlf setting.
     *)

    CRLFPage:=CreateCustomPage(
        PrevPageID
    ,   'Configuring the line ending conversions'
    ,   'How should Git treat line endings in text files?'
    );
    PrevPageID:=CRLFPage.ID;

    // 1st choice
    RdbCRLF[GC_CRLFAlways]:=TRadioButton.Create(CRLFPage);
    with RdbCRLF[GC_CRLFAlways] do begin
        Parent:=CRLFPage.Surface;
        Caption:='Checkout Windows-style, commit Unix-style line endings';
        Left:=ScaleX(4);
        Top:=ScaleY(8);
        Width:=ScaleX(405);
        Height:=ScaleY(17);
        Font.Style:=[fsBold];
        TabOrder:=0;
        Checked:=True;
    end;
    LblCRLFAlways:=TLabel.Create(CRLFPage);
    with LblCRLFAlways do begin
        Parent:=CRLFPage.Surface;
        Caption:=
            'Git will convert LF to CRLF when checking out text files. When committing' + #13 +
            'text files, CRLF will be converted to LF. For cross-platform projects,' + #13 +
            'this is the recommended setting on Windows ("core.autocrlf" is set to "true").';
        Left:=ScaleX(28);
        Top:=ScaleY(32);
        Width:=ScaleX(405);
        Height:=ScaleY(47);
    end;

    // 2nd choice
    RdbCRLF[GC_LFOnly]:=TRadioButton.Create(CRLFPage);
    with RdbCRLF[GC_LFOnly] do begin
        Parent:=CRLFPage.Surface;
        Caption:='Checkout as-is, commit Unix-style line endings';
        Left:=ScaleX(4);
        Top:=ScaleY(80);
        Width:=ScaleX(405);
        Height:=ScaleY(17);
        Font.Style:=[fsBold];
        TabOrder:=1;
        Checked:=False;
    end;
    LblLFOnly:=TLabel.Create(CRLFPage);
    with LblLFOnly do begin
        Parent:=CRLFPage.Surface;
        Caption:=
            'Git will not perform any conversion when checking out text files. When' + #13 +
            'committing text files, CRLF will be converted to LF. For cross-platform projects,' + #13 +
            'this is the recommended setting on Unix ("core.autocrlf" is set to "input").';
        Left:=ScaleX(28);
        Top:=ScaleY(104);
        Width:=ScaleX(405);
        Height:=ScaleY(47);
    end;

    // 3rd choice
    RdbCRLF[GC_CRLFCommitAsIs]:=TRadioButton.Create(CRLFPage);
    with RdbCRLF[GC_CRLFCommitAsIs] do begin
        Parent:=CRLFPage.Surface;
        Caption:='Checkout as-is, commit as-is';
        Left:=ScaleX(4);
        Top:=ScaleY(152);
        Width:=ScaleX(405);
        Height:=ScaleY(17);
        Font.Style:=[fsBold];
        TabOrder:=2;
        Checked:=False;
    end;
    LblCRLFCommitAsIs:=TLabel.Create(CRLFPage);
    with LblCRLFCommitAsIs do begin
        Parent:=CRLFPage.Surface;
        Caption:=
            'Git will not perform any conversions when checking out or committing' + #13 +
            'text files. Choosing this option is not recommended for cross-platform' + #13 +
            'projects ("core.autocrlf" is set to "false").';
        Left:=ScaleX(28);
        Top:=ScaleY(176);
        Width:=ScaleX(405);
        Height:=ScaleY(47);
    end;

    // Restore the setting chosen during a previous install.
    Data:=ReplayChoice('CRLF Option','CRLFAlways');

    if Data='LFOnly' then begin
        RdbCRLF[GC_LFOnly].Checked:=True;
    end else if Data='CRLFAlways' then begin
        RdbCRLF[GC_CRLFAlways].Checked:=True;
    end else if Data='CRLFCommitAsIs' then begin
        RdbCRLF[GC_CRLFCommitAsIs].Checked:=True;
    end;

    (*
     * Create a custom page for Git Bash's terminal emulator setting.
     *)

    BashTerminalPage:=CreateCustomPage(
        PrevPageID
    ,   'Configuring the terminal emulator to use with Git Bash'
    ,   'Which terminal emulator do you want to use with your Git Bash?'
    );
    PrevPageID:=BashTerminalPage.ID;

    // 1st choice
    RdbBashTerminal[GB_MinTTY]:=TRadioButton.Create(BashTerminalPage);
    with RdbBashTerminal[GB_MinTTY] do begin
        Parent:=BashTerminalPage.Surface;
        Caption:='Use MinTTY (the default terminal of MSYS2)';
        Left:=ScaleX(4);
        Top:=ScaleY(8);
        Width:=ScaleX(405);
        Height:=ScaleY(17);
        Font.Style:=[fsBold];
        TabOrder:=0;
        Checked:=True;
    end;
    LblMinTTY:=TLabel.Create(BashTerminalPage);
    with LblMinTTY do begin
        Parent:=BashTerminalPage.Surface;
        Caption:=
            'Git Bash will use MinTTY as terminal emulator, which sports a resizable window,' + #13 +
            'non-rectangular selections and a Unicode font. Windows console programs (such' + #13 +
            'as interactive Python) must be launched via `winpty` to work in MinTTY.';
        Left:=ScaleX(28);
        Top:=ScaleY(32);
        Width:=ScaleX(405);
        Height:=ScaleY(47);
    end;

    // 2nd choice
    RdbBashTerminal[GB_ConHost]:=TRadioButton.Create(BashTerminalPage);
    with RdbBashTerminal[GB_ConHost] do begin
        Parent:=BashTerminalPage.Surface;
        Caption:='Use Windows'' default console window';
        Left:=ScaleX(4);
        Top:=ScaleY(80);
        Width:=ScaleX(405);
        Height:=ScaleY(17);
        Font.Style:=[fsBold];
        TabOrder:=1;
        Checked:=False;
    end;
    LblConHost:=TLabel.Create(BashTerminalPage);
    with LblConHost do begin
        Parent:=BashTerminalPage.Surface;
        Caption:=
            'Git will use the default console window of Windows ("cmd.exe"), which works well' + #13 +
            'with Win32 console programs such as interactive Python or node.js, but has a' + #13 +
            'very limited default scroll-back, needs to be configured to use a Unicode font in' + #13 +
            'order to display non-ASCII characters correctly, and prior to Windows 10 its' + #13 +
            'window was not freely resizable and it only allowed rectangular text selections.';
        Left:=ScaleX(28);
        Top:=ScaleY(104);
        Width:=ScaleX(405);
        Height:=ScaleY(67);
    end;

    // Restore the setting chosen during a previous install.
    Data:=ReplayChoice('Bash Terminal Option','MinTTY');

    if Data='MinTTY' then begin
        RdbBashTerminal[GB_MinTTY].Checked:=True;
    end else if Data='ConHost' then begin
        RdbBashTerminal[GB_ConHost].Checked:=True;
    end;

    (*
     * Create a custom page for extra options.
     *)

    ExtraOptionsPage:=CreateCustomPage(
        PrevPageID
    ,   'Configuring extra options'
    ,   'Which features would you like to enable?'
    );
    PrevPageID:=ExtraOptionsPage.ID;

    // 1st option
    RdbExtraOptions[GP_FSCache]:=TCheckBox.Create(ExtraOptionsPage);
    with RdbExtraOptions[GP_FSCache] do begin
        Parent:=ExtraOptionsPage.Surface;
        Caption:='Enable file system caching';
        Left:=ScaleX(4);
        Top:=ScaleY(8);
        Width:=ScaleX(405);
        Height:=ScaleY(17);
        Font.Style:=[fsBold];
        TabOrder:=0;
        Checked:=True;
    end;
    LblFSCache:=TLabel.Create(ExtraOptionsPage);
    with LblFSCache do begin
        Parent:=ExtraOptionsPage.Surface;
        Caption:=
            'File system data will be read in bulk and cached in memory for certain' + #13 +
            'operations ("core.fscache" is set to "true"). This provides a significant' + #13 +
            'performance boost.';
        Left:=ScaleX(28);
        Top:=ScaleY(32);
        Width:=ScaleX(405);
        Height:=ScaleY(39);
    end;

    // Restore the settings chosen during a previous install.
    Data:=ReplayChoice('Performance Tweaks FSCache','Enabled');

    if Data='Enabled' then begin
        RdbExtraOptions[GP_FSCache].Checked:=True;
    end;

    // 2nd option
    RdbExtraOptions[GP_GCM]:=TCheckBox.Create(ExtraOptionsPage);
    with RdbExtraOptions[GP_GCM] do begin
        Parent:=ExtraOptionsPage.Surface;
        Caption:='Enable Git Credential Manager';
        Left:=ScaleX(4);
        Top:=ScaleY(80);
        Width:=ScaleX(405);
        Height:=ScaleY(17);
        Font.Style:=[fsBold];
        TabOrder:=1;
    end;
    LblGCM:=TLabel.Create(ExtraOptionsPage);
    with LblGCM do begin
        Parent:=ExtraOptionsPage.Surface;
        Caption:=
            'The Git Credential Manager for Windows provides secure Git credential storage'+#13+'for Windows, most notably multi-factor authentication support for Visual Studio'+#13+'Team Services and GitHub. (requires .NET framework v4.5.1 or or later).';
        Left:=ScaleX(28);
        Top:=ScaleY(104);
        Width:=ScaleX(405);
        Height:=ScaleY(39);
    end;
    LblGCMLink:=TLabel.Create(ExtraOptionsPage);
    with LblGCMLink do begin
        Parent:=ExtraOptionsPage.Surface;
        Caption:='Git Credential Manager';
        Left:=GetTextWidth('The ',LblGCM.Font)+ScaleX(28);
        Top:=ScaleY(104);
        Width:=ScaleX(405);
        Height:=ScaleY(13);
        Font.Color:=clBlue;
        Font.Style:=[fsUnderline];
        Cursor:=crHand;
        OnClick:=@OpenGCMHomepage;
    end;

    // Restore the settings chosen during a previous install, if .NET 4.5.1
    // or later is available.
    if DetectNetFxVersion()<378675 then begin
        RdbExtraOptions[GP_GCM].Checked:=False;
        RdbExtraOptions[GP_GCM].Enabled:=False;
    end else begin
        Data:=ReplayChoice('Use Credential Manager','Enabled');

        RdbExtraOptions[GP_GCM].Checked:=Data='Enabled';
    end;

    // 3rd option
    RdbExtraOptions[GP_Symlinks]:=TCheckBox.Create(ExtraOptionsPage);
    with RdbExtraOptions[GP_Symlinks] do begin
        Parent:=ExtraOptionsPage.Surface;
        Caption:='Enable symbolic links';
        Left:=ScaleX(4);
        Top:=ScaleY(152);
        Width:=ScaleX(405);
        Height:=ScaleY(17);
        Font.Style:=[fsBold];
        TabOrder:=1;
    end;
    LblSymlinks:=TLabel.Create(ExtraOptionsPage);
    with LblSymlinks do begin
        Parent:=ExtraOptionsPage.Surface;
        Caption:=
            'Enable symbolic links (requires the SeCreateSymbolicLink permission).'+#13+'Please note that existing repositories are unaffected by this setting.';
        Left:=ScaleX(28);
        Top:=ScaleY(176);
        Width:=ScaleX(405);
        Height:=ScaleY(26);
    end;
    LblSymlinksLink:=TLabel.Create(ExtraOptionsPage);
    with LblSymlinksLink do begin
        Parent:=ExtraOptionsPage.Surface;
        Caption:='symbolic links';
        Left:=GetTextWidth('Enable ',LblSymlinks.Font)+ScaleX(28);
        Top:=ScaleY(176);
        Width:=ScaleX(405);
        Height:=ScaleY(13);
        Font.Color:=clBlue;
        Font.Style:=[fsUnderline];
        Cursor:=crHand;
        OnClick:=@OpenSymlinksWikiPage;
    end;

    // Restore the settings chosen during a previous install, or auto-detect
    // by running `mklink` (unless started as administrator, in which case that
    // test would be meaningless).
    Data:=ReplayChoice('Enable Symlinks','Auto');
    if Data='Auto' then begin
        if EnableSymlinksByDefault() then
	    Data:='Enabled'
	else
	    Data:='Disabled';
    end;

    RdbExtraOptions[GP_Symlinks].Checked:=Data='Enabled';

#ifdef WITH_EXPERIMENTAL_BUILTIN_DIFFTOOL
    (*
     * Create a custom page for experimental options.
     *)

    ExperimentalOptionsPage:=CreateCustomPage(
        PrevPageID
    ,   'Configuring experimental options'
    ,   'Which bleeding-edge features would you like to enable?'
    );
    PrevPageID:=ExperimentalOptionsPage.ID;

    // 1st option
    RdbExperimentalOptions[GP_BuiltinDifftool]:=TCheckBox.Create(ExperimentalOptionsPage);
    with RdbExperimentalOptions[GP_BuiltinDifftool] do begin
        Parent:=ExperimentalOptionsPage.Surface;
        Caption:='Enable experimental, builtin difftool';
        Left:=ScaleX(4);
        Top:=ScaleY(8);
        Width:=ScaleX(405);
        Height:=ScaleY(17);
        Font.Style:=[fsBold];
        TabOrder:=1;
    end;
    LblBuiltinDifftool:=TLabel.Create(ExperimentalOptionsPage);
    with LblBuiltinDifftool do begin
        Parent:=ExperimentalOptionsPage.Surface;
        Caption:=
            'Use the experimental builtin difftool (fast, but only lightly tested).';
        Left:=ScaleX(28);
        Top:=ScaleY(32);
        Width:=ScaleX(405);
        Height:=ScaleY(13);
    end;

    // Restore the settings chosen during a previous install
    Data:=ReplayChoice('Enable Builtin Difftool','Auto');
    if Data='Auto' then
            RdbExperimentalOptions[GP_BuiltinDifftool].Checked:=False
	else
            RdbExperimentalOptions[GP_BuiltinDifftool].Checked:=Data='Enabled';
#endif

    (*
     * Create a custom page for finding the processes that lock a module.
     *)

    ProcessesPage:=CreateCustomPage(
        wpPreparing
    ,   'Replacing in-use files'
    ,   'The following applications use files that need to be replaced, please close them.'
    );

    ProcessesListBox:=TListBox.Create(ProcessesPage);
    with ProcessesListBox do begin
        Parent:=ProcessesPage.Surface;
        Width:=ProcessesPage.SurfaceWidth;
        Height:=ProcessesPage.SurfaceHeight-ScaleY(8);
    end;

    ProcessesRefresh:=TNewButton.Create(WizardForm);
    with ProcessesRefresh do begin
        Parent:=WizardForm;
        Width:=WizardForm.CancelButton.Width;
        Height:=WizardForm.CancelButton.Height;
        Top:=WizardForm.CancelButton.Top;
        Left:=WizardForm.ClientWidth-(WizardForm.CancelButton.Left+WizardForm.CancelButton.Width);
        Caption:='&Refresh';
        OnClick:=@RefreshProcessList;
    end;

    // This button is only used by the uninstaller.
    ContinueButton:=NIL;

#ifdef WITH_EXPERIMENTAL_BUILTIN_DIFFTOOL
    PageIDBeforeInstall:=ExperimentalOptionsPage.ID;
#else
    PageIDBeforeInstall:=ExtraOptionsPage.ID;
#endif

#ifdef DEBUG_WIZARD_PAGE
    DebugWizardPage:={#DEBUG_WIZARD_PAGE}.ID;
#endif
    // Initially hide the Refresh button, show it when the process page becomes current.
    ProcessesRefresh.Hide;
end;

function ShouldSkipPage(PageID:Integer):Boolean;
begin
    if (ProcessesPage<>NIL) and (PageID=ProcessesPage.ID) then begin
        // This page is only reached forward (by pressing "Next", never by pressing "Back").
        RefreshProcessList(NIL);
        Result:=(GetArrayLength(Processes)=0);
    end else begin
        Result:=False;
    end;
#ifdef DEBUG_WIZARD_PAGE
    Result:=PageID<>DebugWizardPage
    Exit;
#endif
end;

procedure CurPageChanged(CurPageID:Integer);
begin
    if CurPageID=wpInfoBefore then begin
        if WizardForm.NextButton.Enabled then begin
            // By default, do not show a blinking cursor for InfoBeforeFile.
            WizardForm.ActiveControl:=WizardForm.NextButton;
        end;
    end else if CurPageID=wpSelectDir then begin
        if not IsDirWritable(WizardDirValue) then begin
            // If the default directory is not writable, choose another default that most likely is.
            // This will be checked later again when the user clicks "Next".
            WizardForm.DirEdit.Text:=ExpandConstant('{userpf}\{#APP_NAME}');
        end;
    end else if CurPageID=PageIDBeforeInstall then begin
        RefreshProcessList(NIL);
        if GetArrayLength(Processes)=0 then
            WizardForm.NextButton.Caption:=SetupMessage(msgButtonInstall);
    end else if (ProcessesPage<>NIL) and (CurPageID=ProcessesPage.ID) then begin
        // Show the "Refresh" button only on the processes page.
        ProcessesRefresh.Show;
        WizardForm.NextButton.Caption:=SetupMessage(msgButtonInstall);
    end else begin
        ProcessesRefresh.Hide;
    end;
end;

function NextButtonClick(CurPageID:Integer):Boolean;
var
    i:Integer;
    Version:TWindowsVersion;
    Msg:String;
begin
    // On a silent install, if your NextButtonClick function returns False
    // prior to installation starting, Setup will exit automatically.
    Result:=True;

    if CurPageID=wpSelectDir then begin
        if not IsDirWritable(WizardDirValue) then begin
            SuppressibleMsgBox(
                'The specified installation directory does not seem to be writable. ' +
            +   'Please choose another directory or restart setup as a user with sufficient permissions.'
            ,   mbCriticalError
            ,   MB_OK
            ,   IDOK
            );
            Result:=False;
            Exit;
        end;
    end;

    if (PuTTYPage<>NIL) and (CurPageID=PuTTYPage.ID) then begin
        Result:=RdbSSH[GS_OpenSSH].Checked or
            (RdbSSH[GS_Plink].Checked and FileExists(EdtPlink.Text));
        if not Result then begin
            SuppressibleMsgBox('{#PLINK_PATH_ERROR_MSG}',mbError,MB_OK,IDOK);
        end;
    end else if (ProcessesPage<>NIL) and (CurPageID=ProcessesPage.ID) then begin
        // It would have been nicer to just disable the "Next" button, but the
        // WizardForm exports the button just read-only.
        for i:=0 to GetArrayLength(Processes)-1 do begin
            if Processes[i].ToTerminate then begin
	        if not TerminateProcessByID(Processes[i].ID) then begin
                    SuppressibleMsgBox('Failed to terminate '+Processes[i].Name+' (pid '+IntToStr(Processes[i].ID)+')'+#13+'Please terminate it manually and press the "Refresh" button.',mbCriticalError,MB_OK,IDOK);
                    Result:=False;
                    Exit;
                end;
		    ;
            end else if not Processes[i].Restartable then begin
	        if WizardSilent() and (ParamIsSet('SKIPIFINUSE') or ParamIsSet('VSNOTICE')) then begin
		    Msg:='Skipping installation because the process '+Processes[i].Name+' (pid '+IntToStr(Processes[i].ID)+') is running, using Git for Windows'+#39+' files.';
		    if ParamIsSet('SKIPIFINUSE') or (ExpandConstant('{log}')='') then
		        LogError(Msg)
		    else
		        Log(Msg);
		    ExitEarlyWithSuccess();
		end;
                SuppressibleMsgBox(
                    'Setup cannot continue until you close at least those applications in the list that are marked as "closing is required".'
                ,   mbCriticalError
                ,   MB_OK
                ,   IDOK
                );
                Result:=False;
                Exit;
            end;
        end;

        Result:=(GetArrayLength(Processes)=0);

        if not Result then begin
            GetWindowsVersionEx(Version);
            if Version.Major>=6 then begin
                Result:=(SuppressibleMsgBox(
                    'If you continue without closing the listed applications they will be closed and restarted automatically.' + #13 + #13 +
                    'Are you sure you want to continue?'
                ,   mbConfirmation
                ,   MB_YESNO
                ,   IDYES
                )=IDYES);
            end else begin
                Result:=(SuppressibleMsgBox(
                    'If you continue without closing the listed applications you will need to log off and on again before changes take effect.' + #13 + #13 +
                    'Are you sure you want to continue anyway?'
                ,   mbConfirmation
                ,   MB_YESNO
                ,   IDNO
                )=IDYES);
            end;
        end;
    end;
end;

// Procedure to create hardlinks for builtins. This procedure relies upon that
// git-wrapper.exe is already copied to {app}\tmp.
procedure CopyBuiltin(FileName:String);
var
    AppDir:String;
    LinkCreated:Boolean;
begin
    if (not DeleteFile(FileName)) then begin
        Log('Line {#__LINE__}: Unable to delete existing built-in "'+FileName+'", skipping.');
        Exit;
    end;

    AppDir:=ExpandConstant('{app}');

    try
        // This will throw an exception on pre-Win2k systems.
        LinkCreated:=CreateHardLink(FileName,AppDir+'\{#MINGW_BITNESS}\bin\git.exe',0);
    except
        LinkCreated:=False;
        Log('Line {#__LINE__}: Creating hardlink "'+FileName+'" failed, will try a copy.');
    end;

    if not LinkCreated then begin
        if not FileCopy(AppDir+'\tmp\git-wrapper.exe',FileName,False) then begin
            Log('Line {#__LINE__}: Creating copy "'+FileName+'" failed.');
            // This is not a critical error, Git could basically be used without the
            // aliases for built-ins, so we continue.
        end;
    end;
end;

procedure CleanupWhenUpgrading;
var
    Domain,ErrorCode:Integer;
    Key,Path,ProgramData,UninstallString:String;
begin
    Key:='Microsoft\Windows\CurrentVersion\Uninstall\Git_is1';
    if RegKeyExists(HKEY_LOCAL_MACHINE,'Software\Wow6432Node\'+Key) then begin
        Domain:=HKEY_LOCAL_MACHINE;
        Key:='Software\Wow6432Node\'+Key;
    end else if RegKeyExists(HKEY_CURRENT_USER,'Software\Wow6432Node\'+Key) then begin
        Domain:=HKEY_CURRENT_USER;
        Key:='Software\Wow6432Node\'+Key;
    end else if RegKeyExists(HKEY_LOCAL_MACHINE,'Software\'+Key) then begin
        Domain:=HKEY_LOCAL_MACHINE;
        Key:='Software\'+Key;
    end else if RegKeyExists(HKEY_CURRENT_USER,'Software\'+Key) then begin
        Domain:=HKEY_CURRENT_USER;
        Key:='Software\'+Key;
    end else
        Domain:=-1;
    if Domain<>-1 then begin
        if RegQueryStringValue(Domain,Key,'Inno Setup: App Path',Path) then begin
            ProgramData:=ExpandConstant('{commonappdata}');
            if FileExists(Path+'\etc\gitconfig') and not FileExists(ProgramData+'\Git\config') then begin
                if not ForceDirectories(ProgramData+'\Git') then
                    LogError('Could not initialize Windows-wide Git config.')
                else if not FileCopy(Path+'\etc\gitconfig',ProgramData+'\Git\config',False) then
                    LogError('Could not copy old Git config to Windows-wide location.');
            end;
        end;

        if RegQueryStringValue(Domain,Key,'UninstallString',UninstallString) then
            // Using ShellExec() here, in case privilege elevation is required
            if not ShellExec('',UninstallString,'/VERYSILENT /SILENT /NORESTART /SUPPRESSMSGBOXES','',SW_HIDE,ewWaitUntilTerminated,ErrorCode) then
                LogError('Could not uninstall previous version. Trying to continue anyway.');
    end;
end;

procedure HardlinkOrCopy(Target,Source:String);
var
    LinkCreated:Boolean;
begin
    try
        // This will throw an exception on pre-Win2k systems.
        LinkCreated:=CreateHardLink(Target,Source,0);
    except
        LinkCreated:=False;
        Log('Line {#__LINE__}: Creating hardlink "'+Target+'" failed, will try a copy.');
    end;

    if not LinkCreated then begin
        if not FileCopy(Source,Target,False) then begin
            Log('Line {#__LINE__}: Creating copy "'+Target+'" failed.');
        end;
    end;
end;

procedure MaybeHardlinkDLLFiles;
var
    FindRec: TFindRec;
    AppDir,Bin,LibExec:String;
begin
    AppDir:=ExpandConstant('{app}');
    Bin:=AppDir+'\{#MINGW_BITNESS}\bin\';
    LibExec:=AppDir+'\{#MINGW_BITNESS}\libexec\git-core\';

    if FindFirst(ExpandConstant(Bin+'*.dll'), FindRec) then
    try
        repeat
            if ((FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) = 0) and
                    not FileExists(LibExec+FindRec.Name) then begin
                HardlinkOrCopy(LibExec+FindRec.Name,Bin+FindRec.Name);
            end;
        until
            not FindNext(FindRec);
    finally
        FindClose(FindRec);
    end;
end;

function ReplaceFile(SourceFile,TargetFile:String):Boolean;
begin
    if not DeleteFile(TargetFile) then begin
        LogError('Line {#__LINE__}: Unable to delete file "'+TargetFile+'".');
        Result:=False;
        Exit;
    end;
    if not RenameFile(SourceFile,TargetFile) then begin
        LogError('Line {#__LINE__}: Unable to overwrite file "'+TargetFile+'" with "'+SourceFile+'".');
        Result:=False;
        Exit;
    end;
    Result:=True;
end;

procedure CurStepChanged(CurStep:TSetupStep);
var
    AppDir,BinDir,ProgramData,DllPath,FileName,Cmd,Msg,Ico:String;
    BuiltIns,ImageNames,EnvPath:TArrayOfString;
    Count,i:Longint;
    RootKey:Integer;
begin
    if CurStep=ssInstall then begin
#ifdef DEBUG_WIZARD_PAGE
        ExitEarlyWithSuccess();
#endif
        // Shutdown locking processes just before the actual installation starts.
        if SessionHandle>0 then try
            RmShutdown(SessionHandle,RmShutdownOnlyRegistered,0);
        except
            Log('Line {#__LINE__}: RmShutdown not supported.');
        end;

        CleanupWhenUpgrading();

        Exit;
    end;

    // Make sure the code below is only executed just after the actual installation finishes.
    if CurStep<>ssPostInstall then begin
        Exit;
    end;

    AppDir:=ExpandConstant('{app}');
    ProgramData:=ExpandConstant('{commonappdata}');

    {
        Bind the imported function addresses
    }

    try
        DllPath:=ExpandConstant('{app}\usr\bin;{app}\{#MINGW_BITNESS}\bin;{sys}');

        // Load the list of images from a text file.
        FileName:=AppDir+'\{#APP_BINDIMAGE}';
        if LoadStringsFromFile(FileName,ImageNames) then begin
            Count:=GetArrayLength(ImageNames)-1;
            for i:=0 to Count do begin
                FileName:=AppDir+'\'+ImageNames[i];
                if not BindImageEx(BIND_NO_BOUND_IMPORTS or BIND_CACHE_IMPORT_DLLS,FileName,DllPath,'',0) then begin
                    Log('Line {#__LINE__}: Error calling BindImageEx for "'+FileName+'".');
                end;
            end;
        end;
    except
        Log('Line {#__LINE__}: An exception occurred while calling BindImageEx.');
    end;

    {
        Replace curl binaries in "/mingw64/bin" with curl-winssl variants
        This needs to be done before copying dlls from "/mingw64/bin" to "/mingw64/libexec/git-core"
    }

    BinDir:=AppDir+'\{#MINGW_BITNESS}\bin\';
    if RdbCurlVariant[GC_WinSSL].Checked and (not ReplaceFile(BinDir+'curl-winssl\curl.exe',BinDir+'curl.exe') or not ReplaceFile(BinDir+'curl-winssl\libcurl-4.dll',BinDir+'libcurl-4.dll')) then begin
        Log('Line {#__LINE__}: Replacing curl-openssl with curl-winssl failed.');
    end;

    {
        Copy dlls from "/mingw64/bin" to "/mingw64/libexec/git-core" if they are
        conflicting with system ones. For example, if a dll named "ssleay32.dll" in
        "/mingw64/bin" is also present in "%SystemRoot\System32", the version in
        "/mingw64/bin" is copied to "/mingw64/libexec/git-core". This call ensures
        that the dll in "/mingw64/libexec/git-core" is picked first when Windows load
        dll dependencies for executables in "/mingw64/libexec/git-core".
        (See https://github.com/git-for-windows/git/issues/145)
    }

    MaybeHardlinkDLLFiles();

    {
        Create the built-ins
    }

    // Load the built-ins from a text file.
    FileName:=AppDir+'\{#MINGW_BITNESS}\{#APP_BUILTINS}';
    if not FileExists(FileName) then
        Exit; // testing...
    if LoadStringsFromFile(FileName,BuiltIns) then begin
        Count:=GetArrayLength(BuiltIns)-1;

        // Delete those scripts from "bin" which have been replaced by built-ins in "libexec\git-core".
        for i:=0 to Count do begin
            FileName:=AppDir+'\{#MINGW_BITNESS}\bin\'+ChangeFileExt(ExtractFileName(BuiltIns[i]),'');
            if FileExists(FileName) and (not DeleteFile(FileName)) then begin
                Log('Line {#__LINE__}: Unable to delete script "'+FileName+'", ignoring.');
            end;
        end;

        // Copy git-wrapper to the temp directory.
        if not FileCopy(AppDir+'\{#MINGW_BITNESS}\libexec\git-core\git-log.exe',AppDir+'\tmp\git-wrapper.exe',False) then begin
            Log('Line {#__LINE__}: Creating copy "'+AppDir+'\tmp\git-wrapper.exe" failed.');
        end;

        // Create built-ins as aliases for git.exe.
        for i:=0 to Count do begin
            FileName:=AppDir+'\{#MINGW_BITNESS}\bin\'+BuiltIns[i];

            if FileExists(FileName) then begin
                CopyBuiltin(FileName);
            end;

            FileName:=AppDir+'\{#MINGW_BITNESS}\libexec\git-core\'+BuiltIns[i];

            if FileExists(FileName) then begin
                CopyBuiltin(FileName);
            end;
        end;

        // Delete git-wrapper from the temp directory.
        if not DeleteFile(AppDir+'\tmp\git-wrapper.exe') then begin
            Log('Line {#__LINE__}: Deleting temporary "'+AppDir+'\tmp\git-wrapper.exe" failed.');
        end;
    end else
        LogError('Line {#__LINE__}: Unable to read file "{#MINGW_BITNESS}\{#APP_BUILTINS}".');

    // Create default system wide git config file
    if not FileExists(ProgramData + '\Git\config') then begin
        if not DirExists(ProgramData + '\Git') then begin
            if not CreateDir(ProgramData + '\Git') then begin
                Log('Line {#__LINE__}: Creating directory "' + ProgramData + '\Git" failed.');
            end;
        end;
        if not FileCopy(AppDir + '\{#MINGW_BITNESS}\etc\gitconfig', ProgramData + '\Git\config', True) then begin
            Log('Line {#__LINE__}: Creating copy "' + ProgramData + '\Git\config" failed.');
        end;
    end;
    if FileExists(ProgramData+'\Git\config') then begin
#if BITNESS=='64'
        if not Exec(AppDir+'\bin\bash.exe','-c "value=\"$(git config -f config pack.packsizelimit)\" && if test 2g = \"$value\"; then git config -f config --unset pack.packsizelimit; fi"',ProgramData+'\Git',SW_HIDE,ewWaitUntilTerminated,i) then
            LogError('Unable to read/adjust packsize limit');
#endif
        Cmd:='http.sslCAInfo "'+AppDir+'/{#MINGW_BITNESS}/ssl/certs/ca-bundle.crt"';
        StringChangeEx(Cmd,'\','/',True);
        if not Exec(AppDir+'\{#MINGW_BITNESS}\bin\git.exe','config -f config '+Cmd,
                ProgramData+'\Git',SW_HIDE,ewWaitUntilTerminated,i) then
            LogError('Unable to configure SSL CA info: ' + Cmd);
        if not DeleteFile(AppDir+'\{#MINGW_BITNESS}\etc\gitconfig') then begin
            Log('Line {#__LINE__}: Deleting template config "' + AppDir + '\{#MINGW_BITNESS}\etc\gitconfig" failed.');
        end;
    end;

    {
        Adapt core.autocrlf
    }

    if RdbCRLF[GC_LFOnly].checked then begin
        Cmd:='core.autocrlf input';
    end else if RdbCRLF[GC_CRLFAlways].checked then begin
        Cmd:='core.autocrlf true';
    end else begin
        Cmd:='core.autocrlf false';
    end;
    if not Exec(AppDir + '\{#MINGW_BITNESS}\bin\git.exe', 'config -f config ' + Cmd,
                ProgramData + '\Git', SW_HIDE, ewWaitUntilTerminated, i) then
        LogError('Unable to configure the line ending conversion: ' + Cmd);

    {
        Configure the terminal window for Git Bash
    }

    if RdbBashTerminal[GB_ConHost].checked then begin
        OverrideGitBashCommandLine(AppDir+'\git-bash.exe','SHOW_CONSOLE=1 APPEND_QUOTE=1 @@COMSPEC@@ /S /C ""@@EXEPATH@@\usr\bin\bash.exe" --login -i');
    end;

    {
        Configure extra options
    }

    if RdbExtraOptions[GP_FSCache].checked then begin
        Cmd:='core.fscache true';

        if not Exec(AppDir + '\{#MINGW_BITNESS}\bin\git.exe', 'config -f config ' + Cmd,
                    ProgramData + '\Git', SW_HIDE, ewWaitUntilTerminated, i) then
            LogError('Unable to enable the extra option: ' + Cmd);
    end;

    if RdbExtraOptions[GP_GCM].checked then begin
        Cmd:='credential.helper manager';
        if not Exec(AppDir + '\{#MINGW_BITNESS}\bin\git.exe', 'config --system ' + Cmd,
                    AppDir, SW_HIDE, ewWaitUntilTerminated, i) then
            LogError('Unable to enable the extra option: ' + Cmd);
    end;

    if RdbExtraOptions[GP_Symlinks].checked then
        Cmd:='core.symlinks true'
    else
        Cmd:='core.symlinks false';
    if not Exec(AppDir + '\{#MINGW_BITNESS}\bin\git.exe', 'config -f config ' + Cmd,
                ProgramData + '\Git', SW_HIDE, ewWaitUntilTerminated, i) then
        LogError('Unable to enable the extra option: ' + Cmd);

    {
        Configure experimental options
    }

#ifdef WITH_EXPERIMENTAL_BUILTIN_DIFFTOOL
    if RdbExperimentalOptions[GP_BuiltinDifftool].checked then begin
        if not Exec(AppDir + '\{#MINGW_BITNESS}\bin\git.exe','config --system difftool.useBuiltin true','',SW_HIDE,ewWaitUntilTerminated, i) then
        LogError('Could not configure difftool.useBuiltin')
    end else begin
        if not Exec(AppDir + '\{#MINGW_BITNESS}\bin\git.exe','config --system --unset difftool.useBuiltin','',SW_HIDE,ewWaitUntilTerminated, i) then
        LogError('Could not configure difftool.useBuiltin')
    end;
#endif

    {
        Modify the environment

        This must happen no later than ssPostInstall to make
        "ChangesEnvironment=yes" not happend before the change!
    }

    // Delete GIT_SSH and SVN_SSH if a previous installation set them (this is required for the GS_OpenSSH case).
    DeleteMarkedEnvString('GIT_SSH');
    DeleteMarkedEnvString('SVN_SSH');

    if (PuTTYPage<>NIL) and RdbSSH[GS_Plink].Checked then begin
        SetAndMarkEnvString('GIT_SSH',EdtPlink.Text,True);
        SetAndMarkEnvString('SVN_SSH',EdtPlink.Text,True);
    end;

    // Get the current user's directories in PATH.
    EnvPath:=GetEnvStrings('PATH',IsAdminLoggedOn);

    // Modify the PATH variable as requested by the user.
    if RdbPath[GP_Cmd].Checked or RdbPath[GP_CmdTools].Checked then begin
        // First, remove the current installation directory from PATH.
        for i:=0 to GetArrayLength(EnvPath)-1 do begin
            if Pos(AppDir+'\',EnvPath[i]+'\')=1 then begin
                EnvPath[i]:='';
            end;
        end;

        i:=GetArrayLength(EnvPath);
        SetArrayLength(EnvPath,i+1);

        // List \cmd before \bin so \cmd has higher priority and programs in
        // there will be called in favor of those in \bin.
        EnvPath[i]:=AppDir+'\cmd';

        if RdbPath[GP_CmdTools].Checked then begin
            SetArrayLength(EnvPath,i+3);
            EnvPath[i+1]:=AppDir+'\{#MINGW_BITNESS}\bin';
            EnvPath[i+2]:=AppDir+'\usr\bin';
        end;
    end;

    // Set the current user's PATH directories.
    if not SetEnvStrings('PATH',EnvPath,True,IsAdminLoggedOn,True) then
        LogError('Line {#__LINE__}: Unable to set the PATH environment variable.');

    {
        Create shortcuts that need to be created regardless of the "Don't create a Start Menu folder" toggle
    }

    Cmd:=AppDir+'\git-bash.exe';
    FileName:=AppDir+'\{#MINGW_BITNESS}\share\git\git-for-windows.ico';

    if IsComponentSelected('icons\quicklaunch') then begin
        CreateShellLink(
            ExpandConstant('{userappdata}\Microsoft\Internet Explorer\Quick Launch\Git Bash.lnk')
        ,   'Git Bash'
        ,   Cmd
        ,   '--cd-to-home'
        ,   '%HOMEDRIVE%%HOMEPATH%'
        ,   FileName
        ,   0
        ,   SW_SHOWNORMAL
        );
    end;

    if IsComponentSelected('icons\desktop') then begin
        CreateShellLink(
            GetShellFolder('desktop')+'\Git Bash.lnk'
        ,   'Git Bash'
        ,   Cmd
        ,   '--cd-to-home'
        ,   '%HOMEDRIVE%%HOMEPATH%'
        ,   FileName
        ,   0
        ,   SW_SHOWNORMAL
        );
    end;

    {
        Create the Windows Explorer integrations
    }

    if IsAdminLoggedOn then begin
        RootKey:=HKEY_LOCAL_MACHINE;
    end else begin
        RootKey:=HKEY_CURRENT_USER;
    end;

    if IsComponentSelected('ext\shellhere') then begin
        Msg:='Git Ba&sh Here';
        Cmd:='"'+AppDir+'\git-bash.exe" "--cd=%1"';
        Ico:=AppDir+'\git-bash.exe';
        if (not RegWriteStringValue(RootKey,'SOFTWARE\Classes\Directory\shell\git_shell','',Msg)) or
           (not RegWriteStringValue(RootKey,'SOFTWARE\Classes\Directory\shell\git_shell\command','',Cmd)) or
           (not RegWriteStringValue(RootKey,'SOFTWARE\Classes\Directory\shell\git_shell','Icon',Ico)) or
           (StringChangeEx(Cmd,'%1','%v.',false)<>1) or
           (not RegWriteStringValue(RootKey,'SOFTWARE\Classes\Directory\Background\shell\git_shell','',Msg)) or
           (not RegWriteStringValue(RootKey,'SOFTWARE\Classes\Directory\Background\shell\git_shell\command','',Cmd)) or
           (not RegWriteStringValue(RootKey,'SOFTWARE\Classes\Directory\Background\shell\git_shell','Icon',Ico)) then
            LogError('Line {#__LINE__}: Unable to create "Git Bash Here" shell extension.');
    end;

    if IsComponentSelected('ext\guihere') then begin
        Msg:='Git &GUI Here';
        Cmd:='"'+AppDir+'\cmd\git-gui.exe" "--working-dir" "%1"';
        Ico:=AppDir+'\cmd\git-gui.exe';
        if (not RegWriteStringValue(RootKey,'SOFTWARE\Classes\Directory\shell\git_gui','',Msg)) or
           (not RegWriteStringValue(RootKey,'SOFTWARE\Classes\Directory\shell\git_gui\command','',Cmd)) or
           (not RegWriteStringValue(RootKey,'SOFTWARE\Classes\Directory\shell\git_gui','Icon',Ico)) or
           (StringChangeEx(Cmd,'%1','%v.',false)<>1) or
           (not RegWriteStringValue(RootKey,'SOFTWARE\Classes\Directory\Background\shell\git_gui','',Msg)) or
           (not RegWriteStringValue(RootKey,'SOFTWARE\Classes\Directory\Background\shell\git_gui\command','',Cmd)) or
           (not RegWriteStringValue(RootKey,'SOFTWARE\Classes\Directory\Background\shell\git_gui','Icon',Ico))
        then
            LogError('Line {#__LINE__}: Unable to create "Git GUI Here" shell extension.');
    end;

    {
        Run post-install scripts to set up system environment
    }

    Cmd:=AppDir+'\post-install.bat';
    if not Exec(Cmd,ExpandConstant('>"{tmp}\post-install.log"'),AppDir,SW_HIDE,ewWaitUntilTerminated,i) or (i<>0) then begin
        if FileExists(ExpandConstant('>"{tmp}\post-install.log"')) then
            LogError('Line {#__LINE__}: Unable to run post-install scripts:'+#13+ReadFileAsString(ExpandConstant('{tmp}\post-install.log')))
	else
	    Log('post-install output:'+#13+ReadFileAsString(ExpandConstant('{tmp}\post-install.log')));
    end;

    {
        Restart any processes that were shut down via the Restart Manager
    }

    if SessionHandle>0 then try
        RmRestart(SessionHandle,0,0);
        RmEndSession(SessionHandle);
    except
        Log('Line {#__LINE__}: RmRestart not supported.');
    end;
end;

procedure RegisterPreviousData(PreviousDataKey:Integer);
var
    Data,Path:String;
begin
    // Git Path options.
    Data:='';
    if RdbPath[GP_BashOnly].Checked then begin
        Data:='BashOnly';
    end else if RdbPath[GP_Cmd].Checked then begin
        Data:='Cmd';
    end else if RdbPath[GP_CmdTools].Checked then begin
        Data:='CmdTools';
    end;
    RecordChoice(PreviousDataKey,'Path Option',Data);

    // Git SSH options.
    Data:='';
    if (PuTTYPage=NIL) or RdbSSH[GS_OpenSSH].Checked then begin
        Data:='OpenSSH';
    end else if RdbSSH[GS_Plink].Checked then begin
        Data:='Plink';
        RecordChoice(PreviousDataKey,'Plink Path',EdtPlink.Text);
    end;
    RecordChoice(PreviousDataKey,'SSH Option',Data);

    // HTTPS implementation (cURL) options.
    Data:='OpenSSL';
    if RdbCurlVariant[GC_WinSSL].Checked then begin
        Data:='WinSSL';
    end;
    RecordChoice(PreviousDataKey,'CURL Option',Data);

    // Line ending conversion options.
    Data:='';
    if RdbCRLF[GC_LFOnly].Checked then begin
        Data:='LFOnly';
    end else if RdbCRLF[GC_CRLFAlways].Checked then begin
        Data:='CRLFAlways';
    end else if RdbCRLF[GC_CRLFCommitAsIs].Checked then begin
        Data:='CRLFCommitAsIs';
    end;
    RecordChoice(PreviousDataKey,'CRLF Option',Data);

    // Bash's terminal emulator options.
    Data:='MinTTY';
    if RdbBashTerminal[GB_ConHost].Checked then begin
        Data:='ConHost';
    end;
    RecordChoice(PreviousDataKey,'Bash Terminal Option',Data);

    // Extra options.
    Data:='Disabled';
    if RdbExtraOptions[GP_FSCache].Checked then begin
        Data:='Enabled';
    end;
    RecordChoice(PreviousDataKey,'Performance Tweaks FSCache',Data);
    Data:='Disabled';
    if RdbExtraOptions[GP_GCM].Checked then begin
        Data:='Enabled';
    end;
    RecordChoice(PreviousDataKey,'Use Credential Manager',Data);
    Data:='Disabled';
    if RdbExtraOptions[GP_Symlinks].Checked then begin
        Data:='Enabled';
    end;
    RecordChoice(PreviousDataKey,'Enable Symlinks',Data);

    // Experimental options.
#ifdef WITH_EXPERIMENTAL_BUILTIN_DIFFTOOL
    Data:='Disabled';
    if RdbExperimentalOptions[GP_BuiltinDifftool].Checked then begin
        Data:='Enabled';
    end;
    RecordChoice(PreviousDataKey,'Enable Builtin Difftool',Data);
#endif

    Path:=ExpandConstant('{app}\etc\install-options.txt');
    if not SaveStringToFile(Path,ChosenOptions,False) then
        LogError('Could not write to '+Path);
end;

{
    Uninstall event functions
}

function InitializeUninstall:Boolean;
var
    Form:TSetupForm;
    Info:TLabel;
    ExitButton,RefreshButton:TButton;
begin
    Result:=True;

    Form:=CreateCustomForm;
    try
        Form.Caption:='Git Uninstall: Removing in-use files';
        Form.ClientWidth:=ScaleX(500);
        Form.ClientHeight:=ScaleY(256);
        Form.Center;

        Info:=TLabel.Create(Form);
        with Info do begin
            Parent:=Form;
            Left:=ScaleX(11);
            Top:=ScaleY(11);
            AutoSize:=True;
            Caption:='The following applications use files that need to be removed, please close them.';
        end;

        ContinueButton:=TButton.Create(Form);
        with ContinueButton do begin
            Parent:=Form;
            Left:=Form.ClientWidth-ScaleX(75+10);
            Top:=Form.ClientHeight-ScaleY(23+10);
            Width:=ScaleX(75);
            Height:=ScaleY(23);
            Caption:='Continue';
            ModalResult:=mrOk;
        end;

        ExitButton:=TButton.Create(Form);
        with ExitButton do begin
            Parent:=Form;
            Left:=ContinueButton.Left-ScaleX(75+6);
            Top:=ContinueButton.Top;
            Width:=ScaleX(75);
            Height:=ScaleY(23);
            Caption:='Exit';
            ModalResult:=mrCancel;
            Cancel:=True;
        end;

        RefreshButton:=TButton.Create(Form);
        with RefreshButton do begin
            Parent:=Form;
            Left:=ScaleX(10);
            Top:=ExitButton.Top;
            Width:=ScaleX(75);
            Height:=ScaleY(23);
            Caption:='Refresh';
            OnClick:=@RefreshProcessList;
        end;

        ProcessesListBox:=TListBox.Create(Form);
        with ProcessesListBox do begin
            Parent:=Form;
            Left:=ScaleX(11);
            Top:=Info.Top+Info.Height+11;
            Width:=Form.ClientWidth-ScaleX(11*2);
            Height:=ContinueButton.Top-ScaleY(11*4);
        end;

        Form.ActiveControl:=ContinueButton;

        RefreshProcessList(NIL);
        if GetArrayLength(Processes)>0 then begin
            // Now that these dialogs are going to be shown, we should probably
            // disable the "Are you sure to remove Git?" confirmation dialog, but
            // unfortunately that is not possible with Inno Setup currently.
            Result:=(Form.ShowModal()=mrOk);

            // Note: The number of processes might have changed during a refresh.
            if Result and (GetArrayLength(Processes)>0) then begin
                Result:=(SuppressibleMsgBox(
                    'If you continue without closing the listed applications, you will need to log off and on again to remove some files manually.' + #13 + #13 +
                    'Are you sure you want to continue anyway?'
                ,   mbConfirmation
                ,   MB_YESNO
                ,   IDNO
                )=IDYES);
            end;
        end;
    finally
        Form.free;
    end;
end;

// PreUninstall
//
// Even though the name of this function suggests otherwise most of the
// code below is only executed right before the actual uninstallation.
// This happens because of the if-guard right in the beginning of this
// function.
procedure CurUninstallStepChanged(CurUninstallStep:TUninstallStep);
var
    AppDir,FileName,PathOption:String;
    EnvPath:TArrayOfString;
    i:Longint;
begin
    if CurUninstallStep<>usUninstall then begin
        Exit;
    end;

    // Reset the console font (the FontType is reset in the Registry section).
    if IsComponentInstalled('consolefont') then begin
        if SuppressibleMsgBox('Do you want to revert the TrueType font setting for all console windows?',mbConfirmation,MB_YESNO,IDYES)=IDYES then begin
            RegWriteDWordValue(HKEY_CURRENT_USER,'Console','FontFamily',0);
            RegWriteDWordValue(HKEY_CURRENT_USER,'Console','FontSize',0);
            RegWriteDWordValue(HKEY_CURRENT_USER,'Console','FontWeight',0);
        end;
    end;

    {
        Modify the environment

        This must happen no later than usUninstall to make
        "ChangesEnvironment=yes" not happend before the change!
    }

    AppDir:=ExpandConstant('{app}');
    FileName:=AppDir+'\setup.ini';

    // Delete the current user's GIT_SSH and SVN_SSH if we set it.
    DeleteMarkedEnvString('GIT_SSH');
    DeleteMarkedEnvString('SVN_SSH');

    // Only remove the installation directory from PATH if the previous
    // installation 'Path Option' modified it.
    PathOption:=GetPreviousData('Path Option','BashOnly');
    if (PathOption='Cmd') or (PathOption='CmdTools') then begin
        // Get the current user's directories in PATH.
        EnvPath:=GetEnvStrings('PATH',IsAdminLoggedOn);

        // Remove the installation directory from PATH.
        for i:=0 to GetArrayLength(EnvPath)-1 do begin
            if Pos(AppDir+'\',EnvPath[i]+'\')=1 then begin
                EnvPath[i]:='';
            end;
        end;

        // Reset the current user's directories in PATH.
        if not SetEnvStrings('PATH',EnvPath,True,IsAdminLoggedOn,True) then
            LogError('Line {#__LINE__}: Unable to revert any possible changes to PATH.');
    end;

    if FileExists(FileName) and (not DeleteFile(FileName)) then
        LogError('Line {#__LINE__}: Unable to delete file "'+FileName+'".');

    {
        Delete the Windows Explorer integrations
    }

    DeleteContextMenuEntries;

    if isWin64 then begin
        FileName:=AppDir+'\git-cheetah\git_shell_ext64.dll';
    end else begin
        FileName:=AppDir+'\git-cheetah\git_shell_ext.dll';
    end;
    if FileExists(FileName) then begin
        if not UnregisterServer(Is64BitInstallMode,FileName,False) then
            LogError('Line {#__LINE__}: Unable to unregister file "'+FileName+'". Please do it manually by running "regsvr32 /u '+ExtractFileName(FileName)+'".');

        if not DeleteFile(FileName) then
            LogError('Line {#__LINE__}: Unable to delete file "'+FileName+'". Please do it manually after logging off and on again.');
    end;
end;
