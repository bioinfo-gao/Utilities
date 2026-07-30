#!/usr/bin/env bash
# 删除 projects_2026H2 迁移后的旧源目录，2026-07-30
#
# 前置条件（执行前逐条已核实）:
#   1. /home/gao/projects_2026H2 的 bind mount 已指向 /dev/sdc1[/gao_projects/projects_2026H2]
#   2. /mnt/ex_8T_SSD/projects_2026H2 本身不是挂载点
#   3. fstab 第17行已改为 /srv/external_data/gao_projects/projects_2026H2
#   4. rsync 反向 dry-run: 只在源端存在的文件 0 个、内容不同的文件 0 个
#   5. 新位置 git fsck 通过、HEAD 7b79140、working tree 干净
#
# 脚本自身再复查 1~3，任何一条不成立就拒绝执行 —— 不靠"我记得已经确认过了"。

set -euo pipefail

SRC="/mnt/ex_8T_SSD/projects_2026H2"
DST="/srv/external_data/gao_projects/projects_2026H2"
LOG="/home/gao/Utilities/Server/nextflow_pipeline/logs/drop_old_source_H2_0730.log"

{
  echo "=== 开始 $(date '+%F %T') ==="

  # 闸门 1: bind mount 必须已指向 sdc1
  cur="$(findmnt -n -o SOURCE -T /home/gao/projects_2026H2)"
  echo "当前 /home/gao/projects_2026H2 <- $cur"
  case "$cur" in
    /dev/sdc1*) echo "  OK: 已指向 sdc1" ;;
    *) echo "  拒绝执行: bind mount 尚未指向 sdc1"; exit 1 ;;
  esac

  # 闸门 2: 源不能是挂载点
  if mountpoint -q "$SRC"; then echo "  拒绝执行: $SRC 仍是挂载点"; exit 1; fi
  echo "  OK: $SRC 不是挂载点"

  # 闸门 3: 目标必须存在且非空
  if [ ! -d "$DST" ] || [ -z "$(ls -A "$DST" 2>/dev/null)" ]; then
    echo "  拒绝执行: 目标 $DST 不存在或为空"; exit 1
  fi
  echo "  OK: 目标存在，顶层 $(ls -A "$DST" | wc -l) 个条目"

  # 闸门 4: 再跑一次 dry-run，确认没有任何文件只存在于源端
  only_src="$(rsync -aHAXn --itemize-changes "$SRC/" "$DST/" 2>/dev/null | grep -cE '^>f\+\+\+\+' || true)"
  echo "  只存在于源端的文件: $only_src"
  if [ "$only_src" != "0" ]; then echo "  拒绝执行: 源端有 $only_src 个文件未同步"; exit 1; fi

  echo
  echo "四道闸门全部通过。待删: $(du -sh "$SRC" | cut -f1)"
  df -h /mnt/ex_8T_SSD | tail -1 | sed 's/^/df_before: /'
  echo "开始删除..."
  rm -rf "$SRC"
  echo "删除完成。"
  df -h /mnt/ex_8T_SSD | tail -1 | sed 's/^/df_after:  /'
  echo "=== 结束 $(date '+%F %T') ==="
  echo "DROP_SOURCE_DONE"
} 2>&1 | tee "$LOG"
