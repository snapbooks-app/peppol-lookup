# Nim PEPPOL Lookup Example

Simple Nim implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

No external dependencies required. Uses only Nim standard library:
- std/md5 for MD5 hashing
- std/net for DNS lookup
- std/httpclient for HTTP requests
- std/re for regex pattern matching

## Running the Example

### Compile and run:

```bash
nim c -r peppol_lookup.nim
```

### Or compile first, then run:

```bash
nim c peppol_lookup.nim
./peppol_lookup
```

### Run as script (if executable):

```bash
chmod +x peppol_lookup.nim
./peppol_lookup.nim
```

Note: Requires Nim compiler to be installed.
