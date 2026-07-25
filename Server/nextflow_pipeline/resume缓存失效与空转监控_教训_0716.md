# nextflow 通用教训：`-resume` 何时救不了你 / 监控如何漏掉"活着但空转"

- **文档日期（创建，immutable）**: 2026-07-16
- **来源事故**: `16_Wenliang_Pan_wgs`（germline WGS，sarek 3.8.1），净亏 ~15.4 h
- **完整叙事版**: `16_Wenliang_Pan_wgs/事故复盘_提速反噬_resume失效_监控缺位_0716.md`
- **本文定位**: **只抽跨项目通用的判据**，供任何 nextflow 项目（sarek / rnaseq / taxprofiler / mag …）复用。
- **相关**: `/corun` skill、`nextflow_watchdog.sh`、`concurrent_nextflow/concurrent_nextflow_resource_lessons_0710.md`

---

## 1. `-resume` 的 cache 键 = task 的 **script 文本 hash**

**核心规则：`-resume` 只对「不改 script 文本」的改动便宜。**

| 改动类型 | 是否进 `.command.sh` | cache | 例子 |
| :--- | :---: | :---: | :--- |
| **directive** | 否 | ✅ 保留 | `cpus`、`memory`、`queueSize`、`errorStrategy` |
| **进命令行的 flag** | 是 | ❌ 全废 | `ext.args`、`--aligner`、工具参数、**pipeline 级 flag（见下）** |

### ⚠ 最隐蔽的坑：一个 flag 会改写"看似无关"的**上游**进程的命令行

proj16 实证：`--use_gatk_spark markduplicates` 是 **markdup 的** flag，却改写了 **`BWAMEM2_MEM`（比对）** 的命令行——
因为 Spark markdup 需要 queryname-sorted 输入，sarek 遂给比对发出 `samtools sort -n -@ 16`；常规 markdup 则是
`samtools sort -@ 16`（无 `-n`）。`diff` 两次 run 的 `.command.sh` 可实证。

后果：**script 文本变 → hash 变 → 整个比对阶段 cache 作废，且开/关各废一次**（加 flag 废一次，去 flag 再废一次）。

- **纪律：改参数重启前，先 `diff` 新旧 work dir 的 `.command.sh` 确认影响面。** 别假设"我只改了 X，上游能复用"。
- **心智模型：`-resume` 不是后悔药，是断点续跑。** 它只在"参数没变、只是中断了"时救你；
  用它"撤销一个决定"通常是全价重跑。

### ⚠ 读 cache 命中数要看构成，不能只看数量

proj16 run3 显示 `Cached process` **31** 条，看着很美好。实际构成：21 个几秒钟的 `TABIX`、2 个 `FASTQC`、
2 个 `FASTP`…… 而**真正值钱的 24 个 `BWAMEM2_MEM` 只命中 1 个**。

```bash
# 正确的查法：看命中了"哪些"，而不是"多少个"
grep -ah "Cached process" .nextflow.log | grep -oE "[A-Z0-9_]+ \(" | sort | uniq -c | sort -rn
```

---

## 2. 读 nextflow 日志：`Task completed` **不等于**成功

```
Task completed > TaskHandler[id: 129; name: ...GATK4_ESTIMATELIBRARYCOMPLEXITY; status: COMPLETED; exit: 129]
```

- `Task completed` / `status: COMPLETED` 只表示**任务结束了**，不表示成功。
- **必须看 `exit:` 字段**：`exit: 129` = `128 + 1` = **SIGHUP**，即被信号杀掉。
  （通用：`exit > 128` ⇒ 被信号终止；`128+N` 的 N 就是信号号。）
- proj16 中这两个 ELC 跑了 6.4 h **到死都没算完**，日志里却写着 `COMPLETED` —— 误读会得出"它跑完了"的错误结论。

---

## 3. 监控必须覆盖「活着但空转」—— 最贵的故障不触发传统告警

### 3.1 现有 `nextflow_watchdog.sh` 的盲区（实测）

proj16 的 ELC 空转状态：**tmux 会话活着 + 内存充足 + 单线程磨洋工 + ~53 核空转 6.4 h**。
对照通用看门狗的三条规则：

| 规则 | ELC 空转时 | 命中？ |
| :--- | :---: | :---: |
| `SESSION_END` | 会话好好活着 | ❌ |
| `LOW_MEM` | 内存充足（ELC 不吃内存） | ❌ |
| `HEARTBEAT` | 90 min 时 `exit 12` 等**上层复检** | ⚠ **夜里没有上层 = 等于没监控** |

**三条一条都不命中。** 看门狗只会在日志行里默默记下 `nflog+300m`，却不告警。

> **通用教学要点：绝大多数监控只查「死没死」（进程在否、内存够否），
> 而真实世界里最贵的故障往往是「活着但空转」—— 它不触发任何告警，可以安静地烧一整夜。**

### 3.2 需要补的两条规则

| 规则 | 判据 | 抓什么 |
| :--- | :--- | :--- |
| **`STALLED`** | `.nextflow.log` 停滞 > 45 min | 流程没在推进（单任务卡死/空转） |
| **`LOW_CPU_UTILIZATION`** | load 连续 30 min < 阈值（如 10） | **会话活着但核在空转**（ELC 型单线程阻塞） |

**参考实现**：`16_Wenliang_Pan_wgs/scripts/10_watchdog.sh` —— 永不退出、自我循环（不靠上层复检）、
只告警不 kill、告警单独落 `logs/watchdog_ALERTS.log`。**两条规则已实测触发。**

> **⚠ 待办（需用户批准后再动共享文件）**：这两条规则目前只在 proj16 本地实现。
> `nextflow_watchdog.sh` 是跨项目共享文件，**所有项目都缺这两条规则**，
> 是否并回共享看门狗待定 —— 未经批准不擅改共享文件。

### 3.3 ⚠ 投递路径：**只写日志文件的告警 = 日记，不是告警**

监控做对了，告警也触发了，**但没人读到，等于没监控**。proj16 第一版看门狗把告警写进
`logs/watchdog_ALERTS.log` 就完事 —— 那个文件只有 agent 去读才会被读到，而 agent 只在用户开口问时才读。
**即："如果用户不问，永远不会发现"** —— 与"监控 3 分钟就退出"是同一个洞的两种形态。

| 渠道 | 依赖 | 夜间（agent 不在）有效？ |
| :--- | :--- | :---: |
| 写 `$ALERT_LOG` | 无 | ❌ 没人读 |
| **定向写用户自己的 tty** | 用户开着终端 | ✅ **脚本自主可达** |
| agent 的 Monitor → IDE 弹窗 | agent 会话在线 | ❌ |
| agent 调 MCP 发邮件 | agent 会话在线 | ❌ |
| **脚本自带 SMTP 凭据发邮件** | app password | ✅ **唯一真正覆盖夜间的方案** |

- **bash 脚本【调不了 MCP】** —— MCP 工具只有 agent 能调。想让 tmux 里的看门狗自己发信，
  必须给它独立的 SMTP 凭据（app password），没有第三条路。
- **不要用 `wall`**：它广播给机器上**所有**用户。要定向就只写运行者自己的 tty。

#### ⚠⚠ tty 枚举必须用 `ps`，**绝不能用 `who`**（2026-07-16 实测，踩到了）

`who` 读的是 utmp **登录会话**记录 —— **IDE（Positron/VS Code）的集成终端不注册 utmp**。实测本机：

| 枚举方式 | 见到的 pts | 含用户真正在用的终端？ |
| :--- | :---: | :---: |
| `who` | 5（全是 tmux pane） | ❌ **漏掉 pts/1** |
| `ps -eo tty -u $USER` | 15 | ✅ |

用户当时正在 Positron 的 **pts/1** 工作，而 `who` 里没有它 → **告警发不到人眼前，日志却显示
"已发送到 5 个终端 ✅"**。**又一个"看起来成功的静默失败"**，与 `MT`→`chrMT`、`exit:129` 被读成
`COMPLETED`、cache 命中 31 里只有 1 个 BWAMEM2 是同一模式：**程序没报错，只是没做到该做的事。**

正确写法：
```bash
for t in $(ps -eo tty -u "$USER" | grep -oE 'pts/[0-9]+' | sort -u); do
  [ -w "/dev/$t" ] || continue
  printf '...' > "/dev/$t"
done
```

### 3.4 纪律

- **`tmux ls` 里每个跑长任务的会话，都必须有一个配对的常驻监控会话。**
  （proj16 现为 `pan_wgs` + `pan_watch` + `pan_down`。）
- **监控进程必须在 tmux**：Bash `run_in_background` 与 agent 会话同生共死——agent 一断监控就没了，而长任务还在跑。
- **Phase-1（3 min 启动确认）退出的那一刻必须无缝接上 Phase-2（10–20 min 巡检直到结束）。**
  「Phase 1 通过」只等于"启动没炸"，**不等于"监控已完成"**。
- **"看门狗启动了" ≠ "看门狗会告警"** —— 监控本身也要实测告警会触发（造假停滞日志 / 压低阈值）。

---

## 4. 提速决策的通用判据

| 判据 | 内容 |
| :--- | :--- |
| **⛔ 铁律** | **绝不对健康运行中的 pipeline 做未经验证的"提速"改动。** proj16 的 run1 本来跑得好好的。 |
| **看整条墙钟** | **"多线程"不等于"更快"** —— 要看它是否连带引入别的单线程步骤（Spark markdup → 强制追加单线程 ELC）。评估提速 flag 要看**全流程墙钟**，不是被优化的那一步。 |
| **风险敞口** | 期望收益（省 3.5 h）vs 风险（赔 15.4 h）。**长任务上的"优化"默认答案是"不做"**，除非已在小样本验证过端到端。 |
| **前提意识** | 工具的"便宜/快"都有**前提**（`-resume` 便宜的前提是 script 不变；Spark 快的前提是不引入 ELC）。**把前提当无条件保证，是这两个坑的共同结构。** |

---

*Zhen Gao, PhD — 内部教材。来源事故：`16_Wenliang_Pan_wgs`，2026-07-16。*
