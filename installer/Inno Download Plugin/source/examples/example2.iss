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

[Files]
Source: "{tmp}\test1.zip"; DestDir: "{app}"; Flags: external; ExternalSize: 1048576
Source: "{tmp}\test2.zip"; DestDir: "{app}"; Flags: external; ExternalSize: 1048576
Source: "{tmp}\test3.zip"; DestDir: "{app}"; Flags: external; ExternalSize: 1048576

[Icons]
Name: "{group}\{cm:UninstallProgram,My Program}"; Filename: "{uninstallexe}"

[Code]
procedure InitializeWizard();
begin
    idpAddFileSize('http://127.0.0.1/test1.zip', ExpandConstant('{tmp}\test1.zip'), 1048576);
    idpAddFileSize('http://127.0.0.1/test2.zip', ExpandConstant('{tmp}\test2.zip'), 1048576);
    idpAddFileSize('http://127.0.0.1/test3.zip', ExpandConstant('{tmp}\test3.zip'), 1048576);

    idpDownloadAfter(wpReady);
end;
