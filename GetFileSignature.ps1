function Get-ChecksumManifestInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ChecksumFilePath
    )

    $resolvedPath = Resolve-Path -LiteralPath $ChecksumFilePath -ErrorAction Stop
    $lines = Get-Content -LiteralPath $resolvedPath.Path | Where-Object {
        $_ -match '\S' -and $_ -notlike '#*'
    }

    if ($null -eq $lines -or $lines.Count -eq 0) {
        throw "The checksum file '$ChecksumFilePath' contains no valid checksum data or only comments."
    }

    $records = foreach ($line in $lines) {
        if ($line -match '^(?<Hash>[a-fA-F0-9]+)\s+[\*]?(?<File>.+)$') {
            $hashString = $Matches.Hash
            $targetFile = $Matches.File.Trim().TrimStart('*', '\', '/', '.', ' ')
        }
        elseif ($line -match '^(?<Algorithm>\w+)\s*\((?<File>.+)\)\s*=\s*(?<Hash>[a-fA-F0-9]+)$') {
            $hashString = $Matches.Hash
            $targetFile = $Matches.File.Trim().TrimStart('*', '\', '/', '.', ' ')
        }
        else {
            continue
        }

        $hashType = switch ($hashString.Length) {
            32  { 'MD5' }
            40  { 'SHA1' }
            56  { 'SHA224' }
            64  { 'SHA256' }
            96  { 'SHA384' }
            128 { 'SHA512' }
            default { 'Unknown' }
        }

        [PSCustomObject]@{
            TargetFile = $targetFile
            Signature  = $hashString.ToUpperInvariant()
            HashType   = $hashType
        }
    }

    return [PSCustomObject]@{
        ManifestPath   = $resolvedPath.Path
        IsMultiFile    = ($lines.Count -gt 1)
        TotalFileCount = @($records).Count
        DetectedTypes  = @($records.HashType | Select-Object -Unique)
        Signatures     = @($records)
    }
}

function Resolve-HashAlgorithm {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo]$FileInfo,

        [Parameter()]
        [ValidateSet('MD5', 'SHA1', 'SHA256', 'SHA384', 'SHA512')]
        [string]$HashType = 'SHA256',

        [Parameter()]
        [string]$ChecksumFile
    )

    $resolvedHashType = $HashType

    if (-not [string]::IsNullOrWhiteSpace($ChecksumFile)) {
        $checksumInfo = Get-ChecksumManifestInfo -ChecksumFilePath $ChecksumFile

        if ($checksumInfo.IsMultiFile) {
            $match = $checksumInfo.Signatures | Where-Object {
                $_.TargetFile -eq $FileInfo.Name -or
                $_.TargetFile -eq $FileInfo.FullName -or
                [System.IO.Path]::GetFileName($_.TargetFile) -eq $FileInfo.Name
            } | Select-Object -First 1

            if ($match) {
                $resolvedHashType = $match.HashType
            }
            else {
                Write-Warning "The file '$($FileInfo.Name)' was not found in '$ChecksumFile'. Using default hash type: SHA256."
                $resolvedHashType = 'SHA256'
            }
        }
        else {
            $detectedType = @($checksumInfo.DetectedTypes | Select-Object -First 1)
            if ($detectedType -and $detectedType -ne 'Unknown') {
                $resolvedHashType = $detectedType
            }
        }

        if ($HashType -ne 'SHA256' -and $resolvedHashType -ne $HashType) {
            throw "The user specified hash type '$HashType' does not match the hash type detected in '$ChecksumFile'."
        }
    }

    return $resolvedHashType
}

function GetFileSignature {
    <#
    .SYNOPSIS
        Gets the hash for a file and optionally compares it to a checksum file.
    .PARAMETER File
        The path to the file to hash.
    .PARAMETER ClearHostOnExecute
        Clears the host before execution when set to true.
    .PARAMETER HashType
        Hash algorithm to use. Defaults to SHA256.
    .PARAMETER ChecksumFile
        Optional checksum file to compare against.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Alias('f')]
        [ValidateNotNullOrEmpty()]
        [string]$File,

        [alias('ch')]
        [string]$ClearHostOnExecute = 'true',

        [Alias('ht')]
        [ValidateSet('MD5', 'SHA1', 'SHA256', 'SHA384', 'SHA512')]
        [string]$HashType = 'SHA256',

        [Alias('cf')]
        [string]$ChecksumFile
    )

    $shouldClearHost = $ClearHostOnExecute.Trim().TrimStart('$') -match '^(?i:true|1)$'
    if ($shouldClearHost) {
        Clear-Host
    }

    try {
        $fileInfo = Get-Item -LiteralPath $File

        if (-not [string]::IsNullOrWhiteSpace($ChecksumFile)) {
            if (-not (Test-Path -LiteralPath $ChecksumFile -PathType Leaf)) {
                throw "The checksum file '$ChecksumFile' does not exist or is not a valid file."
            }
        }

        $resolvedHashType = Resolve-HashAlgorithm -FileInfo $fileInfo -HashType $HashType -ChecksumFile $ChecksumFile

        $hashAlgorithm = [System.Security.Cryptography.HashAlgorithm]::Create($resolvedHashType)
        $fileStream = [System.IO.File]::OpenRead($fileInfo.FullName)
        try {
            $hashBytes = $hashAlgorithm.ComputeHash($fileStream)
        }
        finally {
            $fileStream.Dispose()
            $hashAlgorithm.Dispose()
        }

        $calculatedHash = ([System.BitConverter]::ToString($hashBytes) -replace '-', '').ToUpperInvariant()

        $result = [PSCustomObject]@{
            Path          = $fileInfo.FullName
            Algorithm     = $resolvedHashType
            Hash          = $calculatedHash
            Created       = $fileInfo.CreationTime
            ChecksumFile  = $null
            ExpectedHash  = $null
            ChecksumMatch = $null
        }

        if (-not [string]::IsNullOrWhiteSpace($ChecksumFile)) {
            $checksumInfo = Get-ChecksumManifestInfo -ChecksumFilePath $ChecksumFile
            $match = $checksumInfo.Signatures | Where-Object {
                $_.TargetFile -eq $fileInfo.Name -or
                $_.TargetFile -eq $fileInfo.FullName -or
                [System.IO.Path]::GetFileName($_.TargetFile) -eq $fileInfo.Name
            } | Select-Object -First 1

            $result.ChecksumFile = (Get-Item -LiteralPath $ChecksumFile).FullName

            if ($match) {
                $result.ExpectedHash = $match.Signature.ToUpperInvariant()
                $result.ChecksumMatch = ($result.ExpectedHash -eq $result.Hash)
            }
            else {
                $result.ChecksumMatch = $false
            }
        }

        Write-Host "`n"
        Write-Host "Path:      " -ForegroundColor Cyan -NoNewline; Write-Host $result.Path
        Write-Host "Algorithm: " -ForegroundColor Cyan -NoNewline; Write-Host $result.Algorithm
        Write-Host "Hash:      " -ForegroundColor Cyan -NoNewline; Write-Host $result.Hash
        Write-Host "Created:   " -ForegroundColor Cyan -NoNewline; Write-Host $result.Created

        if (-not [string]::IsNullOrWhiteSpace($ChecksumFile)) {
            Write-Host "Checksum:  " -ForegroundColor Cyan -NoNewline; Write-Host $result.ChecksumFile
            Write-Host "Expected:  " -ForegroundColor Cyan -NoNewline; Write-Host ($result.ExpectedHash ?? 'Not found')
            Write-Host "Match:     " -ForegroundColor Cyan -NoNewline; Write-Host $result.ChecksumMatch
        }

        Write-Host ""
        return $result
    }
    catch {
        Write-Error "Failed to calculate hash: $_"
        return $null
    }
}

# if ($MyInvocation.InvocationName -ne '.') {
#     GetFileSignature -File $File -ChecksumFile $ChecksumFile -HashType $HashType -ClearHostOnExecute $ClearHostOnExecute
# }

# ------------------------------------------------------------------
# Manual test cases
# ------------------------------------------------------------------
# GetFileSignature -File "D:\users\dmadd\Downloads\iso\Linux\Linux Mint\linuxmint-22.3-cinnamon-64bit.iso"
# GetFileSignature -File "D:\users\dmadd\Downloads\iso\Linux\Linux Mint\linuxmint-22.3-cinnamon-64bit.iso" -ChecksumFile "D:\users\dmadd\Downloads\iso\Linux\Linux Mint\sha256sum.txt"
# GetFileSignature -File "D:\users\dmadd\Downloads\iso\Linux\Linux Mint\linuxmint-22.3-cinnamon-64bit.iso" -ChecksumFile "D:\users\dmadd\Downloads\iso\Linux\Linux Mint\sha256sum.txt" -HashType "SHA256"
