#!/usr/bin/env ruby

# PEPPOL uses two key services to enable document exchange:
#
# 1. SML (Service Metadata Locator):
#    - Acts as a DNS-based directory service
#    - Maps a participant's ID to their SMP provider
#    - Uses NAPTR DNS records to find where a participant's metadata is hosted
#    - Similar to how email's MX records help find mail servers
#
# 2. SMP (Service Metadata Publisher):
#    - Hosts metadata about a participant's capabilities
#    - Tells you what document types they can receive
#    - Provides technical details needed for sending documents
#    - Acts like a participant's business card in the network
#
# This example demonstrates how to:
# 1. Use SML to find where a participant's metadata is hosted (via NAPTR DNS lookup)
# 2. Query their SMP to discover what documents they can receive
# 3. Check for PEPPOL BIS Billing 3.0 support

require 'digest'
require 'resolv'
require 'net/http'
require 'uri'

# Test environment SML domain
SML_DOMAIN = 'edelivery.tech.ec.europa.eu'

# PEPPOL BIS Billing 3.0 document identifiers
BIS_BILLING_INVOICE = 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice'
BIS_BILLING_CREDITNOTE = 'urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote'

# Base32 encode binary data (RFC 4648)
def base32_encode(data)
  alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
  result = ''
  bits = 0
  value = 0

  data.each_byte do |byte|
    value = (value << 8) | byte
    bits += 8
    while bits >= 5
      result << alphabet[(value >> (bits - 5)) & 31]
      bits -= 5
    end
  end

  result << alphabet[(value << (5 - bits)) & 31] if bits > 0
  result
end

# Step 1: Use SML (Service Metadata Locator) to find a participant's SMP URL
#
# The SML is like a phone book for the PEPPOL network. Given a participant's ID:
# 1. Create a SHA-256 hash of their lowercase ID (e.g., "0192:921605900")
# 2. Base32-encode the hash (lowercase, strip trailing '=')
# 3. Use the encoded hash to construct a DNS name
# 4. Perform a NAPTR DNS lookup to get the SMP URL
# 5. Extract the SMP URL from the NAPTR record's regexp field
#
# Returns the SMP URL if found, nil if not found
def sml_lookup(icd, identifier, sml_domain = SML_DOMAIN)
  # Create SHA-256 hash of lowercase participant ID
  participant_id = "#{icd}:#{identifier}".downcase
  sha256_hash = Digest::SHA256.digest(participant_id)

  # Base32 encode, strip trailing '=', lowercase
  b32 = base32_encode(sha256_hash).gsub(/=+$/, '').downcase

  # Construct DNS name
  dns_name = "#{b32}.iso6523-actorid-upis.#{sml_domain}"

  # Perform NAPTR DNS lookup
  Resolv::DNS.open do |dns|
    resources = dns.getresources(dns_name, Resolv::DNS::Resource::IN::NAPTR)
    resources.each do |record|
      if record.services == 'Meta:SMP' && record.flags.upcase == 'U'
        # Extract URL from NAPTR regexp field
        # Format: !pattern!replacement! (first char is delimiter)
        regexp = record.regexp
        delim = regexp[0]
        parts = regexp.split(delim)
        pattern = parts[1]
        replacement = parts[2]
        smp_url = dns_name.sub(Regexp.new(pattern), replacement)
        return smp_url
      end
    end
  end

  nil
rescue StandardError
  nil
end

# Step 2: Query SMP (Service Metadata Publisher) to get supported document types
#
# The SMP is like a business card in the PEPPOL network. It tells us:
# 1. What types of documents the participant can receive
# 2. Technical details needed for sending documents
# 3. Specific document format versions they support
#
# This is similar to how DNS MX records tell you where to send email,
# but SMP also includes what "types" of messages you can send.
def smp_lookup(smp_url, icd, identifier)
  # Ensure SMP URL ends with /
  smp_url = "#{smp_url}/" unless smp_url.end_with?('/')

  # Construct SMP URL
  # Format: {smp_url}/[identifier scheme]::[participant identifier]
  participant_id = "#{icd}:#{identifier}"
  url = URI("#{smp_url}iso6523-actorid-upis::#{URI.encode_www_form_component(participant_id)}")

  # Perform HTTPS GET request
  response = Net::HTTP.get(url)

  # Extract document types from ServiceMetadataReference href attributes
  document_types = []

  # Match ServiceMetadataReference href attributes
  response.scan(/ServiceMetadataReference[^>]*href="([^"]*)"[^>]*>/) do |match|
    href = URI.decode_www_form_component(match[0])
    if href.include?('busdox-docid-qns::')
      doc_type = href.split('busdox-docid-qns::')[1].split('#')[0]
      document_types << doc_type
    end
  end

  document_types
end

begin
  # Snapbooks AS (Norwegian organization number)
  icd = '0192'
  identifier = '921605900'

  # Step 1: Perform SML lookup to get SMP URL via NAPTR
  smp_url = sml_lookup(icd, identifier)
  if smp_url.nil?
    puts "Not a PEPPOL participant: #{icd}:#{identifier}"
    exit 1
  end
  puts "SMP URL: #{smp_url}"

  # Step 2: Get supported document identifiers
  document_types = smp_lookup(smp_url, icd, identifier)
  puts "\nSupported document identifiers:"
  document_types.each do |doc_type|
    puts "- #{doc_type}"
  end

  # Check for PEPPOL BIS Billing 3.0 documents
  puts "\nPEPPOL BIS Billing 3.0 Support:"
  puts "- Supports Invoice" if document_types.include?(BIS_BILLING_INVOICE)
  puts "- Supports Credit Note" if document_types.include?(BIS_BILLING_CREDITNOTE)

rescue StandardError => e
  warn "Error: #{e.message}"
  exit 1
end
