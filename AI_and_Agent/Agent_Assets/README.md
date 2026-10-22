# Agent Assets

This directory is the sole editable source for the shared Claude Code, Codex, and Antigravity setup after cutover.

- Edit shared rules in `instructions/` and shared workflows in `skills/`.
- Run `scripts/deploy.sh --apply` to distribute links. It creates a timestamped local rollback snapshot before every change.
- Run `scripts/verify.sh` after every deployment.
- Never edit the linked copies in `~/.claude`, `~/.codex`, or `~/.gemini` directly.
- Authentication, secrets, client state, and vendor plugins deliberately remain client-local.

See `MIGRATION_RUNBOOK.md` for the full rollout and rollback procedure.
