# 空间转录组学：R 生态 vs Python 生态，以及当前分析的选型

**版本**：2026-09-10
**作者**：Zhen Gao（与 Claude Opus 5 协作起草）
**读者设定**：**三年前只在同事报告里听过空间转录组，无任何实操经验**。
因此 §1–§2 补齐"这门技术究竟产出什么数据、因此有哪些分析任务"——**不补这一层，
后面的生态比较会变成一串包名**。已经熟悉的人可从 §3 直接开始。

**标注约定**：**【检索】**= 2026-09-10 当天检索到的事实（§9 附来源）；**【判断】**= 我的评估，可反对；
**【未验证】**= 我没查过，不下结论。

**相关文档**（同目录，口径不同、互不替代）：

- [`R_vs_Python_ecosystem_objective_comparison_20260910.md`](R_vs_Python_ecosystem_objective_comparison_20260910.md) —— 单细胞（非空间）的生态对比
- [`scRNAseq_landscape_2023_to_2026_and_ecosystem_choice_20260910.md`](scRNAseq_landscape_2023_to_2026_and_ecosystem_choice_20260910.md) —— 结合本机资产的分工方案

---

## §0 结论先行

### 0.1 对"当前分析"的判定

**当前分析 = 项目 24（`24_R_advanced_scRNA_and_Spatial_tutorial_2026`）的空间部分**：
Visium + Visium HD（seq-based）与 Xenium + CosMx（imaging-based），
数据是 Oliveira 人结肠同组织多平台套装。

> **结论：维持 Bioconductor 主线，不改。** 项目 2026-07-30 的技术决策 **D2** 经本轮核实**依然成立**，
> 而且证据比当初更强（§6）。**这不是"因为已经这么定了"，而是逐条核对后的独立结论。**

**三条支撑**（详见 §6）：

1. **seq-based 这一侧，R 不是"够用"，是"更完整"**：OSTA 已把 Visium HD 拆成
   **binned / segmented 两套独立 workflow** **【检索】**，另有 QC、去卷积、分割等成章节的 SOP；
   Python 侧没有同等密度的教科书级参考。
2. **去卷积这一格 R 拿的是第一梯队**：多项基准里 **RCTD（R 包 `spacexr`）与 cell2location（Python）
   并列最优** **【检索】** —— 选 R **不付性能代价**。
3. **项目已有的 D5 决策（Visium HD 只用 8/16 µm、不碰 2 µm）恰好绕开了 Python 唯一不可替代的那一格**
   （2 µm → 细胞重建，见 §5.3）。**这是巧合性的幸运，不是当初就想到了**——但结论有效。

### 0.2 一句话生态判定

**空间领域两个生态的分工，比单细胞领域更清晰，也更"互补"而非"竞争"：
Python 强在"从原始图像/转录本到细胞"的工程链条，R 强在"拿到细胞/spot 之后的统计"。**

---

## §1 补课：空间转录组到底产出什么数据

**这一节是理解后面一切的前提。空间数据最反直觉的一点是：观测单位往往不是细胞。**

### 1.1 两大类平台，几乎没有共同点

| | **① Sequencing-based（测序型）** | **② Imaging-based（成像型）** |
| :--- | :---: | :---: |
| 代表平台 | Visium、**Visium HD**、Slide-seq、Stereo-seq | **Xenium**、CosMx、MERFISH/MERSCOPE |
| 原理 | 组织切片贴到带空间条码的载片上，就地建库测序 | 探针逐轮杂交成像，**直接看到每个转录本的坐标** |
| **观测单位** | **spot / bin —— 不是细胞** | **transcript（点）→ 需分割成细胞** |
| 基因覆盖 | **全转录组**（无需预选基因） | **panel，数百至数千基因**（近年到 5000 级） |
| 分辨率 | Visium 55 µm（含数个至数十个细胞）；**Visium HD 2 µm bin** | 亚细胞（转录本级） |
| 核心难题 | **去卷积**（一个 spot 里混了哪些细胞类型、各占多少） | **分割**（哪些转录本属于同一个细胞） |

**⇒ 这一条差异决定了下游的一切**：seq-based 的第一难题是"把混合信号拆开"，
imaging-based 的第一难题是"把点聚成细胞"。**两类平台的 QC 指标、分析流程、可用方法几乎不重叠**——
项目 24 的 D1 决策（两类平台代码完全分开）在方法学上是对的。

### 1.2 三年里（2023 → 2026）最大的三个变化

1. **Visium HD 与 Xenium 成为主流**，把领域从"55 µm 大 spot"推到亚细胞尺度 **【检索】**。
   **副作用**：分辨率提高后，**每个观测单位的 counts 极低**——Visium HD 2 µm bin 的中位 counts
   是个位数，**单 bin 做不了统计**，必须 binning 或分割。
2. **分割 (segmentation) 从"厂商给什么用什么"变成一个独立的方法学战场**。
   现在有 Baysor、Proseg、Cellpose、Segger、Bering 等一批方法，
   **不同方法给出的细胞数与细胞类型分布可以差得非常大** **【检索】**——
   *"Bering 预测的细胞数远少于其他方法，Baysor 远多于其他方法"* **【检索】**。
   **⇒ 分割不是预处理细节，它会改变你最终报告里的细胞类型比例。**
3. **数据结构标准化**：Python 侧出现 `SpatialData`（统一存 image + shape + table）**【检索】**，
   R 侧有 `SpatialExperiment` / `SpatialFeatureExperiment`（后者把 `sf`/`terra` 的
   地理空间几何引入）**【检索】**。

### 1.3 因此，空间分析的任务清单

| 任务 | 说明 | 适用平台 |
| :--- | :---: | :---: |
| 空间感知 QC | 常规 QC 之外，还要查**空间上的局部异常**（某片区域整体偏低 = 组织破损还是生物学？） | 两类 |
| 归一化 / 降维 / 聚类 | 与 scRNA 同源，但要考虑空间自相关 | 两类 |
| **SVG**（spatially variable genes） | 表达是否随空间**非随机**分布 | 两类 |
| **空间域识别**（domain detection） | 把切片划成有生物学意义的区域（不是细胞类型，是"组织结构"） | 两类 |
| **去卷积**（deconvolution） | 一个 spot 里各细胞类型占比；**需要同组织的 scRNA 参考** | **① seq-based** |
| **分割**（segmentation） | 转录本 → 细胞 | **② imaging-based**（及 Visium HD 2 µm） |
| 邻域 / 细胞互作 | 哪些细胞类型在空间上互相靠近；配受体分析 | 两类 |
| **空间统计 / ESDA** | 空间自相关（Moran's I 等）、局部异质性、尺度分析 | 两类 |

---

## §2 一个必须先建立的直觉：空间统计不是"多了两列坐标"

**【判断】** 对有十年 R 经验的人，这一点最容易被低估，也最容易迁移：
空间转录组的统计内核，**是地理统计学（geostatistics）那一套**——空间自相关、
邻接权重矩阵、局部指标（LISA）、尺度依赖。这套东西在 R 里有三十年的成熟实现
（`sf` / `terra` / `spdep`），**而这正是 R 生态在空间领域最硬的优势来源**（§4.2）。

---

## §3 两个生态的整体结构

### 3.1 R / Bioconductor 侧

| 层 | 组件 | 作用 |
| :--- | :---: | :---: |
| 数据结构 | `SpatialExperiment` (SPE) | `SingleCellExperiment` + 坐标 + 图像 |
| 数据结构 | `SpatialFeatureExperiment` (SFE) | SPE + **`sf` 几何**（地理空间 Simple Features）**【检索】** |
| 教科书 | **OSTA**（Orchestrating Spatial Transcriptomics Analysis） | **章节级 SOP**，含 Visium HD binned / segmented / 分割等独立 workflow **【检索】** |
| QC | `SpotSweeper` | 空间感知 QC，发表于 **Nature Methods 22:1520–30** **【检索】** |
| SVG | `nnSVG`、`SPARK-X` | 见 §5.1 的基准数字 |
| 域识别 | `BANKSY` | OSTA 用于降维/聚类/域识别 **【检索】** |
| 去卷积 | **`spacexr`(RCTD)**、`SPOTlight` | 基准第一梯队 **【检索】** |
| 空间统计 | **`Voyager`** | 把 geospatial **ESDA** 传统完整引入 **【检索】** |
| 另一条线 | `Seurat` v5 spatial、`semla`、`Giotto` | 与 Bioc 主干平行的入口 |

### 3.2 Python / scverse 侧

| 层 | 组件 | 作用 |
| :--- | :---: | :---: |
| 数据结构 | **`SpatialData`** | 统一存 image / shape / table 的多模态框架 **【检索】** |
| 工程管线 | **`Sopa`** | **technology-invariant**，覆盖 Xenium / Visium HD / MERSCOPE / CosMx / PhenoCycler 等；处理**原始数据**，含分割、聚合、标注 **【检索】** |
| 分析 | `squidpy` | 空间感知算法集；**处理已加工数据，与 Sopa 互补** **【检索】** |
| 去卷积 | `cell2location`、`DestVI`、`Tangram` | cell2location 基准第一梯队、**预测最稳定** **【检索】** |
| 分割 | `Cellpose`、`StarDist`、`bin2cell` | 见 §5.3 |
| 规模 | dask / zarr 惰性加载 | 与单细胞侧同一套路线 |

### 3.3 一个容易被误判的事实：分割工具本身是"多语言 CLI"，不是 Python 包

**【判断】** 常见说法"分割是 Python 的地盘"**只对了一半**：

- `Baysor` 是 **Julia**，`Proseg` 是 **Rust**，`Cellpose`/`StarDist` 才是 Python **【检索】**；
- **真正属于 Python 的是"编排层"**——`Sopa` 把这些异构工具串成一条可跑的管线 **【检索】**；
- **R 侧并非没有相关内容**：OSTA 有独立的 **Segmentation 章节** **【检索】**。

**⇒ 准确的说法是：分割这件事的"调度与工程化"在 Python 更成熟，而分割算法本身两个生态都要外调。**

---

## §4 逐任务对比（本文的核心表）

| 任务 | R 侧 | Python 侧 | 判定 |
| :--- | :---: | :---: | :---: |
| 数据结构（多模态/图像） | SPE / SFE | **SpatialData** | **Python 优**：统一 image+shape+table |
| 数据结构（几何运算） | **SFE + `sf`/`terra`** | GeoPandas 扩展 AnnData **【检索】** | **R 优**（成熟度） |
| 空间感知 QC | **SpotSweeper**（Nat Methods）**【检索】** | squidpy 内零散实现 | **R 优** |
| SVG | nnSVG、**SPARK-X** | SpatialDE2、squidpy Moran's I | **R 略优**（见 §5.1） |
| 空间域识别 | BANKSY、PRECAST | squidpy + 外部方法 | **平手** **【判断】** |
| **去卷积** | **RCTD / SPOTlight** | **cell2location / DestVI** | **平手**（两边都在第一梯队 **【检索】**） |
| **分割编排** | 有章节，无成熟管线 **【判断】** | **Sopa** **【检索】** | **Python 单极** |
| **2 µm → 细胞重建** | 无对等物 **【判断】** | **bin2cell**、10x 官方 StarDist+scanpy 流程 **【检索】** | **Python 单极** |
| 邻域 / 细胞互作 | 有实现 | **squidpy 更成套** **【检索】** | **Python 略优** |
| **空间统计 / ESDA** | **Voyager** | 无对等物 | **R 单极**（见 §4.2） |
| 教学/SOP 资源密度 | **OSTA 全书** **【检索】** | 分散在各包 tutorial | **R 优** |
| 超大数据规模 | BPCells 路线（非空间专用） | Sopa **可扩展到百万细胞** **【检索】** | **Python 优** |

### 4.1 Python 的单极：从原始数据到细胞

`Sopa` 的定位是**处理原始数据**（分割、转录本聚合、标注、几何分析），
而 `squidpy` 处理**已加工数据**，两者互补 **【检索】**。
**R 侧没有与 Sopa 对等的"原始数据 → 细胞矩阵"的技术无关管线** **【判断】**。

**⇒ 若你的起点是厂商原始输出、且需要自己重做分割，Python 是现实答案。**

### 4.2 R 的单极：空间统计的深度

`Voyager` 作者的明确论断（论文原文）：**Seurat、squidpy、Giotto、semla 都只实现了部分空间方法，
没有系统实现完整的 ESDA 传统**，尤其缺**空间自相关的尺度分析**与**局部空间异质性** **【检索】**。

**⇒ 若你要问的是"这个空间格局在什么尺度上成立""哪里是局部热点"这类问题，R 目前是唯一完整的答案。**

---

## §5 三个会实际影响结论的方法学细节

### 5.1 SVG：nnSVG 不是基准里的第一名

一项 **14 种方法 × 96 个数据集 × 6 个指标**的系统基准 **【检索】**：

| 方法 | 平均相关性 | 备注 |
| :--- | :---: | :---: |
| **SPARK-X** | **0.88** | 一致最优；**R 包** |
| SpatialDE2 | 0.81 | Python |
| **nnSVG** | 0.80 | **R 包**；OSTA 主推 |
| **Moran's I** | 0.76 | **最简单的方法，第四名** |

**【判断】** 两条可操作的含义：

1. **Moran's I 作为基线强得出乎意料**（0.76 vs 0.88）。任何 SVG 结果都应该先和 Moran's I 比一比——
   **复杂方法若赢不了它，就没有使用理由**。
2. **不同方法在不同空间模式上强弱相反** **【检索】**：SPARK-X / nnSVG / Moran's I 对
   "小区域高表达、其余为零"这类模式**准确率都低**，而 SpatialDE2 / SPARK / Sepal 在该模式上强、
   在另一类模式上弱。**⇒ 不存在单一最优 SVG 方法，报告里应说明用了哪种、它对哪类模式不敏感。**
3. 这一格**不构成换生态的理由**——第一名 SPARK-X 本身就是 R 包。

### 5.2 去卷积：选 R 不付代价，但必须有同组织 scRNA 参考

- 基准结论：**cell2location、SPOTlight、RCTD 是最优的一组**；cell2location **预测最稳定**，
  在三个数据集上均列第一；另一项 11 方法 × 63 合成 + 3 binned + 2 真实数据的基准
  **推荐 RCTD 与 cell2location** **【检索】**。
- **【判断】** 因此 R 侧用 `spacexr`(RCTD) **不是妥协**。
- **⚠ 真正的硬约束不在生态，在数据**：去卷积**需要同组织的 scRNA-seq 参考**。
  项目 24 的数据清单里 `Chromium_HumanColon_Oliveira` 正是为此准备的——**这个选择是对的**。

### 5.3 分割：这是 Python 唯一不可替代的一格

- **方法之间差异巨大**：Proseg 比 Baysor **快约一个数量级、省约一个数量级内存**；
  不同方法给出的细胞数与细胞类型分布差异显著 **【检索】**。
- **Visium HD 2 µm 的正确用法不是"当作观测单位"**，而是作为**分割/细胞重建的输入**：
  `bin2cell` 利用形态学图像分割 + 表达信息重建细胞 **【检索】**；
  10x 官方流程是 **StarDist 分割 → 按 mask 汇总表达 → scanpy 下游** **【检索】**。
  **这条链条全在 Python。**
- **好消息**：Xenium / CosMx / MERSCOPE **都自带厂商的转录本→细胞核初分配** **【检索】**，
  OSTA 也说明 **Space Ranger v4 的 Visium HD 细胞级分割结果可直接读成 `SpatialExperiment`** **【检索】**。
  **⇒ 只要接受厂商分割，R 侧全程自洽。**

---

## §6 对"当前分析"的具体判定（项目 24）

### 6.1 结论：维持 Bioconductor 主线

| 项目 24 的原决策 | 本轮核实 | 判定 |
| :--- | :---: | :---: |
| **D1** 两类平台代码完全分开 | §1.1 显示两类平台观测单位/QC/方法几乎无交集 | **强化** |
| **D2** 空间部分走 Bioc 主线、Seurat 作对照 | OSTA 已扩到含 Visium HD binned/segmented/分割等成套 workflow **【检索】** | **强化** |
| **D5** Visium HD 只用 8/16 µm、不用 2 µm | 2 µm 的真实用途就是分割输入，而那条链在 Python **【检索】** | **强化**（恰好避开唯一的 Python 单极） |
| 去卷积用 `spacexr` + `SPOTlight` | 两者均在基准第一梯队 **【检索】** | **成立** |
| 用 `nnSVG` 做 SVG | 基准里 SPARK-X(0.88) > SpatialDE2(0.81) > nnSVG(0.80) **【检索】** | **可改进，见 6.2** |

### 6.2 三条具体建议（都不需要换生态）

1. **SVG 增加两条对照**：在 `nnSVG` 之外**加跑 `SPARK-X` 与 Moran's I**。
   两者都是 R 侧现成的，成本极低，而**能把"方法依赖性"直接展示给读者**——
   对一份教程而言，这比只给一个方法的结果更有价值。**【判断】**
2. **分割这一格明确写成"边界"而不是跳过**：在 imaging-based 部分**说明厂商分割的局限**
   （不同方法细胞数差异巨大 **【检索】**），并指出重做分割属于 Python/Sopa 的领域。
   **诚实标注边界，与项目 D10 已确立的做法一致。**
3. **把 `Voyager` 当作 R 主线的"卖点"而不是可选项** **【判断】**：
   它是这条路线上 Python 拿不出对等物的部分（§4.2）。教程若只做"R 也能做 squidpy 那些事"，
   就浪费了选 Bioc 的最大理由。

### 6.3 什么情况下应该换 / 混用

| 触发条件 | 应该怎么做 |
| :--- | :---: |
| 需要**自己重做分割**（不接受厂商结果） | 走 Python：`Sopa` 编排 + Proseg/Baysor/Cellpose |
| 要用 **Visium HD 2 µm 做细胞级分析** | 走 Python：`bin2cell` 或 StarDist + scanpy |
| 数据量到**百万细胞级**的成像平台 | 走 Python：Sopa 明确宣称可扩展到该量级 **【检索】** |
| 需要**空间统计的尺度/局部分析** | 留在 R：`Voyager` |
| 需要**同组织去卷积** | 两边都行，**不构成换生态的理由** |

**【判断】** 混用的正确形态是**按阶段切分 + 用文件交接**（导出 `h5ad`/`zarr`），
**不是**在同一脚本里用 reticulate 反复横跳——后者是项目 D3 已经识别过的风险来源。

---

## §7 给"无实操经验"的最短上手路径

**【判断】** 按项目 24 的既定结构，建议这个顺序（每步的目的写在后面）：

1. **先跑通一张 Visium 切片的完整链条**（QC → 归一化 → 聚类 → SVG → 去卷积）。
   目的：建立"观测单位不是细胞"的直觉。**这一步不要碰 HD、不要碰成像平台。**
2. **再做 Visium HD（8/16 µm）**。目的：体会分辨率提高后 counts 骤降带来的统计后果。
3. **再进 Xenium**。目的：体会"分割决定一切"——**建议同一切片用厂商分割看一次结果**，
   哪怕不重做分割，也要知道这一步的不确定性有多大。
4. **最后做 Voyager 的 ESDA**。目的：这是 R 路线的差异化能力，也是你十年 R 经验最能直接迁移的部分。

**最该避免的两个坑** **【判断】**：

- **把 spot 当细胞**：Visium 一个 spot 含数个至数十个细胞，任何"细胞类型比例"的说法
  在去卷积之前都不成立。
- **y 轴方向**：图像坐标系与绘图坐标系的 y 轴方向相反，是空间转录组**最经典的静默错误**——
  图看起来完全正常，但上下翻转。项目 24 的 `assert_yaxis_flipped()` 断言正是为此而设，**务必保留**。

---

## §8 我不确定 / 有争议的地方

1. **OSTA 的版本对应**：检索同时命中了 `books/release/OSTA` 与 `books/3.22/OSTA` 两套页面 **【检索】**，
   我未逐页确认 release 当前指向哪个 Bioc 版本。**章节编号在不同版本间有偏移**（如
   "Workflow: Visium HD (binned)" 在一处是第 15 章、另一处是第 16 章）——**引用时要写版本号**。
2. **Python 侧是否有 Voyager 的对等物** **【未验证】**——我依据的是 Voyager 论文自身的论断，
   那是**作者对自己工作的定位**，有立场；我没有独立核实 squidpy 近两年是否补上了尺度分析。
3. **SVG 基准的适用范围** **【未验证】**——该基准的 96 个数据集以哪些平台为主我没有核实；
   对 Visium HD / Xenium 这类新平台是否同样成立，不确定。
4. **`semla` / `Giotto` 的现状** **【未验证】**——本文按"平行入口"一笔带过，没有实际评估。
5. **成像平台的 counts 深度与 panel 设计对下游的影响** **【未验证】**——检索命中了一篇
   *"Resolving sensitivity, specificity and signal contamination in Xenium"* **【检索】**，
   我没有读，只知道存在这个议题。

---

## §9 来源（2026-09-10 检索）

**Bioconductor / R 侧**

- [OSTA — Workflow: Visium HD (binned)](https://bioconductor.org/books/release/OSTA/pages/seq-workflow-visium-hd-bin.html)
- [OSTA — Workflow: Visium HD (segmented)](https://bioconductor.org/books/release/OSTA/pages/seq-workflow-visium-hd-seg.html)
- [OSTA — Deconvolution](https://bioconductor.org/books/release/OSTA/pages/seq-deconvolution.html)
- [OSTA — Segmentation](https://bioconductor.org/books/release/OSTA/pages/img-segmentation.html)
- [OSTA — Infrastructure](https://bioconductor.org/books/release/OSTA/pages/bkg-infrastructure.html)（SpatialData / squidpy 的定位描述）
- [Voyager: exploratory single-cell genomics data analysis with geospatial statistics (PMC)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10461913/)
- [nnSVG (Nature Communications)](https://www.nature.com/articles/s41467-023-39748-z)

**Python 侧**

- [Sopa: a technology-invariant pipeline for image-based spatial omics (Nature Communications)](https://www.nature.com/articles/s41467-024-48981-z)
- [Sopa — GitHub](https://github.com/gustaveroussy/sopa)
- [Bin2cell reconstructs cells from high resolution Visium HD data (Bioinformatics)](https://academic.oup.com/bioinformatics/article/40/9/btae546/7754061)
- [10x — Nuclei Segmentation and Custom Binning of Visium HD](https://www.10xgenomics.com/analysis-guides/segmentation-visium-hd)

**基准**

- [Systematic benchmarking of computational methods to identify spatially variable genes (Genome Biology)](https://genomebiology.biomedcentral.com/articles/10.1186/s13059-025-03731-2)
- [Benchmarking algorithms for spatially variable gene identification (Bioinformatics)](https://academic.oup.com/bioinformatics/article/41/4/btaf131/8096371)
- [Spotless: benchmarking cell type deconvolution (eLife)](https://elifesciences.org/articles/88431)
- [A comprehensive benchmarking with practical guidelines for cellular deconvolution (Nature Communications)](https://www.nature.com/articles/s41467-023-37168-7)
- [Proseg — GitHub](https://github.com/dcjones/proseg)
- [Optimizing Xenium In Situ data utility (Nature Methods)](https://www.nature.com/articles/s41592-025-02617-2)
- [Resolving sensitivity, specificity and signal contamination in Xenium (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC13259927/)
