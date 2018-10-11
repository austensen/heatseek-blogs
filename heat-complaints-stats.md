Heat Complaints - 2017-2018
================
Maxwell Austensen
2018-10-11

``` r
library(tidyverse) # tibble, dplyr, tidyr, readr, purrr, stringr, ggplot2
library(here) # consistent relative file paths
library(DBI) # database connection
library(magick) # image manipulation
```

Download and/or import 311 heat complaints for the 2017-2018 heat
season.

``` r
source(here("R", "get_311_heat_complaints.R"))

complaints_raw <- get_311_heat_complaints(heat_season_start_year = 2017, data_dir = here("data"))
```

I created this lookup table to categorize complaints by
resolution\_description field. You can see all the details in
[`data/resolution_description_lookup.csv`](data/resolution_description_lookup.csv).

``` r
res_desc_lookup <- read_csv(here("data", "resolution_description_lookup.csv"), col_types = "cc")
```

Many complaints are marked only as duplicates, and so here I assign
these complaints the description of the most recent non-duplicate
complaint in that BBL. There are a small number of complaints for which
the description says “Violations were previously issued for these
conditions”, these are included in the “complaints resulting in
violations” category for the stats below.

``` r
complaints_clean <- complaints_raw %>% 
  filter( # 671 records dropped
    str_detect(bbl, "[1-5]\\d{9}"),
    !is.na(resolution_description)
  ) %>% 
  left_join(res_desc_lookup, by = "resolution_description") %>% 
  # Replace duplicates with the description of the most recent non-duplicate in that BBL
  group_by(bbl) %>% 
  mutate(res_desc_filled = if_else(res_desc_recode =="duplicate", NA_character_, res_desc_recode)) %>% 
  arrange(created_date, .by_group = TRUE) %>% 
  fill(res_desc_filled, .direction = "down") %>% 
  ungroup() %>% 
  mutate(
    viol_issued = str_detect(res_desc_recode, "(- violations)|(- previous violations)"),
    viol_issued_filled = str_detect(res_desc_filled, "(- violations)|(- previous violations)")
  )
```

Use [nyc-db](https://github.com/aepyornis/nyc-db) to pull HPD heat
violations for 2017-2018 heat season.

``` r
# Load connect_nyc_db() from secret config file (see sample_config.R)
source(here("config.R"))

# Set up connection you nyc-db database
con <- connect_nyc_db()

# Use nyc-db to get count of heat violations by bbl
violations <- tbl(con, "hpd_violations") %>% 
  filter(
    sql("bbl ~ '[1-5]\\d{9}'"), # valid BBLs
    sql("novdescription ~ '27-20(2[8-9]|3[0-3])'"), # heat violations
    sql("novissueddate between '2017-10-01' and '2018-05-31'") # 2017-2018 heat season
  ) %>% 
  select(bbl, novissueddate) %>% 
  collect()
```

-----

Total heat complaints: **216,601**

BBLs with heat complaints: **32,170**

<br>

Total heat violations: **17,424**

BBLs with heat violations: **7,456**

<br>

Heat complaints tagged as resulting in violations: **6,569**

Heat complaints and their duplicates tagged as resulting in violations:
**15,452**

BBLs with heat complaints tagged as resulting in violations: **4,580**

<br>

Heat complaints in BBLs with heat violations issued this season:
**88,117**

Heat complaints in BBLs with no heat violations issued this season:
**128,484**

BBLs with heat complaints but no heat violations issued this season:
**25,773**

-----

``` r
# Loads ggplot2 theme theme_heatseek(), vector heatseek_colors for graphs, heatseek_logo()
# which returns a scaled {magick} image, and ggimage() which works like ggsave
# but returns a {magick} image
source(here("R", "theme_heatseek.R"))

boro_to_borough <- function(x) {
  recode(x, "1" = "Manhattan", "2" = "Bronx", "3" = "Brooklyn", "4" = "Queens", "5" = "Staten Island")
}

p <- complaints_clean %>% 
  filter(viol_issued_filled) %>% 
  mutate(borough = boro_to_borough(str_sub(bbl, 1, 1))) %>% 
  count(borough) %>% 
  mutate(borough = fct_reorder(borough, n, .desc = TRUE)) %>% 
  ggplot() +
  aes(x = borough, y = n, label = scales::comma(n)) +
  geom_col(width = 0.7, fill = heatseek_colors[["orange"]]) +
  scale_y_continuous(labels = NULL) +
  geom_text(nudge_y = 250, na.rm = TRUE, size = 4, fontface = "bold", color = heatseek_colors["orange"]) +
  theme_heatseek() +
  theme(
    axis.text = element_text(size = 12, face = "bold"),
    panel.grid = element_blank()
  ) +
  labs(
    title = "Heat Complaints Resulting in HPD Violations",
    subtitle = "2017-2018 Heat Season",
    x = NULL, y = NULL,
    caption = "Sources: NYC 311"
  )

p %>% 
  ggimage(width = 8, height = 4) %>% 
  image_composite(heatseek_logo(), offset = "+1850+30") %>% 
  image_write(here("img", "boro-complaints-violations_barchart.png"))

knitr::include_graphics(here("img", "boro-complaints-violations_barchart.png"))
```

![](/Users/maxwell/repos/heatseek-blogs/img/boro-complaints-violations_barchart.png)<!-- -->
