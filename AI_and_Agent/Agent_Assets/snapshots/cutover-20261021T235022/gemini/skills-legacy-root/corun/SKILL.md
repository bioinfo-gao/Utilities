---
name: corun
description: "Use when 要在同一台服务器上同时/排队跑多个重型管线(nextflow/sarek/mag/taxprofiler、长比对、大下载等)且系统资源有限——如何安全并跑、监控、判定故障、-resume 恢复,不把机器跑爆也不误杀健康作业"
disable-model-invocation: true
---

# /corun — 资源受限下多管线并行运行的安全 playbook

> **📍 关联文件组｜项目14「load-152 资源事件」四联档（2026-07-13）** — 以下四份内容互补、共享同一组实测数据，看到任意一份即可定位其余三份（绝对路径，一年后依旧可寻）：
> 1. **根因深挖**：`/home/gao/projects_2026H2/14_geneedit_lats12_wgs/docs/resource_pressure_incident_0713.md` — CNNScoreVariants 超订致 load 峰值 152 的逐层分析 + 配置修正
> 2. **项目14全程负载画像**：`/home/gao/projects_2026H2/facilities/Server/nextflow_pipeline/project14_load_profile_0713.md` — Study A+B 全程峰值/空闲/负载分布
> 3. **wgs skill**：`/home/gao/.claude/skills/wgs/SKILL.md` — CNN 是隐藏 CPU 大户的警告，写入资源 config 节
> 4. **corun skill**：`/home/gao/.claude/skills/corun/SKILL.md` — 哪些阶段可并跑 / 哪些绝对不行 的速判矩阵

场景：**系统资源有限，待跑工作很多。** 本 skill 提炼自 2026-07-09-10 双 sarek 并跑 14.5 h 实测。
完整实测数据与教训见 `projects_2026H2/facilities/Server/concurrent_nextflow_resource_lessons_0710.md`。
**sarek 每步实测耗时+资源画像**见 `projects_2026H2/13_Ellen_knockin_wgs/scripts/sarek_wgs_perstep_timing_and_resources.md`。
通用看门狗脚本：`projects_2026H2/facilities/Server/nextflow_watchdog.sh`。

本机硬件：Threadripper 2990WX，32C/64T，125 GiB RAM，64 GB SSD swap（`swappiness=10`）。
策略上限：**稳态 ≤ 28 物理核 / 56 线程**（设计作业线程预算时按这个数）；
**繁忙期可短时冲到 30 核 / 60 线程**（仅限两作业瞬时同时撞重阶段这类短峰，必须很快回落，不可长期维持），
30/60 是绝不越过的硬顶，永远给 OS/SSH/交互留 ≥2 核 / 4 线程。重 work-dir 一律放 `/mnt/ex_8T_SSD`（SSD、可弃），不放 `/Work_bio`（HDD）。

---

## 决策一：并跑还是排队？

- **内存够 + 想同时推进** → 并跑，守住**两作业核占用之和 ≤ 28 物理核**（稳态）。两条守法(见决策二):
  - **保守(默认)**:每个作业都降配、名义上限之和 ≤28。安全免盯梢,代价是可能小幅牺牲吞吐。
  - **激进**:只降 CPU 重的那个,低 CPU 尾段作业留满配靠阶段自限。吞吐高但须盯梢,回到重阶段即超限。
- **赶时间 / 内存紧** → **排队串行**跑满配。宁可串行快、不要为"看起来并行"把两个都拖慢。
- **经验配额**：两个 sarek（一个比对、一个变异调用）可在本机稳定共存，峰值内存 ~93 GiB、留 32 GiB available。
  **不要叠第三个重活**——28 核预算已满，第三个会让三者都 CPU 饥饿且内存可能顶穿。
- **错峰互补**：让作业处于不同资源画像阶段（比对=重而少 CPU+高 RSS；变异调用=轻而多 CPU）冲突最小。
  先启动的先进入下游，先完成者释放 CPU 让另一个自动提速。

### sarek 每步资源画像速查（实测，用于排程；完整表见上面 timing 文档）

**三大争抢维度**（缺一不可）：① CPU 核（trace `%cpu`）、② 内存（`peak_rss`）、③ **磁盘 I/O 读写量**（`rchar`/`wchar`）。
一个步骤可能同时属于多类（如 TIDDIT 既是内存大户又是 I/O 大户，机理不同、争的资源不同，都要单独看）。

| 步骤 | 实测CPU核 | 峰值RSS | 峰值I/O(读+写)¹ | 类别 → 排程含义 |
| :--- | :---: | :---: | :---: | :--- |
| BWAMEM2_MEM（比对） | ~12–16 | ~30–34 GB | ~93 GB | **CPU+内存+I/O 三重**：两作业比对期**绝不完全重叠**，最该错开 |
| **CNNSCOREVARIANTS（germline 变异过滤）** | **≈8.7（843–920%）** | **仅~1.8 GB** | ~6 GB | ⚠**CPU极端大户/内存与I/O均极轻**：TensorFlow 多线程。**内存/IO 错峰判断都会漏判它！**（RSS+IO 小得像轻活，实则吃~9核）。单条 germline 里 5–6 个并发就~43核 |
| MUTECT2_PAIRED（体细胞） | ~4 | ~4.5 GB | ~6 GB | CPU中/内存轻/I/O轻、量多时长长：适合作为"垫底轻活"与别家比对并跑 |
| GATK4_HAPLOTYPECALLER（germline，按区间） | ~2.2–4.2 | ~1.4–2.4 GB | ~2 GB | CPU中/内存轻/I/O轻、**任务极多、尾巴很长**：末段与 CNN 相位重叠→叠加打满 |
| GATK4_MARKDUPLICATES | ~1.4 | ~34 GB | **~292 GB** | **内存重 + I/O次重、CPU轻**：整条 BAM 读进写出；避开别家内存/IO重步 |
| TIDDIT_SV | ~1.8 | **~57 GB** | **~417 GB** | **内存最重 + I/O最重、波动大**：两家 TIDDIT/MarkDup 同时撞→内存顶峰 + 同盘 I/O 饱和 |
| BWAMEM2_INDEX（一次性） | ~1 | **~56 GB** | ~17 GB | 一次性内存重：建索引时别叠别家内存重步 |
| FASTP（读写全量 FASTQ） | ~7.6 | ~1.3 GB | **~97 GB** | CPU中 + **I/O重**：流式读写整份 FASTQ，短但吞吐大 |
| FASTQC / SAMTOOLS_STATS / MOSDEPTH | 1.6–4 | ≤2 GB | 19–53 GB | CPU轻但**读全量 BAM/FASTQ→I/O中**，随比对期一起不单独排程 |

> ¹ I/O 列是**整个任务生命周期的累计读+写量**（trace 的 `rchar`+`wchar`），衡量"吞吐了多少数据"，不是瞬时带宽；
> 瞬时压力 ≈ 累计量 ÷ 时长（如 TIDDIT 417G/~2h ≈ 58 GB/h）。但累计量本身就能正确排出谁是 I/O 大户。

- **规则**：把每步在**三个维度上分别**归类——「CPU大户」/「内存大户」/「磁盘I/O大户」（可兼属多类）。
  **三个维度都互补→可安心并跑**（一家比对 CPU+I/O 重 vs 另一家 Mutect2 三维都轻）；
  **任一维度同类撞车→在该维度错峰**（两家 BWAMEM2 抢核、两家 TIDDIT/MarkDup 既叠内存又饱和磁盘）。
- ⚠ **只看单一维度判冲突会翻车**：
  - **看内存判 CPU**：CNNScoreVariants RSS 仅 1.8 GB 却吃 ~9 核 → 被当轻活放行，实则 CPU 炸弹。判 CPU 必看 `%cpu`。
  - **看 CPU 判 I/O**：MarkDup/TIDDIT CPU 仅 1.4–1.8 核像"轻活"，却各吞 292/417 GB → 两家同盘重叠会**磁盘带宽饱和**，
    双方都慢、`iowait` 拉高（D 状态进程计入 load，load 会因 I/O 而非 CPU 冲高）。判 I/O 必看 `rchar`/`wchar`。
- **磁盘 I/O 排程要点**：重 work-dir 一律放 `/mnt/ex_8T_SSD`（SSD 带宽高、随机 IO 强，容忍并发 I/O 大户）；
  **HDD 上两家 TIDDIT/MarkDup 对撞会灾难性变慢**。同一物理盘上，别安排两家的 I/O 大户步骤长时间重叠。
- **单样本累计耗时（降配并跑档）**：MarkDuplicates ~4 h/样本(最耗时下游)、TIDDIT ~2 h/样本、比对 ~5–6 块/h。
  估总时长/MultiQC 何时出，用当前 trace 已完成子任务 `submit` 时间戳算真实速率，别凭印象。

### 哪些阶段可并跑 / 哪些绝对不行（速判矩阵）

> 依据：项目14 实测——**单条 germline 内部**的 CNN + HC 尾巴相位重叠就已把整机冲到 **load 152**
> （2026-07-13，详见 `facilities/Server/nextflow_pipeline/project14_load_profile_0713.md`）。
> 推论：凡"单条管线自己就能打满整机"的阶段，**第二条管线的同类阶段绝不能与之重叠**。

| 组合（A 阶段 × B 阶段） | 判定 | 原因 |
| :--- | :---: | :--- |
| A 比对(BWAMEM2) × B 变异调用/去重(Mutect2/MarkDup CPU轻) | ✅ **可并跑** | 画像互补，最佳错峰组合（proj13比对 + proj14 Mutect2 实测长期共存） |
| A 比对 × B 去重/gather 空闲期 | ✅ **可并跑**（还能填空闲） | B 单线程欠载，~50 线程闲置可让 A 吃满 |
| A Mutect2(体细胞,轻多) × B Mutect2 | ⚠ **勉强**（各降配、核和≤28） | 都 CPU 中等，量多；只能保守双降 |
| **A germline 变异调用/过滤(HC+CNN) × B 任何 CPU 重阶段** | ❌ **绝对不行** | CNN≈9核×并发 + HC尾巴，单条就~70核需求，再叠必爆(load>150) |
| **A CNNScoreVariants × B CNNScoreVariants / BWAMEM2** | ❌ **绝对不行** | 两个 CPU 极端大户对撞，直接 2–3× 超订 |
| **A 比对(BWAMEM2) × B 比对(BWAMEM2)** | ❌ **绝对不行**（除非各压到核和≤28） | 既抢核(各~16核)又叠内存(各~34GB)，唯一"CPU+内存双重"对撞 |
| A TIDDIT/MarkDup(内存+I/O重) × B TIDDIT/MarkDup(内存+I/O重) | ⚠ **危险**（可短撞、别长驻） | 双重叠加：内存(57+34≈90G+，~15min自愈) **且** 磁盘 I/O(各吞 292–417G)同盘饱和→双方变慢+iowait拉高 load。别刻意安排 |

- **一句话铁律**：**两条管线的"变异调用/过滤期"绝不能重叠**（germline 的 HC+CNN、或与别家比对期）——
  这是单条就能打满整机的阶段。要并跑，让一条处于比对期(CPU重)、另一条处于去重/gather 空闲期或 Mutect2 轻活期。
- germline 独占跑时也要给 CNN 显式限核（`withName:'.*CNNSCOREVARIANTS.*'{cpus=9}`），否则单条自己就冲 load 152。

## 决策二：怎么配降配 config（保守 vs 激进，按值守条件选）

现代 nf-core 模板用 `process.resourceLimits`（不是 `--max_cpus/--max_memory`）。降配 config 命名要自解释
（如 `local_resources_concurrent_with_projXX.config`）；降配作业单独跑时换回满配版。

| | 保守策略（默认） | 激进策略 |
| :--- | :--- | :--- |
| 做法 | **每个**并跑作业都降配，名义核数上限之和 ≤28（如各 ~12–14 核） | **只降 CPU 重的那个**，低 CPU 尾段作业留满配、靠阶段自限 |
| 优点 | 安全、可预测、**免盯梢**，结构性不超限 | **吞吐更高**，不无谓拖慢已自限的尾段作业 |
| 缺点/风险 | 可能小幅牺牲吞吐（把本就用不满的作业也压着） | **中等风险**：一旦低 CPU 作业回到重阶段，相加瞬间超限，须人工盯梢改配/错开 |
| 何时用 | 无人值守 / 过夜 / 阶段不确定 / 两个都可能进重阶段 | 有人值守 **且**能确认某作业稳定处于低 CPU 尾段 |

> 实测范例（proj13/14，用的是**激进**）：proj14 尾段满配(48线程但实占~10核) + proj13 降配 24 线程 → 相加 ≈ 28 核内。
> 判断"某作业是否已自限"看 trace 的 realtime×%cpu 实占核数，不是配置名义上限。两作业都在比对期时，只能走保守策略、两个都降。

---

## 启动：每个作业各自 tmux（生命周期与 agent 解耦）

```bash
tmux new-session -d -s <name> "cd /path && export NXF_SINGULARITY_CACHEDIR=/Work_bio/gao/configs/.singularity && \
  <nextflow run ...> -work-dir /mnt/ex_8T_SSD/<proj>_work -c <降配config> 2>&1 | tee -a logs/run.log"
```

## 监控：事件驱动看门狗（不被动等成功）

```bash
bash projects_2026H2/facilities/Server/nextflow_watchdog.sh \
  <sess1>:<projdir1>:<logfile1> \
  <sess2>:<projdir2>:<logfile2>
```
- 每 180 s 巡检 session 存活 + `.nextflow.log` 刷新龄 + `free -m` 的 available/swap。
- **只在实际事件退出**（触发上层复检）：某 session 结束(10) / available<2.5GB 连续两次(11) / 90min 健康心跳(12)。
- 后台跑（`run_in_background`），退出即被通知。稳定数小时后可把 `WD_HEARTBEAT` 调大减少唤醒。

---

## 判定与处置（核心纪律——照做，别凭直觉）

1. **看 available，不看 free。** free 常年 <1.5 GB 是正常（cache 占了），available 才是真余量。
2. **健康但慢 ≠ 故障，绝不因慢杀作业。** 只要日志在刷新、trace 无 FAILED，就是在跑。杀健康作业=毁数小时不可逆中间结果。
3. **瞬时内存峰值会自愈，别抢先 `drop_caches`/`swapoff`。** drop_caches 逼作业重读参考更慢；swapoff 在低 free 时可能触发 OOM。
   SSD swap 就是用来吸收峰值的。
4. **真卡死的判据（三者齐备才算）**：进程 wchan 卡 `futex_wait_queue` + 日志 mtime 冻结 >15 min +
   `.nextflow.log` 出现 `No more task to compute -- ... still active`。仅"画面不动"不算——查 `grep -c -w COMPLETED execution_trace_*.txt` 是否在涨。
5. **确认失败/死锁后才重启，且必须显式 `-resume`。** 不带 -resume 会丢弃 work-dir 缓存、白跑数小时。
   择机重启：若失败根因是资源争夺，等另一作业进入低压阶段或先结束，再拉起失败的那个，避免再次对撞。

## 失败后重启模板

```bash
tmux kill-session -t <name> 2>/dev/null
tmux new-session -d -s <name> "cd /path && export NXF_SINGULARITY_CACHEDIR=... && \
  <nextflow run ...> -work-dir <同一 work-dir> -c <config> -resume 2>&1 | tee -a logs/run.log"
```
⚠️ 若项目的运行脚本"首次不带 resume、失败才 resume"，则整段 session 被 OOM 打没后**不能直接重跑该脚本**
（首次那趟会丢缓存）——手动拼带 `-resume` 的显式命令，复用同一 work-dir。
