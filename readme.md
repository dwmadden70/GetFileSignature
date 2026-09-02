# GetFileSignature

Calculates a file hash using a supported .NET hashing algorithm and optionally compares it to a checksum manifest.

## Features

- Hashes a file using `MD5`, `SHA1`, `SHA256`, `SHA384`, or `SHA512`
- Supports short aliases for faster command entry
- Accepts an optional checksum file for validation
- Detects common checksum manifest formats
- Prints the computed hash and comparison result in the console

## Parameters

```powershell
GetFileSignature `
    -File <string> `
    [-HashType <MD5|SHA1|SHA256|SHA384|SHA512>] `
    [-ChecksumFile <string>] `
    [-ClearHostOnExecute <bool>]
```

### Aliases

- `-File` → `-f`
- `-HashType` → `-ht`
- `-ChecksumFile` → `-cf`
- `-ClearHostOnExecute` → `-ch`

## Examples

### Basic usage

```powershell
GetFileSignature -File "D:\path\to\file.iso"
```

### Explicit hash type

```powershell
GetFileSignature -File "D:\path\to\file.iso" -HashType "SHA256"
```

### Compare against a checksum file

```powershell
GetFileSignature -File "D:\path\to\file.iso" -ChecksumFile "D:\path\to\sha256sum.txt"
```

### Disable host clearing

```powershell
GetFileSignature -File "D:\path\to\file.iso" -ChecksumFile "D:\path\to\sha256sum.txt" -ClearHostOnExecute false
```

### Alias form

```powershell
GetFileSignature -f "D:\path\to\file.iso" -cf "D:\path\to\sha256sum.txt" -ch false
```

## Supported checksum formats

The script accepts manifest lines in common formats such as:

```text
A1B2C3D4E5F6...  filename.ext
```

and

```text
SHA256 (filename.ext) = A1B2C3D4E5F6...
```

It compares the hash for the target file and reports whether the checksum matched.

## Defaults

- Default hash algorithm: `SHA256`
- Default clear-host behavior: `true`

## Notes

- The file and checksum file must exist.
- A checksum file is optional.
- If the checksum manifest indicates a different algorithm than the one explicitly requested, the script throws an error to prevent mismatched comparisons.
