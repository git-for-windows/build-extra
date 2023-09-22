param(
    [Parameter(Mandatory = $true, HelpMessage="Enable or disable mandatory ASLR for the target executables.")][ValidateSet('Enable', 'Disable')][string]$Action,
    [Parameter(mandatory=$true, ValueFromRemainingArguments=$true, HelpMessage="The paths of the target executables.")][string[]]$paths
)

# Define a string array that will hold the target executable paths.
$targets = @()

# Parse the target executable paths.
$paths | ForEach-Object {
    if (Test-Path -Path "$_" -PathType Container) {
        Get-ChildItem -Path "$_" -Filter *.exe -File | ForEach-Object { $targets += $_.FullName }
    }
    elseif (Test-Path -Path "$_" -PathType File -Filter *.exe) {
        $targets += (Get-ChildItem -Path "$_" -File).FullName
    }
    else {
        throw New-Object ArgumentException("The path `"$_`" provided is not valid!")
    }
}

# Configure the security settings for each executable in the targets array.
$targets | ForEach-Object { Invoke-Expression "Set-ProcessMitigation -Name `"$_`" -$Action ForceRelocateImages" }
