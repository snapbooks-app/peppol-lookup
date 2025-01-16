# C# PEPPOL Lookup Example

Simple C# implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

No external dependencies required. Uses only .NET standard libraries:
- System.Net for DNS and HTTP operations
- System.Security.Cryptography for MD5 hashing
- System.Xml.Linq for XML parsing

## Running the Example

```bash
dotnet run PeppolLookup.cs
```
