//! PEPPOL uses two key services to enable document exchange:
//!
//! 1. SML (Service Metadata Locator):
//!    - Acts as a DNS-based directory service
//!    - Maps a participant's ID to their SMP provider
//!    - Uses NAPTR DNS records to find where a participant's metadata is hosted
//!    - Similar to how email's MX records help find mail servers
//!
//! 2. SMP (Service Metadata Publisher):
//!    - Hosts metadata about a participant's capabilities
//!    - Tells you what document types they can receive
//!    - Provides technical details needed for sending documents
//!    - Acts like a participant's business card in the network
//!
//! This example demonstrates how to:
//! 1. Use SML to find where a participant's metadata is hosted (via NAPTR DNS lookup)
//! 2. Query their SMP to discover what documents they can receive
//! 3. Check for PEPPOL BIS Billing 3.0 support

use data_encoding::BASE32;
use regex::Regex;
use sha2::{Digest, Sha256};
use std::error::Error;
use std::process::Command;

// Test environment SML domain
const SML_DOMAIN: &str = "edelivery.tech.ec.europa.eu";

// PEPPOL BIS Billing 3.0 document identifiers
const BIS_BILLING_INVOICE: &str = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice";
const BIS_BILLING_CREDITNOTE: &str = "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote";

/// Step 1: Use SML (Service Metadata Locator) to find a participant's SMP URL
///
/// The SML is like a phone book for the PEPPOL network. Given a participant's ID:
/// 1. Create a SHA-256 hash of their lowercase ID (e.g., "0192:921605900")
/// 2. Base32-encode the hash (lowercase, strip trailing '=')
/// 3. Use the encoded hash to construct a DNS name
/// 4. Perform a NAPTR DNS lookup to get the SMP URL
/// 5. Extract the SMP URL from the NAPTR record's regexp field
///
/// Returns the SMP URL if found, None if not found
fn sml_lookup(icd: &str, identifier: &str, sml_domain: &str) -> Option<String> {
    // Create SHA-256 hash of lowercase participant ID
    let participant_id = format!("{}:{}", icd, identifier).to_lowercase();
    let mut hasher = Sha256::new();
    hasher.update(participant_id.as_bytes());
    let hash = hasher.finalize();

    // Base32 encode, strip trailing '=', lowercase
    let b32 = BASE32
        .encode(&hash)
        .trim_end_matches('=')
        .to_lowercase();

    // Construct DNS name
    let dns_name = format!("{}.iso6523-actorid-upis.{}", b32, sml_domain);

    // Perform NAPTR DNS lookup using dig command
    let output = Command::new("dig")
        .args(&["+short", "-t", "naptr", &dns_name])
        .output()
        .ok()?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    if stdout.trim().is_empty() {
        return None;
    }

    // Parse dig output: order preference "flags" "service" "regexp" replacement
    let quote_re = Regex::new(r#""([^"]*)""#).ok()?;
    for line in stdout.lines() {
        if !line.contains("\"Meta:SMP\"") {
            continue;
        }
        // Extract quoted fields: flags, service, regexp
        let captures: Vec<_> = quote_re.captures_iter(line).collect();
        if captures.len() < 3 {
            continue;
        }
        let regexp = &captures[2][1]; // 3rd quoted string is the regexp field
        if regexp.len() < 3 {
            continue;
        }
        let delim = &regexp[0..1];
        let parts: Vec<&str> = regexp.splitn(4, delim).collect();
        if parts.len() < 3 {
            continue;
        }
        // replacement part contains the SMP URL
        return Some(parts[2].to_string());
    }

    None
}

/// Step 2: Query SMP (Service Metadata Publisher) to get supported document types
///
/// The SMP is like a business card in the PEPPOL network. It tells us:
/// 1. What types of documents the participant can receive
/// 2. Technical details needed for sending documents
/// 3. Specific document format versions they support
///
/// This is similar to how DNS MX records tell you where to send email,
/// but SMP also includes what "types" of messages you can send.
fn smp_lookup(smp_url: &str, icd: &str, identifier: &str) -> Result<Vec<String>, Box<dyn Error>> {
    // Ensure SMP URL ends with /
    let base_url = if smp_url.ends_with('/') {
        smp_url.to_string()
    } else {
        format!("{}/", smp_url)
    };

    // Construct SMP URL
    // Format: {smp_url}/[identifier scheme]::[participant identifier]
    let participant_id = format!("{}:{}", icd, identifier);
    let url = format!(
        "{}iso6523-actorid-upis::{}",
        base_url,
        urlencoding::encode(&participant_id)
    );

    // Perform HTTPS GET request
    let client = reqwest::blocking::Client::new();
    let response = client.get(&url).send()?.text()?;

    // Extract document types from ServiceMetadataReference href attributes
    let mut document_types = Vec::new();

    // Match ServiceMetadataReference href attributes
    let re = Regex::new(r#"ServiceMetadataReference[^>]*href="([^"]*)"[^>]*>"#)?;
    for cap in re.captures_iter(&response) {
        let href = urlencoding::decode(&cap[1])?.to_string();
        if href.contains("busdox-docid-qns::") {
            let parts: Vec<&str> = href.split("busdox-docid-qns::").collect();
            if parts.len() > 1 {
                let doc_type = parts[1].split('#').next().unwrap_or("");
                document_types.push(doc_type.to_string());
            }
        }
    }

    Ok(document_types)
}

fn main() -> Result<(), Box<dyn Error>> {
    // Snapbooks AS (Norwegian organization number)
    let icd = "0192";
    let identifier = "921605900";

    // Step 1: Perform SML lookup to get SMP URL via NAPTR
    let smp_url = match sml_lookup(icd, identifier, SML_DOMAIN) {
        Some(url) => url,
        None => {
            println!("Not a PEPPOL participant: {}:{}", icd, identifier);
            return Ok(());
        }
    };
    println!("SMP URL: {}", smp_url);

    // Step 2: Get supported document identifiers
    let document_types = smp_lookup(&smp_url, icd, identifier)?;
    println!("\nSupported document identifiers:");
    for doc_type in &document_types {
        println!("- {}", doc_type);
    }

    // Check for PEPPOL BIS Billing 3.0 documents
    println!("\nPEPPOL BIS Billing 3.0 Support:");
    if document_types.contains(&BIS_BILLING_INVOICE.to_string()) {
        println!("- Supports Invoice");
    }
    if document_types.contains(&BIS_BILLING_CREDITNOTE.to_string()) {
        println!("- Supports Credit Note");
    }

    Ok(())
}
