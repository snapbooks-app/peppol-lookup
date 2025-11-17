# F# PEPPOL Lookup Example

Simple F# implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

No external dependencies required. Uses only .NET/F# standard library:
- System.Security.Cryptography for MD5 hashing
- System.Net.Dns for DNS lookup
- System.Net.Http.HttpClient for HTTP requests
- System.Text.RegularExpressions for XML parsing

## Running the Example

### Using dotnet fsi (F# Interactive):

```bash
dotnet fsi PeppolLookup.fsx
```

### Or make it executable and run directly:

```bash
chmod +x PeppolLookup.fsx
./PeppolLookup.fsx
```

Note: Requires .NET SDK 6.0 or later.
