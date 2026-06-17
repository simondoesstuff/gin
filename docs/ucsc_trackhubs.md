# UCSC Track Hubs — API & Format Notes

Findings from initial exploration (June 2026). Basis for how gin will ingest hub data.

---

## Public hub registry

`GET https://api.genome.ucsc.edu/list/publicHubs`

Returns a JSON array of **118 hubs** — this is a *curated public registry*, not a complete
count. Any lab can host a private hub and point UCSC at it via URL without registering.
Registrations span 2012–2026. Each entry has:

```json
{
  "hubUrl":          "https://…/hub.txt",
  "shortLabel":      "ALFA Hub",
  "longLabel":       "…",
  "registrationTime":"2020-09-02 16:46:09",
  "dbCount":         2,
  "dbList":          "hg19,hg38,"
}
```

`dbCount` / `dbList` are the genome assemblies the hub covers. A hub covering 363 bird
assemblies has `dbCount=363`.

---

## Hub file structure

A hub is a small tree of plain-text files hosted anywhere (GitHub, FTP, S3, …).

```
hub.txt          — hub identity, points to genomesFile
genomesFile      — one stanza per assembly, each pointing to a trackDb file
  hg38/trackDb.txt   — track definitions for hg38
  hg19/trackDb.txt   — track definitions for hg19
```

### hub.txt fields
| field | meaning |
|---|---|
| `hub` | identifier |
| `shortLabel` | display name |
| `longLabel` | full name |
| `genomesFile` | relative path to genomes list (default: `genomes.txt`) |
| `email` | contact |
| `descriptionUrl` | HTML description page |

### genomes.txt fields (per stanza)
| field | meaning |
|---|---|
| `genome` | assembly name (e.g. `hg38`) |
| `trackDb` | relative path to trackDb file |
| `twoBitPath` | (assembly hubs only) genome sequence |
| `groups` | optional track grouping file |
| `defaultPos` | default browser position |

---

## trackDb.txt — hierarchy

Tracks nest in a strict four-level hierarchy. Indentation is cosmetic; the `parent` field
is what actually encodes the relationship.

```
superTrack   (folder / grouping container, no data)
└─ compositeTrack  (logical experiment group, defines subGroups vocabulary)
   └─ view          (data-type facet within a composite, e.g. "signal" vs "peak")
      └─ track      (leaf node — has a bigDataUrl, actual file)
```

Not all levels are required. Simple hubs may have bare leaf tracks with no parents.
Blueprint uses composite → view → track. CCGP assembly hubs have bare leaf tracks.

### Level details

**superTrack** — a folder. No `bigDataUrl`. Groups composites by theme (e.g. "Regulation",
"Gene Expression"). Declared with `superTrack on`.

**compositeTrack** — the main metadata-bearing level. Declared with `compositeTrack on`.
Defines the `subGroup1..N` vocabulary (controlled axes like experiment type, cell type,
tissue). Child tracks reference this vocabulary via their `subGroups` field.

**view** — optional sub-division within a composite for different data representations of
the same experiment (e.g. `signal` = bigWig coverage, `peaks` = bigBed calls).
Declared with `view <ViewName>`.

**track (leaf)** — has a `bigDataUrl` pointing to the actual binary file (bigBed, bigWig,
etc.). Inherits `type` and `subGroup` vocabulary from its parent composite if not
explicitly set.

---

## Assay metadata — where it lives

There are two distinct metadata layers:

### 1. Schema metadata (inside the bigBed/bigWig file)
Parsed via HTTP Range requests — no need to download the full file.

| Section | Location | Content |
|---|---|---|
| File header | bytes 0–63 | magic, version, field counts, offsets to all sections |
| AutoSQL | `auto_sql_off` | field names, types, descriptions for columns 4+ |
| Total summary | `total_summ_off` | item count, min, max, mean, stddev |
| Chrom B+ tree | `chrom_tree_off` | chromosome names + sizes indexed in this file |
| Zoom level table | bytes 64–(64 + zoom_levels×24) | pre-computed zoom resolutions |

`(chrom, start, end)` — the first three BED columns — are **always structurally
guaranteed** regardless of AutoSQL. AutoSQL only matters for extra columns (4+).

The pre-data metadata region (`auto_sql_off` → `data_start_off`) is typically a few KB.
A single Range request fetches the whole thing.

### 2. Assay metadata (in trackDb.txt, per-track stanza)
This is the biological/experimental provenance. **Not inside the binary file.**
Completely hub-specific — no enforced cross-hub schema.

Common fields (Blueprint as example):
```
shortLabel       human-readable name
longLabel        full description
metadata         KEY=VALUE ... (free-form but structured within a hub)
subGroups        experiment=BS-Seq sample_description=monocyte ...
color            RGB for browser display
visibility       dense | pack | full | hide
parent           <parentTrackName> [on|off]
bigDataUrl       https://…/file.bb
type             bigBed 9 + . | bigWig | etc.
```

The `metadata` line in rich hubs (Blueprint, ENCODE) carries fields like:
`EXPERIMENT_TYPE`, `CELL_TYPE`, `DONOR_AGE`, `DONOR_SEX`, `SAMPLE_ID`,
`EXPERIMENT_ID`, ontology URIs, alignment/analysis software versions.

The `subGroups` line encodes per-track membership in the composite's controlled
vocabulary — these are the filterable axes in the UCSC browser UI.

---

## UCSC REST API — what it actually gives us

Base: `https://api.genome.ucsc.edu/`

| Endpoint | Works for hub? | Returns |
|---|---|---|
| `list/publicHubs` | — | registry of 118 hubs |
| `list/hubGenomes?hubUrl=…` | ✓ | assemblies + trackDb paths (JSON) |
| `getData/track?hubUrl=…&genome=…&track=…` | ✓ | `bigDataUrl`, `trackType`, actual records |
| `list/tracks?genome=hg38` | native only | full trackDb stanza as JSON for all tracks |
| `list/schema?genome=hg38&track=…` | native only | AutoSQL schema |

**`list/tracks` does not accept `hubUrl`** — it 404s. For external hub tracks, the API
only returns `bigDataUrl` + `trackType` via `getData`. All other stanza fields require
parsing `trackDb.txt` directly.

### Strategy
Parse `trackDb.txt` ourselves. The format is simple and consistent:
- One stanza per track, blank-line separated
- Each stanza is `key value` lines (first token = key, rest = value)
- Parent fields are inherited by children (particularly `type`)
- `subGroup1..N` on composites define the vocabulary; `subGroups` on leaves reference it

The JSON shape from `list/tracks` (for native genomes) is a good target schema to
normalize into: every trackDb field becomes a JSON key, nested under the track name.

---

## Scripts

| Script | What it does |
|---|---|
| `scripts/01_list_hubs.sh` | Fetch + display the 118 public hub registry |
| `scripts/02_explore_hub.sh [HUB_URL]` | HEAD hub.txt → parse genomes → list all tracks with type + bigDataUrl |
| `scripts/03_fetch_bigbed.sh [HUB_URL]` | Find first bigBed in a hub, HEAD it for size, fetch + save 512-byte header |
| `scripts/04_bigbed_meta.sh [BIGBED_URL]` | Range-fetch pre-data region; parse AutoSQL, total summary, chrom B+ tree, zoom levels |

All scripts default to the ALFA Hub (NCBI allele frequencies, hg19/hg38, 12 bigBed tracks).
