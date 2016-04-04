[Setup]
AppName                    = My Program
AppVersion                 = 1.5
DefaultDirName             = {pf}\My Program
DefaultGroupName           = My Program
OutputDir                  = .

[Languages]
Name: en;    MessagesFile: "compiler:Default.isl"
Name: be;    MessagesFile: "compiler:Languages\Belarusian.isl"
Name: de;    MessagesFile: "compiler:Languages\German.isl"
Name: fi;    MessagesFile: "compiler:Languages\Finnish.isl"
Name: pl;    MessagesFile: "compiler:Languages\Polish.isl"
Name: pt_br; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: ru;    MessagesFile: "compiler:Languages\Russian.isl"

#define IDP_DEBUG

#include <idp.iss>
#include <idplang\Belarusian.iss>
#include <idplang\German.iss>
#include <idplang\Finnish.iss>
#include <idplang\Polish.iss>
#include <idplang\BrazilianPortuguese.iss>
#include <idplang\Russian.iss>

[Files]
Source: "proxytest.iss"; DestDir: "{app}"

[Icons]
Name: "{group}\{cm:UninstallProgram,My Program}"; Filename: "{uninstallexe}"

[Code]
procedure InitializeWizard();
begin
    idpSetOption('DetailedMode',  '1');
    idpSetOption('AllowContinue', '1');
    idpSetOption('RetryButton',   '0');
      
    idpSetProxyName('192.168.1.2:808');
    idpSetProxyLogin('admin', 'password');
    {
    idpSetOption('ProxyName',     '192.168.1.2:808'); 
    idpSetOption('ProxyUserName', 'admin');
    idpSetOption('ProxyPassword', 'password');
    }
    idpAddFile('https://inno-download-plugin.googlecode.com/archive/c1e255ce3c0265a61033c6bc2f8b8d8efa157da1.zip', ExpandConstant('{src}\idp.zip'));
    idpDownloadAfter(wpWelcome);
end;
