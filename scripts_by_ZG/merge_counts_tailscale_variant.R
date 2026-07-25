# install.packages("languageserver") # 用于代码补全和语法检查
# install.packages("httpgd")        # 用于在 VS Code 内部显示高质量图片
# 1: In install.packages("languageserver") :
#   安装程序包‘xml2’时退出狀態的值不是0
# 2: In install.packages("languageserver") :
#   安装程序包‘lintr’时退出狀態的值不是0
# 3: In install.packages("languageserver") :
#   安装程序包‘roxygen2’时退出狀態的值不是0
# 4: In install.packages("languageserver") :
#   安装程序包‘languageserver’时退出狀態的值不是0
# options(download.file.method = "libcurl")
# remotes::install_github("nx10/httpgd")

# if (!require("remotes")) install.packages("remotes")
# remotes::install_github("nx10/httpgd")

# if (!require("BiocManager", quietly = TRUE))
#     install.packages("BiocManager")
# BiocManager::install("tximport")
# library("remotes")
# library("styler")
library("tximport")

# 1. 设置路径
base_dir <- "/home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/results/star_salmon"
tx2gene_file <- file.path(base_dir, "salmon_tx2gene.tsv")

# 2. 获取所有样本的 quant.sf 路径
samples <- list.dirs(base_dir, full.names = FALSE, recursive = FALSE)
samples <- samples[grep("^D", samples)] # 只取 D 开头的样本
files <- file.path(base_dir, samples, "quant.sf")
names(files) <- samples

# 3. 读取转换表
tx2gene <- read.delim(tx2gene_file, header = FALSE)

# 4. 运行 tximport 合并 (这就是 Nextflow 最后一步在做的事)
txi <- tximport(files, type = "salmon", tx2gene = tx2gene)

# 5. 保存结果
write.table(txi$counts, "salmon.merged.gene_counts.tsv", sep="\t", quote=F, col.names=NA)
write.table(txi$abundance, "salmon.merged.gene_tpm.tsv", sep="\t", quote=F, col.names=NA)

cat("Successfully merged!", length(samples), "samples processed.\n")