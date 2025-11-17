#!/usr/bin/env swift

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

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Test environment SML domain
let SML_DOMAIN = "edelivery.tech.ec.europa.eu"

// PEPPOL BIS Billing 3.0 document identifiers
let BIS_BILLING_INVOICE = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice"
let BIS_BILLING_CREDITNOTE = "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote"

/**
 * Step 1: Use SML (Service Metadata Locator) to find a participant's SMP hostname
 *
 * The SML is like a phone book for the PEPPOL network. Given a participant's ID:
 * 1. Create an MD5 hash of their ID (e.g., "0192:921605900")
 * 2. Use the hash to construct a DNS hostname
 * 3. If the hostname exists, the participant is registered in PEPPOL
 * 4. The hostname tells us where to find their metadata (SMP)
 *
 * Returns the SMP hostname if found, nil if not found
 */
func smlLookup(icd: String, identifier: String, smlDomain: String = SML_DOMAIN) -> String? {
    // Create MD5 hash of participant ID
    let participantId = "\(icd):\(identifier)"
    guard let data = participantId.data(using: .utf8) else { return nil }

    var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
    data.withUnsafeBytes {
        _ = CC_MD5($0.baseAddress, CC_LONG(data.count), &digest)
    }
    let md5Hash = digest.map { String(format: "%02x", $0) }.joined()

    // Construct hostname
    let hostname = "b-\(md5Hash).iso6523-actorid-upis.\(smlDomain)"

    // Check if hostname exists using CFHost (cross-platform DNS lookup)
    var resolved = false
    let host = CFHostCreateWithName(nil, hostname as CFString).takeRetainedValue()
    if CFHostStartInfoResolution(host, .addresses, nil) {
        var success: DarwinBoolean = false
        if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as? [Data], success.boolValue && !addresses.isEmpty {
            resolved = true
        }
    }

    return resolved ? hostname : nil
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
func smpLookup(smpHostname: String, icd: String, identifier: String) throws -> [String] {
    // Construct SMP URL
    // Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
    let participantId = "\(icd):\(identifier)"
    guard let encodedId = participantId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
        throw NSError(domain: "PeppolLookup", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode participant ID"])
    }
    let urlString = "http://\(smpHostname)/iso6523-actorid-upis::\(encodedId)"

    guard let url = URL(string: urlString) else {
        throw NSError(domain: "PeppolLookup", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
    }

    // Perform synchronous HTTP GET request
    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<String, Error> = .failure(NSError(domain: "PeppolLookup", code: 3, userInfo: [NSLocalizedDescriptionKey: "Request not completed"]))

    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            result = .failure(error)
        } else if let data = data, let responseString = String(data: data, encoding: .utf8) {
            result = .success(responseString)
        }
        semaphore.signal()
    }
    task.resume()
    semaphore.wait()

    let response = try result.get()

    // Extract document types from ServiceMetadataReference href attributes
    var documentTypes: [String] = []

    // Match ServiceMetadataReference href attributes
    let pattern = #"ServiceMetadataReference[^>]*href="([^"]*)"[^>]*>"#
    let regex = try NSRegularExpression(pattern: pattern)
    let nsrange = NSRange(response.startIndex..<response.endIndex, in: response)

    regex.enumerateMatches(in: response, range: nsrange) { match, _, _ in
        guard let match = match,
              let hrefRange = Range(match.range(at: 1), in: response) else { return }

        let href = String(response[hrefRange]).removingPercentEncoding ?? String(response[hrefRange])
        if let range = href.range(of: "busdox-docid-qns::") {
            let remainder = String(href[range.upperBound...])
            if let hashRange = remainder.range(of: "#") {
                let docType = String(remainder[..<hashRange.lowerBound])
                documentTypes.append(docType)
            } else {
                documentTypes.append(remainder)
            }
        }
    }

    return documentTypes
}

// Import CommonCrypto for MD5
import CommonCrypto

// Main execution
do {
    // Snapbooks AS (Norwegian organization number)
    let icd = "0192"
    let identifier = "921605900"

    // Step 1: Use SML to find where participant's metadata is hosted
    guard let smpHostname = smlLookup(icd: icd, identifier: identifier) else {
        print("Not a PEPPOL participant: \(icd):\(identifier)")
        exit(1)
    }
    print("SMP hostname: \(smpHostname)")

    // Step 2: Query their SMP to discover supported documents
    let documentTypes = try smpLookup(smpHostname: smpHostname, icd: icd, identifier: identifier)
    print("\nSupported document identifiers:")
    for docType in documentTypes {
        print("- \(docType)")
    }

    // Check for PEPPOL BIS Billing 3.0 documents
    print("\nPEPPOL BIS Billing 3.0 Support:")
    if documentTypes.contains(BIS_BILLING_INVOICE) {
        print("- Supports Invoice")
    }
    if documentTypes.contains(BIS_BILLING_CREDITNOTE) {
        print("- Supports Credit Note")
    }

} catch {
    fputs("Error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
