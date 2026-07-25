#!/usr/bin/env bash
# ============================================================================
# wd_guard.sh —— 看门狗的看门狗（由 crontab 每 15 分钟调用，不依赖任何 agent/登录会话）。
#
# 解决的问题（2026-07-16）：看门狗跑在 tmux 里，若被误杀 / 机器重启 / tmux server 挂掉，
#   它就【静默消失】，而被监控的 sarek 还在跑 —— 于是又回到"无人监控"状态，
#   且没有任何人会发现。这与"Phase-1 监控 3 分钟就退出"是同一类洞：
#   **监控本身也需要被监控。**
#
# 逻辑：若「被监控会话存活」但「看门狗会话不在」→ 拉起看门狗 + 发信告知（自主发信，不经 agent）。
#      若被监控会话本就不在（流程已结束）→ 什么也不做，安静退出。
#
# ⚠ 频率标定（user directive 2026-07-16）：**目标是把「发现延迟」压到有界，不是追求秒级复活。**
#   30 分钟一次足矣 —— 最坏情况丢 30 min 监控，而事故当晚丢的是 11 h。
#   更密（如每 13 min）属过度设计：守护本身也在耗资源，而收益只是把 30 min 缩到 13 min，
#   与「10+ 小时 → 30 分钟」这个数量级改进相比可以忽略。
#
# crontab 用法（每 30 分钟，用 9/39 而非 0/30 以避开整点拥挤）：
#   9,39 * * * * /home/gao/projects_2026H2/facilities/Server/wd_guard.sh pan_wgs pan_watch \
#                 'bash /home/gao/projects_2026H2/16_Wenliang_Pan_wgs/scripts/10_watchdog.sh' >/dev/null 2>&1
#
# 参数: $1=被监控会话名  $2=看门狗会话名  $3=拉起看门狗的命令
# ============================================================================
set -uo pipefail
export PATH=/usr/local/bin:/usr/bin:/bin:$PATH

JOB_SESS="${1:?用法: wd_guard.sh <job_session> <watch_session> <watch_cmd>}"
WATCH_SESS="${2:?}"
WATCH_CMD="${3:?}"
LOG=/home/gao/.config/nextflow_watchdog/guard.log
MAILER=/home/gao/projects_2026H2/facilities/Server/wd_sendmail.py

log() { echo "[$(date '+%F %T')] $*" >> "$LOG"; }

# 被监控的作业不在 → 流程已结束，无需看门狗
tmux has-session -t "$JOB_SESS" 2>/dev/null || { log "job '$JOB_SESS' 不在，guard 静默退出"; exit 0; }

# 看门狗健在 → 正常
if tmux has-session -t "$WATCH_SESS" 2>/dev/null; then
    log "OK: $JOB_SESS UP, $WATCH_SESS UP"
    exit 0
fi

# 作业在跑但看门狗没了 → 复活 + 告警
log "⚠ $JOB_SESS 在跑但 $WATCH_SESS 已消失 —— 复活看门狗"
tmux new-session -d -s "$WATCH_SESS" "$WATCH_CMD" 2>>"$LOG"
sleep 2
if tmux has-session -t "$WATCH_SESS" 2>/dev/null; then
    log "✅ 已复活 $WATCH_SESS"
    RESULT="已自动复活成功。"
else
    log "❌ 复活失败!"
    RESULT="⚠ 自动复活【失败】—— 需要人工介入！"
fi

[ -x "$MAILER" ] && printf '看门狗守护告警\n\n主机: %s\n时间: %s\n\n被监控作业 "%s" 仍在运行，但看门狗会话 "%s" 已消失\n（可能原因：被误杀 / tmux server 重启 / 机器重启）。\n\n处置: %s\n\n这意味着在此之前有一段时间处于【无监控】状态。\n请检查 %s 与作业日志。\n\n--\n由 wd_guard.sh 经 crontab 自主发出（未经 agent）。\n' \
  "$(hostname)" "$(date '+%F %T')" "$JOB_SESS" "$WATCH_SESS" "$RESULT" "$LOG" \
  | "$MAILER" "🚨[watchdog-guard] 看门狗曾消失 — $(hostname)" - >>"$LOG" 2>&1
exit 0
