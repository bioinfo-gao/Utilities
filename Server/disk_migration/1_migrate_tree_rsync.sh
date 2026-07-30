#!/usr/bin/env bash
# 1/4 — 把一棵目录树复制到另一块盘（只写，不删源）。
#
# 用法:
#   ./1_migrate_tree_rsync.sh <SRC> <DST> [--exclude PATTERN]...
#
# 例:
#   ./1_migrate_tree_rsync.sh /mnt/ex_8T_SSD/projects_2026H2 \
#                             /srv/external_data/gao_projects_offload/projects_2026H2 \
#                             --exclude '14_geneedit_lats12_wgs/work_B'
#
# 设计要点（都有实证理由，见 tree_migration_playbook.md）:
#   - -aHAX --numeric-ids: 保硬链接/ACL/xattr/原始 uid-gid。-H 必须有，否则硬链接会被
#     展开成多份独立文件，体积暴涨且破坏原有语义。
#   - 绝不加 --delete: 本步只写目标，源在校验通过前一个字节都不能动。
#   - 中途打断可直接重跑，rsync 增量续传，不会留下半损坏状态。
#   - 目标盘剩余空间在开跑前先算，不够就拒绝执行（曾经因为这个没查而中途 No space left）。

set -o pipefail

SRC="${1:-}"; DST="${2:-}"
shift 2 2>/dev/null || true
EXCLUDES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --exclude) EXCLUDES+=(--exclude "$2"); shift 2 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$SRC" || -z "$DST" || ! -d "$SRC" ]]; then
  echo "用法: $0 <SRC> <DST> [--exclude PATTERN]..." >&2; exit 2
fi
SRC="$(cd "$SRC" && pwd)"

LOGDIR="$(dirname "$(readlink -f "$0")")/logs"
mkdir -p "$LOGDIR" "$DST"
LOG="$LOGDIR/migrate_$(basename "$SRC")_$(date +%m%d_%H%M).log"

# --- 闸门: 目标盘空间够不够 ---
need=$(du -sb "${EXCLUDES[@]/--exclude/--exclude=}" "$SRC" 2>/dev/null | cut -f1)
avail=$(df -B1 --output=avail "$DST" | tail -1 | tr -d ' ')
printf '待传: %.1f GiB   目标盘可用: %.1f GiB\n' \
  "$(echo "scale=4;$need/1073741824"|bc)" "$(echo "scale=4;$avail/1073741824"|bc)"
if [ "$avail" -lt "$need" ]; then
  echo "拒绝执行: 目标盘空间不足。" >&2; exit 1
fi

echo "长任务 —— 请在 tmux 里跑本脚本。日志: $LOG"
{
  echo "=== 开始 $(date '+%F %T') ==="
  echo "SRC: $SRC"; echo "DST: $DST"; echo "EXCLUDES: ${EXCLUDES[*]:-无}"
  df -h "$SRC" "$DST"
  echo
  rsync -aHAX --numeric-ids --info=progress2,stats2 "${EXCLUDES[@]}" "$SRC/" "$DST/"
  rc=$?
  echo; echo "rsync exit code: $rc"
  echo "=== 结束 $(date '+%F %T') ==="
  df -h "$SRC" "$DST"
  [ $rc -eq 0 ] && echo "MIGRATE_RSYNC_DONE" || echo "MIGRATE_RSYNC_FAILED rc=$rc"
} 2>&1 | tee "$LOG"
