#!/usr/bin/env perl

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

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);
use Socket;
use LWP::Simple qw(get);
use URI::Escape qw(uri_escape uri_unescape);

# Test environment SML domain
my $SML_DOMAIN = 'edelivery.tech.ec.europa.eu';

# PEPPOL BIS Billing 3.0 document identifiers
my $BIS_BILLING_INVOICE = 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice';
my $BIS_BILLING_CREDITNOTE = 'urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2::CreditNote';

# Step 1: Use SML (Service Metadata Locator) to find a participant's SMP hostname
#
# The SML is like a phone book for the PEPPOL network. Given a participant's ID:
# 1. Create an MD5 hash of their ID (e.g., "0192:921605900")
# 2. Use the hash to construct a DNS hostname
# 3. If the hostname exists, the participant is registered in PEPPOL
# 4. The hostname tells us where to find their metadata (SMP)
#
# Returns the SMP hostname if found, undef if not found
sub sml_lookup {
    my ($icd, $identifier, $sml_domain) = @_;
    $sml_domain //= $SML_DOMAIN;

    # Create MD5 hash of participant ID
    my $participant_id = "$icd:$identifier";
    my $md5_hash = md5_hex($participant_id);

    # Construct hostname
    my $hostname = "b-$md5_hash.iso6523-actorid-upis.$sml_domain";

    # Check if hostname exists
    my $packed_ip = gethostbyname($hostname);
    return $packed_ip ? $hostname : undef;
}

# Step 2: Query SMP (Service Metadata Publisher) to get supported document types
#
# The SMP is like a business card in the PEPPOL network. It tells us:
# 1. What types of documents the participant can receive
# 2. Technical details needed for sending documents
# 3. Specific document format versions they support
#
# This is similar to how DNS MX records tell you where to send email,
# but SMP also includes what "types" of messages you can send.
sub smp_lookup {
    my ($smp_hostname, $icd, $identifier) = @_;

    # Construct SMP URL
    # Format: http://[SMP hostname]/[identifier scheme]::[participant identifier]
    my $participant_id = "$icd:$identifier";
    my $encoded_id = uri_escape($participant_id);
    my $url = "http://$smp_hostname/iso6523-actorid-upis::$encoded_id";

    # Perform HTTP GET request
    my $response = get($url);
    die "Failed to fetch SMP data\n" unless defined $response;

    # Extract document types from ServiceMetadataReference href attributes
    my @document_types;

    # Match ServiceMetadataReference href attributes
    while ($response =~ /ServiceMetadataReference[^>]*href="([^"]*)"[^>]*>/g) {
        my $href = uri_unescape($1);
        if ($href =~ /busdox-docid-qns::([^#]+)/) {
            push @document_types, $1;
        }
    }

    return @document_types;
}

# Main execution
eval {
    # Snapbooks AS (Norwegian organization number)
    my $icd = '0192';
    my $identifier = '921605900';

    # Step 1: Use SML to find where participant's metadata is hosted
    my $smp_hostname = sml_lookup($icd, $identifier);
    unless ($smp_hostname) {
        print "Not a PEPPOL participant: $icd:$identifier\n";
        exit 1;
    }
    print "SMP hostname: $smp_hostname\n";

    # Step 2: Query their SMP to discover supported documents
    my @document_types = smp_lookup($smp_hostname, $icd, $identifier);
    print "\nSupported document identifiers:\n";
    foreach my $doc_type (@document_types) {
        print "- $doc_type\n";
    }

    # Check for PEPPOL BIS Billing 3.0 documents
    print "\nPEPPOL BIS Billing 3.0 Support:\n";
    if (grep { $_ eq $BIS_BILLING_INVOICE } @document_types) {
        print "- Supports Invoice\n";
    }
    if (grep { $_ eq $BIS_BILLING_CREDITNOTE } @document_types) {
        print "- Supports Credit Note\n";
    }
};

if ($@) {
    warn "Error: $@";
    exit 1;
}
