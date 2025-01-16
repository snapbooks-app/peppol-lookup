#!/usr/bin/env node

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

const crypto = require('crypto');
const dns = require('dns').promises;
const http = require('http');

// Test environment SML domain
const SML_DOMAIN = 'edelivery.tech.ec.europa.eu';

// PEPPOL BIS Billing 3.0 document identifiers
const BIS_BILLING_INVOICE = 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice';
const BIS_BILLING_CREDITNOTE = 'urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote';

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
async function smlLookup(icd, identifier, smlDomain = SML_DOMAIN) {
    try {
        // Create MD5 hash of participant ID
        const participantId = `${icd}:${identifier}`;
        const md5Hash = crypto.createHash('md5').update(participantId).digest('hex');
        
        // Construct hostname
        const hostname = `b-${md5Hash}.iso6523-actorid-upis.${smlDomain}`;
        
        // Check if hostname exists
        await dns.lookup(hostname);
        return hostname;
    } catch (error) {
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
async function smpLookup(smpHostname, icd, identifier) {
    return new Promise((resolve, reject) => {
        // Construct SMP URL
        // Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
        const participantId = `${icd}:${identifier}`;
        const url = `http://${smpHostname}/iso6523-actorid-upis::${encodeURIComponent(participantId)}`;
        
        http.get(url, (res) => {
            let data = '';
            
            res.on('data', (chunk) => {
                data += chunk;
            });
            
            res.on('end', () => {
                try {
                    const documentTypes = [];
                    
                    // Extract document types using regex
                    const regex = /ServiceMetadataReference[^>]*href="([^"]*)"[^>]*>/g;
                    let match;
                    
                    while ((match = regex.exec(data)) !== null) {
                        const href = decodeURIComponent(match[1]);
                        if (href.includes('busdox-docid-qns::')) {
                            const docType = href.split('busdox-docid-qns::')[1].split('#')[0];
                            documentTypes.push(docType);
                        }
                    }
                    
                    resolve(documentTypes);
                    
                } catch (error) {
                    reject(new Error(`Failed to parse SMP response: ${error.message}`));
                }
            });
        }).on('error', (error) => {
            reject(new Error(`Failed to fetch SMP data: ${error.message}`));
        });
    });
}

async function main() {
    try {
        // Snapbooks AS (Norwegian organization number)
        const icd = '0192';
        const identifier = '921605900';
        
        // Step 1: Use SML to find where participant's metadata is hosted
        const smpHostname = await smlLookup(icd, identifier);
        if (!smpHostname) {
            console.log(`Not a PEPPOL participant: ${icd}:${identifier}`);
            return;
        }
        console.log(`SMP hostname: ${smpHostname}`);
        
        // Step 2: Query their SMP to discover supported documents
        const documentTypes = await smpLookup(smpHostname, icd, identifier);
        console.log('\nSupported document identifiers:');
        documentTypes.forEach(docType => {
            console.log(`- ${docType}`);
        });
        
        // Check for PEPPOL BIS Billing 3.0 documents
        console.log('\nPEPPOL BIS Billing 3.0 Support:');
        if (documentTypes.includes(BIS_BILLING_INVOICE)) {
            console.log('- Supports Invoice');
        }
        if (documentTypes.includes(BIS_BILLING_CREDITNOTE)) {
            console.log('- Supports Credit Note');
        }
        
    } catch (error) {
        console.error(`Error: ${error.message}`);
    }
}

main();
