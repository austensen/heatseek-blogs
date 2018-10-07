# Create a line graph comparing daily temperatures and heat complaints

library(dplyr) # dataframe manipulation
library(stringr) # string manipulation
library(ggplot2) # plotting
library(feather) # R/Python compatible dataframes
library(readr) # read/write rectangular text data
library(here) # consistent relative file paths
library(fs) # consistent file system operations
library(purrr) # functional programming tools
library(darksky) # DarkSky API for weather data

# Loads theme_heatseek() and vector heatseek_colors
source(here("R", "theme_heatseek.R"))
source(here("R", "get_311_heat_complaints.R"))

# This directory is gitignored
dir_create(here("data"))

# Set start year of Heat Season
start_yr <- 2017
end_yr <- start_yr + 1

start_season <- as.Date(str_glue("{start_yr}-10-01"))
end_season <- as.Date(str_glue("{end_yr}-05-31"))


# Get daily heat complaints for given heat season

compalints_file <- here("data", str_glue("311-complaints_heat_{start_yr}-{end_yr}.feather"))

if (file_exists(compalints_file)) {
  complaints_raw <- read_feather(complaints_file)
} else {
  complaints_raw <- get_311_heat_complaints(2017, here("data"))
}

complaints_daily <- complaints_raw %>% 
  mutate(date = as.Date(created_date)) %>% 
  group_by(date) %>% 
  summarise(heat_complaints = n()) %>% 
  mutate(complaints_highest = if_else(heat_complaints == max(heat_complaints), heat_complaints, NA_integer_))
  


# Get daily temperature lows fro a given heat season

temperatures_file <- here("data", str_glue("daily-temperatures_{start_yr}-{end_yr}.feather"))
                          
if (file_exists(temperatures_file)) {
  temps_raw <- read_feather(temperatures_file)
} else {
  temps_raw <- seq(start_season, end_season, by = "1 day") %>%  
    map(~get_forecast_for(40.673646, -73.969787, .x)) %>% 
    map_dfr("daily")
  
  write_feather(temps_daily, temperatures_file)
}

temps_daily <- temps_raw %>% 
  transmute(
    temp = temperatureLow, 
    date = as.Date(time),
    temp_lowest = if_else(temp == min(temp), temp, NA_real_)
  )

# Create dual-axis line graph of temperature and complaints

# ggplot2 only allows a secondary axis that is a 1:1 transformation of the
# primary axis. So the following uses some hacks borrowed from
# https://rpubs.com/MarkusLoew/226759

x_date_breaks <- c(seq(start_season, end_season, by = "1 month"), end_season)

ggplot() +
  # Complaints
  geom_line(data = complaints_daily, 
            aes(x = date, y = heat_complaints/100), 
            color = heatseek_colors["orange"]) +
  geom_point(data = complaints_daily, 
             aes(x = date, y = complaints_highest/100), 
             na.rm = TRUE,
             color = heatseek_colors["orange"], 
             shape = 1) +
  geom_text(data = complaints_daily, 
            aes(x = date, y = complaints_highest/100, label = scales::comma(complaints_highest)),
            na.rm = TRUE,
            color = heatseek_colors["orange"],
            size = 2,
            fontface = "bold",
            nudge_y = 2.5) + 
  # Temperature
  geom_line(data = temps_daily, 
            aes(x = date, y = temp), 
            color = heatseek_colors["blue"]) +
  geom_point(data = temps_daily, 
             aes(x = date, y = temp_lowest), 
             na.rm = TRUE,
             color = heatseek_colors["blue"], 
             shape = 1) +
  geom_text(data = temps_daily, 
            aes(x = date, y = temp_lowest, label = round(temp_lowest, 1)),
            na.rm = TRUE,
            color = heatseek_colors["blue"],
            size = 2,
            fontface = "bold",
            nudge_y = -2.5) + 
  # Scales, themes, and titles
  scale_x_date(breaks = x_date_breaks, date_labels = "%b %d") +
  scale_y_continuous(labels = scales::comma, 
                     sec.axis = sec_axis(~.*100, labels = scales::comma, name = "Heat Complaints")) + 
  theme_heatseek() +
  theme(axis.title.y.left = element_text(colour = heatseek_colors["blue"]),
        axis.title.y.right = element_text(colour = heatseek_colors["orange"])) +
  labs(
    title = "Daily Heat Complaints and Temperature",
    subtitle = str_glue("October 1, {start_yr} - May 31, {end_yr}"),
    x = NULL,
    y = "Temperature (°F)",
    caption = "Sources: DarkSky, NYC 311 Complaints"
  )

image_file <- here("img", str_glue("temperate-complaints_{start_yr}-{end_yr}_linechart.png"))
ggsave(image_file, width = 8, height = 4, units = "in")


