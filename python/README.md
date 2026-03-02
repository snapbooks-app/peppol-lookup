# Python PEPPOL Lookup Example

Simple Python implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

Requires the `dnspython` package for NAPTR DNS lookups:
- hashlib for SHA-256 hashing
- base64 for Base32 encoding
- dns.resolver (dnspython) for NAPTR DNS lookup
- urllib for HTTPS requests
- xml.etree for XML parsing

## Running the Example

```bash
pip install dnspython
python3 peppol_lookup.py
```
