<img src="img/logos/heatseek-logo.png" width="200">

Data work for blog updates on 2017-2018 heat season

---

### Getting Started

<br>

Install the following R packages

```r
pkgs <- c("tidyverse", "here", "fs", "sf", "mapdeck", "htmlwidgets", "magick", "DBI", "darksky")
install.packages(pkgs)
```

Edit [`sample_config.R`](sample_config.R) to add you connection info for [nyc-db](https://github.com/aepyornis/nyc-db), your [MapBox](https://www.mapbox.com/signup) API key, and your [DarkSky](https://darksky.net/dev/register) API key.

---

### Data

<br>

All of the [`data`](data) created for this analysis are available for download, along with [`data dictionaries`](data/data-dictionaries). Included in the folder are a collection of geojson files with heat complaints, heat violations, residential units, and properties aggregated to a varity of geographic levels.

---

### Results

<br>

#### [`season-heat-complaints_barchart.R`](season-heat-complaints_barchart.R)
![](img/season-heat-complaints_barchart.png)

---

#### [`temperature-complaints_linechart.R`](temperature-complaints_linechart.R)
![](img/temperate-complaints_2017-2018_linechart.png)

---

#### [`heat-complaints-stats.Rmd`](heat-complaints-stats.md)
![](img/boro-complaints-violations_barchart.png)

---

#### [`heat-complaints-buildings_map.R`](heat-complaints-buildings_map.R)
![](img/heat-complaints-buildings_map.png)
