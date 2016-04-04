#pragma include __INCLUDE__ + ";" + ReadReg(HKLM, "Software\Mitrich Software\Inno Download Plugin", "InstallDir")

[Setup]
AppName                    = My Program
AppVersion                 = 1.5
DefaultDirName             = {pf}\My Program
DefaultGroupName           = My Program
ShowUndisplayableLanguages = yes
OutputDir                  = .

#define IDP_DEBUG
#include <idp.iss>

[Files]
Source: "authtest.iss"; DestDir: "{app}"

[Icons]
Name: "{group}\{cm:UninstallProgram,My Program}"; Filename: "{uninstallexe}"

[Code]
procedure InitializeWizard();
begin
    idpSetOption('DetailedMode',  '1');
    idpSetOption('AllowContinue', '1');
    idpSetOption('ErrorDialog',   'UrlList');
    
    idpSetLogin('user1', 'password1');

    idpAddFile('http://127.0.0.1/test1.rar',                    ExpandConstant('{src}\test1.rar'));
    idpAddFile('http://user2:password2@127.0.0.1/test2.rar',    ExpandConstant('{src}\test2.rar'));
    idpAddFile('ftp://127.0.0.1/pub/test3.rar',                 ExpandConstant('{src}\test3.rar'));
    idpAddFile('ftp://user2:password2@127.0.0.1/pub/test3.rar', ExpandConstant('{src}\test3.rar'));

    idpDownloadAfter(wpWelcome);
end;
