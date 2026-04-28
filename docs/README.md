# Aeolian Islands Skipper Decision Tool

**Boat:** Jeanneau Sun Odyssey 440, 4-cabin, 2019 (draft 2.20m)
**Base:** Capo d'Orlando Marina
**Trip:** 6-day sailing (Sat check-in, Sun departure, Fri return)

## What Was Built

An interactive skipper decision-support tool for real-time sailing decisions in the Aeolian Islands. There are now three artefacts, but only two source files:

| File | Role |
|------|------|
| `index.html` | **Source.** Runtime app that fetches `data/locations.json` over HTTP. Edit this. |
| `data/locations.json` | **Source of truth** for all 30 locations + data `version` / `lastUpdated`. Edit this. |
| `docs/index.html` | **Generated.** Self-contained build for GitHub Pages — locations + meta embedded. Do not edit. |
| `aeolian-skipper-tool.html` | **Generated.** Identical content, kept at the repo root as a single-file copy you can email / Dropbox to crew. Do not edit. |

The header shows the current `App vX.Y` and the data file's `lastUpdated` so crew can confirm which version they are looking at.

All artefacts fetch live weather forecasts from the Open-Meteo API and map tiles from CartoDB / OpenSeaMap, so an internet connection is required at use time. There is no offline-cache support — closing the tab and reopening it without internet will fail. True reload-safe offline support would require a service worker, which has not been added yet.

### Features

**Dashboard** — Live wind conditions (current, +12h, +24h, +48h trends), best stops ranked by real-time suitability, quick stats.

**Route Planner** — 6-day itinerary builder (Sun–Fri) with Plan A / Plan B support. Each stop shows leg distance (nm), ETA at 5.5kt and 6.5kt, suitability status, depth/draft warnings, and route warnings (long legs, exposed destinations, settled-weather-only stops, nearest fallback). Route selections sync with the Map view.

**Map View** — Leaflet interactive map with CartoDB Voyager base tiles and OpenSeaMap seamark overlay. Markers color-coded by suitability. Click any marker for full details. Active route drawn as dashed polylines.

**Locations** — Filterable directory of all 30 stops with expandable detail cards. Filters: island, type, wind protection direction, overnight safe, settled weather, fuel, water, electricity, safe depth, fallback value, suitability (now/tomorrow).

**Compare** — Select 2–4 locations for side-by-side comparison.

### Decision Engine

The suitability engine evaluates each location against clustered live forecasts:

- Locations are grouped into forecast clusters by geographic proximity (≤3nm radius). Each cluster gets its own API call using its centroid coordinates. With 30 locations this produces 8 clusters — one per island group. The cluster centroid is the coordinates of the first location assigned to each cluster.
- Fetches wind speed, direction, gusts from Open-Meteo `/v1/forecast` (knots), and marine data (wave height, swell) from `/v1/marine`, per cluster.
- Score-based system (0–100) with penalties for: wind exposure, high gusts (>25kt, >30kt), wave height (>1.5m, >2.5m), settled-weather-only conditions, non-overnight locations, difficult approaches, ferry wake, and draft/depth clearance.
- Draft awareness: 2.20m draft + 0.50m safety margin = 2.70m minimum safe depth. Locations with shallow spots are flagged with guidance.
- Status thresholds: Good (70+), Caution (45–69), Poor (20–44), Avoid (<20).

### Forecast Failure Handling

A status banner below the header shows:
- **Live forecast** — all clusters fetched successfully
- **Partial forecast** — some clusters failed (affected locations show "No forecast")
- **Forecast unavailable** — all calls failed (suitability is not live)

The banner shows the last successful refresh timestamp and a retry button.

### Schema Validation

On startup, `locations.json` is validated before use:
- Required fields and types
- Enum values (type, holdingQuality, approachDifficulty, confidence, fallbackValue)
- Coordinate bounds (Aeolian range)
- Duplicate IDs
- Depth consistency
- Service object completeness
- Validation report logged to browser console
- Invalid records with minimum shape (id, coordinates, name) are still rendered; completely broken records are dropped

## How to Run Locally

The runtime `index.html` cannot be opened with `file://` because it fetches `data/locations.json`. Use the helper to start a local server:

```bash
bash serve.sh
# Then open http://localhost:8080
```

That serves the source app exactly as it will behave when developing.

If you only want to view the deploy output, open `docs/index.html` (or `aeolian-skipper-tool.html`) directly in a browser — those have the data embedded, so no server is needed.

## How to Rebuild

After editing `index.html` or `data/locations.json`, regenerate the self-contained outputs:

```bash
bash build.sh
```

This reads `index.html` + `data/locations.json` and writes:

- `docs/index.html` — the GitHub Pages deploy target
- `aeolian-skipper-tool.html` — identical single-file copy for emailing / Dropbox

Both files contain `EMBEDDED_LOCATIONS` and `EMBEDDED_DATA_META`. The script runs sanity checks and exits non-zero if anything looks wrong.

**Always run `bash build.sh` after editing `index.html` or `data/locations.json`. Never hand-edit `docs/index.html` or `aeolian-skipper-tool.html` — your changes will be overwritten.**

## Deploying to GitHub Pages

The `docs/` folder is the deploy target. GitHub Pages only allows publishing from `/` or `/docs` on a branch, which is why the build output lives in `docs/`.

**Setup (one time):**

1. Push the repo to GitHub.
2. Repo Settings → Pages → Build and deployment → Source: *Deploy from a branch*.
3. Branch: `main`, Folder: `/docs`. Save.
4. Wait for the Pages build; Pages will serve `docs/index.html` as the site root.

`docs/README.md` lives in the same folder but is ignored by Pages (Pages always serves `index.html` as the landing page).

After every change to `index.html` or `data/locations.json`, re-run `bash build.sh` and commit the regenerated `docs/index.html` so Pages picks it up.

> Reminder: Pages serves over HTTPS, but the app calls Open-Meteo and CartoDB / OpenSeaMap directly — those are HTTPS already, so there is no mixed-content issue. Without internet, the page will load the UI but show no forecast and no map tiles.

## Data Schema

Each location in `data/locations.json` includes:

| Field | Type | Description |
|-------|------|-------------|
| id | string | Unique identifier |
| island | string | Island name |
| name | string | Location name |
| type | string | marina / port / buoy_field / anchorage |
| description | string | Short practical description |
| coordinates | {lat, lng} | WGS84 coordinates |
| navilyUrl | string/null | Navily source link |
| navilyRating | number/null | Navily rating if available |
| windProtection | object | protectedFrom[], exposedTo[], description |
| depth | {min, max} | Depth range in meters |
| bottomType | string | Sand, rock, volcanic, posidonia, etc. |
| holdingQuality | string | excellent / good / moderate / poor / unknown |
| overnightRecommended | boolean | Safe for overnight stays |
| settledWeatherOnly | boolean | Requires calm conditions |
| approachDifficulty | string | easy / moderate / difficult |
| hazards | string[] | List of hazards/cautions |
| ferryWakeSurge | boolean | Affected by ferry wash |
| services | object | fuel, water, electricity, provisions, restaurants, townAccess, shower, wifi |
| confidence | string | Data confidence: high / medium / low |
| tags | string[] | Filterable tags |
| fallbackValue | string | Utility as bad-weather refuge: high / medium / low / none |
| notes | string | Additional raw notes |

## How to Update or Add Locations

### Adding a new location:
1. Add to `data/locations.json` following the schema above
2. Run `bash build.sh` to regenerate the self-contained version
3. Set `confidence: "low"` until verified

### Updating existing data:
1. Edit `data/locations.json` (the source of truth)
2. Run `bash build.sh`
3. Update the `confidence` field if verification improves

## Limitations

1. **Clustered forecasts** — Weather is fetched per geographic cluster (3nm radius), not per-location. With 30 locations this produces 8 clusters (one per island group). Nearby locations share one forecast. This does not model hyper-local effects like wind acceleration through channels.
2. **No tide/current data** — Tidal range is minimal in the Tyrrhenian, but currents between islands (especially Lipari–Vulcano strait) are not modeled.
3. **Suitability is advisory** — The tool provides guidance, not safety guarantees. Always check official marine forecasts and use skipper judgment.
4. **Depth data from databases** — Min/max depths are from published sources. Always verify with charts and sonar when approaching.

## File Structure

```
Sailing Sicily/
  index.html                   — Source app (loads from JSON, needs HTTP server)
  build.sh                     — Regenerates docs/ + legacy file from sources
  serve.sh                     — Helper: python3 -m http.server 8080
  .gitignore                   — Keeps docs/ tracked, ignores .DS_Store, raw notes
  docs/
    index.html                 — GENERATED — deploy target for GitHub Pages
    README.md                  — This file
  aeolian-skipper-tool.html    — GENERATED — single-file copy for sharing
  data/
    locations.json             — Source of truth: 30 locations + version + lastUpdated
    raw-research-notes.json    — Research sources and raw notes (gitignored, local-only)
```

## Research Sources

- CruisersWiki: https://www.cruiserswiki.org/wiki/Aeolian_Islands
- Capo d'Orlando Marina: https://www.capodorlandomarina.it/en/territorio/aeolian-islands/
- Porto Pignataro: https://www.portopignataro.it/en/
- Open-Meteo weather API: https://open-meteo.com/en/docs
