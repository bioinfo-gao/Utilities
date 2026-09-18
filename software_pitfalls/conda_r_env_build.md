# 在 conda 上建 R 环境 / 无人值守构建脚本的坑

> 2026-09-17 建 `sc_tut_r` / `sc_tut_r_mono` / `sc_adv_r` 三个 R env 时实测。
> 同一天 `spatial_r` 一次建成、`sc_tut_r` 折了 4 个 R 包，差别不在运气，在 yaml 写法 —— 见 §2。

---

## §1 `mamba env create` 会弹交互确认，无人值守脚本因此静默停摆

**症状**：tmux 里跑构建脚本，solver 正常出结果（列出待装包数、下载量），之后**日志不再增长**，
env 目录一直不创建，进程还在、CPU 接近 0。像"在下载大文件"，实际是在等一个没人回答的问题。

```
Total download: 562MB
Confirm changes: [Y/n]        ← 停在这里，无限期
```

**根因**：`mamba env create -f x.yaml` 在本机会弹 `Confirm changes: [Y/n]`。项目脚本
（proj23/proj24 的 `1_setup_env.sh`）没有传 `-y`，脚本其它地方都写得很讲究
（绝对前缀、GitHub 兜底、逐包验证），偏偏漏了这一个。

**⚠ 最关键的一点 —— 判据选错会完全看不见它**：

| 回读方式 | 能不能看见那行 prompt |
| :--- | :---: |
| `tail -n N <log>` | **看不见**。prompt 不带换行，`tee` 到文件后它和上一行黏在一起，`tail` 按行切会把它藏在行尾 |
| `tmux capture-pane -t <s> -p \| tail` | **看得见**，这是唯一可靠的判据 |
| `ps` 进程还在 | 无用，等输入的进程当然还在 |
| `du -sh <env 前缀>` | 有用的旁证：目录不创建 = 一个包都没装 |

**实测代价**：13:50 solver 完成 → 14:20 才发现，**空等 28 分钟**，其间我还在回复里写了
"日志静默属于正常"。**"没有新输出"和"正在干活"长得一模一样，必须有能区分两者的回读方式。**

**修法（三选一，建议全用）**：
1. 脚本里显式非交互：`mamba env create -y -p ... -f ...`，或外层 `export CONDA_ALWAYS_YES=true`。
2. 已经跑起来了：`tmux send-keys -t <session> "y" Enter` 当场解开，不必重跑（solver 结果保留）。
3. 长任务挂一个自动应答看门狗，每 15 s 查一次 pane 末行：
```bash
pane=$(tmux capture-pane -t <session> -p | grep -v '^\s*$' | tail -1)
case "$pane" in *"Confirm changes"*|*"Proceed ([y]/n)"*)
  tmux send-keys -t <session> "y" Enter ;; esac
```

---

## §2 yaml 只声明 R 包、不声明它们链接的 C 库 ⇒ GitHub 源码编译必败

**症状**：conda 阶段一切正常，走到 `install_github` 阶段成片 `configuration failed`。

```
ERROR: configuration failed for package ‘BPCells’
  Unable to locate libhdf5. Please install manually or edit compiler flags.
ERROR: configuration failed for package ‘magick’
  If Magick++ is already installed, check that 'pkg-config' is in your PATH
```

**根因**：conda **不会**从 R 包名反推出它的 C 依赖。bioconda 上打包好的 `r-xxx` 自带依赖声明，
但**从 GitHub 源码编译的 R 包不经过 conda 的依赖解析** —— 它跑自己的 `configure`，
去系统里找 `libhdf5` / `Magick++`，找不到就失败。yaml 里没写，env 里就没有。

**对照实证（同一天、同一台机器）**：

| env | yaml 写法 | 结果 |
| :--- | :---: | :---: |
| `spatial_r`（proj24） | 把 `sf`/`terra` 的 GDAL/GEOS/PROJ 栈写全了 | 一次建成，501 包 |
| `sc_tut_r`（proj23） | 只写 R 包，未写 `hdf5` / `imagemagick` / `zlib` | BPCells、magick、Signac 编译失败，连带 Banksy / SeuratWrappers / Azimuth |

### ⚠ 2a. conda-forge 把 zlib 拆成两个包，只装到运行时那半边

**最隐蔽的一个**，因为 zlib "肯定装了"：

```
filter.cpp:2:10: fatal error: zlib.h: No such file or directory
ERROR: compilation failed for package ‘Signac’
```

实测该 env 里：

| | 状态 |
| :--- | :---: |
| `lib/libz.so.1` / `libz.so.1.3.2` | ✅ 在 |
| `include/zlib.h` | ❌ **不在** |
| `conda-meta/` | 只有 `libzlib-*.json`，**没有** `zlib-*.json` |

conda-forge 的拆分是 **`libzlib` = 运行时 `.so`，`zlib` = 含头文件**。R 包的运行期依赖只会
把 `libzlib` 拉进来，**源码编译要的是 `zlib`**。同类拆分在 conda-forge 很普遍
（`libcurl`/`curl`、`libxml2` 等），凡是"这个库肯定有啊"的直觉都要用
`ls <prefix>/include/<header>.h` 去证伪，而不是看 `lib/*.so` 在不在。

### ⚠ 2b. 一个缺失的 C 库会连带打掉一串 R 包

```
imagemagick 缺失 → magick → Banksy → SeuratWrappers
zlib(头文件)缺失 → Signac → Azimuth
hdf5 缺失       → BPCells
```

日志里是 **7 条 `ERROR`，根因只有 3 个**。
（额外的浪费：Azimuth 在失败前已经把 `BSgenome.Hsapiens.UCSC.hg38` ≈700 MB 下完了。）
**数 ERROR 条数会高估问题规模**；要沿依赖链回溯到最上游那一个。
修复顺序也必须自底向上 —— 直接重试 `SeuratWrappers` 没有任何意义。

**修法**：
1. 建 env 前，把 yaml 里所有走 GitHub/源码安装的 R 包列出来，逐个查它 `configure` 要哪个 C 库，
   显式写进 yaml 的 `dependencies`（`hdf5`、`imagemagick`、`pkg-config`、`gdal`、`geos`、`proj`…）。
2. 事后补救：`mamba install -p <prefix> -y hdf5 imagemagick zlib pkg-config`，再自底向上重装 R 包。
   能用 conda 装的 R 包就别让它走源码编译（如 `r-signac`，proj24 的 yaml 就是这么写的）。
3. **修完 env 一定要回填 yaml**。只修 env 不修 yaml，下次照这份 yaml 重建会一模一样地再失败一次。

---

## §2c `set -euo pipefail` 让一个可选包的失败吃掉整个后续流程

**症状**：脚本 `exit=1`，主 env 建好了，但**第二个 env 连 `[build]` 那行日志都没有** —— 不是建失败，
是从来没被执行到。

**根因**：proj23 的 `1_setup_env.sh` 用了 `set -euo pipefail`。装 GitHub 包的那段 `Rscript`
因为其中 4 个包编译失败而返回非零，`set -e` 当场终止脚本，`--with-mono` 那一整段从未运行。

**所以缺一个 C 库的最终代价不是"少一个 R 包"，是"少一整个 env"。**

**修法**：
- 建**多个** env 的脚本，外层驱动**不要**用 `set -e`；一个 env 失败不应阻止下一个开建。
  （本轮驱动脚本刻意没用 `set -e`，proj23 挂掉后 `sc_adv_r` 照常开建，保住了后半程。）
- 脚本内部区分**必需**与**可选**步骤：conda env create 失败该中止；
  GitHub/源码包（本就可能编译失败的那批）应当逐包 `tryCatch`/`|| true`，最后汇总报告缺了哪些，
  而不是让第一个失败者掀桌。
- 判据：**看有没有 `[build] <prefix>` 那行日志**，而不是看 env 目录在不在 ——
  "没建成"和"没轮到建"完全是两回事，后者重跑就好，前者要查原因。

---

## §2d 把一个包同时写成硬依赖和「解不出就走兜底」＝ 写了永远执行不到的死代码

**症状**：整个 env 解不出来，`Could not solve for environment specs`。

```
r-base =4.5 requires gsl >=2.7,<2.8
r-lisi 1.0 would require r-base >=4.1,<4.2 / >=4.2,<4.3 / >=4.3,<4.4 / >=4.4,<4.5
  ⇒ 全部与 r-base=4.5 冲突
```

**根因**：`r-lisi` 在 conda-forge 上只有 R 4.1~4.4 的构建，而 yaml 钉死 `r-base=4.5`。
yaml 里那一行的注释是：

```yaml
- r-lisi     # 若 conda 无此包，1_setup_env.sh 会走 GitHub 兜底
```

兜底**确实写了**（`1_setup_env.sh` 的 GitHub 列表里有 `lisi = "immunogenomics/LISI"`），
但 **env 创建本身就失败了，兜底那行代码永远没有机会执行**。
「可能装不上」和「列为硬依赖」是互相矛盾的两件事。

**⚠ 这类失败的杀伤力远大于单个包装不上**：缺一个 R 包只是少一个功能，
解不出来是**整个 env 一个包都不装**。

**修法**：
- 拿不准能否从 conda 装的包，**不要写进 `dependencies`**，只留在脚本的 GitHub/兜底列表里，
  并在 yaml 里用注释说明它去哪了。
- 判据：yaml 里任何带「若…则走兜底」「可能装不上」注释的硬依赖，都是这个坑。
- 钉死 `r-base=<版本>` 时，**先确认每个 R 包在该版本下有构建**：
  `mamba repoquery search 'r-lisi' --channel conda-forge` 看 build string 里的 `r4x`。

---

## §2e 批量 `install_github` 会打爆 GitHub 未认证 API 限额（60 次/小时）

**症状**：包一个接一个装失败，报错文案却指向"包不存在"：

```
[FAIL] SeuratWrappers Failed to install 'unknown package' from GitHub:
  HTTP error 403.
  API rate limit exceeded for <你的公网 IP>.
  Rate limit remaining: 0/60
  Rate limit reset at: 2026-09-17 19:33:18 UTC
```

**⚠ `Failed to install 'unknown package'` 这句话极具误导性** —— 看起来像包名写错或仓库不存在，
实际跟包毫无关系。**必须往下多读两行**才看得到 `403` 和 `rate limit`。

**根因**：未认证的 GitHub API 是 **60 次/小时/IP**。`remotes::install_github()` 每装一个包
要打好几次 API（查 ref、取 tarball、查依赖），一份 10 个包的列表加上传递依赖，
**一轮就能耗掉大半**；失败后重跑一轮必然打满。

**危害在于它伪装成别的问题**：本轮日志里这批失败紧跟在"缺 C 库"那批之后，
极容易被读成"C 库没修好"，从而去改根本没错的东西。
**判据：本轮有没有出现 `ERROR: configuration failed` / `compilation failed`。
没有编译错误却整批失败 ⇒ 先查 403，不要碰 C 库。**

**修法**：
1. 设 `GITHUB_PAT`（或 `GITHUB_TOKEN`）走认证请求，限额升到 5000/小时：
   ```bash
   export GITHUB_PAT=$(gh auth token)      # 本机若无 gh CLI 则此路不通
   ```
   R 侧 `remotes` 会自动读这两个环境变量。**token 只进环境变量，不写进脚本、不打印、不提交。**
2. 没有 token 就等重置（报错里给了 `Rate limit reset at`，是 UTC，注意换算本地时区），
   重跑时**只重试缺的那几个包**，别整轮重来 —— 整轮重来会把刚恢复的限额再打光。
3. 结构性预防：能用 conda/CRAN/Bioconductor 装的一律别走 GitHub（见 §2 结尾那条），
   GitHub 列表越短，撞限额的概率越低。

---

## §2f conda 的 R 包配方只保证 `library(X)` 能加载，不保证 X 的函数都能调用

2026-09-17 proj23 首次跑 20 章教程实测，**同一个模式撞了两次**：

| 缺的包 | 谁在运行时才要它 | 报错出现在 |
| :--- | :--- | :---: |
| `metap`（连带 `multtest`、`mutoss`） | `Seurat::FindConservedMarkers()` | **第 10 章** |
| `scrapper` | `SingleR::SingleR()`（2.12 起换的打分后端） | **第 12 章** |

两次都是：`library(Seurat)` / `library(SingleR)` **完全正常**，
`1_setup_env.sh` 的逐包 `library()` 验证**全绿**，跑到一半调用具体函数时才炸：

```
! Please install the metap package to use FindConservedMarkers.
! there is no package called 'scrapper'
```

**根因**：conda-forge / bioconda 的配方对应的是上游 DESCRIPTION 的 `Depends`/`Imports`，
而这两个包分别落在 `Suggests`（metap）和"某个后端函数才 loadNamespace"（scrapper）里。
**配方没错，是"能装上"与"能用"本来就不是同一件事。**

**代价不是重装，是重跑**：第 10 章之前的九章算力全部白花
（本轮 ≈ 1 小时，含 4 种整合方法与 SCTransform）。

**修法 —— 验证清单要覆盖「会被调用的东西」，不是「会被 library 的东西」**：

```r
## 安装段：这些不在任何 yaml 里，必须显式补
for (p in c("multtest", "scrapper"))
  if (!requireNamespace(p, quietly = TRUE))
    BiocManager::install(p, ask = FALSE, update = FALSE)
for (p in c("mutoss", "metap"))
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)

## 验证段：加进逐包 library() 的向量里，缺了就让脚本 fail
pkgs <- c(..., "metap", "multtest", "scrapper", ...)
```

**更省事的预检**：在渲染/跑分析之前，把所有章节里出现的函数名做一次静态反查
（`getNamespaceExports()` 逐包比对），0 秒算力就能找出这一类。
实现与两个必踩的实现坑见 `23_R_based_scRNA_tutorial_2026/docs/P23_run_and_troubleshooting_log_0917.md` §6。

**⚠ 用 R 侧装而不是 mamba 装**：这类补丁包用 `BiocManager::install()` / `install.packages()`
装进 env 的 R library，不会让 conda 解算器重新求解整个 env
（一个刚验证通过的 47 包 env，不值得为一个 Suggests 冒牵连升级的风险）。

---

## §3 env 隔离切断共享的 Bioconductor 依赖

**症状**：`ERROR: dependency ‘SpatialExperiment’ is not available for package ‘Banksy’`，
而 `SpatialExperiment` 明明装过 —— 装在**另一个** env（`spatial_r`）里。

**根因**：按 yaml 分环境建是对的，proj23 的注释写明了理由：monocle3 走 GitHub 编译，
锁死一组 Matrix/irlba/igraph 版本，塞进 Seurat 5 主栈里 mamba
「要么解不出来，要么给出一个把 Seurat 降级到 4.x 的解，那样主线 19 章全废」。
**但隔离是双向的**：挡得住版本冲突，也挡得住共享依赖。

**修法**：不要为了省事去合并 env（那是用主线换便利）。缺哪个就往需要它的那个 env 里补装，
并把它写进该 env 的 yaml。

---

## §4 脚本头部的耗时估计通常只算了 conda 阶段

proj23 脚本头写「主 env 25~40 min」，实测 conda 阶段确实在范围内，但之后的 GitHub 阶段
被 `Azimuth` 拖进两个重型注释包（`BSgenome.Hsapiens.UCSC.hg38` ≈700 MB、`EnsDb.Hsapiens.v86`），
从 Bioconductor 源码装，把总时长拉长一倍以上。

**判据**：报预计耗时时，把「conda solve+install」和「GitHub/源码编译阶段」分开报，
后者的时长由最重的那个注释/参考数据包决定，**与依赖条数无关**。

---

## §5 监控过滤词用子串匹配会误报，但不要因此收紧

看门狗 `grep -E 'conflict'` 命中了包名 `r-conflicted`（tidyverse 那个处理函数名冲突的包），
报成"求解冲突"。真正的失败信号是 `Could not solve` / `PackagesNotFound`。

**结论：不改。** 这类误报方向是安全的（宁可多报不可漏报），收紧过滤词反而可能漏掉真冲突。
**误报要靠人看一眼排除，漏报没有任何机制能补救。**

---

## §6 开建前检查清单

| # | 检查 | 命令 / 判据 |
| :--- | :---: | :---: |
| 1 | 目标 env 是否已存在 | `ls <prefix>/bin/Rscript`；已存在就别重建，往里补装 |
| 2 | 脚本是否非交互 | `grep -n 'env create' <script>` 看有没有 `-y` |
| 3 | yaml 是否声明了 C 库 | 对每个 GitHub 包查 `configure` 需求 |
| 4 | 磁盘 | 单个 R+Bioc env 约 5~9 GiB，三个约 15~20 GiB |
| 5 | 启动后第一次核实 | **`tmux capture-pane`，不是 `tail 日志`** |
| 6 | 完成后验收 | 逐包 `packageVersion()` 或读 `DESCRIPTION` 的 `Version:`，**不看脚本自报的 ok，也不看 exit code** |
| 7 | 中途被打断 | 未建完的前缀留下半成品目录；重跑前必须删掉，否则 `[skip] 已存在` 守卫会把半成品当成建好的放过去 |

---

## 相关

- 同名 env 解析错解释器 → [conda_env_duplicate_names.md](conda_env_duplicate_names.md)
  （本轮两个脚本全程用 `-p 绝对路径` 正是为了躲这个）
- `conda run` 的子进程隔离 → [conda_run.md](conda_run.md)
- `tee` 写不存在的目录静默失败 → [tmux.md](tmux.md)
- 「某源上没有这个包」凭印象断言的代价 → [leafcutter.md](leafcutter.md)

**同日其它坑（不在本文，只索引，避免重复）**：
- ambient RNA 污染比例 ρ 的循环论证（拿被测变量自己的分位数圈背景细胞 ⇒ 恒为 0）
  → `~/.claude/skills/scrna/SKILL.md` §4 + memory `feedback_zero_result_prove_denominator`
- RCTD 丢弃低 UMI spot 后按位置重新赋 spot ID ⇒ 整体错位 → `~/.claude/skills/spatial/SKILL.md` §4
- `sc.pp.scrublet` 在 `threshold=None` 时硬依赖 skimage → `~/.claude/skills/scrna/SKILL.md` §3.2
- `sanity_report` 只看倍数差不看方向，对"故意很差的对照组"误报 → 同上 §4
- **notebook 里 `del adata.layers["x"]` 不幂等**：创建与删除隔在两个 cell，重跑删除那格就 `KeyError`；
  跟"漏跑上游格子"报错完全相同、无法区分 ⇒ 一律写成 `if "x" in adata.layers: del ...`。
  实例见 `22_python_based_scRNA_tutorial/notebooks/02_preprocessing/2-4_dimensionality_reduction.py:323`
