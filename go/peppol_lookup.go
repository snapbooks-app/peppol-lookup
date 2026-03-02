package main

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
*/

import (
	"crypto/sha256"
	"encoding/base32"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strings"

	"github.com/miekg/dns"
)

// Test environment SML domain
const smlDomain = "edelivery.tech.ec.europa.eu"

// PEPPOL BIS Billing 3.0 document identifiers
const (
	bisBillingInvoice    = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice"
	bisBillingCreditNote = "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote"
)

// smlLookup performs SML lookup using NAPTR DNS records
//
// The SML is like a phone book for the PEPPOL network. Given a participant's ID:
// 1. Create a SHA-256 hash of their lowercase ID (e.g., "0192:921605900")
// 2. Base32-encode the hash (lowercase, strip trailing '=')
// 3. Use the encoded hash to construct a DNS name
// 4. Perform a NAPTR DNS lookup to get the SMP URL
// 5. Extract the SMP URL from the NAPTR record's regexp field
//
// Returns the SMP URL if found, empty string if not found
func smlLookup(icd, identifier string) string {
	// Create SHA-256 hash of lowercase participant ID
	participantID := strings.ToLower(fmt.Sprintf("%s:%s", icd, identifier))
	hash := sha256.Sum256([]byte(participantID))

	// Base32 encode, strip trailing '=', lowercase
	b32 := strings.ToLower(strings.TrimRight(base32.StdEncoding.EncodeToString(hash[:]), "="))

	// Construct DNS name (with trailing dot for FQDN)
	dnsName := fmt.Sprintf("%s.iso6523-actorid-upis.%s", b32, smlDomain)
	fqdn := dnsName + "."

	// Perform NAPTR DNS lookup
	msg := new(dns.Msg)
	msg.SetQuestion(fqdn, dns.TypeNAPTR)

	// Try system resolver first, fall back to public DNS
	c := new(dns.Client)
	config, err := dns.ClientConfigFromFile("/etc/resolv.conf")
	dnsServer := "8.8.8.8:53"
	if err == nil && len(config.Servers) > 0 {
		dnsServer = config.Servers[0] + ":53"
	}

	resp, _, err := c.Exchange(msg, dnsServer)
	if err != nil {
		return ""
	}

	for _, answer := range resp.Answer {
		if naptr, ok := answer.(*dns.NAPTR); ok {
			if naptr.Service == "Meta:SMP" && strings.ToUpper(naptr.Flags) == "U" {
				// Extract URL from NAPTR regexp field
				// Format: !pattern!replacement! (first char is delimiter)
				naptrRegexp := naptr.Regexp
				if len(naptrRegexp) < 3 {
					continue
				}
				delim := string(naptrRegexp[0])
				parts := strings.SplitN(naptrRegexp, delim, 4)
				if len(parts) < 3 {
					continue
				}
				// replacement part contains the SMP URL
				return parts[2]
			}
		}
	}
	return ""
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
func smpLookup(smpURL, icd, identifier string) ([]string, error) {
	// Ensure SMP URL ends with /
	if !strings.HasSuffix(smpURL, "/") {
		smpURL += "/"
	}

	// Construct SMP URL
	// Format: {smp_url}/[identifier scheme]::[participant identifier]
	participantID := fmt.Sprintf("%s:%s", icd, identifier)
	urlStr := fmt.Sprintf("%siso6523-actorid-upis::%s",
		smpURL,
		url.QueryEscape(participantID))

	// Perform HTTPS GET request
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

	// Step 1: Use SML to find where participant's metadata is hosted (NAPTR lookup)
	smpURL := smlLookup(icd, identifier)
	if smpURL == "" {
		fmt.Printf("Not a PEPPOL participant: %s:%s\n", icd, identifier)
		os.Exit(1)
	}
	fmt.Printf("SMP URL: %s\n", smpURL)

	// Step 2: Query their SMP to discover supported documents
	documentTypes, err := smpLookup(smpURL, icd, identifier)
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
