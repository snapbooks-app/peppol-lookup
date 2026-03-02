#!/bin/bash

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
# Requires: dig (from dnsutils/bind-tools), curl, sha256sum, xxd, basenc (coreutils)

# Test environment SML domain
SML_DOMAIN="edelivery.tech.ec.europa.eu"

# PEPPOL BIS Billing 3.0 document identifiers
BIS_BILLING_INVOICE="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice"
BIS_BILLING_CREDITNOTE="urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote"

# Step 1: Use SML (Service Metadata Locator) to find a participant's SMP URL
#
# The SML is like a phone book for the PEPPOL network. Given a participant's ID:
# 1. Create a SHA-256 hash of their lowercase ID (e.g., "0192:921605900")
# 2. Base32-encode the hash (lowercase, strip trailing '=')
# 3. Use the encoded hash to construct a DNS name
# 4. Perform a NAPTR DNS lookup to get the SMP URL
# 5. Extract the SMP URL from the NAPTR record's regexp field
sml_lookup() {
    local icd="$1"
    local identifier="$2"
    local sml_domain="${3:-$SML_DOMAIN}"

    # Create SHA-256 hash of lowercase participant ID, then base32 encode
    local participant_id
    participant_id=$(echo -n "$icd:$identifier" | tr '[:upper:]' '[:lower:]')

    # SHA-256 hash -> raw bytes -> base32 encode (using coreutils sha256sum + basenc)
    local hex b32
    hex=$(echo -n "$participant_id" | sha256sum | cut -d' ' -f1)
    b32=$(printf '%b' "$(echo "$hex" | sed 's/../\\x&/g')" | basenc --base32 | tr -d '=' | tr '[:upper:]' '[:lower:]')

    # Construct DNS name
    local dns_name="$b32.iso6523-actorid-upis.$sml_domain"

    # Perform NAPTR DNS lookup using dig
    local naptr_output
    naptr_output=$(dig +short -t naptr "$dns_name" 2>/dev/null)

    if [ -z "$naptr_output" ]; then
        return 1
    fi

    # Parse NAPTR record: find Meta:SMP with U flag
    # dig +short output format: order preference "flags" "service" "regexp" replacement
    local smp_url
    smp_url=$(echo "$naptr_output" | while IFS= read -r line; do
        if echo "$line" | grep -q '"Meta:SMP"'; then
            # Extract the regexp field (third quoted string)
            local regexp
            regexp=$(echo "$line" | sed 's/[^"]*"\([^"]*\)"/\1\n/g' | sed -n '3p')
            if [ -n "$regexp" ]; then
                # Extract URL from regexp: !pattern!replacement!
                local delim="${regexp:0:1}"
                echo "$regexp" | cut -d"$delim" -f3
                break
            fi
        fi
    done)

    if [ -n "$smp_url" ]; then
        echo "$smp_url"
        return 0
    else
        return 1
    fi
}

# Step 2: Query SMP (Service Metadata Publisher) to get supported document types
#
# The SMP is like a business card in the PEPPOL network. It tells us:
# 1. What types of documents the participant can receive
# 2. Technical details needed for sending documents
# 3. Specific document format versions they support
smp_lookup() {
    local smp_url="$1"
    local icd="$2"
    local identifier="$3"

    # Ensure SMP URL ends with /
    [[ "$smp_url" != */ ]] && smp_url="$smp_url/"

    # Construct SMP URL
    # Format: {smp_url}/[identifier scheme]::[participant identifier]
    local participant_id="$icd:$identifier"
    local url="${smp_url}iso6523-actorid-upis::$(urlencode "$participant_id")"

    # Perform HTTPS GET request, URL-decode response, and extract document types
    # sed decodes %3A->: %2F->/ %23-># which are common in SMP href attributes
    curl -s "$url" | sed 's/%3[Aa]/:/g; s/%2[Ff]/\//g; s/%23/#/g' | grep -o 'busdox-docid-qns::[^#"]*' | sed 's/busdox-docid-qns:://'
}

# URL encode a string
urlencode() {
    local string="$1"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="${c}" ;;
            * )               printf -v o '%%%02x' "'$c"
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}

# Main script

# Snapbooks AS (Norwegian organization number)
icd="0192"
identifier="921605900"

# Step 1: Use SML to find where participant's metadata is hosted (NAPTR lookup)
smp_url=$(sml_lookup "$icd" "$identifier")
if [ $? -ne 0 ]; then
    echo "Not a PEPPOL participant: $icd:$identifier"
    exit 1
fi
echo "SMP URL: $smp_url"

# Step 2: Query their SMP to discover supported documents
echo -e "\nSupported document identifiers:"
document_types=$(smp_lookup "$smp_url" "$icd" "$identifier")
echo "$document_types" | while read -r doc_type; do
    echo "- $doc_type"
done

# Check for PEPPOL BIS Billing 3.0 documents
echo -e "\nPEPPOL BIS Billing 3.0 Support:"
if echo "$document_types" | grep -q "^$BIS_BILLING_INVOICE$"; then
    echo "- Supports Invoice"
fi
if echo "$document_types" | grep -q "^$BIS_BILLING_CREDITNOTE$"; then
    echo "- Supports Credit Note"
fi
