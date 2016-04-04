[Setup]
AppName              = My Program
AppVersion           = 1.5
DefaultDirName       = {pf}\My Program
DefaultGroupName     = My Program
UninstallDisplayIcon = {app}\MyProg.exe
SolidCompression     = yes
OutputDir            = .

#define IDP_DEBUG
#include <idp.iss>

[Files]
Source: "idptest.iss"; DestDir: "{app}"

[Icons]
Name: "{group}\{cm:UninstallProgram,My Program}"; Filename: "{uninstallexe}"

[Code]
procedure InitializeWizard();
begin
    idpSetOption('DetailedMode',  '1');
    idpSetOption('AllowContinue', '1');

    idpAddFile('http://127.0.0.1/test1.rar', ExpandConstant('{src}\test1.rar'));
    idpAddFile('http://fake.addr/test2.rar', ExpandConstant('{src}\test2.rar'));
    idpAddFile('http://127.0.0.1/test3.rar', ExpandConstant('{src}\test3.rar'));

    idpAddMirror('http://fake.addr/test2.rar', 'http://fake2.too/test2.rar');
    idpAddMirror('http://fake.addr/test2.rar', 'http://127.0.0.1/test2.rar');
    idpAddMirror('http://fake.addr/test2.rar', 'http://also.fake/test2.rar');

    idpDownloadAfter(wpWelcome);
end;
