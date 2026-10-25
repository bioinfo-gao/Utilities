#!/usr/bin/env bash
# Install exactly one auditable 30-minute active-project autostart cron job per agent.
# Usage: $0 --apply [codex|claude_code]   (default codex; each agent has its own line)
set -euo pipefail

ASSETS=/home/gao/Utilities/AI_and_Agent/Agent_Assets
STATE=/home/gao/.local/state/agent-assets
AGENT=${2:-codex}
case "$AGENT" in
  codex)
    TAG='# Agent Assets Codex active-project autostart'
    LINE="*/30 * * * * /usr/bin/python3 $ASSETS/scripts/codex_active_project_autostart.py --once >> $STATE/codex_active_project_autostart.cron.log 2>&1 $TAG"
    PREVIOUS_LINE="*/5 * * * * /usr/bin/python3 $ASSETS/scripts/codex_active_project_autostart.py --once >> $STATE/codex_active_project_autostart.cron.log 2>&1 $TAG"
    ;;
  claude_code)
    TAG='# Agent Assets Claude Code active-project autostart'
    LINE="*/30 * * * * /usr/bin/python3 $ASSETS/scripts/codex_active_project_autostart.py --agent claude_code --once >> $STATE/claude_code_active_project_autostart.cron.log 2>&1 $TAG"
    PREVIOUS_LINE=""
    ;;
  *) echo "unknown agent: $AGENT" >&2; exit 2 ;;
esac

if [[ ${1:-} != --apply || $# -gt 2 ]]; then
  echo "Usage: $0 --apply [codex|claude_code]" >&2
  exit 2
fi

mkdir -p "$STATE"
CURRENT=$(mktemp)
UPDATED=$(mktemp)
trap 'rm -f "$CURRENT" "$UPDATED"' EXIT
crontab -l > "$CURRENT" 2>/dev/null || true
if grep -Fqx "$LINE" "$CURRENT"; then
  echo "$AGENT active-project autostart cron already installed"
  exit 0
fi
if grep -Fq "$TAG" "$CURRENT"; then
  [[ -n "$PREVIOUS_LINE" ]] && grep -Fqx "$PREVIOUS_LINE" "$CURRENT" || {
    echo "refusing to replace an unexpected $AGENT active-project autostart cron entry" >&2
    exit 1
  }
  grep -Fv "$TAG" "$CURRENT" > "$UPDATED"
  printf '%s\n' "$LINE" >> "$UPDATED"
  crontab "$UPDATED"
  echo "updated $AGENT active-project autostart cron to 30-minute polling"
  exit 0
fi
{
  cat "$CURRENT"
  printf '%s\n' "$LINE"
} > "$UPDATED"
crontab "$UPDATED"
echo "installed $AGENT active-project autostart cron"
