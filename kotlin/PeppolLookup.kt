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
import java.net.UnknownHostException
import java.security.MessageDigest

// Test environment SML domain
const val SML_DOMAIN = "edelivery.tech.ec.europa.eu"

// PEPPOL BIS Billing 3.0 document identifiers
const val BIS_BILLING_INVOICE = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice"
const val BIS_BILLING_CREDITNOTE = "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote"

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
fun smlLookup(icd: String, identifier: String, smlDomain: String = SML_DOMAIN): String? {
    return try {
        // Create MD5 hash of participant ID
        val participantId = "$icd:$identifier"
        val md5 = MessageDigest.getInstance("MD5")
        val hashBytes = md5.digest(participantId.toByteArray())
        val md5Hash = hashBytes.joinToString("") { "%02x".format(it) }

        // Construct hostname
        val hostname = "b-$md5Hash.iso6523-actorid-upis.$smlDomain"

        // Check if hostname exists
        InetAddress.getByName(hostname)
        hostname
    } catch (e: UnknownHostException) {
        null
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
fun smpLookup(smpHostname: String, icd: String, identifier: String): List<String> {
    // Construct SMP URL
    // Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
    val participantId = "$icd:$identifier"
    val encodedId = URLEncoder.encode(participantId, "UTF-8")
    val urlString = "http://$smpHostname/iso6523-actorid-upis::$encodedId"

    // Perform HTTP GET request
    val url = URL(urlString)
    val connection = url.openConnection()
    val response = connection.getInputStream().bufferedReader().use { it.readText() }

    // Extract document types from ServiceMetadataReference href attributes
    val documentTypes = mutableListOf<String>()

    // Match ServiceMetadataReference href attributes
    val regex = Regex("""ServiceMetadataReference[^>]*href="([^"]*)"[^>]*>""")
    regex.findAll(response).forEach { matchResult ->
        val href = java.net.URLDecoder.decode(matchResult.groupValues[1], "UTF-8")
        if ("busdox-docid-qns::" in href) {
            val docType = href.split("busdox-docid-qns::")[1].split("#")[0]
            documentTypes.add(docType)
        }
    }

    return documentTypes
}

fun main() {
    try {
        // Snapbooks AS (Norwegian organization number)
        val icd = "0192"
        val identifier = "921605900"

        // Step 1: Use SML to find where participant's metadata is hosted
        val smpHostname = smlLookup(icd, identifier)
        if (smpHostname == null) {
            println("Not a PEPPOL participant: $icd:$identifier")
            return
        }
        println("SMP hostname: $smpHostname")

        // Step 2: Query their SMP to discover supported documents
        val documentTypes = smpLookup(smpHostname, icd, identifier)
        println("\nSupported document identifiers:")
        documentTypes.forEach { docType ->
            println("- $docType")
        }

        // Check for PEPPOL BIS Billing 3.0 documents
        println("\nPEPPOL BIS Billing 3.0 Support:")
        if (BIS_BILLING_INVOICE in documentTypes) {
            println("- Supports Invoice")
        }
        if (BIS_BILLING_CREDITNOTE in documentTypes) {
            println("- Supports Credit Note")
        }

    } catch (e: Exception) {
        System.err.println("Error: ${e.message}")
    }
}
