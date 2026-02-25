using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Web;
using System.Xml.Linq;
using DnsClient;

/*
PEPPOL uses two key services to enable document exchange:

1. SML (Service Metadata Locator):
   - Acts as a DNS-based directory service
   - Maps a participant's ID to their SMP provider
   - Uses NAPTR DNS records to find where a participant's metadata is hosted
   - Similar to how email's MX records help find mail servers

2. SMP (Service Metadata Publisher):
   - Hosts metadata about a participant's capabilities
   - Tells you what document types they can receive
   - Provides technical details needed for sending documents
   - Acts like a participant's business card in the network

This example demonstrates how to:
1. Use SML to find where a participant's metadata is hosted (via NAPTR DNS lookup)
2. Query their SMP to discover what documents they can receive
3. Check for PEPPOL BIS Billing 3.0 support

Requires NuGet: DnsClient
*/
class Program
{
    // Test environment SML domain
    private const string SML_DOMAIN = "edelivery.tech.ec.europa.eu";

    // PEPPOL BIS Billing 3.0 document identifiers
    private const string BIS_BILLING_INVOICE = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice";
    private const string BIS_BILLING_CREDITNOTE = "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote";

    // Base32 alphabet (RFC 4648)
    private const string BASE32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

    static async Task Main()
    {
        try
        {
            // Snapbooks AS (Norwegian organization number)
            string icd = "0192";
            string identifier = "921605900";

            // Step 1: Use SML to find where participant's metadata is hosted (NAPTR lookup)
            string smpUrl = await SmlLookup(icd, identifier);
            if (smpUrl == null)
            {
                Console.WriteLine($"Not a PEPPOL participant: {icd}:{identifier}");
                return;
            }
            Console.WriteLine($"SMP URL: {smpUrl}");

            // Step 2: Query their SMP to discover supported documents
            var documentTypes = await SmpLookup(smpUrl, icd, identifier);
            Console.WriteLine("\nSupported document identifiers:");
            foreach (var docType in documentTypes)
            {
                Console.WriteLine($"- {docType}");
            }

            // Check for PEPPOL BIS Billing 3.0 documents
            Console.WriteLine("\nPEPPOL BIS Billing 3.0 Support:");
            if (documentTypes.Contains(BIS_BILLING_INVOICE))
            {
                Console.WriteLine("- Supports Invoice");
            }
            if (documentTypes.Contains(BIS_BILLING_CREDITNOTE))
            {
                Console.WriteLine("- Supports Credit Note");
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Error: {ex.Message}");
        }
    }

    /// <summary>
    /// Base32 encode a byte array (RFC 4648)
    /// </summary>
    private static string Base32Encode(byte[] data)
    {
        var result = new StringBuilder();
        int bits = 0;
        int value = 0;

        foreach (byte b in data)
        {
            value = (value << 8) | b;
            bits += 8;
            while (bits >= 5)
            {
                result.Append(BASE32_ALPHABET[(value >>> (bits - 5)) & 31]);
                bits -= 5;
            }
        }

        if (bits > 0)
        {
            result.Append(BASE32_ALPHABET[(value << (5 - bits)) & 31]);
        }

        return result.ToString();
    }

    /// <summary>
    /// Step 1: Use SML (Service Metadata Locator) to find a participant's SMP URL
    ///
    /// The SML is like a phone book for the PEPPOL network. Given a participant's ID:
    /// 1. Create a SHA-256 hash of their lowercase ID (e.g., "0192:921605900")
    /// 2. Base32-encode the hash (lowercase, strip trailing '=')
    /// 3. Use the encoded hash to construct a DNS name
    /// 4. Perform a NAPTR DNS lookup to get the SMP URL
    /// 5. Extract the SMP URL from the NAPTR record's regexp field
    /// </summary>
    /// <returns>The SMP URL if found, null if not found</returns>
    private static async Task<string> SmlLookup(string icd, string identifier)
    {
        // Create SHA-256 hash of lowercase participant ID
        var participantId = $"{icd}:{identifier}".ToLower();
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(participantId));

        // Base32 encode, strip trailing '=', lowercase
        var b32 = Base32Encode(hash).TrimEnd('=').ToLower();

        // Construct DNS name
        var dnsName = $"{b32}.iso6523-actorid-upis.{SML_DOMAIN}";

        try
        {
            // Perform NAPTR DNS lookup using DnsClient
            var lookup = new LookupClient();
            var result = await lookup.QueryAsync(dnsName, QueryType.NAPTR);

            foreach (var record in result.Answers.NaptrRecords())
            {
                if (record.Service == "Meta:SMP" && record.Flags.ToUpper() == "U")
                {
                    // Extract URL from NAPTR regexp field
                    // Format: !pattern!replacement! (first char is delimiter)
                    var regexp = record.Regexp;
                    var delim = regexp[0];
                    var parts = regexp.Split(delim);
                    if (parts.Length >= 3)
                    {
                        var pattern = parts[1];
                        var replacement = parts[2];
                        var smpUrl = Regex.Replace(dnsName, pattern, replacement);
                        return smpUrl;
                    }
                }
            }
        }
        catch
        {
            return null;
        }

        return null;
    }

    /// <summary>
    /// Step 2: Query SMP (Service Metadata Publisher) to get supported document types
    ///
    /// The SMP is like a business card in the PEPPOL network. It tells us:
    /// 1. What types of documents the participant can receive
    /// 2. Technical details needed for sending documents
    /// 3. Specific document format versions they support
    ///
    /// This is similar to how DNS MX records tell you where to send email,
    /// but SMP also includes what "types" of messages you can send.
    /// </summary>
    private static async Task<List<string>> SmpLookup(string smpUrl, string icd, string identifier)
    {
        var documentTypes = new List<string>();

        // Ensure SMP URL ends with /
        if (!smpUrl.EndsWith("/"))
        {
            smpUrl += "/";
        }

        // Construct SMP URL
        // Format: {smp_url}/[identifier scheme]::[participant identifier]
        var participantId = $"{icd}:{identifier}";
        var url = $"{smpUrl}iso6523-actorid-upis::{HttpUtility.UrlEncode(participantId)}";

        using var client = new HttpClient();
        var response = await client.GetStringAsync(url);

        // Parse XML response
        var doc = XDocument.Parse(response);
        var ns = XNamespace.Get("http://busdox.org/serviceMetadata/publishing/1.0/");
        var refs = doc.Descendants(ns + "ServiceMetadataReference");

        foreach (var reference in refs)
        {
            var href = reference.Attribute("href")?.Value;
            if (string.IsNullOrEmpty(href)) continue;

            var decodedHref = HttpUtility.UrlDecode(href);
            if (decodedHref.Contains("busdox-docid-qns::"))
            {
                var docType = decodedHref.Split("busdox-docid-qns::")[1].Split("#")[0];
                documentTypes.Add(docType);
            }
        }

        return documentTypes;
    }
}
