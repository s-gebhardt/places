# PLACES — Participatory Landscape Configuration Effects Simulator

PLACES is a deployment of the [esgame](https://github.com/mlacayoemery/esgame) "Tradeoff" game
(an Angular web app) backed by an R calculation service and a GeoServer instance.

> **This branch (`feature/esgame-overlay`) re-converges PLACES onto esgame as a thin overlay.**
> PLACES no longer vendors/forks the Angular source. The frontend is the **upstream esgame image**
> with only PLACES' game config and map assets layered on top; PLACES' visual customizations are now
> upstream esgame config flags (`visualOptions`, `gradientOverrides`).

## Layout

```
frontend/        # thin overlay image: FROM the esgame image, COPY data.json + config.json + map TIFFs
  Dockerfile
  data.json      # PLACES' dynamic-game config (incl. visualOptions + gradientOverrides)
  config.json
  assets/images/ # PLACES' suitability/consequence map rasters
calculation/     # PLACES' R Plumber calculation service (its own image)
deploy/
  compose/       # local / single-host stack (docker-compose.places.yml + .env.places.example)
  k8s/           # Kustomize overlay on esgame//deploy/k8s/base (image, hosts, calc geodata, CALC_URL)
  kind/          # deploy/k8s on a local kind cluster, plus a real round through its ingress
scripts/
  fetch-geodata.sh    # fill the local geodata cache
  release-geodata.sh  # publish that cache as the release tarball clusters load from
```

**Not in git:** the large calculation **geodata** (rasters/CSVs) and any **secrets** — supply those
from object storage / your secret store at deploy time.

`calculation/calculation.r` reads these 13 files from `/app/data`, and **none of them is in the
tree** in a form the calculation can use:

```
LU_and_NEW_hexa.tif        (a DIFFERENT raster of this name is in frontend/assets/images — see below)
Water_points_ID_raster.tif   distance_weight_trace.tif   soil_groups_hexa.tif
gvg_hexa_raster.tif          sensi_GW_patch.tif          fix_nature_patches.tif
fixed_HC_score.tif           optimalHC_score.tif         worstHC_score.tif
trace.tif                    trace_numbers.csv           buffer_list.csv
```

> **Do not satisfy `LU_and_NEW_hexa.tif` from `frontend/assets/images/`.** That copy numbers its
> hexagons `10`–`474`; the board numbers its own `100`–`46500` in hundreds, so only **4 of 465**
> ids overlap. The round still returns `200` with finite-looking scores — it just ignores the
> player's allocation almost entirely, returning the same numbers whatever they do. Only the
> data-release copy that `scripts/fetch-geodata.sh` fetches shares the board's id space, which is
> why the loaders take everything from that cache and nothing from the frontend assets.
> Measured against esgame's `tools/R`; see its
> [calculator reference](https://mlacayoemery.github.io/esgame/docs/reference/calculator.html).

`scripts/fetch-geodata.sh` puts them in a cache outside the repo:

```sh
scripts/fetch-geodata.sh                                        # -> /store/places/geodata
PLACES_GEODATA=~/places-data scripts/fetch-geodata.sh           # cache somewhere else
PLACES_GEODATA_URL=https://…/geodata.tar.gz scripts/fetch-geodata.sh
```

With `PLACES_GEODATA_URL` set it pulls a data-release tarball — the production path. Without it, it
recovers the files from **this repository's own history** (they were removed from
`kubernetes_deployment/assets/` when PLACES was re-converged onto esgame), which is enough to run a
round locally with no object storage at all. Either way it verifies all 13 arrived and exits
non-zero otherwise, because a partial load is worse than an empty one: the round still returns
`200` and still publishes rasters, it just scores everything `NaN`.

Both deployment paths consume that cache the same way — the compose stack through a one-shot
`places-geodata-loader` service, `deploy/k8s` through the `load-geodata` init container, which
fetches the tarball from a `places-geodata-source` Secret and applies the same 13-file check:

```sh
kubectl create secret generic places-geodata-source --from-literal=url='https://…/geodata.tar.gz'
```

`scripts/release-geodata.sh` makes that tarball: it packs the cache byte-reproducibly, refuses a
`LU_and_NEW_hexa.tif` that lacks the board's hexagon ids, and publishes it as a GitHub release
named by its content (`geodata-<sha256 prefix>`). Then it checks that an anonymous download
returns the same bytes, and prints the URL for the Secret. `--pack-only` stops before publishing.

The target must stay **writable**: `calculation.r` does `setwd("/app/data")` and writes its seven
output rasters and the spider-plot PNG back into that directory, then serves them from it. So the
read-only cache is copied into a writable volume rather than mounted onto `/app/data` directly.

**Allocate only the playable hexagons, and send an array.** `LU_and_NEW_hexa.tif` carries 472
distinct ids: 465 board hexagons (numbered in hundreds — `100`, `200`, … `46500`, *not* a
contiguous range) plus 7 low values (`2`–`8`) that are fixed landscape features.

```jsonc
{"game_id": 1, "round": 1, "score": 42,
 "allocation": [{"id": 100, "lulc": 10}, {"id": 200, "lulc": 20}, …]}   // 465 entries
```

`allocation` must be an **array of `{id, lulc}` objects** — that is what `jsonlite` turns into the
two-column matrix `raster::reclassify` expects. An id-keyed object instead gives a `500`
(`comparison of these types is not implemented`). `lulc` is a `productionTypes` code from
`frontend/data.json`: `10` `20` `30` `40` `50` `60`.

Including the 7 fixed features does not fail either — measured against this stack, the round still
returns `200` and still publishes all six coverages, but **3 of the 6 scores come back `NaN`** (HH,
WE, HC). Board ids only gives six real scores. So a partly-unscored round is indistinguishable from
a good one unless you look at the numbers, which is what `test/stack.sh` does. See also esgame's
[calculator reference](https://mlacayoemery.github.io/esgame/docs/reference/calculator.html).

## Run locally (compose)

```sh
scripts/fetch-geodata.sh                                    # once
docker compose -p places -f deploy/compose/docker-compose.places.yml up -d --build
# frontend http://localhost:81/   calculation :8000   geoserver :8080
```

Every variable has a default that works, so that is the whole thing — copy
`deploy/compose/.env.places.example` to `.env.places` and pass `--env-file` only when you need to
change something. Set `PLACES_FRONTEND_PORT` / `PLACES_CALC_PORT` / `PLACES_GEOSERVER_PORT` if those
host ports are taken; if you move the GeoServer port, move `GEOSERVER_PUBLIC_URL` with it.

The frontend image builds `FROM` the upstream esgame image, **pinned** to an esgame build
(`ESGAME_IMAGE`, default `ghcr.io/mlacayoemery/esgame:sha-d916a27`; move to `:2.0.0` once tagged).
`CALC_URL` is injected into the running frontend at start — no rebuild to retarget the backend.

**Two GeoServer addresses, and they are not interchangeable.** `GEOSERVER_URL` is server-to-server:
the calculation publishes coverages over the REST API from inside the network. `GEOSERVER_PUBLIC_URL`
is what the WCS URLs in the response are built from, and those are fetched by the **browser** — set
it to the in-network name and every round returns `200` with coverage URLs no client can resolve.

### Running it on a real cluster

`deploy/k8s` is what a deployment applies. Until now it had only ever been *rendered* —
`test/k8s.sh` checks what kustomize produces, and nothing had put traffic through an Ingress.
`test/stack.sh` plays a real round, but over published host ports, so it proves the calculation
and GeoServer work and proves nothing about the proxy in front of them.

```sh
# once, from an esgame checkout — one ingress-nginx serves both stacks
deploy/k8s/kind.sh up

deploy/kind/kind.sh up            # namespace, geodata server, secrets, apply, wait
deploy/kind/ingress-test.sh       # a real round THROUGH the ingress, by Host header
deploy/kind/kind.sh down
```

It runs in its own `places` namespace, because this overlay inherits the esgame base's resource
names — the Deployments really are called `esgame-angular`, `esgame-calculation`,
`esgame-geoserver` — so applying it into `default` beside a running esgame would overwrite it.

The first thing this found was a 504: ingress-nginx defaults `proxy_read_timeout` to 60s and a
PLACES round takes 62-66s, so the calculator finished, published every coverage, and the client
got `504 Gateway Time-out`. Fixed upstream in mlacayoemery/esgame#162, which this repository
inherits through its base ref. Set `PLACES_KUBE_CONTEXT`, `PLACES_INGRESS` and `PLACES_DOMAIN` to
run the same round against another cluster, through its own ingress.

## Testing it

```sh
test/stack.sh          # brings the stack up, plays a real round, asserts the result is usable
test/stack.sh --down   # tear it down
test/smoke.sh          # frontend overlay only (docker + curl)
test/k8s.sh            # renders deploy/k8s (or an overlay of it) and checks it (needs kustomize)
```

`test/stack.sh` checks scores are finite numbers, fetches the returned coverage URLs from outside
the compose network, and asserts the calculation installs nothing at run time — each of which was a
real silent failure, not a hypothetical one.

**CI runs the last two of those** (`.github/workflows/overlay.yml`) on push, on PRs, and **daily**.
Both halves of this overlay are pinned to an esgame build: `deploy/k8s` pulls the base at a commit,
and `frontend/Dockerfile` builds `FROM` an esgame `sha-` tag. They used to track master, and the
repository broke with nobody touching it: master moved GeoServer to its own image. The pins keep
what we deploy reproducible. The daily run's `upstream-master` job re-runs both tests against
esgame **master**, so upstream changes still show up early, as "not safe to bump yet" rather than
as a broken deployment. Preview a bump by hand with
`ESGAME_REF=master test/k8s.sh` and `ESGAME_IMAGE=ghcr.io/mlacayoemery/esgame:master test/smoke.sh`.
`test/stack.sh` is not in CI: geodata plus a ~15 minute R build belongs in a hand-run.

**Images are published by CI**, not built on the cluster. `image-frontend.yml` and
`image-calculation.yml` push `ghcr.io/s-gebhardt/places-{frontend,calculation}` from `main`, tagged
`sha-<commit>` (immutable; what a deployment pins), `main` (rolling) and the version on a `v*` tag.
Each one then pulls the tag it just pushed and checks that it runs.

## Deploy to Kubernetes

`deploy/k8s` references the esgame base (`mlacayoemery/esgame//deploy/k8s/base?ref=<sha>`) and
patches only: the images (PLACES frontend + calculation, and the base's GeoServer pinned to a
`sha-` tag), the ingress hosts, the `CALC_URL`/GeoServer ConfigMap, and a PVC + init container that
loads PLACES' geodata. It has placeholder hosts, so a deployment is an overlay on top of it that
sets the real ones, as `deploy/kind` does for a local cluster.

**Keep a real deployment's overlay out of this repository.** It is public, and an overlay names
hosts, addresses and sizing that belong to whoever runs it. Put the overlay somewhere private,
pointed at this repository by a pinned commit, with pinned `sha-` image tags:

```yaml
resources:
  - https://github.com/s-gebhardt/places//deploy/k8s?ref=<commit>
```

Then check and apply it:

```sh
test/k8s.sh /abs/path/to/overlay                        # the same checks as deploy/k8s gets
kubectl create secret generic esgame-geoserver-admin --from-literal=username=admin \
  --from-literal=password="$(openssl rand -hex 16)"     # hex: no spaces or glob characters
kubectl create secret generic places-geodata-source --from-literal=url='<release tarball URL>'
kustomize build /abs/path/to/overlay | kubectl apply -f -
```

Use a hex password. GeoServer's own `/opt/update_credentials.sh` hashes the password with
`make_hash $GEOSERVER_ADMIN_PASSWORD` **unquoted**. So a password containing a space would get
only its first word hashed, and GeoServer would then reject the full password the calculation sends.

> **The base ref is pinned.** Two applies a week apart are the same deployment. To take upstream
> fixes, preview with `ESGAME_REF=master test/k8s.sh`, then move the sha in
> `deploy/k8s/kustomization.yaml`. If the base's GeoServer image moved, re-pin its tag there
> too, and re-run `test/k8s.sh`.

## Updating game content

Edit `frontend/data.json` (and/or the rasters in `frontend/assets/images/`) and rebuild the
`places-frontend` image. The Angular app itself comes from upstream esgame. To pull in app changes,
bump the `ESGAME_IMAGE` pin in `frontend/Dockerfile` and `deploy/compose` (`test/smoke.sh` fails
if the two drift). There's no source rebuild here.
