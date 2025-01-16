# PEPPOL Lookup Process

This document explains how PEPPOL enables automated discovery of participants and their capabilities.

## Overview

PEPPOL uses a two-step discovery process similar to how email works:
1. First, find where a participant's metadata is hosted (like finding an email server)
2. Then, ask that location what the participant can receive (like checking email capabilities)

This is implemented through two key services:

### SML (Service Metadata Locator)
- Acts as a global directory service using DNS
- Maps participant IDs to their metadata providers
- Similar to how email uses MX records to find mail servers
- Enables automatic discovery without central databases

### SMP (Service Metadata Publisher)
- Hosts detailed information about participants
- Lists supported document types and formats
- Provides technical details for sending documents
- Like a business card in the PEPPOL network

## Step 1: Finding a Participant (SML Lookup)

The SML uses DNS to help you find where a participant's metadata is hosted:

1. Start with a participant's ID (like a phone number):
   ```
   participant_id = "0192:921605900"  # format: icd:identifier
   ```

2. Create MD5 hash of their ID to ensure consistent lookup:
   ```
   md5_hash = md5("0192:921605900")
   # Result: e258de9dbe1f34f17b55d5d3cc5e7a66
   ```

3. Construct a special DNS hostname:
   ```
   hostname = f"b-{md5_hash}.iso6523-actorid-upis.{sml_domain}"
   # Result: b-e258de9dbe1f34f17b55d5d3cc5e7a66.iso6523-actorid-upis.edelivery.tech.ec.europa.eu
   ```

4. Check if this hostname exists in DNS:
   - If it exists: They're a PEPPOL participant
   - If not: They're not registered in PEPPOL

## Step 2: Getting Participant Details (SMP Lookup)

Once you know where a participant's metadata is hosted, you can ask what they can receive:

1. Create an HTTP request to their SMP:
   ```
   url = f"http://{smp_hostname}/iso6523-actorid-upis::{participant_id}"
   ```

2. The SMP responds with an XML document listing their capabilities:
   ```xml
   <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
   <ns3:ServiceGroup xmlns="http://busdox.org/transport/identifiers/1.0/" 
                     xmlns:ns3="http://busdox.org/serviceMetadata/publishing/1.0/">
     <ParticipantIdentifier scheme="iso6523-actorid-upis">0192:921605900</ParticipantIdentifier>
     <ns3:ServiceMetadataReferenceCollection>
       <ns3:ServiceMetadataReference href="http://...busdox-docid-qns::urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice##..."/>
       <ns3:ServiceMetadataReference href="http://...busdox-docid-qns::urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote##..."/>
     </ns3:ServiceMetadataReferenceCollection>
   </ns3:ServiceGroup>
   ```

3. The response includes important details like:
   - Document types they can receive (e.g., invoices)
   - Document format versions they support
   - Technical details needed for sending
   ```
   urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice
   urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote
   ```

## Example: PEPPOL BIS Billing 3.0

In our examples, we check if participants can receive billing documents:

- Invoice: `urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice`
- Credit Note: `urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote`

These identifiers tell us if a participant can receive invoices and credit notes that follow the PEPPOL BIS Billing 3.0 specification, which is widely used in European e-invoicing.

## Real-World Analogy

The process is similar to sending a letter:
1. SML is like looking up a postal code to find the right post office
2. SMP is like checking what types of mail that post office can handle

Or like email:
1. SML is like using DNS to find a domain's mail server (MX records)
2. SMP is like checking what email formats they support (but more sophisticated)

This two-step process enables automated discovery and interoperability in the PEPPOL network, making it easy for participants to find and communicate with each other.
