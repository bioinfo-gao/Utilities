# P19 — nf-core/rnaseq MultiQC (star_salmon) 逐图解读

> **本文件是 canonical 原件，2026-07-25 从项目目录迁移到此**（原判断"接近完美"的 RNA-seq
> QC 报告，留作跨项目教学范例）。同目录下的 `star_salmon/` 是配套的完整 MultiQC 原始报告
> （html + `multiqc_report_data/` + `multiqc_report_plots/`），两者应始终放在一起、成对维护。
> 原项目目录里各留了一个软链接指回这里，以后修改请改这两份原件，不要改链接：
> - `19_Lijian_Wu_Rell1_TNFa_Tumor_Perfect_QC/docs/sLk_of_P19_multiqc_QC_interpretation_0725_in_Utilities_ResultInterp.md`
> - `19_Lijian_Wu_Rell1_TNFa_Tumor_Perfect_QC/Data_Analysis_20260725/QC/multiqc/sLk_of_star_salmon_multiqc_in_Utilities_ResultInterp`

Doc Date（创建）: 2026-07-25
Project: `19_Lijian_Wu_Rell1_TNFa_Tumor`（现已改名 `19_Lijian_Wu_Rell1_TNFa_Tumor_Perfect_QC`）
对应报告: 同目录 `star_salmon/multiqc_report.html`（数据来源:
`star_salmon/multiqc_report_data/`，48 个 read 文件 / 24 个样本，2×150bp paired-end，8 组 × 3 重复）

## 0. 结论先行

**整体质量优秀，可以放心用于下游 DE 分析（`4_run_DE_PCA.R` 等已实际使用其结果）。**
`fastqc-status-check-heatmap` 上有好几列大片是黄/红，第一眼看起来吓人，但逐一深挖后，**没有一项
是真正的数据质量问题**——全部可以归为 (a) RNA-seq 数据的固有特征被 FastQC 通用阈值过度敏感地
标记，或 (b) 指标定义/分母本身就和直觉不同。真正值得记录、但依然不影响使用的两点：

1. 48 个 read 文件里唯一一个 FastQC "Overrepresented Sequences" 红色 FAIL——`WT-TNFa-2_2`，
   原因是 poly-G 伪影占比略高于阈值（见 §1.4），全部样本都有此伪影，只是这一个文件比例最高。
2. 各样本原始测序深度不均血（46.2M–100.2M reads，约2.2倍差），且 duplication% 随深度上升
   （§1.5、§4.5 dupRadar 已确认这是 expression-driven 而非 PCR 伪影）。

以下按 MultiQC 报告里的模块顺序逐个解读。

---

## 1. FastQC（raw + trimmed）

### 1.1 Status Checks 热图（`fastqc-status-check-heatmap`）

Raw 和 trimmed 两张热图有几列几乎全红/全黄，逐列拆解：

| 列 | 状态 | 是否真问题 | 说明 |
| :--- | :---: | :---: | :--- |
| Per Tile Sequence Quality | 全红 | 否 | FastQC 对 flowcell tile 位置质量差异极敏感，现代 NovaSeq/NextSeq patterned flowcell 几乎总会触发；只要 Per Base/Per Sequence Quality 是绿色（本报告是），tile 级别的轻微差异不影响下游 |
| Per Base Sequence Content | raw部分绿部分红，trimmed 全红 | 否 | RNA-seq 建库普遍用随机六聚体（random hexamer）引物，读长前 10-12bp 会有系统性碱基组成偏好——这是教科书级别的已知现象，FastQC 文档本身也说明该检查对 RNA-seq "预期会 fail"，不代表数据坏 |
| Per Sequence GC Content | 黄色为主 | 否 | 见 §1.3，实测分布单峰、平滑，只是与 FastQC 内置的理论正态分布模型形状略有出入（真实转录组从来不是理论正态分布） |
| Sequence Duplication Levels | 全红 | 否 | 见 §1.5，RNA-seq 特征性双峰重复分布，高表达转录本天然产生大量"重复"read，非 PCR 伪影 |
| Overrepresented Sequences | raw 全黄，trimmed 几乎全绿+1红 | 局部是 | 见 §1.4，poly-G 伪影，只有 `WT-TNFa-2_2` 超过阈值变红 |
| Sequence Length Distribution | raw 全绿，trimmed 全黄 | 否 | trim 之后每条 read 长度不再统一（被 adapter/低质量碱基裁短），FastQC 对"长度不均一"本身就会警告，这是 trimming 生效的正常副作用，不是异常 |

Basic Statistics / Per Base Sequence Quality / Per Sequence Quality Scores / Per Base N Content /
Adapter Content 全部绿色通过，无需解读。

### 1.2 Per Base Sequence Quality（trimmed，`fastqc_per_base_sequence_quality_plot-1`）

全长（0–148bp）Phred Q 稳定在 38–40，全程处于绿色区（Q≥28），24 个样本曲线几乎完全重叠，无任何
样本单独掉队。测序质量本身没有任何问题。

### 1.3 Per Sequence GC Content（`fastqc_per_sequence_gc_content_plot-1_Percentages`）

Raw（橙）与 trimmed（绿）均为干净的单峰分布，峰值在 ~52-55% GC，符合小鼠 mRNA/CDS 区域的
典型 GC 含量（高于全基因组平均 ~42%，因为外显子编码区 GC 偏高，这是 mRNA-seq 的常态，不是污染）。
Trimmed 曲线在 100% GC 处有一个极小的尖峰——这正是 §1.4 poly-G 伪影序列（50bp 全 G，GC=100%）
在 trim 后仍残留的贡献，量级 <0.5%，可忽略。

**为什么 51-54% 不算"超标"——对比基准搞对很关键：**

- 小鼠**全基因组**平均 GC 约 42%，但这是把内含子、基因间区、重复序列全部算进去的数字。
- RNA-seq 只测**转录本**（主要是外显子/CDS 区），而哺乳动物（人和鼠都一样）的外显子区系统性地
  比内含子/基因间区 GC 含量高——这是已知的"exon-intron GC 梯度"现象，加上密码子使用偏好、
  5'UTR 附近 CpG island 的贡献，共同把转录组整体 GC% 拉高于基因组平均值。
- 所以老鼠/人的 mRNA-seq 典型 GC% 落在 45-55% 区间是**行业标准常态**，不是异常，本项目
  51-54% 正好落在这个正常区间内，**不能拿"全基因组 42%"当基准去判断它超标**。

**FastQC 的黄色 WARN 和 GC% 数值高低本身无关**：这个模块不是"GC% 超过某个阈值就报警"，而是
拿实测分布去和"以实测均值为中心动态生成的理论正态曲线"做**形状**比对——只要实测分布不是完美
单峰高斯（比如本报告在 33-40% 处有一个小肩峰，是不同 GC 含量转录本混合的正常结果），就会被
判定为形状偏离而打黄标。也就是说 WARN 传达的是"分布形状不够对称"，不是"数值超出正常范围"，
两者是完全不同的判断维度，读报告时不要混为一谈。

### 1.4 Overrepresented Sequences（关键异常点）

`multiqc_top_overrepresented_sequences_table` 显示：

| 数据集 | 序列 | 出现文件数 | 占全部 reads 比例 |
| :--- | :--- | :---: | :---: |
| Raw | `GGGGG...`（50bp 全 G） | 24/24（全部样本） | 0.79% |
| Trimmed | `GGGGG...`（50bp 全 G） | 24/24（全部样本） | 0.39%（trim 后减半） |

这是 **poly-G 伪影**，Illumina 双通道化学（2-channel chemistry，NovaSeq/NextSeq 系列）的已知
特征：当某个 cycle 没有真实荧光信号（dark cycle，常见于插入片段短于 read 长度、read 读穿进入
接头之后的"空转"区域）时，仪器默认把无信号 call 成碱基 G。这是全平台性伪影，24 个样本全部都有，
比例也高度一致（<1%），trimming 后进一步减半——完全是预期行为。

`WT-TNFa-2_2` 是 48 个文件中唯一被 FastQC 标红（FAIL）的，只是因为这一个文件里 poly-G 占比
恰好越过了 FastQC 的单文件阈值，而其余文件都停在 WARN 或 PASS 区间——**不是这个样本独有的问题，
只是同一个全局伪影在这个文件里比例稍高**，不影响该样本可用性（该样本的 STAR 唯一比对率 94.6%，
与同组其他重复一致，见 §2 表格）。

### 1.5 Sequence Duplication Levels（`fastqc_sequence_duplication_levels_plot`）

曲线呈现 RNA-seq 特征性的"双峰"形状：level=1 时 17-25%，随 level 增加平滑下降到 level=9 附近
的低点（~2%），然后在 level=">10" 处出现第二个隆起（可达 20-23%），之后再逐渐衰减。这个二次
隆起正是 RNA-seq（相对于基因组 DNA-seq 那种单调衰减曲线）的典型特征——高表达转录本天然会产生
大量"看起来重复"的 read，属于生物学重复而非文库扩增伪影。§4.5 的 dupRadar 分析已经用独立方法
证实了这一点（duplication% 随基因表达量单调上升，intercept 低），两者互相印证，说明这批数据的
高 duplication 是表达驱动，不是 PCR over-amplification 的信号。

---

## 2. Cutadapt + STAR 比对

Per-sample 关键数字（来自 `multiqc_general_stats.txt` + `star_summary_table.txt`）：

| 样本 | Raw reads (M) | Cutadapt 去除% (R1/R2) | STAR 唯一比对% | Multi-map% | Aligned 总% |
| :--- | :---: | :---: | :---: | :---: | :---: |
| Rell1-KO-un-1 | 72.7 | 2.0/1.6 | 94.96 | 2.10 | 97.84 |
| Rell1-KO-un-2 | 97.8 | 3.6/1.9 | 95.08 | 2.83 | 97.97 |
| Rell1-KO-un-3 | 65.1 | 2.4/1.8 | 94.93 | 1.95 | 97.92 |
| Rell1-TNFa-1~3 | 55.2–77.0 | 1.8–3.1/1.3–2.1 | 94.91–95.01 | 1.63–2.18 | 97.74–97.89 |
| Rell1-Tumor-1~3 | 46.2–52.3 | 1.8–1.9/1.4 | 93.35–93.57 | 1.64–1.82 | 96.89–97.04 |
| Rell1-Tumor-TNFa-1~3 | 50.6–73.4 | 2.1–2.9/1.5–1.7 | 93.32–93.40 | 1.87–2.60 | 96.95–97.05 |
| WT-TNFa-1~3 | 64.6–69.6 | 1.9–2.3/1.4 | 94.64–94.92 | 1.82–1.98 | 97.54–97.76 |
| WT-Tumor-1~3 | 64.8–72.1 | 1.9–2.2/1.4–1.5 | 93.21–93.31 | 2.33–2.63 | 96.88–96.91 |
| WT-Tumor-TNFa-1~3 | 59.4–77.1 | 1.8–2.8/1.4–1.7 | 93.00–93.24 | 2.23–2.88 | 96.68–96.97 |
| WT-un-1~3 | 63.8–68.4 | 2.1–3.9/1.4–1.7 | 94.72–94.78 | 1.88–2.00 | 97.64–97.75 |

**观察点（非异常，但值得记录）**：
1. **原始测序深度不均匀**：46.2M（Rell1-Tumor-2）到 100.2M（Rell1-KO-un-2），约 2.2 倍差异。
   属于常规批次间深度波动，DESeq2 的 size factor 归一化会处理，不影响差异表达结果的有效性；
   仅在这里记录以备将来复现/追溯。
2. **系统性但很小的比对率差异**：`un`/`TNFa` 组（两个基因型）唯一比对率稳定在 94.6-95.1%，
   `Tumor`/`Tumor-TNFa` 组稳定在 93.0-93.6%，差距约 1-2 个百分点，两个基因型内都一致地出现——
   可能反映 Tumor 暴露下转录组复杂度/重复序列表达的细微变化，但差距很小，且两组都远高于
   "唯一比对率 <90% 需要警惕"的经验阈值，不影响使用。
3. STAR 比对分数图（`star_alignment_plot`）24 个样本几乎完全一致的堆叠比例（蓝=唯一比对
   ~93-95%，浅蓝=multi-loci ~2-3%，深红=unmapped too short ~1-2%），无任何单个样本异常掉队。

---

## 3. Samtools flagstat / idxstats

- **Samtools stats "error rate"** 在 general_stats 表里显示为 0.14-0.15，**这不是 14-15%，
  是已经乘以 100 的百分比数值，真实含义是 0.14-0.15%**（原始 `multiqc_samtools_stats.txt`
  记录的是 0.00142 这个小数形式）——测序错配率 0.14% 是非常干净的水平，此处特意记录是因为
  这个字段的单位表述容易被误读成"14% 错误率"而误判为严重问题。
- **`samtools stats` reads_mapped% 全部显示 100.0%**：这不是"零 unmapped reads"的字面意思，
  而是因为这一步统计跑在 STAR 生成的、只保留已比对 read 的 sorted genome BAM 上（未比对的
  read 在 STAR 这一步就没写进 BAM），所以下游对这份 BAM 算 mapped% 天然是 100%。真正反映
  "多少原始 read 比对上了参考基因组"的指标是 STAR 自己的比对率（§2 表格，93-98%）。
- **`samtools idxstats` chrX/chrY 图**（`samtools-idxstats-xy-plot`）：24 个样本清一色约
  99% chrX / 1% chrY reads，WT 和 Rell1-KO 两个基因型完全一致，无任何样本偏离这个模式——
  说明这批细胞系（不论基因型）几乎不表达 Y 连锁基因（提示细胞系本身可能是雌性来源，或该组织
  背景下 Y 基因表达量极低），**且没有出现某个样本 X/Y 比例异常的情况，排除了样本调包/性别
  错配的可能**。

---

## 4. RSeQC

### 4.1 Infer Experiment（链特异性核验，`rseqc_infer_experiment_plot`）

全部 24 个样本一致显示 ~2-3% Sense / ~92-95% Antisense / ~4-6% Undetermined——高度一致的
reverse-stranded 文库特征。更重要的是，nf-core/rnaseq 自带的 **`fail_strand_check_table`**
逐样本核对了"流水线设定的 strandedness"与"RSeQC 实测的 strandedness"，**24/24 全部
`Status=pass`，`Provided strandedness=reverse`，`Inferred strandedness=reverse`**——
说明本项目 Salmon 定量时使用的链特异性参数与实际建库方式完全匹配，这是最容易被忽视、但一旦
配错会直接污染所有下游定量结果的一类错误，本项目已经过自动核验，没有问题。

### 4.2 RSeQC Bam Stat 的 "Proper Pairs %" 为何只有 56-63%（易读错的指标）

`multiqc_general_stats.txt` 里 RSeQC 的 `proper_pairs_percent` 只有 56.15-62.95%，乍看像是
"接近一半的 read pair 没有正确配对"，但对照原始 `rseqc_bam_stat.txt` 逐字段核对后发现：

- 分母 `total_records` 里包含了 optical/PCR 重复（~35-40%，见 §4.5）+ non-primary hits（~3%）
  + 低 MAPQ 的 multi-mapper（~1-2%）；
- 分子 `reads_mapped_in_proper_pairs` 和 "唯一比对且 MAPQ 达标"的 read 数几乎完全重合
  （以 Rell1-KO-un-1 为例：84,719,014 唯一比对 vs 84,712,664 判定为 proper pair，重合度
  >99.99%）。

也就是说 **RSeQC 这里的百分比分母用的是"全部 alignment 记录数"而不是"唯一比对 read 数"**，
所以数值天然比直觉预期低很多，这是 RSeQC bam_stat 模块本身指标定义的特点，不是本数据的
配对失败问题。真正反映配对质量的是 samtools stats 的 `reads_properly_paired_percent`
（99.96%，见 §3 原始记录），非常干净。

### 4.3 Inner Distance / Junction Saturation / Read Distribution

三张图 24 个样本曲线全部紧密重叠、形态一致，均为教科书式正常图形：

- **Inner Distance**：峰值在 -50~0bp 附近（部分片段短于 2×150bp 导致轻微负值，与 §1
  Adapter Content 曲线里约 70bp 位置开始出现读穿信号相互印证，是同一批短片段导致的两种
  表现），分布平滑单峰，无异常拖尾。
- **Junction Saturation**：所有样本的曲线随抽样比例平滑上升且尚未完全平台化（100% reads
  时仍在上升），说明测序深度对于饱和检测全部剪接位点还有余量，属正常现象，不影响差异表达
  分析（DE 分析看的是已知基因表达量，不依赖剪接位点完全饱和）。
- **Read Distribution**：CDS_Exons ~78-85%、3'UTR ~8-13%、5'UTR ~2-4%、Introns ~5-7%，
  TSS/TES 侧翼区域和基因间区几乎为零——外显子占绝对主导、内含子/基因间区极低，是高质量
  poly-A 富集 mRNA-seq 的标准分布，没有基因组 DNA 污染的迹象。

### 4.4 QualiMap Genomic Origin + Gene Coverage Profile

Genomic Origin（Exonic ~83-87% / Intronic ~11-15% / Intergenic ~2%）与 §4.3 Read
Distribution 相互印证，结论一致。Gene Coverage Profile（沿转录本长度归一化覆盖度）曲线
24 样本几乎完全重合，5' 端小幅爬升后维持平台、3' 端末尾（>90% transcript position）才开始
下降，5'/3' bias 比值全部在 1.06-1.13（QualiMap `mqc_5_3_bias` 列，接近 1 = 无明显偏向），
说明 RNA 完整性良好，没有明显降解迹象。

### 4.5 Picard MarkDuplicates + dupRadar

Picard 报告的 duplication 率 32.5-40.5%（Optical duplicate 占比明显，符合 patterned
flowcell NovaSeq 的常见特征，不代表 PCR 过度扩增）。**关键验证在 dupRadar**：24 个样本的
"duplication% vs. 表达量(reads/kbp)"曲线几乎完全重合、单调上升——低表达基因 duplication%
低（<20%），高表达基因 duplication% 自然升高（>40%），dupRadar intercept 全部很低
（0.14-0.21，通用经验阈值 <2 视为健康）。这组合是 RNA-seq duplication 的"标准健康画像"：
duplication 由基因表达量驱动，而非文库扩增偏差驱动，因此 DESeq2 的差异表达分析里不需要额外
去重（`4_run_DE_PCA.R` 用的是未去重的 STAR/Salmon 定量结果，符合 nf-core/rnaseq 推荐做法）。

---

## 5. featureCounts Biotype + DESeq2（nf-core 自带的快速版本）

- **Biotype 分布**：24 个样本清一色 ~97-99% `protein_coding`，其余 biotype（lncRNA/miRNA/
  pseudogene 等）占比极低，说明建库/定量高度特异于蛋白编码基因，无明显非期望 RNA 种类污染。
- **nf-core 自带 DESeq2 PCA/Clustering**（`star_salmon_deseq2_pca-plot` /
  `_clustering-plot`）：用的是 nf-core 内置的默认高变基因筛选（与 `4_run_DE_PCA.R` 自定义的
  regex+低表达过滤不同），8 组 × 3 重复在 PC1/PC2 上依然清晰分成 8 个独立紧凑的簇，
  sample-to-sample 距离热图上对角线（同组重复）稳定呈深红（低距离），组间呈黄/蓝
  （高距离），且 Tumor/Tumor-TNFa 组与 un/TNFa 组明显分离——两种独立算法（nf-core 内置版 +
  `4_run_DE_PCA.R` 自建版，见 `custom_research_report_20260725/DE_PCA_Results/PCA.pdf`，
  分离比 52.99x）得出一致结论，互相印证了 §0 结论里"无样本错标"的判断。

---

## 6. "看起来奇怪，实际正常"速查表

| 现象 | 位置 | 真实原因 | 结论 |
| :--- | :--- | :--- | :---: |
| Per Base Sequence Content 全红 | FastQC status heatmap | random hexamer 引物偏好，RNA-seq 通病 | 正常 |
| Sequence Duplication Levels 全红 + 双峰曲线 | FastQC | 高表达转录本天然重复，dupRadar 已证实 expression-driven | 正常 |
| Sequence Length Distribution trim 后变黄 | FastQC status heatmap | trimming 导致长度不再统一，检查本身设计如此 | 正常 |
| `WT-TNFa-2_2` Overrepresented Sequences 红色 FAIL | FastQC | poly-G 测序伪影，24 样本全有，只此文件比例过阈值 | 正常，不影响样本可用性 |
| samtools error_rate 显示 "0.14" | general_stats 表 | 该列已经是百分比，真实值 0.14%，非 14% | 正常，单位读法问题 |
| samtools reads_mapped% = 100.0 | general_stats 表 | 统计对象是已过滤只含 mapped reads 的 BAM | 正常，需看 STAR 自己的比对率 |
| RSeQC proper_pairs% 只有 56-63% | general_stats 表 | 分母含重复/多比对记录，非直觉的"唯一比对基准" | 正常，需看 samtools 的 99.96% |
| chrX/chrY 图 24 样本几乎全 chrX | idxstats xy-plot | 细胞系本身 Y 基因表达量低（可能雌性来源） | 正常，且证明无性别/样本调包问题 |
| %GC 51-54%，感觉比小鼠基因组"高" | FastQC Per Sequence GC Content | 42% 是全基因组均值，RNA-seq 只测外显子/CDS，天然比全基因组 GC 更高；45-55% 是 mRNA-seq 行业常态 | 正常，对比基准搞错了；黄色 WARN 是分布形状比对触发，与数值高低无关 |

---

*本文档为内部 QC 解读记录，不对客户交付。数据来源与生成时间：nf-core/rnaseq 主流程
2026-07-24 00:35 完成，MultiQC 报告随流程同批生成。*
