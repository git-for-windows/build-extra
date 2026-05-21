# pe-imports.ps1 - Parse PE import tables from binary files.
# Outputs in objdump -p compatible format so check-for-missing-dlls.sh
# can use it as a drop-in fallback when /usr/bin/objdump cannot handle
# the PE architecture (e.g. pei-aarch64).
#
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File pe-imports.ps1 FILE...

foreach ($file in $args) {
    try {
        $bytes = [System.IO.File]::ReadAllBytes($file)
    } catch {
        Write-Error "pe-imports: ${file}: cannot read file"
        continue
    }

    try {
        if ($bytes.Length -lt 64 -or
            $bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) {
            Write-Error "pe-imports: ${file}: not a PE file"
            continue
        }

        $peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
        if ($peOffset + 24 -gt $bytes.Length -or
            $bytes[$peOffset] -ne 0x50 -or $bytes[$peOffset+1] -ne 0x45 -or
            $bytes[$peOffset+2] -ne 0 -or $bytes[$peOffset+3] -ne 0) {
            Write-Error "pe-imports: ${file}: bad PE signature"
            continue
        }

        $numSections = [BitConverter]::ToUInt16($bytes, $peOffset + 6)
        $optHdrSize  = [BitConverter]::ToUInt16($bytes, $peOffset + 20)
        $optHdrOff   = $peOffset + 24

        $magic = [BitConverter]::ToUInt16($bytes, $optHdrOff)
        switch ($magic) {
            0x10B { $importDirOff = $optHdrOff + 104 }  # PE32
            0x20B { $importDirOff = $optHdrOff + 120 }  # PE32+ (x64/ARM64)
            default {
                Write-Error "pe-imports: ${file}: unknown optional header magic 0x$($magic.ToString('X4'))"
                continue
            }
        }

        $importRVA = [BitConverter]::ToUInt32($bytes, $importDirOff)
        if ($importRVA -eq 0) {
            # No imports; emit header only so the caller still sees the file.
            Write-Output "${file}:"
            continue
        }

        # Build section table for RVA-to-file-offset translation.
        $secStart = $optHdrOff + $optHdrSize
        $secVA  = New-Object uint32[] $numSections
        $secRaw = New-Object uint32[] $numSections
        $secSz  = New-Object uint32[] $numSections
        for ($i = 0; $i -lt $numSections; $i++) {
            $o = $secStart + $i * 40
            $secVA[$i]  = [BitConverter]::ToUInt32($bytes, $o + 12)
            $secRaw[$i] = [BitConverter]::ToUInt32($bytes, $o + 20)
            $secSz[$i]  = [BitConverter]::ToUInt32($bytes, $o + 16)
        }

        # Translate an RVA to a file offset; return -1 on failure.
        $rvaToOffset = {
            param([uint32]$rva)
            for ($j = 0; $j -lt $numSections; $j++) {
                if ($rva -ge $secVA[$j] -and $rva -lt ($secVA[$j] + $secSz[$j])) {
                    return $rva - $secVA[$j] + $secRaw[$j]
                }
            }
            return -1
        }

        Write-Output "${file}:"

        # Walk the import descriptor array (20-byte entries, null-terminated).
        $pos = & $rvaToOffset $importRVA
        if ($pos -lt 0) { continue }

        while ($pos + 20 -le $bytes.Length) {
            $nameRVA = [BitConverter]::ToUInt32($bytes, $pos + 12)
            if ($nameRVA -eq 0) { break }

            $nameOff = & $rvaToOffset $nameRVA
            if ($nameOff -lt 0 -or $nameOff -ge $bytes.Length) { break }

            $end = $nameOff
            while ($end -lt $bytes.Length -and $bytes[$end] -ne 0) { $end++ }

            $dllName = [System.Text.Encoding]::ASCII.GetString($bytes, $nameOff, $end - $nameOff)
            Write-Output "$([char]9)DLL Name: $dllName"

            $pos += 20
        }
    } catch {
        Write-Error "pe-imports: ${file}: $_"
        continue
    }
}
