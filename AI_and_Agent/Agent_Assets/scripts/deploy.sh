#!/usr/bin/env bash
# Distribute only symlinks and preserve every replaced entry in a timestamped snapshot.
set -euo pipefail

ASSETS=/home/gao/Utilities/AI_and_Agent/Agent_Assets
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

# Global rules: Claude is cut over to the same canonical rules used by Codex and Antigravity.
link_entry "$ASSETS/instructions/SHARED_AGENT_RULES.md" /home/gao/.claude/CLAUDE.md claude/CLAUDE.md
link_entry "$ASSETS/instructions/SHARED_AGENT_RULES.md" /home/gao/.codex/AGENTS.md codex/AGENTS.md
link_entry "$ASSETS/instructions/SHARED_AGENT_RULES.md" /home/gao/.gemini/AGENTS.md gemini/AGENTS.md
link_entry "$ASSETS/adapters/codex/hooks.json" /home/gao/.codex/hooks.json codex/hooks.json

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

if [[ "$changed" -eq 1 ]]; then
  if [[ ! -s "$ASSETS/snapshots/FIRST_CUTOVER" ]]; then
    printf '%s\n' "$SNAPSHOT" > "$ASSETS/snapshots/FIRST_CUTOVER"
  fi
  printf '%s\n' "$SNAPSHOT" > "$ASSETS/snapshots/LATEST_CUTOVER"
  printf 'Cutover complete. Rollback snapshot: %s\n' "$SNAPSHOT"
else
  printf 'No deployment changes were needed. Empty snapshot retained: %s\n' "$SNAPSHOT"
fi
