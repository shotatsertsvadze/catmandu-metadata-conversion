#!/usr/bin/env perl
# quality_checks.pl -- verify the generated MODS XML against the source CSV.
#
# Every number this script prints comes from actually reading both files;
# nothing here is asserted without comparing to the source data.
#
# Usage: quality_checks.pl <source.csv> <mods_collection.xml>

use strict;
use warnings;
use XML::LibXML;
use Text::CSV;

my ($csv_path, $xml_path) = @ARGV;
die "Usage: $0 <source.csv> <mods_collection.xml>\n" unless $csv_path && $xml_path;

my $MODS_NS = 'http://www.loc.gov/mods/v3';

# --- load source CSV rows, in file order -------------------------------
my $csv = Text::CSV->new({ binary => 1, auto_diag => 1 });
open my $fh, '<:encoding(UTF-8)', $csv_path or die "Cannot read $csv_path: $!";
my $header = $csv->getline($fh);
$csv->column_names(@$header);
my @rows;
while (my $row = $csv->getline_hr($fh)) {
    push @rows, $row;
}
close $fh;

# --- load generated XML, in document order -----------------------------
my $parser = XML::LibXML->new;
my $doc    = $parser->parse_file($xml_path);
my $xpc    = XML::LibXML::XPathContext->new($doc);
$xpc->registerNs('m', $MODS_NS);
my @mods_nodes = $xpc->findnodes('/m:modsCollection/m:mods');

my $failures = 0;
my $pass     = sub { print "PASS  $_[0]\n" };
my $fail     = sub { print "FAIL  $_[0]\n"; $failures++ };

# 1. record count parity
if (@rows == 1000 && @mods_nodes == 1000) {
    $pass->(sprintf("record count: %d source rows, %d <mods> elements", scalar(@rows), scalar(@mods_nodes)));
} else {
    $fail->(sprintf("record count mismatch: %d source rows, %d <mods> elements", scalar(@rows), scalar(@mods_nodes)));
}

my ($title_mismatches, $author_mismatches, $subject_mismatches) = (0, 0, 0);
my ($doi_mismatches, $licence_mismatches, $language_mismatches) = (0, 0, 0);
my ($issn_mismatches) = (0);

for my $i (0 .. $#rows) {
    my $row  = $rows[$i];
    my $node = $mods_nodes[$i];

    # 2. title preserved exactly
    my ($title_out) = $xpc->findnodes('m:titleInfo/m:title', $node);
    my $title_out_text = $title_out ? $title_out->textContent : '';
    $title_mismatches++ if $title_out_text ne trim($row->{Title});

    # 3. author count preserved (and thus no duplication/loss)
    my @authors_src = split /\|/, $row->{Authors};
    my @name_nodes  = $xpc->findnodes('m:name', $node);
    $author_mismatches++ if scalar(@name_nodes) != scalar(@authors_src);

    # 4. subject/topic count preserved (catches the duplicate-subject bug class)
    my @subjects_src = split /\|/, $row->{Subjects};
    my @subject_nodes = $xpc->findnodes('m:subject/m:topic', $node);
    $subject_mismatches++ if scalar(@subject_nodes) != scalar(@subjects_src);

    # 5. DOI: present and unchanged when source has one, absent when it doesn't
    my ($doi_node) = $xpc->findnodes("m:identifier[\@type='doi']", $node);
    my $doi_src = trim($row->{DOI});
    if (length $doi_src) {
        $doi_mismatches++ if !$doi_node || $doi_node->textContent ne $doi_src;
    } else {
        $doi_mismatches++ if $doi_node;
    }

    # 6. Licence: present and unchanged when source has one, absent when it doesn't
    my ($licence_node) = $xpc->findnodes('m:accessCondition', $node);
    my $licence_src = trim($row->{Licence});
    if (length $licence_src) {
        $licence_mismatches++ if !$licence_node || $licence_node->textContent ne $licence_src;
    } else {
        $licence_mismatches++ if $licence_node;
    }

    # 7. Language: present and unchanged when source has one, absent when it doesn't
    my ($lang_node) = $xpc->findnodes('m:language/m:languageTerm', $node);
    my $lang_src = trim($row->{Language_normalized});
    if (length $lang_src) {
        $language_mismatches++ if !$lang_node || $lang_node->textContent ne $lang_src;
    } else {
        $language_mismatches++ if $lang_node;
    }

    # 8. ISSN count preserved (including multi-ISSN records)
    my @issn_src   = split /\|/, $row->{ISSNs};
    my @issn_nodes = $xpc->findnodes("m:relatedItem/m:identifier[\@type='issn']", $node);
    $issn_mismatches++ if scalar(@issn_nodes) != scalar(@issn_src);
}

report_count('title text matches source', $title_mismatches, scalar @rows);
report_count('author count matches source (no duplication/loss)', $author_mismatches, scalar @rows);
report_count('subject/topic count matches source (no duplication/loss)', $subject_mismatches, scalar @rows);
report_count('DOI present/absent and unchanged correctly', $doi_mismatches, scalar @rows);
report_count('Licence present/absent and unchanged correctly', $licence_mismatches, scalar @rows);
report_count('Language present/absent and unchanged correctly', $language_mismatches, scalar @rows);
report_count('ISSN count matches source (incl. multi-ISSN records)', $issn_mismatches, scalar @rows);

# 9. Unicode fidelity: known accented strings from the source must appear
#    unescaped in the serialized XML.
my $xml_text = do {
    open my $xfh, '<:encoding(UTF-8)', $xml_path or die $!;
    local $/;
    <$xfh>;
};
my @unicode_samples =
    grep { /[^\x00-\x7F]/ }
    map { ($_->{Title}, split /\|/, $_->{Authors}) } @rows;
my $unicode_checked = 0;
my $unicode_failed  = 0;
for my $sample (@unicode_samples[0 .. (scalar(@unicode_samples) > 20 ? 19 : $#unicode_samples)]) {
    $unicode_checked++;
    $unicode_failed++ unless index($xml_text, $sample) >= 0;
}
report_count("Unicode strings preserved unescaped ($unicode_checked sampled)", $unicode_failed, $unicode_checked);

print "\n";
if ($failures) {
    print "RESULT: $failures check group(s) had mismatches -- see FAIL lines above.\n";
    exit 1;
} else {
    print "RESULT: all checks passed.\n";
    exit 0;
}

sub report_count {
    my ($label, $mismatches, $total) = @_;
    if ($mismatches == 0) {
        $pass->(sprintf("%s (%d/%d)", $label, $total, $total));
    } else {
        $fail->(sprintf("%s (%d/%d mismatched)", $label, $mismatches, $total));
    }
}

sub trim {
    my ($s) = @_;
    return '' unless defined $s;
    $s =~ s/^\s+|\s+$//g;
    return $s;
}
