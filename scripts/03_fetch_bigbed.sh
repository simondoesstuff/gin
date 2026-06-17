#!/usr/bin/env bash
# Fetch the first bigBed file found in a UCSC track hub.
# Since bigBed files can be many GB, this script:
#   1. Finds the first bigDataUrl with type bigBed in the hub
#   2. HEADs it to get size + metadata
#   3. Fetches the first 512 bytes (the bigBed file header) and inspects it
#   4. Saves the header bytes to data/bigbed_header.bin
#
# bigBed magic numbers:
#   0x8789F2EB  (little-endian) = bigBed
#   0xEBF28987  (big-endian)    = bigBed (byte-swapped)
#
# Usage: ./03_fetch_bigbed.sh [HUB_URL]
# Default: ALFA Hub (NCBI allele frequencies)

set -euo pipefail

HUB_URL="${1:-https://ftp.ncbi.nlm.nih.gov/snp/population_frequency/TrackHub/latest/hub.txt}"
BASE_URL="${HUB_URL%/hub.txt}"

OUTDIR="$(dirname "$0")/../data"
mkdir -p "$OUTDIR"

sep() { printf '%0.s─' {1..80}; echo; }

# ── Resolve hub → genomes → trackDb ──────────────────────────────────────────
HUB_CONTENT=$(curl -fsSL "$HUB_URL")
GENOMES_FILE=$(echo "$HUB_CONTENT" | awk '/^genomesFile/{print $2}')
GENOMES_FILE="${GENOMES_FILE:-genomes.txt}"
GENOMES_CONTENT=$(curl -fsSL "$BASE_URL/$GENOMES_FILE")

# Find the first genome's trackDb
FIRST_GENOME=$(echo "$GENOMES_CONTENT" | awk '/^genome/{print $2; exit}')
TRACKDB_REL=$(echo "$GENOMES_CONTENT" | awk '/^trackDb/{print $2; exit}')
TRACKDB_URL="$BASE_URL/$TRACKDB_REL"

echo "Hub:     $HUB_URL"
echo "Genome:  $FIRST_GENOME"
echo "TrackDb: $TRACKDB_URL"

TRACKDB=$(curl -fsSL "$TRACKDB_URL")

# ── Find first bigBed bigDataUrl ──────────────────────────────────────────────
BIGBED_URL=""
BIGBED_TRACK=""
IN_BIGBED_TRACK=0
PENDING_TRACK=""

while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*track[[:space:]]+(.+) ]]; then
        PENDING_TRACK="${BASH_REMATCH[1]}"
        # Don't reset IN_BIGBED_TRACK here: child tracks inherit type from parent composite
    elif [[ "$line" =~ ^[[:space:]]*type[[:space:]]+(bigBed.*) ]]; then
        IN_BIGBED_TRACK=1
    elif [[ "$line" =~ ^[[:space:]]*type[[:space:]]+ && ! "$line" =~ bigBed ]]; then
        IN_BIGBED_TRACK=0   # explicit non-bigBed type resets the flag
    elif [[ "$IN_BIGBED_TRACK" -eq 1 && "$line" =~ ^[[:space:]]*bigDataUrl[[:space:]]+(.+) ]]; then
        BIGBED_URL="${BASH_REMATCH[1]}"
        BIGBED_TRACK="$PENDING_TRACK"
        break
    fi
done <<< "$TRACKDB"

if [[ -z "$BIGBED_URL" ]]; then
    echo "No bigBed track found in $TRACKDB_URL" >&2
    exit 1
fi

echo
echo "── First bigBed track: $BIGBED_TRACK"
sep
echo "URL: $BIGBED_URL"
echo

# ── HEAD the bigBed file ──────────────────────────────────────────────────────
echo "── HEAD"
sep
HEAD_OUTPUT=$(curl -fsSI "$BIGBED_URL")
echo "$HEAD_OUTPUT"

CONTENT_LENGTH=$(echo "$HEAD_OUTPUT" | grep -i "^content-length:" | awk '{print $2}' | tr -d '\r')
if [[ -n "$CONTENT_LENGTH" ]]; then
    SIZE_MB=$(python3 -c "print(f'{int(\"$CONTENT_LENGTH\") / 1024**2:.1f} MB')")
    SIZE_GB=$(python3 -c "print(f'{int(\"$CONTENT_LENGTH\") / 1024**3:.2f} GB')")
    echo "→ File size: $CONTENT_LENGTH bytes  ($SIZE_MB / $SIZE_GB)"
fi

# ── Fetch header bytes ────────────────────────────────────────────────────────
HEADER_FILE="$OUTDIR/bigbed_header.bin"
HEADER_BYTES=512

echo
echo "── Fetching first $HEADER_BYTES bytes → $HEADER_FILE"
sep
curl -fsSL --range "0-$((HEADER_BYTES - 1))" "$BIGBED_URL" -o "$HEADER_FILE"
echo "Saved $HEADER_BYTES bytes to $HEADER_FILE"
echo

# ── Inspect the bigBed magic number ──────────────────────────────────────────
echo "── Header inspection"
sep

python3 - "$HEADER_FILE" <<'EOF'
import struct, sys

path = sys.argv[1]
with open(path, "rb") as f:
    data = f.read()

if len(data) < 64:
    print(f"ERROR: only got {len(data)} bytes, expected at least 64"); sys.exit(1)

# bigBed / bigWig magic numbers
BIGBED_MAGIC_LE = 0x8789F2EB
BIGBED_MAGIC_BE = 0xEBF28987
BIGWIG_MAGIC_LE = 0x888FFC26
BIGWIG_MAGIC_BE = 0x26FC8F88

magic = struct.unpack_from("<I", data, 0)[0]

if magic == BIGBED_MAGIC_LE:
    fmt, label = "<", "bigBed (little-endian)"
elif magic == BIGBED_MAGIC_BE:
    fmt, label = ">", "bigBed (big-endian)"
elif magic in (BIGWIG_MAGIC_LE, BIGWIG_MAGIC_BE):
    fmt = "<" if magic == BIGWIG_MAGIC_LE else ">"
    label = "bigWig"
else:
    print(f"Unknown magic: 0x{magic:08X}")
    sys.exit(1)

print(f"Format:         {label}")
print(f"Magic:          0x{magic:08X}")

# Parse the bigBed/bigWig common header (64 bytes)
# Offsets per spec: https://genome.ucsc.edu/goldenPath/help/bigBed.html
version         = struct.unpack_from(f"{fmt}H", data, 4)[0]
zoom_levels     = struct.unpack_from(f"{fmt}H", data, 6)[0]
chrom_tree_off  = struct.unpack_from(f"{fmt}Q", data, 8)[0]
data_start_off  = struct.unpack_from(f"{fmt}Q", data, 16)[0]
data_index_off  = struct.unpack_from(f"{fmt}Q", data, 24)[0]
field_count     = struct.unpack_from(f"{fmt}H", data, 32)[0]
defined_count   = struct.unpack_from(f"{fmt}H", data, 34)[0]
auto_sql_off    = struct.unpack_from(f"{fmt}Q", data, 36)[0]
total_summary_off = struct.unpack_from(f"{fmt}Q", data, 44)[0]
uncomp_buf_size = struct.unpack_from(f"{fmt}I", data, 52)[0]

print(f"Version:        {version}")
print(f"Zoom levels:    {zoom_levels}")
print(f"Field count:    {field_count}  (defined: {defined_count})")
print(f"Chrom tree @:   {chrom_tree_off:#x}")
print(f"Data start @:   {data_start_off:#x}")
print(f"Data index @:   {data_index_off:#x}")
print(f"AutoSQL @:      {auto_sql_off:#x}")
print(f"Total summary@: {total_summary_off:#x}")
print(f"Uncomp buf:     {uncomp_buf_size} bytes")

print()
print("Raw header hex dump (first 64 bytes):")
for off in range(0, 64, 16):
    chunk = data[off:off+16]
    hex_part  = " ".join(f"{b:02x}" for b in chunk)
    ascii_part = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
    print(f"  {off:04x}  {hex_part:<47}  {ascii_part}")
EOF
