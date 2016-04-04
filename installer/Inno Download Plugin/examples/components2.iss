; Uncomment one of following lines, if you haven't checked "Add IDP include path to ISPPBuiltins.iss" option during IDP installation:
;#pragma include __INCLUDE__ + ";" + ReadReg(HKLM, "Software\Mitrich Software\Inno Download Plugin", "InstallDir")
;#pragma include __INCLUDE__ + ";" + "c:\lib\InnoDownloadPlugin"

[Setup]
AppName          = My Program
AppVersion       = 1.0
DefaultDirName   = {pf}\My Program
DefaultGroupName = My Program
OutputDir        = userdocs:Inno Setup Examples Output

#include <idp.iss>

[Types]
Name: full;    Description: "Full installation"
Name: compact; Description: "Compact installation"
Name: custom;  Description: "Custom installation"; Flags: iscustom

[Components]
Name: app; Description: "My Program"; Types: full compact custom; Flags: fixed
Name: src; Description: "Source code (requires internet connection)"; Types: full

[Files]
Source: "components2.iss"; DestDir: "{app}"; Components: app
Source: "{tmp}\prj-sources-1.2.3.zip.iss"; DestDir: "{app}"; Components: src; Flags: external; ExternalSize: 1048576

[Icons]
Name: "{group}\{cm:UninstallProgram,My Program}"; Filename: "{uninstallexe}"

[Code]
procedure InitializeWizard;
begin
    idpDownloadAfter(wpReady);
end;

procedure CurPageChanged(CurPageID: Integer);
begin
    if CurPageID = wpReady then
    begin
        // User can navigate to 'Ready to install' page several times, so we 
        // need to clear file list to ensure that only needed files are added.
        idpClearFiles;

        if IsComponentSelected('src') then
            idpAddFile('https://cool-opensource-project.googlecode.com/files/prj-sources-1.2.3.zip', ExpandConstant('{tmp}\src.zip'));
  end;
end;
