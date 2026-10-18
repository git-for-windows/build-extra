#Requires -Version 5.1
<#
.SYNOPSIS
Resolve Git for Windows stack frames using matching PDBs and portable CDB.
.DESCRIPTION
Reuses $HOME\windbg\amd64\cdb.exe (or $HOME\windbg\arm64\cdb.exe on ARM64) and
versioned PDB caches before downloading.
Missing CDB comes from Microsoft's official WinDbg bundle, without app
installation. Missing PDBs come from the corresponding GitHub release.
Opens git.exe as an image, not as a running process. Saves the CDB command
file and full output, and prints source lines with exact-commit links.
See resolve-git-stacktrace.md for cache locations and manual commands.
.EXAMPLE
.\resolve-git-stacktrace.ps1 'git_exe!start_command+0x8fc'
.EXAMPLE
.\resolve-git-stacktrace.ps1 -Frame 'git.exe+0x29113c',
    'git_exe!launch_specified_editor+0x198'
.EXAMPLE
.\resolve-git-stacktrace.ps1 -SelfTest
#>
[CmdletBinding(DefaultParameterSetName = 'Resolve')]
param(
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Resolve')]
    [ValidateNotNullOrEmpty()]
    [string[]]$Frame,
    [Parameter(Mandatory, ParameterSetName = 'SelfTest')]
    [ValidateScript({ $_.IsPresent })]
    [switch]$SelfTest,
    [string]$GitExecutable,
    [string]$DebuggerDirectory = (Join-Path $env:USERPROFILE 'windbg')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-CachedDownload {
    param([string]$Uri, [string]$Path)

    if (Test-Path -LiteralPath $Path -PathType Leaf) { return }
    $partial = "$Path.partial"
    if (Test-Path -LiteralPath $partial) {
        throw "Incomplete download exists: $partial. Inspect it before retrying."
    }
    New-Item -ItemType Directory -Path (Split-Path $Path) -Force |
        Out-Null
    Write-Host "Downloading $Uri"
    try {
        $ErrorActionPreference = 'Continue'
        & curl.exe --fail --location --silent --show-error --output $partial `
            --write-out 'Downloaded bytes: %{size_download}\n' $Uri 2>&1 |
            Tee-Object -FilePath "$Path.download.log" -ErrorAction Stop |
            Out-Host
    }
    finally { $ErrorActionPreference = 'Stop' }
    if ($LASTEXITCODE -ne 0) {
        throw "Download failed; partial file retained at $partial"
    }
    Move-Item -LiteralPath $partial -Destination $Path
}

function Get-PortableCdb {
    param([string]$Directory)

    $hostArch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or
        $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') { 'arm64' } else { 'x64' }
    $cdbSubdir = if ($hostArch -eq 'arm64') { 'arm64' } else { 'amd64' }
    $cdb = Join-Path $Directory "$cdbSubdir\cdb.exe"
    if (-not (Test-Path -LiteralPath $cdb -PathType Leaf)) {
        $downloads = Join-Path $Directory 'downloads'
        $installer = Join-Path $downloads 'windbg.appinstaller'
        Get-CachedDownload 'https://aka.ms/windbg/download' $installer
        [xml]$metadata = [IO.File]::ReadAllText($installer)
        $main = $metadata.AppInstaller.MainBundle
        if ($main.Name -ne 'Microsoft.WinDbg' -or
            $main.Version -notmatch '^\d+\.\d+\.\d+\.\d+$') {
            throw "Unexpected WinDbg download manifest: $installer"
        }
        $bundle = Join-Path $downloads "windbg-$($main.Version).msixbundle"
        $msix = Join-Path $downloads "windbg-$hostArch-$($main.Version).msix"
        if (-not (Test-Path -LiteralPath $msix -PathType Leaf)) {
            Get-CachedDownload $main.Uri $bundle
            $zip = [IO.Compression.ZipFile]::OpenRead($bundle)
            try {
                $entry = $zip.GetEntry('AppxMetadata/AppxBundleManifest.xml')
                if (-not $entry) { throw "Bundle manifest missing: $bundle" }
                $reader = New-Object IO.StreamReader($entry.Open())
                try { [xml]$manifest = $reader.ReadToEnd() }
                finally { $reader.Dispose() }
                $packages = @($manifest.Bundle.Packages.Package |
                    Where-Object {
                        $_.Architecture -eq $hostArch -and
                        $_.Type -eq 'application'
                    })
                if ($packages.Count -ne 1) {
                    throw "Expected one $hostArch application in $bundle"
                }
                $entry = $zip.GetEntry($packages[0].FileName)
                if (-not $entry) { throw "$hostArch package missing: $bundle" }
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $msix)
            }
            finally { $zip.Dispose() }
        }
        [IO.Compression.ZipFile]::ExtractToDirectory($msix, $Directory)
    }
    $signature = Get-AuthenticodeSignature -LiteralPath $cdb
    if ($signature.Status -ne 'Valid' -or
        $signature.SignerCertificate.Subject -notmatch
            '^CN=Microsoft Corporation,') {
        throw "CDB does not have a valid Microsoft signature: $cdb"
    }
    return $cdb
}

function Find-InstalledGit {
    $root = $null
    foreach ($key in @('HKCU:\SOFTWARE\GitForWindows',
                      'HKLM:\SOFTWARE\GitForWindows')) {
        if (Test-Path -LiteralPath $key) {
            $root = (Get-ItemProperty -LiteralPath $key).InstallPath
            if ($root) { break }
        }
    }
    if (-not $root) { $root = Join-Path $env:ProgramFiles 'Git' }
    $candidates = @(foreach ($platform in
        @('ucrt64', 'mingw64', 'mingw32', 'clangarm64')) {
        $candidate = Join-Path $root "$platform\bin\git.exe"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { $candidate }
    })
    if ($candidates.Count -gt 1) {
        throw 'Specify -GitExecutable with the actual installed bin\git.exe.'
    }
    if ($candidates.Count -eq 1) { return $candidates[0] }
}

function Get-CachedGitRelease {
    param([string]$Version, [string]$Directory)

    $path = Join-Path $Directory 'release.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        New-Item -ItemType Directory -Path $Directory -Force | Out-Null
        $json = & gh api "repos/git-for-windows/git/releases/tags/v$Version"
        if ($LASTEXITCODE -ne 0) {
            throw "Could not retrieve the official v$Version release"
        }
        [IO.File]::WriteAllText($path, ($json -join "`n"),
            (New-Object Text.UTF8Encoding($false)))
    }
    $release = [IO.File]::ReadAllText($path) | ConvertFrom-Json
    if ($release.tag_name -ne "v$Version") {
        throw "Wrong release metadata in $path"
    }
    return $release
}

function Get-VerifiedArchive {
    param($Asset, [string]$Directory)

    $digest = [regex]::Match([string]$Asset.digest,
        '^sha256:([0-9a-f]{64})$')
    if (-not $digest.Success) {
        throw "No published SHA-256 digest for $($Asset.name)"
    }
    $archive = Join-Path $Directory $Asset.name
    Get-CachedDownload $Asset.browser_download_url $archive
    $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    if ($hash -ne $digest.Groups[1].Value) {
        throw "Archive SHA-256 mismatch: $archive"
    }
    return $archive
}

$DebuggerDirectory = [IO.Path]::GetFullPath($DebuggerDirectory)
if ($SelfTest) {
    $testVersion = '2.56.0.windows.2'
    $testCommit = 'cc4dbf752a05efdc0e04e71fd3e8110d11bdd35c'
    $expected = [ordered]@{
        'git_exe!start_command+0x8fc' = 'compat\mingw.h:38'
        'git.exe+0x29113c' = 'compat\mingw.h:38'
        'git_exe!launch_specified_editor+0x198' = 'editor.c:99'
        'git_exe!cmd_commit+0x186f' = 'builtin\commit.c:1124'
        'git_exe!handle_builtin+0x1e8' = 'git.c:511'
        'git_exe!cmd_main+0x3ca' = 'git.c:906'
        'git_exe!main+0x22' = 'common-main.c:12'
        'git_exe!wmain+0x2ae' = 'compat\mingw.c:4479'
    }
    $Frame = [string[]]$expected.Keys
    if (-not $GitExecutable) {
        $fixture = Join-Path $DebuggerDirectory "tests\git-$testVersion"
        $reference = Join-Path $fixture 'ucrt64\bin\git.exe'
        if (Test-Path -LiteralPath $reference -PathType Leaf) {
            $GitExecutable = $reference
        }
        else {
            $installed = Find-InstalledGit
            if ($installed -and
                (Get-FileHash -LiteralPath $installed -Algorithm SHA256).Hash `
                    -eq
                'B824434DFE3B5F9CF648AF6C9CC8CB1F6A982CC6E13B6C6EBBE6533C7E51CC2E') {
                $GitExecutable = $installed
            }
            else {
                Write-Host "Caching the Git $testVersion regression fixture"
                $symbols = Join-Path $DebuggerDirectory `
                    "symbols\ucrt64\$testVersion"
                $release = Get-CachedGitRelease $testVersion $symbols
                $assets = @($release.assets | Where-Object {
                    $_.name -eq 'MinGit-2.56.0.2-64-bit.zip'
                })
                if ($assets.Count -ne 1) {
                    throw "Expected the official MinGit fixture for $testVersion"
                }
                $archive = Get-VerifiedArchive $assets[0] $fixture
                [IO.Compression.ZipFile]::ExtractToDirectory($archive, $fixture)
                if (-not (Test-Path -LiteralPath $reference -PathType Leaf)) {
                    throw "Native reference image missing from $archive"
                }
                $GitExecutable = $reference
            }
        }
    }
}

$expressions = @(foreach ($item in $Frame) {
    if ($item -match '^git(?:_exe|\.exe)?\+(0x[0-9a-f]+)$') {
        "git+$($Matches[1])"
    }
    elseif ($item -match
        '^(?:git(?:_exe|\.exe)?!)?([a-z_][a-z0-9_]*)(\+0x[0-9a-f]+)?$') {
        "git!$($Matches[1])$($Matches[2])"
    }
    else {
        throw "Unsupported Git frame: $item. Use git_exe!name+0xOFFSET."
    }
})

if (-not $GitExecutable) {
    $GitExecutable = Find-InstalledGit
    if (-not $GitExecutable) {
        throw 'Specify -GitExecutable with the actual installed bin\git.exe.'
    }
}
$GitExecutable = (Resolve-Path -LiteralPath $GitExecutable).Path
$bin = Split-Path $GitExecutable
$platform = Split-Path (Split-Path $bin) -Leaf
$pdbSuffix = @{
    ucrt64 = 'ucrt64'
    mingw64 = '64-bit'
    mingw32 = '32-bit'
    clangarm64 = 'arm64'
}[$platform]
if ((Split-Path $GitExecutable -Leaf) -ne 'git.exe' -or
    (Split-Path $bin -Leaf) -ne 'bin' -or
    -not $pdbSuffix) {
    throw 'Use the native platform\bin\git.exe, not the cmd\git.exe wrapper.'
}
$build = & $GitExecutable version --build-options
if ($LASTEXITCODE -ne 0) { throw "Could not identify $GitExecutable" }
$buildText = $build -join "`n"
$versionMatch = [regex]::Match($buildText,
    '(?m)^git version (\d+\.\d+\.\d+\.windows\.\d+)\s*$')
$commitMatch = [regex]::Match($buildText,
    '(?m)^built from commit: ([0-9a-f]{40})\s*$')
if (-not $versionMatch.Success -or -not $commitMatch.Success) {
    throw "Expected an official Git for Windows build identity:`n$buildText"
}
$version = $versionMatch.Groups[1].Value
$commit = $commitMatch.Groups[1].Value
if ($SelfTest -and ($version -ne $testVersion -or $commit -ne $testCommit)) {
    throw "Self-test requires Git $testVersion built from $testCommit"
}
$cdb = Get-PortableCdb $DebuggerDirectory
$symbols = Join-Path $DebuggerDirectory "symbols\$platform\$version"
New-Item -ItemType Directory -Path $symbols -Force | Out-Null
$pdb = Join-Path $symbols 'git.pdb'

if (-not (Test-Path -LiteralPath $pdb -PathType Leaf)) {
    $release = Get-CachedGitRelease $version $symbols
    $assets = @($release.assets | Where-Object {
        $_.name -like "pdbs-for-git-$pdbSuffix-*.zip"
    })
    if ($assets.Count -ne 1) {
        throw "Expected one official $pdbSuffix PDB archive for v$version"
    }
    $archive = Get-VerifiedArchive $assets[0] $symbols
    $zip = [IO.Compression.ZipFile]::OpenRead($archive)
    try {
        $entry = $zip.GetEntry("$platform/bin/git.pdb")
        if (-not $entry) { throw "Native git.pdb missing from $archive" }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $pdb)
    }
    finally { $zip.Dispose() }
}

$run = 'cdb-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') +
    '-' + [guid]::NewGuid().ToString('N')
$commandFile = Join-Path $symbols "$run.commands"
$log = Join-Path $symbols "$run.log"
$commands = @(
    ".echo Git version: $version"
    ".echo Built from commit: $commit"
    '.symopt-0xc0'
    '.reload /f'
    '!lmi git'
)
for ($i = 0; $i -lt $expressions.Count; $i++) {
    $commands += @(
        ".echo BEGIN-FRAME-$i"
        "? $($expressions[$i])"
        "ln $($expressions[$i])"
        "u $($expressions[$i]) L8"
        ".echo END-FRAME-$i"
    )
}
$commands += 'q'
[IO.File]::WriteAllLines($commandFile, $commands, [Text.Encoding]::ASCII)
try {
    $ErrorActionPreference = 'Continue'
    $output = & $cdb -sins -ses -lines -y $symbols -z $GitExecutable `
        -cf $commandFile 2>&1 | Tee-Object -FilePath $log -ErrorAction Stop
}
finally { $ErrorActionPreference = 'Stop' }
if ($LASTEXITCODE -ne 0) { throw "CDB failed; see $log" }
$text = ($output | ForEach-Object { "$_" }) -join "`n"
if ($text -notmatch 'Load Report:\s+private symbols & lines') {
    throw "Matching private PDBs with source lines were not loaded; see $log"
}
$identity = [regex]::Match($text,
    'GUID: \{([0-9A-F-]+)\}\s+Age: (\d+),')
if (-not $identity.Success) {
    throw "Could not read the image's PDB GUID and age; see $log"
}
if ($SelfTest -and
    ($identity.Groups[1].Value -ne '4CB9821A-11A9-46FA-9F9B-680236AB44D9' -or
     $identity.Groups[2].Value -ne '1')) {
    throw "Self-test requires the original PDB GUID and age; see $log"
}
Write-Output "Image: $GitExecutable ($version)"
Write-Output "Matching PDB: $($identity.Groups[1]), age $($identity.Groups[2])"
for ($i = 0; $i -lt $expressions.Count; $i++) {
    $block = [regex]::Match($text,
        "(?ms)^BEGIN-FRAME-$i\r?\n(.*?)^END-FRAME-$i\r?$")
    $line = [regex]::Match($block.Groups[1].Value,
        '(?m)^(.+\.(?:c|h))\((\d+)\)(?:\+0x[0-9a-f]+)?\r?$')
    if (-not $block.Success -or -not $line.Success) {
        throw "No source line resolved for $($Frame[$i]); see $log"
    }
    $file = $line.Groups[1].Value
    $number = $line.Groups[2].Value
    if ($SelfTest) {
        $location = $file.Replace('/', '\') + ":$number"
        if ($location -cne $expected[$Frame[$i]]) {
            throw ("Self-test $($Frame[$i]): expected " +
                "$($expected[$Frame[$i]]), got $location; see $log")
        }
    }
    Write-Output "$($Frame[$i]) -> ${file}:$number"
    if ([IO.Path]::IsPathRooted($file) -or
        ($file -split '[/\\]') -contains '..') {
        Write-Warning "Compiler source path is outside the Git tree: $file"
    }
    else {
        $relative = $file.Replace('\', '/')
        Write-Output ("https://github.com/git-for-windows/git/blob/" +
            "$commit/$relative#L$number")
    }
}
Write-Output "PDB: $pdb"
Write-Output "Commands: $commandFile"
Write-Output "Full debugger output: $log"
if ($SelfTest) {
    Write-Output "Self-test passed: $($expected.Count) frames for Git $testVersion"
}
