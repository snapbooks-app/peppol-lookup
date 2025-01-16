using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using System.Web;
using System.Xml.Linq;

/*
PEPPOL uses two key services to enable document exchange:

1. SML (Service Metadata Locator):
   - Acts as a DNS-based directory service
   - Maps a participant's ID to their SMP provider
   - Uses DNS lookup to find where a participant's metadata is hosted
   - Similar to how email's MX records help find mail servers

2. SMP (Service Metadata Publisher):
   - Hosts metadata about a participant's capabilities
   - Tells you what document types they can receive
   - Provides technical details needed for sending documents
   - Acts like a participant's business card in the network

This example demonstrates how to:
1. Use SML to find where a participant's metadata is hosted
2. Query their SMP to discover what documents they can receive
3. Check for PEPPOL BIS Billing 3.0 support
*/
class Program
{
    // Test environment SML domain
    private const string SML_DOMAIN = "edelivery.tech.ec.europa.eu";
    
    // PEPPOL BIS Billing 3.0 document identifiers
    private const string BIS_BILLING_INVOICE = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice";
    private const string BIS_BILLING_CREDITNOTE = "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote";

    static async Task Main()
    {
        try
        {
            // Snapbooks AS (Norwegian organization number)
            string icd = "0192";
            string identifier = "921605900";
            
            // Step 1: Use SML to find where participant's metadata is hosted
            string smpHostname = await SmlLookup(icd, identifier);
            if (smpHostname == null)
            {
                Console.WriteLine($"Not a PEPPOL participant: {icd}:{identifier}");
                return;
            }
            Console.WriteLine($"SMP hostname: {smpHostname}");
            
            // Step 2: Query their SMP to discover supported documents
            var documentTypes = await SmpLookup(smpHostname, icd, identifier);
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
    /// Step 1: Use SML (Service Metadata Locator) to find a participant's SMP hostname
    /// 
    /// The SML is like a phone book for the PEPPOL network. Given a participant's ID:
    /// 1. Create an MD5 hash of their ID (e.g., "0192:921605900")
    /// 2. Use the hash to construct a DNS hostname
    /// 3. If the hostname exists, the participant is registered in PEPPOL
    /// 4. The hostname tells us where to find their metadata (SMP)
    /// </summary>
    /// <returns>The SMP hostname if found, null if not found</returns>
    private static async Task<string> SmlLookup(string icd, string identifier)
    {
        // Create MD5 hash of participant ID
        using var md5 = MD5.Create();
        var participantId = $"{icd}:{identifier}";
        var hash = md5.ComputeHash(Encoding.UTF8.GetBytes(participantId));
        var hexString = BitConverter.ToString(hash).Replace("-", "").ToLower();
        
        // Construct hostname
        var hostname = $"b-{hexString}.iso6523-actorid-upis.{SML_DOMAIN}";
        
        try
        {
            // Check if hostname exists
            var addresses = await Dns.GetHostAddressesAsync(hostname);
            return hostname;
        }
        catch
        {
            return null;
        }
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
    private static async Task<List<string>> SmpLookup(string smpHostname, string icd, string identifier)
    {
        var documentTypes = new List<string>();
        
        // Construct SMP URL
        // Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
        var participantId = $"{icd}:{identifier}";
        var url = $"http://{smpHostname}/iso6523-actorid-upis::{HttpUtility.UrlEncode(participantId)}";
        
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
            
            // Extract document type from href
            // Example href format: .../services/busdox-docid-qns%3A%3Aurn%3Aoasis%3Anames%3Aspecification%3Aubl%3Aschema%3Axsd%3AInvoice-2...
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
