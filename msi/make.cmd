rmdir /s/q build

rem TODO: Where should the git-credential-winstore, gcm and posh-git binaries
rem       be found/stored?

rem TODO: Generate GitComponents.wxs from ..\make-file-list.sh
rem
rem       1. Files installed to `bin\` folder use Directory='BinFolder' and
rem          all others use the pattern Directory='INSTALLFOLDER:\path\'.
rem
rem       2. The `git.exe` file in `BinFolder` is given the explicit
rem          Id='GetExe' all other files are anonymous (do not have an Id).

rem Build the .msi.
rem
rem TODO: Correctly set the bind paths (change the -b gitfileshere switch)
rem       to the real source location for the binaries to include in the
rem       installation package.
rem
rem TODO: Set the output paths appropriately.
rem
wix\candle.exe GitProduct.wxs GitComponents.wxs GitCredStoreComponents.wxs GitPoshComponents.wxs -o build\obj\  -ext WixUtilExtension
wix\light.exe build\obj\GitProduct.wixobj build\obj\GitComponents.wixobj build\obj\GitCredStoreComponents.wixobj build\obj\GitPoshComponents.wixobj -o build\msi\git.msi -ext WixUtilExtension -b gitfileshere -b ..\installer -sval

rem Build the bundle.
rem
rem TODO: Set bind path (-b build\msi switch) to the output path of the MSI
rem       build above.
rem
rem TODO: Set the output paths appropriately.
rem
wix\candle.exe GitBundle.wxs -o build\obj\ -ext WixBalExtension
wix\light.exe build\obj\GitBundle.wixobj -o build\gitsetup.exe -b build\msi -b ..\installer -ext WixBalExtension
