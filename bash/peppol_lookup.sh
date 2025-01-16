#!/bin/bash

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
SML_DOMAIN="edelivery.tech.ec.europa.eu"

# PEPPOL BIS Billing 3.0 document identifiers
BIS_BILLING_INVOICE="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice"
BIS_BILLING_CREDITNOTE="urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote"

# Step 1: Use SML (Service Metadata Locator) to find a participant's SMP hostname
#
# The SML is like a phone book for the PEPPOL network. Given a participant's ID:
# 1. Create an MD5 hash of their ID (e.g., "0192:921605900")
# 2. Use the hash to construct a DNS hostname
# 3. If the hostname exists, the participant is registered in PEPPOL
# 4. The hostname tells us where to find their metadata (SMP)
sml_lookup() {
    local icd="$1"
    local identifier="$2"
    local sml_domain="${3:-$SML_DOMAIN}"
    
    # Create MD5 hash of participant ID
    local participant_id="$icd:$identifier"
    local md5_hash=$(echo -n "$participant_id" | md5sum | cut -d' ' -f1)
    
    # Construct hostname
    local hostname="b-$md5_hash.iso6523-actorid-upis.$sml_domain"
    
    # Check if hostname exists
    if host "$hostname" > /dev/null 2>&1; then
        echo "$hostname"
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
#
# This is similar to how DNS MX records tell you where to send email,
# but SMP also includes what "types" of messages you can send.
smp_lookup() {
    local smp_hostname="$1"
    local icd="$2"
    local identifier="$3"
    
    # Construct SMP URL
    # Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
    local participant_id="$icd:$identifier"
    local url="http://$smp_hostname/iso6523-actorid-upis::$(urlencode "$participant_id")"
    
    # Perform HTTP GET request and extract document types
    curl -s "$url" | grep -o 'busdox-docid-qns::[^#]*' | sed 's/busdox-docid-qns:://'
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

# Step 1: Use SML to find where participant's metadata is hosted
smp_hostname=$(sml_lookup "$icd" "$identifier")
if [ $? -ne 0 ]; then
    echo "Not a PEPPOL participant: $icd:$identifier"
    exit 1
fi
echo "SMP hostname: $smp_hostname"

# Step 2: Query their SMP to discover supported documents
echo -e "\nSupported document identifiers:"
document_types=$(smp_lookup "$smp_hostname" "$icd" "$identifier")
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
