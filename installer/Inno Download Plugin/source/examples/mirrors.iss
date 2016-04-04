; Uncomment one of following lines, if you haven't checked "Add IDP include path to ISPPBuiltins.iss" option during IDP installation:
;#pragma include __INCLUDE__ + ";" + ReadReg(HKLM, "Software\Mitrich Software\Inno Download Plugin", "InstallDir")
;#pragma include __INCLUDE__ + ";" + "c:\lib\InnoDownloadPlugin"

[Setup]
AppName          = My Program
AppVersion       = 1.5
DefaultDirName   = {pf}\My Program
DefaultGroupName = My Program
OutputDir        = .

#include <idp.iss>

[Icons]
Name: "{group}\{cm:UninstallProgram,My Program}"; Filename: "{uninstallexe}"

[Code]
procedure InitializeWizard();
begin
    idpAddFile('http://127.0.0.1/test1.rar', ExpandConstant('{src}\test1.rar'));
    idpAddFile('http://127.0.0.1/test2.rar', ExpandConstant('{src}\test2.rar'));
        //Mirrors for http://127.0.0.1/test2.rar:
        idpAddMirror('http://127.0.0.1/test2.rar', 'http://www.1st.mirror/test2.rar');
        idpAddMirror('http://127.0.0.1/test2.rar', 'http://www.2nd.mirror/test2.rar');
    idpAddFile('http://127.0.0.1/test3.rar', ExpandConstant('{src}\test3.rar'));

    idpDownloadAfter(wpReady);
end;
