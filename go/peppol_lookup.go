package main

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

import (
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strings"
)

// Test environment SML domain
const smlDomain = "edelivery.tech.ec.europa.eu"

// PEPPOL BIS Billing 3.0 document identifiers
const (
	bisBillingInvoice    = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice"
	bisBillingCreditNote = "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote"
)

// smlLookup performs SML lookup using DNS lookup
//
// The SML is like a phone book for the PEPPOL network. Given a participant's ID:
// 1. Create an MD5 hash of their ID (e.g., "0192:921605900")
// 2. Use the hash to construct a DNS hostname
// 3. If the hostname exists, the participant is registered in PEPPOL
// 4. The hostname tells us where to find their metadata (SMP)
//
// Returns the SMP hostname if found, empty string if not found
func smlLookup(icd, identifier string) string {
	// Create MD5 hash of participant ID
	participantID := fmt.Sprintf("%s:%s", icd, identifier)
	hash := md5.Sum([]byte(participantID))
	md5Hash := hex.EncodeToString(hash[:])

	// Construct hostname
	hostname := fmt.Sprintf("b-%s.iso6523-actorid-upis.%s", md5Hash, smlDomain)

	// Check if hostname exists
	_, err := net.LookupHost(hostname)
	if err != nil {
		return ""
	}
	return hostname
}

// smpLookup gets supported document identifiers from SMP
//
// The SMP is like a business card in the PEPPOL network. It tells us:
// 1. What types of documents the participant can receive
// 2. Technical details needed for sending documents
// 3. Specific document format versions they support
//
// This is similar to how DNS MX records tell you where to send email,
// but SMP also includes what "types" of messages you can send.
func smpLookup(smpHostname, icd, identifier string) ([]string, error) {
	// Construct SMP URL
	// Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
	participantID := fmt.Sprintf("%s:%s", icd, identifier)
	urlStr := fmt.Sprintf("http://%s/iso6523-actorid-upis::%s",
		smpHostname,
		url.QueryEscape(participantID))

	// Perform HTTP GET request
	resp, err := http.Get(urlStr)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch SMP data: %v", err)
	}
	defer resp.Body.Close()

	// Read response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %v", err)
	}

	// Extract document types from ServiceMetadataReference href attributes
	documentTypes := make([]string, 0)

	// Match ServiceMetadataReference href attributes
	re := regexp.MustCompile(`ServiceMetadataReference[^>]*href="([^"]*)"[^>]*>`)
	matches := re.FindAllStringSubmatch(string(body), -1)

	for _, match := range matches {
		href, err := url.QueryUnescape(match[1])
		if err != nil {
			continue
		}
		if strings.Contains(href, "busdox-docid-qns::") {
			parts := strings.Split(href, "busdox-docid-qns::")[1]
			docType := strings.Split(parts, "#")[0]
			documentTypes = append(documentTypes, docType)
		}
	}

	return documentTypes, nil
}

func main() {
	// Snapbooks AS (Norwegian organization number)
	icd := "0192"
	identifier := "921605900"

	// Step 1: Use SML to find where participant's metadata is hosted
	smpHostname := smlLookup(icd, identifier)
	if smpHostname == "" {
		fmt.Printf("Not a PEPPOL participant: %s:%s\n", icd, identifier)
		os.Exit(1)
	}
	fmt.Printf("SMP hostname: %s\n", smpHostname)

	// Step 2: Query their SMP to discover supported documents
	documentTypes, err := smpLookup(smpHostname, icd, identifier)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("\nSupported document identifiers:")
	for _, docType := range documentTypes {
		fmt.Printf("- %s\n", docType)
	}

	// Check for PEPPOL BIS Billing 3.0 documents
	fmt.Println("\nPEPPOL BIS Billing 3.0 Support:")
	for _, docType := range documentTypes {
		switch docType {
		case bisBillingInvoice:
			fmt.Println("- Supports Invoice")
		case bisBillingCreditNote:
			fmt.Println("- Supports Credit Note")
		}
	}
}
