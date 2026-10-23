---
name: watchdog
description: "Use when 要启动任何过夜/长时/无人值守的 pipeline（sarek/rnaseq/taxprofiler/mag、长比对、大下载、下游编排链…）——在启动前如何正确架好监控+告警投递，让「出事到被发现」的延迟有界（最坏 30min 而非一整夜），且整条链不依赖 agent 在场"
disable-model-invocation: true
---

# /watchdog — 过夜/长时 pipeline 监控与告警投递 setup

> **本 skill 是「怎么按项目正确接线」的 procedure/checklist，不是又一个监控脚本实现。**
> 监控内核（`nextflow_watchdog.sh` 的规则 10–15 + notify + 邮件）已存在且经 proj16 实测标定，别重写；
> skill 的增量是**决策内容**：传哪些监控目标（含下游）、阈值怎么按本项目的合法单线程阶段来定、
> 启动前 checklist、以及**已知盲区怎么手动补**。

> **📍 关联文件组（绝对路径，一年后仍可寻）**
> - **完整部署手册 / 标定理由**：`/home/gao/Utilities/Server/monitoring_alerting/长任务监控与告警投递_完整方案_0716.md`
> - **本轮暴露的新情况 + 缺口清单（喂本 skill 的原始输入）**：`.../monitoring_alerting/看门狗运行情况汇总_喂skill_0717.md`
> - **0716 空转事故教训（续篇的前篇）**：`.../nextflow_pipeline/resume缓存失效与空转监控_教训_0716.md`
> - **并跑资源策略**：skill `/corun`（引用同一套看门狗）
> - **通知渠道速查**：skill `/notify`（2026-07-23）——本 skill 的告警投递层（tty广播+`wd_sendmail.py`）
>   的轻量速查入口，供**不需要整套 pipeline 监控规则、只是"随便一个脚本要通知用户"**的场景直接抄
>   （例如 `facilities/Server/disk_monitor/disk_space_watchdog.sh` 这类整机级监控）。两个 skill
>   互相引用，别只知道其中一个。

> **⚠ 脚本 canonical 位置（2026-07-17 起）**：三个脚本在
> `/home/gao/Utilities/Server/monitoring_alerting/`
> （`nextflow_watchdog.sh` / `wd_guard.sh` / `wd_sendmail.py`）。
> **它们被多处文档 + `/corun` skill + crontab 用绝对路径引用——移动即静默失效。**
> 若在别处看到 `facilities/Server/<脚本>`（旧的根目录路径），那是过时引用，需同步改。

---

## 0. 一句话

**监控不是运维琐事，它是损失的乘数。** 同一个 bug，有监控值 1 小时，没监控值 6+ 小时。
proj16 事故：11h 无人监控把一个小坑放大成净亏 ~15.4h。本套方案把「出事→被发现」压到**最坏 30min**，
且**没有一环依赖 agent（Claude）在场**。

## 何时用（trigger）

- **启动任何过夜 / 预计跑数小时 / 无人值守的作业之前**——先架监控，再放手。
- 覆盖对象**不限 nextflow**：sarek、rnaseq、taxprofiler、mag、长比对、大下载、以及**下游编排脚本链**。
- `tmux ls` 里**每一个跑长任务的会话，都必须有配对的常驻监控**——这是硬约束不是可选项。

不适用：秒级/分钟级的小命令（直接 Bash 跑完即可，不值得架监控）。

---

## 1. 架构：四层，每层都不依赖 agent

```
  ┌─ 作业层    tmux <proj>_wgs        ← 长任务本体（sarek 等）
  ├─ 监控层    tmux <proj>_watch      ← 看门狗，永不退出(WD_PERSIST=1)，10min 巡检
  ├─ 守护层    crontab 每 30min       ← 看门狗死了？复活它 + 发信告知（监控本身也要被监控）
  └─ 投递层    wd_sendmail.py         ← 脚本自带 SMTP，唯一覆盖夜间的渠道
                 + 定向写用户 tty（要开着终端）
                 + (可选) agent Monitor → IDE 弹窗（要会话在线）
```

**每一层都要问「它坏了谁会知道」**：作业坏→看门狗知道；看门狗坏→guard 知道；告警发不出→**实测过才知道**。

## 2. 六条经实测标定的核心知识（原样继承，别重犯）

这些是看门狗真正的价值，**不是显然的、错了很贵**：

1. **`.nextflow.log` 的 mtime = 存活心跳，不是进度信号。** ELC 空转 6.4h 里 nflog 每 ~2.5min 仍写、mtime 从未变旧
   → `STALLED(rule 13)` 在真停滞时**永不触发**，它只抓「nextflow 进程本身死了」。
2. **低 load ≠ 故障。** 合法 `GATK4_MARKDUPLICATES` 近单线程跑 ~3.5h 时 load 仅 4–6。
   `LOW_LOAD` 阈值**必须长于最长的合法单线程阶段**（→ 默认 4h），否则狼来了 = 等于没告警。
3. **单 task 已运行时长是区分「空转」与「合法慢」的唯一可靠信号**（rule 15 `LONG_TASK`：扫 `work/` 下有
   `.command.begin` 无 `.exitcode` 的 task）。三条新规则里最有用——**直接点名哪个 task 在磨**。
4. **枚举 tty 用 `ps`，绝不用 `who`。** IDE（Positron/VSCode）集成终端不注册 utmp，`who` 只见部分 pts，
   漏掉的正是用户在用的那个 → 「日志显示已发送 ✅，人却没收到」的静默失败。
5. **只写日志文件的告警 = 日记，不是告警。** 三渠道夜间覆盖：`notify_ttys`(要开着终端) / `agent Monitor`(要会话在线)
   / **`send_mail_alert`(自带 SMTP，唯一真覆盖夜间)**。bash 脚本调不了 MCP，想夜间发信只能给它独立 SMTP 凭据。
6. **只监控告警，绝不自行 kill/重启。** 那是需要判断的运维决策，交给人/agent。**健康但慢，绝不杀。**

## 3. 六条告警规则与阈值

| 退出码 | 规则 | 触发条件 | 抓什么 |
| :--- | :--- | :--- | :--- |
| 10 | `SESSION_END` | tmux 会话消失 | 作业结束/崩溃（**对任意 tmux 会话都有效，含非 nextflow 下游**） |
| 11 | `LOW_MEM` | available < 2.5 GB 连续 2 次 | OOM 风险 |
| 12 | `HEARTBEAT` | 健康心跳 | 存活确认 |
| 13 | `STALLED` | `.nextflow.log` 停滞 > 45min | **仅「nextflow 本体死了」**（心跳掩盖停滞，见 §2.1） |
| 14 | `LOW_CPU_UTILIZATION` | load < 10 持续 **4h** | 核在空转（阈值必须 > 最长合法单线程阶段） |
| 15 | `LONG_TASK` | 单 task 运行 > **5h** | **最有用：点名哪个 task 在磨** |

> **判断「低 load 是否正常」的通用判据**：load 本身永不可解读，必须与「当前在跑哪个 task」配对：
> ① 哪个 task 在跑 `grep -a "Submitted process" .nextflow.log | tail -3` → ② 查它的预期 CPU 画像与耗时
> （项目 plan / `/wgs` skill / 历史 `execution_trace_*.txt`）→ ③ 已跑时长 vs 预期：内=正常，超=查。

## 4. 部署到一个新项目（复制即用）

设会话名前缀 `<P>`（如 `pan`）、项目目录 `$PROJ`。

**① 项目内薄封装** `scripts/10_watchdog.sh`（勿复制看门狗本体，直接调共享实现；阈值按本项目合法单线程阶段调）：

```bash
#!/usr/bin/env bash
set -uo pipefail
PROJ=/home/gao/projects_2026H2/<你的项目>
WD=/home/gao/Utilities/Server/monitoring_alerting/nextflow_watchdog.sh
exec env \
  WD_PERSIST=1 WD_POLL=600 \
  WD_LOG="$PROJ/logs/watchdog.log" \
  WD_ALERT_LOG="$PROJ/logs/watchdog_ALERTS.log" \
  WD_STALE_MIN=45 WD_LOW_LOAD=10 WD_LOW_LOAD_MIN=240 WD_MAX_TASK_H=5 \
  bash "$WD" \
  "<P>_wgs:$PROJ:$PROJ/logs/run.log"
  # ⚠ 多目标：有下游编排会话就一并列上（见 §5），如再追加 "<P>_down:$PROJ:$PROJ/logs/downstream.log"
```

**② 起作业 + 立刻起看门狗**（两条一起，别拆开）：

```bash
tmux new-session -d -s <P>_wgs   "cd $PROJ && <nextflow run ...> 2>&1 | tee -a logs/run.log"
tmux new-session -d -s <P>_watch "bash $PROJ/scripts/10_watchdog.sh"
```

**③ 装守护**（每 30min；用 `9,39` 而非 `0,30` 避开整点拥挤）：

```bash
crontab -e   # 追加（注意脚本在 monitoring_alerting/ 子目录）
9,39 * * * * /home/gao/Utilities/Server/monitoring_alerting/wd_guard.sh <P>_wgs <P>_watch 'bash /home/gao/projects_2026H2/<项目>/scripts/10_watchdog.sh' >/dev/null 2>&1
```

**④ 验证（必做，见 §6）。**

**⑤ 项目结束后**：`crontab -e` 删掉该行（否则作业没了 guard 每 30min 空跑一次——残留）。

> **频率标定**：目标是把「发现延迟」压到有界，不是秒级复活。30min 足矣（最坏丢 30min 监控 vs 事故当晚丢 11h）。
> 更密（13min）属过度设计。

---

## 5. ⚠ 最痛的盲区：监控只罩 sarek，下游编排链是盲区（proj16，用户追问 3 次）

sarek 02:06 成功完成 → 下游编排 `pan_down`（annotate→filter→HLA→origin）凌晨连续失败 3/4 步，
**看门狗一声不吭**，次日人工才发现。根因两条，架监控时**必须手动补**：

1. **监控目标只传了 sarek 一个 run。** 下游编排器是**另一个 tmux 会话**，从未列入监控目标。
   → **修**：把下游会话也作为监控目标传进去（`<P>_down:$PROJ:$PROJ/logs/downstream.log`）。
   注意下游编排器**不是 nextflow run**（没有 `.nextflow.log`/`work/`），rule 13/14/15 对它不适用，
   但 **rule 10 `SESSION_END` 对任意 tmux 会话都有效**——至少能抓到「下游会话异常消失」。

2. **看门狗在 sarek 结束的瞬间自杀**（rule 10：任一 session `GONE` 就 `exit 10`，即使 `WD_PERSIST=1`），
   恰好在下游 bug 高发区开始时死掉。→ **「被监控对象结束」≠「该收工」**：若还有下游阶段，
   要么把下游会话与主 run **一起**作为多目标传入（这样主 run 结束时下游会话仍在→不触发 SESSION_END 退出），
   要么主 run 结束后**再起一个看门狗接管下游**，别让监控在交接点断掉。

3. **下游编排器软失败必须接入告警**（proj16 最该先补的一条，成本最低收益最高）：
   编排脚本对失败步骤记 `>>> FAIL ... continuing`、末尾无条件 `ALL_DONE`，**都不写 ALERTS、不发邮件** = 静默吞错。
   「autonomous 继续跑」与「告警」要**解耦**：每个 `FAIL` 必须**同步写 `watchdog_ALERTS.log` + 触发一封
   `wd_sendmail.py` 邮件**；结尾 `ALL_DONE` 改为如实汇总 `DONE:.. FAILED:..`。模板：

   ```bash
   MAILER=/home/gao/Utilities/Server/monitoring_alerting/wd_sendmail.py
   run_step() {  # $1=步骤名 $2..=命令
     local name="$1"; shift
     if "$@"; then echo ">>> OK   $name"; else
       echo ">>> FAIL $name — continuing" | tee -a "$PROJ/logs/watchdog_ALERTS.log"
       echo "下游步骤失败: $name @ $(date '+%F %T')" | "$MAILER" "🚨[$P:down] FAIL $name" - || true
       FAILED="$FAILED $name"
     fi
   }
   # 结尾：如实汇总，别无条件 ALL_DONE
   echo "DONE:$DONE FAILED:${FAILED:-none}" | tee -a "$PROJ/logs/watchdog_ALERTS.log"
   ```

## 6. 验证：「启动了」≠「会告警」（本方案最重要的纪律）

事故的同型错误就是把「启动」当「生效」。**每一条都要看到期望结果，不是「命令没报错」。**

```bash
WD=/home/gao/Utilities/Server/monitoring_alerting/nextflow_watchdog.sh
MAILER=/home/gao/Utilities/Server/monitoring_alerting/wd_sendmail.py

# ① LONG_TASK 会触发（造一个 7h 的假 task）→ 期望 exit 15
mkdir -p /tmp/t/proj/work/zz/aa && touch -d "7 hours ago" /tmp/t/proj/work/zz/aa/.command.begin
tmux new-session -d -s fake 'sleep 300'; touch /tmp/t/proj/.nextflow.log; : > /tmp/t/proj/run.log
WD_LOG=/tmp/t/w.log WD_ALERT_LOG=/tmp/t/a.log WD_POLL=1 WD_STALE_MIN=0 WD_LOW_LOAD=0 WD_MAX_TASK_H=5 \
  bash "$WD" fake:/tmp/t/proj:/tmp/t/proj/run.log; echo "exit=$?"

# ② 反例：3h 的 task 不该误报 → 期望 exit 12(心跳)，a.log 无新告警
touch -d "3 hours ago" /tmp/t/proj/work/zz/aa/.command.begin; rm -f /tmp/.wd_longtask_*

# ③ 守护能复活看门狗，【在 cron 环境下】也能（手动跑通 ≠ cron 跑通）
tmux kill-session -t <P>_watch
env -i HOME=/home/gao PATH=/usr/bin:/bin SHELL=/bin/sh /bin/sh -c \
  "/home/gao/Utilities/Server/monitoring_alerting/wd_guard.sh <P>_wgs <P>_watch 'bash <项目>/scripts/10_watchdog.sh'"
tmux has-session -t <P>_watch && echo "复活成功"

# ④ 邮件真能发出（不看退出码，看收件箱）
echo "测试" | "$MAILER" "[测试] 投递自测" -
```

## 7. 凭据安全（照做，别简化）

- 凭据 `~/.config/nextflow_watchdog/smtp.env`（`chmod 600`，目录 `700`），**必须在 git repo 之外**
  （`projects_2026H2` 是 repo，凭据放进去迟早被提交）。
- 用 **app password** 不是主密码（可独立吊销，不碰 Claude Code 的 Gmail）。发信脚本本身不含密码、从文件读，故可安全入库。
- **不复用 Claude Code 的 Gmail MCP 凭据**：那会被安全策略拦（拦得对），且与 `.claude.json` 耦合、轮换即静默失效。

## 8. 已知缺口 / 待补（按优先级；带着缺口用就是把盲区复制到每个项目）

| 优先级 | 缺口 | 怎么补 |
| :--- | :--- | :--- |
| **P0** | 下游编排器软失败静默吞错 | §5.3：每个 `FAIL` 同步写 ALERTS + 发邮件；`ALL_DONE`→如实汇总 |
| **P0** | 监控不覆盖下游 / 交接点自杀 | §5.1–5.2：下游会话作为多目标传入，或结束后起新看门狗接管 |
| P1 | 多看门狗并存时 TTY 告警串扰（弹到无关项目 pane、易误判本项目故障） | 每条告警强制前缀 `[项目名:会话]` |
| P1 | 队列限流（load 低但 submission queue 深）4h 窗口太长才报 | 加规则「低 load **且** 队列深 → 疑似限流/配置问题」，缩短窗口 |
| P2 | `LONG_TASK` 去重标记用全局 `/tmp/.wd_<key>`，跨项目可能撞/残留 | 按项目命名空间 `/tmp/.wd_<projtag>_<key>` + 启动清理 |
| P2 | 重启被监控作业会误伤下游 watcher | 受控重启前置 sentinel 文件让下游 watcher 暂停判定 |

## 常见错误（红旗——看到就停）

- 「Phase-1 监控打出 done 就退出」→ 把「启动没炸」当「监控已完成」，Phase-2 从未启动。**必须常驻（`WD_PERSIST=1`+tmux）。**
- 监控跑在 Bash `run_in_background` 里 → 与 agent 会话同生共死，agent 一断就没监控。**长任务监控必须 tmux。**
- 只监控 nextflow 主 run，忘了下游编排链 → §5 的盲区。
- 告警只写 `$ALERT_LOG` 不发邮件 → 夜间没人读 = 没监控。
- 因为「慢」就 kill 作业 → 毁掉数小时不可逆中间结果。**确认死锁（wchan futex + mtime 冻结 >15min）才动手。**
- 用 `who` 枚举 tty、用 `wall` 广播 → 前者漏 IDE 终端、后者打扰全机用户。


---

## 启动后的早失败检测与按需状态检查（原在 CLAUDE.md，2026-08-30 搬入）

- Background job follow-up — EARLY FAILURE DETECTION (MANDATORY):
  Programs most often fail in the FIRST 1–3 MINUTES (connection errors, missing
  packages, bad paths, OOM, silent crashes). Passive monitoring that waits for a
  "success" signal will NEVER catch these. Use active two-phase monitoring:

  **Phase 1 — Startup verification (first 3 minutes, ALWAYS do this):**
  After launching a tmux/background job, immediately start a Bash run_in_background
  that polls the log at 30-second intervals for 3 minutes, checking for BOTH
  success signals AND failure signals (error keywords, empty log, dead process):
  ```bash
  # Pattern: poll for success OR failure, whichever comes first
  for i in 1 2 3 4 5 6; do
    sleep 30
    if grep -qiE "error|halted|failed|traceback|cannot|no such" LOG 2>/dev/null; then
      echo "FAILURE DETECTED at ${i}x30s"; cat LOG; break
    fi
    if grep -q "STEP2_MARKER" LOG 2>/dev/null; then
      echo "SUCCESS confirmed"; break
    fi
    echo "Still loading (${i}x30s)..."; tail -3 LOG 2>/dev/null
  done
  ```
  If process is dead AND log shows no completion marker → failure. Fix immediately.

  **Phase 2 — Mid-run monitoring (after 3 min confirmed healthy):**
  Switch to longer-interval background checks (every 10–20 min) until completion.

  **Pipe exit-code trap:** `cmd | tee log.txt` always exits 0 (tee's code).
  For sequential jobs use `set -o pipefail` or check log for errors explicitly
  rather than relying on `&&` after a pipe.


- On-demand status checks — STANDARDIZE ON LAST 15 LINES (user directive 2026-07-09):
  Whenever the user asks "how's project X doing" (or similar, at any point after launch,
  not just the first-3-minutes phase above), check real state directly rather than
  trusting a stale background monitor — read `.nextflow.log` mtime vs now, `tmux
  capture-pane`, and any pipeline log file. **Standardize on the last 15 lines** (`tail -n
  15`) for these ad-hoc log/pane checks by default, instead of picking an arbitrary number
  each time (3, 8, 12...) — consistent enough to actually show recent progress without
  dumping excess output. No new tool/MCP needed for this — it's a plain local `tail`,
  already covered by the Bash tool.

  **Never consider a task "done" just because the tmux session launched.**
  Phase 1 confirmation of actual output is required before reporting "running".
  Failure mode to avoid: launching → reporting "started" → silence → user discovers
  error hours later. This makes autonomous work useless.
