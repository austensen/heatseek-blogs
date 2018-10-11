
# Heat Seek brand colors
heatseek_colors <- c(red = "#FB500A", orange = "#FF9932", blue = "#AFCDD3")

# Custom ggplot2 theme for Heat Seek graphs
theme_heatseek <- function(base_size = 11, 
                           base_family = "",
                           base_line_size = base_size/22, 
                           base_rect_size = base_size/22) {
  
  gg <- ggplot2::theme_minimal()
  gg <- gg + ggplot2::theme(
    panel.grid.minor.x = ggplot2::element_blank(),
    panel.grid.minor.y = ggplot2::element_blank(),
    axis.title.y.right = ggplot2::element_text(margin = ggplot2::margin(0, 0, 0, 10, "pt")),
    axis.title.y.left = ggplot2::element_text(margin = ggplot2::margin(0, 10, 0, 0, "pt")),
    plot.title = ggplot2::element_text(face = "bold"),
    plot.caption = ggplot2::element_text(face = "italic", color = "darkgrey", vjust = -0.2)
  )
}

# Returns Heat Seek logo as a {magick} image
heatseek_logo <- function(scale_geometry = 400) {
  img <- magick::image_read(here::here("img", "logos", "heatseek-logo.png"))
  img <- magick::image_scale(img, geometry = scale_geometry)
  img
}
  
# Returns Mapbox logo as a {magick} image
mapbox_logo <- function(scale_geometry = 200) {
  img <- magick::image_read(here::here("img", "logos", "mapbox-logo.png"))
  img <- magick::image_scale(img, geometry = scale_geometry)
  img <- magick::image_quantize(img, colorspace = "gray")
  img <- magick::image_colorize(img, opacity = 0.6, "grey")
  img
}
# Returns Mapbox logo as a {magick} image
osm_logo <- function(scale_geometry = 200) {
  img <- magick::image_read(here::here("img", "logos", "osm-logo.png"))
  img <- magick::image_scale(img, geometry = scale_geometry)
  img <- magick::image_quantize(img, colorspace = "gray")
  img <- magick::image_colorize(img, opacity = 0.6, "grey")
  img
}
  
# Works live ggsave() but returns a {magick} image
ggimage <- function(plot = ggplot2::last_plot(), width, height, units = "in", device = "png", ...) {
  plot_file <- tempfile()
  ggsave(
    filename = plot_file, 
    plot = plot, 
    width = width, 
    height = height, 
    units = units, 
    device = device, 
    ...
  )
  magick::image_read(plot_file)
}