FROM rstudio/plumber

RUN apt-get update -qq && apt-get install -y libssl-dev libcurl4-gnutls-dev unixodbc-dev libmysqlclient-dev

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
RUN R -e "install.packages('grid')"
RUN R -e "install.packages('jsonlite')"
# geosapi is on CRAN (0.8-1). This was commented out while calculation.r pulled it from GitHub
# HEAD at container start instead — see the note at the top of calculation.r.
RUN R -e "install.packages('geosapi')"
RUN R -e "install.packages('logger')"
RUN R -e "install.packages('devtools')"
RUN R -e "install.packages('landscapemetrics')"
RUN R -e "install.packages('remotes')"

RUN apt-get install -y libcurl4-openssl-dev libssl-dev libjq-dev libprotobuf-dev protobuf-compiler make libgeos-dev libudunits2-dev libgdal-dev gdal-bin libproj-dev libv8-dev

RUN apt-get install -y libsecret-1-dev libsodium-dev

# Fail the build if anything calculation.r library()-s is not loadable. Two silent failures made
# this worth a layer of its own:
#   - install.packages only WARNS on an unavailable package, so `install.packages('rgdal')` exited
#     0 and installed nothing for years (see above).
#   - geosapi pulls in keyring, whose shared object needs libsecret. Install geosapi before the
#     apt layers above and it installs fine but cannot load — which is why this check runs last,
#     after every system library is in place.
# Loading is the real test; presence in installed.packages() is not.
RUN R -q -e "\
  pkgs <- c('sf','raster','ggplot2','ggpubr','tidyverse','tidyr','grid','jsonlite','geosapi','logger','devtools','landscapemetrics','terra'); \
  bad <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]; \
  if (length(bad)) stop('not loadable: ', paste(bad, collapse = ', ')); \
  cat('all', length(pkgs), 'R packages load\n')"

WORKDIR /app

COPY . .

EXPOSE 8000

CMD ["/app/calculation.r"]