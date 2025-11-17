# Swift PEPPOL Lookup Example

Simple Swift implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

No external dependencies required. Uses only Swift Foundation framework:
- CommonCrypto for MD5 hashing
- CFHost for DNS lookup
- URLSession for HTTP requests

## Running the Example

### On macOS:

```bash
swift PeppolLookup.swift
```

### Or compile and run:

```bash
swiftc PeppolLookup.swift -o PeppolLookup
./PeppolLookup
```

### On Linux:

Swift is available for Linux through the official Swift toolchain. However, this implementation uses CommonCrypto which is macOS-specific. For Linux, you would need to modify the MD5 implementation to use an alternative approach.

Note: The GitHub Actions CI tests this implementation on macOS runners to ensure it works correctly on Apple platforms.
