#!/usr/bin/env nim c -r

##[
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
]##

import std/[httpclient, md5, net, nativesockets, uri, re, strutils]

# Test environment SML domain
const SML_DOMAIN = "edelivery.tech.ec.europa.eu"

# PEPPOL BIS Billing 3.0 document identifiers
const BIS_BILLING_INVOICE = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice"
const BIS_BILLING_CREDITNOTE = "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote"

##[
Step 1: Use SML (Service Metadata Locator) to find a participant's SMP hostname

The SML is like a phone book for the PEPPOL network. Given a participant's ID:
1. Create an MD5 hash of their ID (e.g., "0192:921605900")
2. Use the hash to construct a DNS hostname
3. If the hostname exists, the participant is registered in PEPPOL
4. The hostname tells us where to find their metadata (SMP)

Returns the SMP hostname if found, empty string if not found
]##
proc smlLookup(icd: string, identifier: string, smlDomain: string = SML_DOMAIN): string =
  try:
    # Create MD5 hash of participant ID
    let participantId = icd & ":" & identifier
    let md5Hash = getMD5(participantId)

    # Construct hostname
    let hostname = "b-" & md5Hash & ".iso6523-actorid-upis." & smlDomain

    # Check if hostname exists
    let addresses = getAddrInfo(hostname, Port(80))
    if addresses.len > 0:
      return hostname
    else:
      return ""
  except OSError:
    return ""

##[
Step 2: Query SMP (Service Metadata Publisher) to get supported document types

The SMP is like a business card in the PEPPOL network. It tells us:
1. What types of documents the participant can receive
2. Technical details needed for sending documents
3. Specific document format versions they support

This is similar to how DNS MX records tell you where to send email,
but SMP also includes what "types" of messages you can send.
]##
proc smpLookup(smpHostname: string, icd: string, identifier: string): seq[string] =
  # Construct SMP URL
  # Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
  let participantId = icd & ":" & identifier
  let encodedId = encodeUrl(participantId)
  let url = "http://" & smpHostname & "/iso6523-actorid-upis::" & encodedId

  # Perform HTTP GET request
  var client = newHttpClient()
  let response = client.getContent(url)

  # Extract document types from ServiceMetadataReference href attributes
  var documentTypes: seq[string] = @[]

  # Match ServiceMetadataReference href attributes
  let pattern = re(r#"ServiceMetadataReference[^>]*href="([^"]*)"[^>]*>"#)
  for match in response.findAll(pattern):
    let hrefMatch = response.findAll(re(r#"href="([^"]*)""#))
    for href in hrefMatch:
      let decodedHref = decodeUrl(href.replace("href=\"", "").replace("\"", ""))
      if "busdox-docid-qns::" in decodedHref:
        let parts = decodedHref.split("busdox-docid-qns::")
        if parts.len > 1:
          let docType = parts[1].split("#")[0]
          documentTypes.add(docType)

  return documentTypes

# Main execution
proc main() =
  try:
    # Snapbooks AS (Norwegian organization number)
    let icd = "0192"
    let identifier = "921605900"

    # Step 1: Use SML to find where participant's metadata is hosted
    let smpHostname = smlLookup(icd, identifier)
    if smpHostname == "":
      echo "Not a PEPPOL participant: ", icd, ":", identifier
      quit(1)

    echo "SMP hostname: ", smpHostname

    # Step 2: Query their SMP to discover supported documents
    let documentTypes = smpLookup(smpHostname, icd, identifier)
    echo "\nSupported document identifiers:"
    for docType in documentTypes:
      echo "- ", docType

    # Check for PEPPOL BIS Billing 3.0 documents
    echo "\nPEPPOL BIS Billing 3.0 Support:"
    if BIS_BILLING_INVOICE in documentTypes:
      echo "- Supports Invoice"
    if BIS_BILLING_CREDITNOTE in documentTypes:
      echo "- Supports Credit Note"

  except Exception as e:
    stderr.writeLine("Error: " & e.msg)
    quit(1)

when isMainModule:
  main()
