# R Statistics Essential Training
# Ex01_06
# Entering data manually

# Create sequential data
x1 <- 0:10  # Assigns number 0 through 10 to x1
x1  # Prints contents of x1 in console

x2 <- 10:0  # Assigns number 10 through 0 to x2
x2

x3 <- seq(10)  # Counts from 1 to 10 
x3
?seq

x4 <- seq(30, 0, by = -3)  # Counts down by 3
x4

# Manually enter data
x5 <- c(5, 4, 1, 6, 7, 2, 2, 3, 2, 8)  # Concatenate
x5
?c

# The following command is a shortcut for entering data manually, but only FOR Real numbers

# 1) NO strings allowed by this function

# 2) in RStudio, you can use the keyboard shortcut Cmd/Ctrl-Shift-M

# 3) in Positron, look at the bottom of the console, # enter TWICE for FINISH

x6 <- scan()  # After running this command, go to console
              # Hit return after each number
              # Hit return twice to stop
x6 
?scan


print(x6)

ls()  # List objects (same as Workspace viewer)
?ls

rm(list = ls())  # Clean up
