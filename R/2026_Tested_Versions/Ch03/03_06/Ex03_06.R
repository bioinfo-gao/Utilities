# R Statistics Essential Training
# Ex03_06
# Robust statistics for univariate analyses

# See "A Brief Overview of Robust Statistics" by Olfa Nasraoui, at
# browseURL("http://j.mp/12YPV5L") # NO more 2026

# Or see the CRAN Task View on robust statistics at
browseURL("http://cran.r-project.org/web/views/Robust.html")

# Load data
?state.area 
data(state.area)  # Gets error message
area <- state.area  # But can save as vector
area
hist(area)
boxplot(area)
boxplot.stats(area) # conf	the lower and upper extremes of the ‘notch’ 
?boxplot.stats

fivenum(area)
summary(area)

## from ?boxplot.stats
require(stats)
x <- c(1:100, 1000)
x
boxplot(x)   
boxplot.stats(x)   

# ==================================== from ?boxplot.stats
#  stat this vector is identical to fivenum(x, na.rm = TRUE) ？？？？ 2026 by ZF

# $stats: 箱线图的5个关键值（ whisker 的末端和盒子的边界）。
# 注意：这里的 whisker 末端通常是不超过 1.5 * IQR 范围的最大/最小观测值，而不是数据集的绝对最大/最小值。
(b1 <- boxplot.stats(x))
(b2 <- boxplot.stats(x, do.conf = FALSE, do.out = FALSE))

?stopifnot
# If any of the expressions (in ... or exprs) are not all TRUE, stop is called, 
# producing an error message indicating the first expression which was not (all) true. << ============= Error messege

stopifnot(b1 $ stats == b2 $ stats) # do.out = FALSE is still robust
boxplot.stats(x, coef = 3, do.conf = FALSE)

## no outlier treatment:
(b3 <- boxplot.stats(x, coef = 0))
stopifnot(b3$stats == fivenum(x))

## missing values are ignored
x
b1 # b1 是x 的 boxplot.stats
c(x, NA) # 这是在c 后面添加了一个NA， 
boxplot.stats( c(x, NA) ) 
# 这是在x 后面添加了一个NA， 
# 再做boxplot.stats


stopifnot(identical( boxplot.stats( c(x, NA) ),  b1)) #
## ... infinite values are not:

# 这是在x 后面添加了一个 正无穷，一个负无穷， 
(r <- boxplot.stats(c(x, -1:1/0)))
stopifnot(r$out == c(1000, -Inf, Inf))

?fivenum
fivenum(x)
fivenum(x, na.rm = TRUE)
### ========================================


# Robust methods for describing center:
mean(area)  # NOT robust
median(area)
mean(area, trim = .05)  # 5% from each end (10% total)
mean(area, trim = .10)  # 10% from each end (20% total)
mean(area, trim = .20)  # 20% from each end (40% total)
mean(area, trim = .50)  # 50% from each end = median

# Robust methods for describing variation:
sd(area)       # NOT robust
mad(area)      # Median absolute deviation
IQR(area)      # Interquartile range (Can select many methods)
fivenum(area)  # Tukey's hinges (similar to quartiles)

rm(list = ls())  # Clean up
