# Thin overlay image: the upstream esgame frontend with PLACES' game config + map assets layered
# on top. There is NO Angular source fork — the whole app (nginx, entrypoint, runtime-config) comes
# from the upstream image. Only the data and the place-specific map TIFFs are overlaid here.
# calcUrl stays runtime: the upstream entrypoint injects it from the CALC_URL env var.
#
# PINNED to an esgame build, not `:master`. The published places-frontend image is deployed by an
# immutable tag, and building it on a rolling base made that tag mean "whatever master was when CI
# happened to run". sha-d916a27 is the tag whose digest master carried on 2026-09-25
# (sha256:4a7467eef3eb348859e3d89b0db03d09fc054f91f0b39e664f5b461455c2d200). It must be an esgame
# build with the runtime-config + visualOptions/gradientOverrides support — 1.9.0 predates it.
# Move to 2.0.0 once that release is tagged. Keep deploy/compose in step (test/smoke.sh checks).
#
# Bumping: `ESGAME_IMAGE=ghcr.io/mlacayoemery/esgame:master test/smoke.sh` previews master (the
# daily CI run does the same), then change the tag here. Build against a local image with:
#   docker build --build-arg ESGAME_IMAGE=local/esgame-core:latest -t places-frontend frontend
ARG ESGAME_IMAGE=ghcr.io/mlacayoemery/esgame:sha-d916a27
FROM ${ESGAME_IMAGE}

# Overlay PLACES' dynamic-game config (data.json carries its visualOptions + gradientOverrides) and
# its map rasters. nginx serves assets/*.json as no-store, so config still applies on reload.
#
# --chown=101:101 because the base image runs as that uid and its entrypoint replaces config.json
# in place to inject CALC_URL. A plain COPY lands these root-owned, which happens to still work —
# the *directory* is nginx-owned, so `mv` can replace a file it does not own — but relying on that
# is one sticky bit, or one in-place `sed -i` upstream, away from a container that will not start.
COPY --chown=101:101 data.json config.json /usr/share/nginx/html/assets/
COPY --chown=101:101 assets/images/ /usr/share/nginx/html/assets/images/
