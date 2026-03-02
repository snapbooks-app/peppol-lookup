# C# PEPPOL Lookup Example

Simple C# implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

Uses .NET standard libraries and one NuGet package:
- System.Security.Cryptography for SHA-256 hashing
- DnsClient (NuGet) for NAPTR DNS lookup
- System.Net.Http for HTTPS requests
- System.Xml.Linq for XML parsing

## Running the Example

```bash
dotnet run
```
