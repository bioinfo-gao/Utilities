# Agent 接入点与软链接地图

> **用途：** 本文件是现有及未来 Agent 接入共享资产库时唯一应先查的地址地图。
> **核验日期：** 2026-10-22。所有路径均为本机绝对路径。
>
> **维护铁律：** 共享规则、Skill、共享检查逻辑和无密钥 MCP 定义只在
> `/home/gao/Utilities/AI_and_Agent/Agent_Assets/` 编辑；不得直接编辑下游软链接。
> 新 Agent 接入或路径变动时，必须先更新本文件、部署脚本和验证脚本，再建立链接。

> **首要一致性规则：** 通用规则的唯一真身是
> `instructions/SHARED_AGENT_RULES.md`；`registry/agents.json` 列出所有已接入 Agent 的规则入口。
> 任意第 N 个 Agent 只有在其入口被注册且 `scripts/verify.sh` 确认该入口解析到同一真身后，才算接入。
> 不允许为新 Agent 复制、摘要或维护另一份通用规则。

## 1. 唯一共享源

| 资产 | 唯一可编辑源 | 下游引用方式 |
| :--- | :---: | :---: |
| 共享全局规则 | `/home/gao/Utilities/AI_and_Agent/Agent_Assets/instructions/SHARED_AGENT_RULES.md` | 各 Agent 全局规则文件的软链接 |
| 共享 Skills（21 个） | `/home/gao/Utilities/AI_and_Agent/Agent_Assets/skills/<skill-name>/` | 各 Agent Skill 发现目录中的目录软链接 |
| Claude hook 核心和测试 | `/home/gao/Utilities/AI_and_Agent/Agent_Assets/hooks/core/` | Claude hook 源文件/`checks` 的软链接 |
| Codex hook 适配层 | `/home/gao/Utilities/AI_and_Agent/Agent_Assets/adapters/codex/` | Codex `hooks.json` 的软链接 |
| 无密钥 MCP catalog | `/home/gao/Utilities/AI_and_Agent/Agent_Assets/mcp/catalog.yaml` | 人工/脚本渲染的输入；**不含认证信息** |
| 接入、部署、验证与回退脚本 | `/home/gao/Utilities/AI_and_Agent/Agent_Assets/scripts/` | 从资产库直接运行 |

## 2. 当前已注册客户端地址及链接

| Agent | 客户端根目录 | 规则入口 → 源地址 | Skill 发现入口 → 源地址 | hook / adapter 入口 → 源地址 |
| :--- | :---: | :---: | :---: | :---: |
| Claude Code | `/home/gao/.claude/` | `/home/gao/.claude/CLAUDE.md` → `Agent_Assets/instructions/SHARED_AGENT_RULES.md` | `/home/gao/.claude/skills/<skill-name>` → `Agent_Assets/skills/<skill-name>`（21 个） | `/home/gao/.claude/hooks/<core-file>` 与 `checks` → `Agent_Assets/hooks/core/` |
| Codex | `/home/gao/.codex/` | `/home/gao/.codex/AGENTS.md` → `Agent_Assets/instructions/SHARED_AGENT_RULES.md` | `/home/gao/.codex/skills/<skill-name>` → `Agent_Assets/skills/<skill-name>`（21 个；系统自带目录不改） | `/home/gao/.codex/hooks.json` → `Agent_Assets/adapters/codex/hooks.json` |
| Antigravity | `/home/gao/.gemini/` | `/home/gao/.gemini/AGENTS.md` → `Agent_Assets/instructions/SHARED_AGENT_RULES.md` | `/home/gao/.gemini/config/skills/<skill-name>` → `Agent_Assets/skills/<skill-name>`（21 个）；`/home/gao/.gemini/skills` → `/home/gao/.gemini/config/skills` | 当前没有共享 hook adapter |

表中所有 `Agent_Assets/...` 相对路径均以
`/home/gao/Utilities/AI_and_Agent/` 为根；解析后的绝对源地址以第 1 节为准。

## 3. 明确保持本机独立、不可软链的地址

| Agent | 本机独立文件/目录 | 原因 |
| :--- | :---: | :---: |
| Claude Code | `/home/gao/.claude/settings.json`、`/home/gao/.claude.json`、`/home/gao/.claude/hooks/` 的日志和状态文件 | 事件注册、认证或运行状态；不得复制 token/OAuth/会话数据 |
| Codex | `/home/gao/.codex/config.toml`、认证和会话状态 | 模型、沙箱、账户与本机状态由 Codex 独立管理 |
| Antigravity | `/home/gao/.gemini/config/mcp_config.json`、认证和会话状态 | MCP OAuth/账户和客户端状态必须在该客户端原生登录 |

## 4. 新增第四个及后续 Agent 的固定接入顺序

1. 先查该 Agent 官方文档，确认其全局规则、全局 Skill、MCP 和 hooks 的发现目录与链接支持；不得靠猜测复用路径。
2. 先在 `registry/agents.json` 登记该 Agent 的唯一 `rule_entry`；全局规则入口只允许 `symlink` 到第 1 节的 canonical source。
3. 在本文件新增该 Agent 的客户端根目录、每个入口地址、是否支持软链接，以及未能等效实现的功能。
4. 在 `Agent_Assets/adapters/<agent-name>/` 新增仅该客户端需要的 adapter；公共逻辑继续放在既有共享源，禁止复制第二份 Skill 或规则。
5. `scripts/deploy.sh --apply` 读取 registry，以“已有目标先移入时间戳快照、再建立软链接”的方式接入，绝不覆盖或删除旧配置。
6. `scripts/verify.sh` 从 registry 逐项断言每个入口解析到第 1 节的唯一源，并执行该客户端可运行的无写入验证。
7. 将认证、OAuth、token、cookie、会话及供应商插件继续留在新 Agent 本机；只从 `mcp/catalog.yaml` 取无密钥服务定义。
8. 运行 `scripts/deploy.sh --apply` 与 `scripts/verify.sh`，记录实际结果、快照路径和残余差异到 `MIGRATION_RUNBOOK.md`，再提交。

## 5. 日常维护与快速核验

```bash
ASSETS=/home/gao/Utilities/AI_and_Agent/Agent_Assets
bash "$ASSETS/scripts/verify.sh"
python3 - <<'PY'
import json
for agent in json.load(open('/home/gao/Utilities/AI_and_Agent/Agent_Assets/registry/agents.json'))['agents']:
    print(agent['id'], agent['rule_entry'])
PY
```

期望 registry 中每个入口经 `readlink -f` 均输出：

`/home/gao/Utilities/AI_and_Agent/Agent_Assets/instructions/SHARED_AGENT_RULES.md`

发生链接错误时，先阅读 `MIGRATION_RUNBOOK.md` 的对应变更记录，再使用
`scripts/rollback-latest.sh` 指向的最新本机快照回退；不要用删除或覆盖的方式“重建”。
