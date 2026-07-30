#!/usr/bin/env bash
# projects_2026H2 物理迁移 sda1 -> sdc1(/srv/external_data)，2026-07-29
#
# 排除 14_geneedit_lats12_wgs/work_B (1013 GiB) —— 待用户单独确认删或搬。
# 暂存到 gao 可写的 gao_projects_offload/ 下；最终由 root `mv` 到 gao_projects/（同盘，瞬间）。
#
# 只写新目录，不删源。中途打断可直接重跑本脚本续传（rsync 增量）。

set -o pipefail

SRC="/mnt/ex_8T_SSD/projects_2026H2/"
DST="/srv/external_data/gao_projects_offload/projects_2026H2/"
LOG="/home/gao/Utilities/Server/nextflow_pipeline/logs/migrate_H2_0729.log"

mkdir -p "$DST"

{
  echo "=== 开始 $(date '+%F %T') ==="
  echo "SRC: $SRC"
  echo "DST: $DST"
  df -h /mnt/ex_8T_SSD /srv/external_data
  echo

  rsync -aHAX --numeric-ids --info=progress2,stats2 \
        --exclude='14_geneedit_lats12_wgs/work_B' \
        "$SRC" "$DST"
  rc=$?
  echo
  echo "rsync exit code: $rc"

  echo
  echo "=== 结束 $(date '+%F %T') ==="
  df -h /mnt/ex_8T_SSD /srv/external_data
  [ $rc -eq 0 ] && echo "MIGRATE_RSYNC_DONE" || echo "MIGRATE_RSYNC_FAILED rc=$rc"
} 2>&1 | tee "$LOG"
