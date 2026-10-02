# 无生物学重复（n = 1 per group）的 bulk RNA-seq：特殊处理

**创建**: 2026-10-02（源自 proj40 `40_NahYoung_Shin_SRSF2_RNAseq_NO_Repeat`，1 mutant vs 1 corrected）
**适用**: 每组只有 1 个样本的 bulk RNA-seq 比较。标准流程（nf-core/rnaseq → DESeq2 → GO/KEGG/GSEA，见 rnaseq skill）中
**哪些步骤必须换做法、为什么、换成什么、交付时怎么说**。
**软链接**: `40_NahYoung_Shin_SRSF2_RNAseq_NO_Repeat/docs/sLk_of_2_no_replicate_RNAseq_special_handling_in_Utilities_RNAseq.md`
→ 本文件。**修改只在本文件做**，不要改链接。

## 更新记录

- 2026-10-02 — 创建。

---

## 0. 一句话

**没有重复就估不出基因间的生物学变异（dispersion），因此任何 gene-level p 值都只是假设的 dispersion 的函数。**
⇒ 只做**描述性**比较（fold change + 排序），**不出 gene-level p 值**，结果叫 **fold-change candidates**，不叫 DEG。
其余所有改动都从这一条推出来。

## 1. 逐步对照：标准流程 vs 无重复

| 环节 | 标准做法（有重复） | 无重复时 | 理由 |
| :--- | :---: | :---: | :---: |
| 统计检验 | DESeq2 Wald test，`padj ≤ 0.05` | **不做** | 无法估 per-gene dispersion |
| 归一化 | DESeq2 size factors | 同（median-of-ratios 不需要重复） | — |
| log2FC | `lfcShrink(type = "ashr")` | **`vst(blind = TRUE)`（design `~1`）两样本之差** | ashr/apeglm 需要来自 dispersion 的 SE；VST 在低 count 端压缩差异，起到收缩作用 |
| 并列给 | — | unshrunk `log2((norm_A + 1) / (norm_B + 1))` | 供客户对照；**不用于阈值** |
| 阈值 | `padj` + `abs(log2FC)` | **只用 `abs(log2FC_VST)`**（客户默认 1.0 即 2 倍） | 客户表上的 adj-p 无法应用，报告里明说 |
| 低表达过滤 | `≥10 counts in (n − 2) samples` | **`≥10 in ≥ 1 sample`** | n = 2 时 `(n − 2) = 0`，原规则恒真、等于不过滤 |
| PCA | 必画 + 组内/组间距离 | **不画** | 2 个点时 PC1 恒为 100 %，零信息 |
| 替代总览 | — | VST 表达散点（x = baseline）+ Pearson r + MA 图 | 散点直接看出偏离对角线的基因 |
| 样本身份 | PCA 里重复聚在一起即旁证 | **必须单独做**（§3） | 没有重复可对照，标签对调不会在任何表达 QC 里露馅 |
| ORA | DEG 列表 UP/DOWN/ALL | candidates 列表 UP/DOWN/ALL | 方向拆分仍为主读数（proj19：ALL 欠功效） |
| GSEA rank | `sign(LFC) × −log10(p)` | **`log2FC_VST`** | 没有 p 值可组 |
| 交付目录 | `DE_PCA_Results/` | **`FoldChange_Results/`** | 名字不暗示做过检验或 PCA |

### 1.1 VST 差值与 unshrunk 的数量差距（proj40 实测）

同一阈值 `abs(log2FC) ≥ 1`：**VST 112 个 vs unshrunk 1,399 个**。多出来的几乎全是低 count 基因（例如 12 vs 0 counts
就能给出巨大的 unshrunk 倍数）。⇒ 下游一律用 VST 列；报告里两列都给，并解释为什么差这么多。

### 1.2 未采用但可考虑的替代（本机未验证）

| 方法 | 思路 | 未用原因 |
| :--- | :---: | :---: |
| edgeR 固定 BCV（如 0.1） | 人为指定 dispersion 后做检验 | p 值完全由假设的 BCV 决定；DE_R45 也没装 `edgeR`（装包需用户确认） |
| edgeR `predFC(prior.count = …)` / `cpm(log = TRUE, prior.count = …)` | 加伪计数收缩 log2FC | 与 VST 差值作用相同；同样缺 `edgeR` |
| GFOLD、NOISeq-sim 等专为无重复设计的工具 | 生成"可靠倍数"或模拟重复 | 未在本机安装与验证；需要时先查 software_pitfalls |

## 2. 实现要点（代码层）

```r
# n = 1 vs 1：design ~1，只为拿 size factors 和 VST
dds  <- DESeqDataSetFromMatrix(counts_filt, colData = cd, design = ~ 1)
dds  <- estimateSizeFactors(dds)
vsd  <- vst(dds, blind = TRUE)
norm <- counts(dds, normalized = TRUE); vmat <- assay(vsd)
log2FC_VST      <- vmat[, A] - vmat[, B]
log2FC_unshrunk <- log2((norm[, A] + 1) / (norm[, B] + 1))
```

- **方向断言**：从归一化矩阵独立重算至少一个基因的符号，确认是 A / B 而不是列顺序给的方向。
- **不要调用 `DESeq()`**：无重复时会报错或给出无意义的 dispersion；也不要为了"让它跑起来"去改 design。
- 范例：`40_NahYoung_Shin_SRSF2_RNAseq_NO_Repeat/scripts/4_run_descriptive_FC.R`。

## 3. 样本身份校验 —— 无重复时从「旁证」升格为「必做」

有重复时，错标的样本会在 PCA 上跑到别的组里（proj11 A5BKO_2）。**n = 1 时没有任何东西可对照**：
两份样本对调，所有倍数整体变号，QC 指标完全正常。所以要用**与表达无关**的证据：

| 检查 | 做法 | proj40 实测 |
| :--- | :---: | :---: |
| 已知设计位点的基因型 | 对设计里的突变 / 编辑位点做 `samtools mpileup`（MAPQ ≥ 20，BQ ≥ 20，去 duplicate），看 ±60 bp 内有无其他变异与 indel、双链是否均衡 | SRSF2 c.284（chr17:76,736,877）：**两系都是 P95L 杂合**（0.440 / 0.411），与"mutant vs corrected"的描述不符 ⇒ 报告开头警示 + 请客户核实 |
| 同一供体 | `bcftools mpileup/call` 取几条基因密集染色体（chr1/17/19），QUAL > 50 且两样本 DP ≥ 20 的 SNP 比一致率 | 3,424 个 SNP，一致率 99.27 %；不一致多为 het↔hom-alt（RNA 等位特异表达） |
| 性别 | XIST、RPS4Y1、DDX3Y、KDM5D、UTY、EIF1AY 的 TPM | 两系均为男性 |

- **坐标先核对**：用参考 FASTA 取出目标密码子，确认氨基酸（proj40：反向互补 `CCC` = Pro）；负链基因的碱基对应关系写进脚本注释。
- **措辞边界**：RNA 的 allele fraction 反映的是**表达的等位基因**；它分不清"均一的杂合群体"和"混合群体"。
  客户没说清校正对象时，**只陈述测到的事实，不写"校正失败"**，请客户告知校正位点并建议做 Sanger 测序。
- 范例：`scripts/4c_SRSF2_P95_genotype.py`、`scripts/4d_identity_snp_concordance.sh`。

## 4. 富集分析

- **ORA**：输入 = candidates（UP / DOWN / ALL），universe = 过滤后能映射到 Entrez 的基因。
- **GSEA（preranked，fgsea）**：在 n = 1 时能运行，因为它置换的是**基因**而不是样本。
  - **⚠ 显著条目会大幅膨胀**：gene permutation 不考虑同一基因集内基因之间的相关性。proj40：GO BP **1,520** 个、
    KEGG 83 个、Hallmark 25 个达到 adj-p < 0.05。**条目数不代表证据强度**，报告要明说。
  - p 值描述的是"这个基因集在这一条排序里的位置"，不代表在独立培养之间能否重复。
  - rank 里有约 5 % 的 ties（VST 差值在低表达端会相同），fgsea 会警告；记录在案，不处理。

## 5. 解读陷阱（n = 1 时尤其致命，因为无法用重复排除）

### 5.1 样本处理应激特征

- 即刻早期基因（FOS、FOSB、JUN、EGR1/2/3、NR4A1/2/3、IER2/3/5、ATF3、DUSP1、ZFP36、KLF2/4）和热休克基因
  （HSPA1A/B、HSPA6、DNAJB1、HSPH1、HSPB1）**几分钟内**就会对离体时间、温度、解离操作起反应。
- proj40：SRSF2 升高最多的 20 个基因里 **10 个**属于这一类，它们带动了 "response to heat"、MAPK 等富集条目。
- n = 1 时**无法区分**这是系间差异还是两份样本处理时间或温度不同 ⇒ 报告里明说不作系特异解读；
  代码里用固定基因列表动态统计并写进报告（`6_generate_research_report.R` 的 `IEG` 向量）。

### 5.2 与无重复无关、但在 n = 1 时更难被发现的问题

- **X/Y PAR 基因**（GENCODE v44+ 人类）：同一基因被拆成一升一降两行。已写进 rnaseq skill 的 Step 0，**无论有无重复都要做**。
  proj40 合并后候选 125 → 112。
- **readthrough 基因**（如 PDCD6-AHRR）：常出现 0 vs 几百 counts 的极端倍数，多半是定量歧义；看到时要谨慎。

## 6. 报告怎么写（客户交付物，英文）

| 必须 | 禁止 |
| :--- | :---: |
| 标题与 §1 写明 "one sample per line, no biological replicates; descriptive comparison" | `DEG(s)`、`differentially expressed`、基因层面的 `significant` |
| 称 **fold-change candidate genes**；counts 称 **gene-level estimated counts (Salmon)** | `raw read counts` |
| §5 说明为什么不做检验、为什么不画 PCA、为什么低表达过滤改了 | 只放图不解释 |
| §8.3 写明 n = 1 的局限（系间效应与培养 / 处理差异分不开） | 把 candidate 列表写成"已证实的差异" |
| §8.4 建议 **每组 ≥ 3 个生物学重复**（独立培养、同批测序）；可以建议加测深度 | 建议换测序平台 |
| 身份校验结果放进 §7（基因型表 + SNP 一致率 + 性别） | 发现身份异常却只在 Sample Information 里一笔带过 |

- 报告生成脚本里对禁用词做**反向断言**（出现即 `stop()`），范例 `6_generate_research_report.R` 末尾。

## 7. 交付前自审要额外加的检查

在 rnaseq skill 的标准自审之外（范例 `scripts/8_pre_delivery_audit.R`）：

1. 方向：从交付的归一化 counts **独立重算** top-50 的 unshrunk log2FC，必须与表中一致。
2. candidate 文件 = **恰好**是 `abs(log2FC_VST) ≥ 1` 的那些基因。
3. 报告里的 UP/DOWN 计数、基因型表每一行 = 交付文件里的数（跨步骤一致性）。
4. 核糖体 0 命中且 RPS6K 保留；PAR 基因每个只有 1 行。
5. 交付清单用 `FoldChange_Results/`、`Sample_Identity/` 替代 `DE_PCA_Results/` 和 PCA 文件 ——
   **清单必须按本项目改写**，不能沿用标准清单，否则会因为"缺 PCA"误报，或者漏检身份校验文件。

## 8. proj40 实测数字（供下次对照）

| 项 | 值 |
| :--- | :---: |
| 原始 read pairs | SRSF2 24,452,911；N-2.12 31,354,052 |
| adapter dimer 去除 | 45.95 % / 35.68 %（我方建库，与无重复无关，但拉低了有效深度） |
| 过滤 | 63,187 → PAR 63,151 → Step A 19,849 → Step B 14,453 |
| candidates（VST） | UP 49 / DOWN 63（unshrunk 同阈值 1,399） |
| VST Pearson r | 0.972 |
| TIN 中位数 | 78.5 / 79.1 |
| 全部参数与复核命令 | `40_NahYoung_Shin_SRSF2_RNAseq_NO_Repeat/docs/P40_key_operations_and_parameters_log_1001.md` |
