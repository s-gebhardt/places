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
```

**Not in git:** the large calculation **geodata** (rasters/CSVs) and any **secrets** — supply those
from object storage / your secret store at deploy time.

`calculation/calculation.r` reads these 13 files from `/app/data`, and the tree contains only the
first:

```
LU_and_NEW_hexa.tif        (present, in frontend/assets/images)
Water_points_ID_raster.tif   distance_weight_trace.tif   soil_groups_hexa.tif
gvg_hexa_raster.tif          sensi_GW_patch.tif          fix_nature_patches.tif
fixed_HC_score.tif           optimalHC_score.tif         worstHC_score.tif
trace.tif                    trace_numbers.csv           buffer_list.csv
```

A copy of all of them is in this repository's history — they were removed from
`kubernetes_deployment/assets/` when PLACES was re-converged onto esgame. To run a round locally
without object storage:

```sh
mkdir -p /tmp/places-data
for f in $(git show --diff-filter=D --name-only 310fd46 -- 'kubernetes_deployment/assets/*' \
             | grep -E '\.(tif|csv)$'); do
  git show "310fd46^:$f" > "/tmp/places-data/$(basename "$f")"
done
# then mount it: -v /tmp/places-data:/app/data
```

`deploy/k8s/patch-calculation.yaml`'s `load-geodata` init container is still a placeholder
(`echo 'TODO: fetch places geodata'`), so a cluster deploy has no data until that is replaced.

**Allocate only the playable hexagons.** `LU_and_NEW_hexa.tif` carries 472 ids: the 465 board
hexagons the frontend sends, plus 7 low values (`2`–`8`) that are fixed landscape features.
Reclassifying those 7 does not fail — the round still returns `200` and publishes its rasters — but
**every score comes back `NaN`**. See esgame's
[calculator reference](https://mlacayoemery.github.io/esgame/docs/reference/calculator.html).

## Run locally (compose)

```sh
cp deploy/compose/.env.places.example deploy/compose/.env.places   # then edit
docker compose -p places --env-file deploy/compose/.env.places \
  -f deploy/compose/docker-compose.places.yml up -d --build
# frontend http://localhost:81/   calculation :8000   geoserver :8080
```

The frontend image builds `FROM` the upstream esgame image (`ESGAME_IMAGE`, pin to `:2.0.0` once
tagged). `CALC_URL` is injected into the running frontend at start — no rebuild to retarget the
backend. A *real* calculation also needs PLACES' geodata loaded into GeoServer/the calculator.

## Deploy to Kubernetes

```sh
# set images, ingress hosts, and CALC_URL in deploy/k8s/ (CHANGE-ME-* placeholders), then:
kubectl apply -k deploy/k8s
```

`deploy/k8s` references the esgame base (`mlacayoemery/esgame//deploy/k8s/base?ref=…`) and patches
only: the images (PLACES frontend + calculation), the ingress hosts, the `CALC_URL`/GeoServer
ConfigMap, and a PVC + init container that loads PLACES' geodata.

## Updating game content

Edit `frontend/data.json` (and/or the rasters in `frontend/assets/images/`) and rebuild the
`places-frontend` image. The Angular app itself comes from upstream esgame — bump `ESGAME_IMAGE`
to pull in app changes; no source rebuild here.
