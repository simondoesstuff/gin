# Track Hubs

Status and notes for hubs gin targets or has reviewed.

Track counts reflect only 1D interval tracks (bigBed and variants). bigWig signal
tracks are excluded at the `TrackDb` layer — they have no feature intervals for the
gin engine to index.

---

## Reviewed (zero `other`)

| Hub             | URL                                                                                            | Interval tracks | Assemblies | Notes                                                                                                       |
| --------------- | ---------------------------------------------------------------------------------------------- | --------------: | ---------- | ----------------------------------------------------------------------------------------------------------- |
| Blueprint       | http://ftp.ebi.ac.uk/pub/databases/blueprint/releases/current_release/homo_sapiens/hub/hub.txt |           2,205 | hg38       | IHEC member. Uppercase `metadata KEY=VALUE` convention. Primary source of the Blueprint transformer design. |
| BrainEpigenome  | https://s3.us-east-2.amazonaws.com/brainepigenome/hub.txt                                      |              20 | hg19       | Brain region tracks. Sort-key prefixes on tissue names (`A_BA9`, `b_ba24`).                                 |
| MethBase (UCSC) | https://hgdownload.soe.ucsc.edu/hubs/methbase/v1/hub.txt                                       |           3,505 | hg19, hg38 | WGBS methylation analyses. View codes `d1PMD`–`d9MethPost` → `DNA_Methylation` sub-types.                   |
| ENCODE DNA      | https://storage.googleapis.com/gcp.wenglab.org/hubs/dna20/hub.txt                              |          26,186 | hg38       | ENCODE chromatin / DNA assays. Structured compound assay names (`TF_ChIP_seq_CTCF`).                        |
| CEMT            | http://www.bcgsc.ca/downloads/eddc/data/CEMT/hub/bcgsc_datahub.txt                             |             n/a | hg38       | IHEC member (Canadian). **Currently 404** — hub URL has moved. Transformer supports its metadata schema.    |
| ENCODE RNA      | https://storage.googleapis.com/gcp.wenglab.org/hubs/rna22/hub.txt                              |           3,188 | hg38       | ENCODE RNA assays. Adds `eCLIP`, `RAMPAGE`, `CAGE`, `microRNA-seq`, `Control_eCLIP`.                        |
| VISION          | https://hgdownload.gi.ucsc.edu/hubs/vision/VISION_project/hub.txt                              |             680 | hg38       | Hematopoietic epigenome atlas. Uses `include` directives, `mark` / `factor` / `cell` subGroups.             |
| MethBase (Smith Lab) | http://smithlab.usc.edu/trackdata/methylation/hub.txt                                     |          42,305 | hg19, hg38 | Original MethBase. View codes `v1hmr`–`v5coverage` → `DNA_Methylation`. No sample/donor metadata.           |
| FANTOM5         | http://fantom.gsc.riken.jp/5/datahub/hub.txt                                                   |              18 | hg19, hg38, mm9, mm10, canFam3, rn6, rheMac8, galGal5 | CAGE-seq atlas. Interval tracks are peak/enhancer bigBeds only; per-sample CTSS bigWig signals are excluded. |
| GTEx Analysis   | http://hgdownload.soe.ucsc.edu/hubs/gtexAnalysis/hub.txt                                       |             108 | hg19, hg38 | ASE and eQTL analysis bigBeds. No sample metadata in trackDb. |
| ENCODE Integrative | https://storage.googleapis.com/gcp.wenglab.org/hubs/integrative52/hub.txt                  |           1,998 | hg38, mm10 | ENCODE cCRE registry. Rich cell-type data (483 unique values). Adds `cCRE` experiment type. |

**Total reviewed: 80,213 interval tracks across 11 hubs (CEMT currently 404).**

---

## Target list

Hubs we intend to add. Priority order is rough; each should be reviewed with `mix gin.audit` and extended until zero `other`.

| Hub                  | URL                                                                       | Notes                                                                                                                                                                              |
| -------------------- | ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| GTEx RNA-seq         | http://hgdownload.soe.ucsc.edu/hubs/gtex/hub.txt                          | 7,572-sample RNA-seq signal hub. Currently 403 Forbidden from UCSC for programmatic access; likely all bigWig so low value after filtering.                                         |
| Roadmap Epigenomics  | https://vizhub.wustl.edu/VizHub/RoadmapReleaseAll.txt                     | 273 tracks in hg19. Blocked: vizhub.wustl.edu closes TLS mid-handshake for Erlang clients. Metadata keys: `Anatomy`, `Type`, `EID`, `Ethnicity`, `Lab`. Worth fixing or mirroring. |
| IDEAS Roadmap        | http://bx.psu.edu/~yuzhang/Roadmap_ideas/ideas_hub.txt                    | Roadmap 20-state segmentation from IDEAS. Minimal metadata (only subGroups). Low priority.                                                                                         |
| ReMap 2022           | https://remap.univ-amu.fr/storage/public/hubReMap2022/hub.txt             | Single bigBed annotation track, not per-sample. No biological metadata to extract. Skip.                                                                                           |
| DASHR v2             | https://dashr2.lisanwanglab.org/tracks/DASHR2_hub.txt                     | Small ncRNA hub. Worth auditing for ncRNA assay types.                                                                                                                             |

---

## Notes on hub access

- **`include` directives**: Gin resolves these recursively (depth limit 8). Required for VISION and likely other large hubs.
- **Track type filtering**: Only 1D interval types are kept (`bigBed`, `bigNarrowPeak`, `bigBroadPeak`, `bigGenePred`, `bigPsl`, `bigBarChart`, `vcfTabix`, and plain `bed`/`narrowPeak`/`broadPeak`/`genePred`/`psl`). `bigWig`, `bigInteract`, `hic`, `bam`, and unknown types are dropped at parse time.
- **TLS**: vizhub.wustl.edu closes the connection mid-handshake (likely JA3 fingerprint filtering); curl works fine but Erlang's HTTP client cannot reach it.
- **Metadata conventions**: Blueprint/IHEC members use uppercase `metadata KEY=VALUE`. CEMT uses the same keys lowercase. ENCODE DNA/RNA use a different key schema but same inline format. VISION uses only `subGroups`. FANTOM5 uses lowercase `metadata` with `ontology_id` and `sequence_tech` keys.
