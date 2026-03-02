# Java PEPPOL Lookup Example

Simple Java implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

No external dependencies required. Uses only Java standard libraries:
- java.security for SHA-256 hashing
- javax.naming (JNDI) for NAPTR DNS lookup
- java.net for HTTPS requests
- javax.xml for XML parsing

## Running the Example

```bash
javac PeppolLookup.java
java PeppolLookup
```
