# 完整解决方案
# 方案 1：使用 conda 安装 R 包（推荐）
# 由于你使用的是 conda 环境的 R，建议优先使用 conda 安装：

# 方案 2：在 R 中正确安装
# 如果 conda 安装不可用，在 R 中按以下步骤操作：
# # 在终端中运行（不是在R中）
# conda install -c conda-forge r-kableextra r-corrplot r-car r-patchwork r-dplyr r-ggplot2
# mamba install -c conda-forge r-car -y  # 依赖包太多，R内安装困难，在mamba 环境安装  by ZG_20ZG

# # 1. 首先设置正确的库路径
# .libPaths()

# # 2. 安装包时指定正确的库路径（如果需要）
install.packages("car", lib = .libPaths()[1])
# install.packages("kableExtra", lib = .libPaths()[1])
# install.packages("corrplot", lib = .libPaths()[1])
# install.packages("patchwork", lib = .libPaths()[1])
# install.packages("dplyr", lib = .libPaths()[1])
# install.packages("ggplot2", lib = .libPaths()[1])

# 3. 或者一次性安装所有包
required_packages <- c("car", "kableExtra", "corrplot", "patchwork", "dplyr", "ggplot2")
install.packages(required_packages, lib = .libPaths()[1])
# 安装所有必需的包
install.packages(c("kableExtra", "corrplot", "car", "patchwork", "dplyr", "ggplot2"))

# # 使用清华镜像源
# install.packages(c("kableExtra", "corrplot", "car", "patchwork", "dplyr", "ggplot2"), 
#                  repos = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/")

require("kableExtra")
require( "corrplot")
require("car")
require("patchwork")
require("dplyr")
require( "ggplot2") 



# 3. 安装完成后再次预览
# 安装完所有包后，再次运行你的命令： 或者在qmd 界面右上角点击 preview 即可以预览了
# quarto preview /home/gao/projects/Utilities/R/2026_Tested_Versions/Ch05/05_03/Longley_Dataset_Analysis.qmd --no-browser --no-watch-inputs


# No TeX installation was detected.

# Please run 'quarto install tinytex' to install TinyTex.
# If you prefer, you may install TexLive or another TeX distribution.