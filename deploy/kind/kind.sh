#!/usr/bin/env bash
# Deploy PLACES to a local kind cluster with a real ingress controller.
#
#   deploy/kind/kind.sh up          # namespace, geodata server image, secrets, apply, wait
#   deploy/kind/ingress-test.sh     # a real round THROUGH the ingress, by Host header
#   deploy/kind/kind.sh down
#
# This reuses the esgame kind cluster rather than creating another — one ingress-nginx on one
# host port serves both. Create it first, from the esgame checkout:
#
#   deploy/k8s/kind.sh up
#
# Why this exists: deploy/k8s had only ever been RENDERED. test/k8s.sh checks what kustomize
# produces, and nothing had applied it to a cluster or put traffic through an Ingress.
# test/stack.sh plays a real round but over published host ports, so it proves the calculation
# and GeoServer work and proves nothing about the Ingress in front of them.
set -euo pipefail
cd "$(dirname "$0")/../.."

CLUSTER="${KIND_CLUSTER:-esgame}"
NS="${PLACES_NAMESPACE:-places}"
HTTP_PORT="${KIND_HTTP_PORT:-8880}"
GEODATA="${PLACES_GEODATA:-/store/places/geodata}"
REG="${PLACES_REGISTRY:-localhost:5001}"
HOSTS=(places.local places-calculation.local places-geoserver.local)

need() { command -v "$1" >/dev/null || { echo "!! $1 not on PATH" >&2; exit 2; }; }

case "${1:-}" in
  up)
    need kubectl; need docker; need kustomize
    K=(kubectl --context "kind-${CLUSTER}")

    "${K[@]}" cluster-info >/dev/null 2>&1 || {
      echo "!! no kind cluster '${CLUSTER}'. Create it from the esgame checkout: deploy/k8s/kind.sh up"
      exit 1; }

    # The geodata is a data release, deliberately not in git. Serve it over HTTP inside the
    # cluster so load-geodata fetches it from a URL exactly as a real deployment would, rather
    # than special-casing local runs into the manifests.
    [ -d "${GEODATA}" ] || {
      echo "!! no geodata at ${GEODATA}. Populate it first: scripts/fetch-geodata.sh"
      exit 1; }
    n=$(find "${GEODATA}" -maxdepth 1 -type f \( -name '*.tif' -o -name '*.csv' \) | wc -l)
    # 13 is what the init container verifies; fewer means the round would fail later with
    # every indicator NaN, which is exactly the silent failure this stack keeps producing.
    [ "${n}" -eq 13 ] || { echo "!! ${GEODATA} holds ${n} geodata files, expected 13"; exit 1; }
    echo ">> packing ${n} geodata files"

    tmp=$(mktemp -d); trap 'rm -rf "${tmp}"' EXIT
    tar -czf "${tmp}/places-geodata.tar.gz" -C "${GEODATA}" .
    cat > "${tmp}/Dockerfile" <<'DOCKER'
FROM nginx:1.29-alpine
COPY places-geodata.tar.gz /usr/share/nginx/html/places-geodata.tar.gz
DOCKER
    docker build -q -t "${REG}/places-geodata-server:local" "${tmp}" >/dev/null
    docker push -q "${REG}/places-geodata-server:local" >/dev/null
    echo ">> geodata server image pushed ($(du -h "${tmp}/places-geodata.tar.gz" | cut -f1))"

    "${K[@]}" create namespace "${NS}" --dry-run=client -o yaml | "${K[@]}" apply -f - >/dev/null

    # The esgame base ships no GeoServer password on purpose: it references a Secret that does
    # not exist in-repo, so a missing one fails the rollout instead of quietly shipping
    # admin/geoserver. Create a throwaway.
    "${K[@]}" -n "${NS}" get secret esgame-geoserver-admin >/dev/null 2>&1 || \
      "${K[@]}" -n "${NS}" create secret generic esgame-geoserver-admin \
        --from-literal=username=admin \
        --from-literal=password="local-$(head -c 12 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')" >/dev/null

    # Points at the in-cluster server above. A real deployment points it at the actual release.
    "${K[@]}" -n "${NS}" create secret generic places-geodata-source \
      --from-literal=url="http://places-geodata-server.${NS}.svc/places-geodata.tar.gz" \
      --dry-run=client -o yaml | "${K[@]}" apply -f - >/dev/null

    # The overlay hard-codes the ingress port into the browser-facing URLs, because a browser
    # cannot infer it. Read it from the RENDER, not the source: the values are inherited from
    # deploy/k8s and patched here, so grepping either file alone would miss them.
    rendered=$(kustomize build deploy/kind)
    for v in CALC_URL GEOSERVER_PUBLIC_URL; do
      want=$(grep -oE "^  ${v}: .*" <<<"${rendered}" | head -1)
      case "${want}" in
        *":${HTTP_PORT}/"*) ;;
        "") echo "!! ${v} is not in the render"; exit 1 ;;
        *) echo "!! ${v} does not use KIND_HTTP_PORT=${HTTP_PORT}:"; echo "   ${want}"
           echo "   a browser would post to the wrong port; curl with a Host header would not notice"
           exit 1 ;;
      esac
    done

    kustomize build deploy/kind | "${K[@]}" apply -f - >/dev/null
    # esgame-config is consumed as environment variables, fixed when a container starts, under a
    # stable name — so `apply` updates the ConfigMap while every running pod keeps the old value.
    "${K[@]}" -n "${NS}" rollout restart deploy/esgame-angular deploy/esgame-calculation >/dev/null 2>&1 || true

    for d in places-geodata-server esgame-angular esgame-geoserver esgame-calculation; do
      "${K[@]}" -n "${NS}" rollout status "deploy/${d}" --timeout=600s
    done

    # A Service whose selector matches nothing still applies without error.
    for s in esgame-angular-service esgame-geoserver-service esgame-calculation-service; do
      c=$( ("${K[@]}" -n "${NS}" get endpointslice -l "kubernetes.io/service-name=${s}" \
            -o jsonpath='{.items[*].endpoints[*].addresses[*]}' 2>/dev/null || true) | wc -w)
      [ "${c}" -ge 1 ] || { echo "!! ${s} has no endpoints"; exit 1; }
      echo "  ${s} -> ${c} endpoint(s)"
    done
    echo ">> PLACES is on http://localhost:${HTTP_PORT} — send a Host header: ${HOSTS[*]}"
    ;;

  test) exec "$(dirname "$0")/ingress-test.sh" ;;

  down)
    need kubectl
    kubectl --context "kind-${CLUSTER}" delete namespace "${NS}" --wait=false 2>/dev/null || true
    echo ">> namespace ${NS} deleting (the esgame cluster is left alone)"
    ;;

  *) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
