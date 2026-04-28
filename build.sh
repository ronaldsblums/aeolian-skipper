#!/usr/bin/env bash
# build.sh — Regenerate self-contained Aeolian Skipper from index.html + data/locations.json
# Usage: bash build.sh
#
# Source of truth:
#   index.html                  — runtime app, fetches data/locations.json
#   data/locations.json         — locations + version + lastUpdated
#
# Generated outputs (do not edit by hand):
#   dist/index.html             — deploy target for GitHub Pages (self-contained)
#   aeolian-skipper-tool.html   — legacy local-share backup, identical content

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INDEX="$SCRIPT_DIR/index.html"
LOCATIONS="$SCRIPT_DIR/data/locations.json"
DIST_DIR="$SCRIPT_DIR/dist"
DIST_OUT="$DIST_DIR/index.html"
LEGACY_OUT="$SCRIPT_DIR/aeolian-skipper-tool.html"

if [ ! -f "$INDEX" ]; then echo "ERROR: $INDEX not found"; exit 1; fi
if [ ! -f "$LOCATIONS" ]; then echo "ERROR: $LOCATIONS not found"; exit 1; fi

mkdir -p "$DIST_DIR"

python3 - "$INDEX" "$LOCATIONS" "$DIST_OUT" "$LEGACY_OUT" << 'PYEOF'
import sys, json

index_path, locations_path, dist_out, legacy_out = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

with open(index_path, 'r') as f:
    html = f.read()

with open(locations_path, 'r') as f:
    data = json.load(f)
    locations = data['locations'] if 'locations' in data else data
    data_version = data.get('version') if isinstance(data, dict) else None
    last_updated = data.get('lastUpdated') if isinstance(data, dict) else None

if not isinstance(locations, list) or len(locations) == 0:
    print("ERROR: locations.json does not contain a non-empty locations array", file=sys.stderr)
    sys.exit(1)

embedded_js = (
    'const EMBEDDED_LOCATIONS = ' + json.dumps(locations, separators=(',', ':')) + ';\n'
    'const EMBEDDED_DATA_META = ' + json.dumps({'dataVersion': data_version, 'lastUpdated': last_updated}, separators=(',', ':')) + ';\n'
)

LOAD_FN_START = 'async function loadLocations(){'
if LOAD_FN_START not in html:
    print("ERROR: Could not find loadLocations() in index.html", file=sys.stderr)
    sys.exit(1)

start = html.index(LOAD_FN_START)
depth = 0
end = start
for i in range(start, len(html)):
    if html[i] == '{': depth += 1
    elif html[i] == '}':
        depth -= 1
        if depth == 0:
            end = i + 1
            break

new_fn = (
    embedded_js +
    '\nasync function loadLocations(){ '
    'return {locations: EMBEDDED_LOCATIONS, dataVersion: EMBEDDED_DATA_META.dataVersion, lastUpdated: EMBEDDED_DATA_META.lastUpdated}; '
    '}'
)
html = html[:start] + new_fn + html[end:]

html = html.replace(
    '<title>Aeolian Skipper \u2014 Decision Tool</title>',
    '<title>Aeolian Skipper \u2014 Decision Tool (Self-Contained)</title>'
)

with open(dist_out, 'w') as f:
    f.write(html)
with open(legacy_out, 'w') as f:
    f.write(html)

print(f"OK: {dist_out}")
print(f"OK: {legacy_out}")
print(f"  - {len(locations)} locations embedded")
print(f"  - data version: {data_version} • lastUpdated: {last_updated}")
print(f"  - {len(html.encode('utf-8')):,} bytes written")

checks = [
    ('EMBEDDED_LOCATIONS', 'EMBEDDED_LOCATIONS' in html),
    ('EMBEDDED_DATA_META', 'EMBEDDED_DATA_META' in html),
    ('BOAT_DRAFT', 'BOAT_DRAFT=2.20' in html),
    ('wind_speed_unit=kn', 'wind_speed_unit=kn' in html),
    ('CartoDB tiles', 'basemaps.cartocdn.com' in html),
    ('OpenSeaMap', 'openseamap.org' in html),
    ('validateLocations', 'function validateLocations' in html),
    ('buildForecastClusters', 'function buildForecastClusters' in html),
    ('ForecastBanner', 'function ForecastBanner' in html),
    ('APP_VERSION', "APP_VERSION='v" in html or 'APP_VERSION="v' in html),
]
all_ok = True
for name, ok in checks:
    status = 'OK' if ok else 'MISSING'
    if not ok: all_ok = False
    print(f"  - {status}: {name}")

if not all_ok:
    print("WARNING: Some checks failed — review the output file", file=sys.stderr)
    sys.exit(1)
PYEOF

echo "Build complete: $DIST_OUT (and $LEGACY_OUT)"
