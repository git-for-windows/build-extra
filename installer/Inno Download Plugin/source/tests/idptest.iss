#pragma include __INCLUDE__ + ";" + ReadReg(HKLM, "Software\Mitrich Software\Inno Download Plugin", "InstallDir")

[Setup]
AppName                    = My Program
AppVersion                 = 1.5
DefaultDirName             = {pf}\My Program
DefaultGroupName           = My Program
ShowUndisplayableLanguages = yes
OutputDir                  = .

[Languages]
Name: en;    MessagesFile: "compiler:Default.isl"
Name: be;    MessagesFile: "compiler:Languages\Belarusian.isl"
Name: zh;    MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: de;    MessagesFile: "compiler:Languages\German.isl"
Name: fi;    MessagesFile: "compiler:Languages\Finnish.isl"
Name: pl;    MessagesFile: "compiler:Languages\Polish.isl"
Name: pt_br; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: ru;    MessagesFile: "compiler:Languages\Russian.isl"

#define IDP_DEBUG

#include <idp.iss>
#include <idplang\Belarusian.iss>
#include <idplang\ChineseSimplified.iss>
#include <idplang\German.iss>
#include <idplang\Finnish.iss>
#include <idplang\Polish.iss>
#include <idplang\BrazilianPortuguese.iss>
#include <idplang\Russian.iss>

[Files]
Source: "idptest.iss"; DestDir: "{app}"

[Icons]
Name: "{group}\{cm:UninstallProgram,My Program}"; Filename: "{uninstallexe}"

[Code]
procedure InitializeWizard();
begin
    idpSetOption('DetailedMode',  '1');
    idpSetOption('AllowContinue', '1');
    idpSetOption('ErrorDialog',   'URLList');

    idpAddFile('http://127.0.0.1/test1.rar', ExpandConstant('{src}\test1.rar'));
    idpAddFile('http://127.0.0.1/test2.rar', ExpandConstant('{src}\test2.rar'));
    idpAddFile('http://127.0.0.1/test3.rar', ExpandConstant('{src}\test3.rar'));

    idpDownloadAfter(wpWelcome);
end;
