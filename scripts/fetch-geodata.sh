#!/usr/bin/env bash
#
# Populate the PLACES calculation geodata cache.
#
# calculation.r reads 13 rasters/CSVs from /app/data. They are deliberately not in git (see
# README) — this fetches them into a cache outside the repo, which the compose stack mounts
# read-only and the k8s init container fetches the same way.
#
# Two sources, tried in order:
#
#   PLACES_GEODATA_URL   a .tar.gz containing the files (object storage / data release).
#                        This is the production path.
#   git history          the same files as committed before they were removed from
#                        kubernetes_deployment/assets. Enough to run the stack locally with
#                        no object storage at all, which is what makes the local test stack
#                        usable today.
#
# Cached under $PLACES_GEODATA (default /store/places/geodata). Skipped if already complete,
# so re-running is cheap and offline-safe once primed. Nothing lands in the repo.
#
# Env: PLACES_GEODATA, PLACES_GEODATA_URL, PLACES_GEODATA_REF
#
#   scripts/fetch-geodata.sh
set -euo pipefail

DEST="${PLACES_GEODATA:-/store/places/geodata}"
# The commit that removed the assets; its parent still has them.
REF="${PLACES_GEODATA_REF:-310fd46}"
cd "$(dirname "$0")/.."

# Exactly what calculation.r opens. Keep in step with it: the verify step below is the only
# thing standing between a missing input and a round that returns 200 with every score NaN.
FILES=(
  LU_and_NEW_hexa.tif
  Water_points_ID_raster.tif
  distance_weight_trace.tif
  soil_groups_hexa.tif
  gvg_hexa_raster.tif
  sensi_GW_patch.tif
  fix_nature_patches.tif
  fixed_HC_score.tif
  optimalHC_score.tif
  worstHC_score.tif
  trace.tif
  trace_numbers.csv
  buffer_list.csv
)

missing() {
  local m=()
  for f in "${FILES[@]}"; do [ -s "$DEST/$f" ] || m+=("$f"); done
  printf '%s\n' "${m[@]+"${m[@]}"}"
}

mkdir -p "$DEST"

if [ -z "$(missing)" ]; then
  echo ">> geodata already complete in $DEST (${#FILES[@]} files)"
  exit 0
fi

if [ -n "${PLACES_GEODATA_URL:-}" ]; then
  echo ">> fetching geodata from \$PLACES_GEODATA_URL"
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  curl -fsSL --retry 3 -o "$tmp/geodata.tar.gz" "$PLACES_GEODATA_URL"
  tar -xzf "$tmp/geodata.tar.gz" -C "$tmp"
  # Flatten: accept either a bare tarball or one with a top-level directory.
  find "$tmp" -type f \( -name '*.tif' -o -name '*.csv' \) -exec cp -n {} "$DEST/" \;
else
  echo ">> \$PLACES_GEODATA_URL is unset; recovering from git history at ${REF}^"
  echo "   (fine for local testing — set PLACES_GEODATA_URL for a real deployment)"
  git rev-parse --verify "${REF}^" >/dev/null 2>&1 || {
    echo "!! ${REF}^ is not in this clone. Fetch full history, or set PLACES_GEODATA_URL." >&2
    exit 1
  }
  for f in "${FILES[@]}"; do
    [ -s "$DEST/$f" ] && continue
    if git show "${REF}^:kubernetes_deployment/assets/$f" > "$DEST/$f" 2>/dev/null; then
      :
    else
      rm -f "$DEST/$f"   # do not leave a zero-byte file that looks present
    fi
  done
fi

# Verify. A partial cache is worse than an empty one: the calculation still returns 200 and
# still publishes rasters, it just scores everything NaN.
gone="$(missing)"
if [ -n "$gone" ]; then
  echo "!! geodata incomplete in $DEST — missing:" >&2
  printf '     %s\n' $gone >&2
  exit 1
fi

echo ">> geodata ready in $DEST"
du -sh "$DEST" | sed 's/^/   /'
