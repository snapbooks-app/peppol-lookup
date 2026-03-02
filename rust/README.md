# Rust PEPPOL Lookup Example

Simple Rust implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

Uses dependencies from crates.io:
- sha2 for SHA-256 hashing
- data-encoding for Base32 encoding
- hickory-resolver for NAPTR DNS lookup
- reqwest for HTTPS requests
- regex for XML parsing
- urlencoding for URL encoding

## Running the Example

```bash
cargo run
```
