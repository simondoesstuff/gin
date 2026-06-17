#!/usr/bin/env bash
# Fetch and parse per-file metadata from a bigBed file using HTTP Range requests.
#
# Sections parsed:
#   • File header       – version, field counts, all section offsets
#   • AutoSQL schema    – field names, types, and descriptions
#   • Total summary     – validCount, min, max, sum, sumSquares
#   • Chrom B+ tree     – all chromosome names + sizes stored in the file
#   • Zoom level table  – zoom level multipliers and their data/index offsets
#
# No local copy of the full file is needed; we only request the bytes we need.
#
# Usage: ./04_bigbed_meta.sh [BIGBED_URL]
# Default: ALFA Hub hg19 global bigBed

set -euo pipefail

BIGBED_URL="${1:-https://ftp.ncbi.nih.gov/snp/population_frequency/TrackHub/20260205170148/hg19/ALFA_GLB.bb}"

OUTDIR="$(dirname "$0")/../data"
mkdir -p "$OUTDIR"
META_BIN="$OUTDIR/bigbed_meta.bin"

python3 - "$BIGBED_URL" "$META_BIN" <<'PYEOF'
import struct, sys, urllib.request

url   = sys.argv[1]
outpath = sys.argv[2]

BIGBED_MAGIC_LE = 0x8789F2EB
BIGBED_MAGIC_BE = 0xEBF28987
BPTREE_MAGIC    = 0x78CA8C91

def fetch_range(url, start, end):
    req = urllib.request.Request(url, headers={"Range": f"bytes={start}-{end}"})
    with urllib.request.urlopen(req) as r:
        return r.read()

def sep(title=""):
    if title:
        print(f"\n── {title}")
    print("─" * 72)

# ── 1. Parse fixed 64-byte header ────────────────────────────────────────────
sep("File header")
hdr = fetch_range(url, 0, 63)

magic = struct.unpack_from("<I", hdr, 0)[0]
if magic == BIGBED_MAGIC_LE:
    fmt = "<"
elif magic == BIGBED_MAGIC_BE:
    fmt = ">"
else:
    sys.exit(f"Not a bigBed file (magic=0x{magic:08X})")

version         = struct.unpack_from(f"{fmt}H", hdr,  4)[0]
zoom_levels     = struct.unpack_from(f"{fmt}H", hdr,  6)[0]
chrom_tree_off  = struct.unpack_from(f"{fmt}Q", hdr,  8)[0]
data_start_off  = struct.unpack_from(f"{fmt}Q", hdr, 16)[0]
data_index_off  = struct.unpack_from(f"{fmt}Q", hdr, 24)[0]
field_count     = struct.unpack_from(f"{fmt}H", hdr, 32)[0]
defined_count   = struct.unpack_from(f"{fmt}H", hdr, 34)[0]
auto_sql_off    = struct.unpack_from(f"{fmt}Q", hdr, 36)[0]
total_summ_off  = struct.unpack_from(f"{fmt}Q", hdr, 44)[0]
uncomp_buf_size = struct.unpack_from(f"{fmt}I", hdr, 52)[0]

print(f"Magic:            0x{magic:08X}  (bigBed, {'little' if fmt=='<' else 'big'}-endian)")
print(f"Version:          {version}")
print(f"Field count:      {field_count}  (defined: {defined_count})")
print(f"Zoom levels:      {zoom_levels}")
print(f"Chrom tree   @:   0x{chrom_tree_off:x}")
print(f"Data start   @:   0x{data_start_off:x}")
print(f"Data index   @:   0x{data_index_off:x}")
print(f"AutoSQL      @:   0x{auto_sql_off:x}")
print(f"Total summary@:   0x{total_summ_off:x}")
print(f"Uncomp buf:       {uncomp_buf_size:,} bytes")

# ── 2. Fetch the whole pre-data metadata region in one request ────────────────
# Everything we need sits between the first non-header offset and data_start_off.
meta_start = min(o for o in [auto_sql_off, total_summ_off, chrom_tree_off] if o > 0)
meta_end   = data_start_off - 1

print(f"\nFetching metadata region 0x{meta_start:x}–0x{meta_end:x} "
      f"({meta_end - meta_start + 1:,} bytes) …")
meta = fetch_range(url, meta_start, meta_end)

# Save for inspection
with open(outpath, "wb") as f:
    f.write(meta)
print(f"Saved to {outpath}")

def at(offset):
    """Return offset relative to meta_start."""
    return offset - meta_start

# ── 3. Zoom level table (lives right after the 64-byte header) ────────────────
if zoom_levels > 0:
    sep("Zoom level table")
    zoom_data = fetch_range(url, 64, 64 + zoom_levels * 24 - 1)
    print(f"{'LEVEL':>5}  {'REDUCTION':>10}  {'DATA OFF':>14}  {'INDEX OFF':>14}")
    print("-" * 50)
    for i in range(zoom_levels):
        base = i * 24
        reduction  = struct.unpack_from(f"{fmt}I", zoom_data, base)[0]
        _reserved  = struct.unpack_from(f"{fmt}I", zoom_data, base + 4)[0]
        data_off   = struct.unpack_from(f"{fmt}Q", zoom_data, base + 8)[0]
        index_off  = struct.unpack_from(f"{fmt}Q", zoom_data, base + 16)[0]
        print(f"{i:>5}  {reduction:>10,}x  {data_off:>#14x}  {index_off:>#14x}")

# ── 4. AutoSQL schema ─────────────────────────────────────────────────────────
sep("AutoSQL field schema")

if auto_sql_off > 0:
    sql_bytes = meta[at(auto_sql_off):]
    nul = sql_bytes.find(b"\x00")
    autosql = sql_bytes[:nul].decode("ascii", errors="replace") if nul >= 0 else sql_bytes.decode("ascii", errors="replace")

    print(autosql.rstrip())
    print()

    # Parse field lines for a compact table
    import re
    fields = re.findall(r'^\s+(\S+)\s+(\w+)\s*;\s*"([^"]*)"', autosql, re.MULTILINE)
    if fields:
        print(f"  {'#':>3}  {'TYPE':<12}  {'NAME':<20}  DESCRIPTION")
        print(f"  {'':-<3}  {'':-<12}  {'':-<20}  {'':-<40}")
        for i, (ftype, name, desc) in enumerate(fields):
            print(f"  {i:>3}  {ftype:<12}  {name:<20}  {desc}")
else:
    print("  (no AutoSQL offset in header)")

# ── 5. Total summary ──────────────────────────────────────────────────────────
sep("Total summary (whole-file statistics)")

if total_summ_off > 0:
    s = meta[at(total_summ_off):]
    valid_count, min_val, max_val, sum_data, sum_sq = struct.unpack_from(f"{fmt}Qdddd", s, 0)
    mean = sum_data / valid_count if valid_count else 0
    import math
    variance = (sum_sq / valid_count - mean**2) if valid_count else 0
    std_dev  = math.sqrt(max(0, variance))

    print(f"  Item count:   {valid_count:,}")
    print(f"  Min value:    {min_val}")
    print(f"  Max value:    {max_val}")
    print(f"  Mean:         {mean:.6f}")
    print(f"  Std dev:      {std_dev:.6f}")
    print(f"  Sum:          {sum_data}")
    print(f"  Sum of sq:    {sum_sq}")
else:
    print("  (no total summary offset in header)")

# ── 6. Chromosome B+ tree ─────────────────────────────────────────────────────
sep("Chromosome index (B+ tree)")

bpt_data = meta[at(chrom_tree_off):]

# B+ tree header layout (32 bytes total):
#   magic(I4) blockSize(I4) keySize(I4) valSize(I4) itemCount(Q8) reserved(Q8)
bpt_magic,  block_size, key_size, val_size = struct.unpack_from(f"{fmt}IIII", bpt_data, 0)
item_count = struct.unpack_from(f"{fmt}Q", bpt_data, 16)[0]

if bpt_magic != BPTREE_MAGIC:
    print(f"  WARNING: unexpected B+ tree magic 0x{bpt_magic:08X}")
else:
    print(f"  B+ tree magic: 0x{bpt_magic:08X}  ✓")

print(f"  Block size:    {block_size}")
print(f"  Key size:      {key_size} bytes")
print(f"  Value size:    {val_size} bytes")
print(f"  Total chroms:  {item_count}")
print()

# Walk the root node (immediately follows the 32-byte header)
# Node format: isLeaf(1) + padding(1) + childCount(2) + [key(key_size) + val/off(val_size|8)]*
NODE_HDR = 32   # 4+4+4+4+8+8 byte B+ tree file header before root node

def parse_node(data, offset, key_size, val_size, fmt, depth=0):
    """Recursively walk the B+ tree and yield (chrom_name, chrom_id, chrom_size) tuples."""
    is_leaf    = struct.unpack_from("B", data, offset)[0]
    child_count = struct.unpack_from(f"{fmt}H", data, offset + 2)[0]
    pos = offset + 4

    for _ in range(child_count):
        key = data[pos:pos + key_size].rstrip(b"\x00").decode("ascii", errors="replace")
        pos += key_size
        if is_leaf:
            chrom_id   = struct.unpack_from(f"{fmt}I", data, pos)[0]
            chrom_size = struct.unpack_from(f"{fmt}I", data, pos + 4)[0]
            pos += val_size
            yield key, chrom_id, chrom_size
        else:
            child_offset = struct.unpack_from(f"{fmt}Q", data, pos)[0]
            pos += 8
            # child_offset is relative to the start of the B+ tree section in meta
            child_in_meta = child_offset - chrom_tree_off
            yield from parse_node(data, child_in_meta, key_size, val_size, fmt, depth + 1)

chroms = list(parse_node(bpt_data, NODE_HDR, key_size, val_size, fmt))
chroms.sort(key=lambda x: x[1])   # sort by chrom_id

print(f"  {'ID':>4}  {'CHROM':<16}  SIZE (bp)")
print(f"  {'':-<4}  {'':-<16}  {'':-<12}")
for name, cid, size in chroms:
    print(f"  {cid:>4}  {name:<16}  {size:,}")

print()
PYEOF
