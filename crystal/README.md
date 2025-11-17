# Crystal PEPPOL Lookup Example

Simple Crystal implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

No external dependencies required. Uses only Crystal standard library:
- digest/md5 for MD5 hashing
- socket for DNS lookup
- http/client for HTTP requests
- uri for URL encoding/decoding

## Running the Example

### Run directly:

```bash
crystal run peppol_lookup.cr
```

### Or compile and run:

```bash
crystal build peppol_lookup.cr
./peppol_lookup
```

### Or make executable and run:

```bash
chmod +x peppol_lookup.cr
./peppol_lookup.cr
```

Note: Requires Crystal compiler to be installed.
