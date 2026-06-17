#!/usr/bin/env bash
# Fetch the list of public track hubs from the UCSC Genome Browser REST API.
# Outputs one hub per line: index | shortLabel | dbCount | hubUrl

set -euo pipefail

API="https://api.genome.ucsc.edu/list/publicHubs"

echo "Fetching public track hubs from $API ..." >&2

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

curl -fsSL "$API" -o "$TMPFILE"

python3 - "$TMPFILE" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    data = json.load(f)

hubs = data["publicHubs"]

print(f"# {len(hubs)} public track hubs  (dataTime: {data['dataTime']})\n")
print(f"{'IDX':>4}  {'GENOMES':>7}  {'SHORT LABEL':<45}  HUB URL")
print("-" * 120)

for i, h in enumerate(hubs):
    print(f"{i:>4}  {h['dbCount']:>7}  {h['shortLabel']:<45}  {h['hubUrl']}")
PYEOF
