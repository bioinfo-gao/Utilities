# Agent 自动从 Google Cloud 下载测序数据的流程

> 写给：下次接到「把 XX 的数据从 Google Cloud 下载下来」时的 agent（Claude Code / Codex / 其他）。
> 2026-11-20 首次实操（P46 Yeji Park WGS，WALKUP-21683）后整理。用户自己手动操作的版本见同目录
> `1_手动从Google_Cloud下载测序数据.md`。
> 脚本：`/home/gao/Utilities/Server/gcs_download/gcs_download.sh`（唯一实现，不要另写一份）。

## 一句话流程

**读邮件取 `gs://` 路径和样本对照 → 先查 Dropbox 已同步多少 → 请用户本人登录 → 小文件试跑脚本 →
tmux 正式下载（只选我方样本）→ Dropbox 已有且 crc32c 一致的就本地拷贝 → 全量校验 `ALL_DONE` → 链进项目。**

---

## 第 1 步：读邮件（只读授权，不需要逐封请示）

| 邮件 | 取什么 |
| :--- | :--- |
| Jing Shi 转发的 "Walkup sequencing delivery confirmation for WALKUP-xxxxx" | `Google Bucket: gs://...` = **SRC**；Broad 的 `SM-xxxxx` ↔ lane；"Run passes QC" |
| Kuo-Chan 的 "… Data Delivery and Metadata" | 客户样本名 ↔ `WGSxxxxxx` ↔ index ↔ 实际 reads（**选择正则就按这些 WGS 编号写**） |
| 用户发给自己的 "google cloud download" | 登录用哪个账号。**里面的密码不读出、不复述、不写进任何文件、不由 agent 使用** |

Gmail 搜索示例：`newer_than:14d (shi OR Jing OR <客户名>)`、`from:me to:me newer_than:7d`。
`get_thread` 结果太长会落成 JSON 文件 → 用 `python3 -I` 读 `plaintextBody`。

## 第 2 步：确认项目和存放位置

- 项目：在 `~/projects_2026Q4/`（及 `~/projects_2026M7/`）里按客户名找，并核对 `scripts/0_sample_table.csv` 的样本名
  与 Kuo-Chan 的表一致。查 `Agent_Assets/runtime/active_projects.json` 确认不是别的 Agent 负责的项目。
- **DEST 放 `/srv/external_data/gao_projects/<项目名>_raw/WALKUP-xxxxx/`**（9.1 T 盘），项目里只放软链接。
  `/mnt/ex_8T_SSD`（项目盘）剩余空间少，0.8 TB 的原始数据放进去会挤掉后续 BAM 的空间。先 `df -h` 核实。

## 第 3 步：先看 Dropbox 已同步多少

`~/Dropbox/Athenomics_Delivery/WALKUP-xxxxx/` 渐进同步同一批文件。记录成
**"截至 YYYY-MM-DD HH:MM 目录内为 N 个文件"**（不是"数据共 N 个"），并看 mtime 判断是否还在动。
2026-11 实测：约 7 h/文件，11-19 07:30 后停滞，并漏了 1 个文件 ⇒ 不能指望 Dropbox。

## 第 4 步：环境 + 登录（登录只能用户本人做）

- 环境：`/home/gao/.conda/envs/gcloud/bin/gcloud`（Google Cloud SDK 594.0.0）。不在了就先告知用户再
  `mamba create -y -n gcloud -c conda-forge google-cloud-sdk`（独立环境，不动已有环境）。
- `gcloud auth list` 没有账号 ⇒ **停下，请用户本人在终端运行**
  `/home/gao/.conda/envs/gcloud/bin/gcloud auth login --no-launch-browser`。
  - agent **不代填密码、不代粘验证码**；用户把验证码贴进对话时，提醒他粘到终端，不要使用它。
  - 给用户的提示要预先说清：① Microsoft SSO 页面（「使用 Microsoft 帳戶登入」）点继续是正常的；
    ② 要「建立新 Google 账号」⇒ 不要建；③ 验证码必须来自**同一次**运行打印的链接，否则
    `(invalid_grant) Bad Request`；④ 拿码前不要 Ctrl+C。
  - 更好的长期方案（可向用户提一次）：请 Jing 在 Terra 里把 workspace（bucket 名以 `fc-` 开头）以 Reader
    权限分享给用户自己的 Google 账号，以后就不需要她的密码和手机验证。
- 登录后核实：`gcloud auth list` 显示的账号 + `gcloud storage ls $SRC/` 能列出东西。

## 第 5 步：列清单，确定选择正则

```bash
GC=/home/gao/.conda/envs/gcloud/bin/gcloud
$GC storage ls -l $SRC/ ; $GC storage ls -l -r $SRC/fastq/ | grep -v InterOp ; $GC storage du -s $SRC
```

- **lane 是多客户混池**：`fastq/` 里还有别家 `SCR…/SEQ…` 和 `Undetermined_*` ⇒ 只选我方 WGS 编号。
- 本次正则（相对 SRC 的路径，Python regex）：
  `^(fastq/[^/]*WGS0000(29|3[0-8])_[^/]*\.fastq\.gz|fastq/(Reports|Logs)/.*|[^/]+)$`
- 核对：选中的 FASTQ 数 = 样本数 × 2 × lane 数（本次 20），总量与 Kuo-Chan 表的 reads 数量级相符。
- **⚠ 清单一律用 `--format=json`**。本次曾用 csv 加 `timeout 120`，清单被截断成只有 InterOp 的 705 个对象，
  看起来却像完整的。

## 第 6 步：小文件试跑脚本（零风险）

```bash
bash /home/gao/Utilities/Server/gcs_download/gcs_download.sh "$SRC" <scratchpad>/gcs_test '^(fastq/(Reports|Logs)/.*|[^/]+)$'
```

期望最后一行 `ALL_DONE`，`_verify_*.tsv` 全 OK。这一步顺带验证了权限、路径拼接、校验逻辑。

## 第 7 步：tmux 正式下载

**启动前一句话告诉用户**：预计耗时、写哪个目录、中途打断会怎样（可原命令续传，不丢已完成的文件）。

```bash
D=<DEST>; TS=$(date +%Y%m%d_%H%M); echo '<选择正则>' > $D/_regex_$TS.txt
tmux new-session -d -s gcs_walkup<号> "CLOUDSDK_STORAGE_PROCESS_COUNT=16 CLOUDSDK_STORAGE_THREAD_COUNT=8 \
  bash /home/gao/Utilities/Server/gcs_download/gcs_download.sh $SRC $D \"\$(cat $D/_regex_$TS.txt)\" 2>&1 | tee $D/_download_$TS.log"
```

脚本做三件事：① JSON 清单 → `_gcs_manifest_<TS>.tsv`；② 按子目录 `gcloud storage cp -n -I`（跳过已完成，`.gstmp` 续传）；
③ 逐文件 size + crc32c 复核 → `_verify_<TS>.tsv`，全对才打印 `ALL_DONE`，否则 exit 1。
正则写进文件再 `$(cat …)` 传入，避免 tmux 命令里多层引号转义出错，也留下本次用的正则作为记录。

**早期检查（启动后 1–2 分钟）**：日志里 `account:` 和 `selected N objects, X GB` 对得上；出现 `.gstmp`。

**测速**：用网卡计数或已分配块，**不要用 `du -sb`**（`.gstmp` 是预分配的满尺寸稀疏文件）：
```bash
r1=$(awk '/enp5s0/{print $2}' /proc/net/dev); sleep 10; r2=$(awk '/enp5s0/{print $2}' /proc/net/dev); echo "$(( (r2-r1)/10/1048576 )) MiB/s"
```
### 实测速率（2026-11-21 定稿，P46 / WALKUP-21683，`gs://fc-ab3a58ee-…`）

| 场景 | 实测 | 换算 |
| :--- | :---: | :---: |
| **大文件批（12 个 FASTQ，465.1 GiB）** | **12.9 MiB/s** | **45.3 GiB/h** |
| 小文件批（`Reports/` 12 个，4.5 MB） | 3.8 MiB/s | 单文件开销主导 |
| 极小文件（`Logs/` 4 个，16 KB） | 5.3 kiB/s | 速率无意义，只看是否完成 |

**规划公式：一批 N GiB 从 bucket 下载约需 `N / 45` 小时。**
- 465 GiB（12 个 FASTQ）⇒ 实测 **10.3 h**
- 760 GiB（10 样本 WGS 全量，~55×）⇒ 约 **17 h**
- 之后还要加 **约 1 h** 的 gcloud 自带 crc32c 校验（见第 9 步）

**两个独立来源互证**（这是本数可信的理由）：
1. gcloud 自报：日志里 `Average throughput: 12.9MiB/s`（`_download_20261120_2348.log:76`）。
2. 按完成时刻反推：465.1 GiB，23:48:34 开始 → 10:05 最后一个文件改名完成 = 10.28 h ⇒ **12.9 MiB/s**。

两者小数位一致。⚠ 反推用的是 `fastq/*.fastq.gz` 的 mtime，**gcloud 是并行切片下载，12 个文件在
08:50–10:05 这 75 min 内几乎同时完成** ⇒ 不要误读成"每个文件 6 分钟"，也不能用单个文件的 mtime
间隔去算速率。

**瓶颈在 WAN，不要调并发**：`CLOUDSDK_STORAGE_PROCESS_COUNT` 8×4 与 16×8 实测速率相同，
期间 CPU 98 % 空闲。再加并发只会增加小文件的连接开销。

**对照 Dropbox**（同一批数据，反方向）：上传 ≈ 11-15 MiB/s，与 GCS 下载同量级
⇒ 两者都像是被 WAN 上限限住，而不是各自的服务端。详见
`/home/gao/Utilities/Cloud/Dropbox/upload_download_speed_measured.md`。

## 第 8 步：复用 Dropbox 已同步的文件（省几个小时）

1. 找出 Dropbox 里**字节数与 bucket 完全一致**的文件。
2. 把它们从下载正则里排除（负向前瞻 `^(?!.*(<文件名片段>|…)_001)…`），重启第 7 步，先下其余文件。
3. 并行在 tmux 里对这些 Dropbox 文件算 crc32c（`gcloud storage hash --skip-md5`，`xargs -P 4`；
   受磁盘限制约 38 MB/s 合计），结果写进 `$D/_dropbox<N>_crc32c_<TS>.tsv`。
4. **crc32c 与 `_gcs_manifest` 一致的才** `cp` 到 `$D/fastq/`（Dropbox 只读，不移动、不改名）；不一致的交回 bucket 下载。
5. 已经开始下载的同名 `.gstmp` 残留：属于本次会话自建的未完成临时文件，**删除前仍需向用户说明并征得同意**。

## 第 9 步：全量校验 → 完成判定

用**完整正则**（不排除任何文件）再跑一次脚本：`cp -n` 全部跳过，只做校验。完成标准如下。

**校验时间（2026-11-21 实测，`/srv/external_data` 是机械盘）**：
- gcloud 下载结束时会自己校验 crc32c，校验通过才把 `.gstmp` 改名。它用约 77 个进程并行读，盘只跑到 ~80 MB/s，10 个文件用了约 1.5 h。
- 脚本自带复核：4 路并行只有 **27 MB/s**，**串行 165 MB/s** ⇒ 脚本已改成默认串行（`VERIFY_JOBS=1`）。
- 只留一轮全量复核：分批下载时，**中间那轮自带的复核可以直接停掉**，它和最终全量复核重复。

- 日志末行 `ALL_DONE`；`_verify_*.tsv` 中 OK 数 = 选中数，0 FAIL；
- `$D/fastq/` 下没有残留 `*.gstmp`；FASTQ 数 = 预期数。

汇报时给出每一项的实测值（不要只说"下载完成"）。

## 第 10 步：链进项目 + 记录

- `mkdir -p <项目>/raw_data && ln -s $D/fastq/*.fastq.gz <项目>/raw_data/`
- 在 `scripts/0_sample_table.csv` 补 文件名、lane、R1/R2 GiB、raw read pairs（单一数据源，不另开副本）。
- `SampleSheet*.csv` / `delivery_manifest.csv` / `Reports/` 含别家客户样本编号 ⇒ 只作内部 QC，**不进交付**。
- 在本文末尾的「运行记录」表加一行。

## 禁止事项

| 不做 | 原因 |
| :--- | :--- |
| 使用、复述、保存邮件里的密码或验证码 | 凭证只能由用户本人输入 |
| 下载别家客户样本或 Undetermined | 不是我方数据 |
| 对 DEST 做 `rm -rf` 重来 | 中断了原命令续传即可；任何删除先问用户 |
| 写进 Dropbox 目录 | 会被同步回 Dropbox，与正在进行的同步冲突 |
| 用 Bash 后台跑长下载 | 必须 tmux，任务寿命与会话解耦 |

## 运行记录

| 日期 | 项目 | WALKUP | DEST | 结果 |
| :--- | :---: | :---: | :--- | :---: |
| 2026-11-20 | P46 Yeji Park WGS | 21683 | `/srv/external_data/gao_projects/46_park_wgs_raw/WALKUP-21683/` | ✅ 20 FASTQ / 816.0 GB：12 个 bucket 下载（499.4 GB，11-20 23:48 → 11-21 ~10:05，含 gcloud 自校验）+ 8 个 Dropbox 校验后拷贝；11-21 12:44 全量复核 40/40 OK（`_verify_20261121_1131.tsv`）；12:44–13:49 本地补齐 12 个到 Dropbox 交付目录（`46_park_wgs/scripts/2_copy_fastq_to_dropbox_1121.sh`，20/20 大小一致）；Dropbox 云端上传当时粗测 ≈ 8.4 MiB/s ⇒ 约 16 h（**11-21 21:15 正式复测 11-15 MiB/s**，8.4 那个数取样过短，以复测为准）；**bucket 下载实测 12.9 MiB/s / 45.3 GiB/h**（两来源互证，见第 7 步） |
