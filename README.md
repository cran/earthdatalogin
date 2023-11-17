
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

## Installation

You can install the development version of earthdatalogin from
[GitHub](https://github.com/) with:

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

A good way to keep track of your user name and password is to set these
as environmental variables using a `.Renviron` file (see `edl_renviron`)
to record these as `EARTHDATA_USER` and `EARTHDATA_PASSWORD`
respectively. (As with any kind of access credentials, use a unique
password and keep `.Renviron` file secure.)

``` r
library(earthdatalogin)
```

The easiest and most universal method of access is using the HTTP with a
bearer token. Call `edl_set_token()` to set this token given your
username and password (passed as optional arguments or read from the
environmental variables. If neither provides credentials,
`earthdatalogin` will provide it’s own credentials, but you may
experience rate limits more readily):

``` r
edl_set_token()
```

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

``` r
library(terra)
#> terra 1.7.39
rast("https://data.lpdaac.earthdatacloud.nasa.gov/lp-prod-protected/HLSL30.020/HLS.L30.T56JKT.2023246T235950.v2.0/HLS.L30.T56JKT.2023246T235950.v2.0.SAA.tif",
     vsi=TRUE)
#> class       : SpatRaster 
#> dimensions  : 3660, 3660, 1  (nrow, ncol, nlyr)
#> resolution  : 30, 30  (x, y)
#> extent      : 199980, 309780, 7190200, 7300000  (xmin, xmax, ymin, ymax)
#> coord. ref. : WGS 84 / UTM zone 56N (EPSG:32656) 
#> source      : HLS.L30.T56JKT.2023246T235950.v2.0.SAA.tif 
#> name        : HLS.L30.T56JKT.2023246T235950.v2.0.SAA
```

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

## Managing your User Account

Once you have [registered for an
account](https://urs.earthdata.nasa.gov/home) on the NASA EarthData
webpage, you can have R track your username and password in your user
`.Renviron` file by using the helper function:

``` r
edl_renviron()
#> cache set!
```

This is a convenient way to store your user name and password on your
own computer so you don’t have to use the default user or enter your
password for each session. Note that this stores your user name and
password in plain text in a hidden `~/.Renviron` file on your computer –
this may be fine if you are working on your own private computer. Never
reuse passwords associated with other accounts.

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
