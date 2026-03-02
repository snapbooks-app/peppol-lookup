# PowerShell PEPPOL Lookup Example

Simple PowerShell implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

Uses PowerShell built-in functionality and dig for DNS:
- System.Security.Cryptography for SHA-256 hashing
- dig command (dnsutils) or Resolve-DnsName for NAPTR DNS lookup
- Invoke-WebRequest for HTTPS requests
- Regular expressions for XML parsing

## Running the Example

```powershell
.\peppol_lookup.ps1
```
