# 生物信息学里的 Python 通用与核心模块：谁管什么，分界线画在哪

> 建立日期：2026-09-17
> 用途：一份"生态地图"——说清做 RNAseq / 单细胞 / WGS 时会碰到的 Python 模块各自的**职责边界**，
> 以及边界被误解时会产生的**静默错误**。不是 API 手册，重点是"为什么是这么切的"。
> 姊妹篇：`/home/gao/Utilities/Python/Python_tabular_data_structures.md`（表格类数据结构的 8 种形态）
> 同目录另三篇：[R_to_Python_stats_and_plotting.md](R_to_Python_stats_and_plotting.md)（R→Python）· [R_vs_Python_neutral_comparison.md](R_vs_Python_neutral_comparison.md)（中立选型）· [Python_to_R_migration.md](Python_to_R_migration.md)（Python→R）
> 版本号与"装没装"均为**本机实测**，实测环境与命令见 §8。

---

## §0 一句话回答：只有一条分界线，其余都是它的推论

**Python 的科学栈不是按"功能领域"切的，是按「依赖方向」切的**——
下层不许依赖上层，所以每一层只能做"不需要上层概念"的事。

```
生信专用   Biopython · pysam · AnnData/Scanpy · pyDESeq2 · decoupler
              ↓ 依赖
统计 / 建模   statsmodels · scikit-learn · scipy.stats
              ↓ 依赖
数据结构     pandas · AnnData · pyarrow
              ↓ 依赖
数值底座     numpy   ←── 所有东西的地基，它不依赖任何人
                  ↘
绘图（旁路）  seaborn ──依赖──→ matplotlib        plotly 自成一路，不依赖 matplotlib
```

**这条依赖方向解释了 90% 的"为什么 X 在这个包而不在那个包"。**
典型三问的答案都在这里：

| 常见疑问 | 答案 | 根因 |
| :--- | :---: | :---: |
| numpy 有 `mean`/`std`，为什么没有 t 检验？ | 检验在 `scipy.stats` | 检验需要概率分布 → 需要 `scipy.special` 的 gamma/beta 函数；numpy 要保持"只有数组"的轻量地基 |
| scipy 有 `ttest_ind`，为什么没有线性回归诊断？ | 在 `statsmodels` | scipy 只做"一次算完就结束"的函数；回归需要**模型对象**（残差、AIC、预测区间），那是更上层的抽象 |
| seaborn 和 matplotlib 什么关系？ | seaborn **是** matplotlib 的上层封装，不是替代品 | seaborn 最终产出的就是 matplotlib 的 `Figure`/`Axes`，所以两者可以混着用 |

### 🔴 最要紧的三条（全文陷阱清单在 §9，这三条会**不报错地**产出错结果）

| # | 陷阱 | 为什么最危险 | 防法 |
| :--- | :---: | :---: | :---: |
| **1** | `np.std()` 默认 `ddof=0`（总体），`pandas` / R 的 `sd()` 默认 `ddof=1`（样本） | 数值只差几个百分点，看不出来；跨语言核对时会误判成"数据对不上" | 显式写 `ddof=`；见 §2.3 |
| **2** | seaborn 的 **figure-level 函数不接受 `ax=`** | 想拼多 panel 时静默失败或画到新图上；报错信息指向别处 | 拼图一律用 axes-level 函数；见 §5.3 |
| **3** | matplotlib 默认色环**每个 Axes 从头分配** | 多 panel 图里语义不同的类别拿到同一个颜色，读者默认"同色=同义" | 颜色显式映射成 dict，不靠默认顺序；见 §5.5 |

---

## §1 分层地图：七层，日常真正要掌握的是四层

| 层 | 模块 | 一句话职责 | 必须掌握 |
| :--- | :---: | :---: | :---: |
| ① 语言内核 | `pathlib` `itertools` `collections` `re` `gzip` `csv` | 标准库；不装任何东西就有 | ✅ |
| ② 数值底座 | **numpy** | ndarray 这个数据结构 + 元素级运算 + 轴向归约 | ✅ |
| ③ 科学算法 | **scipy** | 建在 ndarray 之上的算法集：`stats` `optimize` `sparse` `signal` `interpolate` | ✅ |
| ④ 数据结构 | **pandas** · `pyarrow` · `polars` | 带标签的异构表格、IO、分组聚合 | ✅ |
| ⑤ 统计 / 机器学习 | `statsmodels` · `scikit-learn` | 模型对象（公式接口、系数、诊断）/ 预测与降维 | ✅ |
| ⑥ 绘图 | **matplotlib** · **seaborn** · `plotly` | 渲染引擎 / 统计图语法 / 交互图 | ✅ |
| ⑦ 生信专用 | `Biopython` `pysam` `AnnData` `Scanpy` `pyDESeq2` `decoupler` | 序列、BAM/VCF、单细胞容器、差异表达、通路活性 | 按项目 |

**层内可以横向替换，跨层不能。** 例如 `polars` 可以替 `pandas`（同在第 4 层），
但 `polars` 替不了 `numpy`——它内部还是要落到数组上。

---

## §2 numpy 与 scipy：分界线不是"统计 vs 非统计"

这是最常被问错的一对。**正确的分界线是「数组上的一次归约运算」vs「需要分布理论或数值算法」。**

### §2.1 谁在哪

| 需求 | 在哪 | 例子 |
| :--- | :---: | :---: |
| 描述统计（均值 / 方差 / 分位数 / 相关） | numpy | `np.mean` `np.std` `np.median` `np.percentile` `np.corrcoef` `np.cov` `np.histogram` |
| 随机数生成 | numpy | `rng = np.random.default_rng(42); rng.normal(...)` |
| 线性代数 | numpy（基础）/ scipy（进阶） | `np.linalg.svd` / `scipy.linalg.eigh`（对称阵专用，更快更稳） |
| 概率分布对象（pdf / cdf / ppf / fit / rvs） | scipy | `scipy.stats.norm` `.nbinom` `.beta` `.hypergeom` |
| 假设检验 | scipy | `ttest_ind` `mannwhitneyu` `fisher_exact` `ks_2samp` `spearmanr` |
| 多重检验校正 | scipy（1.11+）/ statsmodels | `scipy.stats.false_discovery_control` / `statsmodels.stats.multitest.multipletests` |
| 稀疏矩阵 | scipy | `scipy.sparse.csr_matrix`（单细胞 counts 的标准载体） |
| 层次聚类 / 距离矩阵 | scipy | `scipy.cluster.hierarchy.linkage` `scipy.spatial.distance.pdist` |
| 回归 / 广义线性模型 / 混合模型 | statsmodels | `smf.ols` `sm.GLM(family=NegativeBinomial())` |

### §2.2 为什么这么切（依赖方向的必然结果）

numpy 的职责是 **ndarray 这个数据结构，以及在它上面的元素级运算和轴向归约**。
`mean` / `std` 之所以在 numpy，是因为它们本质上是 `sum` 的变体——**一次沿轴归约，不需要任何统计理论**。

scipy 的职责是 **建在 ndarray 之上的科学算法库**（`stats` 和 `optimize` `integrate` `sparse` `signal` 是**平级**的子包）。
`stats` 需要特殊函数（`scipy.special` 的 gamma、beta、erf）、数值优化（最大似然拟合）、精确算法（Fisher 检验的超几何枚举）——
这些都不属于"数组容器"的职责。

> **依赖是单向的：scipy 依赖 numpy，numpy 不依赖 scipy。**
> 如果把分布和检验塞进 numpy，numpy 就得把 `special` 和 `optimize` 一起吞进来，
> 那它就不再是一个轻量的数组库了——而 numpy 被**所有**科学包依赖，它变重，整个生态都变重。

### §2.3 🔴 `ddof` 陷阱（本机实测）

```python
x = np.array([1., 2., 3., 4.])
np.std(x)              # 1.118033988749895   ← ddof=0，总体标准差
pd.Series(x).std()     # 1.2909944487358056  ← ddof=1，样本标准差
np.std(x, ddof=1)      # 1.2909944487358056  ← 与 pandas / R 的 sd() 一致
```

**numpy 默认 `ddof=0`，pandas 和 R 的 `sd()` 默认 `ddof=1`。**
跨语言核对数字对不上时，第一个要查的是这里，不是数据。
`np.var` 同理。样本量越小差距越大（n=4 时差 15%）。

### §2.4 分位数口径

`np.percentile` 默认 `method='linear'`，与 R `quantile()` 的默认 type 7 一致；
但如果对方用了 type 6 或 SAS 口径就会有差。需要严格对齐时显式写 `method=`。

---

## §3 pandas：定位与三条静默陷阱

pandas 在第 4 层，本质是 **dict of Series**——列式存储，每列一个 dtype。
它是"异构表格"的默认选择，也是 IO 的总入口（`read_csv` / `read_excel` / `read_parquet`）。

**详细内容见姊妹篇** `/home/gao/Utilities/Python/Python_tabular_data_structures.md`，
那份文档讲了 8 种表格结构和 12 条陷阱。这里只重复最要命的三条：

| # | 陷阱 | 后果 | 防法 |
| :--- | :---: | :---: | :---: |
| 1 | int 列混入 `NaN` → 静默变 `float64` | counts 变浮点，下游要整数的接口拒收；大整数丢精度 | `dtype="Int64"`（大写 I，nullable integer） |
| 2 | view / copy 语义不确定 | 以为改了原表其实没改，或反过来；`SettingWithCopyWarning` 该警告时也可能不警告 | 要副本显式 `.copy()`；改原表用 `df.loc[行, 列] = 值` 单步赋值 |
| 3 | `merge` 的多对多静默膨胀 | 行数翻倍而不报错，下游所有统计量都错 | merge 前后 `assert len(df) == n`；用 `validate="one_to_one"` |

> **`validate=` 参数是 pandas 里最被低估的一个**：`pd.merge(..., validate="many_to_one")`
> 会在关系不成立时**直接报错**，把静默错误变成显式错误。合并样本表时应当默认加上。

---

## §4 统计与机器学习层：三个包的职责切分

| 包 | 抽象单位 | 什么时候用 | 关键差别 |
| :--- | :---: | :---: | :---: |
| `scipy.stats` | **函数** | 两组比较、相关、分布拟合 | 输入数组，输出 `(statistic, pvalue)`，算完就结束 |
| `statsmodels` | **模型对象** | 需要系数、置信区间、残差、AIC、公式接口 | `smf.ols("y ~ x + batch", data=df).fit().summary()`，R 风格公式 |
| `scikit-learn` | **估计器 (Estimator)** | 预测、降维、聚类、交叉验证 | `fit` / `transform` / `predict` 三件套；**不给 p 值**，它关心的是预测性能 |

### §4.1 一句话选型

- **要 p 值和效应量解释** → `statsmodels`（它给完整的推断表）
- **要预测准确率** → `scikit-learn`（它给交叉验证，但故意不给 p 值）
- **只是一次两组比较** → `scipy.stats`，别上模型

### §4.2 🔴 生信特别提醒：DE 分析不要自己拿 scipy 拼

RNAseq 的差异表达（DE，differential expression）本质是**负二项广义线性模型 + 离散度收缩（dispersion shrinkage）**。
`scipy.stats.ttest_ind` 对 counts 做 t 检验在统计上是错的（方差与均值强相关，且 n 小时离散度估不准）。

| 场景 | 该用 | 本机状态 |
| :--- | :---: | :---: |
| bulk RNAseq DE | R 的 DESeq2 / edgeR（金标准） | `DE_R45` env |
| bulk RNAseq DE（纯 Python 路线） | `pydeseq2`（DESeq2 的 Python 重实现） | 已装于 `sc_tut_main` |
| 单细胞 pseudobulk DE | 聚合到样本水平后走 DESeq2 / edgeR | 见 `scrna` skill |
| 通路活性打分 | `decoupler` | 已装于 `sc_tut_main` |

### §4.3 多重检验校正：scipy 够用，未必需要 statsmodels

**本机实测**：`regular_bioinfo` 里 **statsmodels 没装**，但 scipy 1.15.2 有
`scipy.stats.false_discovery_control`（scipy 1.11 引入），支持 Benjamini–Hochberg 和 Benjamini–Yekutieli：

```python
from scipy.stats import false_discovery_control
padj = false_discovery_control(pvals, method="bh")   # 默认就是 bh
```

只做 FDR（false discovery rate，错误发现率）校正的话，**不必为此装 statsmodels**。

---

## §5 绘图层：四个包，一条继承链

这是最容易搞混的一层，因为它们**不是互斥的四选一**，而是"一条链 + 一个旁路"。

### §5.1 关系图

```
   pandas.DataFrame.plot()      ← 最薄的封装，探索用，一行出图
            ↓ 调用
        seaborn                 ← 统计图语法：分组、聚合、置信区间自动做
            ↓ 调用
       matplotlib               ← 真正的渲染引擎，一切的底层
            ↓ 输出
     PDF / PNG / SVG

       plotly                   ← 旁路：完全独立，不依赖 matplotlib，输出 HTML
```

**关键推论：seaborn 画完的图，可以继续用 matplotlib 的 API 修改**（改轴标签、加注释、调字号），
因为 seaborn 返回的就是 matplotlib 的 `Axes` 对象。这不是 hack，是设计意图。

### §5.2 各自的定位

| 包 | 本质 | 用它的理由 | 不用它的理由 |
| :--- | :---: | :---: | :---: |
| **matplotlib** | 渲染引擎 + 面向对象的图形模型（`Figure` → `Axes` → `Artist`） | 完全可控；出版级排版只能靠它 | 画一张带分组统计的图要写 20 行 |
| **seaborn** | matplotlib 之上的**统计图语法** | 分组/聚合/误差棒自动完成；默认审美好得多 | 高度定制时反而碍事，最终还是要落到 `ax` |
| **plotly** | 独立的交互式引擎，输出 HTML + JS | 需要 hover 查数、缩放、给客户看的交互页面 | 出版图（PDF 矢量导出不如 matplotlib 可靠）；文件大 |
| **pandas `.plot()`** | matplotlib 的一行封装 | 探索阶段快速看一眼 | 任何要给别人看的图 |

### §5.3 🔴 seaborn 的两套 API：figure-level vs axes-level

**这是 seaborn 最大的困惑源，也是拼 panel 时静默失败的根源。**

| 类型 | 函数 | 返回 | 能否传 `ax=` |
| :--- | :---: | :---: | :---: |
| **figure-level**（管整张图） | `relplot` `catplot` `displot` `lmplot` `clustermap` `pairplot` | `FacetGrid` / `JointGrid` | **❌ 不能** |
| **axes-level**（只画到一个格子） | `scatterplot` `lineplot` `boxplot` `violinplot` `heatmap` `histplot` `barplot` | `matplotlib.axes.Axes` | **✅ 能** |

**记忆法：名字里带 `plot` 后缀的多半是 axes-level；`relplot`/`catplot`/`displot` 这三个"缩写名"是 figure-level。**

```python
fig, axes = plt.subplots(1, 2, figsize=(8, 4))

sns.boxplot(data=df, x="group", y="expr", ax=axes[0])   # ✅ axes-level，画进去了
sns.catplot(data=df, x="group", y="expr", ax=axes[1])   # ❌ 报错 / 另开一张图
```

**想拼多 panel，一律用 axes-level 函数。** figure-level 函数自己管分面（facet），
它和 `plt.subplots` 是**两套互斥的排版方案**，不能混用。

### §5.4 seaborn 的第三套 API：`seaborn.objects`（0.12+）

**本机实测**：seaborn 0.13.2，`import seaborn.objects as so` 可用。
这是仿 ggplot2 的图形语法接口，链式调用：

```python
import seaborn.objects as so
(so.Plot(df, x="group", y="expr", color="batch")
   .add(so.Dot(), so.Jitter())
   .add(so.Range(), so.Est(errorbar="se")))
```

**现状判断（我的判断，非实测）**：接口仍在演进，文档和社区示例远少于经典 API。
**做交付图建议继续用经典 axes-level API**，`so` 接口可以在探索时试。

### §5.5 🔴 多 panel 撞色：默认色环每个 Axes 从头分配

matplotlib 的默认颜色循环（`C0` `C1` `C2`…）是**每个 `Axes` 独立从头开始**的。
所以 panel A 的第一个类别和 panel B 的第一个类别会拿到同一个颜色——
**而读者默认"同色 = 同义"**。这是同图内语义不同 panel 之间最常见的静默错误。

**防法：颜色显式映射成 dict，不依赖默认顺序。**

```python
PALETTE = {"Ctrl": "#4C72B0", "Treat": "#DD8452", "KO": "#55A868"}
sns.boxplot(data=df, x="group", y="expr", hue="group",
            palette=PALETTE, ax=ax)          # 每个 panel 拿同一份映射
```

配色优先级与出版级 house style 见 `scientific-figure-making` skill。

### §5.6 服务器上的 matplotlib：三条必知

**本机实测**：`regular_bioinfo` 的默认 backend 是 **`agg`**（无显示设备时自动选）。

| 事实 | 后果 | 处理 |
| :--- | :---: | :---: |
| backend = `agg`，无 GUI | `plt.show()` **什么也不会发生**，也不报错 | 脚本里一律 `fig.savefig(...)`，不用 `show()` |
| 中文字符渲染成方框 | 图里的中文全变 `□`；**告警走 `warnings` 不走 `logger`**，用 logging 抓 = 恒零假通过 | 见 `/home/gao/Utilities/software_pitfalls/matplotlib_cjk_font.md` |
| 循环里不关 figure | 内存持续增长，几百张图后 OOM | `plt.close(fig)`，或 `plt.close("all")` |

### §5.7 交付格式

**交付图件一律只要 PDF（矢量），不要 PNG。** 例外：软件自带导出（MultiQC / nf-core 的 HTML 报告）原样保留。

```python
fig.savefig(out / "fig3_pca.pdf", bbox_inches="tight")   # ✅
```

> `bbox_inches="tight"` 几乎总是要加——否则旋转过的轴标签会被裁掉，
> 而**裁掉的部分在 PDF 里是真的没有了**，不是显示问题。

---

## §6 生信专用层

| 模块 | 管什么 | 典型用法 | 本机状态 |
| :--- | :---: | :---: | :---: |
| `Biopython` (`import Bio`) | 序列对象、FASTA/GenBank 解析、比对格式、NCBI Entrez | `SeqIO.parse(f, "fasta")` | `regular_bioinfo` 1.87 |
| `pysam` | BAM / CRAM / VCF 的读写，**samtools 的 Python 绑定** | `pysam.AlignmentFile(bam).fetch("chr1", 1000, 2000)` | `regular_bioinfo` 0.23.3 |
| `gffutils` | GFF / GTF 建数据库并按坐标查询 | `db.children(gene, featuretype="exon")` | `regular_bioinfo` 0.14 |
| `AnnData` | 单细胞的**数据容器**：`X` 矩阵 + `obs`/`var` 两张注释表 | Scanpy 生态的唯一货币 | `sc_tut_main` 0.12.19 |
| `Scanpy` | 单细胞分析主线：QC、降维、聚类、marker | `sc.pp.*` `sc.tl.*` `sc.pl.*` | `sc_tut_main` 1.11.5 |
| `pydeseq2` | DESeq2 的 Python 重实现 | bulk / pseudobulk DE | `sc_tut_main` 0.5.4 |
| `decoupler` | 通路与转录因子活性打分 | `dc.run_mlm(...)` | `sc_tut_main` 2.2.0 |
| `harmonypy` | 批次整合（Harmony 的 Python 版） | 单细胞去批次 | `sc_tut_main` 2.0.0 |
| `scvi-tools` | 深度生成模型（整合、去噪、标签迁移） | 需要 GPU | `sc_tut_main` 1.3.3 |

### §6.1 🔴 AnnData 与 R 的维度是**转置**的

| 生态 | 维度约定 |
| :--- | :---: |
| AnnData / Scanpy（Python） | **细胞 × 基因**（obs × var） |
| Seurat / SingleCellExperiment（R） | **基因 × 细胞** |

**转置后代码照跑、图照出，所有生物学结论都是错的**；细胞数恰好等于基因数时连报错都没有。
跨语言搬数据必须显式转置并 assert 维度。这是 Python↔R 单细胞互转的头号错误来源。

### §6.2 pysam 的坐标系

`pysam` 的 `fetch(contig, start, end)` 用 **0-based 半开区间**，
而 VCF / GTF 文件里写的是 **1-based 闭区间**。
读 `read.reference_start` 拿到的是 0-based，写进报告前要 `+1`。
更多见 `/home/gao/Utilities/software_pitfalls/pysam.md`。

---

## §7 工程层：让脚本能被别人跑起来的那些模块

| 模块 | 替代掉什么 | 为什么值得换 |
| :--- | :---: | :---: |
| `pathlib` | `os.path` 字符串拼接 | `p / "sub" / "f.txt"`；`p.exists()` `p.stem` `p.glob()`；跨平台且不会漏斜杠 |
| `argparse`（标准库） | 手动读 `sys.argv` | 自动生成 `--help`、类型转换、必填校验 |
| `click` / `typer` | `argparse` | 装饰器写法更短；`typer` 靠类型注解自动推参数 |
| `tqdm` | 手写进度打印 | `for x in tqdm(items)`；能估剩余时间 |
| `joblib` | 手写多进程 | `Parallel(n_jobs=8)(delayed(f)(x) for x in xs)`；**注意遵守 28 核 / 56 线程上限** |
| `pyyaml` (`import yaml`) | 硬编码参数 | 参数与代码分离；Nextflow / nf-core 生态也是 YAML |
| `openpyxl` | 手转 CSV | 直接读客户的 `.xlsx` 送样单 |
| `requests` | `urllib` | 下载参考数据、调 REST API |
| `h5py` | — | 读写 HDF5（CellRanger 的 `.h5`、AnnData 的 `.h5ad` 底层） |

### §7.1 🔴 openpyxl 读客户表单：答案可能藏在字体颜色里

客户常常**不改文字，只把模板句里的 "No" 染成红色**来表示选择。
`cell.value` 读到的还是原句，**信息完全丢失且零报错**。
读客户送样单时必须同时检查 `cell.font.color` 与富文本 runs。
见 `/home/gao/Utilities/software_pitfalls/openpyxl_xlsx_richtext.md`。

### §7.2 ⚠️ 可选依赖（extras）：装没装，要走到那条分支才知道

**层次地图之外还有第二个维度：同一层里，一个包对另一个包的依赖可以是「必装」也可以是「可选」。**
上层包（尤其 Scanpy）大量使用**惰性可选依赖**——不写进硬依赖，只在真正调用到的那一行才 `import`。

**本机实测（`sc_tut_main` 的 scanpy 1.11.5）**：源码里有 **21 处 `raise ImportError`**，
涉及 `leidenalg` `python-igraph` `scikit-misc` `scikit-image` `harmonypy` `bbknn`
`scanorama` `magic-impute` `dca` `palantir` `trimap` `fa2-modified` 等十余个包。

| 走到哪条分支才炸 | 缺哪个包 | 报错 |
| :--- | :---: | :---: |
| `sc.pp.highly_variable_genes(flavor="seurat_v3")` | `scikit-misc` | `Please install skmisc package via pip install scikit-misc` |
| `sc.pp.scrublet(...)`（`threshold=None`，即默认） | **`scikit-image`** | `threshold is None and thus scrublet requires skimage, but skimage is not installed.` |
| `sc.tl.leiden(...)` | `leidenalg` / `python-igraph` | `Please install the leiden algorithm` |
| `sc.external.pp.harmony_integrate` / `bbknn` / `scanorama` | 各自的包 | 各自的 `ImportError` |

**为什么 scanpy 要把 `skimage` 做成可选？** 这正是 §0 那条依赖方向的推论：
scrublet 的最后一步要把 doublet score 直方图**二值化**成"是/不是 doublet"，
而"从双峰直方图里找谷底"是个**图像处理算法**（`skimage.filters.threshold_minimum`，
与 Otsu 同族）。scanpy 没有自己重写它，而是向下调用图像处理层——合规，但代价是多一个可选依赖。

**这个守卫写得很好，值得抄**（`scanpy/preprocessing/_scrublet/__init__.py:179`）：

```python
if threshold is None and not find_spec("skimage"):
    # Scrublet.call_doublets requires `skimage` with `threshold=None` but PCA
    # is called early, which is wasteful if there is not `skimage`
    raise ImportError(...)
```

真正用到 `skimage` 的是最后一步，但它**在入口就用 `importlib.util.find_spec` 探一次**，
免得你白跑十几分钟的 PCA + kNN 才发现缺包。**自己写长流程时照这个模式做前置探测。**

**⛔ 这一类不属于 §9 的"静默陷阱"** —— §9 的判据是「**不报错**地产出错结果」，
而缺可选依赖是**大声报错**的，只是报得晚、且报错信息离"你到底该装什么"有一步之遥。
它的正确归属是工程层：**环境能不能重建**。

**三条操作规则：**

1. **`scikit-image` 不是 RNAseq / WGS 的核心模块**，不必主动掌握。它出现在两种场合：
   ① 上面这种 scanpy 可选依赖；② **空间转录组**真的要处理组织切片图像（`squidpy.im`、
   Visium HD / Xenium 的配准与分割）。本机 `sc_tut_spatial` 里它是 squidpy 带进来的。
2. **装完必须回填 env yaml，并写明"为什么需要"。** 只装不回填 = 下次从 yaml 重建环境时
   同一个坑原样复发，而那时已经没人记得当初发生过什么。
3. **`mamba install --dry-run` 先看解算结果再决定装不装**：关键看**有没有降级/卸载**。
   纯新增可以放心装；有降级就要先评估会不会碰坏已验证的组合。

> 实例：2026-09-17，`sc_tut_main` 跑教程 2-1 章的 `sc.pp.scrublet` 时命中第 2 行，
> 补装 `scikit-image 0.26.0`（纯新增 23 包，numpy/scipy/scanpy 均未动）并回填 yaml。
> 全过程见 `/home/gao/projects_2026M7/22_python_based_scRNA_tutorial/docs/P22_run_and_troubleshooting_log_0903.md` 事件 #7。

---

## §8 本机实测：两个环境的模块矩阵

### §8.1 ⚠️ 先说一个环境解析问题（2026-09-17 实测）

本次探测时发现：当前 shell 的 `PATH` 最前面被插入了
`/mnt/ex_8T_SSD/conda_envs/sc_tut_main/bin`，导致

```
conda run -n regular_bioinfo python   →  实际执行 /mnt/ex_8T_SSD/conda_envs/sc_tut_main/bin/python
conda run -p <regular_bioinfo 绝对路径> python  →  同样执行 sc_tut_main 的 python
```

**`-n` 和 `-p` 都被绕过，且不报错。** 这不在 `~/.bashrc` 里（已 grep 确认），
是由父进程（Positron / VS Code server 或 agent harness）注入的，**属于会话级环境**，
不确定是否影响你自己的登录 shell。

**可靠的验证与规避方式**：直接用绝对解释器路径，或每次先自证身份

```bash
# 规避
/Work_bio/gao/configs/.conda/envs/regular_bioinfo/bin/python script.py

# 自证（任何 conda run 之后都值得跑一次）
conda run -n <env> python -c "import sys; print(sys.executable)"
```

> 相关但**不是同一件事**：本机另有两个同名 `regular_bioinfo`
> （`/Work_bio/gao/configs/.conda/envs/` 与 `/home/gao/.conda/envs/`）。
> 已实测二者在 numpy / pandas / matplotlib / seaborn / Bio / pysam 上版本**完全一致**，
> 按 `envs_dirs` 顺序前者优先。见 `/home/gao/Utilities/software_pitfalls/conda_env_duplicate_names.md`。

### §8.2 模块矩阵

以下为 **2026-09-17 用绝对解释器路径实测**的结果。

| 模块 | `regular_bioinfo`（主环境，Python 3.10.20） | `sc_tut_main`（单细胞主线，Python 3.11.16） |
| :--- | :---: | :---: |
| numpy | **1.26.4** | **2.4.6** |
| scipy | 1.15.2 | 1.17.1 |
| pandas | 2.3.3 | 2.3.3 |
| matplotlib | 3.10.8 | 3.11.1 |
| seaborn | 0.13.2 | 0.13.2 |
| plotly | 6.6.0 | ❌ 未装 |
| polars | 1.39.2 | ❌ 未装 |
| statsmodels | ❌ **未装** | 0.14.6 |
| scikit-learn | 1.7.2 | 1.9.0 |
| scikit-image | ❌ 未装 | 0.26.0（**2026-09-17 补装**，见 §7.2） |
| scikit-misc | ❌ 未装 | ✅（HVG `seurat_v3` 需要，见 §7.2） |
| pyarrow | ❌ 未装 | 25.0.1 |
| h5py | ❌ 未装 | 3.16.0 |
| xarray | ❌ 未装 | 2026.7.0 |
| numba | ❌ 未装 | 0.67.0 |
| Biopython (`Bio`) | 1.87 | ❌ 未装 |
| pysam | 0.23.3 | ❌ 未装 |
| gffutils | 0.14 | ❌ 未装 |
| anndata | ❌ 未装 | 0.12.19 |
| scanpy | ❌ 未装 | 1.11.5 |
| pydeseq2 | ❌ 未装 | 0.5.4 |
| decoupler | ❌ 未装 | 2.2.0 |
| harmonypy | ❌ 未装 | 2.0.0 |
| scvi-tools | ❌ 未装 | 1.3.3 |
| torch | ❌ 未装 | 2.14.0+cu130 |
| igraph / leidenalg | ❌ 未装 | 1.0.0 / 0.12.0 |
| umap-learn | ❌ 未装 | 0.5.12 |
| networkx | 3.4.2 | 3.6.1 |
| joblib / tqdm | 1.5.3 / 4.67.3 | 1.6.0 / 4.70.0 |
| requests / openpyxl / pyyaml | 2.32.5 / 3.1.5 / 6.0.3 | 2.34.2 / 3.1.5 / 6.0.3 |
| click / typer / rich | 8.4.2 / 0.26.7 / ✅ | 8.5.0 / ❌ / ✅ |

**两个环境的分工是清楚的、也是合理的：**

| 环境 | 定位 | 特征 |
| :--- | :---: | :---: |
| `regular_bioinfo` | **序列与文件层**：WGS / RNAseq 的常规处理、读 BAM/VCF/GTF、读客户表单 | 有 `Bio` `pysam` `gffutils`，**没有**单细胞栈 |
| `sc_tut_main` | **单细胞与统计建模层** | 有完整 Scanpy 生态 + `torch` + `statsmodels`，**没有** `Bio` `pysam` |

### §8.3 🔴 numpy 1.x vs 2.x：两个环境跨了一次破坏性升级

**本机实测**：`regular_bioinfo` 是 numpy **1.26.4**，`sc_tut_main` 是 numpy **2.4.6**。

| 符号 | numpy 1.26.4 | numpy 2.4.6 |
| :--- | :---: | :---: |
| `np.float_` | ✅ 存在 | ❌ **已移除** |
| `np.in1d` | ✅ 存在 | ❌ **已移除**（改用 `np.isin`） |

**推论（我的判断，未逐包实测）**：在两个环境间复制粘贴脚本时，
用到这些老别名的代码会在 numpy 2 环境里抛 `AttributeError`。
这类是**显式报错**，相对安全；真正麻烦的是编译型扩展包的 ABI 不兼容——
针对 numpy 1.x 编译的 C 扩展在 numpy 2.x 下会在 import 时报错。
**因此：不要试图把两个环境合并成一个**，它们跨了 numpy 的主版本边界。

### §8.4 复现命令

```bash
# 列出全部环境（注意两个同名 regular_bioinfo）
mamba env list

# 用绝对路径探测，绕过 PATH 注入问题
/Work_bio/gao/configs/.conda/envs/regular_bioinfo/bin/python -c "
import importlib
for m in ['numpy','scipy','pandas','matplotlib','seaborn','statsmodels','sklearn','Bio','pysam']:
    try:
        mm = importlib.import_module(m)
        print(m, getattr(mm,'__version__','?'))
    except Exception:
        print(m, 'NOT INSTALLED')
"
```

---

## §9 静默陷阱清单（会不报错地产出错结果）

按"发现难度"排序，越靠前越难发现。

| # | 模块 | 陷阱 | 症状 | 防法 |
| :--- | :---: | :---: | :---: | :---: |
| 1 | AnnData ↔ Seurat | 维度是转置的 | 代码照跑图照出，结论全错 | 跨语言必转置 + assert 维度 |
| 2 | matplotlib | 多 panel 默认色环各自从头分配 | 不同语义拿同色，读者读成同义 | 颜色写成 dict 显式映射 |
| 3 | matplotlib | 中文渲染成方框，**告警走 `warnings` 不走 `logger`** | 用 logging 抓告警 = 恒零假通过 | 配 CJK 字体 + `warnings.catch_warnings` |
| 4 | pandas | `merge` 多对多静默膨胀 | 行数翻倍，下游统计量全错 | `validate="many_to_one"` |
| 5 | pandas | int 列混 NaN 变 float64 | counts 变浮点，精度丢失 | `dtype="Int64"` |
| 6 | numpy | `std`/`var` 默认 `ddof=0` | 与 pandas/R 差几个百分点 | 显式 `ddof=` |
| 7 | seaborn | figure-level 不接受 `ax=` | 拼图失败或另开新图 | 拼图只用 axes-level |
| 8 | matplotlib | backend=`agg` 时 `plt.show()` 静默无事发生 | 以为出图了其实没有 | 只用 `savefig` |
| 9 | matplotlib | 不加 `bbox_inches="tight"` | 旋转的轴标签被**真的裁掉** | 一律加上 |
| 10 | matplotlib | 循环里不 `plt.close(fig)` | 几百张图后 OOM | 每轮 close |
| 11 | openpyxl | 客户答案藏在字体颜色里 | `cell.value` 读到原句，信息全丢 | 同时读 `cell.font.color` |
| 12 | pysam | `fetch` 是 0-based 半开，VCF/GTF 是 1-based 闭 | 坐标差 1 | 写报告前 `+1` |
| 13 | conda | `conda run -n` 被 PATH 注入绕过（§8.1） | 在错的环境里跑完全程 | 跑 `sys.executable` 自证 |
| 14 | scipy vs 自己拼 | 对 counts 做 t 检验 | 出得来 p 值，统计上是错的 | DE 走 DESeq2 / pydeseq2 |

> **第 3、8、13 条有一个共同结构：失败信号走了一条你没在监听的通道。**
> 这类错误无法靠"更仔细地看日志"避免，只能靠**主动断言**——
> 跑完之后显式检查那个你关心的事实是否成立。

---

## §10 选型速查

| 我要做… | 用 | 不要用 |
| :--- | :---: | :---: |
| 读 10 GB 的 CSV | `pandas` 分块 / `polars` | 一次 `read_csv` 全读 |
| 两组比较出 p 值 | `scipy.stats` | `sklearn` |
| 带协变量的回归 + 系数解释 | `statsmodels` | `sklearn` |
| 预测 + 交叉验证 | `sklearn` | `statsmodels` |
| RNAseq 差异表达 | DESeq2 (R) / `pydeseq2` | `scipy.stats.ttest_ind` |
| FDR 校正 | `scipy.stats.false_discovery_control` | 为此专门装 statsmodels |
| 快速看一眼分布 | `df.plot()` / `sns.histplot` | matplotlib 手搓 |
| 出版级多 panel 图 | matplotlib `subplots` + seaborn **axes-level** | seaborn figure-level |
| 给客户看的交互图 | `plotly` → HTML | matplotlib |
| 交付图件 | matplotlib → **PDF** | PNG |
| 读 BAM / VCF | `pysam` | 自己解析二进制 |
| 单细胞全流程 | `Scanpy` + `AnnData` | pandas 手搓 |
| 稀疏 counts 矩阵 | `scipy.sparse.csr_matrix` | dense ndarray |
| 并行跑 N 个独立任务 | `joblib.Parallel`（**≤56 线程**） | 手写 `multiprocessing` |

---

## §11 延伸阅读（本机文档）

| 主题 | 路径 |
| :--- | :---: |
| 表格类数据结构全景（8 种） | `/home/gao/Utilities/Python/Python_tabular_data_structures.md` |
| R 的对应篇 | `/home/gao/Utilities/R/R_tabular_data_structures.md` |
| 绘图实操笔记本 | `/home/gao/Utilities/Python/10.Plotting/` |
| 软件坑索引 | `/home/gao/Utilities/software_pitfalls/INDEX.md` |
| matplotlib 中文字体 | `/home/gao/Utilities/software_pitfalls/matplotlib_cjk_font.md` |
| conda 同名环境 | `/home/gao/Utilities/software_pitfalls/conda_env_duplicate_names.md` |
| `conda run` 子进程隔离 | `/home/gao/Utilities/software_pitfalls/conda_run.md` |
| pysam | `/home/gao/Utilities/software_pitfalls/pysam.md` |
| openpyxl 富文本 | `/home/gao/Utilities/software_pitfalls/openpyxl_xlsx_richtext.md` |

---

## §12 本文的事实来源

| 内容 | 来源 |
| :--- | :---: |
| 所有版本号、"装 / 未装" | **2026-09-17 本机实测**，命令见 §8.4 |
| `ddof` 数值、`false_discovery_control` 存在性、`seaborn.objects` 可导入性、backend=`agg`、`np.float_`/`np.in1d` 存废 | **2026-09-17 本机实测** |
| `conda run -n` 被 PATH 绕过 | **2026-09-17 本机实测**（`-n` 与 `-p` 各验证一次） |
| 依赖方向、职责切分的"为什么" | 上游文档与设计意图，**非实测** |
| numpy 2 的 ABI 影响范围 | **我的判断，未逐包实测** |
| `seaborn.objects` 是否适合做交付图 | **我的判断**，依据是文档与社区示例的数量 |
