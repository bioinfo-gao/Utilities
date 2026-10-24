#!/usr/bin/env bash
# Install exactly one auditable 30-minute Codex active-project autostart cron job.
set -euo pipefail

ASSETS=/home/gao/Utilities/AI_and_Agent/Agent_Assets
STATE=/home/gao/.local/state/agent-assets
TAG='# Agent Assets Codex active-project autostart'
LINE="*/30 * * * * /usr/bin/python3 $ASSETS/scripts/codex_active_project_autostart.py --once >> $STATE/codex_active_project_autostart.cron.log 2>&1 $TAG"
PREVIOUS_LINE="*/5 * * * * /usr/bin/python3 $ASSETS/scripts/codex_active_project_autostart.py --once >> $STATE/codex_active_project_autostart.cron.log 2>&1 $TAG"

if [[ ${1:-} != --apply || $# -ne 1 ]]; then
  echo "Usage: $0 --apply" >&2
  exit 2
fi

mkdir -p "$STATE"
CURRENT=$(mktemp)
UPDATED=$(mktemp)
trap 'rm -f "$CURRENT" "$UPDATED"' EXIT
crontab -l > "$CURRENT" 2>/dev/null || true
if grep -Fqx "$LINE" "$CURRENT"; then
  echo "codex active-project autostart cron already installed"
  exit 0
fi
if grep -Fq "$TAG" "$CURRENT"; then
  grep -Fqx "$PREVIOUS_LINE" "$CURRENT" || {
    echo "refusing to replace an unexpected Codex active-project autostart cron entry" >&2
    exit 1
  }
  grep -Fv "$TAG" "$CURRENT" > "$UPDATED"
  printf '%s\n' "$LINE" >> "$UPDATED"
  crontab "$UPDATED"
  echo "updated codex active-project autostart cron to 30-minute polling"
  exit 0
fi
{
  cat "$CURRENT"
  printf '%s\n' "$LINE"
} > "$UPDATED"
crontab "$UPDATED"
echo "installed codex active-project autostart cron"
