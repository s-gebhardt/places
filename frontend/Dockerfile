# Thin overlay image: the upstream esgame frontend with PLACES' game config + map assets layered
# on top. There is NO Angular source fork — the whole app (nginx, entrypoint, runtime-config) comes
# from the upstream image. Only the data and the place-specific map TIFFs are overlaid here.
# calcUrl stays runtime: the upstream entrypoint injects it from the CALC_URL env var.
#
# Pin ESGAME_IMAGE to a released esgame tag once available. It must be an esgame build that has the
# runtime-config + visualOptions/gradientOverrides support (i.e. >= 2.0.0 / today's master) — the
# 1.9.0 tag predates it. Build locally against a local image with:
#   docker build --build-arg ESGAME_IMAGE=local/esgame-core:latest -t places-frontend frontend
ARG ESGAME_IMAGE=ghcr.io/mlacayoemery/esgame:master
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
