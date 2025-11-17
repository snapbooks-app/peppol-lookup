# Kotlin PEPPOL Lookup Example

Simple Kotlin implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

No external dependencies required. Uses only Kotlin/Java standard library:
- java.security.MessageDigest for MD5 hashing
- java.net.InetAddress for DNS lookup
- java.net.URL for HTTP requests

## Running the Example

### Using kotlinc and kotlin:

```bash
kotlinc PeppolLookup.kt -include-runtime -d PeppolLookup.jar
kotlin PeppolLookup.jar
```

### Or run as a script:

```bash
kotlinc -script PeppolLookup.kt
```
