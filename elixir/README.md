# Elixir PEPPOL Lookup Example

Simple Elixir implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

No external dependencies required. Uses only Elixir/Erlang standard library:
- :crypto for MD5 hashing
- :inet_res for DNS lookup
- :httpc for HTTP requests

## Running the Example

```bash
chmod +x peppol_lookup.exs
./peppol_lookup.exs
```

Or:

```bash
elixir peppol_lookup.exs
```
