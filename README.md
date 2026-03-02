# PEPPOL Lookup Examples

When we started building [Snapbooks](https://snapbooks.no), we needed to support PEPPOL documents in Norway and Europe. We found it challenging to find clear documentation about how the PEPPOL lookup process worked. This repository aims to help other developers who are on the same path by providing clear, working examples in multiple programming languages.

The PEPPOL network uses two key services to enable document exchange:

1. SML (Service Metadata Locator):
   - Acts as a DNS-based directory service
   - Maps a participant's ID to their SMP provider
   - Uses NAPTR DNS records to find where a participant's metadata is hosted
   - Similar to how email's MX records help find mail servers

2. SMP (Service Metadata Publisher):
   - Hosts metadata about a participant's capabilities
   - Tells you what document types they can receive
   - Provides technical details needed for sending documents
   - Acts like a participant's business card in the network

Each example demonstrates how to:
1. Use SML to find where a participant's metadata is hosted (via NAPTR DNS lookup)
2. Query their SMP over HTTPS to discover what documents they can receive
3. Check for PEPPOL BIS Billing 3.0 support (Invoice and Credit Note)

## NAPTR DNS Lookup (Updated February 2026)

As of February 1, 2026, PEPPOL has fully migrated from CNAME-based DNS lookups to NAPTR-based lookups. The key changes are:

- **Hash algorithm**: SHA-256 (was MD5)
- **Encoding**: Base32, lowercase, trailing `=` stripped (was hex with `B-` prefix)
- **DNS record type**: NAPTR (was CNAME/A)
- **SMP protocol**: HTTPS mandatory (was HTTP)
- **SMP URL**: Extracted from NAPTR record's regexp field (service: `Meta:SMP`)

## Test Case

All examples use the same test case:
- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Implementations

Each implementation follows the same pattern:
- Performs NAPTR DNS lookup to discover SMP URL
- Queries SMP over HTTPS for participant capabilities
- Returns raw document identifiers
- Checks for specific PEPPOL BIS Billing 3.0 document support

Available in:
- [Python](python/) - using dnspython and urllib
- [Java](java/) - using JNDI DNS and HttpURLConnection
- [Node.js](javascript/) - using dns.resolveNaptr and https
- [C#](csharp/) - using DnsClient and HttpClient
- [PHP](php/) - using dns_get_record and file_get_contents
- [Go](go/) - using miekg/dns and http
- [Bash](bash/) - using dig and curl
- [PowerShell](powershell/) - using dig/Resolve-DnsName and Invoke-WebRequest
- [Ruby](ruby/) - using Resolv::DNS and Net::HTTP
- [Rust](rust/) - using hickory-resolver and reqwest

## Documentation

See [docs/peppol-lookup-process.md](docs/peppol-lookup-process.md) for technical details about the PEPPOL lookup process.

## Testing

All examples are automatically tested using GitHub Actions to ensure they:
1. Successfully perform SML lookup via NAPTR DNS
2. Successfully perform SMP lookup over HTTPS
3. Correctly identify PEPPOL BIS Billing 3.0 document support
4. Produce consistent output format
