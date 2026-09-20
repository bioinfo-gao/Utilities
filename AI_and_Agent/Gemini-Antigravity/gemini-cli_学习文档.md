# Gemini CLI 学习文档

> 来源:https://github.com/google-gemini/gemini-cli(Apache-2.0,约 106k stars)
> 整理日期:2026-07-09

---

## 1. 这是什么

**Gemini CLI** 是 Google 开源的一个**终端里的 AI 代理(AI agent)**,把 Gemini 模型直接搬进命令行。定位类似 Claude Code / Aider:可以读你的代码库、生成代码、调试、跑 shell 命令、联网搜索,并支持 **MCP** 扩展自定义工具。

核心卖点:

- **代码分析与生成**:对整个代码库提问,从 PDF/图片生成应用,定位并修复 bug。
- **内置工具**:Google Search 联网grounding、文件读写、执行 shell 命令、抓取网页。
- **MCP 集成**:通过 Model Context Protocol 接入外部工具(GitHub、Slack、数据库等)。
- **会话检查点(checkpointing)**:保存并恢复复杂会话。
- **GitHub 集成**:通过 GitHub Actions 做自动 code review、issue 分类、PR 协助。
- **免费额度**:用个人 Google 账号即可 60 次/分钟、1000 次/天;Gemini 3 模型支持 100 万 token 上下文。

---

## 2. 安装

| 方式 | 命令 | 说明 |
| :--- | :--- | :---: |
| 免安装试用 | `npx @google/gemini-cli` | 不落地,直接跑 |
| 全局 npm | `npm install -g @google/gemini-cli` | 最常用 |
| Homebrew | `brew install gemini-cli` | macOS/Linux |
| MacPorts | `sudo port install gemini-cli` | macOS |
| Conda(推荐给本机) | 见下方代码块 | 用 conda 管理 Node,不污染系统 |

**用 conda 装 Node 再装 gemini-cli(最贴合本机 mamba 工作流):**

```bash
# 建一个独立环境放 Node,避免动系统 node
mamba create -y -n gemini_env -c conda-forge nodejs
mamba activate gemini_env
npm install -g @google/gemini-cli
gemini --version   # 验证安装
```

**发布通道(需要新特性时选 preview/nightly):**

| 通道 | 安装 | 节奏 |
| :--- | :--- | :---: |
| 稳定版 | `npm i -g @google/gemini-cli@latest` | 每周二 20:00 UTC |
| 预览版 | `npm i -g @google/gemini-cli@preview` | 每周二 23:59 UTC |
| 每夜版 | `npm i -g @google/gemini-cli@nightly` | 每天 00:00 UTC |

---

## 3. 认证(三选一)

| 方式 | 适合谁 | 关键操作 |
| :--- | :---: | :--- |
| Google OAuth(推荐) | 个人开发者 | 直接跑 `gemini`,在提示里选 "Sign in with Google" |
| Gemini API Key | 想用固定 key / 脚本化 | `export GEMINI_API_KEY="..."` 后再跑 `gemini` |
| Vertex AI | 企业 | `export GOOGLE_API_KEY=...` + `export GOOGLE_GENAI_USE_VERTEXAI=true` |

```bash
# 方式1:OAuth(最省事)
gemini
# 弹出后选 “Sign in with Google”。若有付费 Code Assist:
export GOOGLE_CLOUD_PROJECT="YOUR_PROJECT_ID"
gemini

# 方式2:API Key(key 从 https://aistudio.google.com/apikey 领)
export GEMINI_API_KEY="YOUR_API_KEY"
gemini
```

> 建议把 `export GEMINI_API_KEY=...` 写进 `~/.bashrc`,免得每次开终端都要设。

---

## 4. 运行(常用命令)

```bash
gemini                                   # 进入交互模式
gemini -p "解释这个代码库的架构"           # 非交互,直接出文本答案
gemini -m gemini-2.5-flash               # 指定模型
gemini --include-directories ../lib,../docs   # 把额外目录纳入上下文
gemini -p "解释架构" --output-format json      # 结构化 JSON 输出(适合脚本解析)
gemini -p "跑测试并部署" --output-format stream-json   # 流式事件输出(适合监控)
```

**交互模式里的斜杠命令:**

| 命令 | 作用 |
| :--- | :---: |
| `/help` | 列出所有命令 |
| `/chat` | 管理会话(含 checkpoint 保存/恢复) |
| `/bug` | 直接从 CLI 里提交 bug |

---

## 5. 配置与 MCP 扩展

- **项目上下文文件 `GEMINI.md`**:放项目根目录,提供长期的项目专属指引(类似 Claude Code 的 `CLAUDE.md`)。
- **MCP 配置**:写在 `~/.gemini/settings.json`,配好后可在会话里用 `@` 调用外部工具:

```
> @github List my open pull requests
> @slack Send summary to #dev channel
> @database Run query to find inactive users
```

---

## 6. 运行调试 / 排错

| 场景 | 怎么做 |
| :--- | :--- |
| 查看可用命令 | 交互里输 `/help` |
| 报 bug | 交互里输 `/bug`,或去仓库 GitHub Issues |
| 认证失败 | 确认 `GEMINI_API_KEY` 已 export;或删掉旧凭据重新 OAuth 登录 |
| 想看程序内部事件 | 用 `--output-format stream-json` 观察每一步事件流 |
| 上下文没覆盖到某目录 | 加 `--include-directories path1,path2` |
| 生产环境安全 | 用内置 sandbox / trusted-folder 配置隔离,避免误跑危险 shell |

**排错资源:** 官方 troubleshooting 指南、仓库 FAQ、GitHub Issues、Security advisories,以及 CLI 内 `/bug`。

---

## 7. 快速上手清单(照着做一遍)

```bash
# 1. 装
mamba create -y -n gemini_env -c conda-forge nodejs && mamba activate gemini_env
npm install -g @google/gemini-cli

# 2. 认证(个人最简单:OAuth)
gemini            # 选 Sign in with Google

# 3. 在一个项目目录里试
cd ~/some_project
gemini -p "用一段话概括这个仓库是做什么的"

# 4. 交互探索
gemini
> /help
> 帮我给 src/ 里的函数补 docstring
```

---
*本文档基于 gemini-cli 官方 README 整理,供个人学习用。*
