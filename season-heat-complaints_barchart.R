# Create bar graph of total heat complaints by heat-season 2010-2018


# Setup -------------------------------------------------------------------

library(tidyverse) # tibble, dplyr, tidyr, readr, purrr, stringr, ggplot2
library(here) # consistent relative file paths

# Loads theme_heatseek() and vector heatseek_colors for graphs
source(here("R", "theme_heatseek.R"))


# Get Heat Complaints Data ------------------------------------------------

# Use Socrata SQL-like API to count heat complaints by year/month
url_query_311 <- URLencode(str_glue(
  "https://data.cityofnewyork.us/resource/fhrw-4uyv.csv?$query=
   SELECT date_extract_y(created_date) AS year, date_extract_m(created_date) AS month, COUNT(*) AS heat_complaints 
   WHERE date_extract_m(created_date) IN (10, 11, 12, 1, 2, 3, 4, 5)
    AND complaint_type IN ('HEAT/HOT WATER', 'HEATING')
   GROUP BY date_extract_y(created_date), date_extract_m(created_date)"
))

# Download, clean, and aggregate complaints
season_complaints <- url_query_311 %>% 
  read_csv(col_types = "iii") %>% 
  mutate(
    # Assign months to "heat seasons"
    season = case_when(
      month %in% 10:12 ~ str_c(year, "-", year + 1),
      month %in% 1:5 ~ str_c(year - 1, "-", year),
    )
  ) %>% 
  filter(!season %in% c("2009-2010", "2018-2019")) %>% # remove incomplete seasons
  group_by(season) %>% 
  summarise(heat_complaints = sum(heat_complaints))



# Create Bar Graph --------------------------------------------------------

# Create column graph of total heat complaints by season
season_complaints %>% 
  # Add label for most recent season only
  mutate(complaint_label = if_else(season == "2017-2018", scales::comma(heat_complaints), NA_character_)) %>% 
  ggplot() +
  aes(x = season, y = heat_complaints,label = complaint_label) +
  geom_col(width = 0.7, fill = heatseek_colors["orange"]) +
  geom_text(nudge_y = 8000, na.rm = TRUE, size = 3, fontface = "bold", color = heatseek_colors["orange"]) +
  scale_y_continuous(breaks = seq(0, 200000, 50000), labels = scales::comma) +
  theme_heatseek() +
  theme(panel.grid.major.x = ggplot2::element_blank()) +
  labs(
    title = "Heat Complaints Year-Over-Year",
    subtitle = "October 1 - May 31",
    x = NULL,
    y = NULL,
    caption = "Source: NYC 311 Complaints"
  )

ggsave(here("img", "season-heat-complaints_barchart.png"), width = 8, height = 4, units = "in")
  