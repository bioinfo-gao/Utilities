---
name: rnaseq
description: "Use when 用户要为一个项目搭建 bulk RNA-seq 分析:nf-core/rnaseq → DESeq2 差异表达 → GO/KEGG ORA + GSEA 富集分析"
disable-model-invocation: true
---

# /rnaseq — Bulk RNA-seq Analysis Setup Skill

为当前项目完整搭建 Bulk RNA-seq 分析代码，包括：
nf-core/rnaseq pipeline → DESeq2 差异表达 → 富集分析（GO/KEGG ORA + GSEA）→ 自定义 marker panel（可选，仅当客户明确要求特定 pathway/marker 时才加）

---

## 第一步：信息收集

读取用户提供的样品 CSV 文件，并确认以下参数：

| 参数 | 确认方式 |
|:---|:---|
| 项目根目录 | 从当前工作目录推断，或请用户确认 |
| 样品 CSV 路径 | 用户提供，或在项目根目录查找 |
| FASTQ 数据目录 | 读取 CSV 后确认实际路径 |
| 物种 | 从 CSV Species 列读取（Mouse / Human） |
| 分组结构 | 从 CSV Group 列自动解析 |
| 对照组 | 询问用户（哪个 Group 是 control） |
| 差异对比 | 询问用户（如 G1 vs G4, G2 vs G4） |
| 是否做富集分析 | 询问（GO/KEGG ORA + GSEA，默认 Yes；这是标准流程的一部分，不要在报告里特别注明"已与用户确认"） |
| 是否需要自定义 pathway/marker panel（如干细胞/分化/特定信号通路）| **默认不做**。只有客户明确点名某个生物学主题时才生成 `5b_run_custom_pathway.R`（见脚本 5b 章节）；不要把它当成每个项目的通用勾选项，也不要在分析计划/报告里写"未做 XX 分析"——默认不做就是默认不做，无需解释 |

---

## 第二步：参考基因组路径（预设）

### Mouse — GRCm39 / GENCODE M35
```
FASTA:      /Work_bio/references/Mus_musculus/GRCm39/mouse_gencode_M35/GRCm39.primary_assembly.genome.fa
GTF:        /Work_bio/references/Mus_musculus/GRCm39/mouse_gencode_M35/gencode.vM35.annotation.gtf
STAR_INDEX: /Work_bio/references/Mus_musculus/GRCm39/mouse_gencode_M35/star_index
KEGG_ORG:   mmu
ORGDB:      org.Mm.eg.db
```

**Mouse 必须加的 STAR 参数（写入 run_nextflow() 函数，放在 --gencode 前）：**
```bash
--extra_star_align_args '--twopassMode None --outFilterMultimapNmax 3' \
```
理由：nf-core 默认硬编码 twopassMode Basic + N=20；鼠基因组 multi-mapped reads ~14%（比人高 4–5×），twopass pass2 每 read CPU 开销是 pass1 的 5.4×，导致大样本（>35M reads）每个样本耗时 10–19h。1-pass + N=3 实测 7.6× 加速（62 min vs ~10h，41M reads 样本）。N=3 对蛋白编码 DE 结果影响可忽略（Salmon EM 正确处理 2–3 候选位置）。详见 `/home/gao/.claude/references/mouse_rnaseq_star_optimization.md`。

### Human — GRCh38 / GENCODE v45
```
FASTA:      /Work_bio/references/Homo_sapiens/GRCh38/human_gencode_v45/GRCh38.primary_assembly.genome.fa
GTF:        /Work_bio/references/Homo_sapiens/GRCh38/human_gencode_v45/gencode.v45.annotation.gtf
STAR_INDEX: /Work_bio/references/Homo_sapiens/GRCh38/human_gencode_v45/star_index
KEGG_ORG:   hsa
ORGDB:      org.Hs.eg.db
```

### Gene Annotation Files（人鼠通用，自动选最新版）
```
Mouse: /Work_bio/references/Genes/mouse_Gene_annotation_*.xlsx  (auto-select latest by filename)
Human: /Work_bio/references/Genes/human_Gene_annotation_*.xlsx  (auto-select latest by filename)
```
构建脚本：`/home/gao/projects_2026H1/Genes/build_mouse_Gene_annotation.R` / `build_human_Gene_annotation.R`
（offline 方式：RTF GTF parse + org.*Eg.db 分列查询 + KEGGREST；**不用 biomaRt**，避免 XML API 超时）

---

## 第三步：创建项目目录结构

```
{PROJECT_DIR}/
├── {csv_file}                  ← 已存在
├── scripts/
│   ├── 1_produce_nf-core_Samplesheet.py
│   ├── 2_nextflow.sh
│   ├── 3_Optional_work_monitor.sh
│   ├── 4A_install_library.sh
│   ├── 4_run_DE_PCA.R
│   ├── 5_run_enrichment.R      ← 如需富集分析
│   ├── 5b_run_custom_pathway.R ← 仅当客户指定特定 pathway/marker panel 时才生成（默认不生成）
│   ├── 6_generate_research_report.R
│   └── local_optimized.config
├── output_results/             ← nf-core 输出
└── Data_Analysis_YYYYMMDD/     ← 带日期，4_run_DE_PCA.R 运行时自动创建
    ├── mouse/human_Gene_annotation_YYYYMMDD.xlsx  ← 自动拷贝最新版
    ├── QC/
    │   └── multiqc/            ← 仅 multiqc（不含 fastqc/pipeline_info，客户不需要）
    ├── Reads/                   ← **表达矩阵本身，客户唯一能据以自行重分析的东西**
    │   ├── All_sample_gene_counts.tsv  ← 拷自 output_results/star_salmon/salmon.merged.gene_counts.tsv
    │   ├── All_sample_gene_tpm.tsv     ← 拷自 output_results/star_salmon/salmon.merged.gene_tpm.tsv
    │   └── library_metrics_per_sample.csv ← 逐样本 assigned reads / 检出基因数（可选，低起始量项目必给）
    ├── DE_PCA_Results/
    ├── Enrichment/                          ← 标准 GO/KEGG/GSEA，如需富集分析
    ├── Enrichment_Custom_Designed_Pathways/ ← 仅当客户指定 pathway 时才有此文件夹
    └── Bioinformatics_Analysis_Report_MMDD.md  ← script 6 输出
```

---

## 第四步：生成各脚本（按模板）

### 脚本 1 — `1_produce_nf-core_Samplesheet.py`

**命名规则（根据实际 FASTQ 目录自动适配）：**
- 读取 CSV `Name in File` 列
- 查找 FASTQ 目录下匹配的子目录（先检测 `J_{name}`、`{name}` 等命名）
- 搜索 `*_1.fq.gz` / `*_R1*.fastq.gz` 等常见后缀
- strandedness 默认 `reverse`（NovaSeq 链特异性建库）
- 输出 `nf_core_samplesheet.csv`，运行后打印确认表

### 脚本 2 — `2_nextflow.sh`

**设计模式：self-relaunch + auto-resume（强制使用，不可简化）**

```bash
# 不在 tmux → 创建 session 并把自身投入，主 shell exit 0
if [ -z "$TMUX" ]; then
    tmux new-session -d -s rnaseq "bash '${SCRIPT}' 2>&1 | tee nextflow_run.log"
    exit 0
fi

# 在 tmux 内 → 执行 nextflow
run_nextflow() {
    nextflow run nf-core/rnaseq \
        -r 3.15.1 \
        -profile singularity \
        -c local_optimized.config \
        "$@" \                    # 此处注入 -resume
        --input ... \
        ...
}

# 第一次运行
if run_nextflow; then exit 0; fi

# 失败 → 自动 -resume
if run_nextflow -resume; then exit 0; fi

exit 1
```

**固定参数：**
- `-r 3.15.1`（锁定版本）
- `--gencode`（GENCODE 注释格式）
- `--aligner star_salmon`
- `--max_cpus 28 --max_memory 108.GB`
- **Mouse 额外加：** `--extra_star_align_args '--twopassMode None --outFilterMultimapNmax 3'`（见上方 Mouse 路径区块）

### 脚本 3 — `3_Optional_work_monitor.sh`

显示 tmux 日志末尾 + 输出目录结构，用于快速查看状态。

### 脚本 4A — `4A_install_library.sh`

安装 `DE_R45` 环境缺少的包。物种对应包：
- Mouse：`bioconductor-org.mm.eg.db`
- Human：`bioconductor-org.hs.eg.db`
- 通用：`bioconductor-clusterprofiler enrichplot r-msigdbr bioconductor-fgsea r-ggrepel r-patchwork`

### 脚本 4 — `4_run_DE_PCA.R`（始终生成）

**关键设计：**
- `setwd` 到 `scripts/` 目录
- `TODAY <- format(Sys.Date(), "%Y%m%d")`；输出目录：`DATA_DIR <- paste0("../Data_Analysis_", TODAY)`
- META_FILE 路径：`../` + CSV 文件名
- COUNT_FILE：`../output_results/star_salmon/salmon.merged.gene_counts.tsv`
- ⚠ **这张矩阵不是整数**——Salmon 的 estimated counts 经 tximport 汇总到基因层，
  典型值形如 `619.999`（proj27 实测 76,370 个单元格带小数）。两个后果，都要处理：
  1. **载入后必须 `round()`**，否则 `DESeqDataSetFromMatrix()` 直接报错
     （`some values in assay are not integers`）：
     ```r
     counts_mat <- raw %>% select(all_of(meta$sample_id)) %>% as.matrix() %>% round()
     ```
  2. **对外措辞不能写 "raw read counts"**——报告 §8、交付说明、给客户的邮件里一律写
     **"gene-level estimated counts (Salmon)"**。写成 "raw counts" 是把估计值说成了实测计数。
     TPM 矩阵不受此影响（本来就是连续量）。
- sample_id 映射：从 CSV `Name in File` 推导，与 nf-core samplesheet `sample` 列一致
- Group 因子水平：对照组排第一（DESeq2 参照）
- `lfcShrink(type = "ashr")`
- 显著阈值：`padj ≤ 0.05 & |log2FC| ≥ 0.263`（log2(1.2)=0.263，即 ≥1.2× fold change）
- 低表达过滤（user directive 2026-11-09 定稿；**一条规则，不按总样本数 N 分段，任何设计都适用**）：
  - **两层，分清楚**：
    1. **检验集合（每个对比单独定）**：只看本对比的两组样本——两组中 **≥ `min(n_g1, n_g2)` 个样本 estimated counts ≥10**
       （DESeq2 vignette 的 "smallest group size" 规则作用于被比较的两组）。
       **两组样本合计计数，不要求落在同一组**（3+3 时 A 组 2 个 + B 组 1 个 ≥10 也算达标）；阈值含等号（≥10）；
       "对比"只指客户指定的对比，不是所有组两两配对。
       **⛔ 不得改成"必须在同一组内达标"**（user directive 2026-11-09，用户经验：实验样本标错经常发生）：
       合计计数只依赖"样本属于这两组之一"，不依赖它被标在哪一组，所以两组之间互换标签不会改变哪些基因被检验；
       要求同组达标时，一个标错的样本就能让基因从检验里消失，零报错、事后也查不出。
       （跨对比的标错——样本被标进另一个对比的组——这条规则防不住，仍靠 PCA 最近邻等样本身份检查。）
    2. **拟合矩阵（进 DESeq2 的大矩阵）** = 所有对比检验集合的**并集**，全部样本都保留，一个 `~ Group` 模型估 size factor 与 dispersion；
       各对比从同一模型取结果。**不要为每个对比单独拿两组样本拟合**（n=3 时 dispersion 只靠 6 个样本，功效显著下降）；
       除非某些组的离散度明显不同（先看各组 dispersion/PCA 组内距离，若要拆模型须在计划里写明理由并经用户确认）。
  - 取结果：`results(..., independentFiltering = FALSE)` → 限定到该对比检验集合 → **在集合内重做 BH**（`p.adjust(..., "BH")`）。
  - **"不进入本对比检验"到底是什么意思**（写代码、写报告前必须读懂）：
    - 含义：**这个基因在这一个对比里不做差异检验**——不给 p / padj，不计入 DEG 数，不进该对比的 ORA 背景和 GSEA 排序；
      该对比的 `*_ALL_genes.csv` 里**没有这一行**。它**仍在**拟合矩阵、normalized counts、TPM、PCA 里，在别的对比里只要达标照常检验。
      所以一个基因可以"在 TNF 对比里检验、在 un 对比里不检验"。
    - 为什么不检验：本对比两组里达到 10 counts 的样本数不到最小组的人数，即**两组都没有一组稳定表达**。
      这时检验几乎没有功效，log2FC 由个位数 counts 决定、受收缩支配，偶尔显著也最不可靠；放进来只会增加 BH 的检验数、压低其余基因的功效。
    - **不检验 ≠ 没有差异，也 ≠ 不表达**。报告里写 "not tested (low expression in both groups of this comparison)"，标记用 `n.t.`，
      不得写成 "not changed / not differentially expressed"；若该基因是客户关心的 marker，给出两组的 normalized counts 让读者自己看。
    - 实例（P51，Crtc2-un vs control-un）：
      Ptgs2 两组 6 个样本 raw counts 为 0–5，只在 PGE2/TNF 组 ≥10 ⇒ un 对比不检验，TNF/PGE2 对比照常检验（−2.48*、−2.06*）。
      Cxcl10 为 control-un 8/15/8、Crtc2-un 3/2/2，6 个里只有 1 个 ≥10 ⇒ 按本条**不检验**；
      当时的 30% 分支让它进入检验并得到 −0.70（padj 0.014）。这是本条的代价：**贴近 10 counts 阈值的弱表达差异会被放弃**，
      换来的是不再报告由个位数 counts 决定的 DEG。
    - 一个基因只要在任一对比里达标就进拟合矩阵；在**所有**对比里都不达标的基因才从拟合矩阵中删除。
  - **N−2 规则与"全体 ≥30% 样本"规则均已废除，不要再用**：
    - N−2：门槛随 N 增长，只在部分组表达的基因必被删。2 组×3 时 N−2=4，只在一组表达的 on/off 基因（3 个样本）被删；
      P51（8 组×3）N−2=22/24 删光 Cxcl2/Cxcl10/Il6 等 TNF 靶基因，DEG 5,327 vs 正确的 5,905。
    - 全体 30%：只要最小组占 N 的比例 <30%（≥4 组平衡设计）就会删掉只在一组表达的基因；
      作为检验集合的 OR 分支时，又会把主要在**别的组**表达、本对比两组几乎为零的基因放进检验
      （P52 实测每个对比 100–318 个，其中 23–198 个在本对比 6 样本里 ≤1 个 ≥10），稀释 BH 且产出最脆弱的 DEG。
      实测它对大矩阵贡献 0 个基因（P52：30% 规则 11,813 个全部已在并集 12,327 内）。
  - 必须保存 machine-readable 过滤审计：逐基因 × 逐对比的达标样本数、是否进入检验集合、是否进入拟合矩阵，**含被排除的基因**；log 打印前后数量。
  - 决策记录：2026-11-08 用户裁定弃用 N−2（「样品数量巨大，不能用 n-2 规则，这相当不合理」，P51）；
    2026-11-09 比较 P51/P52 后用户确认本条（去掉 30% 分支、用 min 组大小、不分 N）。
    依据：DESeq2 vignette "Pre-filtering"（smallest group size）；M. Love, support.bioconductor.org/p/109669（per-contrast 显式过滤 + `independentFiltering=FALSE`）。
    范例实现：`projects_2026Q4/51_Lijian_Wu_RNAseq/scripts/4_run_DE_PCA.R` Step B（注意它仍含 30% 分支，是旧口径；新项目按本条去掉）。
    对 P51/P52（3+3 平衡、N=24）：本条与当时规则的拟合矩阵相同、检验集合每对比少 100–318 个基因；P51/P52 是否按本条重出结果**由用户决定，未经决定不动**。


**PCA 数值汇总（凡是生成了 PCA 图，就必须同步保存这些数据供脚本6写解读，不能只在报告里放一张图不加文字说明）：**
```r
pca_data   <- plotPCA(vsd, intgroup = "Group", returnData = TRUE)
percentVar <- round(100 * attr(pca_data, "percentVar"))

# 组内 vs 组间平均欧氏距离 (在 PC1-PC2 平面上)，量化分离程度，避免"目测"式解读
dist_mat <- as.matrix(dist(pca_data[, c("PC1","PC2")]))
same_group <- outer(pca_data$Group, pca_data$Group, "==")
diag(same_group) <- FALSE
within_dist  <- mean(dist_mat[same_group])
between_dist <- mean(dist_mat[!same_group & upper.tri(dist_mat) | (!same_group & lower.tri(dist_mat))])
separation_ratio <- between_dist / within_dist

saveRDS(list(percentVar = percentVar, within_dist = within_dist,
             between_dist = between_dist, separation_ratio = separation_ratio),
        file.path(RDS_DIR, "pca_summary.rds"))  # 如有多个独立模型 (如跨批次场景)，每个模型各存一份，命名区分
```
`separation_ratio` 明显 >1（例如 >2）说明组间分离好于组内变异（重复样本聚类紧密、处理组彼此分开）；接近或小于1说明组间界限不清晰，值得在报告里如实指出而不是含糊带过。

**Section 2.5（必须包含）— 拷贝 Annotation + QC：**
```r
DATA_ANALYSIS_DIR <- DATA_DIR  # 与 OUT_DIR 同根

# 1. 自动拷贝最新 annotation xlsx 到 Data_Analysis 顶层
annot_files <- sort(list.files("/Work_bio/references/Genes",
  pattern = "^(mouse|human)_Gene_annotation_.*\\.xlsx$", full.names=TRUE), decreasing=TRUE)
if (length(annot_files) > 0) file.copy(annot_files[1], file.path(DATA_ANALYSIS_DIR, basename(annot_files[1])), overwrite=TRUE)

# 2. 仅拷贝 multiqc（不含 fastqc/pipeline_info，客户不需要）
QC_DEST <- file.path(DATA_ANALYSIS_DIR, "QC")
dir.create(QC_DEST, showWarnings=FALSE, recursive=TRUE)
if (dir.exists("../output_results/multiqc"))
  file.copy("../output_results/multiqc", QC_DEST, recursive=TRUE, overwrite=TRUE)
```
- **Step 0 — X/Y PAR 基因合并（仅人，GENCODE v44 起；在 Step A 之前，默认必做）**（2026-10-01 proj40 发现）：
  - **现象**：GENCODE v45 给 chrY 上的 pseudoautosomal（PAR）拷贝**独立的 gene_id**（不再是 `_PAR_Y` 后缀，
    v45 GTF 里 `_PAR_Y` 为 0 个）。X/Y 两份序列相同，Salmon 在两者间分配 reads 是任意的 ⇒
    **同一个基因以两行出现，常常一升一降**。proj40 实测：ASMTL 同时 +2.06 / −2.31，VAMP7、IL3RA、IL9R
    排在 DOWN 前列；合并后 18 个 PAR protein_coding 基因**全部**低于阈值，候选 125 → 112。
    **男性样本才明显**（女性没有 chrY reads）；有重复时 Y 行带进 DESeq2，同样污染 dispersion 与富集。
  - **规模**：36 对（含 18 个 protein_coding：IL9R DHRSX ASMT ASMTL CSF2RA VAMP7 P2RY8 SHOX CD99 ZBED1 PLCXD1
    PPP2R3B GTPBP6 SLC25A6 IL3RA WASH6P AKAP17A CRLF2）。小鼠 M35 无 X/Y 重复的 protein_coding 基因 ⇒ 鼠不需要。
  - **做法**：按 GRCh38 PAR 坐标取 chrY 基因（PAR1 chrY:10,001–2,781,479；PAR2 chrY:56,887,903–57,217,415），
    与 **chrX 上唯一**的同名基因配对，Y 的 counts 加到 X 行、删 Y 行。**不要只按基因名配对** ——
    `Y_RNA`、snRNA、`DDX11L16`（别处还有第三个拷贝）会让配对错乱。交付的原始 counts/TPM 矩阵**不动**。
  - **断言**：文库总 counts 合并前后不变；Y 行全部移除；X 目标行唯一；18 个 protein_coding PAR 基因都在配对里。
    范例 `40_NahYoung_Shin_SRSF2_RNAseq_NO_Repeat/scripts/4_run_descriptive_FC.R` 的 `# ---- 2-PAR.` 节。
  - **交付前必检**：全基因表里 18 个 PAR 基因名**每个只有 1 行**（范例 `8_pre_delivery_audit.R`）。
  - `filter_stats.rds` 记 `n_original`（合并前）/ `n_par_pairs` / `n_after_par`，报告 §5 单列一行。
  - **2026-10-01 之前交付的人类项目没有这一步；用户决定旧项目不回改**（与核糖体排除项同一口径）。
- 物种基因过滤（**两步串联，均为默认必做**）：
  - **Step A — 核糖体过滤 `&` 蛋白编码过滤（两个条件【相与】，不是二选一）**：

    ```r
    # 两条都必须成立 —— 【& 不能退化成 if/else 分支】
    ribosomal_filter    <- !grepl(RIBO_PATTERN, gene_name, ignore.case = TRUE)
    protein_coding_filter <- gene_type == "protein_coding"   # 无 xlsx 时用 regex 近似
    step_a_filter <- ribosomal_filter & protein_coding_filter
    ```

    - Human：`protein_coding_filter` 用 `human_Gene_annotation_*.xlsx` 的 biotype 列；
      **`ribosomal_filter` 照样要做** —— RPS/RPL/MRPL/MRPS **本身就是 protein_coding**，
      biotype 过滤按定义留下它们，`MT-` 那 13 个同理。
    - Mouse：两条都用 regex（见下方完整 regex 代码块）。
    - **⛔ 0831 事故（proj12 + proj20，客户投诉）**：本条曾被写成
      「有 xlsx 走 biotype；无 xlsx 则 fallback regex」—— 把**相与的两个条件**改成了
      **互斥的两条分支**，核糖体过滤落进了永不执行的 fallback。两批交付各带
      177 个 RPS/RPL/MRP + 13 个 MT- 基因。**遮蔽点：变量名 `regex_filter` 在走
      biotype 分支时装的是 biotype 结果，命名把差异抹平了；且 63,187 → 20,049
      这个数字看着"过滤生效了"，被拿去佐证了一件没做的事。**
    - **⇒ 交付前必检**：DEG 表里核糖体命中**必须为 0**，排除项照样要扣掉：
      `grep -iE '^(RPS|RPL|MRP|MT-)' | grep -viE '^(RPS6K|RPS19BP1$|RPS23RG1$)' | wc -l` = 0。
      这是唯一能证伪的检查 —— 基因数下降多少都不能替代它。
    - **⛔ 前缀正则会误伤非核糖体基因，必须带排除项（2026-10-01 proj40 发现）**：
      `^RPS` 同时命中 **RPS6K 激酶家族 10 个**（RPS6KA1–6、RPS6KB1/2、RPS6KC1、RPS6KL1，
      mTOR/MAPK 通路信号激酶）和 **RPS19BP1**（AROS）；小鼠另有 **Rps23rg1**（retrogene，编码膜蛋白）。
      它们**不是核糖体蛋白，必须保留**。实测 GENCODE v45：193 命中 = 182 真核糖体/MT + 11 误伤；
      M35 小鼠：183 命中，误伤同样 11 个 + Rps23rg1。人鼠通用写法：
      ```r
      RIBO_PATTERN     <- "^RPL|^RPS|^MRPL|^MRPS|^RPLP|^RPSA|^MT-"   # ignore.case = TRUE 覆盖鼠的大小写
      NOT_RIBO_PATTERN <- "^RPS6K|^RPS19BP1$|^RPS23RG1$"
      is_ribo <- function(x) grepl(RIBO_PATTERN, x, ignore.case = TRUE) &
                             !grepl(NOT_RIBO_PATTERN, x, ignore.case = TRUE)
      ribosomal_filter <- !is_ribo(gene_name)
      ```
      并加硬断言：look-alike 全部留在 `step_a_filter` 里（范例
      `40_NahYoung_Shin_SRSF2_RNAseq_NO_Repeat/scripts/4_run_descriptive_FC.R` 的 Step A）。
      **2026-10-01 之前交付的项目都按旧正则删掉了这些基因；用户决定旧项目不回改。**
  - **Step B — 低表达过滤**（后做；规则见上文「低表达过滤」条）：
    ```r
    MIN_CNT <- 10L
    grp_of  <- as.character(meta$Group[match(colnames(counts_pc), meta$sample_id)])
    stopifnot(!anyNA(grp_of))
    # CONTRASTS: named list, each = c(numerator_group, baseline_group)
    eligible <- sapply(CONTRASTS, function(cc) {
      n_min <- min(sum(grp_of == cc[1]), sum(grp_of == cc[2]))       # smallest group size of this pair
      stopifnot(n_min >= 2)
      rowSums(counts_pc[, grp_of %in% cc, drop = FALSE] >= MIN_CNT) >= n_min
    })                                                               # genes x contrasts
    keep <- rowSums(eligible) > 0                                    # fit matrix = union
    counts_filt <- counts_pc[keep, , drop = FALSE]
    eligible    <- eligible[keep, , drop = FALSE]
    # ... DESeq2(~ Group) on counts_filt with ALL samples; per contrast:
    # res <- results(dds, contrast = c("Group", num, den), independentFiltering = FALSE)
    # stopifnot(identical(rownames(res), rownames(eligible)))
    # res <- res[eligible[, cname], ]; res$padj <- p.adjust(res$pvalue, "BH")
    ```
  - 两步过滤后输出行数到 log，便于 QC 核查
- 最后 `saveRDS(res_list / vsd / meta / counts_raw)` 供脚本 5 使用；**同时必须保存 `filter_stats.rds`** 供脚本 6 报告用。
  **这些 rds 一律存到 `RDS_DIR <- "rds_cache"`（`scripts/` 下的子目录），绝不能存进 `OUT_DIR`/`DATA_DIR`
  （即 `Data_Analysis_YYYYMMDD/` 内）——那个文件夹会整体分享给客户，中间传递对象不是交付物**：
  ```r
  RDS_DIR <- "rds_cache"
  dir.create(RDS_DIR, showWarnings = FALSE, recursive = TRUE)

  saveRDS(list(
    n_original            = nrow(counts_mat),
    n_after_regex         = sum(regex_filter),
    n_final               = nrow(counts_mat_filtered),
    n_samples             = n_samples,
    low_count_min         = 10L,
    filter_rule           = ">=10 counts in >= min(group sizes) of the compared pair's samples; fit matrix = union over contrasts",
    n_tested_per_contrast = colSums(eligible)
  ), file.path(RDS_DIR, "filter_stats.rds"))
  ```
  脚本 5/6 对应从 `DE_DIR <- "rds_cache"` 读取，而不是 `file.path(DATA_DIR, "DE_PCA_Results")`。

**Mouse regex 过滤（标准代码，逐字复制）：**
```r
# 核糖体基因（鼠命名：首字母大写）
ribo_pattern <- "^Rpl|^Rps|^Mrpl|^Mrps|^Rplp|^Rpsa"
not_ribo_pattern <- "^Rps6k|^Rps19bp1$|^Rps23rg1$"   # 非核糖体 look-alike，保留（见 Step A 说明）
non_ribosomal <- !(grepl(ribo_pattern, gene_info$gene_name, ignore.case = TRUE) &
                   !grepl(not_ribo_pattern, gene_info$gene_name, ignore.case = TRUE))

# 非编码 / 低质量基因
noncoding_pattern <- paste0(
  "^mt-",                        # 线粒体基因（mt-Co1 等）
  "|^Snord|^Snora|^Rnu",         # snoRNA / snRNA
  "|^Malat1|^Neat1|^Xist",       # 高表达 lncRNA（会主导 PCA 第一轴）
  "|^Mir[0-9]|^let-",            # miRNA（poly-A 建库捕获效率极低）
  "|^Linc|^Gm[0-9]",            # lincRNA / 未命名预测基因（无 Entrez ID，富集分析无用）
  "|pseudogene|antisense"        # 假基因 / 反义转录本
)
protein_coding_like <- !grepl(noncoding_pattern, gene_info$gene_name, ignore.case = TRUE)

regex_filter <- non_ribosomal & protein_coding_like
```

**过滤效果参考（GRCm39 / GENCODE M35，~57K 基因）：**
- Regex 后：~26,500（去除 ~53%，主要是预测基因和非编码）
- 低表达后：~14,000（进入 DESeq2 的最终基因数）

**为什么不能跳过 regex 过滤：**
- 核糖体基因高表达 → VST 后 PCA 第一轴被核糖体基因占据，掩盖真实生物学变异
- 大量非编码基因进入多重检验 → 真实 DEG 的 padj 更难显著
- `Gm` 预测基因无 Entrez ID → GO/KEGG 富集背景集污染，结果偏差

### 脚本 5 — `5_run_enrichment.R`（询问后生成）

**路径：动态查找最新 Data_Analysis_* 文件夹（标准模板）：**
```r
data_dirs <- sort(list.dirs("..", full.names=TRUE, recursive=FALSE), decreasing=TRUE)
data_dirs <- data_dirs[grepl("/Data_Analysis_[0-9]{8}$", data_dirs)]
if (length(data_dirs) == 0) stop("No Data_Analysis_YYYYMMDD folder found.")
DATA_DIR <- data_dirs[1]
DE_DIR  <- file.path(DATA_DIR, "DE_PCA_Results")
ENR_DIR <- file.path(DATA_DIR, "Enrichment")
```

每个对比产出（标准，始终生成）：
```
{comp_name}/
├── GO/    enrichGO — BP/MF/CC × UP/DOWN/ALL → CSV + dotplot
├── KEGG/  enrichKEGG — UP/DOWN/ALL → CSV + dotplot
└── GSEA/  gseGO(BP) + gseKEGG + MSigDB Hallmark → CSV + ridgeplot/dotplot
```

GSEA rank 统计量：`sign(log2FC) × (−log10(pvalue))`
  - **⚠ 强效应/多组设计改用 DESeq2 未收缩 Wald `stat`**（user directive 2026-11-08, P51）：−log10 p 尾部过重时（P51 有 871 个基因 |值|>50），GSEA 加权 ES 被少数极端基因主导，Crtc2-PGE2 vs control-PGE2 GO:BP 显著 0 条（min padj 0.063），改 Wald stat 后 479 条且 top 条目相同。判据：ORA 有数百条而 GSEA ≈0 ⇒ 先怀疑排序值。`lfcShrink` 前先存 `res$stat`（ashr 输出不带 stat）。

### 脚本 5b — `5b_run_custom_pathway.R`（**可选服务，仅当客户指定特定 pathway/marker panel 时才生成**）

**默认不生成、不运行、不在报告里提及。** 这不是标准流程的一部分——只有客户明确点名某个生物学主题
（例如"帮我看看这批样本的干细胞/分化/某个信号通路情况"）时才按需生成这个脚本，并将其中的 curated
marker panel 换成与客户需求匹配的基因集。参考实现：`/home/gao/projects_2026H2/6_jinlong_mouse/scripts/5b_run_custom_pathway.R`
（该文件里的 StemCell / CellDiff / Notch 三个 panel 是那一次客户的具体要求，**不要原样套用到新项目**，
只是作为写法模板）。

**前置条件：** 必须先跑完 `5_run_enrichment.R`（复用其 `KEGG_ALL.csv`，避免重复调用 enrichKEGG 的
KEGG API）。

**标准写法模板（对每个客户指定的 pathway/主题重复这个模式）：**
```r
# 1. Curated marker 基因表，按功能分类组织成命名 list（每个类别一组基因）
markers <- list(
  CategoryA = c("Gene1","Gene2", ...),
  CategoryB = c("Gene3","Gene4", ...)
)
all_markers <- unique(unlist(markers))

# 2. 从 res_list 提取这些基因的 DE 结果，join 上 Category 标签
marker_de <- df %>% filter(gene_name %in% all_markers) %>% ...
write_csv(marker_de, file.path(pathway_dir, "<Name>_Markers_DE_Results.csv"))

# 3. 按 Category facet 的 log2FC 条形图（注意 StemCell 条形图 bug，见下）
# 4. MSigDB ORA：选择合适的 collection 并用关键词过滤 gs_name，缩小到主题相关的基因集
#    （C8 = 细胞类型特征；C5/GO:BP = 生物过程关键词过滤；不加 category 限制 = 跨库关键词搜索特定通路名）
# 5. 如果该主题有已知 KEGG pathway ID，直接从 5_run_enrichment.R 已生成的 KEGG_ALL.csv 里筛选提取
#    （不要重新调用 enrichKEGG，避免重复的 KEGG API 请求）
```

**条形图 factor levels bug（必须用 unique，否则崩溃）：**
```r
# 同一基因跨多个 Category 时 factor levels 会重复 → 崩溃
mutate(gene_name = factor(gene_name, levels = unique(gene_name)))  # ✅
# 错误写法：levels = gene_name  ← 会报 "factor level duplicated"
```

**输出结构（有运行才有此文件夹）：**
```
Enrichment_Custom_Designed_Pathways/
├── {comp_name}/
│   └── {PathwayName}/
│       ├── {PathwayName}_Markers_DE_Results.csv
│       ├── {PathwayName}_Markers_log2FC.pdf       ← facet 条形图
│       └── MSigDB_{PathwayName}_ORA.csv + dotplot.pdf
└── {PathwayName}_AllComparisons_Summary.csv        ← 跨对比汇总 (合并所有 comp_name 的结果, 加 Comparison 列)
```

**报告收尾：** 只有真正运行了这一步，`6_generate_research_report.R` 才在 Key Findings / Results 里加上
对应小节；没运行就完全不提，不要写"未做 XX 分析"。

### 脚本 6 — `6_generate_research_report.R`（始终生成）

生成客户交付报告 `Bioinformatics_Analysis_Report_MMDD.md`，保存在 `Data_Analysis_YYYYMMDD/` 顶层。

**路径：与脚本 5 相同，动态查找最新 Data_Analysis_* 文件夹。**

**报告结构（强制；2026-08-18 起 §2 新增 Core Conclusions，其余顺延一位）：**
1. Objectives
2. **Core Conclusions** —— 第一重要的一节：逐组/逐对比「这结果意味着什么、下一步该做什么」，
   大白话不带推导（客户是非专业读者，读不完全文）。导语点名 §8.2 详版 + §8.3 限制 + §8.4 后续实验。
   **§2 与 §8.2 一简一详、两者都必须在**；改章节号后要跑引用可解析性检查（见 CLAUDE.md）。
3. Key Findings
   - DEG 汇总表（加粗 Total）+ 显著性标准：`padj ≤ 0.05 AND |log2FC| ≥ 0.263; log2(1.2)=0.263, ≥1.2-fold`
   - 每个对比的 Top GO(BP) / Top KEGG / GSEA KEGG / GSEA Hallmark 显著数（若该项目确实做了自定义 marker panel，才追加对应显著数，不做则完全不提）
4. Sample Information（分组表）
5. Analysis Rationale（不含 Aligner 行；Gene filtering 拆成两行，含实际数字）：
   - `Regex gene filter`：`57,132 → 26,572 genes retained (removed 30,560 noise genes)`（数字来自 `filter_stats.rds`）
   - `Low-expression filter`：`26,572 → 14,090 robustly expressed genes input to DESeq2`
6. Methods（工具版本参数表）
7. Results（**7.1 PCA Overview — 强制，只要有 PCA 图就必须写**；7.2 DEG 表；7.3 GO/KEGG/GSEA 汇总；若做了自定义 marker panel 才加 7.4 明细）
8. **Conclusions, Limitations and Next Steps**（8.1 每组解读 / **8.2 Practical reading = §2 详版** / 8.3 Limitations / 8.4 Suggested confirmation）
9. Deliverable Files（文件清单表）

**PCA Overview 小节写法（用脚本4存的 `pca_summary.rds`，禁止只放图不写解读）：**
```r
pca <- readRDS(file.path(RDS_DIR, "pca_summary.rds"))
sprintf("PC1 explains %d%% of variance, PC2 explains %d%%.", pca$percentVar[1], pca$percentVar[2])
sprintf("Average within-group distance: %.2f; average between-group distance: %.2f (ratio %.2fx).",
        pca$within_dist, pca$between_dist, pca$separation_ratio)
# separation_ratio 明显 >1 (如 >2) → "replicates cluster tightly within each group, and groups are
#   clearly separated" ；接近/小于 1 → 如实写 "groups show substantial overlap in PCA space", 不要回避
```
如果一个项目有多个独立 DESeq2 模型（如跨批次场景，各自一个 PCA），每个模型的 PCA 都要单独总结一段，不能只写其中一个。

签名：`*Zhen Gao, PhD, Principal Bioinformatics Scientist, Athenomics*`

**运行：**
```bash
/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript scripts/6_generate_research_report.R
```

### `local_optimized.config`

```
executor { cpus = 28; memory = '108 GB' }
STAR_ALIGN:  cpus=14, memory=35GB, maxForks=2
SALMON_QUANT: cpus=7, memory=15GB, maxForks=4
SORTMERNA:   cpus=7, memory=10GB, maxForks=4
process_medium: cpus=4, memory=8GB, maxForks=7
process_low:    cpus=2, memory=4GB, maxForks=14
```

---

## 第五步：验证 samplesheet

生成脚本后立即运行：
```bash
cd {PROJECT_DIR}/scripts
conda run -n regular_bioinfo python 1_produce_nf-core_Samplesheet.py
```
确认所有样本均找到（12/12 样式输出），路径无误后告知用户。

---

## 第六步：生成 analysis_plan_MMDD.md

在项目根目录写入分析计划文档，包含：
- 样品分组表
- 对比方案
- 脚本说明
- 运行命令（按顺序）
- 关键参数及依据
- 计算资源分配表
- 已知局限说明

---

## 运行顺序（告知用户）

```bash
RSCRIPT=/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript

# 1. 生成 samplesheet（已自动验证）
conda run -n regular_bioinfo python scripts/1_produce_nf-core_Samplesheet.py

# 2. 启动 pipeline（自动进入 tmux，失败自动 resume）
bash scripts/2_nextflow.sh

# 3. Pipeline 完成后：DE 分析（创建 Data_Analysis_YYYYMMDD/）
$RSCRIPT scripts/4_run_DE_PCA.R > scripts/de_pca.log 2>&1

# 4. 富集分析（自动找最新 Data_Analysis_* 文件夹）
$RSCRIPT scripts/5_run_enrichment.R > scripts/enrichment.log 2>&1

# 4b. [可选，仅当客户指定了特定 pathway/marker panel 时才有这一步]
$RSCRIPT scripts/5b_run_custom_pathway.R > scripts/custom_pathway.log 2>&1

# 5. 生成客户报告（Bioinformatics_Analysis_Report_MMDD.md）
$RSCRIPT scripts/6_generate_research_report.R
```

**注意：** 步骤 3–5 用直接路径 `$RSCRIPT`，不用 `conda run`（conda run 有挂起 bug）。日志用 `> log 2>&1` 而非 `| tee`（tee 会掩盖 Rscript 退出码）。

**第6步（强制，不可省略）：交付前自查（Pre-Delivery Self-Audit）。**
**"脚本跑完没报错" ≠ "结果是对的"。** 2026-07-06 的教训（11_Qiuchen_Li 的样品错标 + 热图标注反了，
两个问题都是客户自己看出来的，不是我主动发现的）说明：只靠代码跑通、不主动核对生成的结果，是会
把明显能看出来的错误直接交付给客户的。在把任何项目标记为"完成"、报告给用户之前，必须实际打开/
核对以下内容，而不是假设它们是对的：
- **打开 PCA.pdf（或至少看 pca_data 的坐标数值）**：每个样品是否和自己组内的重复样本聚在一起？
  有没有哪个样品的坐标明显更接近另一个组的其他重复样本？——如果有，这是错标的强烈信号，必须在
  交付前查清楚，不能当作"正常生物学变异"忽略过去（真实案例：11_Qiuchen_Li 的 A5BKO_2）。
  **发现这类异常后，不能只是默默剔除样品再加一句脚注——必须在报告的 Conclusions 里明确给出独立
  判断**（例如"该样品高度可能是错标或实验操作问题，建议客户核查该样品的采样/标注/处理记录"），
  主动指出这是客户样品/实验环节的问题，而不是被动等客户自己发现、或只在 Sample Information 里
  轻描淡写一笔带过。这体现的是分析师应有的独立判断能力，不是简单执行数据处理流程。
- **核对至少一张热图/带 Group 标注的图**：图例颜色和底部/侧边的样品名是否真的对应（不能只看"图
  生成了"就默认标注是对的——真实案例：11_Qiuchen_Li 3张热图里2张 Group 和样品名完全反了）。
- **DEG 数量是否在合理范围**：某个对比的显著基因数量如果和其他类似对比差异极大（比如其他对比几
  千个，这个只有十几个），要停下来查原因，而不是直接写进报告——这类异常往往就是数据问题的信号
  （真实案例：A5BKO_vs_NT 因为样品错标，DEG 数从正常应有的3000+ 变成了异常的18个，这本该是一个
  早该被发现的警示信号）。
- **整组身份核对（user directive 2026-11-09）**：上面的 PCA 检查只抓得到**单个样本**错标（它会落进别的组）。
  **整组标错 PCA 抓不到**——两组标签整体互换后，各组照样自成一簇、组内一致，PCA 无法判断哪个标签才对；
  过滤规则（两组合计计数）也帮不上。只能拿**预期必然变化的基因**当已知答案逐组核对：
  - 每个实验因素至少选 1 个预期基因，开跑前写进计划：**基因型/细胞系** = 被修饰的基因本身（KO/KD 后该基因降低；
    过表达后升高；knock-in 看构建体特征序列或标签）；**每种处理** 1–2 个经典应答基因（如 TNF → Nfkbia/Tnfaip3/Cxcl1；
    cAMP 通路激动剂如 PGE2/forskolin → Nr4a1/Nr4a2/Pde4b/Crem；IFN → Isg15/Ifit1；LPS → Il1b/Tnf）；
    **未处理对照** = 这些应答基因都处在基线。
  - 用组均值 normalized counts 逐组核对方向，并写成 machine-readable 表
    （`rds_cache/group_identity_check.csv`：因素、组、预期基因、预期方向、实测组均值/log2 比、PASS/FAIL/无法核对）。
  - **方向相反或该变的没变 ⇒ 疑似整组错标**：相关对比不进结论，先向用户报告，由用户决定是否请客户核查标签/处理记录；
    不得自行互换标签"修正"。
  - 客户没说明修饰方式、处理没有公认靶基因、或被修饰基因本身不表达时，写"**无法核对**"并说明原因，
    **不得写成"已核对"**；报告里相应注明样本身份只经过单样本层面（PCA 最近邻）的检查。
  - 实例（P51）：Crtc2 在 4 种条件下都是 Crtc2 line 更低（0.53–0.67×）；TNF 组占据整条 PC1 且 Nfkbia/Tnfaip3 上调；
    PGE2 在 control 中上调 Pde4d +2.17、Nr4a2 +0.85；control-un 处在基线 ⇒ 全部 PASS。
只有完成这一步自查、确认没有发现类似异常，才可以说"分析完成"、生成报告并交付。这一步不是可选的
质量检查，是每个项目收尾时的强制步骤。

**第6步之二（强制）：交付完整性检查 —— 清单驱动，与上面的正确性检查是两回事。**
上面那一整段查的全是**"在的东西对不对"**（样本有没有错标、图例有没有反、DEG 数合不合理）。
它在原理上抓不到**"该有的东西不在"**：报告 §8 表和交付目录**一起漏掉同一件**产物时，
"报告提到的路径都存在"这条检查恒为 PASS。事故：proj28（0810 交付）与 proj27（0809 交付）
**都把 count 与 TPM 矩阵漏在了 output_results 里没进交付**，客户拿到的 `Reads/` 只有一个
QC 指标 CSV；两个项目的自审脚本各七八项检查全部通过，是用户审阅时自己发现的。
根因就在本文件 —— 上面的目录树里 `Reads/` 曾是一个**没写内容的空条目**。

所以交付前必须再跑一遍**与项目无关的固定清单**（不是从报告里抽路径，那是闭环）：

| 必给 | 路径 |
| :--- | :--- |
| 表达矩阵（counts） | `Reads/All_sample_gene_counts.tsv` —— 对外称 **estimated counts (Salmon)**，不是 raw counts（见脚本 4 的说明） |
| 表达矩阵（TPM） | `Reads/All_sample_gene_tpm.tsv` |
| QC | `QC/multiqc/` |
| 总览 PCA + 坐标 | `DE_PCA_Results/PCA_AllSamples_Overview.pdf` + `PCA_coordinates_overview.csv` |
| 每个对比 | `DE_PCA_Results/<comp>/` 全基因表 + 显著表 + volcano |
| 富集（如做） | `Enrichment/<comp>/{GO,KEGG,GSEA}/` |
| 基因注释 | `*_Gene_annotation_*.xlsx` |
| 报告 | `<ProjectName>_MMDD.md` |

清单里的每一项还必须**出现在报告 §8 的文件清单表里** —— 两侧都查，才能同时挡住
"目录里有但报告没说"和"报告说了但目录里没有"，以及本次这种"两边一起没有"。

---

## 注意事项（每次执行均需检查）

1. **Strandedness**：NovaSeq 标准建库 = `reverse`；如有疑问用 `auto` 让 nf-core 自检
2. **对照组排第一**：`factor(Group, levels = c("Control", "G1", "G2", ...))`
3. **STAR index**：使用已建好的 index，不要重建（耗时且无必要）
4. **线程总量不超过 56**：当前 config 已控制，勿手动加大
5. **DE_R45 vs regular_bioinfo**：Python/nextflow 用 regular_bioinfo；R 分析用 DE_R45
6. **tmux 保护**：所有超过 1 分钟的命令必须在 tmux 内运行
7. **Mouse STAR 速度**：默认 twopassMode Basic 对大样本（>35M reads）极慢（10–19h/样本）。务必加 `--extra_star_align_args '--twopassMode None --outFilterMultimapNmax 3'`，实测 7.6× 加速。参数不影响蛋白编码 DE 结果。详见 `/home/gao/.claude/references/mouse_rnaseq_star_optimization.md`
8. **Data_Analysis 文件夹带日期**：每次运行 `4_run_DE_PCA.R` 自动创建 `Data_Analysis_YYYYMMDD/`；脚本 5/6 自动查找最新同名文件夹，无需手动改路径
9. **客户 QC 只给 multiqc**：`fastqc/` 和 `pipeline_info/` 对非生信客户无意义，不拷贝
10. **Rscript 直接路径**：`/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript`；`conda run -n DE_R45 Rscript` 有挂起 bug，禁止使用
11. **跨批次 DESeq2 陷阱（关键，务必检查）**：若两个及以上分组分别来自不同测序批次/来源（如客户提供的旧计数矩阵 + 本次新测序）且没有任何重叠条件，**绝不能把它们放进同一个 `~Group` DESeq2 模型**——即使只想检验其中同批次的一对对比，合并模型的 dataset-wide mean-dispersion trend 拟合仍会被跨批次的巨大差异污染，对"同批次"的对比也会产生假阳性。已通过具体诊断案例验证（10_Yue_Liu 项目，2026-07-04：基因 FSCN1/ENSG00000075618 在同批次内几乎无差异，但合并 4-group 模型给出 padj=0.0017"显著"；同批次单独重新建模给出 padj=0.9996"无差异"）。**规则：每一对同批次对比必须独立建模**（各自 `DESeqDataSetFromMatrix` + `DESeq()`，不共享 dispersion 估计）；如需展示"全部时间点/全部批次"的整体视图（如 PCA 参考图），可以另外单独跑一个合并模型，但仅用于可视化参考，不产出富集分析、不用于任何结论。
12. **不可靠对比的文件夹组织**（当出现跨批次、confounded、或其他统计上不可信但仍需展示的对比时）：拆成两个客户交付顶层文件夹 `DE_PCA_Results_Reliable/` 和 `DE_PCA_Results_Unreliable_<原因>/`（如 `_CrossBatch`）；**只对 Reliable 对比跑 Enrichment**（对不可靠的假阳性基因列表做富集分析等于二次放大误导）；客户报告开头（Objectives 之前）必须用醒目的引用块 (blockquote) 提前警示哪些对比不可靠、为什么，不要等到 Methods 部分才说明；Conclusions 绝不能从 Unreliable 文件夹的数字得出生物学结论。
13. **客户报告绝不包含**：(a) 任何 `.rds`/`.RData` 等脚本间内部传递对象（见上方脚本 4 的 `rds_cache` 规则）；(b) 内部调试/排错叙事（例如"我们发现某基因是假阳性，诊断过程如下，修复方法是……"）——`Bioinformatics_Analysis_Report_MMDD.md` 只呈现修正后的方法学作为既定设计选择，调试过程的完整细节只写入分析师自用的 `analysis_plan_MMDD.md`，不进入客户报告。
14. **解读 MultiQC/FastQC QC 图（Inner Distance、Overrepresented Sequences、Adapter Content、Status Checks 等）**：不要凭记忆给通用教科书式回答，先去 `multiqc_report_data/*.txt`（或 `output_results/fastqc/raw/*_fastqc.zip` 里的原始 `fastqc_data.txt`）拉实际数值，用真实数字解释。方法论 + 已积累的具体案例（含 R1/R2 poly-G 不对称、raw vs trimmed 两次 FastQC 对比等）见
    `/home/gao/.claude/references/rnaseq_qc_interpretation.md`——这是一份持续维护的文档，每次遇到新的 QC 问题讨论清楚之后，都在这个文件里补一节（含真实数据示例），不要只回答完就丢掉。
15. **热图 (pheatmap) 的 Group 标注绝不能用逻辑子集筛选来构造（关键 bug，已实际发生过）**：
    ```r
    # 错误写法 —— 保留的是 meta 自身的行顺序，不是 smp_comp 的顺序，两者不一致时
    # Group 标注会和样品名完全错位（曾导致 11_Qiuchen_Li 项目 3 个热图里 2 个的
    # Group 图例和底部样品名完全对调，2026-07-06 由客户核查 PCA 图后发现）
    ann_df <- data.frame(Group = as.character(meta$Group[meta$sample_id %in% smp_comp]),
                         row.names = smp_comp)

    # 正确写法 —— match() 强制按 smp_comp 的顺序对齐
    ann_df <- data.frame(Group = as.character(meta$Group[match(smp_comp, meta$sample_id)]),
                         row.names = smp_comp)

    # 必须紧跟一个硬断言，任何不匹配立即报错终止，不能让标注错误的图静默生成：
    expected_group <- setNames(as.character(meta$Group), meta$sample_id)[smp_comp]
    stopifnot("Heatmap annotation Group mismatch!" = all(as.character(ann_df$Group) == unname(expected_group)))
    ```
    **这条规则不止适用于热图**：任何时候生成的结果（图、表）里同时包含"Group/分组标签"和"样品名"两类信息，在提交/交付前都必须有类似的程序化核查（不能只靠肉眼看着"应该对"），确保标签和它标注的样品是真实对应的——这是底线级别的正确性检查，不是可选项。
    **PCA 图也要养成习惯核查**：某个样品如果在 PCA 图上的坐标和另一个 Group 的其他重复样本几乎重合，而不是和自己组内的重复样本聚在一起，要主动怀疑是否为样品错标（见跨批次章节外的另一起真实案例：11_Qiuchen_Li 项目 A5BKO_2 与 NT 组重合，2026-07-06 确认为错标并剔除），而不是当作普通的生物学变异忽略过去。
