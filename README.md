# PEPPOL Lookup Examples

When we started building [Snapbooks](https://snapbooks.no), we needed to support PEPPOL documents in Norway and Europe. We found it challenging to find clear documentation about how the PEPPOL lookup process worked. This repository aims to help other developers who are on the same path by providing clear, working examples in multiple programming languages.

The PEPPOL network uses two key services to enable document exchange:

1. SML (Service Metadata Locator):
   - Acts as a DNS-based directory service
   - Maps a participant's ID to their SMP provider
   - Uses DNS lookup to find where a participant's metadata is hosted
   - Similar to how email's MX records help find mail servers

2. SMP (Service Metadata Publisher):
   - Hosts metadata about a participant's capabilities
   - Tells you what document types they can receive
   - Provides technical details needed for sending documents
   - Acts like a participant's business card in the network

Each example demonstrates how to:
1. Use SML to find where a participant's metadata is hosted
2. Query their SMP to discover what documents they can receive
3. Check for PEPPOL BIS Billing 3.0 support (Invoice and Credit Note)

## Test Case

All examples use the same test case:
- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Implementations

Each implementation follows the same pattern:
- Uses minimal dependencies (standard libraries where possible)
- Returns raw document identifiers
- Checks for specific PEPPOL BIS Billing 3.0 document support

Available in:
- [Python](python/) - using socket and urllib
- [Java](java/) - using InetAddress and HttpURLConnection
- [Node.js](javascript/) - using dns.promises and http
- [C#](csharp/) - using Dns and HttpClient
- [PHP](php/) - using gethostbyname and file_get_contents
- [Go](go/) - using net and http
- [Bash](bash/) - using host and curl
- [PowerShell](powershell/) - using System.Net.Dns and Invoke-WebRequest
- [Ruby](ruby/) - using Resolv and Net::HTTP
- [Rust](rust/) - using ToSocketAddrs and reqwest

## Documentation

See [docs/peppol-lookup-process.md](docs/peppol-lookup-process.md) for technical details about the PEPPOL lookup process.

## Testing

All examples are automatically tested using GitHub Actions to ensure they:
1. Successfully perform SML lookup
2. Successfully perform SMP lookup
3. Correctly identify PEPPOL BIS Billing 3.0 document support
4. Produce consistent output format
