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
# Requires: dig (from dnsutils/bind-tools) on Linux, or Resolve-DnsName on Windows

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

    # Perform NAPTR DNS lookup
    try {
        if ($IsWindows -or $null -eq $IsWindows) {
            # Try Resolve-DnsName on Windows
            try {
                $records = Resolve-DnsName -Name $dnsName -Type NAPTR -ErrorAction Stop
                foreach ($record in $records) {
                    if ($record.Service -eq "Meta:SMP" -and $record.Flags.ToUpper() -eq "U") {
                        $regexp = $record.Regexp
                        $delim = $regexp[0]
                        $parts = $regexp.Split($delim)
                        return $parts[2] # replacement part contains the SMP URL
                    }
                }
            } catch {
                # Fall through to dig
            }
        }

        # Use dig command (Linux / fallback)
        $digOutput = & dig +short -t naptr $dnsName 2>&1
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($digOutput)) {
            return $null
        }

        # Parse dig output: order preference "flags" "service" "regexp" replacement
        foreach ($line in $digOutput -split "`n") {
            if ($line -match '"Meta:SMP"' -and $line -match '"U"') {
                # Extract the regexp field (content between the third pair of quotes)
                $quotes = [regex]::Matches($line, '"([^"]*)"')
                if ($quotes.Count -ge 3) {
                    $regexp = $quotes[2].Groups[1].Value
                    $delim = $regexp[0]
                    $parts = $regexp.Split($delim)
                    return $parts[2] # replacement part contains the SMP URL
                }
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
    $documentTypes = @()
    $pattern = 'busdox-docid-qns::([^#]*)'
    $matches = [regex]::Matches($response.Content, $pattern)

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
