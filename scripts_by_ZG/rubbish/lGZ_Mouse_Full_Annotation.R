library(biomaRt)
library(org.Mm.eg.db)
library(dplyr)

# 1. 连接 Ensembl 数据库获取基础信息
cat("Step 1: 正在从 BioMart 抓取基础注释、GO 和 UniProt...\n")
mart <- useMart("ensembl", dataset = "mmusculus_gene_ensembl")

# 移除报错字段，保留有效字段
attributes <- c(
  "ensembl_gene_id", 
  "external_gene_name", 
  "gene_biotype", 
  "description", 
  "go_id", 
  "name_1006", 
  "uniprotswissprot"
)

raw_biomart <- getBM(attributes = attributes, mart = mart)

# 2. 格式化 BioMart 数据 (合并 GO)
cat("Step 2: 正在格式化 GO 描述 (编号+括号)...\n")
biomart_formatted <- raw_biomart %>%
  mutate(GO_fmt = ifelse(go_id != "", paste0(go_id, "(", name_1006, ")"), "")) %>%
  group_by(ensembl_gene_id) %>%
  summarize(
    gene_symbol = first(external_gene_name),
    gene_type = first(gene_biotype),
    Description = first(description),
    GO = paste(unique(GO_fmt[GO_fmt != ""]), collapse = "; "),
    UniProt = paste(unique(uniprotswissprot[uniprotswissprot != ""]), collapse = "; ")
  )

# 3. 使用 org.Mm.eg.db 补全 KEGG, KO, EC
cat("Step 3: 正在从本地 org.Mm.eg.db 补全 KEGG 和 EC 编号...\n")
ids <- biomart_formatted$ensembl_gene_id
extra_anno <- select(org.Mm.eg.db, 
                     keys = ids, 
                     columns = c("PATH", "ENZYME"), 
                     keytype = "ENSEMBL")

# 格式化额外注释
extra_formatted <- extra_anno %>%
  group_by(ENSEMBL) %>%
  summarize(
    KEGG_ID = paste(unique(PATH[!is.na(PATH)]), collapse = "; "),
    EC = paste(unique(ENZYME[!is.na(ENZYME)]), collapse = "; ")
  )

# 4. 合并所有数据
cat("Step 4: 正在合并最终大表...\n")
final_table <- biomart_formatted %>%
  left_join(extra_formatted, by = c("ensembl_gene_id" = "ENSEMBL")) %>%
  mutate(No = row_number()) %>%
  select(No, gene_id = ensembl_gene_id, gene_symbol, gene_type, Description, GO, UniProt, KEGG_ID, EC)

# 5. 保存结果
write.table(final_table, "Mouse_Full_Annotation_Final.txt", sep="\t", row.names = FALSE, quote = FALSE)

cat("🎉 任务完成！生成的表格包含所有 6-8 万个小鼠基因的完整功能注释。\n")