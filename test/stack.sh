#!/usr/bin/env bash
# End-to-end test of the local PLACES compose stack: brings up frontend + calculation + geoserver,
# plays a real round, and checks the result is genuinely usable rather than merely HTTP 200.
#
# That distinction is the whole point. Every failure this stack has had was silent:
#   - /app/data empty          -> 200, coverages published, every score NaN
#   - all 472 raster ids sent  -> 200, coverages published, every score NaN
#   - geosapi missing          -> container installs it from GitHub HEAD on every boot
#   - WCS URLs built from the in-network GeoServer name -> 200, URLs no browser can resolve
# So this asserts on scores, on the published coverages actually returning GeoTIFFs, and on the
# returned URLs being fetchable from OUTSIDE the compose network — from here, like a browser.
#
#   test/stack.sh                       # ports 8186/8100/8180 by default
#   PLACES_GEOSERVER_PORT=9080 test/stack.sh
#
# Needs docker + curl + python3, and the geodata cache (scripts/fetch-geodata.sh). Leaves the stack
# running on success so you can open the frontend; `test/stack.sh --down` tears it down.
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT=places-test
COMPOSE_FILE=deploy/compose/docker-compose.places.yml
# Off the default ports: this is a test stack and 8080 is usually already taken.
export PLACES_FRONTEND_PORT="${PLACES_FRONTEND_PORT:-8186}"
export PLACES_CALC_PORT="${PLACES_CALC_PORT:-8100}"
export PLACES_GEOSERVER_PORT="${PLACES_GEOSERVER_PORT:-8180}"
# The browser-facing addresses must match the ports actually published above -- and CALC_URL must
# carry the calculator's ROUTE, not just its host and port. calculation/calculation.r serves
# `#* @post /esgame` and the frontend posts to this URL verbatim, so a pathless value 404s on every
# round. This harness stood the frontend up with one, and then played its round against a URL it
# built itself, so nothing here could notice. Same defect as the compose default (fixed in 703fe43)
# and as upstream esgame's (mlacayoemery/esgame#254).
export CALC_URL="http://localhost:${PLACES_CALC_PORT}/esgame"
export GEOSERVER_PUBLIC_URL="http://localhost:${PLACES_GEOSERVER_PORT}/geoserver"

# A NON-DEFAULT GeoServer password, on purpose. Two checks below depend on it and both were
# vacuous without it: with the password left at "geoserver", "the default password is not in
# use" short-circuits to true and asserts nothing, while "REST answers with our credentials"
# only proves the image's built-in login works. Generating one here makes both real, and makes
# the round prove the calculation can publish against a GeoServer that is not on its defaults —
# which is what any deployment looks like.
export GEOSERVER_PASSWORD="${GEOSERVER_PASSWORD:-stacktest-$(head -c 9 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')}"

dc() { docker compose -p "${PROJECT}" -f "${COMPOSE_FILE}" "$@"; }

if [ "${1:-}" = "--down" ]; then dc down -v; exit 0; fi

command -v python3 >/dev/null || { echo "python3 not on PATH"; exit 2; }

GEODATA="${PLACES_GEODATA:-/store/places/geodata}"
if [ ! -s "${GEODATA}/LU_and_NEW_hexa.tif" ]; then
  echo "no geodata in ${GEODATA} — run scripts/fetch-geodata.sh first"; exit 2
fi

echo "==> bringing up the stack (${PROJECT})"
dc up -d --build

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

# --- the loader ran and left a complete /app/data -------------------------------------------
# depends_on: service_completed_successfully means a non-zero exit here blocks the calculation,
# so reaching this point at all is part of the assertion.
loader_log="$(dc logs places-geodata-loader 2>&1 || true)"
check "geodata loader reported ready"  "grep -q 'geodata ready' <<<\"\${loader_log}\""
check "geodata loader did not error"   "! grep -q 'incomplete' <<<\"\${loader_log}\""
check "calculation sees all 13 inputs" \
  "[ \"\$(dc exec -T places-calculation sh -c 'ls /app/data/*.tif /app/data/*.csv 2>/dev/null | wc -l')\" -ge 13 ]"

# --- the calculation starts without reaching the internet ------------------------------------
# It used to remotes::install_github('eblondel/geosapi') on every boot. Dependencies belong in
# the image, so a fresh container must not fetch anything.
echo "==> waiting for plumber"
for i in $(seq 1 60); do
  dc logs places-calculation 2>&1 | grep -q 'Running plumber API' && break
  sleep 2
done
calc_log="$(dc logs places-calculation 2>&1 || true)"
check "plumber is listening"                     "grep -q 'Running plumber API' <<<\"\${calc_log}\""
check "calculation does not install at run time" "! grep -qi 'Downloading GitHub repo' <<<\"\${calc_log}\""
# The startup banner is also where a missing library() shows up, and plumber exits on it.
check "no R error during startup"                "! grep -qE 'there is no package called' <<<\"\${calc_log}\""

echo "==> waiting for GeoServer"
for i in $(seq 1 90); do
  curl -fs -u "${GEOSERVER_USER:-admin}:${GEOSERVER_PASSWORD:-geoserver}" \
    "http://localhost:${PLACES_GEOSERVER_PORT}/geoserver/rest/about/version.json" >/dev/null 2>&1 && break
  sleep 2
done
check "GeoServer REST answers with our credentials" \
  "curl -fs -u '${GEOSERVER_USER:-admin}:${GEOSERVER_PASSWORD:-geoserver}' 'http://localhost:${PLACES_GEOSERVER_PORT}/geoserver/rest/about/version.json'"
# If the image had ignored GEOSERVER_ADMIN_PASSWORD, the built-in login would still work.
# Meaningful only because the password above is not the default one — see the note there.
check "GeoServer default password is rejected" \
  "! curl -fs -u admin:geoserver 'http://localhost:${PLACES_GEOSERVER_PORT}/geoserver/rest/about/version.json'"

# --- the frontend overlay -------------------------------------------------------------------
fe="http://localhost:${PLACES_FRONTEND_PORT}"
check "frontend serves"                   "curl -fs ${fe}/ -o /dev/null"
# Bodies captured first, NOT piped into `grep -q`. grep -q exits the moment it matches, curl
# then fails writing the rest and, with `set -o pipefail` (line 18), the pipeline reports the
# check as failed — precisely BECAUSE the pattern matched. Whether it bites depends on whether
# curl finishes writing before grep exits, which is what makes it look intermittent.
#
# Hardening, not a fix for something observed: this did bite esgame's ingress-test.sh and is
# documented there, but five attempts against these two files (14KB) did not reproduce it. The
# shape is here, the bodies are just small enough today.
cfg_body=$(curl -fs "${fe}/assets/config.json" || true)
data_body=$(curl -fs "${fe}/assets/data.json" || true)
check "CALC_URL injected at run time"     "grep -q ':${PLACES_CALC_PORT}' <<<\"\${cfg_body}\""
check "frontend is PLACES, not upstream"  "grep -q 'Agriculture Edition V.2' <<<\"\${data_body}\""

# --- a real round ---------------------------------------------------------------------------
# The ids are read out of LU_and_NEW_hexa.tif rather than assumed. They are NOT a contiguous
# range: the raster carries 472 distinct values, the 7 fixed landscape features 2-8 plus 465
# board hexagons numbered in hundreds (100, 200, … 46500). Allocating the 7 fixed features still
# returns 200 and still publishes rasters, but scores every indicator NaN — see the README.
echo "==> reading the board id space from LU_and_NEW_hexa.tif"
dc exec -T places-calculation R -q -e '
  suppressMessages(library(raster))
  v <- sort(unique(na.omit(values(raster("/app/data/LU_and_NEW_hexa.tif")))))
  cat("IDS:", paste(v[v >= 9], collapse = ","), "\n")' 2>/dev/null \
  | tr -d '\r' | sed -n 's/^IDS: //p' | tr -d ' ' > /tmp/places-ids.txt
board_n=$(tr ',' '\n' < /tmp/places-ids.txt | grep -c .)
echo "    ${board_n} board ids"
check "read 465 board ids from the raster" "[ '${board_n}' = '465' ]"

# The count alone does not identify the raster, it only happens to differ. The contract is the
# ID SPACE: the board numbers its hexagons in hundreds (100, 200 … 46500), and the copy shipped
# in the frontend assets numbers a different set 10-474. Measured 2026-07-31:
#
#   frontend copy   455 ids   min 10    max 474      multiples of 100: no
#   data release    465 ids   min 100   max 46500    multiples of 100: yes
#
# Mount the wrong one and every check here still passes: the round returns 200, publishes all
# its coverages, and scores an allocation it has almost entirely ignored. This is the check that
# tells them apart for the reason that matters rather than by a coincidence of counting.
id_min=$(tr ',' '\n' < /tmp/places-ids.txt | sort -n | head -1)
id_max=$(tr ',' '\n' < /tmp/places-ids.txt | sort -n | tail -1)
in_hundreds=$(tr ',' '\n' < /tmp/places-ids.txt | awk 'NF && $1 % 100 != 0 {bad++} END {print bad+0}')
echo "    id space: ${id_min}..${id_max}, ${in_hundreds} not a multiple of 100"
check "board ids are the data-release id space" \
  "[ -n '${id_min}' ] && [ '${in_hundreds}' = '0' ] && [ '${id_max}' -gt '10000' ]"

# allocation is an ARRAY OF OBJECTS {id, lulc} — jsonlite turns that into the two-column
# reclassification matrix raster::reclassify wants. An id-keyed object instead fails with
# "comparison of these types is not implemented" and a 500.
echo "==> playing a round"
python3 - /tmp/places-ids.txt > /tmp/places-payload.json <<'PY'
import json, sys
ids = [int(x) for x in open(sys.argv[1]).read().strip().split(',') if x]
types = [10, 20, 30, 40, 50, 60]          # places' productionTypes
alloc = [{"id": i, "lulc": types[n % len(types)]} for n, i in enumerate(ids)]
json.dump({"game_id": 1, "round": 1, "score": 42, "allocation": alloc}, sys.stdout)
PY
check "payload has 465 hexagons, none fixed" \
  "python3 -c \"
import json,sys
a=json.load(open('/tmp/places-payload.json'))['allocation']
sys.exit(0 if len(a)==465 and not [x for x in a if x['id']<9] else 1)\""

start=$(date +%s)
http=$(curl -s -o /tmp/places-round.json -w '%{http_code}' -m 900 \
  -X POST -H 'Content-Type: application/json' \
  --data @/tmp/places-payload.json "http://localhost:${PLACES_CALC_PORT}/esgame" || echo 000)
echo "    POST /esgame -> ${http} in $(( $(date +%s) - start ))s"
check "round returns 200"  "[ '${http}' = '200' ]"

# The scores are the point. A round that returns 200 with NaN everywhere is the failure mode this
# whole file exists to catch, so assert they are finite numbers. Six indicators carry a `score`;
# the seventh result is the spider-plot PNG (id -1), which has none by design.
python3 - /tmp/places-round.json > /tmp/places-summary.txt <<'PY' || true
import json, sys, math
rows = json.load(open(sys.argv[1]))["results"]
scored, urls = 0, []
for it in rows:
    name, sid, url = it.get("name", ""), it.get("id"), it.get("url")
    if url: urls.append(str(url))
    if sid == -1:                                  # the spider plot: an image, not an indicator
        print(f"    {name:<30} (plot, no score)")
        continue
    s = it.get("score")
    ok = isinstance(s, (int, float)) and not isinstance(s, bool) and math.isfinite(float(s))
    if ok: scored += 1
    print(f"    {name:<30} score={s}{'' if ok else '   <-- NOT A FINITE NUMBER'}")
print(f"FINITE_SCORES={scored}")
print("URLS=" + " ".join(urls))
# How much of the allocation the model could actually use. reclassify() drops any id that is
# not in the base raster, silently, so every assertion above passes on a round that ignored the
# player entirely — the scores come back finite either way. See mlacayoemery/esgame#170.
cov = json.load(open(sys.argv[1])).get("allocationCoverage")
print("COVERAGE=" + ("" if not cov else f"{cov['matched']}/{cov['allocated']}"))
print("COVERAGE_FRACTION=" + ("" if not cov else str(cov.get("fraction"))))
PY
grep -v '^FINITE_SCORES\|^URLS=\|^COVERAGE' /tmp/places-summary.txt
finite=$(grep '^FINITE_SCORES=' /tmp/places-summary.txt | cut -d= -f2)
urls=$(grep '^URLS=' /tmp/places-summary.txt | cut -d= -f2-)
coverage=$(grep '^COVERAGE=' /tmp/places-summary.txt | cut -d= -f2)
coverage_fraction=$(grep '^COVERAGE_FRACTION=' /tmp/places-summary.txt | cut -d= -f2)

check "all six indicators scored (not NaN)" "[ -n '${finite}' ] && [ '${finite}' = 6 ]"

# Everything above this line passes on a round the model ignored: reclassify() drops ids it does
# not recognise without a word, and the scores are finite constants either way. This is the only
# assertion here that tells "scored" from "ignored".
echo "    allocation the model could use: ${coverage:-<not reported>}"
check "the calculator reported allocation coverage" "[ -n '${coverage}' ]"
# PLACES ships the data-release raster, so its ids ARE the board's. Anything less than half means
# /app/data holds the wrong raster — which is exactly the state the esgame repo ships in.
check "the round was actually scored, not ignored" \
  "[ -n '${coverage_fraction}' ] && python3 -c \"import sys; sys.exit(0 if float('${coverage_fraction}') >= 0.5 else 1)\""
# The spider plot is served by plumber itself out of /app/data (@assets /app/data /images), so it
# also proves the output side of that writable volume.
plot_url=$(tr ' ' '\n' <<<"${urls}" | grep '\.png$' | head -1)
check "spider plot URL was returned"       "[ -n '${plot_url}' ]"
check "spider plot is a fetchable PNG" \
  "[ -n '${plot_url}' ] && [ \"\$(curl -s -o /dev/null -w '%{content_type}' -m 60 '${plot_url}')\" = 'image/png' ]"

# --- the returned URLs must work FROM OUTSIDE the compose network ---------------------------
# This is the GEOSERVER vs GEOSERVER_PUBLIC_URL split. A URL built from the in-network name
# resolves fine inside the stack and not at all in a browser, so fetch them from here.
wcs_total=0; wcs_ok=0
for u in ${urls}; do
  case "${u}" in *"/wcs?"*) ;; *) continue ;; esac
  wcs_total=$((wcs_total + 1))
  ct=$(curl -s -o /dev/null -w '%{content_type}' -m 120 "${u}" || true)
  case "${ct}" in *tiff*) wcs_ok=$((wcs_ok + 1));; *) echo "    unfetchable: ${u} (content-type: ${ct:-none})";; esac
done
echo "    WCS GetCoverage from outside the network: ${wcs_ok}/${wcs_total}"
check "coverage URLs were returned"            "[ ${wcs_total} -ge 5 ]"
check "every coverage URL returns a GeoTIFF"   "[ ${wcs_total} -gt 0 ] && [ ${wcs_ok} = ${wcs_total} ]"
# The -n guard is not decoration: `! grep -q ...` on an EMPTY list finds nothing, inverts to
# true, and passes. So a run whose URL extraction broke would report this — the check that
# guards the whole GEOSERVER vs GEOSERVER_PUBLIC_URL split — as green.
check "coverage URLs are not in-network names" "[ -n '${urls}' ] && ! grep -q 'places-geoserver' <<<'${urls}'"

# The workspace is per game/round, so a second round must not collide with the first.
ws="esgame_game1_round1"
check "workspace ${ws} exists in GeoServer" \
  "curl -fs -u '${GEOSERVER_USER:-admin}:${GEOSERVER_PASSWORD:-geoserver}' 'http://localhost:${PLACES_GEOSERVER_PORT}/geoserver/rest/workspaces/${ws}.json'"

echo
if [ "${checks}" -lt 15 ]; then
  echo "PLACES stack test: FAIL   only ${checks} checks ran; this file covers more than that"
  exit 1
fi
if [ "${fail}" = 0 ]; then
  echo "PLACES stack test: PASS   ${passed}/${checks} checks   frontend http://localhost:${PLACES_FRONTEND_PORT}/"
  echo "(stack left running; test/stack.sh --down to remove it)"
else
  echo "PLACES stack test: FAIL"
  exit 1
fi
