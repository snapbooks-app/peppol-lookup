#!/usr/bin/env groovy

/**
 * PEPPOL uses two key services to enable document exchange:
 *
 * 1. SML (Service Metadata Locator):
 *    - Acts as a DNS-based directory service
 *    - Maps a participant's ID to their SMP provider
 *    - Uses DNS lookup to find where a participant's metadata is hosted
 *    - Similar to how email's MX records help find mail servers
 *
 * 2. SMP (Service Metadata Publisher):
 *    - Hosts metadata about a participant's capabilities
 *    - Tells you what document types they can receive
 *    - Provides technical details needed for sending documents
 *    - Acts like a participant's business card in the network
 *
 * This example demonstrates how to:
 * 1. Use SML to find where a participant's metadata is hosted
 * 2. Query their SMP to discover what documents they can receive
 * 3. Check for PEPPOL BIS Billing 3.0 support
 */

import java.net.InetAddress
import java.net.URL
import java.net.URLEncoder
import java.net.URLDecoder
import java.net.UnknownHostException
import java.security.MessageDigest

// Test environment SML domain
def SML_DOMAIN = "edelivery.tech.ec.europa.eu"

// PEPPOL BIS Billing 3.0 document identifiers
def BIS_BILLING_INVOICE = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice"
def BIS_BILLING_CREDITNOTE = "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote"

/**
 * Step 1: Use SML (Service Metadata Locator) to find a participant's SMP hostname
 *
 * The SML is like a phone book for the PEPPOL network. Given a participant's ID:
 * 1. Create an MD5 hash of their ID (e.g., "0192:921605900")
 * 2. Use the hash to construct a DNS hostname
 * 3. If the hostname exists, the participant is registered in PEPPOL
 * 4. The hostname tells us where to find their metadata (SMP)
 *
 * Returns the SMP hostname if found, null if not found
 */
def smlLookup(String icd, String identifier, String smlDomain = SML_DOMAIN) {
    try {
        // Create MD5 hash of participant ID
        def participantId = "${icd}:${identifier}"
        def md5 = MessageDigest.getInstance("MD5")
        def hashBytes = md5.digest(participantId.bytes)
        def md5Hash = hashBytes.collect { String.format("%02x", it) }.join()

        // Construct hostname
        def hostname = "b-${md5Hash}.iso6523-actorid-upis.${smlDomain}"

        // Check if hostname exists
        InetAddress.getByName(hostname)
        return hostname
    } catch (UnknownHostException e) {
        return null
    }
}

/**
 * Step 2: Query SMP (Service Metadata Publisher) to get supported document types
 *
 * The SMP is like a business card in the PEPPOL network. It tells us:
 * 1. What types of documents the participant can receive
 * 2. Technical details needed for sending documents
 * 3. Specific document format versions they support
 *
 * This is similar to how DNS MX records tell you where to send email,
 * but SMP also includes what "types" of messages you can send.
 */
def smpLookup(String smpHostname, String icd, String identifier) {
    // Construct SMP URL
    // Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
    def participantId = "${icd}:${identifier}"
    def encodedId = URLEncoder.encode(participantId, "UTF-8")
    def urlString = "http://${smpHostname}/iso6523-actorid-upis::${encodedId}"

    // Perform HTTP GET request
    def url = new URL(urlString)
    def response = url.text

    // Extract document types from ServiceMetadataReference href attributes
    def documentTypes = []

    // Match ServiceMetadataReference href attributes
    def pattern = ~/ServiceMetadataReference[^>]*href="([^"]*)"[^>]*>/
    response.findAll(pattern) { match, href ->
        def decodedHref = URLDecoder.decode(href, "UTF-8")
        if (decodedHref.contains("busdox-docid-qns::")) {
            def docType = decodedHref.split("busdox-docid-qns::")[1].split("#")[0]
            documentTypes << docType
        }
    }

    return documentTypes
}

// Main execution
try {
    // Snapbooks AS (Norwegian organization number)
    def icd = "0192"
    def identifier = "921605900"

    // Step 1: Use SML to find where participant's metadata is hosted
    def smpHostname = smlLookup(icd, identifier)
    if (!smpHostname) {
        println "Not a PEPPOL participant: ${icd}:${identifier}"
        System.exit(1)
    }
    println "SMP hostname: ${smpHostname}"

    // Step 2: Query their SMP to discover supported documents
    def documentTypes = smpLookup(smpHostname, icd, identifier)
    println "\nSupported document identifiers:"
    documentTypes.each { docType ->
        println "- ${docType}"
    }

    // Check for PEPPOL BIS Billing 3.0 documents
    println "\nPEPPOL BIS Billing 3.0 Support:"
    if (BIS_BILLING_INVOICE in documentTypes) {
        println "- Supports Invoice"
    }
    if (BIS_BILLING_CREDITNOTE in documentTypes) {
        println "- Supports Credit Note"
    }

} catch (Exception e) {
    System.err.println "Error: ${e.message}"
    System.exit(1)
}
