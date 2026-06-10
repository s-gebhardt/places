FROM rstudio/plumber

RUN apt-get update -qq && apt-get install -y libssl-dev libcurl4-gnutls-dev unixodbc-dev libmysqlclient-dev

RUN R -e "install.packages('Rcpp')"
RUN R -e "install.packages('sf')"
RUN R -e "install.packages('sp')"
RUN R -e "install.packages('raster')"
RUN R -e "install.packages('rgdal')"
RUN R -e "install.packages('ggplot2')"
RUN R -e "install.packages('ggpubr')"
RUN R -e "install.packages('tidyverse')"
RUN R -e "install.packages('tidyr')"
RUN R -e "install.packages('grid')"
RUN R -e "install.packages('jsonlite')"
#RUN R -e "install.packages('geosapi')"
RUN R -e "install.packages('logger')"
RUN R -e "install.packages('devtools')"
RUN R -e "install.packages('landscapemetrics')"
RUN R -e "install.packages('remotes')"

RUN apt-get install -y libcurl4-openssl-dev libssl-dev libjq-dev libprotobuf-dev protobuf-compiler make libgeos-dev libudunits2-dev libgdal-dev gdal-bin libproj-dev libv8-dev

RUN apt-get install -y libsecret-1-dev libsodium-dev

WORKDIR /app

COPY . .

EXPOSE 8000

CMD ["/app/calculation.r"]