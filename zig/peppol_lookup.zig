// PEPPOL uses two key services to enable document exchange:
//
// 1. SML (Service Metadata Locator):
//    - Acts as a DNS-based directory service
//    - Maps a participant's ID to their SMP provider
//    - Uses DNS lookup to find where a participant's metadata is hosted
//    - Similar to how email's MX records help find mail servers
//
// 2. SMP (Service Metadata Publisher):
//    - Hosts metadata about a participant's capabilities
//    - Tells you what document types they can receive
//    - Provides technical details needed for sending documents
//    - Acts like a participant's business card in the network
//
// This example demonstrates how to:
// 1. Use SML to find where a participant's metadata is hosted
// 2. Query their SMP to discover what documents they can receive
// 3. Check for PEPPOL BIS Billing 3.0 support

const std = @import("std");
const net = std.net;
const crypto = std.crypto;
const http = std.http;
const mem = std.mem;
const fmt = std.fmt;

// Test environment SML domain
const SML_DOMAIN = "edelivery.tech.ec.europa.eu";

// PEPPOL BIS Billing 3.0 document identifiers
const BIS_BILLING_INVOICE = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice";
const BIS_BILLING_CREDITNOTE = "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote";

// Helper function to compute MD5 hash
fn computeMd5(allocator: mem.Allocator, input: []const u8) ![]u8 {
    var hash: [16]u8 = undefined;
    crypto.hash.Md5.hash(input, &hash, .{});

    var result = try allocator.alloc(u8, 32);
    _ = try fmt.bufPrint(result, "{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}", .{
        hash[0], hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7],
        hash[8], hash[9], hash[10], hash[11], hash[12], hash[13], hash[14], hash[15],
    });

    return result;
}

// Step 1: Use SML (Service Metadata Locator) to find a participant's SMP hostname
//
// The SML is like a phone book for the PEPPOL network. Given a participant's ID:
// 1. Create an MD5 hash of their ID (e.g., "0192:921605900")
// 2. Use the hash to construct a DNS hostname
// 3. If the hostname exists, the participant is registered in PEPPOL
// 4. The hostname tells us where to find their metadata (SMP)
//
// Returns the SMP hostname if found, null if not found
fn smlLookup(allocator: mem.Allocator, icd: []const u8, identifier: []const u8) !?[]u8 {
    // Create MD5 hash of participant ID
    const participant_id = try fmt.allocPrint(allocator, "{s}:{s}", .{ icd, identifier });
    defer allocator.free(participant_id);

    const md5_hash = try computeMd5(allocator, participant_id);
    defer allocator.free(md5_hash);

    // Construct hostname
    const hostname = try fmt.allocPrint(allocator, "b-{s}.iso6523-actorid-upis.{s}", .{ md5_hash, SML_DOMAIN });

    // Check if hostname exists
    const list = net.getAddressList(allocator, hostname, 80) catch {
        allocator.free(hostname);
        return null;
    };
    defer list.deinit();

    if (list.addrs.len > 0) {
        return hostname;
    } else {
        allocator.free(hostname);
        return null;
    }
}

// Step 2: Query SMP (Service Metadata Publisher) to get supported document types
//
// The SMP is like a business card in the PEPPOL network. It tells us:
// 1. What types of documents the participant can receive
// 2. Technical details needed for sending documents
// 3. Specific document format versions they support
//
// This is similar to how DNS MX records tell you where to send email,
// but SMP also includes what "types" of messages you can send.
fn smpLookup(allocator: mem.Allocator, smp_hostname: []const u8, icd: []const u8, identifier: []const u8) !std.ArrayList([]const u8) {
    // Construct SMP URL
    const participant_id = try fmt.allocPrint(allocator, "{s}:{s}", .{ icd, identifier });
    defer allocator.free(participant_id);

    // Simple URL encoding (for production use a proper URL encoder)
    const encoded_id = try fmt.allocPrint(allocator, "{s}", .{participant_id}); // Simplified
    defer allocator.free(encoded_id);

    const uri_str = try fmt.allocPrint(allocator, "http://{s}/iso6523-actorid-upis::{s}", .{ smp_hostname, encoded_id });
    defer allocator.free(uri_str);

    const uri = try std.Uri.parse(uri_str);

    // Perform HTTP GET request
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    var response = std.ArrayList(u8).init(allocator);
    defer response.deinit();

    const result = try client.fetch(.{
        .location = .{ .uri = uri },
        .response_storage = .{ .dynamic = &response },
    });

    if (result.status != .ok) {
        return error.HttpRequestFailed;
    }

    // Extract document types from ServiceMetadataReference href attributes
    var document_types = std.ArrayList([]const u8).init(allocator);

    // Simple string searching (for production use proper XML/regex parsing)
    const body = response.items;
    var i: usize = 0;
    while (mem.indexOf(u8, body[i..], "busdox-docid-qns::")) |pos| {
        const start = i + pos + 18; // length of "busdox-docid-qns::"
        if (mem.indexOf(u8, body[start..], "#")) |end_pos| {
            const doc_type = try allocator.dupe(u8, body[start .. start + end_pos]);
            try document_types.append(doc_type);
            i = start + end_pos;
        } else {
            break;
        }
    }

    return document_types;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    // Snapbooks AS (Norwegian organization number)
    const icd = "0192";
    const identifier = "921605900";

    // Step 1: Use SML to find where participant's metadata is hosted
    const smp_hostname = smlLookup(allocator, icd, identifier) catch |err| {
        try stderr.print("Error during SML lookup: {}\n", .{err});
        std.process.exit(1);
    };

    if (smp_hostname) |hostname| {
        defer allocator.free(hostname);
        try stdout.print("SMP hostname: {s}\n", .{hostname});

        // Step 2: Query their SMP to discover supported documents
        var document_types = smpLookup(allocator, hostname, icd, identifier) catch |err| {
            try stderr.print("Error during SMP lookup: {}\n", .{err});
            std.process.exit(1);
        };
        defer {
            for (document_types.items) |doc_type| {
                allocator.free(doc_type);
            }
            document_types.deinit();
        }

        try stdout.print("\nSupported document identifiers:\n", .{});
        for (document_types.items) |doc_type| {
            try stdout.print("- {s}\n", .{doc_type});
        }

        // Check for PEPPOL BIS Billing 3.0 documents
        try stdout.print("\nPEPPOL BIS Billing 3.0 Support:\n", .{});
        for (document_types.items) |doc_type| {
            if (mem.eql(u8, doc_type, BIS_BILLING_INVOICE)) {
                try stdout.print("- Supports Invoice\n", .{});
            }
            if (mem.eql(u8, doc_type, BIS_BILLING_CREDITNOTE)) {
                try stdout.print("- Supports Credit Note\n", .{});
            }
        }
    } else {
        try stdout.print("Not a PEPPOL participant: {s}:{s}\n", .{ icd, identifier });
        std.process.exit(1);
    }
}
