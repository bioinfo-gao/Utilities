# AI 在单细胞与空间转录组中（一）：作为分析方法，什么真有用、什么是炒作

**版本**：2026-09-10 ｜ **作者**：Zhen Gao（与 Claude Opus 5 协作起草）
**本篇范围**：**AI/ML 作为分析方法本身** —— scVI 这类深度生成模型、Cellpose 这类分割模型、
scGPT 这类基础模型、以及自动注释与扰动预测。
**不含**：把 LLM 当分析助手（见第二篇）、用 LLM 做生物学推断（见第三篇）。

**三篇的关系**

| 篇 | 主题 | 文件 |
| :--- | :---: | :---: |
| **一（本篇）** | AI 作为**分析方法** | 本文件 |
| 二 | LLM/agent 作为**分析助手** | [`AI_in_singlecell_and_spatial_2_agent_workflow_20260910.md`](AI_in_singlecell_and_spatial_2_agent_workflow_20260910.md) |
| 三 | LLM 做**生物学推断** | [`AI_in_singlecell_and_spatial_3_llm_biology_20260910.md`](AI_in_singlecell_and_spatial_3_llm_biology_20260910.md) |

**标注约定**：**【检索】**= 2026-09-10 检索到的事实（§7 附来源）；**【判断】**= 我的评估；**【未验证】**= 未查证。

---

## §0 结论先行：一张可信度分级表

| 环节 | AI 的地位 | 证据 | 判定 |
| :--- | :---: | :---: | :---: |
| **图像分割**（成像平台、Visium HD 2 µm） | **不可替代** | Cellpose-SAM **超过人类标注者之间的一致性**，逼近 human-consensus bound **【检索】** | ✅ **直接用** |
| **批次整合**（复杂任务） | **当前最优之一** | scANVI/scVI/scGen 在**复杂任务**上最好；**Harmony 在简单任务上仍有竞争力** **【检索】** | ✅ **按任务复杂度选** |
| **自动细胞注释**（监督分类器） | 成熟 | 属于常规监督学习，非"生成式 AI" | ✅ **直接用** |
| **spot 去卷积** | 第一梯队 | cell2location（贝叶斯/深度）与 RCTD（统计）**并列最优** **【检索】** | ✅ **但非 AI 独占** |
| **基础模型 zero-shot 嵌入** | **不及简单基线** | Geneformer/scGPT 零样本**不及 HVG 基线** **【检索】** | ⚠️ **别当默认** |
| **扰动预测** | **未赢过线性基线** | Nature Methods：5 个基础模型 + 2 个深度模型，**没有一个赢过刻意简单的线性基线** **【检索】** | ⛔ **不要据此下结论** |
| **插补 / 去噪** | **有主动危害** | MAGIC 在本无相关的基因间**制造强正相关**；MAGIC/DCA 把**所有零当成缺失**，输出"每个基因在每个细胞都表达" **【检索】** | ⛔ **默认不做**（见 §3.3） |

**一句话**：**AI 在"感知类"任务上已经赢麻了（分割、把高维数据压成表示），
在"因果/预测类"任务上还没赢过刻意简单的基线。** **【判断】**
这条分界线比"哪个模型更新"有用得多。

---

## §1 先把四类"AI"分开——不分开就没法讨论

**领域里说的"AI"至少是四种不同的东西，可信度差了一个数量级。**

| 类 | 代表 | 训练方式 | 你该怎么看 |
| :--- | :---: | :---: | :---: |
| **① 判别式监督学习** | 细胞类型分类器（CellTypist / SingleR 一类） | 有标签，任务专一 | **就是统计学习**，成熟、可评估、无神秘性 |
| **② 深度生成 / 概率模型** | **scVI / scANVI / totalVI / DestVI** | 无监督或半监督，建的是**计数的概率模型** | **真正的主力**，见 §2.2 |
| **③ 视觉深度学习** | **Cellpose / Cellpose-SAM / StarDist** | 大量人工标注的图像 | **空间领域的刚需**，见 §2.1 |
| **④ 大规模预训练"基础模型"** | **scGPT / Geneformer** 及后继 | 在数千万细胞上自监督预训练 | **争议最大**，见 §3.1 |

**【判断】** 常见的认知错误是把 ④ 的宣传效果安到 ②③ 头上，或者反过来因为 ④ 被基准打脸
就连 ②③ 一起怀疑。**这四类要分开评价。**

---

## §2 AI 确实赢了的三个地方

### 2.1 图像分割：这是 AI 唯一"不可替代"的一格

**背景**：成像平台（Xenium / CosMx / MERSCOPE）直接产出的是**转录本坐标点**，
必须先判断"哪些点属于同一个细胞"才能得到表达矩阵。**这一步没有非 AI 的可行方案。**

**当前水平** **【检索】**：

- `Cellpose-SAM` 把 SAM（Segment Anything Model）的预训练 transformer 主干接到 Cellpose 框架上，
  **显著超过人类标注者之间的一致性**，逼近 human-consensus bound；
- 训练规模：**22,826 张图像、约 330 万个标注细胞**，来自 Cellpose、TissueNet、LiveCell、
  Omnipose、MoNuSeg 等十余个数据集；
- 对通道顺序、细胞大小、散粒噪声、降采样、各向同性/异性模糊**都稳健**；
- **已经是 Bruker CosMx 与 Vizgen MERSCOPE 商业平台内部的分割引擎**；
- 但 2026 年的横评显示 **没有单一模型在所有场景通吃**。

**⚠ 关键警告（§4 铁律 3 的来源）** **【检索】**：不同分割方法给出的**细胞数与细胞类型分布差异巨大**——
Bering 预测的细胞数远少于其他方法，Baysor 远多于其他方法。
**⇒ 分割不是预处理细节，它直接决定你报告里的细胞类型比例。**

### 2.2 深度生成模型：scVI 家族赢在"复杂任务"

**基准结论** **【检索】**：scANVI（带标签）、scVI、scGen（带标签）以及线性嵌入模型 Scanorama
表现最好，**尤其在复杂任务上**；而 **Harmony 在不太复杂的任务上表现良好**。

**【判断】** 这句话的可操作版本是：**"要不要上 scVI"的判据是任务复杂度，不是"深度学习更先进"。**

| 情形 | 建议 |
| :--- | :---: |
| 同一实验、少数批次、同一技术平台 | **Harmony 足够**，快、可解释、无需调参 |
| 多技术平台 / 多物种 / 强批次 + 需要保留细粒度亚群 | **scVI / scANVI** |
| 有部分标签可用 | **scANVI**（半监督，同时做批次矫正与注释） |

**【判断】** 另一个常被忽略的优点：scVI 家族给的是**概率模型**，可以输出不确定性、
可以做后验采样——这比"多一个降维方法"有价值得多。

### 2.3 去卷积：AI 与统计方法打平

**【检索】** cell2location（贝叶斯/深度）、SPOTlight、RCTD（统计）是最优的一组；
cell2location **预测最稳定**。

**【判断】** ⇒ 这一格**不构成"必须用 AI"的理由**。选 RCTD 不吃亏（详见空间篇 §5.2）。

---

## §3 AI 明确**没有**赢的三个地方（这一节才是本文的价值）

### 3.1 基础模型（scGPT / Geneformer）：零样本不及最朴素的基线

**【检索】**（多项 2026 年独立基准）：

- 零样本 scFM 嵌入在多种生物系统中**不及 HVG 基线**，尤其在恢复未观测细胞的分布复杂性上；
- 聚类任务中，**HVG 选择 + scVI + Harmony 在生物学保真与批次整合指标上常常更好**；
- **无参数的简单线性方法**在多个基准上达到或接近 SOTA，**在分布外任务上还更好**；
- 收益**强烈依赖任务**：细胞类型注释获益明显，**扰动预测获益有限**。

**【判断】** 结论不是"基础模型没用"，而是：
**在 2026 年，不会用基础模型不构成方法学劣势；把它当默认第一选择则是方法学错误。**

### 3.2 扰动预测：这是最硬的一记

**【检索】** Nature Methods（2025）标题即结论：
*"Deep-learning-based gene perturbation effect prediction does not yet outperform simple linear baselines"*
—— 该研究比较了**五个基础模型 + 两个其他深度学习模型**（含 GEARS、CPA、scGPT、scFoundation）
对单基因/双基因扰动后转录组变化的预测，**没有一个赢过刻意设计得很简单的基线**。

**【判断】** ⇒ **不要把扰动预测的输出写进任何结论性句子。** 它现在只适合做假设生成，
而且生成的假设**不比线性外推更好**。

### 3.3 插补 / 去噪：这一格有**主动危害**，不只是"没用"

**【检索】**：

- **过度插补会制造虚假相关**——MAGIC 在本来无相关或低相关的基因间**引入强正相关**；
- **MAGIC 与 DCA 把所有零当成缺失值**，输出的矩阵里**每个基因在每个细胞中都有表达**
  —— 也就是**生物学零被消灭了**。

**【判断】** 后果非常具体：**插补之后再做基因-基因相关、共表达网络、配受体分析，
得到的"强相关"可能完全是插补算法自己造的**。⇒ **默认不做插补**；
若必须做，**绝不在插补后的矩阵上做任何相关性类分析**，并在方法里写明。

---

## §4 怎么用：四条铁律

### 铁律 1：任何 AI 方法都必须与"刻意简单的基线"并排跑

**这条是本文所有证据的共同指向。** 具体基线：

| 你要做的 | 必须并排的朴素基线 |
| :--- | :---: |
| 基础模型嵌入 | **HVG + PCA** |
| 深度整合（scVI） | **Harmony**（简单任务）或**不整合** |
| SVG 检测 | **Moran's I**（空间篇 §5.1：它在 14 方法基准里排第四） |
| 扰动预测 | **线性外推** |
| 任何"AI 更好"的说法 | 给出**两者的同口径指标差**，而不是只给 AI 的结果 |

**【判断】** 判据很简单：**复杂方法若赢不过朴素基线，就没有使用理由**——
而这在 2026 年是**经常发生**的情况，不是罕见例外。

### 铁律 2：先问"它改变了什么不该变的"

**【判断】** AI 方法的失败模式不是报错，是**输出看起来更漂亮**。
- 插补让 UMAP 更干净 → 因为它抹掉了生物学零；
- 强整合让批次完全混合 → 可能同时抹掉了真实的组间差异。

**⇒ 每次用完都要检查"不该变的有没有变"**：阴性对照基因、已知不应受影响的通路、
已知应当分开的细胞群。

### 铁律 3：分割与整合必须做敏感性分析

**【检索】** 分割方法之间细胞数差异可达数倍。**⇒ 至少用两种设置跑一遍，
看结论（细胞类型比例、组间差异方向）是否稳定。** 若结论随方法翻转，
那它就不是结论，是方法的产物。

### 铁律 4：AI 的输出永远标注为"模型产物"而非"观测"

**【判断】** 分割出的细胞、插补出的表达值、预测出的扰动效应、基础模型的嵌入——
**全都是模型的输出**。在报告里与实测量区分开写，是可复现性的最低要求。

---

## §5 决策树（照着走即可）

```
要做的事是"感知/表示"类吗？（分割、降维、批次整合、注释）
├── 是 → AI 通常是对的选择
│      ├── 分割 → Cellpose-SAM / Proseg / Baysor，必做敏感性分析（铁律3）
│      ├── 整合 → 任务简单用 Harmony；复杂用 scVI/scANVI
│      └── 注释 → 监督分类器；LLM 注释见第三篇
└── 否（因果/预测类：扰动效应、基因调控、疾病预测）
       └── 先跑线性基线 → AI 若赢不过（当前常态），
           就只把 AI 输出当假设生成，不写进结论
是否打算做插补/去噪？
└── 默认不做。若做，插补后禁止一切相关性/共表达分析（§3.3）
```

---

## §6 我不确定 / 有争议的地方

1. **本文引用的基准多数发表于 2025–2026 上半年** **【判断】**。基础模型迭代很快，
   §3.1 的结论**有可能在 12 个月内被推翻**——但届时应当**要求新证据同样与朴素基线对比**，
   而不是接受"新模型 vs 旧模型"的比较。
2. **Cellpose-SAM 在空间转录组数据上的表现** **【未验证】**——检索到一篇 2026 年的
   *"Foundation cell segmentation models performance on live microscopy and spatial-omics data"*，
   我只读到"**没有单一模型通吃**"这一句，未读全文。
3. **scVI 在小样本/浅测序下的行为** **【未验证】**——深度模型需要足够数据，
   本文引用的基准以中大型数据集为主。
4. **插补方法的新一代（如 scZN）是否真的解决了虚假相关** **【未验证】**——
   检索命中该方法自称"不引入虚假生物学信号"，但**这是作者自述，不是独立基准**。

---

## §7 来源（2026-09-10 检索）

- [Deep-learning-based gene perturbation effect prediction does not yet outperform simple linear baselines (Nature Methods)](https://www.nature.com/articles/s41592-025-02772-6)
- [Benchmarking deep learning methods for biologically conserved single-cell integration (Genome Biology)](https://link.springer.com/article/10.1186/s13059-025-03869-z)
- [Parameter-free representations outperform single-cell foundation models on downstream benchmarks](https://arxiv.org/pdf/2602.16696)
- [Benchmarking zero-shot single-cell foundation model embeddings for cellular dynamics reconstruction](https://www.biorxiv.org/content/10.64898/2026.03.10.710748v1.full)
- [Evaluating the learnability of single-cell large language models on multiple tasks (BMC Genomics)](https://link.springer.com/article/10.1186/s12864-026-12975-6)
- [Cellpose-SAM: superhuman generalization for cellular segmentation](https://www.biorxiv.org/content/10.1101/2025.04.28.651001v1)
- [Foundation cell segmentation models performance on live microscopy and spatial-omics data](https://www.biorxiv.org/content/10.64898/2026.04.18.719315v1.full)
- [Proseg — GitHub](https://github.com/dcjones/proseg)（分割方法间差异）
- [Spotless: benchmarking cell type deconvolution (eLife)](https://elifesciences.org/articles/88431)
- [Single-cell RNA-seq denoising using a deep count autoencoder (Nature Communications)](https://www.nature.com/articles/s41467-018-07931-2)
- [Zero-preserving imputation of single-cell RNA-seq data (Nature Communications)](https://www.nature.com/articles/s41467-021-27729-z)（虚假相关与"消灭生物学零"）
- [scvi-tools — GitHub](https://github.com/scverse/scvi-tools)
