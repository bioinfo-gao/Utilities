library(org.Mm.eg.db)
library(clusterProfiler)

# 1. 读取你之前的差异分析结果或 Counts 表 (获取 Gene ID 列表)
# 假设你的文件第一列是 ENSMUSG00000039220 这样的 ID
res <- read.csv("DE_T1_vs_Control_Clean.csv", row.names = 1)
genes_to_annotate <- rownames(res)

# 去掉可能存在的版本号 (如 .10)
genes_clean <- gsub("\\..*", "", genes_to_annotate)

cat("正在从 org.Mm.eg.db 提取多维度注释信息...\n")

# 2. 核心转换：使用 bitr 或 select 获取基础注释
# keys: 输入的ID,  columns: 想要获取的列
anno_base <- select(org.Mm.eg.db, 
                    keys = genes_clean, 
                    column = c("SYMBOL", "GENENAME", "ENTREZID", "UNIPROT"), 
                    keytype = "ENSEMBL")

# 3. 获取 GO 注释 (因为一个基因对应多个 GO，通常取第一个或合并)
# 为了简洁，我们这里提取 GO ID
anno_go <- select(org.Mm.eg.db, 
                  keys = genes_clean, 
                  column = c("GO"), 
                  keytype = "ENSEMBL")

# 4. 获取 KEGG 注释 (小鼠对应 mmu)
# 注意：KEGG 需要使用 Entrez ID (数字ID)
cat("正在获取 KEGG 路径信息...\n")
kegg_info <- bitr_kegg(anno_base$ENTREZID, fromType = "kegg", toType = "Path", organism = "mmu")

# 5. 合并所有信息 (构建类似你图片中的 Markdown Table 格式数据)
# 这里我们做一个简化合并逻辑
final_table <- data.frame(
    gene_id = genes_to_annotate,
    gene_symbol = anno_base$SYMBOL[match(genes_clean, anno_base$ENSEMBL)],
    gene_type = "protein_coding", # 这一列通常从 GTF 中提取，此处为示例
    Description = anno_base$GENENAME[match(genes_clean, anno_base$ENSEMBL)],
    UniProt = anno_base$UNIPROT[match(genes_clean, anno_base$ENSEMBL)]
)

# 6. 保存为 CSV
write.csv(final_table, "Mouse_Gene_Annotation_Table.csv", row.names = FALSE, quote = TRUE)

cat("注释表已生成：Mouse_Gene_Annotation_Table.csv\n")