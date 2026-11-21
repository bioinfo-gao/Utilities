# 手动从 Google Cloud 下载测序数据（Broad Walk-Up 交付）

> 写给：我自己下次手动操作时照着做。2026-11-20 首次实操（P46 Yeji Park WGS，WALKUP-21683）后整理。
> 让 agent 自动下载的流程见同目录 `2_Agent自动从Google_Cloud下载的流程.md`。

## 一句话流程

**找到邮件里的 `gs://` 路径 → 服务器上 `gcloud auth login` → 列出文件、只挑自己的样本 → 在 tmux 里 `gcloud storage cp` → 核对大小和 crc32c。**

---

## ⚠ 每次开新终端，先粘这几行

下面的命令都用到 `$GC`、`$SRC`、`$DEST` 这几个变量。它们**只在定义它们的那个终端里有效**；
新开终端或换了 tmux 窗口，必须重新定义。否则 `$GC` 是空的，会报 **`storage: command not found`**。

```bash
GC=/home/gao/.conda/envs/gcloud/bin/gcloud
SRC=gs://fc-ab3a58ee-f93b-4445-9cfb-3093775a3bdf/WALKUP-21683/261112_SL-EXF_0833_B25FGWWLT4/16496_1794694072   # ← 换成本次邮件里的
DEST=/srv/external_data/gao_projects/46_park_wgs_raw/WALKUP-21683                                                 # ← 换成本次的
echo "GC=$GC"; echo "SRC=$SRC"; echo "DEST=$DEST"; $GC --version | head -1   # 自查：三行都非空、版本号能打印
```

（登录状态保存在 `~/.config/gcloud/`，不会随终端消失；会消失的只是这几个变量。）

## 第 0 步：准备两样东西

| 要什么 | 从哪里来 |
| :--- | :---: |
| bucket 路径 `gs://fc-.../WALKUP-xxxxx/<run>/<id>` | Jing Shi 转发的 Broad 邮件，标题 **"Walkup sequencing delivery confirmation for WALKUP-xxxxx"**，正文 `Google Bucket:` 那一行 |
| 客户样本名 ↔ `WGSxxxxxx` 编号对照 | Kuo-Chan 的 **"… Data Delivery and Metadata"** 邮件附表 |
| 登录账号 | Jing Shi 的 Athenomics Google 账号（她通过微信给；**账号密码不写进任何文件**） |

> 为什么不直接等 Dropbox：`Dropbox/Athenomics_Delivery/WALKUP-xxxxx/` 也会同步同一批文件，但 2026-11 实测
> 约 **7 小时一个文件**，而且会停滞、漏文件。Dropbox 里**已经同步完**的文件可以复用（见第 6 步）。

## 第 1 步：工具（已经装好，一般跳过）

服务器上已有独立环境 `gcloud`（Google Cloud SDK 594.0.0）。下面所有命令都用这个绝对路径，不需要激活环境：

```bash
GC=/home/gao/.conda/envs/gcloud/bin/gcloud
$GC --version
```

如果这个环境不在了，重装：`mamba create -y -n gcloud -c conda-forge google-cloud-sdk`

## 第 2 步：登录（远程服务器，没有浏览器）

```bash
$GC auth login --no-launch-browser
```

1. 终端打印一条很长的链接 → 在**本地浏览器**打开（VSCode 里 Ctrl+点击）。
2. 输入 `j.shi@athenomics.com` → 出现「**使用 Microsoft 帳戶登入**」页面 → 点继续，这是正常的（她的账号走 Microsoft 单点登录）。
   - 如果页面让你「**注册/建立新 Google 账号**」→ 不要建，退出，问 Jing。
   - 可能要她手机上的多因素验证。
3. 点「允许」→ 页面显示一串验证码 `4/0A...` → **复制，马上粘回同一个终端**，回车。
4. 看到 `You are now logged in as [j.shi@athenomics.com]` 就成功了。

**⚠ 最常见的错误**：`ERROR: (gcloud.auth.login) (invalid_grant) Bad Request`
= 粘的是**上一次**运行拿到的码。每运行一次 `auth login` 都要用**这一次**打印的新链接重新拿码；
拿码之前不要 Ctrl+C、不要重跑命令。验证码一次性、几分钟过期，也不要发给别人。

检查当前登录了谁：`$GC auth list`。用完想撤销：`$GC auth revoke j.shi@athenomics.com`。

## 第 3 步：看 bucket 里有什么

（先确认已粘过开头那几行变量。）

```bash
$GC storage ls -l $SRC/                       # 顶层：RunInfo.xml、SampleSheet、InterOp/、fastq/
$GC storage ls -l $SRC/fastq/ | grep fastq.gz # 所有 FASTQ 和大小
$GC storage du -s $SRC                        # 总大小
```

**⚠ 关键：lane 是多客户混池。** `fastq/` 里除了我们的 `WGSxxxxxx`，还有别家的 `SCR…`/`SEQ…` 样本和
`Undetermined_*`（本次约 240 GB）。**只下载我们自己的样本**，别家的数据不下载、也不碰。
`InterOp/`（约 9 GB 机器运行指标）一般不需要。

## 第 4 步：建目录，写下载清单

数据大（10 个 WGS 样本 ≈ 0.8 TB）⇒ 放在空间最大的盘 `/srv/external_data/gao_projects/`，项目里只放软链接。

```bash
mkdir -p $DEST/fastq               # DEST 已在开头定义
# 只挑我们的样本（按 WGS 编号改正则）：
$GC storage ls $SRC/fastq/ | grep -E 'WGS0000(29|3[0-8])_.*\.fastq\.gz$' > $DEST/_my_files.txt
wc -l $DEST/_my_files.txt          # 应 = 样本数 × 2（R1/R2）× lane 数；本次 = 20
```

## 第 5 步：在 tmux 里下载（大文件必须用 tmux）

```bash
tmux new-session -d -s gcs_dl "cat $DEST/_my_files.txt | $GC storage cp -n -I $DEST/fastq/ 2>&1 | tee $DEST/_download_\$(date +%Y%m%d_%H%M).log"
# 顺便把小的报告文件也下下来（QC 用）：
$GC storage cp -r $SRC/fastq/Reports $SRC/fastq/Logs $DEST/fastq/
$GC storage cp $SRC/RunInfo.xml $SRC/RunParameters.xml $SRC/SampleSheet_hsa.csv $DEST/
```

- `-n` = 已经存在的文件跳过；**中断了就原命令再跑一遍**，未完成的文件（`*.gstmp`）会自动续传。
- 下载中的文件名是 `xxx.fastq.gz_.gstmp`，**完成后才改名**为 `.fastq.gz`。
- 看进度：`tmux capture-pane -t gcs_dl -p | tail -3`，或 `ls $DEST/fastq/*.fastq.gz | wc -l`。
- **⚠ 看速度不要用 `du -sb`**：`.gstmp` 一开始就被预分配成满尺寸的稀疏文件，显示的大小没有意义。用：
  ```bash
  r1=$(awk '/enp5s0/{print $2}' /proc/net/dev); sleep 10; r2=$(awk '/enp5s0/{print $2}' /proc/net/dev); echo "$(( (r2-r1)/10/1048576 )) MiB/s"
  ```
- 本机实测上限 **≈ 13 MiB/s**（加大并发也不变），⇒ **1 TB ≈ 22 小时，800 GB ≈ 17 小时**。

## 第 6 步（可选，省时间）：复用 Dropbox 里已经同步好的文件

Dropbox 里已有、而且**大小和 bucket 完全一致**的文件，先算 crc32c 和 bucket 比对，一致才拷贝，就不用再下载：

```bash
$GC storage hash --skip-md5 /path/in/Dropbox/xxx.fastq.gz                          # 本地 crc32c
$GC storage objects describe $SRC/fastq/xxx.fastq.gz --format='value(crc32c_hash)'  # 远端 crc32c
# 两者相同 ⇒ cp 到 $DEST/fastq/；第 5 步的清单里删掉这些文件
```

（40 GB 文件算一次 crc32c 约 10–20 分钟，受磁盘读速限制。）

## 第 7 步：校验 —— 每个文件大小和 crc32c 都要与 bucket 一致

```bash
cd $DEST/fastq
for f in *.fastq.gz; do
  r=$($GC storage objects describe $SRC/fastq/$f --format='value(size,crc32c_hash)' | tr '\t' ' ')
  l="$(stat -c %s $f) $($GC storage hash --skip-md5 --format='value(crc32c_hash)' $f)"
  [ "$r" = "$l" ] && echo "OK   $f" || echo "FAIL $f  remote=[$r] local=[$l]"
done | tee ../_verify_$(date +%Y%m%d_%H%M).txt
```

**全部 OK、数量对（本次 20 个）、没有残留的 `*.gstmp`** 才算下载完成。有 FAIL 的：删掉那一个文件，再跑一次第 5 步。

## 第 8 步：链进项目 + 记录

```bash
mkdir -p <项目>/raw_data && ln -s $DEST/fastq/*.fastq.gz <项目>/raw_data/
```

- 在项目 `scripts/0_sample_table.csv` 里记：文件名 ↔ 客户样本名（来自 Kuo-Chan 的对照表）。
- Illumina 文件名可以直接解读：`<flowcell>_<lane>_<库号>_<WGS编号>_S<n>_L00<lane>_R<1|2>_001.fastq.gz`。
- `SampleSheet*.csv`、`delivery_manifest.csv`、`Reports/` 里有**别家客户的样本编号** ⇒ 只作内部 QC，**绝不放进客户交付**。

---

## 附：只想下几个小文件时

浏览器打开邮件里 "Google Cloud Console: View" 的链接，用同一账号登录，可以直接点文件下载。
**FASTQ 动辄 40 GB，不要用浏览器下**，一定在服务器上用上面的命令。

## 附：本次（2026-11-20）实际参数

| 项 | 值 |
| :--- | :--- |
| 项目 | `/mnt/ex_8T_SSD/projects_2026Q4/46_park_wgs`（Yeji Park，10 样本 Ctr_1–3 + Sample 1–7） |
| WALKUP | 21683；flowcell 25FGWWLT4；lane 4 = WGS000029–033，lane 5 = WGS000034–038 |
| SRC | `gs://fc-ab3a58ee-f93b-4445-9cfb-3093775a3bdf/WALKUP-21683/261112_SL-EXF_0833_B25FGWWLT4/16496_1794694072` |
| DEST | `/srv/external_data/gao_projects/46_park_wgs_raw/WALKUP-21683/` |
| 我们的文件 | 20 个 FASTQ，816.0 GB（整个交付 1081 GB，其余是别家样本 + Undetermined + InterOp） |
