
问的是能不能MCP harnews plugin subagent 这些能不能和skill 一样，也只有一个设置，各个Agent 都用软连接？

明白你的核心疑问了。你问的是：既然纯文本的 Skill 可以用软链接实现“一处修改，全局生效”，那像 MCP、Harness、Plugin、Subagent 这些更复杂的配置和组件，能不能也像 Skill 一样，在电脑里只设一个“真身”，然后给不同的 Agent 工具都挂软链接？
结论是：部分可以，但绝大多数“不能单纯靠软链接”搞定。
这是因为 Skill 的本质只是纯文本文件（Markdown/JSON），而 MCP、Plugin 等涉及运行中的服务（Process）、环境变量、安全凭证（Token）和完全不同的配置文件格式。
我们可以逐一拆解这些组件，看看它们在多个 Agent 工具之间要如何实现“只设一个”：

1. ⚙️ MCP（模型上下文协议）—— 不能靠软链接，要靠“网关（Gateway）”

• 为什么不能用软链接：各个 Agent（如 Claude Code, Cursor, VS Code）用来配置 MCP 的文件格式完全不同：
	• Claude Code 认 ~/.claude/config.json 或 .mcp.json
	• Cursor 认 ~/.config/Cursor/ 里的 SQLite 数据库或私有 JSON
	• VS Code Copilot 认 .vscode/mcp.json
你没办法用一个软链接去同时适配 JSON、Toml 和数据库。此外，本地 MCP 往往通过标准输入输出（Stdio）运行，一个进程同时只能被一个 Agent 独占占用。
• 真正的“单一设置”解法：使用 MCP Gateway（如 Bifrost 或自建网关）。
你只需要在一个统一的网关服务里配置好你所有的本地或远程 MCP 服务器。然后让 Claude Code、Cursor、Windsurf 等所有 Agent，全都指向这同一个网关的 URL（通常是 HTTP-SSE 传输模式）。这样，你修改网关一处的配置，所有 Agent 调用的工具同步更新。

2. 🔌 Plugin（插件）—— 部分可以软链接，但正在走向“统一规范”

• 情况分析：目前的 AI 插件形态非常混乱。如果这个 Plugin 的本质只是一个包含了多份 Skill 文本和本地脚本的文件夹，你完全可以用原图的办法，把整个 my-plugin/ 目录软链接到各个工具的插件发现路径下（如 ~/.claude/plugins/）。
• 最新趋势：行业已经意识到了这个痛点。自 2026 年起，由 Google、微软、OpenAI、Cursor 等大厂联合发布了 Agent Plugins 开放标准。它把 Skill 和 MCP 统一打包成了一个标准的 .plugin 包。对于支持该标准的新一代 Agent 框架，你确实可以在本地只放一个真身，然后通过软链接分发。

3. 🤖 Subagent（子智能体）—— 可以软链接，因为它是 Skill 的延伸

• 情况分析：完全可以像 Skill 一样用软链接。
在当前的 Agent 框架中（如 Claude Code 的 Subagent 体系），子智能体通常也是由一段系统提示词（System Prompt）、元数据（Frontmatter）和预载技能清单组成的纯文本描述文件（例如 coder.agent 或 reviewer.md）。
• 操作方法：你可以在自己的配置库里写好 Subagents/ 目录，里面定义好不同角色的“分身”。然后像同步 Skill 一样，用软链接挂载到各个主 Agent 工具的读取路径下。

4. 🦺 Harness（开发框架/马甲）—— 无法软链接，因为它是“宿主本身”

• 概念澄清：Harness（智能体马甲/运行框架）不是一个可以被注入的“组件”，它本身就是那个正在运行的容器程序（Host）。比如，Claude Code 就是一个 Harness，Cursor 的 AI 运行时也是一个 Harness。
• 如何统一：你无法把一个 Harness “软链接”给另一个 Harness。你只能选择一个足够强大的 Harness（例如支持多模型切换、支持挂载通用 MCP 门禁的框架），把它作为你唯一的终端开发环境，在它里面去调用不同的模型（如切换 DeepSeek 或 Claude）。

💡 总结：构建你个人的“万能 Agent 资产库”

如果你想效仿原图作者，把所有资产统一管理，你的本地目录结构和分发逻辑应该演变成这样：
text
~/my-ai-vault/ (你的唯一资产真身库)
├── 📂 skills/       ───(软链接)───> 挂载到各个 Agent 工具的 skills 目录
├── 📂 subagents/    ───(软链接)───> 挂载到各个 Agent 工具的 agents 目录
└── 📄 mcp-master.json  (只在这里配置一次) ──> 启动一个本地 MCP 统一网关进程
                                             └─> 各个 Agent 直接连接该网关
Use code with caution.
通过这种“文本靠软链，服务靠网关”的组合拳，你才能真正做到不仅统一了“大脑和规矩（Skills）”，还统一了“手脚和工具（MCP/Plugins）”。
你目前在多工具配置上遇到了哪两个特定工具（例如 Cursor 和 Claude Code）的冲突吗？如果需要，我可以帮你看看这两款工具的 MCP 配置文件分别在哪，以及如何用最少的成本把它们合二为一。





对于 Hooks（生命周期钩子 / 拦截器） 来说，答案是：完全可以像 Skill 一样使用软链接，而且这正是目前最高效的玩法！
在 AI Agent 体系（如 Claude Code、Cursor）中，Hook 的本质其实就是一段脚本文件（如 Python, Shell 脚本）或一个指定脚本路径的 JSON 配置文件。它们在 AI 执行核心动作（如输入 Prompt、调用工具、执行 Bash 命令前/后）进行拦截和治理。
因为它们也是本地文件资产，所以你完全可以通过软链接实现“一处配置，多个 Agent 共享”。
具体怎么做，以及两个需要注意的细节：

🛠️ Hooks 的统一管理方式

你可以在你的中央资产库里这样布局：
text
~/my-ai-vault/ (个人 AI 资产库真身)
├── 📂 skills/
└── 📂 hooks/        ───(核心脚本真身放这里)
    ├── 🐍 lint_and_format.py (代码检查钩子)
    ├── 🐍 block_secrets.py    (防止密钥泄漏到 AI 的安全钩子)
    └── 📄 config.json         (告诉工具在什么生命周期执行哪个脚本)
Use code with caution.
通过软链接，把这个 hooks/ 文件夹挂载到不同工具的默认读取路径下：
• Cursor: 软链接到工程目录下的 .cursor/hooks/
• Claude Code: 软链接到对应配置目录或插件体系中

⚠️ 但相比于 Skill，统一 Hooks 有两个特殊难点：

1. 兼容性痛点：各家工具的“生命周期命名”不统一

Skill 只是纯文本，AI 怎么读都能看懂。但 Hooks 依赖的是工具底层写死的触发事件（Event Trigger）。
• Cursor 提供了非常细致的实时拦截点，比如 preToolUse（工具执行前）、afterShellExecution（命令行执行后）。
• Claude Code 同样支持 Hooks，但某些版本的架构（例如早期的 Turn-based 机制）更倾向于在会话结束时触发总体的 Stop 或 sessionEnd 钩子去拿 transcript 审计。
好消息是，行业正在快速兼容统一。例如，Cursor 的官方文档中已经明确支持直接读取并翻译 Claude Code 的 Hook 配置，这意味着你可以直接用一套配置同时喂给这两个工具。而在开源大方向上，也有了像 Agent Hooks 这种试图消灭平台差异的通用控制标准。

2. “真身”里千万不要包含动态状态

如果你写了一个 Hook 用来记录 AI 的对话审计日志（Audit Log），千万不要把日志文件本身也写进被软链接的目录里。否则，Claude Code 和 Cursor 的日志就会混在同一个文件里，导致数据相互踩踏和污染。
💡 正确做法：软链接只用来分发只读的脚本代码（逻辑真身）。在编写 Python 或 Bash 脚本时，内部涉及日志输出、临时缓存的路径，一律使用当前项目路径的相对路径（或传入的变量环境变量），让它们在各自工具的本地沙箱里运行。

📦 终极形态：2026 的 Plugin（插件）

如果你觉得针对 Skill、Subagent、Hook 一个个去挂软链接太琐碎，在目前的智能体生态中，它们正在被打包成同一种东西——Agent Plugins。
一个标准的 .plugin 文件夹里会同时包含你的 skills/、hooks/ 和 subagents/。你只需要软链接这一个大文件夹，各个 Agent 工具就能一次性把你所有的提示词、拦截脚本和子分身全部加载进去。
你目前手头有写好的 Git Hooks（比如 Husky 的 pre-commit），还是想写专门针对 AI 智能体行为拦截的 AI Agent Hooks？我可以为你提供一个针对 Cursor / Claude Code 通用的基础 Hooks 模版脚本。


在 AI 智能体的上下文中，提及 Routings（路由 / 模型与工具调度机制） 时，问题的本质发生了改变：路由无法使用软链接来做“一处设置，全局生效”。
因为 Skill 和 Hook 是“资产文件”（数据层），而 Routing 是“运行时的逻辑和网关网络”（协议层与服务层）。
如果你的目标是让 Cursor、Claude Code、Aider、Zed 等所有 Agent 在模型选择、费用控制、Fallback 容灾上都共享唯一一个路由设置，应该采用以下方法：

❌ 为什么不能用软链接？

1. 它是服务层逻辑，没有统一的文件载体：不同的 Agent 处理路由的方式大相径庭。比如，Cursor 的路由依靠的是它闭源的云端 Cursor Router 服务；而 Claude Code 的路由是通过底层的编译层硬编码，或通过不同的本地环境变量（如 ANTHROPIC_BASE_URL）去重定向。
2. 它是动态决策过程：路由包含“当 Claude 接口超时，自动切到 DeepSeek”或者“简单的任务发给 Haiku，复杂的发给 Opus”这种动态计算逻辑，文本软链接承载不了这种逻辑。

真正实现 Routing “单一设置，全局生效”的解法

在 2026 年的 AI 工程开发中，统一所有 Agent 路由的标准做法是：不要让 Agent 独立连接大模型，而是建立一个本地或局域网的“LLM 路由网关（LLM Router / Proxy）”。
text
               ┌───────────────────────┐
               │ 📄 my-router-config   │ <─── 唯一需要修改的配置文件
               └───────────┬───────────┘
                           ▼
               ┌───────────────────────┐
               │  LLM 路由网关 (服务)  │ (如 OpenRouter / LiteLLM / 自建)
               └──────┬─────────┬──────┘
                      ▲         ▲
         (API重定向)  │         │  (API重定向)
         ┌────────────┴─┐     ┌─┴────────────┐
         │ 🤖 Claude    │     │ 🤖 Cursor    │  ... 以及其他本地 Agent
         │    Code CLI  │     │    IDE       │
         └──────────────┘     └──────────────┘
Use code with caution.

🛠️ 落地操作分为两步：

第一步：配置唯一的“路由中心”

你可以使用像 OpenRouter、LiteLLM 或是开源的 ai-gateway，在你的电脑里只写一个配置文件（比如 router-config.yaml）。
在这个文件里，你规定好：
• 默认主模型是什么。
• 遇到并发限制（Rate Limit）或者故障时，自动 Fallback（灾备）到哪个备用模型/渠道。
• 设置个人每月的 Token 或消费限额。

第二步：把各个 Agent 的“枪口”对准这个中心

你不需要乱挂软链接，只需要在各工具的环境变量中设置 BASE_URL 即可：
• 对于 Claude Code / 命令行工具：
在你的终端配置文件（.bashrc 或 .zshrc）里，直接暴露统一的网关地址：bash
export ANTHROPIC_BASE_URL="http://localhost:8000/v1" # 指向你的本地路由网关
export ANTHROPIC_API_KEY="your-router-key"
Use code with caution.
• 对于 Cursor / VS Code：
在 Cursor 软件的 Settings -> Models 页面里，关闭官方默认通道，在 OpenAI Override Base URL 处同样填入 http://localhost:8000/v1。

💡 核心总结

在 AI 资产的“全一统”路线图里：
• 📝 Skills, Subagents, Rules：属于纯文本资产 → 用软链接统一。
• 🔌 Tools, MCPs：属于数据与外部 API 连接 → 用 MCP 网关进程统一。
• Routings (LLM API & Failover)：属于网络与模型调度 → 用统一的 LLM Proxy 代理统一。
你目前是用 OpenRouter 这样的云端路由服务，还是在本地用 LiteLLM / Ollama 自建路由？如果需要，我可以为你提供一份能直接兼容 Cursor 和 Claude Code 接口格式的本地路由网关配置。


对于 Routines（定时任务 / 自动化流程 / 复合型工作流），答案是：核心逻辑完全可以靠软链接统一，但需要通过一个“中央执行器（Runner）”或统一的格式来触发。

在当前的 AI 生态中，Routines 通常指的是一系列有先后顺序的复杂动作组合（例如：“每天早上 9 点：1. 拉取最新代码 \(\rightarrow \) 2. 让 AI 生成日报 \(\rightarrow \) 3. 运行测试并用 Hook 检查质量 \(\rightarrow \) 4. 发送到 Slack”）。
要实现各个 Agent 工具都能共享同一套 Routines 配置，我们需要根据 Routines 的存在形式来决定“软链接”的策略：

1. ⚙️ 以脚本为核心的 Routines：完全可以软链接

如果你的 Routines 是通过标准脚本（如 Python 脚本、Node.js、或是 Shell 脚本）把一堆 Skill 和工具串联起来的，它们本质上就是本地文件。
• 如何统一：
你可以在中央资产库建立一个 routines/ 目录。text
~/my-ai-vault/ (个人 AI 资产库真身)
├── 📂 skills/└── 📂 routines/    ───(软链接)───> 挂载到各大工具的 scripts/ 或 bin/ 目录
    ├── 📜 daily_audit.sh   (每日代码审计流程)
    └── 🐍 auto_release.py  (自动发布与变更日志生成流程)
Use code with caution.
通过软链接把这些脚本映射到各个 Agent 的执行目录下。无论是 Claude Code 通过终端调用，还是 Cursor 内部的任务触发器（Task Runner）去跑，执行的都是同一份逻辑真身。

2. 🤖 依赖特定框架格式的 Routines：需要看工具的兼容性

如果你的 Routines 是用特定 Agent 框架的 DSL（领域专用语言）或特定 JSON/YAML 格式编写的：
• Claude Code / Anthropic Routines：通常存储在 ~/.claude/routines/ 下的 JSON 文件。
• Cursor / Windsurf Tasks：可能存在项目根目录下的 .cursor/tasks.json。
只要两个工具认同同一种格式，你就可以无脑用软链接。
不幸的是，目前各大 IDE 厂商在任务流/流程（Routines）的 JSON 格式上还没有完全打通。但如果你是统一用 GitHub Actions 或 Make/Makefile 作为执行载体，那么完全可以把一个 Makefile 放在工作区，通过软链接分发给不同项目的根目录，让不同的 Agent 都能去调用 make routine-name。

3. 🌐 2026 最新行业趋势：使用 MCP 来统一 Routines

为了彻底消灭由于格式不统一导致无法软链接的痛点，最新的工程实践是：把 Routines 做成一个通用的 MCP Server（Model Context Protocol）。
你不再把流程写成各家 Agent 都不一定看得懂的配置文件，而是写成一个本地运行的 MCP 服务（比如一个集成了工作流引擎的 MCP-Workflow-Server）。
• 运作方式：
这个 MCP Server 暴露出一个叫 execute_routine(name="daily_audit") 的工具（Tool）。
这时候，无论是 Cursor 还是 Claude Code，只要它们连接了这个 MCP，就都能看到并调用这个 Routine。你修改这个 MCP 里的流程，所有 Agent 实时同步。

🛠️ 终极总结：你的“全一统”AI 资产库（The Grand Matrix）

如果你把前面聊到的所有组件（Skills, Hooks, Routings, Routines）全部塞进你的中央库，它看起来应该是这样的：

资产组件	核心本质	统一手段	示例路径
Skills / Subagents	纯文本提示词 / 行为 SOP	🔗 软链接（Symbolic Link）	~/vault/skills/
Hooks	拦截与治理代码脚本（Python/Shell）	🔗 软链接 + 相对路径设计	~/vault/hooks/
Routines	自动化流程 / 任务链脚本	🔗 软链接 (或打包成 MCP Tool)	~/vault/routines/
Tools / Plugins	API 连接 / 动态扩展服务	🌐 MCP 统一网关 / 统一规范包	~/vault/mcp/
Routings	模型分发 / 负载均衡 / 费用控制	🚦 本地 LLM Proxy 代理（如 LiteLLM）	~/vault/router/

你的 Routines 目前主要是用什么写出来的？是纯 Shell 脚本/Python，还是某些特定工具内置的流程/任务配置？我可以帮你看看如何把它无痛转化为能被所有 AI 共同读取的形式。
