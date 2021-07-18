$version = "1.0.0"

$packageLayout = [xml]@"
<PackagingLayout xmlns="http://schemas.microsoft.com/appx/makeappx/2017">
  <PackageFamily ID="Git-$($version)" FlatBundle="false" ManifestPath="..\build-extra\msix\appxmanifest.xml" ResourceManager="false">
    <Package ID="Git-x64-$($version)" ProcessorArchitecture="x64">
      <Files>
        <File DestinationPath="Git\*" SourcePath="build\x64\*" />
        <File DestinationPath="Images\*.png" SourcePath="..\build-extra\msix\Images\*.png" />
        <File DestinationPath="Public\Fragments\*" SourcePath="..\build-extra\msix\Fragments\*" />
      </Files>
    </Package>
    <Package ID="Git-x86-$($version)" ProcessorArchitecture="x86">
      <Files>
        <File DestinationPath="Git\*" SourcePath="build\x86\*" />
        <File DestinationPath="Images\*.png" SourcePath="..\build-extra\msix\Images\*.png" />
        <File DestinationPath="Public\Fragments\*" SourcePath="..\build-extra\msix\Fragments\*" />
      </Files>
    </Package>
    <Package ID="Git-ARM64-$($version)" ProcessorArchitecture="ARM64">
      <Files>
        <File DestinationPath="Git\*" SourcePath="build\arm64\*" />
        <File DestinationPath="Images\*.png" SourcePath="..\build-extra\msix\Images\*.png" />
        <File DestinationPath="Public\Fragments\*" SourcePath="..\build-extra\msix\Fragments\*" />
      </Files>
    </Package>
  </PackageFamily>
</PackagingLayout>
"@
$packageLayout.Save("build\PackagingLayout.xml")