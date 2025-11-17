# Haskell PEPPOL Lookup Example

Simple Haskell implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

Requires several Haskell packages:
- pureMD5 for MD5 hashing
- http-conduit for HTTP requests
- network for DNS lookup
- regex-posix for regex pattern matching

Install dependencies using cabal or stack:

```bash
# Using cabal
cabal install --lib pureMD5 http-conduit network regex-posix

# Or using stack
stack install pureMD5 http-conduit network regex-posix
```

## Running the Example

### Using runhaskell:

```bash
runhaskell PeppolLookup.hs
```

### Or compile and run:

```bash
ghc -o PeppolLookup PeppolLookup.hs
./PeppolLookup
```

Note: Requires GHC (Glasgow Haskell Compiler) to be installed.
