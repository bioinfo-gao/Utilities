TCGA 数据库


TCGA（The Cancer Genome Atlas，癌症基因组图谱） 是由美国国家癌症研究所（NCI）和国家人类基因组研究所（NHGRI）联合发起的标志性大型基因组学项目。该项目系统性地收集并分析了覆盖 33 种常见癌症类型、超过 11,000 名患者 的多组学数据，是目前癌症生物信息学研究中最核心、最权威的公共数据库。一、 TCGA 多组学数据类型与层级TCGA 数据的核心优势在于其多组学整合性（Multi-omics Integration），涵盖了从 DNA 到蛋白质以及临床表型的全方位数据。组学维度数据类型 (Data Type)常见技术平台/分析方法典型文件格式转录组学RNA-Seq (mRNA / lncRNA / miRNA)Illumina STAR-Counts, Salmon.tsv, .txt基因组学体细胞突变 (Somatic Mutation), CNVWES, WGS, SNP Array (MuTect2, VarScan2).MAF, .seg表观基因组学DNA 甲基化 (DNA Methylation)Illumina HumanMethylation 450k/EPIC.idat, .txt蛋白质组学RPPA (反相蛋白质阵列)RPPA 信号定量.tsv临床与病理存活时间、分期、用药、病理切片临床随访表、SVS 高清病理图像.xml, .json, .svs原始 Markdown 代码：Markdown| 组学维度 | 数据类型 (Data Type) | 常见技术平台/分析方法 | 典型文件格式 |
| :--- | :--- | :--- | :--- |
| **转录组学** | RNA-Seq (mRNA / lncRNA / miRNA) | Illumina STAR-Counts, Salmon | `.tsv`, `.txt` |
| **基因组学** | 体细胞突变 (Somatic Mutation), CNV | WES, WGS, SNP Array (MuTect2, VarScan2) | `.MAF`, `.seg` |
| **表观基因组学** | DNA 甲基化 (DNA Methylation) | Illumina HumanMethylation 450k/EPIC | `.idat`, `.txt` |
| **蛋白质组学** | RPPA (反相蛋白质阵列) | RPPA 信号定量 | `.tsv` |
| **临床与病理** | 存活时间、分期、用药、病理切片 | 临床随访表、SVS 高清病理图像 | `.xml`, `.json`, `.svs` |
二、 TCGA Barcode（样本标识码）结构TCGA 的核心数据标识符为 TCGA Barcode，包含了极其关键的样本属性信息（如肿瘤 vs 正常对照）：

$$
\underbrace{\text{TCGA}}_{\text{项目}} - \underbrace{\text{06}}_{\text{组织来源}} - \underbrace{\text{0125}}_{\text{患者ID}} - \underbrace{\text{01A}}_{\text{样本类型}} - \underbrace{\text{01D}}_{\text{核酸类型}} - \underbrace{\text{A45W}}_{\text{板号}} - \underbrace{\text{05}}_{\text{测序中心}}
$$

样本类型（Sample Type）关键代码：01 至 09：肿瘤组织（如 01A 代表 Primary Solid Tumor 实体瘤原发灶）。10 至 19：对照组织（如 11A 代表 Solid Normal Tissue 癌旁正常组织）。20 至 29：复发灶或细胞系样本。三、 数据获取与下载途径获取 TCGA 数据（目前托管于 NCI GDC Data Portal）主要有以下三种方式：1. R 语言工具获取：TCGAbiolinks (推荐)TCGAbiolinks 是目前针对 GDC 接口封装最完善的 R 包，支持精准筛选、下载并自动转换为 SummarizedExperiment 对象。Rlibrary(TCGAbiolinks)


# 1. 构建查询 (以肺腺癌 TCGA-LUAD 为例)

query <- GDCquery(
    project = "TCGA-LUAD",
    data.category = "Transcriptome Profiling",
    data.type = "Gene Expression Quantification",
    workflow.type = "STAR - Counts"
)

# 2. 下载数据

GDCdownload(query, method = "api", files.per.chunk = 10)

# 3. 载入并转换为表达矩阵与临床数据

se <- GDCprepare(query)
exp_matrix <- assay(se)
clinical_data <- colData(se)
2. Linux 官方命令行工具：gdc-client适合批量、大规模或断点续传下载大文件（如 BAM、WES 原始数据）。Bash# 1. 创建保活会话并激活环境
screen -S gdc_download
mamba activate R44

# 2. 通过 GDC 官方 Data Transfer Tool 凭 manifest 文件下载

gdc-client download -m gdc_manifest.txt -t gdc-user-token.txt

# 3. 剥离会话 (Ctrl+A -> D)

3. 三方二次加工数据库 (免去繁琐预处理)对于不需要原始读段、只需经过标准化（如 Log2(TPM+1)）矩阵的下游统计分析，可直接通过以下平台获取：UCSC Xena：提供统一归一化的多组学矩阵，非常适合做生存分析和跨癌种分析。cBioPortal：擅长体细胞突变、基因拷贝数变异（CNV）与临床生存曲线的可视化展示。cBioPortal / Firebrowse：适合直接下载预整理的标准化表格。四、 常见下游分析流派与工具套件在获得 TCGA 数据后，典型的生信分析链路涵盖以下方向：分析方向常用 R 包 / 工具关键产出/图形差异表达分析 (DEG)DESeq2, edgeR, limma火山图 (Volcano Plot)、热图 (Heatmap)突变图谱绘制maftools瀑布图 (OncoPrint)、突变负荷 (TMB)生存与预后分析survival, survminerKM 生存曲线、Cox 回归分析 (Forest Plot)免疫微环境浸润CIBERSORTx, TIMER, EPIC免疫细胞丰度矩阵、免疫评分通路与功能富集clusterProfiler, GSVAGSEA 夹心图、GO/KEGG 柱状图原始 Markdown 代码：Markdown| 分析方向 | 常用 R 包 / 工具 | 关键产出/图形 |
   | :--- | :--- | :--- |
   | **差异表达分析 (DEG)** | `DESeq2`, `edgeR`, `limma` | 火山图 (Volcano Plot)、热图 (Heatmap) |
   | **突变图谱绘制** | `maftools` | 瀑布图 (OncoPrint)、突变负荷 (TMB) |
   | **生存与预后分析** | `survival`, `survminer` | KM 生存曲线、Cox 回归分析 (Forest Plot) |
   | **免疫微环境浸润** | `CIBERSORTx`, `TIMER`, `EPIC` | 免疫细胞丰度矩阵、免疫评分 |
   | **通路与功能富集** | `clusterProfiler`, `GSVA` | GSEA 夹心图、GO/KEGG 柱状图 |
