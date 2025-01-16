# Bash PEPPOL Lookup Example

Simple Bash implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

Uses standard Unix tools:
- md5sum for hashing
- host for DNS lookup
- curl for HTTP requests
- grep/sed for XML parsing

## Running the Example

```bash
chmod +x peppol_lookup.sh
./peppol_lookup.sh
```
