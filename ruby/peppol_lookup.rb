#!/usr/bin/env ruby

# PEPPOL uses two key services to enable document exchange:
#
# 1. SML (Service Metadata Locator):
#    - Acts as a DNS-based directory service
#    - Maps a participant's ID to their SMP provider
#    - Uses DNS lookup to find where a participant's metadata is hosted
#    - Similar to how email's MX records help find mail servers
#
# 2. SMP (Service Metadata Publisher):
#    - Hosts metadata about a participant's capabilities
#    - Tells you what document types they can receive
#    - Provides technical details needed for sending documents
#    - Acts like a participant's business card in the network
#
# This example demonstrates how to:
# 1. Use SML to find where a participant's metadata is hosted
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

# Step 1: Use SML (Service Metadata Locator) to find a participant's SMP hostname
#
# The SML is like a phone book for the PEPPOL network. Given a participant's ID:
# 1. Create an MD5 hash of their ID (e.g., "0192:921605900")
# 2. Use the hash to construct a DNS hostname
# 3. If the hostname exists, the participant is registered in PEPPOL
# 4. The hostname tells us where to find their metadata (SMP)
#
# Returns the SMP hostname if found, nil if not found
def sml_lookup(icd, identifier, sml_domain = SML_DOMAIN)
  # Create MD5 hash of participant ID
  participant_id = "#{icd}:#{identifier}"
  md5_hash = Digest::MD5.hexdigest(participant_id)
  
  # Construct hostname
  hostname = "b-#{md5_hash}.iso6523-actorid-upis.#{sml_domain}"
  
  # Check if hostname exists
  begin
    Resolv.getaddress(hostname)
    hostname
  rescue Resolv::ResolvError
    nil
  end
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
def smp_lookup(smp_hostname, icd, identifier)
  # Construct SMP URL
  # Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
  participant_id = "#{icd}:#{identifier}"
  url = URI("http://#{smp_hostname}/iso6523-actorid-upis::#{URI.encode_www_form_component(participant_id)}")
  
  # Perform HTTP GET request
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
  
  # Step 1: Perform SML lookup to get SMP hostname
  smp_hostname = sml_lookup(icd, identifier)
  if smp_hostname.nil?
    puts "Not a PEPPOL participant: #{icd}:#{identifier}"
    exit 1
  end
  puts "SMP hostname: #{smp_hostname}"
  
  # Step 2: Get supported document identifiers
  document_types = smp_lookup(smp_hostname, icd, identifier)
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
