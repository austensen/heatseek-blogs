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

# City Council Districts
ccd_shapes <- "https://data.cityofnewyork.us/api/geospatial/yusd-j4xi?method=export&format=GeoJSON" %>% 
  read_sf() %>% 
  select(ccd = coun_dist)

# Tracts
tract2010_shapes <- "https://data.cityofnewyork.us/api/geospatial/fxpq-c8ku?method=export&format=GeoJSON" %>% 
  read_sf() %>% 
  transmute(tract2010 = str_c("36", boro_to_fips(boro_code), ct2010))

# Zip Codes
zip_url <- "https://data.cityofnewyork.us/api/views/i8iw-xf4u/files/YObIR0MbpUVA0EpQzZSq5x55FzKGM2ejSeahdvjqR20?filename=ZIP_CODE_040114.zip"
zip_dir <- tempdir()
download.file(zip_url, path(zip_dir, "zipcodes.zip"))
unzip(path(zip_dir, "zipcodes.zip"), exdir = zip_dir)

zipcode_shapes <- path(zip_dir, "ZIP_CODE_040114.shp") %>% 
  read_sf(crs = 2263) %>% 
  select(zipcode = ZIPCODE) %>% 
  st_transform(4326)


# Get Residential Units, Heat Complaints & Heat Violations by BBL ---------

# Get BBLs registered with HPD, because when creating violation rates we don't
# want to include non-rental units in the denoinator. So we'll add a flag to the
# data that indicates whether the BBL is registered with HPD so we can create
# serparte counts of units and violations just for these buildings
hpd_registered_bbls <- tbl(con, "hpd_registrations") %>% 
  distinct(bbl) %>% 
  mutate(is_hpd_reg = TRUE)

# Use nyc-db to get bbls, other geographies, and residential units from Pluto
pluto_bbls <- tbl(con, "pluto_18v1") %>% 
  filter(unitsres > 0) %>% 
  # Keep only BBLs registered with HPD
  left_join(hpd_registered_bbls, by = "bbl") %>% 
  transmute(
    bbl,
    is_hpd_reg,
    boro = borocode,
    cd = as.character(cd), 
    ccd = as.character(council),
    zipcode,
    tract2010,
    unitsres,
    lng, 
    lat
  ) %>% 
  collect() %>% 
  replace_na(list(is_hpd_reg = FALSE)) %>% 
  mutate(tract2010 = str_c("36", boro_to_fips(boro), str_pad(tract2010, 6, "right", "0")))

# Use nyc-db to get count of heat violations by bbl
violation_bbls <- tbl(con, "hpd_violations") %>% 
  filter(
    sql("bbl ~ '^[1-5](?!0{5})\\d{5}(?!0{4})\\d{4}$'"), # valid BBLs
    sql("novdescription ~ '27-20(2[8-9]|3[0-3])'"), # heat violations
    sql("novissueddate between '2017-10-01' and '2018-05-31'") # 2017-2018 heat season
  ) %>% 
  group_by(bbl) %>% 
  summarise(viol = n()) %>% 
  collect() %>% 
  mutate(viol = as.integer(viol))


# Get count of heat complaints by bbl from 311 data for 2017-2018 heat season
complaint_bbls <- get_311_heat_complaints(2017, here("data")) %>% 
  filter(str_detect(bbl, "^[1-5](?!0{5})\\d{5}(?!0{4})\\d{4}$")) %>% 
  group_by(bbl) %>% 
  summarise(comp = n())

# Join units, complaints, and violations by bbl
all_bbls <- pluto_bbls %>% 
  left_join(violation_bbls, by = "bbl") %>% 
  left_join(complaint_bbls, by = "bbl") %>% 
  replace_na(list(viol = 0, comp = 0)) %>% 
  mutate_at(vars(viol, comp), funs("rt" = . / unitsres)) %>% 
  # Create these HPD-registered-only columns now for easier aggregation below
  mutate_at(vars(viol, comp, unitsres), funs("bbls" = . > 0)) %>% 
  mutate_at(vars(matches("(comp)|(viol)|(unitsres)")), funs("reg" = . * is_hpd_reg))


# Export GeoJSON Data for Maps --------------------------------------------

# All BBLs with any complaints or violations
all_bbls %>% 
  filter_at(vars(lng, lat), any_vars(!is.na(.))) %>% 
  filter_at(vars(viol, comp), any_vars(. > 0)) %>% 
  st_as_sf(coords = c("lng", "lat"), crs = 4326) %>% 
  select(bbl, is_hpd_reg, unitsres, comp, comp_rt, viol, viol_rt) %>% 
  write_sf(here("data", "bbl-complaints-violations_2017-2018.geojson"), delete_dsn = TRUE)

# Aggregate by given geography and export a geojson file with counts of
# residential units, complaints, violations, and rates for all residential BBLs
# and just those registered with HPD
summarise_and_export_geojson <- function(geo, shapes) {
  all_bbls %>% 
    select(-contains("_rt")) %>% 
    group_by(!!sym(geo)) %>% 
    summarise_at(vars(matches("^(comp)|(viol)|(unitsres)")), sum) %>% 
    mutate_at(vars(viol, comp), funs("rt" = . / unitsres)) %>% 
    mutate_at(vars(viol_reg, comp_reg), funs("rt" = . / unitsres_reg)) %>% 
    mutate_at(vars(viol_bbls, comp_bbls), funs("rt" = . / unitsres_bbls)) %>% 
    mutate_at(vars(viol_bbls_reg, comp_bbls_reg), funs("rt" = . / unitsres_bbls_reg)) %>% 
    select(!!sym(geo), starts_with("unitsres"), starts_with("comp"), starts_with("viol")) %>% 
    right_join(shapes, by = geo) %>%
    st_as_sf() %>%
    write_sf(here("data", str_glue("{geo}-complaints-violations_2017-2018.geojson")), delete_dsn = TRUE)
}

geos <- c("boro", "cd", "ccd", "tract2010", "zipcode")
shapes <- list(boro_shapes, cd_shapes, ccd_shapes, tract2010_shapes, zipcode_shapes)

walk2(geos, shapes, summarise_and_export_geojson)

