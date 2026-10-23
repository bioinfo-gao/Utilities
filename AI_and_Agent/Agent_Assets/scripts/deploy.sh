#!/usr/bin/env bash
# Distribute only symlinks and preserve every replaced entry in a timestamped snapshot.
set -euo pipefail

ASSETS=/home/gao/Utilities/AI_and_Agent/Agent_Assets
AGENT_REGISTRY="$ASSETS/registry/agents.json"
MODE=${1:-}

if [[ "$MODE" != "--apply" ]]; then
  echo "Usage: $0 --apply" >&2
  exit 64
fi

STAMP=$(date +%Y%m%dT%H%M%S)
SNAPSHOT="$ASSETS/snapshots/cutover-$STAMP"
changed=0
mkdir -p "$SNAPSHOT"/{claude,claude/skills,codex/codex-skills,gemini,gemini/config}
printf 'Agent Assets cutover snapshot %s\n' "$STAMP" > "$SNAPSHOT/README.md"

link_entry() {
  local source=$1 target=$2 backup_rel=$3
  mkdir -p "$(dirname "$target")" "$(dirname "$SNAPSHOT/$backup_rel")"
  if [[ -L "$target" && "$(readlink -f "$target")" == "$(readlink -f "$source")" ]]; then
    printf 'already linked: %s\n' "$target"
    return
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    mv "$target" "$SNAPSHOT/$backup_rel"
    changed=1
    printf 'moved to rollback snapshot: %s -> %s\n' "$target" "$SNAPSHOT/$backup_rel"
  fi
  ln -s "$source" "$target"
  changed=1
  printf 'linked: %s -> %s\n' "$target" "$source"
}

# Global rules: every registered Agent links to the same canonical source.
while IFS=$'\t' read -r agent_id rule_entry; do
  link_entry "$ASSETS/instructions/SHARED_AGENT_RULES.md" "$rule_entry" "rules/$agent_id/$(basename "$rule_entry")"
done < <(python3 - "$AGENT_REGISTRY" "$ASSETS/instructions/SHARED_AGENT_RULES.md" <<'PY'
import json
import pathlib
import sys
registry = json.load(open(sys.argv[1], encoding="utf-8"))
canonical = pathlib.Path(sys.argv[2])
if registry.get("schema_version") != 1 or pathlib.Path(registry.get("canonical_rule", "")) != canonical:
    raise SystemExit("invalid agent registry canonical_rule")
for agent in registry.get("agents", []):
    if agent.get("rule_entry_mode") != "symlink":
        raise SystemExit(f'unsupported rule entry mode for {agent.get("id")}')
    print(f'{agent["id"]}\t{agent["rule_entry"]}')
PY
)
link_entry "$ASSETS/adapters/codex/hooks.json" /home/gao/.codex/hooks.json codex/hooks.json
link_entry "$ASSETS/adapters/antigravity/hooks.json" /home/gao/.gemini/config/hooks.json gemini/config/hooks.json

# Skills: every client points to the same canonical folders.
for source in "$ASSETS"/skills/*; do
  name=$(basename "$source")
  link_entry "$source" "/home/gao/.claude/skills/$name" "claude/skills/$name"
  link_entry "$source" "/home/gao/.codex/skills/$name" "codex/codex-skills/$name"
  link_entry "$source" "/home/gao/.gemini/config/skills/$name" "gemini/config/skills/$name"
done

# Antigravity's old global skill root becomes an alias of its current documented root.
link_entry /home/gao/.gemini/config/skills /home/gao/.gemini/skills gemini/skills-legacy-root

# Claude hooks keep their client-local log and state files. Only executable source and checks are linked.
for source in "$ASSETS"/hooks/core/*.py; do
  name=$(basename "$source")
  link_entry "$source" "/home/gao/.claude/hooks/$name" "claude/hooks/$name"
done
link_entry "$ASSETS/hooks/core/checks" /home/gao/.claude/hooks/checks claude/hooks/checks

CRON_RESULT=$(bash "$ASSETS/scripts/install_continuity_guard_cron.sh" --apply "$SNAPSHOT/cron/crontab_before")
printf '%s\n' "$CRON_RESULT"
case "$CRON_RESULT" in
  "installed continuity cron"|"updated continuity cron") changed=1 ;;
  "continuity cron already installed") ;;
  *) echo "unexpected continuity-cron installer result" >&2; exit 1 ;;
esac

if [[ "$changed" -eq 1 ]]; then
  if [[ ! -s "$ASSETS/snapshots/FIRST_CUTOVER" ]]; then
    printf '%s\n' "$SNAPSHOT" > "$ASSETS/snapshots/FIRST_CUTOVER"
  fi
  printf '%s\n' "$SNAPSHOT" > "$ASSETS/snapshots/LATEST_CUTOVER"
  printf 'Cutover complete. Rollback snapshot: %s\n' "$SNAPSHOT"
else
  printf 'No deployment changes were needed. Empty snapshot retained: %s\n' "$SNAPSHOT"
fi
