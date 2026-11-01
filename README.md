# Catmandu Metadata Conversion: DOAJ to MODS 3.8 XML

A library-metadata project: 1,000 cleaned journal article records from the
Directory of Open Access Journals (DOAJ) are mapped to the Library of
Congress's [MODS 3.8](https://www.loc.gov/standards/mods/) schema using
[Catmandu](https://librecat.org/Catmandu/) Fix scripts, serialized to
namespaced MODS XML, and validated against the official XSD.

Portfolio Project 03. It builds on Project 01,
[Bibliographic Metadata Quality Improvement with OpenRefine](https://github.com/shotatsertsvadze/bibliographic-metadata-quality),
and Project 02,
[From DOAJ to Dublin Core: Bibliographic Metadata Mapping](https://github.com/shotatsertsvadze/doaj-dublin-core-mapping),
which produced and first mapped the input dataset.

German summary: [README_DE.md](README_DE.md)

| | Result |
| --- | --- |
| Records | 1,000 in, 1,000 `<mods>` out |
| Schema validation | passes against the official MODS 3.8 XSD (both the full collection and the 5-record sample) |
| Title / author count / subject count fidelity | 1,000 / 1,000 / 1,000 match source exactly |
| DOI / Licence / Language presence | correctly present or correctly omitted for all 1,000 (23 / 6 / 15 missing in source, never invented) |
| ISSN handling | 41 multi-ISSN records correctly expanded to multiple `identifier` elements |
| Unicode fidelity | 20 accented sample strings, 20/20 preserved unescaped |
| Full report | [reports/quality_report.md](reports/quality_report.md) |

## 1. Why this project

Catmandu is a toolkit libraries actually use to move bibliographic data
between formats (CSV, MARC, OAI, MODS, Dublin Core, ...) without hand-writing
a parser for each one. The Fix language lets you describe a field mapping
declaratively; the same script can run on the command line, in a batch job,
or embedded in a larger pipeline. This project uses it for the most common
real task such a pipeline faces: converting flat, CSV-shaped bibliographic
records into a standards-compliant, schema-validated XML format that other
library systems can actually ingest.

## 2. Architecture

```
data/input/bibliographic_metadata_cleaned.csv
        |  fix/mods_mapping.fix   (Catmandu Fix: all field mapping/splitting/trimming)
        v
data/intermediate/mods_records.json   (MODS-shaped JSON, one object per record)
        |  scripts/json_to_mods_xml.pl   (thin XML::LibXML serializer, no data logic)
        v
data/output/doaj_mods_collection.xml   (MODS 3.8, namespace http://www.loc.gov/mods/v3)
        |  xmllint --schema reports/schema/mods-3-8.xsd
        v
reports/validation_log.txt + reports/quality_checks_log.txt
```

**Catmandu does the transformation; the Perl script only serializes.**
`Catmandu::Exporter::XML` was evaluated for the last step and not used
directly: it serializes via `XML::Struct::Writer::Stream`, which writes a
generic `[ element, {attrs}, [children] ]` array shape rather than
understanding MODS's namespace, attribute, and element-choice rules. Building
that array by hand inside the Fix script would not have been meaningfully
different from writing a small serializer, so the responsibilities are kept
explicit instead: Catmandu produces an already-mapped, MODS-shaped structure,
and `scripts/json_to_mods_xml.pl` turns it into XML syntax using one fixed,
documented convention (a hash with a `value` key becomes element text plus
attributes from `{type, authority, authorityURI, valueURI, usage}`; anything
else becomes child elements) — no field-specific logic lives in that script.

## 3. Field mapping

| Source column | MODS element | Notes |
|---|---|---|
| `Title` | `titleInfo/title` | — |
| `Authors` (`\|`-separated) | `name[type=personal]/namePart` + `role/roleTerm[type=text, authority=marcrelator]` | one `<name>` per author |
| `DOI` | `identifier[type=doi]` | omitted when empty (23/1000) |
| `Language_normalized` | `language/languageTerm[type=code, authority=iso639-1]` | omitted when empty (15/1000); codes are ISO 639-1, stated as such |
| `Publisher` | `originInfo/agent[type=corporate]/namePart` + `role/roleTerm` | MODS 3.8 deprecates `<publisher>` in favour of `<agent>` |
| `Date` | `originInfo/dateIssued` | preserved exactly as given, no date convention asserted |
| `Subjects` (`\|`-separated) | one `subject/topic` per term | no controlled-vocabulary `authority` asserted |
| `ISSNs` (`\|`-separated, 41 records have more than one) | `relatedItem[type=host]/identifier[type=issn]` (repeatable) | — |
| `URL` | `location/url[usage=primary]` | — |
| `Licence` | `accessCondition[type="use and reproduction"]` | source label preserved verbatim; omitted when empty (6/1000) |

Every judgment call above — and why it was made that way — is in
[reports/quality_report.md](reports/quality_report.md).

## 4. Repository layout

```
fix/
  01_learning_title_trim.fix   the first hands-on Fix script (copy + trim a title) -- a learning artifact, kept as written
  mods_mapping.fix             the production Fix script used by the pipeline
data/input/                    source CSV (1,000 records)
data/intermediate/             Catmandu's JSON output (regenerated by the pipeline; not committed if large)
data/output/                   the validated MODS XML collection
samples/                       a 5-record MODS XML sample for quick human reading
scripts/
  json_to_mods_xml.pl           JSON -> MODS XML serializer
  quality_checks.pl             cross-checks the XML against the source CSV
  run_pipeline.sh               runs the full pipeline end to end
reports/
  schema/                       the official MODS 3.8 XSD (vendored for reproducibility)
  validation_log.txt            xmllint --schema output
  quality_checks_log.txt        quality_checks.pl output
  quality_report.md             full write-up of the above
```

## 5. Reproduce it (macOS)

Apple's system Perl (`/usr/bin/perl`) cannot build Catmandu's XS
dependencies: it is compiled with the macOS hardened runtime, which refuses
to load a relative-path shared library — exactly how Perl's own test harness
loads a freshly built XS module (`XS::Parse::Keyword`, a Catmandu dependency).
This project therefore uses Homebrew's own Perl, kept isolated with
`local::lib`, and never touches the system Perl at all.

```bash
# one-time setup
brew install perl cpanminus
cpanm -l ~/perl5-brew local::lib
eval "$(perl -I ~/perl5-brew/lib/perl5 -Mlocal::lib=~/perl5-brew)"
cpanm Catmandu Catmandu::XML

# run the pipeline
git clone https://github.com/shotatsertsvadze/catmandu-metadata-conversion.git
cd catmandu-metadata-conversion
./scripts/run_pipeline.sh
```

`run_pipeline.sh` regenerates `data/intermediate/mods_records.json`,
`data/output/doaj_mods_collection.xml`, `samples/sample_mods_records.xml`,
and both report logs, and exits non-zero if any check fails.

## 6. Transparency

**What I (Shota) did by hand:** learned Catmandu's Fix language and wrote
the first working example (`fix/01_learning_title_trim.fix`, a single
`copy_field` + `trim`), ran it against the real dataset, and inspected the
YAML output to confirm it worked, with guidance.

**What was done with AI assistance (Claude):** extending that script into
the full production mapping (`fix/mods_mapping.fix`) covering all ten
source columns; researching the MODS 3.8 user guide and XSD to resolve the
mapping decisions in section 3; writing the XML serializer, the quality-check
script, the schema validation, this documentation, and publishing the
repository.

## 7. Related projects

- Project 01: [Bibliographic Metadata Quality Improvement with OpenRefine](https://github.com/shotatsertsvadze/bibliographic-metadata-quality)
- Project 02: [From DOAJ to Dublin Core: Bibliographic Metadata Mapping](https://github.com/shotatsertsvadze/doaj-dublin-core-mapping)

## License

Code and documentation: MIT. The source dataset and the vendored MODS XSD
are third-party and carry their own licences — see [LICENSE](LICENSE) for
the full chain of attribution.
