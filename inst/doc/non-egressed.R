## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  fig.path="img/",
  message = FALSE,
  warning = FALSE,
  eval = FALSE
)

## ----setup, message=FALSE-----------------------------------------------------
# library(earthdatalogin)
# library(rstac)
# library(gdalcubes)
# gdalcubes_options(parallel = TRUE)
# gdal_cloud_config()

## -----------------------------------------------------------------------------
# edl_s3_token(daac = "https://data.lpdaac.earthdatacloud.nasa.gov")

## -----------------------------------------------------------------------------
# bbox <- c(xmin=-122.5, ymin=37.5, xmax=-122.0, ymax=38)
# start <- "2022-01-01"
# end <- "2022-06-30"
# 
# # Find all assets from the desired catalog:
# items <- stac("https://cmr.earthdata.nasa.gov:443/search/stac/LPCLOUD") |>
#   stac_search(collections = "HLSL30.v2.0",
#               bbox = bbox,
#               datetime = paste(start,end, sep = "/")) |>
#   post_request() |>
#   items_fetch() |>
#   items_filter(filter_fn = \(x) {x[["eo:cloud_cover"]] < 20})
# 

## -----------------------------------------------------------------------------
# col <-
#   stac_image_collection(items$features,
#                         asset_names = c("B02", "B03", "B04", "Fmask"),
#                         url_fun = \(url) edl_as_s3(url, prefix = "/vsis3/"))

## ----sf_bay-------------------------------------------------------------------
# # Desired data cube shape & resolution
# v = cube_view(srs = "EPSG:4326",
#               extent = list(t0 = as.character(start),
#                             t1 = as.character(end),
#                             left = bbox[1], right = bbox[3],
#                             top = bbox[4], bottom = bbox[2]),
#                 nx = 2048, ny = 2048, dt = "P1M")
# 
# cloud_mask <- image_mask("Fmask", values=1) # mask clouds and cloud shadows
# rgb_bands <- c("B04","B03", "B02")
# 
# # Here we go! note eval is lazy
# raster_cube(col, v, mask=cloud_mask) |>
#   select_bands(rgb_bands) |>
#   plot(rgb=1:3)

