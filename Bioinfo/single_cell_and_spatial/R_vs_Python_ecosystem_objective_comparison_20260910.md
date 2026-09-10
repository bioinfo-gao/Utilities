# 单细胞分析：R 生态 vs Python 生态的客观对比与趋势判断

**版本**：2026-09-10
**作者**：Zhen Gao（与 Claude Opus 5 协作起草）
**定位**：**纯生态对比**。评价对象是两个生态**本身**的当前能力与演进方向，
**不考虑任何一方是否已在本机安装**，也不把"迁移成本""学习曲线"当作生态优劣的证据。
安装与配置一律视为**零门槛**处理。

**与既有文档的关系**：本文**不替代、不修改**同目录
[`scRNAseq_landscape_2023_to_2026_and_ecosystem_choice_20260910.md`](scRNAseq_landscape_2023_to_2026_and_ecosystem_choice_20260910.md)。
那一篇的落点是"**给定本机资产，怎么分工**"；本文的落点是"**抛开资产，两个生态各自什么水平、往哪走**"。
两篇结论若不一致，是**口径不同**，不是其中一篇错。

**标注约定**：**【检索】** = 2026-09-10 当天检索到的事实（附来源）；**【判断】** = 我的评估，可以反对；
**【未验证】** = 我没查过，不作结论。

---

## §0 结论先行

### 0.1 一句话

**两个生态在"通用分析主干"上已经基本对等，差距集中在两个方向相反的单极地带：
深度概率建模与超大规模计算是 Python 单极，统计推断与实验设计是 R 单极。**
**【判断】** 这两个单极在可预见的 12–24 个月内**都不会被对方补上**——因为它们各自扎根于
底层依赖（PyTorch / GPU 栈 vs 三十年的统计建模包与其审稿共识），而不是"某个包还没人写"。

### 0.2 逐环节裁定

| 环节 | 优势方 | 差距量级 | 依据 |
| :--- | :---: | :---: | :---: |
| 数据结构与磁盘格式 | **Python 略优** | 小 | AnnData/`h5ad`+`zarr` 事实上成为跨语言交换格式；R 侧三个对象模型并存 |
| QC / 归一化 / HVG / 降维聚类 | **平手** | 无 | 两边算法同源，差异在 API 风格不在能力 |
| 批次整合 (integration) | **平手偏 Python** | 小 | Harmony/scVI/Seurat 三足鼎立，其中 scVI 只在 Python 原生 |
| **深度概率建模 / 生成模型** | **Python 单极** | **极大** | scvi-tools 全家（scVI/scANVI/totalVI/DestVI/scArches…）无 R 原生对等物 |
| 单细胞基础模型 (foundation models) | **Python 单极** | **极大** | scGPT/Geneformer 及其后继全部为 PyTorch 生态 |
| **差异表达 / 多样本统计推断** | **R 单极** | **大** | limma / edgeR / DESeq2 / glmmTMB / muscat / propeller，且是审稿共识的锚点 |
| 实验设计、混合效应、复杂对照 | **R 单极** | **大** | 公式接口 (`~ a + b + (1\|donor)`) 与其诊断工具是 R 的原生语法层能力 |
| 轨迹 / RNA velocity | **Python 优** | 中 | scVelo/CellRank 是参考实现；R 侧 slingshot/tradeSeq 强在**沿轨迹的统计检验** |
| 空间转录组：数据结构与多模态 | **Python 优** | 中 | SpatialData 统一了 image+shape+table 的多模态存储 |
| 空间转录组：**空间统计** | **R 优** | 中 | Voyager/SpatialFeatureExperiment 把 geospatial ESDA 传统完整搬入 |
| 超大规模（>1e6 cells） | **两边都有解，路线不同** | — | R: BPCells 磁盘流式；Python: dask+zarr（仍标注 experimental）+ GPU |
| GPU 加速 | **Python 单极** | 大 | rapids-singlecell；R 侧无对等物 **【判断】** |
| 出版级绘图 | **R 优** | 中 | ggplot2 语法一致性与细粒度控制仍无对手 **【判断】** |
| 生态治理与可复现性 | **R 优** | 中 | Bioconductor 半年一版 + 全量反向依赖检查，是制度性保证 |

---

## §1 三层结构性差异（比"哪个包多"重要得多）

### 1.1 发布治理：制度化 vs 去中心化

| | Bioconductor | PyPI / conda-forge |
| :--- | :---: | :---: |
| 发布节奏 | **固定半年一版** | 各包自行其是 |
| 版本耦合 | **与 R 主版本硬绑定** | 与 Python 版本松绑定 |
| 入库门槛 | 强制 review + 全量反向依赖每日构建 | 基本无门槛 |
| 当前版本 | **3.23（2026-04-29，需 R 4.6，2418 个软件包）【检索】** | scanpy **1.12.4（2026-08-27，需 Python ≥3.12）【检索】** |

**这条差异的两面**：

- **正面**：Bioconductor 的"同一版本内所有包互相兼容且每天被真实构建验证"，是 Python 侧
  **结构上不存在**的保证。跨包组合出来的分析在 R 侧更不容易因为版本漂移而静默改变结果。
- **负面**：**版本耦合是硬的**。Bioc 3.23 要求 R 4.6 **【检索】**；停在旧 R 上就等于停在旧 Bioc 上，
  **且没有"只升级单个包"这个选项**。Python 侧则相反——升级自由，代价是依赖冲突常态化。

**【判断】** 这不是"谁更好"，是**两种风险的交换**：R 把风险集中到"半年一次的整体升级"，
Python 把风险分散成"任意时刻的局部冲突"。做长期可复现的项目，前者更省心；追新方法，后者更省心。

### 1.2 对象模型：Python 一家 vs R 两家半

- **Python**：`AnnData` 一个对象贯穿 scanpy / scvi-tools / squidpy / scVelo；多模态用 `MuData`，
  空间用 `SpatialData`。**同一个内存对象在整个生态里流动，不需要转换。**
- **R**：`SingleCellExperiment`（Bioconductor 主干，70+ 个包的通用货币 **【检索】**）
  与 `Seurat` 对象（Satija lab 生态）**长期并存**，另加空间侧的 `SpatialExperiment` /
  `SpatialFeatureExperiment`。两大对象之间转换是家常便饭，且转换**不总是无损**。

**【判断】** 这是 R 侧最实在的一处劣势，而且是**社会结构问题不是技术问题**——
Seurat 与 Bioconductor 是两个独立的开发与文化中心，不会合并。

### 1.3 计算后端：磁盘流式 vs 惰性数组 + GPU

| | R 路线 | Python 路线 |
| :--- | :---: | :---: |
| 主力方案 | **BPCells**：bitpacking 压缩 + 磁盘流式 | **dask + zarr** 惰性加载 / out-of-core |
| 成熟度 | 已发表并有基准 **【检索】** | scanpy 侧多数函数**仍标注 experimental【检索】** |
| 实测口径 | 内存需求降低近 **70 倍**，速度几乎不损；在 3 小时 / 256 GB 限制下，**最大数据集只有 BPCells 跑得完【检索】** | 强项在**远程/云端只取所需切片** **【检索】** |
| GPU | 无对等物 **【判断】** | **rapids-singlecell** **【检索】** |

**【判断】** 这一格常被简化成"Python 更能扛大数据"，**按当前证据这个说法站不住**：
纯 CPU 的百万级到千万级单机分析，**R 的 BPCells 目前是更成熟的答案**。
Python 的优势在**云端/远程数据**与 **GPU**，不在"单机大矩阵"本身。

---

## §2 两个单极地带（本文最重要的一节）

### 2.1 Python 单极：深度概率建模

`scvi-tools` 覆盖整合 (scVI/scANVI)、注释 (CellAssign)、多模态 (totalVI)、
空间去卷积 (Stereoscope/DestVI)、doublet (Solo)、迁移学习 (scArches) **【检索】**，
统一建在 PyTorch + AnnData 之上。

**R 侧的现状不是"有个差一点的对等物"，而是"没有原生实现"**：Bioconductor 的 `scviR`
自我描述为 *"a very elementary approach to interfacing between R, Bioconductor and scvi-tools"*
**【检索】** —— 它是**通过 reticulate 调用同一个 Python 包**，不是 R 的独立实现。

**⇒ 结论：在这一格，"选 R"实际上等于"选 R 调 Python"**，而不是"用 R 的方案"。
单细胞基础模型（scGPT / Geneformer 及后继）情况相同且更极端。

### 2.2 R 单极：统计推断与实验设计

**这一格的不对称同样彻底，只是方向相反，且常被 Python 侧文档轻描淡写。**

- **伪重复 (pseudo-replication) 已是审稿门槛**：把细胞当独立重复会**显著抬高 FDR**；
  多项基准一致认为**正确设置下 pseudobulk 方法优于混合模型，也优于 cell-level 检验** **【检索】**。
- **pseudobulk 之后落到哪儿**：`DESeq2` / `edgeR`（LRT、QLF）/ `limma`（trend、voom）
  —— 六种主流实现**全部在 R** **【检索】**。
- **【判断】** 更关键的是**语法层能力**：R 的 formula 接口 (`~ condition + batch + (1|donor)`)
  加上 `contrast` / `design matrix` 的成套工具与诊断，让"复杂对照怎么设"成为**可表达、可复核**的东西。
  Python 侧要么绕回 R，要么用 `statsmodels`/`pydeseq2` 处理有限的设计。
- **【判断】** 还有一层**社会性事实**：审稿人对 `DESeq2`/`limma` 的输出有三十年的直觉，
  这本身构成一种不可替代的"沟通带宽"。这不是技术优势，但它真实影响交付。

**⇒ 结论：在这一格，"选 Python"实际上等于"选 Python 调 R"或"接受更弱的统计表达力"。**

---

## §3 逐环节细看（只写有实质差异的）

### 3.1 空间转录组：两边强在完全不同的地方

- **Python / scverse**：`SpatialData` 解决的是**多模态存储与对齐**——image、shape、table
  在一个框架里统一表示 **【检索】**；`squidpy` 提供成套空间感知算法 **【检索】**。
- **R / Bioconductor**：`Voyager` + `SpatialFeatureExperiment` 把**地理空间统计 (ESDA)**
  完整引入——底层用 `sf`/`terra`，支持几何操作，覆盖 Visium、Slide-seq、Xenium、CosMX、
  MERFISH、seqFISH、CODEX **【检索】**。其作者明确指出：Seurat、squidpy、Giotto、semla
  **都只实现了部分空间方法，没有系统实现完整的 ESDA 传统**，尤其缺**空间自相关的尺度分析
  与局部异质性** **【检索】**。

**【判断】** 所以空间这块不该问"哪个生态更强"，该问"你要做的是数据工程还是空间统计"：
**大规模多模态对齐 → Python；空间统计的深度 → R。**

### 3.2 轨迹分析

**【判断】** Python 的 scVelo/CellRank 是 RNA velocity 的参考实现；但**沿轨迹做统计检验**
（tradeSeq 那一类"表达随 pseudotime 变化是否显著"）R 侧更完整。这是 §2.2 那个单极的延伸表现。

### 3.3 互操作：正在从"跨语言调用"转向"原生读写"

**这是过去两年最实质的一个变化 【检索】**：

| 方案 | 机制 | 代价 |
| :--- | :---: | :---: |
| `zellkonverter` | 经 **reticulate** 调 Python 的 anndata 再转换 **【检索】** | R 用户**仍需维护一个 Python 环境**，且存在**内存内数据重复** **【检索】** |
| `anndataR` | **R 原生**读写 `h5ad` / `zarr`，无需 Python 环境 **【检索】** | 新，覆盖面待观察 **【未验证】** |

**【判断】** 方向很明确：**交换格式（h5ad/zarr）正在取代语言桥（reticulate/rpy2）成为互操作的主路径。**
这对 R 用户是**结构性利好**——它把"想用 Python 的某个模型就得把整个分析搬过去"降级成"导出一个文件"。

---

## §4 发展趋势（12–24 个月，全部为 **【判断】**，附证据基础）

1. **基础模型退潮到"任务相关"，而不是全面胜出。**
   2026 年多项独立基准显示：零样本下 Geneformer 与 scGPT **不及 HVG 基线**；
   在聚类上不如 HVG + scVI + Harmony；**无参数的简单线性方法在多个基准上达到或接近 SOTA，
   在分布外任务上还更好** **【检索】**。收益强烈依赖任务——细胞类型注释获益明显，
   扰动预测获益有限 **【检索】**。
   **⇒ 判断**：这一格 Python 仍是单极，但**"单极"的实际价值被基准压缩了**。
   不会用基础模型，在 2026–2027 并不构成方法学劣势。

2. **out-of-core 与远程访问成为默认假设。** scverse 的核心工作正是让 AnnData/MuData/SpatialData
   适配远程访问与 out-of-core **【检索】**。R 侧 BPCells 已经在磁盘流式上给出更成熟的实现 **【检索】**。
   **⇒ 判断**：两边会在这一格收敛，Python 的相对优势会从"能不能扛"转移到"云端原生"。

3. **GPU 差距会扩大而不是缩小。** rapids-singlecell 有明确的工程投入 **【检索】**，
   R 侧没有可比的组织性投入 **【判断】**。

4. **统计推断这一格 Python 不会追上。** **【判断】** 依据是它的瓶颈不在包，
   而在语言层的 formula/contrast 表达力与三十年的方法学沉淀。

5. **R 的真实风险不是"包不够"，是"版本耦合 + 对象分裂"。** **【判断】**
   Bioc 与 R 主版本硬绑定（3.23 → R 4.6 **【检索】**），叠加 SCE/Seurat 两套对象，
   长期看是持续的摩擦源。

6. **语言层面的宏观趋势对 R 不利，但对"单细胞里的 R"影响有限。** **【判断】**
   通用开发者调查里 Python 占比 57.9% 而 R 不足 5% **【检索】**，
   但单细胞领域的实际分布远比这个数字均衡——Bioconductor 仍是学界与业界的标准工具链 **【检索】**。
   **不要用通用语言流行度推断单细胞生态的走向。**

---

## §5 版本现状（2026-09-10 核实）

| 组件 | 当前版本 | 备注 |
| :--- | :---: | :---: |
| Bioconductor | **3.23**（2026-04-29） | 需 **R 4.6**；2418 个软件包 **【检索】** |
| Seurat | **5.5.1**（2026-06-25） | CRAN **【检索】** |
| scanpy | **1.12.4**（2026-08-27） | 需 **Python ≥3.12** **【检索】** |
| scvi-tools | **1.5.1** | 发布日期未取到 **【未验证】** |

> **⚠ 与旧文的一处事实差异**：同目录 `scRNAseq_landscape_..._20260910.md` §1.10 把
> **Bioconductor 3.22** 记为当前版本。按 Bioconductor 官方发布公告页，3.22 发布于
> **2025-10-30**，**3.23 已于 2026-04-29 发布**并成为 current release **【检索】**。
> 本文按 3.23 记。**旧文按用户要求未作修改**，此处仅登记差异供回溯。

---

## §6 对一个"写了十年 R"的分析者，这些差异的客观含义

**（这一节仍不涉及"已经装了什么"，只涉及能力边界。）**

| 若主力选 R | 若主力选 Python |
| :--- | :---: |
| 通用主干、统计推断、空间统计、绘图**全部不吃亏** | 通用主干、深度模型、GPU、云端规模**全部不吃亏** |
| 深度概率建模只能经 reticulate 调 Python（`scviR` 明确定位为 interface **【检索】**） | 严肃的多样本统计推断通常要回落到 R，或接受更弱的设计表达力 **【判断】** |
| 需接受 Bioc↔R 版本硬耦合与 SCE/Seurat 双对象 | 需接受依赖冲突常态化与 out-of-core 仍 experimental **【检索】** |
| 大矩阵单机分析有 BPCells，**这一格不弱反强【检索】** | 大矩阵优势主要在 GPU 与远程 zarr |

**【判断】** 因此客观结论是：**十年 R 经验在 2026 的单细胞领域没有贬值**，
它恰好覆盖了 Python 生态最薄的那一格（统计推断与实验设计）。
真正无法用 R 完成的只有一格——**深度概率建模与基础模型**——而这一格
**当前的实证收益正在被基准研究压缩**（§4.1）。

---

## §7 我不确定 / 有争议的地方

1. **`anndataR` 的实际覆盖面与稳定性** **【未验证】**——它是本文"互操作正在变简单"这一判断的
   主要支点，但我没有跑过它。
2. **R 侧 GPU 的真实空白程度** **【判断】**——我没有系统检索过 R 的 GPU 单细胞方案，
   只能说没有看到与 rapids-singlecell 对等的东西。
3. **BPCells 与 dask/GPU 路线的直接对比** **【未验证】**——两边的基准来自不同论文、
   不同硬件与数据集，**不能直接对齐**。§1.3 那张表是两条独立证据的并列，不是同一实验的对照。
4. **绘图优势的量级** **【判断】**——ggplot2 vs matplotlib/plotnine 的差距有多少是能力、
   多少是习惯，我无法客观切分。

---

## §8 来源（2026-09-10 检索）

- [Bioconductor — Release Announcements](https://bioconductor.org/about/release-announcements/)（3.23 / 2026-04-29 / R 4.6 / 2418 包）
- [Bioconductor 3.22 Released](https://bioconductor.org/news/bioc_3_22_release/)（3.22 发布于 2025-10-30）
- [Bioconductor — SingleCellExperiment](https://bioconductor.org/packages/SingleCellExperiment)（70+ 包的通用货币）
- [Seurat 5.5.1 — CRAN](https://cran.r-project.org/web/packages/Seurat/Seurat.pdf)
- [scanpy — PyPI](https://pypi.org/project/scanpy/)（1.12.4 / 2026-08-27 / Python ≥3.12）
- [scverse — packages](https://scverse.org/packages/)、[Scaling the foundations of scverse (Wellcome)](https://wellcome.org/research-funding/funding-portfolio/funded-grants/scaling-foundations-scverse)（out-of-core / 远程访问路线）
- [scanpy GitHub](https://github.com/scverse/scanpy)（dask 兼容仍标注 experimental）
- [scvi-tools GitHub](https://github.com/scverse/scvi-tools)（模型覆盖面）
- [scviR vignette (Bioconductor)](https://bioconductor.org/packages//release/bioc/vignettes/scviR/inst/doc/scviR.html)（自述为 elementary interface）
- [Scalable high-performance single cell data analysis with BPCells](https://www.biorxiv.org/content/10.1101/2025.03.27.645853.full.pdf)（~70× 内存下降；3h/256GB 限制下的唯一完成者）
- [GPU-accelerated single-cell analysis at scale with rapids-singlecell](https://arxiv.org/pdf/2603.02402)
- [Parameter-free representations outperform single-cell foundation models](https://arxiv.org/pdf/2602.16696)
- [Benchmarking zero-shot single-cell foundation model embeddings](https://www.biorxiv.org/content/10.64898/2026.03.10.710748v1.full)（不及 HVG 基线）
- [Evaluating the learnability of single-cell large language models (BMC Genomics)](https://link.springer.com/article/10.1186/s12864-026-12975-6)（收益依任务而定）
- [A balanced measure shows superior performance of pseudobulk methods](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9780232/)
- [Single-cell differential expression analysis between conditions within nested settings (Brief Bioinform)](https://academic.oup.com/bib/article/26/4/bbaf397/8232550)
- [Confronting false discoveries in single-cell differential expression (Nat Commun)](https://www.nature.com/articles/s41467-021-25960-2)
- [Voyager: exploratory single-cell genomics data analysis with geospatial statistics (PMC)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10461913/)
- [OSTA — Infrastructure (Bioconductor)](https://bioconductor.org/books/release/OSTA/pages/bkg-infrastructure.html)（SpatialData / squidpy 定位）
- [anndataR improves interoperability between R and Python (Bioinformatics)](https://academic.oup.com/bioinformatics/article/42/6/btag288/8675377)
- [zellkonverter (Bioconductor)](https://bioconductor.org/packages/zellkonverter/)
- [R vs Python 2026 usage](https://tech-insider.org/r-vs-python-2026/)（通用语言层面的占比，非单细胞领域）

## §9 相关文档

- 同目录 [`scRNAseq_landscape_2023_to_2026_and_ecosystem_choice_20260910.md`](scRNAseq_landscape_2023_to_2026_and_ecosystem_choice_20260910.md) —— 结合本机资产的分工方案（口径不同，见文首）
- `../splicing/splicing_bioinformatics_review_20260905.md` —— 同类"空窗期重新校准"综述，体例可对照
