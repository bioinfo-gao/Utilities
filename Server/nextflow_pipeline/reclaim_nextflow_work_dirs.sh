#!/usr/bin/env bash
# reclaim_nextflow_work_dirs.sh
#
# 回收 Nextflow `work/` scratch cache 占用的磁盘空间。
# 实证背景见同目录 磁盘回收_三方案实证对比_projects_2026H1_0729.md
#   —— projects_2026H1 实测 5.5 TiB 里 4.8 TiB (87%) 全在 work/ 下，
#      而整体 gzip 只能省 ~0.4 TiB (~8%)，因为 87% 的内容是 BAM/fastq.gz 已压缩格式。
#   ⇒ 磁盘吃紧时的第一动作永远是「删 work/」，不是「压缩」。
#
# 安全设计：
#   1. 默认 DRY-RUN，必须显式 --execute 才真删。
#   2. marker 校验，两条判据任一通过即可（2026-08-29 放宽，原先只看同级）：
#        (a) work/ 的父目录【及其上两层】存在 .nextflow.log 或 .nextflow/
#        (b) work/ 内部 >= 10 个 .command.sh（Nextflow 任务目录的固有结构）
#      —— 避免误删任何恰好叫 work 的普通文件夹；两条都不满足的一律 SKIP 并打印出来。
#      放宽原因：实测「从 scripts/ 启动、work/ 落在项目根」的布局会让 marker 与 work 不同级，
#      0829 因此漏判 778 GiB（proj27/28/30），只能人工复核后补删。
#   3. 删除前把清单 + 每个目录的字节数写进 manifest 日志（append-only），
#      事后可查「当初删了什么、各多大」。
#   4. 只删 work/ 自身，绝不碰 .nextflow.log / .nextflow/ / output* / results*
#      —— provenance 和交付物必须留下。
#   5. 若检测到正在运行的 nextflow 进程，直接拒绝执行。
#
# 用法:
#   ./reclaim_nextflow_work_dirs.sh <ROOT>                 # dry-run，只报告
#   ./reclaim_nextflow_work_dirs.sh <ROOT> --execute       # 真删
#   ./reclaim_nextflow_work_dirs.sh <ROOT> --depth 4       # 限制搜索深度 (默认不限深度)
#
# 代价提醒：删掉 work/ 后该 run 的 `-resume` 缓存失效，重跑等于从头跑。
#           只对「已交付/已结项」的项目执行。

set -euo pipefail

ROOT="${1:-}"
EXECUTE=0
# 默认不限深度。曾用 DEPTH=4 默认值，结果漏掉了深度 5 的
#   2026_Item5_T.majus/cleaning_and_make_ref/working_split/WhS4_4/work  (78 GiB)
# —— 项目内常有"按样本分片再各跑一条 pipeline"的布局，work/ 会埋得很深。
# 用 -prune 保证匹配到 work/ 后不再往里递归（避免嵌套 work 重复计数）。
#
# 0729 第二个同类漏检（维度是【命名】不是深度）：硬匹配 -name work 漏掉了
#   projects_2026H2/14_geneedit_lats12_wgs/work_B  (1013 GiB)
# —— 一个项目分 Study A / Study B 两臂各跑一条 pipeline 时，work 目录会带后缀
#    (work_A / work_B)，taxprofiler+mag 双路线同理 (work_mag / work_taxprofiler)。
#    这一个目录就占该 repo 可回收量的 65%，dry-run 只报 0.55 T 而非 1.55 T。
# 修法：匹配放宽到 work / work_* / *_work，仍由闸门2 的 .nextflow marker 兜底防误删。
DEPTH=""
MANIFEST="${HOME}/Utilities/Server/nextflow_pipeline/reclaimed_work_dirs_manifest.log"

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) EXECUTE=1; shift ;;
    --depth)   DEPTH="$2"; shift 2 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$ROOT" || ! -d "$ROOT" ]]; then
  echo "用法: $0 <ROOT_DIR> [--execute] [--depth N]" >&2
  exit 2
fi
ROOT="$(cd "$ROOT" && pwd)"

# --- 闸门 1: 有 nextflow 在跑就别动 -------------------------------------------
# 注意: 必须匹配真正的 nextflow 启动命令, 不能宽泛地 grep "nextflow" ——
# 本脚本自身路径就含 nextflow_pipeline, 会自匹配导致永远拒绝执行 (0729 实测踩到)。
# 同时排除本进程及父进程, 以免自己的命令行被算进去。
RUNNING="$(ps -eo pid,etime,cmd --no-headers \
  | grep -vE "^[[:space:]]*($$|$PPID)[[:space:]]" \
  | grep -E '(^|[[:space:]/])nextflow([[:space:]]|$)|nextflow\.cli\.Launcher|nextflow-[0-9.]+-one\.jar' \
  || true)"
if [[ -n "$RUNNING" ]]; then
  echo "拒绝执行: 检测到正在运行的 nextflow 进程。先确认它跑完/停掉再来。" >&2
  echo "$RUNNING" >&2
  exit 1
fi

DEPTH_ARGS=()
[[ -n "$DEPTH" ]] && DEPTH_ARGS=(-maxdepth "$DEPTH")

echo "ROOT   : $ROOT"
echo "MODE   : $([[ $EXECUTE -eq 1 ]] && echo 'EXECUTE (真删)' || echo 'DRY-RUN (只报告)')"
echo "DEPTH  : ${DEPTH:-unlimited}"
echo "df 当前:"
df -h "$ROOT" | tail -1
echo

TOTAL=0
declare -a TARGETS=()

while IFS= read -r d; do
  parent="$(dirname "$d")"
  # --- 闸门 2: marker 校验（2026-08-29 放宽 + 加第二判据）---
  # 原判据只看【同级】有无 .nextflow.log / .nextflow/。实测漏掉 778 GiB：
  #   proj27 / proj28 / proj30 是「从 scripts/ 启动、work/ 落在项目根」的布局，
  #   .nextflow.log 在 scripts/ 下、与 work/ 不同级 -> 被判 SKIP。
  #   若无人复核，这类目录会被当成「没有可回收的东西」而永远留着。
  # 现在两条判据【任一】通过即可：
  #   (a) work/ 的父目录【及其上两层】任一处存在 .nextflow.log / .nextflow/
  #   (b) work/ 内部含 >= 10 个 .command.sh —— 这是 Nextflow 任务目录的固有结构，
  #       比同级文件更难被伪造，也不受"从哪里启动"影响
  marker_ok=0
  probe="$parent"
  for _ in 1 2 3; do
    if [[ -e "$probe/.nextflow.log" || -d "$probe/.nextflow" ]]; then marker_ok=1; break; fi
    probe="$(dirname "$probe")"
    [[ "$probe" == "/" ]] && break
  done
  ncmd=0
  if [[ "$marker_ok" -eq 0 ]]; then
    ncmd="$(find "$d" -maxdepth 3 -name '.command.sh' 2>/dev/null | wc -l)"
    [[ "$ncmd" -ge 10 ]] && marker_ok=2
  fi
  if [[ "$marker_ok" -eq 0 ]]; then
    printf 'SKIP  %-60s (上溯 3 层无 .nextflow.log/.nextflow/，且内部 .command.sh=%s < 10)\n' "$d" "$ncmd"
    continue
  fi
  [[ "$marker_ok" -eq 2 ]] && printf 'NOTE  %s 依据内部 .command.sh=%s 判定为 Nextflow work（同级/上溯无 marker）\n' "$d" "$ncmd"
  bytes="$(du -sb "$d" 2>/dev/null | cut -f1 || echo 0)"
  printf 'TARGET %9.1f GiB  %s\n' "$(echo "scale=4; $bytes/1073741824" | bc)" "$d"
  TARGETS+=("$d")
  TOTAL=$((TOTAL + bytes))
done < <(find "$ROOT" -xdev "${DEPTH_ARGS[@]}" -type d \
           \( -name 'work' -o -name 'work_*' -o -name '*_work' \) -prune 2>/dev/null | sort)

echo
printf '合计可回收: %.2f TiB  (%d 个 work/ 目录)\n' "$(echo "scale=6; $TOTAL/1099511627776" | bc)" "${#TARGETS[@]}"

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "无可回收目标，退出。"
  exit 0
fi

if [[ $EXECUTE -eq 0 ]]; then
  echo
  echo "DRY-RUN 结束。确认无误后加 --execute 真删。"
  exit 0
fi

# --- 落 manifest 再删 ---------------------------------------------------------
{
  echo "===== $(date '+%Y-%m-%d %H:%M:%S')  ROOT=$ROOT ====="
  df -h "$ROOT" | tail -1 | sed 's/^/df_before: /'
  for d in "${TARGETS[@]}"; do
    echo -e "$(du -sb "$d" 2>/dev/null | cut -f1)\t$d"
  done
  printf 'total_bytes\t%d\n' "$TOTAL"
} >> "$MANIFEST"

echo "manifest 已写入: $MANIFEST"
echo "开始删除..."
for d in "${TARGETS[@]}"; do
  echo "  rm -rf $d"
  rm -rf "$d"
done

echo
echo "完成。df 现在:"
df -h "$ROOT" | tail -1
df -h "$ROOT" | tail -1 | sed 's/^/df_after: /' >> "$MANIFEST"
