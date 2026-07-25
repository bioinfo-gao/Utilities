# mamba install bioconductor-genomicfeatures -c bioconda -c conda-forge -y # 10 min 
install.packages("BiocManager", repos = "https://cran.rstudio.com/")
BiocManager::install("txdbmaker") # 这个程序不应该用R安装，几十分钟很慢，所以用Python来处理
# mamba install bioconductor-txdbmaker -c bioconda -c conda-forge -y
library(BiocManager)

library(txdbmaker)
library(GenomicFeatures)

setwd("/home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/Final_Report") 
# 1. 定义文件路径
gtf_path <- "/home/songz/lhn_work/database/02.genome/mouse_reference/Mus_musculus.gtf"
#counts_path <- "salmon.merged.gene_counts.tsv"
counts_path <- "samples.merged.gene_counts.tsv"

cat("正在解析 GRCm39.109 GTF 文件...\n")

# 2. 构建 TxDb 并计算基因长度 (非重叠外显子之和)
txdb <- makeTxDbFromGFF(gtf_path, format="gtf")
exons_list <- exonsBy(txdb, by="gene")
gene_lengths <- sum(width(reduce(exons_list)))
length_df <- data.frame(gene_id = names(gene_lengths), length = gene_lengths)

# 3. 读取 Counts 数据
counts <- read.table(counts_path, header = TRUE, row.names = 1, check.names = FALSE)

# 4. 匹配基因 ID
# 注意：Ensembl 的 GTF 通常带有版本号 (如 ENSMUSG00000000001.4)
# 如果你的 Counts 表里没有小数点后的版本号，需要先剔除
# rownames(counts) <- gsub("\\..*", "", rownames(counts)) 

common <- intersect(rownames(counts), length_df$gene_id)
counts_final <- counts[common, ]
lengths_final <- length_df[match(common, length_df$gene_id), "length"]

cat(sprintf("成功匹配到 %d 个基因进行计算。\n", length(common)))

# 5. 计算 FPKM 和 TPM
calc_metrics <- function(counts, lengths) {
    total_reads <- colSums(counts) / 1e6
    gene_kb <- lengths / 1e3
    
    # FPKM
    fpkm <- counts / gene_kb
    fpkm <- t(t(fpkm) / total_reads)
    
#     # TPM
#     tpm <- t(t(fpkm) / colSums(fpkm)) * 1e6
  return(list(fpkm=fpkm))
}

results <- calc_metrics(counts_final, lengths_final)

# 6. 保存结果
#write.table(fpkm, "salmon.merged.gene_fpkm.tsv", sep="\t", quote=FALSE, col.names=NA)
write.table(results$fpkm, "salmon.merged.gene_fpkm.tsv", sep="\t", quote=FALSE, col.names=NA)
# write.table(results$tpm, "salmon.merged.gene_tpm.tsv", sep="\t", quote=FALSE, col.names=NA)

cat("计算完成！文件已生成：\n- salmon.merged.gene_fpkm.tsv\n- salmon.merged.gene_tpm.tsv\n")