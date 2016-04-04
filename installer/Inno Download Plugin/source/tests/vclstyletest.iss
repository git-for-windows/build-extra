#pragma include __INCLUDE__ + ";" + ReadReg(HKLM, "Software\Mitrich Software\Inno Download Plugin", "InstallDir")

[Setup]
AppName                    = My Program
AppVersion                 = 1.5
DefaultDirName             = {pf}\My Program
DefaultGroupName           = My Program
OutputDir                  = .

#define IDP_DEBUG
#include <idp.iss>

[Files]
Source: "VCLStylesInno.dll"; Flags: dontcopy
Source: "SlateClassico.vsf"; Flags: dontcopy

[Icons]
Name: "{group}\{cm:UninstallProgram,My Program}"; Filename: "{uninstallexe}"

[Code]
procedure LoadVCLStyle(VClStyleFile: String); external 'LoadVCLStyleW@files:VclStylesInno.dll stdcall';
procedure UnLoadVCLStyles;                    external 'UnLoadVCLStyles@files:VclStylesInno.dll stdcall';

function InitializeSetup(): Boolean;
begin
	ExtractTemporaryFile('SlateClassico.vsf');
	LoadVCLStyle(ExpandConstant('{tmp}\SlateClassico.vsf'));
	Result := True;
end;

procedure DeinitializeSetup();
begin
	UnLoadVCLStyles;
end;

procedure InitializeWizard();
begin
    idpSetOption('DetailedMode',  '1');
    idpSetOption('AllowContinue', '1');
    idpSetOption('ErrorDialog',   'UrlList');

    idpAddFile('http://127.0.0.1/test1.rar', ExpandConstant('{src}\test1.rar'));
    idpAddFile('http://127.0.0.1/test2.rar', ExpandConstant('{src}\test2.rar'));
    idpAddFile('http://127.0.0.1/test3.rar', ExpandConstant('{src}\test3.rar'));

    idpDownloadAfter(wpWelcome);
end;
