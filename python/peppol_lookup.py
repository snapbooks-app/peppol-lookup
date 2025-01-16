#!/usr/bin/env python3

"""
PEPPOL uses two key services to enable document exchange:

1. SML (Service Metadata Locator):
   - Acts as a DNS-based directory service
   - Maps a participant's ID to their SMP provider
   - Uses DNS lookup to find where a participant's metadata is hosted
   - Similar to how email's MX records help find mail servers

2. SMP (Service Metadata Publisher):
   - Hosts metadata about a participant's capabilities
   - Tells you what document types they can receive
   - Provides technical details needed for sending documents
   - Acts like a participant's business card in the network

This example demonstrates how to:
1. Use SML to find where a participant's metadata is hosted
2. Query their SMP to discover what documents they can receive
3. Check for PEPPOL BIS Billing 3.0 support
"""

import hashlib
import socket
import xml.etree.ElementTree as ET
from urllib.request import urlopen
from urllib.parse import quote, unquote
from urllib.error import URLError

def sml_lookup(icd: str, identifier: str, sml_domain: str = "edelivery.tech.ec.europa.eu") -> str | None:
    """
    Step 1: Use SML (Service Metadata Locator) to find a participant's SMP hostname
    
    The SML is like a phone book for the PEPPOL network. Given a participant's ID:
    1. Create an MD5 hash of their ID (e.g., "0192:921605900")
    2. Use the hash to construct a DNS hostname
    3. If the hostname exists, the participant is registered in PEPPOL
    4. The hostname tells us where to find their metadata (SMP)
    
    Returns the SMP hostname if found, None if not found
    """
    try:
        md5_hash = hashlib.md5(f"{icd}:{identifier}".encode()).hexdigest()
        hostname = f"b-{md5_hash}.iso6523-actorid-upis.{sml_domain}"
        socket.getaddrinfo(hostname, None)
        return hostname
    except socket.gaierror:
        return None

def smp_lookup(smp_hostname: str, icd: str, identifier: str) -> list:
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
    # Format: https://[SMP hostname]/[identifier scheme]::[participant identifier]
    participant_id = f"{icd}:{identifier}"
    url = f"http://{smp_hostname}/iso6523-actorid-upis::{quote(participant_id)}"
    
    # Perform HTTP GET request and parse XML response
    try:
        with urlopen(url) as response:
            xml_data = response.read()
            print(f"\nSMP Response:\n{xml_data.decode()}\n")
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
        # Example href format: .../services/busdox-docid-qns%3A%3Aurn%3Aoasis%3Anames%3Aspecification%3Aubl%3Aschema%3Axsd%3AInvoice-2...
        decoded_href = unquote(href)
        if 'busdox-docid-qns::' in decoded_href:
            parts = decoded_href.split('busdox-docid-qns::')[1].split('::')[0]
            # Extract full document identifier from href
            parts = decoded_href.split('busdox-docid-qns::')[1].split('#')[0]
            document_types.append(parts)
    
    return document_types

def main():
    # Snapbooks AS (Norwegian organization number)
    icd = "0192"
    identifier = "921605900"
    
    # Step 1: Perform SML lookup to get SMP hostname
    smp_hostname = sml_lookup(icd, identifier)
    if not smp_hostname:
        print(f"Not a PEPPOL participant: {icd}:{identifier}")
        return
        
    print(f"SMP hostname: {smp_hostname}")
    
    try:
        # Step 2: Perform SMP lookup to get supported document types
        document_types = smp_lookup(smp_hostname, icd, identifier)
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
