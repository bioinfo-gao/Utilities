#!/usr/bin/env bash
# 4/4 — 迁移完成后删除旧源目录（真正腾出空间的一步）。
#
# 用法: ./4_drop_migrated_source.sh <SRC> <DST> <MOUNTPOINT> <EXPECTED_DEV> [--execute]
# 例:
#   ./4_drop_migrated_source.sh /mnt/ex_8T_SSD/projects_2026H2 \
#        /srv/external_data/gao_projects/projects_2026H2 \
#        /home/gao/projects_2026H2 /dev/sdc1 --execute
#
# 默认 DRY-RUN。四道闸门在【执行那一刻】重新复查，不依赖"我记得前面确认过了" ——
# 前面的校验和这一步之间可能隔了很久，中间状态可能已经变了。

set -o pipefail
SRC="${1:-}"; DST="${2:-}"; MP="${3:-}"; DEV="${4:-}"; EXECUTE=0
[[ "${5:-}" == "--execute" ]] && EXECUTE=1
[[ -n "$SRC" && -n "$DST" && -n "$MP" && -n "$DEV" ]] || {
  echo "用法: $0 <SRC> <DST> <MOUNTPOINT> <EXPECTED_DEV> [--execute]" >&2; exit 2; }

LOGDIR="$(dirname "$(readlink -f "$0")")/logs"; mkdir -p "$LOGDIR"
LOG="$LOGDIR/drop_$(basename "$SRC")_$(date +%m%d_%H%M).log"

{
  echo "=== 开始 $(date '+%F %T') ==="
  echo "MODE: $([[ $EXECUTE -eq 1 ]] && echo 'EXECUTE (真删)' || echo 'DRY-RUN')"

  # 闸门 1: 挂载点必须已经指向新盘
  cur="$(findmnt -n -o SOURCE -T "$MP" 2>/dev/null)"
  echo "闸门1  $MP <- $cur"
  case "$cur" in
    "$DEV"*) echo "       OK: 已指向 $DEV" ;;
    *) echo "       拒绝执行: 尚未指向 $DEV，切换没做或没生效"; exit 1 ;;
  esac

  # 闸门 2: 源自己不能还是挂载点（否则删的是活数据）
  if mountpoint -q "$SRC"; then echo "闸门2  拒绝执行: $SRC 仍是挂载点"; exit 1; fi
  echo "闸门2  OK: $SRC 不是挂载点"

  # 闸门 3: 目标必须存在且非空
  if [ ! -d "$DST" ] || [ -z "$(ls -A "$DST" 2>/dev/null)" ]; then
    echo "闸门3  拒绝执行: 目标 $DST 不存在或为空"; exit 1
  fi
  echo "闸门3  OK: 目标存在，顶层 $(ls -A "$DST" | wc -l) 个条目"

  # 闸门 4: 重跑 dry-run，确认没有任何文件只存在于源端
  only_src="$(rsync -aHAXn --itemize-changes "$SRC/" "$DST/" 2>/dev/null | grep -cE '^>f\+\+\+\+' || true)"
  echo "闸门4  只存在于源端的文件: $only_src"
  if [ "$only_src" != "0" ]; then
    echo "       拒绝执行: 源端有 $only_src 个文件未同步，先补同步"
    rsync -aHAXn --itemize-changes "$SRC/" "$DST/" 2>/dev/null | grep -E '^>f\+\+\+\+' | head -10
    exit 1
  fi

  echo
  echo "四道闸门全部通过。待删: $(du -sh "$SRC" | cut -f1)"
  df -h "$SRC" | tail -1 | sed 's/^/df_before: /'

  if [ $EXECUTE -eq 0 ]; then
    echo; echo "DRY-RUN 结束。确认无误后加 --execute 真删。"; exit 0
  fi

  echo "开始删除..."
  rm -rf "$SRC"
  echo "删除完成。"
  df -h "$(dirname "$SRC")" | tail -1 | sed 's/^/df_after:  /'
  echo "=== 结束 $(date '+%F %T') ==="
  echo "DROP_SOURCE_DONE"
} 2>&1 | tee "$LOG"
