# Dropbox 实测传输速率（本机 192.168.0.81 / enp5s0）

**首测 2026-11-21，样本 = P46 客户交付（WALKUP-21683 / Yeji_WGS，20 个 WGS FASTQ，759.9 GiB）。**

## 结论先行：规划交付时用这三个数

| 用途 | 速率 | 换算 |
| :--- | :---: | :---: |
| **上传（持续，实测瞬时）** | **≈ 15 MiB/s** | ≈ 125 Mbit/s |
| **上传（整批平均，含排队与爬升）** | **≈ 11 MiB/s** | **≈ 39 GiB/h** |
| 本地盘间拷贝（srv sdc1 → Work_bio sdb1） | ≈ 130 MiB/s | ≈ 457 GiB/h |

**规划公式：一批 N GiB 上传到 Dropbox 约需 `N / 39` 小时。**
- 760 GiB（10 样本 WGS，~55×）⇒ **约 19 h**
- 单个 38 GiB FASTQ ⇒ 约 1 h

⚠ **本地拷贝比上传快 12 倍**，所以「文件已出现在 `~/Dropbox/` 里」距离「客户能下载」还差十几个小时。
清点交付状态必须看 `dropbox filestatus`，**不能看 `ls`**。

## 实测依据

### 1. 瞬时速率（直接测网卡）

每 30 s 读 `/proc/net/dev` 的 `enp5s0` tx 累计字节，同时记录 `dropbox filestatus` 的待同步文件数。
采样期间全程 3 个文件在 `syncing`。

```
区间 30s   enp5s0 tx 14.92 MiB/s   enp9s0 0.00 MiB/s   syncing=3
区间 30s   enp5s0 tx 14.87 MiB/s   enp9s0 0.00 MiB/s   syncing=3
```

速率极稳（两点差 0.3 %），**像是被限速而不是带宽竞争**。

**归因依据**（为什么把网卡 tx 算成 Dropbox 的）：`ss -tnp` 显示只有 `dropbox`(PID 4142334)
一个进程有大 Send-Q（3,955,560 bytes → `162.125.4.12:443`），其余外联（claude / codex /
claude-science / agy）Send-Q 全为 0，是空闲控制连接。同时本机在跑的 P46 比对全部是本地盘
I/O（`/srv` 与 `/Work_bio` 均为本地 ext4，非网络挂载，已用 `df -T` + `mount` 确认），不产生网络流量。

### 2. 整批平均速率（按文件完成时刻反推）

| 项 | 实测 |
| :--- | :---: |
| 我方上传批 | 12 个文件，465.1 GiB |
| 本地拷贝窗口 | 12:48 → 13:49（61 min）⇒ 130 MiB/s |
| 21:15 时上传完成 | 9 / 12 个 = 333.6 GiB |
| 经过时长 | 8.47 h（自第一个文件 12:48 可传起算） |
| **批量平均下限** | **11.2 MiB/s = 39.4 GiB/h** |

这是**下限**：另外 3 个在传的文件已传了一部分但未计入。真实值在 11-15 MiB/s 之间，
与瞬时测值一致。整批平均低于瞬时值的原因是前期文件还在本地拷贝、无法同时开传。

## 对照：同一批数据的 Google Cloud 下载

同一批 FASTQ 从 `gs://fc-ab3a58ee-…` 下载实测 **12.9 MiB/s（45.3 GiB/h）**，与本机 Dropbox 上传的
11-15 MiB/s **同量级** ⇒ 两个方向都像被同一个 WAN 上限限住，而不是各自的服务端或协议差异。
⇒ **估算任何云端搬运，先用 ~12 MiB/s / ~43 GiB/h 这个量级起算。**
详见 `/home/gao/Utilities/Cloud/google_cloud/2_Agent自动从Google_Cloud下载的流程.md` 第 7 步。

## 陷阱

### `ls` 看到文件 ≠ 已上传完

`~/Dropbox/` 是本地目录，文件一拷进去就能 `ls` 到，但上传要再等若干小时。
唯一可信的是：

```bash
cd ~/Dropbox/<目录> && dropbox filestatus * | grep -v 'up to date'
dropbox status          # "Uploading N files..." / "Up to date"
```

### 文件 mtime 不能用来推我方的下载速度

同一目录下另有 8 个文件（294.8 GiB）的 Dropbox 侧 mtime 是 11-17 ~ 11-19，比本机源文件还早
⇒ 它们是**从 Dropbox 同步下来的**，不是我方上传的。但 **Dropbox 会把服务端 mtime 写到本地文件上**，
那个时间反映的是**上传方改动文件的时刻，不是我方下载完成的时刻**。
这 8 个文件的 mtime 间隔极规整（每个 ~37 GiB 相隔 6.5-7.4 h，折合 ~5.15 GiB/h），
看着很像一个速率，**但无法判定那是谁的速率** ⇒ **本文不据此给下载速率**，待单独实测。

### 两块盘不抢 I/O

`/srv/external_data` = sdc1，`/Work_bio`（Dropbox 目录实际位置 `/Work_bio/dropbox/Dropbox_Data`）= sdb1。
上传时 Dropbox 读 sdb1，分析读写 sdc1，互不干扰 —— 这是巧合而非设计，换盘时要重新确认。

## 复现方法

```bash
# 瞬时速率：每 30 s 一点，20 min
for i in $(seq 1 41); do
  printf '%s\t%s\n' "$(date +%s)" "$(awk '/enp5s0:/{print $10}' /proc/net/dev)"
  sleep 30
done
# 相邻两点 (Δbytes / Δsec / 1048576) = MiB/s

# 归因：确认只有 dropbox 在上传
ss -tnp | awk '$3+0 > 100000'   # Send-Q 大的进程
```

---

## 修订记录

| 日期 | 内容 |
| :--- | :--- |
| 2026-11-21 | 首测。样本 P46 / WALKUP-21683，759.9 GiB。上传瞬时 ~15 MiB/s、整批 ~11 MiB/s。下载速率未测。 |
