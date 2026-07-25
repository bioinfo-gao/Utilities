# 项目14 全程运行负载画像 — Study A(somatic) + Study B(germline)

> **📍 关联文件组｜项目14「load-152 资源事件」四联档（2026-07-13）** — 以下四份内容互补、共享同一组实测数据，看到任意一份即可定位其余三份（绝对路径，一年后依旧可寻）：
> 1. **根因深挖**：`/home/gao/projects_2026H2/14_geneedit_lats12_wgs/docs/resource_pressure_incident_0713.md` — CNNScoreVariants 超订致 load 峰值 152 的逐层分析 + 配置修正
> 2. **项目14全程负载画像**：`/home/gao/projects_2026H2/facilities/Server/nextflow_pipeline/project14_load_profile_0713.md` — Study A+B 全程峰值/空闲/负载分布
> 3. **wgs skill**：`/home/gao/.claude/skills/wgs/SKILL.md` — CNN 是隐藏 CPU 大户的警告，写入资源 config 节
> 4. **corun skill**：`/home/gao/.claude/skills/corun/SKILL.md` — 哪些阶段可并跑 / 哪些绝对不行 的速判矩阵

> **文件性质**：单个 nf-core/sarek WGS 项目在本服务器上从头到尾的**真实负载记录**（峰值 + 空闲 + 分布），
> 作为未来排程 / 资源分配 / 空闲产能利用的原始参考。创建日 = 2026-07-13，文件名不改，修订在文件内记。
> **数据来源**：全部实测——`hc_resource_monitor_0712.log`、两条 `execution_trace_*.txt`、
> `concurrent_nextflow/` 并跑监控日志。测量服务器：28 物理核 / 56 线程 / ~128 GB RAM。
> **关联**：根因深挖见 [`14_.../docs/resource_pressure_incident_0713.md`]；每步资源画像见
> [`concurrent_nextflow/sarek_wgs_perstep_timing_and_resources.md`]；并跑教训见
> [`concurrent_nextflow/concurrent_nextflow_resource_lessons_0710.md`]。
> **Prepared by**: Zhen Gao, PhD, Athenomics.

## 更新记录
- 2026-07-13 — 建档，记录 Study A + Study B 全程负载、07-13 load 峰值152、空闲窗口利用。

---

## 0. 项目概览与两 arm 的负载定位

项目14 = 12 样本小鼠 WGS，拆成两个 sarek arm 分开跑（依 CLAUDE.md "Per-part resource configs"）：

| Arm | 分析 | 参考 | 样本 | 运行区间(wall-clock) | 并发上下文 | 配置 |
| :--- | :---: | :---: | :---: | :--- | :---: | :--- |
| **Study A** | somatic (Mutect2) | GRCm39 | 6 | 2026-07-08 21:38 → 07-12 04:54(~3.3天,含-resume) | **与项目13 germline 并跑** | 降配 queueSize=3 |
| **Study B** | germline (HaplotypeCaller) | GRCm39 | 6 | 2026-07-11 20:39 起,07-12 14:27 -resume → 07-13 仍在收尾 | **独占整机** | `local_resources_full_machine.config` |

**一句话**：Study A 的负载被"降配并跑"人为压住（峰值受控但慢）；Study B 独占整机反而在 CNN 过滤段
**冲出 load 152 的失控峰值**——说明"独占≠安全"，独占时更要显式限核。

---

## 1. Study A(somatic,并跑期)负载画像

- **并发上下文**：与项目13 germline 长期共存，用降配 config(queueSize=3)把两作业的 BWAMEM2 并发核数之和压到 ≤28 物理核。
- **重步骤实测峰值(trace)**：

| 步骤 | 任务数 | 最高 %cpu | ≈核 | 峰值RSS | 画像 |
| :--- | :---: | :---: | :---: | :---: | :---: |
| BWAMEM2_MEM | 72 | **1590%** | **≈16** | ~34 GB | CPU+内存双重、最重 |
| MUTECT2(按区块) | 105 | 415% | ≈4 | ~4.5 GB | CPU中、量多、总时长最长(>15h在此环) |
| MARKDUPLICATES | 18 | 418% | ≈4 | **~34 GB** | 内存重 |
| TIDDIT_SV | 27 | 244% | ≈2.4 | **~57 GB** | 内存最重、波动大 |

- **内存峰值对撞**：Study A 与 proj13 各自进入内存重步骤(A 的 TIDDIT 57GB + proj13 的 MarkDup)时，
  available 一度跌到 **~32 GB**；约 15 min 由 SSD swap 吸收自愈——**没有 drop_caches/swapoff**(符合"峰值自愈别抢先")。
- **结论**：并跑降配下 Study A 全程 load 受控（未见失控峰值），代价是慢（Mutect2 段 >15h）。这是**用时间换安全**的正确取舍。

## 2. Study B(germline,独占整机)负载画像

监控覆盖 **07-12 14:57 → 07-13 10:47**（239 个 1 分钟采样，每 5 min 一采）。

### 2.1 load 分布(1min load,239 采样)

| load 区间 | 含义 | 采样数 | 占比 |
| :--- | :--- | :---: | :---: |
| <15 | **空闲/极轻**(单线程步:MarkDup/gather) | 67 | 28% |
| 15–56 | 预算内(≤56线程) | 54 | 23% |
| 56–80 | 轻超订 | 89 | **37%** |
| 80–110 | 超订 | 13 | 5% |
| **≥110** | **严重超订** | **16** | **7%** |

> 注：37% 时间处于 56–80 的"轻超订"是 full_machine config 有意打满(HC 14并发)的常态,尚可接受;
> 真正的问题是那 7% 的 ≥110 严重峰值(下节)。

### 2.2 高峰期(2026-07-13 07:17–09:32,持续~2h15m)⚠

- **1min load 峰值 152.80**(07:57);15min 均值最高 124.83。**约为 56 线程预算的 2.7 倍。**
- **根因**：CNNScoreVariants(变异过滤)每任务实测 **≈8.7 核**(%cpu 843–920%)但 RSS 仅 1.8 GB,
  config 无显式限核→5 个并发(≈43核) + 仍在收尾的 HaplotypeCaller 尾巴(~10个×2.7核≈27核) 叠加 ≈70 核压在 56 线程上。
- **内存全程健康**(可用 85–115 GB),纯 CPU/进程超订。
- **无任务失败、无 OOM、结果无损**(全 exit=0),09:37 CNN 结束后自愈。**不重跑。**
- 完整根因 + 配置修正见 `docs/resource_pressure_incident_0713.md`。**已给 config 加 `CNNSCOREVARIANTS cpus=9`**(未来 germline 生效)。

### 2.3 高峰采样(Top,监控日志原文)

| 时间(07-13) | load 1m/5m/15m | avail |
| :--- | :---: | :---: |
| 07:57 | 152.80 / 131.37 / 124.83 | 94G |
| 07:37 | 150.50 / 138.19 / 113.31 | 85G |
| 07:32 | 138.69 / 121.82 / 100.48 | 85G |
| 07:42 | 132.61 / 137.07 / 120.11 | 87G |
| 08:27 | 127.61 / 114.58 / 116.04 | 96G |

---

## 3. 空闲产能与利用(重要:空闲也要记)

**Study B 独占整机 ≠ 整机一直满载。** germline 流程有大段低负载:

| 空闲窗口(07-12) | load 1m | avail | 对应流程阶段 |
| :--- | :---: | :---: | :--- |
| 15:07 – 16:12 | **3–4** | 71–79G | MarkDuplicates / 单线程 gather(CPU仅~1.4核,严重欠载) |
| 16:17 – 17:2x | 3–9 | 89–102G | 去重收尾 / 变异调用前的排队间隙 |

- **成因**：MarkDuplicates(~1.4核)、MERGE/gather、CNN 之间的排队间隙都是**单线程或低并发**步骤,
  56 线程预算只用了零头 → load 掉到 3–4,**~50 线程闲置约 2 小时**。
- **本次利用**:这段空闲产能被用来**完整跑完项目13的下游分析**(见
  [`concurrent_nextflow/`] 目录 + 项目13 交付)。**空闲 = 可安全插入其它工作的窗口**,不必让机器干等。
- **规则**:germline 的去重/gather 期是**天然的空闲插槽**;规划时可把另一项目的 CPU 轻活(或 proj13 这类下游分析)
  排进这些窗口,总吞吐更高。反之,**别把另一个 CPU 重活排进 Study B 的比对期或 CNN 期**(见第2节峰值)。

---

## 4. 给未来排程/分配的净结论

1. **"独占整机"不等于安全**:full_machine config 靠内存自动限流,对 CNN 这类"低RSS高线程"进程失效,反而冲出 load 152。→ **凡实测%cpu远超声明cpus的进程必须显式限核**(CNN cpus=9)。
2. **负载是相位性的,不是恒定的**:germline 一条线里,比对期(CPU重)、去重期(空闲)、变异调用+CNN期(CPU爆)交替。排程要**看阶段而非看"是否在跑"**。
3. **空闲窗口要主动利用**:去重/gather 期 ~50 线程闲置 ~2h,是插入其它工作的黄金窗口(本次用于收尾项目13)。
4. **并跑(Study A)用时间换安全是对的**:降配 queueSize 让峰值受控、内存对撞自愈,虽慢但零故障;独占反而更容易失控——**独占时更要显式限核,不能只依赖"没人抢就随便打满"**。
5. **内存从不是本项目 germline 的约束**(全程余 85G+),CPU/线程才是。配置以 CPU 为第一约束。

## 5. 数据来源清单
- Study B load 时间线:`14_geneedit_lats12_wgs/logs/hc_resource_monitor_0712.log`(239 采样)
- Study A/B 每进程 %cpu/RSS:`output_A/pipeline_info/execution_trace_2026-07-08_21-38-32.txt`、
  `output_B/pipeline_info/execution_trace_2026-07-12_14-27-42.txt`
- 并跑期监控:`facilities/Server/concurrent_nextflow/concurrent_run_monitor_log_0710.txt`
- 配置:`14_.../scripts/0_common/local_resources_full_machine.config`(独占) / `local_resources.config`(并跑降配)

---

*Zhen Gao, PhD, Principal Bioinformatics Scientist, Athenomics*
