#!/usr/bin/env bash
# 回收「已 offload 到别的盘、原位留软链接」的 Nextflow work 目录。
#
# 主脚本 reclaim_nextflow_work_dirs.sh 处理不了这种形态，因为:
#   - work 是 symlink 不是 dir  -> `find -type d -name work` 匹配不到
#   - marker (.nextflow.log/.nextflow/) 留在原树, 不在 offload 目标处 -> 闸门2 过不了
# 这里的校验口径: 在【软链接所在的原树父目录】找 marker, 通过才删【软链接指向的目标】。
#
# 用法: ./reclaim_offloaded_work_dirs.sh <ROOT> [--execute]

set -euo pipefail

ROOT="${1:-}"
EXECUTE=0
MANIFEST="${HOME}/Utilities/Server/nextflow_pipeline/reclaimed_work_dirs_manifest.log"

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) EXECUTE=1; shift ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$ROOT" && -d "$ROOT" ]] || { echo "用法: $0 <ROOT_DIR> [--execute]" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd)"

# --- 闸门 1: 有 nextflow 在跑就别动（与主脚本同一套窄匹配，避免自匹配）---
RUNNING="$(ps -eo pid,etime,cmd --no-headers \
  | grep -vE "^[[:space:]]*($$|$PPID)[[:space:]]" \
  | grep -E '(^|[[:space:]/])nextflow([[:space:]]|$)|nextflow\.cli\.Launcher|nextflow-[0-9.]+-one\.jar' \
  || true)"
if [[ -n "$RUNNING" ]]; then
  echo "拒绝执行: 检测到正在运行的 nextflow 进程。" >&2
  echo "$RUNNING" >&2
  exit 1
fi

echo "ROOT   : $ROOT"
echo "MODE   : $([[ $EXECUTE -eq 1 ]] && echo 'EXECUTE (真删)' || echo 'DRY-RUN (只报告)')"
echo

TOTAL=0
declare -a LINKS=() TARGETS=()

# 只认名字像 work 的软链接: work / work_* / *_work
while IFS= read -r link; do
  tgt="$(readlink -f "$link" || true)"
  [[ -n "$tgt" && -d "$tgt" ]] || { printf 'SKIP  %s (目标不存在或非目录)\n' "$link"; continue; }

  # --- 闸门 2: marker 必须在原树的父目录里 ---
  parent="$(dirname "$link")"
  if [[ ! -e "$parent/.nextflow.log" && ! -d "$parent/.nextflow" ]] \
     && ! compgen -G "$parent/.nextflow.log.*" >/dev/null; then
    printf 'SKIP  %-60s (原树父目录无 .nextflow marker)\n' "$link"
    continue
  fi

  # --- 闸门 3: 目标必须真的在别的文件系统上, 且不在 ROOT 之内(防自删) ---
  case "$tgt" in
    "$ROOT"/*) printf 'SKIP  %s (目标在 ROOT 内, 不属于 offload 形态)\n' "$link"; continue ;;
  esac

  bytes="$(du -sb "$tgt" 2>/dev/null | cut -f1 || echo 0)"
  printf 'TARGET %9.1f GiB  %s\n           -> %s\n' \
    "$(echo "scale=4; $bytes/1073741824" | bc)" "$link" "$tgt"
  LINKS+=("$link"); TARGETS+=("$tgt")
  TOTAL=$((TOTAL + bytes))
done < <(find "$ROOT" -xdev -type l \( -name 'work' -o -name 'work_*' -o -name '*_work' \) 2>/dev/null | sort)

echo
printf '合计可回收: %.2f TiB  (%d 个 offload work 目录)\n' \
  "$(echo "scale=6; $TOTAL/1099511627776" | bc)" "${#TARGETS[@]}"

[[ ${#TARGETS[@]} -eq 0 ]] && { echo "无可回收目标，退出。"; exit 0; }

if [[ $EXECUTE -eq 0 ]]; then
  echo; echo "DRY-RUN 结束。确认无误后加 --execute 真删。"
  exit 0
fi

{
  echo "===== $(date '+%Y-%m-%d %H:%M:%S')  OFFLOAD-WORK  ROOT=$ROOT ====="
  df -h "${TARGETS[0]}" | tail -1 | sed 's/^/df_before(target_fs): /'
  for i in "${!TARGETS[@]}"; do
    echo -e "$(du -sb "${TARGETS[$i]}" 2>/dev/null | cut -f1)\t${TARGETS[$i]}\t(symlink: ${LINKS[$i]})"
  done
  printf 'total_bytes\t%d\n' "$TOTAL"
} >> "$MANIFEST"

echo "manifest 已写入: $MANIFEST"
echo "开始删除..."
for i in "${!TARGETS[@]}"; do
  echo "  rm -rf ${TARGETS[$i]}"
  rm -rf "${TARGETS[$i]}"
  echo "  rm     ${LINKS[$i]}   (清掉断掉的软链接)"
  rm -f "${LINKS[$i]}"
done

echo
echo "完成。目标盘 df 现在:"
df -h /srv/external_data | tail -1
df -h /srv/external_data | tail -1 | sed 's/^/df_after(target_fs): /' >> "$MANIFEST"
