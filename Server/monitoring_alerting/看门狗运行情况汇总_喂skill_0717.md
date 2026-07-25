# 看门狗（nextflow_watchdog）运行情况汇总 —— 供生成通用 skill

- **创建**: 2026-07-17
- **来源**: proj16（16_Wenliang_Pan_wgs）整个 WGS 运行（sarek germline + 下游 annotate/HLA/origin）中看门狗暴露的全部情况
- **用途**: 明天据此生成一个「通用、适合各项目」的 pipeline 监控 skill 的**原始情况清单 + 设计输入**
- **配套**: 现有实现 `facilities/Server/nextflow_watchdog.sh`（共享脚本）+ 各项目薄封装 `scripts/10_watchdog.sh`；
  已有教训文档 [`resume缓存失效与空转监控_教训_0716.md`](../nextflow_pipeline/resume缓存失效与空转监控_教训_0716.md)（0716 那次 ELC 空转事故）。
  本文是**它的续篇**，专收 0716→0717 这轮暴露的**新**情况。

**更新记录 / change-log**（创建日期不变，修订在此追加）：
- 2026-07-17 — ① 三个脚本已从 `facilities/Server/` 根目录迁至 `facilities/Server/monitoring_alerting/`
  子目录，本文开头「配套」及正文中出现的旧根路径 `facilities/Server/<脚本>` 均应读作
  `.../Server/monitoring_alerting/<脚本>`。② 本文已作为原始输入固化为 skill `/watchdog`
  （`~/.claude/skills/watchdog/SKILL.md`）——§3 的 TODO 清单在 skill §8「已知缺口」中承接。

---

## 0. 一句话结论

看门狗的**监控内核（规则 13/14/15 + notify + 邮件）本身是好的、经过实测标定**；这轮暴露的问题**几乎全在"作用域/编排/协同"层**——
它只守 sarek 一个 nextflow run，看不见下游编排链，且在 sarek 结束的瞬间自杀。skill 要解决的是**"怎么把监控正确地罩住整条流水线"**，
不是重写监控内核。

---

## 1. 本次运行中看门狗出现的全部情况（分类目录）

### 情况 A —— 监控作用域只到 sarek，下游编排链是盲区【最严重，用户追问 3 次】
- **现象**: sarek 02:06 成功完成；下游编排 `pan_down`（annotate→filter→HLA→origin）凌晨 02:07/02:08 连续失败 3/4 步，
  **看门狗一声不吭**，次日人工自查才发现。
- **根因**: `10_watchdog.sh` 只传了**一个**监控目标 `pan_wgs:$PROJ:sarek_run.log`（第 30 行）。作用域 = sarek 那个 run。
  下游 `pan_down` 是**另一个 tmux 会话**，从未被列入监控目标。
- **状态**: 未修（待 skill 决定）。
- **对 skill 的启示**: 监控目标必须**覆盖整条流水线**，不只是 nextflow 主 run。共享脚本本身**支持多目标**
  （`nextflow_watchdog.sh <s1>:<d1>:<l1> <s2>:<d2>:<l2> ...`），但下游编排器不是 nextflow run（没有 `.nextflow.log`/work/），
  现有 3 条规则（都依赖 nflog/work/）对它**不适用** → 需要给"非 nextflow 的下游脚本"设计一类**新监控原语**
  （见情况 F）。

### 情况 B —— SESSION_END 语义使看门狗在"交接点"自杀，恰好在下游 bug 高发区开始时
- **现象**: 看门狗 02:10:51 记 `SESSION_END pan_wgs=COMPLETED` 后**自己退出**（`pgrep` 现在为空）。
- **根因**: 规则 10（脚本第 143-147 行）——任一 session `GONE` 就 `exit 10`，**即使 `WD_PERSIST=1` 也退出**
  （注释明写"没有可监控对象了"）。于是 sarek 一完，看门狗死，而这**正是下游链（最容易出低级 bug 的部分）开始的时刻**。
- **状态**: 未修。
- **对 skill 的启示**: "被监控对象结束" ≠ "该收工"。若还有下游阶段，看门狗应**转而接管下游**，而不是退出。
  skill 需要一个"阶段交接"概念：run A 结束 → 自动把监控焦点切到 run B / 下游脚本。

### 情况 C —— 编排器软失败 + 不接入告警渠道 = 静默吞错
- **现象**: 下游编排 `9_run_downstream_when_ready.sh` 的 `run_step` 对失败步骤记 `>>> FAIL ... continuing`，
  末尾**无条件**写 `ALL_DONE`；这些**都不写入 `watchdog_ALERTS.log`**，也不触发 notify/邮件。
- **根因**: "autonomous 软失败继续" 与 "告警" 被做成了二选一。软失败继续本身没错（符合用户 autonomous 指令），
  但**缺了配套告警**。
- **状态**: 未修。
- **对 skill 的启示**: 两层都不报警才是最坏。**"继续跑"和"告警"要解耦**：每个 `FAIL` 必须同步写 ALERTS +
  触发邮件；结尾 `ALL_DONE` 改为如实汇总 `DONE:.. FAILED:..`。这是最小、最该先做的一条（成本最低、收益最高）。

### 情况 D —— 队列限流（load 低但队列深）看门狗结构上抓不到
- **现象**: HC scatter 阶段 `queueSize=2` 成瓶颈，2 RUNNING/54 queued、load 4.2、56 线程只用 ~4.4，是**用户询问时**才发现的。
- **根因**: 规则 14 `LOW_CPU_UTILIZATION` 阈值 `WD_LOW_LOAD_MIN=240min(4h)`——**刻意**设长于最长合法单线程阶段
  （markdup 3.5h）以防"狼来了"。本次低 load 只持续 ~25min，远不到 4h，故不触发。即**队列限流最坏要空转 4h 才告警**。
- **状态**: 未修（是设计权衡的副作用，不是 bug）。
- **对 skill 的启示**: `load` 单一信号**无法区分**「合法单线程（markdup，队列浅）」与「限流空转（队列深）」。
  **queue depth 能一击区分**（限流 = load 低 **且** nextflow submission queue 深），现有规则没用这个信号。
  skill 可加一条"低 load + 队列深 → 疑似限流/配置问题"的规则，把 4h 窗口缩短。

### 情况 E —— TTY 告警跨项目/跨 session 串扰【假告警来源】
- **现象**: proj16 的 `pan_wgs`/`pan_down` pane 里弹出 `LONG_TASK zz/deadbe`，指向
  `/tmp/.../scratchpad/wd3/proj/work/zz/deadbe`——**根本不是 proj16 的 work 目录**，看着像 proj16 有个卡了 7h 的 task。
- **根因**: `notify_ttys`（第 82-90 行)刻意写用户**所有** pts（为了确保睡觉/换终端也能送到，这个设计是对的）。
  副作用是**机器上任何一个看门狗实例**的告警都会喷进**所有**终端，包括无关项目的 pane。经核实 proj16 自己的
  `watchdog_ALERTS.log` 是干净的（只有 2 条自测），那条 `zz/deadbe` 来自**另一个 session 的看门狗测试实例**。
- **状态**: 设计权衡；未改。
- **对 skill 的启示**: 多看门狗并存时，TTY 告警要**带项目标签**（`[proj16]`/`[proj14]`），否则一眼分不清是哪个项目、
  甚至误判本项目故障。skill 应强制每条告警前缀项目名 + 会话名。

### 情况 F —— LONG_TASK 去重标记是全局 /tmp，跨项目/跨run 可能冲突或残留
- **现象**: 规则 15 用 `/tmp/.wd_${key}`（`key=longtask_$(basename workdir)`）去重（第 179-181 行）。
- **根因**: `/tmp` 全局命名空间；`basename` 是 nextflow work 的 hash 短目录名，理论上两项目可撞；且标记**不随 run 清理**，
  下次可能残留导致漏报或误判。
- **状态**: 未改。
- **对 skill 的启示**: 去重标记应**按项目/run 命名空间隔离**（如 `/tmp/.wd_<projtag>_<key>`），并在启动时清理本项目旧标记。

### 情况 G —— 监控本身要在 tmux、且必须 PERSIST（0716 教训，本轮已正确执行）
- **现象**: 本轮看门狗以 `tmux new-session -d -s pan_watch` + `WD_PERSIST=1` 跑，整夜稳定巡检（10min 一跳），
  sarek 阶段监控**没有**再出 0716 那种"夜里零监控"的问题。
- **状态**: 已是正确姿势（0716 教训的成果）。
- **对 skill 的启示**: skill 的启动模板必须内建 `tmux new-session -d` + `WD_PERSIST=1`；这是硬约束，不是可选项。

### 情况 H —— 重启被监控作业会误伤下游 watcher（协同风险）
- **现象**: 我为 HC 提速 kill+重启 `pan_wgs` 时，下游编排器 `pan_down` 的 liveness 判据
  （`tmux has-session pan_wgs` 消失 + 无成功标志 → `exit 1`）**差点触发自杀**，靠 120s+20s 轮询与 ~50s 重启空窗错开而侥幸存活。
- **状态**: 侥幸；未加保护。
- **对 skill 的启示**: 监控/编排组件的 liveness 判据要能容忍**受控重启**（如 restart 前置一个 sentinel 文件让下游 watcher 暂停判定）。
  skill 文档应写明"重启被监控作业时，必须同时暂停/协调其下游 watcher"。

---

## 2. 已沉淀、经实测标定的部分（skill 应原样继承，别重犯）

来自 0716 事故 + 本轮，均已写进共享脚本头部，**这些是看门狗真正的价值，skill 必须保留**：

1. **`.nextflow.log` mtime = 存活心跳，不是进度信号**：ELC 空转 6.4h 里 nflog 每 2.5min 仍写 → STALLED(45m) 在真停滞时**永不触发**。
   规则 13 的真实作用域仅"nextflow 本体死了"。
2. **低 load ≠ 故障**：合法 markdup 单线程 ~3.5h 时 load 仅 4-6。LOW_LOAD 阈值**必须长于最长合法单线程阶段**，否则狼来了。
3. **单 task 运行时长是区分"空转"与"合法慢"的唯一可靠信号**（规则 15 LONG_TASK，扫 `.command.begin` 无 `.exitcode`）。三条里最有用。
4. **notify 用 `ps` 枚举 pts，绝不用 `who`**：IDE（Positron/VSCode）集成终端不注册 utmp，`who` 只见 5/15 个 pts，
   漏掉的正是用户在用的那个 → "看起来已发送"的静默失败。
5. **只写日志文件 = 日记不是告警**；三渠道夜间覆盖差异：`notify_ttys`(要开着终端)、`agent Monitor`(要会话在线)、
   **`send_mail_alert`(自带 SMTP 凭据，唯一真覆盖夜间)**。
6. **只监控告警、绝不自行 kill/重启**——那是需要判断的运维决策，交给人/agent（"健康但慢绝不杀"）。

---

## 3. 喂给 skill 的 TODO 清单（按优先级）

> 优先级标签（软件/事故分级惯例，P = Priority）：**P0** = 必须先做的关键项；**P1** = 重要但不阻塞；**P2** = 锦上添花。

| 优先级 | 项 | 对应情况 | 成本 |
| :--- | :--- | :---: | :---: |
| P0 | 编排器每个 `>>> FAIL` 同步写 ALERTS + 触发邮件；`ALL_DONE`→如实汇总 | C | 低 |
| P0 | 监控目标覆盖下游（多目标 / 阶段交接），SESSION_END 后接管而非自杀 | A,B | 中 |
| P1 | 告警前缀强制带 `[项目名:会话]`，消除 TTY 串扰误判 | E | 低 |
| P1 | 新规则"低 load + 队列深 → 疑似限流/配置问题"，缩短 4h 窗口 | D | 中 |
| P2 | LONG_TASK 去重标记按项目命名空间隔离 + 启动清理 | F | 低 |
| P2 | 受控重启协议:restart 被监控作业时暂停下游 watcher 判定 | H | 中 |

---

## 4. "把看门狗设置做成 skill" 合理性评估（回答用户提问）

**结论：合理，但要框定为"流程监控 setup 的 procedure/checklist skill"，不是重写脚本。**

**为什么合理**：
- 看门狗积累了大量**非显然、易错、错了很贵**的标定知识（3 条规则的阈值依据、ps-not-who、邮件覆盖夜间、
  阈值绑定 markdup 3.5h……）——这正是 skill 该固化的"程序性知识"。
- 触发时机清晰：**"启动任何过夜/长时 pipeline 前，先正确架好监控"** 是一个明确 trigger，符合 skill 的用法。
- 已有 `/corun` skill 引用了这个看门狗，监控 skill 与现有结构契合，不是凭空造。

**必须框定的边界（否则会做歪）**：
- **skill ≠ 重写监控脚本**。共享脚本已存在且经实测，skill 的产物应是**"怎么按项目正确接线"的 procedure**：
  传哪些监控目标（含下游）、PERSIST+tmux 硬约束、阈值怎么按本项目的合法单线程阶段来定、启动前 checklist。
- **skill 的真正增量是决策内容，不是启动命令**。若 skill 只说"tmux 里跑 10_watchdog.sh"，太薄，不值得做成 skill。
  值得做，当且仅当它打包了：①第 2 节的标定沉淀 ②第 3 节的 TODO（作为"已知缺口/要先补的" ）③启动前 checklist。
- **建议先补 P0 再固化**：情况 A/B/C（下游盲区）是这轮最痛的，且是 skill 要教的核心。若带着这些缺口固化，
  skill 会把盲区一起复制到每个项目。**理想顺序：先在共享脚本补 P0（下游告警接入 + 多目标/阶段交接）→ 再写
  skill 固化正确用法**。P1（TTY 前缀、队列深规则）可随 skill 一起做或稍后补，不阻塞固化。

**一句话**：做，但做成"过夜跑 pipeline 前如何正确架监控"的 checklist-skill（薄封装共享脚本 + 标定知识 + 缺口清单），
不要做成"又一个监控脚本实现"。
