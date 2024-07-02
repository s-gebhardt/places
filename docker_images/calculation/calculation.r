library(remotes)
remotes::install_github('eblondel/geosapi')	
options("plumber.port" = 5555)

#NEW CODE --> ALLOW CORS REQUESTS
#* @filter cors
cors <- function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  if (req$REQUEST_METHOD == "OPTIONS") {
    res$setHeader("Access-Control-Allow-Methods","*")
    res$setHeader("Access-Control-Allow-Headers", req$HTTP_ACCESS_CONTROL_REQUEST_HEADERS)
    res$status <- 200 
    return(list())
  } else {
    plumber::forward()
  }
}

#* @assets /app/data /images
list()

#* @post /esgame
#* @serializer unboxedJSON
esgame <- function(req, json_in='{}') {
  geoserver_url <- Sys.getenv("GEOSERVER")
  #NEW CODE --> ALLOW TO SEND DATA IN BODY OF Request
  if (!(json_in == '' || json_in == '{}')) { 
    json_list<-fromJSON(json_in, simplifyVector = T)
    #json_list<-fromJSON("Results50.json", simplifyVector = T)
    game_id <- json_list$game_id 
    round_id <-json_list$round 
    score_PD <- json_list$score
    map_AG <- json_list$allocation 
  } else {
    game_id <- req$body$game_id 
    round_id <-req$body$round 
    score_PD <- req$body$score
    map_AG <- req$body$allocation
  }
  return(calculate(req, geoserver_url, game_id, round_id, score_PD, map_AG))
}

library(sf)
library(raster)
library(ggplot2)
library(ggpubr)
library(tidyverse)
library(tidyr)
library(grid)
library(jsonlite)
library(geosapi)
library(logger)
library(devtools)
library(landscapemetrics)
library(terra)

calculate<-function(req, geoserver_url, game_id, round_id,score_PD,map_AG) {
  ##### 0) Start #####
  directory<-"/app/data"
  setwd(directory)
  
  ##### 1) Create Land use map #####
  LU_hexa<- raster("LU_and_NEW_hexa.tif")
  LU_complete<-reclassify(LU_hexa, map_AG, right=F) # no value can be 1!!!!
  writeRaster(x=LU_complete, filename=paste0("LU_", "Game_",game_id,"_Round_",round_id,".tif"),overwrite=TRUE, NAflag=-9999)

  #### Set parameters ####
  # farm type identifier
  ext_arable<-10
  ext_livest<-20
  int_arable<-30
  int_livest<-40
  agropark<-50
  add_nat<-60
  
  # consequence map identifier
  human_health<-11
  nutrient_pollution<-22
  water_eutrophication<-33
  water_availability<-44
  habitat_cohesion<-55
  recreational<-66
  
  # useful maps
  zero_raster<-LU_complete
  zero_raster[!is.na(zero_raster)] <- 0
  NA_raster<-zero_raster
  NA_raster[]<-NA
  
  #### 2) MODEL: Human health #####
  # calculate distance decay for both PM2.5 and NH3 for each agriculture type, large patches are counted twice to account for accumulated emissions
  agri_only<-reclassify(LU_complete, matrix(c(2,3,4,5,6,7,8,10,20,30,40,50,60,61,NA,NA,NA,NA,NA,NA,NA,10,20,30,40,50,60,61),nrow = 14), right=F)
  LU_patches <- get_patches(agri_only, class = "all")[[1]]
  
  if (any(ext_arable %in% values(LU_complete))) {
    AG10<-reclassify(LU_complete, cbind(ext_arable,1), right=FALSE)
    AG10<-reclassify(AG10, cbind(2,70,NA), right=FALSE)
    dist10<-raster::distance(AG10)
    deposited_NH3_AG10<- (10 *  exp(-0.00245 * dist10))
    conc_PM2.5_AG10<- (0.06 *  exp(-0.000356 * dist10))  
    
    LU_patch_area10<-lsm_p_para(LU_patches$class_10)
    LU_patch_area10<-LU_patch_area10[,c(3,6)]
    LU_patch_area10$value <- 1/LU_patch_area10$value
    LU_patch_area10$value[which(LU_patch_area10$value <= 350)]<- NA
    LU_patch_area10$value[which(LU_patch_area10$value >350)]<-1
    
    if (length(which(LU_patch_area10$value == 1))> 0) {
    LU_patches_10<-LU_patches$class_10
    LU_patches_10<-raster(LU_patches_10)
    LU_patches_10<-reclassify(LU_patches_10,LU_patch_area10, right=F)
    dist10x<-raster::distance(LU_patches_10)
    deposited_NH3_AG10x<- (10 *  exp(-0.00245 * dist10x))
    conc_PM2.5_AG10x<- (0.06 *  exp(-0.000356 * dist10x))
    }else {
      deposited_NH3_AG10x<-zero_raster
      conc_PM2.5_AG10x<-zero_raster
    }
   }else{
    deposited_NH3_AG10<-zero_raster
    conc_PM2.5_AG10<-zero_raster
    deposited_NH3_AG10x<-zero_raster
    conc_PM2.5_AG10x<-zero_raster
  }
  
  
  if (any(ext_livest %in% values(LU_complete))) {
    AG20<-reclassify(LU_complete, cbind(ext_livest,1), right=FALSE)
    AG20<-reclassify(AG20, cbind(2,70,NA), right=FALSE)
    dist20<-raster::distance(AG20)
    deposited_NH3_AG20<- (39 *  exp(-0.00245 * dist20))
    conc_PM2.5_AG20<- (0.66 *  exp(-0.000356 * dist20))  
    
    LU_patch_area20<-lsm_p_para(LU_patches$class_20)
    LU_patch_area20<-LU_patch_area20[,c(3,6)]
    LU_patch_area20$value <- 1/LU_patch_area20$value
    LU_patch_area20$value[which(LU_patch_area20$value <= 350)]<- NA
    LU_patch_area20$value[which(LU_patch_area20$value >350)]<-1
    
    if (length(which(LU_patch_area20$value == 1))> 0) {
      LU_patches_20<-LU_patches$class_20
      LU_patches_20<-raster(LU_patches_20)
      LU_patches_20<-reclassify(LU_patches_20,LU_patch_area20, right=F)
      dist20x<-raster::distance(LU_patches_20)
      deposited_NH3_AG20x<- (39 *  exp(-0.00245 * dist20x))
      conc_PM2.5_AG20x<- (0.66 *  exp(-0.000356 * dist20x))
    }else {
      deposited_NH3_AG20x<-zero_raster
      conc_PM2.5_AG20x<-zero_raster
    }
  }else{
    deposited_NH3_AG20<-zero_raster
    conc_PM2.5_AG20<-zero_raster
    deposited_NH3_AG20x<-zero_raster
    conc_PM2.5_AG20x<-zero_raster
  }
  
  
  if (any(int_arable %in% values(LU_complete))) {
    AG30<-reclassify(LU_complete, cbind(int_arable,1), right=FALSE)
    AG30<-reclassify(AG30, cbind(2,70,NA), right=FALSE)
    dist30<-raster::distance(AG30)
    deposited_NH3_AG30<- (13 *  exp(-0.00245 * dist30))
    conc_PM2.5_AG30<- (0.06 *  exp(-0.000356 * dist30)) 
    
    LU_patch_area30<-lsm_p_para(LU_patches$class_30)
    LU_patch_area30<-LU_patch_area30[,c(3,6)]
    LU_patch_area30$value <- 1/LU_patch_area30$value
    LU_patch_area30$value[which(LU_patch_area30$value <= 350)]<- NA
    LU_patch_area30$value[which(LU_patch_area30$value >350)]<-1
    
    if (length(which(LU_patch_area30$value == 1))> 0) {
      LU_patches_30<-LU_patches$class_30
      LU_patches_30<-raster(LU_patches_30)
      LU_patches_30<-reclassify(LU_patches_30,LU_patch_area30, right=F)
      dist30x<-raster::distance(LU_patches_30)
      deposited_NH3_AG30x<- (13 *  exp(-0.00245 * dist30x))
      conc_PM2.5_AG30x<- (0.06 *  exp(-0.000356 * dist30x))
    }else {
      deposited_NH3_AG30x<-zero_raster
      conc_PM2.5_AG30x<-zero_raster
    }
  }else{
    deposited_NH3_AG30<-zero_raster
    conc_PM2.5_AG30<-zero_raster
    deposited_NH3_AG30x<-zero_raster
    conc_PM2.5_AG30x<-zero_raster
  }
  
  
  if (any(int_livest %in% values(LU_complete))) {
    AG40<-reclassify(LU_complete, cbind(int_livest,1), right=FALSE)
    AG40<-reclassify(AG40, cbind(2,70,NA), right=FALSE)
    dist40<-raster::distance(AG40)
    deposited_NH3_AG40<- (84 *  exp(-0.00245 * dist40))
    conc_PM2.5_AG40<- (1.45 *  exp(-0.000356 * dist40))  
    
    LU_patch_area40<-lsm_p_para(LU_patches$class_40)
    LU_patch_area40<-LU_patch_area40[,c(3,6)]
    LU_patch_area40$value <- 1/LU_patch_area40$value
    LU_patch_area40$value[which(LU_patch_area40$value <= 350)]<- NA
    LU_patch_area40$value[which(LU_patch_area40$value >350)]<-1
    
    if (length(which(LU_patch_area40$value == 1))> 0) {
      LU_patches_40<-LU_patches$class_40
      LU_patches_40<-raster(LU_patches_40)
      LU_patches_40<-reclassify(LU_patches_40,LU_patch_area40, right=F)
      dist40x<-raster::distance(LU_patches_40)
      deposited_NH3_AG40x<- (84 *  exp(-0.00245 * dist40x))
      conc_PM2.5_AG40x<- (1.45 *  exp(-0.000356 * dist40x))
    }else {
      deposited_NH3_AG40x<-zero_raster
      conc_PM2.5_AG40x<-zero_raster
    }
   }else{
    deposited_NH3_AG40<-zero_raster
    conc_PM2.5_AG40<-zero_raster
    deposited_NH3_AG40x<-zero_raster
    conc_PM2.5_AG40x<-zero_raster
  }
  
  
   if (any(agropark %in% values(LU_complete))) {
    AG50<-reclassify(LU_complete, cbind(agropark,1), right=FALSE)
    AG50<-reclassify(AG50, cbind(2,70,NA), right=FALSE)
    dist50<-raster::distance(AG50)
    deposited_NH3_AG50<- (8.4 *  exp(-0.00245 * dist50))
    conc_PM2.5_AG50<- (0.14 *  exp(-0.000356 * dist50))  
    
    LU_patch_area50<-lsm_p_para(LU_patches$class_50)
    LU_patch_area50<-LU_patch_area50[,c(3,6)]
    LU_patch_area50$value <- 1/LU_patch_area50$value
    LU_patch_area50$value[which(LU_patch_area50$value <= 350)]<- NA
    LU_patch_area50$value[which(LU_patch_area50$value >350)]<-1
    
    if (length(which(LU_patch_area50$value == 1))> 0) {
      LU_patches_50<-LU_patches$class_50
      LU_patches_50<-raster(LU_patches_50)
      LU_patches_50<-reclassify(LU_patches_50,LU_patch_area50, right=F)
      dist50x<-raster::distance(LU_patches_50)
      deposited_NH3_AG50x<- (8.4 *  exp(-0.00245 * dist50x))
      conc_PM2.5_AG50x<- (0.14 *  exp(-0.000356 * dist50x))
    }else {
      deposited_NH3_AG50x<-zero_raster
      conc_PM2.5_AG50x<-zero_raster
    }
    }else{
    deposited_NH3_AG50<-zero_raster
    conc_PM2.5_AG50<-zero_raster
    deposited_NH3_AG50x<-zero_raster
    conc_PM2.5_AG50x<-zero_raster
    }
  
  # summing up all PM2.5 distributions
  conc_PM2.5_sum<- conc_PM2.5_AG10 +conc_PM2.5_AG20  + conc_PM2.5_AG30 +  conc_PM2.5_AG40 + conc_PM2.5_AG50 +
                  conc_PM2.5_AG10x +conc_PM2.5_AG20x  + conc_PM2.5_AG30x + conc_PM2.5_AG40x + conc_PM2.5_AG50x 
  HH<-conc_PM2.5_sum + zero_raster # cut to study area
  HH[which(values(LU_complete != 2) )]<-NA # show up only in urban land use
  HH_norm<-(HH - 0)/(4.2 - 0)*100 # normalized by worst case and best case
  HH_norm[HH_norm > 100]<- 100

  #write Raster
  hh_name<-paste0("HH_", "Game_", game_id, "_Round_", round_id, ".tif")
  writeRaster(x=HH_norm, filename=paste0("HH_", "Game_",game_id,"_Round_",round_id,".tif"),overwrite=TRUE, NAflag=-9999)
  hh_info <- list('name' = hh_name, 'id' = human_health)
  
  #### 3) MODEL: NH3  deposition #####
  # summing up all NH3 deposition rasters
  deposited_NH3_sum<- deposited_NH3_AG10 +deposited_NH3_AG20  + deposited_NH3_AG30  + deposited_NH3_AG40 + deposited_NH3_AG50 +
                      deposited_NH3_AG10x +deposited_NH3_AG20x  + deposited_NH3_AG30x  + deposited_NH3_AG40x + deposited_NH3_AG50x
  NP<-deposited_NH3_sum +zero_raster
  NP[which(values(LU_complete != 5 & LU_complete != 6 & LU_complete != 7 & LU_complete != 8 & LU_complete != 60) )]<-NA # show only in nature land uses
  NP_norm<-(NP - 0)/(180 - 0)*100 # normalized by worst case and best case scenario
  NP_norm[NP_norm > 100]<- 100

  # write Raster  
  np_name<-paste0("NP_", "Game_", game_id, "_Round_", round_id, ".tif")
  writeRaster(x=NP_norm, filename=paste0("NP_", "Game_",game_id,"_Round_",round_id,".tif"),overwrite=TRUE, NAflag=-9999)
  np_info <- list('name' = np_name, 'id' = nutrient_pollution)
  
  #### 4) MODEL: Surface water eutrophication #####
  soil_groups<-raster("soil_groups_hexa.tif")
  orig_leach<- zero_raster
  # attach leaching mass to area of agriculture type on sand and clay
  orig_leach[LU_complete == ext_arable & soil_groups == 1] <- 6.5
  orig_leach[LU_complete == ext_arable & soil_groups == 2] <- 5
  orig_leach[LU_complete == ext_livest & soil_groups == 1] <- 3
  orig_leach[LU_complete == ext_livest & soil_groups == 2] <- 2
  orig_leach[LU_complete == int_arable & soil_groups == 1] <- 18
  orig_leach[LU_complete == int_arable & soil_groups == 2] <- 10
  orig_leach[LU_complete == int_livest & soil_groups == 1] <- 75
  orig_leach[LU_complete == int_livest & soil_groups == 2] <- 36
  
  # calculate amount of distance-weighted leaching mass and of retaining land uses in each sub-watershed 
  trace_numbers<-read.csv("trace_numbers.csv") # numbers of sub-watersheds
  trace<-raster("trace.tif") #sub-watersheds
  distance_weight_trace<-raster("distance_weight_trace.tif") # distance in each sub-watershed to surface water entry point
  
  dist_leach<-orig_leach/(distance_weight_trace/100)
  sum_leach_dist<-as.data.frame(zonal(dist_leach,z=trace, fun=sum))
  
  trace_numbers$add_nat<-zonal(match(LU_complete, 60),trace, "count")
  trace_numbers$add_nat<-trace_numbers$add_nat[,"count"]
  trace_numbers$share_addnat<-trace_numbers$add_nat/trace_numbers$count
  trace_numbers$retention_addnat<-trace_numbers$share_addnat * 0.7
  trace_numbers$retention_sum<-(trace_numbers$retention_forestprod + trace_numbers$retention_forestnat+
                                  trace_numbers$retention_grass+ trace_numbers$retention_wet+  trace_numbers$retention_addnat )
  
  sum_leach_dist$final_leach_ret<-sum_leach_dist$value * (1-trace_numbers$retention_sum)
  final_leach_ret<-cbind(trace_numbers$value,sum_leach_dist$final_leach_ret)
  
  Water_IDs<-raster("Water_points_ID_raster.tif") # watershed entry points
  water_leach<-reclassify(Water_IDs, final_leach_ret, right=F)
  
  # focal mean over leaching massed in each watershed entry point
  water_leach_focal <- focal(water_leach, w = matrix(1,15,15), fun = mean,na.rm=T,pad=T,NAonly=F)
  water_leach_focal[which(values(LU_complete != 4 ))]<-NA
  water_leach_focal<-water_leach_focal+zero_raster

  WE_norm<-((water_leach_focal - 0)/(180 - 0))*100 # normalized by worst case and best case
  WE_norm[WE_norm > 100] <-100

  # write Raster
  we_name<-paste0("WE_", "Game_", game_id, "_Round_", round_id, ".tif")
  writeRaster(x=WE_norm, filename=paste0("WE_", "Game_",game_id,"_Round_",round_id,".tif"),overwrite=TRUE, NAflag=-9999)
  we_info <- list('name' = we_name, 'id' = water_eutrophication) 
  
  #### 5) MODEL: Water availability #####
  gvg_groups<-raster("gvg_hexa_raster.tif")#load GVG map
  orig_extract<- zero_raster
  # attach extraction values per GVG class and per agriculture type 
  orig_extract[LU_complete == ext_arable & gvg_groups == 1] <- 1
  orig_extract[LU_complete == ext_arable & gvg_groups == 2] <- 2
  orig_extract[LU_complete == ext_arable & gvg_groups == 3] <- 3
  orig_extract[LU_complete == ext_livest & gvg_groups == 1] <- 4
  orig_extract[LU_complete == ext_livest & gvg_groups == 2] <- 5
  orig_extract[LU_complete == ext_livest & gvg_groups == 3] <- 6
  orig_extract[LU_complete == int_arable & gvg_groups == 1] <- 7
  orig_extract[LU_complete == int_arable & gvg_groups == 2] <- 8
  orig_extract[LU_complete == int_arable & gvg_groups == 3] <- 9
  orig_extract[LU_complete == int_livest & gvg_groups == 1] <- 10
  orig_extract[LU_complete == int_livest & gvg_groups == 2] <- 11
  orig_extract[LU_complete == int_livest & gvg_groups == 3] <- 12
  
  # distance decay of extraction effect for each agriculture type in each GVG class
  # ext arable AG10
  if (length(which(values(orig_extract == 1))) > 0) {
    extract_AG10A<-NA_raster
    extract_AG10A[LU_complete == ext_arable & gvg_groups == 1]<-1
    dist_AG10A<-raster::distance(extract_AG10A)
    WA_AG10A <- 8.06 * exp(-0.0156 * dist_AG10A)
    
  }else{
    WA_AG10A <-zero_raster
  }
  
  
  if (length(which(values(orig_extract == 2))) > 0) {
    extract_AG10B<-NA_raster
    extract_AG10B[LU_complete == ext_arable & gvg_groups == 2]<-1
    dist_AG10B<-raster::distance(extract_AG10B)
    WA_AG10B <- 38.27 * exp(-0.005 * dist_AG10B)
    
  }else{
    WA_AG10B <-zero_raster
  }
  
  
  if (length(which(values(orig_extract == 3))) > 0) {
    extract_AG10C<-NA_raster
    extract_AG10C[LU_complete == ext_arable & gvg_groups == 3]<-1
    dist_AG10C<-raster::distance(extract_AG10C)
    WA_AG10C <- 50.48 * exp(-0.0033 * dist_AG10C)
    
  }else{
    WA_AG10C <-zero_raster
  }
  
  # ext livestock AG20
  if (length(which(values(orig_extract == 4))) > 0) {
    extract_AG20A<-NA_raster
    extract_AG20A[LU_complete == ext_livest & gvg_groups == 1]<-1
    dist_AG20A<-raster::distance(extract_AG20A)
    WA_AG20A <- 5.74 * exp(-0.0156 * dist_AG20A)
    
  }else{
    WA_AG20A <-zero_raster
  }
  
  
  if (length(which(values(orig_extract == 5))) > 0) {
    extract_AG20B<-NA_raster
    extract_AG20B[LU_complete == ext_livest & gvg_groups == 2]<-1
    dist_AG20B<-raster::distance(extract_AG20B)
    WA_AG20B <- 20.26 * exp(-0.0083 * dist_AG20B)
    
  }else{
    WA_AG20B <-zero_raster
  }
  
  if (length(which(values(orig_extract == 6))) > 0) {
    extract_AG20C<-NA_raster
    extract_AG20C[LU_complete == ext_livest & gvg_groups == 3]<-1
    dist_AG20C<-raster::distance(extract_AG20C)
    WA_AG20C <- 22.95 * exp(-0.0083 * dist_AG20C)
    
  }else{
    WA_AG20C <-zero_raster
  }
  
  # intensive arable AG30
  if (length(which(values(orig_extract == 7))) > 0) {
    extract_AG30A<-NA_raster
    extract_AG30A[LU_complete == int_arable & gvg_groups == 1]<-1
    dist_AG30A<-raster::distance(extract_AG30A)
    WA_AG30A <- 10.75 * exp(-0.0156 * dist_AG30A)
    
  }else{
    WA_AG30A <-zero_raster
  }
  
  if (length(which(values(orig_extract == 8))) > 0) {
    extract_AG30B<-NA_raster
    extract_AG30B[LU_complete == int_arable & gvg_groups == 2]<-1
    dist_AG30B<-raster::distance(extract_AG30B)
    WA_AG30B <- 51.02 * exp(-0.0033 * dist_AG30B)
    
  }else{
    WA_AG30B <-zero_raster
  }
  
  if (length(which(values(orig_extract == 9))) > 0) {
    extract_AG30C<-NA_raster
    extract_AG30C[LU_complete == int_arable & gvg_groups == 3]<-1
    dist_AG30C<-raster::distance(extract_AG30C)
    WA_AG30C <- 67.3 * exp(-0.0026 * dist_AG30C)
    
  }else{
    WA_AG30C <-zero_raster
  }
  
  
  # intensive livestock AG40
  if (length(which(values(orig_extract == 10))) > 0) {
    extract_AG40A<-NA_raster
    extract_AG40A[LU_complete == int_livest & gvg_groups == 1]<-1
    dist_AG40A<-raster::distance(extract_AG40A)
    WA_AG40A <- 7.65 * exp(-0.0156 * dist_AG40A)
    
  }else{
    WA_AG40A <-zero_raster
  }
  
  if (length(which(values(orig_extract == 11))) > 0) {
    extract_AG40B<-NA_raster
    extract_AG40B[LU_complete == int_livest & gvg_groups == 2]<-1
    dist_AG40B<-raster::distance(extract_AG40B)
    WA_AG40B <- 27.02 * exp(-0.005 * dist_AG40B)
    
  }else{
    WA_AG40B <-zero_raster
  }
  
  if (length(which(values(orig_extract == 12))) > 0) {
    extract_AG40C<-NA_raster
    extract_AG40C[LU_complete == int_livest & gvg_groups == 3]<-1
    dist_AG40C<-raster::distance(extract_AG40C)
    WA_AG40C <- 30.6 * exp(-0.005 * dist_AG40C)
    
  }else{
    WA_AG40C <-zero_raster
  }
  
  
  WA_sum<-WA_AG10A +WA_AG10B +WA_AG10C+WA_AG20A +WA_AG20B+WA_AG20C+
    WA_AG30A +WA_AG30B +WA_AG30C +WA_AG40A +WA_AG40B+WA_AG40C 
  WA_round<-WA_sum + zero_raster
  
  # in game: multiply sensible zones with WA_norm
  sensi_GW<-raster("sensi_GW_patch.tif")
  WA_vuln<-WA_round * sensi_GW
  WA_vuln[which(values(LU_complete != 5 & LU_complete != 6 & LU_complete != 7 & LU_complete != 8 & LU_complete != 60 ) )]<- NA # only in nature
  WA_norm<-(WA_vuln - 0)/(70 - 0)*100 # normalized by worst case and best case
  
  # write Raster
  wa_name<-paste0("WA_", "Game_", game_id, "_Round_", round_id, ".tif")
  writeRaster(x=WA_norm, filename=paste0("WA_", "Game_",game_id,"_Round_",round_id,".tif"),overwrite=TRUE, NAflag=-9999)
  wa_info <- list('name' = wa_name, 'id' = water_availability)
  
  #### 6) MODEL: Habitat cohesion #####
  # load pre-calculated rasters
  fix_nature_patches<- raster("fix_nature_patches.tif")
  fixed_HC_score<-raster("fixed_HC_score.tif")
  optimalHC_score<-raster("optimalHC_score.tif")
  worstHC_score<-raster("worstHC_score.tif")
  
  # calculate similarity index for each patch
  number_patches<- cellStats(fix_nature_patches, max)
  round_HC_score<- zero_raster
  agri_only<-reclassify(LU_complete, matrix(c(2,3,4,5,6,7,8,10,20,30,40,50,60,61,NA,NA,NA,NA,NA,NA,NA,10,20,30,40,50,60,61),nrow = 14), right=F)
  patch_df<-as.data.frame(cbind(c(10,20,30,40,50,60,61,NA), c(0.5,0.6,0.2,0.3,0,0.7,0.7,NA)))
  buffer_csv<-read.csv("buffer_list.csv",header=T, sep=";")
  
  for (i in 1:number_patches) {
    buffer_mask<- NA_raster
    targets<-as.numeric(buffer_csv[which(buffer_csv$buffer_df == i),2])
    values(buffer_mask)[targets] <-  1
    ring_round<- mask(agri_only, buffer_mask)
    ring_area<-as.data.frame(freq(ring_round))
    ring_area_df<-data.frame(patch_df, ring_area[match(patch_df[,1], ring_area[,1]),2])
    colnames(ring_area_df)<-c("V1", "V2", "V3")
    ring_area_df<-ring_area_df[-c(8),]
    ring_area_df[is.na(ring_area_df)] <- 0
    ring_area_df$V4<-(ring_area_df$V3*10000*ring_area_df$V2)/1000^2
    round_HC_score[fix_nature_patches == i]<- sum(ring_area_df$V4, na.rm=T)   
  } 
   
  round_HC_score[which(values(LU_complete != 5 & LU_complete != 6 & LU_complete != 7 & LU_complete != 8 ) )]<- NA
  round_tot_HC<-round_HC_score + fixed_HC_score  
  HC_norm<-(round_tot_HC - optimalHC_score)/( worstHC_score - optimalHC_score)*100 # normalize for best and worst case

  # write Raster
  hc_name<-paste0("HC_", "Game_", game_id, "_Round_", round_id, ".tif")
  writeRaster(x=HC_norm, filename=paste0("HC_", "Game_",game_id,"_Round_",round_id,".tif"),overwrite=TRUE, NAflag=-9999)
  hc_info <- list('name' = hc_name, 'id' = habitat_cohesion)
  
  #### 7) MODEL: Recreational value #####
  # assign in situ recreation quality
  rqq<-matrix(c(2,3,4,5,6,7,8,10,20,30,40,50,60,61,0,0,0,1,1,1,1,1,1,0.6,0.5,0,1,0),nrow = 14)
  RQ<-reclassify(LU_complete,rqq, right=FALSE)  # in situ recreational quality
  
  # spatial radiation of recreational quality 
  if (any(agropark %in% values(LU_complete))) {
    AG50_buff<-buffer(AG50, width=2500, dissolve=F)
    AG50_buff[values(AG50)==1]<-NA
    AG50_RSR<-(0.5-(dist50 *0.0002 * AG50_buff))*-1
    AG50_RSR[is.na(AG50_RSR)] <- 0
  }else{
    AG50_RSR<-zero_raster
  }
  
  if (any(int_livest %in% values(LU_complete))) {
    AG40_buff<-buffer(AG40, width=2500, dissolve=F)
    AG40_buff[values(AG40)==1]<-NA
    AG40_RSR<-(0.3-(dist40 *0.00012 * AG40_buff))*-1
    AG40_RSR[is.na(AG40_RSR)] <- 0
  }else{
    AG40_RSR<-zero_raster
  }
  
  if (any(add_nat %in% values(LU_complete))) {
    AG60<-reclassify(LU_complete, cbind(add_nat,1), right=FALSE)
    AG60<-reclassify(AG60, cbind(2,70,NA), right=FALSE)
    AG60_buff<-buffer(AG60, width=2500, dissolve=F)
    AG60_buff[values(AG60)==1]<-NA
    AG60_RSR<-(0.3 * AG60_buff)
    AG60_RSR[is.na(AG60_RSR)] <- 0
  }else{
    AG60_RSR<-zero_raster
  }

  RSR_total_round<- AG50_RSR + AG40_RSR + AG60_RSR
  RV_round<-RQ+RSR_total_round # both together
  RV_round[which(values(LU_complete== 2 | LU_complete== 3 | LU_complete== 4 ))] <- NA # show nature and agriculture
  RV_round[which(values(LU_complete== 50 ))] <- 0 # agropark stays 0
  RV_round[which(values(LU_complete== 61 ))] <- NA #  empty land is NA
  RV_round[which(values(RV_round < 0 ))] <- 0
  RV_round[which(values(RV_round >1 ))] <- 1
  RV_norm<-(1-RV_round) *100
  
  # write Raster
  rv_name<-paste0("RV_", "Game_", game_id, "_Round_", round_id, ".tif")
  writeRaster(x=RV_norm, filename=paste0("RV_","Game_",game_id,"_Round_",round_id,".tif"),overwrite=TRUE, NAflag=-9999)
  rv_info<- list('name' = rv_name, 'id' = recreational)  
  
  
  #### Scores #####
  # per round: The relative score of all cells that encounter the consequence: sum(score in cells that encounter consequence)/number of cells that encounter consequence
  score_HH<-round((cellStats(HH_norm, mean)/54 *100) ,0)
  score_NP<-round((cellStats(NP_norm, mean)/ 34 *100) , 0)
  score_WE<-round((cellStats(WE_norm, mean)/ 38 *100), 0)
  score_WA<-round((cellStats(WA_norm, mean)/ 25 *100), 0)
  score_HC<-round((cellStats(HC_norm, mean)/ 100 *100), 0) 
  score_RV<-round((cellStats(RV_norm, mean)/85*100), 0) 

  #NEW CODE
  hh_info['score']<-score_HH
  np_info['score']<-score_NP
  we_info['score']<-score_WE
  wa_info['score']<-score_WA
  hc_info['score']<-score_HC
  rv_info['score']<-score_RV
  
  # scores matrix
  scores_df<-as.data.frame(matrix(data=c("Luchtvervuiling \nin steden", "Verontreiniging \ndoor nutriënten \nin de natuur","Watervervuiling \ndoor nutriënten ", "Watertekort \nin de natuur", "Versnippering \nvan habitats", "Verlies van \nrecreatieve waarde",
                                            score_HH , score_NP, score_WE, score_WA, score_HC ,  score_RV), nrow = 6 , ncol=2, byrow = F)) 
  colnames(scores_df)<-c("consequence","scores")
  scores_df$scores<-as.numeric(scores_df$scores)
  
  #### Spider plot #####
  scores_df$max_cons<-rep(100,length(scores_df$consequence))
  scores_df$id<- seq(1,length(scores_df$consequence),1)
  
  p <-
    ggplot(scores_df, aes(x=as.factor(id), y=max_cons))+        
    geom_bar(aes(x=as.factor(id), y=max_cons),fill = "snow4", stat="identity", alpha=0.3) +
    geom_bar(aes(x=as.factor(id), y=scores, fill=consequence), stat="identity", alpha=0.9) +
    scale_fill_manual( values = rep("#de2d26",6))+
    theme_minimal() +
    theme(
      legend.position = "none",
      axis.text = element_blank(),
      axis.title = element_blank(),
      panel.grid = element_blank(),
      plot.margin = unit(rep(0.8,5), "cm") 
    ) +
    coord_polar()
  
  # Save your plot
 png(paste0("Spider_plot_","Game_",game_id,"_Round_",round_id,".png"), bg = 'transparent',  width = 5, height = 5, units = "cm", res = 900)
  plot(p)

  # Adding labels
  grid.text(scores_df[1,1], x=0.70,  y=0.85, gp=gpar(col="black", fontsize=4, fontface="bold"))
  grid.text(scores_df[2,1], x=0.89,  y=0.5, gp=gpar(col="black", fontsize=4, fontface="bold"))
  grid.text(scores_df[3,1], x=0.7,  y=0.17, gp=gpar(col="black", fontsize=4, fontface="bold"))
  grid.text(scores_df[4,1], x=0.3,  y=0.17, gp=gpar(col="black", fontsize=4, fontface="bold"))
  grid.text(scores_df[5,1], x=0.14,  y=0.5, gp=gpar(col="black", fontsize=4, fontface="bold"))
  grid.text(scores_df[6,1], x=0.30,  y=0.85, gp=gpar(col="black", fontsize=4, fontface="bold"))
  
  dev.off()

  #NEW CODE
  plot_name <- paste0("Spider_plot_", "Game_", game_id, "_Round_", round_id, ".png")
  plot_info <- list('name' = plot_name, 'id' = -1)
  
#### Upload #####
  #connect to GeoServer
  ## Geoserver
  gs_url <- geoserver_url
  gsman <-GSManager$new(
    url = gs_url, #baseUrl of the Geoserver
    user = "admin", pwd = "geoserver", #credentials
    logger = NULL #logger, for info or debugging purpose
  )
  
  #create GeoServer workspace for given game and round
  ws_name <- paste0("esgame_game",game_id, "_round",round_id)
  deleted <- gsman$deleteWorkspace(ws_name, recurse = TRUE)
  created <- gsman$createWorkspace(ws_name, paste0(geoserver_url, ws_name))
  
  ### raster upload

  raster_minx<-xmin(LU_complete)
  raster_miny <-ymin(LU_complete)
  raster_maxx <-xmax(LU_complete)
  raster_maxy <-ymax(LU_complete)
  raster_width <-res(LU_complete)[1]
  raster_height <-res(LU_complete)[2]
  raster_epsg <- 28992
  
 
  
  #register each raster into GeoServer
  #https://cran.r-project.org/web/packages/geosapi/vignettes/geosapi.html#GSCoverage-upload
  
  calculated_rasters <- list(hh_info, np_info, we_info, wa_info, hc_info, rv_info, plot_info)
  
  #CHANGED CODE --> loop over calculated rasters which contains all the informations
  for (i in 1:length(calculated_rasters)) {
    if(calculated_rasters[[i]]['id'] == -1) {
      calculated_rasters[[i]]['url'] = paste0(req$rook.url_scheme,"://", req$HTTP_HOST, "/images/", calculated_rasters[[i]]['name'])
    } else {
  short_name <- substring(calculated_rasters[[i]]['name'], 1, nchar(calculated_rasters[[i]]['name'])-4)
  log_info("Attempting upload of {short_name} from {calculated_rasters[[i]]['path']}")
  uploaded <- gsman$uploadGeoTIFF(
    ws = ws_name, cs = short_name,
    endpoint = "file", configure = "none", update = "overwrite",
    filename = paste0(directory, '/', calculated_rasters[[i]]['name'])
  )
  
  #create coverage object
  cov <- GSCoverage$new()
  cov$setName(short_name)
  cov$setNativeName(short_name)
  cov$setTitle(paste("Title for", short_name))
  cov$setDescription(paste("Description for", short_name))
  cov$addKeyword(paste(short_name,"keyword1"))
  cov$addKeyword(paste(short_name,"keyword2"))
  cov$addKeyword(paste(short_name,"keyword3"))
  
  md1 <- GSMetadataLink$new(
    type = "text/xml",
    metadataType = "ISO19115:2003",
    content = "http://somelink.org/sfdem_new/xml"
  )
  cov$addMetadataLink(md1)
  md2 <- GSMetadataLink$new(
    type = "text/html",
    metadataType = "ISO19115:2003",
    content = "http://somelink.org/sfdem_new/html"
  )
  cov$addMetadataLink(md2)
  
  cov$setSrs(paste("EPSG:",raster_epsg))
  cov$setNativeCRS(paste("EPSG:",raster_epsg))
  cov$setProjectionPolicy("FORCE_DECLARED")
  cov$setLatLonBoundingBox(5.0332222794293484, 51.5304424429716477, 5.7127527056648306, 51.8315979727805569, crs = "EPSG:4326")
  cov$setNativeBoundingBox(raster_minx, raster_miny, raster_maxx, raster_maxy, crs = paste("EPSG:",raster_epsg))
  
  created <- gsman$createCoverage(ws = ws_name, cs = short_name, coverage = cov)
  
  raster_url <- paste0(gs_url , "/wcs?service=WCS&version=2.0.1&request=GetCoverage" ,
                           "&coverageId=" , ws_name , ":" , short_name ,
                           "&format=image%2Fgeotiff" )
  
  calculated_rasters[[i]]['url'] = raster_url
  log_info("Constructed URL for  {short_name}: from {raster_url}")
  
 
  }
  
  }
 
  
  
  
  return(list(results = calculated_rasters))
}
