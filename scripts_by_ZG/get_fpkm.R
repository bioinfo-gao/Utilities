# # 1. 进入工作目录
# cd /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216

# # 2. 开启 screen
# screen -S calculate_fpkm

# # 3. 激活环境
# mamba activate DE_R44

# # 4. 使用 vim 创建 R 脚本
# vim get_fpkm.R

# R
# 读取 Counts 数据
setwd("/home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/Final_Report") 
#counts <- read.table("salmon.merged.gene_counts.tsv", header = TRUE, row.names = 1, check.names = FALSE)
counts <- read.table("samples.merged.gene_counts.tsv", header = TRUE, row.names = 1, check.names = FALSE)

# 读取 长度 数据 (Salmon 合并结果中通常包含这个文件)
# # 如果你没有这个文件，需要从 GTF 中提取长度
# lengths <- read.table("salmon.merged.gene_lengths.tsv", header = TRUE, row.names = 1, check.names = FALSE)

# 确保 Counts 和 Lengths 的基因顺序完全一致
common_genes <- intersect(rownames(counts), rownames(lengths))
counts <- counts[common_genes, ]
lengths <- lengths[common_genes, ]

# 定义计算 FPKM 的函数
countToFPKM <- function(counts, lengths) {
    # 计算每个样本的总 Reads 数 (Million 为单位)
    total_reads <- colSums(counts) / 1e6
    
    # 将长度转换为 Kilobase 为单位
    gene_lengths_kb <- lengths / 1e3
    
    # 计算 FPKM
    # 这里利用 R 的矩阵广播机制：先除以长度，再除以总 Reads 数
    fpkm <- counts / gene_lengths_kb
    fpkm <- t(t(fpkm) / total_reads)
    
    return(as.data.frame(fpkm))
}

# 执行计算
fpkm_results <- countToFPKM(counts, lengths)

# 保存结果
write.table(fpkm_results, "salmon.merged.gene_fpkm.tsv", sep="\t", quote=FALSE, col.names=NA)

cat("FPKM 计算完成！结果已保存至 salmon.merged.gene_fpkm.tsv\n")