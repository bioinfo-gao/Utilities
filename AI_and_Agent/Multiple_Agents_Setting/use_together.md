我现在有三个AI 智能体在我的服务器工作（claude code ，codex ， antigravity），但每个月只付款一个，进行能力比较，所有如何让三个智能体共用一套规则或者技巧？ 比如各种skill 和harness， 和 MCP 和 setting



要让这三个在不同月份轮流启用的 AI 智能体（Claude Code、Codex/GitHub Copilot Codex、Antigravity）共用一套规则、技巧、MCP（Model Context Protocol）和 Harness 环境，核心策略是“配置解耦，中心化管理”。

由于你每月只激活一个，通过建立一个独立的规则与上下文中心（Central Source of Truth），并让三个智能体的配置文件全部指向或读取这个中心，即可实现“一次修改，处处同步”。

以下是具体落地实现的四层架构方案：

1. 核心骨架：建立 Global Workspace（全局配置仓）在你的服务器上建立一个独立的全局目录，专门存放共用的规则。

bash/home/user/.global_ai_harness/
├── prompts/
│   ├── system_rules.md      # 核心系统提示词（你要求的各种技巧和规范）
│   └── coding_standards.md   # 代码规范与 Harness 运行要求
├── tools/
│   └── skills/              # 自定义的本地脚本、Skills 扩展
└── mcp_config.json          # MCP 服务器全局配置文件




2. MCP (Model Context Protocol) 共享MCP 是连接智能体与外部工具的标准协议。目前 Claude Code 对 MCP 提供了原生支持（通过 claude.json），而 Codex 和 Antigravity 需要通过“桥接”或配置文件复用。统一 MCP 配置文件：在全局目录中维护 mcp_config.json，里面定义好你所有的工具（如：数据库读取、Git 操作、网络检索等）。各智能体桥接：Claude Code：直接在 ~/.config/claude/claude.json 中，通过 mcpServers 字段引入你的全局 MCP 配置。Codex / Antigravity：如果有些智能体本身不原生支持标准的 MCP，可以使用开源的 mcp-cli 或通过包装器（Wrapper）将 MCP 工具转换成标准命令行工具（CLI Skills），让它们通过终端调用。

3. Rules & Skills 共享：符号链接（Symbolic Links）与自动加载这是让三个智能体共用“提示词/规则（System Prompts）”和“技能（Skills）”的最有效手段。针对项目级别（Harness & Workspace）在你的代码项目根目录下，不要直接写 .claudecode.toml 或智能体的专属配置文件，而是使用 符号链接（Ln -s）：统一的系统规则文件：在项目根目录创建一个 .ai_rules.md。强制读取设置：

Claude Code：在项目根目录的 claude.toml 中配置（或在其系统提示词中指定）：“Always read and obey the rules in .ai_rules.md before executing tasks.”Codex（如果是通过 VS Code / Cursor 等载体）：在 .cursorrules 或 .vscode/settings.json 中配置关联，让其自动载入该 MD 文件。Antigravity：在其特定的初始化配置文件（如 .antigravityrc 或 config.yaml）中，将系统提示词路径指向全局的 system_rules.md。bash# 在你的开发项目目录下建立软链接，直接引用全局规则
ln -s /home/user/.global_ai_harness/prompts/system_rules.md .ai_rules.md
Use code with caution.

4. Harness & Environment 

隔离与标准化为了让三个智能体在同一个自动化测试和评估（Harness）环境下工作，必须将环境与智能体本身剥离：

CLI 标准化封装：编写一个通用的 Makefile 或 Shell 脚本（如 run_harness.sh），负责跑测试、检查 Lint、收集错误日志。教智能体使用这个 Harness：在你的 system_rules.md（共用规则）中写入一条硬性指令："你正在一个受控的服务器环境中工作。在修改代码后，必须运行 bash run_harness.sh 来验证你的修改。不要尝试自己写复杂的测试命令，完全依赖该脚本的返回结果。"因为三个智能体都有执行终端命令（Terminal Tool）的能力，只要它们遵循同一条系统指令，就能完美复用这套 Harness。💡 高阶技巧：动态智能体切换脚本（Agent Switcher）既然你每月只付一个人的钱，为了防止因为不小心调用了未付费的智能体导致报错，或者频繁手动改配置，建议在服务器写一个简单的切换脚本 switch_agent.sh：bash#!/bin/bash

# 举例：切换到 claude_code 模式

AGENT=$1

if [ "$AGENT" == "claude" ]; then
    echo "Activating Claude Code Context..."
    # 自动将全局规则链接到 Claude 专属的配置目录或项目根目录
    ln -sf /home/user/.global_ai_harness/prompts/system_rules.md .claudecode_rules
    # 配置你的环境变量，比如只暴露 CLAUDE_API_KEY
    export ACTIVE_AGENT="claude"
elif [ "$AGENT" == "antigravity" ]; then
    echo "Activating Antigravity Context..."
    ln -sf /home/user/.global_ai_harness/prompts/system_rules.md .antigravity_rules
    export ACTIVE_AGENT="antigravity"
fi
Use code with caution.为了帮你写出更精准的共享配置文件（如 MCP 桥接或通用的 .ai_rules.md），你能告诉我：你的 Antigravity 和 Codex 目前是通过什么界面或客户端（例如：VS Code 插件、终端 CLI、还是特定的 WebUI 容器）在服务器上运行的？你目前正在使用的 MCP 工具（Servers） 主要有哪些（例如：Postgres, Filesystem, GitHub 等）？
