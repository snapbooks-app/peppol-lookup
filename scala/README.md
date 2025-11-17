# Scala PEPPOL Lookup Example

Simple Scala implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

No external dependencies required. Uses only Scala/Java standard library:
- java.security.MessageDigest for MD5 hashing
- java.net.InetAddress for DNS lookup
- java.net.URL for HTTP requests
- scala.io.Source for reading HTTP responses

## Running the Example

### Using scala:

```bash
scala PeppolLookup.scala
```

### Or compile and run:

```bash
scalac PeppolLookup.scala
scala PeppolLookup
```
