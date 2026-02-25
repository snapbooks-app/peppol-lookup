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

import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URI;
import java.net.URL;
import java.net.URLDecoder;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Hashtable;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import javax.naming.NamingEnumeration;
import javax.naming.directory.Attribute;
import javax.naming.directory.Attributes;
import javax.naming.directory.DirContext;
import javax.naming.directory.InitialDirContext;
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

    // Base32 alphabet (RFC 4648)
    private static final String BASE32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

    public static void main(String[] args) {
        try {
            // Snapbooks AS (Norwegian organization number)
            String icd = "0192";
            String identifier = "921605900";

            // Step 1: Use SML to find where participant's metadata is hosted (NAPTR lookup)
            String smpUrl = smlLookup(icd, identifier);
            if (smpUrl == null) {
                System.out.println("Not a PEPPOL participant: " + icd + ":" + identifier);
                return;
            }
            System.out.println("SMP URL: " + smpUrl);

            // Step 2: Query their SMP to discover supported documents
            List<String> documentTypes = smpLookup(smpUrl, icd, identifier);
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
     * Base32 encode a byte array (RFC 4648)
     */
    private static String base32Encode(byte[] data) {
        StringBuilder result = new StringBuilder();
        int bits = 0;
        int value = 0;

        for (byte b : data) {
            value = (value << 8) | (b & 0xFF);
            bits += 8;
            while (bits >= 5) {
                result.append(BASE32_ALPHABET.charAt((value >>> (bits - 5)) & 31));
                bits -= 5;
            }
        }

        if (bits > 0) {
            result.append(BASE32_ALPHABET.charAt((value << (5 - bits)) & 31));
        }

        return result.toString();
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
     * @return The SMP URL if found, null if not found
     */
    private static String smlLookup(String icd, String identifier) throws Exception {
        // Create SHA-256 hash of lowercase participant ID
        MessageDigest sha256 = MessageDigest.getInstance("SHA-256");
        String participantId = (icd + ":" + identifier).toLowerCase();
        byte[] hash = sha256.digest(participantId.getBytes(StandardCharsets.UTF_8));

        // Base32 encode, strip trailing '=', lowercase
        String b32 = base32Encode(hash).replaceAll("=+$", "").toLowerCase();

        // Construct DNS name
        String dnsName = b32 + ".iso6523-actorid-upis." + SML_DOMAIN;

        try {
            // Perform NAPTR DNS lookup via JNDI
            Hashtable<String, String> env = new Hashtable<>();
            env.put("java.naming.factory.initial", "com.sun.jndi.dns.DnsContextFactory");
            DirContext ctx = new InitialDirContext(env);
            Attributes attrs = ctx.getAttributes(dnsName, new String[]{"NAPTR"});

            Attribute naptrAttr = attrs.get("NAPTR");
            if (naptrAttr == null) {
                return null;
            }

            NamingEnumeration<?> records = naptrAttr.getAll();
            while (records.hasMore()) {
                String record = records.next().toString();
                // JNDI NAPTR format: "order preference flags service regexp replacement"
                // Example: "100 10 U Meta:SMP !^.*$!https://smp.example.com/! ."
                if (record.contains("Meta:SMP")) {
                    // Extract SMP URL from regexp field
                    // Format: !pattern!replacement! - replacement contains the SMP URL
                    Pattern regexpExtractor = Pattern.compile("!([^!]*)!([^!]*)!");
                    Matcher matcher = regexpExtractor.matcher(record);
                    if (matcher.find()) {
                        return matcher.group(2); // replacement part contains the SMP URL
                    }
                }
            }
        } catch (Exception e) {
            return null;
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
     *
     * This is similar to how DNS MX records tell you where to send email,
     * but SMP also includes what "types" of messages you can send.
     */
    private static List<String> smpLookup(String smpUrl, String icd, String identifier) throws Exception {
        List<String> documentTypes = new ArrayList<>();

        // Ensure SMP URL ends with /
        if (!smpUrl.endsWith("/")) {
            smpUrl += "/";
        }

        // Construct SMP URL
        // Format: {smp_url}/[identifier scheme]::[participant identifier]
        String participantId = icd + ":" + identifier;
        String url = String.format("%siso6523-actorid-upis::%s",
            smpUrl,
            URLEncoder.encode(participantId, StandardCharsets.UTF_8));

        // Perform HTTPS GET request
        HttpURLConnection conn = (HttpURLConnection) new URI(url).toURL().openConnection();
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

            String decodedHref = URLDecoder.decode(href, StandardCharsets.UTF_8);
            if (decodedHref.contains("busdox-docid-qns::")) {
                String docType = decodedHref.split("busdox-docid-qns::")[1].split("#")[0];
                documentTypes.add(docType);
            }
        }

        return documentTypes;
    }
}
