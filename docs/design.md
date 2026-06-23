# Gin

In a separate repo, we've created a 1D interval intersection search tool, a "genomic search engine" that can perform at trillion scale.
To feed the engine, Gin centralizes intervals and standardizes metadata from track hubs.

Gin is still en route to version 1.0 in elixir. Gin is currently only so ambitious as to support UCSC Genome Browser or track hubs compatible for parsing by the UCSC Genome Browser.

**Gin Responsibilities**

- Pull intervals from external repositories
- Pull and standardize metadata
- Maintain the timestamp of when the cache was last updated
- Send HEAD requests on refresh to conservatively update
- Deduplicate tracks by hashing intervals and merging metadata

### Gin Store

The gin store is a flat list of entries in a track hub. The bulk consists of sub-directories for each track hub source. A source sub-directory contains entries, one per track. A gin store entry is the pair: .json file and genomic interval set file. The entry pair contains all of the information of that track, considering even the entire store. Most track hubs will store contents hierarchically, gin flattens, not capturing the hierarchy; only leaf nodes. If a track hub specifies an entry's metadata using inheritance, gin resolves the references so it can store metadata self-contained.

**Gin store entry .json**

- sources: { source_name, download_link }[]
- refresh_time
- iv_hash
- metadata: GinMeta

**Gin Meta**

The standardized schema of genomic track descriptions. This is a big type, but it contains at least:

- name
- assembly
- other
- ...

A "source" is a track hub, considered as a list of "targets". A fully qualified target name is in the form `source/name` where the `name` could itself include slashes. In addition to entry data, the gin store contains the **IV hash record** which maps an IV set hash to a target name -- crucial for efficient IV-set deduplication. The gin store guarantees the IV hash record and IV hash in an entry to be consistent -- the IV hash record can be trusted to point to an entry with that IV hash.

### GinMeta

The current standardized schema:

```
GinMeta
  name            — track identifier (trackDb "track" field)
  short_label     — display name (≤17 chars)
  long_label      — extended display name
  description     — free-text description of the track or experiment
  assembly        — genome assembly (e.g. "hg38", "mm10")
  track_type      — bigBed | bigWig | bigGenePred | bigNarrowPeak | …
  big_data_url    — direct URL to the interval data file
  other           — map of dot-notation flat keys for unrecognized fields

  Sample
    id              — database accession (e.g. ERS208312)
    barcode         — sample barcode / short code
    cell_type       — cell type name (free text, with vocab)
    tissue          — anatomical source (controlled vocab)
    biomaterial_type — Primary_Cell | Primary_Cell_Culture | Primary_Tissue | Cell_Line
    ontology_uri    — list of CL/UBERON URIs
    Donor
      id              — donor identifier
      age             — age or age range string
      sex             — Female | Male | Mixed | Unknown
      ethnicity       — free text
      health_status   — free text
      disease         — disease name (free text, with vocab)
      disease_ontology_uri — list of DOID/NCI URIs

  Experiment
    id              — experiment accession (e.g. ERX204011)
    accession       — hub-native accession (e.g. ENCODE ENCSR…)
    type            — assay type (controlled vocab, e.g. ChIP-seq, ATAC-seq)
    target          — ChIP target protein or histone mark (e.g. CTCF, H3K4me3)
    molecule        — genomic_DNA | polyA_RNA | total_RNA
    epirr_id        — IHEC EpiRR identifier

  Provenance
    analysis_group          — lab or consortium that ran the analysis
    analysis_type           — analysis pipeline variant (e.g. MACS2_wiggler)
    alignment_software      — aligner used (e.g. BWA, STAR, GEM)
    alignment_software_version
    analysis_software       — peak caller / quantifier (e.g. MACS2, RSEM)
    analysis_software_version
```

### Metadata Transformers

Raw track stanzas from UCSC-compatible hubs use many different conventions to describe the same biological concepts. The transformer pipeline normalizes these into a single `GinMeta` struct.

**Pipeline**

Each transformer is a function `raw_track → {attrs, consumed}` where:

- `attrs` is a flat map of `atom → value` for named GinMeta fields
- `consumed` is a `MapSet` of dot-notation flat keys claimed by this transformer (e.g. `"metadata.CELL_TYPE"`, `"subGroups.experiment"`)

`Transformer.transform/1` runs all transformers, merges their attrs (later transformers win on collision), computes `other` as the set of all flat keys not consumed by any transformer, then assembles the nested `GinMeta` struct.

**Transformers**

`Core` — lifts the fields present on every leaf track: `track`, `shortLabel`, `longLabel`, `description`, `_assembly`, `bigDataUrl`, `type` (first token only, e.g. `"bigBed 6 ."` → `"bigBed"`).

`Blueprint` — extracts biological and provenance metadata from two UCSC inline sub-formats:

- `metadata KEY=VALUE KEY=VALUE …` — used by Blueprint, IHEC, and many ENCODE hubs. Keys are typically uppercase (e.g. `CELL_TYPE`, `DONOR_SEX`); some hubs use lowercase. Blueprint normalizes both.
- `subGroups key=value key=value …` — used for faceted filtering in compositeTrack hubs. Blueprint lifts cell type, tissue, analysis group, analysis type, sample barcode, experiment type, and experiment target from a priority-ordered list of candidate subGroup keys, so the same biological concept can be found under different key names across hubs.

Blueprint also handles:

- Semicolon-separated URI lists (`SAMPLE_ONTOLOGY_URI`, `DISEASE_ONTOLOGY_URI`)
- Quote-stripping for hubs that emit JSON-style quoted values
- Numeric sample-code detection: values that are all digits (Roadmap Epigenomics cell type codes) are rejected from the experiment type field rather than stored as garbage
- Compound assay name parsing (see Vocab / ExperimentType below)

`Display` — consumes known UCSC browser rendering keys (color, visibility, autoScale, maxHeightPixels, subGroup1–8, etc.) that have no biological meaning. This keeps them out of `other` without storing them.

**Controlled Vocabularies**

Vocab modules implement a compile-time whitelist of `{canonical, [aliases…]}` pairs. `normalize/1` maps raw strings case-insensitively through the alias table, returning `{:ok, canonical}` or `{:unknown, raw}`. Unknown values are stored as-is — they are not rejected — but surface in `mix gin.audit` output so the whitelist can be extended.

Current vocabs:

| Module            | Closed?   | Description                                                                                                                                                                                       |
| ----------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ExperimentType`  | semi-open | Assay types: ChIP-seq marks, methylation, RNA-seq, ATAC-seq, DNase-seq, Repli-seq. Also implements `parse_structured/1` for ENCODE compound names like `"TF_ChIP_seq_CTCF"` → `{ChIP-seq, CTCF}`. |
| `Molecule`        | closed    | `genomic_DNA`, `polyA_RNA`, `total_RNA`                                                                                                                                                           |
| `BiomaterialType` | closed    | `Primary_Cell`, `Primary_Cell_Culture`, `Primary_Tissue`, `Cell_Line`                                                                                                                             |
| `Sex`             | closed    | `Female`, `Male`, `Mixed`, `Unknown`                                                                                                                                                              |
| `Tissue`          | semi-open | Anatomical sources from Blueprint and brain region codes from BrainEpigenome (e.g. `A_BA9` → `frontal_cortex`)                                                                                    |
| `TrackType`       | closed    | `bigBed`, `bigWig`, `bigGenePred`, `bigNarrowPeak`, …                                                                                                                                             |

**Audit**

`mix gin.audit [hub_url …]` fetches one or more hubs, transforms all tracks, and reports:

- Per named field: observed value frequencies with `[?]` markers for values not yet in any vocab
- `other` key frequencies — anything still escaping the transformer pipeline

The iterative workflow is: run the audit against a new hub, inspect `[?]` markers and `other` keys, extend vocab entries or transformer mappings, repeat until `other` is empty and `[?]` counts are acceptable.

### Other

- IV hash collisions are not handled, although it is not quite catastrophic if it occurs. Gin relies on large hashes like SHA-256 to make the chance astronomically low.
