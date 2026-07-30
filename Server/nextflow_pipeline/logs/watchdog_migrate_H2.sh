#!/usr/bin/env bash
# Phase 2 看门狗 —— 常驻 tmux，监控 migrate_H2 的 rsync。
# 每 10 分钟检查一次: 目标盘用量是否还在涨(STALLED 检测) + 是否出现错误 + 是否完成。

LOG="/home/gao/Utilities/Server/nextflow_pipeline/logs/migrate_H2_0729.log"
WLOG="/home/gao/Utilities/Server/nextflow_pipeline/logs/watchdog_migrate_H2_0729.log"
DST="/srv/external_data/gao_projects_offload/projects_2026H2"

prev=0
stall=0
while true; do
  ts=$(date '+%F %T')
  if grep -q "MIGRATE_RSYNC_DONE" "$LOG" 2>/dev/null; then
    echo "$ts  DONE — rsync 正常结束" | tee -a "$WLOG"; break
  fi
  if grep -qE "MIGRATE_RSYNC_FAILED|No space left|rsync error" "$LOG" 2>/dev/null; then
    echo "$ts  FAILED — 见 $LOG" | tee -a "$WLOG"
    grep -iE "rsync error|No space left|rsync: " "$LOG" | tail -5 | tee -a "$WLOG"; break
  fi
  if ! tmux has-session -t migrate_H2 2>/dev/null; then
    echo "$ts  ABORTED — migrate_H2 tmux 已消失但日志无完成标记" | tee -a "$WLOG"; break
  fi

  cur=$(du -sb "$DST" 2>/dev/null | cut -f1); cur=${cur:-0}
  delta=$(( (cur - prev) / 1048576 ))
  if [ "$delta" -lt 100 ]; then
    stall=$((stall+1))
    echo "$ts  STALLED?($stall) 已传 $((cur/1073741824)) GiB，本轮仅 +${delta} MiB" | tee -a "$WLOG"
    [ "$stall" -ge 3 ] && { echo "$ts  STALLED 30min — 需人工检查" | tee -a "$WLOG"; }
  else
    stall=0
    echo "$ts  OK  已传 $((cur/1073741824)) GiB (+${delta} MiB/10min)" | tee -a "$WLOG"
  fi
  prev=$cur
  sleep 600
done
