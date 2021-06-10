; Uncomment the line below to be able to compile the script from within the IDE.
;#define COMPILE_FROM_IDE
; vim: sw=4 expandtab:

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

#ifndef DEFAULT_BRANCH_NAME
#define DEFAULT_BRANCH_NAME 'master'
#endif

#ifndef INSTALLER_FILENAME_SUFFIX
#define INSTALLER_FILENAME_SUFFIX ''
#endif

[Setup]
; Compiler-related
Compression=lzma2/ultra64
LZMAUseSeparateProcess=yes
#ifdef OUTPUT_TO_TEMP
OutputBaseFilename={#FILENAME_VERSION}
OutputDir={#GetEnv('TEMP')}
#else
#if INSTALLER_FILENAME_SUFFIX!=''
OutputBaseFilename={#APP_NAME+'-'+FILENAME_VERSION+'-'+INSTALLER_FILENAME_SUFFIX}
#else
OutputBaseFilename={#APP_NAME+'-'+FILENAME_VERSION}-{#BITNESS}-bit
#endif
#ifdef OUTPUT_DIRECTORY
OutputDir={#OUTPUT_DIRECTORY}
#else
OutputDir={#GetEnv('USERPROFILE')}
#endif
#endif
SolidCompression=yes
#ifndef SOURCE_DIR
#define SOURCE_DIR SourcePath+'\..\..\..\..'
#endif
SourceDir={#SOURCE_DIR}
#if BITNESS=='64' || INSTALLER_FILENAME_SUFFIX=='arm64'
ArchitecturesInstallIn64BitMode=x64 arm64
#endif
#ifdef SIGNTOOL
SignTool=signtool
#endif

#define FILE_VERSION GetFileVersion(SOURCE_DIR+'\'+MINGW_BITNESS+'\bin\git.exe')

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
VersionInfoVersion={#FILE_VERSION}
#endif

; Cosmetic
SetupIconFile={#SourcePath}\..\git.ico
WizardImageBackColor=clWhite
WizardImageStretch=no
WizardImageFile={#SourcePath}\git.bmp
WizardSmallImageFile={#SourcePath}\gitsmall.bmp
MinVersion=6.0

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
Name: consolefont; Description: Use a TrueType font in all console windows; OnlyBelowVersion: 10.0
Name: autoupdate; Description: Check daily for Git for Windows updates
Name: windowsterminal; Description: "(NEW!) Add a Git Bash Profile to Windows Terminal"; MinVersion: 10.0.18362
#ifdef WITH_SCALAR
Name: scalar; Description: "(NEW!) Scalar (Git add-on to manage large-scale repositories)"; Types: default
#endif


[Run]
Filename: {app}\git-bash.exe; Parameters: --cd-to-home; Description: Launch Git Bash; Flags: nowait postinstall skipifsilent runasoriginaluser unchecked
Filename: {app}\ReleaseNotes.html; Description: View Release Notes; Flags: shellexec skipifdoesntexist postinstall skipifsilent

[Files]
; Install files that might be in use during setup under a different name.
#include "file-list.iss"
Source: {#SourcePath}\ReleaseNotes.html; DestDir: {app}; Flags: replacesameversion; AfterInstall: DeleteFromVirtualStore
Source: {#SourcePath}\..\LICENSE.txt; DestDir: {app}; Flags: replacesameversion; AfterInstall: DeleteFromVirtualStore
Source: {#SourcePath}\NOTICE.txt; DestDir: {app}; Flags: replacesameversion; AfterInstall: DeleteFromVirtualStore; Check: ParamIsSet('VSNOTICE')
#ifdef INCLUDE_EDIT_GIT_BASH
Source: {#SourcePath}\..\edit-git-bash.exe; Flags: dontcopy
#endif

[Dirs]
Name: "{app}\dev"
Name: "{app}\dev\mqueue"
Name: "{app}\dev\shm"
Name: "{app}\tmp"
Name: "{commonappdata}\Microsoft\Windows Terminal\Fragments\Git"; Components: windowsterminal; Check: IsAdminLoggedOn
Name: "{localappdata}\Microsoft\Windows Terminal\Fragments\Git"; Components: windowsterminal; Check: not IsAdminLoggedOn

[Icons]
Name: {group}\Git GUI; Filename: {app}\cmd\git-gui.exe; Parameters: ""; WorkingDir: %HOMEDRIVE%%HOMEPATH%; IconFilename: {app}\{#MINGW_BITNESS}\share\git\git-for-windows.ico
Name: {group}\Git Bash; Filename: {app}\git-bash.exe; Parameters: "--cd-to-home"; WorkingDir: %HOMEDRIVE%%HOMEPATH%; IconFilename: {app}\{#MINGW_BITNESS}\share\git\git-for-windows.ico
Name: {group}\Git CMD; Filename: {app}\git-cmd.exe; Parameters: "--cd-to-home"; WorkingDir: %HOMEDRIVE%%HOMEPATH%; IconFilename: {app}\{#MINGW_BITNESS}\share\git\git-for-windows.ico
Name: {group}\Git Release Notes; Filename: {app}\ReleaseNotes.html; Parameters: ""; WorkingDir: %HOMEDRIVE%%HOMEPATH%; IconFilename: {app}\{#MINGW_BITNESS}\share\git\git-for-windows.ico
Name: {group}\Git FAQs (Frequently Asked Questions); Filename: https://github.com/git-for-windows/git/wiki/FAQ; IconFilename: {app}\{#MINGW_BITNESS}\share\git\git-for-windows.ico

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

; Delete Git Bash options
Type: files; Name: {app}\etc\git-bash.config

; Delete Windows Terminal profile fragments
Type: files; Name: {commonappdata}\Microsoft\Windows Terminal\Fragments\Git\git-bash.json
Type: files; Name: {localappdata}\Microsoft\Windows Terminal\Fragments\Git\git-bash.json

[Code]
#include "helpers.inc.iss"
#include "environment.inc.iss"
#include "putty.inc.iss"
#include "modules.inc.iss"

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
#ifdef INCLUDE_EDIT_GIT_BASH
    if not FileExists(ExpandConstant('{tmp}\edit-git-bash.exe')) then
        ExtractTemporaryFile('edit-git-bash.exe');
#endif
    StringChangeEx(GitBashPath,'"','\"',True);
    StringChangeEx(CommandLine,'"','\"',True);
    CommandLine:='"'+GitBashPath+'" "'+CommandLine+'"';
#ifdef INCLUDE_EDIT_GIT_BASH
    Exec(ExpandConstant('{tmp}\edit-git-bash.exe'),CommandLine,'',SW_HIDE,ewWaitUntilTerminated,Result);
#else
    Exec(ExpandConstant('{app}\{#MINGW_BITNESS}\share\git\edit-git-bash.exe'),CommandLine,'',SW_HIDE,ewWaitUntilTerminated,Result);
#endif
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
    GE_SublimeText = 5;
    GE_Atom = 6;
    GE_VSCodium = 7;
    GE_Notepad = 8;
    GE_Wordpad = 9;
    GE_CustomEditor = 10;

    // Git Path options.
    GP_BashOnly       = 1;
    GP_Cmd            = 2;
    GP_CmdTools       = 3;

    // Default Branch options.
    DB_Unspecified    = 1;
    DB_Manual         = 2;

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

    // `git pull` behavior settings.
    GP_GitPullMerge   = 1;
    GP_GitPullRebase  = 2;
    GP_GitPullFFOnly  = 3;

    // Git Credential Manager settings.
    GCM_None          = 1;
    GCM_Classic       = 2;
    GCM_Core          = 3;

    // Extra options
    GP_FSCache        = 1;
    GP_Symlinks       = 2;

#ifdef WITH_EXPERIMENTAL_BUILTIN_DIFFTOOL
#define HAVE_EXPERIMENTAL_OPTIONS 1
#endif

#ifdef WITH_EXPERIMENTAL_BUILTIN_REBASE
#define HAVE_EXPERIMENTAL_OPTIONS 1
#endif

#ifdef WITH_EXPERIMENTAL_BUILTIN_STASH
#define HAVE_EXPERIMENTAL_OPTIONS 1
#endif

#ifdef WITH_EXPERIMENTAL_BUILTIN_ADD_I
#define HAVE_EXPERIMENTAL_OPTIONS 1
#endif

#ifdef WITH_EXPERIMENTAL_PCON
#define HAVE_EXPERIMENTAL_OPTIONS 1
#endif

#ifdef WITH_EXPERIMENTAL_BUILTIN_FSMONITOR
#define HAVE_EXPERIMENTAL_OPTIONS 1
#endif

#ifdef HAVE_EXPERIMENTAL_OPTIONS
    // Experimental options
    GP_BuiltinDifftool = 1;
    GP_BuiltinRebase   = 2;
    GP_BuiltinStash    = 3;
    GP_BuiltinAddI     = 4;
    GP_EnablePCon      = 5;
    GP_EnableFSMonitor = 6;
#endif

var
    AppDir,UninstallAppPath,UninstallString:String;
    InferredDefaultKeys,InferredDefaultValues:TStringList;

    // The options chosen at install time, to be written to /etc/install-options.txt
    ChosenOptions:String;

    // Accumulated set of custom pages that have options, and those that have 'new' parameters on them
    CurrentCustomPageID,FirstCustomPageID:Integer;
    AllCustomPages,CustomPagesWithUnseenOptions:String;
    HasUnseenComponents:Boolean;

    // Previous Git for Windows version (if upgrading)
    PreviousGitForWindowsVersion:String;

    // Wizard page and variables for the Editor options.
    EditorPage:TInputFileWizardPage;
    CbbEditor:TNewComboBox;
    LblEditor:array[GE_Nano..GE_CustomEditor] of array of TLabel;
    EditorAvailable:array[GE_Nano..GE_CustomEditor] of Boolean;
    SelectedEditor:Integer;

    VisualStudioCodeUserInstallation:Boolean;
    VisualStudioCodeInsidersUserInstallation:Boolean;
    SublimeTextUserInstallation:Boolean;
    VSCodiumUserInstallation:Boolean;

    NotepadPlusPlusPath:String;
    VisualStudioCodePath:String;
    VisualStudioCodeInsidersPath:String;
    SublimeTextPath:String;
    AtomPath:String;
    VSCodiumPath:String;
    CustomEditorPath:String;
    CustomEditorOptions:String;

    // Wizard page and variables for the Default Branch options.
    DefaultBranchPage:TWizardPage;
    RdbDefaultBranch:array[DB_Unspecified..DB_Manual] of TRadioButton;
    EdtDefaultBranch:TEdit;

    // Wizard page and variables for the Path options.
    PathPage:TWizardPage;
    RdbPath:array[GP_BashOnly..GP_CmdTools] of TRadioButton;

    // Wizard page and variables for the SSH options.
    PuTTYPage:TWizardPage;
    RdbSSH:array[GS_OpenSSH..GS_Plink] of TRadioButton;
    EdtPlink:TEdit;
    TortoisePlink:TCheckBox;

    // Wizard page and variables for the HTTPS implementation (cURL) settings.
    CurlVariantPage:TWizardPage;
    RdbCurlVariant:array[GC_OpenSSL..GC_WinSSL] of TRadioButton;

    // Wizard page and variables for the line ending conversion options.
    CRLFPage:TWizardPage;
    RdbCRLF:array[GC_LFOnly..GC_CRLFCommitAsIs] of TRadioButton;

    // Wizard page and variables for the terminal emulator settings.
    BashTerminalPage:TWizardPage;
    RdbBashTerminal:array[GB_MinTTY..GB_ConHost] of TRadioButton;

    // Wizard page and variables for the `git pull` options.
    GitPullBehaviorPage:TWizardPage;
    RdbGitPullBehavior:array[GP_GitPullMerge..GP_GitPullFFOnly] of TRadioButton;

    // Wizard page and variables for the credential manager options.
    GitCredentialManagerPage:TWizardPage;
    RdbGitCredentialManager:array[GCM_None..GCM_Core] of TRadioButton;

    // Wizard page and variables for the extra options.
    ExtraOptionsPage:TWizardPage;
    RdbExtraOptions:array[GP_FSCache..GP_Symlinks] of TCheckBox;

#ifdef HAVE_EXPERIMENTAL_OPTIONS
    // Wizard page and variables for the experimental options.
    ExperimentalOptionsPage:TWizardPage;
    RdbExperimentalOptions:array[GP_BuiltinDifftool..GP_EnableFSMonitor] of TCheckBox;
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
    ProcessesRefresh,ContinueButton,TestCustomEditorButton:TButton;
    OnlyShowNewOptions:TCheckBox;
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
    Command:String;
    RootKey,i:Integer;
    Keys:TArrayOfString;
begin

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

var
    BuiltinFSMonitorStopOption,AlreadyHandledFSMonitorPaths:String;

// Returns true if at least one FSMonitor daemon was shut down successfully
function ShutdownFSMonitorDaemons():Boolean;
var
    FindRec:TFindRec;
    Path,Str:String;
    Len,i:Integer;
begin
    Result:=False;
#ifdef WITH_EXPERIMENTAL_BUILTIN_FSMONITOR
    if (BuiltinFSMonitorStopOption='(huh?)') then
        Exit;
    if not FindFirst('\\.\pipe\*',FindRec) then
        Exit;
    if (AlreadyHandledFSMonitorPaths='') then
        AlreadyHandledFSMonitorPaths:=#0;
    repeat
        if WildcardMatch(FindRec.Name,'*\fsmonitor--daemon.ipc') or WildcardMatch(FindRec.Name,'*\.git\fsmonitor') then begin
            if (Pos(#0+FindRec.Name+#0,AlreadyHandledFSMonitorPaths)>0) then
                Continue;
            AlreadyHandledFSMonitorPaths:=AlreadyHandledFSMonitorPaths+FindRec.Name+#0;

            // An earlier `fsmonitor--daemon` iteration called it `--stop`, not `stop`;
            // Find out which form to use.
            if (BuiltinFSMonitorStopOption='') then begin
                BuiltinFSMonitorStopOption:='(huh?)';
                Path:=ExpandConstant('{tmp}\fsmonitor--help.err');
                if not Exec(ExpandConstant('{sys}\cmd.exe'),'/D /C ""'+AppDir+'\cmd\git.exe" fsmonitor--daemon -h 2>"'+Path+'""','',SW_HIDE,ewWaitUntilTerminated,i) or (i<>129) then begin
                    if (i<>1) and (i<>127) then // Suppress message if `git.exe` was not found, or if it does not know about the built-in FSMonitor
                        LogError('Could not get FSMonitor help:'+#13+ReadFileAsString(Path)+IntToStr(i));
                    Exit;
                end else begin
                    Str:=ReadFileAsString(Path);
                    i:=Pos('stop'+#10,Str);
                    if (i=0) then begin
                        LogError('Could not determine stop option from:'+#13+Str);
                        Exit;
                    end;
                    if (i>2) and (Str[i-1]='-') and (Str[i-2]='-') then
                        BuiltinFSMonitorStopOption:='--stop'
                    else
                        BuiltinFSMonitorStopOption:='stop';
                end;
                Str:='';
            end;

            // The colon was replaced with an underscore by the FSMonitor daemon
            Len:=Length(FindRec.Name);
            if WildcardMatch(FindRec.Name,'*\fsmonitor--daemon.ipc') then
                Len:=Len-22
            else
                Len:=Len-10;
            Path:=Copy(FindRec.Name,1,Len);
            if (Length(Path)>2) and (Path[2]='_') then
                Path[2]:=':';

            if ExecSilently('"'+AppDir+'\cmd\git.exe" -C "'+Path+'" fsmonitor--daemon '+BuiltinFSMonitorStopOption,'fsmonitor-stop','Could not stop FSMonitor daemon in '+Path) then
                Result:=True;
        end;
    until not FindNext(FindRec);
#endif
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
    if (AppDir='') then begin
        SetArrayLength(Processes,0);
        Exit;
    end;

    // Use the Restart Manager API when installing the shell extension.
    AppendToArray(Modules,AppDir+'\usr\bin\msys-2.0.dll');
    AppendToArray(Modules,AppDir+'\{#MINGW_BITNESS}\bin\tcl85.dll');
    AppendToArray(Modules,AppDir+'\{#MINGW_BITNESS}\bin\tk85.dll');
    AppendToArray(Modules,AppDir+'\{#MINGW_BITNESS}\bin\tcl86.dll');
    AppendToArray(Modules,AppDir+'\{#MINGW_BITNESS}\bin\tk86.dll');
    AppendToArray(Modules,AppDir+'\{#MINGW_BITNESS}\bin\zlib1.dll');
    AppendToArray(Modules,AppDir+'\{#MINGW_BITNESS}\libexec\git-core\zlib1.dll');
    SessionHandle:=FindProcessesUsingModules(Modules,Processes);

    if (GetArrayLength(Processes)>0) and ShutdownFSMonitorDaemons() then begin
        // We potentially shut down at least one process, refresh again
        RmEndSession(SessionHandle);
        SessionHandle:=FindProcessesUsingModules(Modules,Processes);
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

function ShellQuote(Value:String):String;
begin
    // Sadly, we cannot use the '\'' trick used throughout Git's
    // source code, as InnoSetup quotes those in a way that
    // git.exe does not understand them.
    //
    // So we try to imitate quote_arg_msvc() in Git's
    // compat/mingw.c instead: \ => \\, followed by " => \",
    // then surround with double quotes.
    StringChangeEx(Value,#92,#92+#92,True);
    StringChangeEx(Value,#34,#92+#34,True);
    Result:=#34+Value+#34;
end;

function GitSystemConfigSet(Key,Value:String):Boolean;
var
    i:Integer;
    OutPath,ErrPath:String;
begin
    OutPath:=ExpandConstant('{tmp}\config-set.out');
    ErrPath:=ExpandConstant('{tmp}\config-set.err');
    if (Value=#0) then begin
        if Exec(ExpandConstant('{cmd}'),'/D /C .\{#MINGW_BITNESS}\bin\git.exe config --system --unset '+Key+' >'+#34+OutPath+#34+' 2>'+#34+ErrPath+#34,
                AppDir,SW_HIDE,ewWaitUntilTerminated,i) And ((i=0) Or (i=5)) then
            // exit code 5 means it was already unset, so that's okay
            Result:=True
        else begin
            LogError('Unable to unset system config "'+Key+'": exit code '+IntToStr(i)+#13+#10+ReadFileAsString(OutPath)+#13+#10+'stderr:'+#13+#10+ReadFileAsString(ErrPath));
            Result:=False
        end
    end else if Exec(ExpandConstant('{cmd}'),'/D /C .\{#MINGW_BITNESS}\bin\git.exe config --system '+ShellQuote(Key)+' '+ShellQuote(Value)+' >'+#34+OutPath+#34+' 2>'+#34+ErrPath+#34,
                AppDir,SW_HIDE,ewWaitUntilTerminated,i) And (i=0) then
        Result:=True
    else begin
        LogError('Unable to set system config "'+Key+'":="'+Value+'": exit code '+IntToStr(i)+#13+#10+ReadFileAsString(OutPath)+#13+#10+'stderr:'+#13+#10+ReadFileAsString(ErrPath));
        Result:=False;
    end;
end;

procedure RecordInferredDefault(Key,Value:String);
var
    i:Integer;
begin
    i:=InferredDefaultKeys.IndexOf(Key); // cannot use .Find because the list is not sorted
    if (i>=0) then
        InferredDefaultValues[i]:=Value
    else begin
        i:=InferredDefaultKeys.Add(Key);
        InferredDefaultValues.Add(Value)
    end;
end;

function GetDefaultsFromGitConfig(WhichOne:String):Boolean;
var
    ExtraOptions,TmpFile,Key,Value:String;
    FileContents:AnsiString;
    Values:TArrayOfString;
    c,i,j,k:Integer;
begin
    case WhichOne of
    'ProgramData': ExtraOptions:='-f "'+ExpandConstant('{commonappdata}\Git\config')+'"';
    'system': ExtraOptions:='--system';
    else
        begin
            LogError('Invalid config type: '+WhichOne);
            Result:=False;
            Exit
        end
    end;

    TmpFile:=ExpandConstant('{tmp}\git-config-get.txt');
    if not Exec(ExpandConstant('{cmd}'),'/D /C .\{#MINGW_BITNESS}\bin\git.exe config -l -z '+ExtraOptions+' >'+#34+TmpFile+#34,
                AppDir,SW_HIDE,ewWaitUntilTerminated,i) then begin
        if FileExists(AppDir+ExpandConstant('\{#MINGW_BITNESS}\bin\git.exe')) then
            LogError('Unable to get system config')
        else
            // The previous directory went poof
            SaveStringToFile(TmpFile,'',False)
    end;

    if not LoadStringFromFile(TmpFile,FileContents) then begin
        LogError('Could not read '+#34+TmpFile+#34);
        Result:=False;
        Exit;
    end;

    if not DeleteFile(TmpFile) then begin
        LogError('Could not read '+#34+TmpFile+#34);
        Result:=False;
        Exit;
    end;

    // Split NUL-delimited key/value pairs, extract LF that denotes end of key
    Value:=FileContents;
    i:=1; j:=i; k:=i;
    while (j<=Length(FileContents)) do begin
        c:=Ord(FileContents[j]);
        if (c=10) then
            k:=j
        else if (c=0) then begin
            if (i<>k) then begin // Ignore keys without values
                Key:=Copy(FileContents,i,k-i);
                Value:=Copy(FileContents,k+1,j-k-1);
                case Key of
                    'http.sslbackend':
                        case Value of
                            'schannel': RecordInferredDefault('CURL Option','WinSSL');
                            'openssl': RecordInferredDefault('CURL Option','OpenSSL');
                        end;
                    'core.autocrlf':
                        case Value of
                            'true': RecordInferredDefault('CRLF Option','CRLFAlways');
                            'false': RecordInferredDefault('CRLF Option','CRLFCommitAsIs');
                            'input': RecordInferredDefault('CRLF Option','LFOnly');
                        end;
                    'core.fscache':
                        case Value of
                            'true': RecordInferredDefault('Performance Tweaks FSCache','Enabled');
                            'false': RecordInferredDefault('Performance Tweaks FSCache','Disabled');
                        end;
                    'credential.helper':
                        case Value of
                            'manager': RecordInferredDefault('Use Credential Manager','Enabled');
                            'manager-core': RecordInferredDefault('Use Credential Manager','Core');
                        else RecordInferredDefault('Use Credential Manager','Disabled');
                        end;
                    'core.symlinks':
                        case Value of
                            'true': RecordInferredDefault('Enable Symlinks','Enabled');
                            'false': RecordInferredDefault('Enable Symlinks','Disabled');
                        end;
                    'pull.ff':
                        case Value of
                            'only': RecordInferredDefault('Git Pull Behavior Option','FFOnly');
                        end;
                    'pull.rebase':
                        case Value of
                            'true': RecordInferredDefault('Git Pull Behavior Option','Rebase');
                            'false': RecordInferredDefault('Git Pull Behavior Option','Merge');
                        end;
                end;
            end;
            i:=j+1;
            j:=i;
            k:=i;
        end;
        j:=j+1;
    end;

    Result:=True;
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
            Result:=Ord(CurrentVersion[i])-Ord(PreviousVersion[j]);
            if (Result=0) then begin
                // skip identical non-numerical characters
                i:=i+1;
                j:=j+1;
                Continue;
            end;
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

function CountDots(S:String):Integer;
var
    i:Integer;
begin
    Result:=0;
    for i:=1 to Length(S) do
        if (S[i]=#46) then
            Result:=Result+1;
end;

var
    PreviousGitVersion:String;
    PreviousGitVersionInitialized:Boolean;

function GetPreviousGitVersion():String;
var
    Path:String;
    i:Integer;
begin
    if not PreviousGitVersionInitialized then begin
        PreviousGitVersionInitialized:=True;
        if (RegQueryStringValue(HKEY_LOCAL_MACHINE,'Software\GitForWindows','InstallPath',Path))
                and (Exec(ExpandConstant('{cmd}'),'/d /c ""'+Path+'\cmd\git.exe" version >"'+ExpandConstant('{tmp}')+'\previous.version""','',SW_HIDE,ewWaitUntilTerminated,i))
                and (i=0) then begin
            PreviousGitVersion:=ReadFileAsString(ExpandConstant('{tmp}\previous.version'));
        end;
    end;
    Result:=PreviousGitVersion;
end;

function IsDowngrade(CurrentVersion:String):Boolean;
begin
    Result:=(VersionCompare(CurrentVersion,PreviousGitForWindowsVersion)<0);
#ifdef GIT_VERSION
    if Result or (CountDots(CurrentVersion)>3) or (CountDots(PreviousGitForWindowsVersion)>3) then begin
        // maybe the previous version was a prerelease (prereleases have five numbers: v2.24.0-rc1.windows.1 reduces to '2.24.0.1.1')?
        CurrentVersion:='{#GIT_VERSION}';
        Result:=(VersionCompare(CurrentVersion,GetPreviousGitVersion())<0);
    end;
#endif
end;

function IsUpgrade(CurrentVersion:String):Boolean;
var
    PreviousVersion:String;
begin
    PreviousVersion:=PreviousGitForWindowsVersion;
    // It is not an upgrade:
    // - if there was no previous version
    // - or if the previous version is identical to the current one (re-install)
    // - or if it is actually a downgrade
    Result:=(PreviousVersion<>'') and (CurrentVersion<>PreviousVersion) and not IsDowngrade(CurrentVersion)
end;

{ Represent a set as a string of comma-separated values }
function IsInSet(var ASet:String;Value:Integer):Boolean;
begin
    Result:=(Pos(','+IntToStr(Value)+',',ASet)>0);
end;

procedure AddToSet(var ASet:String;Value:Integer);
begin
    if ASet='' then
        ASet:=',';
    if not IsInSet(ASet,Value) then
        ASet:=ASet+IntToStr(Value)+',';
end;

function IsLastPageBeforeInstall(PageID:Integer):Boolean;
begin
    if (OnlyShowNewOptions.Checked) then begin
        // The "Select Program Group" page is suppressed when
        // re-installing/upgrading/downgrading, but not the Components page.
        if (PageID<wpSelectComponents) and HasUnseenComponents then
            PageID:=wpSelectComponents
        else if (PageID<=wpSelectProgramGroup) then
            PageID:=FirstCustomPageID
        else
            PageID:=PageID+1;
        while (PageID<=PageIDBeforeInstall) and not IsInSet(CustomPagesWithUnseenOptions,PageID) do
            PageID:=PageID+1;
        Result:=(PageID>PageIDBeforeInstall);
    end else
        Result:=(PageID=PageIDBeforeInstall);
end;

procedure AdjustNextButtonLabel(Sender:TObject);
begin
    if (CurrentCustomPageID=ProcessesPage.ID) then
        WizardForm.NextButton.Caption:=SetupMessage(msgButtonInstall)
    else if (CurrentCustomPageID=wpFinished) then
        // Always let the final page's button read "Finish"
        WizardForm.NextButton.Caption:=SetupMessage(msgButtonFinish)
    else if IsLastPageBeforeInstall(CurrentCustomPageID) then begin
        RefreshProcessList(NIL);
        if GetArrayLength(Processes)=0 then
            WizardForm.NextButton.Caption:=SetupMessage(msgButtonInstall)
        else
            WizardForm.NextButton.Caption:=SetupMessage(msgButtonNext);
    end else
        WizardForm.NextButton.Caption:=SetupMessage(msgButtonNext);
end;

function InitializeSetup:Boolean;
var
    CurrentVersion,Msg:String;
    ErrorCode:Integer;
begin
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
    // The Windows Terminal profile is new in v2.32.0
    HasUnseenComponents:=IsUpgrade('2.32.0');
    if HasUnseenComponents then
        AddToSet(CustomPagesWithUnseenOptions,wpSelectComponents);
#if APP_VERSION!='0-test'
    if Result and not ParamIsSet('ALLOWDOWNGRADE') then begin
        CurrentVersion:=ExpandConstant('{#APP_VERSION}');
        if IsDowngrade(CurrentVersion) then begin
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

    // Warn about switching away from VFS-enabled Git
    if Result and (Pos('.vfs.','{#GIT_VERSION}')=0) and (Pos('.vfs.',GetPreviousGitVersion())>0) then
        if SuppressibleMsgBox('The VFS for Git-aware flavor of Git for Windows is currently installed.'+#13+'Switching away from that flavor might break your Scalar/VFS for Git enlistments.'+#13+'Do you still want to switch?',mbConfirmation,MB_YESNO or MB_DEFBUTTON2,IDNO)=IDNO then
            Result:=False;
#endif
end;

procedure RecordChoice(PreviousDataKey:Integer;Key,Data:String);
begin
    ChosenOptions:=ChosenOptions+Key+': '+Data+#13+#10;
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
    i:Integer;
begin
    NoSpaces:=Key;
    StringChangeEx(NoSpaces,' ','',True);

    // A side effect of ReplayChoice is to collect a set of pages that have options on them, and the subset
    // of those pages have _new_ options (options whose values have no previously-set value)
    AddToSet(AllCustomPages,CurrentCustomPageID);

    // Interpret /o:PathOption=Cmd and friends
    Result:=ExpandConstant('{param:o:'+NoSpaces+'| }');
    if Result<>' ' then
        Log('Parameter '+Key+'='+Result+' set via command-line')
    else if ShouldLoadInf then
        // Use settings from the user provided INF.
        // .inf files do not like keys with spaces.
        Result:=LoadInfString('Setup',NoSpaces,Default)
    else begin
        i:=InferredDefaultKeys.IndexOf(Key); // cannot use .Find because the list is not sorted
        if (i>=0) then
            Result:=InferredDefaultValues[i]
        else
            // Restore the settings chosen during a previous install.
            Result:=GetPreviousData(Key,Default);
            // Check to see if this result was the default, or was previously set.
            // If it was the default, the user has not seen this option yet.
            if GetPreviousData(Key,'z'+Result)<>Result then
                AddToSet(CustomPagesWithUnseenOptions,CurrentCustomPageID)
    end;
end;

function DetectNetFxVersion:Cardinal;
begin
    // We are only interested in version v4.5.1 or later, therefore it
    // is enough to only use the 4.5 method described in
    // https://docs.microsoft.com/en-us/dotnet/framework/migration-guide/how-to-determine-which-versions-are-installed
    if IsWin64 then begin
        if (
            not RegQueryDWordValue(HKLM64,'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full','Release',Result)
            and not RegQueryDWordValue(HKLM32,'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full','Release',Result)
        ) then
            Result:=0;
    end else begin
        if not RegQueryDWordValue(HKLM32,'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full','Release',Result) then
            Result:=0;
    end;
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
    if not ExecAsOriginalUser(ExpandConstant('{cmd}'),ExpandConstant('/d /c net session >"{tmp}\net-session.txt"'),'',SW_HIDE,ewWaitUntilTerminated,ResultCode) then
        ResultCode:=-1;
    Result:=(ResultCode=0);
end;

function EnableSymlinksByDefault():Boolean;
var
    SymlinksForRegularUsers:Cardinal;
    Root:Integer;
    ResultCode:Integer;
    Version:TWindowsVersion;
begin

    RegQueryDwordValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock', 'AllowDevelopmentWithoutDevLicense', SymlinksForRegularUsers)
    GetWindowsVersionEx(Version);

    if ((SymlinksForRegularUsers=1) and (Version.Build>=14972)) then begin
        // awesome, Developer mode enabled, and we're in Creators update, we can create symlinks w/o being admin
        Log('Symbolic links enabled, machine has Developer Mode enabled');
        Result:=True
        Exit;
    end;

    if IsOriginalUserAdmin then begin
        // detection only works when we're not running as admin
        Log('Symbolic link permission detection failed: running as admin');
        Result:=False;
    end else begin
        // maybe rights assigned through group policy without enabling developer mode?
        // let's test by creating a symbolic link
        ExecAsOriginalUser(ExpandConstant('{cmd}'),ExpandConstant('/d /c mklink /d "{tmp}\symbolic link" "{tmp}" >"{tmp}\symlink test.txt"'),'',SW_HIDE,ewWaitUntilTerminated,ResultCode);
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
    CurrentCustomPageID:=Result.ID;
    if (FirstCustomPageID=0) then
        FirstCustomPageID:=Result.ID;
    PrevPageID:=Result.ID;
    TabOrder:=0;
    Top:=8;
    Left:=4;
end;

function CreateFilePage(var PrevPageID:Integer;const Caption,Description,SubCaption:String;var TabOrder,Top,Left:Integer):TInputFileWizardPage;
begin
    Result:=CreateInputFilePage(PrevPageID,Caption,Description,SubCaption);
    CurrentCustomPageID:=Result.ID;
    if (FirstCustomPageID=0) then
        FirstCustomPageID:=Result.ID;
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
                if (Description[1]=#10) then
                    RowPrefix:=RowPrefix+SubString(Description,2,i-2)
                else
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
                if Description[1]=#10 then
                    RowPrefix:=RowPrefix+SubString(Description,2,i-2)
                else
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

procedure SetInputFileTop(Page:TInputFileWizardPage;Offset:Integer);
begin
    Page.Edits[0].Top:=Offset+Page.Edits[0].Top;
    Page.Buttons[0].Top:=Offset+Page.Buttons[0].Top;
    Page.PromptLabels[0].Top:=Offset+Page.PromptLabels[0].Top;
    TestCustomEditorButton.Top:=Page.Buttons[0].Top+Page.Buttons[0].Height+ScaleY(3);
end;

procedure SetInputFileState(Page:TInputFileWizardPage;State:Boolean);
begin
    Page.Edits[0].Enabled:=State;
    Page.Buttons[0].Enabled:=State;
    Page.PromptLabels[0].Enabled:=State;
    TestCustomEditorButton.Enabled:=State;
end;

procedure SetInputFileVisible(Page:TInputFileWizardPage;Visible:Boolean);
begin
    Page.Edits[0].Visible:=Visible;
    Page.Buttons[0].Visible:=Visible;
    Page.PromptLabels[0].Visible:=Visible;
    TestCustomEditorButton.Visible:=Visible;
end;

{
    Find the position of the next of the three specified tokens (if any).
    Returns 0 if none were found.
}

function PathIsValidExecutable(var Path: String):Boolean;
var
    Env,Path2,Ext:String;
    PathExt:String;
    ExtArray:TArrayOfString;
    i,Len:Integer;
    j:Integer;
    ExtensionFlag:Boolean;
begin
    Result:=False;
    if Path='' then
        Exit;

    (* If Path contains only the file name, search through PATH *)
    if Pos('\',Path)=0 then begin
        Env:=GetEnv('PATH')+';';
        repeat
            i:=Pos(';',Env);
            Path2:=Copy(Env,1,i-1)+'\'+Path;
            Env:=Copy(Env,i+1,Length(Env));
            if PathIsValidExecutable(Path2) then begin
                Path:=Path2;
                Result:=True;
            end;
        until Result or (Env='');
        Exit;
    end;

    (*
     * If Path lacks a file extension, look through PATHEXT, otherwise
     * verify that the file extension is in PATHEXT.
     *)
    Env:=GetEnv('PATHEXT')+';';
    Ext:=ExtractFileExt(Path);
    if Ext<>'' then
        Result:=(Pos(';'+Uppercase(Ext)+';',';'+Uppercase(Env))>0) and FileExists(Path)
    else begin
        repeat
            i:=Pos(';',Env);
            Path2:=Path+Copy(Env,1,i-1);
            Env:=Copy(Env,i+1,Length(Env));
            if FileExists(Path2) then begin
                Path:=Path2;
                Result:=True;
            end;
        until Result or (Env='');
    end
end;

procedure TestCustomEditor(Sender:TObject);
var
    InputText,OutputText:AnsiString;
    TmpFile:String;
    Res:Longint;
    CustomEditorExt:String;
    Show:Integer;
begin
    if not PathIsValidExecutable(CustomEditorPath) then begin
        Wizardform.NextButton.Enabled:=False;
        SuppressibleMsgBox('Not a valid executable: "'+CustomEditorPath+'"',mbError,MB_OK,IDOK);
        Exit;
    end;

    TmpFile:=ExpandConstant('{tmp}\editor-test.txt');
    InputText:='Please modify this text, e.g. delete it, then save it and exit the editor.'
    SaveStringToFile(TmpFile,InputText,False);

    CustomEditorExt:=ExtractFileExt(CustomEditorPath);
    if (CompareText(CustomEditorExt,'.bat')=0) or (CompareText(CustomEditorExt,'.cmd')=0) then
        Show:=SW_HIDE
    else
        Show:=SW_SHOW;

    if not ShellExecAsOriginalUser('',CustomEditorPath,CustomEditorOptions+' "'+TmpFile+'"','',Show,ewWaitUntilTerminated,Res) then begin
        Wizardform.NextButton.Enabled:=False;
        SuppressibleMsgBox('Could not launch: "'+CustomEditorPath+'"',mbError,MB_OK,IDOK);
        Exit;
    end;
    if (Res<>0) then begin
        Wizardform.NextButton.Enabled:=False;
        SuppressibleMsgBox('Exited with failure: "'+CustomEditorPath+'"',mbError,MB_OK,IDOK);
        Exit;
    end;

    if not LoadStringFromFile(TmpFile,OutputText) then begin
        Wizardform.NextButton.Enabled:=False;
        SuppressibleMsgBox('Could not read "'+TmpFile+'"',mbError,MB_OK,IDOK);
        Exit;
    end;

    if not DeleteFile(TmpFile) then begin
        Wizardform.NextButton.Enabled:=False;
        SuppressibleMsgBox('Could not delete "'+TmpFile+'"',mbError,MB_OK,IDOK);
        Exit;
    end;

    if InputText=OutputText then begin
        Wizardform.NextButton.Enabled:=False;
        SuppressibleMsgBox('The file was not modified!'+#13+#10+'Does the editor require an option to wait?',mbError,MB_OK,IDOK);
        Exit;
    end;

    Wizardform.NextButton.Enabled:=True;
    SuppressibleMsgBox('Success!',mbInformation,MB_OK,IDOK);
end;

procedure EnableNextButtonOnValidExecutablePath(Path: String);
begin
    if PathIsValidExecutable(Path) then
        Wizardform.NextButton.Enabled:=True
    else
        Wizardform.NextButton.Enabled:=False;
end;

procedure UpdateCustomEditorPath(Sender: TObject);
var
    PathLength:Integer;
    Path:String;
begin
    (*
     * Add space at the end of the string in order to rule out paths like
     * 'FOO.exeBAR', but allow paths like 'FOO.exe --BAR'.
     *)

    Path:=EditorPage.Values[0]+' ';
    if WildcardMatch(Path, '"*" *') then begin
        Path:=Copy(Path,2,Length(Path));
        PathLength:=Pos(#34,Path)-1;
        CustomEditorPath:=Copy(Path,1,PathLength);
        CustomEditorOptions:=Copy(Path,PathLength+3,Length(Path)-PathLength-3)
    end
    else begin
        Path:=EditorPage.Values[0];
        PathLength:=Pos(' ',Path)-1;
        if PathIsValidExecutable(Path) or (PathLength=0) then begin
            CustomEditorPath:=Path;
            CustomEditorOptions:=''
        end else begin
            CustomEditorPath:=Copy(Path,1,PathLength);
            CustomEditorOptions:=Copy(Path,PathLength+1,Length(Path))
        end
    end;

    (*
     * If the specified path does not contain '.exe' at the end,
     * CustomEditorPath will be formed with the first three letters of Path,
     * but that should not be a problem because the next button is enabled
     * only when PathIsValidExecutable() returns True.
     *)
    EnableNextButtonOnValidExecutablePath(CustomEditorPath);
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
    if (SelectedEditor=GE_CustomEditor) then begin
        SetInputFileState(EditorPage,True);
        SetInputFileVisible(EditorPage,True);
        EnableNextButtonOnValidExecutablePath(CustomEditorPath);
    end else begin
        SetInputFileState(EditorPage,False);
        SetInputFileVisible(EditorPage,False);
        Wizardform.NextButton.Enabled:=EditorAvailable[SelectedEditor];
    end;
end;

procedure DefaultBranchOptionChanged(Sender: TObject);
begin
    EdtDefaultBranch.Enabled:=RdbDefaultBranch[DB_Manual].Checked;
    if EdtDefaultBranch.Enabled and (WizardForm.CurPageID=DefaultBranchPage.ID) then
        // If the manual option was just checked, move the focus to the text box
        WizardForm.ActiveControl:=EdtDefaultBranch;
end;

procedure DefaultBranchNameChanged(Sender: TObject);
var
    IsValidBranchName:Boolean;
begin
    if EdtDefaultBranch.Enabled then begin
        // Disallow illegal ref names
        with EdtDefaultBranch do
            IsValidBranchName:=(Text<>'') and (Text<>'@') and
                    (Pos('..',Text)=0) and (Pos('@{',Text)=0) and (Pos('//',Text)=0) and
                    (Pos(#8,Text)=0) and (Pos(' ',Text)=0) and (Pos(':',Text)=0) and
                    (Pos('?',Text)=0) and (Pos('[',Text)=0) and (Pos('\',Text)=0) and
                    (Pos('^',Text)=0) and (Pos('~',Text)=0) and (Pos(#127,Text)=0) and
                    (Pos('/.','/'+Text)=0) and (Pos('./',Text+'/')=0) and (Pos('.lock/',Text+'/')=0);
        if (WizardForm.CurPageID=DefaultBranchPage.ID) then
            Wizardform.NextButton.Enabled:=IsValidBranchName;
        if IsValidBranchName then
            EdtDefaultBranch.Color:=clWhite
        else
            EdtDefaultBranch.Color:=clRed;
    end;
end;

procedure QueryUninstallValues; forward;

procedure InitializeWizard;
var
    PrevPageID,TabOrder,TopOfLabels,Top,Left:Integer;
    PuTTYSessions,EnvSSH:TArrayOfString;
    BtnPlink:TButton;
    Data:String;
    LblInfo:TLabel;
begin
    InferredDefaultKeys:=TStringList.Create;
    InferredDefaultValues:=TStringList.Create;
    QueryUninstallValues();
    AppDir:=UninstallAppPath;
    GetDefaultsFromGitConfig('ProgramData');
    GetDefaultsFromGitConfig('system');

    ChosenOptions:='';

    PrevPageID:=wpSelectProgramGroup;

    (*
     * Allow skipping pages that contain only previously-seen options.
     * For upgrades, default to skipping.
     *)
    OnlyShowNewOptions:=TCheckBox.Create(WizardForm);
    with OnlyShowNewOptions do begin
        Parent:=WizardForm;
        Caption:='&Only show new options';
        Width:=GetTextWidth(Caption,Font)+20; // 20 is the estimated width of the checkbox itself
        Left:=WizardForm.BackButton.Left-Width-(WizardForm.CancelButton.Left-WizardForm.NextButton.Left-WizardForm.NextButton.Width);
        Checked:=IsUpgrade(ExpandConstant('{#APP_VERSION}'));
        OnClick:=@AdjustNextButtonLabel;
        Height:=WizardForm.CancelButton.Height;
        Top:=WizardForm.CancelButton.Top;
    end;
    if (PreviousGitForWindowsVersion='') then
        OnlyShowNewOptions.Hide;

    (*
     * Create a custom page for configuring the default Git editor.
     *)

    EditorPage:=CreateFilePage(PrevPageID,'Choosing the default editor used by Git','Which editor would you like Git to use?','',TabOrder,Top,Left);

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
    EditorAvailable[GE_VisualStudioCode]:=RegQueryStringValue(HKEY_LOCAL_MACHINE,'SOFTWARE\Classes\Applications\Code.exe\shell\open\command','',VisualStudioCodePath);
    if (not EditorAvailable[GE_VisualStudioCode]) then begin
        EditorAvailable[GE_VisualStudioCode]:=RegQueryStringValue(HKEY_CURRENT_USER,'Software\Classes\Applications\Code.exe\shell\open\command','',VisualStudioCodePath);
        VisualStudioCodeUserInstallation:=True;
    end;
    EditorAvailable[GE_VisualStudioCodeInsiders]:=RegQueryStringValue(HKEY_LOCAL_MACHINE,'SOFTWARE\Classes\Applications\Code - Insiders.exe\shell\open\command','',VisualStudioCodeInsidersPath);
    if (not EditorAvailable[GE_VisualStudioCodeInsiders]) then begin
        EditorAvailable[GE_VisualStudioCodeInsiders]:=RegQueryStringValue(HKEY_CURRENT_USER,'Software\Classes\Applications\Code - Insiders.exe\shell\open\command','',VisualStudioCodeInsidersPath);
        VisualStudioCodeInsidersUserInstallation:=True;
    end;
    SublimeTextPath:=ExpandConstant('{pf}\Sublime Text\subl.exe');
    EditorAvailable[GE_SublimeText]:=PathIsValidExecutable(SublimeTextPath);
    if (not EditorAvailable[GE_SublimeText]) then begin
        SublimeTextPath:=ExpandConstant('{pf}\Sublime Text 3\subl.exe');
        EditorAvailable[GE_SublimeText]:=PathIsValidExecutable(SublimeTextPath);
        if (not EditorAvailable[GE_SublimeText]) then begin
            EditorAvailable[GE_SublimeText]:=RegQueryStringValue(HKEY_CURRENT_USER,'Software\Classes\Applications\sublime_text.exe\shell\open\command','',SublimeTextPath);
            SublimeTextUserInstallation:=True;
        end;
    end;
    EditorAvailable[GE_Atom]:=RegQueryStringValue(HKEY_CURRENT_USER,'Software\Classes\Applications\atom.exe\shell\open\command','',AtomPath);
    EditorAvailable[GE_CustomEditor]:=True;
    EditorAvailable[GE_VSCodium]:=RegQueryStringValue(HKEY_LOCAL_MACHINE,'SOFTWARE\Classes\Applications\VSCodium.exe\shell\open\command','',VSCodiumPath);
    if (not EditorAvailable[GE_VSCodium]) then begin
        EditorAvailable[GE_VSCodium]:=RegQueryStringValue(HKEY_CURRENT_USER,'Software\Classes\Applications\VSCodium.exe\shell\open\command','',VSCodiumPath);
        VSCodiumUserInstallation:=True;
    end;

    // Remove `" %1"` from end and unqote the string.
    if (EditorAvailable[GE_VisualStudioCode]) then
        // Extract <path> from "<path>" "%1"
        VisualStudioCodePath:=Copy(VisualStudioCodePath, 2, Length(VisualStudioCodePath) - 7);
    if (EditorAvailable[GE_VisualStudioCodeInsiders]) then
        // Extract <path> from "<path>" "%1"
        VisualStudioCodeInsidersPath:=Copy(VisualStudioCodeInsidersPath, 2, Length(VisualStudioCodeInsidersPath) - 7);
    if (EditorAvailable[GE_SublimeText]) and SublimeTextUserInstallation then
        // Extract <path> from "<path>" "%1"
        SublimeTextPath:=Copy(SublimeTextPath, 2, Length(SublimeTextPath) - 7);
    if (EditorAvailable[GE_Atom]) then
        // Extract <path> from "<path>" "%1"
        AtomPath:=Copy(AtomPath, 2, Length(AtomPath) - 7);
    if (EditorAvailable[GE_VSCodium]) then
        // Extract <path> from "<path>" "%1"
        VSCodiumPath:=Copy(VSCodiumPath, 2, Length(VSCodiumPath) - 7);

    // 1st choice
    Top:=TopOfLabels;
    CbbEditor.Items.Add('Use the Nano editor by default');
    Data:='<A HREF=https://www.nano-editor.org/dist/v2.8/nano.html>GNU nano</A> is a small and friendly text editor running in the console'+#13+'window.';
    if (not EditorAvailable[GE_NotepadPlusPlus] and not EditorAvailable[GE_VisualStudioCode] and not EditorAvailable[GE_VisualStudioCodeInsiders] and not EditorAvailable[GE_SublimeText] and not EditorAvailable[GE_Atom]) and not EditorAvailable[GE_VSCodium] then
        Data:=Data+#13+#13+'This is the recommended option for end users if no GUI editors are installed.';
    CreateItemDescription(EditorPage,Data,Top,Left,LblEditor[GE_Nano],False);
    EditorAvailable[GE_Nano]:=True;

    // 2nd choice
    Top:=TopOfLabels;
    CbbEditor.Items.Add('Use Vim (the ubiquitous text editor) as Git'+#39+'s default editor');
    CreateItemDescription(EditorPage,'The <A HREF=http://www.vim.org/>Vim editor</A>, while powerful, <A HREF=https://stackoverflow.blog/2017/05/23/stack-overflow-helping-one-million-developers-exit-vim/>can be hard to use</A>. Its user interface is'+#13+'unintuitive and its key bindings are awkward.'+#13+#13+'<RED>Note:</RED> Vim is the default editor of Git for Windows only for historical reasons, and'+#13+'it is highly recommended to switch to a modern GUI editor instead.'+#13+#13+'<RED>Note:</RED> This will leave the '+#39+'core.editor'+#39+' option unset, which will make Git fall back'+#13+'to the '+#39+'EDITOR'+#39+' environment variable. The default editor is Vim - but you'+#13+'may set it to some other editor of your choice.',Top,Left,LblEditor[GE_VIM],False);
    EditorAvailable[GE_VIM]:=True;

    // 3rd choice
    Top:=TopOfLabels;
    CbbEditor.Items.Add('Use Notepad++ as Git'+#39+'s default editor');
    CreateItemDescription(EditorPage,'<A HREF=https://notepad-plus-plus.org/>Notepad++</A> is a popular GUI editor that can be used by Git.'+#13+#13+'This editor is popular in part due to the vast number of available plugins;'+#13+'However, when configured via this option, Git will call Notepad++ with'+#13+'plugins disabled (to open the editor as quickly as possible).',Top,Left,LblEditor[GE_NotepadPlusPlus],False);

    // 4th choice
    Top:=TopOfLabels;
    CbbEditor.Items.Add('Use Visual Studio Code as Git'+#39+'s default editor');
    if (VisualStudioCodeUserInstallation=False) then
        CreateItemDescription(EditorPage,'<A HREF=https://code.visualstudio.com//>Visual Studio Code</A> is an Open Source, lightweight and powerful editor'+#13+'running as a desktop application. It comes with built-in support for JavaScript,'+#13+'TypeScript and Node.js and has a rich ecosystem of extensions for other'+#13+'languages (such as C++, C#, Java, Python, PHP, Go) and runtimes (such as'+#13+'.NET and Unity).'+#13+#13+'Use this option to let Git use Visual Studio Code as its default editor.',Top,Left,LblEditor[GE_VisualStudioCode],False)
    else
        CreateItemDescription(EditorPage,'<A HREF=https://code.visualstudio.com//>Visual Studio Code</A> is an Open Source, lightweight and powerful editor'+#13+'running as a desktop application. It comes with built-in support for JavaScript,'+#13+'TypeScript and Node.js and has a rich ecosystem of extensions for other'+#13+'languages (such as C++, C#, Java, Python, PHP, Go) and runtimes (such as'+#13+'.NET and Unity).'+#13+'<RED>(WARNING!) This will be installed only for this user.</RED>'+#13+#13+'Use this option to let Git use Visual Studio Code as its default editor.',Top,Left,LblEditor[GE_VisualStudioCode],False);

    // 5th choice
    Top:=TopOfLabels;
    CbbEditor.Items.Add('Use Visual Studio Code Insiders as Git'+#39+'s default editor');
    if (VisualStudioCodeInsidersUserInstallation=False) then
        CreateItemDescription(EditorPage,'<A HREF=https://code.visualstudio.com/insiders/>Visual Studio Code</A> is an Open Source, lightweight and powerful editor'+#13+'running as a desktop application. It comes with built-in support for JavaScript,'+#13+'TypeScript and Node.js and has a rich ecosystem of extensions for other'+#13+'languages (such as C++, C#, Java, Python, PHP, Go) and runtimes (such as'+#13+'.NET and Unity).'+#13+#13+'Use this option to let Git use Visual Studio Code Insiders as its default editor.',Top,Left,LblEditor[GE_VisualStudioCodeInsiders],False)
    else
        CreateItemDescription(EditorPage,'<A HREF=https://code.visualstudio.com/insiders/>Visual Studio Code</A> is an Open Source, lightweight and powerful editor'+#13+'running as a desktop application. It comes with built-in support for JavaScript,'+#13+'TypeScript and Node.js and has a rich ecosystem of extensions for other'+#13+'languages (such as C++, C#, Java, Python, PHP, Go) and runtimes (such as'+#13+'.NET and Unity).'+#13+'<RED>(WARNING!) This will be installed only for this user.</RED>'+#13+#13+'Use this option to let Git use Visual Studio Code Insiders as its default editor.',Top,Left,LblEditor[GE_VisualStudioCodeInsiders],False);

    // 6th choice
    Top:=TopOfLabels;
    CbbEditor.Items.Add('Use Sublime Text as Git'+#39+'s default editor');
    if (SublimeTextUserInstallation=False) then
        CreateItemDescription(EditorPage,'<A HREF=https://www.sublimetext.com/>Sublime text</A> is a lightweight editor which supports a great number'+#13+'of plugins.'+#13+#13+'Use this option to let Git use Sublime Text as its default editor.',Top,Left,LblEditor[GE_SublimeText],False)
    else
        CreateItemDescription(EditorPage,'<A HREF=https://www.sublimetext.com/>Sublime text</A> is a lightweight editor which supports a great number'+#13+'of plugins.'+#13+'<RED>(WARNING!) This will be installed only for this user.</RED>'+#13+#13+'Use this option to let Git use Sublime Text as its default editor.',Top,Left,LblEditor[GE_SublimeText],False);

    // 7th choice
    Top:=TopOfLabels;
    CbbEditor.Items.Add('Use Atom as Git'+#39+'s default editor');
    CreateItemDescription(EditorPage,'<A HREF=https://atom.io/>Atom</A> is an open source text editor which comes with builtin support'+#13+'for Git and Github.'+#13+'<RED>(WARNING!) This will be installed only for this user.</RED>'+#13+#13+'Use this option to let Git use Atom as its default editor.',Top,Left,LblEditor[GE_Atom],False);

    // 8th choice
    Top:=TopOfLabels;
    CbbEditor.Items.Add('Use VSCodium as Git'+#39+'s default editor');
    if (VSCodiumUserInstallation=False) then
        CreateItemDescription(EditorPage,'<A HREF=https://vscodium.com///>VSCodium</A> provides Free/Libre Open Source Software Binaries of VSCode with the same features, but without telemetry/tracking of Microsoft or any non-floss code parts. It comes with built-in support for JavaScript,'+#13+'TypeScript and Node.js and has a rich ecosystem of extensions for other'+#13+'languages (such as C++, C#, Java, Python, PHP, Go) and runtimes (such as'+#13+'.NET and Unity).'+#13+#13+'Use this option to let Git use VSCodium as its default editor.',Top,Left,LblEditor[GE_VSCodium],False)
    else
        CreateItemDescription(EditorPage,'<A HREF=https://vscodium.com///>VSCodium</A> provides Free/Libre Open Source Software Binaries of VSCode with the same features, but without telemetry/tracking of Microsoft or any non-floss code parts. It comes with built-in support for JavaScript,'+#13+'TypeScript and Node.js and has a rich ecosystem of extensions for other'+#13+'languages (such as C++, C#, Java, Python, PHP, Go) and runtimes (such as'+#13+'.NET and Unity).'+#13+'<RED>(WARNING!) This will be installed only for this user.</RED>'+#13+#13+'Use this option to let Git use VSCodium as its default editor.',Top,Left,LblEditor[GE_VSCodium],False);

    // 9th choice
    Top:=TopOfLabels;
    CbbEditor.Items.Add('Use Notepad as Git'+#39+'s default editor');
    CreateItemDescription(EditorPage,'<RED>(NEW!)</RED> Notepad is a simple GUI editor that comes with windows.',Top,Left,LblEditor[GE_Notepad],False);
    EditorAvailable[GE_Notepad]:=True;

    // 10th choice
    Top:=TopOfLabels;
    CbbEditor.Items.Add('Use Wordpad as Git'+#39+'s default editor');
    CreateItemDescription(EditorPage,'<RED>(NEW!)</RED> Wordpad is a basic word processor that comes with windows.'+#13+'It can also be used as a text editor.',Top,Left,LblEditor[GE_Wordpad],False);
    EditorAvailable[GE_Wordpad]:=True;

    // Custom choice
    Top:=TopOfLabels;
    CbbEditor.Items.Add('Select other editor as Git'+#39+'s default editor');
    CreateItemDescription(EditorPage,'Use this option to select the path to Git'+#39+'s default editor.',Top,Left,LblEditor[GE_CustomEditor],False);

    EditorPage.add('Location of editor (plus command-line options, if necessary):','Executable files|*.exe;*.cmd;*.bat|All files|*.*','.exe');
    TestCustomEditorButton:=TButton.Create(EditorPage);
    with TestCustomEditorButton do begin
        Parent:=EditorPage.Surface;
        Caption:='Test Custom Editor';
        Left:=ScaleX(Left+24);
        OnClick:=@TestCustomEditor;
        Width:=ScaleX(128);
        Height:=ScaleY(21);
    end;
    SetInputFileTop(EditorPage, ScaleY(Top) + ScaleY(CbbEditor.Height))
    EditorPage.Edits[0].OnChange:=@UpdateCustomEditorPath;
    SetInputFileState(EditorPage, False);
    SetInputFileVisible(EditorPage, False);

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
    'SublimeText': begin
            if EditorAvailable[GE_SublimeText] then
                CbbEditor.ItemIndex:=GE_SublimeText
            else
                CbbEditor.ItemIndex:=GE_VIM;
        end;
    'Atom': begin
            if EditorAvailable[GE_Atom] then
                CbbEditor.ItemIndex:=GE_Atom
            else
                CbbEditor.ItemIndex:=GE_VIM;
        end;
    'VSCodium': begin
            if EditorAvailable[GE_VSCodium] then
                CbbEditor.ItemIndex:=GE_VSCodium
            else
                CbbEditor.ItemIndex:=GE_VIM;
        end;
    'Notepad': CbbEditor.ItemIndex:=GE_Notepad;
    'Wordpad': CbbEditor.ItemIndex:=GE_Wordpad;
    'CustomEditor': begin
            CbbEditor.ItemIndex:=GE_CustomEditor;
            EditorPage.Values[0]:=ReplayChoice('Custom Editor Path','');
            (*
             * UpdateCustomEditorPath() will also check if the path is still available and
             * enable / disable the "Next" button.
             *)
            UpdateCustomEditorPath(NIL);
        end;
    else
        CbbEditor.ItemIndex:=GE_VIM;
    end;
    EditorSelectionChanged(NIL);

    (*
     * Create a custom page for modifying the default branch.
     *)

    DefaultBranchPage:=CreatePage(PrevPageID,'Adjusting the name of the initial branch in new repositories','What would you like Git to name the initial branch after "git init"?',TabOrder,Top,Left);

    // 1st choice
    RdbDefaultBranch[DB_Unspecified]:=CreateRadioButton(DefaultBranchPage,'Let Git decide','Let Git use its default branch name (currently: "{#DEFAULT_BRANCH_NAME}") for the initial branch'+#13+'in newly created repositories. The Git project <A HREF=https://sfconservancy.org/news/2020/jun/23/gitbranchname/>intends</A> to change this default to'+#13+'a more inclusive name in the near future.',TabOrder,Top,Left);
    RdbDefaultBranch[DB_Unspecified].OnClick:=@DefaultBranchOptionChanged;

    // 2nd choice
    RdbDefaultBranch[DB_Manual]:=CreateRadioButton(DefaultBranchPage,'Override the default branch name for new repositories','<RED>NEW!</RED> Many teams already renamed their default branches; common choices are'+#13+'"main", "trunk" and "development". Specify the name "git init" should use for the'+#13+'initial branch:',TabOrder,Top,Left);
    RdbDefaultBranch[DB_Manual].OnClick:=@DefaultBranchOptionChanged;

    // Text field for the overridden branch name
    Top:=Top-13;
    EdtDefaultBranch:=TEdit.Create(DefaultBranchPage);
    EdtDefaultBranch.Parent:=DefaultBranchPage.Surface;
    EdtDefaultBranch.Left:=ScaleX(Left+24);
    EdtDefaultBranch.Top:=ScaleY(Top);
    EdtDefaultBranch.Width:=ScaleX(158);
    EdtDefaultBranch.Height:=ScaleY(13);
    EdtDefaultBranch.TabOrder:=TabOrder;
    TabOrder:=TabOrder+1;
    EdtDefaultBranch.Text:='main';
    EdtDefaultBranch.Enabled:=False;
    EdtDefaultBranch.OnChange:=@DefaultBranchNameChanged;
    Top:=Top+13+24;

    LblInfo:=TLabel.Create(DefaultBranchPage);
    LblInfo.Parent:=DefaultBranchPage.Surface;
    LblInfo.Caption:='This setting does not affect existing repositories.';
    LblInfo.Left:=ScaleX(Left);
    LblInfo.Top:=ScaleY(Top);

    // Restore the setting chosen during a previous install.
    Data:=ReplayChoice('Default Branch Option','');
    case Data of
        '':  RdbDefaultBranch[DB_Unspecified].Checked:=True;
        ' ': RdbDefaultBranch[DB_Unspecified].Checked:=True;
    else begin
        RdbDefaultBranch[DB_Manual].Checked:=True;
        EdtDefaultBranch.Text:=Data;
        EdtDefaultBranch.Enabled:=True;
        DefaultBranchNameChanged(NIL);
    end end;

    (*
     * Create a custom page for modifying the environment.
     *)

    PathPage:=CreatePage(PrevPageID,'Adjusting your PATH environment','How would you like to use Git from the command line?',TabOrder,Top,Left);

    // 1st choice
    RdbPath[GP_BashOnly]:=CreateRadioButton(PathPage,'Use Git from Git Bash only','This is the most cautious choice as your PATH will not be modified at all. You will'+#13+'only be able to use the Git command line tools from Git Bash.',TabOrder,Top,Left);

    // 2nd choice
    RdbPath[GP_Cmd]:=CreateRadioButton(PathPage,'Git from the command line and also from 3rd-party software','<RED>(Recommended)</RED> This option adds only some minimal Git wrappers to your'+#13+'PATH to avoid cluttering your environment with optional Unix tools.'+#13+'You will be able to use Git from Git Bash, the Command Prompt and the Windows'+#13+'PowerShell as well as any third-party software looking for Git in PATH.',TabOrder,Top,Left);

    // 3rd choice
    RdbPath[GP_CmdTools]:=CreateRadioButton(PathPage,'Use Git and optional Unix tools from the Command Prompt','Both Git and the optional Unix tools will be added to your PATH.'+#13+'<RED>Warning: This will override Windows tools like "find" and "sort". Only'+#13+'use this option if you understand the implications.</RED>',TabOrder,Top,Left);

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
        RdbSSH[GS_Plink]:=CreateRadioButton(PuTTYPage,'Use (Tortoise)Plink',
            'PuTTY sessions were found in your Registry. You may specify the path'+#13+
            'to an existing copy of (Tortoise)Plink.exe from the TortoiseGit/SVN/CVS'+#13+
            'or PuTTY applications. "ssh.variant" will be set in the GIT configuration. '+#13+
            'The GIT_SSH and SVN_SSH environment variables will be adjusted to point '+#13+
            'to the following executable:',TabOrder,Top,Left);
        EdtPlink:=TEdit.Create(PuTTYPage);
        EdtPlink.Left:=ScaleX(Left+24);
        EdtPlink.Top:=ScaleY(Top);
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
            TabOrder:=TabOrder;
        end;
        TabOrder:=TabOrder+1;
        BtnPlink:=TButton.Create(PuTTYPage);
        BtnPlink.Left:=ScaleX(Left+344);
        BtnPlink.Top:=ScaleY(Top);
        with BtnPlink do begin
            Parent:=PuTTYPage.Surface;
            Caption:='...';
            OnClick:=@BrowseForPuTTYFolder;
            Width:=ScaleX(21);
            Height:=ScaleY(21);
            TabOrder:=TabOrder;
        end;
        TabOrder:=TabOrder+1;
        Top:=Top+29;

        // Add checkbox for tortoise plink
        TortoisePlink:=TCheckBox.Create(PuTTYPage);
        TortoisePlink.Left:=ScaleX(Left+24);
        TortoisePlink.Top:=ScaleY(Top);
        with TortoisePlink do begin
            Caption:='Set ssh.variant for Tortoise Plink';
            Parent:=PuTTYPage.Surface;
            Width:=ScaleX(405);
            Height:=ScaleY(17);
            TabOrder:=TabOrder;
        end;
        TabOrder:=TabOrder+1;
        Top:=Top+17;

        // Restore the setting chosen during a previous install.
        case ReplayChoice('SSH Option','OpenSSH') of
            'OpenSSH': RdbSSH[GS_OpenSSH].Checked:=True;
            'Plink': RdbSSH[GS_Plink].Checked:=True;
        else
            RdbSSH[GS_OpenSSH].Checked:=True;
        end;

        data:=ReplayChoice('Tortoise Option','');
        if (data='true') then
            TortoisePlink.Checked:=True;
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
     * Create a custom page for the default behavior of `git pull`.
     *)

    GitPullBehaviorPage:=CreatePage(PrevPageID,'Choose the default behavior of `git pull`','What should `git pull` do by default?',TabOrder,Top,Left);

    // 1st choice
    RdbGitPullBehavior[GP_GitPullMerge]:=CreateRadioButton(GitPullBehaviorPage,'Default (fast-forward or merge)','This is the standard behavior of `git pull`: fast-forward the current branch to'+#13+'the fetched branch when possible, otherwise create a merge commit.',TabOrder,Top,Left);

    // 2nd choice
    RdbGitPullBehavior[GP_GitPullRebase]:=CreateRadioButton(GitPullBehaviorPage,'Rebase','Rebase the current branch onto the fetched branch. If there are no local'+#13+'commits to rebase, this is equivalent to a fast-forward.',TabOrder,Top,Left);

    // 3rd choice
    RdbGitPullBehavior[GP_GitPullFFOnly]:=CreateRadioButton(GitPullBehaviorPage,'Only ever fast-forward','Fast-forward to the fetched branch. Fail if that is not possible.',TabOrder,Top,Left);

    // Restore the setting chosen during a previous install.
    case ReplayChoice('Git Pull Behavior Option','Merge') of
        'Merge': RdbGitPullBehavior[GP_GitPullMerge].Checked:=True;
        'Rebase': RdbGitPullBehavior[GP_GitPullRebase].Checked:=True;
        'FFOnly': RdbGitPullBehavior[GP_GitPullFFOnly].Checked:=True;
    else
        RdbGitPullBehavior[GP_GitPullMerge].Checked:=True;
    end;

    (*
     * Create a custom page for the choice of Git Credential Manager.
     *)

    GitCredentialManagerPage:=CreatePage(PrevPageID,'Choose a credential helper','Which credential helper should be configured?',TabOrder,Top,Left);

    // Git Credential Manager Core
    RdbGitCredentialManager[GCM_Core]:=CreateRadioButton(GitCredentialManagerPage,'Git Credential Manager Core','<RED>(NEW!)</RED> Use the new, <A HREF=https://github.com/microsoft/Git-Credential-Manager-Core>cross-platform version of the Git Credential Manager</A>.'+#13+'See more information about the future of Git Credential Manager <A HREF=https://github.com/microsoft/Git-Credential-Manager-Core/blob/master/docs/faq.md#about-the-project>here</A>.',TabOrder,Top,Left);

    // Git Credential Manager for Windows
    RdbGitCredentialManager[GCM_Classic]:=CreateRadioButton(GitCredentialManagerPage,'Git Credential Manager','(DEPRECATED) The <A HREF=https://github.com/Microsoft/Git-Credential-Manager-for-Windows>Git Credential Manager for Windows</A> handles credentials e.g.'+#13+'for Azure DevOps and GitHub (requires .NET framework v4.5.1 or later).',TabOrder,Top,Left);

    // No credential helper
    RdbGitCredentialManager[GCM_None]:=CreateRadioButton(GitCredentialManagerPage,'None','Do not use a credential helper.',TabOrder,Top,Left);

    // Restore the settings chosen during a previous install, if .NET 4.5.1
    // or later is available.
    if DetectNetFxVersion()<378675 then begin
        RdbGitCredentialManager[GCM_Classic].Checked:=False;
        RdbGitCredentialManager[GCM_Classic].Enabled:=False;
        RdbGitCredentialManager[GCM_Core].Checked:=False;
        RdbGitCredentialManager[GCM_Core].Enabled:=False;
    end else begin
        case ReplayChoice('Use Credential Manager','Core') of
            'Disabled': RdbGitCredentialManager[GCM_None].Checked:=True;
            'Enabled': RdbGitCredentialManager[GCM_Classic].Checked:=True;
            'Core': RdbGitCredentialManager[GCM_Core].Checked:=True;
        else
            RdbGitCredentialManager[GCM_Core].Checked:=True;
        end;
        // Auto-upgrade GCM to GCM Core in version v2.29.0
        if RdbGitCredentialManager[GCM_Classic].Checked and ((PreviousGitForWindowsVersion='') or IsUpgrade('2.29.0')) then begin
            RdbGitCredentialManager[GCM_Core].Checked:=True;
            AddToSet(CustomPagesWithUnseenOptions,GitCredentialManagerPage.ID);
        end;
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

    ExperimentalOptionsPage:=CreatePage(PrevPageID,'Configuring experimental options','These features are developed actively. Would you like to try them?',TabOrder,Top,Left);

#ifdef WITH_EXPERIMENTAL_BUILTIN_DIFFTOOL
    RdbExperimentalOptions[GP_BuiltinDifftool]:=CreateCheckBox(ExperimentalOptionsPage,'Enable experimental, builtin difftool','Use the experimental builtin difftool (fast, but only lightly tested).',TabOrder,Top,Left);

    // Restore the settings chosen during a previous install
    RdbExperimentalOptions[GP_BuiltinDifftool].Checked:=ReplayChoice('Enable Builtin Difftool','Auto')='Enabled';
#endif

#ifdef WITH_EXPERIMENTAL_BUILTIN_REBASE
    RdbExperimentalOptions[GP_BuiltinRebase]:=CreateCheckBox(ExperimentalOptionsPage,'Enable experimental, built-in rebase','<RED>(NEW!)</RED> Use the experimental built-in rebase (about 70% faster, but only'+#13+'lightly tested).',TabOrder,Top,Left);

    // Restore the settings chosen during a previous install
    RdbExperimentalOptions[GP_BuiltinRebase].Checked:=ReplayChoice('Enable Builtin Rebase','Auto')='Enabled';
#endif

#ifdef WITH_EXPERIMENTAL_BUILTIN_STASH
    RdbExperimentalOptions[GP_BuiltinStash]:=CreateCheckBox(ExperimentalOptionsPage,'Enable experimental, built-in stash','<RED>(NEW!)</RED> Use the experimental built-in stash (about 90% faster, but only'+#13+'lightly tested).',TabOrder,Top,Left);

    // Restore the settings chosen during a previous install
    RdbExperimentalOptions[GP_BuiltinStash].Checked:=ReplayChoice('Enable Builtin Stash','Auto')='Enabled';
#endif

#ifdef WITH_EXPERIMENTAL_BUILTIN_ADD_I
    RdbExperimentalOptions[GP_BuiltinAddI]:=CreateCheckBox(ExperimentalOptionsPage,'Enable experimental, built-in add -i/-p','<RED>(NEW!)</RED> Use the experimental built-in interactive add ("git add -i" or "git add -p").'+#13+'This makes it faster (especially the startup!), but it is not yet considered robust.',TabOrder,Top,Left);

    // Restore the settings chosen during a previous install
    RdbExperimentalOptions[GP_BuiltinAddI].Checked:=ReplayChoice('Enable Builtin Interactive Add','Auto')='Enabled';
#endif

#ifdef WITH_EXPERIMENTAL_PCON
    RdbExperimentalOptions[GP_EnablePCon]:=CreateCheckBox(ExperimentalOptionsPage,'Enable experimental support for pseudo consoles.','<RED>(NEW!)</RED> This allows running native console programs like Node or Python in a'+#13+'Git Bash window without using winpty, but it still has known bugs.',TabOrder,Top,Left);

    // Restore the settings chosen during a previous install
    RdbExperimentalOptions[GP_EnablePCon].Checked:=ReplayChoice('Enable Pseudo Console Support','Auto')='Enabled';
#endif

#ifdef WITH_EXPERIMENTAL_BUILTIN_FSMONITOR
    RdbExperimentalOptions[GP_EnableFSMonitor]:=CreateCheckBox(ExperimentalOptionsPage,'Enable experimental built-in file system monitor','<RED>(NEW!)</RED> Automatically run a <A HREF=https://github.com/git-for-windows/git/discussions/3251>built-in file system watcher</A>, to speed up common'+#13+'operations such as `git status`, `git add`, `git commit`, etc in worktrees'+#13+'containing many files.',TabOrder,Top,Left);

    // Restore the settings chosen during a previous install
    RdbExperimentalOptions[GP_EnableFSMonitor].Checked:=ReplayChoice('Enable FSMonitor','Auto')='Enabled';
#endif

#endif

    PageIDBeforeInstall:=CurrentCustomPageID;

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

#ifdef DEBUG_WIZARD_PAGE
    DebugWizardPage:={#DEBUG_WIZARD_PAGE};
#endif
    // Initially hide the Refresh button, show it when the process page becomes current.
    ProcessesRefresh.Hide;
end;

function ShouldSkipPage(PageID:Integer):Boolean;
var
    Msg,Cmd,LogPath:String;
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
                Cmd:='/D /C ""'+ExpandConstant('{tmp}\blocked-file-util.exe')+'" blocking-pids "'+AppDir+'" 2>"'+LogPath+'""';
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
    end else if OnlyShowNewOptions.Checked then begin
        if (IsInSet(AllCustomPages,PageID)) then
            Result:=not IsInSet(CustomPagesWithUnseenOptions,PageID)
        else if (PageID=wpSelectComponents) and HasUnseenComponents then
            Result:=False
        else
            Result:=(PageID<>wpInfoBefore) and (PageID<>wpFinished);
    end else
        Result:=False;
#ifdef DEBUG_WIZARD_PAGE
    Result:=PageID<>DebugWizardPage
    Exit;
#endif
end;

procedure CurPageChanged(CurPageID:Integer);
begin
    CurrentCustomPageID:=CurPageID;
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
    end else if (ProcessesPage<>NIL) and (CurPageID=ProcessesPage.ID) then begin
        // Show the "Refresh" button only on the processes page.
        ProcessesRefresh.Show;
        WizardForm.NextButton.Caption:=SetupMessage(msgButtonInstall);
    end else begin
        ProcessesRefresh.Hide;
    end;
    AdjustNextButtonLabel(Nil);
end;

function NextButtonClick(CurPageID:Integer):Boolean;
var
    i,j:Integer;
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
        (*
         * Before continuing, we need to check one last time if the path
         * to the custom editor (if selected) is still valid.
         *)
        if (CbbEditor.ItemIndex=GE_CustomEditor) and not PathIsValidExecutable(CustomEditorPath) then begin
            Result:=False;
            MsgBox('The path you specified is no longer available.',mbError,MB_OK);
            Wizardform.NextButton.Enabled:=False;
            Exit;
        end;
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
            end else if not Processes[i].Restartable then begin
                if WizardSilent() and (ParamIsSet('SKIPIFINUSE') or ParamIsSet('VSNOTICE')) then begin
                    Msg:='Skipping installation because the process '+Processes[i].Name+' (pid '+IntToStr(Processes[i].ID)+') is running, using Git for Windows'+#39+' files.';
                    if ParamIsSet('SKIPIFINUSE') or (ExpandConstant('{log}')='') then
                        LogError(Msg)
                    else
                        Log(Msg);
                    ExitEarlyWithSuccess();
                end;
                if WizardSilent() then
                    while True do begin
                        Msg:='';
                        for j:=i to GetArrayLength(Processes)-1 do
                            if not Processes[j].Restartable then
                                Msg:=Msg+#13+#10+Processes[j].Name+' (PID '+IntToStr(Processes[j].ID)+')'
                            else if (Processes[j].ToTerminate) and (not TerminateProcessByID(Processes[i].ID)) then
                                Msg:=Msg+#13+#10+Processes[j].Name+' (PID '+IntToStr(Processes[j].ID)+')';

                        if Msg='' then begin
                            Result:=True;
                            Exit;
                        end;

                        Msg:='The following process(es) use Git for Windows:'+#13+#10+Msg+#13+#10+#13+#10+'Please terminate those processes and retry.'+#13+#10+'Alternatively, cancel to abandon setup altogether.';
                        if SuppressibleMsgBox(Msg, mbCriticalError, MB_RETRYCANCEL, IDCANCEL) = IDCANCEL then begin
                            Result:=False;
                            Exit;
                        end;

                        RefreshProcessList(NIL);
                        i:=0;
                    end
                else begin
                    Msg:='Setup cannot continue until you close at least those applications in the list that are marked as "closing is required".';
                    SuppressibleMsgBox(Msg, mbCriticalError, MB_OK, IDOK);
                end;
                Result:=False;
                Exit;
            end;
        end;

        Result:=(GetArrayLength(Processes)=0);

        if not Result then begin
            Result:=(SuppressibleMsgBox(
                'If you continue without closing the listed applications they will be closed and restarted automatically.' + #13 + #13 +
                'Are you sure you want to continue?'
            ,   mbConfirmation
            ,   MB_YESNO
            ,   IDYES
            )=IDYES);
        end;
    end;
end;

// Procedure to create hardlinks for builtins. This procedure relies upon that
// git-wrapper.exe is already copied to {app}\tmp.
procedure HardlinkOrCopyGit(FileName:String;Builtin:Boolean);
var
    GitTarget:String;
    LinkCreated:Boolean;
begin
    if FileExists(FileName) and (not DeleteFile(FileName)) then begin
        Log('Line {#__LINE__}: Unable to delete existing built-in "'+FileName+'", skipping.');
        Exit;
    end;

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

procedure QueryUninstallValues;
var
    Domain:Integer;
    Key,Path:String;
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
        if not RegQueryStringValue(Domain,Key,'Inno Setup: App Path',UninstallAppPath) then
            UninstallAppPath:='';
        if not RegQueryStringValue(Domain,Key,'UninstallString',UninstallString) then
            UninstallString:='';
    end else begin
        UninstallAppPath:='';
        UninstallString:='';
    end;
end;

procedure CleanupWhenUpgrading;
var
    ErrorCode:Integer;
begin
    if UninstallAppPath<>'' then begin
        // Save a copy of the system config so that we can copy it back later
        if FileExists(UninstallAppPath+'\{#MINGW_BITNESS}\etc\gitconfig') then begin
            if (not FileCopy(UninstallAppPath+'\{#MINGW_BITNESS}\etc\gitconfig',ExpandConstant('{tmp}\gitconfig.system'),True)) then
                LogError('Could not save system config; continuing anyway');
        // Save a copy of the system config so that we can copy it back later
        end else if FileExists(UninstallAppPath+'\etc\gitconfig') and
            (not FileCopy(UninstallAppPath+'\etc\gitconfig',ExpandConstant('{tmp}\gitconfig.system'),True)) then
            LogError('Could not save system config; continuing anyway');
    end;

    if UninstallString<>'' then begin
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
    Bin,LibExec:String;
begin
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
    AppPath,XMLPath,Start:String;
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
    ExecSilently('schtasks /Create /F /TN "Git for Windows Updater" /XML "'+XMLPath+'"','install-autoupdate',ExpandConstant('Line {#__LINE__}: Unable to schedule the Git for Windows updater'));
end;

procedure UninstallAutoUpdater;
begin
    ExecSilently('schtasks /Delete /F /TN "Git for Windows Updater"','remove-autoupdate',ExpandConstant('Line {#__LINE__}: Unable to remove the Git for Windows updater'));
end;

procedure InstallWindowsTerminalFragment;
var
    Res:Longint;
    AppPath,JSONPath:String;
begin
    if IsAdminInstallMode() then
        JSONPath:=ExpandConstant('{commonappdata}\Microsoft\Windows Terminal\Fragments\Git\git-bash.json')
    else
        JSONPath:=ExpandConstant('{localappdata}\Microsoft\Windows Terminal\Fragments\Git\git-bash.json');
    AppPath:=ExpandConstant('{app}');
    StringChangeEx(AppPath, '\', '/', True)
    if not SaveStringToFile(JSONPath,
        '{'+
        '    "profiles": ['+
        '      {'+
        '        "guid": "{2ece5bfe-50ed-5f3a-ab87-5cd4baafed2b}",'+
        '        "name": "Git Bash",'+
        '        "commandline": "'+AppPath+'/bin/bash.exe -i -l",'+
        '        "icon": "'+AppPath+'/{#MINGW_BITNESS}/share/git/git-for-windows.ico",'+
        '        "startingDirectory": "%USERPROFILE%"'+
        '      }'+
        '    ]'+
        '  }',False) then begin
        LogError('Line {#__LINE__}: Unable to install Windows Terminal Fragment to '+JSONPath)
    end;
end;

{
    Create Cygwin's idea of a symbolic link:
    - a system file
    - starting with the prefix `!<symlink>\xff\xfe`
    - followed by the symlink target, in UTF-16
    - ending in two NUL bytes (reflecting a UTF-16 NUL)
}

function GetFileAttributes(Path:PAnsiChar):DWORD;
 external 'GetFileAttributesA@kernel32.dll stdcall';

function SetFileAttributes(Path:PAnsiChar;dwFileAttributes:DWORD):BOOL;
external 'SetFileAttributesA@kernel32.dll stdcall';

function CryptStringToBinary(sz:string;cch:LongWord;flags:LongWord;binary:string;var size:LongWord;skip:LongWord;flagsused:LongWord):Integer;
external 'CryptStringToBinaryW@crypt32.dll stdcall';

const
  CRYPT_STRING_HEX = $04;
  HEX_CHARS = '0123456789abcdef';

function CharToHex(C:Integer):string;
begin
    Result:=HEX_CHARS[((C div 16) and 15)+1]+HEX_CHARS[(C and 15)+1];
end;

function CreateCygwinSymlink(SymlinkPath,TargetPath:String):Boolean;
var
    Attribute:DWord;
    i:Integer;
    Hex,Buffer:string;
    Stream:TStream;
    Size:LongWord;
begin
    Result:=True;

    // assuming that the target is actually all-ASCII, convert to UTF-16
    for i:=Length(TargetPath) downto 1 do
        TargetPath:=Copy(TargetPath,1,i)+#0+Copy(TargetPath,i+1,Length(TargetPath)-i);

    Hex:='213c73796d6c696e6b3efffe'; // "!<symlink>\xff\xfe"
    for i:=1 to Length(TargetPath) do
        Hex:=Hex+CharToHex(Ord(TargetPath[i])); // append wide characters as hex
    Hex:=Hex+'0000'; // append a wide NUL

    // write the file
    Stream:=TFileStream.Create(SymlinkPath,fmCreate);
    try
        Size:=Length(Hex) div 2;
        SetLength(Buffer,Size);
        if (CryptStringToBinary(Hex,Length(Hex),CRYPT_STRING_HEX,Buffer,Size,0,0)=0) or (Size<>Length(Hex) div 2) then
            RaiseException('could not decode hex '+Hex);
        Stream.WriteBuffer(Buffer,Size);
    except
        LogError('Could not write "'+SymlinkPath+'" '+GetExceptionMessage());
        Result:=False;
    finally
        Stream.Free
    end;

    // Set system bit (required for Cygwin to interpret this as a symlink)
    Attribute:=GetFileAttributes(SymlinkPath);
    if (Attribute and 4) = 0  then
    begin
        Attribute:=Attribute or 4;
        if not SetFileAttributes(SymlinkPath,Attribute) then begin
            LogError('Could not mark "'+SymlinkPath+'" as system file');
            Result:=False;
        end;
    end;
end;

function UpgradeFromDotNetBasedScalar:Boolean;
var
    RegKey,UninstallScalar,ScalarExe,Cmd:String;
    Res:Longint;
    Enlistments:TArrayOfString;
    i:Integer;
begin
    Result:=True;

    RegKey:='SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{82F731CB-1CFC-406D-8D84-8467BF6040C7}_is1';
    if not RegQueryStringValue(HKEY_LOCAL_MACHINE,RegKey,'UninstallString',UninstallScalar) then
        // No existing Scalar found; ignore this silently
        Exit;

    // Check twice that .NET-based Scalar is there
    ScalarExe:=UninstallScalar;
    StringChangeEx(ScalarExe,'"','',True); // strip the surrounding double-quote characters
    StringChangeEx(ScalarExe,'\unins000.exe','\scalar.exe',True);
    if not FileExists(ScalarExe) then
        Exit;

    WizardForm.StatusLabel.Caption:='Upgrading from .NET-based Scalar';

    // First, get .NET-based Scalar's idea of the registered enlistments
    if not ExecSilently('"'+ScalarExe+'" list','scalar-list',ExpandConstant('Line {#__LINE__}: Unable to run `scalar list`')) then
        Result:=False;
    LoadStringsFromFile(ExpandConstant('{tmp}\scalar-list.out'),Enlistments);

    // Now, register them with the C-based Scalar
    for i:=0 to Length(Enlistments)-1 do begin
        WizardForm.StatusLabel.Caption:='Registering '+Enlistments[i]+' with Scalar';
        ExecSilentlyAsOriginalUser('"'+AppDir+'\cmd\scalar.exe" register "'+Enlistments[i]+'"','scalar-register-'+IntToStr(i),ExpandConstant('Line {#__LINE__}: Could not register "'+Enlistments[i]+'" with Scalar'));
    end;

    // Now uninstall the .NET-based Scalar
    // (leaving C:\ProgramData\Scalar in place, in case
    // the user needs to downgrade again to get unblocked)
    WizardForm.StatusLabel.Caption:='Uninstalling .NET-based Scalar';
    Cmd:='"'+UninstallScalar+'/VERYSILENT /SILENT /NORESTART /SUPPRESSMSGBOXES /LOG"';
    if (not Exec(ExpandConstant('{sys}\cmd.exe'),'/D /C '+Cmd,'',SW_HIDE,ewWaitUntilTerminated,Res)) or (Res<>0) then
        LogError('Could not uninstall Scalar. Trying to continue anyway.');
end;

procedure CurStepChanged(CurStep:TSetupStep);
var
    DllPath,FileName,Cmd,Msg,Ico:String;
    BuiltIns,ImageNames,EnvPath:TArrayOfString;
    Count,i:Longint;
    RootKey:Integer;
begin
    if CurStep=ssInstall then begin
#ifdef DO_NOT_INSTALL
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
        Create the symlinks in `/dev/`
    }

    CreateCygwinSymlink(AppDir+'\dev\fd','/proc/self/fd');
    CreateCygwinSymlink(AppDir+'\dev\stdin','/proc/self/fd/0');
    CreateCygwinSymlink(AppDir+'\dev\stdout','/proc/self/fd/1');
    CreateCygwinSymlink(AppDir+'\dev\stderr','/proc/self/fd/2');

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

    // Copy previous system wide git config file, if any
    if FileExists(ExpandConstant('{tmp}\gitconfig.system')) then begin
        if (not ForceDirectories(AppDir+'\{#ETC_GITCONFIG_DIR}')) then
            LogError('Failed to create \{#ETC_GITCONFIG_DIR}; continuing anyway')
        else
            FileCopy(ExpandConstant('{tmp}\gitconfig.system'),AppDir+'\{#ETC_GITCONFIG_DIR}\gitconfig',True)
    end;

    {
        Configure some defaults in the system config
    }

    if not SetSystemConfigDefaults() then
        LogError('Unable to set system config defaults');

    {
        Configure http.sslBackend according to the user's choice.
    }

    if RdbCurlVariant[GC_WinSSL].Checked then
        GitSystemConfigSet('http.sslBackend','schannel')
    else
        GitSystemConfigSet('http.sslBackend','openssl');

    if not RdbCurlVariant[GC_WinSSL].Checked then begin
        Cmd:=AppDir+'/{#MINGW_BITNESS}/ssl/certs/ca-bundle.crt';
        StringChangeEx(Cmd,'\','/',True);
        GitSystemConfigSet('http.sslCAInfo',Cmd);
    end else
        GitSystemConfigSet('http.sslCAInfo',#0);

    {
        Adapt core.autocrlf
    }

    if RdbCRLF[GC_LFOnly].checked then begin
        Cmd:='input';
    end else if RdbCRLF[GC_CRLFAlways].checked then begin
        Cmd:='true';
    end else begin
        Cmd:='false';
    end;
    GitSystemConfigSet('core.autocrlf',Cmd);

    {
        Configure the terminal window for Git Bash
    }

    if RdbBashTerminal[GB_ConHost].checked then begin
        OverrideGitBashCommandLine(AppDir+'\git-bash.exe','SHOW_CONSOLE=1 APPEND_QUOTE=1 @@COMSPEC@@ /S /C ""@@EXEPATH@@\usr\bin\bash.exe" --login -i');
    end;

    {
        Configure the default `git pull` behavior
    }

    if RdbGitPullBehavior[GP_GitPullMerge].Checked then begin
        GitSystemConfigSet('pull.rebase','false')
    end else if RdbGitPullBehavior[GP_GitPullRebase].Checked then begin
        GitSystemConfigSet('pull.rebase','true')
    end else if RdbGitPullBehavior[GP_GitPullFFOnly].Checked then begin
        GitSystemConfigSet('pull.ff','only')
    end;

    {
        Configure credential helper
    }

    if RdbGitCredentialManager[GCM_None].checked then begin
        GitSystemConfigSet('credential.helper',#0);
        GitSystemConfigSet('credential.https://dev.azure.com.useHttpPath',#0);
    end else if RdbGitCredentialManager[GCM_Classic].checked then begin
        GitSystemConfigSet('credential.helper','manager');
        GitSystemConfigSet('credential.https://dev.azure.com.useHttpPath',#0);
    end else if RdbGitCredentialManager[GCM_Core].checked then begin
        GitSystemConfigSet('credential.helper','manager-core');
        GitSystemConfigSet('credential.https://dev.azure.com.useHttpPath','true');
    end;

    {
        Configure extra options
    }

    if RdbExtraOptions[GP_FSCache].checked then
        GitSystemConfigSet('core.fscache','true');

    if RdbExtraOptions[GP_Symlinks].checked then
        Cmd:='true'
    else
        Cmd:='false';
    GitSystemConfigSet('core.symlinks',Cmd);

    {
        Configure experimental options
    }

#ifdef WITH_EXPERIMENTAL_BUILTIN_DIFFTOOL
    if RdbExperimentalOptions[GP_BuiltinDifftool].checked then
        GitSystemConfigSet('difftool.useBuiltin','true')
    else
        GitSystemConfigSet('difftool.useBuiltin',#0);
#endif

#ifdef WITH_EXPERIMENTAL_BUILTIN_REBASE
    if RdbExperimentalOptions[GP_BuiltinRebase].checked then
        GitSystemConfigSet('rebase.useBuiltin','true')
    else
        GitSystemConfigSet('rebase.useBuiltin',#0);
#endif

#ifdef WITH_EXPERIMENTAL_BUILTIN_STASH
    if RdbExperimentalOptions[GP_BuiltinStash].checked then
        GitSystemConfigSet('stash.useBuiltin','true')
    else
        GitSystemConfigSet('stash.useBuiltin',#0);
#endif

#ifdef WITH_EXPERIMENTAL_BUILTIN_ADD_I
    if RdbExperimentalOptions[GP_BuiltinAddI].checked then
        GitSystemConfigSet('add.interactive.useBuiltin','true')
    else
        GitSystemConfigSet('add.interactive.useBuiltin',#0);
#endif

#ifdef WITH_EXPERIMENTAL_PCON
    if RdbExperimentalOptions[GP_EnablePCon].checked and
       not SaveStringToFile(ExpandConstant('{app}\etc\git-bash.config'),'MSYS=enable_pcon',False) then
        LogError('Could not write to '+ExpandConstant('{app}\etc\git-bash.config'));
#endif

#ifdef WITH_EXPERIMENTAL_BUILTIN_FSMONITOR
    if RdbExperimentalOptions[GP_EnableFSMonitor].checked then
        GitSystemConfigSet('core.useBuiltinFSMonitor','true')
    else
        GitSystemConfigSet('core.useBuiltinFSMonitor',#0);
#endif

    {
        Modify the environment

        This must happen no later than ssPostInstall to make
        "ChangesEnvironment=yes" not happend before the change!
    }

    // Delete GIT_SSH and SVN_SSH if a previous installation set them (this is required for the GS_OpenSSH case).
    DeleteMarkedEnvString('GIT_SSH');
    DeleteMarkedEnvString('SVN_SSH');

    if (PuTTYPage<>NIL) then begin
        GitSystemConfigSet('ssh.variant',#0);
        if RdbSSH[GS_Plink].Checked then begin
            SetAndMarkEnvString('GIT_SSH',EdtPlink.Text,True);
            SetAndMarkEnvString('SVN_SSH',EdtPlink.Text,True);
            if TortoisePlink.Checked then begin
                Log('Line {#__LINE__}: Setting config option ssh.variant=tortoiseplink');
                GitSystemConfigSet('ssh.variant','tortoiseplink')
            end else begin
                Log('Line {#__LINE__}: Setting config option ssh.variant=putty');
                GitSystemConfigSet('ssh.variant','putty');
            end;
        end;
    end;

    if RdbDefaultBranch[DB_Manual].Checked then
        GitSystemConfigSet('init.defaultBranch',EdtDefaultBranch.Text)
    else
        GitSystemConfigSet('init.defaultBranch','{#DEFAULT_BRANCH_NAME}');

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
        if not DeleteFile(AppDir+'\{#MINGW_BITNESS}\bin\git-lfs.exe') and not DeleteFile(AppDir+'\{#MINGW_BITNESS}\libexec\git-core\git-lfs.exe') then
            LogError('Line {#__LINE__}: Unable to delete "git-lfs.exe".');
    end;

    {
        Handle Scalar
    }

#ifdef WITH_SCALAR
    if not IsComponentSelected('scalar') then begin
        // Remove scalar.exe from Git for Windows' files
        if not DeleteFile(AppDir+'\cmd\scalar.exe') or
           not DeleteFile(AppDir+'\{#MINGW_BITNESS}\bin\scalar.exe') or
           not DeleteFile(AppDir+'\{#MINGW_BITNESS}\libexec\git-core\scalar.exe') or
           not DeleteFile(AppDir+'\{#MINGW_BITNESS}\share\doc\git-doc\scalar.html') then begin
            LogError('Line {#__LINE__}: Unable to delete "scalar.exe".');
        end;
    end else begin
        UpgradeFromDotNetBasedScalar();
        ExecSilentlyAsOriginalUser('"'+AppDir+'\cmd\scalar.exe" reconfigure --all','scalar-reconfigure','Line {#__LINE__}: Could not reconfigure Scalar enlistments');
    end;
#endif

    {
        Create the Windows Terminal integration
    }

    if IsComponentSelected('windowsterminal') then
        InstallWindowsTerminalFragment();

    {
        Set the default Git editor
    }

    if (CbbEditor.ItemIndex=GE_Nano) then
        GitSystemConfigSet('core.editor','nano.exe')
    else if ((CbbEditor.ItemIndex=GE_NotepadPlusPlus)) and (NotepadPlusPlusPath<>'') then
        GitSystemConfigSet('core.editor','"'+NotepadPlusPlusPath+'" -multiInst -notabbar -nosession -noPlugin')
    else if ((CbbEditor.ItemIndex=GE_VisualStudioCode)) and (VisualStudioCodePath<>'') then begin
        if (VisualStudioCodeUserInstallation=False) then
            GitSystemConfigSet('core.editor','"'+VisualStudioCodePath+'" --wait')
        else if not ExecAsOriginalUser(AppDir + '\{#MINGW_BITNESS}\bin\git.exe','config --global core.editor "\"'+VisualStudioCodePath+'\" --wait"','',SW_HIDE,ewWaitUntilTerminated, i) then
            LogError('Could not set Visual Studio Code as core.editor in the gitconfig.')
    end else if ((CbbEditor.ItemIndex=GE_VisualStudioCodeInsiders)) and (VisualStudioCodeInsidersPath<>'') then begin
        if (VisualStudioCodeInsidersUserInstallation=False) then
            GitSystemConfigSet('core.editor','"'+VisualStudioCodeInsidersPath+'" --wait')
        else if not ExecAsOriginalUser(AppDir + '\{#MINGW_BITNESS}\bin\git.exe','config --global core.editor "\"'+VisualStudioCodeInsidersPath+'\" --wait"','',SW_HIDE,ewWaitUntilTerminated, i) then
            LogError('Could not set Visual Studio Code Insiders as core.editor in the gitconfig.')
    end else if ((CbbEditor.ItemIndex=GE_SublimeText)) and (SublimeTextPath<>'') then begin
        if (SublimeTextUserInstallation=False) then
            GitSystemConfigSet('core.editor','"'+SublimeTextPath+'" -w')
        else if not ExecAsOriginalUser(AppDir + '\{#MINGW_BITNESS}\bin\git.exe','config --global core.editor "\"'+SublimeTextPath+'\" -w"','',SW_HIDE,ewWaitUntilTerminated, i) then
            LogError('Could not set Sublime Text as core.editor in the gitconfig.');
    end else if ((CbbEditor.ItemIndex=GE_Atom)) and (AtomPath<>'') then begin
        if not ExecAsOriginalUser(AppDir + '\{#MINGW_BITNESS}\bin\git.exe','config --global core.editor "\"'+AtomPath+'\" --wait"','',SW_HIDE,ewWaitUntilTerminated, i) then
            LogError('Could not set Atom as core.editor in the gitconfig.');
    end else if ((CbbEditor.ItemIndex=GE_VSCodium)) and (VSCodiumPath<>'') then begin
        if (VSCodiumUserInstallation=False) then
            GitSystemConfigSet('core.editor','"'+VSCodiumPath+'" --wait')
        else if not ExecAsOriginalUser(AppDir + '\{#MINGW_BITNESS}\bin\git.exe','config --global core.editor "\"'+VSCodiumPath+'\" --wait"','',SW_HIDE,ewWaitUntilTerminated, i) then
            LogError('Could not set VSCodium as core.editor in the gitconfig.')
    end else if (CbbEditor.ItemIndex=GE_Notepad) then
        GitSystemConfigSet('core.editor','notepad')
    else if (CbbEditor.ItemIndex=GE_Wordpad) then
        GitSystemConfigSet('core.editor','wordpad')
    else if ((CbbEditor.ItemIndex=GE_CustomEditor)) and (PathIsValidExecutable(CustomEditorPath)) then
        GitSystemConfigSet('core.editor','"'+CustomEditorPath+'" '+CustomEditorOptions);

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
    Data,Data2,CustomEditorData,Path:String;
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
    end else if (CbbEditor.ItemIndex=GE_SublimeText) then begin
        Data:='SublimeText';
    end else if (CbbEditor.ItemIndex=GE_Atom) then begin
        Data:='Atom';
    end else if (CbbEditor.ItemIndex=GE_VSCodium) then begin
        Data:='VSCodium';
    end else if (CbbEditor.ItemIndex=GE_Notepad) then begin
        Data:='Notepad';
    end else if (CbbEditor.ItemIndex=GE_Wordpad) then begin
        Data:='Wordpad';
    end else if (CbbEditor.ItemIndex=GE_CustomEditor) then begin
        Data:='CustomEditor'
        CustomEditorData:=EditorPage.Values[0];
    end;
    RecordChoice(PreviousDataKey,'Editor Option',Data);
    RecordChoice(PreviousDataKey,'Custom Editor Path',CustomEditorData);

    // Default Branch options.
    Data:=' ';
    if RdbDefaultBranch[DB_Manual].Checked then
        Data:=EdtDefaultBranch.Text;
    RecordChoice(PreviousDataKey,'Default Branch Option',Data);

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
    Data2:='false';
    if (PuTTYPage=NIL) or RdbSSH[GS_OpenSSH].Checked then begin
        Data:='OpenSSH';
    end else if RdbSSH[GS_Plink].Checked then begin
        Data:='Plink';
        RecordChoice(PreviousDataKey,'Plink Path',EdtPlink.Text);
        if TortoisePlink.Checked then
            Data2:='true';
    end;
    RecordChoice(PreviousDataKey,'SSH Option',Data);
    RecordChoice(PreviousDataKey,'Tortoise Option',Data2);

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

    // Default behavior of `git pull`.
    Data:='Merge';
    if RdbGitPullBehavior[GP_GitPullRebase].Checked then begin
        Data:='Rebase'
    end else if RdbGitPullBehavior[GP_GitPullFFOnly].Checked then begin
        Data:='FFOnly'
    end;
    RecordChoice(PreviousDataKey,'Git Pull Behavior Option',Data);

    // Credential helper.
    Data:='Disabled';
    if RdbGitCredentialManager[GCM_Classic].Checked then begin
        Data:='Enabled';
    end else if RdbGitCredentialManager[GCM_Core].Checked then begin;
        Data:='Core';
    end;
    RecordChoice(PreviousDataKey,'Use Credential Manager',Data);

    // Extra options.
    Data:='Disabled';
    if RdbExtraOptions[GP_FSCache].Checked then begin
        Data:='Enabled';
    end;
    RecordChoice(PreviousDataKey,'Performance Tweaks FSCache',Data);
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

#ifdef WITH_EXPERIMENTAL_BUILTIN_ADD_I
    Data:='Disabled';
    if RdbExperimentalOptions[GP_BuiltinAddI].Checked then begin
        Data:='Enabled';
    end;
    RecordChoice(PreviousDataKey,'Enable Builtin Interactive Add',Data);
#endif

#ifdef WITH_EXPERIMENTAL_PCON
    Data:='Disabled';
    if RdbExperimentalOptions[GP_EnablePCon].Checked then begin
        Data:='Enabled';
    end;
    RecordChoice(PreviousDataKey,'Enable Pseudo Console Support',Data);
#endif

#ifdef WITH_EXPERIMENTAL_BUILTIN_FSMONITOR
    Data:='Disabled';
    if RdbExperimentalOptions[GP_EnableFSMonitor].Checked then begin
        Data:='Enabled';
    end;
    RecordChoice(PreviousDataKey,'Enable FSMonitor',Data);
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
    FileName,PathOption:String;
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
