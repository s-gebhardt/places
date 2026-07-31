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

# The frontend validates its data file at run time (see mlacayoemery/esgame#154), so a value it
# does not recognise means a console error and a silent fallback for whoever opens the game. The
# names come from esgame's DefaultGradients, plus "custom" — the marker a map uses to say its
# colours come from customColorId, which this file's Background map does.
#
# That marker being mistaken for a typo is not hypothetical: it was, upstream, and every load of
# the game logged an error about a correct configuration until esgame#161.
echo "==> gradients the frontend will recognise"
grads=$(curl -fs "$b/assets/data.json" | python3 -c "
import json,sys
print(' '.join(sorted({m.get('gradient') for m in json.load(sys.stdin).get('maps',[]) if m.get('gradient')})))")
echo "    ${grads:-<none>}"
known="blue green orange purple red yellow custom"
bad=""
for g in ${grads}; do case " ${known} " in *" ${g} "*) ;; *) bad="${bad} ${g}";; esac; done
# Presence first: an empty list would validate nothing and report success.
check "data.json names some gradients"            "[ -n '${grads}' ]"
check "every gradient is one the frontend knows"  "[ -z '${bad}' ]"
[ -n "${bad}" ] && echo "    unknown:${bad} (known: ${known})"

if [ "${fail}" = 0 ]; then echo "PLACES overlay smoke test: PASS"; else echo "PLACES overlay smoke test: FAIL"; exit 1; fi
