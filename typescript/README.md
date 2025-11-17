# TypeScript PEPPOL Lookup Example

Simple TypeScript implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

Uses TypeScript with Node.js built-in modules:
- crypto for MD5 hashing
- dns/promises for DNS lookup
- http for HTTP requests

## Running the Example

### Using ts-node (recommended for quick testing):

```bash
npx ts-node peppol-lookup.ts
```

### Or compile and run:

```bash
npx tsc peppol-lookup.ts
node peppol-lookup.js
```
