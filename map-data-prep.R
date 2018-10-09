# Create geojson files with counts of residential units, heat complaints, and
# heat violations by various geographies for mapping


# Setup -------------------------------------------------------------------

library(tidyverse) # tibble, dplyr, tidyr, readr, purrr, stringr, ggplot2
library(here) # consistent relative file paths
library(fs) # consistent file system operations
library(sf) # spatial dataframe
library(DBI) # Database connection

# Download and/or import 311 heat complaints for a given heat season
source(here("R", "get_311_heat_complaints.R"))

# Load secret info from config file
source(here("config.R"))

# Set up connection you nyc-db database
con <- connect_nyc_db()

boro_to_fips <- function(x) {
  recode(x, "1" = "061", "2" = "005", "3" = "047", "4" = "081", "5" = "085")
}


# Get Geographies from NYC Open Data --------------------------------------

# Boroughs
boro_shapes <- "https://data.cityofnewyork.us/api/geospatial/tqmj-j8zm?method=export&format=GeoJSON" %>% 
  read_sf() %>% 
  select(boro = boro_code)

# CDs
cd_shapes <- "https://data.cityofnewyork.us/api/geospatial/yfnk-k7r4?method=export&format=GeoJSON" %>% 
  read_sf() %>% 
  select(cd = boro_cd)

# Tracts
tract_shapes <- "https://data.cityofnewyork.us/api/geospatial/fxpq-c8ku?method=export&format=GeoJSON" %>% 
  read_sf() %>% 
  transmute(tract2010 = str_c("36", boro_to_fips(boro_code), ct2010))

# Zip Codes
zip_url <- "https://data.cityofnewyork.us/api/views/i8iw-xf4u/files/YObIR0MbpUVA0EpQzZSq5x55FzKGM2ejSeahdvjqR20?filename=ZIP_CODE_040114.zip"
zip_dir <- tempdir()
download.file(zip_url, path(zip_dir, "zipcodes.zip"))
unzip(path(zip_dir, "zipcodes.zip"), exdir = zip_dir)

zip_shapes <- path(zip_dir, "ZIP_CODE_040114.shp") %>% 
  read_sf(crs = 2263) %>% 
  select(zipcode = ZIPCODE) %>% 
  st_transform(4326)


# Get Residential Units, Heat Complaints & Heat Violations by BBL ---------

# Use nyc-db to get bbls, other geographies, and residential units from Pluto
pluto_bbls <- tbl(con, "pluto_18v1") %>% 
  filter(unitsres > 0) %>% 
  transmute(
    bbl,
    boro = borocode,
    cd = as.character(cd), 
    zipcode,
    tract2010,
    unitsres,
    lng, 
    lat
  ) %>% 
  collect() %>% 
  mutate(tract2010 = str_c("36", boro_to_fips(boro), str_pad(tract2010, 6, "right", "0")))

# Use nyc-db to get count of heat violations by bbl
violation_bbls <- tbl(con, "hpd_violations") %>% 
  filter(
    sql("bbl ~ '[1-5]\\d{9}'"),
    sql("novdescription ~ '27-20(2[8-9]|3[0-3])'"), # heat violations
  ) %>% 
  group_by(bbl) %>% 
  summarise(viol = n()) %>% 
  collect() %>% 
  mutate(viol = as.integer(viol))


# Get count of heat complaints by bbl from 311 data
complaint_bbls <- get_311_heat_complaints(2017, here("data")) %>% 
  filter(str_detect(bbl, "[1-5]\\d{9}")) %>% 
  group_by(bbl) %>% 
  summarise(comp = n())

# Join units, complaints, and violations by bbl
all_bbls <- pluto_bbls %>% 
  left_join(violation_bbls, by = "bbl") %>% 
  left_join(complaint_bbls, by = "bbl") %>% 
  replace_na(list(viol = 0, comp = 0)) %>% 
  mutate_at(vars(viol, comp), funs("rt" = . / unitsres))


# Export GeoJSON Data for Maps --------------------------------------------

# Aggregate data (if necessary), join with (or create) geometries, and export

# BBL
all_bbls %>% 
  filter_at(vars(lng, lat), any_vars(!is.na(.))) %>% 
  filter_at(vars(viol, comp), any_vars(. > 0)) %>% 
  st_as_sf(coords = c("lng", "lat"), crs = 4326) %>% 
  select(bbl, unitsres, comp, comp_rt, viol, viol_rt) %>% 
  write_sf(here("data", "bbl-complaints-violations_2017-2018.geojson"), delete_dsn = TRUE)

# Boroughs
all_bbls %>% 
  group_by(boro) %>% 
  summarise_at(vars(viol, comp, unitsres), sum) %>% 
  mutate_at(vars(viol, comp), funs("rt" = . / unitsres)) %>% 
  right_join(boro_shapes, by = "boro") %>% 
  st_as_sf() %>% 
  write_sf(here("data", "boro-complaints-violations_2017-2018.geojson"), delete_dsn = TRUE)

# CDs
all_bbls %>% 
  group_by(cd) %>% 
  summarise_at(vars(viol, comp, unitsres), sum) %>% 
  mutate_at(vars(viol, comp), funs("rt" = . / unitsres)) %>% 
  right_join(cd_shapes, by = "cd") %>% 
  replace_na(list(viol = 0, comp = 0, viol_rt = 0, comp_rt = 0, unitsres = 0)) %>% 
  st_as_sf() %>% 
  write_sf(here("data", "cd-complaints-violations_2017-2018.geojson"), delete_dsn = TRUE)

# Tracts
all_bbls %>% 
  group_by(tract2010) %>% 
  summarise_at(vars(viol, comp, unitsres), sum) %>% 
  mutate_at(vars(viol, comp), funs("rt" = . / unitsres)) %>% 
  right_join(tract_shapes, by = "tract2010") %>% 
  replace_na(list(viol = 0, comp = 0, viol_rt = 0, comp_rt = 0, unitsres = 0)) %>% 
  st_as_sf() %>% 
  write_sf(here("data", "tract-complaints-violations_2017-2018.geojson"), delete_dsn = TRUE)

# Zip Codes
all_bbls %>% 
  group_by(zipcode) %>% 
  summarise_at(vars(viol, comp, unitsres), sum) %>% 
  mutate_at(vars(viol, comp), funs("rt" = . / unitsres)) %>% 
  right_join(zip_shapes, by = "zipcode") %>% 
  replace_na(list(viol = 0, comp = 0, viol_rt = 0, comp_rt = 0, unitsres = 0)) %>% 
  st_as_sf() %>% 
  write_sf(here("data", "zip-complaints-violations_2017-2018.geojson"), delete_dsn = TRUE)
