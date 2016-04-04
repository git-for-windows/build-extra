; Uncomment one of following lines, if you haven't checked "Add IDP include path to ISPPBuiltins.iss" option during IDP installation:
;#pragma include __INCLUDE__ + ";" + ReadReg(HKLM, "Software\Mitrich Software\Inno Download Plugin", "InstallDir")
;#pragma include __INCLUDE__ + ";" + "c:\lib\InnoDownloadPlugin"

[Setup]
AppName          = My Program
AppVersion       = 1.0
DefaultDirName   = {pf}\My Program
DefaultGroupName = My Program
OutputDir        = userdocs:Inno Setup Examples Output

[Languages]
Name: en;    MessagesFile: "compiler:Default.isl"
;Name: be;   MessagesFile: "compiler:Languages\Belarusian.isl"
;Name: zh;   MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: de;    MessagesFile: "compiler:Languages\German.isl"
Name: fi;    MessagesFile: "compiler:Languages\Finnish.isl"
Name: it;    MessagesFile: "compiler:Languages\Italian.isl"
Name: pl;    MessagesFile: "compiler:Languages\Polish.isl"
Name: pt_br; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: ru;    MessagesFile: "compiler:Languages\Russian.isl"

#include <idp.iss>
; Language files must be included after idp.iss and after [Languages] section
;#include <idplang\Belarusian.iss>
;#include <idplang\ChineseSimplified.iss>
#include <idplang\German.iss>
#include <idplang\Finnish.iss>
#include <idplang\Italian.iss>
#include <idplang\Polish.iss>
#include <idplang\BrazilianPortuguese.iss>
#include <idplang\Russian.iss>

; Let's change some of standard strings:
[CustomMessages]
en.IDP_FormCaption=Downloading lot of files...

[Icons]
Name: "{group}\{cm:UninstallProgram,My Program}"; Filename: "{uninstallexe}"

[Code]
procedure InitializeWizard();
begin
    idpAddFile('http://127.0.0.1/test1.zip', ExpandConstant('{tmp}\test1.zip'));
    idpAddFile('http://127.0.0.1/test2.zip', ExpandConstant('{tmp}\test2.zip'));
    idpAddFile('http://127.0.0.1/test3.zip', ExpandConstant('{tmp}\test3.zip'));

    idpDownloadAfter(wpReady);
end;
