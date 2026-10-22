---
name: ssd-swap
description: "Use when 需要为跑重型/并发 WGS 管线(sarek、双管线并跑等)在本机加挂或重启后重新激活 64GB SSD swap 缓冲——该 swapfile 不在 fstab、重启后会失活消失,本 skill 给出探测现状→快速重激活 或 首次创建→设优先级/swappiness 的完整安全流程"
disable-model-invocation: true
---

# /ssd-swap — 加挂 / 重启后重新激活 SSD swap 缓冲

**用途**:本机跑重型 WGS(sarek)或双管线并跑时,用 64GB SSD swap 吸收瞬时内存峰值(见 `/corun`)。
**为什么需要这个 skill**:该 64GB swapfile **不在 `/etc/fstab`**(fstab 里只有 2GB 的 `/swapfile`)——
所以**每次重启后它会失活"消失"**,需手动重新 `swapon`。历史来源:`projects_2026H2/facilities/Server/1_add_SSD_swap.sh`。

**本机 swap 设计(目标状态)**:
| swapfile | 大小 | 优先级 | 物理盘 |
| :--- | :---: | :---: | :---: |
| `/swapfile`(系统,在 fstab,重启自动挂) | 2 GB | -2(最后用) | OS NVMe(Samsung 970 EVO) |
| `/mnt/ex_8T_SSD/swapfile`(本 skill 管理) | 64 GB | **10(先用)** | 7.3T SATA 数据盘 |
`vm.swappiness=10`(平时几乎不换出,只在真紧时用)。

---

## 步骤 0 — 先探测现状(决定走哪条路)

```bash
swapon --show; echo "swappiness=$(cat /proc/sys/vm/swappiness)"
ls -lh /mnt/ex_8T_SSD/swapfile 2>/dev/null
df -h /mnt/ex_8T_SSD | tail -1     # 确认盘上有 ≥64G 余量(创建时才需要)
```
- 若 `swapon --show` **已列出** `/mnt/ex_8T_SSD/swapfile` 且 PRIO=10 → 已就绪,无需操作。
- 若 **文件存在但没在 swapon 列表**(最常见:重启后)→ 走【路径 A:快速重激活】。
- 若 **文件不存在**(首次,或想换更大容量)→ 走【路径 B:创建】。

## 路径 A — 重启后快速重激活(文件已在持久 SSD 上,只是没激活)

swapfile 是持久 SSD 上的普通文件,重启不会删除,**只需重新激活 + 设优先级**:
```bash
sudo swapon -p 10 /mnt/ex_8T_SSD/swapfile   # -p 10 = 高优先级,先于 NVMe 的 2G 用
sudo sysctl vm.swappiness=10
swapon --show                                # 确认 64G 行出现且 PRIO=10
```
> 若报 "swapon: already active" → 已经在用,忽略即可。

## 路径 B — 首次创建 / 换更大容量

```bash
# (换容量时先关旧的:sudo swapoff /mnt/ex_8T_SSD/swapfile && sudo rm /mnt/ex_8T_SSD/swapfile)
SIZE=64G                                      # 需要更大就改这里(先确认 df 有余量)
sudo fallocate -l $SIZE /mnt/ex_8T_SSD/swapfile
sudo chmod 600 /mnt/ex_8T_SSD/swapfile        # 必须 600,否则 mkswap/swapon 拒绝
sudo mkswap /mnt/ex_8T_SSD/swapfile
sudo swapon -p 10 /mnt/ex_8T_SSD/swapfile     # 直接带 -p 10,省去"先开再改优先级"两步
sudo sysctl vm.swappiness=10
swapon --show
```
> `fallocate` 失败(某些 fs 不支持)时用:`sudo dd if=/dev/zero of=/mnt/ex_8T_SSD/swapfile bs=1M count=65536 status=progress`

## 步骤 2 — 验证(目标态)

```bash
swapon --show
# 期望看到两行,64G 那行 PRIO=10:
# /swapfile               file  2G  ...  -2
# /mnt/ex_8T_SSD/swapfile file 64G  ...  10
```

---

## 要点与安全

- **优先级刻意"反直觉"**:64G 在较慢的 SATA SSD 却 prio 10(先用),2G 在更快的 NVMe 却 prio -2(后用)——
  目的是让**大容量 SATA SSD 当主力溢出缓冲**、把 **NVMe 带宽留给 OS/根分区**,并少磨损系统盘。
- **`swappiness=10`**:只在真紧时才换出,平时不乱换(重型作业内存峰值靠它平滑越过,不 OOM)。
- **并跑纪律(见 `/corun`)**:峰值时 SSD swap 用到十几 G 是**正常缓冲、会自愈**——**不要恐慌 `swapoff` / `drop_caches`**;
  低 free 时 swapoff 反而可能把冷页硬拉回内存触发 OOM。跑大作业**前**激活,别在峰值中途动 swap。
- **持久化(可选,默认不做)**:当前刻意保持"按需手动激活"(只在跑 12 样 WGS 等重活前开)。若想永久:
  - swap 开机自挂:`/etc/fstab` 加 `/mnt/ex_8T_SSD/swapfile none swap sw,pri=10 0 0`
  - swappiness 永久:`/etc/sysctl.conf` 末尾加 `vm.swappiness=10`
- 需要 `sudo`。执行前用步骤 0 确认盘余量与现状,避免重复创建或误删正在用的 swapfile。
