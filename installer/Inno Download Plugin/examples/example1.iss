; Uncomment one of following lines, if you haven't checked "Add IDP include path to ISPPBuiltins.iss" option during IDP installation:
;#pragma include __INCLUDE__ + ";" + ReadReg(HKLM, "Software\Mitrich Software\Inno Download Plugin", "InstallDir")
;#pragma include __INCLUDE__ + ";" + "c:\lib\InnoDownloadPlugin"

[Setup]
AppName                = My Program
AppVersion             = 1.0
DefaultDirName         = {pf}\My Program
DefaultGroupName       = My Program
; Size of files to download:
ExtraDiskSpaceRequired = 1048576
OutputDir              = userdocs:Inno Setup Examples Output

#include <idp.iss>

[Icons]
Name: "{group}\{cm:UninstallProgram,My Program}"; Filename: "{uninstallexe}"

[UninstallDelete]
Type: files; Name: "{app}\test1.zip"
Type: files; Name: "{app}\test2.zip"
Type: files; Name: "{app}\test3.zip"

[Code]
procedure InitializeWizard();
begin
    idpAddFile('http://127.0.0.1/test1.zip', ExpandConstant('{tmp}\test1.zip'));
    idpAddFile('http://127.0.0.1/test2.zip', ExpandConstant('{tmp}\test2.zip'));
    idpAddFile('http://127.0.0.1/test3.zip', ExpandConstant('{tmp}\test3.zip'));

    idpDownloadAfter(wpReady);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
    if CurStep = ssPostInstall then 
    begin
        // Copy downloaded files to application directory
        FileCopy(ExpandConstant('{tmp}\test1.zip'), ExpandConstant('{app}\test1.zip'), false);
        FileCopy(ExpandConstant('{tmp}\test2.zip'), ExpandConstant('{app}\test2.zip'), false);
        FileCopy(ExpandConstant('{tmp}\test3.zip'), ExpandConstant('{app}\test3.zip'), false);
    end;
end;


