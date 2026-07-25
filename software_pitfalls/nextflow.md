# Nextflow 坑

## 裸布尔 CLI flag 被现代版本变成字符串 → nf-schema 校验全灭

**本机 Nextflow 26.04.4（`mag_biobakery` env）上，裸布尔 CLI flag（如 `--skip_spades`）被赋成字符串
`"true"` 而不是布尔 `true`**，被现代 nf-core 严格的 nf-schema `validateParameters()` 逐个拒绝：
```
* --skip_spades (true): Value is [string] but should be [boolean]
```
**所有裸布尔 flag 同时报错，参数校验期直接 abort**——零算力损失，但 pipeline 根本起不来。

**两个因素叠加**：
1. 新版 Nextflow CLI 把没给值的 `--flag` 填成字符串 `"true"`（旧版会 coerce 成真布尔）。
2. 现代 nf-schema 严格类型校验，不再宽容 coerce。
⚠ `--flag true`（显式给值）**也没用**，还是字符串。

**解法：所有参数一律走 `-params-file`（YAML/JSON）**——布尔=真布尔、路径=真字符串，绕开 CLI
字符串化这一步。等价方案：用 `-c` config 里的 `params { x = true }` 块。

**附带独立 bug**：`checkm2_db` 参数是 `format: file-path`，要的是**文件**（`.dmnd`），不是目录——传库
路径前先查 schema 的 `format` 字段是 `file-path` 还是 `path`。

**阴险点**：
- 版本相关（旧 Nextflow 能跑，问题不会在旧管线上重现）。
- `-profile test` 走的是 params-file，**测不出这个问题**——只有跑真实项目参数时才会咬人（`15_mag_setup`
  的 test profile 全绿就是因为这个）。

**适用范围**：本机所有现代模板的 nf-core pipeline。已实测 **nf-core/mag（Nextflow 26.04.4）触发**。
**taxprofiler**（25.10.4，同样是现代模板）未逐一验证过，但含布尔参数时应优先走 params-file。
**sarek 3.8.1 是旧模板**（用 `check_max`/`--max_cpus`，没有严格 nf-schema）→ **基本不受影响**。

首踩：2026-07-19，project 17 Phase 2 MAG。已固化进 `/tax-assembly-mag`（详）、`/taxnom`、`/wgs` 三个
skill。实例脚本：`17_Daniel_Mendes_gut_metagenomics/scripts/{4_run_mag.sh,params_mag.yaml}`。

## 自定义 resource config 漏配某个 label → 该步骤悄悄吃官方默认值，并发被压低

**症状**：写自定义 `local_optimized.config`（`withName:`/`withLabel:` 混用）时，只挑了几个"重量级"
步骤单独 override（如 STAR_ALIGN/SORTMERNA/SALMON_QUANT）+ `process_medium`/`process_low` 两个通用
标签，**唯独漏了 `process_high`**。结果该 pipeline 里所有标 `process_high` 但没被单独 `withName`
覆盖的步骤（本例是 TRIMGALORE），直接吃 nf-core 官方 `conf/base.config` 的默认值（**12 cpus/task**），
在 28-core 预算下最多只能 2 个并发，实测常被其他并发任务挤到**只剩 1 个在跑**（`.nextflow.log` 里
"上一个完成的同一毫秒下一个才提交"，零重叠，是 maxForks 被间接钳制的典型信号）。**表面现象是"负载
极低但没有 I/O 瓶颈"**（`iostat`/`vmstat` 显示基本空闲），容易被误判成别的问题（网络存储慢、machine
被别的东西占用等）——实际是配置遗漏。

**顺带发现**：该步骤实测真实 CPU 使用（`execution_trace_*.txt` 的 `%cpu` 列）往往远低于声明值（本例
声明 12 核，实测只用 ~7.2 核，~60%），说明官方默认值本身也偏保守/浪费——所以修复不是"调高"而是
"调低单任务声明、调高 maxForks"，用同样的核数预算换更多并发，两头都赚。

**根因排查方法**：
1. `grep -n "label 'process_high'\|label 'process_medium'\|label 'process_low'" <module>/main.nf`
   逐个确认这条 pipeline 实际用到的模块分别标的什么 label——不要凭经验假设某步骤是哪个 label。
2. 对照自己的自定义 config，**四个通用标签（process_low/medium/high/long）只要 pipeline 用到，就必须
   都覆盖**，不能挑着写；漏掉的会静默吃官方 base.config 默认值，不会报错、不会警告。
3. `.nextflow.log` 搜 `Submitted process\|Task completed` 按时间戳看**同一 process 名字**的任务是否有
   时间重叠——零重叠 = 并发被钳制的直接证据，比看 `top`/`uptime` 瞬时快照更可靠。

**适用范围**：任何用 `withName:`/`withLabel:` 手写自定义资源配置的现代 nf-core pipeline（本例实测
nf-core/rnaseq 3.15.1，TRIMGALORE 模块）。凡是自定义 config 里只覆盖了"重点步骤"而非该 pipeline
用到的全部四个通用标签，都有同样风险。

首踩：2026-07-22，project 19 bulk RNAseq（Rell1-KO/WT × TNFa/Tumor，24 mouse samples）。修复后
1分钟 load average 从 4.00 → 20.41，TrimGalore 并发数从常见的 1 个 → 4 个（同一时间戳一起提交）。
