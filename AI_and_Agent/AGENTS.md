# AI_and_Agent directory instructions

This directory stores documentation and the versioned shared assets for multiple
coding agents. The active cross-Agent operational rules are not maintained here:

`/home/gao/Utilities/AI_and_Agent/Agent_Assets/instructions/SHARED_AGENT_RULES.md`

Before changing any shared configuration, read these documents in order:

1. `Agent_Assets/AGENT_ENDPOINTS_AND_LINKS.md` — client paths, canonical sources, and how to add another Agent.
2. `Agent_Assets/MIGRATION_RUNBOOK.md` — cutover history, verification, snapshots, and rollback.
3. `DOCUMENT_MAP.md` — role and status of the documentation in this directory.

Do not edit client-side linked copies under `~/.claude`, `~/.codex`, or `~/.gemini`.
Edit the canonical file in `Agent_Assets/`, run its verification script, and record
any material migration in the runbook. Authentication, OAuth, tokens, sessions,
and vendor plugin state remain client-local and must never be copied into shared
assets or Git.
