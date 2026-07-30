#!/usr/bin/env bash
# 迁移校验 —— 在删源之前跑，必须全绿才允许 rm 源目录。
# 用法: ./verify_migrate_H2.sh <SRC> <DST>

SRC="${1:-/mnt/ex_8T_SSD/projects_2026H2}"
DST="${2:-/srv/external_data/gao_projects_offload/projects_2026H2}"
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

hdr "3. 逐顶层目录对账"
for p in "$SRC"/*/ "$SRC"/.git; do
  [ -e "$p" ] || continue
  b="$(basename "$p")"
  s="$(du -sb "$SRC/$b" 2>/dev/null | cut -f1)"
  d="$(du -sb "$DST/$b" 2>/dev/null | cut -f1)"
  if [ "$s" = "$d" ]; then printf 'PASS  %-42s %s B\n' "$b" "$s"
  else printf 'FAIL  %-42s src=%s dst=%s\n' "$b" "$s" "$d"; fail=1; fi
done

hdr "4. rsync 反向 dry-run"
# 已知良性差异（源仓库仍是"活的"时必然出现，与数据完整性无关）:
#   .git/index        stat 缓存，记录每个文件的 inode/device —— 跨文件系统复制后必然不同，
#                     任一侧跑 git status 就会各自重写。不含唯一数据。
#   .git/FETCH_HEAD   IDE 的 git 扩展周期性 autofetch 刷新 mtime（内容 md5 实测一致）
#   .git/ .git/objects/  上述两者导致的父目录 mtime 变化
# 真正的数据差异必须单独报出来，不能被这几条掩盖 —— 所以分两类打印，只有非良性项才置 fail。
BENIGN='^[.>]f\.\.t\.+ \.git/(index|FETCH_HEAD)$|^\.d\.\.t\.+ \.git/(objects/)?$'
allout="$(rsync -aHAXn --itemize-changes "$SRC/" "$DST/" 2>&1 | grep -vE '^$|^sending|^sent |^total ')"
diffout="$(echo "$allout" | grep -vE "$BENIGN" | grep -v '^$')"
benign="$(echo "$allout" | grep -E "$BENIGN")"
[ -n "$benign" ] && { echo "已知良性（git 元数据抖动，不计入失败）:"; echo "$benign" | sed 's/^/      /'; }
if [ -z "$diffout" ]; then echo "PASS  无实质差异"
else echo "FAIL  存在实质差异:"; echo "$diffout" | head -20; fail=1; fi

hdr "5. git 仓库完整性（在目标处）"
if git -C "$DST" rev-parse --git-dir >/dev/null 2>&1; then
  echo "分支: $(git -C "$DST" branch --show-current)"
  echo "HEAD: $(git -C "$DST" rev-parse --short HEAD)"
  if git -C "$DST" fsck --no-progress --no-dangling >/dev/null 2>&1; then echo "PASS  git fsck 通过"
  else echo "FAIL  git fsck 报错"; fail=1; fi
  st="$(git -C "$DST" status --porcelain | head -5)"
  [ -z "$st" ] && echo "PASS  working tree 干净" || { echo "注意  working tree 有改动:"; echo "$st"; }
else echo "FAIL  目标处不是 git 仓库"; fail=1; fi

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
[ $fail -eq 0 ] && echo "ALL_VERIFY_PASS —— 可以删源" || echo "VERIFY_FAILED —— 不要删源"
exit $fail
