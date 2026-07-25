library(DESeq2)

# 1. 加载数据并取整
counts_data <- read.table("salmon.merged.gene_counts.tsv", header = TRUE, row.names = 1, check.names = FALSE)
counts_round <- round(counts_data)

# 2. 实验设计
col_data <- data.frame(
    row.names = colnames(counts_round),
    condition = factor(c(rep("Control", 3), rep("Treatment1", 3), rep("Treatment2", 3)), 
                       levels = c("Control", "Treatment1", "Treatment2"))
)
col_data
# 3. 运行 DESeq2 标准流程
dds <- DESeqDataSetFromMatrix(countData = counts_round, colData = col_data, design = ~ condition)
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
# 1) Treatment1 vs Control
res1 <- results(dds, contrast = c("condition", "Treatment1", "Control"))
process_res_ordered(res1, counts_data, "DE_T1_vs_Control_Reordered.csv")

# 2) Treatment2 vs Control
res2 <- results(dds, contrast = c("condition", "Treatment2", "Control"))
process_res_ordered(res2, counts_data, "DE_T2_vs_Control_Reordered.csv")

# 3) Treatment2 vs Treatment1
res3 <- results(dds, contrast = c("condition", "Treatment2", "Treatment1"))
process_res_ordered(res3, counts_data, "DE_T2_vs_T1_Reordered.csv")