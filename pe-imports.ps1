# pe-imports.ps1 - Parse PE import tables from binary files.
# Outputs in objdump -p compatible format so check-for-missing-dlls.sh
# can use it as a drop-in fallback when /usr/bin/objdump cannot handle
# the PE architecture (e.g. pei-aarch64).
#
# PE format reference:
# https://learn.microsoft.com/en-us/windows/win32/debug/pe-format
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File pe-imports.ps1 FILE...
#        powershell.exe -NoProfile -ExecutionPolicy Bypass -File pe-imports.ps1 -ArchitectureOnly FILE...
#        powershell.exe -NoProfile -ExecutionPolicy Bypass -File pe-imports.ps1 -ArchitectureOnly -FileList FILE
#
# -ArchitectureOnly writes one tab-separated FILE/ARCHITECTURE row for
# every PE file and silently skips non-PE files.

[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$ArchitectureOnly,
    [string]$Root,
    [string]$FileList,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Path
)

if ($FileList) {
    $inputFiles = Get-Content -LiteralPath $FileList
} else {
    $inputFiles = $Path
}

foreach ($file in $inputFiles) {
    if ($Root) {
        $filePath = Join-Path $Root $file
    } else {
        $filePath = $file
    }
    try {
        $stream = [System.IO.File]::OpenRead($filePath)
        try {
            $isMZ = $stream.Length -ge 64 -and
                $stream.ReadByte() -eq 0x4D -and $stream.ReadByte() -eq 0x5A
        } finally {
            $stream.Dispose()
        }
    } catch {
        Write-Error "pe-imports: ${file}: cannot read file"
        continue
    }

    if (-not $isMZ) {
        if (-not $ArchitectureOnly) {
            Write-Error "pe-imports: ${file}: not a PE file"
        }
        continue
    }

    try {
        $bytes = [System.IO.File]::ReadAllBytes($filePath)
    } catch {
        Write-Error "pe-imports: ${file}: cannot read file"
        continue
    }

    try {
        # Look for `PE\0\0`
        $peSignatureOffset = [BitConverter]::ToInt32($bytes, 0x3C)
        if ($peSignatureOffset + 24 -gt $bytes.Length -or
            $bytes[$peSignatureOffset] -ne 0x50 -or $bytes[$peSignatureOffset+1] -ne 0x45 -or
            $bytes[$peSignatureOffset+2] -ne 0 -or $bytes[$peSignatureOffset+3] -ne 0) {
            if (-not $ArchitectureOnly) {
                Write-Error "pe-imports: ${file}: bad PE signature"
            }
            continue
        }
        $peOffset = $peSignatureOffset + 4
        $machine = [BitConverter]::ToUInt16($bytes, $peOffset)

        if ($ArchitectureOnly -and $machine -ne 0x014C) {
            switch ($machine) {
                0x8664 { $architecture = "x64" }
                0xA641 { $architecture = "arm64ec" }
                0xAA64 { $architecture = "arm64" }
                default { $architecture = "unknown-0x$($machine.ToString('X4').ToLowerInvariant())" }
            }
            Write-Output "${file}$([char]9)$architecture$([char]9)0x$($machine.ToString('X4'))"
            continue
        }

        $numSections = [BitConverter]::ToUInt16($bytes, $peOffset + 2)
        $optHdrSize  = [BitConverter]::ToUInt16($bytes, $peOffset + 16)
        # See https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#optional-header-image-only
        $optHdrOff   = $peOffset + 20

        $magic = [BitConverter]::ToUInt16($bytes, $optHdrOff)
        switch ($magic) {
            0x10B { $dataDirBase = $optHdrOff + 96 }   # PE32
            0x20B { $dataDirBase = $optHdrOff + 112 }   # PE32+ (x64/ARM64)
            default {
                $dataDirBase = 0
            }
        }
        if ($dataDirBase -eq 0) {
            if ($ArchitectureOnly) {
                Write-Output "${file}$([char]9)x86$([char]9)0x014C"
            } else {
                Write-Error "pe-imports: ${file}: unknown optional header magic 0x$($magic.ToString('X4'))"
            }
            continue
        }
        $optHdrEnd = $optHdrOff + $optHdrSize

        # Data directory index 1: Import Table (8 bytes per entry); for details, see
        # https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#optional-header-data-directories-image-only
        $importRVA = [uint32]0
        $importRVASize = [uint32]0
        $importDirOff = $dataDirBase + 8
        if ($importDirOff + 8 -le $optHdrEnd -and
            $importDirOff + 8 -le $bytes.Length) {
            $importRVA = [BitConverter]::ToUInt32($bytes, $importDirOff)
            $importRVASize = [BitConverter]::ToUInt32($bytes, $importDirOff + 4)
        }

        # Data directory index 13: Delay Import Descriptor
        $delayImportRVA = [uint32]0
        $delayImportRVASize = [uint32]0
        $delayDirOff = $dataDirBase + 104 # = optHdrOff + 200/216 for 32-bit/64-bit
        if ($delayDirOff + 8 -le $optHdrEnd -and
            $delayDirOff + 8 -le $bytes.Length) {
            $delayImportRVA = [BitConverter]::ToUInt32($bytes, $delayDirOff)
            $delayImportRVASize = [BitConverter]::ToUInt32($bytes, $delayDirOff + 4)
        }

        # Build section table for RVA-to-file-offset translation.
        # Per the PE spec, an RVA belongs to a section when
        # VirtualAddress <= RVA < VirtualAddress + VirtualSize.
        # https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#section-table-section-headers
        $secStart = $optHdrOff + $optHdrSize
        $secVA    = New-Object uint32[] $numSections
        $secRaw   = New-Object uint32[] $numSections
        $secVSz   = New-Object uint32[] $numSections
        for ($i = 0; $i -lt $numSections; $i++) {
            $o = $secStart + $i * 40
            $secVA[$i]  = [BitConverter]::ToUInt32($bytes, $o + 12)  # VirtualAddress
            $secRaw[$i] = [BitConverter]::ToUInt32($bytes, $o + 20)  # PointerToRawData
            $secVSz[$i] = [BitConverter]::ToUInt32($bytes, $o + 8)   # VirtualSize
        }

        # Translate an RVA to a file offset; return -1 on failure.
        $rvaToOffset = {
            param([uint32]$rva)
            for ($j = 0; $j -lt $numSections; $j++) {
                if ($rva -ge $secVA[$j] -and $rva -lt ($secVA[$j] + $secVSz[$j])) {
                    return $rva - $secVA[$j] + $secRaw[$j]
                }
            }
            return -1
        }

        if ($ArchitectureOnly) {
            $architecture = "x86"
            $clrDirOff = $dataDirBase + 112 # Data directory index 14: CLR Runtime Header
            if ($clrDirOff + 8 -le $optHdrEnd -and
                $clrDirOff + 8 -le $bytes.Length) {
                $clrRVA = [BitConverter]::ToUInt32($bytes, $clrDirOff)
                if ($clrRVA -ne 0) {
                    $clrOff = & $rvaToOffset $clrRVA
                    if ($clrOff -ge 0 -and $clrOff + 20 -le $bytes.Length) {
                        $clrFlags = [BitConverter]::ToUInt32($bytes, $clrOff + 16)
                        # IL-only images without COMIMAGE_FLAGS_32BITREQUIRED are AnyCPU.
                        if (($clrFlags -band 0x1) -ne 0 -and
                            ($clrFlags -band 0x2) -eq 0) {
                            $architecture = "anycpu"
                        }
                    }
                }
            }
            Write-Output "${file}$([char]9)$architecture$([char]9)0x014C"
            continue
        }

        if (($importRVA -eq 0 -or $importRVASize -eq 0) -and ($delayImportRVA -eq 0 -or $delayImportRVASize -eq 0)) {
            # No imports; emit header only so the caller still sees the file.
            Write-Output "${file}:"
            continue
        }

        # Walk an import descriptor array and emit "DLL Name:" lines.
        $walkImports = {
            param([uint32]$descRVA, [uint32]$descRVASize, [int]$descSize, [int]$nameField)
            $p = & $rvaToOffset $descRVA
            if ($p -lt 0) { return }

            while ($descRVASize -ge $descSize -and $p + $descSize -le $bytes.Length) {
                $nRVA = [BitConverter]::ToUInt32($bytes, $p + $nameField)
                if ($nRVA -eq 0) { break }

                $nOff = & $rvaToOffset $nRVA
                if ($nOff -lt 0 -or $nOff -ge $bytes.Length) { break }

                $end = $nOff
                while ($end -lt $bytes.Length -and $bytes[$end] -ne 0) { $end++ }

                $dllName = [System.Text.Encoding]::ASCII.GetString($bytes, $nOff, $end - $nOff)
                Write-Output "$([char]9)DLL Name: $dllName"

                $p += $descSize
                $descRVASize -= $descSize
            }
        }

        Write-Output "${file}:"

        # Import directory: 20-byte descriptors, Name RVA at offset 12
        if ($importRVA -ne 0 -and $importRVASize -gt 0) {
            & $walkImports $importRVA $importRVASize 20 12
        }

        # Delay-load import directory: 32-byte descriptors, Name RVA at offset 4
        if ($delayImportRVA -ne 0 -and $delayImportRVASize -gt 0) {
            & $walkImports $delayImportRVA $delayImportRVASize 32 4
        }
    } catch {
        Write-Error "pe-imports: ${file}: $_"
        continue
    }
}
