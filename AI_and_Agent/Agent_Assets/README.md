# Agent Assets

This directory is the sole editable source for the shared setup of every registered Agent, currently Claude Code, Codex, and Antigravity.

- Edit universal rules only in `instructions/SHARED_AGENT_RULES.md`. `registry/agents.json` is the SSOT for every registered Agent rule entry; every entry must resolve to that same file.
- Edit shared workflows in `skills/`.
- Run `scripts/deploy.sh --apply` to distribute links. It creates a timestamped local rollback snapshot before every change.
- Run `scripts/verify.sh` after every deployment.
- Never edit the linked copies in `~/.claude`, `~/.codex`, or `~/.gemini` directly.
- Authentication, secrets, client state, and vendor plugins deliberately remain client-local.

See `MIGRATION_RUNBOOK.md` for the full rollout and rollback procedure.
See `AGENT_ENDPOINTS_AND_LINKS.md` for the client paths, canonical sources, and mandatory procedure for adding another Agent.
