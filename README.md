
<!-- README.md is generated from README.Rmd. Please edit that file -->

# earthdatalogin :artificial_satellite: :earth_asia:

<!-- badges: start -->

[![R-CMD-check](https://github.com/boettiger-lab/earthdatalogin/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/boettiger-lab/earthdatalogin/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

`earthdatalogin` seeks to streamline the process of accessing NASA data
from the Earth Data cloud program *from anywhere*. Because Amazon Web
Services (AWS) typically charges egress fees whenever network traffic
leaves the data center which hosts it, NASA has restricted access to its
data hosted by Amazon to only be accessible from AWS servers running in
the same data center (`us-west-2`) when using the S3 access protocol.
However, NASA also makes this cloud data available publicly to any
machine using a standard HTTPS connection. Both cases require requesting
and managing credentials tied to a registered user name. This package
merely makes that process easier.

## Installation

`earthdatalogin` is now on CRAN, and can simply be installed with

``` r
install.packages("earthdatalogin")
```

Or you can install the development version of `earthdatalogin` from
[GitHub](https://github.com/):

``` r
# install.packages("devtools")
devtools::install_github("boettiger-lab/earthdatalogin")
```

## Getting started

Access to EarthData is free, but users are required to
[register](https://urs.earthdata.nasa.gov/home). Currently,
`earthdatalogin` provides it’s own default credentials for a quick
start. Users are still encouraged to
**[register](https://urs.earthdata.nasa.gov/home)** their own
credentials!

``` r
library(earthdatalogin)
```

The easiest and most portable method of access is using the netrc basic
authentication protocol for HTTP. Call `edl_netrc()` to set this up
given your username and password (passed as optional arguments or read
from the environmental variables. If neither provides credentials,
`earthdatalogin` will provide it’s own credentials, but you may
experience rate limits more readily):

``` r
edl_netrc()
```

If `edl_netrc()` has been called, then most existing spatial data
packages in R can then seamlessly access NASA Earthdata over HTTP links.

``` r
url <- "https://data.lpdaac.earthdatacloud.nasa.gov/lp-prod-protected/HLSL30.020/HLS.L30.T56JKT.2023246T235950.v2.0/HLS.L30.T56JKT.2023246T235950.v2.0.SAA.tif"

terra::rast(url, vsi=TRUE)
#> class       : SpatRaster 
#> dimensions  : 3660, 3660, 1  (nrow, ncol, nlyr)
#> resolution  : 30, 30  (x, y)
#> extent      : 199980, 309780, 7190200, 7300000  (xmin, xmax, ymin, ymax)
#> coord. ref. : WGS 84 / UTM zone 56N (EPSG:32656) 
#> source      : HLS.L30.T56JKT.2023246T235950.v2.0.SAA.tif 
#> name        : HLS.L30.T56JKT.2023246T235950.v2.0.SAA
```

Note that no special `earthdatalogin` functions are needed in the rest
of our code. This is important as it lets the user take advantage of any
existing R packages or tutorials without modification, as if there was
no authentication barrier to NASA EarthData in the first place. If we
had not called `edl_netrc()` for authentication, this would throw an
error that the file does not exist. This call needs be made only once
per session (i.e. at the start of a script.)

## How does it work?

Most R packages (`terra`, `sf`, `stars`, and others) access spatial data
by using an underlying C++ library called GDAL.[^1] GDAL is also used
under the hood of many other spatial tools, from Python (`geopandas`,
`rasterio`, others) to QGIS and Google Earth Engine. `earthdatalogin`
sets a collection of config files and environmental variables used by
GDAL to allow it to access authentication credentials. Crucially, the
use of `netrc`-based authentication works just as well if you are
running from a laptop or if you are running from inside AWS compute in
`us-west-2` – such as using the popular Openscapes 2i2c hub. This
portability does not hold for other mechanisms, such as S3-based login,
which in the case of NASA EarthData only works from inside AWS-based
compute, and not true of the bearer token mechanism, which only works
from *outside* AWS-based compute. The `earthdatalogin` package does
provide functions for using these other authentication mechanisms (see
`edl_s3_token()` and `edl_set_token()`), but discourages their use as
they are less portable while offering no performance advantage.[^2]

This function takes care of managing tokens for you. If you don’t have
any tokens, it will request one be minted. If your user name has tokens
already, it will look them up and re-use them. (EDL will issue at most
two tokens per user, and tokens expire after 6 month, but users
shouldn’t need to worry about this since `edl_set_token()` handles it).
This function will also set the token in as a GDAL environmental
variable. This means that popular R packages such as `terra`, `sf` or
`stars` that all involve bindings to GDAL will automatically be able to
utilize this token for any operations reading from HTTPS (using the
`vsicurl` prefix).

Because NASA EarthData is also the first introduction to cloud-hosted
data for many researchers, the fact that NASA tries to minimize egress
charges by restricting S3 access to requests coming from AWS `us-west-2`
compute center this sometimes gives the false impression that accessing
data “from the cloud” *requires* also paying Amazon Web Services for
compute time. This is entirely spurious. For instance, [NOAA also
provides](https://registry.opendata.aws/collab/noaa/) an extensive set
of regularly updated data products on AWS without this restriction,
which can be accessed over a standard HTTPS connection or using the S3
protocol as an anonymous user (with no keys or tokens). To maximize
performance, heavy users of NOAA data will frequently choose to access
that data from AWS compute in the same region (mostly `us-east-1` for
NOAA), but this is not required. Technically speaking, we frequently use
the vernacular phrase of “accessing cloud data” to refer to network
based access of data using **HTTP range requests** – the ability to ask
a web server to transfer some range of bytes from an individual file
rather than transferring the entire file across the network.

Note that we can now successfully access this file over https from any
machine with an internet connection, and with no further authentication
steps. That URL could have been obtained in a variety of ways, including
<https://search.earthdata.nasa.gov/search>, searching individual DAACs,
or programmatically using the EarthData STAC catalog. The point here is
that despite the barrier of `earthdatalogin`, the R code required for
cloud-native access is now matches the standard strategies we would use
for cloud-native access of any other data source.

The defining feature that makes ‘cloud native’ access fast is that this
access is *lazy*. All though these individual files could be quite
large, our request has not downloaded the entire file – it has instead
used its knowledge of spatial data formats to read just those bytes of
the file that provide critical metadata such as extent, projection,
bands and coordinate ranges. Using that information, we can extract just
the bits of data (locations, variables) we care about without having to
download everything else as well. This saves the RAM on our computer,
and drive space on our disks, as well as speeding up download. Without
these techniques, processing the massive amounts of data coming from
modern earth observation methods would be impractical.

*However*, not all data formats are equally amenable to this approach.
Requesting a few bytes from a file across hundreds of miles of network
connection is not the same thing as requesting a few bytes across the
six inches of PCI connection between your processor and your hard-drive.
More recent formats like “Cloud Optimized Geotiff” (COG) files are, as
the name suggests, optimized for this. Complex older formats like HDF5
or GRIB are much less efficient. Network based range requests are not
possible on some older (but still widely used) formats, like HDF4. In
this last case, we will need to download the file to a local disk (a
POSIX filesystem, not a hyperscale Object Store) to read it. Use
`edl_download()` to handle authenticated downloads in this case.

## Vignettes

To facilitate cloud-native access of NASA EarthData from R, this package
also includes a series of vignettes illustrating the use of some popular
R packages in there (often less well-known) cloud-native modes. In each
of these vignettes, we will take care to leverage “lazy evaluation” to
avoid downloading more than we have to. With the exception of the
vignette on S3 access from within `us-west-2`, these vignettes should
run most anywhere, but will be most effective on machines with fast
network access. Many university networks, and any cloud-hosted platform,
such as GitHub Codespaces, offer excellent network performance for this
purpose.

[^1]: Some R users have heard that the `rgdal` package is being
    deprecated. Don’t confuse this with the GDAL C++ library being
    deprecated – `rgdal` was only one of many R packages that used the
    GDAL C++ libraries, and was deprecated in favor of the same bindings
    to GDAL being available in `sf`.

[^2]: NASA’s own documentation often points users to the S3-based access
    protocol when working on AWS compute. Note that the S3 tokens NASA’s
    AWS setup provides expire every hour, and are specific to each DAAC,
    making it very difficult for users to work across data products from
    multiple DAACs in a single workflow. Note also that this
    authentication mechanism provides essentially no advantage in terms
    of speed or cost to the user or to NASA, especially for large data.
