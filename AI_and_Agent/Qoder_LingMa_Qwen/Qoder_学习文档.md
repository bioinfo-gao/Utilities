# Qoder 学习文档

> 来源:官方站点 https://qoder.com/ 与官方文档 https://docs.qoder.com/
> (原始的 B站视频《阿里偷偷免费了:Qoder国内版首月0元…》无字幕且为促销向,本文档改用官方文档撰写)
> 整理日期:2026-07-09

---

## 1. 这是什么

**Qoder** 是**阿里推出的"agentic(自主代理)AI 编程平台"**,定位对标 Cursor,但更强调**把长任务整段交给 AI 代理自己跑完**。它不只是一个 IDE,而是一整套形态:桌面 IDE、JetBrains 插件、命令行 CLI、云端 Agent。

核心理念:你写清楚需求 → 交给 Agent → 它自己拆解任务、生成执行计划、写代码、跑测试验证,最后端到端完成。

> **国内版说明:** 视频里讲的是 **Qoder 国内版(Qoder CN)**,与阿里"通义灵码 / Lingma"体系打通,有新用户免费额度、师生认证加额度等促销。全球版则是 qoder.com 的 public preview 免费试用。功能主体一致,本文以官方全球文档为准。

---

## 2. 产品形态(按你的使用习惯选一个)

| 形态 | 是什么 | 适合 |
| :--- | :--- | :---: |
| Qoder Desktop(IDE) | 独立的自主开发环境 | 主力开发 |
| JetBrains 插件 | 装进 IntelliJ/PyCharm 等 | 已有 JetBrains 工作流 |
| **Qoder CLI(`qodercli`)** | 终端里的 Agent | 脚本化/服务器/自动化 |
| Cloud Agents | 托管在云端的 Agent | 长任务、无人值守 |

> 对你(常在远程服务器上跑 bioinfo)最顺手的通常是 **CLI**。

---

## 3. 安装

### 3.1 CLI(命令行,推荐服务器场景)

```bash
# macOS / Linux
curl -fsSL https://qoder.com/install | bash

# Windows PowerShell
irm https://qoder.com/install.ps1 | iex

# 验证
qodercli --version
```

### 3.2 桌面 IDE / JetBrains 插件

1. 到 https://qoder.com/download 下对应平台安装包(Windows/macOS/Linux)。
2. 双击安装,点图标启动。
3. JetBrains 用户可直接在 IDE 插件市场搜 "Qoder" 安装。

---

## 4. 认证 / 登录

### CLI

```bash
# 方式1:交互式登录(推荐)
qodercli
/login              # 选浏览器登录 或 输入 personal access token

# 方式2:环境变量(自动化/服务器无浏览器时)
export QODER_PERSONAL_ACCESS_TOKEN="你的token"
# token 从 https://qoder.com/account/integrations 领取

# 退出登录
/logout
```

### IDE

1. 点右上角用户图标,或按 `Ctrl+Shift+,`(Mac `⌘⇧,`)。
2. 选 "Sign in":可创建账号 / 用 Google / 用 GitHub。
3. 认证完回到 IDE 即可。

---

## 5. 运行 / 日常使用

### IDE 两大模式

**Editor Mode(编辑器模式)—— 边写边协作:**

| 功能 | 快捷键(Win / Mac) | 作用 |
| :--- | :---: | :--- |
| NEXT | `Alt+P` / `⌥P` | 上下文感知代码补全,Tab 接受 |
| Inline Chat | `Ctrl+I` / `⌘I` | 在代码里就地提问/改写 |
| Ask / Agent Chat | `Ctrl+L` / `⌘L` | Ask 做问答;Agent 做跨多文件实现 |

**Quest Mode(任务模式)—— 把长任务甩给 Agent:**
专门的窗口,用来交付"长时间、多步骤"的活。你下达需求后,Agent 自己推进,你在任务看板里看进度、审查产物(artifact)。官方称单任务最长可自主执行到 26 小时、可处理 10 万级文件上下文。

### 打开项目

- 本地:`Ctrl+O`(Mac `⌘O`)选文件夹。
- 远程:点 "Clone repo",填 GitHub URL 或用 GitHub 授权。

### 其他关键能力

- **Repo Wiki**:自动把代码库"维基化",生成结构化文档帮助理解大项目。
- **多模型自动选择**:后端会按任务在 Claude / GPT / Gemini 等模型间自动挑最合适的。
- **支持 200+ 语言**(JS/TS/Python/Go/C/C++/C#/Java 等)。

---

## 6. MCP 扩展

Qoder 支持 **MCP(Model Context Protocol)** 接入外部工具。配置说明见官方文档:
https://docs.qoder.com/user-guide/chat/model-context-protocol

---

## 7. 运行调试 / 排错

| 场景 | 怎么做 |
| :--- | :--- |
| 确认装好没 | `qodercli --version` |
| 升级 | `qodercli update`(或用安装命令加 `--force` 重装) |
| 关掉自动更新 | 编辑 `~/.qoder/settings.json`:`{"general": {"enableAutoUpdate": false}}` |
| 服务器无浏览器登录不了 | 改用 `QODER_PERSONAL_ACCESS_TOKEN` 环境变量 |
| token 在哪拿 | https://qoder.com/account/integrations |
| 找不到功能/更多文档 | 看 `https://docs.qoder.com/llms.txt`(文档全量索引) |

> 官方文档目前没有独立的 troubleshooting 章节;遇到问题优先查 `llms.txt` 索引或对应功能页。

---

## 8. 定价 / 免费额度

- **全球版**:新用户 2 周 Pro 试用,含全部 Pro 功能;到期后升级付费或自动降级到免费层。整体按 **credit(积分)计量**。
- **国内版(视频所讲)**:有"首月 Pro 免费""新用户送积分""师生认证额外加额度""邀请返积分"等促销活动(以官方活动页实时为准,可能随时间变化)。

---

## 9. 快速上手清单(CLI,照着做一遍)

```bash
# 1. 装
curl -fsSL https://qoder.com/install | bash
qodercli --version

# 2. 登录
qodercli
/login          # 浏览器登录;服务器场景改用 QODER_PERSONAL_ACCESS_TOKEN

# 3. 进项目试
cd ~/some_project
# 在交互里描述需求,交给 Agent 跑
```

---
## 附:参考来源

- Qoder 官网:https://qoder.com/
- 官方文档:https://docs.qoder.com/
- CLI 快速上手:https://docs.qoder.com/en/cli/quick-start
- MCP 配置:https://docs.qoder.com/user-guide/chat/model-context-protocol

*本文档基于 Qoder 官方站点与文档整理,供个人学习用。*
