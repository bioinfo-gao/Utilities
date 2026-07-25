# R Statistics Essential Training
# Ex08_01
# Creating clustered bar chart for frequencies

# Load data
# Built-in dataset "warpbreaks"
library(datasets) # Load dataset ZG_2026 sometimes it's NEEDED
?warpbreaks
warpbreaks
# Doesn't work: ==============<<<<<<<<<<<<<<<<
barplot(breaks ~ wool*tension, data = warpbreaks)

data <- tapply(warpbreaks$breaks,
               list(warpbreaks$wool,
                    warpbreaks$tension),
               mean)

data

barplot(data,
        beside = TRUE,
        col = c("steelblue3", "thistle3"),
        bor = NA,
        main = "Mean Number of Warp Breaks\nby Tension and Wool",
        xlab = "Tension",
        ylab = "Mean Number of Breaks")

# For legend, "locator(1)" is interactive and lets you click <<<<========== ZG 2022-06-07
# where you want to put the legend. You can also specify
# with coordinates.
# legend(locator(1), #====================<<<<<<<<<<<<<<< NOT working in Positron
#        rownames(data),
#        fill = c("steelblue3", "thistle3"))

# 使用预定义的位置（推荐） # ZG 2026-04-17
legend("topright", 
       rownames(data),
       fill = c("steelblue3", "thistle3"))


library(ggplot2)

# For means with error bars
ggplot(warpbreaks, aes(x = interaction(wool, tension), y = breaks)) +
  stat_summary(fun = mean, geom = "bar") +
  stat_summary(fun.data = mean_se, geom = "errorbar", width = 0.2) +
  labs(x = "Wool-Tension Combination", y = "Mean Breaks") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))



rm(list = ls())  # Clean up
