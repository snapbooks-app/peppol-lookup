# Dart PEPPOL Lookup Example

Simple Dart implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

Requires the crypto package for MD5 hashing. Other functionality uses Dart built-in libraries:
- crypto for MD5 hashing
- dart:io for DNS lookup and HTTP requests
- dart:convert for string encoding

Install dependencies:

```bash
dart pub get
```

## Running the Example

```bash
dart run peppol_lookup.dart
```

Or make it executable and run directly:

```bash
chmod +x peppol_lookup.dart
./peppol_lookup.dart
```
