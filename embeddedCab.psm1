function Dump-EmbeddedCabFromOffset {
    param(
        [string]$SourceFilePath,
        [int]$Offset,
        [string]$DestinationFilePath
    )

    try {
        # Open the source file for reading
        $fileStream = [System.IO.File]::OpenRead($SourceFilePath)

        # Move to the specified offset
        $fileStream.Seek($Offset, [System.IO.SeekOrigin]::Begin)

        # Open the destination file for writing
        $outputStream = [System.IO.File]::OpenWrite($DestinationFilePath)

        # Create a buffer to hold the data read from the source file
        $buffer = New-Object Byte[] 4096 # Adjust buffer size as needed
        while ($true) {
            $read = $fileStream.Read($buffer, 0, $buffer.Length)
            if ($read -eq 0) { break }
            $outputStream.Write($buffer, 0, $read)
        }

        Write-Host "Content dumped successfully from offset $Offset to $DestinationFilePath."
    }
    catch {
        Write-Error "An error occurred: $_"
    }
    finally {
        if ($fileStream -ne $null) {
            $fileStream.Close()
        }
        if ($outputStream -ne $null) {
            $outputStream.Close()
        }
    }
}

function Find-EmbeddedCabOffsets {
    param(
        [string]$filePath       
    )

    $dword = 0x4643534D
    $dwordBytes = [BitConverter]::GetBytes($dword)
    $chunkSize = 1024 * 1024 # Read in chunks of 1MB
    $offsets = New-Object System.Collections.Generic.List[int]

    $fileStream = [System.IO.File]::Open($filePath, [System.IO.FileMode]::Open)
    $reader = New-Object System.IO.BinaryReader($fileStream)

    try {
        $fileLength = $fileStream.Length
        $buffer = New-Object byte[] $chunkSize
        $totalReadBytes = 0

        while ($totalReadBytes -lt $fileLength) {
            $readBytes = $reader.Read($buffer, 0, $buffer.Length)
            $totalReadBytes += $readBytes

            # Adjust readBytes for the size of DWORD to avoid missing overlaps between chunks
            $adjustedReadBytes = $readBytes
            if ($totalReadBytes -lt $fileLength) {
                $adjustedReadBytes -= $dwordBytes.Length
            }

            for ($i = 0; $i -lt $adjustedReadBytes; $i++) {
                $match = $true
                for ($j = 0; $j -lt $dwordBytes.Length; $j++) {
                    if ($buffer[$i + $j] -ne $dwordBytes[$j]) {
                        $match = $false
                        break
                    }
                }

                if ($match) {
                    $offset = $totalReadBytes - $readBytes + $i
                    $offsets.Add($offset)
                }
            }
        }
    }
    finally {
        $reader.Dispose()
        $fileStream.Dispose()
    }

    return $offsets
}