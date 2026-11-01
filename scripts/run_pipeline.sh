#!/usr/bin/env bash
# run_pipeline.sh -- reproduce the full CSV -> MODS 3.8 XML pipeline.
#
# Requires Catmandu + Catmandu::XML installed under the local::lib
# described in README.md (Homebrew Perl, not macOS system Perl).
set -euo pipefail

cd "$(dirname "$0")/.."

PERL5_LOCAL_LIB="${PERL5_LOCAL_LIB:-$HOME/perl5-brew}"
eval "$(perl -I "$PERL5_LOCAL_LIB/lib/perl5" -Mlocal::lib="$PERL5_LOCAL_LIB")"

mkdir -p data/intermediate data/output samples reports

echo "==> 1/4 Catmandu Fix: CSV -> intermediate JSON"
catmandu convert CSV --fix fix/mods_mapping.fix to JSON \
    < data/input/bibliographic_metadata_cleaned.csv \
    > data/intermediate/mods_records.json

echo "==> 2/4 Serialize: JSON -> MODS XML (sample + full collection)"
perl scripts/json_to_mods_xml.pl data/intermediate/mods_records.json samples/sample_mods_records.xml --limit 5
perl scripts/json_to_mods_xml.pl data/intermediate/mods_records.json data/output/doaj_mods_collection.xml

echo "==> 3/4 Validate against the official MODS 3.8 XSD"
xmllint --noout samples/sample_mods_records.xml
xmllint --noout data/output/doaj_mods_collection.xml
xmllint --schema reports/schema/mods-3-8.xsd --noout data/output/doaj_mods_collection.xml 2>&1 | tee reports/validation_log.txt

echo "==> 4/4 Quality checks against the source CSV"
perl scripts/quality_checks.pl data/input/bibliographic_metadata_cleaned.csv data/output/doaj_mods_collection.xml | tee reports/quality_checks_log.txt

echo "==> Done."
