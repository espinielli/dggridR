#' @importFrom utils read.csv read.table tail write.table
#' @importFrom rgdal readOGR
#' @importFrom rgdal writeOGR
#' @importFrom ggplot2 fortify
#' @importFrom methods as
#' @import     dplyr
#' @import     sp
#' @useDynLib  dggridR


#' @name dg_env
#' 
#' @title Control global aspects of the dggridR package
#'
#' @description
#'        This environment is used to control global features of the dggridR
#'        package. At the moment the only option is 'dg_debug' which, when set
#'        to TRUE provides extensive outputs useful for tracking down bugs.
#'
dg_env <- new.env()
assign("dg_debug", FALSE, envir=dg_env)

#' @name dg_shpfname_south_africa
#' 
#' @title National border of South Africa
#'
#' @description
#'        This variable points to a shapefile containing the national border
#'        of South Africa
#'
#' @return A filename of a shapefile containing the national border of South Africa
#'
#' @export
dg_shpfname_south_africa <- function(){
  file.path(find.package('dggridR'), "extdata", "ZAF_adm0.shp")
}



#' @name dgconstruct
#' 
#' @title      Construct a discrete global grid system (dggs) object
#'
#' @description
#'             Construct a discrete global grid system (dggs) object
#' 
#' @param projection Type of grid to use. Options are: ISEA and FULLER.
#'                   Default: ISEA3H
#'
#' @param topology   Shape of cell. Options are: HEXAGON, DIAMOND, TRIANGLE.
#'                   Default: HEXAGON
#'
#' @param aperture   How finely subsequent resolution levels divide the grid.
#'                   Options are: 3, 4. Not all options work with all 
#'                   projections and topologies.
#'                   Default: 3
#'
#' @param res  Resolution. Must be in the range [0,30]. Larger values represent
#'             finer resolutions. Appropriate resolutions can be found with
#'             dg_closest_res_to_area(), dg_closest_res_to_spacing(), and
#'             dg_closest_res_to_cls(). Default is 9, which corresponds to a
#'             cell area of ~2600 sq km and a cell spacing of ~50 km.
#'             Only one of res, area, length, or cls should be used.
#'
#' @param precision Round output to this number of decimal places. Must be in
#'                  the range [0,30]. Default: 7.
#'
#' @param area      The desired area of the grid's cells.
#'                  Only one of res, area, length, or cls should be used.
#'
#' @param spacing   The desired spacing between the center of adjacent cells.
#'                  Only one of res, area, length, or cls should be used.
#'
#' @param cls       The desired CLS of the cells.
#'                  Only one of res, area, length, or cls should be used.
#'
#' @param resround  What direction to search in. Must be nearest, up, or down.
#'
#' @param show_info Print the area, spacing, and CLS of the chosen resolution.
#'
#' @param metric    Whether input and output should be in metric (TRUE) or
#'                  imperial (FALSE)
#'
#' @param azimuth_deg   Rotation in degrees of grid about its pole, value in [0,360].
#'                      Default=0.
#'
#' @param pole_lat_deg  Latitude in degrees of the pole, value in [-90,90].
#'                      Default=58.28252559.
#'
#' @param pole_lon_deg  Longitude in degrees of the pole, value in [-180,180].
#'                      Default=11.25.
#'
#' @return          Returns a dggs object which can be passed to other dggridR
#'                  functions
#'
#' @examples 
#' \dontrun{
#' library(dggridR)
#' dggs <- dgconstruct(res=20)
#'
#' dggs <- dgconstruct(area=5,metric=FALSE)
#' }
#' @export 
dgconstruct <- function(
  projection   = 'ISEA',
  aperture     = 3,
  topology     = 'HEXAGON',
  res          = NA,
  precision    = 7,
  area         = NA,
  spacing      = NA,
  cls          = NA,
  resround     = 'nearest',
  metric       = TRUE,
  show_info    = TRUE,
  azimuth_deg  = 0,
  pole_lat_deg = 58.28252559,
  pole_lon_deg = 11.25
){
  if(sum(!is.na(c(res,area,spacing,cls)))!=1)
    stop('dgconstruct(): Only one of res, area, length, or cls can have a value!')

  #Use a dummy resolution, we'll fix it in a moment
  dggs <- list(
    pole_lon_deg = pole_lon_deg,
    pole_lat_deg = pole_lat_deg,
    azimuth_deg  = azimuth_deg,
    aperture     = aperture,
    res          = 1,
    topology     = topology,
    projection   = projection,
    precision    = precision
  )

  if(!is.na(res))
    dggs[['res']] = res
  else if(!is.na(area))
    dggs[['res']] = dg_closest_res_to_area   (dggs,area=area,      round=resround,metric=metric,show_info=TRUE)
  else if(!is.na(spacing))
    dggs[['res']] = dg_closest_res_to_spacing(dggs,spacing=spacing,round=resround,metric=metric,show_info=TRUE)
  else if(!is.na(cls))
    dggs[['res']] = dg_closest_res_to_cls    (dggs,cls=cls,        round=resround,metric=metric,show_info=TRUE)
  else
    stop('dgconstruct(): Logic itself has failed us.')

  dgverify(dggs)

  dggs
}



#' @name dgsetres
#' 
#' @title Set the resolution of a dggs object
#'
#' @description
#'             Set the resolution of a dggs object
#'
#' @param dggs A dggs object from dgconstruct().
#'
#' @param res  Resolution. Must be in the range [0,30]. Larger values represent
#'             finer resolutions. Appropriate resolutions can be found with
#'             dg_closest_res_to_area(), dg_closest_res_to_spacing(), and
#'             dg_closest_res_to_cls(). Default is 9, which corresponds to a
#'             cell area of ~2600 sq km and a cell spacing of ~50 km.
#'             Default: 9.
#'
#' @return     Returns a dggs object which can be passed to other dggridR
#'             functions
#'
#' @examples 
#' \dontrun{
#' library(dggridR)
#' dggs <- dgconstruct(res=20)
#' dggs <- dgsetres(dggs,10)
#' }
#' @export 
dgsetres <- function(dggs,res){
  dggs[['res']] = res
  dgverify(dggs)
  dggs
}



#' @name dgverify
#' 
#' @title Verify that a dggs object has appropriate values
#'
#' @description
#'             Verify that a dggs object has appropriate values
#' 
#' @param dggs The dggs object to be verified
#'
#' @return     The function has no return value. A stop signal is raised if the
#'             object is misspecified
#' @examples
#' \dontrun{
#' library(dggridR)
#' dggs <- dgconstruct(res=20)
#' dgverify(dggs)
#' }
#' @export
dgverify <- function(dggs){
  #See page 21 of documentation for further bounds
  if(!(dggs[['projection']] %in% c('ISEA','FULLER')))
    stop('Unrecognised dggs projection', call.=FALSE) #TODO: Where can they get valid types?
  if(!(dggs[['topology']] %in% c('HEXAGON','DIAMOND','TRIANGLE')))
    stop('Unrecognised dggs topology', call.=FALSE) #TODO: Where can they get valid types?
  if(!(dggs[['aperture']] %in% c(3,4)))
    stop('Unrecognised dggs aperture', call.=FALSE) #TODO: Where can they get valid types?
  if(dggs[['res']]<0)
    stop('dggs resolution must be >=0', call.=FALSE)
  if(dggs[['res']]>30)
    stop('dggs resolution must be <=30', call.=FALSE)
  if(dggs[['azimuth_deg']]<0 || dggs[['azimuth_deg']]>360)
    stop('dggs azimuth_deg must be in the range [0,360]')
  if(dggs[['pole_lat_deg']]<(-90) || dggs[['pole_lat_deg']]>90)
    stop('dggs pole_lat_deg must be in the range [-90,90]')
  if(dggs[['pole_lon_deg']]<(-180) || dggs[['pole_lon_deg']]>180)
    stop('dggs pole_lon_deg must be in the range [-180,180]')
  if(!all.equal(dggs[['res']], as.integer(dggs[['res']])))
    stop('dggs resolution must be an integer', call.=FALSE)
}



#' @name dgtransform
#' 
#' @title (DEPRECATED) Converts lat-long pairs into discrete global grid cell numbers
#'
#' @description
#'          A discrete global grid maps lat-long points to particular cells.
#'          These cells are uniquely numbered, for a given resolution, from
#'          1 to some maximum number. Cell numbers may be reused from one
#'          resolution to the next.
#'          THIS FUNCTION IS DEPRECATED.
#' 
#' @param dggs A dggs object from dgconstruct().
#'
#' @param lat  A vector of latitudes. Same length at the longtiudes
#'
#' @param lon  A vector of longitudes. Same length as the latitudes.
#'
#' @return     A vector of the same length as latitudes and longitudes 
#'             containing the cell id numbers of the points' cells
#'             in the discrete grid.
#'
#' @examples 
#' \dontrun{
#' library(dggridR)
#' data(dgquakes)
#'
#' #Construct a grid with cells about ~1000 miles wide
#' dggs          <- dgconstruct(spacing=1000,metric=FALSE) 
#' dgquakes$cell <- dgtransform(dggs,dgquakes$lat,dgquakes$lon)
#' }
#' @export 
dgtransform <- function(dggs, lat, lon){ #TODO: Make sure we're not modifying the original dggs
  dgverify(dggs)

  warning("The 'dgtransform(dggs,lat,lon)' function has been deprecated. Please use 'dgGEO_to_SEQNUM(dggs,lon,lat)' instead! NOTE THE ARGUMENT ORDER!")

  dgGEO_to_SEQNUM(dggs, lon, lat)$seqnum
}



#' @name dginfo
#' 
#' @title Print a buncha info about a dggs object to the screen
#'
#' @description
#'          dggs objects have many settings. This returns all of them, along
#'          with info about the grid being specified.
#' 
#' @param dggs A dggs object from dgconstruct()
#'
#' @return No return. All info is printed to the screen.
#'
#' @examples 
#' \dontrun{
#' library(dggridR)
#' dggs <- dgconstruct(res=20)
#' dginfo(dggs)
#' }
#' @export 
dginfo <- function(dggs){
  dgverify(dggs)

  res <- dggetres(dggs)

  scipen <- getOption('scipen')
  options(scipen=999)

  print(res, sep="\r\n")

  options(scipen=scipen)

  NULL
}



#' @name dggetres
#' 
#' @title      Get table of grid resolution information
#'
#' @description
#'             Gets a grid's resolution and cell property info as a data frame.
#' 
#' @param dggs A dggs object from dgconstruct()
#'
#' @return     A data frame containing the resolution levels, number of cells,
#'             area of those cells, intercell spacing, and characteristic length
#'             scale of the cells. All values are in kilometres.
#'
#' @examples 
#' \dontrun{
#' library(dggridR)
#' dggs <- dgconstruct(res=20)
#' dggetres(dggs)
#' }
#' @export 
dggetres <- function(dggs){
  dgverify(dggs)

  ress <- 0:30

  data.frame(
    res        = ress,
    cells      = sapply(ress, function(r) GridStat_nCells(dggs[['projection']], dggs[['topology']], dggs[['aperture']], r)),
    area_km    = sapply(ress, function(r) GridStat_cellAreaKM(dggs[['projection']], dggs[['topology']], dggs[['aperture']], r)),
    spacing_km = sapply(ress, function(r) GridStat_cellDistKM(dggs[['projection']], dggs[['topology']], dggs[['aperture']], r)),
    cls_km     = sapply(ress, function(r) GridStat_cls(dggs[['projection']], dggs[['topology']], dggs[['aperture']], r))
  )
}



#' @name dgmaxcell
#' 
#' @title      Get largest cell id for a dggs
#'
#' @description
#'             Cells are labeled 1-N. This function returns N. This is useful if
#'             you want to choose cells from the dggs randomly.
#' 
#' @param dggs A dggs object from dgconstruct()
#'
#' @param res  If NA, use the resolution specified by the dggs. Otherwise,
#'             override the resolution.
#'
#' @return     The maximum cell id.
#'
#' @examples 
#' \dontrun{
#' #Choose a set of cells randomly distributed over the Earth
#' library(dggridR)
#' dggs    <- dgconstruct(spacing=1000, metric=FALSE, resround='down')
#' N       <- 100                                 #Number of cells
#' maxcell <- dgmaxcell(dggs)                     #Get maximum cell id
#' cells   <- sample(1:maxcell, N, replace=FALSE) #Choose random cells
#' grid    <- dgcellstogrid(dggs,cells,frame=TRUE,wrapcells=TRUE) #Get grid
#' }
#' @export 
dgmaxcell <- function(dggs,res=NA){
  dgverify(dggs)

  reses <- dggetres(dggs)

  restoget <- dggs[['res']]
  if(!is.na(res))
    restoget <- res

  #Add one because R uses 1-based indexing and there is a row 0
  reses$cells[restoget+1] 
}



#' @name dg_closest_res
#' 
#' @title Determine an appropriate grid resolution based on input data.
#'
#' @description
#'          This is a generic function that is used to determine an appropriate
#'          resolution given an area, cell spacing, or correlated length scale.
#'          It does so by extracting the appropriate length/area column and
#'          searching it for a value close to the input.
#'
#' @param dggs      A dggs object from dgconstruct()
#'
#' @param col       Column in which to search for a close value. Should be: 
#'                  AreaKm, SpacingKm, or CLSKm.
#'
#' @param val       The value to search for
#'
#' @param round     What direction to search in. Must be nearest, up, or down.
#'
#' @param show_info Print the area, spacing, and CLS of the chosen resolution.
#'
#' @param metric    Whether input and output should be in metric (TRUE) or
#'                  imperial (FALSE)
#'
#' @return A number representing the grid resolution
#'
#' @examples 
#' \dontrun{
#' library(dggridR)
#' dggs <- dgconstruct(res=20)
#' res  <- dg_closest_res(dggs,'AreaKm',1)
#' dggs <- dgsetres(dggs,res)
#' }
dg_closest_res <- function(dggs,col,val,round='nearest',show_info=TRUE,metric=TRUE){
  KM_TO_M <- 0.621371

  dgverify(dggs)

  ret <- dggetres(dggs)

  searchvec = ret[col]

  if(!metric)
    searchvec <- searchvec*KM_TO_M #Convert kilometers to miles

  searchvec <- unlist(searchvec, use.names=FALSE)

  if(round=='up')
    idx <- max(which(searchvec>val))
  else if(round=='down')
    idx <- min(which(searchvec<val))
  else if(round=='nearest')
    idx <- which.min(abs(searchvec-val))
  else
    stop('Unrecognised rounding direction. Must be up, down, or nearest.', call.=FALSE)

  if(show_info && metric)
    cat(paste("Resolution: ",ret$res[idx],", Area (km^2): ",ret$area_km[idx],", Spacing (km): ", ret$spacing_km[idx],", CLS (km): ", ret$cls_km[idx], "\n", sep=""))
  else if(show_info && !metric)
    cat(paste("Resolution: ",ret$res[idx],", Area (mi^2): ",ret$area_km[idx]*KM_TO_M,", Spacing (mi): ", ret$spacing_km[idx]*KM_TO_M,", CLS (mi): ", ret$cls_km[idx]*KM_TO_M, "\n", sep=""))

  ret$res[idx]
}



#' @name dg_closest_res_to_area
#' 
#' @title           Determine resolution based on desired area
#'
#' @description
#'                  Determine an appropriate grid resolution based on a desired 
#'                  cell area.
#'
#' @param dggs      A dggs object from dgconstruct()
#'
#' @param area      The desired area of the grid's cells
#'
#' @param round     What direction to search in. Must be nearest, up, or down.
#'
#' @param show_info Print the area, spacing, and CLS of the chosen resolution.
#'
#' @param metric    Whether input and output should be in metric (TRUE) or
#'                  imperial (FALSE)
#'
#' @return A number representing the grid resolution
#'
#' @examples 
#' \dontrun{
#' library(dggridR)
#' dggs <- dgconstruct(res=20)
#' res  <- dg_closest_res_to_area(dggs,1)
#' dggs <- dgsetres(dggs,res)
#' }
#' @export 
dg_closest_res_to_area <- function(dggs,area,round='nearest',show_info=TRUE,metric=TRUE){
  dg_closest_res(dggs,'area_km',area,round,show_info,metric)
}



#' @name dg_closest_res_to_spacing
#' 
#' @title           Determine grid resolution from desired spacing.
#'
#' @description     Determine an appropriate grid resolution based on a desired 
#'                  spacing between the center of adjacent cells.
#'
#' @param dggs      A dggs object from dgconstruct()
#'
#' @param spacing   The desired spacing between the center of adjacent cells
#'
#' @param round     What direction to search in. Must be nearest, up, or down.
#'
#' @param show_info Print the area, spacing, and CLS of the chosen resolution.
#'
#' @param metric    Whether input and output should be in metric (TRUE) or
#'                  imperial (FALSE)
#'
#' @return A number representing the grid resolution
#'
#' @examples 
#' \dontrun{
#' library(dggridR)
#' dggs <- dgconstruct(res=20)
#' res  <- dg_closest_res_to_spacing(dggs,1)
#' dggs <- dgsetres(dggs,res)
#' }
#' @export 
dg_closest_res_to_spacing <- function(dggs,spacing,round='nearest',show_info=TRUE,metric=TRUE){
  dg_closest_res(dggs,'spacing_km',spacing,round,show_info,metric)
}



#' @name dg_closest_res_to_cls
#' 
#' @title Determine an appropriate grid resolution based on a desired 
#'        characteristic length scale of the cells.
#'
#' @description
#'          The characteristic length scale (CLS) is the diameter of a spherical
#'          cap of the same area as a cell of the specified resolution.
#'
#' @param dggs      A dggs object from dgconstruct()
#'
#' @param cls       The desired CLS of the cells.
#'
#' @param round     What direction to search in. Must be nearest, up, or down.
#'
#' @param show_info Print the area, spacing, and CLS of the chosen resolution.
#'
#' @param metric    Whether input and output should be in metric (TRUE) or
#'                  imperial (FALSE)
#'
#' @return A number representing the grid resolution
#'
#' @examples 
#' \dontrun{
#' library(dggridR)
#' dggs <- dgconstruct(res=20)
#' res  <- dg_closest_res_to_cls(dggs,1)
#' dggs <- dgsetres(dggs,res)
#' }
#' @export
dg_closest_res_to_cls <- function(dggs,cls,round='nearest',show_info=TRUE,metric=TRUE){
  dg_closest_res(dggs,'cls_km',cls,round,show_info,metric)
}



#' @name dg_process_polydata
#' 
#' @title   Load a KML file
#'
#' @description     Convert data from internal dggrid functions into something
#'                  useful: an sp object or a data frame
#'
#' @param polydata  Polygons generated by dggrid. These will be converted.
#'
#' @param frame     If TRUE, return a data frame suitable for ggplot plotting.
#'                  If FALSE, return an SpatialPolygons
#'
#' @param wrapcells Cells which cross -180/180 degrees can present 
#'                  difficulties for plotting. Setting this TRUE will result in
#'                  cells with components in both hemispheres to be mapped
#'                  entirely to positive degrees (the Eastern hemisphere). As a
#'                  result, such cells will have components in the range
#'                  [180,360). Only used when \code{frame=TRUE}.
#'
#' @return Returns a data frame or OGR poly object, as specified by \code{frame}
#'
dg_process_polydata <- function(polydata,frame,wrapcells){
  polydata  <- as.data.frame(polydata)
  polydata  <- split(polydata, polydata$seqnum)
  an        <- names(polydata)
  polydata  <- lapply(polydata, function(x) { x["seqnum"] <- NULL; x })
  polydata  <- lapply(polydata, Polygon)
  polydata  <- lapply(seq_along(polydata), function(i) Polygons(list(polydata[[i]]), ID = an[i]  ))
  polydata  <- SpatialPolygons(polydata, proj4string = CRS("+proj=longlat +datum=WGS84") )

  #These two lines suppress a WARNING message that would otherwise be raised by
  #`R CMD check` due to the use of dplyr
  long  <- NULL
  group <- NULL

  if(frame){
    polydata.points      <- fortify(polydata, region="seqnum")
    polydata.points$cell <- polydata.points$id
    polydata.points$id   <- NULL

    if(wrapcells){
      #Find dangerous polygons based on how many degrees of longitude they span
      groups_to_wrap <- polydata.points %>% group_by(group) %>% summarise(diff=max(long)-min(long)) %>% filter(diff>180) %>% select(group)

      #Adjust them so they appear on the eastern side of the map
      polydata.points <- polydata.points %>% mutate(long=ifelse(group %in% groups_to_wrap$group, ifelse(long<0,long+360,long), long))
    }

    #Arrange polygon points so they are ordered appropriately, otherwise the results
    #will not be nice, closed cells, but weird triangular thingies
    polydata.points %>% arrange(group,order)

  } else {
    polydata
  }
}



#' @name dgrectgrid
#' 
#' @title   Return the coordinates constituting the boundary of cells within a
#'          specified region
#'
#' @description     Note: This may generate odd results for very large
#'                  rectangles, because putting rectangles on spheres is
#'                  weird... as you should know, if you're using this package.
#'
#' @param dggs      A dggs object from dgconstruct()
#'
#' @param minlat    Minimum latitude of region of interest
#'
#' @param minlon    Minimum longitude of region of interest
#'
#' @param maxlat    Maximum latitude of region of interest
#'
#' @param maxlon    Maximum longitude of region of interest
#'
#' @param frame     If TRUE, return a data frame suitable for ggplot plotting.
#'                  If FALSE, return an OGR poly object
#'
#' @param wrapcells Cells which cross -180/180 degrees can present 
#'                  difficulties for plotting. Setting this TRUE will result in
#'                  cells with components in both hemispheres to be mapped
#'                  entirely to positive degrees (the Eastern hemisphere). As a
#'                  result, such cells will have components in the range
#'                  [180,360). Only used when \code{frame=TRUE}.
#'
#' @param cellsize  Distance, in degrees, between the sample points used to
#'                  generate the grid. Small values yield long generation times
#'                  while large values may omit cells.
#'
#' @param savegrid  If savegrid is set to a file path, then a shapefile 
#'                  containing the grid is written to that path and the filename
#'                  is returned. No other manipulations are done.
#'                  Default: NA (do not save grid, return it)
#'
#' @return Returns a data frame or OGR poly object, as specified by \code{frame}.
#'         If \code{!is.na(savegrid)}, returns a filename.
#'
#' @examples 
#' \dontrun{
#' library(dggridR)
#' dggs <- dgconstruct(spacing=1000,metric=FALSE,resround='down')
#'
#' #Get grid cells for the conterminous United States
#' grid <- dgrectgrid(dggs,
#'                minlat=24.7433195, minlon=-124.7844079, 
#'                maxlat=49.3457868, maxlon=-66.9513812, frame=TRUE)
#' }
#' @export
dgrectgrid <- function(dggs,minlat=-1,minlon=-1,maxlat=-1,maxlon=-1,cellsize=0.1,frame=TRUE,wrapcells=TRUE,savegrid=NA){ #TODO: Densify?
  dgverify(dggs) 

  coords <- matrix(c(minlon, minlat, maxlon, minlat, maxlon, maxlat, maxlon, minlat, minlon, minlat), ncol = 2, byrow = TRUE)
  regbox <- Polygon(coords)
  regbox <- SpatialPolygons(list(Polygons(list(regbox), ID = "a")), proj4string=CRS("+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"))

  #Generate a dense grid of points
  samp_points <- sp::makegrid(regbox, cellsize = cellsize)

  #Convert the points to SEQNUM ids for dggs
  samp_points <- dgGEO_to_SEQNUM(dggs,samp_points$x1, samp_points$x2)$seqnum

  dgcellstogrid(dggs, samp_points, frame=frame, wrapcells=wrapcells, savegrid=savegrid)
}



#' @name dgearthgrid
#' 
#' @title   Return the coordinates constituting the boundary of cells for the
#'          entire Earth
#'
#' @description     Note: If you have a high-resolution grid this may take a
#'                  loooooong time to execute.
#'
#' @param dggs      A dggs object from dgconstruct()
#'
#' @param frame     If TRUE, return a data frame suitable for ggplot plotting.
#'                  If FALSE, return an OGR poly object
#'
#' @param wrapcells Cells which cross -180/180 degrees can present 
#'                  difficulties for plotting. Setting this TRUE will result in
#'                  cells with components in both hemispheres to be mapped
#'                  entirely to positive degrees (the Eastern hemisphere). As a
#'                  result, such cells will have components in the range
#'                  [180,360). Only used when \code{frame=TRUE}.
#'
#' @param savegrid  If savegrid is set to a file path, then a shapefile 
#'                  containing the grid is written to that path and the filename
#'                  is returned. No other manipulations are done.
#'                  Default: NA (do not save grid, return it)
#'
#' @return Returns a data frame or OGR poly object, as specified by \code{frame}.
#'         If \code{!is.na(savegrid)}, returns a filename.
#'
#' @examples 
#' \dontrun{
#' library(dggridR)
#' dggs         <- dgconstruct(res=20)
#' res          <- dg_closest_res_to_spacing(dggs,spacing=1000,round='down',metric=FALSE)
#' dggs         <- dgsetres(dggs,res)
#' gridfilename <- dgearthgrid(dggs,savegrid="temp.shp") #Save directly to a file
#' }
#' @export
dgearthgrid <- function(dggs,frame=TRUE,wrapcells=TRUE,savegrid=NA){ #TODO: Densify?
  dgverify(dggs) 

  grid <- GlobalGrid(dggs[["pole_lon_deg"]], dggs[["pole_lat_deg"]], dggs[["azimuth_deg"]], dggs[["aperture"]], dggs[["res"]], dggs[["topology"]], dggs[["projection"]])
  if(is.na(savegrid)){
    dg_process_polydata(grid,frame,wrapcells)
  } else {
    grid <- dg_process_polydata(grid,frame=FALSE,wrapcells=FALSE)
    dgsavegrid(grid,savegrid)
  }
}



#' @name dgcellstogrid
#' 
#' @title           Return boundary coordinates for specified cells
#'
#' @description     Returns the coordinates constituting the boundary of a 
#'                  specified set of cells. Duplicates are eliminated to reduce
#'                  processing and storage requirements.
#'
#' @param dggs      A dggs object from dgconstruct()
#'
#' @param cells     The cells to get the boundaries of
#'
#' @param frame     If TRUE, return a data frame suitable for ggplot plotting.
#'                  If FALSE, return an OGR poly object
#'
#' @param wrapcells Cells which cross -180/180 degrees can present 
#'                  difficulties for plotting. Setting this TRUE will result in
#'                  cells with components in both hemispheres to be mapped
#'                  entirely to positive degrees (the Eastern hemisphere). As a
#'                  result, such cells will have components in the range
#'                  [180,360). Only used when \code{frame=TRUE}.
#'
#' @param savegrid  If savegrid is set to a file path, then a shapefile 
#'                  containing the grid is written to that path and the filename
#'                  is returned. No other manipulations are done.
#'                  Default: NA (do not save grid, return it)
#'
#' @return Returns a data frame or OGR poly object, as specified by \code{frame}.
#'         If \code{!is.na(savegrid)}, returns a filename.
#'
#' @examples 
#' \dontrun{
#' library(dggridR)
#' data(dgquakes)
#'
#' #Construct a grid with cells about ~1000 miles wide
#' dggs          <- dgconstruct(spacing=1000,metric=FALSE) 
#' dgquakes$cell <- dgtransform(dggs,dgquakes$lat,dgquakes$lon)
#'
#' #Get grid cells for the earthquakes identified
#' grid          <- dgcellstogrid(dggs, dgquakes$cell, frame=TRUE)
#' }
#' @export
dgcellstogrid <- function(dggs,cells,frame=TRUE,wrapcells=TRUE,savegrid=NA){ #TODO: Densify?
  dgverify(dggs) 

  #dggrid also eliminates duplicate cells, but doing so here saves disk space
  #and likely wall time, given the costs of IO, not that it matters unless the
  #data set is huge
  cells <- unique(cells)

  if(max(cells)>dgmaxcell(dggs))
    stop("'cells' contained cell ids which were larger than the maximum id!")

  grid <- SeqNumGrid(dggs[["pole_lon_deg"]], dggs[["pole_lat_deg"]], dggs[["azimuth_deg"]], dggs[["aperture"]], dggs[["res"]], dggs[["topology"]], dggs[["projection"]], cells)
  if(is.na(savegrid)){
    dg_process_polydata(grid,frame,wrapcells)
  } else {
    grid <- dg_process_polydata(grid,frame=FALSE,wrapcells=FALSE)
    dgsavegrid(grid,savegrid)
  }
}



#' @name dgsavegrid
#'
#' @title           Saves a generated grid to a shapefile
#'
#' @description     Saves a generated grid to a shapefile
#'
#' @param grid      Grid to be saved
#' @param shpfname  File to save the grid to
#'
#' @return          The filename the grid was saved to
dgsavegrid <- function(grid,shpfname) {
  grid<-as(grid, "SpatialPolygonsDataFrame")
  writeOGR(grid, shpfname, driver='ESRI Shapefile', layer='dggrid')
  shpfname
}



#' @name dgshptogrid
#' 
#' @title           Return boundary coordinates for cells intersecting a 
#'                  shapefile
#'
#' @description     Returns the coordinates constituting the boundary of a 
#'                  set of cells which intersect or are contained by a polygon
#'                  (or polygons) specified in a shapefile. Note that grid cells
#'                  are also generated for holes in the shapefile's polygon(s).
#'
#'                  Note that coordinates in the shapefile must be rounded to
#'                  check polygon intersections. Currently this round preserves
#'                  eight decimal digits of precision.
#'
#'                  The eighth decimal place is worth up to 1.1 mm of precision:
#'                  this is good for charting the motions of tectonic plates and
#'                  the movements of volcanoes. Permanent, corrected,
#'                  constantly-running GPS base stations might be able to
#'                  achieve this level of accuracy.
#'
#'                  In other words: you should be just fine with this level of
#'                  precision.
#'
#' @param dggs      A dggs object from dgconstruct()
#'
#' @param shpfname  File name of the shapefile. Filename should end with '.shp'
#'
#' @param frame     If TRUE, return a data frame suitable for ggplot plotting.
#'                  If FALSE, return an OGR poly object
#'
#' @param wrapcells Cells which cross -180/180 degrees can present 
#'                  difficulties for plotting. Setting this TRUE will result in
#'                  cells with components in both hemispheres to be mapped
#'                  entirely to positive degrees (the Eastern hemisphere). As a
#'                  result, such cells will have components in the range
#'                  [180,360). Only used when \code{frame=TRUE}.
#'
#' @param cellsize  Distance, in degrees, between the sample points used to
#'                  generate the grid. Small values yield long generation times
#'                  while large values may omit cells.
#'
#' @param savegrid  If savegrid is set to a file path, then a shapefile 
#'                  containing the grid is written to that path and the filename
#'                  is returned. No other manipulations are done.
#'                  Default: NA (do not save grid, return it)
#'
#' @return Returns a data frame or OGR poly object, as specified by \code{frame}.
#'         If \code{!is.na(savegrid)}, returns a filename.
#'
#' @examples 
#' \dontrun{
#' library(dggridR)
#'
#' dggs <- dgconstruct(spacing=25, metric=FALSE, resround='nearest')
#' south_africa_grid <- dgshptogrid(dggs,dg_shpfname_south_africa())
#' }
#' @export
dgshptogrid <- function(dggs,shpfname,cellsize=0.1,frame=TRUE,wrapcells=TRUE,savegrid=NA){ #TODO: Densify?
  dgverify(dggs) 

  shpfname <- trimws(shpfname)

  if(!grepl('\\.shp$',shpfname))
    stop("Shapefile name does to end with '.shp'!")
  if(!file.exists(shpfname))
    stop('Shapefile does not exist!')

  dsn   <- dirname(shpfname)
  layer <- tools::file_path_sans_ext(basename(shpfname))
  poly  <- readOGR(dsn=dsn, layer=layer)

  #Generate a dense grid of points
  samp_points <- sp::makegrid(poly, cellsize = cellsize)

  #Convert the points to SEQNUM ids for dggs
  samp_points <- dgGEO_to_SEQNUM(dggs,samp_points$x1, samp_points$x2)$seqnum

  dgcellstogrid(dggs, samp_points, frame=frame, wrapcells=wrapcells, savegrid=savegrid)
}
