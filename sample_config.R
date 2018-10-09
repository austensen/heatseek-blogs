# Fill in "xxxxxx" with your information and rename this file "config.R"

# https://github.com/aepyornis/nyc-db
connect_nyc_db <- function() {
  DBI::dbConnect(
    RPostgres::Postgres(),
    dbname = "nycdb",
    host = "localhost", 
    port = 5432,
    user = "xxxxxx",
    password = "xxxxxxx"
  )
}

# https://www.mapbox.com/signup
get_mapbox_key <- function() {
  "xxxxxxx"
}

# https://darksky.net/dev/register
get_darksky_key <- function() {
  "xxxxxxx"
}
