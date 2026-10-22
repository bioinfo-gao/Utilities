---
name: taxnom
description: "Use when 用户要做 shotgun 宏基因组 assembly-free 物种分类/丰度定量:nf-core/taxprofiler(Kraken2+Bracken/MetaPhlAn)"
disable-model-invocation: true
---

# /taxnom — Shotgun 宏基因组 Taxonomic Classification & Profiling Setup Skill

为当前项目搭建**不依赖基因组组装（assembly-free）**的 shotgun 宏基因组物种分类/丰度定量分析代码，覆盖短读长（Illumina）与长读长（Nanopore/PacBio）数据：

nf-core/taxprofiler → QC/去宿主 → 多分类器 taxonomic classification/profiling（Kraken2+Bracken / MetaPhlAn / 按需其他）→ taxpasta 标准化合并 → 下游丰度/多样性分析 → 报告。

参考已验证安装：`8_taxprofiler_setup/`（pipeline 安装、容器引擎、共享镜像缓存、资源配置、`-profile test` 全 14 个 classifier 均验证通过，2026-07-01）。

> **与 WGS skill 的边界**：本 skill 是"直接对 reads 分类定量、不组装"的路线，适用于常规群落物种组成/丰度问题。如果目标是"样品里有没有混入某个未知外源序列/转基因，需要先组装再 BLAST 才能鉴定"，那是 `/wgs` 模式 C（host-subtraction + de novo 组装 + BLAST）的范畴，不是本 skill。两者可以互补：taxprofiler 给整体群落画像，WGS 模式C 负责"揪出具体是什么"。
>
> **关键分叉一：短读长 vs 长读长** —— 决定 QC 工具组合与可用 classifier 集合（不是所有工具都支持长读长，见第五步 classifier 兼容表）。
> **关键分叉二：是否需要去宿主（host removal）** —— 宿主源样本（粪便/组织/拭子等哺乳动物来源样本）通常需要；环境样本（水、土壤）通常不需要，直接分类。

---

## 第一步：信息收集

| 参数 | 确认方式 |
|:---|:---|
| 项目根目录 | 从当前工作目录推断，或请用户确认 |
| 样品表路径 | 用户提供，或在项目根目录查找 |
| FASTQ / FASTA 数据目录 | 读取样品表后确认实际路径 |
| 读长类型 | 短读长(Illumina, `fastq_1`/`fastq_2`) / 长读长(Nanopore/PacBio, `fasta`) / 两者都有 |
| 样品来源（决定是否去宿主） | 宿主源（人/鼠/CHO 等组织、粪便、拭子）→ 需要 host removal；环境样品（水/土/发酵液）→ 通常不需要 |
| 宿主物种（若需去宿主） | Mouse / Human / 其他 → 决定 `--hostremoval_reference` |
| 目标 classifier | 默认 **Kraken2+Bracken（属/种级丰度，本地已有 Standard-8GB 库）+ MetaPhlAn（marker gene 法种级，本地已有 CHOCOPhlAn SGB 库）双工具交叉验证**；客户指定特定工具（如疑似病毒/新颖序列想用 Kaiju/DIAMOND 蛋白比对，或长读长用 MetaCache/Melon）另外加 |
| 是否需要功能通路（functional profiling） | **taxprofiler 不做这个**（它只做物种分类，无 HUMAnN 模块）。客户如果要 pathway/gene family 丰度，需求超出本 skill 范围，改用 `mag_biobakery` 环境原生跑 HUMAnN（本地已有 chocophlan 16G + uniref 34G 库，见第二步） |
| 对照/空白样本 | 有无阴性对照（无模板对照、灭菌水等）；有的话其 unclassified 比例应接近 100%，是判断本底污染的重要基线 |
| 交付重心 | 与客户确认：物种组成堆叠图、alpha/beta 多样性比较（分组间群落结构差异）、特定病原体/物种检出与定量、跨工具交叉验证一致性 |

---

## 第二步：数据库路径（预设，已本地就位）

### Kraken2 — Standard 8GB（供 Kraken2 + Bracken 共用）
```
db_path: /Work_bio/references/Metagenomics/kraken2/k2_standard_08gb_20260226/k2_standard_08_GB_20260226.tar.gz
（同目录已有 database{50,75,100,150,200,250,300}mers.kmer_distrib，Bracken 用；建库日期 2026-02-26）
```
`databases.csv` 里可以直接指向这个 `.tar.gz`（taxprofiler 接受目录或 tar 包），无需解压。Bracken 复用同一个 Kraken2 db，`db_params` 用分号语法：`<kraken2_params>;<bracken_params>`（如 `;-r 150` 表示只传 Bracken 的 read-length 参数）。

### MetaPhlAn — CHOCOPhlAn SGB (vJan25)
```
db_path: /Work_bio/references/Metagenomics/metaphlan/
（mpa_vJan25_CHOCOPhlAnSGB_202503.{1,2,3,4}.bt2l + .pkl + .nwk 等，db_path 指向目录即可，taxprofiler 自动识别）
```

### 宿主基因组（去宿主用，与 `/wgs`、`/rnaseq` 共用同一份参考）
```
Mouse GRCm39:  /Work_bio/references/Mus_musculus/GRCm39/mouse_gencode_M35/GRCm39.primary_assembly.genome.fa
Human GRCh38:  /Work_bio/references/Homo_sapiens/GRCh38/human_gencode_v45/GRCh38.primary_assembly.genome.fa
```
**本地暂无现成 Bowtie2（短读长）/ minimap2（长读长）索引** —— 首次用某个宿主时，第一次跑会由 pipeline 用 `--hostremoval_reference <fasta>` 现场建索引（较慢，每个项目重复建）。若同一宿主会被多个项目反复使用，建议仿照 STAR/bwa-mem2 index 的做法，在参考目录下**手动预建一次并长期复用**：
```bash
# 短读长（Bowtie2），之后用 --shortread_hostremoval_index 指向索引目录
bowtie2-build --threads 20 GRCm39.primary_assembly.genome.fa GRCm39_bowtie2/GRCm39
# 长读长（minimap2），之后用 --longread_hostremoval_index 指向 .mmi 文件
minimap2 -d GRCm39.mmi GRCm39.primary_assembly.genome.fa
```

### 其他 classifier 数据库（客户指定时按需下载/建库）
本地未预置。各工具 `db_path` 要求的产出格式（下载/建库脚本另写）：

| 工具 | `db_path` 应为… |
|:---|:---|
| Centrifuge | `centrifuge-build` 产物 |
| Kaiju | `kaiju-makedb` 产物 |
| DIAMOND | `diamond makedb` 产物（`.dmnd`） |
| KrakenUniq | `krakenuniq-build` 产物 |
| MALT | `malt-build` 产物 |
| mOTUs (v3) | `motus downloadDB` 的 `db_mOTU/` 目录 |
| ganon | `ganon build` / `ganon build-custom` 产物 |
| KMCP | `kmcp index` 产物 |
| sylph | `sylph sketch` 产物 |
| Melon（长读长专用） | DIAMOND db + minimap2 index |
| MetaCache（长读长） | `metacache build` 产物 |

### Functional profiling（超出 taxprofiler 范围，客户明确要求才做）
```
env: mag_biobakery（已装 humann v3.9 / metaphlan / kraken2 原生二进制，非容器）
ChocoPhlAn: /Work_bio/references/Metagenomics/humann/chocophlan   (16G)
UniRef:     /Work_bio/references/Metagenomics/humann/uniref       (34G)
```

---

## 第三步：环境与工具（已装，勿重复安装）

| 工具 | 位置 | 用途 |
|:---|:---|:---|
| nextflow 25.10.4 / nf-core tools 4.0.2 / openjdk | 独立 **`taxprofiler`** conda env（与 `regular_bioinfo` 分开，方便独立升级） | 调度 pipeline |
| nf-core/taxprofiler | **锁定 `-r 2.0.1`**（已 `nextflow pull`，缓存在 `~/.nextflow/assets/`） | 分析引擎 |
| apptainer/singularity 1.4.5、docker 29.3.0 | 系统级 | 容器引擎，用 `-profile singularity` |
| Singularity 镜像缓存 | `/Work_bio/gao/configs/.singularity`（跨项目共享，含 sarek 等其他 pipeline 已拉取的镜像） | 避免重复下载 |

**具体生信工具（Kraken2/MetaPhlAn/Bracken 等）不需要装进任何 conda env** —— 每个 process 在 Nextflow 自动拉取的独立容器里跑；`taxprofiler` env 只负责 Nextflow+Java 调度。`mag_biobakery` env（原生 humann/metaphlan/kraken2 二进制）仅在做**容器外的 HUMAnN 功能通路分析**时才用得到。

---

## 第四步：目录结构

```
{PROJECT_DIR}/
├── {sample_sheet}
├── scripts/
│   ├── 0_build_databases_csv.py    ← 生成 databases.csv（指向本地库 + 客户指定库）
│   ├── 1_produce_samplesheet.py    ← 生成 taxprofiler input samplesheet.csv
│   ├── 2_run_taxprofiler.sh        ← self-relaunch + auto-resume（同 rnaseq/wgs 模式）
│   ├── 3_work_monitor.sh
│   ├── 4_downstream_analysis.R     ← taxpasta 合并表 → 相对丰度堆叠图 + alpha/beta 多样性
│   ├── 5_generate_report.R
│   └── local_resources.config      ← 直接复用 8_taxprofiler_setup 已验证配置
├── output_results/                 ← taxprofiler 输出（kraken2/ metaphlan/ taxpasta/ multiqc/ krona/ …）
└── custom_research_report_YYYYMMDD/   ← 交付（见 CLAUDE.md 结构规范）
```

---

## 第五步：核心脚本

### 脚本 0 — `0_build_databases_csv.py`
生成 `databases.csv`（列：`tool,db_name,db_params,db_type,db_path`），默认双工具模板：
```csv
tool,db_name,db_params,db_type,db_path
kraken2,k2standard8gb,,short;long,/Work_bio/references/Metagenomics/kraken2/k2_standard_08gb_20260226/k2_standard_08_GB_20260226.tar.gz
bracken,k2standard8gb,;-r 150,short,/Work_bio/references/Metagenomics/kraken2/k2_standard_08gb_20260226/k2_standard_08_GB_20260226.tar.gz
metaphlan,mpa_vJan25,,short,/Work_bio/references/Metagenomics/metaphlan/
```
- `bracken` 的 `-r 150` 要按实际测序读长改（150bp/250bp 等要匹配 kmer_distrib 文件）。
- 长读长且要用 MetaCache/Melon 等专用工具时，再加对应行（先按第二步的表下载/建库）。
- 客户指定 Kaiju/DIAMOND/Centrifuge 等时，追加对应行，`db_path` 指向现建的库。

### 脚本 1 — `1_produce_samplesheet.py`
生成 taxprofiler 官方 schema 的 `samplesheet.csv`（**固定列**，别按客户样品表改列名）：
```
sample,run_accession,instrument_platform,fastq_1,fastq_2,fasta
```
- 短读长双端：填 `fastq_1`/`fastq_2`，`fasta` 留空。
- 长读长：填 `fasta`，`fastq_1`/`fastq_2` 留空。**不能混填**（FASTA 和 FASTQ 列二选一，同一行不能同时有）。
- `run_accession` 每个文件对唯一；同一 `sample` 出现多个 `run_accession` 且开了 `--perform_runmerging`，预处理后会自动合并成一个样品。
- `instrument_platform` 用 EBI ENA 受控词表（如 `ILLUMINA`、`OXFORD_NANOPORE`）。

### 脚本 2 — `2_run_taxprofiler.sh`（self-relaunch + auto-resume，强制模式，同 rnaseq/wgs）
```bash
if [ -z "$TMUX" ]; then
    tmux new-session -d -s taxnom "bash '${SCRIPT}' 2>&1 | tee taxprofiler_run.log"; exit 0
fi

# NXF_SINGULARITY_CACHEDIR 必须在 tmux 命令字符串内部 export（tmux server 已常驻时，
# 新 session 继承的是 server 启动时的环境，外层脚本提前 export 不会生效——已验证的坑）
export NXF_SINGULARITY_CACHEDIR='/Work_bio/gao/configs/.singularity'

run_taxprofiler() {
    nextflow run nf-core/taxprofiler -r 2.0.1 -profile singularity \
        -c local_resources.config "$@" \
        --input samplesheet.csv --databases databases.csv \
        --outdir output_results -work-dir work \
        --perform_shortread_qc \
        --perform_shortread_hostremoval --hostremoval_reference {HOST_GENOME}.fa \
        --run_kraken2 --run_bracken --run_metaphlan
}
if run_taxprofiler; then exit 0; fi
if run_taxprofiler -resume; then exit 0; fi
exit 1
```
**固定/关键参数：**
- `-r 2.0.1`（锁定）
- 环境样品（无需去宿主）时去掉 `--perform_shortread_hostremoval`/`--hostremoval_reference` 两行
- 长读长项目改用 `--perform_longread_qc --perform_longread_hostremoval` 等对应 `longread_*` 参数
- `--run_<tool>` 全部默认关闭，**必须显式打开**，且要和 `databases.csv` 里的 `tool` 行对上，否则该工具不会跑（不报错，静默跳过）
- `--run_bracken` 会自动带出 Kraken2 前置步骤，和 `--run_kraken2` 同开不冲突

### 脚本 3 — `3_work_monitor.sh`
显示 tmux 日志末尾 + `output_results/` 目录结构，用于快速查看状态。若日志 >15 分钟无新内容，先查 `.nextflow.log` 有没有反复出现 `No more task to compute -- ... still active`（见下方"已知坑点"第 3 条），确诊 deadlock 再决定要不要重启。

### 脚本 4 — `4_downstream_analysis.R`
从 `output_results/taxpasta/` 的跨工具/跨样品标准化合并表出发（Kraken2 一份、MetaPhlAn 一份，各自独立文件）：
- 每个工具各自的**相对丰度堆叠图**（属/种级，Top N + "Other" 汇总）
- **alpha 多样性**（Shannon/Simpson/observed richness）按分组比较（箱线图 + 组间检验）
- **beta 多样性**（Bray-Curtis 距离 + PCoA 排序图），量化组间/组内距离比（同 rnaseq skill PCA 的 `separation_ratio` 思路，排序图必须配数值解读，不能只放图）
- **跨工具交叉验证**：Kraken2/Bracken 与 MetaPhlAn 的 Top 10 物种排名做对比（如 Spearman 相关或并排表），严重不一致时要在报告里标注、不能只挑一个工具的结果交付
- 保存 `rds_cache/`（跨脚本传递对象），不进最终交付文件夹（同 rnaseq/wgs 的 rds 规则）

### 脚本 5 — `5_generate_report.R`
生成客户交付报告，结构见下方"报告"章节。

### `local_resources.config`（直接复用 `8_taxprofiler_setup` 已验证配置，勿改动核心机制）
```groovy
executor { cpus = 24; memory = '96.GB' }
process { resourceLimits = [cpus: 24, memory: 96.GB, time: 12.h] }
singularity { enabled = true; autoMounts = true; cacheDir = '/Work_bio/gao/configs/.singularity' }
```
总量守住 ≤28 物理核 / 56 线程留余量（这里用 24 核/96GB，已在硬上限内）。

---

## 已知坑点（每次执行前检查，来自 `8_taxprofiler_setup` 实测记录）

1. **`--max_cpus`/`--max_memory` 对 taxprofiler 完全无效**（静默忽略，不报错）。taxprofiler 2.0.1 用新版 nf-core 模板，已弃用 `check_max()` 机制（sarek 3.8.1 那种旧模板才认这两个参数）。资源上限**只能**靠 `process.resourceLimits`（即 `local_resources.config`）控制。新加自定义参数前，先用 `nextflow run ... -preview` 核对参数确实出现在打印的参数汇总里，避免"传了但静默无效"。
2. **常见拼写陷阱（不存在的参数名，同样静默忽略）**：`--perform_shortread_preprocessing`（不存在，正确是 `--perform_shortread_qc`）、`--remove_host`（不存在，正确是 `--perform_shortread_hostremoval`/`--perform_longread_hostremoval`，且**必须同时给 `--hostremoval_reference`** 才真正生效，只给开关是 no-op）。
3. **大 DAG 下偶发 dataflow 停滞（deadlock，非资源问题）**：全套 classifier 同时跑时，`TAXPASTA_MERGE`/`MULTIQC` 等下游聚合 process 偶尔卡死等一个不会再关闭的 channel。确诊信号：`.nextflow.log` 每 5 分钟重复打印 `No more task to compute -- ... still active`（Nextflow 自己的调度器报告，比"日志不动"更硬的证据）。确诊后 `tmux kill-session` + 重跑同一条带 `-resume` 的命令即可，已完成 process 会被 `cached ✔` 复用，不丢进度。
4. **`NXF_SINGULARITY_CACHEDIR` 导出位置**：必须写在 tmux 命令字符串**内部** export，不能在外层脚本提前 export——tmux server 若已常驻，新 session 继承的是 server 自己的环境（同 sarek 项目踩过的坑）。
5. **`test` profile 的 `--databases` 默认值是活分支**（`nf-core/test-datasets` 的 `taxprofiler` 分支，与 dev 分支共用、不随 release 冻结），只在**验证安装/调试环境**时才可能踩到版本不匹配（如 `centrifuger` 工具在 2.0.1 schema 里不认识）；真实项目自己提供 `databases.csv`，不会遇到这个问题，无需处理。
6. **线程/核数**：本地 executor 已设 24 核/96GB（在 28 核/56 线程硬上限内），勿手动调大顶到上限。

---

## 交付前自查（Pre-Delivery Self-Audit，强制，不可省略）

**"pipeline 跑完 `Failed: 0`" ≠ "群落分类结果是对的"**（CLAUDE.md 铁律，宏基因组场景同样适用）。报告/交付前必须实际核对：

- **去宿主比例是否合理**：粪便/肠道样品去宿主后应保留大部分 reads（宿主污染通常个位数到二十几个百分点）；若某样品去宿主后剩余 reads 骤降（远超其他重复），是采样/提取污染信号，先查再写。
- **unclassified 比例是否异常**：多数环境/宿主样品 unclassified 应在合理区间；若某样品明显偏高（数据库覆盖不足或建库/QC 问题）或阴性对照 unclassified 明显低于接近 100%（说明有污染或试剂/环境本底菌群),都要停下来查。
- **跨工具交叉验证**：Kraken2/Bracken 与 MetaPhlAn 的 Top 物种排名是否大致吻合（**必须做**，不能只跑一个工具就直接下结论）；严重不一致时要在报告里如实指出、分析可能原因（数据库版本、marker gene vs k-mer 方法学差异等），不能挑一个"看起来更好看"的结果交付。
- **beta 多样性排序图（PCoA/NMDS）核对**：同 RNAseq PCA 规则——每个重复是否与自己组内聚在一起？某样品若明显更接近别的分组，是错标/污染信号，需要在报告 Conclusions 里明确指出，不能当普通生物学变异忽略。
- **样品名与分组标签核对**：任何堆叠图/热图/排序图只要同时带"分组标签+样品名"，交付前必须程序化核查（`match()` 对齐 + 硬断言），不能只靠肉眼看图（同 rnaseq/wgs 的热图/PCA 标签反转教训）。
- **数字离群即停查**：某样品的物种数/多样性指数/丰度分布与同组其他重复差异悬殊，是数据问题的信号，不是可以直接写进报告的"有意思的发现"。

---

## 报告（客户交付，CLAUDE.md 规范）

- **英文**，文件名 `<ProjectName>_MMDD.md`，交付文件夹 `custom_research_report_YYYYMMDD/`，内部按分析类型分子文件夹（如 `qc/` `host_removal/` `kraken2_bracken/` `metaphlan/` `diversity/`），源文件**拷贝**入内。
- 结构：1 Objectives / 2 **Key Findings**（3–5 条大白话结论前置）/ 3 Sample Information / 4 Analysis Rationale & Decision Criteria（为何选这些 classifier、去宿主判据、显著性/多样性判据阈值）/ 5 Methods（工具版本参数，taxprofiler `-r 2.0.1` + 各 classifier 版本）/ 6 Results（带数值证据）/ 7 Conclusions（表格）/ 8 Deliverable Files。
- **若交付里含 beta 多样性排序图（PCoA/NMDS），必须用文字解读**（解释了多少方差/inertia + 组内 vs 组间距离量化），比照 CLAUDE.md 对 PCA 图的强制解读要求——这是该规则在宏基因组场景下的对应物。
- 其他图（相对丰度堆叠图、alpha 多样性箱线图、Krona）按需解读，非每报告强制。
- **报告绝不含**：`.rds`/中间对象、内部调试叙事（进自用 `analysis_plan_MMDD.md`，不进客户报告）。
- 签名：`Zhen Gao, PhD, Principal Bioinformatics Scientist, Athenomics`

---

## 运行顺序（告知用户）

```bash
# 0. 生成 databases.csv
conda run -n regular_bioinfo python scripts/0_build_databases_csv.py

# 1. 生成 samplesheet
conda run -n regular_bioinfo python scripts/1_produce_samplesheet.py

# 2. taxprofiler（自动进 tmux，失败自动 resume）
bash scripts/2_run_taxprofiler.sh

# 3. 下游丰度/多样性分析
/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript scripts/4_downstream_analysis.R > scripts/downstream.log 2>&1

# 4. 生成报告
/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript scripts/5_generate_report.R
```

---

## 注意事项（每次执行均检查）

1. **锁定 taxprofiler `-r 2.0.1`**；资源上限只用 `process.resourceLimits`，`--max_cpus`/`--max_memory` 对这条 pipeline 无效。
2. **`--run_<tool>` 必须显式打开**且要和 `databases.csv` 里的 `tool` 行对应，默认全关。
3. **去宿主必须同时给 `--hostremoval_reference`**，只开 `--perform_*_hostremoval` 开关是 no-op。
4. **短读长 vs 长读长参数不通用**（`shortread_*`/`longread_*` 前缀分开），别把 WGS/RNAseq 习惯的参数名直接套用过来。
5. **本地已有 Kraken2 Standard-8GB + MetaPhlAn CHOCOPhlAn SGB 库**，默认双工具方案直接可用，无需重新下载建库；其他 classifier 按需现建。
6. **功能通路（HUMAnN）不在 taxprofiler 范围内**，客户明确要求才切到 `mag_biobakery` 环境原生跑（本地已有 chocophlan/uniref 库）。
7. **线程 ≤56 / 物理核 ≤28**；`local_resources.config` 已设 24 核/96GB，勿手动调大。
8. **tmux 保护 + `NXF_SINGULARITY_CACHEDIR` 必须在 tmux 命令内部 export**；所有 >1 分钟命令在 tmux 内跑。
9. **早期失败检测**（CLAUDE.md）：启动后前 3 分钟主动轮询日志查 error/traceback/validation failed，别被动等成功信号；>15 分钟无新日志时查 `.nextflow.log` 有没有反复出现 `No more task to compute -- ... still active`（deadlock 信号）。
10. **Rscript 用直接路径** `/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript`（`conda run` 有挂起 bug）；日志 `> log 2>&1` 不用 `| tee`（掩盖退出码）。
11. **交叉验证 Kraken2/Bracken 与 MetaPhlAn 结果**，不一致要如实报告，不能挑一个交付。
12. **代码与可见文件同步**（CLAUDE.md）：实际命令一变，脚本同一响应内更新。
13. **worked example**：`8_taxprofiler_setup/`（安装、容器引擎、共享镜像缓存、`test` profile 全 14 classifier 验证通过，含参数校验/dataflow stall 两次实测故障排查过程，见 `docs/README_taxprofiler_tutorial.md` 与中文版 `docs/taxprofiler_安装与测试记录_0701.md`）。
