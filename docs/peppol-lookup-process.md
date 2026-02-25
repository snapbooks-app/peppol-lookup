# PEPPOL Lookup Process

This document explains how PEPPOL enables automated discovery of participants and their capabilities.

## Overview

PEPPOL uses a two-step discovery process similar to how email works:
1. First, find where a participant's metadata is hosted (like finding an email server)
2. Then, ask that location what the participant can receive (like checking email capabilities)

This is implemented through two key services:

### SML (Service Metadata Locator)
- Acts as a global directory service using DNS NAPTR records
- Maps participant IDs to their metadata providers
- Similar to how email uses MX records to find mail servers
- Enables automatic discovery without central databases

### SMP (Service Metadata Publisher)
- Hosts detailed information about participants
- Lists supported document types and formats
- Provides technical details for sending documents
- Like a business card in the PEPPOL network
- Accessed exclusively over HTTPS

## Step 1: Finding a Participant (SML Lookup via NAPTR)

The SML uses DNS NAPTR records to help you find where a participant's metadata is hosted:

1. Start with a participant's ID (like a phone number):
   ```
   participant_id = "0192:921605900"  # format: icd:identifier
   ```

2. Create a SHA-256 hash of the lowercase participant ID:
   ```
   sha256_hash = sha256("0192:921605900")  # binary hash
   ```

3. Base32-encode the hash, strip trailing `=`, and lowercase:
   ```
   b32 = base32(sha256_hash).strip("=").lower()
   # Result: edomqmynkzsm3hvpe24uyqzskf6uuuqbqrlvskch7vw2bgtsjwnq
   ```

4. Construct a DNS name for the NAPTR lookup:
   ```
   dns_name = f"{b32}.iso6523-actorid-upis.{sml_domain}"
   # Result: edomqmynkzsm3hvpe24uyqzskf6uuuqbqrlvskch7vw2bgtsjwnq.iso6523-actorid-upis.edelivery.tech.ec.europa.eu
   ```

5. Perform a DNS NAPTR lookup on this name:
   ```
   dig -t naptr edomqmynkzsm3hvpe24uyqzskf6uuuqbqrlvskch7vw2bgtsjwnq.iso6523-actorid-upis.edelivery.tech.ec.europa.eu
   ```

6. Parse the NAPTR record to extract the SMP URL:
   - Look for a record with service `Meta:SMP` and flags `U`
   - The regexp field contains the SMP URL (e.g., `!^.*$!https://smp.example.com/!`)
   - Extract the URL from the regexp replacement

## Step 2: Getting Participant Details (SMP Lookup)

Once you know the SMP URL, you can query what the participant can receive:

1. Create an HTTPS request to their SMP:
   ```
   url = f"{smp_url}iso6523-actorid-upis::{participant_id}"
   ```

2. The SMP responds with an XML document listing their capabilities:
   ```xml
   <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
   <ns3:ServiceGroup xmlns="http://busdox.org/transport/identifiers/1.0/"
                     xmlns:ns3="http://busdox.org/serviceMetadata/publishing/1.0/">
     <ParticipantIdentifier scheme="iso6523-actorid-upis">0192:921605900</ParticipantIdentifier>
     <ns3:ServiceMetadataReferenceCollection>
       <ns3:ServiceMetadataReference href="https://...busdox-docid-qns::urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice##..."/>
       <ns3:ServiceMetadataReference href="https://...busdox-docid-qns::urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote##..."/>
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

## NAPTR Record Format

The NAPTR DNS record contains the following fields:
- **Order**: Priority ordering (lower = higher priority)
- **Preference**: Secondary ordering
- **Flags**: `"U"` indicates the output is a URI
- **Service**: `"Meta:SMP"` identifies this as a PEPPOL SMP record
- **Regexp**: Substitution regex containing the SMP URL (e.g., `!^.*$!https://smp.example.com/!`)
- **Replacement**: Typically `.` (unused when flags is `U`)

## Migration from CNAME to NAPTR (February 2026)

PEPPOL previously used CNAME DNS records with MD5 hashing. The migration to NAPTR was completed on February 1, 2026:

| Aspect | Old (CNAME) | New (NAPTR) |
|--------|-------------|-------------|
| Hash algorithm | MD5 | SHA-256 |
| Encoding | Hex with `B-` prefix | Base32, lowercase, `=` stripped |
| DNS record | CNAME/A | NAPTR |
| Protocol | HTTP | HTTPS (mandatory) |
| SMP URL | Constructed from hostname | Extracted from NAPTR regexp |

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
