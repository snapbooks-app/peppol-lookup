# Go PEPPOL Lookup Example

Simple Go implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

No external dependencies required. Uses only Go standard library:
- crypto/md5 for hashing
- net for DNS lookup
- net/http for HTTP requests
- regexp for XML parsing

## Running the Example

```bash
go run peppol_lookup.go
```
