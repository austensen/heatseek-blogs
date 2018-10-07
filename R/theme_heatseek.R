
# Heat Seek brand colors
heatseek_colors <- c(red = "#FB500A", orange = "#FF9932", lightblue = "#AFCDD3")

# Custom ggplot2 theme for Heat Seek graphs
theme_heatseek <- function(base_size = 11, 
                           base_family = "",
                           base_line_size = base_size/22, 
                           base_rect_size = base_size/22) {
  
  gg <- ggplot2::theme_minimal()
  gg <- gg + ggplot2::theme(
    panel.grid.major.x = ggplot2::element_blank(),
    panel.grid.minor.x = ggplot2::element_blank(),
    panel.grid.minor.y = ggplot2::element_blank(),
    plot.title = ggplot2::element_text(face = "bold"),
    plot.caption = ggplot2::element_text(face = "italic", color = "darkgrey", vjust = -0.2)
  )
}