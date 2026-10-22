---
name: wgs
description: "Use when 用户要搭建 WGS 分析——种系变异检出(sarek)、转基因/定点敲入整合分析、或细胞系株系鉴定+转基因发现"
disable-model-invocation: true
---

# /wgs — Whole-Genome Sequencing Analysis Setup Skill

> **📍 关联文件组｜项目14「load-152 资源事件」四联档（2026-07-13）** — 以下四份内容互补、共享同一组实测数据，看到任意一份即可定位其余三份（绝对路径，一年后依旧可寻）：
> 1. **根因深挖**：`/home/gao/projects_2026H2/14_geneedit_lats12_wgs/docs/resource_pressure_incident_0713.md` — CNNScoreVariants 超订致 load 峰值 152 的逐层分析 + 配置修正
> 2. **项目14全程负载画像**：`/home/gao/projects_2026H2/facilities/Server/nextflow_pipeline/project14_load_profile_0713.md` — Study A+B 全程峰值/空闲/负载分布
> 3. **wgs skill**：`/home/gao/.claude/skills/wgs/SKILL.md` — CNN 是隐藏 CPU 大户的警告，写入资源 config 节
> 4. **corun skill**：`/home/gao/.claude/skills/corun/SKILL.md` — 哪些阶段可并跑 / 哪些绝对不行 的速判矩阵

为当前项目搭建 WGS 分析代码。覆盖三种模式，先判断项目属于哪一种（或组合）：

- **模式 A — 标准种系 WGS**：nf-core/sarek → 比对/QC/去重 → SNV/indel（HaplotypeCaller/DeepVariant/Strelka）→ SV/CNV（Manta/TIDDIT）→ 报告。用于质量评估、变异检出。参考已验证实现：`4_wgs_human_immu/`。
- **模式 B — 转基因/定点敲入整合分析（构建体已知）**：混合参考（hybrid ref）→ 比对 → 整合位点/结合部检测（Manta/DELLY + 嵌合读段）→ 拷贝数（mosdepth 深度比值）→ 脱靶筛查 → 断点注释 → 报告。参考已验证实现：`13_Ellen_knockin_wgs/`。
- **模式 C — 细胞系种系/株系鉴定 + 转基因发现（构建体未知）**：轻量 bwa 比对 → 物种确认（mapping rate）+ 株系鉴定（标志位点拷贝数）+ 转基因**发现**（host-subtraction：未比对读段 de novo 组装 + BLAST）→ 报告。用于表达系统/细胞系身份确认与外源序列盲鉴。参考已验证实现：`3_cho_wgs_species_confirm/`（CHO 细胞系）。

> **关键分叉一：转基因"构建体已知"还是"未知"？**
> - **已知**（有质粒图谱/等位基因序列）→ **模式 B**：建混合参考、精确定位整合。
> - **未知**（只知道"可能转了东西"，无序列）→ **模式 C**：host-subtraction 盲鉴——把未比对读段组装后 BLAST，能查出转了什么，无需事先拿到载体图。
> **关键分叉二（模式 B 内）：随机转基因 vs 定点打靶敲入**：解析构建体序列，两侧有宿主基因组同源臂 → 定点打靶（整合位点已知，核心是验证 on-target/脱靶/拷贝数/合子型/Neo）；无同源臂 → 随机整合（靠嵌合读段找位点）。

---

## 第一步：信息收集

读取样本表（CSV/xlsx），确认：

| 参数 | 确认方式 |
|:---|:---|
| 项目根目录 | 从当前工作目录推断，或请用户确认 |
| 样本表路径 | 用户提供，或在项目根目录查找 |
| FASTQ 数据目录 | 读样本表后确认实际路径 |
| 物种 | Mouse / Human / CHO / 其他（决定参考基因组；模式C 可能就是"待确认物种"） |
| 分析模式 | A 标准种系 / B 整合分析(构建体已知) / C 细胞系鉴定+转基因发现(构建体未知) / 组合 |
| （模式B）构建体序列 | **头号 blocker**：客户的载体/等位基因序列（GenBank/FASTA/SnapGene .dna）；随机转基因需质粒全序列，定点敲入需带同源臂的等位基因序列 |
| （模式C）候选物种/株系 | 客户声称的细胞系身份（如 CHO-K1）；用于选参考、定株系标志位点。**无需构建体序列** |
| （模式C）reads 用量 | **默认全量**（株系鉴定客户要求全量、深度结论不可抽样）；**主动提供** 5M 子集"快速预览"作为赶时间选项，但预览不作交付结论 |
| 对照 | 有无纯野生型（WT）；模式B若无 WT，用"样本自身单拷贝基线 + 品系互为阴性对照" |
| （模式A）germline / somatic | 纯 germline 还是 tumor-normal 配对 |
| 交付物重心 | 与客户确认目标（整合验证/拷贝数/脱靶/合子型/Neo/变异检出／物种株系确认／转基因盲鉴），决定报告侧重 |

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

| 工具 | 位置 | 用途 |
|:---|:---|:---|
| nextflow / nf-core / docker / singularity | regular_bioinfo（项目4已验证） | 跑 sarek |
| nf-core/sarek | **锁定 `-r 3.8.1`** | 标准骨架引擎 |
| bwa-mem2 / bwa / samtools / bcftools / blastn / minimap2 / seqkit / fastp | regular_bioinfo | 比对/处理/建参考/比对构建体 |
| mosdepth 0.3.14 / delly 2.3.0 | regular_bioinfo | 深度/SV |
| manta 1.6.0 | **独立 `manta` 环境**（py2，勿装进 regular_bioinfo） | SV/整合结合部 |
| Biopython | regular_bioinfo | 解析 SnapGene `.dna`（`SeqIO.read(f,'snapgene')`） |
| megahit / blastn / bwa / bedtools | regular_bioinfo | **模式C**：host-subtraction 组装 + nt 同源搜索 |

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
  | DHFR/侧翼比值 | 株系 |
  | :--- | :---: |
  | <0.05（且覆盖<5%） | CHO-DG44（DHFR 纯合缺失） |
  | 0.05–0.35 | CHO-DXB11（杂合缺失） |
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

## 交付前自查（Pre-Delivery Self-Audit，强制，不可省略）
**"脚本跑完没报错" ≠ "结果是对的"**（CLAUDE.md 铁律）。报告/交付前必须实际核对客户会看的输出，而非假设正确：

- **模式A**：看 MultiQC——每样比对率/覆盖度/重复率是否合理，有无某样明显离群（污染/混样信号）；种/株确认类项目核对 flagstat/depth 与预期是否一致。
- **模式B — 整合位点**：每个整合位点是否有**双向证据**（split + discordant 都支持）？定点敲入项目，预期位点（如 Rag2/Htt）是否真的检出结合部？把关键位点在 **IGV 里目视**确认软剪切/discordant 成簇，别只信 caller 的一行输出。
- **模式B — 拷贝数**：数值是否物理合理（定点单敲入应 ~1 拷贝/等位；异常高值先查是否同源区交叉比对虚高，而非直接写进报告）。
- **模式B — 阴性对照自洽**：某品系样本在**别的**构建体 contig 上是否确实近零覆盖？若不是，提示样本混淆或参考问题，查清再交付。
- **模式C**：mapping rate 是否 >85%（物种确认）；DHFR/侧翼比值落在哪个株系区间、与客户声称是否一致；未比对比例是否显著（>0.5%）；BLAST 命中的载体/元件是否自洽（如 dCas9/EASE 等），零命中的长 contig 是否已在报告里列为"疑似专有序列请客户核对"。
- **样本身份**：任何带"品系/分组标签 + 样本名"的图表，交付前程序化核查标签与样本真实对应（不靠肉眼），参照 rnaseq skill 的热图断言习惯。
- **数字离群即停查**：某样/某位点的指标与同类差异悬殊，是数据问题的信号，不是可直接写进报告的结果。

---

## 报告（客户交付，CLAUDE.md 规范）
- **英文**，文件名 `<ProjectName>_MMDD.md`，交付文件夹 `custom_research_report_YYYYMMDD/`，内部按分析类型分子文件夹（`qc/` `alignment/` `integration/` `copy_number/` `variant_calling/` 等），源文件**拷贝**入内。
- 结构：1 Objectives / 2 **Key Findings**（3–5 条大白话结论前置）/ 3 Sample Information / 4 Analysis Rationale & Decision Criteria / 5 Methods（工具版本参数）/ 6 Results（带数值证据）/ 7 Conclusions（表格）/ 8 Deliverable Files。
- **模式C 报告范本**：`3_cho_wgs_species_confirm/custom_research_report_20260626/WGS_Analysis_Report_wt1_0626.md`。其第 4 节"Analysis Rationale & Decision Criteria"把每步的科学依据 + 判据阈值表写得很到位（为何比对定物种、为何 DHFR 定株系、为何 host-subtraction、为何组装而非直接 BLAST）——模式C 报告照此写。子文件夹：`qc/` `species_strain/` `transgene/`。
- **PCA 图若含在交付里必须用文字解读**（PC1/PC2 方差 % + 组内 vs 组间距离量化，不许只放图）；其他图按需解读。
- **报告绝不含**：`.rds`/中间对象、内部调试叙事（那些进自用 `analysis_plan`，不进客户报告）。
- 签名：`Zhen Gao, PhD, Principal Bioinformatics Scientist, Athenomics`

---

## 注意事项（每次执行均检查）
1. **锁定 sarek `-r 3.8.1`**；`--skip_tools baserecalibrator`（无 known-sites + NovaSeq）。
2. **模式B 必须跑 hybrid 参考**，绝不跑 stock 基因组——否则测不到整合位点、且要重比对，白跑一趟。
3. **一个合并 hybrid 参考跑全部样本**，自带跨品系阴性对照。
4. **定点 vs 随机先判断**（看构建体有无小鼠同源臂），决定分析问题的重心。
5. **线程 ≤56 / 物理核 ≤28**；sarek `queueSize=2`；`samtools sort -m` 是 per-thread，先 `free -h`。
6. **tmux 保护**：所有 >1 分钟命令在 tmux 内跑；长任务用 tmux 而非 Bash 后台模式。
7. **早期失败检测**（CLAUDE.md）：启动后前 3 分钟主动轮询日志查 error/traceback/OOM，别被动等成功信号。
8. **Rscript 用直接路径** `/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript`（`conda run` 有挂起 bug）；日志 `> log 2>&1` 不用 `| tee`（掩盖退出码）。
9. **构建体拷贝数**走 mosdepth 深度比值，不用 sarek CNV 模块。
10. **无纯 WT 对照时**：自身单拷贝基线 + 品系互为阴性对照；可建议客户补送一只 WT 强化基线。
11. **代码与可见文件同步**（CLAUDE.md）：实际命令一变，脚本/notebook 同一响应内更新。
12. **worked example**：`13_Ellen_knockin_wgs/`（模式B 定点敲入，RAGH=Rag2 人源化细胞因子 / MTTH=人源 HTT）；`4_wgs_human_immu/`（模式A sarek 安装与 test-profile 验证）；`3_cho_wgs_species_confirm/`（模式C CHO 细胞系物种/株系确认 + 转基因盲鉴，含完整判据报告）。

## 实测教训（13_Ellen 首跑 2026-07-07，正式跑直接采用；详见该项目 `docs/试跑经验与教训_0707.md`）
- **Manta 在 CRAM 上病态慢**（单样 >7h，remote-read-retrieval 每 edge ~60s）。混合参考/敲入项目**别让 sarek 里的 Manta 直接吃 CRAM 全基因组**：改 `--tools tiddit` 去掉 manta，整合靠**嵌合读段法(脚本4A)**（不靠 Manta 就能检出）+ DELLY；非要 Manta 则先 CRAM→BAM 或 `--callRegions` 限定。
- **GATK4 MarkDuplicates 近单线程慢**（单 WGS 样 ~3.5h）。可 `--use_gatk_spark markduplicates` 提速（Spark 先小验证）。可选 `--skip_tools fastqc` 每样省 ~30m。
- **同源臂遮蔽（定点敲入必做）**：构建体的小鼠同源臂与内源位点全同→多重比对。拷贝数/整合**只在人源特异区算、遮蔽同源臂、MAPQ≥20**；否则拷贝数被严重低估（实测全长 0.08 vs 人源区真实 0.60），且内源直系同源位点会冒出假整合信号。
- **高深度 artifact 黑名单**：候选整合位点过滤深度 > 基线×5 的塌缩重复位点（实测 chr1:78.58Mb 达基线 29×）。
- **实测耗时(单样~19×,不含Manta) ~7h**：bwa-mem2 建索引 45m/61GB、比对 22m、MarkDup 3.5h、TIDDIT 1.3h。6 样 queueSize=2 约 ~21h。
