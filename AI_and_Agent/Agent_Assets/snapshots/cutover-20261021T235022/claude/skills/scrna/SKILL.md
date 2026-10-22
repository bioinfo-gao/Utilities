---
name: scrna
description: "Use when 要做单细胞转录组分析（scRNA-seq / CellRanger 输出起步）——设计门槛与「该问客户 vs 我方决定」、Python 主线 + R 两块阵地的分工与文件桥、逐环节必须偏离默认的参数、伪重复/注释/富集三大翻车点、静默错误清单与可执行自审断言"
---

# /scrna — 单细胞转录组分析 SOP

**方法学依据（三份，互不重复）**：

| 文档 | 回答什么 |
| :--- | :---: |
| [`scRNAseq_landscape_2023_to_2026_and_ecosystem_choice_20260910.md`](/home/gao/Utilities/Bioinfo/single_cell_and_spatial/scRNAseq_landscape_2023_to_2026_and_ecosystem_choice_20260910.md) | 三年里什么变了、选哪个生态 |
| [`scRNAseq_refresh_1_data_objects_and_upstream_20260914.md`](/home/gao/Utilities/Bioinfo/single_cell_and_spatial/scRNAseq_refresh_1_data_objects_and_upstream_20260914.md) | 对象与上游产物的字段怎么读 |
| [`AI_in_singlecell_and_spatial_1_methods_20260910.md`](/home/gao/Utilities/Bioinfo/single_cell_and_spatial/AI_in_singlecell_and_spatial_1_methods_20260910.md) ＋ [`_3_llm_biology_`](/home/gao/Utilities/Bioinfo/single_cell_and_spatial/AI_in_singlecell_and_spatial_3_llm_biology_20260910.md) | AI/LLM 哪些格能用、哪些有主动危害 |

**参考实现（可运行，27 章）**：[`22_python_based_scRNA_tutorial`](/home/gao/projects_2026M7/22_python_based_scRNA_tutorial/)
**空间部分走** `/spatial`。

---

## §0 结论先行 —— 只记这七条也够用

| # | 规则 | 违反的后果 |
| :--- | :---: | :---: |
| **1** | **跨条件比较一律 pseudobulk**（按「样本 × 细胞类型」聚合 raw counts → DESeq2/edgeR）。细胞级检验只用于**同一样本内簇间 marker** | 伪重复，FDR 完全失效 —— 2026 年的审稿硬门槛 |
| **2** | **QC 用逐样本自适应阈值（MAD），不用固定阈值** | 固定阈值已不被接受为默认；且会系统性丢掉低 RNA 含量细胞类型 |
| **3** | **doublet + ambient RNA 现在是标配**，不是可选项 | doublet 形成稳定的假"过渡态"簇，在 UMAP 上像真实分化中间态 |
| **4** | **注释必须给不确定性**：`mapping.score` / `conf_score` 阈值**固化成元数据列**，低分置 `Unassigned`；**且用参考之前先核对它的物种与组织**（看 `rownames(ref)` 的大小写、看实际下载的文件名，不看注释怎么写） | 只看 prediction score 会把白血病克隆当成正常前体（0.95 prediction + 0.3 mapping）；物种错了则整个投影无意义而**全程不报错**（proj23：`ProjecTILs::load.reference.map()` 默认给小鼠图谱） |
| **5** | **counts 显式存 `layers['counts']`，不用 `.raw`**；HVG **只打标记不子集化** | `.raw` 会被绘图/DE 函数在你没察觉时使用；子集化是不可逆信息损失，很多经典 marker 不是 HVG |
| **6** | **ORA 分 UP/DOWN 方向做**，ALL 只作参考 | proj19 实测：DEG 占比 63–79% 时 ALL 方向 6 个对比里 3 个误报"0 通路" |
| **7** | **默认不做插补/去噪**；做了就禁止一切相关性/共表达/配受体分析 | MAGIC/DCA 消灭生物学零并**凭空制造强正相关** |

**一句话分工**：**Python 出细胞（QC→整合→聚类→注释），R 出结论（pseudobulk DE）和图。桥是文件，不是 rpy2。**

**⚠ 但选型前先看「今天哪条路真的跑得通」（2026-09-18 实测）**：

| 路线 | 状态 | 什么时候选它 |
| :--- | :---: | :--- |
| **R 全栈**（`sc_tut_r`，proj23 20 章） | **唯一端到端验证过的**：20/20 跑通、33 条断言零失败 | 需要 Seurat 生态专属工具（Azimuth / ProjecTILs / scGate / CellChat / BPCells）、或交接对象是 R 用户 |
| **Python 主线 + R 出结论**（默认） | proj22 已跑到 ch5-3（19 章产物 / 16 checkpoint），**尚未全程** | 常规项目默认走它；上游快、生态新 |

**分工原则不变**（Python 出细胞、R 出结论），变的只是：**R 那一侧现在已经有一条实跑验证过的完整实现可抄**，不必从零拼。

---

## §1 第零步：先判断这个项目能做到什么程度

### 1.1 设计门槛

| 项 | 门槛 | 不满足时怎么写 |
| :--- | :---: | :---: |
| 生物学重复 | **每组 n≥3 个独立样本**才能做跨条件推断 | n=1/n=2 ⇒ **只出描述性结果**（细胞类型构成、marker、UMAP），报告里明写"无法做统计推断"，不给 p 值（同 proj33 处理） |
| 细胞数/样本/类型 | pseudobulk 每格 **≥10 细胞**才计入 | 低于阈值的格子剔除，并在报告里**列出剔除了哪些** —— 否则会得到 2 个细胞支撑的"显著" |
| 分组与个体是否共线 | 个体身份与分组**必须可分离** | 共线（如每组只有一个 donor）⇒ 讲不了伪重复也做不了跨条件，等同 n=1 |
| 参考包一致性 | 同项目全部样本**同一个 CellRanger 参考包** | 版本不同 ⇒ var 行数不同、symbol 对不上，直接 concat 会**静默取交集或产生 NaN** |
| 建库/平台 | 3' vs 5'、有无 hashing、是否 multiome | 影响可做的分析（如 VDJ、velocity 需 spliced/unspliced 分层，CellRanger 标准输出**没有**） |

### 1.2 该问客户 vs 我方自己定（沿用公司业务边界）

| 谁的决定 | 内容 |
| :--- | :---: |
| **客户的（必须问）** | 样本、实验设计、分组与对照、**哪个是基准组**、处理因素、目标细胞类型、分析目的、是否有已知 marker/参考图谱偏好 |
| **我方的（自己定，写进 Methods，不问客户）** | 测序深度/read length/建库化学版本/平台、参考基因组与 GENCODE 版本、QC 阈值策略、归一化/整合/聚类方法与参数、注释工具 |

**⛔ 唯一不追问的是「是不是患者来源」**（送样表已列）。**其余一切与分析口径有关的都必须问，且必须在开跑之前问。**

---

## §2 执行环境：4 个 Python env + 1 个 R 工位（2026-09-16 实测）

| 用途 | 解释器绝对路径 |
| :--- | :---: |
| 主线：读入→QC→整合→聚类→注释→DE→组成→富集→CCC | `/mnt/ex_8T_SSD/conda_envs/sc_tut_main/bin/python` |
| 轨迹 / RNA velocity / CellRank | `/mnt/ex_8T_SSD/conda_envs/sc_tut_traj/bin/python` |
| GRN（pySCENIC，Python 3.10 钉死栈） | `/mnt/ex_8T_SSD/conda_envs/sc_tut_grn/bin/python` |
| 空间（squidpy / spatialdata / tangram） | `/mnt/ex_8T_SSD/conda_envs/sc_tut_spatial/bin/python` |
| **R 工位（轻）**：pseudobulk DESeq2 + clusterProfiler + ggplot2 | `/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript` |
| **R 全栈（重，2026-09-17 建成并实跑）**：Seurat 5 全流程 + SingleR/Azimuth/ProjecTILs + muscat/MAST + miloR/speckle + slingshot/tradeSeq + CellChat + BPCells | `/mnt/ex_8T_SSD/conda_envs/sc_tut_r/bin/Rscript` |

**⚠ R 工位的实测缺口（2026-09-16）**：`DE_R45` 有 **DESeq2 / clusterProfiler / ggplot2**，**没有 edgeR / limma / ComplexHeatmap / SingleCellExperiment / zellkonverter**。
⇒ 需要 edgeR 或 SCE 桥接时**先向用户说明并取得批准再装**（全局 §4：未经确认不安装依赖）。**不要临时换环境顶上。**
⇒ **要 edgeR/limma/SCE 的活直接用 `sc_tut_r`**（它全都有，Seurat 5.5.1 / SingleR 2.12 / DESeq2 1.50 / edgeR 4.8 / limma 3.66 / CellChat 2.2），不必再为 `DE_R45` 装东西。

**⚠ `sc_tut_r` 的三个实测坑（2026-09-17 首次跑 20 章时全部踩到，都不在 yaml 里）**：

| 现象 | 真因 | 处置 |
| :--- | :--- | :---: |
| `FindConservedMarkers` 报 "Please install the metap package" | conda 配方不装 `Suggests` | 已补装 `metap` / `multtest` / `mutoss` 并写回 `1_setup_env.sh` |
| `SingleR()` 报 "there is no package called 'scrapper'" | SingleR 2.12 换了打分后端，配方没跟 | 已补装 `scrapper 1.4.0`，同上写回 |
| `quarto render` 报 `bin/tools/x86_64/deno: No such file` | 不走 `conda activate` 时激活钩子没跑 | 渲染前显式 export 9 个 `QUARTO_*` 变量，见 `~/Utilities/software_pitfalls/quarto_conda.md` |

**通用教训**：`library(X)` 加载成功**不代表** X 的每个函数都能调用；逐包 `library()` 的验证清单会全绿，
然后在第 10 章、第 12 章炸掉，把前面的算力全部作废。**验证清单要覆盖"会被调用的函数"。**

**⛔ 三种会静默出错的写法（全部本机实测）：**

| 写法 | 实际发生什么 |
| :--- | :---: |
| `conda run -n sc_tut_main …` / `mamba run -n …` | 这 4 个 env 是 `--prefix` 装的，**不在名字表里**；`mamba env list` 也看不到。用 `ls -d /mnt/ex_8T_SSD/conda_envs/sc_tut_*` 判断是否存在 |
| `conda activate <prefix>` | `CONDA_PREFIX` 设对了但 `PATH` 没换 ⇒ **`which python` 指向 regular_bioinfo**。要 activate 必须用 `mamba activate <prefix 全路径>` |
| 在 Positron 里按 Python 版本号选 kernel | 3 个 env 都显示 `3.11.16`，**只能按路径尾部选** |

**自检永远看 `sys.executable`，绝不看 `CONDA_PREFIX`。** 每章 `setup()` 打印的解释器指纹就是为此设计的，**每次都要看那一行**。

**资源上限**：`N_THREADS = 28`（持续 28 核/56 线程）；**`USE_GPU = False`** —— 本机 GTX 1060 **3 GB**，`rapids-singlecell` / `CellBender` / `cell2location` **全部跑不动**，scVI 只能 CPU（几万细胞 CPU 可接受）。RAM 125 GB 富余 ⇒ **out-of-core 不是刚需**。
**超过几分钟的步骤一律进 tmux**（见 `/watchdog`）。

### 2.1 实测耗时（proj23，6 样本 19,858 cells，28 核上限，2026-09-18）

**全 20 章端到端 ≈ 1 小时 20 分**（含四种整合横评与 Azimuth 参考映射）。逐步骤：

| 步骤 | 实测 | 说明 |
| :--- | :---: | :--- |
| 整合横评（CCA+RPCA+Harmony+fastMNN 各一遍） | **11 min** | 全流程最贵的一步，占总时长约 1/7 |
| Azimuth 映射到 297k 细胞骨髓参考 | **7.5 min** | 加参考下载首次 +411 MiB |
| 轨迹（slingshot + tradeSeq GAM，3,021 cells） | 4.8 min | |
| 聚类 + clustree + 重抽样稳定性 | 3.5 min | 已退出 future 并行仍只要这么多 |
| 其余各章（QC / 注释 / DE / 富集 / 组成 / 通讯 / sketch） | **各 1.5–3 min** | |

**用途**：2 万细胞这个量级，**除了整合与参考映射，其它步骤都是分钟级** ——
不要为了省几分钟去关并行或跳过验证；真正值得优化的只有那两步。

### 2.2 长流程的工程约定：checkpoint 链（proj23 实跑验证）

每一章**只读上游 checkpoint、只写自己那个**，并在正文里显式标注「上游 X / 产出 Y」：

```r
seu <- read_ckpt("ckpt_06_integrated", produced_by = "3-1")   # 缺了会明确报错，而不是往下跑
...
save_ckpt(seu, "ckpt_07_clustered")
```

**这条约定的价值在出事的时候才显出来**：proj23 首轮 14 个问题里有 9 次需要中途停下来改代码，
每次都只需 `--from <章号>` 续跑，**没有一次要从头再来**。
`read_ckpt(produced_by=)` 的作用是把"缺上游"和"代码写错"两类失败分开 ——
前者给一句人话提示，后者才是真错。

---

## §3 逐环节 SOP —— 每格都写"默认不能用在哪"

### 3.1 读入与第一次体检

```bash
/mnt/ex_8T_SSD/conda_envs/sc_tut_main/bin/python \
  /home/gao/projects_2026M7/22_python_based_scRNA_tutorial/notebooks/01_introduction/0_first_look_qc.py raw.h5 filtered.h5
```

| 必查 | 正确值 | 错了会怎样 |
| :--- | :---: | :---: |
| `MT-` 基因数（人） | **13** | 前缀写成 `mt-`/`chrM` ⇒ `pct_counts_mt` 全 0，被读成"数据质量很好"，**零报错** |
| barcode 后缀集合 | 单库全 `-1` | 出现 `-2`/`-3` 说明是 `aggr` 过的，**必须拿到 aggr CSV 的顺序**否则认不出样本 |
| `feature_types` | 只有 `Gene Expression` | 混进 `Peaks`/`Antibody Capture` ⇒ HVG 选出一堆 peak，PCA 变成混合信号，**图照画但无意义** |
| raw / filtered 行数比 | 几个百分点 | — |

**两条铁律**：① **不要自己拿 UMI 阈值切 raw 代替 filtered** —— cell calling 是 EmptyDrops 类统计检验不是阈值，s4d8 实测 99.9% 的细胞落在"单看 UMI 无法与空液滴区分"的重叠区间，强行按阈值切错判 ≈6.8% **且系统性偏向低 RNA 含量细胞类型**；② **不要只留 filtered 扔掉 raw** —— raw 是 ambient RNA 校正的唯一原料。

其它必做动作：`var_names_make_unique()`（原地修改返回 `None`，**别写成 `adata = adata.var_names_make_unique()`**）；跨样本合并**按 `gene_ids` 不按 symbol**；显式加样本前缀 `f"{sample}_{bc}"`，**不依赖 concat 自动加的数字后缀**。

### 3.2 QC → 归一化 → HVG → 降维

| 步骤 | 做法 | ⚠ 非默认/易错点 |
| :--- | :---: | :---: |
| QC 阈值 | **逐样本 MAD 自适应**（`scater::isOutlier` 或 scanpy 等价写法） | 全局一刀切会把某个样本整体判掉；固定 `nFeature 200–2500 / mt<5` 已不被接受为默认 |
| doublet | **scDblFinder（R，benchmark 最强）** 或 scrublet / solo | **逐样本跑，不要合并后跑**；doublet 簇看起来像真实过渡态 |
| ambient RNA | **SoupX / decontX（R，CPU）** | 组织解离样本（肿瘤/肝/胰腺）不校正就报低表达 marker = 常见翻车点。**CellBender 本机不可用** |
| ambient **ρ 的估计** | **必须放在聚类之后**，不能放在 QC 阶段 | 估 ρ 要先定义"不该表达该示踪基因的细胞"，**这个判据必须独立于该基因本身**。SoupX `autoEstCont` 因此需要簇标签。没有簇就只能拿基因自己的表达分位数圈背景细胞 ⇒ 循环论证（见 §4）。做法：在**簇**层面判"该簇不表达 g"（簇均值 ≤ 5% × 最高簇），再拿该簇**全部细胞**去测量 |
| doublet 检测的依赖 | `sc.pp.scrublet` 在 `threshold=None` 时**硬依赖 skimage** | 缺包报 `ValueError: threshold is None and thus scrublet requires skimage`。会报错，但只在跑到那一步才炸，前面几十分钟白跑 ⇒ 开跑前先 import 一遍 |
| counts 备份 | `adata.layers["counts"] = adata.X.copy()` **在归一化之前** | `sc.pp.scale()` 原地覆盖 `X`；Seurat 的 `scale.data` 在 AnnData 里没有对应槽位 |
| 归一化 | shifted-log（median-of-counts）为默认；Pearson residuals 可作对照 | — |
| HVG | **只打 `var['highly_variable']` 标记**，下游 `use_highly_variable=True` | 子集化基因**不可逆**，经典 marker 常不是 HVG |
| PCA/UMAP | PCA 50 维起步；UMAP **只做展示** | **簇间"距离远近""是否连续"一律不能从嵌入图上读**，也不能作为定量结论 |

### 3.3 整合：必须给量化依据，不能凭喜好

| 方法 | 什么时候 |
| :--- | :---: |
| **Harmony** | 默认；快、无监督、批次效应强时首选 |
| **scVI / scANVI** | 复杂任务、需要半监督带标签；本机 CPU 跑 |
| **RPCA（Seurat 侧）** | 保守、不过度混合 |

**判据不是喜好**：按 scIB 思路把"批次去除"与"生物变异保留"**拆成两组指标分别打分**，至少给两个量化指标（如批次 kBET/iLISI 类 + 细胞类型 ASW/保留度），并**与"不整合"并排比**。
**⚠ 强整合可能同时抹掉真实的组间差异** ⇒ 整合后必须检查"不该变的有没有变"（阴性对照基因、已知应当分开的细胞群）。

### 3.4 注释：三条腿 + 不确定性

| 路线 | 工具 | 定位 |
| :--- | :---: | :---: |
| 手动 marker | 文献 marker + dotplot | **永远要做**，是另外两条腿的验收标准 |
| 分类器 | CellTypist（Py）/ SingleR（R） | 有匹配模型时最省事 |
| 参考映射 | Azimuth / scANVI / ProjecTILs / scGate | 有**同组织**高质量参考时精度最高 |
| 共识 | popV | 需要可辩护标签时 |

**两条硬规则**：

1. **参考图谱必须组织匹配。** 用 PBMC 参考跑骨髓数据会给出一堆看起来非常合理的标签（骨髓前体在 PBMC 参考里根本不存在），**且没有任何报错**。
2. **阈值固化成元数据列**：新增 `*_reliable` 布尔列与 `celltype_*` 列，低分细胞置 `Unassigned`。**阈值从 score 密度图的谷底读，不是拍脑袋定 0.5。** 判断留在读者脑子里 = 没做。

`predicted.celltype.score` 问"在给定标签集内哪个最像"，`mapping.score` 问"参考里到底有没有这类细胞" —— **两个不同的问题，必须都看。**

### 3.5 跨条件 DE：本 skill 最承重的一节

```
按「样本 × 细胞类型」分组 → 聚合 raw counts（求和）→ 每个细胞类型单独建模 → DESeq2/edgeR
```

| 必须做对 | 说明 |
| :--- | :---: |
| 聚合的是 **raw counts** | 不是归一化值 —— DESeq2/edgeR 要整数 counts |
| **每个细胞类型单独建模** | 不是全部细胞混一起 |
| **剔除 <10 细胞的格子** | 并在报告里列出剔除了哪些 |
| 细胞级结果的地位 | 只能作为**方向一致性的旁证**，报告里必须写明**它不是独立证据** |
| 阴性结果的写法 | 非显著但效应不为零 ⇒ 写 "no statistically significant …"，**不写"无变化"**（underpowered ≠ null） |

**桥怎么搭**：Python 导出 `<proj>_pseudobulk_counts.csv`（样本 × 基因，整数）+ `<proj>_pseudobulk_coldata.csv`（样本元数据）→ R 侧 `DE_R45` 读入建模。
**⛔ 不用 rpy2 / reticulate 做流程内互操作** —— 判据：**桥必须能在两边 env 各自独立升级后依然成立**，文件能，进程内调用不能。
需要整个对象过桥时才用 `.h5ad ↔ SCE`（zellkonverter，**本机未装**），转完**必须核对细胞数、基因数、metadata 列数**；`.h5ad ↔ Seurat`（sceasy）会丢图结构与部分 uns。
**⚠ AnnData 是 cells × genes，Seurat/SCE 是 genes × cells —— 转置错了不报错。**

### 3.6 组成 / 富集 / 通讯 / 轨迹

| 分析 | 工具 | 分寸 |
| :--- | :---: | :---: |
| 细胞组成差异 | scCODA / pertpy（Py）、sccomp / propeller（R） | 比例是**成分数据**，一类变多必然压低其他类 ⇒ **不能各自独立做 t 检验/卡方** |
| 富集 | decoupler / gseapy（Py）、clusterProfiler / fgsea（R） | **ORA 分 UP/DOWN 做**；GSEA 用连续统计量 |
| 细胞通讯 | CellChat v2（R）、LIANA+（Py） | 输出是"表达模式相容"，**不是"确实发生了通讯"** ⇒ 报告里写成假说 |
| 轨迹 / velocity | CellRank 2 / scVelo（`sc_tut_traj`） | velocity 需要 spliced/unspliced 分层，**CellRanger 标准输出没有**，要 velocyto/kb-python 重跑比对 |
| GRN | pySCENIC（`sc_tut_grn`） | 该栈钉死 py3.10 + pandas 1.5.3 + numpy 1.23.5 + dask 2023.3.2；**pyscenic 可能静默返回空 regulon 而不报错** ⇒ 章节第一格写死版本校验 assert |

---

## §4 静默错误清单 —— 按"是否报错"排序（报错的反而安全）

| 坑 | 报错？ | 后果 |
| :--- | :---: | :---: |
| `MT-` 前缀大小写写错 | **否** | 线粒体比例全 0，被读成"质量很好" |
| 不做 `var_names_make_unique()` 就按名取基因 | **否** | 取到重复 symbol 中的任意一个（该参考包实测 10 个重复） |
| 跨样本按 symbol 而非 `gene_ids` 合并 | **否** | 静默取交集 / NaN 列 |
| 同项目混用不同参考包 | **否** | 引入与批次效应无法区分的技术变量 |
| 用 `FindMarkers`/`rank_genes_groups` 做跨条件 | **否** | 伪重复，p 值虚高 |
| Seurat v5 layers 未 `JoinLayers()` 就 DE/导出 | **否** | 部分操作只用第一个 layer |
| **拿旧 `.rds`（v3/v4 对象）当 v5 用**：`UpdateSeuratObject()` **不转 `Assay`→`Assay5`** | 有（但延迟且提示误导） | 它跑完会打印 "Object representation is consistent with the most current Seurat version"，**而 `class(obj[["RNA"]])` 仍是 `Assay`** ⇒ 几十行之后 `JoinLayers()` 才报 "no applicable method"。修法=`obj[["RNA"]] <- as(obj[["RNA"]], "Assay5")` 再 `stopifnot(inherits(..., "Assay5"))`。公开数据集/合作者给的 rds 几乎都是这种 |
| `SCTransform` 静默把 `DefaultAssay` 改成 SCT | **否** | 此后所有 DE/FeaturePlot 作用在 Pearson 残差上，含义全变 |
| 参考图谱与组织不匹配 | **否** | 给出一堆看似合理的标签 |
| **参考不匹配时，"被过滤掉多少"容易归错因** | 否（有提示行） | ProjecTILs `filter.cells=TRUE` 的移除由**内部 scGate 纯度门控**做，不是"图谱不覆盖这些细胞类型"。proj23 实测 3478 → **70（98% 被移除）**，而同一批细胞表达层面 CD8A/B+ 占 33.2%、CD4+ 仅 7.1% ⇒ 覆盖范围解释不了这个量级。**归错因的后果是改错东西**（去换更宽的图谱，而真问题是这批细胞压根不像纯 T）。⚠ **关掉 filter.cells 不是补救**：投影总会把每个细胞派给最近的状态，实测关掉后 3478 个细胞 **81% 挤进 CD8.CM** —— **"状态坍缩"才是参考不匹配的第二条硬判据**，且它在过滤率正常时也能抓到问题 |
| **参考图谱与物种不匹配**：`ProjecTILs::load.reference.map()` 不带参数 = **小鼠** `ref_TILAtlas_mouse_v1.rds` | **否** | 人数据套小鼠图谱，基因符号大小写都对不上；要么被 `filter.cells` 大面积丢弃、要么映射到无意义状态，**日志里只有一行文件名**。proj23 的代码注释白纸黑字写着"默认下载 human TIL atlas"，存在 49 天没人怀疑。人类参考必须 `get.reference.maps(collection="human", reference="CD8"/"CD4"/"DC"/"MoMac")` 显式点名；验收看 `head(rownames(ref))` 是不是人类大写符号。⚠ **CD8 图谱不覆盖 CD4/NK**，这部分被过滤掉不能读成"状态谱不重叠" |
| **样本名做过 `_`→`-` 变换后又用 `gsub("-","_")` 反解** | **否** | 正向变换不可逆：`ETV6-RUNX1_1` → `ETV6-RUNX1-1` → 反解成 `ETV6_RUNX1_1`，**样本名自带的那个 `-` 也被改掉** ⇒ `match()` 给 NA ⇒ `samples$group[NA]` 静默得到 NA。proj23 实测 6 个样本 3 个中招，**恰好是全部 CASE 样本**，而 UMAP/聚类/出图一切正常。修法=**拿正向变换本身去匹配**（`match(orig.ident, names(datadirs))`），别写 f⁻¹ |
| **注释里写的"默认行为"当成事实** | **否** | 上面两条的共同母题。凡是"默认会下载 X""默认用 Y"的注释，都要有一次实跑证据（看日志里的真实文件名 / `args()` / 函数体），否则它只是作者当时的以为 |
| `bc.split("-")[0]` 遇上双后缀 | **否** | barcode 被截错 |
| 插补后再做相关/共表达 | **否** | "强相关"可能完全是算法造的 |
| `adata[mask]` 是 view 不是新对象 | 有时 | 写回触发隐式复制或报警 |
| **用被测变量自己的分位数圈"背景/对照"细胞** | **否** | **结果按构造恒为 0，而且专挑好示踪剂下手。** 稀疏基因（检出率 <40%）的 `np.quantile(expr, 0.60)` 就是 0，于是"背景细胞"= 表达为 0 的那批，背景内总 count 必然是 0。proj22 实测 6 个示踪基因 5 个返回 0.000，唯一非零的是检出率 83% 的 HBB —— **那恰好是会让结果偏高的坏示踪剂**。改正后 ρ 从 0.0 变成 5.95%。**通用判据：选择单位与测量单位不能是同一个变量** |
| `sanity_report` 对"故意很差的对照组"误报 | 否（出 ⚠ 而非错） | 它只看与中位数的倍数差、不看方向。proj22 的 Pearson residuals 因为**去深度效应最好**（0.120 vs 中位 0.464）被判离群 —— 正是那一章要证明的结论 |
| **`future::plan("multicore")` 与包内部自建的 BiocParallel fork 叠加** | 报错 | `INTERNAL ERROR: Cannot remove from 'multicore-<hash>' registry`。两个各自正确的并行设置撞车（proj23：`set_parallel()` 设 future multicore，`scGate(ncores=8)` 又自建 `MulticoreParam`）。修法=调用期间 `future::plan("sequential")`，让下游库自己那层并行（实测 19,858 cells 仍 1.0 分钟跑完），**不要去调 workers 数量**。与 joblib 那条同族：并行设置会被下游库再解释一次 |
| 对全矩阵 `.toarray()` | OOM | raw 稠密化约 101 GB |

---

## §5 自审：写成代码，不靠肉眼

共享断言有**两份对应实现，新项目直接复用、不要重写**：

| 语言 | 文件 | 状态 |
| :--- | :--- | :---: |
| Python | [`22_.../scripts/_common/sc_tut_utils.py`](/home/gao/projects_2026M7/22_python_based_scRNA_tutorial/scripts/_common/sc_tut_utils.py) | proj22 在用 |
| **R** | [`23_.../scripts/_common/sc_tut_utils.R`](/home/gao/projects_2026M7/23_R_based_scRNA_tutorial_2026/scripts/_common/sc_tut_utils.R) | **proj23 全 20 章实跑，33 次触发零失败**（proj24 已软链复用） |

R 版除三个同名断言外，还提供整套工程约定：`save_ckpt`/`read_ckpt`（见 §2.2）、
`save_fig`（**已走 `cairo_pdf`，否则中文标题在交付 PDF 里变成一串点**，见
`~/Utilities/software_pitfalls/r_pdf_cjk.md`）、`save_table`、`set_parallel`、
`scale_color_tut`（配色已避开 ColorBrewer Set1 的浅黄）、`chapter_header`（打印版本指纹）。

下面这四个断言两边同名同义：

| 函数 | 抓什么 |
| :--- | :---: |
| `assert_all_points_visible(ax, n)` | 散点图实际可见点数 ≠ 期望 N（NaN 坐标、shape 映射超标记数 ⇒ 静默丢点） |
| `assert_text_layer_present(ax, n)` | 定义了 label 映射却没加文字层 ⇒ 标签永不出现、零报错 |
| `assert_annotation_aligned(adata, key, df)` | heatmap 分组注释用布尔过滤而非 `reindex` ⇒ 图例整体反转 |
| `sanity_report(dict)` | 跨可比对象扫离群值（一个对比 18 个 DEG、同类几千个） |

**另加两类每个项目都要有的检查**：

- **阳性对照断言**：先想好"什么必须出现"（如 IFN 刺激实验必须出 ISG、轨迹方向必须从祖细胞指向分化末端），**失败即 `stop()`**。比事后解释一堆陌生基因可靠。
- **"0 值"当结论前先断言分母非零**：任何"没检出 / 比例为 0 / 无显著"的结果，写进结论之前先 `assert` 它的分母不是被自己的筛选条件掏空的。proj22 的一行防线：`assert bg_counts > 0, "背景细胞里一个 count 都没有，说明背景选法退化了"` —— 有它就会炸，没它就返回一个长得像生物学结论的 0。
- **自证伪重复**（可选但强烈建议写进报告附录）：在同一份数据上把**对照组内部随机对半分**也跑一次细胞级检验，把"照样检出 N 个显著基因"的数字摆出来。抽象忠告没用，同数据自证才有说服力。

### 5.1 跑之前先做一次 0 算力的静态预检（2026-09-17 加，proj23 实测有效）

**教训**：proj23 的 20 章代码在写完时全部通过 `parse()`，但首次真跑九个事件里**有五个**
（缺包、缺 `library()`）可以在 0 秒算力下找出来 —— 而实际是靠一章一章渲染撞出来的，
每撞一次浪费几分钟到一小时（3-1 那次是 CCA/RPCA/Harmony 三种整合方法全跑完才报
`object 'FastMNNIntegration' not found`）。

```
从每个 .qmd / .py / .R 抽出代码
  → parse() + all.names()（R）/ ast.walk（Python）取出全部被调用的符号
  → 减去：base/内置、本地工具文件定义的、本文件内自定义的、已 library()/import/pkg:: 覆盖的
  → 剩下的到【已安装包】的 getNamespaceExports() / dir(module) 里反查来源
  → 报告"用到但没加载"与"根本没装"
```

**两个必踩的实现坑**（第一版都写错，结果完全不可用）：

- 一行里有多个 `library(a); library(b)` 时**必须 `gregexpr` 全取**；
  `gsub(".*library\\((...)\\).*", "\\1", x)` 的前缀 `.*` 是贪婪的，**只拿得到最后一个**
  ⇒ 把已加载的包全报成缺失，噪声把真信号淹掉；
- dplyr / tidyverse 的 NSE 会把**列名**（`logFC`、`gene`、`cluster`、`n`）混进符号表，
  它们会被误配到恰好导出同名函数的包上 ⇒ 这一类必须人工过一遍。

`parse()` 通过只说明语法对。它**查不出**：函数不存在、包没加载、参数语义反了、参考物种错了。

配色与出图一律走 `/scientific-figure-making`（`PALETTE` 已把 ColorBrewer Set1 的浅黄 `#FFFF33` 换掉，`LABEL_COLOR` 强制黑字）。**交付图件只要 PDF。**

---

## §6 AI / LLM 的使用纪律

| 场景 | 判定 |
| :--- | :---: |
| 分割、降维、批次整合、注释（感知/表示类） | 🟢 AI 通常是对的选择 |
| 基础模型（scGPT / Geneformer）零样本嵌入 | 🔴 **不进生产流程** —— 多项独立 benchmark 显示不及 HVG+PCA 基线，Geneformer 整合指标持续垫底 |
| 扰动效应预测 | 🔴 **不写进任何结论性句子**；深度模型至今没赢过刻意简单的线性基线 |
| 插补 / 去噪 | 🔴 有**主动危害**（见 §0 规则 7） |
| LLM 做细胞类型注释 | 🟡 可用：**top-10 DE 基因 + 双侧 Wilcoxon**、给定候选集、**一簇一问**、必须与 CellTypist/SingleR 对一遍，**不一致的簇 = 人工必看清单** |
| LLM 解读通路 | 🟡 **只能给"已经在你富集结果表里的通路"排序和解释**；表外出现的通路名 = 幻觉，直接判失败 |
| LLM 做因果断言 / 阴性结论 / 文献引用 | 🔴 **绝不** |

**铁律**：任何 AI 方法都必须与**刻意简单的基线**并排跑，并给出**同口径指标差**；赢不过基线就没有使用理由。AI 的输出（分割出的细胞、嵌入、预测值）在报告里**永远标注为模型产物，不是观测**。

---

## §7 参考实现索引（要跑代码就去这里抄，不要重新发明）

| 环节 | 可运行源文件（jupytext percent `.py`，认 `# %%`） |
| :--- | :---: |
| 体检 / 上游 / AnnData | [`notebooks/01_introduction/`](/home/gao/projects_2026M7/22_python_based_scRNA_tutorial/notebooks/01_introduction/) 4 份 |
| QC → 归一化 → HVG → 降维 → 整合 | [`notebooks/02_preprocessing/`](/home/gao/projects_2026M7/22_python_based_scRNA_tutorial/notebooks/02_preprocessing/) 5 份 |
| 聚类 → 手动/自动/迁移注释 | [`notebooks/03_cellular_structure/`](/home/gao/projects_2026M7/22_python_based_scRNA_tutorial/notebooks/03_cellular_structure/) 4 份 |
| DE / 组成 / 富集 / 扰动 | [`notebooks/04_conditions/`](/home/gao/projects_2026M7/22_python_based_scRNA_tutorial/notebooks/04_conditions/) 4 份 |
| 轨迹 / velocity / 命运 | [`notebooks/05_trajectories/`](/home/gao/projects_2026M7/22_python_based_scRNA_tutorial/notebooks/05_trajectories/) 3 份 |
| GRN / 细胞通讯 | [`notebooks/06_mechanisms/`](/home/gao/projects_2026M7/22_python_based_scRNA_tutorial/notebooks/06_mechanisms/) 2 份 |
| R/Seurat 对照写法 | [`23_R_based_scRNA_tutorial_2026/chapters/`](/home/gao/projects_2026M7/23_R_based_scRNA_tutorial_2026/chapters/) 20 章 `.qmd` —— **2026-09-18 全部 20 章实跑通过**（`sc_tut_r` env、`_site/` 有全站 HTML、16 个 checkpoint、46 张 PDF、31 份表、33 条 audit 断言零失败）⇒ **这是目前唯一端到端验证过的 R 主线实现，抄代码优先来这里** |

**⚠ 状态标注（proj23 部分更新于 2026-09-18）**：**proj23 已全量跑通**（详细排查链见
`23_R_based_scRNA_tutorial_2026/docs/P23_run_and_troubleshooting_log_0917.md`，14 个事件）；
**proj24（空间/进阶）仍未执行**，且它的 `4_render_all.sh` 有与 proj23 同款的 quarto-deno 坑、
全项目没有 `options(timeout)` —— 动它之前先看 `~/Utilities/software_pitfalls/quarto_conda.md`
与 `r_download_timeout.md`。**proj22 的状态（2026-09-18 复核，它由并行会话持续推进，引用前最好再看一眼目录）**：
4 个 env 已建成并逐模块验证；`output_results/` 现有 **ch1-1 ~ ch5-3 共 19 个章节产物 + 16 个
`.h5ad` checkpoint**（最新 09-17 20:49），`tmp/done_stamps` 11 个。
**ch5-1 与第 6 章及之后尚无产物** ⇒ 引用那些章节时说"已写好可参考"，**不要说"已验证跑通"**。
proj24（空间/进阶）三个 env 里 `sc_adv_r`(3.9 G) 与 `spatial_r`(4.2 G) 已建、**`scvi_py` 未建**
（scVI 相关章节会卡在这里）；**17 章一章都没跑过**（无 `_site`/`_freeze`/`run_logs`，
`output_results` 为空）。且它的 `4_render_all.sh` 带着与 proj23 同款的 quarto-deno 坑、
全项目无 `options(timeout)` ⇒ 动它之前先看 `~/Utilities/software_pitfalls/quarto_conda.md`
与 `r_download_timeout.md`，能省掉 proj23 踩过的头两轮。
已知缺口：`sc_tut_spatial` 里 SpatialDE 不可用（scipy 1.17 移除 `scipy.misc.derivative`，按决定不修，7-4 章有兜底）。

**依赖排查顺序**（import 失败时照这个走，不要先读报错行）：
① `import sys; print(sys.executable)` → ② `ls -d /mnt/ex_8T_SSD/conda_envs/sc_tut_*` → ③ 核对本章该用哪个 env → ④ `bash scripts/1_setup_envs.sh --verify-only <env>` → ⑤ 才看代码。
**共同病理**：不再活跃维护的包引用了依赖里已删除的符号，而那个依赖**在 yaml 里没有 pin**。修法是钉住它并把"为什么"写回 yaml。

---

## §8 交付与报告

- **全流程 = 分析 + 交付**：`output_results/` 有产物**不等于**结束，交付目录生成 + 报告写完才是终点（见 `/delivery`、`/report`）。
- **客户唯一能自行复分析的东西必须给到**：细胞级 counts（`.h5ad` 或 mtx 三件套）+ **细胞注释表** + **pseudobulk counts 矩阵与 coldata**（CSV）。⛔ 交付目录不放 `.rds` / `rds_cache/` / 中间 checkpoint。
- **报告必须描述处理因素本身的生物学响应**，不能只给 DEG 数 + 通路名单；阴性结果照写。
- 报告头部必须写明 **Species + Tissue/Cell type**；缩写首次出现拼出英文全称。
- **数据质量要详写**：设计有无混杂 → 技术 QC → PCA/整合表现 → 该变的变了没 → **不该变的有没有乱变**。
- 对外一律**只准备不发送**。

**启动语义照旧**：请求里没有"自动/全流程/全过程"三个关键词 ⇒ 只做调研与研究计划，不跑正式分析。
