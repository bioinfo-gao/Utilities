# R Statistics Essential Training
# Ex06_05_Solution
# Creating your own grouped boxplots

# Load data
# gsd <- read.csv("~/Desktop/R/SearchData.csv", header = TRUE)
gsd <- read.csv("/home/gao/projects/Utilities/R/2026_Tested_Versions/Ch06/06_04_Challenge/SearchData.csv", header = TRUE)
# NO trainling "/" for file !! by ZG 2026
gsd[1:5, ]

# Draw boxplots of interest in NFL (nfl) by region
# Basic version
boxplot(gsd$nfl ~ gsd$region)
gsd[gsd$region == "Midwest", ]

# Modified version
require("RColorBrewer")
boxplot(gsd$nfl ~ gsd$region,
        col = brewer.pal(4, "Set2"),
        boxwex = 0.5,  # Width of box
        whisklty = 1,  # Whisker line type; 1 = solid line
        staplelty = 1,  # Staple type; 0 = none
        outpch = 16,  # Outlier symbol; 16 = filled circle
        outcol = brewer.pal(4, "Set2"),  # Outlier color
        main = "Google Search Interest in NFL by Region of US",
        xlab = "Region of US",
        ylab = "Search Interest (z-scores)")

# Clean up
detach("package:RColorBrewer", unload=TRUE)
rm(list = ls())