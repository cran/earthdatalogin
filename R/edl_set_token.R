#' Get or set an earthdata login token
#'
#' This function will ping the EarthData API for any available tokens.
#' If a token is not found, it will request one.  You may only have
#' two active tokens at any given time.  Use edl_revoke_token to remove
#' unwanted tokens.  By default, the function will also set an environmental
#' variable for the active R session to store the token.  This allows
#' popular R packages which use gdal to immediately authenticate any http
#' addresses to NASA EarthData assets.
#'
#' IMPORTANT: it is necessary to unset this token using [edl_unset_token()]
#' before trying to access HTTP resources that are not part of EarthData,
#' as setting this token will cause those calls to fail! OR simply use
#' [edl_netrc()] to authenticate without facing this issue.
#'
#' NOTE: Because GDAL >= 3.6.1 is required to recognize the GDAL_HTTP_HEADERS,
#' but all versions recognize GDAL_HTTP_HEADER_FILE. So we set the Bearer token
#' in a temporary file and provide this path as GDAL_HTTP_HEADER_FILE to
#' improve compatibility with older versions.
#'
#' @param username EarthData Login User
#' @param password EarthData Login Password
#' @param token_number Which token (1 or 2)
#' @param set_env_var Should we set the GDAL_HTTP_HEADER_FILE
#' environmental variable?  logical, default TRUE.
#' @param format One of "token", "header" or "file."  "header" adds the prefix
#' used by http headers to the return string.  "file" returns
#' @param prompt_for_netrc Often netrc is preferable, so this function will by
#' default prompt the user to switch.  Set to FALSE to silence this.
#' @return A text string containing only the token (format=token),
#' or a token with the header prefix included, `Authorization: Bearer <token>`
#' @export
#' @examplesIf interactive()
#' edl_set_token()
#' edl_unset_token()
edl_set_token <- function (username = default("user"),
                           password = default("password"),
                           token_number = 1,
                           set_env_var = TRUE,
                           format = c("token", "header", "file"),
                           prompt_for_netrc = interactive()
){

  if(prompt_for_netrc){
    done <- we_prefer_netrc(username, password)
    if (done) return(invisible(TRUE))
  }

  p <- edl_api("/api/users/tokens", username, password)

  if(length(p) < token_number) {
    p <- edl_api("/api/users/token", username, password, method = httr::POST)
  } else {
    p <- p[[token_number]]
  }
  token <- p$access_token

  if (set_env_var) {
    edl_setenv(token)
  }
  format <- match.arg(format)
  out <- switch(format,
                token = token,
                header = edl_header(token),
                file = edl_headerfile(token)
  )
  invisible(out)
}



edl_headerfile <- function(token) {
  header <- edl_header(token)
  headerfile <- tempfile(pattern="GDAL_HTTP_HEADERS", fileext = "")
  writeLines(header, headerfile)
  invisible(headerfile)

}

edl_setenv <- function(token) {
  headerfile <- edl_headerfile(token)
  Sys.setenv("GDAL_HTTP_HEADER_FILE"=headerfile)
}



edl_header <- function(token) {
  paste("Authorization: Bearer", token)
}


edl_api <- function(endpoint,
                    username = default("user"),
                    password = default("password"),
                    ...,
                    base = "https://urs.earthdata.nasa.gov",
                    method = httr::GET) {

  pw <- openssl::base64_encode(paste0(username, ":", password))
  resp <- method(paste0(base, endpoint),
  #                  ...,
                    httr::add_headers(Authorization = paste("Basic", pw)))
  httr::stop_for_status(resp)
  p <- httr::content(resp, "parsed", "application/json")
  p
}



#' URL for an example of an LP DAAC COG file
#'
#' @return The URL to a Cloud-Optimized Geotiff file from the LP DAAC.
#'
#' @examples
#' lpdacc_example_url()
#'
#' @export
lpdacc_example_url <- function() {
  paste0("https://data.lpdaac.earthdatacloud.nasa.gov/lp-prod-protected/",
         "HLSL30.020/HLS.L30.T56JKT.2023246T235950.v2.0/",
         "HLS.L30.T56JKT.2023246T235950.v2.0.SAA.tif")
}




#' unset token
#'
#' External sources that don't need the token may error if token is set.
#' Call `edl_unset_token` before accessing non-EarthData URLs.
#' @return unsets environmental variables token (no return object)
#' @export
#'
#' @examples
#' edl_unset_token()
edl_unset_token <- function() {
  Sys.unsetenv("GDAL_HTTP_HEADER_FILE")
}

#' Revoke an EarthData token
#'
#' Users can only have at most 2 active tokens at any time.
#' You don't need to keep track of a token since earthdatalogin can
#' retrieve your tokens with your user name and password.  However,
#' should you want to revoke a token, you can do so with this function.
#'
#' @inheritParams edl_set_token
#' @return API response (invisibly)
#' @examplesIf interactive()
#' edl_revoke_token()
#'
#' @export
edl_revoke_token <- function(
    username = default("user"),
    password = default("password"),
    token_number = 1
){

  if(username == "" || password == "") {
    message("You must provide a username and password either in .Renviron\n",
            "or using the optional arguments")
  }

  p <- edl_api("/api/users/tokens", username, password)
  if(length(p) == 0) {
    message("No tokens to revoke")
    return(invisible(NULL))
  } else {
    token <- p[[token_number]]$access_token
    p2 <- edl_api(paste0("/api/users/revoke_token?token=", token),
                  username, password, method=httr::POST)

  }
  invisible(p2)
}






#' Helper function for extracting URLs from STAC
#'
#' @param items an items list from rstac
#' @param assets name(s) of assets to extract
#' @return a vector of hrefs for all discovered assets.
#'
#' @export
#'
edl_stac_urls <- function(items, assets = "data") {
  purrr::map(items$features, list("assets")) |>
    purrr::map(list(assets)) |>
    purrr::map_chr("href")
}
