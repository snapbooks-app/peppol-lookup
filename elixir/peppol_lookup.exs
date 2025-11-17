#!/usr/bin/env elixir

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

defmodule PeppolLookup do
  # Test environment SML domain
  @sml_domain "edelivery.tech.ec.europa.eu"

  # PEPPOL BIS Billing 3.0 document identifiers
  @bis_billing_invoice "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice"
  @bis_billing_creditnote "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote"

  @doc """
  Step 1: Use SML (Service Metadata Locator) to find a participant's SMP hostname

  The SML is like a phone book for the PEPPOL network. Given a participant's ID:
  1. Create an MD5 hash of their ID (e.g., "0192:921605900")
  2. Use the hash to construct a DNS hostname
  3. If the hostname exists, the participant is registered in PEPPOL
  4. The hostname tells us where to find their metadata (SMP)

  Returns the SMP hostname if found, nil if not found
  """
  def sml_lookup(icd, identifier, sml_domain \\ @sml_domain) do
    # Create MD5 hash of participant ID
    participant_id = "#{icd}:#{identifier}"
    md5_hash = :crypto.hash(:md5, participant_id) |> Base.encode16(case: :lower)

    # Construct hostname
    hostname = "b-#{md5_hash}.iso6523-actorid-upis.#{sml_domain}"

    # Check if hostname exists
    case :inet_res.gethostbyname(String.to_charlist(hostname)) do
      {:ok, _} -> hostname
      {:error, _} -> nil
    end
  end

  @doc """
  Step 2: Query SMP (Service Metadata Publisher) to get supported document types

  The SMP is like a business card in the PEPPOL network. It tells us:
  1. What types of documents the participant can receive
  2. Technical details needed for sending documents
  3. Specific document format versions they support

  This is similar to how DNS MX records tell you where to send email,
  but SMP also includes what "types" of messages you can send.
  """
  def smp_lookup(smp_hostname, icd, identifier) do
    # Construct SMP URL
    # Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
    participant_id = "#{icd}:#{identifier}"
    encoded_id = URI.encode(participant_id)
    url = "http://#{smp_hostname}/iso6523-actorid-upis::#{encoded_id}"

    # Perform HTTP GET request
    :inets.start()
    :ssl.start()

    case :httpc.request(:get, {String.to_charlist(url), []}, [], []) do
      {:ok, {{_, 200, _}, _, body}} ->
        response = List.to_string(body)

        # Extract document types from ServiceMetadataReference href attributes
        regex = ~r/ServiceMetadataReference[^>]*href="([^"]*)"[^>]*>/

        Regex.scan(regex, response)
        |> Enum.map(fn [_, href] -> URI.decode(href) end)
        |> Enum.filter(fn href -> String.contains?(href, "busdox-docid-qns::") end)
        |> Enum.map(fn href ->
          [_, doc_type] = String.split(href, "busdox-docid-qns::", parts: 2)
          String.split(doc_type, "#") |> List.first()
        end)

      {:error, reason} ->
        raise "Failed to fetch SMP data: #{inspect(reason)}"
    end
  end

  def main do
    # Snapbooks AS (Norwegian organization number)
    icd = "0192"
    identifier = "921605900"

    # Step 1: Use SML to find where participant's metadata is hosted
    case sml_lookup(icd, identifier) do
      nil ->
        IO.puts("Not a PEPPOL participant: #{icd}:#{identifier}")
        System.halt(1)

      smp_hostname ->
        IO.puts("SMP hostname: #{smp_hostname}")

        # Step 2: Query their SMP to discover supported documents
        document_types = smp_lookup(smp_hostname, icd, identifier)
        IO.puts("\nSupported document identifiers:")
        Enum.each(document_types, fn doc_type -> IO.puts("- #{doc_type}") end)

        # Check for PEPPOL BIS Billing 3.0 documents
        IO.puts("\nPEPPOL BIS Billing 3.0 Support:")

        if @bis_billing_invoice in document_types do
          IO.puts("- Supports Invoice")
        end

        if @bis_billing_creditnote in document_types do
          IO.puts("- Supports Credit Note")
        end
    end
  rescue
    error ->
      IO.puts(:stderr, "Error: #{Exception.message(error)}")
      System.halt(1)
  end
end

PeppolLookup.main()
