function GetFileSignature {
    <#
    .SYNOPSIS
        Get File Hash for a file using a specified hashing algorithm.
    .PARAMETER File
        The path to the test file. Mandatory.
    .PARAMETER ClearHostOnExecute
        Switches whether to clear the terminal screen before execution. Defaults to $true.
    .PARAMETER HashType
        The algorithm to use for hashing. Defaults to 'SHA256'.
    #>

    [CmdletBinding()]
    param (
        # Position 0 allows running:
        #   .\GetFileSignature.exe --File "C:\path\to\file.exe"
        # ValueFromPipeline links it natively to the PowerShell
        # pipeline
        [Parameter(Mandatory = $true)]
        [Alias('f')]
        [ValidateNotNullOrEmpty()]
        [string]$File,

        # Accepts PowerShell and native executable forms such as $true, true, or 1.
        [string]$ClearHostOnExecute = 'false',

        # Restrict to algorithms supported by the .NET hashing APIs.
        [Parameter(Mandatory = $false)]
        [ValidateSet('MD5', 'SHA1', 'SHA256', 'SHA384', 'SHA512')]
        [string]$HashType = 'SHA256'
    )

    $shouldClearHost = $ClearHostOnExecute.Trim().TrimStart('$') -match '^(?i:true|1)$'

    # Clear Host if requested
    if ($shouldClearHost) {
        Clear-Host
    }

    # Calculate and Return the Hash
    try {
        $hashAlgorithm = [System.Security.Cryptography.HashAlgorithm]::Create($HashType)
        $fileStream = [System.IO.File]::OpenRead($File)
        try {
            $hashBytes = $hashAlgorithm.ComputeHash($fileStream)
        }
        finally {
            $fileStream.Dispose()
            $hashAlgorithm.Dispose()
        }

        $calculatedHash = [PSCustomObject]@{
            Path      = (Get-Item $File).FullName
            Algorithm = $HashType
            Hash      = ([System.BitConverter]::ToString($hashBytes) -replace '-', '')
        }

        # Output a custom object with relevant details
        $obj = [PSCustomObject]@{
            Path      = $calculatedHash.Path
            Algorithm = $calculatedHash.Algorithm
            Hash      = $calculatedHash.Hash
            Created   = (Get-Item $File).CreationTime
        }

         # -NoNewline lets us change colors halfway through the same line!
        Write-Host "`n"
        Write-Host "Path:      " -ForegroundColor Cyan -NoNewline; Write-Host $obj.Path
        Write-Host "Algorithm: " -ForegroundColor Cyan -NoNewline; Write-Host $obj.Algorithm
        Write-Host "Hash:      " -ForegroundColor Cyan -NoNewline; Write-Host $obj.Hash
        Write-Host "Created:   " -ForegroundColor Cyan -NoNewline; Write-Host $obj.Created
        Write-Host "" # Adds a clean empty line between files
    }
    catch {
        Write-Error "Failed to calculate hash: $_"
        return
    }
}

GetFileSignature -File "D:\users\dmadd\Downloads\iso\Linux\Linux Mint\linuxmint-22.3-cinnamon-64bit.iso"