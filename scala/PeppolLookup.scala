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

import java.net.{InetAddress, URL, URLEncoder, URLDecoder, UnknownHostException}
import java.security.MessageDigest
import scala.io.Source
import scala.util.{Try, Using}

object PeppolLookup {
  // Test environment SML domain
  val SML_DOMAIN = "edelivery.tech.ec.europa.eu"

  // PEPPOL BIS Billing 3.0 document identifiers
  val BIS_BILLING_INVOICE = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice"
  val BIS_BILLING_CREDITNOTE = "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote"

  /**
   * Step 1: Use SML (Service Metadata Locator) to find a participant's SMP hostname
   *
   * The SML is like a phone book for the PEPPOL network. Given a participant's ID:
   * 1. Create an MD5 hash of their ID (e.g., "0192:921605900")
   * 2. Use the hash to construct a DNS hostname
   * 3. If the hostname exists, the participant is registered in PEPPOL
   * 4. The hostname tells us where to find their metadata (SMP)
   *
   * Returns Some(hostname) if found, None if not found
   */
  def smlLookup(icd: String, identifier: String, smlDomain: String = SML_DOMAIN): Option[String] = {
    Try {
      // Create MD5 hash of participant ID
      val participantId = s"$icd:$identifier"
      val md5 = MessageDigest.getInstance("MD5")
      val hashBytes = md5.digest(participantId.getBytes)
      val md5Hash = hashBytes.map("%02x".format(_)).mkString

      // Construct hostname
      val hostname = s"b-$md5Hash.iso6523-actorid-upis.$smlDomain"

      // Check if hostname exists
      InetAddress.getByName(hostname)
      hostname
    }.toOption
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
  def smpLookup(smpHostname: String, icd: String, identifier: String): List[String] = {
    // Construct SMP URL
    // Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
    val participantId = s"$icd:$identifier"
    val encodedId = URLEncoder.encode(participantId, "UTF-8")
    val urlString = s"http://$smpHostname/iso6523-actorid-upis::$encodedId"

    // Perform HTTP GET request
    val url = new URL(urlString)
    val response = Using(Source.fromURL(url)) { source =>
      source.mkString
    }.get

    // Extract document types from ServiceMetadataReference href attributes
    val pattern = """ServiceMetadataReference[^>]*href="([^"]*)"[^>]*>""".r

    pattern.findAllMatchIn(response).flatMap { m =>
      val href = URLDecoder.decode(m.group(1), "UTF-8")
      if (href.contains("busdox-docid-qns::")) {
        val docType = href.split("busdox-docid-qns::")(1).split("#")(0)
        Some(docType)
      } else {
        None
      }
    }.toList
  }

  def main(args: Array[String]): Unit = {
    try {
      // Snapbooks AS (Norwegian organization number)
      val icd = "0192"
      val identifier = "921605900"

      // Step 1: Use SML to find where participant's metadata is hosted
      smlLookup(icd, identifier) match {
        case None =>
          println(s"Not a PEPPOL participant: $icd:$identifier")
          sys.exit(1)

        case Some(smpHostname) =>
          println(s"SMP hostname: $smpHostname")

          // Step 2: Query their SMP to discover supported documents
          val documentTypes = smpLookup(smpHostname, icd, identifier)
          println("\nSupported document identifiers:")
          documentTypes.foreach(docType => println(s"- $docType"))

          // Check for PEPPOL BIS Billing 3.0 documents
          println("\nPEPPOL BIS Billing 3.0 Support:")
          if (documentTypes.contains(BIS_BILLING_INVOICE)) {
            println("- Supports Invoice")
          }
          if (documentTypes.contains(BIS_BILLING_CREDITNOTE)) {
            println("- Supports Credit Note")
          }
      }
    } catch {
      case e: Exception =>
        System.err.println(s"Error: ${e.getMessage}")
        sys.exit(1)
    }
  }
}
