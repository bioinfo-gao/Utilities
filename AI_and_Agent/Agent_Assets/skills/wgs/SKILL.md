---
name: wgs
description: "Use when 用户要搭建 WGS 分析——种系变异检出(sarek)、转基因/定点敲入整合分析、细胞系株系鉴定+转基因发现、或指定位点(重复区)的 clone-vs-population 结构变异/断裂-重排研究(read rescue)"
disable-model-invocation: true
---
# /wgs — Whole-Genome Sequencing Analysis Setup Skill

> **📍 关联文件组｜项目14「load-152 资源事件」四联档（2026-07-13）** — 以下四份内容互补、共享同一组实测数据，看到任意一份即可定位其余三份（绝对路径，一年后依旧可寻）：
>
> 1. **根因深挖**：`/home/gao/projects_2026H2/14_geneedit_lats12_wgs/docs/resource_pressure_incident_0713.md` — CNNScoreVariants 超订致 load 峰值 152 的逐层分析 + 配置修正
> 2. **项目14全程负载画像**：`/home/gao/projects_2026H2/facilities/Server/nextflow_pipeline/project14_load_profile_0713.md` — Study A+B 全程峰值/空闲/负载分布
> 3. **wgs skill**：`/home/gao/.claude/skills/wgs/SKILL.md` — CNN 是隐藏 CPU 大户的警告，写入资源 config 节
> 4. **corun skill**：`/home/gao/.claude/skills/corun/SKILL.md` — 哪些阶段可并跑 / 哪些绝对不行 的速判矩阵

为当前项目搭建 WGS 分析代码。覆盖三种模式，先判断项目属于哪一种（或组合）：

- **模式 A — 标准种系 WGS**：nf-core/sarek → 比对/QC/去重 → SNV/indel（HaplotypeCaller/DeepVariant/Strelka）→ SV/CNV（Manta/TIDDIT）→ 报告。用于质量评估、变异检出。参考已验证实现：`4_wgs_human_immu/`。
- **模式 B — 转基因/定点敲入整合分析（构建体已知）**：混合参考（hybrid ref）→ 比对 → 整合位点/结合部检测（Manta/DELLY + 嵌合读段）→ 拷贝数（mosdepth 深度比值）→ 脱靶筛查 → 断点注释 → 报告。参考已验证实现：`13_Ellen_knockin_wgs/`。
- **模式 C — 细胞系种系/株系鉴定 + 转基因发现（构建体未知）**：轻量 bwa 比对 → 物种确认（mapping rate）+ 株系鉴定（标志位点拷贝数）+ 转基因**发现**（host-subtraction：未比对读段 de novo 组装 + BLAST）→ 报告。用于表达系统/细胞系身份确认与外源序列盲鉴。参考已验证实现：`3_cho_wgs_species_confirm/`（CHO 细胞系）。
- **模式 D — 指定位点（常是重复区）的结构变异 / 断裂-重排研究（clone vs population）**：自写 bwa-mem2 比对（BAM，非 sarek）→ 位点可比对性预检 → 三路独立 SV 证据（Manta 放宽 + DELLY 无排除表 + 自写读段级证据）→ 阴性对照窗口本底 → clone-vs-population 减法 → 深度断崖 + BAF/LOH → **第二轮 read rescue**（全基因组扫 mate/SA/XA + unmapped，竞争性再基因分型）→ claim ladder → 报告。用于"某位点在克隆里有没有 DEL/INS/INV/易位"类问题。参考已验证实现：P41 `41_Vedict_18_wgs/`（初报）→ P45 `45_Vedita_18_wgs_combined_Advanced/`（rescue 合并版）。详见下文「模式 D 专用流程」。

> **关键分叉一：转基因"构建体已知"还是"未知"？**
>
> - **已知**（有质粒图谱/等位基因序列）→ **模式 B**：建混合参考、精确定位整合。
> - **未知**（只知道"可能转了东西"，无序列）→ **模式 C**：host-subtraction 盲鉴——把未比对读段组装后 BLAST，能查出转了什么，无需事先拿到载体图。
>   **关键分叉二（模式 B 内）：随机转基因 vs 定点打靶敲入**：解析构建体序列，两侧有宿主基因组同源臂 → 定点打靶（整合位点已知，核心是验证 on-target/脱靶/拷贝数/合子型/Neo）；无同源臂 → 随机整合（靠嵌合读段找位点）。

---

## 第一步：信息收集

读取样本表（CSV/xlsx），确认：

| 参数                        | 确认方式                                                                                                                                 |
| :--- | :---: |
| 项目根目录                  | 从当前工作目录推断，或请用户确认                                                                                                         |
| 样本表路径                  | 用户提供，或在项目根目录查找                                                                                                             |
| FASTQ 数据目录              | 读样本表后确认实际路径                                                                                                                   |
| 物种                        | Mouse / Human / CHO / 其他（决定参考基因组；模式C 可能就是"待确认物种"）                                                                 |
| 分析模式                    | A 标准种系 / B 整合分析(构建体已知) / C 细胞系鉴定+转基因发现(构建体未知) / 组合                                                         |
| （模式B）构建体序列         | **头号 blocker**：客户的载体/等位基因序列（GenBank/FASTA/SnapGene .dna）；随机转基因需质粒全序列，定点敲入需带同源臂的等位基因序列 |
| （模式C）候选物种/株系      | 客户声称的细胞系身份（如 CHO-K1）；用于选参考、定株系标志位点。**无需构建体序列**                                                  |
| （模式C）reads 用量         | **默认全量**（株系鉴定客户要求全量、深度结论不可抽样）；**主动提供** 5M 子集"快速预览"作为赶时间选项，但预览不作交付结论     |
| 对照                        | 有无纯野生型（WT）；模式B若无 WT，用"样本自身单拷贝基线 + 品系互为阴性对照"                                                              |
| （模式A）germline / somatic | 纯 germline 还是 tumor-normal 配对                                                                                                       |
| （模式D）靶区坐标与是否 mask | **严格按客户坐标**（P41 客户写"~25 kb"，坐标实为 21,501 bp，以坐标为准）；客户要求重复区不 mask 时，逐个 caller 落实到参数（见模式 D） |
| （模式D）比较设计            | 谁是基线（population + no-dox 对照克隆）、谁是处理克隆；写成 `scripts/0_design_comparisons.tsv` SSOT；有无"+诱导剂但无效应蛋白"对照（没有 ⇒ Limitations 写混杂） |
| 交付物重心                  | 与客户确认目标（整合验证/拷贝数/脱靶/合子型/Neo/变异检出／物种株系确认／转基因盲鉴），决定报告侧重                                       |

---

## 第二步：参考基因组路径（预设，已建 bwa-mem2 索引）

### Mouse — GRCm39 / GENCODE M35

```
FASTA:  /Work_bio/references/Mus_musculus/GRCm39/mouse_gencode_M35/GRCm39.primary_assembly.genome.fa
GTF:    /Work_bio/references/Mus_musculus/GRCm39/mouse_gencode_M35/gencode.vM35.annotation.gtf
（同目录已有 .0123 / .bwt.2bit.64 / .amb / .ann / .pac → bwa-mem2 索引就绪）
```

### Human — GRCh38 / GENCODE v45

```
FASTA:  /Work_bio/references/Homo_sapiens/GRCh38/human_gencode_v45/GRCh38.primary_assembly.genome.fa
GTF:    /Work_bio/references/Homo_sapiens/GRCh38/human_gencode_v45/gencode.v45.annotation.gtf
```

模式B 常用 GRCh38 提取人源基因序列（bootstrap 或核对客户构建体）。

### CHO — CriGri-PICR（模式C 细胞系）

```
FASTA: /Work_bio/references/Cricetulus_griseus/CriGri-PICR/ncbi_refseq/GCF_003668045.1_CriGri-PICR_genomic.fna
GFF:   /Work_bio/references/Cricetulus_griseus/CriGri-PICR/ncbi_refseq/GCF_003668045.1_CriGri-PICR_genomic.gff.gz
株系标志位点 DHFR: NW_020822461.1:37,643,639-37,667,418
```

其他物种参考：NCBI RefSeq 下载（`GCF_*`），`bwa index`（内存紧张时勿用 bwa-mem2 index）+ `samtools faidx`。

---

## 第三步：环境与工具（已装，勿重复安装）

| 工具                                                                      | 位置                                                         | 用途                                                  |
| :--- | :---: | :---: |
| nextflow / nf-core / docker / singularity                                 | regular_bioinfo（项目4已验证）                               | 跑 sarek                                              |
| nf-core/sarek                                                             | **锁定 `-r 3.8.1`**                                  | 标准骨架引擎                                          |
| bwa-mem2 / bwa / samtools / bcftools / blastn / minimap2 / seqkit / fastp | regular_bioinfo                                              | 比对/处理/建参考/比对构建体                           |
| mosdepth 0.3.14 / delly 2.3.0                                             | regular_bioinfo                                              | 深度/SV                                               |
| manta 1.6.0                                                               | **独立 `manta` 环境**（py2，勿装进 regular_bioinfo） | SV/整合结合部                                         |
| Biopython                                                                 | regular_bioinfo                                              | 解析 SnapGene`.dna`（`SeqIO.read(f,'snapgene')`） |
| megahit / blastn / bwa / bedtools                                         | regular_bioinfo                                              | **模式C**：host-subtraction 组装 + nt 同源搜索  |

模式B 若客户构建体是 SnapGene `.dna`：用 Biopython 解析出序列 + feature（同源臂/外显子/Neo/FRT 标签信息量极大），导出干净 FASTA。若序列以 Gmail 附件形式发来且 Gmail MCP 下不了附件，走 IMAP 自取（凭据在 `~/.claude.json` 的 `mcpServers.gmail.env`，见记忆 `feedback-gmail-attachment-via-imap`）。

---

## 第四步：目录结构

```
{PROJECT_DIR}/
├── {sample_sheet}
├── refs/constructs/              ← 模式B：客户构建体 .dna/.fa + 导出的 TG_*.fa + 合并 hybrid 参考
├── scripts/
│   ├── 0_build_hybrid_ref.sh     ← 模式B：cat GRCm39 + 构建体 contig → bwa-mem2 index
│   ├── 1_produce_samplesheet.py  ← 生成 sarek samplesheet.csv
│   ├── 2_run_sarek.sh            ← self-relaunch + auto-resume（见下）
│   ├── 3_work_monitor.sh
│   ├── 4_integration_analysis.sh ← 模式B：嵌合读段抓取 + manta/delly + 结合部聚类
│   ├── 5_copy_number.sh          ← 模式B：mosdepth 深度比值
│   ├── 6_annotate_breakpoints.R  ← 模式B：断点注释到 GENCODE vM35
│   ├── 7_generate_report.R
│   └── local_resources.config
├── output_results/               ← sarek 输出
└── custom_research_report_YYYYMMDD/   ← 交付（见 CLAUDE.md 结构规范）
```

---

## 第五步：核心脚本

### 模式B 脚本 0 — 建合并 hybrid 参考

- **一个合并参考跑全部样本**（不是每组一个）：`cat GRCm39.fa TG_A.fa TG_B.fa ... > GRCm39_plus_constructs.fa`
- 每个构建体作独立 contig（`>TG_<name>`）；`bwa-mem2 index` + `samtools faidx` + `samtools dict`。
- **好处**：每样只覆盖自己构建体，在其他构建体上零覆盖 = 自带阴性对照（特异性验证）。
- **定点敲入注意**：同源臂是小鼠序列，在 hybrid 里与原生位点重复 → 该区多重比对。定位靶位点用同源臂比对 GRCm39（`minimap2 -x asm5`，MAPQ60 即锁定）；区分敲入用**人源/新颖片段**和结合部 split reads，必要时对原生靶位点做 MAPQ 过滤。

### 脚本 2 — `2_run_sarek.sh`（self-relaunch + auto-resume，强制模式，同 rnaseq）

```bash
if [ -z "$TMUX" ]; then
    tmux new-session -d -s wgs "bash '${SCRIPT}' 2>&1 | tee sarek_run.log"; exit 0
fi
run_sarek() {
    nextflow run nf-core/sarek -r 3.8.1 -profile singularity \
        -c local_resources.config "$@" \
        --input samplesheet.csv --outdir output_results \
        --fasta {HYBRID_or_GENOME}.fa \
        --aligner bwa-mem2 \
        --skip_tools baserecalibrator \
        --tools manta,tiddit          # 模式A 另加 haplotypecaller/strelka/deepvariant
}
if run_sarek; then exit 0; fi
if run_sarek -resume; then exit 0; fi
exit 1
```

**固定/关键参数：**

- `-r 3.8.1`（锁定）
- `--aligner bwa-mem2`
- `--skip_tools baserecalibrator`（无 known-sites；NovaSeq 上 BQSR 收益极小——项目4已确认）
- 模式B `--tools manta,tiddit`（BND 断点 = 整合结合部）；模式A 追加 germline caller
- 自定义 `--fasta` 时跳过 snpEff/VEP 人类注释，断点/变异自己注释到 GENCODE vM35

> **sarek samplesheet 是固定 schema 的机器输入，别按客户样本表改（常见困惑点）**：只认 `patient,sample,status,lane,fastq_1,fastq_2` 六列，改列名会被拒。**`patient` 是"tumor-normal 配对分组键"，不是"病人"**：somatic 时同一 tumor 与其 normal **必须共享同一个 `patient` 值**，sarek 才会配对（如一整条谱系/一只小鼠所有样本共用一个 patient，normal=status0、tumor=status1）——把 patient 改成每样唯一会让"没有 normal 可配、somatic 失效"。行的区分靠 `sample` 列。germline 则每样自成 patient、status=0。**客户一致的命名放独立的 `sample_info.tsv`（可含客户原 `Sample_Name`/`Sample_Type` 列），不要塞进 sarek CSV。** 详例见 `14_geneedit_lats12_wgs/scripts/0_common/samplesheet_design_notes.md`。

### 模式B 脚本 4 — 整合位点检测（两路交叉验证）

- **(A) 定向嵌合读段**：`samtools view <BAM> TG_<name>` 抓落在构建体 contig 上的读段及其配偶 → 看配偶/软剪切段落回小鼠何处 → 聚类成整合位点，split-read 给碱基级断点。
- **(B) 通用 SV caller**：manta（`manta` 环境）或 delly（BND 模式）在 hybrid 上直接调用跨 contig 断点。
- 汇总每位点：小鼠侧坐标、构建体侧坐标、支持读段数（split+discordant）、方向。
- **定点敲入额外**：预期位点结合部是否存在且干净（on-target 验证）；构建体读段配偶落到预期位点以外 = **脱靶随机整合**；残留 **Neo/载体骨架**读段 = Neo 未删干净。

### 模式B 脚本 5 — 拷贝数（mosdepth 深度比值）

- `mosdepth` 算：构建体 contig 平均深度、全基因组常染色体中位深度、若干已知单拷贝小鼠区域深度。
- 拷贝数 ≈ 构建体 contig 唯一比对深度 / **样本自身**单拷贝小鼠基线深度（本批常无纯 WT → 用自身基线）。
- 人源/小鼠同源区做 MAPQ 过滤唯一比对，避免交叉比对虚高；用其他品系样本作阴性对照。
- **不用 sarek 的 CNV 模块**（ASCAT/CNVkit 肿瘤/人类导向）。

### 脚本 6 — 断点/变异注释

- 整合断点坐标注释到 `gencode.vM35.annotation.gtf` → 落在哪个小鼠基因（外显子/内含子/调控区），是否破坏内源基因。
- 定点敲入：确认内源靶基因原生区覆盖丢失（被置换）。

### `local_resources.config`（沿用项目4稳健配置）

```
executor { name='local'; queueSize=2 }        # 同时只跑 2 个样本，防内存紧张
process {
    cpus=16; memory=50.GB
    withName:'.*BWAMEM2.*' { cpus=16; memory=60.GB }
}
```

总量守住 ≤28 物理核 / 56 线程、RAM 留 buffer（`samtools sort -m` 是 per-thread，总量 = m×(threads+1)，先 `free -h`）。

> ⚠ **germline 变异过滤 `CNNScoreVariants` 是隐藏 CPU 大户**：实测每任务 **≈8.7 核**（%cpu 843–920%，TensorFlow 多线程）但 **RSS 仅 1.8 GB**。靠内存预算自动限流的 config 对它**完全无效**（RSS 太小永不触发），不显式限核会按默认拿满并发席位 → 曾致 **load 峰值 152**（项目14 Study B，2026-07-13，持续 ~2h15m）。**germline 独占整机跑时必须显式声明** `withName:'.*CNNSCOREVARIANTS.*' { cpus=9 }`（56/9≈6 并发=6样本，不叠加）。通用推论：**内存限流对"低RSS高线程"进程无效，凡实测 %cpu 远超声明 cpus 的进程一律显式限核**——用 `execution_trace` 的 `%cpu` 列核算预算，别信 declared。完整实测/根因见 `facilities/Server/nextflow_pipeline/project14_load_profile_0713.md` 与 `14_geneedit_lats12_wgs/docs/resource_pressure_incident_0713.md`。此外 germline 的**去重/gather 期是天然空闲窗口**（load 掉到 3–4，~50 线程闲置约 2h），可排入其它 CPU 轻活。

---

## 模式 C 专用流程 —— 细胞系种系/株系鉴定 + 转基因发现（构建体未知）

> **完整分步命令 + 参数 + 解读表见参考文件：`/home/gao/.claude/references/wgs_modeC_celline_transgene_discovery.md`**（源自已交付 CHO 项目全量流程 notebook `3_cho_wgs_species_confirm/CHO_WGS_full_species_strain_transgene_pipeline.ipynb`）。下面是要点速览。

参考实现 `3_cho_wgs_species_confirm/`（CHO 表达系统，wt1 样本）。**不用 sarek**，轻量 bwa + 组装 + BLAST，三个目标。

> **默认全量比对（一次全量比对同时产出物种/株系/转基因三项）。**
> **株系鉴定必须用全部 reads —— 这是客户明确要求，深度依赖的结论不能用抽样。**
> 5M 子集只是**赶时间的快速预览选项**，属初步、不作交付结论。**运行前主动向用户提供选择**："默认全量(结论级，慢) vs 5M 子集预览(快，非交付)"。
> 真实教训：抽样版（0.6× 覆盖，DHFR 仅 1.7×、20% 碱基覆盖，`OLD/Research_Report/Research_Summary.md`）**客户不满意**；全量版（DHFR 24.1×、侧翼 23.9×、ratio 1.008，`custom_research_report_20260626/`）才是最终交付。低深度下 DXB11 的 ~0.5 杂合缺失尤其难以有把握地判定。

### C0 — 全量比对（默认；三项分析的共同输入）

- `bwa mem -t 20 -R '@RG\tID:<s>\tSM:<s>\tPL:ILLUMINA' <物种参考> R1 R2 | samtools sort -@ 8 -m 8G -o full.bam` → `samtools index`。
- （可选预览）赶时间先看：fastp `--reads_to_process 5000000` 取子集跑一遍，得初步 mapping rate + 大致 DHFR ratio，但**株系结论仍以全量为准**。

### C1 — 物种确认

- `samtools flagstat full.bam`。**判据**：primary mapping rate **>85% = 确认该物种**；50–85% = 可疑/需查；<50% = 非该物种。（未比对的小部分是转基因，不代表物种不符——CHO wt1 全量 95.83%，正因 4.2% 转基因拉低。）

### C2 — 株系鉴定（标志位点拷贝数深度比值，**全量**）

- 找该物种的**株系标志位点**，算 `位点深度 / 侧翼(±500kb)深度` 比值——同染色体、免归一化、不受测序深度与 GC 影响。
- **CHO 用 DHFR 位点**（CriGri-PICR `NW_020822461.1:37,643,639-37,667,418`）：

  | DHFR/侧翼比值                                    |                                           株系                                           |
  | :--- | :---: |
  | <0.05（且覆盖<5%）                               |                                CHO-DG44（DHFR 纯合缺失）                                |
  | 0.05–0.35                                       |                                  CHO-DXB11（杂合缺失）                                  |
  | >0.70（全量观测 1.008，DHFR 24.1×/侧翼 23.9×） | CHO-K1 或 CHO-S（DHFR 完整；WGS 无法再区分 K1/S，需问培养方式：贴壁→K1，悬浮无血清→S） |
- 命令：`samtools depth -r <位点> full.bam | awk '{s+=$3;n++}END{print s/n}'`，侧翼同理。**全量下 DHFR 与侧翼都接近全覆盖、~24× 深度**，比值才 robust（子集只有 ~20% 覆盖/1.7×，不足以交付）。

### C3 — 转基因发现（host-subtraction，构建体未知时的盲鉴，**全量**）

> 直接全量 de novo 组装不可行（>500GB RAM、被宿主序列淹没）；只组装**未比对**读段，小、快、富集外源序列，**无需事先拿到载体图**。

1. 从 **C0 的全量 BAM** 提未比对读段：
   - 双端均未比对：`samtools view -b -f 12 -F 256 -F 2048` → `samtools fastq` 出 `unmapped_R1/R2`
   - 单端未比对：`samtools view -b -f 4 -F 8 -F 256 -F 2048` → `unmapped_singleton`
   - **判据**：未比对比例 **>0.5%（远超正常 <0.5% 背景）= 有显著外源序列**（CHO wt1 达 4.2%）。
2. **de novo 组装**：`megahit -1 unmapped_R1 -2 unmapped_R2 -r singleton -t 16 -m 0.5 --min-contig-len 200`。
3. **BLAST**：取 **≥1000bp** contig，`blastn` 对 NCBI **nt**（`-evalue 1e-10 -max_target_seqs 5`，outfmt 含 stitle）。
   - **判据**：identity ≥95% 且 e≤1e-10 = 高置信命中；**≥1000bp 却零命中的 contig = 很可能是客户专有载体/GOI 序列**，报告里列出并请客户提供载体图核对。

- **短读不能直接 BLAST**（150bp 太短、噪声大）→ 必须先组装成长 contig。
- **局限**：若转基因与宿主内源基因高度同源（如人源化基因、其啮齿类直系同源在参考里），对应读段会比对上宿主而被排除在未比对池外 → 灵敏度下降；此时改用"只以该转基因序列为参考的定向 realign"（即转成模式 B）。

### 模式 C 资源/坑

- **参考建索引**：`bwa-mem2 index` 需 ~20–30GB RAM，服务器内存紧张时会 **OOM Killed**（CHO 项目实际发生，当时 STAR 占 ~80GB）→ 退回普通 **`bwa index`（~5–8GB）**，比对时用 `bwa mem`，结果完全相同、只是稍慢。
- CHO 参考已就位：`/Work_bio/references/Cricetulus_griseus/CriGri-PICR/ncbi_refseq/GCF_003668045.1_CriGri-PICR_genomic.{fna,gff.gz}`。
- 交付目录按 CLAUDE.md：`qc/` + `species_strain/`（flagstat、dhfr_depth）+ `transgene/`（contigs、blast_results）。

---

## 模式 D 专用流程 —— 指定位点结构变异 / 断裂-重排研究（P41 → P44 → P45 实测，2026-10）

> **来源（绝对路径，均为只读参考）**：
> - P41 初报 `/home/gao/projects_2026M7/41_Vedict_18_wgs/`：计划 `docs/P41_research_plan_and_review_1003.md`、参数 `docs/P41_key_operations_and_parameters_log_1003.md`、事故 `docs/P41_incidents_and_pitfalls_1006.md`（I-1…I-9）、背景 `docs/P41_background_dox_EBNA1_breakage_1007.md`；客户已收 2026-10-09 报告。
> - P44 rescue 设计 `/home/gao/projects_2026Q4/44_wgs_advanced_analysis_from_P41_by_cc/`：`docs/P44_research_plan_and_review_1024.md`、`docs/P44-learned-from-P42/P44_learned_from_P42_1025.md`（与 Codex 平行线 P42 的对比）。
> - P45 合并版 `/home/gao/projects_2026Q4/45_Vedita_18_wgs_combined_Advanced/`：`docs/P45_research_plan_and_review_1025.md`、`docs/P45_key_operations_and_parameters_log_1025.md`；交付 `custom_research_report_20261025/`（未发送）。
>
> 案例：18 样本 ~15–30× PE150（DLD1 / GM12878 / Mutu I / DG75 的 population + 克隆；DLD1 +dox 克隆经 EBNA1 诱导断裂），靶区 chr11:114,604,000–114,625,500。

### D0 — 设计（P41，已交付验证）

| 决定 | 做法 | 为什么 |
| :--- | :---: | :--- |
| 不用 sarek | 自写 `bwa-mem2 mem -K 100000000 -Y` → `samtools sort`（2-way pipe）→ GATK MarkDuplicates（非 Spark，`OPTICAL_DUPLICATE_PIXEL_DISTANCE=2500`，**只标记不删**） | 要 BAM（Manta 吃 CRAM 病态慢）；`-Y` 让 supplementary 用 soft-clip ⇒ **hard-clip = 0，每条 record 的 SEQ 都是完整 read**，rescue 时不用回 FASTQ |
| 不 trim | 不跑 fastp | fastp 大文件死锁；但**代价是 adapter read-through 伪 split**（见 D3），下游必须显式识别 adapter |
| 参考 | GATK analysis set `Homo_sapiens_assembly38.fasta`（含 ALT/decoy/HLA/**chrEBV**） | EBV+ 细胞系的 EBV 读段要有地方放；chrEBV 覆盖顺带当样本身份探针 |
| 完整性断言 | BAM primary 记录数 == bwa 日志 "Processed N reads" 之和 | 防截断静默通过 |
| 样本身份三道断言（不过 exit 2） | EBV 状态与细胞系一致；同系性别一致；克隆与自己 population 的 chr22 基因型一致性 > 任何跨系样本 | FASTQ 编号 ↔ 样本编号常是推断，错位则整个减法作废 |
| 位点可比对性预检（开跑前 1.5 min） | 靶区自相似（minimap2 off-diagonal）、异位同源（asm20）、`seqkit sliding` 150 bp 模拟读段回贴（unique / MAPQ0 / misplaced） | P41 实测：靶区内部重复仅 ~60–86% 一致，模拟读段 **100% 唯一**——"重复区 ⇒ 多重比对淹没"的担心对该区不成立，假阳性主要来自**别处**的比对黑洞。边界：asm20 只抓 ≲5% 分歧的近期拷贝 |

**"不 mask 重复"必须逐 caller 落实到参数**（客户明确要求时；不是一句口号）：
- Manta 靶窗口联合运行：`graphNodeMaxEdgeCount` 10→**1000**、`minScoredVariantSize` 50→20、`--generateEvidenceBam`（默认 10 = 两端节点边数都 >10 的候选边直接跳过 = 自动回避重复区；详见 `software_pitfalls/manta.md`）。全基因组 Manta 保持默认，callRegions = 主染色体 + chrEBV。Manta libexec 要 `python2` ⇒ 脚本内 PATH 垫片指向 manta 环境。
- DELLY：**不用**官方 `human.hg38.excl.tsv`（屏蔽着丝粒/端粒/重复），`-x` 只排 ALT/decoy/HLA；联合基因型只对"窗口内有断点端的位点并集"做。
- 自写证据：MAPQ0、dup 只**分列计数**不丢弃；分级只用 nondup。

### D1 — 证据分级与"不存在"的口径（P41）

- **三路互相独立的证据**：Manta（图+局部组装）、DELLY（PE+SR）、自写读段级证据（split / discordant，caller 无关）。**caller 同意是加分项不是必要条件**——caller 在重复区恰恰最不可靠。
- **分级预先登记、开跑前定**（看结果再改 = p-hacking）：A = (s20≥3 且 pr≥2) 或 (s20≥2 且 caller)；B = snd≥2 或 (pr≥3 且 snd≥1) 或 (snd≥1 且 caller)；C = 任何痕迹，保留并标记。
- **split 按 fragment（QNAME）去重**，否则 R1/R2 跨同一断点算两次；朝外（RF）判据要求反向读段末端 < 正向读段起点（短于读长的片段仍是正常 FR，冒烟里曾造出 55 个假 DUP 簇）；插入片段阈值取 `median±5×MAD` 与 99.9/0.1% 分位数中**较宽者**（只用 MAD 会把正常右尾当 DEL）。
- **"克隆里没有" = 有覆盖却无证据**：跨断点参考 fragment `ref_span ≥ 10` 才可判 absent，否则 `underpowered`。按 Poisson（λ = 0.6×深度×AF）给检出功效表：克隆性事件（AF 0.5/1.0）≥25× 基本都抓得到；population 里 AF<0.1 的亚克隆抓不稳 ⇒ 只能写"低于约 10% AF 检出下限"。
- **阴性对照窗口本底**：100 个与靶区等长、深度 0.8–1.2× 中位数、可比对性相近的常染色体窗口（固定种子），同一套代码跑 ⇒ "无已知生物学的 21.5 kb 里每样本产出多少假 tier A/B"。**窗口数决定最小可达 p = 1/(N+1)**：N=40 永远到不了 0.01，P41 因此增至 100。
  - ⛔ **窗口必须对所有样本都可估计，并排除 IGH/IGK/IGL/TRA/TRB/TRG/TRD**：P41 只按第一个样本（DLD1）选窗，ctrl36 落在 IGH，13 个 B 细胞系样本因 V(D)J 重排窗口内几乎无正常配对 ⇒ 总控 FATAL 停 4 h 53 min（I-6）。替换单个窗口时**不重跑选窗脚本**（随机种子会让其余 99 个全变），只换那一个并在 Methods 写明。
- `universal`（四个细胞系都出现且 ≥75% 样本）= 参考差异/常见多态/系统性比对假象，**标记不删**。
- **深度是独立证据线**：P41 最终主发现来自 chr11q 10 kb 窗口深度（S04/S05 远端 ≈0.50×、近端 1.2–1.5×），而**不是**任何 tier A/B junction。看到图后才追加的分析必须在报告里写明"不在预先登记的 tier 体系内"。

### D2 — 第二轮 read rescue：先定义 data universe（P44 设计，P45 继承）

> 动机：P41 的区域查询只看"落在窗口里的 record"。**BAM 里没有 secondary record（比对没用 `-a`），多重比对只以 `XA` tag 存在**——本属该位点却被放到别处的 read，区域查询永远找不到。

- **抽取窗口 W** = target ±50 kb（第 1 轮 ±5 kb，扩窗改变 data universe ⇒ 开跑前须用户确认，§2A）；目标区 junction = 一端落在 target ±50 bp。
- **Rescue 集合 R** = 以下任一命中的全部 record（dup、MAPQ0、QC-fail 全保留打标签）：(a) record 在 W；(b) mate 在 W；(c) SA 任一段在 W；(d) **XA 任一 hit 在 W**；(e) 双端 unmapped pair 经 W 序列筛选命中。对 R 中每个 QNAME **取回全部 record**。(b)–(d) 只能**全 BAM 流式扫描**（P44：18 个 BAM，6 并发，每样 ~25–32 min，I/O 限速）。XA 是最大来源（每样本 3,920–7,946 pair）。
- **Stage 1 断言**：W 内无 secondary、无 hard-clip、无缺 SEQ——这是 §2A「SEQ 可用性 ≠ 完整性」的实测落地。
- **竞争性再基因分型**（"after rescue"的定义）：每个 junction 建 400+400 bp alt / ref 模板；read-end 跨 junction 每侧 ≥20 bp，且 **AS_alt ≥ AS_genome + 10 且 ≥ AS_ref + 10** 才计 alt（同一 repeat 拷贝能同样解释的 read 不计）；全部样本用同一模板同一规则分型；fragment 为主、read-end 并列。
- **Secondary 只在 AS ≥ primary AS − 10 时算"竞争 placement"**：rescue 再比对用 `-a` 会产出大量远低于 primary 的局部 hit（S04 W 内 66,300 条），不筛就把噪声当歧义证据。
- **Event grouping**：共享 ≥50% alt read-end 的 junction 合并为一个 event、计数取并集、列出 alternative placements（partner 在端粒重复等多拷贝序列时，同一批 read 能放到 chrX/4/2/10 多个末端）；有 alternative placement 即 Ambiguous。
- **Flank 唯一性**：junction 两侧 100 bp `bwa-mem2 mem -a`，数 AS ≥ best − 10 的 placement。
- **局部组装**只对 ≥2 非 dup fragment 的 cluster：SPAdes `--sc --only-assembler --cov-cutoff off -k 21,33,55`，read 先在 adapter 处截断（≥30 bp）——微小 read 集合下默认 k-mer coverage model 报 exit 64。
- **分级（P44 预注册）**：Well supported（≥3 fragment、≥2 类证据、两侧 flank 唯一、不确定区间 ≤10 bp）/ Limited（≥2 fragment、flank 唯一，但证据不足 Well）/ Ambiguous (repeat) / Weak（1 fragment）/ Not supported after rescue。
- **成果**：P44 找到了 caller 输出里**没有**的两个关键事件——S04 chr11:114,605,216 → (TTAGGG)n 端粒 junction（rescue 前 0 → 后 4 fragment，caller = neither）、S05 376 bp fold-back——两者都落在本样本深度断崖 95% CI 内。平行的候选封闭式分析（P42：从 caller 282 个候选收窄到 C1–C4）两个都漏了。**候选封闭式流程即使后续审计再严，也补不回被排除的证据。**

### D3 — 未 trim 数据的 adapter / poly-G artefact（P44 实测，必做）

- insert 中位 ~160 bp < 150 bp read ⇒ 大量 read 读穿 TruSeq adapter + index + poly-G 尾；**poly-G 尾被比对为 supplementary 到 chr2:32,916,3xx（参考上是纯 poly-G）**。P41 目标区 1,181 个事件里 693 个就是这个"chr2:32.9 Mb 吸附区"。
- 规则：3′ segment 起点 ≥ adapter 起点 − 5 的 split 不计；adapter 在 clip 前 10 bp 内的 3′ clip 不计，更深则只保留 insert 部分（≥20 bp）；segment / clip / discordant mate 的 Shannon entropy < 1.2 bits 判 low-complexity 不计；soft-clip ≥20 bp 才作断点证据。全部计入 filter-impact 表（6 样本试跑删 1,677 条）。
- 复核：`samtools faidx $REF chr2:32916330-32916480`（纯 G）；`samtools view <BAM> chr2:32916340-32916360` 可见 insert + `AGATCGGAAGAGC` + index + polyG。

### D4 — 结论层级与 caller concordance（P45）

- **claim ladder 是 evidence 分级之上的另一列**（`claim_level`，不替换分级）：mapping_observation → repeat_ambiguous_junction → limited_junction_candidate → **well_supported_junction_candidate** → **structurally_coherent**（① chr11 侧断点区间与本样本深度断崖 95% CI 有交集 **且** ② 断崖远端同样本为 LOH：≥90% baseline-het 位点变纯合）→ confirmed（需独立 assay 原始结果；无输入则预期 0，写进 `external_input_status.tsv`，**不当阴性**）。
  - ⚠ 预注册时**每个 evidence 级别都要映射到一个 claim 级别**：P45 v1 漏了 Well supported，2 个 GM12878 共有翼侧 junction 被并入 limited，低估证据强度；补级后 v1 归档。
  - 判据有区分力的实测：S05 chr21 junction 距 S05 断崖 CI ~1 kb ⇒ 不满足 ①；S03 10 bp inversion ⇒ S03 无 LOH，不满足 ②。
- **深度断崖**：200 bp bin，以本样本 chr11:114.40–114.58 Mb 中位数归一再除以基线克隆均值；two-level step + 1,000 block bootstrap 给 95% CI（只抽完整 block，末端截断会让索引长度差 1）。**BAF/LOH**：chr11 联合 `bcftools mpileup -q20 -Q20 --max-depth 1000 | call -mv`，QUAL≥30；BAF 位点 = 基线全部样本 AF 0.25–0.75 且 DP≥10（S04/S05 远端 LOH 0.978/0.980，同一 homolog 保留 99.78%）。
- **4-caller concordance**：Manta、DELLY + GRIDSS（18 样本联合）+ SvABA（DLD1）；主口径两端 ±100 bp + 方向一致，另报最近距离与 ≤50 bp 标志；GRIDSS 单断端（ALT `.`）只记 anchor。**caller 一致 = 同一数据的算法一致，不是独立验证**；这句话在报告 Limitations 写一次即可。
- **P42 的"60× sensitivity gate"不要学**：~15× 数据不可能达到，所有候选"未过 gate"，结论只剩"什么都不能说"。用逐样本检出功效（AF 0.1/0.25/0.5 下 ≥2/≥3 fragment 的 Poisson 概率）替代，让"未检出"读作"在该 AF 以上未检出"。
- **genome-wide 版 clone-specific（客户 A2 要的是全基因组）**：DELLY germline→somatic 流程——合并基线 + 处理样本 discovery sites（`delly merge -y 0 -a 0.05 -v 5`，不预过滤）→ 逐 BAM re-genotype → `delly filter -f somatic` 只打标签不删；逐样本 present = 非参考 GT 且 DV+RV ≥3，absent = alt 0 且 DR+RR ≥10，alt 1–2 = low_support，其余 underpowered。genome-wide SNV/indel：同 chr11 参数按 5 Mb chunk 并行（S01–S10，632 chunk，20 并发约 3 h），**验收 = chr11 记录数与之前单独 chr11 call 完全相同**。

### D5 — 模式 D 专属代码坑（均已实测）

1. ⛔ **pysam 不在 `rec.info` 里暴露 `END`**：`info.get("END", pos)` 永远退回 POS ⇒ 所有 DEL/DUP/INV 变成长度 0 的点事件，caller 第二端永远匹配不上。改用 `rec.stop` 也不够——**DELLY genotyped BCF 的 rlen 写为 1，`rec.stop` = POS**。✅ 从 INFO 原文解析 `END=`。影响：P45 修正后 148 行 Manta/DELLY concordance 升级、G2 的 "with Manta" 计数 6→7。复核：`bcftools view -H -i 'ID=="<id>"' X.bcf | cut -f8 | tr ';' '\n' | grep ^END`。
2. ⛔ **pysam `rec.info.get(k, d)` 对 header 未声明的键抛 `ValueError('Invalid header')`**，不返回默认值。Manta 头里没声明 `CHR2`、DELLY 有 ⇒ 合并多 caller 时只在 Manta 行炸（P41 I-9）。✅ 先判 `k in rec.header.info and k in rec.info`。
3. ⛔ **mosdepth `regions.bed.gz` 列数取决于 `--by`**：整数窗口 → 4 列；带名字的 BED → 5 列。同一脚本里 `split()[3]` 对一类文件对、另一类错（取到窗口名 `w114604099`）。✅ 一律 `split()[-1]` 或 `*_, v`（P41 I-2 / I-9 两个脚本先后因此崩溃；"同类缺陷第二次必须全局 grep"的通用规则见 `project-setup` skill）。
4. **多模式 `grep -o` 会吞并重叠匹配**（引物特异性计数把 1 处计成 0）：每条 query 单独 grep，再用 `samtools faidx` 核对。
5. **bash `local c=$1 o="$O/parts/$c"`**：`$c` 在同一条 `local` 赋值前就被展开 ⇒ 所有分片同名、0 产物。同一条 `local` 里不要引用刚声明的变量。
6. **P41 运行工程事故（I-1…I-9）的通用规则已分别放在**：总控失败告警、`kill -0` 僵尸、心跳、`python -u`、`xargs -r`、日志命名 → `watchdog` skill「自写总控 / 守候脚本的坑」；样本表驱动可追加、冒烟覆盖每个消费者、BAM 随机访问循环默认并行 → `project-setup` skill「Step-script / 总控设计规则」。

### D6 — 模式 D 交付工程（P42/P44 对比后的固定做法）

- **BAM/VCF header 去本机路径并审计**：`@PG CL`、`##commandline` 等含 `/home/` `/mnt/` `/Work_bio` 的行改写（`samtools reheader` / `bcftools reheader`，检查命令用 `--no-PG`/`--no-version` 防止自身再写入路径）；`methods/header_sanitization_audit.tsv` 证明 record 数与 record 流 SHA-256 前后一致。DELLY BCF→VCF 同样出转换审计。
- **机读配套表**：`client_request_coverage.tsv`（客户每个问句 / 每项 deliverable 一行 → 状态 → 证据文件 → 边界）、`external_input_status.tsv`（PCR/FISH 等未提供项及其对解读的影响）、`data_inventory.tsv`（逐文件 bytes/md5/索引）、`key_junction_read_evidence.tsv`（关键事件每条 read end 的 FLAG/坐标/CIGAR/MAPQ/SA/XA/SEQ、模板 AS vs 基因组 AS、dup、query overlap/gap）、`figure_manifest.json`。self-audit 断言：账本行数 = 图中 read 数；表中每个证据文件存在；header 路径 = 0。
- **建议 PCR 就随附引物**：Primer3（flank → junction_overlap 两轮）+ 全基因组逐 query 精确命中计数要求唯一；避开重复单元；端粒 junction 附 STELA 类方案；无法唯一就写"无唯一引物"。
- **客户文字**：不出现内部项目编号（P41/P42…；前一份报告称 "the report dated 2026-10-09"），交付 ID 去内部前缀（`P44J0332` → `J0332`）；限定语只在 §8.3 写全一次；全基因组 BAM 不放进报告包，§9 写明另行传输。
- **复用上一轮产物**：只读复制（不用硬链接），写 `import_manifest.tsv`（源/目标 md5 + 源脚本 md5，并与源项目 git 最新提交比对）；来源脚本快照放 `scripts/<日期>/from_P<NN>/`，改过的版本放本层，可直接 `diff`。

---

## 第六步：analysis_plan_MMDD.md（项目根目录）

含：样本表、模式判断、（模式B）构建体解码表（靶位点+敲入内容+模型解读）、流程步骤、运行命令（按序）、关键参数依据、资源分配、已知局限、待客户确认清单。改版必须重标 MMDD 并更新内部日期、删旧文件（CLAUDE.md 规则）。

---

## 运行顺序（告知用户）

```bash
# 模式B：先建 hybrid 参考
bash scripts/0_build_hybrid_ref.sh
# 1. samplesheet
conda run -n regular_bioinfo python scripts/1_produce_samplesheet.py
# 2. sarek（自动进 tmux，失败自动 resume）
bash scripts/2_run_sarek.sh
# 3. 完成后：模式B 整合/拷贝数/注释
bash scripts/4_integration_analysis.sh
bash scripts/5_copy_number.sh
/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript scripts/6_annotate_breakpoints.R
# 4. 报告
/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript scripts/7_generate_report.R
```

---

## 交付必给清单（清单驱动，与下面的正确性自查是两回事）

**交付前自查查的是"在的东西对不对"，它在原理上抓不到"该有的东西不在"。**
报告的 §8 文件清单表与交付目录**一起漏掉同一件**产物时，"报告提到的路径都存在"这条检查恒为 PASS。
真实事故（2026-08-18 用户发现）：RNAseq 的 proj27/proj28 **都把 count 与 TPM 矩阵漏在
`output_results/` 里没进交付**，客户拿到的只有我们的判读结果、没有能重算的数据；两个项目各七八项
自审检查全部通过。同一路线上 proj19/20 却交对了 —— **清单没写下来时，交对交错纯看运气。**

所以交付前必须再跑一遍**与项目无关的固定清单**（不是从报告里抽路径，那是闭环）：

| 必给 | 来源 | 说明 |
| :--- | :---: | :---: |
| 每样本注释后 VCF `*.vcf.gz` + `.tbi` | sarek `annotation/` | **客户唯一能自行重筛变异的东西**，只给 tsv 不够 |
| 变异表 `*.prioritised.tsv` + 合并 `all_samples.prioritised.tsv` | 注释后筛选脚本 | 人可读版，与 VCF 并给 |
| 覆盖度/比对 QC 汇总 `*.flagstat` `*.samtools_stats` + mosdepth summary | sarek `reports/` | 深度类结论的支撑证据 |
| `multiqc_report.html` + 每样本 fastp html | sarek `reports/` | |
| SV/CNV：manta / tiddit / cnvkit VCF + 基因重叠注释表 | sarek `variant_calling/` | 做了就必给，不能只在报告里写结论 |
| 模式B 另加：断点坐标表、拷贝数比值表、判读图 PDF（**逐张人眼看过**） | 脚本 4/5/6 | |
| 参考基因组/构建体版本说明 | | 客户复现的前提 |

范例（做得对的）：`16_Wenliang_Pan_wgs/custom_research_report_20260717/` —— annotated VCF + tbi +
prioritised tsv + QC + SV/CNV 注释 + HLA + ROH 全给了。

**两条通用判据：**
1. **"数据本身"必给，不能只给"我们的判读"。** 客户要能换阈值、换检验、挑自己关心的对象重算 ——
   只给差异检验表 / 汇总表 = 数据没交。
2. 清单里的每一项还必须**出现在报告 §8 的文件清单表里**；两侧对查，才能同时挡住"目录里有但报告
   没说""报告说了但目录里没有"，以及"两边一起没有"。

---

## 交付前自查（Pre-Delivery Self-Audit，强制，不可省略）

**"脚本跑完没报错" ≠ "结果是对的"**（CLAUDE.md 铁律）。报告/交付前必须实际核对客户会看的输出，而非假设正确：

- **模式A**：看 MultiQC——每样比对率/覆盖度/重复率是否合理，有无某样明显离群（污染/混样信号）；种/株确认类项目核对 flagstat/depth 与预期是否一致。
- **模式B — 整合位点**：每个整合位点是否有**双向证据**（split + discordant 都支持）？定点敲入项目，预期位点（如 Rag2/Htt）是否真的检出结合部？把关键位点在 **IGV 里目视**确认软剪切/discordant 成簇，别只信 caller 的一行输出。
- **模式B — 拷贝数**：数值是否物理合理（定点单敲入应 ~1 拷贝/等位；异常高值先查是否同源区交叉比对虚高，而非直接写进报告）。
- **模式B — 阴性对照自洽**：某品系样本在**别的**构建体 contig 上是否确实近零覆盖？若不是，提示样本混淆或参考问题，查清再交付。
- **模式C**：mapping rate 是否 >85%（物种确认）；DHFR/侧翼比值落在哪个株系区间、与客户声称是否一致；未比对比例是否显著（>0.5%）；BLAST 命中的载体/元件是否自洽（如 dCas9/EASE 等），零命中的长 contig 是否已在报告里列为"疑似专有序列请客户核对"。
- **模式D**：阴性对照窗口每样本平均 tier A 是否 >0.5（是 ⇒ 阈值偏松，报告如实写）；每个 absent 是否 `ref_span ≥ 10`；关键事件逐 read 账本与图中 read 数相等；交付 BAM/VCF header 本机路径计数为 0；claim_level 每个 evidence 级别都有映射；客户文字无内部项目编号。
- **样本身份**：任何带"品系/分组标签 + 样本名"的图表，交付前程序化核查标签与样本真实对应（不靠肉眼），参照 rnaseq skill 的热图断言习惯。
- **数字离群即停查**：某样/某位点的指标与同类差异悬殊，是数据问题的信号，不是可直接写进报告的结果。

---

## 报告（客户交付，CLAUDE.md 规范）

- **英文**，文件名 `<ProjectName>_MMDD.md`，交付文件夹 `custom_research_report_YYYYMMDD/`，内部按分析类型分子文件夹（`qc/` `alignment/` `integration/` `copy_number/` `variant_calling/` 等），源文件**拷贝**入内。
- 结构（2026-08-18 起）：1 Objectives / **2 Core Conclusions（逐克隆「该怎么办」，大白话，第一重要）** / 3 Key Findings（逐主题「测出了什么」）/ 4 Sample Information / 5 Analysis Rationale & Decision Criteria / 6 Methods（工具版本参数）/ 7 Results（带数值证据）/ 8 **Conclusions, Limitations and Next Steps**（8.1 逐克隆表 / **8.2 Practical reading = §2 详版，每条挂证据出处** / 8.3 Limitations / 8.4 Suggested confirmation）/ 9 Deliverable Files。
  **§2 与 §8.2 一简一详，两者都必须在**；改章节号必须跑引用检查（`29_.../scripts/39_check_report_sections.py`）。详见 CLAUDE.md。
- **模式C 报告范本**：`3_cho_wgs_species_confirm/custom_research_report_20260626/WGS_Analysis_Report_wt1_0626.md`。其第 4 节"Analysis Rationale & Decision Criteria"把每步的科学依据 + 判据阈值表写得很到位（为何比对定物种、为何 DHFR 定株系、为何 host-subtraction、为何组装而非直接 BLAST）——模式C 报告照此写。子文件夹：`qc/` `species_strain/` `transgene/`。
- **PCA 图若含在交付里必须用文字解读**（PC1/PC2 方差 % + 组内 vs 组间距离量化，不许只放图）；其他图按需解读。
- **报告绝不含**：`.rds`/中间对象、内部调试叙事（那些进自用 `analysis_plan`，不进客户报告）。
- 签名：`Zhen Gao, PhD, Principal Bioinformatics Scientist, Athenomics`

### ⭐ 报告不直接写进交付目录 —— 源文件 + 占位符 + 交付脚本重打日期（2026-08-18 起，新项目一律照此）

WGS 报告是大段散文推理，不像 RNAseq 能由 `6_generate_research_report.R` 拼出来，
所以过去都是**手写 .md 直接落进交付目录**（14/16/26 都是）。这样做交付日期就散在三处、
只能靠人记得——**proj27 0809 就因此漏改一处、新建出第二个交付目录，用户一直读的是旧的那份**。
结构如下，让手写报告也能被脚本重打日期：

```
docs/_client_report_source.md          ← 报告唯一真源，手写；日期处写 @@REPORT_DATE@@
scripts/<N>_build_delivery.sh <DATE>   ← 交付日期是**参数**，一条命令三处同时重打
custom_research_report_<YMD>/<Name>_<MMDD>.md   ← 生成物，绝不手改
```

脚本要点（范例：`29_Keqiang_Xie_wgs_5_vectors/scripts/35_build_delivery.sh`）：

```bash
DATE="${1:-$(date +%F)}"; YMD="${DATE//-/}"; MMDD="${YMD:4:4}"
# 已存在交付目录一律 mv 改名，**不新建第二个**（proj27 事故）
existing=$(find "$ROOT" -maxdepth 1 -type d -name 'custom_research_report_*' | head -1)
[[ -n "$existing" && "$existing" != "$DELIV" ]] && { mv "$existing" "$DELIV"; mv 旧 .md "$DELIV/$REPORT"; }
sed "s/@@REPORT_DATE@@/$DATE/g" "$ROOT/docs/_client_report_source.md" > "$DELIV/$REPORT"
```

硬校验（任一不满足即 `exit 1`）：**交付目录恰好 1 个**；目录里 `*.md` **恰好 1 个**（防旧日期报告残留）；
`Report Date` 那行**含且仅含**本次日期；**无残留 `@@REPORT_DATE@@`**；交付物无中文、无自绘 PNG。

⚠ **不能在源文件里写任何说明性注释** —— 它被逐字拷进交付包（只替换占位符），
注释会出现在客户报告里（HTML 注释也一样，文本编辑器打开就看得见）。
⇒ 该文件的功能说明写进 **`docs/README.md`**（`docs/` 下每个文件一行的索引），
范例：`29_Keqiang_Xie_wgs_5_vectors/docs/README.md`。

⚠ **只适用于新项目。已交付的老项目（13/14/16/26）一律不动**——报告早已发出，改了客户也看不到。

---

## 注意事项（每次执行均检查）

1. **锁定 sarek `-r 3.8.1`**；`--skip_tools baserecalibrator`（无 known-sites + NovaSeq）。
2. **模式B 必须跑 hybrid 参考**，绝不跑 stock 基因组——否则测不到整合位点、且要重比对，白跑一趟。
3. **一个合并 hybrid 参考跑全部样本**，自带跨品系阴性对照。
4. **定点 vs 随机先判断**（看构建体有无小鼠同源臂），决定分析问题的重心。
5. **线程 ≤56 / 物理核 ≤28**；sarek `queueSize=2` **仅适配比对阶段**——variant-calling（HC scatter）阶段务必改非绑定 queueSize + `executor.cpus/memory`（见「模式A germline 教训」,否则 HC 阶段严重欠载）；`samtools sort -m` 是 per-thread，先 `free -h`。
6. **tmux 保护**：所有 >1 分钟命令在 tmux 内跑；长任务用 tmux 而非 Bash 后台模式。
7. **早期失败检测**（CLAUDE.md）：启动后前 3 分钟主动轮询日志查 error/traceback/OOM，别被动等成功信号。
8. **Rscript 用直接路径** `/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript`（`conda run` 有挂起 bug）；日志 `> log 2>&1` 不用 `| tee`（掩盖退出码）。
9. **构建体拷贝数**走 mosdepth 深度比值，不用 sarek CNV 模块。
10. **无纯 WT 对照时**：自身单拷贝基线 + 品系互为阴性对照；可建议客户补送一只 WT 强化基线。（⛔ **切勿** 用 `--use_gatk_spark markduplicates` 提速——见实测教训,是净倒退陷阱。）
11. **代码与可见文件同步**（CLAUDE.md）：实际命令一变，脚本/notebook 同一响应内更新。
12. **裸布尔 CLI flag 变字符串坑 —— sarek 3.8.1 大概率不受影响，但换新模板时注意**：新版 Nextflow 把裸 `--flag` 解析成**字符串 `"true"`**、被现代 nf-core 的严格 nf-schema 拒（`Value is [string] but should be [boolean]`），实测在 **nf-core/mag（现代模板 + Nextflow 26.04.4）** 上全灭（proj17）。**sarek 3.8.1 是旧模板（`check_max`/`--max_cpus` 时代，无严格 nf-schema），此坑基本不咬**——现有 sarek 流程照旧。但若**升级 sarek 到现代模板、或本机换用 mag/taxprofiler 等现代 nf-core 管线**，一律**优先 `-params-file`（YAML 真布尔）传参**。全解见 `facilities/Server/nextflow_pipeline/nextflow_bare_bool_flag_变字符串_坑_0719.md`。
13. **worked example**：`13_Ellen_knockin_wgs/`（模式B 定点敲入，RAGH=Rag2 人源化细胞因子 / MTTH=人源 HTT）；`4_wgs_human_immu/`（模式A sarek 安装与 test-profile 验证）；`3_cho_wgs_species_confirm/`（模式C CHO 细胞系物种/株系确认 + 转基因盲鉴，含完整判据报告）；`41_Vedict_18_wgs/` → `45_Vedita_18_wgs_combined_Advanced/`（模式D 重复区位点 SV，初报 + read rescue 合并版）。

## 实测教训（13_Ellen 首跑 2026-07-07，正式跑直接采用；详见该项目 `docs/试跑经验与教训_0707.md`）

- **Manta 在 CRAM 上病态慢**（单样 >7h，remote-read-retrieval 每 edge ~60s）。混合参考/敲入项目**别让 sarek 里的 Manta 直接吃 CRAM 全基因组**：改 `--tools tiddit` 去掉 manta，整合靠**嵌合读段法(脚本4A)**（不靠 Manta 就能检出）+ DELLY；非要 Manta 则先 CRAM→BAM 或 `--callRegions` 限定。
- **GATK4 MarkDuplicates 近单线程慢**（单 WGS 样 ~3.5h）——**接受它，别用 Spark "提速"**。可选 `--skip_tools fastqc` 每样省 ~30m。
- **⛔ `--use_gatk_spark markduplicates` 是 germline WGS 的净倒退陷阱（proj16 实测 2026-07-16，代价 ~15h）**。两个独立的坑叠加：

  1. **Spark markdup 不产 duplicate metrics** → sarek 自动补一个单线程 `GATK4_ESTIMATELIBRARYCOMPLEXITY`。proj16 实测跑了 **6.3h 仍在减速**（~40 groups/min，内存 thrashing），且在 `queueSize=2` 下霸占全部 slot → 变异检测被堵死、~53 核空转。省下的 markdup 时间被 ELC 连本带利吃回去。
  2. **该 flag 会改写 `BWAMEM2_MEM` 自己的命令行**（Spark 需 queryname-sorted 输入 → `samtools sort -n`，常规 markdup 则无 `-n`）。script 文本变 → task hash 变 → **一开一关都会让整个比对阶段缓存全废**。proj16 实测：加 Spark 时废掉已完成的比对、去 Spark 时 24 个比对**只命中 1 个 cache**，两个方向各赔一次 ~4.5h 重比对。

  - **判据：`-resume` 只对"不改 script 文本"的改动便宜。** 改 `cpus`/`memory` 这类 directive 安全；改会进入 `.command.sh` 的 flag（Spark 开关、`ext.args`、`--aligner`）= 上游全部重跑。改前先 `diff` 新旧 work dir 的 `.command.sh` 确认影响面，别假设"上游能复用"。
  - **默认就用常规 `GATK4_MARKDUPLICATES`**（proj4/proj13 已验证路径）：单线程但有界、可预期、metrics inline、无 ELC。只有在真有 Spark/GPU 集群、且小样本验证过之后才考虑。
- **⛔ contig 改名的 `MT`→`chrM` 陷阱（proj16 实测 2026-07-16）**：ClinVar 官方 VCF 用 Ensembl 命名（`1,2,…,X,Y,MT`），叠到 GATK.GRCh38 calls（`chr1,…,chrM`）前要 `bcftools annotate --rename-chrs` 改名。**顺手写的 `for c in $(seq 1 22) X Y MT; do echo "$c chr$c"; done` 会产出 `chrMT`，而 GATK.GRCh38 的线粒体 contig 叫 `chrM`** → 全部 **3,125 条 mito ClinVar 注释静默丢失**（`bcftools annotate` 对 contig 不符不报错、只是零命中）。正确：`{ for c in $(seq 1 22) X Y; do echo "$c chr$c"; done; echo "MT chrM"; }`。
  ⚠ **这里原写「gnomAD af-only 本身已 `chr`-prefixed，无需改名」—— 2026-09-12 删除该表述**：它读起来像在背书用 `af-only-gnomad` 做频率注释，而那是错的，见下一条。
  - **通用判据（不止 ClinVar）**：**任何跨 DB 注释/改名操作，事后必须验产物、不能只看退出码 0** —— (a) 验一条目标 contig 上的记录拿到**非空**注释（零注释和"该位点本就没注释"在输出里长得一模一样）；(b) 改名类操作核对**总记录数守恒**（`bcftools index -n` 新旧对比）；(c) **边缘 contig（MT/chrM、chrY、alt/decoy）是命名分歧高发区**，主染色体 24/25 全对不代表没问题。
  - **光读源码看不出来**（`chr$c` 语法完全正确）——必须 `tabix -l` 列出产物实际 contig 名，与参考 `.fai` 对照。
- **⛔⛔ 罕见性判据：不许用 `af-only-gnomad.hg38`，不许把 `absent` 当 `rare`（proj36 实测 2026-09-12，起因是已交付产物出问题）**
  - **事故规模**：proj16 交付的 `prioritised.tsv` 里，标 `gnomAD_AF=absent`（⇒ 判罕见 ⇒ 进候选名单）的位点中
    **70.1% / 72.2%（A/B 样本）其实在同一个 VCF 的 VEP `CSQ` 里就有 gnomAD v4.1 频率**，
    其中 **2,171 / 2,257 条是 AF > 0.01 的常见多态** —— **交付的候选名单里约一半是常见多态**。
  - **根因是两句各自都对的话拼起来**：① 注释用 `bcftools annotate` + `af-only-gnomad.hg38`；
    ② 过滤写 `rare = (af != af) or (af < RARE_AF)  # nan -> absent -> rare`。
    `/Work_bio/references/.../af-only-gnomad.hg38.vcf.gz` 是 **2017-08 用 GATK 3.7 从 hg19 liftover 的
    Mutect2 germline resource**（gnomAD v2 时代、且 `af-only` 本就是子集）。**它查不到 ≠ gnomAD 里没有。**
  - **✅ 正确做法**：
    1. **罕见性判据直接用 VEP `CSQ` 的 `gnomADe_AF` / `gnomADg_AF`** —— sarek 的 VEP 已用正确版本算好，零额外成本；
       字段序号**从该 VCF 自己的 header 读**，不要硬编码（VEP 版本变了顺序就变）。
    2. 若确实要自己 annotate：用 **gnomAD v4 正式 VCF**，且先 `bcftools norm -m -any -f <ref>` 拆多等位 + 左对齐
       （表示法不同就匹配不上：`TAAA>TAAAA` 在 gnomAD 里存成 `T>TA`）。
    3. **`absent` 不得等同于 `rare`** —— 区分「查过且确实不在库中」与「没查到/没查」；后者是缺失值，不是结果。
    4. `af-only-gnomad.hg38` **只用于 Mutect2 的 `--germline-resource`**，不作任何频率判据。
  - **强制门禁（注释后必跑，4.4 秒）**：查 `INFO/gnomAD_AF` 与 `CSQ` 是否自相矛盾 ——
    proj16 实测 chr22 96,188 个变异里 **29,422 个（30.6%）** INFO 为空而 CSQ 有值。
    完整命令与判据见 `~/Utilities/software_pitfalls/gnomad_af_only_rarity.md`。
  - **为什么交付前自审抓不到**：`bcftools annotate` 匹配不上**不报错**，只是不写值 ⇒
    「本就不在库中」与「我们没匹配上」在输出里**逐字节相同**（都是 `.`）；行数/列名/文件大小/退出码全部正常。
- **同源臂遮蔽（定点敲入必做）**：构建体的小鼠同源臂与内源位点全同→多重比对。拷贝数/整合**只在人源特异区算、遮蔽同源臂、MAPQ≥20**；否则拷贝数被严重低估（实测全长 0.08 vs 人源区真实 0.60），且内源直系同源位点会冒出假整合信号。
- **高深度 artifact 黑名单**：候选整合位点过滤深度 > 基线×5 的塌缩重复位点（实测 chr1:78.58Mb 达基线 29×）。
- **实测耗时(单样~19×,不含Manta) ~7h**：bwa-mem2 建索引 45m/61GB、比对 22m、MarkDup 3.5h、TIDDIT 1.3h。6 样 queueSize=2 约 ~21h。

### 模式A germline + 下游注释/HLA/origin 教训（proj16 实测 2026-07-17）

- **⚠ `queueSize` 是相位相关的：按 alignment 配的值会卡死 variant-calling（HC scatter）阶段。** `queueSize=2` 适配比对阶段（2 样 × BWAMEM2@16cpu = 32 threads），但流程进入 HaplotypeCaller scatter 后 task 形态反转成几十个 ~2-thread 的 interval 小任务 → 实测 **2 RUNNING / 54 queued，56 线程只用 ~4.4、load 4.2、110GB RAM 闲置**（同 proj14 Study B 的 queueSize 节流）。
  - **修法**：HC 阶段把 `queueSize` 设为**非绑定**（如 24），真正的闸门交给 `executor.cpus` + `executor.memory`，并按**实测**per-task 用量声明。关键:HC 继承 sarek `base.config` 的 `withLabel:process_low`（cpus 2 / **memory 12GB**），但实测 peak RSS 仅 **~4.7GB** → local executor 是**按声明 memory 算并发**的,**虚高的 memory（不是 cpus）才是抬 queueSize 后的真天花板**。用 `withName:'.*HAPLOTYPECALLER.*'{ cpus=2; memory=10.GB }`（仍 2× 实测余地）。
  - **`-resume` 缓存判据（复述 Spark 教训的正面）**：改 `cpus`/`memory` 这类 **directive 不进 task hash**，安全——proj16 实测降 HC memory 改写了 `-Xmx`,但已完成的 HC 仍命中 cache。只有改会进 `.command.sh` 的 flag 才废缓存。所以**限流可安全热修 + `-resume`**：改 config → kill tmux → 重启,alignment/markdup 全部命中 cache。
- **⚠ 下游脚本的 `conda run` 子进程隔离两坑（详见 memory `reference_conda_run_subprocess_pitfalls`）**：
  1. **进程替换失效**：`conda run bcftools annotate -h <(echo '##INFO=...')` → `Failed to open /dev/fd/63`。conda-run 子进程继承不到父 shell 的 `/dev/fd`。改写 `mktemp` 真实临时文件 + `trap 'rm -f' EXIT`。
  2. **跨两个 conda-run 的管道 BrokenPipe**：`conda run samtools collate -Ou X | conda run samtools fastq ...` → `BrokenPipeError`。改成 collate 落盘再 fastq,不跨进程 pipe。
  - 通用规避：一段带 pipe/进程替换的逻辑用**一次** `conda run bash -c '整段'` 包起来,别对每条命令单独 `conda run`。
  - 附带坑:sarek 的 VEP 产物是大写 `_VEP.ann.vcf.gz`,`find` 用 `-iname` 大小写不敏感,否则漏匹配 fallback 到未注释件。
- **⛔ 下游任何吃 CRAM 的步骤（HLA 提取、origin 等）必须用 sarek 建 CRAM 的【同一个】参考**：GATK.GRCh38 建的 CRAM 用别的 GRCh38 build（如 gencode `GRCh38.primary_assembly.genome.fa`）解码 → **`@SQ M5` checksum 不匹配,`samtools view` 直接 abort**（`cram_decode_slice` 报 CRAM vs Ref 的 M5）。把 sarek 下载的 `Homo_sapiens_assembly38.fasta` 持久化,下游全部指向它;用前核对参考 `.dict` 的 chr1 M5 与 CRAM header 一致。
- **HLA typing（T1K）建索引 + 调用的坑（proj16 连踩 4 个）**：
  - 建索引：`t1k-build.pl --download IPD-IMGT/HLA -o <dir> --prefix hlaidx`。`t1k-build.pl` 在 env 的 **`bin/`（在 PATH 上）,不在 `share/`**;`-d` 是 EMBL-ENA **dat 文件路径**,不是关键字 "hla"（写 `-d hla` 建不出任何东西,留下**空索引目录**);默认 prefix 随 `-o` 文件夹名 → 必须 `--prefix hlaidx` 才对得上 run-t1k 的 `-f`。
  - 调用：run-t1k 的 `-o` 是**文件名前缀（basename）**,`--od` 才是目录;给 `-o` 传全路径 + `--od` 会把目录**拼两遍**。数据是 WGS 用 **`--preset hla-wgs`**（非 `hla`）。
  - 症状对照:空索引 → fastq-extractor 报 **"Need to use -f to specify the reference sequence"**（其实是 `-f` 指向的空文件),别被误导去查 `-f` 语法。
- **⛔ origin/aneuploidy 从 cnvkit `.call.cns` 读拷贝数必须【按列名】读 `cn`**：`.call.cns` 第 5 列是 `log2`（浮点、几乎不等于 2）,第 6 列才是整数 `cn`。**误读 `$5` 当 CN → `cn!=2` 恒真 → `aneuploidy_frac` 恒为 1.000 → 假结论 "high-aneuploidy cell-line"**。proj16 交付前自查抓到,修正后真值 0.10/0.05（90-95% 二倍体、primary/germline）——**方向 180° 翻转**。用 `.call.cns`（有 cn 列）不用 pre-call `.cns`;awk 按 header 名定位 cn 列。这是"结论级数字离群（1.000 一眼可疑）必须查证"的活教材。
- **下游编排链要接告警**：sarek 看门狗作用域只到 nextflow run,下游编排器（annotate/HLA/origin）软失败会静默（`ALL_DONE`≠每步成功）。交付前自查必须**实际打开下游产物目录确认非空**。详见 `facilities/Server/monitoring_alerting/看门狗运行情况汇总_喂skill_0717.md`。


---

## 拆步骤设计（原在 CLAUDE.md，2026-08-30 搬入）

- Pipeline design — SPLIT INTO INDEPENDENT STEPS (MANDATORY):
  - **General principle (applies to ALL analysis types, not just WGS):** for
    long-running / large-memory multi-stage jobs, prefer splitting into independent
    sequential steps over a single long pipe. A 2-stage pipe is acceptable (e.g.
    `bwa mem | samtools sort`); avoid pipes of 3+ stages — especially when an early
    stage's output (e.g. a QC report) would be lost entirely if a later stage crashes.
    The WGS `fastp | bwa | samtools` rule below is the concrete instance of this.
  - **Never chain fastp | bwa | samtools into a single 3-way pipe.** This is a
    fundamental design mistake:
    1. If any stage fails, ALL output (including QC files) is lost.
    2. All three processes run simultaneously, making memory prediction impossible.
    3. 3-way pipes create complex inter-process blocking that triggers futex deadlocks.
    4. fastp writes its HTML/JSON report only when it exits — so if bwa or samtools
       crash, the client gets zero QC output despite hours of compute.
  - **Correct approach: 3 separate sequential steps, each in its own tmux:**
    - Step 1 (tmux cho_fastp): `fastp -i R1 -I R2 -o filt_R1.fq.gz -O filt_R2.fq.gz`
      → QC HTML/JSON available immediately on completion; checkpoint saved to disk.
    - Step 2 (tmux cho_bwa): `bwa mem | samtools sort` — only a 2-way pipe, far
      more stable; reads from Step 1 output files.
    - Step 3 (tmux cho_index): `samtools index` — trivial, sequential.
  - **With separate steps, threads CAN be higher because resource use is predictable:**
    - Step 1 fastp alone: `-w 8` (no pipe pressure, pure I/O+CPU)
    - Step 2 bwa mem alone: `-t 20` (2-way pipe only; bwa -t 8 rule was forced by
      the 3-way pipe complexity; a clean 2-way pipe is more tolerant)
    - Step 2 samtools sort: `-@ 8 -m 8G`
    - Each step uses only what it needs; no thread budgets add up across stages.


---

## 从 CLAUDE.md 搬入（2026-08-30，逐字未改）

> 分层重构时核查发现：本 skill 原有内容**并未完整覆盖**这几节（实测 26%–62%），
> 故把 CLAUDE.md 里的原文整块搬来。与上文若有重叠，**以本节为准（更全）**。

- Resource allocation — GENEROUS BUFFERS, VERIFY PER-THREAD MATH (MANDATORY):
  - `samtools sort -m` is **per-thread** memory, NOT total.
    Total = `-m × (threads + 1)`. With `-@ 8 -m 8G` → 9 × 8G = 72G. Always verify
    available RAM (`free -h`) before setting `-m`.
  - Give sort enough memory to minimise tmp file count (each flush-to-disk = one
    more merge step = one more opportunity for deadlock).
  - **Proven safe defaults for bwa-mem WGS pipelines on this server (3-step design):**
    - Step 1 fastp: `-w 8`
    - Step 2 bwa mem: `-t 20`, samtools sort: `-@ 8 -m 8G` (72G total, check RAM)
    - Step 3 samtools index: `-@ 8`
  - **Do not kill a running job unless it is confirmed deadlocked** (all processes
    on `futex_wait_queue` via `/proc/PID/wchan` AND log mtime frozen >15 min).
    Killing a healthy but slow job destroys hours of irreplaceable intermediate
    work. Verify deadlock first, then restart.
