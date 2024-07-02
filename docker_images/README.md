# Docker container images

## Calculations container

- cd calculations

1. Set environment variable GEOSERVER
2. build docker image
    - docker build -t esgame-calculation:latest .
3. check if it works
    - docker run esgame-calculation
4. Push image to container registry of choice
    - docker push esgame-calculation:latest 

## esgame container

- cd esgame

2. build docker image
    - docker build -t esgame:latest .
3. check if it works
    - docker run esgame
4. Push image to container registry of choice
    - docker push esgame:latest 

