FROM rstudio/plumber

# System libraries FIRST, then R packages. The previous order installed R packages and only then
# the apt layers, which meant a package could install cleanly and still fail to LOAD: geosapi
# pulls in keyring, whose shared object needs libsecret, so requireNamespace('geosapi') was FALSE
# at that point in the build even though install.packages had just succeeded.
#
# These are RUNTIME libraries, not -dev packages. Every R package here installs as a p3m binary
# for noble, so it links against the shared objects and never needs headers. Together with
# --no-install-recommends this took the image from 3.36 GB to ~2.6 GB; the dropped layer had been
# pulling in python3-numpy, libpoppler-dev and libhdf5-dev. gdal-bin (command-line tools),
# protobuf-compiler, libjq-dev, unixodbc-dev and libmysqlclient-dev went too — calculation.r
# shells out to nothing and talks to no database.
#
# The trade-off: these names are tied to the Ubuntu release and the library soname (libgdal34t64
# is noble/GDAL 3.8). A newer base fails the build with "Unable to locate package", which is the
# good kind of failure. If you add an R package with no binary that compiles from source, add its
# -dev package back. Same layout as esgame's tools/R/Dockerfile — keep the two in step.
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      libgdal34t64 \
      libgeos-c1t64 \
      libproj25 \
      libudunits2-0 \
      libsecret-1-0 \
      libsodium23 \
 && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages('Rcpp')"
RUN R -e "install.packages('sf')"
RUN R -e "install.packages('sp')"
RUN R -e "install.packages('raster')"
# rgdal was here. It was retired from CRAN in October 2023 (its GDAL/PROJ bindings live on in sf
# and terra, both installed here), so the line had silently installed nothing for years —
# install.packages only warns on an unavailable package. calculation.r never library()-ed it.
RUN R -e "install.packages('ggplot2')"
RUN R -e "install.packages('ggpubr')"
RUN R -e "install.packages('tidyverse')"
RUN R -e "install.packages('tidyr')"
# 'grid' was here too: it ships with R as a base package, so that line also installed nothing.
RUN R -e "install.packages('jsonlite')"
# geosapi is on CRAN (0.8-1). This was commented out while calculation.r pulled it from GitHub
# HEAD at container start instead — see the note at the top of calculation.r.
RUN R -e "install.packages('geosapi')"
RUN R -e "install.packages('logger')"
RUN R -e "install.packages('landscapemetrics')"
RUN R -e "install.packages('terra')"
# devtools and remotes were here. Nothing in calculation.r calls anything from either — they were
# left over from the run-time install_github, which is gone. devtools alone was 39 MB of
# package-development toolchain (usethis, roxygen2, pkgdown) in a runtime image.

# Fail the build if anything calculation.r library()-s is not loadable. install.packages only
# WARNS on an unavailable package — that is how install.packages('rgdal') exited 0 and installed
# nothing for years — and a package can install fine yet fail to load when a system library is
# missing. Loading is the real test; presence in installed.packages() is not.
RUN R -q -e "\
  pkgs <- c('sf','raster','ggplot2','ggpubr','tidyverse','tidyr','grid','jsonlite','geosapi','logger','landscapemetrics','terra'); \
  bad <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]; \
  if (length(bad)) stop('not loadable: ', paste(bad, collapse = ', ')); \
  cat('all', length(pkgs), 'R packages load\n')"

# And the two things dropping the -dev packages could plausibly have broken, checked rather than
# assumed. sf loading proves it found libgdal/libproj; asking for the versions proves they work.
# TLS is the other: geosapi talks to GeoServer over https in any real deployment, and losing
# libssl would not show up until a request failed at run time.
RUN R -q -e "\
  v <- sf::sf_extSoftVersion(); \
  cat('GDAL', v[['GDAL']], '/ PROJ', v[['PROJ']], '/ GEOS', v[['GEOS']], '\n'); \
  s <- curl::curl_fetch_memory('https://cran.r-project.org/')\$status_code; \
  if (s != 200) stop('TLS request failed with status ', s); \
  cat('https ok\n')"

WORKDIR /app

COPY . .

# Match the uid the esgame base's Deployment asserts (mlacayoemery/esgame, calculation-deployment
# securityContext: runAsNonRoot + runAsUser: 10001). Without this the pod still runs — runAsUser
# forces the uid whether or not the image has it — but as an unnamed user with no ownership of
# /app, which works only because the geodata volume happens to be world-writable. Declaring the
# user makes that intentional instead of incidental.
#
# /app/data is a PVC here, so its ownership comes from the volume (fsGroup), not from this line;
# the mkdir is only so the mount point exists and is owned sensibly when there is no volume.
RUN useradd --system --uid 10001 --gid 0 --no-create-home --shell /usr/sbin/nologin places \
 && mkdir -p /app/data \
 && chown -R 10001:0 /app \
 && chmod -R g=u /app
USER 10001

EXPOSE 8000

CMD ["/app/calculation.r"]
