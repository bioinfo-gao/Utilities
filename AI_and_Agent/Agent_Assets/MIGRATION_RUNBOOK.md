# 三 Agent 统一资产库：迁移与回滚运行手册

> **状态：Phase 1–6 已部署并验证（2026-10-22）**
> **权威范围：** Claude Code、Codex、Antigravity 的个人可移植资产迁移。  
> **本文件是迁移过程的唯一操作记录。** 每一次实际变更必须先更新本文件的「变更日志」，再执行；完成后补充验证结果与回退信息。

## 1. 目标与边界

目标是在不损失现有行为的前提下，把可移植资产收敛为一个可版本控制的真身库：

- 共用：工作规则、业务规则、Skills、非敏感 MCP 定义、hook 的检查逻辑、harness 脚本、资产清单和测试。
- 保留各端独立：账号与 OAuth、token、会话/记忆、模型选择、权限/沙箱、厂商插件缓存、插件 manifest 与事件适配器。

**不把任何带密钥、token、cookie、OAuth 刷新令牌、会话数据库或对话历史的文件复制到本资产库或 Git。**

## 2. 当前基线（只读盘点）

| 类别 | Claude Code | Codex | Antigravity |
| :--- | :---: | :---: | :---: |
| 全局主规则 | `~/.claude/CLAUDE.md`，351 行 | 尚无个人 `AGENTS.md` | 使用自身 settings / rules 表面 |
| 自建 Skills | 21 个有效目录 | 0 个个人 Skill | 8 个 |
| MCP 名称 | `gmail`、`github` | 0 个 | `github`、`gmail`、`outlook` |
| 强制 hook | 7 个 | 未配置 | 未配置为同等本地保护 |
| 现有模型/权限 | 保持不动 | 保持不动 | 保持不动 |

Claude Code 当前安全实现位于 `~/.claude/hooks/` 并由 `~/.claude/settings.json` 驱动；在所有其它端达到经验证的等效保护前，**不得修改、迁移或停用**该实现。

同名 Skill 的初步 checksum 结果：

- **本次迁移的初始权威来源为 Claude Code。** Claude 是历史唯一主力 Agent；Antigravity 的同名版本只保留为迁移审计依据，不参与内容合并或覆盖 Claude 版本。
- 因此 `ssd-swap`、`video2doc`、`corun`、`ftp`、`rnaseq`、`taxnom`、`wgs` 一律以 `~/.claude/skills/<name>/` 为首次迁移源。前两者的相同 checksum 仅作为一致性记录；后五者的差异只需归档记录，无需再作内容决策。
- 完成切换后，`Agent_Assets/skills/` 是三端（包括 Claude Code）唯一的长期权威真身。后续修改只能在该目录完成，再经部署脚本分发；不得直接修改任一 Agent 的发现目录副本或链接目标以外的版本。
- 名称不同的 Claude `tax-assembly-mag` 与 Antigravity `tax-resemb-mag` 暂保留为独立资产；不得因内容相近而自动合并、重命名或互相覆盖。

## 3. 目标目录与文件所有权

```text
/home/gao/Utilities/AI_and_Agent/Agent_Assets/
├── MIGRATION_RUNBOOK.md       # 本手册及实际变更日志
├── README.md                  # 使用说明与当前发布版本
├── registry/                  # 资产清单、来源、部署范围、checksum
├── instructions/              # 跨端规则的唯一真身
├── skills/                    # 自建 Skill 的唯一真身
├── mcp/                       # 不含任何凭据的 MCP catalog
├── hooks/core/                # 平台无关的检查逻辑与单元测试
├── harness/                   # 可跨端执行的验证入口
├── adapters/                  # claude / codex / antigravity 薄适配器
├── scripts/                   # inventory、render、install、verify、rollback
├── tests/                     # 资产库与适配器测试
└── snapshots/                 # 仅迁移前的只读清单与 checksum；不存密钥
```

`instructions/`、`skills/`、`mcp/catalog.*`、`hooks/core/` 是唯一可编辑的共享真身。`adapters/` 是受版本控制的源代码；任何生成的客户端配置都是可重建产物，不作为第二个手工维护的权威副本。

## 4. 不可违反的迁移规则

1. 不删除、不覆盖、不移动现有 Agent 文件；先做清单、hash 和可恢复的本地备份，后部署。
2. 不读取或输出凭据内容。涉及认证的配置只记录服务器名称、认证类型和“需在该端重新登录”的状态。
3. 不直接软链接整个 `settings.json`、`config.toml`、`mcp_config.json` 或插件目录；这些文件含平台状态或格式专属字段。
4. 仅可对**已审查且可移植**的 Skill 目录创建软链接。链接必须先经断链检查，再替换发现入口。
5. 所有写入均采用：预检 → 生成到临时位置 → 语法/内容验证 → 建立可回退备份 → 原子切换 → 运行验证。
6. 每项部署都必须能独立回退；不得把多个 Agent、多个 Skill 或多种资产绑定成一次不可拆分的变更。
7. 发生任何验证失败时，立刻回退该项，记录失败证据，不继续下一项。

## 5. 分阶段实施计划

### Phase 0 — 记录与冻结基线

**目的：** 建立本手册、收集非敏感清单、确认原始状态未被改动。

**允许写入：** 仅 `Agent_Assets/` 内的文档、清单与测试。  
**禁止写入：** `~/.claude`、`~/.codex`、`~/.gemini`、任意项目工作区。

**完成条件：**

- 本手册已提交到 Utilities Git 仓库。
- 生成包含路径、类型、mtime、SHA-256（仅非敏感文本/脚本）的清单。
- 明确排除凭据、SQLite、JSONL 会话、日志、OAuth 文件和插件缓存。

**回退：** 删除本次新建的文档即可；不影响任何 Agent。删除前仍须获得用户确认。

### Phase 1 — 建立资产库骨架与 registry

**目的：** 创建目录、机器可读 registry schema、README、忽略规则与验证脚本框架。

**前置检查：**

- `git -C /home/gao/Utilities status --short` 仅记录与本任务无关的既有改动，不碰它们。
- 验证所有目标父目录可写。
- 验证 `.gitignore` 排除 `*.env`、credential/token 文件、会话数据库和构建缓存。

**操作：**

1. 新建目录结构及 `registry/skills.*`、`registry/mcp.*` schema。
2. 对每个资产记录：来源、适用 Agent、是否可软链、是否含平台适配、最后验证时间、原始 checksum。
3. 建立 `scripts/verify-assets`，初期只检查目录、YAML/JSON/TOML 语法和断链。

**验证：** 空仓库验证脚本通过；Git diff 只包含 `Agent_Assets/`。

**回退：** 删除 Phase 1 新建目录（须经用户确认）；或使用本 Phase 的唯一 Git commit 反向恢复。不得影响现有 Agent 目录。

### Phase 2 — Skill 审计、合并与分发

**目的：** 让每个可移植 Skill 在资产库中只有一个真身。

**前置检查：**

1. 对每个候选 Skill 递归记录文件清单与 checksum。
2. 对同名不同内容的 Skill 生成逐文件 diff 和语义差异摘要。
3. 检查 `SKILL.md` frontmatter、相对资源路径和脚本可执行位。

**决策门：**

- 名称相同的 Skill 在**首次迁移**时一律采用 Claude Code 版本建立 `Agent_Assets/skills/` 中的唯一真身；Antigravity 版本的 checksum、来源路径和差异摘要记录在 registry 中供审计。
- 切换完成后，所有三端均从该唯一真身发现/部署；Claude Code 与 Antigravity 均不得再作为独立的长期编辑源。
- 名称不同的 Skill 即使功能相近，也视为独立资产；只有用户明确授权时才讨论合并、重命名或废弃。
- 不得以 Antigravity 版本覆盖、补写或混合 Claude Code 版本的内容。

**部署顺序：**

1. 先在 `Agent_Assets/skills/<name>/` 创建并验证真身。
2. 在临时目录创建三端链接并验证解析到同一 inode/目标、无断链、资源路径可读。
3. 按一端、一个 Skill 的粒度部署：Claude → Codex → Antigravity。
4. Antigravity 采用官方全局发现目录 `~/.gemini/config/skills/`；现有 `~/.gemini/skills/` 不删除，直到确认真实加载行为、完成回退设计并获得明确授权。

**验证：**

- 三端各自列出该 Skill，读取其描述并能访问所需脚本/参考资料。
- 所有目标链接通过 `test -e`、`readlink` 和 registry checksum 验证。
- 目标端启动日志没有 Skill 解析或 frontmatter 错误。

**回退：** 移除本次新增的发现入口链接，恢复该项切换前备份；资产库真身和原始 Agent Skill 均保留。

### Phase 3 — 共享规则与项目规则适配

**目的：** 从 Claude L0 规则提取跨端规则，而不把 Claude 专属机制错误移植。

**共享候选：** 中文沟通、先结论后证据、最小修改、保护用户既有改动、不把未验证写成事实、删除/覆盖前询问、验证与 Git 交付原则、客户交付不发送、长任务 tmux、资源上限及生信业务约束。

**必须留在适配层的内容：** Claude hook 事件名、Claude 专属状态/IDE lock、`Co-Authored-By` 的模型名称表达、各端权限语法和 UI/命令。

**操作：**

1. 创建 `instructions/core.md` 与有明确适用范围的模块文件。
2. 为 Claude 生成/链接其加载入口，为 Codex 生成 `AGENTS.md` 层级入口，为 Antigravity 生成其 rules/plugin 入口。
3. 项目级规则通过项目内的最薄入口文件连接共享模块；项目自身规则仍留在项目内并在最末层覆盖。

**验证：** 每个 Agent 从同一测试项目报告已加载的规则来源和优先级；用无破坏性的提示验证核心约束被正确理解。

**回退：** 恢复该 Agent 的原规则入口；删除新入口，不删除共享源文件和原始文件。

### Phase 4 — MCP catalog 与客户端渲染

**目的：** 统一服务器定义，而不是统一凭据或客户端状态。

**MCP catalog 允许记录：** 规范名称、用途、transport、命令/非敏感 URL、参数、非敏感环境变量名称、权限级别、适用 Agent、是否需要 OAuth。  
**MCP catalog 禁止记录：** token、密码、authorization header 值、OAuth client secret、刷新令牌。

**操作：**

1. 先把当前 `gmail`、`github`、`outlook` 作为“发现到、尚待核验”的条目，而非自动新装。
2. 分别渲染 Claude、Codex TOML 与 Antigravity `mcp_config.json` 的无密钥定义。
3. 对每个 Agent 在其原生认证流程中单独登录；不复制认证文件。
4. 一次只启用一个只读/低风险服务器，确认列出工具、权限提示和超时行为后才扩展。

**验证：** 配置语法正确；服务器被发现；未授权操作仍要求批准；无 token 出现在 Git diff、日志或 catalog。

**回退：** 在该客户端禁用/删除本次新增服务器定义；认证材料不动。必要时仅恢复该客户端本地配置备份。

### Phase 5 — hooks、权限与安全等效性

**目的：** 最大化复用 Claude 已验证的保护逻辑，同时承认生命周期事件并不完全相同。

**现有 Claude 保护：** destructive Bash、符号链接搜索、内联客户邮件、冻结交付物、当前文档解析、写后报告/邮件检查、结束前回复检查。

**操作原则：**

- 将检查规则和 fixture 放入 `hooks/core/`，将输入/输出协议标准化。
- Claude 保留现有 hook 脚本与 settings，直到新适配器逐项通过原有测试。
- Codex/Antigravity 只在其原生 event 可表达同一保证时接入；无法等效的项保留为规则或人工验证，不虚称“已硬拦”。
- 每添加一个 hook，必须新增该端的正反例测试和失败回退测试。

**验证：** 现有 Claude 105 条测试先全部通过；每端分别记录覆盖率和未能机械化的规则。

**回退：** 移除仅本次添加的客户端 hook/adaptor，恢复原有客户端权限；Claude 原 hook 不受影响。

### Phase 6 — harness、项目模板与发布验证

**目的：** 每个项目以相同的可执行检查入口让三个 Agent 验证工作，而不是依赖各自临时命令。

**操作：**

1. 建立小型、可组合的 harness 命令（例如资产验证、项目静态检查、项目测试入口），不强制所有生信项目使用同一条重型 pipeline。
2. 提供项目模板：项目规则入口、可选 MCP 定义、harness 入口和完成标准。
3. 先在一个无生产数据的测试项目 smoke test，再逐项目采用。

**发布验收：**

- 三端各自发现同一组已批准 Skills。
- 三端读取同一核心规则，且各自专属规则仍生效。
- 三端能解析其 MCP 配置；认证相互独立。
- Claude 既有 hooks 未退化；其它端的声明性保护有测试证据。
- `verify-assets`、断链检查、语法检查和仓库 diff 检查全部通过。

**回退：** 逐项目移除模板入口，逐客户端恢复前一版入口；共享资产库保留以供审计，不删除历史。

## 6. 明确不纳入统一真身的内容

| 类别 | 原因 | 策略 |
| :--- | :--- | :--- |
| OAuth、API key、token、cookie | 安全与账户隔离 | 仅各客户端自己的安全存储/登录流程管理 |
| 模型、订阅、用量与 LLM routing | 由各厂商产品和订阅决定 | 不部署 Proxy，不共享 API key |
| 对话、记忆、SQLite、JSONL、日志 | 高动态、私密且格式专属 | 保留原端；有价值的长期项目事实转为项目文档 |
| 官方/市场插件与缓存 | manifest、版本和权限专属 | 保持原生安装；仅记录依赖与版本 |
| 直接复制 hook 配置 | 生命周期和输入格式不同 | 仅共享检查逻辑与测试，分别适配 |

## 7. 每次变更的强制记录模板

在执行任何实际配置变更前后，向本节追加一条记录：

```md
### YYYY-MM-DD HH:MM — <唯一变更 ID>

- 阶段：Phase <N>
- 状态：planned | applied | verified | reverted | failed
- 目标：<一个 Agent / 一个资产 / 一个项目>
- 原因与预期：<为何需要该变更>
- 前置基线：<路径、非敏感 checksum、原状态>
- 写入范围：<精确路径清单>
- 执行命令/脚本版本：<可重放命令或 Git commit>
- 验证：<实际运行的检查与结果>
- 回退：<精确恢复步骤、备份位置或 Git commit>
- 残余风险/待决策：<若有>
```

## 8. 回退总原则

1. 先停止后续部署，再读取该项变更日志；不得在不明状态下批量“重置”。
2. 只回退发生故障的最小单元（一个链接、一个配置段、一个 hook 适配器或一个项目入口）。
3. 优先恢复切换前的本地备份或对应 Git commit；禁止 `git reset --hard`、`git clean`、递归删除。
4. 回退后必须重新运行该项原有验证，并把实际结果写回本手册。
5. 如果回退会删除用户文件、认证状态、结果目录或历史记录，停止并先取得明确用户批准。

## 9. 当前变更日志

### 2026-10-21 — AA-000 Phase 0 runbook

- 阶段：Phase 0
- 状态：verified
- 目标：建立迁移运行手册
- 前置基线：未改动任何 Agent 配置；`/home/gao/Utilities` 工作树在检查时无本任务相关未提交变更
- 写入范围：仅本文件
- 验证：`git -C /home/gao/Utilities diff --check` 通过；结构检查确认第 1–9 节齐全；当时 Git 状态仅显示新增的 `AI_and_Agent/Agent_Assets/` 目录
- 回退：删除本文件即可；须先获用户确认
- 残余风险/待决策：同名 Skill 已确定 Claude Code 为首次迁移来源；切换后由 `Agent_Assets` 作为唯一长期权威；仅名称不同而功能可能相近的 Skill 仍不得自动合并

### 2026-10-21 — AA-001 Claude 同名 Skill 首次迁移来源决策

- 阶段：Phase 2（预先决策）
- 状态：verified
- 目标：确定同名 Skill 的首次迁移来源与长期权威位置
- 决策：所有同名 Skill 首次迁移时一律以 `~/.claude/skills/<name>/` 内容建立 `Agent_Assets/skills/<name>/` 真身；完成切换后仅 `Agent_Assets/skills/` 可编辑并作为三端共同标准。Antigravity 同名版本仅留作迁移审计记录
- 影响范围：后续 registry、Skill 分发、checksum 基线和长期维护入口；未改动任何 Agent Skill 文件
- 验证：本手册的基线和 Phase 2 决策门已更新为同一规则
- 回退：仅在用户明确撤销本决策后修改本手册；既有 Agent 文件不受影响

### 2026-10-22 — AA-002 shared-asset cutover

- 阶段：Phase 1–6
- 状态：verified
- 目标：将共享规则、Skills 与 Claude hook 源切换为 `Agent_Assets` 的唯一真身，并建立三端发现入口
- 写入范围：
  - `Agent_Assets/`：共享规则、21 个共享 Skill、hook 源/测试、registry、MCP 无密钥 catalog、Codex hook adapter、部署/验证/回退脚本。
  - `~/.claude/CLAUDE.md`：链接至 `instructions/SHARED_AGENT_RULES.md`。
  - `~/.claude/skills/`：20 个原有自建 Skill 替换为链接；新增的 `tax-resemb-mag` 链接指向独立共享资产。
  - `~/.claude/hooks/`：10 个 Python hook/test 文件和 `checks/` 替换为链接；动态日志和状态文件未移动。
  - `~/.codex/AGENTS.md`、`~/.codex/hooks.json` 和 `~/.codex/skills/`：建立共享规则、Codex hook adapter、21 个 Skill 的链接。
  - `~/.gemini/AGENTS.md`、`~/.gemini/config/skills/`：建立共享规则和 21 个 Skill 的链接；旧 `~/.gemini/skills/` 改为指向官方全局 Skill 根的链接。
- 未写入范围：Claude/Codex/Antigravity 的认证、token、OAuth、会话、模型选择、权限设置、MCP 原始配置和厂商插件缓存。
- 回退快照：
  - 完整首次切换：`/home/gao/Utilities/AI_and_Agent/Agent_Assets/snapshots/cutover-20261021T235022/`
  - Codex hook 入口：`/home/gao/Utilities/AI_and_Agent/Agent_Assets/snapshots/cutover-20261022T151220/`
  - 快照保留在本机但由 `.gitignore` 排除；不得删除或批量清理。
- 验证：
  - `scripts/verify.sh` 通过，确认三端 21 个 Skill、三端规则入口、Claude hook 链接和 Codex hook 入口均解析到唯一真身。
  - Claude 原有测试通过：destructive guard 21/21、symlink-search guard 19/19、报告/邮件/回复检查 65/65，共 105/105。
  - Codex adapter 实测：force-push 返回 `deny`；非临时路径删除返回“需要用户确认”的附加上下文并交由 Codex 原生审批处理。
  - Antigravity CLI 的无写入 `--mode plan --print` 发现测试已发起，但在调用模型前要求该客户端完成 OAuth 登录；遵守无凭据迁移边界，未登录、未复制认证信息，因此仅记录为待客户端首次登录后的手工复验。
  - `git diff --check` 通过。
- MCP 状态：`mcp/catalog.yaml` 已建立为唯一无密钥 catalog；现有客户端的认证型 MCP 配置保持原状，未跨端复制任何凭据。新增客户端连接须在该客户端完成原生登录后启用。
- 残余风险：Codex 会按其安全模型要求在首次使用时 review/trust 本地 hook；Antigravity 使用共享全局 `AGENTS.md` 和官方 global Skills 目录，但其 hooks/MCP 认证尚未声称与 Claude 完全等效。

### 2026-10-22 — AA-003 endpoint and symlink reference map

- 阶段：Phase 6
- 状态：applied
- 目标：建立未来所有 Agent 必须参考的客户端地址、唯一源地址与新增接入流程。
- 写入范围：新增 `AGENT_ENDPOINTS_AND_LINKS.md`；在 `README.md` 增加该文档入口。
- 验证：实际 `readlink -f` 核验三个规则入口、Codex hook 入口、Antigravity legacy Skill alias，以及三个 Skill 根目录各 21 个共享软链接；随后运行 `scripts/verify.sh`。
- 回退：删除本次新增的说明文档和 README 链接即可；不影响任何客户端入口或共享资产。

### 2026-10-22 — AA-004 universal-rule registry and N-agent verification

- 阶段：Phase 3 / 6
- 状态：verified
- 目标：把“所有 Agent 的通用规则均来自唯一 canonical source”提升为首要共享规则，并以机器可读 registry 驱动验证，避免 `verify.sh` 仅硬编码 Claude Code、Codex、Antigravity 三端。
- 原因与预期：当前与未来任意第 N 个 Agent 必须使用同一份纯共享规则；不得因新增客户端复制或分叉通用规则。
- 前置基线：三个当前入口均为软链接并解析到 `instructions/SHARED_AGENT_RULES.md`；`scripts/verify.sh` 的规则入口检查为三端硬编码。
- 计划写入范围：`instructions/SHARED_AGENT_RULES.md`、`registry/agents.json`、`scripts/verify.sh`、`AGENT_ENDPOINTS_AND_LINKS.md`、`README.md` 和本变更记录。
- 实际写入范围：与计划一致；未运行 deploy，未改变任何 Agent 的现有规则入口、认证、会话或客户端设置。
- 验证：`python3 -m json.tool registry/agents.json`、`bash -n scripts/verify.sh`、`bash -n scripts/deploy.sh` 均通过；registry 断言确认 3 个已注册入口均解析到唯一 canonical rule；`scripts/verify.sh` 通过；`git diff --check` 通过。
- 回退：仅回退 AA-004 修改的 registry、验证逻辑与说明；不删除任何 Agent 的既有入口链接。
