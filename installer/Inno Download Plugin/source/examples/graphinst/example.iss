; Uncomment one of following lines, if you haven't checked "Add IDP include path to ISPPBuiltins.iss" option during IDP installation:
;#pragma include __INCLUDE__ + ";" + ReadReg(HKLM, "Software\Mitrich Software\Inno Download Plugin", "InstallDir")
;#pragma include __INCLUDE__ + ";" + "c:\lib\InnoDownloadPlugin"

; This example demonstrates using IDP together with Graphical Installer (http://www.graphical-installer.com/)

#define GRAPHICAL_INSTALLER_PROJECT
 
#ifdef GRAPHICAL_INSTALLER_PROJECT
    #include "example.graphics.iss"
#else
    #define public GraphicalInstallerUI ""
#endif

[Setup]
AppName          = My Program
AppVersion       = 1.0
DefaultDirName   = {pf}\My Program
DefaultGroupName = My Program
OutputDir        = userdocs:Inno Setup Examples Output
WizardSmallImageBackColor = {#GraphicalInstallerUI}

#include <idp.iss>

[Icons]
Name: "{group}\{cm:UninstallProgram,My Program}"; Filename: "{uninstallexe}"
 
[Code]
procedure InitializeWizard();
begin
    idpSetOption('DetailedMode',  '1');

    idpAddFile('http://127.0.0.1/test1.zip', ExpandConstant('{tmp}\test1.zip'));
    idpAddFile('http://127.0.0.1/test2.zip', ExpandConstant('{tmp}\test2.zip'));
    idpAddFile('http://127.0.0.1/test3.zip', ExpandConstant('{tmp}\test3.zip'));

    idpDownloadAfter(wpReady); //Must be called before InitGraphicalInstaller()

    #ifdef GRAPHICAL_INSTALLER_PROJECT
    InitGraphicalInstaller();
    #endif
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
 
procedure CurPageChanged(CurPageID: Integer);
begin
    #ifdef GRAPHICAL_INSTALLER_PROJECT
    PageChangedGraphicalInstaller(CurPageID);
    #endif
end;
 
procedure DeInitializeSetup();
begin
    #ifdef GRAPHICAL_INSTALLER_PROJECT
    DeInitGraphicalInstaller();
    #endif
end;
