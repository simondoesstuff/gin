#!/usr/bin/env bash
# Explore a UCSC track hub:
#   1. HEAD the hub.txt URL to check availability and headers
#   2. GET hub.txt and parse metadata
#   3. GET genomes.txt and list supported assemblies + trackDb paths
#   4. GET each trackDb.txt and list all tracks (type, label, bigDataUrl)
#
# Usage: ./02_explore_hub.sh [HUB_URL]
# Default: ALFA Hub (NCBI allele frequencies)

set -euo pipefail

HUB_URL="${1:-https://ftp.ncbi.nlm.nih.gov/snp/population_frequency/TrackHub/latest/hub.txt}"
BASE_URL="${HUB_URL%/hub.txt}"  # strip filename to get base directory URL

sep() { printf '%0.s─' {1..80}; echo; }

# ── 1. HEAD ──────────────────────────────────────────────────────────────────
echo
echo "── HEAD $HUB_URL"
sep
curl -fsSI "$HUB_URL"

# ── 2. hub.txt ───────────────────────────────────────────────────────────────
echo
echo "── GET hub.txt"
sep
HUB_CONTENT=$(curl -fsSL "$HUB_URL")
echo "$HUB_CONTENT"

# Parse the genomesFile field (defaults to "genomes.txt")
GENOMES_FILE=$(echo "$HUB_CONTENT" | awk '/^genomesFile/{print $2}')
GENOMES_FILE="${GENOMES_FILE:-genomes.txt}"

GENOMES_URL="$BASE_URL/$GENOMES_FILE"

# ── 3. genomes.txt ───────────────────────────────────────────────────────────
echo
echo "── GET $GENOMES_URL"
sep
GENOMES_CONTENT=$(curl -fsSL "$GENOMES_URL")
echo "$GENOMES_CONTENT"

# ── 4. Each trackDb.txt ───────────────────────────────────────────────────────
echo
echo "── Tracks per genome assembly"
sep

# Extract pairs of (genome, trackDb path) from genomes.txt
while IFS= read -r line; do
    if [[ "$line" =~ ^genome[[:space:]]+(.+) ]]; then
        CURRENT_GENOME="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^trackDb[[:space:]]+(.+) ]]; then
        TRACKDB_REL="${BASH_REMATCH[1]}"
        TRACKDB_URL="$BASE_URL/$TRACKDB_REL"

        echo
        echo "  Genome: $CURRENT_GENOME  →  $TRACKDB_URL"

        TRACKDB=$(curl -fsSL "$TRACKDB_URL")

        # Print a summary table of all tracks
        echo "  $(echo "$TRACKDB" | grep -c '^[[:space:]]*track ') track entries"
        echo
        echo "  $(printf '%-40s  %-12s  %s' 'TRACK' 'TYPE' 'bigDataUrl')"
        echo "  $(printf '%0.s-' {1..100})"

        CURRENT_TRACK=""
        CURRENT_TYPE=""
        INHERITED_TYPE=""   # last type seen (child tracks inherit from parent)
        while IFS= read -r tline; do
            if [[ "$tline" =~ ^[[:space:]]*track[[:space:]]+(.+) ]]; then
                CURRENT_TRACK="${BASH_REMATCH[1]}"
                CURRENT_TYPE=""
            elif [[ "$tline" =~ ^[[:space:]]*type[[:space:]]+(.+) ]]; then
                CURRENT_TYPE="${BASH_REMATCH[1]}"
                INHERITED_TYPE="$CURRENT_TYPE"
            elif [[ "$tline" =~ ^[[:space:]]*bigDataUrl[[:space:]]+(.+) ]]; then
                DISPLAY_TYPE="${CURRENT_TYPE:-$INHERITED_TYPE}"
                printf "  %-40s  %-12s  %s\n" "$CURRENT_TRACK" "$DISPLAY_TYPE" "${BASH_REMATCH[1]}"
            fi
        done <<< "$TRACKDB"
    fi
done <<< "$GENOMES_CONTENT"

echo
