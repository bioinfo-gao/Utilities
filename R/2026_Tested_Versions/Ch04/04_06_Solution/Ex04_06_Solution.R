# R Statistics Essential Training
# Ex04_06_Solution
# Transforming skewed data

# Import data
#xskew <- read.csv("~/Desktop/R/xskew.csv")
xskew <- read.csv("/home/gao/projects/Utilities/R/2026_Tested_Versions/Ch04/04_05_Challenge/xskew.csv")
xskew

# ... existing code ...

x <- xskew[, 2]
hist(x)

# Square data
# Squaring transformation is used to correct negative (left) skewness by expanding the lower tail and compressing the upper tail
# When values are between 0 and 1, squaring makes them smaller; when values are > 1, squaring makes them larger
# This stretches out the clustered low values and reduces the impact of extreme high values, making the distribution more symmetric
# The transformation is monotonic (preserves order) but non-linear, which reshapes the distribution
# Best applied when all values are positive; if data contains zeros or negatives, add a constant first: (x + c)^2
# by ZG2026

# 如果数据在0-10区间
# 比如 9 的平方是 81， 
# 则降低 [9, 10] 区间的密度 , 增加了[80， 90] 区间的密度  把强烈右偏的数据变换为近似正态分布

# 如何还要保持数据区间不变， 则平方之后再除以10

# 比如 9 的平方是 3， 再乘以10
# 则降低 [0, 9] 区间的密度 , 增加了[30， 40] 区间的密度， 把强烈左偏的数据变换为近似正态分布

x2 <- x^2
hist(x2)
boxplot(x2)

# 4th power
# Raising to the 4th power is a more aggressive transformation than squaring for correcting severe negative skewness
# Higher powers create stronger compression of the right tail and stronger expansion of values close to zero
# This can better normalize distributions with extreme left skew where squaring alone is insufficient
# However, it may over-correct moderate skewness and make the distribution positively skewed instead
# Like squaring, requires all positive values; use (x + c)^4 if data contains zeros or negatives
# The choice between x^2 and x^4 depends on the degree of skewness: mild skew → square, severe skew → higher power
# by ZG2026
x4 <- x^4
hist(x4)   # 现在偏态大体上被纠正，但范围从0-10区间 变成了 0-10000 区间 
boxplot(x4) 

# ... existing code ...

rm(list = ls())  # Clean up

# 核心原理总结：

# 平方变换 (x²)：

# 适用于**负偏态（左偏）**数据，即大部分值集中在右侧，左侧有长尾
# 对小于1的值会缩小，对大于1的值会放大
# 能够拉伸聚集的低值区域，压缩高值区域的极端值
# 使分布更加对称
# 四次方变换 (x⁴)：

# 是更强烈的变换，适用于严重负偏态的情况
# 比平方变换更强烈地压缩右尾、扩展接近零的值
# 当平方变换不足以纠正偏态时使用
# 但可能过度校正，导致分布变成正偏态
# 注意：这两种变换都要求数据为正值。如果数据包含零或负数，需要先加上一个常数使其全部为正。