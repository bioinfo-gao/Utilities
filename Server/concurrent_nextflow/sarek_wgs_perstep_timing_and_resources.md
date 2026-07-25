# sarek WGS 每步耗时 + 资源画像 — 实测参考

> **本文件是唯一权威副本(canonical)。** 以下路径通过软链接指向本文件,请勿在软链接处编辑,所有修改都在本文件进行:
> - `13_Ellen_knockin_wgs/logs/sLk_of_sarek_wgs_perstep_timing_and_resources_in_facilities_Server.md`

适用范围:nf-core/sarek 常规 WGS(germline / somatic 均适用),用于估算总耗时、排程并跑、
判断哪些步骤会互相争抢资源。
记录时间:2026-07-10(**本版用项目13/14 两条真实运行的 `execution_trace` 实测值替换了 0709 版的"借用值"**)。
数据来源:
- 项目14(somatic,GRCm39,6样本):`14_geneedit_lats12_wgs/output_A/pipeline_info/execution_trace_2026-07-08_21-38-32.txt`
- 项目13(germline+SV,混合参考,6样本):`13_Ellen_knockin_wgs/output_results/pipeline_info/execution_trace_2026-07-09_10-29-42.txt`
- 两条均为**降配并跑**期间的运行(见 `logs/key_operations_log.md` 与 `facilities/Server/concurrent_nextflow_resource_lessons_0710.md`);
  满配单跑时 CPU 步骤会更快,内存画像不变。

---

## 1. 每步实测:耗时 + 资源(解析自 trace 的 `realtime`/`%cpu`/`peak_rss`)

`CPU核` = `%cpu / 100`(nextflow 的 %cpu 是多核累加,400% ≈ 4 核满载);`峰值RSS` 是单任务实测峰值内存。

| 步骤 | 每任务耗时(均值 / 范围) | 实测CPU核 | 峰值RSS | 任务数 | 资源画像 |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **BWAMEM2_MEM**(比对,按区间分块) | ~38–43 min / 24–59 min | **~12–16 核** | ~30–34 GB | 每样本12块,6样本共72 | **CPU+内存双重、重** |
| **GATK4_MARKDUPLICATES**(去重) | **~3.9 h** / 2.7–5.6 h | ~1.4 核 | **~34 GB** | 每样本1,共6 | **内存重、CPU轻、最耗时下游步** |
| **TIDDIT_SV**(结构变异) | ~2.0 h / 0.9–3.8 h | ~1.8 核 | **~57 GB** | 每样本1,共6 | **内存最重、波动大** |
| **MUTECT2_PAIRED**(体细胞变异,按区块) | ~1.8 h / 0.4–2.5 h | ~4 核 | ~4.5 GB | 90(肿瘤-正常对×区块) | **CPU中、内存轻、量多总时长长** |
| **SAMTOOLS_STATS** | ~27 min / 20–31 min | ~1.6 核 | ~0.4 GB | 每样本1 | 轻 |
| **FASTQC** | ~39 min / 30–51 min | ~1.7 核 | ~2 GB | 每样本1 | 轻 |
| **FASTP** | ~13 min / 11–23 min | ~7.6 核 | ~1.3 GB | 每样本1 | CPU中、短 |
| **MOSDEPTH** | ~2 min | ~4 核 | ~1.5 GB | 每样本1 | 轻、快 |
| **BWAMEM2_INDEX**(建索引,一次性) | ~52 min | ~0.9 核 | **~56 GB** | 每参考1次 | 内存重、一次性 |
| BUILD/CREATE_INTERVALS、TABIX 等 | <1 s | — | <0.1 GB | 多 | 可忽略 |

> ⚠️ 数字来自降配并跑期,BWAMEM2 满配单跑时 CPU 核数更高(实测项目14 满配 `%cpu` 达 ~1573% ≈ 16 核,
> 项目13 降配 ~1193% ≈ 12 核)。耗时波动本身很大(尤其 TIDDIT 0.9–3.8 h、MarkDup 2.7–5.6 h),
> 下方估算只给区间、不给精确值。

## 2. 资源竞争关系(排程并跑时看这一节)

把每步归成两类资源画像,**画像互补的步骤可并跑、同类画像的步骤应错峰**:

| 资源画像 | 步骤 | 并跑影响 |
| :--- | :---: | :---: |
| **CPU大户**(多核、内存中等) | BWAMEM2_MEM、FASTP、MOSDEPTH、MUTECT2(中等4核) | 两个同时跑会抢核→都变慢;核数之和须 ≤28 物理核 |
| **内存大户**(CPU很低、RSS高) | TIDDIT_SV(~57GB)、MARKDUPLICATES(~34GB)、BWAMEM2_INDEX(~56GB) | 两个同时撞上会顶内存峰值(实测两作业各进内存重阶段时 available 一度跌到 32GB) |

- **最佳错峰组合**:一个作业在**比对期(CPU重)**、另一个在**变异调用/去重期(内存重、CPU轻)**——
  实测项目14(Mutect2 CPU轻而多)+ 项目13(比对 CPU重)长时间共存,冲突最小。
- **最危险的对撞**:两个作业**同时进入内存重步骤**(如 A 的 TIDDIT 57GB + B 的 MarkDup 34GB ≈ 90GB),
  会短暂逼近内存上限。实测这种峰值约 15 min 自愈(SSD swap 吸收),**不要恐慌 drop_caches/swapoff**。
- **BWAMEM2 是唯一的"CPU+内存双重"重步**:两个作业的比对期若完全重叠,既抢核又叠内存,是最该避免的重叠;
  用降配 config 把各自 BWAMEM2 的并发核数压到和 ≤28 核。

## 3. 单样本累计耗时估算(串行下游,降配并跑速率)

下游步骤在 `queueSize` 受限时会被迫排队串行。单样本从比对到出 germline VCF 的粗略累计:

| 阶段 | 单样本耗时 | 说明 |
| :--- | :---: | :---: |
| 比对(12块,受并发席位数影响) | 比对速率约 5–6 块/h(降配) → 全72块约 12–15 h | 6样本共享席位,非线性 |
| MarkDuplicates | ~4 h/样本 | 单样本最耗时下游步,内存重难高并发 |
| SAMTOOLS_STATS + MOSDEPTH | ~0.5 h/样本 | |
| TIDDIT_SV | ~2 h/样本(波动大) | |
| (somatic) Mutect2 | 90区块 × ~1.8h,受并发数强烈影响 | 项目14 >15h 都在这一环 |

**估"MultiQC 何时出"**:MultiQC 是收尾步(见下),订阅几乎所有QC channel,必须等**所有样本的
比对/去重/stats/mosdepth/TIDDIT 全部完成**才触发。用当前 trace 已完成子任务的 `submit` 时间戳
算真实速率(个/h),推剩余队列 ÷ `queueSize`,给区间估计。

## 4. MultiQC 在流程中的位置(收尾步,不是中间产物)

MultiQC 订阅 FASTQC、FASTP、SAMTOOLS_STATS、MOSDEPTH、MARKDUPLICATES 指标、TIDDIT 等几乎所有QC
channel,用 `.collect()`/`.mix()` 汇总——**必须等所有样本的所有相关进程完成、channel 关闭后才触发**。
哪怕 FASTQC/FASTP 已 6/6 完成,只要比对/去重/TIDDIT 还有一个样本没跑完,MultiQC 就不会执行。

**等不及汇总版**:
- 单样本原始质量直接开 `output_results/reports/fastqc/<样本>/*.html`、`reports/fastp/<样本>/*.fastp.html`,不用等。
- 想要已完成部分的多样本汇总:`multiqc <fastqc目录> <fastp目录> -o tmp/ -n multiqc_preview_MMDD -f`
  **⚠️ 必须写 `tmp/`,不可写 `output_results/`**(CLAUDE.md "Standard output folder CANONICAL-ONLY" 规则)。

---

*Zhen Gao, PhD, Principal Bioinformatics Scientist, Athenomics*
