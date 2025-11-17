# Clojure PEPPOL Lookup Example

Simple Clojure implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

No external dependencies required. Uses only Clojure with Java interop:
- java.security.MessageDigest for MD5 hashing
- java.net.InetAddress for DNS lookup
- java.net.URL for HTTP requests

## Running the Example

### Using clojure CLI:

```bash
clojure peppol_lookup.clj
```

### Or make it executable and run directly:

```bash
chmod +x peppol_lookup.clj
./peppol_lookup.clj
```

Note: Requires Clojure CLI tools to be installed.
