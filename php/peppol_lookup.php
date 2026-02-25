<?php

/**
 * PEPPOL uses two key services to enable document exchange:
 *
 * 1. SML (Service Metadata Locator):
 *    - Acts as a DNS-based directory service
 *    - Maps a participant's ID to their SMP provider
 *    - Uses NAPTR DNS records to find where a participant's metadata is hosted
 *    - Similar to how email's MX records help find mail servers
 *
 * 2. SMP (Service Metadata Publisher):
 *    - Hosts metadata about a participant's capabilities
 *    - Tells you what document types they can receive
 *    - Provides technical details needed for sending documents
 *    - Acts like a participant's business card in the network
 *
 * This example demonstrates how to:
 * 1. Use SML to find where a participant's metadata is hosted (via NAPTR DNS lookup)
 * 2. Query their SMP to discover what documents they can receive
 * 3. Check for PEPPOL BIS Billing 3.0 support
 */

// Test environment SML domain
const SML_DOMAIN = 'edelivery.tech.ec.europa.eu';

// PEPPOL BIS Billing 3.0 document identifiers
const BIS_BILLING_INVOICE = 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice';
const BIS_BILLING_CREDITNOTE = 'urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote';

/**
 * Base32 encode binary data (RFC 4648)
 */
function base32_encode_bytes($data) {
    $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    $result = '';
    $bits = 0;
    $value = 0;

    for ($i = 0; $i < strlen($data); $i++) {
        $value = ($value << 8) | ord($data[$i]);
        $bits += 8;
        while ($bits >= 5) {
            $result .= $alphabet[($value >> ($bits - 5)) & 31];
            $bits -= 5;
        }
    }

    if ($bits > 0) {
        $result .= $alphabet[($value << (5 - $bits)) & 31];
    }

    return $result;
}

/**
 * Step 1: Use SML (Service Metadata Locator) to find a participant's SMP URL
 *
 * The SML is like a phone book for the PEPPOL network. Given a participant's ID:
 * 1. Create a SHA-256 hash of their lowercase ID (e.g., "0192:921605900")
 * 2. Base32-encode the hash (lowercase, strip trailing '=')
 * 3. Use the encoded hash to construct a DNS name
 * 4. Perform a NAPTR DNS lookup to get the SMP URL
 * 5. Extract the SMP URL from the NAPTR record's regexp field
 *
 * Returns the SMP URL if found, null if not found
 */
function sml_lookup($icd, $identifier, $sml_domain = SML_DOMAIN) {
    // Create SHA-256 hash of lowercase participant ID
    $participant_id = strtolower($icd . ':' . $identifier);
    $sha256_hash = hash('sha256', $participant_id, true);

    // Base32 encode, strip trailing '=', lowercase
    $b32 = strtolower(rtrim(base32_encode_bytes($sha256_hash), '='));

    // Construct DNS name
    $dns_name = $b32 . '.iso6523-actorid-upis.' . $sml_domain;

    // Perform NAPTR DNS lookup
    $records = @dns_get_record($dns_name, DNS_NAPTR);
    if ($records === false || empty($records)) {
        return null;
    }

    // Find Meta:SMP record with U flag
    foreach ($records as $record) {
        if (isset($record['services']) && $record['services'] === 'Meta:SMP'
            && isset($record['flags']) && strtoupper($record['flags']) === 'U') {
            // Extract URL from NAPTR regex field
            // Format: !pattern!replacement! (first char is delimiter)
            // For PEPPOL, the pattern is always ^.*$ and replacement is the SMP URL
            $regexp = $record['regex'];
            $delim = $regexp[0];
            $parts = explode($delim, $regexp);
            return $parts[2]; // replacement part contains the SMP URL
        }
    }

    return null;
}

/**
 * Step 2: Query SMP (Service Metadata Publisher) to get supported document types
 *
 * The SMP is like a business card in the PEPPOL network. It tells us:
 * 1. What types of documents the participant can receive
 * 2. Technical details needed for sending documents
 * 3. Specific document format versions they support
 */
function smp_lookup($smp_url, $icd, $identifier) {
    // Ensure SMP URL ends with /
    if (substr($smp_url, -1) !== '/') {
        $smp_url .= '/';
    }

    // Construct SMP URL
    // Format: {smp_url}/[identifier scheme]::[participant identifier]
    $participant_id = $icd . ':' . $identifier;
    $url = $smp_url . 'iso6523-actorid-upis::' . urlencode($participant_id);

    // Perform HTTPS GET request
    $response = file_get_contents($url);
    if ($response === false) {
        throw new Exception('Failed to fetch SMP data');
    }

    // Extract document types from ServiceMetadataReference href attributes
    $document_types = array();

    // Match ServiceMetadataReference href attributes
    if (preg_match_all('/ServiceMetadataReference[^>]*href="([^"]*)"[^>]*>/', $response, $matches)) {
        foreach ($matches[1] as $href) {
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

    // Step 1: Use SML to find where participant's metadata is hosted (NAPTR lookup)
    $smp_url = sml_lookup($icd, $identifier);
    if ($smp_url === null) {
        echo "Not a PEPPOL participant: $icd:$identifier\n";
        exit(1);
    }
    echo "SMP URL: $smp_url\n";

    // Step 2: Query their SMP to discover supported documents
    $document_types = smp_lookup($smp_url, $icd, $identifier);
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
