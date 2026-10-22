---
name: spatial
description: "Use when 要做空间转录组分析（Visium / Visium HD / Xenium / CosMx / MERFISH）——两类平台的强制分流、观测单位不是细胞、R(统计) 与 Python(工程) 的分工与本机资产实测、SVG/去卷积/分割的选型与必配基线、y 轴翻转等静默错误清单与空间专用断言"
---

# /spatial — 空间转录组分析 SOP

**方法学依据**：[`spatial_transcriptomics_R_vs_Python_ecosystem_20260910.md`](/home/gao/Utilities/Bioinfo/single_cell_and_spatial/spatial_transcriptomics_R_vs_Python_ecosystem_20260910.md)（逐任务生态对比 + 基准数字）
**参考实现**：[`24_R_advanced_scRNA_and_Spatial_tutorial_2026`](/home/gao/projects_2026M7/24_R_advanced_scRNA_and_Spatial_tutorial_2026/)（R/Bioc，13 章空间 `.qmd`）＋ [`22_.../notebooks/07_spatial/`](/home/gao/projects_2026M7/22_python_based_scRNA_tutorial/notebooks/07_spatial/)（Python/squidpy，5 章）
**细胞层面的通用规则（QC/注释/pseudobulk/富集/AI 纪律）走** `/scrna`，本 skill 不复述。

---

## §0 结论先行 —— 只记这六条也够用

| # | 规则 | 违反的后果 |
| :--- | :---: | :---: |
| **1** | **观测单位不是细胞。** Visium 一个 spot 含数个至数十个细胞 | **去卷积之前任何"细胞类型比例"的说法都不成立** |
| **2** | **两类平台（测序型 / 成像型）当两条独立管线**，代码分树、checkpoint 命名空间分开 | 两者观测单位、QC 指标、可用方法几乎无交集；"这条规则适用于哪一类"是最易记错的部分 |
| **3** | **分割（segmentation）不是预处理细节，它会改变你报告里的细胞类型比例** | 不同分割方法给出的细胞数可差数倍 ⇒ **必须做敏感性分析或明确声明边界** |
| **4** | **SVG 必须与 Moran's I 基线并排跑** | 14 方法基准里 Moran's I 排第四（0.76 vs SPARK-X 0.88）；复杂方法赢不过基线就没有使用理由 |
| **5** | **去卷积需要同组织的 scRNA 参考**（数据约束，不是生态约束），**且必须两法并跑**（RCTD + Tangram） | 没有同组织参考 ⇒ 做不了，别硬做。只跑一法 ⇒ spot ID 错位、参考细胞数过少这类错误**没有任何东西能发现**（见 §4） |
| **6** | **y 轴方向必须显式断言** | 图像坐标 y 向下 vs 绘图 y 向上；不翻转就得到上下镜像的组织 —— **图正常、聚类正常，只有解剖方向是反的** |

**一句话分工**：**Python 强在"从原始图像/转录本到细胞"的工程链条，R 强在"拿到细胞/spot 之后的统计"。** 两者互补，不是竞争。

---

## §1 第零步：平台分流

| | **① 测序型（seq-based）** | **② 成像型（imaging-based）** |
| :--- | :---: | :---: |
| 平台 | Visium、**Visium HD**、Slide-seq、Stereo-seq | **Xenium**、CosMx、MERFISH/MERSCOPE |
| 观测单位 | **spot / bin —— 不是细胞** | **transcript（点）→ 需分割成细胞** |
| 基因覆盖 | **全转录组** | **panel，数百至数千基因**（近年到 5000–6000 级） |
| 分辨率 | Visium 55 µm；Visium HD 2 µm bin | 亚细胞 |
| **核心难题** | **去卷积**（一个 spot 混了哪些细胞类型） | **分割**（哪些转录本属于同一个细胞） |
| 每单位 counts | Visium 够用；**HD 2 µm 中位个位数 ⇒ 单 bin 做不了统计** | panel 基因深，但受 spillover 影响 |

**⚠ 基础设施警告**：跑通过 Visium **不能假定**同一套基础设施能处理 Xenium/CosMx。要当成两条独立管线准备，不是一条管线加个参数。

### 1.1 该问客户 vs 我方自己定

| 谁的决定 | 内容 |
| :--- | :---: |
| **客户的（必须问）** | 组织类型与切片来源、切片方向/解剖学参照（**哪边是上**）、分组与重复、目标区域或结构、**有没有配套的同组织 scRNA 参考**、panel 选择（成像型的 panel 是实验设计的一部分） |
| **我方的（自己定，写进 Methods）** | 参考基因组与版本、bin 尺度、归一化/聚类/域识别方法与参数、SVG 方法与基线、去卷积算法、是否接受厂商分割 |

**n=1 的现实**：一块组织 = 一个样本。**单样本做不了跨条件统计**，只能给模板与判据。诚实写明边界，比拿单样本硬做出一张"显著"的表有价值。

---

## §2 生态选型与本机资产（2026-09-16 实测）

### 2.1 逐任务判定

| 任务 | R / Bioconductor | Python / scverse | 判定 |
| :--- | :---: | :---: | :---: |
| 数据结构（多模态/图像） | SpatialExperiment、SFE | **SpatialData** | Python 优 |
| 数据结构（几何运算） | **SFE + `sf`/`terra`** | GeoPandas 扩展 | R 优 |
| 空间感知 QC | **SpotSweeper**（Nat Methods） | squidpy 内零散实现 | R 优 |
| SVG | nnSVG、**SPARK-X** | SpatialDE2、squidpy Moran's I | R 略优 |
| 空间域识别 | BANKSY、PRECAST | squidpy + 外部方法 | 平手 |
| **去卷积** | **RCTD(`spacexr`)、SPOTlight** | **cell2location、DestVI、Tangram** | **平手，两边都在第一梯队** |
| **分割编排** | 有章节，无成熟管线 | **Sopa** | **Python 单极** |
| **2 µm → 细胞重建** | 无对等物 | **bin2cell**、StarDist+scanpy | **Python 单极** |
| 邻域 / 细胞互作 | 有实现 | **squidpy 更成套** | Python 略优 |
| **空间统计 / ESDA（尺度、局部热点）** | **Voyager** | 无对等物 | **R 单极** |
| 教学/SOP 资源密度 | **OSTA 40 章** | 分散在各包 tutorial | R 优 |

**⚠ 分割算法本身是多语言 CLI**：Baysor 是 Julia、Proseg 是 Rust、Cellpose/StarDist 才是 Python。**属于 Python 的是编排层（Sopa）**，不是算法本身。

### 2.2 本机资产 —— 这一格决定"今天能跑什么"

| | 状态（2026-09-17 实测） |
| :--- | :---: |
| **Python 空间 env** | ✅ **已建成**：`/mnt/ex_8T_SSD/conda_envs/sc_tut_spatial/bin/python` —— squidpy 1.8.2 / spatialdata 0.7.3 / spatialdata_io 0.7.1 / spatialdata_plot 0.4.0 / **tangram 1.0.4** / geopandas / skimage。**已知缺口：SpatialDE 不可用**（scipy 1.17 移除 `scipy.misc.derivative`，按决定不修） |
| **R 空间栈** | ✅ **已建成并端到端跑通**（2026-09-17，proj37）：`/mnt/ex_8T_SSD/conda_envs/spatial_r/bin/Rscript`，R 4.5.3，库内 501 个包。实测版本：SpatialExperiment 1.20.0 / nnSVG 1.14.0 / **spacexr 1.2.0（RCTD）** / Voyager 1.12.0 / SingleCellExperiment 1.32.0 / scater 1.38.1 / scran 1.38.1 / SpotSweeper 1.6.0 / sf 1.1-2 / terra 1.9-34 / spdep 1.4-2 / Seurat 5.5.1。**⚠ 旧的 `/Work_bio/gao/miniforge3/lib/R/library` 里仍然只有孤立的 Seurat —— 别指错前缀** |
| **GPU** | GTX 1060 **3 GB** ⇒ **cell2location 不可用**（官方推荐 ≥16 GB，CPU 单次训练 >10 h）。去卷积走 **Tangram** |
| RAM / CPU | 125 GB / 28 核 56 线程上限 | 

**⇒ 由此得出的执行判据（本 skill 最实用的一条）：**

> **两条路线现在都可用，按方法学优势选，不再按"哪个装好了"选。**
> Python（`sc_tut_spatial`）= 工程链条（读入、spatialdata、Tangram、绘图）；
> R（`spatial_r`）= spot 之后的统计（Voyager ESDA、nnSVG、RCTD、SpotSweeper）。
> **⚠ 别再把建 R env 当作要先取得批准的前置工程任务 —— 它已经建好了，重建纯属浪费。**
> 动手前先 `ls /mnt/ex_8T_SSD/conda_envs/spatial_r/lib/R/library | wc -l` 确认（应为 501 左右），
> 缺某个包再单独装，而不是重建整个 env。

**⇒ 跨语言协作的做法（proj37 实测跑通）：** 用**文件桥**，不用 rpy2。
Python 侧导出 counts/coords/meta → R 侧跑统计 → 写回 CSV → Python 侧整合。
脚本骨架见 [`37_.../scripts/`](/home/gao/projects_2026M7/37_spatial_visium_heart_pilot/scripts/)
（`8_export_for_r.py` → `9_r_nnsvg_vs_moran.R` / `10_r_rctd_deconv.R` / `11_r_voyager_esda.R` → `12_integrate_r_python.py`）。
**建 env 的脚本骨架**（万一要在别的机器重建）见同目录 `7_build_spatial_r_env.sh`：
把验证分成「主线必需 / 可降级」两组并逐包 `BiocManager` 兜底。

---

## §3 逐任务 SOP

### 3.1 读入与空间专用 QC

| 必做 | 说明 |
| :--- | :---: |
| **`in_tissue` 过滤** | 组织外的 spot 必须剔除；剔除后剩余比例异常低（<20%）说明配准或切片有问题 |
| **坐标合法性** | 坐标不能大面积重复/缺失；`assert_spatial_coords()` 查唯一值占比 |
| **y 轴方向** | **显式断言**（见 §0 规则 6）；`assert_yaxis_flipped()` |
| **空间感知 QC** | 除常规 counts/genes/mito 外，查**空间上的局部异常**：某片区域整体偏低 = 组织破损还是生物学？R 侧 `SpotSweeper` 是专用工具，Python 侧需自己算局部统计量 |
| 常规 QC 的差异 | **不要照搬 scRNA 的 MAD 阈值就算完** —— 空间数据里"离群"可能是一个真实的解剖结构 |

### 3.2 归一化 / 降维 / 域识别

- 归一化与降维同 scRNA（`/scrna` §3.2），但**要考虑空间自相关**；R 侧有 `SpaNorm` 这类空间感知归一化。
- **空间域（domain）≠ 细胞类型**：域是组织结构。工具：**BANKSY**（R，OSTA 主推，同时做降维/聚类/域识别）、PRECAST；Python 侧 squidpy + 外部方法。
- **域的数量是超参数** ⇒ 至少扫两三个设置，看主要结构是否稳定。

### 3.3 SVG（空间可变基因）

| 方法 | 14 方法 × 96 数据集基准的平均相关性 | 生态 |
| :--- | :---: | :---: |
| **SPARK-X** | **0.88**（一致最优） | R |
| SpatialDE2 | 0.81 | Python |
| **nnSVG** | 0.80（OSTA 主推） | R |
| **Moran's I** | **0.76（最简单的方法，第四名）** | 两边都有 |

**本机实测（proj37，同一组 1000 个候选基因上跑两法）**：nnSVG vs Moran's I 排名 **Spearman rho = 0.908**，
top-100 重叠 **92/100**，nnSVG 耗时 3.5–3.7 min。⇒ **复杂方法没赢过基线，这件事现在有自家证据，
不只是文献里的基准数字。** 先跑基线、赢不过就用基线，是可以照做的默认。

**⚠ 送检基因先过滤**：只把**该切片内有变异**的基因送进 `spatial_autocorr`。无变异基因的 Moran's I = NaN，而 squidpy 会给它们未初始化内存当 p 值，并经 BH 污染有效基因（见 §4）。配套断言 `assert uns["moranI"]["I"].notna().all()`。

**三条操作规则**：① **必须跑 Moran's I 作基线**，复杂方法赢不过它就没有使用理由；② **不存在单一最优 SVG 方法** —— SPARK-X/nnSVG/Moran's I 对"小区域高表达、其余为零"这类模式准确率都低，而 SpatialDE2/SPARK/Sepal 在该模式上强 ⇒ **报告里必须写明用了哪种、它对哪类模式不敏感**；③ 这一格**不构成换生态的理由**（第一名 SPARK-X 本身就是 R 包）。

### 3.4 去卷积（仅测序型）

- **第一梯队**：cell2location、RCTD(`spacexr`)、SPOTlight —— **选 R 不付性能代价**；cell2location 预测最稳定但**本机 GPU 跑不动**。
- **本机可行路径 = Tangram**（`sc_tut_spatial` 已装）。参考分层下采样到约 2 万细胞，并打印映射矩阵体积。
- **硬约束在数据不在生态**：**必须有同组织的 scRNA/snRNA 参考**。没有就不做，别用别的组织凑。
- **产出必须断言**：每个 spot 的比例和为 1、无负值（`assert_deconv_proportions()`）。
- **种子必须非零且自己显式播**（`np.random.seed` + `torch.manual_seed`），CPU 上再 `torch.set_num_threads(N)` 固定归约顺序 —— 否则 Tangram 每跑一遍换一组结果（见 §4）。**验收方式只有一个：同参数跑两遍 `md5sum` 比产物。**
- **Tangram 没有"参考细胞数不足"的护栏**：15 个细胞的类型照跑照给比例，而 RCTD（`CELL_MIN_INSTANCE=25`）直接拒绝运行。⇒ **跑通 ≠ 可信**，必须配一条不经过该算法的独立证据（如 marker 表达的空间相关性）。
- **报告口径**：去卷积给的是**估计比例**，是模型产物不是观测，写法上与实测量区分开。

### 3.5 Visium HD

| 尺度 | 用途 |
| :--- | :---: |
| **8 µm / 16 µm bin** | **默认分析尺度**（单切片 2 µm 是 870 万 bins，必须流式处理） |
| **2 µm bin** | **不当作观测单位**，它的真实用途是**分割/细胞重建的输入**（`bin2cell`、StarDist+scanpy，**这条链全在 Python**） |

**Space Ranger v4 起**，Visium HD 的细胞级分割结果可直接读成 `SpatialExperiment` ⇒ **只要接受厂商分割，R 侧全程自洽。**

### 3.6 成像型（Xenium / CosMx / MERFISH）

- **分割是首要误差来源。** 厂商（Xenium/CosMx/MERSCOPE）都自带转录本→细胞核初分配，**接受厂商分割是合理的默认**，但必须做两件事之一：**① 敏感性分析**（换一种设置跑一遍，看细胞类型比例与组间差异方向是否稳定 —— **结论随方法翻转的就不是结论，是方法的产物**）；**② 明确写成边界**（说明厂商分割的局限，并指出重做分割属于 Python/Sopa 的领域）。
- **要自己重做分割 ⇒ 走 Python**：Sopa 编排 + Proseg（比 Baysor 快约一个数量级、省约一个数量级内存）/ Baysor / Cellpose。
- **转录本 spillover（信号污染）**是成像平台的专门议题，在 Limitations 里陈述。
- panel 只有数百至数千基因 ⇒ **"未检出" 常常是 panel 里没有这个基因**，不是不表达。**这句话必须写进报告**。

### 3.7 邻域 / 空间互作 / ESDA

- 邻域富集、共定位、配受体：squidpy 更成套；**输出是"空间上邻近 + 表达相容"，不是"确实发生了通讯"** ⇒ 写成假说。
- **尺度分析与局部热点（LISA）目前只有 R 的 `Voyager` 完整实现** —— 要回答"这个空间格局在什么尺度上成立""哪里是局部热点"，只能走 R。这也是建 R 空间栈的**唯一不可替代的理由**。

---

## §4 静默错误清单

| 坑 | 报错？ | 后果 |
| :--- | :---: | :---: |
| **y 轴未翻转** | **否** | 组织上下镜像；图、聚类、统计全部"正常" |
| **把 spot 当细胞** | **否** | 所有"细胞类型比例"结论作废 |
| 未按 `in_tissue` 过滤 | **否** | 组织外背景 spot 参与聚类，产生假的"低表达域" |
| 两类平台共用一套 checkpoint 命名 | **否** | 拿 seq 的中间产物喂 img 的下游，形状碰巧合法 |
| 把 HD 2 µm bin 当观测单位做统计 | **否** | 中位 counts 个位数，检验无意义 |
| 去卷积比例未归一化/含负值 | **否** | 后续比例比较全错 |
| 分割方法换一个就变的结论 | **否** | 把方法产物当生物学 |
| 用非同组织参考做去卷积 | **否** | 给出看似合理的细胞类型构成 |
| 成像型 panel 缺基因被读成"不表达" | **否** | 阴性结论完全站不住 |
| **RCTD 丢弃低 UMI spot 后按位置重新赋 spot ID** | **否** | **每个 spot 拿到别人的比例**。RCTD 会静默丢掉 `UMI < UMI_min` 的 spot，输出行数少于输入；此时 `rownames(prop) <- colnames(counts)` 就整体错位。proj37 实测：修复前后 RCTD vs Tangram 的 Spearman **10/10 个细胞类型全部上升**（Cardiomyocyte 0.676→0.735，Myeloid 0.522→0.571）—— **齐刷刷同向变化正是错位的指纹，而不是噪声** |
| 去卷积只跑一种方法 | **否** | 没有任何东西能发现上面那条错位。**两法并跑 + 逐类型 Spearman 是唯一的探测器** |
| **squidpy `spatial_autocorr` 的 p 值列在无变异基因上是未初始化内存** | **否** | `_p_value_calc` 用 `np.empty` 开数组、按 `z>0`/`z<=0` 两个掩码写入；基因在该切片无变异 ⇒ I=NaN ⇒ z=NaN ⇒ **两个掩码都不覆盖 ⇒ 元素永不被写入**。拿到脏页就是 `pval_norm=2.0`、`pval_norm_fdr_bh=-891`；**拿到零页则全是 `0.0`，看起来毫无异常**，还会变成"最显著"的一批。BH 又对整列做校正，把污染传给有效基因。proj37 实测 FDR<0.05 计数虚高 **20–40 倍**（15,690 → 710），并据此在文档里写下"检验功效极高"的错误解释。**修法=送检前剔除无变异基因 + `assert I.notna().all()`**；详见 [squidpy.md](/home/gao/Utilities/software_pitfalls/squidpy.md) |
| **Tangram `random_state=0` 等于没播种** | **否** | `if self.random_state:` —— 0 是 falsy ⇒ `np.random.seed`/`torch.manual_seed` 整段跳过。proj37 同参数两轮 spot 级比例**最大差 0.29 绝对比例**，两轮都通过"和为 1、无负值"的断言。**与 decoupler `seed=0` 同一家族的第二次** ⇒ 见到 `seed`/`random_state` 先搜源码里的 `if ` 再决定给不给 0。⚠ 改种子时别动兼做参考下采样的那个常量（会毁掉"RCTD 与 Tangram 同一份参考"的前提），**拆成两个**；详见 [tangram.md](/home/gao/Utilities/software_pitfalls/tangram.md) |

---

## §5 断言与代码复用

**canonical 位置（2026-09-17 起，proj37）**：
[`spatial_utils.py`](/home/gao/projects_2026M7/37_spatial_visium_heart_pilot/scripts/_common/spatial_utils.py) 与
[`spatial_utils.R`](/home/gao/projects_2026M7/37_spatial_visium_heart_pilot/scripts/_common/spatial_utils.R)
—— **这两份是现在的原件**，proj24 的 `adv_tut_utils.R` 是更早的 R 版，功能是子集，新项目别再指它。

| 函数 | 在哪 | 抓什么 |
| :--- | :---: | :---: |
| `assert_spatial_coords()` | py | 坐标缺失/大面积重复（查唯一值占比） |
| `assert_yaxis_orientation()` | py | **y 轴方向**（最经典的静默错误） |
| `assert_in_tissue_filtered()` | py | `in_tissue` 是否已过滤、保留比例是否合理 |
| `assert_deconv_proportions()` | py + R | 去卷积比例和为 1、无负值 |
| `assert_reference_same_tissue()` | py | 去卷积参考是否同组织（§3.4 的硬约束） |
| `assert_points_plotted()` | py | 图上点数与 `n_obs` 对得上（静默丢点） |
| **`assert_spot_ids_subset()`** | **R** | **身份对齐** —— RCTD 等会静默丢 spot，输出行数少于输入（§4 那条错位坑的探测器） |
| `save_ckpt()` / `read_ckpt()` | py | **强制 `ckpt_seq_*` / `ckpt_img_*` 前缀**，两类平台命名空间不串 |

**⚠ 这张表里没有、但必须自己写进脚本的两条**（proj37 自测查出来的，见 §4 末两行）：

| 断言 | 拦什么 |
| :--- | :---: |
| `assert uns["moranI"]["I"].notna().all()` | squidpy 给 NaN 行的 p 值是未初始化内存 |
| **同参数跑两遍 + `cmp`/`md5sum` 比产物** | 任何带随机性的步骤（去卷积、置换、随机初始化）。**这不是"可选的额外验证"，是这类步骤唯一的验收方式** —— 单轮 exit=0、断言全过、自审全 PASS 都证明不了结果是确定的 |

> **为什么单独强调第二条**：现有断言查的全是**数值合法性**（和为 1、无负值、点数对得上），
> **没有一条查"换一次运行还是不是这个数"**。proj37 的两个最严重缺陷都恰好通过了全部合法性断言。

Python 侧的**通用**断言（文字层、注释对齐、离群扫描）仍复用 [`sc_tut_utils.py`](/home/gao/projects_2026M7/22_python_based_scRNA_tutorial/scripts/_common/sc_tut_utils.py)。
**跨项目复用工具一律走软链接指向 canonical 原件，不复制**（SSOT）。

---

## §6 上手顺序（没实操经验时照这个走）

| 步 | 做什么 | 目的 |
| :--- | :---: | :---: |
| 1 | **一张 Visium 切片跑通全链条**（QC→归一化→聚类→SVG→去卷积）。**不碰 HD、不碰成像平台** | 建立"观测单位不是细胞"的直觉 |
| 2 | Visium HD（8/16 µm） | 体会分辨率提高后 counts 骤降的统计后果 |
| 3 | Xenium（先用厂商分割） | 体会"分割决定一切"，知道这一步的不确定性有多大 |
| 4 | Voyager ESDA / nnSVG / RCTD（**`spatial_r` 已建好，直接用，别重建**，见 §2.2） | R 路线的差异化能力 |

**混用两个生态的正确形态 = 按阶段切分 + 文件交接**（`.h5ad` / `.zarr` / counts+coords CSV），**不是**在同一脚本里用 reticulate 反复横跳。

---

## §7 交付与报告

- 报告头必须写明 **平台 + Species + Tissue**，并明写**观测单位是 spot/bin 还是分割后的细胞**。
- **必须声明的三件事**：① 分割来源（厂商 / 自做 / 未做）；② 去卷积参考的来源与是否同组织；③ panel 覆盖范围（成像型）。
- 去卷积比例、分割细胞、域标签**都是模型产物**，与实测量分开写。
- 单样本项目：**明确承认做不了跨条件统计**，只给描述与模板。
- 图件只交 PDF；配色走 `/scientific-figure-making`；**同图内语义不同的 panel 绝不共用配色**。
- 交付流程走 `/delivery`，报告体例走 `/report`；对外**只准备不发送**。

**启动语义照旧**：没有"自动/全流程/全过程"三个关键词 ⇒ 只做调研与研究计划。
