#!/usr/bin/env bash
# 一次性 runner —— projects_2026H2 的 work/ 回收，2026-07-29
#
# 批次1: sda1 上 4 个已交付项目的 work/            约 569 GiB
#        10_Yue_Liu / 11_Qiuchen_Li / 12_Zhen_Yan / 5_mouse-rRNA
# 批次2: /srv 上 7 个已 offload 的 work/           约 3.20 TiB
#        13_Ellen / 16_Wenliang / 17_Daniel(work_mag + work_taxprofiler)
#        / 1_opossum / 6_jinlong / 9_Lijian
#
# 不在本次范围: 14_geneedit_lats12_wgs/work_B (1013 GiB) —— 待用户单独确认
#
# 两个脚本都自带: nextflow 运行检测 / .nextflow marker 校验 / manifest append-only 记录。
# 只删 work 目录自身；.nextflow.log、.nextflow/、output*、custom_research_report* 一律不动。

set -o pipefail

RECLAIM_DIR="/home/gao/Utilities/Server/nextflow_pipeline"
# 本次实际执行时 offload 脚本还在临时目录；跑完后已归档到 RECLAIM_DIR，这里指向归档位置。
OFFLOAD_SCRIPT="${RECLAIM_DIR}/reclaim_offloaded_work_dirs.sh"
ROOT="/mnt/ex_8T_SSD/projects_2026H2"
LOG="${RECLAIM_DIR}/logs/reclaim_H2_0729.log"

{
  echo "########## 批次1: sda1 上 4 个已交付项目的 work (569G) ##########"
  "${RECLAIM_DIR}/reclaim_nextflow_work_dirs.sh" "$ROOT" --execute

  echo
  echo "########## 批次2: /srv 上 7 个 offload work (3.20T) ##########"
  "$OFFLOAD_SCRIPT" "$ROOT" --execute

  echo
  echo "=== 收工 df ==="
  df -h /mnt/ex_8T_SSD /srv/external_data
  echo "ALL_RECLAIM_DONE"
} 2>&1 | tee "$LOG"
