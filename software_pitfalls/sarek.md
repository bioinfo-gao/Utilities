# nf-core/sarek 坑

## 1. `--use_gatk_spark markduplicates` 在高深度 WGS 上是净倒退，别开

**实测代价（proj16, 2026-07-16）：~15.4 h。** 两个失败模式叠加：

1. **强制单线程 ELC**：MarkDuplicatesSpark 不产生 duplicate metrics，sarek 会额外加一个独立的
   `GATK4_ESTIMATELIBRARYCOMPLEXITY`。~35–43 GiB/样本、30–40× WGS 上跑了 **6.3 h 还在减速**
   （~40 groups/min，内存 thrashing）；`queueSize=2` 时会占满两个槽位 → variant calling 全被堵住，
   ~53 核闲置。
2. **重写 `BWAMEM2_MEM` 命令行 → 双向击穿 alignment cache**：Spark markdup 需要 queryname-sorted
   输入，sarek 会让 BWAMEM2_MEM 内部发出 `samtools sort -n -@ N`；普通 markdup 是不带 `-n` 的
   `samtools sort -@ N`。脚本文本不同 → task hash 不同 → **开/关 Spark 任何一次切换，都会让已完成的
   比对全部失效**（`.command.sh` diff 验证过）。每切换一次代价约 4.5 h 重新比对。

**默认**：germline WGS 用普通 `GATK4_MARKDUPLICATES`（proj4/proj13 验证过）：单线程 ~3–3.5 h/样本，
但耗时有界、可预测、metrics 内联、没有 ELC 拖尾。只有真的有 Spark/GPU 环境、且先在小样本上验证过，
才考虑打开 Spark。

**经验法则**：`-resume` 只对不改变脚本文本的改动便宜——`cpus`/`memory` 这类 directive 安全，不会
rehash；凡是落进 `.command.sh` 里的东西（Spark 开关、`ext.args`、`--aligner`）上游都会重跑。改参数
前先 `diff` 一下新旧 `.command.sh`，别假设上游能复用。

---

## 2. CNNScoreVariants 是隐藏的 CPU 大户，内存限流对它无效

germline 变异过滤阶段的 **CNNScoreVariants** 实测 **%cpu 843–920%（≈8.7 核，TensorFlow 多线程）**，
但 **peak_rss 只有 1.7–1.9 GB**。

**后果**：靠"内存预算自动限流"的 nextflow config 对它**完全无效**（RSS 太小永远触发不了限流）。若
不显式声明 `cpus`，它按默认 `process_medium`（cpus=4）拿到 `56/4=14` 个并发席位；5–6 个样本同时跑
CNN 就是 ~43 核，再叠加 germline 收尾阶段 HaplotypeCaller 尾巴（同一样本 HC 一完成就启动该样本的
CNN，两阶段相位重叠），实测总 CPU 需求 ≈70 核压在 56 线程预算上。

**实测事件**：project 14 Study B，load 1min 峰值 **152.80**，15min 均值 124.83，持续 ~2h15m（内存
全程健康，纯 CPU 超订）。

**规则**（适用所有 sarek germline 运行）：
1. config 必须显式 `withName: '.*CNNSCOREVARIANTS.*' { cpus = 9 }`；且把 `executor.cpus` 压到
   **48**（不是 56）——load 会把 iowait(D 状态) 线程也计入，56 容易让 load 冲过 60，留 8 线程余量能把
   实测 load 稳定在 ≤56。
2. 通用教训：**内存限流对"低 RSS 高线程"进程无效，必须显式限核**——凡实测 `%cpu` 远超声明 `cpus`
   的进程都要显式右调。
3. 资源预算按 `execution_trace` 里的**实测 %cpu** 核算，不要用 declared cpus（declared 只决定席位数,
   往往被低估/高估）。
4. 独占整机跑 germline 时，给变异调用段的 `executor.cpus` 留出 HC 尾巴 + CNN 叠加的缓冲。

关联：[[reference_corun_concurrent_pipelines]]（那份是多管线并跑降配；本条是独占整机也会超订的补充）。
