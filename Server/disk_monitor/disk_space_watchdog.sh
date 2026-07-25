#!/bin/bash
# General-purpose disk-space watchdog for this server.
# One check per invocation (designed to be cron'd, e.g. every 15-30 min) — NOT a long-running loop.
#
# ⚠ CORRECTED 2026-07-23 (same day, caught by user): this script originally rolled its own
# tty-broadcast + inline-Python-SMTP-via-.claude.json-Gmail-creds alerting. Both were
# reinventions of the ALREADY-ESTABLISHED /watchdog skill's infrastructure
# (`/home/gao/projects_2026H2/facilities/Server/monitoring_alerting/`:
# `nextflow_watchdog.sh` + `wd_guard.sh` + `wd_sendmail.py`), which:
#   - has its own isolated SMTP app-password (`~/.config/nextflow_watchdog/smtp.env`, chmod 600,
#     outside any git repo) — deliberately NOT the Claude Code Gmail MCP credentials, because
#     reusing those (a) risks being blocked by security policy and (b) is coupled to
#     `.claude.json`, silently breaking on any credential rotation there. See /watchdog skill §7.
#   - already sends to BOTH of the user's addresses (not just one).
#   - already has the exact same ps-based (not `who`) tty enumeration this script also uses.
# **Lesson: check `~/.claude/skills/` for an existing skill before building monitoring/alerting
# infra from scratch — don't rediscover things that are already solved and tested.**
# This script now calls the established `wd_sendmail.py` for email instead of inlining SMTP.
#
# Two independent alert channels, both usable with NO agent/Claude session running at all:
#   1. tty broadcast — reaches the user only if they're at a terminal right now.
#   2. wd_sendmail.py — reaches the user's inbox/phone even if nobody's watching a terminal
#      (e.g. overnight), via its own isolated credentials. Rate-limited per mount (see
#      EMAIL_COOLDOWN_SEC) so it doesn't spam every 15min.
# Per the lesson in facilities/Server/nextflow_pipeline/resume缓存失效与空转监控_教训_0716.md:
# writing only to a log file is a diary, not an alert — nobody reads it unless they already
# know to look. `who` misses IDE-integrated terminals (they don't register utmp); enumerate
# active ttys via `ps` instead.
#
# NOTE on scope: the agent-side `PushNotification` tool (desktop/phone push) is a THIRD,
# separate channel — but it can only be called by an active Claude Code session, not by a
# bare cron'd shell script like this one. It's the right tool when *I* (the agent) am live
# and want to proactively surface something; it is not a substitute for this script's own
# channels when no session is running at all.
#
# Background: written 2026-07-23 after ex_8T_SSD hit 0 bytes available overnight and silently
# crashed project 19's nextflow run for ~9.5h before anyone noticed. See
# facilities/Server/disk_migration/ for the emergency cleanup that followed.

WD_SENDMAIL="/home/gao/projects_2026H2/facilities/Server/monitoring_alerting/wd_sendmail.py"

# --- config: mount point -> min free GiB before alerting ---
declare -A THRESHOLDS=(
  ["/mnt/ex_8T_SSD"]=200
  ["/Work_bio"]=100
  ["/"]=50
)

LOG="$(dirname "$0")/disk_watchdog.log"
EMAIL_COOLDOWN_SEC=7200   # don't re-email about the same mount more than once per 2h
STATE_DIR="$(dirname "$0")/.email_cooldown"
mkdir -p "$STATE_DIR"
ts() { date '+%Y-%m-%d %H:%M:%S'; }

alert_ttys() {
  local msg="$1"
  for t in $(ps -eo tty -u "$USER" 2>/dev/null | grep -oE 'pts/[0-9]+' | sort -u); do
    [ -w "/dev/$t" ] || continue
    printf '\n⚠️  [disk_watchdog %s] %s\n' "$(ts)" "$msg" > "/dev/$t" 2>/dev/null
  done
}

alert_email() {
  local mount_key="$1" msg="$2"
  local marker="$STATE_DIR/${mount_key//\//_}"
  local now epoch_last
  now=$(date +%s)
  if [ -f "$marker" ]; then
    epoch_last=$(cat "$marker")
    if [ $((now - epoch_last)) -lt "$EMAIL_COOLDOWN_SEC" ]; then
      return 0   # still in cooldown, skip email (tty alert above already fired)
    fi
  fi
  if echo "$msg" | "$WD_SENDMAIL" "🚨 disk_watchdog ALERT — $mount_key low disk space" - >>"$LOG" 2>&1; then
    echo "$now" > "$marker"
    echo "[$(ts)] email sent for $mount_key" >> "$LOG"
  else
    echo "[$(ts)] email FAILED for $mount_key (see log above)" >> "$LOG"
  fi
}

any_alert=0
for mount in "${!THRESHOLDS[@]}"; do
  [ -d "$mount" ] || continue
  min_gb="${THRESHOLDS[$mount]}"
  # avail (user-visible, i.e. respects ext4's reserved-blocks-for-root — this is the
  # number that actually matters: it's what a normal write from gao's own processes can use)
  avail_kb=$(df --output=avail "$mount" 2>/dev/null | tail -1 | tr -d ' ')
  [ -z "$avail_kb" ] && continue
  avail_gb=$(awk -v k="$avail_kb" 'BEGIN{printf "%.1f", k/1024/1024}')

  if awk -v a="$avail_gb" -v m="$min_gb" 'BEGIN{exit !(a<m)}'; then
    msg="$mount only ${avail_gb}G available (threshold ${min_gb}G)"
    echo "[$(ts)] ALERT: $msg" >> "$LOG"
    alert_ttys "$msg"
    alert_email "$mount" "$msg"
    any_alert=1
  else
    echo "[$(ts)] ok: $mount ${avail_gb}G available (threshold ${min_gb}G)" >> "$LOG"
  fi
done

exit $any_alert
