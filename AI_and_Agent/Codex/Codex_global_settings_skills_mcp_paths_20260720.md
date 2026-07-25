# Codex Global Settings, Skills, Plugins, and MCP Paths

Created: 2026-07-20

This document records where the current Codex-side configuration, skills, plugin cache, app/MCP cache, and runtime state live on this machine. It is meant as a quick path map, analogous to `/home/gao/.claude/CLAUDE.md` and `/home/gao/.claude/skills/`, but for Codex.

## Executive Summary

| Category | Path | Status / Notes |
| :--- | :---: | :---: |
| Main Codex config | `/home/gao/.codex/config.toml` | Active global Codex config |
| Permission rules | `/home/gao/.codex/rules/default.rules` | Contains saved command approval rules |
| System skills | `/home/gao/.codex/skills/.system/` | Built-in Codex skills currently available |
| User skills | `/home/gao/.codex/skills/` | No non-system user skills found under this directory |
| Plugin cache | `/home/gao/.codex/plugins/` | Installed/remote plugin cache area |
| Remote plugin catalog cache | `/home/gao/.codex/.tmp/plugins/` and `/home/gao/.codex/cache/remote_plugin_catalog/` | Cached plugin marketplace metadata, not necessarily installed |
| Apps/MCP cache | `/home/gao/.codex/cache/codex_app_directory/`, `/home/gao/.codex/cache/codex_apps_server_info/`, `/home/gao/.codex/cache/codex_apps_tools/` | Cached ChatGPT Apps / connector MCP metadata |
| Auth/session/state | `/home/gao/.codex/auth.json`, `/home/gao/.codex/sessions/`, SQLite state files | Sensitive/runtime state; do not copy into project docs or git |
| Personal agent marketplace | `/home/gao/.agents/` | Directory exists but currently empty |

## Active Global Config

File: `/home/gao/.codex/config.toml`

Current content observed:

```toml
model = "gpt-5.5"
model_reasoning_effort = "medium"

[features]
multi_agent = true

[projects."/home/gao"]
trust_level = "trusted"
```

Meaning:

- Default model: `gpt-5.5`
- Reasoning effort: `medium`
- Multi-agent support: enabled
- `/home/gao` is trusted by Codex

## Saved Rules

File: `/home/gao/.codex/rules/default.rules`

Current content observed:

```text
prefix_rule(pattern=["git", "push"], decision="allow")
```

Meaning: Codex has a saved allow rule for commands beginning with `git push`.

## Built-In Codex Skills

Directory: `/home/gao/.codex/skills/.system/`

| Skill | Main file | Main purpose |
| :--- | :---: | :---: |
| `imagegen` | `/home/gao/.codex/skills/.system/imagegen/SKILL.md` | Generate/edit raster images; uses built-in `image_gen` by default, CLI fallback only when explicitly needed |
| `openai-docs` | `/home/gao/.codex/skills/.system/openai-docs/SKILL.md` | Official OpenAI/Codex docs, model guidance, OpenAI API guidance |
| `plugin-creator` | `/home/gao/.codex/skills/.system/plugin-creator/SKILL.md` | Scaffold Codex plugins and marketplace entries |
| `review-agent` | `/home/gao/.codex/skills/.system/review-agent/SKILL.md` | Read-only defect-first code review |
| `skill-creator` | `/home/gao/.codex/skills/.system/skill-creator/SKILL.md` | Create/update Codex skills |
| `skill-installer` | `/home/gao/.codex/skills/.system/skill-installer/SKILL.md` | Install curated or GitHub-hosted Codex skills |

Important helper/reference paths:

| Skill | Helper/reference paths |
| :--- | :---: |
| `imagegen` | `/home/gao/.codex/skills/.system/imagegen/references/`, `/home/gao/.codex/skills/.system/imagegen/scripts/image_gen.py`, `/home/gao/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py` |
| `openai-docs` | `/home/gao/.codex/skills/.system/openai-docs/references/`, `/home/gao/.codex/skills/.system/openai-docs/scripts/fetch-codex-manual.mjs` |
| `plugin-creator` | `/home/gao/.codex/skills/.system/plugin-creator/references/`, `/home/gao/.codex/skills/.system/plugin-creator/scripts/` |
| `skill-creator` | `/home/gao/.codex/skills/.system/skill-creator/references/`, `/home/gao/.codex/skills/.system/skill-creator/scripts/` |
| `skill-installer` | `/home/gao/.codex/skills/.system/skill-installer/scripts/` |

## Plugin And Marketplace Paths

Installed/remote plugin areas:

| Path | Notes |
| :--- | :---: |
| `/home/gao/.codex/plugins/` | Codex plugin installation/cache area |
| `/home/gao/.codex/plugins/cache/openai-curated-remote/openai-templates/.codex-remote-plugin-install.json` | Remote plugin install metadata; observed remote plugin id `plugin_connector_1p_2330815c823c8191941e5dc465bb899f` |
| `/home/gao/.codex/.tmp/plugins/` | Temporary synced plugin catalog checkout/cache |
| `/home/gao/.codex/.tmp/plugins/.agents/plugins/marketplace.json` | Cached marketplace metadata from remote catalog |
| `/home/gao/.codex/.tmp/plugins/plugins/` | Large directory of cached plugin definitions; presence here does not mean installed/connected |
| `/home/gao/.agents/` | Personal marketplace root exists but is empty at the time of inspection |

Do not treat `/home/gao/.codex/.tmp/plugins/plugins/*` as installed plugins. It is a catalog/cache mirror used for discovery.

## Apps / MCP / Connector Metadata

Codex Apps / connector cache:

| Path | Notes |
| :--- | :---: |
| `/home/gao/.codex/cache/codex_app_directory/` | Cached directory of ChatGPT Apps/connectors |
| `/home/gao/.codex/cache/codex_apps_server_info/` | Cached server info; observed server name `plugin-runtime` |
| `/home/gao/.codex/cache/codex_apps_tools/` | Cached tool schemas for app/MCP tools |

Tool discovery in the active session showed these lazily available MCP/tool namespaces:

| Namespace | Purpose |
| :--- | :---: |
| `mcp__codex_apps__codex_document_control` | Connected document sessions for Excel / PowerPoint / Google Sheets; use only when a document session is connected |
| `mcp__codex_apps__plugin_management` | Install/connect/uninstall apps/plugins and inspect/update plugin permissions |
| `multi_agent_v1` | Spawn, wait for, resume, and close sub-agents; enabled by `[features].multi_agent = true` |

Current visible non-MCP developer tools in this Codex session include:

| Tool group | Purpose |
| :--- | :---: |
| `functions.exec_command`, `functions.apply_patch`, `functions.view_image`, etc. | Local shell/file/image/task utilities |
| `image_gen.imagegen` | Built-in image generation/editing |
| `tool_search.tool_search_tool` | Deferred tool discovery, including MCP/plugin tools |
| `multi_tool_use.parallel` | Parallel execution wrapper for developer tools |
| `web.run` | Internet search/open/weather/finance/etc. when browsing is required |

## Runtime State And Sensitive Files

These are useful to know about but should generally not be read, copied, or committed unless there is a specific debugging need:

| Path | Why to avoid casual use |
| :--- | :---: |
| `/home/gao/.codex/auth.json` | Authentication material / sensitive local state |
| `/home/gao/.codex/sessions/` | Conversation/session transcripts |
| `/home/gao/.codex/attachments/` | User-provided attachment cache |
| `/home/gao/.codex/logs_2.sqlite*` | Runtime logs database |
| `/home/gao/.codex/state_5.sqlite*` | Runtime state database |
| `/home/gao/.codex/memories_1.sqlite` | Memory database |
| `/home/gao/.codex/goals_1.sqlite*` | Goal tracking database |
| `/home/gao/.codex/shell_snapshots/` | Shell session snapshots |
| `/home/gao/.codex/tmp/` and `/home/gao/.codex/.tmp/` | Temporary runtime/cache files |

## Relationship To Claude Settings

The Claude-side configuration that was inspected separately lives here:

| Claude category | Path |
| :--- | :---: |
| Global Claude instructions | `/home/gao/.claude/CLAUDE.md` |
| Claude skills | `/home/gao/.claude/skills/` |
| Claude settings | `/home/gao/.claude/settings.json`, `/home/gao/.claude/settings.local.json` |
| Claude plugin cache | `/home/gao/.claude/plugins/` |

For future work, Codex should follow the user-specific scientific/workflow rules learned from `/home/gao/.claude/CLAUDE.md` and `/home/gao/.claude/skills/` where they do not conflict with higher-priority Codex system/developer instructions.

## Practical Maintenance Notes

- To add persistent Codex behavior, first consider whether it belongs in `/home/gao/.codex/config.toml`, a project `AGENTS.md`, or a custom skill under `/home/gao/.codex/skills/`.
- To add a new reusable Codex skill, use the `skill-creator` workflow and place it under `/home/gao/.codex/skills/<skill-name>/`.
- To install a curated/GitHub skill, use the `skill-installer` workflow.
- To create a Codex plugin, use `plugin-creator`; default personal plugin roots are typically under `~/plugins/` and marketplace metadata may be placed under `~/.agents/plugins/marketplace.json`.
- Do not commit `auth.json`, session transcripts, attachment caches, SQLite runtime state, or plugin/app cache blobs into project repositories.
