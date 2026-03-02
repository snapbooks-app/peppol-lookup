# PHP PEPPOL Lookup Example

Simple PHP implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

No external dependencies required. Uses only PHP built-in functions:
- hash() for SHA-256 hashing
- dns_get_record() for NAPTR DNS lookup
- file_get_contents() for HTTPS requests
- preg_match_all() for XML parsing

## Running the Example

```bash
php peppol_lookup.php
```
