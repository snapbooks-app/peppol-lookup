# Go PEPPOL Lookup Example

Simple Go implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

Uses Go standard library and one external dependency:
- crypto/sha256 for hashing
- encoding/base32 for Base32 encoding
- github.com/miekg/dns for NAPTR DNS lookup
- net/http for HTTPS requests
- regexp for XML parsing

## Running the Example

```bash
go run peppol_lookup.go
```
