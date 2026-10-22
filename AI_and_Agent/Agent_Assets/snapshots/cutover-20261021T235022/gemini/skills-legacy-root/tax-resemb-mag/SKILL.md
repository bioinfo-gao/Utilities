---
name: tax-resemb-mag
description: "Use when 用户要做 shotgun 宏基因组 de-novo 组装+分箱+MAG 重建与分类:nf-core/mag"
disable-model-invocation: true
---

# /tax-resemb-mag — 宏基因组 De-novo 组装 · 分箱 · MAG 重建与分类 Setup Skill

为当前项目搭建**基于组装（assembly-based）**的 shotgun 宏基因组分析代码：把 reads 从头组装成 contigs，分箱（binning）重建 **MAG（Metagenome-Assembled Genomes）**，做 bin 质量评估与分类学鉴定，覆盖短读长（Illumina）与长读长（Nanopore/PacBio，混合组装）数据：

nf-core/mag **5.4.2** → QC/去宿主/去 PhiX（fastp/AdapterRemoval + Porechop）→ **组装（MEGAHIT + metaSPAdes，QUAST/ALE 评估）** → **分箱（MetaBAT2 / MaxBin2 / CONCOCT / COMEBin / MetaBinner / SemiBin2，六选多）** → DAS Tool 精炼（可选）→ **bin 质控（BUSCO 默认 / CheckM / CheckM2 + 可选 GUNC）** → **bin 分类（GTDB-Tk 默认 + 可选 CAT）+ 病毒 geNomad / 真核 Tiara（可选）** → Prodigal/Prokka（+可选 MetaEuk）基因预测注释 → MultiQC 报告。

参考已验证安装：`15_mag_setup/`（nf-core/mag **5.4.2** 装到 `mag_biobakery` 环境、nextflow 26.04.4、共享镜像缓存、`-profile test` 组装→六分箱器→BUSCO→GTDB-Tk(mockup)→CAT→注释全链路验证通过，2026-07-08）。

> **⚠️ 版本说明**：本 skill 针对 **nf-core/mag 5.4.2**（现代 nf-core 模板）。项目 `15_mag_setup/` 是更早的 **2.5.1**（旧模板，已弃用），两者差异巨大——5.4.2 不需要 2.5.1 那套 `NXF_SYNTAX_PARSER=v1` / `--max_cpus` / centrifuge-`/tmp` hack。**新项目一律用 5.4.2**。

> **与 `/taxnom`（taxprofiler）的边界 —— 最重要的选型分叉**：
> - `/taxnom` = **assembly-free**，直接把 reads 比对参考库定量物种丰度（Kraken2+Bracken / MetaPhlAn）。回答"群落里有哪些已知物种、各占多少"，快、轻。
> - `/tax-resemb-mag`（本 skill）= **assembly-based**，从头组装 + 分箱重建**基因组草图（MAG）**。回答"能不能拼出一个个近完整基因组、它们是谁（GTDB 分类）、编码哪些基因"，慢、重（GTDB-Tk r226 库 ~102GB），适合**发现新物种/未培养菌、基因组层面证据、pangenome/功能注释**。
> - **注意：mag 5.x 已移除 reads 层分类（不再内置 Kraken2/Centrifuge）**——群落丰度画像**只能**走 `/taxnom`，本 skill 只做"组装→分箱→MAG 分类"。两者互补：先 `/taxnom` 看组成，需要基因组再上本 skill。
>
> **与 `/wgs` 模式 C 的边界**：`/wgs` 模式 C 是"去宿主 + 单样本 de novo 组装 + BLAST 揪出某段已知外源/转基因序列"，不分箱；本 skill 重建群落里**多个**微生物基因组并系统做 bin 质控+分类。
>
> **关键分叉一：短读长 vs 长读长 vs 混合** —— 决定组装器与 QC 工具（fastp vs Porechop），及 samplesheet 的 platform 列。
> **关键分叉二：单样本组装 vs 分组共组装（`--coassemble_group`）** —— 同 `group` 合并组装，提升低丰度菌 contig 连续性、利于跨样本 co-abundance 分箱，但内存/时间成本更高。

---

## 第一步：信息收集

| 参数 | 确认方式 |
|:---|:---:|
| 项目根目录 | 从当前工作目录推断，或请用户确认 |
| 样品表路径 | 用户提供，或在项目根目录查找 |
| FASTQ 数据目录 | 读取样品表后确认实际路径 |
| 读长类型 | 短读长(Illumina) / 长读长(Nanopore/PacBio) / 混合(短+长) |
| 测序平台（5.4.2 samplesheet 必填列） | 短读 `short_reads_platform`（ILLUMINA/BGISEQ/…）、长读 `long_reads_platform`（OXFORD_NANOPORE/PACBIO_HIFI） |
| 是否分组共组装 | 想跨样本重建低丰度菌 → `--coassemble_group`；否则逐样本组装 |
| 样品来源（决定是否去宿主） | 宿主源（人/鼠/CHO 组织、粪便、拭子）→ 需去宿主；环境样品（水/土/发酵液）→ 通常不需要 |
| 宿主物种（若需去宿主） | Mouse / Human / 其他 → `--host_genome`（iGenomes key）或 `--host_fasta`（本地 fasta） |
| bin 质控工具 | 默认 **BUSCO**（`run_busco=true`）；要标准完整度/污染度加 **`--run_checkm2 --checkm2_db <库>`**（推荐）或 `--run_checkm`；嵌合检测 `--run_gunc` |
| 是否做 GTDB-Tk 分类 | **默认开**（`skip_gtdbtk=false`），但**需 ~102GB 的 GTDB r226 库**（见第二步）。库没就位就先 `--skip_gtdbtk`，别让它联网拉 102GB |
| 是否加 CAT / 病毒 / 真核 | CAT contig/bin 分类 `--cat_db`；病毒 `--run_virus_identification`(geNomad)；真核 bin `--bin_domain_classification`(Tiara) |
| 对照/空白样本 | 有无阴性对照；其 contig/bin 数应极少，是本底污染基线 |
| 交付重心 | 与客户确认：MAG 数量与质量分级（near-complete/high/medium/low）、GTDB 分类树、bin 丰度跨样本比较、目标类群基因组功能注释 |

---

## 第二步：数据库路径

mag 5.4.2 的库大多在运行时**自动下载**，但大库建议**下载一次、长期复用**，用 `--*_db` 指本地路径避免每项目重复下载。

### GTDB-Tk（bin 分类，默认开，**大库，必须手动下载一次**）
```
默认 URL（release226）：https://data.gtdb.aau.ecogenomic.org/releases/release226/226.0/auxillary_files/gtdbtk_package/full_package/gtdbtk_r226_data.tar.gz
本地路径（首次下载解压到）：/Work_bio/references/Metagenomics/gtdbtk/release226/   ← 下载 ~50GB、解压 ~102GB，用 --gtdb_db 传入
```
- **务必下载一次存共享参考目录**，`--gtdb_db /Work_bio/references/Metagenomics/gtdbtk/release226/` 复用，不要每项目重下。
- 只有 bin 完整度 ≥ `--gtdbtk_min_completeness`（默认 50）才送 GTDB-Tk（省算力）。
- 库未就位/冒烟测试时 `--skip_gtdbtk`（真实数据要出分类就必须先备好库）。

### BUSCO（默认 bin QC，`run_busco=true`）
```
已本地就位一个 lineage：/Work_bio/references/Metagenomics/busco/bacteria_odb10.2024-01-08.tar.gz
```
- 不传 `--busco_db` 时 BUSCO 会 auto-lineage 联网下载；想固定/离线就 `--busco_db <本地tar.gz> --busco_db_lineage bacteria_odb10`。
- 细菌群落用 bacteria_odb10 起步；其他 lineage 从 `https://busco-data.ezlab.org/v5/data/lineages/` 下**当前日期版本**（旧的 2020-03-06 等已从服务器下架），存同目录复用。

### CheckM2（若 `--run_checkm2`，推荐做标准完整度/污染度）
```
--checkm2_db 指向 CheckM2 DIAMOND 库（首次 checkm2 database --download 获取，存共享参考目录复用）
```

### CAT（若 `--cat_db`，contig/bin 级 taxonomy）
```
--cat_db 指向 CAT prepare 产物（NR-based，较大）；不给则不跑
```

### 宿主基因组（去宿主，与 /wgs、/rnaseq、/taxnom 共用）
```
Mouse GRCm39: /Work_bio/references/Mus_musculus/GRCm39/mouse_gencode_M35/GRCm39.primary_assembly.genome.fa
Human GRCh38: /Work_bio/references/Homo_sapiens/GRCh38/human_gencode_v45/GRCh38.primary_assembly.genome.fa
```
`--host_fasta <fasta>`（现建 bowtie2 索引）或 `--host_genome <iGenomes key>`。

### reads 层群落丰度 → 不在本 skill
mag 5.x **不再内置** Kraken2/Centrifuge reads 分类。要群落组成/丰度/多样性，走 `/taxnom`（taxprofiler，本地已有 Kraken2 Standard-8GB + MetaPhlAn 库）。

---

## 第三步：环境与工具（已装，勿重复安装）

| 工具 | 位置 | 用途 |
|:---|:---:|:---:|
| **nextflow 26.04.4 + openjdk 23** | 装在 **`mag_biobakery`** conda env（`mamba install -n mag_biobakery -c bioconda -c conda-forge nextflow`） | 调度 pipeline（mag 5.4.2 要求 **Nextflow ≥25.04.2**，本 env 满足） |
| nf-core/mag | **锁定 `-r 5.4.2`**（已 `nextflow pull`，缓存 `~/.nextflow/assets/nf-core/mag`） | 分析引擎 |
| apptainer/singularity 1.4.x、docker | 系统级 | 容器引擎，用 `-profile singularity` |
| Singularity 镜像缓存 | `/Work_bio/gao/configs/.singularity`（跨项目共享，含 sarek/taxprofiler/mag 已拉镜像） | 避免重复下载 |
| 原生 biobakery 工具（metaphlan/humann/kraken2/bowtie2） | 同 `mag_biobakery` env（`.../bin`） | 容器外补充分析（如 HUMAnN 功能通路），mag 本身不用 |

**关键：`mag_biobakery` 自己的 nextflow(26.04.4) 会被 PATH 里更靠前的 `regular_bioinfo/bin/nextflow`(25.10.4) 遮蔽**（`command -v nextflow` / `conda run -n mag_biobakery nextflow` 都可能解析到 regular_bioinfo）。因 mag 5.4.2 硬要求 Nextflow ≥25.04.2，脚本里**必须用绝对路径** `/Work_bio/gao/configs/.conda/envs/mag_biobakery/bin/nextflow` + `export JAVA_HOME=/Work_bio/gao/configs/.conda/envs/mag_biobakery`。

**具体生信工具（MEGAHIT/SPAdes/6 个 binner/BUSCO/GTDB-Tk/Prokka 等）不装进任何 conda env** —— 每个 process 在 Nextflow 自动拉取的容器里跑；`mag_biobakery` env 只负责 Nextflow+Java 调度（+容器外 biobakery 补充分析）。

---

## 第四步：目录结构

```
{PROJECT_DIR}/
├── {sample_sheet}.csv                ← 5.4.2 schema（7 列，见第五步）
├── scripts/
│   ├── 1_produce_samplesheet.py      ← 生成 mag input CSV（固定列名）
│   ├── 2_run_mag.sh                  ← self-relaunch + auto-resume（同 rnaseq/wgs/taxnom 模式）
│   ├── 3_work_monitor.sh
│   ├── 4_downstream_analysis.R       ← MAG 质量分级 + GTDB 分类汇总 + 跨样本 bin 丰度
│   ├── 5_generate_report.R
│   └── local_resources.config        ← 复用 15_mag_setup 已验证配置
├── output_results/                   ← mag 输出（Assembly/ GenomeBinning/ Taxonomy/ QC_shortreads/ Annotation/ ...）
└── custom_research_report_YYYYMMDD/  ← 交付（见 CLAUDE.md 结构规范）
```

---

## 第五步：核心脚本

### 脚本 1 — `1_produce_samplesheet.py`
生成 nf-core/mag **5.4.2** schema 的 `samplesheet.csv`（**固定 7 列**，别按客户样品表改列名）：
```
sample,group,short_reads_1,short_reads_2,long_reads,short_reads_platform,long_reads_platform
```
- `sample`：唯一样品名。
- `group`：分组标签；`--coassemble_group` 时同 `group` 合并组装。不共组装也必须填（可全填 `0`）。
- `short_reads_1`/`short_reads_2`：双端 fastq.gz（单端只填 `_1` 且加 `--single_end`）。
- `long_reads`：Nanopore/PacBio 路径（用于混合组装/纠错，需配对短读）。
- `short_reads_platform`：给了短读就**必填**（`ILLUMINA`/`BGISEQ`/`ION_TORRENT`…）。
- `long_reads_platform`：给了长读就**必填**（`OXFORD_NANOPORE`/`PACBIO_HIFI`…）。
- 可选 `run` 列：同样品跨多 run 时组装前先合并。
- 另有 `--assembly_input`（CSV：`id,group,assembler,fasta`）跳过组装、直接从已有 assembly 开跑。

### 脚本 2 — `2_run_mag.sh`（self-relaunch + auto-resume，强制模式，同 rnaseq/wgs/taxnom）
```bash
#!/usr/bin/env bash
set -uo pipefail
PROJ={PROJECT_DIR}
NEXTFLOW=/Work_bio/gao/configs/.conda/envs/mag_biobakery/bin/nextflow   # 必须绝对路径（≥25.04.2）
export JAVA_HOME=/Work_bio/gao/configs/.conda/envs/mag_biobakery

if [ -z "${TMUX:-}" ]; then
    tmux new-session -d -s mag_run "bash '${PROJ}/scripts/2_run_mag.sh' 2>&1 | tee '${PROJ}/mag_run.log'"
    exit 0
fi

# 下面 export 必须在 tmux 命令上下文内（常驻 tmux server 不继承外层 export——已验证坑）
export NXF_SINGULARITY_CACHEDIR='/Work_bio/gao/configs/.singularity'
# 注意：5.4.2 是现代模板，NO NXF_SYNTAX_PARSER=v1（那是 2.5.1 旧模板才要的 hack）

run_mag() {
    "$NEXTFLOW" run nf-core/mag -r 5.4.2 -profile singularity \
        -c "${PROJ}/scripts/local_resources.config" \
        --input samplesheet.csv --outdir output_results \
        -work-dir /mnt/ex_8T_SSD/mag_work/{PROJECT_NAME}/work \
        --host_fasta {HOST_GENOME}.fa \
        --run_checkm2 --checkm2_db /Work_bio/references/Metagenomics/checkm2/ \
        --gtdb_db /Work_bio/references/Metagenomics/gtdbtk/release226/ "$@"
}
if run_mag;         then echo "MAG_SUCCESS"; exit 0; fi
if run_mag -resume; then echo "MAG_SUCCESS"; exit 0; fi
echo "MAG_FAILED"; exit 1
```
**固定/关键参数：**
- `-r 5.4.2`（锁定）
- 环境样品（无需去宿主）去掉 `--host_fasta` 行
- 逐样本组装是默认；分组共组装加 `--coassemble_group`
- 6 个 binner 默认全开；不需要的用 `--skip_metabat2 --skip_maxbin2 --skip_concoct --skip_comebin --skip_metabinner --skip_semibin` 关掉（CONCOCT/COMEBin/MetaBinner 较慢，小项目可关）
- **GTDB 库未就位就先 `--skip_gtdbtk`**，别让它联网拉 102GB
- 群落 reads 丰度**不在这里**，走 `/taxnom`

### 脚本 3 — `3_work_monitor.sh`
显示 tmux 日志末尾 + `output_results/` 目录结构。>15 分钟无新内容时查 `.nextflow.log` 是否反复 `No more task to compute -- ... still active`（dataflow deadlock），确诊再重启。

### 脚本 4 — `4_downstream_analysis.R`
- **MAG 质量分级**（读 `GenomeBinning/QC/` BUSCO/CheckM2 汇总）：near-complete(>90/<5)/high/medium/low，统计各样本 MAG 数。
- **GTDB 分类汇总**（`Taxonomy/GTDB-Tk/`）：MAG → 域/门/属/种分类表 + 分类组成图/树。
- **跨样本 bin 丰度**（`GenomeBinning/depths/`）：MAG 覆盖度矩阵，聚类/PCoA（同 taxnom beta 多样性思路，排序图必须配数值解读）。
- 保存 `rds_cache/`（不进交付文件夹，同 rnaseq/wgs/taxnom）。

### 脚本 5 — `5_generate_report.R`
生成客户交付报告，结构见下方"报告"章节。

### `local_resources.config`（复用 `15_mag_setup` 已验证配置）
```groovy
singularity { enabled = true; autoMounts = true; cacheDir = '/Work_bio/gao/configs/.singularity'; pullTimeout = '30m' }
process     { resourceLimits = [cpus: 24, memory: 96.GB, time: 48.h] }   // 5.4.2 现代模板：资源上限只认 resourceLimits
```
总量守住 ≤28 物理核 / 56 线程留余量。

---

## 已知坑点（每次执行前检查，来自 `15_mag_setup` 实测记录）

1. **资源上限只用 `process.resourceLimits`**。mag 5.4.2 是**现代 nf-core 模板**，`check_max()` / `--max_cpus` / `--max_memory` **已不存在**（传了静默无效）。这与旧 2.5.1 相反——旧版认 `--max_cpus`，5.4.2 不认。
2. **需要 Nextflow ≥25.04.2**。`mag_biobakery` 的 26.04.4 满足；但 PATH 里 `regular_bioinfo` 的 nextflow(25.10.4) 也够——无论如何脚本**用绝对路径** `/Work_bio/gao/configs/.conda/envs/mag_biobakery/bin/nextflow` + `JAVA_HOME`，保证版本确定。
3. **不要用 2.5.1 那套 hack**：5.4.2 **不需要** `NXF_SYNTAX_PARSER=v1`（现代模板正常解析），也没有内置 centrifuge（故无 `/tmp` FIFO 崩溃问题），BUSCO test URL 也由 test-data 仓库自带。这些都是旧版遗留，5.4.2 一律不用。
4. **GTDB-Tk 库巨大（r226 ~102GB）且默认开**：默认会去 `data.gtdb.aau.ecogenomic.org` 拉 ~50GB 下载+解压。**首次务必手动下到共享参考目录**用 `--gtdb_db` 复用；冒烟测试/库未就位时 `--skip_gtdbtk`（test profile 用的是几 MB 的 mockup 库，真实项目不能用 mockup）。
5. **MaxBin2 在极小数据上 exit 255 是良性**：contigs 太少时报错，mag 设了 `errorStrategy ignore`，日志 `terminated with an error exit status (255) -- Error is ignored`，不影响整体成功。真实数据一般不触发；见到别误判失败。
6. **`WARN: Access to undefined parameter 'skip_tiara'` 是良性**：Tiara 真核分类默认关（`bin_domain_classification=false`）时的无害警告，不影响运行。
7. **SPAdes/co-assembly 是内存大户**（`process_high_memory` 默认可要 ~200GB，本机 125GB）：靠 `resourceLimits`/内存充足性把控，OOM 时 `--skip_spades` 退回 MEGAHIT，或减少并发。
8. **`NXF_SINGULARITY_CACHEDIR` 导出位置**：必须写在 tmux 命令字符串**内部** export（常驻 tmux server 不继承外层环境，同 taxprofiler/sarek 坑）。
9. **大 DAG dataflow 停滞**：6 个分箱器 × 多质控同跑时，下游聚合 process 偶发卡死。确诊信号 `.nextflow.log` 每 5 分钟重复 `No more task to compute -- ... still active`；确诊后 `tmux kill-session` + 带 `-resume` 重跑，`cached ✔` 复用不丢进度。
10. **线程/内存**：`local_resources.config` 已设 24 核/96GB，在 28 核/56 线程硬上限内，勿手动调大。本机 125GB 内存是**唯一硬墙**——`--skip_spades`(复杂样本改用 MEGAHIT)、GTDB-Tk 禁用 `--full_tree`(默认 split-tree ~55GB)、跳过 CAT(nr 库要 100–200GB)，是把内存压进 125GB 的关键。
11. **work-dir 放 SSD，别放 /Work_bio**：`-work-dir /mnt/ex_8T_SSD/mag_work/<project>/work`。原因：`/Work_bio`(`/dev/sdb1`)是**机械盘**且仅剩 ~898GB；`/mnt/ex_8T_SSD`(`/dev/sda1`)是**固态盘**、剩 ~3.9TB、可随时删项目腾空间。组装/分箱中间文件极其 I/O 密集且巨大(单样本 work/ 可达数十~百 GB)，放 SSD 又快又不挤爆 HDD。跑完成功后清 work/。`outdir`(最终结果，体量小)留项目目录即可。

---

## 交付前自查（Pre-Delivery Self-Audit，强制，不可省略）

**"pipeline 跑完 `Succeeded`" ≠ "MAG 结果是对的"**（CLAUDE.md 铁律）。报告/交付前必须实际核对：

- **组装质量是否合理**：QUAST 的 N50、total length、最长 contig——某样本 assembly 显著碎是低质量/污染/深度不足信号，先查再写。
- **MAG 数量与质量分级是否可信**：near-complete MAG 数是核心交付；某样本 MAG 数远超/远低于同组其他样本，是数据或组装问题信号（数字离群即停查），不是"有意思的发现"。
- **BUSCO/CheckM2 完整度-污染度**：高污染（>10%）bin 可能是嵌合，别当干净基因组交付；GTDB-Tk 只对达标 bin 分类，核对低质量 bin 没被误标物种（必要时开 `--run_gunc` 查嵌合）。
- **去宿主比例**（宿主源样本）：去宿主后剩余 reads 是否合理；某样本骤降是污染信号。
- **GTDB 分类离群核对**：某 MAG 分类若与同项目其他明显冲突/意外（如粪便样本拼出海洋菌），核对是否 bin 嵌合或污染，不能直接写进结论。
- **跨样本 bin 丰度排序图（PCoA/聚类）核对**：同 RNAseq PCA 规则——重复是否组内聚拢？某样本异常靠近别组是错标/污染信号，报告 Conclusions 里明确指出。
- **样品名与分组标签核对**：任何带"分组+样品名"的图，交付前程序化核查（`match()` 对齐 + 硬断言），不靠肉眼（同 rnaseq/wgs 热图/PCA 标签反转教训）。

---

## 报告（客户交付，CLAUDE.md 规范）

- **英文**，文件名 `<ProjectName>_MMDD.md`，交付文件夹 `custom_research_report_YYYYMMDD/`，内部按分析类型分子文件夹（如 `qc/` `host_removal/` `assembly/` `binning/` `bin_qc/` `taxonomy/`），源文件**拷贝**入内。
- 结构：1 Objectives / 2 **Key Findings**（3–5 条大白话，如"共重建 N 个 near-complete MAG，覆盖 X 个属"）/ 3 Sample Information / 4 Analysis Rationale & Decision Criteria（为何选这些组装器/分箱器、bin 质量分级阈值、GTDB 分类判据）/ 5 Methods（工具版本参数，mag `-r 5.4.2` + 各工具版本）/ 6 Results（数值证据：QUAST 指标、MAG 质量分级表、GTDB 分类）/ 7 Conclusions（表格）/ 8 Deliverable Files。
- **若交付含 bin 丰度排序图（PCoA/NMDS）或 PCA，必须用文字解读**（方差/inertia + 组内 vs 组间距离量化），比照 CLAUDE.md 对 PCA 图的强制解读要求。
- 其他图（组装质量图、MAG 质量散点、GTDB 分类树）按需解读。
- **报告绝不含**：`.rds`/中间对象、内部调试叙事（进自用 `analysis_plan_MMDD.md`，不进客户报告）。
- 签名：`Zhen Gao, PhD, Principal Bioinformatics Scientist, Athenomics`

---

## 运行顺序（告知用户）

```bash
# 1. 生成 samplesheet
conda run -n regular_bioinfo python scripts/1_produce_samplesheet.py

# 2. mag（自动进 tmux，失败自动 resume）
bash scripts/2_run_mag.sh

# 3. 下游 MAG 质量分级 / GTDB 分类 / 跨样本丰度
/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript scripts/4_downstream_analysis.R > scripts/downstream.log 2>&1

# 4. 生成报告
/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript scripts/5_generate_report.R
```

---

## 注意事项（每次执行均检查）

1. **绝对路径 nextflow + `JAVA_HOME`**（mag 5.4.2 要 Nextflow ≥25.04.2；`mag_biobakery` 的 26.04.4 满足，但会被 PATH 里 regular_bioinfo 遮蔽）。
2. **锁定 mag `-r 5.4.2`**；资源上限**只用 `process.resourceLimits`**（`--max_cpus`/`--max_memory` 在 5.4.2 已不存在）。
3. **不用旧版 hack**：5.4.2 不需要 `NXF_SYNTAX_PARSER=v1`、无 centrifuge、无需 `--busco_db` 覆盖 test URL（那些是 2.5.1 遗留）。
4. **GTDB 库 r226 ~102GB 且默认开**：先下到共享参考目录用 `--gtdb_db` 复用；未就位就 `--skip_gtdbtk`，别联网拉大库。
5. **群落 reads 丰度不在 mag 5.x**（已移除 Kraken2/Centrifuge），走 `/taxnom`。
6. **bin QC 默认 BUSCO**；要标准完整度/污染度加 `--run_checkm2 --checkm2_db`；嵌合 `--run_gunc`。
7. **6 个 binner 默认全开**（metabat2/maxbin2/concoct/comebin/metabinner/semibin）；慢的（concoct/comebin/metabinner）小项目可 `--skip_*` 关。
8. **去宿主用 `--host_fasta`/`--host_genome`**（环境样品不去宿主）。
9. **MaxBin2 exit 255 / `skip_tiara` WARN 均良性**，别误判失败。
10. **线程 ≤56 / 物理核 ≤28**；`local_resources.config` 已设 24 核/96GB。SPAdes/co-assembly 内存大，OOM 时 `--skip_spades`。
11. **tmux 保护 + 早期失败检测**（CLAUDE.md）：启动后前 3 分钟主动轮询日志查 error/validation/No such file；>15 分钟无新日志查 `.nextflow.log` 的 dataflow deadlock 信号。
12. **Rscript 用直接路径** `/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript`（`conda run` 有挂起 bug）；日志 `> log 2>&1` 不用 `| tee`。
13. **代码与可见文件同步**（CLAUDE.md）：实际命令一变，脚本同一响应内更新。
14. **选型边界**：群落丰度/多样性 → `/taxnom`（快、assembly-free）；重建基因组(MAG)/发现新物种 → 本 skill（慢、重）。
15. **worked example**：`15_mag_setup/`（nf-core/mag 5.4.2 装到 mag_biobakery、nextflow 26.04.4、`-profile test` 组装→六分箱器→BUSCO→GTDB-Tk(mockup)→CAT→注释全链路验证通过，2026-07-08）。
