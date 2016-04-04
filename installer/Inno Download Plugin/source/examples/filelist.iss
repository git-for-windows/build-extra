; Uncomment one of following lines, if you haven't checked "Add IDP include path to ISPPBuiltins.iss" option during IDP installation:
;#pragma include __INCLUDE__ + ";" + ReadReg(HKLM, "Software\Mitrich Software\Inno Download Plugin", "InstallDir")
;#pragma include __INCLUDE__ + ";" + "c:\lib\InnoDownloadPlugin"

; This example downloads text file, which lists files to download, then downloads each file, specified in filelist.txt
; File list has following format: each file name on new line:
; file1.xyz
; file2.xyz
; file3.xyz

[Setup]
AppName          = My Program
AppVersion       = 1.0
DefaultDirName   = {pf}\My Program
DefaultGroupName = My Program
OutputDir        = userdocs:Inno Setup Examples Output

#include <idp.iss>

[Icons]
Name: "{group}\{cm:UninstallProgram,My Program}"; Filename: "{uninstallexe}"

[Code]
var FileList: TStringList;

procedure InitializeWizard();
var i: Integer;
begin
    //Downloading file list
    idpDownloadFile('http://127.0.0.1/FileList.txt', ExpandConstant('{tmp}\FileList.txt'));
    
    FileList := TStringList.Create;
    FileList.LoadFromFile(ExpandConstant('{tmp}\FileList.txt'));
    
    for i := 0 to FileList.Count-1 do
        //Add each file to download queque
        idpAddFile('http://127.0.0.1/' + FileList[i], ExpandConstant('{tmp}\') + FileList[i]);
    
    idpDownloadAfter(wpReady);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var i: Integer;
begin
    if CurStep = ssPostInstall then 
    begin
        // Copy downloaded files to application directory
        for i := 0 to FileList.Count-1 do
            FileCopy(ExpandConstant('{tmp}\') + FileList[i], ExpandConstant('{app}\') + FileList[i], false);
    end;
end;


