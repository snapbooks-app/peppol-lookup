# Perl PEPPOL Lookup Example

Simple Perl implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

Uses Perl with standard and commonly available modules:
- Digest::MD5 for MD5 hashing
- Socket for DNS lookup
- LWP::Simple for HTTP requests
- URI::Escape for URL encoding/decoding

Install dependencies on most systems:

```bash
# Debian/Ubuntu
sudo apt-get install libwww-perl

# macOS with Homebrew
brew install perl
cpan LWP::Simple

# Or using cpanm
cpanm LWP::Simple
```

## Running the Example

```bash
chmod +x peppol_lookup.pl
./peppol_lookup.pl
```

Or:

```bash
perl peppol_lookup.pl
```
