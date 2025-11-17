#!/usr/bin/env lua

--[[
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
]]

local socket = require("socket")
local http = require("socket.http")
local url = require("socket.url")

-- Test environment SML domain
local SML_DOMAIN = "edelivery.tech.ec.europa.eu"

-- PEPPOL BIS Billing 3.0 document identifiers
local BIS_BILLING_INVOICE = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice"
local BIS_BILLING_CREDITNOTE = "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote"

-- Helper function to compute MD5 hash
local function md5(str)
    -- Use openssl command for MD5 hashing as Lua doesn't have built-in crypto
    local handle = io.popen("echo -n '" .. str .. "' | md5sum | cut -d' ' -f1")
    local result = handle:read("*a")
    handle:close()
    return result:gsub("%s+", "")
end

-- Helper function to URL encode
local function url_encode(str)
    return url.escape(str)
end

-- Helper function to URL decode
local function url_decode(str)
    return url.unescape(str)
end

--[[
Step 1: Use SML (Service Metadata Locator) to find a participant's SMP hostname

The SML is like a phone book for the PEPPOL network. Given a participant's ID:
1. Create an MD5 hash of their ID (e.g., "0192:921605900")
2. Use the hash to construct a DNS hostname
3. If the hostname exists, the participant is registered in PEPPOL
4. The hostname tells us where to find their metadata (SMP)

Returns the SMP hostname if found, nil if not found
]]
local function sml_lookup(icd, identifier, sml_domain)
    sml_domain = sml_domain or SML_DOMAIN

    -- Create MD5 hash of participant ID
    local participant_id = icd .. ":" .. identifier
    local md5_hash = md5(participant_id)

    -- Construct hostname
    local hostname = "b-" .. md5_hash .. ".iso6523-actorid-upis." .. sml_domain

    -- Check if hostname exists
    local ip = socket.dns.toip(hostname)
    if ip then
        return hostname
    else
        return nil
    end
end

--[[
Step 2: Query SMP (Service Metadata Publisher) to get supported document types

The SMP is like a business card in the PEPPOL network. It tells us:
1. What types of documents the participant can receive
2. Technical details needed for sending documents
3. Specific document format versions they support

This is similar to how DNS MX records tell you where to send email,
but SMP also includes what "types" of messages you can send.
]]
local function smp_lookup(smp_hostname, icd, identifier)
    -- Construct SMP URL
    -- Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
    local participant_id = icd .. ":" .. identifier
    local encoded_id = url_encode(participant_id)
    local request_url = "http://" .. smp_hostname .. "/iso6523-actorid-upis::" .. encoded_id

    -- Perform HTTP GET request
    local response, status = http.request(request_url)
    if not response then
        error("Failed to fetch SMP data: " .. tostring(status))
    end

    -- Extract document types from ServiceMetadataReference href attributes
    local document_types = {}

    -- Match ServiceMetadataReference href attributes
    for href in response:gmatch('ServiceMetadataReference[^>]*href="([^"]*)"[^>]*>') do
        local decoded_href = url_decode(href)
        local doc_type = decoded_href:match("busdox%-docid%-qns::([^#]+)")
        if doc_type then
            table.insert(document_types, doc_type)
        end
    end

    return document_types
end

-- Main execution
local function main()
    -- Snapbooks AS (Norwegian organization number)
    local icd = "0192"
    local identifier = "921605900"

    -- Step 1: Use SML to find where participant's metadata is hosted
    local smp_hostname = sml_lookup(icd, identifier)
    if not smp_hostname then
        print("Not a PEPPOL participant: " .. icd .. ":" .. identifier)
        os.exit(1)
    end
    print("SMP hostname: " .. smp_hostname)

    -- Step 2: Query their SMP to discover supported documents
    local document_types = smp_lookup(smp_hostname, icd, identifier)
    print("\nSupported document identifiers:")
    for _, doc_type in ipairs(document_types) do
        print("- " .. doc_type)
    end

    -- Check for PEPPOL BIS Billing 3.0 documents
    print("\nPEPPOL BIS Billing 3.0 Support:")
    for _, doc_type in ipairs(document_types) do
        if doc_type == BIS_BILLING_INVOICE then
            print("- Supports Invoice")
        end
        if doc_type == BIS_BILLING_CREDITNOTE then
            print("- Supports Credit Note")
        end
    end
end

-- Run main with error handling
local status, err = pcall(main)
if not status then
    io.stderr:write("Error: " .. tostring(err) .. "\n")
    os.exit(1)
end
