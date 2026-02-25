#!/usr/bin/env python3

"""
PEPPOL uses two key services to enable document exchange:

1. SML (Service Metadata Locator):
   - Acts as a DNS-based directory service
   - Maps a participant's ID to their SMP provider
   - Uses NAPTR DNS records to find where a participant's metadata is hosted
   - Similar to how email's MX records help find mail servers

2. SMP (Service Metadata Publisher):
   - Hosts metadata about a participant's capabilities
   - Tells you what document types they can receive
   - Provides technical details needed for sending documents
   - Acts like a participant's business card in the network

This example demonstrates how to:
1. Use SML to find where a participant's metadata is hosted (via NAPTR DNS lookup)
2. Query their SMP to discover what documents they can receive
3. Check for PEPPOL BIS Billing 3.0 support

Requires: pip install dnspython
"""

import hashlib
import base64
import re
import xml.etree.ElementTree as ET
from urllib.request import urlopen, Request
from urllib.parse import quote, unquote
from urllib.error import URLError
import ssl

import dns.resolver

def sml_lookup(icd: str, identifier: str, sml_domain: str = "edelivery.tech.ec.europa.eu") -> str | None:
    """
    Step 1: Use SML (Service Metadata Locator) to find a participant's SMP URL

    The SML is like a phone book for the PEPPOL network. Given a participant's ID:
    1. Create a SHA-256 hash of their lowercase ID (e.g., "0192:921605900")
    2. Base32-encode the hash (lowercase, strip trailing '=')
    3. Use the encoded hash to construct a DNS name
    4. Perform a NAPTR DNS lookup to get the SMP URL
    5. Extract the SMP URL from the NAPTR record's regexp field

    Returns the SMP URL if found, None if not found
    """
    try:
        participant_id = f"{icd}:{identifier}"
        # SHA-256 hash of lowercase participant ID
        sha256_hash = hashlib.sha256(participant_id.lower().encode()).digest()
        # Base32 encode, strip trailing '=', lowercase
        b32 = base64.b32encode(sha256_hash).decode().rstrip('=').lower()
        dns_name = f"{b32}.iso6523-actorid-upis.{sml_domain}"

        # Perform NAPTR DNS lookup
        answers = dns.resolver.resolve(dns_name, 'NAPTR')
        for rdata in answers:
            flags = rdata.flags.decode()
            service = rdata.service.decode()
            if service == 'Meta:SMP' and flags.upper() == 'U':
                # Extract URL from NAPTR regexp field
                # Format: !pattern!replacement! (first char is delimiter)
                regexp = rdata.regexp.decode()
                delim = regexp[0]
                parts = regexp.split(delim)
                pattern = parts[1]
                replacement = parts[2]
                smp_url = re.sub(pattern, replacement, dns_name)
                return smp_url
    except Exception:
        return None

    return None

def smp_lookup(smp_url: str, icd: str, identifier: str) -> list:
    """
    Step 2: Query SMP (Service Metadata Publisher) to get supported document types

    The SMP is like a business card in the PEPPOL network. It tells us:
    1. What types of documents the participant can receive
    2. Technical details needed for sending documents
    3. Specific document format versions they support

    This is similar to how DNS MX records tell you where to send email,
    but SMP also includes what "types" of messages you can send.
    """
    # Construct SMP URL
    # Format: {smp_url}/[identifier scheme]::[participant identifier]
    participant_id = f"{icd}:{identifier}"
    if not smp_url.endswith('/'):
        smp_url += '/'
    url = f"{smp_url}iso6523-actorid-upis::{quote(participant_id)}"

    # Perform HTTPS GET request and parse XML response
    try:
        ctx = ssl.create_default_context()
        req = Request(url)
        with urlopen(req, context=ctx) as response:
            xml_data = response.read()
            root = ET.fromstring(xml_data)
    except URLError as e:
        raise Exception(f"Failed to fetch SMP data: {str(e)}")

    # Extract document types from ServiceMetadataReference href attributes
    document_types = []

    # Define namespace map for XML parsing
    ns = {'ns3': 'http://busdox.org/serviceMetadata/publishing/1.0/'}

    # Find all ServiceMetadataReference elements
    refs = root.findall('.//ns3:ServiceMetadataReference', ns)

    for ref in refs:
        href = ref.get('href', '')
        # Extract document type from href
        decoded_href = unquote(href)
        if 'busdox-docid-qns::' in decoded_href:
            parts = decoded_href.split('busdox-docid-qns::')[1].split('#')[0]
            document_types.append(parts)

    return document_types

def main():
    # Snapbooks AS (Norwegian organization number)
    icd = "0192"
    identifier = "921605900"

    # Step 1: Perform SML lookup to get SMP URL via NAPTR
    smp_url = sml_lookup(icd, identifier)
    if not smp_url:
        print(f"Not a PEPPOL participant: {icd}:{identifier}")
        return

    print(f"SMP URL: {smp_url}")

    try:
        # Step 2: Perform SMP lookup to get supported document types
        document_types = smp_lookup(smp_url, icd, identifier)
        print("\nSupported document identifiers:")
        for doc_id in document_types:
            print(f"- {doc_id}")

        # Check for PEPPOL BIS Billing 3.0 documents
        bis_billing_invoice = 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice'
        bis_billing_cn = 'urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote'

        print("\nPEPPOL BIS Billing 3.0 Support:")
        if bis_billing_invoice in document_types:
            print("- Supports Invoice")
        if bis_billing_cn in document_types:
            print("- Supports Credit Note")
    except Exception as e:
        print(f"Error: {str(e)}")

if __name__ == "__main__":
    main()
