# Groovy PEPPOL Lookup Example

Simple Groovy implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

No external dependencies required. Uses only Groovy/Java standard library:
- java.security.MessageDigest for MD5 hashing
- java.net.InetAddress for DNS lookup
- java.net.URL for HTTP requests

## Running the Example

### Using groovy command:

```bash
groovy PeppolLookup.groovy
```

### Or make it executable and run directly:

```bash
chmod +x PeppolLookup.groovy
./PeppolLookup.groovy
```

Note: Requires Groovy runtime to be installed.
