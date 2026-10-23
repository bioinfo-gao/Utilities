#!/usr/bin/env bash
# Install exactly one tagged continuity-guard cron line without disturbing other jobs.
set -euo pipefail

MODE=${1:-}
BACKUP=${2:-}
ASSETS=/home/gao/Utilities/AI_and_Agent/Agent_Assets
TAG="# Agent Assets active-project continuity guard"
STATE_DIR=/home/gao/.local/state/agent-assets
LINE="*/10 * * * * /usr/bin/python3 $ASSETS/scripts/continuity_guard.py --once >> $STATE_DIR/continuity_guard.cron.log 2>&1 $TAG"
OLD_LINES=(
  "*/3 * * * * /usr/bin/python3 $ASSETS/scripts/continuity_guard.py --once >> $STATE_DIR/continuity_guard.cron.log 2>&1 $TAG"
  "*/3 * * * * /usr/bin/python3 $ASSETS/scripts/continuity_guard.py --once $TAG"
)

if [[ "$MODE" != "--apply" || -z "$BACKUP" ]]; then
  echo "Usage: $0 --apply <backup-path>" >&2
  exit 64
fi

mkdir -p "$(dirname "$BACKUP")"
mkdir -p "$STATE_DIR"
WORK=$(mktemp)
REPLACEMENT=$(mktemp)
trap 'rm -f "$WORK" "$REPLACEMENT"' EXIT
crontab -l 2>/dev/null > "$WORK" || true
cp "$WORK" "$BACKUP"

matches=$(grep -Fxc "$LINE" "$WORK" || true)
tagged=$(grep -Fc "$TAG" "$WORK" || true)
if [[ "$matches" -eq 1 && "$tagged" -eq 1 ]]; then
  echo "continuity cron already installed"
  exit 0
fi
if [[ "$tagged" -eq 1 ]]; then
  for old_line in "${OLD_LINES[@]}"; do
    if grep -Fqx "$old_line" "$WORK"; then
      grep -Fvx "$old_line" "$WORK" > "$REPLACEMENT"
      printf '%s\n' "$LINE" >> "$REPLACEMENT"
      mv "$REPLACEMENT" "$WORK"
      crontab "$WORK"
      echo "updated continuity cron"
      exit 0
    fi
  done
fi
if [[ "$tagged" -ne 0 ]]; then
  echo "refusing to replace an unexpected continuity-guard cron entry" >&2
  exit 1
fi

printf '%s\n' "$LINE" >> "$WORK"
crontab "$WORK"
echo "installed continuity cron"
