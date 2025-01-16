//! PEPPOL uses two key services to enable document exchange:
//!
//! 1. SML (Service Metadata Locator):
//!    - Acts as a DNS-based directory service
//!    - Maps a participant's ID to their SMP provider
//!    - Uses DNS lookup to find where a participant's metadata is hosted
//!    - Similar to how email's MX records help find mail servers
//!
//! 2. SMP (Service Metadata Publisher):
//!    - Hosts metadata about a participant's capabilities
//!    - Tells you what document types they can receive
//!    - Provides technical details needed for sending documents
//!    - Acts like a participant's business card in the network
//!
//! This example demonstrates how to:
//! 1. Use SML to find where a participant's metadata is hosted
//! 2. Query their SMP to discover what documents they can receive
//! 3. Check for PEPPOL BIS Billing 3.0 support

use md5::{Md5, Digest};
use regex::Regex;
use std::error::Error;
use std::net::ToSocketAddrs;

// Test environment SML domain
const SML_DOMAIN: &str = "edelivery.tech.ec.europa.eu";

// PEPPOL BIS Billing 3.0 document identifiers
const BIS_BILLING_INVOICE: &str = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice";
const BIS_BILLING_CREDITNOTE: &str = "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote";

/// Step 1: Use SML (Service Metadata Locator) to find a participant's SMP hostname
///
/// The SML is like a phone book for the PEPPOL network. Given a participant's ID:
/// 1. Create an MD5 hash of their ID (e.g., "0192:921605900")
/// 2. Use the hash to construct a DNS hostname
/// 3. If the hostname exists, the participant is registered in PEPPOL
/// 4. The hostname tells us where to find their metadata (SMP)
///
/// Returns the SMP hostname if found, None if not found
fn sml_lookup(icd: &str, identifier: &str, sml_domain: &str) -> Option<String> {
    // Create MD5 hash of participant ID
    let participant_id = format!("{}:{}", icd, identifier);
    let mut hasher = Md5::new();
    hasher.update(participant_id.as_bytes());
    let md5_hash = format!("{:x}", hasher.finalize());
    
    // Construct hostname
    let hostname = format!("b-{}.iso6523-actorid-upis.{}", md5_hash, sml_domain);
    
    // Check if hostname exists
    // Try to resolve hostname by attempting to convert it to a socket address
    match (hostname.as_str(), 0).to_socket_addrs() {
        Ok(_) => Some(hostname),
        Err(_) => None,
    }
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
fn smp_lookup(smp_hostname: &str, icd: &str, identifier: &str) -> Result<Vec<String>, Box<dyn Error>> {
    // Construct SMP URL
    // Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
    let participant_id = format!("{}:{}", icd, identifier);
    let url = format!("http://{}/iso6523-actorid-upis::{}", 
        smp_hostname,
        urlencoding::encode(&participant_id));
    
    // Perform HTTP GET request
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
    
    // Step 1: Perform SML lookup to get SMP hostname
    let smp_hostname = match sml_lookup(icd, identifier, SML_DOMAIN) {
        Some(hostname) => hostname,
        None => {
            println!("Not a PEPPOL participant: {}:{}", icd, identifier);
            return Ok(());
        }
    };
    println!("SMP hostname: {}", smp_hostname);
    
    // Step 2: Get supported document identifiers
    let document_types = smp_lookup(&smp_hostname, icd, identifier)?;
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
