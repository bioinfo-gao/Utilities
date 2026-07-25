# Load required libraries
require("RColorBrewer")

# Load data
data(iris)

# Define the panel.hist function exactly as in Ex08_03.R
# 注意这是生成对角线上的直方图的
panel.hist <- function(x, ...)
{
  usr <- par("usr"); on.exit(par(usr))
  par(usr = c(usr[1:2], 0, 1.5) )
  h <- hist(x, plot = FALSE)
  breaks <- h$breaks; nB <- length(breaks)
  y <- h$counts; y <- y/max(y)
  rect(breaks[-nB], 0, breaks[-1], y,  ...)
}

# Generate plot with exact same parameters as Ex08_03.R
# Use png() with exact dimensions matching plot26.png (653x658)
png("plot26_recreated.png", width = 653, height = 658, res = 96)

pairs(iris[1:4], 
      panel = panel.smooth,
      main = "Scatterplot Matrix for Iris Data Using pairs Function",
      diag.panel = panel.hist, 
      pch = 16, 
      col = brewer.pal(3, "Pastel1")[unclass(iris$Species)])


# Clean up
detach("package:RColorBrewer", unload = TRUE)