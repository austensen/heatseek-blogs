# Create map of buildings with heat complaints


# Setup -------------------------------------------------------------------

library(dplyr) # dataframe manipulation
library(here) # consistent relative file paths
library(fs) # consistent file system operations
library(mapdeck) # maps with mapbox/deck
library(htmlwidgets) # export map to HTML file
library(magick) # manipulate images

# Loads theme_heatseek() and vector heatseek_colors
source(here("R", "theme_heatseek.R"))

# Download and/or import 311 heat complaints for a given heat season
source(here("R", "get_311_heat_complaints.R"))

# Load secret info from config file
source(here("config.R"))

# Create an account at MapBox.com and provide your API key below
mapbox_key <- get_mapbox_key()


# Get Heat Complaint Locations --------------------------------------------

# Get building-level count of heat complaints
complaints_bldgs <- get_311_heat_complaints(2017, here("data")) %>% 
  filter(
    !is.na(latitude) & !is.na(longitude)
  ) %>% 
  group_by(incident_address, latitude, longitude) %>% 
  summarise(complaints = n())


# Create Map of Heat Complaints -------------------------------------------

# Create map of residential buildings with heat complaints
complaints_map <- mapdeck(
  token = mapbox_key, 
  style = "mapbox://styles/austensen/cjmycivcs3axf2ro84n4pcqr2", # Light, but with no labels
  location = c(-73.974119, 40.719099),
  zoom = 9.5
  ) %>%
  add_scatterplot(
    data = complaints_bldgs,
    lat = "latitude",
    lon = "longitude",
    fill_colour = heatseek_colors[["orange"]],
    fill_opacity = 60,
    layer_id = "complaints_buildings"
  )

# This directory is gitignored
dir_create(here("img", "mapdeck"))

# Export HTML page for map
htmlwidgets::saveWidget(complaints_map, here("img", "mapdeck", "complaints-map.html"))


# STOP - Open HTML map in browser and export screenshot: "heat-complaints-buildings_map_nolabels.png"


# After creating the screenshot, add title
image_read(here("img", "heat-complaints-buildings_map_nolabels.png")) %>% 
  image_annotate("Residential Buildings with Heat Complaints", size = 48, gravity = "northwest", location = "+20+10") %>% 
  image_annotate("October 1, 2017 - May 31, 2018", size = 30, gravity = "northwest", location = "+20+80") %>% 
  image_write(here("img", "heat-complaints-buildings_map.png"))
