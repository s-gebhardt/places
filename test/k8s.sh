#!/usr/bin/env bash
# Renders the PLACES Kustomize overlay and checks it actually produces PLACES.
#
# This exists because it silently did not. The overlay keyed its `images:` entries on the
# esgame base's LOGICAL names (esgame-angular / esgame-calculation). Kustomize applies the
# base's own images transformer first, so those names are already gone by the time the
# overlay runs: the entries matched nothing, nothing warned, and the overlay rendered
# cleanly while deploying the UPSTREAM esgame images instead of PLACES'.
#
# test/smoke.sh covers the frontend Docker overlay; this covers the k8s one.
#
#   test/k8s.sh
#
# Needs kustomize on PATH. kubeconform is used if present, skipped if not.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v kustomize >/dev/null || { echo "kustomize not on PATH"; exit 2; }

echo "rendering deploy/k8s (fetches the esgame base by ref)"
rendered=$(mktemp); trap 'rm -f "${rendered}"' EXIT
kustomize build deploy/k8s > "${rendered}"

fail=0
check() { if eval "$2" >/dev/null 2>&1; then echo "  ok   $1"; else echo "  FAIL $1"; fail=1; fi; }

images=$(grep -E '^\s+image:' "${rendered}" | awk '{print $2}')

# The point of the overlay: PLACES images, not the upstream ones.
check "frontend is the PLACES image"        "grep -q 'places-frontend' <<<\"\${images}\""
check "calculation is the PLACES image"     "grep -q 'places-calculation' <<<\"\${images}\""
check "no upstream esgame image remains"    "! grep -qE 'ghcr\.io/mlacayoemery/esgame(-calculation)?:' <<<\"\${images}\""

# The base should still supply GeoServer, pinned rather than rolling.
check "GeoServer comes from the base"       "grep -q 'docker.osgeo.org/geoserver:' <<<\"\${images}\""
check "GeoServer is not a rolling tag"      "! grep -qE 'geoserver:[0-9]+\.[0-9]+\.x' <<<\"\${images}\""

# The overlay's own additions.
check "PVC for the geodata is present"      "grep -q 'kind: PersistentVolumeClaim' '${rendered}'"
check "ingress hosts are PLACES hosts"      "[ \"\$(grep -cE '^\s+- host: .*places' '${rendered}')\" -eq 3 ]"

if command -v kubeconform >/dev/null; then
  check "manifests are schema-valid"        "kubeconform -strict -kubernetes-version 1.31.0 '${rendered}'"
else
  echo "  skip kubeconform not installed"
fi

if [ "${fail}" = 0 ]; then echo "PLACES k8s overlay test: PASS"; else echo "PLACES k8s overlay test: FAIL"; exit 1; fi
