# GetFileSignature

Gets file hashes using a specified hashing algorithm. Supports one or more paths, including files passed through the PowerShell pipeline.

```powershell
.\GetFileSignature.ps1 --File .\readme.md
.\GetFileSignature.ps1 --File .\GetFileSignature.ps1, .\readme.md
Get-ChildItem -File | .\GetFileSignature.ps1

# For the compiled executable, pass the value as text.
.\GetFileSignature.exe --File "d:\users\dmadd\Downloads\spotdl-4.5.2-win32.exe" --HashType "SHA256" --ClearHostOnExecute true
.\GetFileSignature.exe --File "d:\users\dmadd\Downloads\spotdl-4.5.2-win32.exe" --HashType "SHA256"

#Assumes SHA256 as default
.\GetFileSignature.exe --File "d:\users\dmadd\Downloads\spotdl-4.5.2-win32.exe"
```
