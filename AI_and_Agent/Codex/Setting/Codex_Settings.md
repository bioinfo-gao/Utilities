# Codex Settings

Last updated: 2026-09-19

## User Preferences

- When the user asks a question about a document and does not specify a path, treat the target as the currently open document that the user is reading.
- Respond in Chinese when the conversation is in Chinese, unless the user asks otherwise.
- Prefer direct, practical answers for hardware, coding, and workflow questions.

## Working Assumptions

- The shared workspace includes `/home/gao/.claude`, `/home/gao/projects_2026M7`, `/home/gao/Utilities`, and `/home/gao`.
- Current local timezone context is `America/New_York`.
- For local file work, inspect existing files before editing and preserve unrelated user changes.
- Use fast local search tools such as `rg` where possible.

## Codex Behavior Notes

- If a user asks for an implementation or file change, proceed to make the change when the request is clear.
- If the user asks for a code review, prioritize concrete findings, risks, regressions, and missing tests.
- For OpenAI/Codex product documentation questions, use the available OpenAI documentation skill or official sources when needed.
- For current, time-sensitive, legal, financial, medical, pricing, schedule, or product-status information, verify with up-to-date sources.

## Skill Locations

Codex skills currently visible in this session are mainly stored under these roots:

- System skills: `/home/gao/.codex/skills/.system`
- Plugin cache skills: `/home/gao/.codex/plugins/cache/openai-curated-remote`

Visible skill files include:

- `imagegen`: `/home/gao/.codex/skills/.system/imagegen/SKILL.md`
- `openai-docs`: `/home/gao/.codex/skills/.system/openai-docs/SKILL.md`
- `plugin-creator`: `/home/gao/.codex/skills/.system/plugin-creator/SKILL.md`
- `skill-creator`: `/home/gao/.codex/skills/.system/skill-creator/SKILL.md`
- `skill-installer`: `/home/gao/.codex/skills/.system/skill-installer/SKILL.md`
- `plugin-management:plugin-management`: `/home/gao/.codex/plugins/cache/openai-curated-remote/plugin-management/0.1.0/skills/plugin-management/SKILL.md`

If the document-context preference is later turned into a dedicated Codex skill, a reasonable location would be:

- `/home/gao/.codex/skills/document-context/SKILL.md`
