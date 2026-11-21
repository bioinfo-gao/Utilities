#!/usr/bin/env bash
# gcs_download.sh — 从 Google Cloud Storage（如 Broad Walk-Up 交付）按正则挑选文件下载 + 校验
# 用法: gcs_download.sh <gs://bucket/prefix> <本地目标目录> <选择正则> [billing_project]
#   选择正则：Python regex，匹配相对 prefix 的路径（Broad 的 lane 是多客户混池，必须只挑自己的样本）
#   可重复执行：cp -n 跳过已完整的文件，未完成的 .gstmp 自动续传 ⇒ 中断后原命令重跑
#   前提：已由用户本人 `gcloud auth login --no-launch-browser`（脚本不处理凭证）
#   产物：<DEST>/_gcs_manifest_<TS>.tsv（选中的远端清单）、_verify_<TS>.tsv（逐文件 size+crc32c）
# 详见同目录 README.md
set -euo pipefail
SRC="${1:?gs:// source}"; SRC="${SRC%/}"; DEST="${2:?local dest dir}"; RE="${3:?selection regex}"; BILL="${4:-}"
GC=/home/gao/.conda/envs/gcloud/bin/gcloud
TS=$(date +%Y%m%d_%H%M); mkdir -p "$DEST"
BP=(); [[ -n "$BILL" ]] && BP=(--billing-project "$BILL")
# 并发：默认 8 进程 × 4 线程，可用环境变量覆盖。瓶颈是单连接 WAN 带宽、不是 CPU（实测 CPU 98% 空闲）
export CLOUDSDK_STORAGE_PROCESS_COUNT=${CLOUDSDK_STORAGE_PROCESS_COUNT:-8} CLOUDSDK_STORAGE_THREAD_COUNT=${CLOUDSDK_STORAGE_THREAD_COUNT:-4}

ACC=$("$GC" auth list --format='value(account)' --filter='status:ACTIVE' 2>/dev/null || true)
[[ -n "$ACC" ]] || { echo "未登录：请用户本人运行 $GC auth login --no-launch-browser"; exit 2; }
echo "[$(date)] account: $ACC"

# 1) 远端清单（json；不要用 csv+timeout，那次截断成了部分清单）
MAN="$DEST/_gcs_manifest_${TS}.tsv"
"$GC" storage objects list "$SRC/**" "${BP[@]}" --format=json | python3 -I -c '
import json,re,sys
pfx,rx=sys.argv[1].split("/",3)[3]+"/",re.compile(sys.argv[2])
for o in json.load(sys.stdin):
    rel=o["name"][len(pfx):]
    if rx.search(rel): print(rel,o["size"],o.get("crc32c_hash",""),sep="\t")
' "$SRC" "$RE" > "$MAN"
N=$(wc -l < "$MAN"); echo "[$(date)] selected $N objects, $(awk '{s+=$2} END{printf "%.1f GB", s/1e9}' "$MAN") -> $MAN"
[[ "$N" -gt 0 ]] || { echo "正则没选中任何文件"; exit 3; }

# 2) 下载：按子目录分组 cp -n -I，保留相对路径
cut -f1 "$MAN" | xargs -I{} dirname {} | sort -u | while read -r d; do
  mkdir -p "$DEST/$d"
  awk -F'\t' -v d="$d" -v s="$SRC" '{n=split($1,a,"/"); p=(n>1)?substr($1,1,length($1)-length(a[n])-1):"."; if(p==d) print s"/"$1}' "$MAN" \
    | "$GC" storage cp -n -I "$DEST/$d/" "${BP[@]}"
done

# 3) 落盘后独立复核 size + crc32c（4 个并行）
VER="$DEST/_verify_${TS}.tsv"; echo -e "file\tremote_size\tlocal_size\tremote_crc32c\tlocal_crc32c\tstatus" > "$VER"
export GC DEST
awk -F'\t' '{print $1"\t"$2"\t"$3}' "$MAN" | xargs -P 4 -d '\n' -I{} bash -c '
  IFS=$'"'"'\t'"'"' read -r rel size crc <<< "$1"; f="$DEST/$rel"
  ls_=$(stat -c %s "$f" 2>/dev/null || echo NA)
  lc=$("$GC" storage hash --skip-md5 --format="value(crc32c_hash)" "$f" 2>/dev/null || echo NA)
  st=OK; [[ "$ls_" == "$size" && "$lc" == "$crc" ]] || st=FAIL
  printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$rel" "$size" "$ls_" "$crc" "$lc" "$st"' _ {} >> "$VER"
NOK=$(grep -c $'\tOK$' "$VER" || true); NF=$(grep -c $'\tFAIL$' "$VER" || true)
echo "[$(date)] verify: $NOK OK / $NF FAIL (expected $N) -> $VER"
[[ "$NOK" -eq "$N" && "$NF" -eq 0 ]] && echo "ALL_DONE" || exit 1
