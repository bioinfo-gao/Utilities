#!/usr/bin/env bash
# 3/4 — 切换 bind mount 的准备与命令生成。
#
# 本步需要 root，脚本【不执行】任何 root 操作 —— 它做两件事:
#   (a) 查清谁占着挂载点（umount 会被它们挡住），并给出针对性的处理建议
#   (b) 生成一份填好路径的 root 命令块，供人工审阅后粘贴执行
#
# 用法: ./3_prep_bindmount_switch.sh <MOUNTPOINT> <OLD_PHYS> <NEW_PHYS>
# 例:
#   ./3_prep_bindmount_switch.sh /home/gao/projects_2026H2 \
#        /mnt/ex_8T_SSD/projects_2026H2 \
#        /srv/external_data/gao_projects/projects_2026H2
#
# 为什么保持挂载点【路径不变】而不是改成软链接:
#   nextflow 的 work 目录之间用【绝对路径软链接】互相 stage 输入。projects_2026H2 里
#   实测有 1387 条这种链接指向 /home/gao/projects_2026H2/...。只要挂载点路径一个字节不变，
#   它们全部继续有效，零改动。换成软链接形式虽然也能保住路径，但 bind mount 更干净
#   （见同目录 symlink_vs_bind_mount_0721.md）。

set -o pipefail
MP="${1:-}"; OLD="${2:-}"; NEW="${3:-}"
[[ -n "$MP" && -n "$OLD" && -n "$NEW" ]] || {
  echo "用法: $0 <MOUNTPOINT> <OLD_PHYS> <NEW_PHYS>" >&2; exit 2; }

echo "=== 当前挂载 ==="
findmnt -T "$MP" || { echo "$MP 不是挂载点？请确认。"; }

echo
echo "=== fstab 里对应的行 ==="
grep -n -- "$MP" /etc/fstab || echo "  (未找到 —— 若不是 fstab 管理的，下面的 sed 不适用)"

echo
echo "=== 谁占着挂载点（cwd 落在 $MP 下的进程）==="
# 注意: 不要用 `fuser -vm <挂载点>` 做判据 —— 它给的是【设备级】结果，会把同一块盘上
# 其他目录的用户、甚至 swapfile 都列进来（实测虚报一倍）。真正挡 umount 的判据是
# readlink /proc/*/cwd 落在挂载点路径下。
found=0
for p in $(ls /proc 2>/dev/null | grep -E '^[0-9]+$'); do
  c=$(readlink /proc/$p/cwd 2>/dev/null)
  case "$c" in "$MP"*)
    found=$((found+1))
    printf "  PID %-8s %-44s %s\n" "$p" "$c" "$(ps -o cmd= -p $p 2>/dev/null | cut -c1-50)" ;;
  esac
done
if [ "$found" -eq 0 ]; then
  echo "  无 —— 挂载点空闲，可以直接 umount"
else
  cat <<'TIPS'

  处理建议（按实测经验）:
    - tmux session      : tmux kill-session -t <name>
                          ⚠ 注意 `tmux new -s X` 那个进程往往是 tmux SERVER 本身，
                            自己正在跑的任务也挂在它下面 —— 别在任务跑完前 kill 它。
                            关掉所有 session 后 server 会自行退出。
    - IDE 集成终端的 bash: 交互 shell 【忽略 SIGTERM】，要用 SIGHUP:  kill -HUP <pid>
    - 其他进程          : 先 kill -TERM，5 秒不退再 kill -HUP / -KILL
    - 实在不想逐个清理   : sudo umount -l （lazy umount）。对"永远不会再碰这个挂载点的
                          idle shell"是安全的，只是不如清干净利落。
TIPS
fi

cat <<EOF

================= 以下命令需要 root，请人工审阅后执行 =================

# 1. 建最终父目录并搬入（若 NEW_PHYS 的父目录是 root 所有）
#    同一文件系统内是 rename，瞬间完成，不重复复制数据
sudo mkdir -p "$(dirname "$NEW")"
sudo chown "\$(id -un):\$(id -gn)" "$(dirname "$NEW")"
# mv <暂存位置> "$NEW"

# 2. 改 fstab（先备份），改完先看一眼再动挂载
sudo cp /etc/fstab /etc/fstab.bak_\$(date +%m%d)
sudo sed -i 's|^$OLD |$NEW |' /etc/fstab
grep "$MP" /etc/fstab

# 3. 卸载 → 此刻源端静止 → 最后一次增量同步 → 挂上新位置
#    把增量同步夹在 umount 与 mount 之间: 那一刻源端没有任何路径能被写入，同步窗口为零。
#    这不是多此一举 —— 活着的仓库（IDE 的 git autofetch 等）会在你不注意时改动源端。
sudo umount "$MP"
rsync -aHAX --numeric-ids "$OLD/" "$NEW/"
sudo mount "$MP"

# 4. 确认（SOURCE 必须变成新盘的设备名）
findmnt -T "$MP"

======================== 出问题的回退 ========================
# 源数据此刻还一个字节都没删，随时可退:
sudo cp /etc/fstab.bak_\$(date +%m%d) /etc/fstab
sudo umount "$MP" && sudo mount "$MP"

确认第 4 步 findmnt 指向新盘后，再跑 4_drop_migrated_source.sh 删源。
EOF
