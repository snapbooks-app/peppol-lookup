# PEPPOL uses two key services to enable document exchange:
#
# 1. SML (Service Metadata Locator):
#    - Acts as a DNS-based directory service
#    - Maps a participant's ID to their SMP provider
#    - Uses NAPTR DNS records to find where a participant's metadata is hosted
#    - Similar to how email's MX records help find mail servers
#
# 2. SMP (Service Metadata Publisher):
#    - Hosts metadata about a participant's capabilities
#    - Tells you what document types they can receive
#    - Provides technical details needed for sending documents
#    - Acts like a participant's business card in the network
#
# This example demonstrates how to:
# 1. Use SML to find where a participant's metadata is hosted (via NAPTR DNS lookup)
# 2. Query their SMP to discover what documents they can receive
# 3. Check for PEPPOL BIS Billing 3.0 support
#
# Uses Resolve-DnsName on Windows, raw UDP DNS queries via .NET sockets on Linux

# Test environment SML domain
$SML_DOMAIN = "edelivery.tech.ec.europa.eu"

# PEPPOL BIS Billing 3.0 document identifiers
$BIS_BILLING_INVOICE = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice"
$BIS_BILLING_CREDITNOTE = "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote"

# Base32 alphabet (RFC 4648)
$BASE32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

<#
.SYNOPSIS
Base32 encode a byte array (RFC 4648)
#>
function ConvertTo-Base32 {
    param([byte[]]$Data)

    $result = [System.Text.StringBuilder]::new()
    $bits = 0
    $value = 0

    foreach ($b in $Data) {
        $value = ($value -shl 8) -bor $b
        $bits += 8
        while ($bits -ge 5) {
            $index = ($value -shr ($bits - 5)) -band 31
            [void]$result.Append($BASE32_ALPHABET[$index])
            $bits -= 5
        }
    }

    if ($bits -gt 0) {
        $index = ($value -shl (5 - $bits)) -band 31
        [void]$result.Append($BASE32_ALPHABET[$index])
    }

    return $result.ToString()
}

<#
.SYNOPSIS
Perform a raw UDP DNS query for NAPTR records using .NET sockets

.DESCRIPTION
Constructs a DNS query packet, sends it via UDP, and parses the NAPTR
response records. Used on Linux where Resolve-DnsName is unavailable.
#>
function Resolve-NaptrRaw {
    param([string]$Name)

    # Build DNS query packet
    $ms = [System.IO.MemoryStream]::new()
    $bw = [System.IO.BinaryWriter]::new($ms)

    # Header: ID, Flags(RD=1), QDCOUNT=1, ANCOUNT=0, NSCOUNT=0, ARCOUNT=0
    $queryId = Get-Random -Maximum 65535
    $bw.Write([byte](($queryId -shr 8) -band 0xFF))
    $bw.Write([byte]($queryId -band 0xFF))
    $bw.Write([byte]0x01); $bw.Write([byte]0x00)  # Flags: RD=1
    $bw.Write([byte]0x00); $bw.Write([byte]0x01)  # QDCOUNT=1
    $bw.Write([byte]0x00); $bw.Write([byte]0x00)  # ANCOUNT=0
    $bw.Write([byte]0x00); $bw.Write([byte]0x00)  # NSCOUNT=0
    $bw.Write([byte]0x00); $bw.Write([byte]0x00)  # ARCOUNT=0

    # Encode domain name as labels
    foreach ($label in $Name.TrimEnd('.').Split('.')) {
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($label)
        $bw.Write([byte]$bytes.Length)
        $bw.Write($bytes)
    }
    $bw.Write([byte]0)  # Root label

    # Question: Type=NAPTR(35), Class=IN(1)
    $bw.Write([byte]0x00); $bw.Write([byte]0x23)  # Type NAPTR = 35
    $bw.Write([byte]0x00); $bw.Write([byte]0x01)  # Class IN = 1

    $queryBytes = $ms.ToArray()
    $bw.Close(); $ms.Close()

    # Get system DNS server from /etc/resolv.conf or use fallback
    $dnsServer = "8.8.8.8"
    if (Test-Path /etc/resolv.conf) {
        $ns = Get-Content /etc/resolv.conf | Where-Object { $_ -match '^\s*nameserver\s+(\S+)' } | Select-Object -First 1
        if ($ns -match 'nameserver\s+(\S+)') { $dnsServer = $Matches[1] }
    }

    # Send UDP query and receive response
    $udp = [System.Net.Sockets.UdpClient]::new()
    $udp.Client.ReceiveTimeout = 5000
    [void]$udp.Send($queryBytes, $queryBytes.Length, $dnsServer, 53)
    $remoteEP = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any, 0)
    $response = $udp.Receive([ref]$remoteEP)
    $udp.Close()

    # Parse response
    $pos = 0

    # Helper: read 16-bit unsigned integer (big-endian)
    $readUInt16 = {
        $val = ([int]$response[$script:pos] -shl 8) -bor [int]$response[$script:pos + 1]
        $script:pos += 2
        return $val
    }

    # Helper: read DNS name (handles compression pointers)
    $readName = {
        param([int]$startPos = -1)
        $p = if ($startPos -ge 0) { $startPos } else { $script:pos }
        $jumped = $false
        $labels = @()
        while ($response[$p] -ne 0) {
            if (($response[$p] -band 0xC0) -eq 0xC0) {
                # Compression pointer
                $ptr = (([int]$response[$p] -band 0x3F) -shl 8) -bor [int]$response[$p + 1]
                if (-not $jumped) { $script:pos = $p + 2; $jumped = $true }
                $p = $ptr
            } else {
                $len = [int]$response[$p]; $p++
                $labels += [System.Text.Encoding]::ASCII.GetString($response, $p, $len)
                $p += $len
            }
        }
        if (-not $jumped) { $script:pos = $p + 1 }
        return ($labels -join '.')
    }

    # Helper: read DNS character string (length-prefixed)
    $readString = {
        $len = [int]$response[$script:pos]; $script:pos++
        $str = [System.Text.Encoding]::ASCII.GetString($response, $script:pos, $len)
        $script:pos += $len
        return $str
    }

    # Skip header (already have it)
    $pos = 0
    $null = & $readUInt16  # ID
    $null = & $readUInt16  # Flags
    $qdCount = & $readUInt16
    $anCount = & $readUInt16
    $null = & $readUInt16  # NSCOUNT
    $null = & $readUInt16  # ARCOUNT

    # Skip question section
    for ($i = 0; $i -lt $qdCount; $i++) {
        $null = & $readName  # Name
        $null = & $readUInt16  # Type
        $null = & $readUInt16  # Class
    }

    # Parse answer records
    $results = @()
    for ($i = 0; $i -lt $anCount; $i++) {
        $null = & $readName   # Name
        $rType = & $readUInt16   # Type
        $null = & $readUInt16    # Class
        $pos += 4                # Skip TTL (4 bytes)
        $rdLength = & $readUInt16  # RDLENGTH

        if ($rType -eq 35) {
            # NAPTR record: ORDER(2) + PREFERENCE(2) + FLAGS(str) + SERVICES(str) + REGEXP(str) + REPLACEMENT(name)
            $order = & $readUInt16
            $preference = & $readUInt16
            $flags = & $readString
            $services = & $readString
            $regexp = & $readString
            $replacement = & $readName

            $results += [PSCustomObject]@{
                Order       = $order
                Preference  = $preference
                Flags       = $flags
                Services    = $services
                Regexp      = $regexp
                Replacement = $replacement
            }
        } else {
            # Skip unknown record type
            $pos += $rdLength
        }
    }

    return $results
}

<#
.SYNOPSIS
Step 1: Use SML (Service Metadata Locator) to find a participant's SMP URL

.DESCRIPTION
The SML is like a phone book for the PEPPOL network. Given a participant's ID:
1. Create a SHA-256 hash of their lowercase ID (e.g., "0192:921605900")
2. Base32-encode the hash (lowercase, strip trailing '=')
3. Use the encoded hash to construct a DNS name
4. Perform a NAPTR DNS lookup to get the SMP URL
5. Extract the SMP URL from the NAPTR record's regexp field

Returns the SMP URL if found, null if not found
#>
function Get-SmlLookup {
    param(
        [string]$icd,
        [string]$identifier,
        [string]$smlDomain = $SML_DOMAIN
    )

    # Create SHA-256 hash of lowercase participant ID
    $participantId = "$icd`:$identifier".ToLower()
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hash = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($participantId))

    # Base32 encode, strip trailing '=', lowercase
    $b32 = (ConvertTo-Base32 -Data $hash).TrimEnd('=').ToLower()

    # Construct DNS name
    $dnsName = "$b32.iso6523-actorid-upis.$smlDomain"

    # Perform NAPTR DNS lookup using native .NET
    try {
        # Try Resolve-DnsName on Windows
        if ($IsWindows -or $null -eq $IsWindows) {
            try {
                $records = Resolve-DnsName -Name $dnsName -Type NAPTR -ErrorAction Stop
                foreach ($record in $records) {
                    if ($record.Service -eq "Meta:SMP" -and $record.Flags.ToUpper() -eq "U") {
                        $regexp = $record.Regexp
                        $delim = $regexp[0]
                        $parts = $regexp.Split($delim)
                        return $parts[2]
                    }
                }
            } catch {
                # Fall through to raw DNS query
            }
        }

        # Raw UDP DNS query for NAPTR records using .NET sockets
        $naptrRecords = Resolve-NaptrRaw -Name $dnsName
        foreach ($naptr in $naptrRecords) {
            if ($naptr.Services -eq "Meta:SMP" -and $naptr.Flags.ToUpper() -eq "U") {
                $regexp = $naptr.Regexp
                $delim = $regexp[0]
                $parts = $regexp.Split($delim)
                return $parts[2]
            }
        }
    } catch {
        return $null
    }

    return $null
}

<#
.SYNOPSIS
Step 2: Query SMP (Service Metadata Publisher) to get supported document types

.DESCRIPTION
The SMP is like a business card in the PEPPOL network. It tells us:
1. What types of documents the participant can receive
2. Technical details needed for sending documents
3. Specific document format versions they support

This is similar to how DNS MX records tell you where to send email,
but SMP also includes what "types" of messages you can send.
#>
function Get-SmpLookup {
    param(
        [string]$smpUrl,
        [string]$icd,
        [string]$identifier
    )

    # Ensure SMP URL ends with /
    if (-not $smpUrl.EndsWith("/")) {
        $smpUrl += "/"
    }

    # Construct SMP URL
    # Format: {smp_url}/[identifier scheme]::[participant identifier]
    $participantId = "$icd`:$identifier"
    $url = "${smpUrl}iso6523-actorid-upis::$([System.Web.HttpUtility]::UrlEncode($participantId))"

    # Perform HTTPS GET request
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing

    # Extract document types from ServiceMetadataReference href attributes
    # URL-decode the response content first (SMP servers often return URL-encoded hrefs)
    $decodedContent = [System.Uri]::UnescapeDataString($response.Content)
    $documentTypes = @()
    $pattern = 'busdox-docid-qns::([^#"]*)'
    $matches = [regex]::Matches($decodedContent, $pattern)

    foreach ($match in $matches) {
        $documentTypes += $match.Groups[1].Value
    }

    return $documentTypes
}

# Main script

# Snapbooks AS (Norwegian organization number)
$icd = "0192"
$identifier = "921605900"

# Step 1: Use SML to find where participant's metadata is hosted (NAPTR lookup)
$smpUrl = Get-SmlLookup -icd $icd -identifier $identifier
if (-not $smpUrl) {
    Write-Host "Not a PEPPOL participant: $icd`:$identifier"
    exit 1
}
Write-Host "SMP URL: $smpUrl"

# Step 2: Query their SMP to discover supported documents
Write-Host "`nSupported document identifiers:"
$documentTypes = Get-SmpLookup -smpUrl $smpUrl -icd $icd -identifier $identifier
foreach ($docType in $documentTypes) {
    Write-Host "- $docType"
}

# Check for PEPPOL BIS Billing 3.0 documents
Write-Host "`nPEPPOL BIS Billing 3.0 Support:"
if ($documentTypes -contains $BIS_BILLING_INVOICE) {
    Write-Host "- Supports Invoice"
}
if ($documentTypes -contains $BIS_BILLING_CREDITNOTE) {
    Write-Host "- Supports Credit Note"
}
