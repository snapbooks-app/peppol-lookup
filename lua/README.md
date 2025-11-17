# Lua PEPPOL Lookup Example

Simple Lua implementation demonstrating PEPPOL participant lookup for Snapbooks AS.

## Test Case Details

- Company: Snapbooks AS
- Country: Norway
- Organization number: 921605900
- PEPPOL Participant ID: 0192:921605900 (ICD: 0192, Identifier: 921605900)

## Dependencies

Requires LuaSocket library for DNS and HTTP functionality:
- socket for DNS lookup
- socket.http for HTTP requests
- socket.url for URL encoding/decoding

Install dependencies:

```bash
# Debian/Ubuntu
sudo apt-get install lua5.3 lua-socket

# macOS with Homebrew
brew install lua luarocks
luarocks install luasocket

# Or using luarocks directly
luarocks install luasocket
```

Also requires `md5sum` command-line tool (usually pre-installed on Unix systems).

## Running the Example

```bash
chmod +x peppol_lookup.lua
./peppol_lookup.lua
```

Or:

```bash
lua peppol_lookup.lua
```
