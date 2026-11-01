# Catmandu-Metadatenkonvertierung: DOAJ zu MODS 3.8 XML

Ein Projekt zur bibliografischen Metadatenkonvertierung: 1.000 bereinigte
Zeitschriftenartikel aus dem Directory of Open Access Journals (DOAJ) werden
mit [Catmandu](https://librecat.org/Catmandu/)-Fix-Skripten auf das
MODS-3.8-Schema der Library of Congress abgebildet, als XML serialisiert und
gegen das offizielle XSD-Schema validiert.

Portfolio-Projekt 03. Grundlage ist der Datensatz aus Projekt 01,
[Bibliographic Metadata Quality Improvement with OpenRefine](https://github.com/shotatsertsvadze/bibliographic-metadata-quality),
und Projekt 02,
[From DOAJ to Dublin Core: Bibliographic Metadata Mapping](https://github.com/shotatsertsvadze/doaj-dublin-core-mapping).

Ausführliche englische Fassung: [README.md](README.md)

## Durchgeführte Arbeiten

**Catmandu Fix (manuell, mit Anleitung).** Erstes eigenständiges Fix-Skript
(`fix/01_learning_title_trim.fix`): Titel kopieren und trimmen, am echten
Datensatz getestet und per YAML-Ausgabe kontrolliert.

**Produktions-Mapping und XML-Serialisierung (KI-unterstützt).** Das
Lern-Skript wurde zu `fix/mods_mapping.fix` erweitert, das alle zehn
Quellspalten auf MODS-3.8-Elemente abbildet (Titel, Autor:innen mit Rolle,
DOI, Sprache, Verlag als `<agent>`, Datum unverändert, Schlagwörter, ISSN als
`relatedItem`, URL, Lizenz als `accessCondition`). Ein schlankes
Perl-Skript (`scripts/json_to_mods_xml.pl`) serialisiert die bereits
abgebildete Struktur als Namespace-korrektes MODS-XML; die inhaltliche
Abbildung bleibt vollständig Aufgabe von Catmandu.

## Ergebnis

| | Wert |
| --- | --- |
| Datensätze | 1.000 ein, 1.000 `<mods>`-Elemente aus |
| Schema-Validierung | bestanden, offizielles MODS-3.8-XSD |
| Titel- / Autor:innen- / Schlagwort-Treue | 1.000 / 1.000 / 1.000 stimmen mit der Quelle überein |
| DOI / Lizenz / Sprache | korrekt vorhanden oder korrekt ausgelassen (23 / 6 / 15 fehlen in der Quelle, nichts wurde erfunden) |
| ISSN | 41 Datensätze mit mehreren ISSN korrekt auf mehrere Elemente verteilt |
| Unicode-Treue | 20 stichprobenhaft geprüfte Zeichenketten mit Akzenten, 20/20 korrekt erhalten |

Vollständiger Bericht: [reports/quality_report.md](reports/quality_report.md) (englisch).

## Grenzen

- Datumsangaben (`01/11/2015`) bleiben unveränderte Zeichenketten, da die
  Reihenfolge von Tag und Monat nicht unabhängig belegt ist.
- Sprachcodes werden als ISO 639-1 (zweistellig) ausgezeichnet, nicht in das
  in Bibliotheken übliche ISO 639-2b umgewandelt, da keine verifizierte
  Umwandlungstabelle vorlag.
- Für Schlagwörter wird kein kontrolliertes Vokabular (z. B. LCSH) behauptet.
- `<publisher>` wird in MODS 3.8 durch `<agent>` ersetzt; dieses Projekt
  verwendet die aktuelle `<agent>`-Form.
- Die Validierung belegt Schema-Konformität und Quelltreue, nicht die
  inhaltliche Richtigkeit der Angaben selbst.

## Urheberschaft und KI-Unterstützung

Das erste Fix-Skript wurde von Shota Tsertsvadze manuell geschrieben und
getestet. Das Produktions-Mapping, die XML-Serialisierung, die
Qualitätsprüfungen, die Berichte und die README-Dateien entstanden mit dem
KI-Assistenten Claude Code (Anthropic).
