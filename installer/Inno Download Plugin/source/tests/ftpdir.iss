[Setup]
AppName          = My Program
AppVersion       = 1.5
DefaultDirName   = {pf}\My Program
DefaultGroupName = My Program
OutputDir        = .

#define IDP_DEBUG
#include <idp.iss>

[Files]
Source: "idptest.iss"; DestDir: "{app}"

[Icons]
Name: "{group}\{cm:UninstallProgram,My Program}"; Filename: "{uninstallexe}"

[Code]
procedure InitializeWizard();
begin
    idpSetOption('DetailedMode',    '1');
    idpSetOption('AllowContinue',   '1');
    idpSetOption('ErrorDialog',     'FileList');
    //idpSetOption('PreserveFtpDirs', '0');
    idpAddFtpDir('ftp://127.0.0.1/', '', ExpandConstant('{src}'), true);
    idpDownloadAfter(wpWelcome);
end;
