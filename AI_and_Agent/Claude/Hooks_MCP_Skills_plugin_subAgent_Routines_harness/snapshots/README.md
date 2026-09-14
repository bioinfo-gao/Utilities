# 能力清单快照序列（每 2–3 个月过一遍）

**这是什么**：`../1_当前能力清单_INVENTORY.md` 每次刷新前后的**历史定点**。
上级那份是 **living doc —— 永不改名、就地更新**；本目录按 `YYYYMMDD_` 存历史版，
两者分工与 `PLANS`（活文档）／`DELIVERABLES`（带日期）的约定一致。

**为什么要留历史点**：清单本身只回答"现在有什么"，回答不了
**"这两个月我到底加了什么、为什么加"** —— 而后者才是每 2–3 个月复盘时真正要看的东西。

## 下次怎么跑（整套三条命令，可直接粘贴）

```bash
cd /home/gao/Utilities/AI_and_Agent/Claude/Hooks_MCP_Skills_plugin_subAgent_Routines_harness
cp -p 1_当前能力清单_INVENTORY.md snapshots/$(date +%Y%m%d)_INVENTORY.md   # ① 先归档旧版
python3 refresh_inventory.py                                              # ② 再刷新（只重写 A 段）
cp -p 1_当前能力清单_INVENTORY.md snapshots/$(date +%Y%m%d)_INVENTORY.md   # ③ 存今天的定点
```

**顺序不能换**：①②③ 里第 ① 步是"覆盖前先归档"，跳过它，上一个定点就永久没了。
（①③ 同名是有意的：③ 覆盖 ①，最终留下的是刷新后的版本；②失败时 ① 还在，可回退。）

跑完把本文件底部的趋势表补一行，并写一句**这两个月新增的东西解决了什么问题**。

## 趋势

| 日期 | 个人 skill | 插件 | 插件带来的 skill | MCP | 自定义 hook | 自定义 subagent | 自定义 slash |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **2026-06-16（t0，API 计费）** | **0** | **0** | **0** | **0** | **0** | **0** | **0** |
| 2026-06-18（转订阅） | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| 2026-07-09 | 5 | 1（v6.1.1） | 14 | 1 | **0** | 0 | 5（旧形态） |
| 2026-08-06 | 13 | 1 | 14 | 2 | **0** | 0 | 0 |
| 2026-09-13 | 18 | 1（v6.3.0） | 14 | 2 | **7 脚本 / 4 事件** | 0 | 0 |

起点文档见 [`20260616_origin_api_then_subscription.md`](20260616_origin_api_then_subscription.md)：**06-16 起走 API，约 2.15 个使用日烧 55 美元后于 06-18 转订阅**；那时能力基线全零，文档同时记录了当时**错**在哪。

## 每一段变化解决了什么

| 区间 | 变化 | 起因 |
| :--- | :---: | :---: |
| **06-16 → 06-18** | API 计费 → 订阅 | **2.15 个等效使用日烧掉 55 美元**（≈22 美元/天，折合一个月约 660 美元），而订阅 20 美元/月；Jun 19 起 API 用量归零 |
| **06-18 → 07-09** | 从零到 5 个 slash 命令 + 1 个 MCP + 1 个插件 | 起步期：先解决「怎么让它动手」，还没有任何约束机制 |
| 07-09 → 08-06 | **`~/.claude/commands/` 的 5 个命令全部迁成标准 `SKILL.md`**（5 slash → 0，skill 5 → 13）；MCP 加 `github` | 个人能力统一走 skill 格式，不再用 commands |
| 08-06 → 09-13 | **hook 从 0 长到 7 个脚本 / 4 个事件**；skill 13 → 18 | CLAUDE.md 分层重构（08-30），把"违反一次就不可逆"的规则从"靠我记得"改成**机械拦截** |

## 当前 7 个 hook 各管什么（详表见上级 INVENTORY 的 A4 段与 CLAUDE.md）

| 脚本 | 事件 | 拦什么 |
| :--- | :---: | :---: |
| `guard_destructive_bash.py` | PreToolUse/Bash | 递归删结果目录、force-push、`reset --hard`、改写历史 |
| `guard_search_symlink.py` | PreToolUse/Bash | 不跟随符号链接的 `grep -r`／`find`（静默假阴性） |
| `guard_inline_email.py` | PreToolUse/Bash | 绕过写文件、直接用 Bash 起草客户邮件 |
| `guard_frozen_delivery.py` | PreToolUse/Write\|Edit | 覆盖已存在的交付／归档文件 |
| `resolve_current_doc.py` | UserPromptSubmit | 无 path 指代 ⇒ 注入解析好的绝对路径 |
| `route_post_write.py` | PostToolUse/Write\|Edit | 按路径路由到报告／客户邮件判据 |
| `stop_check_reply.py` | Stop | 回复自检（状态断言／表格格式／语言）+ **表格落盘逐行确认**（09-13 新增） |

判据模块 4 个，在 `~/.claude/hooks/checks/`：`check_reply` / `check_report` /
`check_client_email` / `check_table_transfer`。
回归测试三套合计 **98** 条：
`python3 ~/.claude/hooks/test_checks.py`（58）、`test_guard_destructive_bash.py`（21）、
`test_guard_search_symlink.py`（19）。

## 注意

- `20260709_skills_hooks_MCP_Plugin.txt` 是**手写快照**，不是脚本产物，字段与后面两份对不齐，
  趋势表里它那一行的数是我从正文读出来的，**不是同一套口径**。
- 脚本只扫得出 **A 段**（本机配置）。B 段（内置 skill／内置 subagent／harness 能力）
  来自 Claude Code 版本本身，**只在会话里对模型可见，必须人工更新**。
