
get_311_heat_complaints <- function(heat_season_start_year = 2017, data_dir = ".") {
  
  start_yr <- as.integer(heat_season_start_year)
  end_yr <- heat_season_start_year + 1
  
  # Confirm the data is available for the requested season
  today <- Sys.Date()
  end_season <- as.Date(stringr::str_glue("{end_yr}-05-31"))
  stopifnot(today > end_season)
  
  output_file <- here::here("data", stringr::str_glue("311-complaints_heat_{start_yr}-{end_yr}.feather"))
  
  url_query_311 <- utils::URLencode(stringr::str_glue(
    "https://data.cityofnewyork.us/resource/fhrw-4uyv.csv?$query=
    SELECT * 
    WHERE created_date between '{start_yr}-10-01T00:00:00' and '{end_yr}-05-31T23:59:59' 
    AND complaint_type IN ('HEAT/HOT WATER', 'HEATING')
    LIMIT 500000"
  ))
  
  cols_311 <- readr::cols_only(
    address_type = col_character(),
    bbl = col_character(),
    borough = col_character(),
    closed_date = col_datetime(format = ""),
    community_board = col_character(),
    complaint_type = col_character(),
    created_date = col_datetime(format = ""),
    descriptor = col_character(),
    facility_type = col_character(),
    incident_address = col_character(),
    incident_zip = col_character(),
    latitude = col_double(),
    longitude = col_double(),
    resolution_action_updated_date = col_datetime(format = ""),
    resolution_description = col_character(),
    status = col_character(),
    unique_key = col_character()
  )
  
  readr::read_csv(url_query_311, col_types = cols_311, na = c("", "NA", "N/A"))
}