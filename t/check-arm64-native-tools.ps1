param(
    [Parameter(Mandatory = $true)]
    [string]$Root
)

$cases = @(
    @{ Name = "bunzip2"; Arguments = @("--help"); ExitCode = 0 },
    @{ Name = "bzcat"; Arguments = @("--help"); ExitCode = 0 },
    @{ Name = "bzip2"; Arguments = @("--help"); ExitCode = 0 },
    @{ Name = "bzip2recover"; Arguments = @(); ExitCode = 1 },
    @{ Name = "nettle-hash"; Arguments = @("--help"); ExitCode = 0 },
    @{ Name = "nettle-lfib-stream"; Arguments = @("--help"); ExitCode = 1 },
    @{ Name = "nettle-pbkdf2"; Arguments = @("--help"); ExitCode = 0 },
    @{ Name = "pkcs1-conv"; Arguments = @("--help"); ExitCode = 0 },
    @{ Name = "sexp-conv"; Arguments = @("--help"); ExitCode = 0 },
    @{ Name = "p11-kit"; Arguments = @("--help"); ExitCode = 0 },
    @{ Name = "trust"; Arguments = @("--help"); ExitCode = 0 }
)

foreach ($case in $cases) {
    $x64 = Join-Path $Root "usr\bin\$($case.Name).exe"
    if (Test-Path -LiteralPath $x64) {
        throw "The ARM64 payload still contains $x64"
    }

    $native = Join-Path $Root "clangarm64\bin\$($case.Name).exe"
    if (-not (Test-Path -LiteralPath $native)) {
        throw "The ARM64 payload does not contain $native"
    }

    & $native @($case.Arguments) *> $null
    if ($LASTEXITCODE -ne $case.ExitCode) {
        throw "$native returned $LASTEXITCODE instead of $($case.ExitCode)"
    }
}
