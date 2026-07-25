# R Statistics Essential Training
# Ex05_01
# Selecting cases

# Load data
?mtcars
data(mtcars)
mtcars
head(mtcars)
# ... existing code ...
# Load data
# mtcars 数据集包含1974年《Motor Trend》杂志抽取的32款汽车的燃油消耗和10个汽车设计性能指标
# 各列含义如下：
# mpg  - Miles/(US) gallon，每加仑汽油行驶英里数（燃油效率）
# cyl  - Number of cylinders，气缸数量（4、6或8个）
# disp - Displacement (cu.in.)，发动机排量（立方英寸）
# hp   - Gross horsepower，总马力
# drat - Rear axle ratio，后轴比
# wt   - Weight (1000 lbs)，车重（以1000磅为单位）
# qsec - 1/4 mile time (sec)，四分之一英里加速时间（秒）
# vs   - Engine shape，发动机形状（0 = V型，1 = 直列型）
# am   - Transmission，变速箱类型（0 = 自动，1 = 手动）
# gear - Number of forward gears，前进挡位数
# carb - Number of carburetors，化油器数量
?mtcars
data(mtcars)
mtcars

# ... existing code ...

# Mean quarter-mile time (for all cars)
mean(mtcars$qsec)

# Mean quarter-mile time (for 8-cylinder cars)
# Use square brackets to indicate what to select
# in this format: [rows]
mean(mtcars$qsec[mtcars$cyl == 8])

# Median horsepower (for all cars)
median(mtcars$hp)

# Mean MPG for cars above median horsepower
mean(mtcars$mpg[mtcars$hp > median(mtcars$hp)])

# Create new data frame for 8-cylinder cars
# To create a new data frame, must indicate
# which rows and columns to copy in this
# format: [rows, columns]. To select all
# columns, leave second part blank.
cyl.8 <- mtcars[mtcars$cyl == 8, ]

# Select 8-cylinder cars with 4+ barrel carburetors
mtcars[mtcars$cyl == 8 & mtcars$carb >= 4, ]

rm(list = ls())  # Clean up
