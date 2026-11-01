#!/usr/bin/env perl
# json_to_mods_xml.pl -- serialize Catmandu's MODS-shaped JSON into MODS 3.8 XML.
#
# This is the "small serialization layer" referenced in the project README:
# all field mapping/transformation already happened in fix/mods_mapping.fix.
# This script only turns that already-mapped structure into namespaced XML,
# using the key convention the Fix script writes:
#   - a hash with a "value" key: element text content, plus the remaining
#     keys among (type, authority, authorityURI, valueURI, usage) as
#     XML attributes;
#   - a hash without "value": a scalar or hash of child elements;
#   - any other hash key: a child element (singular) or, if its value is
#     an array, one repeated child element per array item;
#   - a plain scalar: element text content, no attributes.
#
# Usage:
#   json_to_mods_xml.pl <input.json> <output.xml> [--limit N]

use strict;
use warnings;
use JSON::PP qw(decode_json);
use XML::LibXML;

my ($input_path, $output_path, @rest) = @ARGV;
die "Usage: $0 <input.json> <output.xml> [--limit N]\n"
    unless $input_path && $output_path;

my $limit;
for (my $i = 0; $i <= $#rest; $i++) {
    if ($rest[$i] eq '--limit' && defined $rest[$i + 1]) {
        $limit = $rest[$i + 1];
    }
}

my $MODS_NS = 'http://www.loc.gov/mods/v3';
my %ATTRIBUTE_KEYS = map { $_ => 1 } qw(type authority authorityURI valueURI usage);

# Read raw UTF-8 bytes; decode_json decodes them itself. XML::LibXML's
# toString(1) below likewise returns raw UTF-8 bytes, so no filehandle
# :encoding layer is used on either side -- that would double-decode/encode.
open my $fh, '<', $input_path or die "Cannot read $input_path: $!";
binmode $fh;
local $/;
my $records = decode_json(<$fh>);
close $fh;

if (defined $limit) {
    $records = [ @{$records}[0 .. $limit - 1] ];
}

my $doc = XML::LibXML::Document->new('1.0');
$doc->setEncoding('UTF-8');

my $collection = $doc->createElementNS($MODS_NS, 'modsCollection');
$doc->setDocumentElement($collection);

for my $record (@$records) {
    my $mods_elem = build_element($doc, 'mods', $record->{mods});
    $mods_elem->setAttribute('version', '3.8');
    $collection->appendChild($mods_elem);
}

open my $out, '>', $output_path or die "Cannot write $output_path: $!";
binmode $out;
print {$out} $doc->toString(1);
close $out;

print "Wrote ", scalar(@$records), " <mods> record(s) to $output_path\n";

# Recursively build one XML::LibXML::Element named $name from a Fix-mapped
# node ($node is a hashref, arrayref element already unwrapped by the caller,
# or a plain scalar).
sub build_element {
    my ($doc, $name, $node) = @_;
    my $elem = $doc->createElementNS($MODS_NS, $name);

    if (ref $node eq 'HASH') {
        for my $key (sort keys %$node) {
            my $val = $node->{$key};
            if ($ATTRIBUTE_KEYS{$key}) {
                $elem->setAttribute($key, $val);
            }
            elsif ($key eq 'value') {
                $elem->appendText($val);
            }
            elsif (ref $val eq 'ARRAY') {
                $elem->appendChild(build_element($doc, $key, $_)) for @$val;
            }
            else {
                $elem->appendChild(build_element($doc, $key, $val));
            }
        }
    }
    elsif (ref $node eq 'ARRAY') {
        die "Unexpected bare array under element '$name'";
    }
    else {
        $elem->appendText($node) if defined $node && length $node;
    }

    return $elem;
}
