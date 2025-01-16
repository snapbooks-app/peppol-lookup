# Ruby PEPPOL Lookup Example

Simple Ruby implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

No external dependencies required. Uses only Ruby standard libraries:
- digest for MD5 hashing
- resolv for DNS lookup
- net/http for HTTP requests
- uri for URL encoding

## Running the Example

```bash
ruby peppol_lookup.rb
```
