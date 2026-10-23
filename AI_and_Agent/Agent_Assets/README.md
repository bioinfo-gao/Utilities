# Agent Assets

This directory is the sole editable source for the shared setup of every registered Agent, currently Claude Code, Codex, and Antigravity.

- Edit universal rules only in `instructions/SHARED_AGENT_RULES.md`. `registry/agents.json` is the SSOT for every registered Agent rule entry; every entry must resolve to that same file.
- Edit shared workflows in `skills/`.
- Active autonomous-project state exists only in `runtime/active_projects.json`. The shared evaluator in `hooks/core/continuity_state.py` is used by client Stop adapters, while the managed crontab entry runs `scripts/continuity_guard.py` independently every ten minutes. An active project missing its expected tmux is logged silently during a 30-minute hand-off grace period; only an uninterrupted absence beyond that period sends a severe-event email/TTY alert, with repeat reminders no more often than every six hours until recovery. Do not create per-agent project-status lists or claim a client adapter is runtime-enforced without client-specific evidence.
- Run `scripts/deploy.sh --apply` to distribute links. It creates a timestamped local rollback snapshot before every change.
- Run `scripts/verify.sh` after every deployment.
- Never edit the linked copies in `~/.claude`, `~/.codex`, or `~/.gemini` directly.
- Authentication, secrets, client state, and vendor plugins deliberately remain client-local.

See `MIGRATION_RUNBOOK.md` for the full rollout and rollback procedure.
See `AGENT_ENDPOINTS_AND_LINKS.md` for the client paths, canonical sources, and mandatory procedure for adding another Agent.
