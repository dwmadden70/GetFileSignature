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
    #   .\GetFileSignature.exe "C:\path\to\file.exe"
    # ValueFromPipeline links it natively to the PowerShell
    # pipeline
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$File,

    # Default to false
    [switch]$ClearHostOnExecute,

    # Restrict to supported algorithms by Get-FileHash
    [Parameter(Mandatory = $false)]
    [ValidateScript({
        # Define or retrieve the valid list here
        $valid = (Get-Command Get-FileHash)
            .Parameters['Algorithm'].Attributes.ValidValues
        if ($valid -contains $_) {
            return $true
        } else {
            Write-Error "Invalid algorithm.
                Valid values: $($valid -join ',')"
                -ErrorAction Stop
        }
    })]
    [string]$HashType = 'SHA256'
)

# Clear Host if requested
if ($ClearHostOnExecute) {
    Clear-Host
}

# Calculate and Return the Hash
try {
    $calculatedHash = Get-FileHash -Path $File -Algorithm $HashType

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

#GetFileSignature -File "d:\users\dmadd\Downloads\spotdl-4.5.2-win32.exe" -HashType "SHA256" ClearTerminal $true
