<?php

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

// Test environment SML domain
const SML_DOMAIN = 'edelivery.tech.ec.europa.eu';

// PEPPOL BIS Billing 3.0 document identifiers
const BIS_BILLING_INVOICE = 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice';
const BIS_BILLING_CREDITNOTE = 'urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote';

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
function sml_lookup($icd, $identifier, $sml_domain = SML_DOMAIN) {
    // Create MD5 hash of participant ID
    $participant_id = $icd . ':' . $identifier;
    $md5_hash = md5($participant_id);
    
    // Construct hostname
    $hostname = 'b-' . $md5_hash . '.iso6523-actorid-upis.' . $sml_domain;
    
    // Check if hostname exists
    try {
        gethostbyname($hostname);
        return $hostname;
    } catch (Exception $e) {
        return null;
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
function smp_lookup($smp_hostname, $icd, $identifier) {
    // Construct SMP URL
    // Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
    $participant_id = $icd . ':' . $identifier;
    $url = 'http://' . $smp_hostname . '/iso6523-actorid-upis::' . urlencode($participant_id);
    
    // Perform HTTP GET request
    $response = file_get_contents($url);
    if ($response === false) {
        throw new Exception('Failed to fetch SMP data');
    }
    
    // Extract document types from ServiceMetadataReference href attributes
    $document_types = array();
    
    // Match ServiceMetadataReference href attributes
    if (preg_match_all('/ServiceMetadataReference[^>]*href="([^"]*)"[^>]*>/', $response, $matches)) {
        foreach ($matches[1] as $href) {
            // Extract document type from href
            // Example href format: .../services/busdox-docid-qns%3A%3Aurn%3Aoasis%3Anames%3Aspecification%3Aubl%3Aschema%3Axsd%3AInvoice-2...
            $decoded_href = urldecode($href);
            if (strpos($decoded_href, 'busdox-docid-qns::') !== false) {
                $parts = explode('busdox-docid-qns::', $decoded_href)[1];
                $doc_type = explode('#', $parts)[0];
                $document_types[] = $doc_type;
            }
        }
    }
    
    return $document_types;
}

try {
    // Snapbooks AS (Norwegian organization number)
    $icd = '0192';
    $identifier = '921605900';
    
    // Step 1: Use SML to find where participant's metadata is hosted
    $smp_hostname = sml_lookup($icd, $identifier);
    if ($smp_hostname === null) {
        echo "Not a PEPPOL participant: $icd:$identifier\n";
        exit(1);
    }
    echo "SMP hostname: $smp_hostname\n";
    
    // Step 2: Query their SMP to discover supported documents
    $document_types = smp_lookup($smp_hostname, $icd, $identifier);
    echo "\nSupported document identifiers:\n";
    foreach ($document_types as $doc_type) {
        echo "- $doc_type\n";
    }
    
    // Check for PEPPOL BIS Billing 3.0 documents
    echo "\nPEPPOL BIS Billing 3.0 Support:\n";
    if (in_array(BIS_BILLING_INVOICE, $document_types)) {
        echo "- Supports Invoice\n";
    }
    if (in_array(BIS_BILLING_CREDITNOTE, $document_types)) {
        echo "- Supports Credit Note\n";
    }
    
} catch (Exception $e) {
    fwrite(STDERR, "Error: " . $e->getMessage() . "\n");
    exit(1);
}
