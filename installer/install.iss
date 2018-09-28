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
#define APP_URL       'https://gitforwindows.org/'
#define APP_BUILTINS  'share\git\builtins.txt'

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
#ifdef SOURCE_DIR
SourceDir={#SOURCE_DIR}
#else
SourceDir={#SourcePath}\..\..\..\..
#endif
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
Name: gitlfs; Description: Git LFS (Large File Support); Types: default; Flags: disablenouninstallwarning
Name: assoc; Description: Associate .git* configuration files with the default text editor; Types: default
Name: assoc_sh; Description: Associate .sh files to be run with Bash; Types: default
Name: consolefont; Description: Use a TrueType font in all console windows
Name: autoupdate; Description: Check daily for Git for Windows updates

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

; Delete git-lfs wrapper
Type: files; Name: {app}\cmd\git-lfs.exe

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

const
    // Git Editor options.
    GE_Nano           = 0;
    GE_VIM            = 1;
    GE_NotepadPlusPlus = 2;
    GE_VisualStudioCode = 3;
    GE_VisualStudioCodeInsiders = 4;

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
#define HAVE_EXPERIMENTAL_OPTIONS 1
#endif

#ifdef WITH_EXPERIMENTAL_BUILTIN_REBASE
#define HAVE_EXPERIMENTAL_OPTIONS 1
#endif

#ifdef WITH_EXPERIMENTAL_BUILTIN_STASH
#define HAVE_EXPERIMENTAL_OPTIONS 1
#endif

#ifdef HAVE_EXPERIMENTAL_OPTIONS
    // Experimental options
    GP_BuiltinDifftool = 1;
    GP_BuiltinRebase   = 2;
    GP_BuiltinStash    = 3;
#endif

var
    // The options chosen at install time, to be written to /etc/install-options.txt
    ChosenOptions:String;

    // Previous Git for Windows version (if upgrading)
    PreviousGitForWindowsVersion:String;

    // Wizard page and variables for the Editor options.
    EditorPage:TWizardPage;
    CbbEditor:TNewComboBox;
    LblEditor:array[GE_Nano..GE_VisualStudioCodeInsiders] of array of TLabel;
    EditorAvailable:array[GE_Nano..GE_VisualStudioCodeInsiders] of Boolean;
    SelectedEditor:Integer;

    NotepadPlusPlusPath:String;
    VisualStudioCodePath:String;
    VisualStudioCodeInsidersPath:String;

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

#ifdef HAVE_EXPERIMENTAL_OPTIONS
    // Wizard page and variables for the experimental options.
    ExperimentalOptionsPage:TWizardPage;
    RdbExperimentalOptions:array[GP_BuiltinDifftool..GP_BuiltinStash] of TCheckBox;
#endif

    // Mapping controls to hyperlinks
    HyperlinkSource:array of TObject;
    HyperlinkTarget:array of String;
    HyperlinkCount:Integer;

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
        SetArrayLength(Modules,17);
        Modules[0]:=ExpandConstant('{app}\usr\bin\msys-2.0.dll');
        Modules[1]:=ExpandConstant('{app}\{#MINGW_BITNESS}\bin\tcl85.dll');
        Modules[2]:=ExpandConstant('{app}\{#MINGW_BITNESS}\bin\tk85.dll');
        Modules[3]:=ExpandConstant('{app}\{#MINGW_BITNESS}\bin\tcl86.dll');
        Modules[4]:=ExpandConstant('{app}\{#MINGW_BITNESS}\bin\tk86.dll');
        Modules[5]:=ExpandConstant('{app}\git-cheetah\git_shell_ext.dll');
        Modules[6]:=ExpandConstant('{app}\git-cheetah\git_shell_ext64.dll');
        Modules[7]:=ExpandConstant('{app}\git-cmd.exe');
        Modules[8]:=ExpandConstant('{app}\git-bash.exe');
        Modules[9]:=ExpandConstant('{app}\bin\bash.exe');
        Modules[10]:=ExpandConstant('{app}\bin\git.exe');
        Modules[11]:=ExpandConstant('{app}\bin\sh.exe');
        Modules[12]:=ExpandConstant('{app}\cmd\git.exe');
        Modules[13]:=ExpandConstant('{app}\cmd\gitk.exe');
        Modules[14]:=ExpandConstant('{app}\cmd\git-gui.exe');
        Modules[15]:=ExpandConstant('{app}\{#MINGW_BITNESS}\bin\git.exe');
        Modules[16]:=ExpandConstant('{app}\usr\bin\bash.exe');
        SessionHandle:=FindProcessesUsingModules(Modules,Processes);
    end else begin
        SetArrayLength(Modules,15);
        Modules[0]:=ExpandConstant('{app}\usr\bin\msys-2.0.dll');
        Modules[1]:=ExpandConstant('{app}\{#MINGW_BITNESS}\bin\tcl85.dll');
        Modules[2]:=ExpandConstant('{app}\{#MINGW_BITNESS}\bin\tk85.dll');
        Modules[3]:=ExpandConstant('{app}\{#MINGW_BITNESS}\bin\tcl86.dll');
        Modules[4]:=ExpandConstant('{app}\{#MINGW_BITNESS}\bin\tk86.dll');
        Modules[5]:=ExpandConstant('{app}\git-cmd.exe');
        Modules[6]:=ExpandConstant('{app}\git-bash.exe');
        Modules[7]:=ExpandConstant('{app}\bin\bash.exe');
        Modules[8]:=ExpandConstant('{app}\bin\git.exe');
        Modules[9]:=ExpandConstant('{app}\bin\sh.exe');
        Modules[10]:=ExpandConstant('{app}\cmd\git.exe');
        Modules[11]:=ExpandConstant('{app}\cmd\gitk.exe');
        Modules[12]:=ExpandConstant('{app}\cmd\git-gui.exe');
        Modules[13]:=ExpandConstant('{app}\{#MINGW_BITNESS}\bin\git.exe');
        Modules[14]:=ExpandConstant('{app}\usr\bin\bash.exe');
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

function VersionCompare(CurrentVersion,PreviousVersion:String):Integer;
var
    i,j,Current,Previous:Integer;
begin
    Result:=0;
    i:=1;
    j:=1;
    while True do begin
        if j>Length(PreviousVersion) then begin
	    Result:=+1;
            Exit;
	end;
        if i>Length(CurrentVersion) then begin
            Result:=-1;
            Exit;
        end;
        Previous:=NextNumber(PreviousVersion,j);
        Current:=NextNumber(CurrentVersion,i);
        if Previous<0 then begin
            if Current>=0 then
                Result:=+1;
            Exit;
	end;
        if Current<0 then begin
            Result:=-1;
            Exit;
        end;
        if Current>Previous then begin
            Result:=+1;
            Exit;
	end;
        if Current<Previous then begin
            Result:=-1;
            Exit;
        end;
        if j>Length(PreviousVersion) then begin
	    if i<=Length(CurrentVersion) then
	        Result:=+1;
            Exit;
	end;
        if i>Length(CurrentVersion) then begin
            Result:=-1;
            Exit;
        end;
        if CurrentVersion[i]<>PreviousVersion[j] then begin
            if PreviousVersion[j]='.' then
                Result:=-1
            else
                Result:=+1;
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
    CurrentVersion,Msg:String;
    Version:TWindowsVersion;
    ErrorCode:Integer;
begin
    GetWindowsVersionEx(Version);
    if (Version.Major<6) then begin
        if SuppressibleMsgBox('Git for Windows requires Windows Vista or later.'+#13+'Click "Yes" for more details.',mbError,MB_YESNO,IDNO)=IDYES then
	    ShellExec('open','https://gitforwindows.org/requirements.html','','',SW_SHOW,ewNoWait,ErrorCode);
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
    RegQueryStringValue(HKEY_LOCAL_MACHINE,'Software\GitForWindows','CurrentVersion',PreviousGitForWindowsVersion);
#if APP_VERSION!='0-test'
    if Result and not ParamIsSet('ALLOWDOWNGRADE') then begin
        CurrentVersion:=ExpandConstant('{#APP_VERSION}');
        if (VersionCompare(CurrentVersion,PreviousGitForWindowsVersion)<0) then begin
            if WizardSilent() and (ParamIsSet('SKIPDOWNGRADE') or ParamIsSet('VSNOTICE')) then begin
                Msg:='Skipping downgrade from '+PreviousGitForWindowsVersion+' to '+CurrentVersion;
                if ParamIsSet('SKIPDOWNGRADE') or (ExpandConstant('{log}')='') then
                    LogError(Msg)
                else
                    Log(Msg);
                ExitEarlyWithSuccess();
            end;
            if SuppressibleMsgBox('Git for Windows '+PreviousGitForWindowsVersion+' is currently installed.'+#13+'Do you really want to downgrade to Git for Windows '+CurrentVersion+'?',mbConfirmation,MB_YESNO or MB_DEFBUTTON2,IDNO)=IDNO then
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

procedure OpenHyperlink(Sender:TObject);
var
  i,ExitStatus:Integer;
begin
  for i:=0 to (HyperlinkCount-1) do begin
      if (HyperlinkSource[i]=Sender) then begin
          ShellExec('',HyperlinkTarget[i],'','',SW_SHOW,ewNoWait,ExitStatus);
          exit;
      end;
  end;
  LogError('Missing hyperlink!');
end;

procedure OpenNanoHomepage(Sender:TObject);
var
  ExitStatus:Integer;
begin
  ShellExec('','https://www.nano-editor.org/dist/v2.8/nano.html','','',SW_SHOW,ewNoWait,ExitStatus);
end;

procedure OpenVIMHomepage(Sender:TObject);
var
  ExitStatus:Integer;
begin
  ShellExec('','http://www.vim.org/','','',SW_SHOW,ewNoWait,ExitStatus);
end;

procedure OpenExitVIMPost(Sender:TObject);
var
  ExitStatus:Integer;
begin
  ShellExec('','https://stackoverflow.blog/2017/05/23/stack-overflow-helping-one-million-developers-exit-vim/','','',SW_SHOW,ewNoWait,ExitStatus);
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

function IsOriginalUserAdmin():Boolean;
var
    ResultCode:Integer;
begin
    if not ExecAsOriginalUser(ExpandConstant('{cmd}'),ExpandConstant('/c net session >"{tmp}\net-session.txt"'),'',SW_HIDE,ewWaitUntilTerminated,ResultCode) then
        ResultCode:=-1;
    Result:=(ResultCode=0);
end;

function EnableSymlinksByDefault():Boolean;
var
    ResultCode:Integer;
begin
    if IsOriginalUserAdmin then begin
        Log('Symbolic link permission detection failed: running as admin');
	Result:=False;
    end else begin
        ExecAsOriginalUser(ExpandConstant('{cmd}'),ExpandConstant('/c mklink /d "{tmp}\symbolic link" "{tmp}" >"{tmp}\symlink test.txt"'),'',SW_HIDE,ewWaitUntilTerminated,ResultCode);
        Result:=DirExists(ExpandConstant('{tmp}\symbolic link'));
    end;
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

function CreatePage(var PrevPageID:Integer;const Caption,Description:String;var TabOrder,Top,Left:Integer):TWizardPage;
begin
    Result:=CreateCustomPage(PrevPageID,Caption,Description);
    PrevPageID:=Result.ID;
    TabOrder:=0;
    Top:=8;
    Left:=4;
end;

function SubString(S:String;Start,Count:Integer):String;
begin
    Result:=S;
    if (Start>1) then
        Delete(Result,1,Start-1);
    if (Count>=0) then
        SetLength(Result,Count);
end;

{
    Find the position of the next of the three specified tokens (if any).
    Returns 0 if none were found.
}

function Pos3(S,Token1,Token2,Token3:String;var ResultPos:Integer):String;
var
    i:Integer;
begin
    ResultPos:=Pos(Token1,S);
    if (ResultPos>0) then
        Result:=Token1;
    i:=Pos(Token2,S);
    if (i>0) and ((ResultPos=0) or (i<ResultPos)) then begin
        ResultPos:=i;
        Result:=Token2;
    end;
    i:=Pos(Token3,S);
    if (i>0) and ((ResultPos=0) or (i<ResultPos)) then begin
        ResultPos:=i;
        Result:=Token3;
    end;
end;

function CountLines(S:String):Integer;
begin
    Result:=1+StringChangeEx(S,#13,'',True);
end;

{
    Description can contain pseudo tags <RED>...</RED> and <A HREF=...>...</A>
    (which cannot be mixed).
}

function CreateItemDescription(Page:TWizardPage;const Description:String;var Top,Left:Integer;var Labels:array of TLabel;Visible:Boolean):TLabel;
var
    SubLabel:TLabel;
    Untagged,RowPrefix,Link:String;
    RowStart,RowCount,i,j:Integer;
begin
    Untagged:='';
    Result:=TLabel.Create(Page);
    Result.Parent:=Page.Surface;
    Result.Caption:=Untagged;
    Result.Top:=ScaleY(Top);
    Result.Left:=ScaleX(Left+24);
    Result.Width:=ScaleX(405);
    Result.Height:=ScaleY(13);
    Result.Visible:=Visible;
    SetArrayLength(Labels,GetArrayLength(Labels)+1);
    Labels[GetArrayLength(Labels)-1]:=Result;
    RowPrefix:='';
    RowCount:=1;
    while True do begin
        case Pos3(Description,#13,'<RED>','<A HREF=',i) of
            '': begin
                Untagged:=Untagged+Description;
                Result.Caption:=Untagged;
                Result.Height:=ScaleY(13*RowCount);
                Top:=Top+13+18;
                Exit;
            end;
            ''+#13: begin
                Untagged:=Untagged+SubString(Description,1,i);
                Description:=SubString(Description,i+1,-1);
                RowCount:=RowCount+1;
                RowPrefix:='';
                Top:=Top+13;
            end;
            '<RED>': begin
                Untagged:=Untagged+SubString(Description,1,i-1);
                RowPrefix:=RowPrefix+SubString(Description,1,i-1);
                Description:=SubString(Description,i+5,-1);
                i:=Pos('</RED>',Description);
                if (i=0) then LogError('Could not find </RED> in '+Description);
                j:=Pos(#13,Description);
                if (j>0) and (j<i) and (RowPrefix<>'') then begin
                    SubLabeL:=TLabel.Create(Page);
                    SubLabel.Parent:=Page.Surface;
                    SubLabel.Caption:=SubString(Description,1,j-1);
                    SubLabel.Top:=ScaleY(Top);
                    SubLabel.Left:=GetTextWidth(RowPrefix,Result.Font)+ScaleX(Left+24);
                    SubLabel.Width:=ScaleX(405);
                    SubLabel.Height:=ScaleY(13);
                    SubLabel.Font.Color:=clRed;
                    SubLabel.Visible:=Visible;
                    Untagged:=Untagged+SubString(Description,1,j);
                    Description:=SubString(Description,j+1,-1);
                    i:=i-j;
                    RowPrefix:='';
                    Top:=Top+13;
                    RowCount:=RowCount+1;
                    SetArrayLength(Labels,GetArrayLength(Labels)+1);
                    Labels[GetArrayLength(Labels)-1]:=SubLabel;
                end;
                SubLabeL:=TLabel.Create(Page);
                SubLabel.Parent:=Page.Surface;
                SubLabel.Caption:=SubString(Description,1,i-1);
                SubLabel.Top:=ScaleY(Top);
                SubLabel.Left:=GetTextWidth(RowPrefix,Result.Font)+ScaleX(Left+24);
                SubLabel.Width:=ScaleX(405);
                SubLabel.Height:=ScaleY(13*CountLines(SubLabel.Caption));
                SubLabel.Font.Color:=clRed;
                SubLabel.Visible:=Visible;
                Untagged:=Untagged+SubString(Description,1,i-1);
                RowPrefix:=RowPrefix+SubString(Description,1,i-1);
                Description:=SubString(Description,i+6,-1);
                SetArrayLength(Labels,GetArrayLength(Labels)+1);
                Labels[GetArrayLength(Labels)-1]:=SubLabel;
            end;
            '<A HREF=': begin
                Untagged:=Untagged+SubString(Description,1,i-1);
                RowPrefix:=RowPrefix+SubString(Description,1,i-1);
                Description:=SubString(Description,i+8,-1);
                i:=Pos('>',Description);
                if (i=0) then LogError('Could not find > in '+Description);
                HyperlinkCount:=HyperlinkCount+1;
                SetArrayLength(HyperlinkSource,HyperlinkCount);
                SetArrayLength(HyperlinkTarget,HyperlinkCount);
                HyperlinkTarget[HyperlinkCount-1]:=SubString(Description,1,i-1);
                Description:=SubString(Description,i+1,-1);
                i:=Pos('</A>',Description);
                if (i=0) then LogError('Could not find </A> in '+Description);
                j:=Pos(#13,Description);
                if (j>0) and (j<i) and (RowPrefix<>'') then begin
                    SubLabeL:=TLabel.Create(Page);
                    HyperlinkSource[HyperlinkCount-1]:=SubLabel;
                    HyperlinkCount:=HyperlinkCount+1;
                    SetArrayLength(HyperlinkSource,HyperlinkCount);
                    SetArrayLength(HyperlinkTarget,HyperlinkCount);
                    HyperlinkTarget[HyperlinkCount-1]:=HyperlinkTarget[HyperlinkCount-2];
                    SubLabel.Parent:=Page.Surface;
                    SubLabel.Caption:=SubString(Description,1,j-1);
                    SubLabel.Top:=ScaleY(Top);
                    SubLabel.Left:=GetTextWidth(RowPrefix,Result.Font)+ScaleX(Left+24);
                    SubLabel.Width:=ScaleX(405);
                    SubLabel.Height:=ScaleY(13);
                    SubLabel.Font.Color:=clBlue;
                    SubLabel.Font.Style:=[fsUnderline];
                    SubLabel.Cursor:=crHand;
                    SubLabel.OnClick:=@OpenHyperlink;
                    SubLabel.Visible:=Visible;
                    Untagged:=Untagged+SubString(Description,1,j);
                    Description:=SubString(Description,j+1,-1);
                    i:=i-j;
                    RowPrefix:='';
                    Top:=Top+13;
                    RowCount:=RowCount+1;
                    SetArrayLength(Labels,GetArrayLength(Labels)+1);
                    Labels[GetArrayLength(Labels)-1]:=SubLabel;
                end;
                SubLabeL:=TLabel.Create(Page);
                HyperlinkSource[HyperlinkCount-1]:=SubLabel;
                SubLabel.Parent:=Page.Surface;
                SubLabel.Caption:=SubString(Description,1,i-1);
                SubLabel.Top:=ScaleY(Top);
                SubLabel.Left:=GetTextWidth(RowPrefix,Result.Font)+ScaleX(Left+24);
                SubLabel.Width:=ScaleX(405);
                SubLabel.Height:=ScaleY(13*CountLines(SubLabel.Caption));
                SubLabel.Font.Color:=clBlue;
                SubLabel.Font.Style:=[fsUnderline];
                SubLabel.Cursor:=crHand;
                SubLabel.OnClick:=@OpenHyperlink;
                SubLabel.Visible:=Visible;
                Untagged:=Untagged+SubString(Description,1,i-1);
                RowPrefix:=RowPrefix+SubString(Description,1,i-1);
                Description:=SubString(Description,i+4,-1);
                SetArrayLength(Labels,GetArrayLength(Labels)+1);
                Labels[GetArrayLength(Labels)-1]:=SubLabel;
            end;
        end;
    end;
end;

function CreateRadioButtonOrCheckBox(CreateRadioButton:Boolean;Page:TWizardPage;const Caption,Description:String;var TabOrder,Top,Left:Integer):TButtonControl;
var
    RadioButton:TRadioButton;
    CheckBox:TCheckBox;
    Dummy:array of TLabel;
begin
    if (CreateRadioButton) then begin
        RadioButton:=TRadioButton.Create(Page);
        RadioButton.Caption:=Caption;
        RadioButton.Font.Style:=[fsBold];
        Result:=RadioButton;
    end else begin
        CheckBox:=TCheckBox.Create(Page);
        CheckBox.Caption:=Caption;
        CheckBox.Font.Style:=[fsBold];
        Result:=CheckBox;
    end;
    Result.Parent:=Page.Surface;
    Result.Left:=ScaleX(Left);
    Result.Top:=ScaleY(Top);
    Result.Width:=ScaleX(405);
    Result.Height:=ScaleY(17);
    Result.TabOrder:=TabOrder;
    TabOrder:=TabOrder+1;
    Top:=Top+24;
    CreateItemDescription(Page,Description,Top,Left,Dummy,True);
end;

function CreateRadioButton(Page:TWizardPage;const Caption,Description:String;var TabOrder,Top,Left:Integer):TRadioButton;
begin
    Result:=TRadioButton(CreateRadioButtonOrCheckBox(True,Page,Caption,Description,TabOrder,Top,Left));
end;

function CreateCheckBox(Page:TWizardPage;const Caption,Description:String;var TabOrder,Top,Left:Integer):TCheckBox;
begin
    Result:=TCheckBox(CreateRadioButtonOrCheckBox(False,Page,Caption,Description,TabOrder,Top,Left));
end;

procedure EditorSelectionChanged(Sender: TObject);
var
    i:Integer;
begin
    for i:=0 to GetArrayLength(LblEditor[SelectedEditor])-1 do
        LblEditor[SelectedEditor][i].Visible:=False;
    SelectedEditor:=CbbEditor.ItemIndex;
    for i:=0 to GetArrayLength(LblEditor[SelectedEditor])-1 do begin
        LblEditor[SelectedEditor][i].Visible:=True;
        if (LblEditor[SelectedEditor][i].Cursor<>crHand) then
            LblEditor[SelectedEditor][i].Enabled:=EditorAvailable[SelectedEditor];
    end;
    Wizardform.NextButton.Enabled:=EditorAvailable[SelectedEditor];
end;

procedure InitializeWizard;
var
    PrevPageID,TabOrder,TopOfLabels,Top,Left:Integer;
    PuTTYSessions,EnvSSH:TArrayOfString;
    BtnPlink:TButton;
    Data:String;
begin

    ChosenOptions:='';

    PrevPageID:=wpSelectProgramGroup;

    (*
     * Create a custom page for configuring the default Git editor.
     *)

    EditorPage:=CreatePage(PrevPageID,'Choosing the default editor used by Git','Which editor would you like Git to use?',TabOrder,Top,Left);

    CbbEditor:=TNewComboBox.Create(EditorPage);
    CbbEditor.Style:=csDropDownList;
    CbbEditor.OnChange:=@EditorSelectionChanged;
    CbbEditor.Parent:=EditorPage.Surface;
    CbbEditor.Left:=ScaleX(Left);
    CbbEditor.Top:=ScaleY(Top);
    CbbEditor.Width:=ScaleX(405);
    CbbEditor.Height:=ScaleY(17);
    CbbEditor.TabOrder:=TabOrder;
    TabOrder:=TabOrder+1;
    Top:=Top+24;
    TopOfLabels:=Top;

    EditorAvailable[GE_NotepadPlusPlus]:=RegQueryStringValue(HKEY_LOCAL_MACHINE,'SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\notepad++.exe','',NotepadPlusPlusPath);
    EditorAvailable[GE_VisualStudioCode]:=RegQueryStringValue(HKEY_CURRENT_USER,'SOFTWARE\Classes\Applications\Code.exe\shell\open\command','',VisualStudioCodePath);
    if (not EditorAvailable[GE_VisualStudioCode]) then begin
        EditorAvailable[GE_VisualStudioCode]:=RegQueryStringValue(HKEY_LOCAL_MACHINE,'SOFTWARE\Classes\Applications\Code.exe\shell\open\command','',VisualStudioCodePath);
    end
    EditorAvailable[GE_VisualStudioCodeInsiders]:=RegQueryStringValue(HKEY_CURRENT_USER,'SOFTWARE\Classes\Applications\Code - Insiders.exe\shell\open\command','',VisualStudioCodeInsidersPath);
    if (not EditorAvailable[GE_VisualStudioCodeInsiders]) then begin
        EditorAvailable[GE_VisualStudioCodeInsiders]:=RegQueryStringValue(HKEY_LOCAL_MACHINE,'SOFTWARE\Classes\Applications\Code - Insiders.exe\shell\open\command','',VisualStudioCodeInsidersPath);
    end;
    

    if (EditorAvailable[GE_VisualStudioCode]) then begin
        StringChangeEx(VisualStudioCodePath,' "%1"','',True);
    end;
    if (EditorAvailable[GE_VisualStudioCodeInsiders]) then begin
        StringChangeEx(VisualStudioCodeInsidersPath,' "%1"','',True);
    end;

    // 1st choice
    Top:=TopOfLabels;
    CbbEditor.Items.Add('Use the Nano editor by default');
    Data:='<RED>(NEW!)</RED> <A HREF=https://www.nano-editor.org/dist/v2.8/nano.html>GNU nano</A> is a small and friendly text editor running in the console'+#13+'window.';
    if (not EditorAvailable[GE_NotepadPlusPlus] and not EditorAvailable[GE_VisualStudioCode] and not EditorAvailable[GE_VisualStudioCodeInsiders]) then
        Data:=Data+#13+#13+'This is the recommended option for end users if no GUI editors are installed.';
    CreateItemDescription(EditorPage,Data,Top,Left,LblEditor[GE_Nano],False);
    EditorAvailable[GE_Nano]:=True;

    // 2nd choice
    Top:=TopOfLabels;
    CbbEditor.Items.Add('Use Vim (the ubiquitous text editor) as Git'+#39+'s default editor');
    CreateItemDescription(EditorPage,'The <A HREF=http://www.vim.org/>Vim editor</A>, while powerful, <A HREF=https://stackoverflow.blog/2017/05/23/stack-overflow-helping-one-million-developers-exit-vim/>can be hard to use</A>. Its user interface is'+#13+'unintuitive and its key bindings are awkward.'+#13+#13+'<RED>Note:</RED> Vim is the default editor of Git for Windows only for historical reasons, and'+#13+'it is highly recommended to switch to a modern GUI editor instead.',Top,Left,LblEditor[GE_VIM],False);
    EditorAvailable[GE_VIM]:=True;

    // 3rd choice
    Top:=TopOfLabels;
    CbbEditor.Items.Add('Use Notepad++ as Git'+#39+'s default editor');
    CreateItemDescription(EditorPage,'<RED>(NEW!)</RED> <A HREF=https://notepad-plus-plus.org/>Notepad++</A> is a popular GUI editor that can be used by Git.'+#13+#13+'This editor is popular in part due to the vast number of available plugins;'+#13+'However, when configured via this option, Git will call Notepad++ with'+#13+'plugins disabled (to open the editor as quickly as possible).',Top,Left,LblEditor[GE_NotepadPlusPlus],False);

    // 4th choice
    Top:=TopOfLabels;
    CbbEditor.Items.Add('Use Visual Studio Code as Git'+#39+'s default editor');
    CreateItemDescription(EditorPage,'<RED>(NEW!)</RED> <A HREF=https://code.visualstudio.com//>Visual Studio Code</A> is an Open Source, lightweight and powerful editor'+#13+'running as a desktop application. It comes with built-in support for JavaScript,'+#13+'TypeScript and Node.js and has a rich ecosystem of extensions for other'+#13+'languages (such as C++, C#, Java, Python, PHP, Go) and runtimes (such as'+#13+'.NET and Unity).'+#13+#13+'Use this option to let Git use Visual Studio Code as its default editor.',Top,Left,LblEditor[GE_VisualStudioCode],False);

    // 5th choice
    Top:=TopOfLabels;
    CbbEditor.Items.Add('Use Visual Studio Code Insiders as Git'+#39+'s default editor');
    CreateItemDescription(EditorPage,'<RED>(NEW!)</RED> <A HREF=https://code.visualstudio.com/insiders/>Visual Studio Code</A> is an Open Source, lightweight and powerful editor'+#13+'running as a desktop application. It comes with built-in support for JavaScript,'+#13+'TypeScript and Node.js and has a rich ecosystem of extensions for other'+#13+'languages (such as C++, C#, Java, Python, PHP, Go) and runtimes (such as'+#13+'.NET and Unity).'+#13+#13+'Use this option to let Git use Visual Studio Code Insiders as its default editor.',Top,Left,LblEditor[GE_VisualStudioCodeInsiders],False);

    // Restore the setting chosen during a previous install.
    case ReplayChoice('Editor Option','VIM') of
        'Nano': CbbEditor.ItemIndex:=GE_Nano;
        'VIM': CbbEditor.ItemIndex:=GE_VIM;
	'Notepad++': begin
            if EditorAvailable[GE_NotepadPlusPlus] then
                CbbEditor.ItemIndex:=GE_NotepadPlusPlus
            else
                CbbEditor.ItemIndex:=GE_VIM;
        end;
    'VisualStudioCode': begin
            if EditorAvailable[GE_VisualStudioCode] then
                CbbEditor.ItemIndex:=GE_VisualStudioCode
            else
                CbbEditor.ItemIndex:=GE_VIM;
        end;
    'VisualStudioCodeInsiders': begin
            if EditorAvailable[GE_VisualStudioCodeInsiders] then
                CbbEditor.ItemIndex:=GE_VisualStudioCodeInsiders
            else
                CbbEditor.ItemIndex:=GE_VIM;
        end;
    else
        CbbEditor.ItemIndex:=GE_VIM;
    end;
    EditorSelectionChanged(NIL);

    (*
     * Create a custom page for modifying the environment.
     *)

    PathPage:=CreatePage(PrevPageID,'Adjusting your PATH environment','How would you like to use Git from the command line?',TabOrder,Top,Left);

    // 1st choice
    RdbPath[GP_BashOnly]:=CreateRadioButton(PathPage,'Use Git from Git Bash only','This is the safest choice as your PATH will not be modified at all. You will only be'+#13+'able to use the Git command line tools from Git Bash.',TabOrder,Top,Left);

    // 2nd choice
    RdbPath[GP_Cmd]:=CreateRadioButton(PathPage,'Use Git from the Windows Command Prompt','This option is considered safe as it only adds some minimal Git wrappers to your'+#13+'PATH to avoid cluttering your environment with optional Unix tools. You will be'+#13+'able to use Git from both Git Bash and the Windows Command Prompt.',TabOrder,Top,Left);

    // 3rd choice
    RdbPath[GP_CmdTools]:=CreateRadioButton(PathPage,'Use Git and optional Unix tools from the Windows Command Prompt','Both Git and the optional Unix tools will be added to your PATH.'+#13+'<RED>Warning: This will override Windows tools like "find" and "sort". Only'+#13+'use this option if you understand the implications.</RED>',TabOrder,Top,Left);

    // Restore the setting chosen during a previous install.
    case ReplayChoice('Path Option','Cmd') of
        'BashOnly': RdbPath[GP_BashOnly].Checked:=True;
        'Cmd': RdbPath[GP_Cmd].Checked:=True;
        'CmdTools': RdbPath[GP_CmdTools].Checked:=True;
    else
        RdbPath[GP_Cmd].Checked:=True;
    end;

    (*
     * Create a custom page for using (Tortoise)Plink instead of OpenSSH
     * if at least one PuTTY session is found in the Registry.
     *)

    if RegGetSubkeyNames(HKEY_CURRENT_USER,'Software\SimonTatham\PuTTY\Sessions',PuTTYSessions) and (GetArrayLength(PuTTYSessions)>0) then begin
        PuTTYPage:=CreatePage(PrevPageID,'Choosing the SSH executable','Which Secure Shell client program would you like Git to use?',TabOrder,Top,Left);

        // 1st choice
        RdbSSH[GS_OpenSSH]:=CreateRadioButton(PuTTYPage,'Use OpenSSH','This uses ssh.exe that comes with Git. The GIT_SSH and SVN_SSH'+#13+'environment variables will not be modified.',TabOrder,Top,Left);

        // 2nd choice
        RdbSSH[GS_Plink]:=CreateRadioButton(PuTTYPage,'Use (Tortoise)Plink','PuTTY sessions were found in your Registry. You may specify the path'+#13+'to an existing copy of (Tortoise)Plink.exe from the TortoiseGit/SVN/CVS'+#13+'or PuTTY applications. The GIT_SSH and SVN_SSH environment'+#13+'variables will be adjusted to point to the following executable:',TabOrder,Top,Left);
        EdtPlink:=TEdit.Create(PuTTYPage);
        EdtPlink.Left:=ScaleX(Left+24);
        EdtPlink.Top:=ScaleY(Top+9);
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

            Width:=ScaleX(316);
            Height:=ScaleY(13);
        end;
        BtnPlink:=TButton.Create(PuTTYPage);
        BtnPlink.Left:=ScaleX(Left+344);
        BtnPlink.Top:=ScaleY(Top+9);
        with BtnPlink do begin
            Parent:=PuTTYPage.Surface;
            Caption:='...';
            OnClick:=@BrowseForPuTTYFolder;
            Width:=ScaleX(21);
            Height:=ScaleY(21);
        end;
	Top:=Top+30;

        // Restore the setting chosen during a previous install.
        case ReplayChoice('SSH Option','OpenSSH') of
            'OpenSSH': RdbSSH[GS_OpenSSH].Checked:=True;
            'Plink': RdbSSH[GS_Plink].Checked:=True;
	else
            RdbSSH[GS_OpenSSH].Checked:=True;
        end;
    end else begin
        PuTTYPage:=NIL;
    end;

    (*
     * Create a custom page for HTTPS implementation (cURL) setting.
     *)

    CurlVariantPage:=CreatePage(PrevPageID,'Choosing HTTPS transport backend','Which SSL/TLS library would you like Git to use for HTTPS connections?',TabOrder,Top,Left);

    // 1st choice
    RdbCurlVariant[GC_OpenSSL]:=CreateRadioButton(CurlVariantPage,'Use the OpenSSL library','Server certificates will be validated using the ca-bundle.crt file.',TabOrder,Top,Left);

    // 2nd choice
    RdbCurlVariant[GC_WinSSL]:=CreateRadioButton(CurlVariantPage,'Use the native Windows Secure Channel library','Server certificates will be validated using Windows Certificate Stores.'+#13+'This option also allows you to use your company''s internal Root CA certificates'+#13+'distributed e.g. via Active Directory Domain Services.',TabOrder,Top,Left);

    // Restore the setting chosen during a previous install.
    case ReplayChoice('CURL Option','OpenSSL') of
        'OpenSSL': RdbCurlVariant[GC_OpenSSL].Checked:=True;
        'WinSSL': RdbCurlVariant[GC_WinSSL].Checked:=True;
    else
        RdbCurlVariant[GC_OpenSSL].Checked:=True;
    end;

    (*
     * Create a custom page for the core.autocrlf setting.
     *)

    CRLFPage:=CreatePage(PrevPageID,'Configuring the line ending conversions','How should Git treat line endings in text files?',TabOrder,Top,Left);

    // 1st choice
    RdbCRLF[GC_CRLFAlways]:=CreateRadioButton(CRLFPage,'Checkout Windows-style, commit Unix-style line endings','Git will convert LF to CRLF when checking out text files. When committing'+#13+'text files, CRLF will be converted to LF. For cross-platform projects,'+#13+'this is the recommended setting on Windows ("core.autocrlf" is set to "true").',TabOrder,Top,Left);

    // 2nd choice
    RdbCRLF[GC_LFOnly]:=CreateRadioButton(CRLFPage,'Checkout as-is, commit Unix-style line endings','Git will not perform any conversion when checking out text files. When'+#13+'committing text files, CRLF will be converted to LF. For cross-platform projects,'+#13+'this is the recommended setting on Unix ("core.autocrlf" is set to "input").',TabOrder,Top,Left);

    // 3rd choice
    RdbCRLF[GC_CRLFCommitAsIs]:=CreateRadioButton(CRLFPage,'Checkout as-is, commit as-is','Git will not perform any conversions when checking out or committing'+#13+'text files. Choosing this option is not recommended for cross-platform'+#13+'projects ("core.autocrlf" is set to "false").',TabOrder,Top,Left);

    // Restore the setting chosen during a previous install.
    case ReplayChoice('CRLF Option','CRLFAlways') of
        'LFOnly': RdbCRLF[GC_LFOnly].Checked:=True;
        'CRLFAlways': RdbCRLF[GC_CRLFAlways].Checked:=True;
        'CRLFCommitAsIs': RdbCRLF[GC_CRLFCommitAsIs].Checked:=True;
    else
        RdbCRLF[GC_CRLFAlways].Checked:=True;
    end;

    (*
     * Create a custom page for Git Bash's terminal emulator setting.
     *)

    BashTerminalPage:=CreatePage(PrevPageID,'Configuring the terminal emulator to use with Git Bash','Which terminal emulator do you want to use with your Git Bash?',TabOrder,Top,Left);

    // 1st choice
    RdbBashTerminal[GB_MinTTY]:=CreateRadioButton(BashTerminalPage,'Use MinTTY (the default terminal of MSYS2)','Git Bash will use MinTTY as terminal emulator, which sports a resizable window,'+#13+'non-rectangular selections and a Unicode font. Windows console programs (such'+#13+'as interactive Python) must be launched via `winpty` to work in MinTTY.',TabOrder,Top,Left);

    // 2nd choice
    RdbBashTerminal[GB_ConHost]:=CreateRadioButton(BashTerminalPage,'Use Windows'' default console window','Git will use the default console window of Windows ("cmd.exe"), which works well'+#13+'with Win32 console programs such as interactive Python or node.js, but has a'+#13+'very limited default scroll-back, needs to be configured to use a Unicode font in'+#13+'order to display non-ASCII characters correctly, and prior to Windows 10 its'+#13+'window was not freely resizable and it only allowed rectangular text selections.',TabOrder,Top,Left);

    // Restore the setting chosen during a previous install.
    case ReplayChoice('Bash Terminal Option','MinTTY') of
        'MinTTY': RdbBashTerminal[GB_MinTTY].Checked:=True;
        'ConHost': RdbBashTerminal[GB_ConHost].Checked:=True;
    else
        RdbBashTerminal[GB_MinTTY].Checked:=True;
    end;

    (*
     * Create a custom page for extra options.
     *)

    ExtraOptionsPage:=CreatePage(PrevPageID,'Configuring extra options','Which features would you like to enable?',TabOrder,Top,Left);

    // 1st option
    RdbExtraOptions[GP_FSCache]:=CreateCheckBox(ExtraOptionsPage,'Enable file system caching','File system data will be read in bulk and cached in memory for certain'+#13+'operations ("core.fscache" is set to "true"). This provides a significant'+#13+'performance boost.',TabOrder,Top,Left);

    // Restore the settings chosen during a previous install.
    RdbExtraOptions[GP_FSCache].Checked:=ReplayChoice('Performance Tweaks FSCache','Enabled')<>'Disabled';

    // 2nd option
    RdbExtraOptions[GP_GCM]:=CreateCheckBox(ExtraOptionsPage,'Enable Git Credential Manager','The <A HREF=https://github.com/Microsoft/Git-Credential-Manager-for-Windows>Git Credential Manager for Windows</A> provides secure Git credential storage'+#13+'for Windows, most notably multi-factor authentication support for Visual Studio'+#13+'Team Services and GitHub. (requires .NET framework v4.5.1 or later).',TabOrder,Top,Left);

    // Restore the settings chosen during a previous install, if .NET 4.5.1
    // or later is available.
    if DetectNetFxVersion()<378675 then begin
        RdbExtraOptions[GP_GCM].Checked:=False;
        RdbExtraOptions[GP_GCM].Enabled:=False;
    end else begin
        RdbExtraOptions[GP_GCM].Checked:=ReplayChoice('Use Credential Manager','Enabled')<>'Disabled';
    end;

    // 3rd option
    RdbExtraOptions[GP_Symlinks]:=CreateCheckBox(ExtraOptionsPage,'Enable symbolic links','Enable <A HREF=https://github.com/git-for-windows/git/wiki/Symbolic-Links>symbolic links</A> (requires the SeCreateSymbolicLink permission).'+#13+'Please note that existing repositories are unaffected by this setting.',TabOrder,Top,Left);

    // Restore the settings chosen during a previous install, or auto-detect
    // by running `mklink` (unless started as administrator, in which case that
    // test would be meaningless).
    Data:=ReplayChoice('Enable Symlinks','Auto');
    if (Data='Auto') Or ((Data='Disabled') And (VersionCompare(PreviousGitForWindowsVersion,'2.14.1')<=0)) then begin
        if EnableSymlinksByDefault() then
	    Data:='Enabled'
	else
	    Data:='Disabled';
    end;

    RdbExtraOptions[GP_Symlinks].Checked:=Data<>'Disabled';

#ifdef HAVE_EXPERIMENTAL_OPTIONS
    (*
     * Create a custom page for experimental options.
     *)

    ExperimentalOptionsPage:=CreatePage(PrevPageID,'Configuring experimental options','Which bleeding-edge features would you like to enable?',TabOrder,Top,Left);

#ifdef WITH_EXPERIMENTAL_BUILTIN_DIFFTOOL
    // 1st option
    RdbExperimentalOptions[GP_BuiltinDifftool]:=CreateCheckBox(ExperimentalOptionsPage,'Enable experimental, builtin difftool','Use the experimental builtin difftool (fast, but only lightly tested).',TabOrder,Top,Left);

    // Restore the settings chosen during a previous install
    RdbExperimentalOptions[GP_BuiltinDifftool].Checked:=ReplayChoice('Enable Builtin Difftool','Auto')='Enabled';
#endif

#ifdef WITH_EXPERIMENTAL_BUILTIN_REBASE
    // 2nd option
    RdbExperimentalOptions[GP_BuiltinRebase]:=CreateCheckBox(ExperimentalOptionsPage,'Enable experimental, built-in rebase','<RED>(NEW!)</RED> Use the experimental built-in rebase (about 70% faster, but only'+#13+'lightly tested).',TabOrder,Top,Left);

    // Restore the settings chosen during a previous install
    RdbExperimentalOptions[GP_BuiltinRebase].Checked:=ReplayChoice('Enable Builtin Rebase','Auto')='Disabled';
#endif

#ifdef WITH_EXPERIMENTAL_BUILTIN_STASH
    // 3rd option
    RdbExperimentalOptions[GP_BuiltinStash]:=CreateCheckBox(ExperimentalOptionsPage,'Enable experimental, built-in stash','<RED>(NEW!)</RED> Use the experimental built-in stash (about 90% faster, but only'+#13+'lightly tested).',TabOrder,Top,Left);

    // Restore the settings chosen during a previous install
    RdbExperimentalOptions[GP_BuiltinStash].Checked:=ReplayChoice('Enable Builtin Stash','Auto')='Disabled';
#endif

#endif

    (*
     * Create a custom page for finding the processes that lock a module.
     *)

    ProcessesPage:=CreateCustomPage(
#ifdef DEBUG_WIZARD_PAGE
        PrevPageID
#else
        wpPreparing
#endif
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

#ifdef HAVE_EXPERIMENTAL_OPTIONS
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
var
    AppDir,Msg,Cmd,LogPath:String;
    Res:Longint;
begin
    if (ProcessesPage<>NIL) and (PageID=ProcessesPage.ID) then begin
        // This page is only reached forward (by pressing "Next", never by pressing "Back").
        if (ParamIsSet('SKIPIFINUSE') or ParamIsSet('VSNOTICE')) then begin
            AppDir:=ExpandConstant('{app}');
            if DirExists(AppDir) then begin
                if not FileExists(ExpandConstant('{tmp}\blocked-file-util.exe')) then
                    ExtractTemporaryFile('blocked-file-util.exe');
		LogPath:=ExpandConstant('{tmp}\blocking-pids.log');
		Cmd:='/C ""'+ExpandConstant('{tmp}\blocked-file-util.exe')+'" blocking-pids "'+AppDir+'" 2>"'+LogPath+'""';
                if not Exec(ExpandConstant('{sys}\cmd.exe'),Cmd,'',SW_HIDE,ewWaitUntilTerminated,Res) or (Res<>0) then begin
                    Msg:='Skipping installation because '+AppDir+' is still in use:'+#13+#10+ReadFileAsString(LogPath);
                    if ParamIsSet('SKIPIFINUSE') or (ExpandConstant('{log}')='') then
                        LogError(Msg)
                    else
                        Log(Msg);
                    ExitEarlyWithSuccess();
                end;
            end;
        end;
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

    if (EditorPage<>NIL) and (CurPageID=EditorPage.ID) then begin
        EditorSelectionChanged(NIL);
    end else if (PuTTYPage<>NIL) and (CurPageID=PuTTYPage.ID) then begin
        Result:=RdbSSH[GS_OpenSSH].Checked or
            (RdbSSH[GS_Plink].Checked and FileExists(EdtPlink.Text));
        if not Result then begin
            SuppressibleMsgBox('{#PLINK_PATH_ERROR_MSG}',mbError,MB_OK,IDOK);
        end;
    end else if (ProcessesPage<>NIL) and (CurPageID=ProcessesPage.ID) then begin
        RefreshProcessList(NIL);
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
procedure HardlinkOrCopyGit(FileName:String;Builtin:Boolean);
var
    AppDir,GitTarget:String;
    LinkCreated:Boolean;
begin
    if FileExists(FileName) and (not DeleteFile(FileName)) then begin
        Log('Line {#__LINE__}: Unable to delete existing built-in "'+FileName+'", skipping.');
        Exit;
    end;

    AppDir:=ExpandConstant('{app}');
    if Builtin then
        GitTarget:=AppDir+'\{#MINGW_BITNESS}\bin\git.exe'
    else
        // For non-builtins, we want to use the Git wrapper in cmd
        GitTarget:=AppDir+'\cmd\git.exe';

    try
        // This will throw an exception on pre-Win2k systems.
        LinkCreated:=CreateHardLink(FileName,GitTarget,0);
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
            if ((FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) = 0) then begin
                if FileExists(LibExec+FindRec.Name) then
                    DeleteFile(LibExec+FindRec.Name);
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

procedure InstallAutoUpdater;
var
    Res:Longint;
    LogPath,ErrPath,AppPath,XMLPath,Start:String;
begin
    Start:=GetDateTimeString('yyyy-mm-dd','-',':')+'T'+GetDateTimeString('hh:nn:ss','-',':');
    XMLPath:=ExpandConstant('{tmp}\auto-updater.xml');
    AppPath:=ExpandConstant('{app}');
    SaveStringToFile(XMLPath,
        '<?xml version="1.0" encoding="UTF-16"?>'+
        '<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">'+
        '  <Settings>'+
        '    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>'+
        '    <RunOnlyIfNetworkAvailable>true</RunOnlyIfNetworkAvailable>'+
        '    <StartWhenAvailable>true</StartWhenAvailable>'+
        '    <IdleSettings>'+
        '      <StopOnIdleEnd>false</StopOnIdleEnd>'+
        '      <RestartOnIdle>false</RestartOnIdle>'+
        '    </IdleSettings>'+
        '  </Settings>'+
        '  <Triggers>'+
        '    <CalendarTrigger>'+
        '      <StartBoundary>'+Start+'</StartBoundary>'+
        '      <ExecutionTimeLimit>PT4H</ExecutionTimeLimit>'+
        '      <ScheduleByDay>'+
        '        <DaysInterval>1</DaysInterval>'+
        '      </ScheduleByDay>'+
        '    </CalendarTrigger>'+
        '  </Triggers>'+
        '  <Actions Context="Author">'+
        '    <Exec>'+
        '      <Command>"'+AppPath+'\git-bash.exe"</Command>'+
        '      <Arguments>--hide --no-needs-console --command=cmd\git.exe update-git-for-windows --quiet --gui</Arguments>'+
        '    </Exec>'+
        '  </Actions>'+
        '</Task>',False);
    LogPath:=ExpandConstant('{tmp}\remove-autoupdate.log');
    ErrPath:=ExpandConstant('{tmp}\remove-autoupdate.err');
    if not Exec(ExpandConstant('{sys}\cmd.exe'),ExpandConstant('/C schtasks /Create /F /TN "Git for Windows Updater" /XML "'+XMLPath+'" >"'+LogPath+'" 2>"'+ErrPath+'"'),'',SW_HIDE,ewWaitUntilTerminated,Res) or (Res<>0) then
        LogError(ExpandConstant('Line {#__LINE__}: Unable to schedule the Git for Windows updater (output: '+ReadFileAsString(LogPath)+', errors: '+ReadFileAsString(ErrPath)+').'));
end;

procedure UninstallAutoUpdater;
var
    Res:Longint;
    LogPath,ErrPath:String;
begin
    LogPath:=ExpandConstant('{tmp}\remove-autoupdate.log');
    ErrPath:=ExpandConstant('{tmp}\remove-autoupdate.err');
    if not Exec(ExpandConstant('{sys}\cmd.exe'),ExpandConstant('/C schtasks /Delete /F /TN "Git for Windows Updater" >"'+LogPath+'" 2>"'+ErrPath+'"'),'',SW_HIDE,ewWaitUntilTerminated,Res) or (Res<>0) then
        LogError(ExpandConstant('Line {#__LINE__}: Unable to remove the Git for Windows updater (output: '+ReadFileAsString(LogPath)+', errors: '+ReadFileAsString(ErrPath)+').'));
end;

procedure CurStepChanged(CurStep:TSetupStep);
var
    AppDir,ProgramData,DllPath,FileName,Cmd,Msg,Ico:String;
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
                HardlinkOrCopyGit(FileName,True);
            end;

            FileName:=AppDir+'\{#MINGW_BITNESS}\libexec\git-core\'+BuiltIns[i];

            if FileExists(FileName) then begin
                HardlinkOrCopyGit(FileName,True);
            end;
        end;

        if IsComponentSelected('gitlfs') then begin
            HardlinkOrCopyGit(AppDir+'\cmd\git-lfs.exe',False);
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
        if not FileExists(ExpandConstant('{tmp}\programdata-config.template')) then
            ExtractTemporaryFile('programdata-config.template');
        if not FileCopy(ExpandConstant('{tmp}\programdata-config.template'), ProgramData + '\Git\config', True) then begin
            Log('Line {#__LINE__}: Creating initial "' + ProgramData + '\Git\config" failed.');
        end;
    end;

    {
        Configure http.sslBackend according to the user's choice.
    }

    if RdbCurlVariant[GC_WinSSL].Checked then begin
        Cmd:='schannel';
    end else begin
        Cmd:='openssl';
    end;
    if not Exec(AppDir+'\{#MINGW_BITNESS}\bin\git.exe','config --system http.sslBackend '+Cmd,
                AppDir,SW_HIDE,ewWaitUntilTerminated,i) then
        LogError('Unable to configure the HTTPS backend: '+Cmd);

    if FileExists(ProgramData+'\Git\config') then begin
        if not Exec(AppDir+'\bin\bash.exe','-c "value=\"$(git config -f config pack.packsizelimit)\" && if test 2g = \"$value\"; then git config -f config --unset pack.packsizelimit; fi"',ProgramData+'\Git',SW_HIDE,ewWaitUntilTerminated,i) then
            LogError('Unable to remove packsize limit from ProgramData config');
#if BITNESS=='32'
        if not Exec(AppDir+'\{#MINGW_BITNESS}\bin\git.exe','config --system pack.packsizelimit 2g',AppDir,SW_HIDE,ewWaitUntilTerminated,i) then
            LogError('Unable to limit packsize to 2GB');
#endif
        Cmd:=AppDir+'/';
        StringChangeEx(Cmd,'\','/',True);
        if not Exec(AppDir+'\bin\bash.exe','-c "value=\"$(git config -f config http.sslcainfo)\" && case \"$value\" in \"'+Cmd+'\"/*|\"C:/Program Files/Git/\"*|\"c:/Program Files/Git/\"*) git config -f config --unset http.sslcainfo;; esac"',ProgramData+'\Git',SW_HIDE,ewWaitUntilTerminated,i) then
            LogError('Unable to delete http.sslCAInfo from ProgramData config');
        if not RdbCurlVariant[GC_WinSSL].Checked then begin
            Cmd:='http.sslCAInfo "'+AppDir+'/{#MINGW_BITNESS}/ssl/certs/ca-bundle.crt"';
            StringChangeEx(Cmd,'\','/',True);
            if not Exec(AppDir+'\{#MINGW_BITNESS}\bin\git.exe','config --system '+Cmd,
                    AppDir,SW_HIDE,ewWaitUntilTerminated,i) then
                LogError('Unable to configure SSL CA info: ' + Cmd);
         end else begin
            if not Exec(AppDir+'\{#MINGW_BITNESS}\bin\git.exe','config --system --unset http.sslCAInfo',
                    AppDir,SW_HIDE,ewWaitUntilTerminated,i) then
                LogError('Unable to unset SSL CA info');
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

#ifdef WITH_EXPERIMENTAL_BUILTIN_REBASE
    if RdbExperimentalOptions[GP_BuiltinRebase].checked then begin
        if not Exec(AppDir + '\{#MINGW_BITNESS}\bin\git.exe','config --system rebase.useBuiltin true','',SW_HIDE,ewWaitUntilTerminated, i) then
        LogError('Could not configure rebase.useBuiltin')
    end else begin
        if not Exec(AppDir + '\{#MINGW_BITNESS}\bin\git.exe','config --system --unset rebase.useBuiltin','',SW_HIDE,ewWaitUntilTerminated, i) then
        LogError('Could not configure rebase.useBuiltin')
    end;
#endif

#ifdef WITH_EXPERIMENTAL_BUILTIN_STASH
    if RdbExperimentalOptions[GP_BuiltinStash].checked then begin
        if not Exec(AppDir + '\{#MINGW_BITNESS}\bin\git.exe','config --system stash.useBuiltin true','',SW_HIDE,ewWaitUntilTerminated, i) then
        LogError('Could not configure stash.useBuiltin')
    end else begin
        if not Exec(AppDir + '\{#MINGW_BITNESS}\bin\git.exe','config --system --unset stash.useBuiltin','',SW_HIDE,ewWaitUntilTerminated, i) then
        LogError('Could not configure stash.useBuiltin')
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
           (not RegWriteStringValue(RootKey,'SOFTWARE\Classes\Directory\Background\shell\git_shell','Icon',Ico)) or
           (not RegWriteStringValue(RootKey,'SOFTWARE\Classes\LibraryFolder\background\shell\git_shell','',Msg)) or
           (not RegWriteStringValue(RootKey,'SOFTWARE\Classes\LibraryFolder\background\shell\git_shell\command','',Cmd)) or
           (not RegWriteStringValue(RootKey,'SOFTWARE\Classes\LibraryFolder\background\shell\git_shell','Icon',Ico)) then
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
           (not RegWriteStringValue(RootKey,'SOFTWARE\Classes\Directory\Background\shell\git_gui','Icon',Ico)) or
           (not RegWriteStringValue(RootKey,'SOFTWARE\Classes\LibraryFolder\Background\shell\git_gui','',Msg)) or
           (not RegWriteStringValue(RootKey,'SOFTWARE\Classes\LibraryFolder\Background\shell\git_gui\command','',Cmd)) or
           (not RegWriteStringValue(RootKey,'SOFTWARE\Classes\LibraryFolder\Background\shell\git_gui','Icon',Ico))
        then
            LogError('Line {#__LINE__}: Unable to create "Git GUI Here" shell extension.');
    end;

    {
        Optionally disable Git LFS completely
    }

    if not IsComponentSelected('gitlfs') then begin
        if not Exec(AppDir + '\{#MINGW_BITNESS}\bin\git.exe','config --system --remove-section filter.lfs','',SW_HIDE,ewWaitUntilTerminated, i) then
            LogError('Could not disable Git LFS in the gitconfig.');
        if not DeleteFile(AppDir+'\{#MINGW_BITNESS}\bin\git-lfs.exe') and not DeleteFile(AppDir+'\{#MINGW_BITNESS}\libexec\git-core\git-lfs.exe') then
            LogError('Line {#__LINE__}: Unable to delete "git-lfs.exe".');
    end;

    {
        Set nano as default editor
    }

    if (CbbEditor.ItemIndex=GE_Nano) then begin
        if not Exec(AppDir + '\{#MINGW_BITNESS}\bin\git.exe','config --system core.editor nano.exe','',SW_HIDE,ewWaitUntilTerminated, i) then
            LogError('Could not set GNU nano as core.editor in the gitconfig.');
    end else if ((CbbEditor.ItemIndex=GE_NotepadPlusPlus)) and (NotepadPlusPlusPath<>'') then begin
        if not Exec(AppDir + '\{#MINGW_BITNESS}\bin\git.exe','config --system core.editor "'+#39+NotepadPlusPlusPath+#39+' -multiInst -notabbar -nosession -noPlugin"','',SW_HIDE,ewWaitUntilTerminated, i) then
            LogError('Could not set Notepad++ as core.editor in the gitconfig.');
    end else if ((CbbEditor.ItemIndex=GE_VisualStudioCode)) and (VisualStudioCodePath<>'') then begin
        if not Exec(AppDir + '\{#MINGW_BITNESS}\bin\git.exe','config --system core.editor "'+#39+VisualStudioCodePath+#39+' --wait"','',SW_HIDE,ewWaitUntilTerminated, i) then
            LogError('Could not set Visual Studio Code as core.editor in the gitconfig.');
    end else if ((CbbEditor.ItemIndex=GE_VisualStudioCodeInsiders)) and (VisualStudioCodeInsidersPath<>'') then begin
        if not Exec(AppDir + '\{#MINGW_BITNESS}\bin\git.exe','config --system core.editor "'+#39+VisualStudioCodeInsidersPath+#39+' --wait"','',SW_HIDE,ewWaitUntilTerminated, i) then
            LogError('Could not set Visual Studio Code Insiders as core.editor in the gitconfig.');
    end;

    {
        Install a scheduled task to try to auto-update Git for Windows
    }

    if IsComponentInstalled('autoupdate') then
        InstallAutoUpdater();

    {
        Run post-install scripts to set up system environment
    }

    Cmd:=AppDir+'\post-install.bat';
    Log('Line {#__LINE__}: Executing '+Cmd);
    if (not Exec(Cmd,ExpandConstant('>"{tmp}\post-install.log"'),AppDir,SW_HIDE,ewWaitUntilTerminated,i) or (i<>0)) and FileExists(Cmd) then begin
        if FileExists(ExpandConstant('{tmp}\post-install.log')) then
            LogError('Line {#__LINE__}: Unable to run post-install scripts:'+#13+#10+ReadFileAsString(ExpandConstant('{tmp}\post-install.log')))
	else
            LogError('Line {#__LINE__}: Unable to run post-install scripts; no output?');
    end else begin
        if FileExists(ExpandConstant('{tmp}\post-install.log')) then
            Log('Line {#__LINE__}: post-install scripts run successfully:'+#13+#10+ReadFileAsString(ExpandConstant('{tmp}\post-install.log')))
	else
            LogError('Line {#__LINE__}: Unable to run post-install scripts; no error, no output?');
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
    // Git Editor options.
    Data:='';
    if (CbbEditor.ItemIndex=GE_Nano) then begin
        Data:='Nano';
    end else if (CbbEditor.ItemIndex=GE_VIM) then begin
        Data:='VIM';
    end else if (CbbEditor.ItemIndex=GE_NotepadPlusPlus) then begin
        Data:='Notepad++';
    end else if (CbbEditor.ItemIndex=GE_VisualStudioCode) then begin
        Data:='VisualStudioCode';
    end else if (CbbEditor.ItemIndex=GE_VisualStudioCodeInsiders) then begin
        Data:='VisualStudioCodeInsiders';
    end;
    RecordChoice(PreviousDataKey,'Editor Option',Data);

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

#ifdef WITH_EXPERIMENTAL_BUILTIN_REBASE
    Data:='Disabled';
    if RdbExperimentalOptions[GP_BuiltinRebase].Checked then begin
        Data:='Enabled';
    end;
    RecordChoice(PreviousDataKey,'Enable Builtin Rebase',Data);
#endif

#ifdef WITH_EXPERIMENTAL_BUILTIN_STASH
    Data:='Disabled';
    if RdbExperimentalOptions[GP_BuiltinStash].Checked then begin
        Data:='Enabled';
    end;
    RecordChoice(PreviousDataKey,'Enable Builtin Stash',Data);
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
        Remove the scheduled task to try to auto-update Git for Windows
    }

    if IsComponentInstalled('autoupdate') then
        UninstallAutoUpdater();

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
