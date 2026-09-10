# 单细胞转录组分析：2023 → 2026 的变化，与 Python / R 生态选型

**版本**：2026-09-10
**作者**：Zhen Gao（与 Claude Opus 5 协作起草）
**定位**：写给**三年前（≈2023）系统做过 scRNA-seq、此后未实际上手**的分析者。因此本文**不做基础科普**（不解释什么是 UMAP、什么是 HVG），篇幅集中在三件事：

1. **这三年真正变了什么** —— 哪些做法从"可选"变成"审稿门槛"，哪些当年的标准操作现在会被挑错；
2. **Python 还是 R** —— 不按信仰答，按**分析环节逐项判定**，并结合本机已有资产给出可执行的分工；
3. **重新入场的最短路径** —— 手上已有的三个教程项目怎么用，先跑哪个。

> ⚠ **可靠性标注约定**（沿用 `Bioinfo/splicing/` 那份综述）：
> **【实测】** = 本次在本机跑命令得到的事实（附路径/命令）；
> **【检索】** = 2026-09-10 本次 web 检索得到，出处见 §9；
> **【文献】** = 已发表 benchmark/论文的结论；
> **【判断】** = 我的方法学意见，你可以不同意。
> 我的模型知识截止 **2026-05**，2026-05 之后的事实一律走【检索】并标注。**引用前请自行核对 DOI/版本号。**

---

## §0 结论先行（只读这一节也够用）

### 0.1 生态选型的结论

> **Python（scverse）做主线，R 保留三块阵地，两者用文件交换而不是进程内互操作。**

| | 内容 | 为什么 |
| :--- | :---: | :---: |
| **主线 = Python** | scanpy + anndata + scvi-tools + squidpy | 主线全环节覆盖；轨迹/velocity/GRN/扰动四块 R 侧没有对等物；本机 4 个 env 已装好可用 |
| **R 阵地 ①** | **pseudobulk 跨条件 DE**：DESeq2 / edgeR / limma-voom | 审稿人认的是**原版**，不是移植版。且你在 bulk RNAseq 项目里天天用，零学习成本 |
| **R 阵地 ②** | **空间转录组的统计方法**：nnSVG / spacexr(RCTD) / Banksy / SpaNorm / SpotSweeper | Bioconductor 侧生态明显更全（OSTA 40 章 vs Seurat 2 个 vignette）——**这是你自己 proj24 调研出的结论** |
| **R 阵地 ③** | **出版级绘图**：ggplot2 + ComplexHeatmap | 交付图件质量的天花板更高，且你已有 `scientific-figure-making` skill 的 house style |
| **⛔ 不要做** | rpy2 / reticulate 做**进程内**实时互操作 | 最脆的一环：它把两个生态的依赖冲突叠加起来，且报错点离真因极远 |
| **✅ 桥怎么搭** | 导出中间产物成文件：`.h5ad`（对象级）或 **pseudobulk count 矩阵 CSV**（最稳） | CSV 那条桥不依赖任何转换库，十年后也能读 |

**⇒ 一句话**：**Python 出细胞（QC→整合→聚类→注释），R 出结论（pseudobulk DE）和图。**

### 0.2 三年空窗期的重新校准清单：你当年的哪些标准操作，现在会被挑错

**【判断】** 这是本文最该先看的表。左列是 2023 年完全正常、我猜你肌肉记忆还在的做法。

| 2023 年的标准做法 | 2026 年的判定 | 该改成什么 |
| :--- | :---: | :---: |
| 用 `FindMarkers` / `rank_genes_groups` 做**跨条件**（处理 vs 对照）比较 | ❌ **伪重复（pseudo-replication）**，FDR 完全失效 | **按样本聚合成 pseudobulk，再用 DESeq2/edgeR**。细胞级检验只留给"同一样本内不同簇之间"的 marker 识别 |
| QC 用固定阈值（`nFeature 200–2500`、`percent.mt < 5`） | ⚠ 已不被接受为默认 | **自适应阈值**（MAD-based，如 `scater::isOutlier` / scanpy 的 MAD 写法），并**逐样本**算 |
| 不做 doublet 检测 | ❌ 现在是标配 | **scDblFinder（R，当前最强）/ scrublet / solo**。doublet 会形成稳定的假"过渡态"簇 |
| 不做 ambient RNA 校正 | ⚠ 组织解离样本必须做 | **SoupX / decontX / CellBender**。不校正就报低表达 marker 是常见翻车点 |
| 选完 HVG 立刻子集化基因 | ⚠ 不可逆信息损失 | 只**打标记**（`var['highly_variable']`），下游按需 `use_highly_variable=True`。很多经典 marker 恰恰不是 HVG |
| 参考映射只看 `predicted.celltype.score` | ❌ 最危险的一条 | **必须同时看 `mapping.score`**：前者问"在给定标签集内哪个最像"，后者问"参考里到底有没有这类细胞"。肿瘤克隆可以拿 0.95 的 prediction + 0.3 的 mapping |
| 细胞比例直接做 t 检验 / 卡方 | ❌ 比例是**成分数据（compositional）**，各类此消彼长 | **scCODA / sccomp / propeller**，或至少做 CLR 变换后再检验 |
| t-SNE 作为主嵌入 | ⚠ 已被 UMAP 取代，但**两者都不能承载定量结论** | UMAP 只做展示。簇间"距离远近"、"是否连续"一律不能从嵌入图上读 |
| 用 `.raw` 存 counts | ⚠ 隐式，易出事 | 显式 `layers['counts']`；`rank_genes_groups` 和绘图函数会在你没察觉时去用 `.raw` |
| 报告只给 DEG 数 + 通路名单 | ❌ 你自己的既定判据 | 必须描述**处理因素本身的生物学响应**，阴性结果照写 |

### 0.3 三年里最大的三个变化（如果只记三件事）

| # | 变化 | 对你的实际影响 |
| :--- | :---: | :---: |
| **1** | **伪重复问题从学术争论变成审稿硬门槛** | 跨条件分析的**默认写法变了**。这一条影响你几乎每个客户项目 |
| **2** | **规模从 10⁴ 细胞变成 10⁶–10⁷** | 对象模型全部换代（Seurat v5 layers/BPCells/sketch；AnnData + dask/out-of-core）。"全部读进内存"的时代结束了 |
| **3** | **空间转录组从边缘变成主流** | 这是三年里**唯一全新的大块分析领域**。Visium HD 单张切片 870 万 bins，是新的工程难题 |

---

## §1 三年间真正变了什么（逐条）

### 1.1 伪重复：从"有人提"到"不这么做就退稿"

**2023 年的状态**：Squair et al. (2021) 已经指出细胞级检验会膨胀 FDR，但实践里 `FindMarkers(ident.1="treated")` 仍然满地都是。

**2026 年的状态**：**【文献】【检索】** pseudobulk 方法在多个 benchmark 中系统性优于细胞级检验；主流教程（sc-best-practices、OSCA、10x 官方 analysis guide）全部把 pseudobulk 写成跨条件比较的默认路径。

**但要注意共识的边界** —— **【检索】** 领域**并没有**收敛到"pseudobulk 是唯一正确答案"：

| 方法 | 错在哪 |
| :--- | :---: |
| 细胞级检验（Wilcoxon / MAST 等） | 把细胞当独立重复 ⇒ **FDR 膨胀**，p 值虚高 |
| pseudobulk 聚合 | 丢掉细胞间变异 ⇒ **假阴性率偏高**，小细胞数的簇尤其 |

**【判断】** 实操上：**pseudobulk 作为默认与主结论来源**；细胞级结果如果要用，只能作为**方向一致性的旁证**，且必须在报告里写明它不是独立证据。你 proj23 的 D8 决策（在同一份数据上把"对照组内部随机对半分也能检出 N 个显著基因"跑出来）是把这件事讲清楚的最好方式 —— **抽象忠告没用，同数据自证才有说服力。**

**⚠ 承重前提**：pseudobulk 要求**每组有真正的生物学重复**。n=1 的项目做不了任何跨条件推断，只能出描述性结果 —— 这一点和你 proj33 的处理一致。

### 1.2 对象模型与规模：两边都换了代

**Seurat v5**（2023 年底发布，你的空窗期正好跨过它）：

| 概念 | 说明 | 最容易踩的坑 |
| :--- | :---: | :---: |
| **layers** | 一个 assay 内可以有多个 layer（`counts.1`、`data.2`…），整合前按样本 split | **split 状态下部分操作只用第一个 layer 且不报错**。DE / 导出前必须 `JoinLayers()` |
| **`IntegrateLayers()`** | 五种方法统一接口：CCA / RPCA / Harmony / FastMNN / **scVI** | 老的 `FindIntegrationAnchors` + `IntegrateData` 写法仍能跑但不是主线 |
| **BPCells** | 磁盘支撑的稀疏矩阵，百万细胞不进内存 | 对象里存的是文件指针，**移动/删除底层文件会让对象失效** |
| **sketch** | 抽子集算，再把结果投回全量 | 抽样策略（leverage score）不是均匀抽样，别当成 `subset()` |
| **SCTransform v2** | 仍在，但会**静默把 `DefaultAssay` 改成 SCT** | 此后所有 `FindMarkers`/`FeaturePlot` 作用在 Pearson 残差上 —— 不报错，含义全变 |

**Python 侧**：AnnData 稳定在 0.11/0.12 系；out-of-core 走 dask/zarr；`rapids-singlecell` 提供近乎 drop-in 的 GPU 替换。**【检索】** rapids-singlecell 已支持多 GPU（Dask）与 out-of-core，DGX 上 1000 万细胞 PCA <10 秒；但 out-of-core 路径仍报有 RMM 内存管理导致的崩溃/停滞。

**⚠ 对本机的含义 —— 【实测】**：本机 GPU = **GTX 1060 3 GB**（`nvidia-smi` 确认）。**GPU 加速路线在本机不成立**，rapids-singlecell / cell2location 这类都跑不动。但本机 **RAM 125 GB**、32 核 64 线程，**内存反而是富余的** —— 所以 out-of-core 对你不是刚需，百万细胞级别直接进内存是可行的。**这条约束把"要不要上 GPU"这个问题直接消掉了。**

### 1.3 整合：从"每年一个新方法"到三足鼎立 + 有裁判

**2026 年的实际选择空间已经收敛**：**Harmony**（快、无监督、批次效应强时首选）、**scVI/scANVI**（概率模型，可带标签半监督，输出可直接用于下游）、**RPCA**（Seurat 侧，保守、不过度混合）。fastMNN / Scanorama / BBKNN 仍在但不是默认。

**变化的关键不是方法，是有了裁判**：**scIB** 系列 benchmark 把"批次去除"和"生物变异保留"拆成两组指标分别打分。**【判断】** 这意味着"该选哪个"在 2026 已经是一个**必须给量化依据**的问题，不能再凭喜好选 —— 你 proj23 的 D7（四方法横评 + 两个量化指标）正是这个思路。

### 1.4 注释：三条腿 + 不确定性，而不是一条

| 路线 | 代表工具 | 什么时候用 |
| :--- | :---: | :---: |
| **手动 marker** | 文献 marker + `dotplot` | 永远要做 —— 它是另外两条腿的验收标准 |
| **分类器** | **CellTypist**（Python，原生）、**SingleR**（R，最成熟）、scTab | 有匹配的训练模型时最省事 |
| **参考映射** | **Azimuth**、scArches、scANVI、ProjecTILs、scGate | 有高质量同组织参考图谱时精度最高 |
| **共识** | **popV**（跑 8 种方法 + 本体投票 + 不确定性分数） | **【检索】** 需要可辩护标签、或没把握时 |

**【判断】** 三年里注释领域最重要的进步**不是准确率**，是**不确定性被制度化了**：popV 给投票不确定性，Azimuth 给 `mapping.score`，CellTypist 给 `conf_score`。

> **⚠ 这是重新入场最该补的一个判据**（引自你 proj23 4-3 章）：
> `predicted.celltype.score` 与 `mapping.score` 问的是**两个不同的问题**。一个肿瘤细胞可以有 **0.95 的 prediction score**（它确实最像 Pro-B）和 **0.3 的 mapping score**（它其实不是任何一种正常细胞）。**只看前者，就会把整群白血病克隆当成正常前体细胞。**
> ⇒ 阈值判断要**固化成元数据列**（低分置 `Unassigned`），不能留在读者脑子里；阈值从密度图谷底读，不是拍脑袋定 0.5。

**另一个高频翻车点**：参考图谱与组织**不匹配**。用 PBMC 参考跑骨髓数据会给出一堆看起来非常合理的标签，而骨髓里的前体细胞在 PBMC 参考里根本不存在 —— 且**没有任何报错**。

### 1.5 QC：补齐了两个当年常跳过的环节

- **Doublet 检测**：**scDblFinder**（R）在多个 benchmark 中排名靠前；Python 侧 scrublet / solo（scvi-tools）。**doublet 会形成稳定的假"过渡态"簇** —— 这是最常见的假阳性来源，而且它在 UMAP 上看起来非常像真实的分化中间态。
- **Ambient RNA**：SoupX / decontX（R）、CellBender（Python，需 GPU）。组织解离样本（尤其肿瘤、肝、胰腺）不校正就直接报低表达 marker，容易报出"所有细胞都表达某组织特异基因"这类假象。
- **自适应阈值取代硬阈值**：`isOutlier`（MAD-based）、逐样本算而不是全局一刀切。

### 1.6 空间转录组：三年里唯一的全新大块

**这是你空窗期里变化最大的部分。** **【检索】** 2026-01 *Genome Biology* 发表了五平台（Visium v1 / Visium v2-CytAssist / Visium HD / Xenium / CosMx）在同一批 FFPE 肿瘤切片上的系统 benchmark。

| 类型 | 平台 | 特点 | 分析上的新难题 |
| :--- | :---: | :---: | :---: |
| **测序型** | Visium → **Visium HD**（2 µm bins） | 全转录组，近单细胞分辨率 | **数据稀疏 + 体量爆炸**（单切片 870 万 bins）；bin 聚合尺度是新的方法学选择 |
| **成像型** | **Xenium 5K**（5001 基因）、**CosMx 6K**（6175 基因）、MERFISH | 单分子精度，亚细胞定位 | **细胞分割（segmentation）是首要误差来源**；转录本错配（spillover）需专门处理 |

**【检索】** 成像型平台横评中 **Xenium 背景噪声更低、空间信号更强**，但 Xenium 与 CosMx 给出的细胞类型分类**结果相当**。**【检索】** *Nature Methods* 2026 有专文处理 Xenium 的灵敏度/特异性/信号污染问题。

**⚠ 基础设施警告 —— 【检索】**：跑通过 Visium 的实验室**不能假定**同一套基础设施能处理 Xenium 或 CosMx，需要实质性重新架构。**【判断】** 对你的含义：如果公司要接空间业务，**Visium/Visium HD 与成像型平台要当成两条独立管线来准备**，不是一条管线加个参数。

**生态对比（这是 R 侧最强的地方）** —— 引自你 proj24 §1.2 的实读结论：
- **Seurat 的空间支持只有 2 个 vignette**（测序型 1 个、成像型 1 个）；
- **Bioconductor 的 OSTA 有 40 章 + 4 附录**，**【检索】** 是 Bioconductor 3.22 周期新增的书；生态 40+ 个专用包（SpotSweeper / SpaNorm / Banksy / nnSVG / spacexr / SPOTlight / lisaClust / mistyR …）；
- Python 侧 squidpy + SpatialData 在**数据结构与大规模处理**上更强（SpatialData 的多模态/多分辨率模型是当前最完整的），**统计方法的数量**不如 Bioconductor。

### 1.7 单细胞基础模型：起来了，又被 benchmark 打回原形

**2023–2024**：scGPT、Geneformer、scFoundation、UCE 密集发布，宣传语是"单细胞的 GPT 时刻"。

**2026 的 benchmark 结论 —— 【检索】【文献】**，多篇独立评估一致：

- Geneformer 与 scGPT 是基础模型里表现最好的两个，但**两者仍不如 HVG baseline**；
- zero-shot（不微调）场景下实用性有限，**HVG 选择 + scVI + Harmony 在生物保留与批次整合指标上普遍更好**；
- **Geneformer 在整合指标上持续垫底**，embedding 里保留甚至放大批次变异；
- 有研究直接指出：依赖仔细归一化的**简单可解释线性流程**在多个 benchmark 上达到或接近 SOTA，在分布外任务上**优于**基础模型。

**【判断】** 结论很直接：**不要把基础模型放进 2026 的生产流程。** 你需要知道它们存在（客户或审稿人会问），但当前证据不支持用它替换标准流程。这也是个有用的一般教训 —— **三年空窗期里最响的东西，未必是最该学的东西。**

### 1.8 下游三件套：各自的分寸

| 分析 | 工具 | 分寸 |
| :--- | :---: | :---: |
| **细胞组成差异** | scCODA / pertpy（Py）、sccomp / propeller（R） | 比例是成分数据，**一类细胞变多必然导致其他类比例下降** —— 不能各自独立检验 |
| **细胞间通讯** | CellChat v2（R）、**LIANA+**（Py，共识框架）、CellPhoneDB | **【判断】** 这是最容易过度解读的一类分析。输出的是"表达模式相容"，**不是**"确实发生了通讯"。报告里必须写成假说而非结论 |
| **通路/富集** | decoupler（双语言）、clusterProfiler / fgsea（R）、gseapy（Py） | ORA **必须分 UP/DOWN 方向做**，ALL 方向在 DEG 占比大时严重欠功效（你 proj19 实测：6 个对比里 3 个误报"0 通路"） |

### 1.9 依赖地狱：这本身就是 2026 的一个特征

**【实测】** 这不是抽象抱怨，是你自己项目的实测结果：

| 项目 | 需要几个独立 env | 为什么拆不开 |
| :--- | :---: | :---: |
| proj22（Python，27 章） | **4 个** | scVelo+CellRank、spatialdata 栈、pySCENIC 旧栈三者对 numpy/pandas/dask 的版本区间**互不相容** |
| proj23（R，20 章） | **2 个** | monocle3 锁死的 Matrix/irlba/igraph 与 Seurat 5 栈解不到一起；塞一起会得到"把 Seurat 降级到 4.x"的解 |
| proj24（R，17 章） | **3 个** | 同上 + 空间栈 |

**【判断】** ⇒ **"一个 env 装下整个单细胞流程"在 2026 已经不可能了，两个生态都一样。** 这不该被当成挫折，该被当成设计前提：**按分析阶段拆 env，用绝对路径解释器，每个 env 装完立刻验证模块清单。** 你 proj22 的 `1_setup_envs.sh` 已经这么做了（幂等 + 查 `PIPESTATUS` + 装完验证 15 个模块 + grn env 额外核对钉死版本号），那份脚本的模式值得在别处照抄。

**特别提示 —— pySCENIC 是最难的一个**：它把整个栈钉死在 Python 3.10 + pandas 1.5.3 + numpy 1.23.5 + dask 2023.3.2。**【实测】** 本机 `sc_tut_grn` 就是这个配置，scanpy 只能停在 1.9.8。做 GRN 分析要预算一个专用环境。

### 1.10 版本现状（2026-09-10）

| 组件 | 当前版本 | 本机装的 | 差距判定 |
| :--- | :---: | :---: | :---: |
| Seurat | **5.5.1**（2026-06-25 CRAN 文档日期）**【检索】** | **5.4.0**（base R library）**【实测】** | 落后一个小版本，可用 |
| scanpy | **1.12.3**（2026-07-24）**【检索】** | **1.11.5**（`sc_tut_main`）**【实测】** | 落后一个小版本，可用 |
| anndata | 0.12 系 | **0.12.19** **【实测】** | 当前 |
| scvi-tools | 1.3 系 | **1.3.3** **【实测】** | 当前 |
| Bioconductor | **3.22**（2361 个软件包，配 R 4.5）**【检索】** | R **4.5.2**，**无 Bioc 单细胞栈** **【实测】** | **缺口在这里** |
| squidpy / spatialdata | — | 1.8.2 / 0.7.3 **【实测】** | 当前 |

**【判断】** 版本不是问题，**不要为了追版本先做升级**。1.11.5 → 1.12.3 之间没有会改变结论的变更；先把流程跑起来，升级留到下一个环境重建周期。

---

## §2 逐环节生态判定

**判据**：① 有没有原生实现（而非移植/桥接）；② 方法数量与成熟度；③ 审稿人/客户的接受度。

| 分析环节 | Python (scverse) | R (Seurat / Bioconductor) | 判定 |
| :--- | :---: | :---: | :---: |
| 数据结构 | AnnData / MuData / SpatialData | SingleCellExperiment / Seurat / SpatialExperiment / SFE | 平手 |
| QC（自适应阈值） | scanpy | `scater::isOutlier` | 平手 |
| **Doublet 检测** | scrublet, solo | **scDblFinder** | **R 略优** |
| **Ambient RNA** | CellBender（需 GPU） | **SoupX, decontX** | **R 优**（本机无可用 GPU） |
| 归一化 | scanpy, pearson residuals | scran pooling, SCTransform v2 | 平手 |
| **整合** | **scVI / scANVI（原生）**, harmonypy, BBKNN, Scanorama | Harmony（原版）, RPCA/CCA, fastMNN, scVI（需桥接） | **Python 优** |
| 聚类 | leiden (igraph) | leiden (leidenbase) | 平手 |
| **注释** | CellTypist, **popV**, scANVI | **SingleR**, Azimuth, ProjecTILs, scGate | **R 略优**（方法更多、参考更全） |
| **跨条件 DE（pseudobulk）** | PyDESeq2, decoupler 聚合 | **DESeq2 / edgeR / limma-voom 原版** | **R 明确优** |
| 组成分析 | scCODA, pertpy | sccomp, propeller/speckle | 平手偏 R |
| 富集/通路 | decoupler, gseapy | clusterProfiler, fgsea, decoupleR | 平手 |
| **轨迹 / 拟时序** | **CellRank 2**, PAGA, Palantir, scFates | monocle3, slingshot, tradeSeq | **Python 优** |
| **RNA velocity** | **scVelo, veloVI** | 无原生对等 | **Python 独占** |
| **GRN** | **pySCENIC, CellOracle** | SCENIC（R 版，慢很多） | **Python 优** |
| 细胞通讯 | LIANA+, CellPhoneDB | CellChat v2, LIANA(R) | 平手 |
| **扰动 / CRISPR 筛选** | **pertpy, mixscape** | 无对等 | **Python 独占** |
| 大规模 | AnnData+dask, rapids-singlecell（需 GPU） | **BPCells + sketch** | 平手（本机无 GPU ⇒ R 侧路径反而更现实） |
| **空间 — 测序型** | squidpy, SpatialData | **OSTA 生态**：nnSVG, SpaNorm, SpotSweeper, spacexr(RCTD), SPOTlight, Banksy | **R 明确优** |
| 空间 — 成像型 | squidpy, sopa, SpatialData | SFE, MoleculeExperiment, imcRtools, lisaClust | 平手（Py 强在工程，R 强在统计方法数） |
| **出版级绘图** | matplotlib, seaborn | **ggplot2 + ComplexHeatmap** | **R 明确优** |
| 可复现报告 | Jupyter / Quarto | Quarto / RMarkdown | 平手（Quarto 双支持） |
| 与管线胶合 | **Python 是 nextflow 生态的原生胶水** | 需额外封装 | **Python 优** |

**汇总**：Python 在 **4 个环节独占或明确领先**（velocity、扰动、GRN、轨迹）+ 整合 + 胶合；R 在 **3 个环节明确领先**（pseudobulk DE、空间统计方法、绘图）+ 注释/doublet/ambient 略优。

---

## §3 你手上的实际资产盘点（2026-09-10 实测）

**【实测】** 这是决定"先做什么"的关键事实，与生态优劣同等重要。

| 项目 | 章节数 | 环境状态 | 执行状态 |
| :--- | :---: | :---: | :---: |
| **22**（Python） | **27** 份 `.py` | ✅ **4 个 env 全部装好**（2026-09-03 建成，模块已验证） | ⚠ **只跑了 1-1 章**（`done_stamps` = 0，`output_results` 仅 `ch1-1`/`ch1-1s`） |
| **23**（R，Seurat 主线） | **20** 份 `.qmd` | ❌ **`sc_tut_r` / `sc_tut_r_mono` 均不存在** | ❌ 从未执行 |
| **24**（R 高级 + 空间） | **17** 份 `.qmd` | ❌ 3 个 env 均不存在 | ❌ 从未执行 |

**本机 R 现状 —— 【实测】**：`/Work_bio/gao/miniforge3/lib/R/library` 有 **R 4.5.2 + Seurat 5.4.0**，但 **SingleCellExperiment / scater / scran / harmony / BPCells / DESeq2 / edgeR / limma / monocle3 / CellChat / SpatialExperiment 全部缺失**。也就是说：**R 侧目前只有一个孤立的 Seurat，没有可用的单细胞分析栈。**

**硬件 —— 【实测】**：

| 资源 | 实测值 | 对选型的含义 |
| :--- | :---: | :---: |
| CPU | AMD Threadripper 2990WX，32 核 / 64 线程 | 按既定上限用 **28 核 / 56 线程** |
| RAM | **125 GB**（可用 114 GB） | **富余** —— 百万细胞可直接进内存，out-of-core 不是刚需 |
| GPU | **GTX 1060 3 GB** | ❌ **GPU 路线全部不成立**：rapids-singlecell、CellBender、cell2location 都跑不动；scVI 只能走 CPU |
| 磁盘 | `/mnt/ex_8T_SSD` 剩 5.3 T | 充足 |

**【判断】** 这份盘点直接给出优先级：**Python 侧的沉没成本已经变成了可用资产（env 装好了），R 侧还停在纸面上。** 在两个生态旗鼓相当的环节，"哪个现在就能跑"是压倒性的判据。

---

## §4 结论与分工方案

### 4.1 结论

> **主线走 Python（scverse）。R 不是备份，是三个专用工位。**

**支持这个结论的四条理由，按权重排序：**

| # | 理由 | 权重 |
| :--- | :---: | :---: |
| 1 | **Python 侧 4 个 env 已装好并验证，27 章已写好；R 侧 5 个 env 一个都没建，37 章从未跑过** 【实测】 | 最高 |
| 2 | **轨迹 / RNA velocity / GRN / 扰动四块，R 侧没有对等物** —— 这不是偏好差异，是能力缺口 | 高 |
| 3 | 公司业务是"测序 + 分析"一体交付，**Python 是已有 nextflow/WGS/RNAseq 管线的原生胶水语言** | 中 |
| 4 | 未来三年的数据规模（Visium HD、百万细胞）在 Python 侧的工程路径更成熟 | 中 |

**⚠ 一条反对意见，我认为不成立**：「R 的 Seurat 用户更多，客户更容易复现」。**【判断】** 客户拿到的是**报告 + 数据矩阵**，不是你的分析脚本；而交付的 count/TPM 矩阵是纯文本，与生态无关。这条不构成选型理由。

**⚠ 一条我确实不确定的**：如果公司未来的空间业务以 **Visium HD / Xenium 为主**，R 侧（OSTA 生态）的方法学优势会比现在这张表显示的更重要。**这取决于业务方向，需要你拍板** —— 见 §8。

### 4.2 具体分工

```
┌─ Python (sc_tut_main) ─────────────────────────────────┐
│  读入 → QC → 归一化 → HVG → 降维 → 整合 → 聚类 → 注释    │
│  ↓ 产出两样东西                                          │
│  ① <proj>_annotated.h5ad         （完整对象，留档）      │
│  ② <proj>_pseudobulk_counts.csv  （样本 × 基因，整数）   │
│     + <proj>_pseudobulk_coldata.csv （样本元数据）       │
└──────────────────────┬─────────────────────────────────┘
                       │  文件交换，不是 rpy2
                       ▼
┌─ R (新建 sc_de_viz env) ───────────────────────────────┐
│  DESeq2 / edgeR ← 按细胞类型分别建模                     │
│  ggplot2 + ComplexHeatmap ← 出版级图件                   │
└─────────────────────────────────────────────────────────┘

轨迹 / velocity / GRN / 扰动 → 留在 Python（sc_tut_traj / _grn）
空间转录组             → 见 §8，取决于业务方向
```

**为什么 pseudobulk CSV 是最好的桥**：它是**整数矩阵 + 元数据表**，两个文本文件，不依赖 zellkonverter / anndataR / sceasy 任何一个转换库，也不会因为 AnnData 版本变化而失效。**【判断】** 对象级 `.h5ad ↔ SCE` 的转换留给"确实需要整个对象"的场合（比如把 Python 注释好的对象交给 R 做空间分析），日常 DE 不需要。

**⚠ pseudobulk 聚合的三个必须做对的细节**：

1. **聚合的是 raw counts，不是归一化值**（DESeq2/edgeR 要 counts）；
2. **按「样本 × 细胞类型」双重分组**，每个细胞类型单独建模，不是全部混在一起；
3. **细胞数太少的组要剔除**（常用阈值 ≥10 细胞/样本/类型），并在报告里说明剔除了哪些 —— 否则会得到由 2 个细胞支撑的"显著"结果。

---

## §5 互操作：怎么搭桥，以及不要搭什么

| 方式 | 判定 | 说明 |
| :--- | :---: | :---: |
| **pseudobulk CSV** | ✅ **首选** | 纯文本，零依赖，可存档，可给客户 |
| **`.h5ad` ↔ SCE**（zellkonverter） | ✅ 需要整个对象时用 | Bioc 官方维护，稳定；注意 `.obsm`/`.layers` 的映射规则 |
| **`.h5ad` ↔ Seurat**（sceasy / anndataR） | ⚠ 谨慎 | 转换会丢东西（图结构、部分 uns）。转完必须核对细胞数、基因数、metadata 列数 |
| **rpy2**（Python 调 R） | ⛔ **不要** | 把两个生态的依赖冲突叠加；报错点离真因极远；env 一升级就碎 |
| **reticulate**（R 调 Python） | ⛔ **不要**（作为流程一环） | 同上。偶尔交互探索可以，不要写进 step 脚本 |

**【判断】** 判据很简单：**桥必须能在两边 env 各自独立升级后依然成立。** 文件能，进程内调用不能。

---

## §6 重新入场的 90 天路线

**【判断】** 前提：不新建项目，用已有的 proj22。理由是 §3 的资产盘点 —— **最高 ROI 的动作是把已经装好环境、已经写好 27 章的东西跑完**，而不是去补 proj23/24 的环境。

| 阶段 | 做什么 | 产出 | 为什么这个顺序 |
| :--- | :---: | :---: | :---: |
| **第 1–2 周** | proj22 **Part 1–2**（1-1 → 2-5，8 章） | 手感恢复 + `ckpt_05b` | AnnData 操作、QC 判据、整合横评 —— 这三样是所有后续的地基 |
| **第 3–4 周** | proj22 **Part 3**（3-1 → 3-4，4 章） | `ckpt_09_mapped` | 注释三条腿 + `mapping.score` 判据（§1.4 那个最该补的判据） |
| **第 5–7 周** | proj22 **Part 4**（4-1 → 4-4，4 章）**+ 建 R 侧 DE 环境** | `ckpt_13` + R 侧跑通一次 pseudobulk | **这是客户项目最常用的部分**。跨条件分析必须两边都跑一次，互证 |
| **第 8–9 周** | proj22 **6-2**（通讯）+ **Part 5**（轨迹 3 章） | `ckpt_16_fate` | 轨迹是 Python 独占能力，值得单独一段 |
| **第 10–12 周** | **二选一**（见 §8）：Part 7 空间 5 章 ／ 6-1 GRN | — | 按业务方向定 |

**⚠ 三条执行纪律**（都是你既有 SOP，这里只是提醒它们对本任务同样适用）：

1. **长任务进 tmux**：`bash scripts/4_run_all_chapters.sh --tmux`，脚本已内建 tmux 自举与逐章 checkpoint；
2. **退出码 0 ≠ 结果对**：跑完必须 `grep -n '⚠' tmp/run_logs/*.log` 看各章自报的可疑点；
3. **不要为了追版本先升级** —— 先跑通，升级留到下个环境重建周期（§1.10）。

**关于 proj23/24（R 教程，37 章）**：**【判断】** 我的建议是**暂不建那 5 个 env**。它们的价值在两处：① 空间部分（proj24 Part 2–5）是 R 侧真正不可替代的内容，等业务需要时再建；② proj23 的 D8（伪重复自证）与 4-3（mapping.score）两章内容价值极高，但**这两个判据已经写进本文 §1.1 和 §1.4**，你不必跑完 20 章才能用上。

---

## §7 三个容易被忽略的本机约束

| 约束 | 后果 | 对策 |
| :--- | :---: | :---: |
| **GPU 3 GB** 【实测】 | cell2location / CellBender / rapids-singlecell 全部不可用；scVI 只能 CPU | 去卷积用 **Tangram**（proj22 D6 已这么定）；ambient RNA 用 **SoupX/decontX（R，CPU）**；不要在计划里写 GPU 步骤 |
| **同名 env 会静默解析错** 【实测】 | `conda run -n` 拿到别的解释器，直到缺包才暴露 | 一律用**绝对路径解释器**；交互用 `mamba activate <prefix 全路径>`，**不用 `conda activate`** |
| **函数内延迟 import** 【实测】 | `ModuleNotFoundError` 的 traceback 指向调用行而不是缺包处，误导排查方向 | 看到 `ModuleNotFoundError` **第一步查当前解释器是谁**，不要先读报错行附近的代码 |

---

## §8 需要你拍板的两件事

**【判断】** 这两件我给不出默认值，因为答案取决于业务方向而不是技术优劣：

| # | 问题 | 两个选项的实际差别 |
| :--- | :---: | :---: |
| **1** | **公司未来 12 个月会不会接空间转录组业务？** | 会 ⇒ 第 10–12 周做 proj22 Part 7（Python/squidpy 打底），**并且要认真评估建 proj24 的 R 空间栈**（OSTA 生态的方法学优势在这个方向上是实质性的）。不会 ⇒ 第 10–12 周改做 6-1 GRN，空间整块推迟 |
| **2** | **R 侧建到什么程度？** | **最小方案**：新建一个 `sc_de_viz` env，只装 DESeq2 / edgeR / limma / ggplot2 / ComplexHeatmap / SingleCellExperiment / zellkonverter —— 覆盖 §4.2 的分工，约半小时。**完整方案**：把 proj23 的 2 个 env 建起来跑 20 章，约数天。我推荐**最小方案**，除非你确认要走空间路线 |

---

## §9 本文引用来源

**【检索】** 2026-09-10 检索到的（我的模型知识截止 2026-05，以下均为检索所得）：

- Seurat 版本：[CRAN Seurat 手册（Version 5.5.1, 2026-06-25）](https://cran.r-project.org/web/packages/Seurat/Seurat.pdf)、[Seurat 官网](https://satijalab.org/seurat/)、[GitHub releases](https://github.com/satijalab/seurat/releases)
- scanpy / scverse：[scanpy release notes（1.12.3, 2026-07-24）](https://scanpy.readthedocs.io/en/stable/release-notes/index.html)、[scverse packages](https://scverse.org/packages/)、[scvi-tools changelog](https://docs.scvi-tools.org/en/latest/changelog.html)
- Bioconductor 3.22 与两本书：[Bioconductor 3.22 发布公告](https://bioconductor.org/news/bioc_3_22_release/)、[OSCA](https://bioconductor.org/books/release/OSCA/)、[OSTA](https://www.bioconductor.org/books/OSTA/)
- 基础模型 benchmark：[Parameter-free representations outperform single-cell foundation models（arXiv 2602.16696）](https://arxiv.org/pdf/2602.16696)、[Zero-shot benchmark of foundation model embeddings（bioRxiv 2026-03）](https://www.biorxiv.org/content/10.64898/2026.03.10.710748v1.full)、[Biology-driven insights into single-cell foundation models（Genome Biology）](https://link.springer.com/article/10.1186/s13059-025-03781-6)
- pseudobulk DE：[A balanced measure shows superior performance of pseudobulk methods（PMC9780232）](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9780232/)、[10x Genomics analysis guide: DE between conditions with biological replicates](https://www.10xgenomics.com/analysis-guides/differential-gene-expression-analysis-in-scrna-seq-data-between-conditions-with-biological-replicates)、[Single-cell DE within nested settings（PMC12343076）](https://pmc.ncbi.nlm.nih.gov/articles/PMC12343076/)
- 空间平台横评：[五平台 FFPE 肿瘤横评（Genome Biology 2026-01）](https://link.springer.com/article/10.1186/s13059-026-03937-y)、[Xenium 灵敏度/特异性/信号污染（Nature Methods 2026）](https://www.nature.com/articles/s41592-026-03089-8)、[亚细胞空间平台系统 benchmark（PMC12534522）](https://pmc.ncbi.nlm.nih.gov/articles/PMC12534522/)
- GPU 规模化：[GPU-accelerated single-cell analysis at scale with rapids-singlecell（arXiv 2603.02402）](https://arxiv.org/abs/2603.02402)、[ScaleSC（Bioinformatics Advances 2025）](https://academic.oup.com/bioinformaticsadvances/article/5/1/vbaf167/8205667)
- 注释共识：[popV（Nature Genetics 2024）](https://www.nature.com/articles/s41588-024-01993-3)、[Cell Ontology in the age of single-cell omics（arXiv 2506.10037）](https://arxiv.org/pdf/2506.10037)

**【实测】** 本机事实的复核命令：

```bash
# 各 env 与包版本
for e in main traj grn spatial; do
  /mnt/ex_8T_SSD/conda_envs/sc_tut_$e/bin/python -c \
    "import importlib.metadata as m,sys;print(sys.version.split()[0], m.version('scanpy'))"
done
# R 侧
grep -m1 ^Version /Work_bio/gao/miniforge3/lib/R/library/Seurat/DESCRIPTION
# 三个项目的执行状态
for p in 22_python_based_scRNA_tutorial 23_R_based_scRNA_tutorial_2026 \
         24_R_advanced_scRNA_and_Spatial_tutorial_2026; do
  echo -n "$p done_stamps: "
  ls /home/gao/projects_2026M7/$p/tmp/done_stamps 2>/dev/null | wc -l
done
# 硬件
nvidia-smi --query-gpu=name,memory.total --format=csv; free -g | head -2
```

**内部交叉引用**：
- `Bioinfo/splicing/splicing_bioinformatics_review_20260905.md` —— 同类"空窗期重新校准"综述，可对照体例
- `software_pitfalls/conda_env_duplicate_names.md` —— §7 的同名 env 陷阱
- `projects_2026M7/22_python_based_scRNA_tutorial/docs/P22_run_and_troubleshooting_log_0903.md` —— §1.9、§7 的实测来源
- `projects_2026M7/23_R_based_scRNA_tutorial_2026/docs/P23_research_plan_and_review_0730.md` —— §1.1 D8、§1.4 D12/D13 的来源
- `projects_2026M7/24_R_advanced_scRNA_and_Spatial_tutorial_2026/docs/P24_research_plan_and_review_0730.md` —— §1.6 的 OSTA/Seurat 生态对比来源
