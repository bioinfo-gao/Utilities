# 用 .Rprofile 补上 conda 环境变量：Positron 里跑 conda R 的必要设置

建立 / 实测：2026-11-22，p53 教程书（`/mnt/ex_8T_SSD/projects_2026Q4/53_R-for-Bioinformatics-Tutorial-Detailed`）
相关笔记：同目录 `R_in_Positron_in_tailscale.sh`（解释器选不到 ⇒ 登记 `positron.r.customBinaries`）

## 结论先说

- **Positron 直接启动 `<env>/bin/R`，不做 `conda activate`** ⇒ 用 `conda env config vars set` 设在环境里的变量**全部不生效**，且**没有任何提示**。
- 最要紧的后果是 **BLAS 线程不受限**：实测同一段矩阵乘法，不补变量时占 **35.2 核**（当时机器有别的负载，空闲时会更多），补上后 **7.8 核**。服务器的线程上限是 56 线程，矩阵运算一多就会挤占其他分析。
- 修法：在**项目根**放 `.Rprofile`，R 启动时检查这几个变量，缺了就补，并用 `RhpcBLASctl` 在运行中限制 BLAS 线程。
- ⚠ **`.Rprofile` 只在 R 启动时工作目录 = 项目根才会被读取。** Positron 的 R 会话工作目录取决于你打开的文件夹（见 §4）。

## 1. 为什么光 `Sys.setenv()` 不够

| 变量 | 作用 | 何时读取 | 只用 `Sys.setenv()` 够不够 |
| :--- | :---: | :---: | :---: |
| `OPENBLAS_NUM_THREADS` | OpenBLAS 线程数 | **OpenBLAS 库载入时读一次**，R 启动时就已载入 | ❌ 当前会话无效，只影响子进程；必须 `RhpcBLASctl::blas_set_num_threads()` |
| `OMP_NUM_THREADS` | OpenMP 线程数 | OpenMP 运行时初始化时 | ❌ 同上，用 `RhpcBLASctl::omp_set_num_threads()` |
| `R_USER_CACHE_DIR` | `tools::R_user_dir(..., "cache")` 的根，ExperimentHub / BiocFileCache / `scRNAseq` 数据集的缓存位置 | 每次调用时读 | ✅ |
| `XDG_CACHE_HOME` | 子进程（quarto/Deno）的缓存根；`~/.cache` 是软链接时 Deno KV 打不开 `sass.kv` | 子进程启动时 | ✅ |

查看某个环境设了哪些变量：`cat <env>/conda-meta/state`。

## 2. p53 的 `.Rprofile` 做了什么

文件：`/mnt/ex_8T_SSD/projects_2026Q4/53_R-for-Bioinformatics-Tutorial-Detailed/.Rprofile`

1. 对 4 个变量逐个检查，**只补缺失的**。终端里 `mamba activate` 过的会话保持原值，不被覆盖。
2. 用 `RhpcBLASctl` 把当前会话的 BLAS / OpenMP 线程限制到上面的值。p53_rbio 已装 `RhpcBLASctl`；没装时不报错，只在提示里写明"未限制"。
3. 交互会话启动时打印一行：`[p53 .Rprofile] 补设 4 个变量 (...); BLAS 线程=8`。**在 Console 里看到这一行才说明它生效了。**
4. 末尾 `source("~/.Rprofile")`（若存在）。原因：**存在项目级 `.Rprofile` 时，R 不再读用户级 `~/.Rprofile`**。目前 `~/.Rprofile` 不存在，这一行留作以后用。

数值的源头是项目里 `install-conda.sh` 的 `conda env config vars set` 那一行。**两处必须同改。**

## 3. 实测（2026-11-22）

用 `env -u` 清掉 4 个变量来模拟 Positron 的启动方式：

| 情形 | 4 个变量 | BLAS 线程 | ExperimentHub 缓存 | 实际占用核数 |
| :--- | :---: | :---: | :---: | :---: |
| A 未激活、工作目录 = 项目根 | 全部补上 | 8 | `/mnt/ex_8T_SSD/R_user_cache/R/ExperimentHub` | 7.8 |
| B 未激活、工作目录 = `/home/gao` | 全空（`.Rprofile` 未读） | 64 | `/home/gao/.cache/R/ExperimentHub` | 35.2 |
| C 已激活但 `OPENBLAS_NUM_THREADS=4` | 4 保留、其余照常 | 4 | 同 A | — |

- 占用核数 = 3000×3000 矩阵乘 6 次的 (user+sys)/elapsed。
- `/proc/<pid>/task` 里看到的 64 个线程是 OpenBLAS 启动时预建的线程池，**不代表实际并行度**，不能拿它判断限制是否生效。
- **尚未在 Positron 界面里实测**：当时没有运行中的 Positron R 会话，§4 的工作目录行为需要第一次使用时确认。

## 4. 让 Positron 读到 `.Rprofile`

Positron 的 R 会话在启动时工作目录 = 当前窗口打开的文件夹。多根工作区一般是**第一个**文件夹，现在是 `/home/gao`。这一行为未实测，见 §3。

| 做法 | 能否读到 p53 的 `.Rprofile` | 说明 |
| :--- | :---: | :--- |
| **File → Open Folder… 打开 p53 目录**（单独一个窗口） | ✅ | 推荐；Quarto 书项目本来也适合单独开 |
| 在现有多根工作区里打开 `.qmd` 直接跑 | 很可能 ❌ | 工作目录是 `/home/gao` |
| 会话已启动后 `setwd()` 到项目根 | ❌ | `.Rprofile` 只在启动时读；可手动 `source(".Rprofile")` 补救 |
| 改变工作目录后 Restart R Session | 取决于 Positron 重启时用的目录 | 不可靠，以 Console 里那行提示为准 |

**判据只有一个：Console 启动时是否打印 `[p53 .Rprofile] ...`。** 没打印 ⇒ 没生效，执行 `source("/mnt/ex_8T_SSD/projects_2026Q4/53_R-for-Bioinformatics-Tutorial-Detailed/.Rprofile")`。

### 不依赖工作目录的替代：环境级 `Rprofile.site`

把同样的逻辑放进 `<env>/lib/R/etc/Rprofile.site`：**只要启动这个 env 的 R 就会读，与工作目录无关**。

- 适合**专用于一个项目**的环境，比如 p53_rbio。
- 代价是它在项目 git 之外，重建环境会丢；要写进 `install-conda.sh` 才能复现。
- p53_rbio 目前还没有这个文件。

## 5. 新建其他 conda R 环境时照做

1. 把 `<env>/bin/R` 登记进 Positron 的 `positron.r.customBinaries`（见 `R_in_Positron_in_tailscale.sh`）。
2. 若环境用 `conda env config vars set` 设了变量，项目根放一份同结构的 `.Rprofile`，把 `want <- c(...)` 换成该环境的值。
3. 环境里装 `r-rhpcblasctl`（conda-forge），否则 BLAS 线程限不住。
4. 第一次在 Positron 里启动，确认 Console 打印了那行提示。
