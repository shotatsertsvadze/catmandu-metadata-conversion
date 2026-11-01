# Quality Report — DOAJ Bibliographic CSV to MODS 3.8 XML

All figures below are measured by `scripts/quality_checks.pl` and
`xmllint`, run against `data/input/bibliographic_metadata_cleaned.csv`
and `data/output/doaj_mods_collection.xml`. Reproduce with
`scripts/run_pipeline.sh`.

## Input / output record counts

| Stage | Records |
|---|---|
| Source CSV (`data/input/bibliographic_metadata_cleaned.csv`) | 1000 |
| Intermediate JSON (`data/intermediate/mods_records.json`) | 1000 |
| Final MODS XML collection (`data/output/doaj_mods_collection.xml`) | 1000 `<mods>` elements |

No records were dropped or added at any stage.

## Fields mapped

| Source column | MODS element | Notes |
|---|---|---|
| `Title` | `titleInfo/title` | — |
| `Authors` (pipe-separated) | `name[type=personal]/namePart` + `role/roleTerm[type=text,authority=marcrelator]` | one `<name>` per author |
| `DOI` | `identifier[type=doi]` | omitted when source DOI is empty (23 of 1000 records) |
| `Language_normalized` | `language/languageTerm[type=code,authority=iso639-1]` | omitted when empty (15 of 1000); source codes are ISO 639-1 two-letter (`en`, `es`, `fr`), stated as such rather than converted to ISO 639-2b |
| `Publisher` | `originInfo/agent[type=corporate]/namePart` + `role/roleTerm` | MODS 3.8 deprecates `<publisher>` in favour of `<agent>`; see Known limitations |
| `Date` | `originInfo/dateIssued` | preserved exactly as given, no `encoding` attribute added |
| `Subjects` (pipe-separated) | one `subject/topic` per term | no `authority` attribute added — terms are not asserted controlled vocabulary |
| `ISSNs` (pipe-separated, 41 of 1000 records have more than one) | `relatedItem[type=host]/identifier[type=issn]` (repeatable) | — |
| `URL` | `location/url[usage=primary]` | — |
| `Licence` | `accessCondition[type="use and reproduction"]` | source label preserved verbatim; omitted when empty (6 of 1000); no CC version/URL invented |

## Missing metadata (measured against all 1000 source rows)

| Field | Empty in source | Handling |
|---|---|---|
| `DOI` | 23 | `identifier` element omitted entirely |
| `Licence` | 6 | `accessCondition` element omitted entirely |
| `Language_normalized` | 15 | `language` element omitted entirely |
| `Title`, `Authors`, `URL`, `Date`, `Subjects`, `ISSNs`, `Publisher` | 0 | always present |

No empty or attribute-only placeholder elements are produced for the missing cases (verified: a defect of this exact shape was found and fixed during development — see Known limitations).

## Multivalued field handling

- **Authors**: split on `|`, one `<name>` per author. Verified author count per record matches source split count for 1000/1000 records.
- **Subjects**: split on `|`, one `<subject><topic>` per term. Verified topic count per record matches source split count for 1000/1000 records.
- **ISSNs**: split on `|` (41 records have more than one — print + electronic), one `<identifier type="issn">` per ISSN inside `relatedItem[type=host]`. Verified count match for 1000/1000 records.

## XML validation results

- Well-formedness (`xmllint --noout`): pass, both the 5-record sample and the full 1000-record collection.
- Schema validation against the official MODS 3.8 XSD (`reports/schema/mods-3-8.xsd`, retrieved from `https://www.loc.gov/standards/mods/mods-3-8.xsd`): **pass**, both files. Full log in `reports/validation_log.txt`.
- Record count: 1000/1000.
- Title text: 1000/1000 match source exactly.
- Author count per record: 1000/1000 match source.
- Subject/topic count per record: 1000/1000 match source.
- DOI present/absent and unchanged: 1000/1000 correct (23 correctly omitted, 977 correctly unchanged).
- Licence present/absent and unchanged: 1000/1000 correct (6 correctly omitted, 994 correctly unchanged).
- Language present/absent and unchanged: 1000/1000 correct (15 correctly omitted, 985 correctly unchanged).
- ISSN count per record (including the 41 multi-ISSN records): 1000/1000 correct.
- Unicode fidelity: 20 accented title/author strings sampled, 20/20 found unescaped and byte-correct in the output XML.

Schema validity and semantic quality are distinct: the above confirms the XML is both well-formed/schema-valid *and* faithful to the source data, not merely syntactically valid.

## Known quality limitations and unresolved ambiguities

- **Publisher as `<agent>`, not `<publisher>`**: MODS 3.8's own user guide states `<publisher>` "should not be used" from 3.8 onward in favour of `<agent>` with a `Publisher` role. `<publisher>` remains defined in the XSD for backward compatibility, so either choice would validate; this project uses `<agent>` as the current-practice form.
- **Date ambiguity preserved, not resolved**: source dates (e.g. `01/11/2015`) are copied verbatim with no `encoding` attribute, because the day/month convention used by the source is not stated and was not independently verified. A production system ingesting this data would need to confirm the convention with DOAJ before asserting ISO 8601 dates.
- **Language authority is ISO 639-1, not ISO 639-2b**: library MODS records conventionally use the three-letter ISO 639-2b codes; this project states the two-letter codes actually present in the source (`authority="iso639-1"`) rather than converting them through an unverified lookup table.
- **Subjects are not asserted as controlled vocabulary**: the source `Subjects` column mixes free text and what appear to be classification-like codes (e.g. `QC1-999`); no `authority` attribute (e.g. `lcsh`, `fast`) is added, since the actual scheme was not verified.
- **ISSN host item has no journal title**: `relatedItem[type=host]` contains only the ISSN(s); the source has no clean, separate journal-title field (only the free-text `Citation` column), and parsing a title out of that string was judged too unreliable to assert as structured metadata.
- **DOI duplicates**: of the 977 non-empty DOIs, all are distinct (no duplicate DOIs across records).

## Reproducibility

The full pipeline — CSV → Fix mapping → JSON → MODS XML → schema validation → quality checks — is driven by `scripts/run_pipeline.sh` and requires no manual steps beyond the one-time Homebrew Perl + Catmandu setup documented in `README.md`. Re-running it from a clean checkout reproduces the same record counts and validation result.
