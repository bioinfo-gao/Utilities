# AI_and_Agent 文档地图

> **目的：** 消除同名/重复规则造成的歧义。下表定义每份文档的唯一职责、状态和维护入口。

| 文档 | 状态 | 唯一职责 | 更新规则 |
| :--- | :---: | :---: | :---: |
| `AGENTS.md` | active | 本目录的简短路由入口 | 仅维护入口和链接，不复制完整规则 |
| `AGENTS0.md` | compatibility | 保留旧书签/旧引用 | 不添加规则；只指向 `AGENTS.md` |
| `rules.md` | compatibility | 保留旧书签/旧引用 | 不添加规则；只指向唯一共享规则源 |
| `MERGE_NOTES.md` | historical record | 整个 Utilities 的合并与退役事实 | 仅追加新的、带日期的历史核验 |
| `Agent_Assets/instructions/SHARED_AGENT_RULES.md` | canonical | Claude Code、Codex、Antigravity 的共享行为规则 | 只在此处修改，三个客户端通过链接加载 |
| `Agent_Assets/AGENT_ENDPOINTS_AND_LINKS.md` | canonical | 三端入口、软链接源与新增 Agent 接入方法 | 路径或接入方式变动时同步更新 |
| `Agent_Assets/MIGRATION_RUNBOOK.md` | canonical record | 迁移、验证、快照与回退记录 | 每次实际切换先记录、后执行、再补验证 |

## 本次整理（2026-10-22）

- `AGENTS.md` 成为本目录唯一有效入口，不再维护平行规则副本。
- `AGENTS0.md` 与 `rules.md` 保留原路径以兼容旧链接，但已降级为明确的跳转文档。
- `MERGE_NOTES.md` 保留原路径和正文，仅补充文档角色与维护边界。
- 四份整理前的逐字节副本和 SHA-256 见：
  `superseded_for_comparison/agent_documentation/v1_20261022_pre_consolidation/`。

若需要移动 `MERGE_NOTES.md` 到 Utilities 根目录，必须作为单独的路径迁移：先搜索引用、建立兼容
入口、验证 Git 历史与链接，再得到用户确认后执行；本次没有改变该文件路径。
