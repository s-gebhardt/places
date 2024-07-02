# TradeoffV2

A cross-platform game about Ecosystem Services and Tradeoffs built with Angular.

## Getting started

### Setting up

Make sure you have Angular installed (https://angular.io/guide/setup-local). 

**Clone the repository**

```
$ git clone https://github.com/Vangelis96/esgame.git
$ cd esgame/V2
```

**Install dependencies**

```
$ npm install
```
### Run it locally

Run `$ ng serve` for creating a development server. By default, the app is reachable at `http://localhost:4200/`. The app will automatically reload if there are changes in the code.

### Run with docker
**Build**
```
$ docker build -t tradeoffv2 .
```

**Run**

In this example the url to access the game will be `http://localhost:81/`. If you want to be able to access it on a different port you can change the 81 in the command below to the desired port.
```
$ docker run -p 81:80 tradeoffv2
```

## Configuration

The configuration is stored in the [data.json](src/data.json) file. You can generate a new configuration on the `/configuration` endpoint. Once you are done with the configuration a file will be downloaded. You can replace the data.json file with the newly downloaded file.

It is important to configure the GDAL_NODATA in the tiff file. The GDAL_NODATA is used for the non-selectable areas.
The maps have to be tiff files. It is important that every map has the same size, otherwise it's not possible to show the maps properly.

### Map type

Select "Zones" if you want a game that defines the clickable fields in a TIFF that you attach and with an external calculation of the score and consequence maps. Select "Fields" if you want a game with a grid which is defined in the configuration and with maps that are predefined in attached TIFF files. 

### Calculation URL

On level change, this is the url were the result of the level gets posted. Please check the interface definition: 

#### Object that is sent to the calculation url

| Name of field			 | Type	           | Usage											                             |
|------------------|-----------------|----------------------------------------------|
| round					       | number 			      | Shows the current round number of the game 	 |
| score 				       | number 			      | The total score of the round 					           |
| game_id 				     | string 			      | the uuid of the game 							                 |
| allocation 			   | Array[Field] 		 | An array of field objects 					              |

#### Field object

| Name of field			 | Type	      | Usage											                                        |
|------------------|------------|---------------------------------------------------------|
| id					          | number 			 | The id of the field						 	                             |
| lulc 				        | number 			 | The id of the production type that is set in this field |



#### Expected response from calculation url

| Name of field			 | Type	           | Usage											                 |
|------------------|-----------------|----------------------------------|
| results				      | Array[result]		 | An array of result objects				 	 |



#### Result object

| Name of field			 | Type	      | Usage											                                |
|------------------|------------|-------------------------------------------------|
| name					        | string 			 | A random string; unused					 	                  |
| id 					         | number 			 | The id of the consequence map					              |
| score 				       | number 			 | The score of this consequence		 			             |
| url 					        | string	 		 | The url to the tiff file of the consequence map |

The id that is given in this object must match the id that is configured to the fitting consequence map in the configuration.
