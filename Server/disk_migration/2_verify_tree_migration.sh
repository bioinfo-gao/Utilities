#!/usr/bin/env bash
# 2/4 — 迁移校验。必须 ALL_VERIFY_PASS 才允许进入第 3、4 步。
#
# 用法: ./2_verify_tree_migration.sh <SRC> <DST>
#
# 六项检查，每一项都有它存在的理由:
#   1 条目数【分类型】数 —— 只数总数会让"目录变成了文件"这类错误蒙混过关
#   2 字节总量
#   3 逐顶层目录字节数 —— 总量对得上不代表每个子树都对；0729 项目 H1 就是靠逐项对账
#     抓到 77 GiB 漏删的（见 nextflow_pipeline/磁盘回收_三方案实证对比 §5.2）
#   4 rsync 反向 dry-run —— 唯一能发现"只存在于源端"的文件的检查
#   5 git 完整性（若是 git 仓库）
#   6 随机大文件 md5 抽样 —— 前五项都只比元数据，这项才真读内容

set -o pipefail
SRC="${1:-}"; DST="${2:-}"
[[ -n "$SRC" && -n "$DST" && -d "$SRC" && -d "$DST" ]] || {
  echo "用法: $0 <SRC> <DST>" >&2; exit 2; }
SRC="$(cd "$SRC" && pwd)"; DST="$(cd "$DST" && pwd)"
fail=0

hdr(){ printf '\n=== %s ===\n' "$1"; }
chk(){ if [ "$2" = "$3" ]; then printf 'PASS  %-34s %s\n' "$1" "$2"
       else printf 'FAIL  %-34s src=%s  dst=%s\n' "$1" "$2" "$3"; fail=1; fi }

hdr "1. 条目数对账（文件 / 目录 / 软链接 分开数）"
for t in f d l; do
  case $t in f) n="普通文件";; d) n="目录";; l) n="软链接";; esac
  chk "$n" "$(find "$SRC" -xdev -type $t 2>/dev/null | wc -l)" \
           "$(find "$DST" -xdev -type $t 2>/dev/null | wc -l)"
done

hdr "2. 字节总量对账"
chk "总字节数" "$(du -sb "$SRC" 2>/dev/null | cut -f1)" "$(du -sb "$DST" 2>/dev/null | cut -f1)"

hdr "3. 逐顶层条目对账"
while IFS= read -r b; do
  s="$(du -sb "$SRC/$b" 2>/dev/null | cut -f1)"
  d="$(du -sb "$DST/$b" 2>/dev/null | cut -f1)"
  if [ "$s" = "$d" ]; then printf 'PASS  %-44s %s B\n' "$b" "$s"
  else printf 'FAIL  %-44s src=%s dst=%s\n' "$b" "$s" "$d"; fail=1; fi
done < <(ls -A "$SRC")

hdr "4. rsync 反向 dry-run"
# 已知良性差异：源仓库若仍是"活的"（IDE 的 git 扩展周期性 autofetch、任一侧跑过 git status），
# 这几个 .git 元数据文件的 mtime 会持续变动，校验永远不会自然变干净。
#   .git/index      stat 缓存（记录每个文件的 inode/device）—— 跨文件系统复制后 inode 必然变，
#                   任一侧跑一次 git status 就各自重写。不含唯一数据。
#   .git/FETCH_HEAD autofetch 刷 mtime，内容 md5 实测一致。
# 白名单只放行这几条；真正的数据差异（>f++++ 只在源端 / s 体积不同）仍必须 FAIL。
BENIGN='^[.>]f\.\.t\.+ \.git/(index|FETCH_HEAD)$|^\.d\.\.t\.+ \.git/(objects/)?$'
allout="$(rsync -aHAXn --itemize-changes "$SRC/" "$DST/" 2>&1 | grep -vE '^$|^sending|^sent |^total ')"
diffout="$(echo "$allout" | grep -vE "$BENIGN" | grep -v '^$')"
benign="$(echo "$allout" | grep -E "$BENIGN")"
[ -n "$benign" ] && { echo "已知良性（git 元数据抖动，不计入失败）:"; echo "$benign" | sed 's/^/      /'; }
if [ -z "$diffout" ]; then echo "PASS  无实质差异"
else echo "FAIL  存在实质差异:"; echo "$diffout" | head -20; fail=1; fi

hdr "5. git 仓库完整性（在目标处）"
if git -C "$DST" rev-parse --git-dir >/dev/null 2>&1; then
  echo "分支: $(git -C "$DST" branch --show-current)   HEAD: $(git -C "$DST" rev-parse --short HEAD)"
  git -C "$DST" fsck --no-progress --no-dangling >/dev/null 2>&1 \
    && echo "PASS  git fsck 通过" || { echo "FAIL  git fsck 报错"; fail=1; }
  if diff <(git -C "$SRC" show-ref 2>/dev/null | sort) \
          <(git -C "$DST" show-ref 2>/dev/null | sort) >/dev/null; then
    echo "PASS  refs 与源完全一致"
  else echo "FAIL  refs 与源不一致"; fail=1; fi
  st="$(git -C "$DST" status --porcelain | head -5)"
  [ -z "$st" ] && echo "PASS  working tree 干净" || { echo "注意  working tree 有改动:"; echo "$st"; }
else echo "跳过  目标处不是 git 仓库"; fi

hdr "6. 抽样内容校验（随机 20 个 >10MB 文件比 md5）"
n=0; bad=0
while IFS= read -r f; do
  r="${f#$SRC/}"
  a="$(md5sum "$f" 2>/dev/null | cut -d' ' -f1)"
  b="$(md5sum "$DST/$r" 2>/dev/null | cut -d' ' -f1)"
  n=$((n+1))
  [ -n "$a" ] && [ "$a" = "$b" ] || { echo "FAIL  md5 不符: $r"; bad=1; fail=1; }
done < <(find "$SRC" -xdev -type f -size +10M 2>/dev/null | shuf -n 20)
[ $bad -eq 0 ] && echo "PASS  $n 个文件 md5 全部一致"

hdr "结论"
[ $fail -eq 0 ] && echo "ALL_VERIFY_PASS —— 可以进入第 3 步（切换挂载）" \
                || echo "VERIFY_FAILED —— 不要删源，先查清每一条差异的根因"
exit $fail
