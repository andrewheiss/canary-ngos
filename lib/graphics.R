# ggplot themes -----------------------------------------------------------

#' theme_ngo
#'
#' A custom ggplot2 theme used throughout this project
#'
#' @param base_size base font size (default is 9)
#' @param base_family base font family (default is Roboto Condensed)
#'
#' @export
#'
#' @examples
#' library(ggplot2)
#'
#' ggplot(mtcars, aes(x = mpg, y = wt)) +
#'   geom_point() +
#'   theme_ngo()
theme_ngo <- function(base_size = 9, base_family = "Inter Light") {
  ret <- theme_bw(base_size, base_family) +
    theme(plot.title = element_text(size = rel(1.4), face = "bold",
                                    family = "Inter"),
          plot.subtitle = element_text(size = rel(1), face = "plain",
                                       family = "Inter Medium"),
          plot.caption = element_text(size = rel(0.8), color = "grey50", face = "plain",
                                      family = "Inter Light",
                                      margin = margin(t = 10)),
          panel.border = element_rect(color = "grey50", fill = NA, size = 0.15),
          panel.spacing = unit(1, "lines"),
          panel.grid = element_line(size = 0.30),
          panel.grid.minor = element_blank(),
          strip.text = element_text(size = rel(0.9), hjust = 0,
                                    family = "Inter", face = "bold"),
          strip.background = element_rect(fill = "grey85", colour = NA),
          axis.ticks = element_blank(),
          axis.title.x = element_text(margin = margin(t = 10)),
          axis.title.y = element_text(margin = margin(r = 10)),
          axis.text = element_text(family = "Inter Light", face = "plain"),
          axis.title = element_text(family = "Inter Medium", face = "plain"),
          legend.key = element_blank(),
          legend.text = element_text(size = rel(1), family = "Inter Light", face = "plain"),
          legend.spacing = unit(0.1, "lines"),
          legend.box.margin = margin(t = -0.5, unit = "lines"),
          legend.margin = margin(t = 0),
          legend.position = "bottom")

  ret
}


# Conversion and formatting help ------------------------------------------

#' Convert mms to pts
#'
#' Convert units specified in millimeters to typographic points. This is especially helpful when working with ggplot geoms that use size parameters
#'
#' @param x a numeric value (in millimeters)
#'
#' @return A numeric value (in points)
#' @export
#'
#' @examples
#' library(ggplot2)
#'
#' ggplot(mtcars, aes(x = mpg, y = wt)) +
#'   geom_point() +
#'   annotate(geom = "text", x = 20, y = 4,
#'            label = "Here's a label", size = pts(11))
pts <- function(x) {
  as.numeric(grid::convertUnit(grid::unit(x, "pt"), "mm"))
}
