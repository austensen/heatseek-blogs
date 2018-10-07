# Create map of buildings with heat complaints

library(dplyr) # dataframe manipulation
library(feather) # R/Python compatible dataframes
library(here) # consistent relative file paths
library(fs) # consistent file system operations
library(mapdeck) # maps with mapbox/deck
library(htmlwidgets) # export map to HTML file
library(magick) # manipulate images
library(getPass) # supply passwords securely via popup

# Loads theme_heatseek() and vector heatseek_colors
source(here("R", "theme_heatseek.R"))

complaints_raw <- read_feather(here("data", "311-complaints_heat_2017-2018.feather"))

# Create an account at MapBox.com and provide your API key below
mapbox_key <- getPass::getPass("MapBox API Key")

# Get building-level count of heat complaints
complaints_bldgs <- complaints_raw %>% 
  filter(
    !is.na(latitude) & !is.na(longitude)
  ) %>% 
  group_by(incident_address, latitude, longitude) %>% 
  summarise(complaints = n())

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


# STOP - Open HTML map in browser and export screenshot


# After creating the screenshot, add title
image_read(here("img", "heat-complaints-buildings_map_nolabels.png")) %>% 
  image_annotate("Residential Buildings with Heat Complaints", size = 48, gravity = "northwest", location = "+20+10") %>% 
  image_annotate("October 1, 2017 - May 31, 2018", size = 30, gravity = "northwest", location = "+20+80") %>% 
  image_write(here("img", "heat-complaints-buildings_map.png"))
