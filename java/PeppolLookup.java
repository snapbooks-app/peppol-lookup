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

import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.net.URL;
import java.net.URLDecoder;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.List;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

public class PeppolLookup {
    // Test environment SML domain
    private static final String SML_DOMAIN = "edelivery.tech.ec.europa.eu";
    
    // PEPPOL BIS Billing 3.0 document identifiers
    private static final String BIS_BILLING_INVOICE = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice";
    private static final String BIS_BILLING_CREDITNOTE = "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote";

    public static void main(String[] args) {
        try {
            // Snapbooks AS (Norwegian organization number)
            String icd = "0192";
            String identifier = "921605900";
            
            // Step 1: Use SML to find where participant's metadata is hosted
            String smpHostname = smlLookup(icd, identifier);
            if (smpHostname == null) {
                System.out.println("Not a PEPPOL participant: " + icd + ":" + identifier);
                return;
            }
            System.out.println("SMP hostname: " + smpHostname);
            
            // Step 2: Query their SMP to discover supported documents
            List<String> documentTypes = smpLookup(smpHostname, icd, identifier);
            System.out.println("\nSupported document identifiers:");
            for (String docType : documentTypes) {
                System.out.println("- " + docType);
            }
            
            // Check for PEPPOL BIS Billing 3.0 documents
            System.out.println("\nPEPPOL BIS Billing 3.0 Support:");
            if (documentTypes.contains(BIS_BILLING_INVOICE)) {
                System.out.println("- Supports Invoice");
            }
            if (documentTypes.contains(BIS_BILLING_CREDITNOTE)) {
                System.out.println("- Supports Credit Note");
            }
            
        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Step 1: Use SML (Service Metadata Locator) to find a participant's SMP hostname
     *
     * The SML is like a phone book for the PEPPOL network. Given a participant's ID:
     * 1. Create an MD5 hash of their ID (e.g., "0192:921605900")
     * 2. Use the hash to construct a DNS hostname
     * 3. If the hostname exists, the participant is registered in PEPPOL
     * 4. The hostname tells us where to find their metadata (SMP)
     *
     * @return The SMP hostname if found, null if not found
     */
    private static String smlLookup(String icd, String identifier) throws Exception {
        // Create MD5 hash of participant ID
        MessageDigest md = MessageDigest.getInstance("MD5");
        String participantId = icd + ":" + identifier;
        byte[] hash = md.digest(participantId.getBytes(StandardCharsets.UTF_8));
        
        // Convert hash to hexadecimal
        StringBuilder hexString = new StringBuilder();
        for (byte b : hash) {
            hexString.append(String.format("%02x", b));
        }
        
        // Construct hostname
        String hostname = "b-" + hexString + ".iso6523-actorid-upis." + SML_DOMAIN;
        
        try {
            // Check if hostname exists
            InetAddress.getByName(hostname);
            return hostname;
        } catch (Exception e) {
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
    private static List<String> smpLookup(String smpHostname, String icd, String identifier) throws Exception {
        List<String> documentTypes = new ArrayList<>();
        
        // Construct SMP URL
        // Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
        String participantId = icd + ":" + identifier;
        String url = String.format("http://%s/iso6523-actorid-upis::%s", 
            smpHostname,
            URLEncoder.encode(participantId, StandardCharsets.UTF_8));
            
        // Perform HTTP GET request
        HttpURLConnection conn = (HttpURLConnection) new URL(url).openConnection();
        conn.setRequestMethod("GET");
        
        // Parse XML response
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        factory.setNamespaceAware(true);
        DocumentBuilder builder = factory.newDocumentBuilder();
        Document doc = builder.parse(conn.getInputStream());
        
        // Extract document types from ServiceMetadataReference href attributes
        NodeList refs = doc.getElementsByTagNameNS("http://busdox.org/serviceMetadata/publishing/1.0/", "ServiceMetadataReference");
        for (int i = 0; i < refs.getLength(); i++) {
            Element ref = (Element) refs.item(i);
            String href = ref.getAttribute("href");
            
            // Extract document type from href
            // Example href format: .../services/busdox-docid-qns%3A%3Aurn%3Aoasis%3Anames%3Aspecification%3Aubl%3Aschema%3Axsd%3AInvoice-2...
            String decodedHref = URLDecoder.decode(href, StandardCharsets.UTF_8);
            if (decodedHref.contains("busdox-docid-qns::")) {
                String docType = decodedHref.split("busdox-docid-qns::")[1].split("#")[0];
                documentTypes.add(docType);
            }
        }
        
        return documentTypes;
    }
}
