#pragma include __INCLUDE__ + ";" + ReadReg(HKLM, "Software\Mitrich Software\Inno Download Plugin", "InstallDir")

[Setup]
AppName                    = My Program
AppVersion                 = 1.5
DefaultDirName             = {pf}\My Program
DefaultGroupName           = My Program
ShowUndisplayableLanguages = yes
OutputDir                  = .

#define IDP_DEBUG
#include <idp.iss>

[Files]
Source: "idptest.iss"; DestDir: "{app}"

[Icons]
Name: "{group}\{cm:UninstallProgram,My Program}"; Filename: "{uninstallexe}"

[Code]
procedure InitializeWizard();
begin
    MsgBox(Format('IDP version constants: IDP_VER_STR = %s, IDP_VER = 0x%x, IDP_VER_MAJOR = %s, IDP_VER_MINOR = %s, IDP_VER_REV = %s, IDP_VER_BUILD = %s', ['{#IDP_VER_STR}', StrToInt('{#IDP_VER}'), '{#IDP_VER_MAJOR}', '{#IDP_VER_MINOR}', '{#IDP_VER_REV}', '{#IDP_VER_BUILD}']),
                  mbInformation, MB_OK);  
end;
