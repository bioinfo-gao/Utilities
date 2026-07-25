# mamba deactivate 
# 加入 --override-channels 确保它只走你配置好的清华源，不去撞墙
# --override-channels: 这一行是关键。它告诉 Mamba：“别去管那个报错的 anaconda.org 了，只看我给你的这几个清华镜像站。”
# 避免 SSL 错误: 因为清华源在境内，连接非常稳定，不会出现那种“unexpected eof”的断开情况。
# 缓存复用: 你刚才运行时的日志显示 Using cache，这意味着即使重新运行，它也会从上次下载进度继续。
# mamba create -n DE_R44 \
#     --override-channels \
#     -c https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/bioconda/ \
#     -c https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge/ \
#     -c https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/ \
#     r-base=4.4 \
#     bioconductor-deseq2 \
#     r-ggplot2 \
#     bioconductor-tximport \
#     r-pheatmap \
#     r-ggrepel
# 创建一个名为 DE_Final 的纯净 R 4.4 环境
# mamba create -y -n DE_Final -c bioconda -c conda-forge \
#     r-base=4.4 \
#     bioconductor-deseq2 \
#     r-ggplot2 \
#     bioconductor-tximport \
#     r-pheatmap \
#     r-ggrepel
#mamba activate DE_R44
# 运行脚本
# Rscript DE_analysis.R
# 也可以进去“手动”操作（进入 R 交互界面）
# 1. 加载必要的包
library(DESeq2)
library(ggplot2) 

# 2. 读取数据
# 确保文件路径正确，就是我们刚刚合并出来的那个矩阵
#setwd("/home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/results/star_salmon")
setwd("/home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/")
counts_data <- read.table("salmon.merged.gene_counts.tsv", header = TRUE, row.names = 1, check.names = FALSE)
head(counts_data )

# 3. 将计数取整 (DESeq2 要求整数计数)
counts_data <- round(counts_data)

# 4. 构建样本信息表 (Coldata)
samples <- colnames(counts_data)
groups <- factor(c(rep("Control", 3), rep("Treatment1", 3), rep("Treatment2", 3)), levels = c("Control", "Treatment1", "Treatment2"))
groups
col_data <- data.frame(row.names = samples, condition = groups)
col_data

# 5. 构建 DESeq2 对象
dds <- DESeqDataSetFromMatrix(countData = counts_data,
                              colData = col_data,
                              design = ~ condition)

# 6. 运行差异分析
dds <- DESeq(dds)

# --- 核心函数：调整列顺序并排序 ---
process_res_ordered <- function(res, counts, filename) {
    res_df <- as.data.frame(res)
    
    # 将 padj 重命名为 Q_value
    colnames(res_df)[colnames(res_df) == "padj"] <- "Q_value"
    
    # 按照你的要求：[D1...D9] [统计指标]
    # 先把原始表达量矩阵放左边，统计指标放右边
    final_res <- cbind(counts, res_df)
    
    # 排序：Q_value 升序 (优先)，abs(log2FoldChange) 降序 (次之)
    # 注意：na.last = TRUE 确保 NA 值排在最后面
    final_res <- final_res[order(final_res$Q_value, -abs(final_res$log2FoldChange), na.last = TRUE), ]
    
    # 保存结果
    write.csv(final_res, filename, quote = FALSE)
    cat("生成文件:", filename, " (前 5 行显示):\n")
    print(head(final_res, 5))
    cat("\n")
}

# 4. 执行三次两两比较
getwd()  # 检查当前工作目录
# 1) Treatment1 vs Control
res1 <- results(dds, contrast = c("condition", "Treatment1", "Control"))
process_res_ordered(res1, counts_data, "DE_T1_vs_Control.csv")

# 2) Treatment2 vs Control
res2 <- results(dds, contrast = c("condition", "Treatment2", "Control"))
process_res_ordered(res2, counts_data, "DE_T2_vs_Control.csv")

# 3) Treatment2 vs Treatment1
res3 <- results(dds, contrast = c("condition", "Treatment2", "Treatment1"))
process_res_ordered(res3, counts_data, "DE_T2_vs_T1.csv")

# 9. 绘制简单的 PCA 图检查样本聚类情况
vsd <- vst(dds, blind = FALSE)
pca_plot <- plotPCA(vsd, intgroup = "condition") + 
            theme_minimal() + 
            ggtitle("PCA Plot of 9 Samples")

ggsave("PCA_plot.png", pca_plot, width = 8, height = 6)

cat("DE Analysis Complete! Files generated: 3 CSVs and 1 PCA plot.\n")