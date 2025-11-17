#!/usr/bin/env dotnet fsi

(**
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
 *)

open System
open System.Net
open System.Net.Http
open System.Security.Cryptography
open System.Text
open System.Text.RegularExpressions

// Test environment SML domain
let SML_DOMAIN = "edelivery.tech.ec.europa.eu"

// PEPPOL BIS Billing 3.0 document identifiers
let BIS_BILLING_INVOICE = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice"
let BIS_BILLING_CREDITNOTE = "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote"

(**
 * Step 1: Use SML (Service Metadata Locator) to find a participant's SMP hostname
 *
 * The SML is like a phone book for the PEPPOL network. Given a participant's ID:
 * 1. Create an MD5 hash of their ID (e.g., "0192:921605900")
 * 2. Use the hash to construct a DNS hostname
 * 3. If the hostname exists, the participant is registered in PEPPOL
 * 4. The hostname tells us where to find their metadata (SMP)
 *
 * Returns Some(hostname) if found, None if not found
 *)
let smlLookup (icd: string) (identifier: string) (smlDomain: string) =
    try
        // Create MD5 hash of participant ID
        let participantId = sprintf "%s:%s" icd identifier
        use md5 = MD5.Create()
        let hashBytes = md5.ComputeHash(Encoding.UTF8.GetBytes(participantId))
        let md5Hash =
            hashBytes
            |> Array.map (fun b -> b.ToString("x2"))
            |> String.concat ""

        // Construct hostname
        let hostname = sprintf "b-%s.iso6523-actorid-upis.%s" md5Hash smlDomain

        // Check if hostname exists
        Dns.GetHostAddresses(hostname) |> ignore
        Some hostname
    with
    | :? System.Net.Sockets.SocketException -> None

(**
 * Step 2: Query SMP (Service Metadata Publisher) to get supported document types
 *
 * The SMP is like a business card in the PEPPOL network. It tells us:
 * 1. What types of documents the participant can receive
 * 2. Technical details needed for sending documents
 * 3. Specific document format versions they support
 *
 * This is similar to how DNS MX records tell you where to send email,
 * but SMP also includes what "types" of messages you can send.
 *)
let smpLookup (smpHostname: string) (icd: string) (identifier: string) =
    // Construct SMP URL
    // Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
    let participantId = sprintf "%s:%s" icd identifier
    let encodedId = Uri.EscapeDataString(participantId)
    let url = sprintf "http://%s/iso6523-actorid-upis::%s" smpHostname encodedId

    // Perform HTTP GET request
    use client = new HttpClient()
    let response = client.GetStringAsync(url).Result

    // Extract document types from ServiceMetadataReference href attributes
    let pattern = @"ServiceMetadataReference[^>]*href=""([^""]*)""[^>]*>"
    let regex = Regex(pattern)

    regex.Matches(response)
    |> Seq.cast<Match>
    |> Seq.map (fun m -> Uri.UnescapeDataString(m.Groups.[1].Value))
    |> Seq.filter (fun href -> href.Contains("busdox-docid-qns::"))
    |> Seq.map (fun href ->
        let parts = href.Split([|"busdox-docid-qns::"|], StringSplitOptions.None)
        parts.[1].Split('#').[0])
    |> Seq.toList

// Main execution
try
    // Snapbooks AS (Norwegian organization number)
    let icd = "0192"
    let identifier = "921605900"

    // Step 1: Use SML to find where participant's metadata is hosted
    match smlLookup icd identifier SML_DOMAIN with
    | None ->
        printfn "Not a PEPPOL participant: %s:%s" icd identifier
        exit 1
    | Some smpHostname ->
        printfn "SMP hostname: %s" smpHostname

        // Step 2: Query their SMP to discover supported documents
        let documentTypes = smpLookup smpHostname icd identifier
        printfn "\nSupported document identifiers:"
        documentTypes |> List.iter (fun docType -> printfn "- %s" docType)

        // Check for PEPPOL BIS Billing 3.0 documents
        printfn "\nPEPPOL BIS Billing 3.0 Support:"
        if documentTypes |> List.contains BIS_BILLING_INVOICE then
            printfn "- Supports Invoice"
        if documentTypes |> List.contains BIS_BILLING_CREDITNOTE then
            printfn "- Supports Credit Note"
with
| ex ->
    eprintfn "Error: %s" ex.Message
    exit 1
