# 方法0：mamba install as in R_in_vsCode_in_tailscale.sh    （推荐）
# 方法1：从 CRAN 安装（ second 推荐）
# install.packages("httpgd")
# 方法2：如果 CRAN 版本有问题，从 GitHub 安装
# install.packages("remotes")
# remotes::install_github("nx10/httpgd")

install.packages("languageserver")

x <- 1:10

# Linux（需要 X11 支持）
x11()
plot(1:10)

# macOS
quartz()
plot(1:10)

# Windows
windows()
plot(1:10)

# 通用（自动选择）
dev.new()
plot(1:10)

library(httpgd)
hgd()  # 测试是否正常工作
plot(1:10)  # 测试绘图

# ✅ 正确：确保图形设备正确初始化
dev.new()  # 或 x11(), quartz(), windows() 根据系统
plot(1:10)
dev.off()  # 关闭设备（可选）