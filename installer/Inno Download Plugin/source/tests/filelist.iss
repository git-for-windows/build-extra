; Uncomment one of following lines, if you haven't checked "Add IDP include path to ISPPBuiltins.iss" option during IDP installation:
;#pragma include __INCLUDE__ + ";" + ReadReg(HKLM, "Software\Mitrich Software\Inno Download Plugin", "InstallDir")
;#pragma include __INCLUDE__ + ";" + "c:\lib\InnoDownloadPlugin"

[Setup]
AppName          = My Program
AppVersion       = 1.0
DefaultDirName   = {pf}\My Program
DefaultGroupName = My Program
OutputDir        = .

#define IDP_DEBUG
#include <idp.iss>

[Icons]
Name: "{group}\{cm:UninstallProgram,My Program}"; Filename: "{uninstallexe}"

[UninstallDelete]
Type: files; Name: "{app}\test1.zip"
Type: files; Name: "{app}\test2.zip"
Type: files; Name: "{app}\test3.zip"

[Code]
var FileList: TStringList;

procedure InitializeWizard();
var i: Integer;
    r: Boolean;
begin
    idpTrace('Downloading file list...');
    r := idpDownloadFile('http://127.0.0.1/FileList.txt', ExpandConstant('{src}\FileList.txt'));
    
    if r then idpTrace('File list OK')
    else      idpTrace('File list NOT DOWNLOADED');
    
    FileList := TStringList.Create;
    FileList.LoadFromFile(ExpandConstant('{src}\FileList.txt'));
    
    for i := 0 to FileList.Count-1 do
        idpAddFile('http://127.0.0.1/' + FileList[i], ExpandConstant('{src}\') + FileList[i]);
    
    idpDownloadAfter(wpWelcome);
end;
