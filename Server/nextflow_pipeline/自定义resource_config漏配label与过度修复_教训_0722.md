# nextflow 通用教训：自定义 resource config 漏配 label → 过度修复吃满预算 → 该重叠的阶段没能重叠

- **文档日期（创建，immutable）**: 2026-07-22
- **来源事故**: `19_Lijian_Wu_Rell1_TNFa_Tumor`（bulk RNAseq，nf-core/rnaseq 3.15.1，24 mouse samples，
  Rell1-KO/WT × TNFa/Tumor）
- **本文定位**：抽跨项目通用的判据，供任何手写 `withName:`/`withLabel:` 自定义资源配置的 nf-core
  pipeline（rnaseq / sarek / taxprofiler / mag …）复用。
- **相关**：`facilities/software_pitfalls/nextflow.md`（同一坑的精简版，索引见 `INDEX.md`）、
  memory `feedback_verify_concurrency_fix_whole_dag`、`feedback_reuse_proven_configs_first`、
  `project_19_lijian_wu_rell1_tnfa_tumor`。

---

## 0. 起因：为什么会去查这个

项目19（24样本，大数据量、预计跑很久）从低资源 corun 配置切到独跑高资源配置（28c/108GB）后，
用户反馈"负载极低"，要求查一下——排查过程牵出了两个连续的配置问题，构成一次完整的教训链。

---

## 1. 自定义 resource config 只挑"重点步骤"覆盖 → 漏掉的步骤悄悄吃官方默认值

**症状**：`local_optimized.config` 手写了 `SORTMERNA`/`STAR_ALIGN`/`SALMON_QUANT`/
`PICARD_MARKDUPLICATES` 四个具体步骤 + `process_medium`/`process_low` 两个通用标签，
**唯独漏了 `process_high`**。TRIMGALORE 模块在 nf-core/rnaseq 里标的正是 `process_high`
（官方 `conf/base.config` 默认 **12 cpus/task**），从未被覆盖，24个样本的 trim 步骤在 28核
预算下最多只能 2 个并发，实测常被其它并发任务挤到**只剩 1 个在跑**。

**表面现象**：`iostat`/`vmstat` 显示基本空闲（不是 I/O 瓶颈），`uptime` load average 远低于
28核预算——容易被误判成"网络存储慢"或"机器被占用"，实际是配置遗漏，不会报错、不会警告。

**排查方法（比看 `top`/`uptime` 瞬时快照更可靠）**：
```bash
# 1. 确认这条 pipeline 里每个模块实际标的是哪个 label —— 不要凭经验假设
grep -n "label 'process_high'\|label 'process_medium'\|label 'process_low'" <module_dir>/main.nf

# 2. 用 .nextflow.log 的时间戳看"同一个 process 名字"的任务是否有重叠
grep -E "Submitted process|Task completed" .nextflow.log | grep <PROCESS_NAME>
# 上一个 Task completed 与下一个 Submitted 时间戳相同/几毫秒之差、零重叠 = 并发被钳制的直接证据
```

**顺带发现**：该步骤实测真实 CPU 使用（`execution_trace_*.txt` 的 `%cpu` 列）往往远低于声明值
（本例声明 12 核，实测只用 ~7.2 核，~60%）——说明官方默认值本身也偏保守，修复方向是
"调低单任务声明、调高 maxForks"，同样的核数预算换更多并发，两头都赚。

**结论**：自定义 config 只要用到 `withLabel:`，就必须覆盖这条 pipeline **实际用到的全部**通用
标签（process_low/medium/high/long），不能挑着写——漏掉的会静默继承官方默认值。

---

## 2. 过度修复：cpus × maxForks 刚好吃满预算 → 其它一切进程被彻底挤出调度

**修复第一版**：给 TRIMGALORE 加 `cpus=7, maxForks=4`（7×4=28，**正好等于整个 28 核预算**）。
验证时只看了"TrimGalore 是不是变快了、load average 是不是涨了"（4.00→20.41）就判定修复生效。

**没验证到的后果**：因为 4 个槽位**始终精确吃满 28/28 核**，且 16 个样本还在排队、一有空位立刻
被下一个 trim 任务补上，**从重启起再没有一刻有空闲核心**——不仅 `STAR_ALIGN`（14核/任务）无法
开始，连一次性、极小的前置步骤 `MAKE_TRANSCRIPTS_FASTA`（`process_low`，仅需2核）都插不进来。
`.nextflow.log` 里 `grep "Submitted process"` 统计，重启后 **20 个任务全部是 TRIMGALORE，其它任何
process 一次都没提交过**——整条下游流水线静默空转了 **~3.5 小时**。

**关键澄清（用户当场指出，值得单独强调）**：这**不是** TrimGalore 自己在空转、也不是 CPU 被浪费——
那4个（后改2个）槽位全程满负荷、真实有效地在处理该处理的样本。**真正的成本是"已经trim完、随时能
送去比对的样本被迫在队列里干等"**——这些样本的 STAR_ALIGN 和"正在trim的其它样本"完全独立
（不同数据、不同核心、无依赖关系），本该同时发生，却因为配置一点余量都没留而被迫串行。

**代价的量化方式**：多阶段流水线如果能重叠（trim 和比对同时对不同样本发生），总耗时 ≈
`max(各阶段单独跑完全部样本的时间)`；如果被迫变成"先做完全部阶段A、再做阶段B"的批次串行，
总耗时 ≈ `各阶段时间相加`。对24个样本、每阶段动辄几十分钟到一小时的项目，这个差距是**小时级**的，
不是"CPU被浪费"，而是**流水线该有的并行性被配置意外关闭**。

**修复第二版**：TRIMGALORE `maxForks` 4→2（cpus 不变，仍 7），合计 14/28 核，**刻意留 14 核余量**
——够 `MAKE_TRANSCRIPTS_FASTA` 随时插入，也够放下一个 `STAR_ALIGN`（14核）并发跑。重启后
`grep "Submitted process"` 立即出现 `MAKE_TRANSCRIPTS_FASTA` 和 `STAR_ALIGN`，堵点解除。

**代价**：两次重启（`-resume`）各打断了当时正在跑的几个 in-flight 任务（trim 到 ~60-70% 的进度
作废重来），但换回流水线恢复正常并行，判断是划算的。

**通用规则**：**任何时候把某个 process 的 `cpus × maxForks` 调到刚好等于（或接近）executor 总预算，
都要显式检查这是否会让其它 process 完全无法调度**——不要让"这一步的并发数"占满整个预算，
必须刻意留出至少能放下"下一个最重的并发任务类型"的余量。

---

## 3. 验证标准的教训：只看被调优的那个指标，不足以证明修复"完成"

第一版修复时只确认了"TrimGalore 变快了、load 涨了"，没有去检查"整条 DAG 是否还在正常推进"——
这正是第2节问题得以潜伏 3.5 小时才被发现的原因（靠用户主动要 status、顺手多查了一眼日志）。

**standing 检查清单（调完任何并发/资源配置后都应过一遍，不只是本次这类问题）**：
1. 重启后几分钟，`grep "Submitted process" .nextflow.log | sed ... | sort -u` 看**除了被调优的
   那个 process，是否还有别的 process 名字在被提交**——健康的多阶段流水线应该是"混合"出现，
   不是一个名字长期独占。
2. "这一步变快了" 和 "其它一切还能正常往前走" 是两件需要分别验证的事，不能用前者替代后者。

---

## 4. 复用"已跑通"的配置：能避免现改出新bug，但不能替代针对新项目的核实

本次两个坑都是"现场手写/现场调整数字"造成的（漏配 label 是原始版本就有的老问题；吃满预算是
本轮临时调整时新引入的）。事后核对同一客户更早的项目（`9_Lijian_Wu_Mouse`，同一 nf-core/rnaseq
pipeline）发现：**它的 `local_optimized.config` 里同样漏了 TRIMGALORE 的 `process_high` 覆盖**——
只是那个项目样本量小（12个 vs 本次24个），瓶颈没被注意到。

**结论（两条要结合，不是二选一）**：
- **默认应该做**：新项目起步优先复制同类型 pipeline 最近一次成功跑通的 config 作为起点，
  不要每次从空白页现改数字——这能避免"现场发明一个新 bug"（如本例的 maxForks=4 精确吃满预算）。
- **不能因此免检**：复用不等于这份配置本身是最优的——"跑完了没报错"不代表"配置调得对"，
  资源配置不当不会失败，只会安静地拖慢总耗时，必须仍按第1/3节的方法核实这条 pipeline 具体用到
  的 label 是否被完整覆盖、DAG 是否在真正并行推进。
- **修复要回填"模板"项目**：本次已把 `9_Lijian_Wu_Mouse/scripts/local_optimized.config` 也同步
  打了 TRIMGALORE 补丁，避免以后复用"项目9的成熟配置"时把老坑重新带回来。
- **⚠ 回填旧项目文件时，必须显式注释标明"这是事后补丁，不是原始记录"**：项目9的配置文件代表的是
  该项目 2026-07-04 实际跑用的配置，若直接改进去而不加说明，会让人误以为项目9当初就是用这个（已修
  复）版本跑的，与项目9当时的 `execution_trace`/耗时记录对不上。**做法**：补丁块前用注释写清楚
  "RETROACTIVE ADDITION"、添加日期、原始运行日期、以及"当初实际跑的版本没有这一段"，让文件本身
  自解释新旧版本的界限，不依赖记忆或外部文档才能看懂。

---

*Zhen Gao, PhD — 内部教材。来源事故：`19_Lijian_Wu_Rell1_TNFa_Tumor`，2026-07-22。*
