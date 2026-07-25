# R Statistics Essential Training
# Ex01_07
# Importing data

# EXCEL FILES
# Don't do it
browseURL("http://cran.r-project.org/doc/manuals/R-data.html#Reading-Excel-spreadsheets")

# TEXT FILES
# Load a spreadsheet that has been saved as tab-delimited text file
# Need to give complete address to file
# This command gives an error on missing data
# but works on complete data
# "header = TRUE" means the first line is a header
# trends.txt <- read.table("~/Desktop/R/GoogleTrends.txt", header = TRUE)
trends.txt <- read.table("/home/gao/projects/Utilities/R/2026_Tested_Versions/Ch01/01_07/GoogleTrends.csv", sep = ",", header = TRUE)
?read.table

# This works with missing data by specifying the
# separator: \t is for tabs, sep = "," for commas
# R converts missing to "NA"
# trends.txt <- read.table("~/Desktop/R/GoogleTrends.txt", header = TRUE, sep = "\t")
str(trends.txt)  # This gives structure of object sntxt
# Or click on file in Workspace viewer, which brings up this:


# Example code snippet
# install.packages("gtrendsR") # quotation marks are important, cannot be omitted !!
# library(gtrendsR)
# res <- gtrends(c("Hand sanitizer"), geo = "US", time = "now 1-H")
# res$interest_over_time
# getwd()
# setwd("/home/gao/projects/Utilities/R/2026_Tested_Versions")
# write.csv(res$interest_over_time, "trends.csv")

#trends.txt <- read.table("/home/gao/projects/Utilities/R/2026_Tested_Versions/trends.csv", header = TRUE) # NO separator provided, error
trends.txt <- read.table("/home/gao/projects/Utilities/R/2026_Tested_Versions/Ch01/01_07/trends.csv", header = TRUE, sep = ",")

View(trends.txt)
?View

# CSV FILES
# Don't have to specify delimiters for missing data
# because CSV means "comma separated values"
# trends.csv <- read.csv("~/Desktop/R/GoogleTrends.csv", header = TRUE)
trends.csv <- read.csv("/home/gao/projects/Utilities/R/2026_Tested_Versions/Ch01/01_07/GoogleTrends.csv", header = TRUE)
str(trends.csv)
View(trends.csv)

rm(list = ls())  # Clean up
