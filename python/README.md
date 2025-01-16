# Python PEPPOL Lookup Example

Simple Python implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

No external dependencies required. Uses only Python standard library:
- hashlib for MD5 hashing
- socket for DNS lookup
- urllib for HTTP requests
- xml.etree for XML parsing

## Running the Example

```bash
python3 peppol_lookup.py
```
