#!/usr/bin/env bash
# Smoke test for the PLACES frontend overlay: builds the thin image on an esgame base and checks it
# serves PLACES' config/data/map assets with CALC_URL injected at runtime. Dependency-light (docker
# + curl) so it runs anywhere.
#
#   test/smoke.sh                                                  # on the pinned esgame base
#   ESGAME_IMAGE=ghcr.io/mlacayoemery/esgame:master test/smoke.sh  # on esgame master: bump-safe?
#   ESGAME_IMAGE=local/esgame-core:latest test/smoke.sh           # on a local esgame build
#   PLACES_FRONTEND_IMAGE=ghcr.io/s-gebhardt/places-frontend:sha-… test/smoke.sh
#                                                     # a PUBLISHED image, as pulled — no build
set -euo pipefail

PORT="${PORT:-8186}"
NAME=places-smoke
cd "$(dirname "$0")/.."

# The default is the Dockerfile's own pin, read rather than repeated, so this tests what the
# image workflow builds unless told otherwise.
pinned=$(sed -n 's/^ARG ESGAME_IMAGE=//p' frontend/Dockerfile)
ESGAME_IMAGE="${ESGAME_IMAGE:-${pinned}}"

if [ -n "${PLACES_FRONTEND_IMAGE:-}" ]; then
  # The artefact a cluster will pull, not a rebuild of the same source: a build can pass here and
  # the push can still carry something else (a stale tag, the wrong platform, a missing layer).
  echo "pulling ${PLACES_FRONTEND_IMAGE}"
  docker pull -q "${PLACES_FRONTEND_IMAGE}" >/dev/null
  image="${PLACES_FRONTEND_IMAGE}"
else
  echo "building places-frontend FROM ${ESGAME_IMAGE}"
  # --pull is what makes this a test of a ROLLING tag rather than of whatever is cached here.
  # Without it, a machine holding a week-old ghcr.io/.../esgame:master builds on that and reports
  # PASS about an image nobody is running — which is exactly what happened on 2026-08-06: the
  # esgame base had moved to an unprivileged nginx on 8080 and this passed against a July 31
  # copy. The default base is pinned now, but ESGAME_IMAGE=…:master is how a bump is previewed.
  docker build -q --pull --build-arg ESGAME_IMAGE="${ESGAME_IMAGE}" -t places-frontend:smoke frontend >/dev/null
  echo "  base: $(docker image inspect "${ESGAME_IMAGE}" --format '{{index .RepoDigests 0}}' 2>/dev/null || echo "${ESGAME_IMAGE} (local, no digest)")"
  image=places-frontend:smoke
fi

docker rm -f "${NAME}" >/dev/null 2>&1 || true
# 8080, not 80: the esgame base runs nginx unprivileged as uid 101 (mlacayoemery/esgame#166).
docker run -d --name "${NAME}" -e CALC_URL=http://localhost:8000 -p "${PORT}:8080" "${image}" >/dev/null
trap 'docker rm -f "${NAME}" >/dev/null 2>&1 || true' EXIT
b="http://localhost:${PORT}"

# Poll rather than sleep-and-hope. A fixed sleep that is a little too short reads as "every asset
# is missing" — five FAILs that look like a broken overlay rather than a container still starting.
for _ in $(seq 1 30); do
  curl -fs -o /dev/null "$b/" && break
  sleep 1
done

fail=0
# Counted, not hand-tallied, and floored. Two failures in one: a number in a document drifts the
# moment a check is added inside a loop (upstream's ingress-test.sh said 16 while running 18), and
# a script whose every check is guarded by data it fetched will report PASS having run none of
# them if the fetch failed early. See mlacayoemery/esgame#173.
checks=0
passed=0
check() {
  checks=$((checks + 1))
  if eval "$2" >/dev/null 2>&1; then passed=$((passed + 1)); echo "  ok   $1"; else echo "  FAIL $1"; fail=1; fi
}

check "CALC_URL injected into config.json"        "curl -fs $b/assets/config.json | grep -q 'localhost:8000'"
check "defaultMode is dynamic (lands on the game)" "curl -fs $b/assets/config.json | grep -q '\"defaultMode\".*\"dynamic\"'"
check "data.json is PLACES (title V.2!)"           "curl -fs $b/assets/data.json | grep -q 'Agriculture Edition V.2'"
check "data.json carries visualOptions"            "curl -fs $b/assets/data.json | grep -q 'visualOptions'"
check "place-specific map TIFF is served"          "curl -fs -o /dev/null $b/assets/images/suit_arable_ext_norm2.tif"
# Not "some uid that isn't 0": the number the esgame base's Deployment asserts with runAsUser. An
# image that runs as anything else serves fine here and is refused by the kubelet on a cluster.
check "runs as uid 101, as the Deployment asserts" "[ \"\$(docker exec ${NAME} id -u)\" = 101 ]"
# The compose stack passes ESGAME_IMAGE explicitly, so it builds on its own default rather than on
# the Dockerfile's — two pins that drift apart silently, since each still builds.
check "compose builds on the Dockerfile's pin"     "grep -qF 'ESGAME_IMAGE:-${pinned}}' deploy/compose/docker-compose.places.yml"

# The frontend validates its data file at run time (see mlacayoemery/esgame#154), so a value it
# does not recognise means a console error and a silent fallback for whoever opens the game. The
# names come from esgame's DefaultGradients, plus "custom" — the marker a map uses to say its
# colours come from customColorId, which this file's Background map does.
#
# That marker being mistaken for a typo is not hypothetical: it was, upstream, and every load of
# the game logged an error about a correct configuration until esgame#161.
echo "==> gradients the frontend will recognise"
# `|| true` on the parse: when the frontend is not serving, curl hands python an empty stdin and
# json.load raises, which under `set -e` printed a 20-line traceback over the check output. The
# checks below already report the empty result properly; a stack trace only hides them.
grads=$(curl -fs "$b/assets/data.json" 2>/dev/null | python3 -c "
import json,sys
print(' '.join(sorted({m.get('gradient') for m in json.load(sys.stdin).get('maps',[]) if m.get('gradient')})))" 2>/dev/null || true)
echo "    ${grads:-<none>}"
known="blue green orange purple red yellow custom"
bad=""
for g in ${grads}; do case " ${known} " in *" ${g} "*) ;; *) bad="${bad} ${g}";; esac; done
# Presence first: an empty list would validate nothing and report success.
check "data.json names some gradients"            "[ -n '${grads}' ]"
check "every gradient is one the frontend knows"  "[ -z '${bad}' ]"
[ -n "${bad}" ] && echo "    unknown:${bad} (known: ${known})"

if [ "${checks}" -lt 5 ]; then
  echo "PLACES overlay smoke test: FAIL   only ${checks} checks ran; this file covers more than that"
  exit 1
fi
if [ "${fail}" = 0 ]; then
  echo "PLACES overlay smoke test: PASS   ${passed}/${checks} checks"
else
  echo "PLACES overlay smoke test: FAIL   ${passed}/${checks} checks"; exit 1
fi
