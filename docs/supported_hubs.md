# Track Hubs

Status and notes for hubs gin targets or has reviewed.

---

## Reviewed (zero `other`)

| Hub             | URL                                                                                            | Tracks | Assemblies | Notes                                                                                                       |
| --------------- | ---------------------------------------------------------------------------------------------- | -----: | ---------- | ----------------------------------------------------------------------------------------------------------- |
| Blueprint       | http://ftp.ebi.ac.uk/pub/databases/blueprint/releases/current_release/homo_sapiens/hub/hub.txt |  5,695 | hg38       | IHEC member. Uppercase `metadata KEY=VALUE` convention. Primary source of the Blueprint transformer design. |
| BrainEpigenome  | https://s3.us-east-2.amazonaws.com/brainepigenome/hub.txt                                      |     56 | hg19       | Brain region tracks. Sort-key prefixes on tissue names (`A_BA9`, `b_ba24`).                                 |
| MethBase (UCSC) | https://hgdownload.soe.ucsc.edu/hubs/methbase/v1/hub.txt                                       |  8,508 | hg19, hg38 | WGBS methylation analyses. View codes `d1PMD`–`d9MethPost` → `DNA_Methylation` sub-types.                   |
| ENCODE DNA      | https://storage.googleapis.com/gcp.wenglab.org/hubs/dna20/hub.txt                              | 50,344 | hg38       | ENCODE chromatin / DNA assays. Structured compound assay names (`TF_ChIP_seq_CTCF`).                        |
| CEMT            | http://www.bcgsc.ca/downloads/eddc/data/CEMT/hub/bcgsc_datahub.txt                             |  3,138 | hg38       | IHEC member (Canadian). Lowercase `metadata` keys; richer set of IHEC fields.                               |
| ENCODE RNA      | https://storage.googleapis.com/gcp.wenglab.org/hubs/rna22/hub.txt                              | 67,425 | hg38       | ENCODE RNA assays. Adds `eCLIP`, `RAMPAGE`, `CAGE`, `microRNA-seq`, `Control_eCLIP`.                        |
| VISION          | https://hgdownload.gi.ucsc.edu/hubs/vision/VISION_project/hub.txt                              |  2,140 | hg38       | Hematopoietic epigenome atlas. Uses `include` directives, `mark` / `factor` / `cell` subGroups.             |
| MethBase (Smith Lab) | http://smithlab.usc.edu/trackdata/methylation/hub.txt                                     | 74,491 | hg19, hg38 | Original MethBase. View codes `v1hmr`–`v5coverage` → `DNA_Methylation`. No sample/donor metadata.           |
| FANTOM5         | http://fantom.gsc.riken.jp/5/datahub/hub.txt                                                    | 23,746 | hg19, hg38, mm9, mm10, canFam3, rn6, rheMac8, galGal5 | CAGE-seq atlas. `sequence_tech` (`hCAGE`/`LQhCAGE`) → CAGE. `ontology_id` as sample ID. |

**Total reviewed: 235,543 tracks across 9 hubs.**

---

## Target list

Hubs we intend to add. Priority order is rough; each should be reviewed with `mix gin.audit` and extended until zero `other`.

| Hub                  | URL                                                                       | Notes                                                                                                                                                                              |
| -------------------- | ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| GTEx RNA-seq         | http://hgdownload.soe.ucsc.edu/hubs/gtex/hub.txt                          | 7,572-sample RNA-seq signal hub. Currently 403 Forbidden from UCSC for programmatic access; investigate.                                                                           |
| GTEx Analysis        | http://hgdownload.soe.ucsc.edu/hubs/gtexAnalysis/hub.txt                  | ASE and eQTL analysis tracks. Accessible; ~55 bigBed/bigWig tracks.                                                                                                                |
| Roadmap Epigenomics  | https://vizhub.wustl.edu/VizHub/RoadmapReleaseAll.txt                     | 273 tracks in hg19. Blocked: vizhub.wustl.edu closes TLS mid-handshake for Erlang clients. Metadata keys: `Anatomy`, `Type`, `EID`, `Ethnicity`, `Lab`. Worth fixing or mirroring. |
| IDEAS Roadmap        | http://bx.psu.edu/~yuzhang/Roadmap_ideas/ideas_hub.txt                    | Roadmap 20-state segmentation from IDEAS. Minimal metadata (only subGroups). Low priority.                                                                                         |
| ReMap 2022           | https://remap.univ-amu.fr/storage/public/hubReMap2022/hub.txt             | Single bigBed annotation track, not per-sample. No biological metadata to extract. Skip.                                                                                           |
| DASHR v2             | https://dashr2.lisanwanglab.org/tracks/DASHR2_hub.txt                     | Small ncRNA hub. Worth auditing for ncRNA assay types.                                                                                                                             |
| ENCODE Integrative   | https://storage.googleapis.com/gcp.wenglab.org/hubs/integrative52/hub.txt | Likely same metadata schema as ENCODE DNA/RNA. Audit to confirm.                                                                                                                   |

---

## Notes on hub access

- **`include` directives**: Gin resolves these recursively (depth limit 8). Required for VISION and likely other large hubs.
- **TLS**: Erlang's `:httpc` needs `depth: 5` in SSL opts for cert chains deeper than the default. vizhub.wustl.edu additionally closes the connection mid-handshake (likely JA3 fingerprint filtering); curl works fine.
- **Metadata conventions**: Blueprint/IHEC members use uppercase `metadata KEY=VALUE`. CEMT uses the same keys lowercase. ENCODE DNA/RNA use a different key schema but same inline format. VISION uses only `subGroups`.
