# R 与 Python 的中立比对：各自真正强在哪、代价是什么

> 建立日期：2026-09-17
> **写作视角：中立。** 不假设读者以哪一边为母语，也不预设结论。
> 目的是**选型**——面对一个新任务，判断该用哪一边，以及代价是什么。
> 姊妹篇（有方向性的迁移指南）：
> - [R_to_Python_stats_and_plotting.md](R_to_Python_stats_and_plotting.md)（R → Python）
> - [Python_to_R_migration.md](Python_to_R_migration.md)（Python → R）
> - [Python_core_modules_for_bioinformatics.md](Python_core_modules_for_bioinformatics.md)（Python 侧生态分层）
>
> 性能数字为 **2026-09-17 本机实测**（5,000,000 行 × 4 列，225 MB CSV，各跑 3 次取最小值与中位数），
> 环境与完整脚本见 §7。

---

## §0 结论：语言之间的差距，小于同一语言内选错工具的差距

这是本文最重要的一条，而且是**实测逼出来的结论**，不是立场。

同一个任务（500 万行分组聚合、读 225 MB CSV），两边的**最优工具性能在同一量级**；
但**同一语言内部选错工具，差距可以到两个数量级**：

| 操作 | 最快 | 最慢 | 倍数 |
| :--- | :---: | :---: | :---: |
| 读 225 MB CSV | polars 0.078 s | **base R `read.csv` 24.7 s** | **317×** |
| 读 225 MB CSV（各语言内部） | R `fread` 0.171 s | R `read.csv` 24.7 s | **145×**（同为 R） |
| 读 225 MB CSV（各语言内部） | `read_csv(engine="pyarrow")` 0.182 s | `pd.read_csv` 默认 1.655 s | **9×**（同为 Python） |
| 分组聚合（10 万组） | data.table 0.085 s | **dplyr 1.568 s** | **18×**（同为 R） |
| 分组聚合（10 万组，跨语言最优对最优） | data.table 0.085 s | pandas 0.135 s | **1.6×** |

**所以"R 慢还是 Python 慢"是个伪问题。** 真正决定性能的是：
`fread`/`polars` 还是 `read.csv`；`data.table` 还是 `dplyr`；向量化还是 `for` 循环。

### §0.1 那什么才是真正的选型依据

去掉性能这个伪变量之后，剩下的差异是实打实的：

| 维度 | 更强的一边 | 差距大小 |
| :--- | :---: | :---: |
| 统计方法的**广度与前沿性** | **R** | 大 |
| 生信的**成熟统计方法**（bulk DE、富集、多重检验框架） | **R**（Bioconductor） | 大 |
| **单细胞 / 大规模矩阵 / 深度学习** | **Python** | 大 |
| **工程化**（CLI、管线、测试、部署） | **Python** | 大 |
| **序列 / BAM / VCF 文件处理** | **Python** | 中 |
| **声明式作图**（图形语法） | **R**（ggplot2） | 中 |
| **包管理与依赖可复现性** | **R**（见 §3.3，这条常被低估） | 中 |
| 数据处理表达力 | 平手（`data.table`/`dplyr` vs `pandas`/`polars`） | 小 |
| 数值计算性能 | 平手（都落到同一批 BLAS/LAPACK） | 小 |

### §0.2 一句话选型

> **数据在"样本 × 特征"这个尺度上做统计推断 → R。
> 数据在"细胞 / 读段 / 文件"这个尺度上做工程化处理 → Python。**

分界线不是语言好坏，是**问题的尺度和形态**。

---

## §1 设计哲学：两种不同的"默认应该方便什么"

| | R | Python |
| :--- | :---: | :---: |
| 出身 | 1993 年，为**统计学家**设计（S 语言的自由实现） | 1991 年，为**通用编程**设计 |
| 核心假设 | "用户手上有一张表，想做统计" | "用户在写程序" |
| 一等公民 | 向量、`data.frame`、**公式 `y ~ x`** | 对象、`list`/`dict`、**迭代器** |
| 默认方便什么 | 交互式探索、一行出统计结果 | 组织代码、复用、部署 |
| 默认不方便什么 | 写大型程序、命名空间管理 | 一行做完一个统计分析 |
| 演化方式 | 由统计学界驱动，**新方法先有 R 包** | 由工业界驱动，**新工程能力先有 Python 库** |

### §1.1 这个差异的具体表现

**R 的极致例子**——一行完成"拟合 + 推断 + 排版"：

```r
summary(lm(expr ~ treatment + batch, data = d))
```

**Python 的等价写法**需要先决定"这归哪个库管"：

```python
import statsmodels.formula.api as smf
smf.ols("expr ~ treatment + batch", data=d).fit().summary()
```

多的不只是一行 import——是**你必须先知道**回归归 `statsmodels`（不是 `scipy`，也不是 `sklearn`）。
R 里没有这个决策负担，因为统计就是语言本身。

**Python 的极致例子**——把分析变成可复用的命令行工具：

```python
# analyze.py
import argparse
from pathlib import Path
p = argparse.ArgumentParser()
p.add_argument("--input", type=Path, required=True)
p.add_argument("--fdr", type=float, default=0.05)
args = p.parse_args()
```

R 里对应的 `optparse` / `argparse` 包能做同样的事，但**生态惯性不在这边**：
nf-core 的模块、Snakemake、Docker 镜像、CI，默认都假设你写的是 Python 或 shell。

### §1.2 一个常被忽略的哲学差异：缺失值

| | R | Python |
| :--- | :---: | :---: |
| `NA` 是什么 | **语言级的一等公民**，每种类型都有自己的 NA | `np.nan` 只是一个**浮点数值**；整数数组放不下 |
| 默认行为 | **阻断计算**：`mean(c(1,NA))` 返回 `NA` | `np.mean` 返回 `nan`；**但 `pd.Series.mean()` 静默丢弃** |
| 设计意图 | 逼你显式处理缺失 | 让分析顺畅进行 |

**这不是谁对谁错，是两种立场。** 但它的后果不对称：
R 的方式会让你**多写 `na.rm=TRUE`**；pandas 的方式会让你**样本量悄悄变小而不自知**。
做临床或小样本分析时，R 的这个默认值是真正的优势。

---

## §2 性能实测（本机，2026-09-17）

### §2.1 测试设置

| 项 | 值 |
| :--- | :---: |
| 数据 | 5,000,000 行 × 4 列（int key 10 万组、4 水平字符列、2 个 float64） |
| CSV 大小 | 225 MB |
| 重复 | 每项 3 次，报告 **min** 与 **median** |
| R | 4.5.2，data.table 1.17.8（**限 8 线程**），dplyr 1.2.0 |
| Python | 3.11.16 / 3.10.20，pandas 2.3.3，polars 1.39.2 |

### §2.2 读 CSV

| 工具 | min | median | 相对最快 |
| :--- | :---: | :---: | :---: |
| `polars.read_csv` | **0.078 s** | 0.083 s | **1.0×** |
| R `data.table::fread` | 0.171 s | 0.263 s | 2.2× |
| `pd.read_csv(engine="pyarrow")` | 0.182 s | 0.196 s | 2.3× |
| `pd.read_csv`（默认 C 引擎） | 1.655 s | 1.662 s | 21× |
| R `read.csv`（base） | **24.72 s**（单次） | — | **317×** |

**两条可直接照做的结论：**

1. **R 里永远不要用 `read.csv`**，用 `data.table::fread`（或 `readr::read_csv`）。145 倍不是调优，是换函数。
2. **pandas 读大 CSV 加 `engine="pyarrow"`**，9 倍提速，一个参数的事（需要装 `pyarrow`）。

### §2.3 分组聚合（10 万组）

| 工具 | min | median | 相对最快 |
| :--- | :---: | :---: | :---: |
| `polars.group_by` | **0.081 s** | 0.104 s | 1.0× |
| R `data.table` `keyby=` | 0.085 s | 0.091 s | 1.05× |
| R `data.table` `by=` | 0.108 s | 0.126 s | 1.3× |
| `pandas.groupby` | 0.135 s | 0.166 s | 1.7× |
| R `dplyr::group_by + summarise` | **1.568 s** | 1.580 s | **19×** |

**data.table、polars、pandas 在同一量级**（0.08–0.17 s），差别在实务上可忽略。
**dplyr 是唯一的离群点**——慢一个数量级。这是它为可读性和惰性求值付出的代价，
在几十万行以下完全无感，到千万行级就成了瓶颈。

> ⚠️ **我没有测的东西**：更大数据（超内存）、复杂 join、窗口函数、字符串密集操作。
> 这几项的排序**可能不同**，尤其 polars 的惰性执行（`scan_csv` + `LazyFrame`）在超内存场景有结构性优势，
> 而我这里测的是全内存。**不要把这张表外推到我没测的场景。**

### §2.4 内存占用

| | 占用 |
| :--- | :---: |
| R `data.table`（`object.size`） | 134 MB |
| pandas（`memory_usage()`，不含对象列真实大小） | 153 MB |
| pandas（`memory_usage(deep=True)`，含字符串） | **391 MB** |

**pandas 的字符串列是重灾区**：同一份数据，把 4 个不同字符串当 object 存，
深度统计是浅统计的 2.6 倍。R 的 `character` 有全局字符串缓存（CHARSXP cache），天然去重。

**pandas 的解法**：把低基数字符串列转成 `category`（对应 R 的 `factor`）：

```python
df["grp"] = df["grp"].astype("category")     # 几乎总是该做
```

### §2.5 🔴 线程默认值：两边都超出本机 28 核 / 56 线程的政策上限

**本机实测**：

| 工具 | 默认线程数 | 是否超限 |
| :--- | :---: | :---: |
| `data.table`（`getDTthreads()`） | **32** | 单独跑不超，**并跑会超** |
| `polars`（`pl.thread_pool_size()`） | **64** | 🔴 **直接超过 56 硬顶** |
| pandas | 1（单线程） | 否 |
| numpy / BLAS | 取决于 `OMP_NUM_THREADS` | 需显式限制 |

**两边都默认"把机器吃满"**，这与"永远留 ≥2 核 / 4 线程给 OS 和交互"的要求冲突。

```r
data.table::setDTthreads(8)        # R：脚本开头就设
```
```python
import os
os.environ["POLARS_MAX_THREADS"] = "8"    # 必须在 import polars 之前
os.environ["OMP_NUM_THREADS"]    = "8"    # 管住 numpy/BLAS
import polars as pl
```

> `POLARS_MAX_THREADS` **必须在 `import polars` 之前设**，之后设无效——
> 线程池在 import 时就建好了。这是个静默失效的坑。

---

## §3 生态：三条最实质的差异

### §3.1 统计方法的广度：R 明显领先

| | R | Python |
| :--- | :---: | :---: |
| 包总量 | **CRAN 25,037 个**（本机实测 2026-09-17） | PyPI 数量更大，但**统计类占比低得多** |
| 新统计方法 | 通常**先有 R 实现**（论文附带 R 包是惯例） | 常滞后，或永远没有 |
| 混合模型 | `lme4` / `nlme`，成熟且被广泛验证 | `statsmodels.mixedlm`，功能子集，语法不兼容 `lme4` |
| 生存分析 | `survival` / `survminer`，事实标准 | `lifelines`，可用但生态薄 |
| 贝叶斯 | `brms` / `rstanarm`（公式接口直通 Stan） | `PyMC` / `NumPyro`，强大但要手写模型 |
| 多重比较 / 事后检验 | `emmeans`（极强） | 无等价物 |

**`emmeans` 是一个值得单独点名的例子**：估计边际均值 + 各种事后比较 + 自动处理对比编码，
Python 侧**没有可比的东西**。做析因设计、交互项事后检验时，这一个包就足以决定用 R。

### §3.2 生信生态：Bioconductor vs 零散

| | R | Python |
| :--- | :---: | :---: |
| 组织方式 | **Bioconductor**：统一的发布周期、统一的对象体系、强制的文档与测试 | PyPI 上各自为战，无统一对象体系 |
| 核心对象 | `SummarizedExperiment` / `SingleCellExperiment`（**跨包通用**） | `AnnData`（仅 Scanpy 系）；其余各用各的 |
| bulk DE | `DESeq2` / `edgeR` / `limma`——**审稿人默认接受** | `pydeseq2`（重实现，接受度较低） |
| 富集分析 | `clusterProfiler`（本机 4.18.4） | `gseapy` 等，功能与可视化都更薄 |
| 单细胞 | `Seurat`（生态大但内存吃紧） | **`Scanpy` + `AnnData`（大数据量下优势明显）** |
| 空间转录组 | 有，但落后 | **`squidpy` / `spatialdata` 更活跃** |

**Bioconductor 的真正价值不是包多，是"统一的对象体系 + 统一的发布周期"**：
`SummarizedExperiment` 让不同作者的包可以直接对接，而 Python 侧
"这个包吃 DataFrame、那个包吃 ndarray、另一个吃 AnnData"是常态。

**但在单细胞上，这个优势被 Python 反超了**——数据量到十万细胞级时，
`AnnData` + 稀疏矩阵 + `Scanpy` 的内存效率是结构性优势，`Seurat` 会先撞内存墙。

### §3.3 可复现性：R 的优势常被低估

这一条很少被讨论，但对**几年后还要重跑**的分析非常关键。

| | R | Python |
| :--- | :---: | :---: |
| 版本快照 | **Bioconductor 每年两次统一发布**，一个版本号锁定整套包的兼容组合 | 无等价机制；每个包独立发版 |
| 依赖冲突 | 相对少（Bioconductor 内部做兼容性测试） | 常见；`conda` 解依赖可能耗时很久 |
| 环境锁定 | `renv`（lockfile） | `conda env export` / `uv lock` / `requirements.txt`，**多套方案并存** |
| 破坏性变更 | base R 极其保守，十年前的代码大多还能跑 | **numpy 2.0 移除了 `np.float_` / `np.in1d`** 等老别名；生态跟进不一 |

> **本机的一个具体例证**：两个环境跨了 numpy 主版本（`regular_bioinfo` 是 1.26.4，
> `sc_tut_main` 是 2.4.6），用到 `np.float_`、`np.in1d` 的旧脚本在后者直接报错。
> R 侧没有对应量级的断裂。
>
> **公平地说另一面**：R 的保守也意味着语言层面的设计缺陷（§4.1）几乎永远不会被修掉。

---

## §4 各自真正的痛点（都要说）

### §4.1 R 的痛点

| 痛点 | 具体表现 | 能绕过吗 |
| :--- | :---: | :---: |
| **语言级设计缺陷无法修** | `as.numeric(factor)` 返回编码不是值；`1:0` 给出 `c(1,0)`；`sapply` 返回类型不确定；`$` 部分匹配静默生效；`T`/`F` 可被重新赋值 | 只能靠纪律（`seq_len`、`vapply`、`TRUE`/`FALSE`） |
| **内存吃紧** | 值语义 + 频繁复制；大对象容易翻倍 | `data.table` 的 `:=` 引用修改 |
| **工程化生态薄** | 测试、打包、CLI、容器化的社区惯例远不如 Python | `testthat` + `renv` 能用，但生态惯性不在这边 |
| **并行笨重** | `parallel`/`future` 比 Python 的 `joblib`/`multiprocessing` 更啰嗦 | — |
| **字符串处理弱** | 正则接口分裂（base vs `stringr`），性能一般 | `stringr`/`stringi` |
| **三套数据框方言** | `data.frame` / `tibble` / `data.table` 语法互不兼容 | 团队内统一一种 |

### §4.2 Python 的痛点

| 痛点 | 具体表现 | 能绕过吗 |
| :--- | :---: | :---: |
| **统计推断是二等公民** | 回归要 `statsmodels`、预测要 `sklearn`、检验要 `scipy`，三套 API 风格不一 | 只能熟记归属 |
| **pandas 的 API 混乱** | `loc`/`iloc`/`at`/`iat`；view vs copy 不确定；`axis=0` 在聚合和删除里读法不同 | `polars` 的 API 一致得多 |
| **NA 静默丢弃** | `pd.Series.mean()` 默认 `skipna=True` | 显式 `skipna=False` + assert |
| **整数列放不下 NA** | int 列混入 NaN 静默变 float64 | `dtype="Int64"` |
| **绘图没有图形语法** | matplotlib 是命令式；多 panel 配色要手工统一 | `plotnine` / `seaborn.objects` |
| **环境管理复杂** | conda/pip/uv/poetry 多套并存；本机甚至出现 `conda run -n` 被 PATH 绕过 | 用绝对解释器路径自证 |
| **破坏性升级** | numpy 2.0 的 ABI 断裂 | 环境隔离，不合并 |

### §4.3 一个公平的观察

**两边的痛点性质不同：**

- **R 的痛点大多在"语言本身"**——无法修复，但**可以靠纪律完全规避**，而且一旦学会就不再犯。
- **Python 的痛点大多在"库的边界"**——可以靠换库改善（polars 替 pandas、plotnine 替 matplotlib），
  但**边界会随生态演化不断出现新的**。

哪种更难受因人而异。做长期维护的项目，R 的"缺陷是固定的"反而是一种确定性。

---

## §5 选型决策表

### §5.1 按任务

| 任务 | 建议 | 理由强度 |
| :--- | :---: | :---: |
| bulk RNAseq 差异表达 | **R**（DESeq2 / edgeR / limma） | 强——审稿人默认接受 |
| 富集 / 通路分析 | **R**（clusterProfiler） | 强 |
| 复杂实验设计的统计推断（交互、事后比较、混合模型） | **R**（`emmeans` / `lme4`） | 强——Python 无等价物 |
| 生存分析 | **R**（`survival`） | 中 |
| 单细胞（万级以上细胞） | **Python**（Scanpy + AnnData） | 强——内存与性能 |
| 空间转录组 | **Python**（squidpy / spatialdata） | 中 |
| 深度学习 / 大模型 | **Python** | 强——R 侧基本没有 |
| 序列 / BAM / VCF 处理 | **Python**（pysam / Biopython） | 强 |
| 管线编排、批处理、CLI 工具 | **Python** | 强 |
| 出版级统计图 | **R**（ggplot2）或 Python（plotnine） | 中 |
| 探索性数据处理 | **平手** | — |
| 超大表格（千万行以上） | **平手**：`data.table` 或 `polars` | — |

### §5.2 按你的处境

| 情况 | 建议 |
| :--- | :---: |
| 一次性分析，团队都用同一种 | **用团队那种**，语言选择的收益小于协作成本 |
| 要交给别人长期维护 | 看**维护者**会哪种，不看你会哪种 |
| 方法学创新，要实现论文里的新方法 | **先查 R 有没有现成包**，通常有 |
| 要嵌进 nf-core / Snakemake 管线 | **Python 或 shell**，生态惯性在这边 |
| 数据量在内存边缘 | **polars（惰性）或 data.table**，都不要用 dplyr/默认 pandas |

---

## §6 双语共存：文件桥，不要进程内桥

真实项目里很少纯用一边。**推荐的连接方式是"文件桥"而不是"进程内互调"。**

| 方式 | 评价 |
| :--- | :---: |
| **文件桥**（一边写 CSV / Parquet / H5AD，另一边读） | ✅ **推荐**：可断点续、可独立复现、出错定位清楚、不受两边版本耦合影响 |
| `rpy2`（Python 里嵌 R） | ⚠️ 不推荐：版本耦合紧、错误信息难读、环境一变就崩 |
| `reticulate`（R 里嵌 Python） | ⚠️ 同上 |

### §6.1 推荐的交换格式

| 数据类型 | 格式 | 两边的读写 |
| :--- | :---: | :---: |
| 普通表格 | **Parquet** | R `arrow::read_parquet` ↔ Python `pd.read_parquet` |
| 普通表格（求简单） | CSV | R `fread` ↔ Python `read_csv`（注意 CSV 丢 dtype） |
| 计数矩阵 | CSV 或 `.mtx` | — |
| 单细胞对象 | `.h5ad` ↔ `SingleCellExperiment` | 经 `zellkonverter` 或手工转换 |

### §6.2 🔴 跨语言搬单细胞数据的头号陷阱

| 生态 | 维度约定 |
| :--- | :---: |
| AnnData / Scanpy（Python） | **细胞 × 基因** |
| Seurat / SingleCellExperiment（R） | **基因 × 细胞** |

**两边是转置关系。** 转置后代码照跑、图照出，所有生物学结论都是错的；
细胞数恰好等于基因数时连报错都没有。**跨语言搬数据必须显式转置并 assert 维度。**

### §6.3 文件桥的纪律

```python
# 写出的一侧：把形状和关键统计量一起写出来
meta = {"n_obs": adata.n_obs, "n_var": adata.n_vars,
        "sum_counts": float(adata.X.sum())}
json.dump(meta, open("bridge_meta.json", "w"))
```
```r
# 读入的一侧：读进来立刻核对
meta <- jsonlite::fromJSON("bridge_meta.json")
stopifnot(ncol(mat) == meta$n_obs, nrow(mat) == meta$n_var)
stopifnot(abs(sum(mat) - meta$sum_counts) < 1e-6)
```

**这三行 `stopifnot` 就能挡掉 §6.2 的转置错误**，代价接近于零。

---

## §7 实测环境与复现

| 侧 | 路径 | 版本 |
| :--- | :---: | :---: |
| R | `/Work_bio/gao/configs/.conda/envs/DE_R45` | R 4.5.2；data.table 1.17.8；dplyr 1.2.0；ggplot2 4.0.2；DESeq2 1.50.2；clusterProfiler 4.18.4；SummarizedExperiment 1.40.0；**已装 254 个包** |
| Python | `/mnt/ex_8T_SSD/conda_envs/sc_tut_main` | Python 3.11.16；pandas 2.3.3；numpy 2.4.6；pyarrow 25.0.1 |
| Python | `/Work_bio/gao/configs/.conda/envs/regular_bioinfo` | Python 3.10.20；polars 1.39.2；numpy 1.26.4 |

### §7.1 ⚠️ 探测时必须用绝对解释器路径

本机 `conda run -n <env>` 存在被 `PATH` 注入绕过的情况（`-n` 与 `-p` 都失效且不报错），
详见 [Python_core_modules_for_bioinformatics.md](Python_core_modules_for_bioinformatics.md) §8.1。

### §7.2 基准复现

```bash
# 1) 生成测试数据（225 MB）
/mnt/ex_8T_SSD/conda_envs/sc_tut_main/bin/python -c "
import numpy as np, pandas as pd
rng = np.random.default_rng(42); n = 5_000_000
pd.DataFrame({'key': rng.integers(0,100_000,n),
              'grp': rng.choice(list('abcd'), n),
              'v1': rng.normal(size=n),
              'v2': rng.normal(size=n)}).to_csv('bench.csv', index=False)"

# 2) R 侧
/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript -e '
suppressMessages(library(data.table)); setDTthreads(8)
dt <- fread("bench.csv")
print(system.time(dt[, .(s=sum(v1), m=mean(v2)), by=key]))'

# 3) Python 侧
/mnt/ex_8T_SSD/conda_envs/sc_tut_main/bin/python -c "
import pandas as pd, time
df = pd.read_csv('bench.csv')
t0=time.perf_counter()
df.groupby('key', sort=False).agg(s=('v1','sum'), m=('v2','mean'))
print('%.3f s' % (time.perf_counter()-t0))"
```

---

## §8 本文的事实来源

| 内容 | 来源 |
| :--- | :---: |
| §0 / §2 全部性能数字与内存占用 | **2026-09-17 本机实测**，n=3 取 min/median，脚本见 §7.2 |
| 线程默认值（data.table 32、polars 64） | **2026-09-17 实测**（`getDTthreads()` / `pl.thread_pool_size()`） |
| CRAN 25,037 个可用包、本机已装 254 个、各包版本号 | **2026-09-17 实测** |
| numpy 2.0 移除 `np.float_` / `np.in1d` | **2026-09-17 双环境实测** |
| pandas 字符串列内存 391 MB vs 153 MB | **2026-09-17 实测**（`memory_usage(deep=True)`） |
| §1 设计哲学、§3 生态组织方式 | 上游文档与社区共识，**非实测** |
| §3.1 "新统计方法通常先有 R 实现" | **我的判断**，未做系统统计 |
| §3.2 "Seurat 在十万细胞级先撞内存墙" | **我的判断**，本机未做该规模对比测试 |
| §4 两边的痛点清单 | **我的判断**，部分条目（R 的语言缺陷、numpy 2 断裂）有实测支撑，其余为经验 |
| §5 选型建议 | **我的判断** |
| §6 "文件桥优于 rpy2/reticulate" | **我的判断**，本机未做稳定性对比测试 |
