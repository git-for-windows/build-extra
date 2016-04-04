[Setup]
AppName              = My Program
AppVersion           = 1.5
DefaultDirName       = {pf}\My Program
DefaultGroupName     = My Program
UninstallDisplayIcon = {app}\MyProg.exe
Compression          = lzma2
SolidCompression     = yes
OutputDir            = .

#define IDP_DEBUG
#include <idp.iss>

[Files]
Source: "isskintest.iss"; DestDir: "{app}"

Source: "ISSkinU.dll";         Flags: dontcopy
Source: "Office2010.cjstyles"; Flags: dontcopy

[Icons]
Name: "{group}\{cm:UninstallProgram,My Program}"; Filename: "{uninstallexe}"

[Code]
procedure LoadSkin(lpszPath: String; lpszIniFileName: String); external 'LoadSkin@files:isskinu.dll stdcall';
procedure UnloadSkin();                                        external 'UnloadSkin@files:isskinu.dll stdcall';
function  ShowWindow(hWnd: Integer; uType: Integer): Integer;  external 'ShowWindow@user32.dll stdcall';

function InitializeSetup(): Boolean;
begin
	ExtractTemporaryFile('Office2010.cjstyles');
	LoadSkin(ExpandConstant('{tmp}\Office2010.cjstyles'), 'NormalBlue.ini');
	Result := True;
end;

procedure DeinitializeSetup();
begin
	ShowWindow(StrToInt(ExpandConstant('{wizardhwnd}')), 0);
	UnloadSkin();
end;

procedure InitializeWizard();
begin
    idpSetOption('DetailedMode', '1');
    idpSetOption('ErrorDialog',  'FileList');

    idpAddFile('http://127.0.0.1/test1.rar', ExpandConstant('{src}\test1.rar'));
    idpAddFile('http://127.0.0.1/test2.rar', ExpandConstant('{src}\test2.rar'));
    idpAddFile('http://127.0.0.1/test3.rar', ExpandConstant('{src}\test3.rar'));

    idpDownloadAfter(wpWelcome);
end;
