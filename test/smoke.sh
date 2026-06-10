#!/usr/bin/env bash
# Smoke test for the PLACES frontend overlay: builds the thin image on an esgame base and checks it
# serves PLACES' config/data/map assets with CALC_URL injected at runtime. Dependency-light (docker
# + curl) so it runs anywhere.
#
#   ESGAME_IMAGE=local/esgame-core:latest test/smoke.sh     # against a local esgame build
#   test/smoke.sh                                            # against ghcr.io/.../esgame:master
set -euo pipefail

ESGAME_IMAGE="${ESGAME_IMAGE:-ghcr.io/mlacayoemery/esgame:master}"
PORT="${PORT:-8186}"
NAME=places-smoke
cd "$(dirname "$0")/.."

echo "building places-frontend FROM ${ESGAME_IMAGE}"
docker build -q --build-arg ESGAME_IMAGE="${ESGAME_IMAGE}" -t places-frontend:smoke frontend >/dev/null

docker rm -f "${NAME}" >/dev/null 2>&1 || true
docker run -d --name "${NAME}" -e CALC_URL=http://localhost:8000 -p "${PORT}:80" places-frontend:smoke >/dev/null
trap 'docker rm -f "${NAME}" >/dev/null 2>&1 || true' EXIT
sleep 2
b="http://localhost:${PORT}"

fail=0
check() { if eval "$2" >/dev/null 2>&1; then echo "  ok   $1"; else echo "  FAIL $1"; fail=1; fi; }

check "CALC_URL injected into config.json"        "curl -fs $b/assets/config.json | grep -q 'localhost:8000'"
check "defaultMode is dynamic (lands on the game)" "curl -fs $b/assets/config.json | grep -q '\"defaultMode\".*\"dynamic\"'"
check "data.json is PLACES (title V.2!)"           "curl -fs $b/assets/data.json | grep -q 'Agriculture Edition V.2'"
check "data.json carries visualOptions"            "curl -fs $b/assets/data.json | grep -q 'visualOptions'"
check "place-specific map TIFF is served"          "curl -fs -o /dev/null $b/assets/images/suit_arable_ext_norm2.tif"

if [ "${fail}" = 0 ]; then echo "PLACES overlay smoke test: PASS"; else echo "PLACES overlay smoke test: FAIL"; exit 1; fi
