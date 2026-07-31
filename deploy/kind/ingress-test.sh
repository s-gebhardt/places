#!/usr/bin/env bash
# A real PLACES round through a real ingress controller.
#
#   deploy/kind/kind.sh up && deploy/kind/ingress-test.sh
#
# Every request here goes to the ingress on ${KIND_HTTP_PORT} with a Host header — never
# port-forward, which proves a Pod listens and proves nothing about the Ingress in front of it.
#
# test/stack.sh already plays a round against the compose stack, over published host ports. This
# is the same round with an Ingress in the path, on the manifests a deployment actually applies.
set -euo pipefail
cd "$(dirname "$0")/../.."

CLUSTER="${KIND_CLUSTER:-esgame}"
NS="${PLACES_NAMESPACE:-places}"
PORT="${KIND_HTTP_PORT:-8880}"
BASE="http://localhost:${PORT}"
K=(kubectl --context "kind-${CLUSTER}" -n "${NS}")

fail=0
check() { if eval "$2" >/dev/null 2>&1; then echo "  ok   $1"; else echo "  FAIL $1"; fail=1; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' -m 30 -H "Host: $1" "${BASE}${2:-/}" "${@:3}"; }
ing()  { curl -s -m 30 -H "Host: $1" "${BASE}${2:-/}" "${@:3}"; }

echo "==> the controller adopted our Ingresses"
# An Ingress only gets a status address once a controller has adopted it. Empty means the class
# did not match and nothing is routing, however healthy everything looks.
for i in esgame-angular-ingress esgame-calculation-ingress esgame-geoserver-ingress; do
  addr=$("${K[@]}" get ingress "$i" -o jsonpath='{.status.loadBalancer.ingress[*].ip}{.status.loadBalancer.ingress[*].hostname}' 2>/dev/null || true)
  check "${i} adopted" "[ -n '${addr}' ]"
done

echo "==> the frontend is PLACES, through the ingress"
body=$(ing places.local / || true)
check "places.local serves the app"        "[ \"\$(code places.local /)\" = 200 ]"
# `<app-root` only. With '<app-root\|<title' this matched ingress-nginx's own 404 page —
# "<html><head><title>404 Not Found</title>..." — so with nothing serving places.local it
# reported that the app really was being served. Found by running this script against a deleted
# deployment, which is the only way that shape shows up.
check "index.html is really the app"       "grep -qi '<app-root' <<<\"\${body}\""
data=$(ing places.local /assets/data.json || true)
# The whole point of the overlay: PLACES' own data, not the upstream esgame image's.
check "data.json is PLACES (title V.2)"    "grep -q 'Agriculture Edition V.2' <<<\"\${data}\""

cfg=$(ing places.local /assets/config.json || true)
want=$("${K[@]}" get cm esgame-config -o jsonpath='{.data.CALC_URL}' 2>/dev/null || true)
got=$(sed -n 's/.*"calcUrl"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' <<<"${cfg}" || true)
echo "     ConfigMap CALC_URL=${want}"
echo "     served    calcUrl =${got}"
check "CALC_URL reached the served config" "[ -n '${want}' ] && [ '${want}' = '${got}' ]"

# Agreeing with the ConfigMap only proves the env var was plumbed; it says nothing about whether
# the URL WORKS, and every other request here is built from ${BASE} plus a Host header so it
# reaches the ingress whatever the served config says. A CALC_URL with no port passed every
# check of this shape upstream while no browser could play a round.
calc_host=$(sed -E 's|^https?://([^:/]+).*|\1|' <<<"${got}")
calc_port=$(sed -nE 's|^https?://[^:/]+:([0-9]+).*|\1|p' <<<"${got}")
[ -n "${calc_port}" ] || calc_port=$(grep -q '^https' <<<"${got}" && echo 443 || echo 80)
calc_path=$(sed -E 's|^https?://[^/]+||' <<<"${got}")
echo "     as a client reads it: host=${calc_host} port=${calc_port} path=${calc_path}"
calc_code=$(curl -s -o /dev/null -w '%{http_code}' -m 20 --resolve "${calc_host}:${calc_port}:127.0.0.1" \
  "http://${calc_host}:${calc_port}${calc_path}" -X POST -H 'Content-Type: application/json' \
  -d '{"allocation":[]}' 2>/dev/null || true)
check "CALC_URL is reachable as written"   "[ -n '${calc_code}' ] && [ '${calc_code}' != 000 ]"

echo "==> a wrong Host must NOT be served by our app"
other=$(ing no-such-host.local / || true)
check "unknown host is not the app" \
  "[ \"\$(code places.local /)\" = 200 ] && { [ \"\$(code no-such-host.local /)\" != 200 ] || ! grep -qi '<app-root' <<<\"\${other}\"; }"

echo "==> geoserver through the ingress"
check "geoserver web UI responds"          "[ \"\$(code places-geoserver.local /geoserver/index.html)\" = 200 ]"

echo "==> the board id space the calculation will score against"
"${K[@]}" exec deploy/esgame-calculation -- Rscript -e '
  suppressMessages(library(raster))
  v <- sort(unique(na.omit(values(raster("/app/data/LU_and_NEW_hexa.tif")))))
  cat("IDS:", paste(v[v >= 9], collapse = ","), "\n")' 2>/dev/null \
  | tr -d '\r' | sed -n 's/^IDS: //p' | tr -d ' ' > /tmp/places-kind-ids.txt || true
n=$(tr ',' '\n' < /tmp/places-kind-ids.txt | grep -c . || echo 0)
echo "     ${n} allocatable ids read from the deployed raster"
check "read the id space from the pod"     "[ '${n}' -gt 100 ]"
# The count alone does not identify the raster — the frontend copy happens to have 455. The
# contract is the id SPACE: the board numbers its hexagons in hundreds.
id_max=$(tr ',' '\n' < /tmp/places-kind-ids.txt | sort -n | tail -1)
not100=$(tr ',' '\n' < /tmp/places-kind-ids.txt | awk 'NF && $1 % 100 != 0 {b++} END {print b+0}')
echo "     id space: max ${id_max:-<none>}, ${not100} not a multiple of 100"
check "the data-release raster is mounted" "[ -n '${id_max}' ] && [ '${not100}' = '0' ] && [ '${id_max}' -gt 10000 ]"

echo "==> playing a round through the ingress"
python3 - /tmp/places-kind-ids.txt > /tmp/places-kind-payload.json <<'PY'
import json, sys
ids = [int(x) for x in open(sys.argv[1]).read().strip().split(',') if x]
types = [10, 20, 30, 40, 50, 60]
json.dump({"game_id": "kind", "round": 1, "score": 42,
           "allocation": [{"id": i, "lulc": types[n % len(types)]} for n, i in enumerate(ids)]},
          sys.stdout)
PY
start=$(date +%s)
res=$(curl -s -m 900 -H 'Host: places-calculation.local' -H 'Content-Type: application/json' \
        --data @/tmp/places-kind-payload.json "${BASE}/esgame" || true)
echo "     POST /esgame -> $(( $(date +%s) - start ))s"
# Not `-n`: with nothing serving, the POST comes back as nginx's 404 HTML — 145 bytes of it —
# which is very much "something". The round has to have returned the shape the frontend parses.
check "round returned JSON with results"   "python3 -c \"
import json,sys
try: r=json.loads(sys.argv[1])
except Exception: sys.exit(1)
rs=r.get('results', r) if isinstance(r,dict) else r
sys.exit(0 if isinstance(rs,list) and rs else 1)\" '${res}'"

scored=$(python3 - <<PY
import json
try: r = json.loads('''${res}''')
except Exception: print(0); raise SystemExit
rs = r.get('results', r) if isinstance(r, dict) else r
ok = 0
for e in rs:
    s = e.get('score')
    if e.get('id') != '-1' and isinstance(s, (int, float)) and s == s:
        ok += 1
        print(f"     {e.get('name'):46} score={round(s)}", flush=True)
print(ok)
PY
)
n_scored=$(tail -1 <<<"${scored}"); sed '$d' <<<"${scored}"
check "indicators scored (not NaN)"        "[ '${n_scored}' -ge 5 ]"

echo "==> the returned coverage URLs are fetchable as a browser would fetch them"
urls=$(python3 -c "
import json,sys
try: r=json.loads('''${res}''')
except Exception: sys.exit()
rs=r.get('results', r) if isinstance(r,dict) else r
print('\n'.join(e['url'] for e in rs if e.get('url')))" || true)
ok=0; tot=0
for u in ${urls}; do
  case "${u}" in *"/wcs?"*) ;; *) continue ;; esac
  tot=$((tot + 1))
  host=$(sed -E 's|https?://([^/:]+).*|\1|' <<<"${u}")
  path=$(sed -E 's|https?://[^/]+||' <<<"${u}")
  ct=$(curl -s -o /dev/null -w '%{content_type}' -m 180 -H "Host: ${host}" "${BASE}${path}" || true)
  case "${ct}" in *tiff*) ok=$((ok + 1));; *) echo "     unfetchable via ingress: ${host} (${ct:-none})";; esac
done
echo "     WCS GetCoverage through the ingress: ${ok}/${tot}"
# The -n guard is load-bearing: `! grep -q` over an EMPTY list finds nothing and inverts to true,
# so a round that returned no URLs at all would report this as green.
check "coverage URLs use an ingress host"  "[ -n '${urls}' ] && ! grep -q 'esgame-geoserver-service' <<<'${urls}'"
check "coverage URLs return GeoTIFFs"      "[ ${tot} -gt 0 ] && [ ${ok} = ${tot} ]"

echo "==> how much of the allocation the calculator could use"
cov=$("${K[@]}" logs deploy/esgame-calculation --tail=400 2>/dev/null | grep -F 'Allocation coverage:' | tail -1 || true)
echo "     ${cov:-<no coverage line in the log>}"
# Presence, not a threshold: the reporter being wired in at all is what is worth failing on, and
# this percentage is circular anyway — the payload's ids came from that same raster.
check "the calculator reported coverage"   "[ -n '${cov}' ]"

echo "==> what was actually under test"
for d in esgame-angular esgame-calculation; do
  echo "     ${d}"
  echo "       spec:    $("${K[@]}" get deploy "${d}" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)"
  echo "       running: $("${K[@]}" get pod -l "app=${d}" -o jsonpath='{.items[0].status.containerStatuses[0].imageID}' 2>/dev/null)"
done
digests=$("${K[@]}" get pod -l 'app in (esgame-angular,esgame-calculation)' \
  -o jsonpath='{range .items[*]}{.status.containerStatuses[0].imageID}{"\n"}{end}' 2>/dev/null | grep -c '@sha256:' || true)
check "both pods report an image digest"   "[ '${digests}' = '2' ]"

echo
if [ "${fail}" = 0 ]; then
  echo "PLACES ingress round-trip: PASS   (${n} ids, ${n_scored} scores, ${ok}/${tot} coverages, all via ${BASE})"
else
  echo "PLACES ingress round-trip: FAIL"; exit 1
fi
