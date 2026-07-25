# R Statistics Essential Training
# Ex08_03
# Creating scatterplot matrices

# Load data
library(datasets)
# 两个图都需要2分钟才能显示 完全成功  <<<<<<< ===========================================
# 很奇怪的是：经常图片无法显示完全，但是拉动一下plot panel 下的图片大小就可以正常显示

?iris
data(iris)
iris[1:5, ]

# Basic scatterplot matrix
pairs(iris[1:4])

# Modified scatterplot matrices


# Create palette with RColorBrewer
require("RColorBrewer")
display.brewer.pal(3, "Pastel1")

# Put histograms on the diagonal (from "pairs" help)
panel.hist <- function(x, ...) {
  usr <- par("usr")
  on.exit(par(usr))
  par(usr = c(usr[1:2], 0, 1.5))
  h <- hist(x, plot = FALSE)
  breaks <- h$breaks
  nB <- length(breaks)
  y <- h$counts
  y <- y / max(y)
  rect(breaks[-nB], 0, breaks[-1], y, ...)
  # Removed "col = "cyan" from code block; original below
  # rect(breaks[-nB], 0, breaks[-1], y, col = "cyan", ...)
}

library(graphics)
graphics::pairs(
  iris[1:4],
  panel = panel.smooth, # Optional smoother
  main = "Scatterplot Matrix for Iris Data Using pairs Function",
  diag.panel = panel.hist,
  pch = 16,
  col = brewer.pal(3, "Pastel1")[unclass(iris$Species)]
)

# Similar with "car" package
# Gives kernal density and rugplot for each variable
# R 4.5.1
# (base) zhen@DESKTOP-C8OKE65:~/GZ_Projects_2026$ mamba activate spatial
# critical libmamba Cannot activate, prefix does not exist at: '/home/zhen/miniforge3/envs/spatial'
# (base) zhen@DESKTOP-C8OKE65:~/GZ_Projects_2026$ mamba activate spatial_R  R 4.5
# (spatial_R) zhen@DESKTOP-C8OKE65:~/GZ_Projects_2026$ mamba install -c conda-forge r-car

# (base) zhen@DESKTOP-C8OKE65:~/GZ_Projects_2026$ mamba activate seurat_env # ===========> R4.3.3
# 以下行尾禁止升级R 且 自动安装 #同时降级了python 否则无法兼容
# (seurat_env) zhen@DESKTOP-C8OKE65:~/GZ_Projects_2026$ mamba install -c conda-forge r-car r-base=4.3.3 python=3.12 -y

# 很奇怪的是：经常图片无法显示完全，但是拉动一下plot panel 下的图片大小就可以正常显示

library(car)
library(stats)
scatterplotMatrix(
  ~ Petal.Length + Petal.Width + Sepal.Length + Sepal.Width | Species,
  data = iris,
  col = brewer.pal(3, "Dark2"),
  main = "Scatterplot Matrix for Iris Data Using \"car\" Package"
)

# Clean up
palette("default") # Return to default
detach("package:RColorBrewer", unload = TRUE)
detach("package:car", unload = TRUE)
rm(list = ls())
