; Uncomment one of following lines, if you haven't checked "Add IDP include path to ISPPBuiltins.iss" option during IDP installation:
;#pragma include __INCLUDE__ + ";" + ReadReg(HKLM, "Software\Mitrich Software\Inno Download Plugin", "InstallDir")
;#pragma include __INCLUDE__ + ";" + "c:\lib\InnoDownloadPlugin"

[Setup]
AppName          = My Program
AppVersion       = 1.0
DefaultDirName   = {pf}\My Program
DefaultGroupName = My Program
OutputDir        = userdocs:Inno Setup Examples Output

#include <idp.iss>

[Types]
Name: full;    Description: "Full installation"
Name: compact; Description: "Compact installation"
Name: custom;  Description: "Custom installation"; Flags: iscustom

[Components]
Name: app;  Description: "My Program";  Types: full compact custom; Flags: fixed
Name: help; Description: "Help files";  Types: full
Name: src;  Description: "Source code"; Types: full

[Files]
Source: "{tmp}\app.exe";  DestDir: "{app}"; Flags: external; ExternalSize: 1048576; Components: app
Source: "{tmp}\help.chm"; DestDir: "{app}"; Flags: external; ExternalSize: 1048576; Components: help
Source: "{tmp}\src.zip";  DestDir: "{app}"; Flags: external; ExternalSize: 1048576; Components: src

[Icons]
Name: "{group}\My Program"; Filename: "app.exe";  Components: app
Name: "{group}\Help file";  Filename: "help.chm"; Components: help
Name: "{group}\{cm:UninstallProgram,My Program}"; Filename: "{uninstallexe}"

[Code]
procedure InitializeWizard;
begin
    idpAddFileComp('http://127.0.0.1/app.exe',  ExpandConstant('{tmp}\app.exe'),  'app');
    idpAddFileComp('http://127.0.0.1/help.chm', ExpandConstant('{tmp}\help.chm'), 'help');
    idpAddFileComp('http://127.0.0.1/src.zip',  ExpandConstant('{tmp}\src.zip'),  'src');

    idpDownloadAfter(wpReady);
end;
