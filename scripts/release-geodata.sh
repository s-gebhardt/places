#!/usr/bin/env bash
#
# Publish the PLACES calculation geodata as a GitHub release asset: the tarball the load-geodata
# init container downloads (deploy/k8s) from the URL in the places-geodata-source
# Secret.
#
#   scripts/release-geodata.sh               # pack, verify, publish; prints the URL for the Secret
#   scripts/release-geodata.sh --pack-only   # pack and verify, publish nothing
#
# NAMED BY CONTENT. The release tag is geodata-<first 12 hex of the tarball's sha256>, and the
# tarball is byte-reproducible (sorted, fixed owner/mode/mtime, gzip -n). So the same thirteen
# files always give the same URL, re-running once published is a no-op, and a URL already in a
# cluster's Secret cannot start serving different data underneath it: new data is a new release
# and a new URL, changed on purpose. The tag does not start with v, so it publishes no images.
#
# Public on purpose: the repository is public and these files are already recoverable from its
# git history (that is where scripts/fetch-geodata.sh gets them), so this exposes nothing new.
#
# Env: PLACES_GEODATA      the cache to pack (default /store/places/geodata; filled if short)
#      PLACES_REPO         owner/name to publish to (default: this checkout's GitHub repository)
#      PLACES_GEODATA_OUT  where the tarball is left (default a directory under $TMPDIR)
#
# Needs GNU tar, python3 with Pillow (for the board check), and gh logged in with write access.
set -euo pipefail
cd "$(dirname "$0")/.."

publish=1
case "${1:-}" in
  --pack-only) publish=0 ;;
  "") ;;
  *) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac

DEST="${PLACES_GEODATA:-/store/places/geodata}"
OUT="${PLACES_GEODATA_OUT:-${TMPDIR:-/tmp}/places-geodata-release}"
TARBALL="${OUT}/places-geodata.tar.gz"

# The file list is scripts/fetch-geodata.sh's, read rather than repeated — it is the one the
# comment there says to keep in step with calculation.r. 13 is floored because a sed that stops
# matching would otherwise pack nothing and verify nothing, successfully.
mapfile -t FILES < <(sed -n '/^FILES=($/,/^)$/{/^FILES=($/d;/^)$/d;s/^[[:space:]]*//;s/[[:space:]]*$//;/^$/d;p}' \
  scripts/fetch-geodata.sh)
[ "${#FILES[@]}" -eq 13 ] || {
  echo "!! read ${#FILES[@]} file names from scripts/fetch-geodata.sh, expected 13" >&2; exit 1; }

# Idempotent: exits at once when the cache is complete, fills it (from PLACES_GEODATA_URL or this
# repository's history) when it is not, and fails when it cannot — never packs a partial set.
PLACES_GEODATA="${DEST}" scripts/fetch-geodata.sh

# THE BOARD CHECK. A LU_and_NEW_hexa.tif that does not carry the board's hexagon ids does not
# fail anything: the round returns 200 with finite scores and ignores the player's allocation
# almost entirely (the pre-#181 copy matched 4 of 465 — see the README). So before this becomes
# the URL a cluster loads from, require every hexagon id of the board the frontend draws
# (frontend/assets/images/New_hexagons.tif) to be a value in the raster the calculation scores.
echo ">> checking LU_and_NEW_hexa.tif against the board the frontend draws"
python3 - "${DEST}/LU_and_NEW_hexa.tif" frontend/assets/images/New_hexagons.tif <<'PY'
import sys, warnings
try:
    from PIL import Image
except ImportError:
    sys.exit("!! python3 cannot import PIL; install Pillow (python3 -m pip install pillow)")
warnings.simplefilter('ignore')
def values(path):
    im = Image.open(path)
    data = getattr(im, 'get_flattened_data', im.getdata)()
    # Nodata is -9999 in these rasters; ids and land-use codes are positive.
    return {v for v in data if v == v and v > 0}
lu, board = values(sys.argv[1]), values(sys.argv[2])
if not board:
    sys.exit("!! read no hexagon ids from the board raster; this check would check nothing")
missing = sorted(board - lu)
print(f"   {len(board) - len(missing)} of {len(board)} board ids are in the calculation's raster")
if missing:
    sys.exit(f"!! {len(missing)} board ids missing, e.g. {missing[:5]} — this is not the board-matching raster")
PY

echo ">> packing ${#FILES[@]} files from ${DEST}"
mkdir -p "${OUT}"
work=$(mktemp -d); trap 'rm -rf "${work}"' EXIT
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime=@0 --mode='u=rw,go=r' \
  -C "${DEST}" -cf - "${FILES[@]}" | gzip -9n > "${TARBALL}"

# Verify the ARTEFACT, not the inputs: exactly the thirteen names, flat (the init container
# flattens, but nothing should need it to), and every file byte-identical to the cache.
tar -tzf "${TARBALL}" | sort > "${work}/members"
printf '%s\n' "${FILES[@]}" | sort > "${work}/expected"
diff -u "${work}/expected" "${work}/members" >&2 || {
  echo "!! the tarball does not hold exactly the ${#FILES[@]} geodata files" >&2; exit 1; }
mkdir "${work}/x"; tar -xzf "${TARBALL}" -C "${work}/x"
for f in "${FILES[@]}"; do
  cmp -s "${DEST}/${f}" "${work}/x/${f}" || { echo "!! ${f} differs after a round trip" >&2; exit 1; }
done

sha=$(sha256sum "${TARBALL}" | cut -d' ' -f1)
tag="geodata-${sha:0:12}"
echo ">> ${TARBALL}  ($(du -h "${TARBALL}" | cut -f1), sha256 ${sha})"

if [ "${publish}" = 0 ]; then
  echo ">> --pack-only: would publish as release ${tag}"
  exit 0
fi

command -v gh >/dev/null || { echo "!! gh not on PATH" >&2; exit 2; }
REPO="${PLACES_REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
url="https://github.com/${REPO}/releases/download/${tag}/places-geodata.tar.gz"

if gh release view "${tag}" -R "${REPO}" >/dev/null 2>&1; then
  echo ">> release ${tag} already exists on ${REPO}; checking it holds these bytes"
else
  echo ">> creating release ${tag} on ${REPO}"
  # --latest=false: this is data, and the project's "Latest" release should stay a version of
  # the software rather than whichever geodata upload happened most recently.
  gh release create "${tag}" "${TARBALL}" -R "${REPO}" --latest=false \
    --title "PLACES geodata ${sha:0:12}" --notes-file - <<NOTES
The ${#FILES[@]} reference rasters/CSVs the PLACES calculation reads from \`/app/data\`, for the
\`load-geodata\` init container (deploy/k8s). Packed by \`scripts/release-geodata.sh\`.

sha256 \`${sha}\`

\`\`\`sh
kubectl -n places create secret generic places-geodata-source --from-literal=url='${url}'
\`\`\`

$(printf -- '- `%s`\n' "${FILES[@]}")
NOTES
fi

# The acceptance test is the init container's own: an ANONYMOUS download of that URL, following
# GitHub's redirect, giving these exact bytes. A release that exists but serves something else
# (replaced by hand, or a private repository) fails here rather than in a pod on a cluster.
got=$(curl -fsSL --retry 3 "${url}" | sha256sum | cut -d' ' -f1)
if [ "${got}" != "${sha}" ]; then
  echo "!! ${url}" >&2
  echo "   serves sha256 ${got:-<nothing>}, expected ${sha}" >&2
  exit 1
fi

echo ">> published and verified by anonymous download:"
echo "   ${url}"
echo "   point a cluster at it:"
echo "     kubectl -n places create secret generic places-geodata-source --from-literal=url='${url}'"
