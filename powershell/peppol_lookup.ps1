# PEPPOL uses two key services to enable document exchange:
#
# 1. SML (Service Metadata Locator):
#    - Acts as a DNS-based directory service
#    - Maps a participant's ID to their SMP provider
#    - Uses DNS lookup to find where a participant's metadata is hosted
#    - Similar to how email's MX records help find mail servers
#
# 2. SMP (Service Metadata Publisher):
#    - Hosts metadata about a participant's capabilities
#    - Tells you what document types they can receive
#    - Provides technical details needed for sending documents
#    - Acts like a participant's business card in the network
#
# This example demonstrates how to:
# 1. Use SML to find where a participant's metadata is hosted
# 2. Query their SMP to discover what documents they can receive
# 3. Check for PEPPOL BIS Billing 3.0 support

# Test environment SML domain
$SML_DOMAIN = "edelivery.tech.ec.europa.eu"

# PEPPOL BIS Billing 3.0 document identifiers
$BIS_BILLING_INVOICE = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice"
$BIS_BILLING_CREDITNOTE = "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote"

<#
.SYNOPSIS
Step 1: Use SML (Service Metadata Locator) to find a participant's SMP hostname

.DESCRIPTION
The SML is like a phone book for the PEPPOL network. Given a participant's ID:
1. Create an MD5 hash of their ID (e.g., "0192:921605900")
2. Use the hash to construct a DNS hostname
3. If the hostname exists, the participant is registered in PEPPOL
4. The hostname tells us where to find their metadata (SMP)

Returns the SMP hostname if found, null if not found
#>
function Get-SmlLookup {
    param(
        [string]$icd,
        [string]$identifier,
        [string]$smlDomain = $SML_DOMAIN
    )
    
    # Create MD5 hash of participant ID
    $participantId = "$icd`:$identifier"
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $hash = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($participantId))
    $md5Hash = [System.BitConverter]::ToString($hash).Replace("-", "").ToLower()
    
    # Construct hostname
    $hostname = "b-$md5Hash.iso6523-actorid-upis.$smlDomain"
    
    # Check if hostname exists
    try {
        [System.Net.Dns]::GetHostEntry($hostname) | Out-Null
        return $hostname
    } catch {
        return $null
    }
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
        [string]$smpHostname,
        [string]$icd,
        [string]$identifier
    )
    
    # Construct SMP URL
    # Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
    $participantId = "$icd`:$identifier"
    $url = "http://$smpHostname/iso6523-actorid-upis::$([System.Web.HttpUtility]::UrlEncode($participantId))"
    
    # Perform HTTP GET request
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

# Step 1: Use SML to find where participant's metadata is hosted
$smpHostname = Get-SmlLookup -icd $icd -identifier $identifier
if (-not $smpHostname) {
    Write-Host "Not a PEPPOL participant: $icd`:$identifier"
    exit 1
}
Write-Host "SMP hostname: $smpHostname"

# Step 2: Query their SMP to discover supported documents
Write-Host "`nSupported document identifiers:"
$documentTypes = Get-SmpLookup -smpHostname $smpHostname -icd $icd -identifier $identifier
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
