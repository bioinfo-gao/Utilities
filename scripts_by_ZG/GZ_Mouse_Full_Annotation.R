library(biomaRt)
library(org.Mm.eg.db)
library(dplyr)

# 1. 连接 BioMart
cat("Step 1: 正在从 BioMart 抓取基础注释...\n")
mart <- useMart("ensembl", dataset = "mmusculus_gene_ensembl")

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

# 2. 格式化 GO (处理冲突：显式使用 dplyr 的函数)
cat("Step 2: 正在处理 GO 描述...\n")
biomart_formatted <- raw_biomart %>%
  dplyr::mutate(GO_fmt = ifelse(go_id != "", paste0(go_id, "(", name_1006, ")"), "")) %>%
  dplyr::group_by(ensembl_gene_id) %>%
  dplyr::summarize(
    gene_symbol = first(external_gene_name),
    gene_type = first(gene_biotype),
    Description = first(description),
    GO = paste(unique(GO_fmt[GO_fmt != ""]), collapse = "; "),
    UniProt = paste(unique(uniprotswissprot[uniprotswissprot != ""]), collapse = "; ")
  )

# 3. 补全 KEGG 和 EC (关键：显式使用 AnnotationDbi::select)
cat("Step 3: 正在从 org.Mm.eg.db 补全 KEGG 和 EC...\n")
ids <- biomart_formatted$ensembl_gene_id

# 显式指定包名防止冲突
extra_anno <- AnnotationDbi::select(org.Mm.eg.db, 
                                    keys = ids, 
                                    columns = c("PATH", "ENZYME"), 
                                    keytype = "ENSEMBL")

# 4. 格式化额外注释
cat("Step 4: 正在合并最终数据...\n")
extra_formatted <- extra_anno %>%
  dplyr::group_by(ENSEMBL) %>%
  dplyr::summarize(
    KEGG_ID = paste(unique(PATH[!is.na(PATH)]), collapse = "; "),
    EC = paste(unique(ENZYME[!is.na(ENZYME)]), collapse = "; ")
  )

# 合并
final_table <- biomart_formatted %>%
  dplyr::left_join(extra_formatted, by = c("ensembl_gene_id" = "ENSEMBL")) %>%
  dplyr::mutate(No = row_number()) %>%
  dplyr::select(No, gene_id = ensembl_gene_id, gene_symbol, gene_type, Description, GO, UniProt, KEGG_ID, EC)

# 5. 保存
write.table(final_table, "Mouse_Annotation.tsv", sep="\t", row.names = FALSE, quote = FALSE)

cat("🎉 任务完成！已生成符合格式要求的全基因组字典。\n")

# 4. 合并所有数据
cat("Step 4: 正在合并最终大表...\n")
final_table <- biomart_formatted %>%
  left_join(extra_formatted, by = c("ensembl_gene_id" = "ENSEMBL")) %>%
  mutate(No = row_number()) %>%
  select(No, gene_id = ensembl_gene_id, gene_symbol, gene_type, Description, GO, UniProt, KEGG_ID, EC)

head(final_table)
dim(final_table)
# 5. 保存结果
write.table(final_table, "Mouse_Full_Annotation.txt", sep="\t", row.names = FALSE, quote = FALSE)

cat("🎉 任务完成！生成的表格包含所有 6-8 万个小鼠基因的完整功能注释。\n")