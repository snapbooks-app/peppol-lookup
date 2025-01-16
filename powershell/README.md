# PowerShell PEPPOL Lookup Example

Simple PowerShell implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

Uses only PowerShell built-in functionality:
- System.Security.Cryptography for MD5 hashing
- System.Net.Dns for DNS lookup
- Invoke-WebRequest for HTTP requests
- Regular expressions for XML parsing

## Running the Example

```powershell
.\peppol_lookup.ps1
```
