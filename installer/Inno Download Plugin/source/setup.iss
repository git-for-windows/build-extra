#define ProgName "Inno Download Plugin"
#define ProgVer  Copy(GetFileVersion("unicode\idp.dll"), 1, 5)
#define ProgYear GetDateTimeString("yyyy", "", "")
#define WebSite  "http://mitrichsoftware.wordpress.com"
#define Forum    "https://groups.google.com/forum/#!forum/inno-download-plugin"

[Setup]
AppName              = {#ProgName}
AppVersion           = {#ProgVer}
AppId                = MitrichSoftware.InnoDownloadPlugin
AppCopyright         = (C)2013-{#ProgYear} Mitrich Software
AppPublisher         = Mitrich Software
AppPublisherURL      = {#WebSite}
AppSupportURL        = {#Forum}
DefaultDirName       = {pf}\{#ProgName}
DefaultGroupName     = {#ProgName}
AllowNoIcons         = yes
SolidCompression     = yes
SetupIconFile        = misc\Setup.ico
VersionInfoVersion   = {#ProgVer}
OutputBaseFilename   = idpsetup-{#ProgVer}
OutputDir            = .

[CustomMessages]
ForumDescription=Support Forum
Documentation   =Documentation
SourceCode      =Source code
AddIncludePath  =Add IDP include path to ISPPBuiltins.iss

[Components]
Name: main; Description: "{#ProgName} binaries, examples & documentation"; Types: full compact custom; Flags: fixed
Name: src;  Description: "{cm:SourceCode}";                                Types: full

[Tasks]
Name: includepath; Description: "{cm:AddIncludePath}"

[Files]
Source: "unicode\idp.dll";        DestDir: "{app}\unicode";                Components: main
Source: "ansi\idp.dll";           DestDir: "{app}\ansi";                   Components: main
Source: "idp.iss";                DestDir: "{app}";                        Components: main
Source: "unicode\idplang\*.iss";  DestDir: "{app}\unicode\idplang";        Components: main
Source: "ansi\idplang\*.iss";     DestDir: "{app}\ansi\idplang";           Components: main
Source: "examples\*.*";           DestDir: "{app}\examples";               Components: main; Flags: recursesubdirs
Source: "doc\idp.chm";            DestDir: "{app}";                        Components: main
Source: "COPYING.txt";            DestDir: "{app}";                        Components: main

Source: "idp.iss";                      DestDir: "{app}\source";                 Components: src
Source: "unicode\idplang\*.iss";        DestDir: "{app}\source\unicode\idplang"; Components: src
Source: "ansi\idplang\*.iss";           DestDir: "{app}\source\ansi\idplang";    Components: src
Source: "setup.iss";                    DestDir: "{app}\source";                 Components: src
Source: "InnoDownloadPlugin.sln";       DestDir: "{app}\source";                 Components: src
Source: "InnoDownloadPlugin.workspace"; DestDir: "{app}\source";                 Components: src
Source: "idp\idp.vcproj";               DestDir: "{app}\source\idp";             Components: src
Source: "idp\idp.cbp";                  DestDir: "{app}\source\idp";             Components: src
Source: "idp\*.cpp";                    DestDir: "{app}\source\idp";             Components: src
Source: "idp\*.h";                      DestDir: "{app}\source\idp";             Components: src
Source: "idp\*.rc";                     DestDir: "{app}\source\idp";             Components: src
Source: "idp\*.def";                    DestDir: "{app}\source\idp";             Components: src
Source: "doc\*.lua";                    DestDir: "{app}\source\doc";             Components: src
Source: "doc\build.bat";                DestDir: "{app}\source\doc";             Components: src
Source: "doc\styles.css";               DestDir: "{app}\source\doc";             Components: src
Source: "doc\tooltip.js";               DestDir: "{app}\source\doc";             Components: src
Source: "doc\*.png";                    DestDir: "{app}\source\doc";             Components: src
Source: "examples\*.*";                 DestDir: "{app}\source\examples";        Components: src; Flags: recursesubdirs
Source: "misc\DownloadForm.isf";        DestDir: "{app}\source\misc";            Components: src
Source: "misc\Setup.ico";               DestDir: "{app}\source\misc";            Components: src
Source: "misc\*.lua";                   DestDir: "{app}\source\misc";            Components: src
Source: "misc\*.bat";                   DestDir: "{app}\source\misc";            Components: src
Source: "COPYING.txt";                  DestDir: "{app}\source";                 Components: src

Source: "tests\*.iss";                        DestDir: "{app}\source\tests";            Components: src
Source: "tests\statictest\statictest.vcproj"; DestDir: "{app}\source\tests\statictest"; Components: src
Source: "tests\statictest\main.cpp";          DestDir: "{app}\source\tests\statictest"; Components: src
Source: "tests\dlltest\dlltest.vcproj";       DestDir: "{app}\source\tests\dlltest";    Components: src
Source: "tests\dlltest\main.cpp";             DestDir: "{app}\source\tests\dlltest";    Components: src
Source: "tests\ftpdirtest\ftpdirtest.vcproj"; DestDir: "{app}\source\tests\ftpdirtest"; Components: src
Source: "tests\ftpdirtest\main.cpp";          DestDir: "{app}\source\tests\ftpdirtest"; Components: src

[Icons]
Name: "{group}\{#ProgName} {cm:Documentation}";    Filename: "{app}\idp.chm"
Name: "{group}\Example scripts";                   Filename: "{app}\examples"
Name: "{group}\{cm:ProgramOnTheWeb,{#ProgName}}";  Filename: "{#WebSite}"
Name: "{group}\{cm:ForumDescription}";             Filename: "{#Forum}"
Name: "{group}\{cm:UninstallProgram,{#ProgName}}"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\examples"; Description: "Open Examples folder"; Flags: postinstall shellexec skipifsilent
Filename: "{app}\idp.chm";  Description: "View documentation";   Flags: postinstall shellexec skipifsilent

[Registry]
Root: HKLM; Subkey: "Software\Mitrich Software";             Flags: uninsdeletekeyifempty
Root: HKLM; Subkey: "Software\Mitrich Software\{#ProgName}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\Mitrich Software\{#ProgName}"; ValueType: string; ValueName: "InstallDir"; ValueData: "{app}"

[Code]
const idpPathStr = '#pragma include __INCLUDE__ + ";" + ReadReg(HKLM, "Software\Mitrich Software\Inno Download Plugin", "InstallDir")';

function GetISPPBuiltinsLocation: String;
var dir: String;
begin
    if RegQueryStringValue(HKEY_LOCAL_MACHINE, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 5_is1', 'InstallLocation', dir) then
    begin
        if FileExists(dir + 'ISPPBuiltins.iss') then
            result := dir + 'ISPPBuiltins.iss'
        else if FileExists(dir + 'Builtins.iss') then
            result := dir + 'Builtins.iss';
    end
    else
        result := '';
end;

function IncludePathAlreadyAdded: Boolean;
var ISPPBuiltins: TArrayOfString;
    i: Integer;
begin
    LoadStringsFromFile(GetISPPBuiltinsLocation, ISPPBuiltins);
    result := false;

    for i := 0 to GetArrayLength(ISPPBuiltins)-1 do
        if ISPPBuiltins[i] = idpPathStr then
        begin
            result := true;
            break;
        end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
    if CurStep = ssPostInstall then
        if IsTaskSelected('includepath') then
            if FileExists(GetISPPBuiltinsLocation) then
                if not IncludePathAlreadyAdded then
                    SaveStringToFile(GetISPPBuiltinsLocation, #13#10 + '; Inno Download Plugin include path' + #13#10 + idpPathStr + #13#10, true);
end;
