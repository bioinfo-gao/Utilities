# Claude Code 当前能力清单（本机实况）

> 姊妹文档：[`0_七大原语对比与实战教学.md`](0_七大原语对比与实战教学.md) 讲**概念区别**；
> **本文只回答一个问题：此刻本机到底装了什么、能用什么。**
>
> **首次生成：2026-08-05**（会话实测 + 本机配置扫描）

## 怎么维护

分两段，维护方式完全不同 —— 这是本文的关键设计：

| 段 | 内容 | 怎么更新 | 会不会漂 |
| :--- | :--- | :--- | :---: |
| **A. 本机配置** | skills / 插件 / MCP / hooks / 自定义 subagent / settings | **跑一次脚本**：<br>`python3 refresh_inventory.py` | 不会（每次重扫） |
| **B. 内置能力** | Claude Code 自带的 skill、subagent 类型、工具、harness 特性 | **只能人工更新** —— 这些不在本机配置里，是版本自带、只在会话中对模型可见 | 会（随版本变） |

**给未来的自己 / 下一次会话**：本机配置有增删（装了新 skill/插件/MCP、加了 hook）→ 跑脚本；
发现 Claude Code 出了新内置能力 → 手工改 B 段并更新下面的"实测日期"。
用户明确要求**随时维护**这份清单（2026-08-05）。

---

<!-- AUTO:BEGIN -->

> 本段由 `refresh_inventory.py` 自动扫描生成，**不要手改** —— 重新跑一遍脚本即可。扫描时间：2026-08-05 22:21

### A1. 个人 skills（`~/.claude/skills/`）—— 13 个

| skill | 触发 | 一句话 |
| :--- | :---: | :--- |
| `/corun` | 仅手动 | Use when 要在同一台服务器上同时/排队跑多个重型管线(nextflow/sarek/mag/taxprofiler、长比对、大下载等)且系统资源有限——如何安全并跑、监 |
| `/ftp` | 仅手动 | Use when 用户要给客户开 sFTP 上传/下载通道、查回 sFTP 端口/账号/密码、或确认穿透(bore)隧道是否还活着 |
| `/git` | 仅手动 | Use when 要对本机任一 git 仓库做提交/推送/清理——尤其 commit+push 前必须排除大文件(避免 258G scratch、BAM/work/ 进库或撞  |
| `/notify` | 仅手动 | Use when writing ANY script that needs to alert the user (watchdog, monitor, cron job, l |
| `/rnaseq` | 仅手动 | Use when 用户要为一个项目搭建 bulk RNA-seq 分析:nf-core/rnaseq → DESeq2 差异表达 → GO/KEGG ORA + GSEA 富集 |
| `/scientific-figure-making` | 仅手动 | Use when 要出版级/客户交付级的图: matplotlib 或 ggplot2 的 grouped bar、trend line、heatmap、scatter/PCA |
| `/ssd-swap` | 仅手动 | Use when 需要为跑重型/并发 WGS 管线(sarek、双管线并跑等)在本机加挂或重启后重新激活 64GB SSD swap 缓冲——该 swapfile 不在 fst |
| `/tax-assembly-mag` | 仅手动 | Use when 用户要做 shotgun 宏基因组 de-novo 组装+分箱+MAG 重建与分类:nf-core/mag |
| `/tax-functional-humann` | 仅手动 | Use when 用户要做 shotgun 宏基因组 functional profiling（功能通路/基因家族丰度、代谢潜能、KO/EC、SCFA/代谢差异）:HUMAnN |
| `/taxnom` | 仅手动 | Use when 用户要做 shotgun 宏基因组 assembly-free 物种分类/丰度定量:nf-core/taxprofiler(Kraken2+Bracken/M |
| `/video2doc` | 仅手动 | Use when 用户给一个视频链接(B站/YouTube 等)要整理成结构化中文学习文档 |
| `/watchdog` | 仅手动 | Use when 要启动任何过夜/长时/无人值守的 pipeline（sarek/rnaseq/taxprofiler/mag、长比对、大下载、下游编排链…）——在启动前如何正 |
| `/wgs` | 仅手动 | Use when 用户要搭建 WGS 分析——种系变异检出(sarek)、转基因/定点敲入整合分析、或细胞系株系鉴定+转基因发现 |

### A2. 插件（plugin）—— 已装 1 个；已知市场：claude-plugins-official

| 插件 | 版本 | 启用 | 装在哪 | 带来什么 |
| :--- | :---: | :---: | :--- | :--- |
| `superpowers@claude-plugins-official` | 6.2.0 | 是 | `user` 级 | 14 个 skill、SessionStart hook |

`superpowers@claude-plugins-official` 带的 skill（用 `superpowers:<名字>` 调用）：

　`brainstorming`、`dispatching-parallel-agents`、`executing-plans`、`finishing-a-development-branch`、`receiving-code-review`、`requesting-code-review`、`subagent-driven-development`、`systematic-debugging`、`test-driven-development`、`using-git-worktrees`、`using-superpowers`、`verification-before-completion`、`writing-plans`、`writing-skills`

### A3. MCP servers

| 名称 | 类型 | 命令 / 端点 | 需要的 env 键 |
| :--- | :---: | :--- | :--- |
| `gmail` | stdio | `/home/gao/.local/bin/uvx claude-gmail-mcp` | GMAIL_ADDRESS, GMAIL_APP_PASSWORD |
| `github` | http | `https://api.githubcopilot.com/mcp/` | — |

**只列 env 的键名，绝不落盘任何值** —— 那里面是凭据。

### A4. Hooks

| 来源 | 事件 | 内容 |
| :--- | :---: | :--- |
| plugin superpowers@claude-plugins-official | `SessionStart` | matcher=`startup|clear|compact` |

另有 **git hooks**（与 Claude Code 无关，是 git 自己的）：`/home/gao/Utilities/.githooks` -> pre-commit；各 projects 仓库用 `core.hooksPath .githooks` 指向同款 >10MB 拦截。

### A5. 用户自定义 subagent（`~/.claude/agents/*.md`）—— 0 个

　（无 —— 目前只用内置的几种，见 B2）

### A6. 用户自定义 slash 命令（`~/.claude/commands/`）—— 0 个

　（无 —— 个人能力一律做成 skill，见 [[feedback_personal_skills_standard_format]]）

### A7. settings 关键项

| 项 | 值 |
| :--- | :--- |
| `model` | `opus` |
| `theme` | `dark` |
| `permissions.defaultMode` | `bypassPermissions` |
| `skipDangerousModePermissionPrompt` | `True` |
| `statusLine` | command: `bash ~/.claude/statusline-command.sh` |
| 允许规则条数 | settings.json 14 条 + settings.local.json 2 条 |

<!-- AUTO:END -->

---

# B. 内置能力（版本自带，人工维护）

**B 段实测日期：2026-08-05**（Claude Code / Opus 5 会话内实际可见的能力，非文档抄录）。
这些**扫不出来** —— 不写在 `~/.claude` 里，随 Claude Code 版本变化。

## B1. 内置 skills（不用安装，直接 `/name`）

| skill | 用途 |
| :--- | :--- |
| `/dataviz` | 任何图表/仪表盘的配色与形式规范（写第一行画图代码前读） |
| `/artifact-design` | Artifact 页面设计基本功 |
| `/artifact-diagramming` | Artifact 里的示意图（内联 SVG / mermaid） |
| `/artifact-capabilities` | 已发布 Artifact 的运行时能力（活数据、共享状态、自更新） |
| `/update-config` | 改 `settings.json`：权限、环境变量、**hooks** |
| `/keybindings-help` | 自定义快捷键 `~/.claude/keybindings.json` |
| `/simplify` | 只做质量清理（复用/简化/效率），不找 bug |
| `/fewer-permission-prompts` | 扫历史会话，生成只读命令白名单，减少授权弹窗 |
| `/loop` | 按间隔重复跑某个提示/命令；不给间隔则模型自定节奏 |
| `/schedule` | 建/改/列 **cron 定时云代理（Routines）**，也支持一次性定时 |
| `/claude-api` | Claude API / SDK 参考（模型 id、定价、缓存、tool use…） |
| `/run` | 启动本项目的 app 看效果/截图 |
| `/init` | 生成 `CLAUDE.md` |
| `/review` | 审 GitHub PR |
| `/security-review` | 审当前分支的安全问题 |

**注意**：`/code-review ultra`（曾用名 `/ultrareview`）是**用户触发且计费**的多代理云端审查，
**我无法自己启动**，也不能用 Bash 绕过。

## B2. 内置 subagent 类型（`Agent` 工具的 `subagent_type`）

| 类型 | 定位 | 工具面 |
| :--- | :--- | :--- |
| `claude` | 通用兜底，没指定名字时的默认 | 全部 |
| `general-purpose` | 复杂多步研究/搜索 | 全部 |
| `Explore` | **只读**广度搜索，读片段不读全文；要说清广度（"medium"/"very thorough"） | 除写入外 |
| `Plan` | 架构/实现方案设计，返回分步计划 | 只读 |
| `claude-code-guide` | 专答 Claude Code / Agent SDK / Claude API / Slack 集成的问题 | Bash/Read/WebFetch/WebSearch |
| `statusline-setup` | 配状态栏 | Read/Edit |

**本机没有自定义 subagent**（见 A5）。派生方式：`Agent` 工具（默认后台跑，完成后通知）；
`isolation: "worktree"` 给它独立 git worktree；`SendMessage` 可继续与已派生的 agent 对话。
**约定：除非用户明确要求，不主动派生 subagent**（每次冷启动要重推上下文，代价高）。

## B3. 会话内可用的工具（harness 提供）

**直接可用**：`Bash` `Read` `Write` `Edit` `Skill` `Agent` `Artifact` `AskUserQuestion`
`ToolSearch` `ScheduleWakeup` `ReportFindings`

**延迟加载**（先 `ToolSearch` 取 schema 再调用，省上下文）：
`TodoWrite` `WebFetch` `WebSearch` `NotebookEdit` `Monitor` `TaskOutput` `TaskStop` `SendMessage`
`EnterPlanMode` `ExitPlanMode` `EnterWorktree` `ExitWorktree` `DesignSync` `RemoteTrigger`
`PushNotification` `CronCreate` `CronList` `CronDelete`
`ListMcpResourcesTool` `ReadMcpResourceTool` `ReadMcpResourceDirTool`
＋ **GitHub MCP 的全部工具**（issue/PR/repo/代码搜索/发布/密钥扫描等约 50 个）

## B4. Harness 特性（运行时本身）

| 特性 | 说明 |
| :--- | :--- |
| 模型 | 本机设 `opus`（= Opus 5）。`/fast` 切快速模式，仍是 Opus 不降级 |
| 上下文管理 | 会话过长自动摘要续跑，不必提前收尾 |
| 后台任务 | `Bash(run_in_background)`、后台 subagent；完成后自动回调，**不必轮询** |
| 定时/循环 | `Routines`（cron 云代理，`/schedule`）· `/loop`（会话内循环）· `ScheduleWakeup`（动态自定节奏）。**2026-08-05 `CronList` 实测：无已排定任务** |
| Plan mode | `EnterPlanMode` / `ExitPlanMode`，先出计划再动手 |
| Worktree 隔离 | `EnterWorktree` / subagent `isolation:"worktree"` |
| Artifacts | 发布私有网页到 claude.ai（默认私有，可再分享） |
| 权限模式 | 本机 `bypassPermissions`（见 A7）——**风险自负，破坏性操作仍须先说明再执行** |
| Scratchpad | 每会话独立临时目录，替代 `/tmp` |
| 记忆 | `~/.claude/projects/-home-gao/memory/` + `MEMORY.md` 索引，跨会话持久 |
| IDE 集成 | VSCode 扩展内运行；能看到用户当前打开的文件与选中内容 |
| 通知 | `PushNotification`（仅会话存活时）· tty · Gmail SMTP（见 [[reference_notification_channels]]） |

---

## 三个最容易记混的点（写在这里免得每次重推）

1. **Skill vs Hook**：Skill 是**给模型看的指令**，模型可能不完美遵守；
   Hook 是**系统强制跑的代码**，模型绕不过。"必须每次都做"的事 → Hook。
2. **Routine vs /loop vs ScheduleWakeup**：Routine 是**云端 cron、无人在场**也跑；
   `/loop` 是**会话内**重复；`ScheduleWakeup` 是 `/loop` 动态模式下自己定下次醒来的时间。
3. **本机 13 个个人 skill 全是"仅手动"**（`disable-model-invocation: true`）——
   我不会自动触发它们，**要用就打 `/名字`**。这是刻意的：它们都是重型生信流程。
