library(org.Mm.eg.db)

cat("正在导出全基因组小鼠基因注释列表...\n")

# 1. 提取所有 Ensembl ID
all_ensembl_ids <- keys(org.Mm.eg.db, keytype = "ENSEMBL")

# 2. 批量查询对应的多项信息
# 我们选取最核心的字段：Symbol, Name(Description), EntrezID, Chromosome
all_anno <- select(org.Mm.eg.db, 
                   keys = all_ensembl_ids, 
                   columns = c("SYMBOL", "GENENAME", "ENTREZID", "CHR"), 
                   keytype = "ENSEMBL")

# 3. 清理重复项
# 数据库中有些基因对应多个染色体位置或ID，我们保留主信息
all_anno_clean <- all_anno[!duplicated(all_anno$ENSEMBL), ]

# 4. 统计导出的数量
gene_count <- nrow(all_anno_clean)
cat(sprintf("成功导出 %d 个小鼠基因注释。\n", gene_count))

# 5. 保存为 CSV 和 TSV (方便你用 Excel 或 Linux 命令行查看)
write.csv(all_anno_clean, "Mouse_Full_Genome_Annotation_GRCm39.csv", row.names = FALSE)
write.table(all_anno_clean, "Mouse_Full_Genome_Annotation_GRCm39.tsv", sep="\t", row.names = FALSE, quote = FALSE)

cat("文件已保存至：Mouse_Full_Genome_Annotation_GRCm39.csv\n")