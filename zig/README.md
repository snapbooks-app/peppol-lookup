# Zig PEPPOL Lookup Example

Simple Zig implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

No external dependencies required. Uses only Zig standard library:
- std.crypto for MD5 hashing
- std.net for DNS lookup
- std.http for HTTP requests

## Running the Example

### Build and run:

```bash
zig build-exe peppol_lookup.zig
./peppol_lookup
```

### Or run directly:

```bash
zig run peppol_lookup.zig
```

Note: Requires Zig compiler (0.11.0 or later recommended) to be installed.
