#!/usr/bin/env dart

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

import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

// Test environment SML domain
const String SML_DOMAIN = 'edelivery.tech.ec.europa.eu';

// PEPPOL BIS Billing 3.0 document identifiers
const String BIS_BILLING_INVOICE = 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice';
const String BIS_BILLING_CREDITNOTE = 'urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote';

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
Future<String?> smlLookup(String icd, String identifier, [String smlDomain = SML_DOMAIN]) async {
  try {
    // Create MD5 hash of participant ID
    final participantId = '$icd:$identifier';
    final bytes = utf8.encode(participantId);
    final md5Hash = md5.convert(bytes).toString();

    // Construct hostname
    final hostname = 'b-$md5Hash.iso6523-actorid-upis.$smlDomain';

    // Check if hostname exists
    await InternetAddress.lookup(hostname);
    return hostname;
  } catch (e) {
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
Future<List<String>> smpLookup(String smpHostname, String icd, String identifier) async {
  // Construct SMP URL
  // Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
  final participantId = '$icd:$identifier';
  final encodedId = Uri.encodeComponent(participantId);
  final url = Uri.parse('http://$smpHostname/iso6523-actorid-upis::$encodedId');

  // Perform HTTP GET request
  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch SMP data: HTTP ${response.statusCode}');
    }

    final responseBody = await response.transform(utf8.decoder).join();

    // Extract document types from ServiceMetadataReference href attributes
    final documentTypes = <String>[];

    // Match ServiceMetadataReference href attributes
    final regex = RegExp(r'ServiceMetadataReference[^>]*href="([^"]*)"[^>]*>');
    final matches = regex.allMatches(responseBody);

    for (final match in matches) {
      final href = Uri.decodeComponent(match.group(1)!);
      if (href.contains('busdox-docid-qns::')) {
        final parts = href.split('busdox-docid-qns::');
        if (parts.length > 1) {
          final docType = parts[1].split('#')[0];
          documentTypes.add(docType);
        }
      }
    }

    return documentTypes;
  } finally {
    client.close();
  }
}

void main() async {
  try {
    // Snapbooks AS (Norwegian organization number)
    final icd = '0192';
    final identifier = '921605900';

    // Step 1: Use SML to find where participant's metadata is hosted
    final smpHostname = await smlLookup(icd, identifier);
    if (smpHostname == null) {
      print('Not a PEPPOL participant: $icd:$identifier');
      exit(1);
    }
    print('SMP hostname: $smpHostname');

    // Step 2: Query their SMP to discover supported documents
    final documentTypes = await smpLookup(smpHostname, icd, identifier);
    print('\nSupported document identifiers:');
    for (final docType in documentTypes) {
      print('- $docType');
    }

    // Check for PEPPOL BIS Billing 3.0 documents
    print('\nPEPPOL BIS Billing 3.0 Support:');
    if (documentTypes.contains(BIS_BILLING_INVOICE)) {
      print('- Supports Invoice');
    }
    if (documentTypes.contains(BIS_BILLING_CREDITNOTE)) {
      print('- Supports Credit Note');
    }

  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}
