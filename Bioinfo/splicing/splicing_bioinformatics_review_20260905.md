# RNA 剪接（Splicing）生物信息学研究综述

**版本**：2026-09-05
**作者**：Zhen Gao（与 Claude Opus 5 协作起草）
**定位**：写给**已有 splicing 领域知识、但约两年未实际上手**的分析者。因此本文**不做基础科普**（不解释什么是 exon skipping、什么是 PSI（percent spliced-in）的定义式推导），而是把篇幅压在三件事上：
  1. **这两年真正变了什么** —— 哪些工具从"可选"变成"默认"，哪些结论被 benchmark 推翻；
  2. **选型判据** —— 面对一个具体项目，凭什么决定用哪一类方法、测多深、用长读长还是短读长；
  3. **成本的完整账** —— **测序成本 + 分析人工成本之和**，分析按内部技术人力 **$60/hour** 折算。

**范围声明**：本文聚焦**生物信息分析**。剪接的分子机制（spliceosome 组装、SR/hnRNP 调控网络、branchpoint 化学）只在影响分析决策时才展开。

> ⚠ **可靠性标注约定**：本文中
> **【实测/文献】** = 有明确出处（见 §13）；
> **【估算】** = 我基于公开报价与实际项目工时推算，**是估算不是报价**，用于量级判断；
> **【判断】** = 我的方法学意见，读者可以不同意。
> 版本号与发表年份以我的知识范围（截至 2026-05）加本次检索为准，**引用前请自行核对 DOI**。

---

## §0 两年空窗期的重新校准清单（TL;DR）

如果你只读一节，读这一节。以下是 2024 中～2026 中之间，**会改变你实际操作**的变化。

### 0.1 短读长差异剪接：格局稳定，但默认选择变了

| 变化 | 说明 |
| :--- | :---: |
| **rMATS-turbo 成为唯一该用的 rMATS** | Nature Protocols 2024 正式化。保留原 rMATS 的统计框架与接口，重写计算流程；可扩展到**上万样本**级别。老的 rMATS 4.0.x 没有再用的理由。**【文献】** |
| **MAJIQ v2 在 FDR 上确立优势** | 报告 FDR ≈ 0.3%，**FNR**<sup>†</sup> 与 LeafCutter 相当（2.5–5.5%，随样本量变）；比 LeafCutter 多识别 34% 变化事件。**且它是唯一能做"未注释 intron retention"检测与定量的主流工具。** **【文献】** |
| **LeafCutter 的优势重新被定位为"速度 + 无需注释 + p 值校准好"** | 多个 benchmark 中 LeafCutter 的 p 值校准优于同类；在 ≤0.2 的任意 FDR 下检出更多事件；运行时间 1 小时级，而 rMATS / MAJIQ 是数小时级。**【文献】** |
| **SUPPA2 的定位是"快，但大样本量下 FDR 抬头"** | PSI 定量 24 秒级、差异分析 30 分钟级。代价：**样本量越大 FDR 越高**——因为它直接在 ΔPSI 上做检验，不回看 read 层数据。**【文献】** |
| **"工具间重叠低"已成公认事实，不再是可以忽略的技术细节** | 事件级 benchmark 中不同工具的排序会随评估口径反转（SUPPA/LeafCutter/DARTS/rMATS 在事件级排序，与 MAJIQ/LeafCutter 在复杂事件上的表现呈**相反趋势**）。**⇒ 单工具结果不可作为终点。** **【文献】** |

> **<sup>†</sup> 注：FNR（false negative rate，假阴性率）** = 在**真实存在**的差异剪接事件中被工具**漏掉**的比例，即 `FN / (FN + TP)` = `1 − sensitivity (recall)`。它与 **FDR（false discovery rate，假发现率）** = `FP / (FP + TP)` 构成**一对相互牵制的指标**，描述两类完全不同的错误：
>
> | 指标 | 错在哪 | 对项目的实际代价 |
> | :--- | :---: | :---: |
> | **FDR 高** | 报出来的事件里混着假的 | 你会去验证一堆不存在的事件，**浪费湿实验与工时** |
> | **FNR 高** | 真事件被漏掉 | 你会得出"这个条件下剪接没变"的**假阴性结论**——而这个错误在报告里**看不出来**，没有任何提示 |
>
> **为什么这里必须成对给出**：任何工具都能靠调松/调紧阈值在 FDR 与 FNR 之间移动，所以孤立的一句"FDR = 0.3%"是没有信息量的（把阈值调到极严，FDR 必然低，代价是 FNR 飙升）。**只有 FDR 与 FNR 成对报告，性能声明才可比。** MAJIQ v2 值得注意的地方正在于此：**把 FDR 压到 0.3% 的同时，FNR 没有相应变差**（与 LeafCutter 同档）。
>
> **⚠ 三处口径提醒**：
> 1. 此处 FNR 取 `1 − 灵敏度`（漏掉的真事件 ÷ 全部真事件），**不是**另一种少见写法 `FN / (FN + TN)`；
> 2. **2.5–5.5% 这个区间随样本量变化 —— 样本量越小，FNR 越高。** 我们常做的 **n=3** 项目处在该区间的**上沿甚至之外**，**【判断】** benchmark 数字不能直接搬到小样本项目上做承诺；
> 3. benchmark 里的"真实事件"由某种金标准定义（RT-qPCR 验证集，或用组内 vs 组间比较构造的近似真值），**不同论文金标准不同 ⇒ FDR/FNR 的绝对数值跨论文不可比**，只能比同一篇内部的相对排序。
>
> **⇒ 报告写作含义**：当我们写"未检出显著差异剪接事件"时，**必须同时说明该分析的检出力（power / 1−FNR）受什么限制**（深度、重复数、ΔPSI 阈值），否则读者无法区分"确实没变"与"没测出来"。参见 §11 pitfall #2、#3。


**【判断】** 这两年最重要的方法学转变不是出现了更好的工具，而是**共识从"选一个最好的工具"变成了"用两个坐标系互证"**。见 §10.3。

### 0.2 长读长：从"发现工具"升级为"可定量工具"——但只在有注释引导时

这是空窗期里**变化最大**的部分。

- **通量拐点已经过去。** PacBio Kinnex（原 MAS-Seq）通过 concatenation 把 Revio 单张 SMRT Cell 的 full-length 读段产量拉到千万级；ONT 的 R10.4.1 + RNA004 化学配合 dorado basecalling，把 cDNA 与 direct RNA 的可用性都推过了实用门槛。**长读长做定量（而不只是做 isoform 目录）在 2026 已经成立。**
- **LRGASP 联盟给出了第一份系统性 benchmark（Nature Methods 2024），结论很硬：** **【文献】**
  - **有注释引导时**：**IsoQuant 与 bambu 精度最高**；**IsoQuant 与 StringTie2 灵敏度最高**。
  - **de novo（无注释）时**：所有工具都不可靠，**假 isoform 大量涌现**。
  - 定量指标上（SIRV-Set 4）：IsoQuant ≈ 0.76、FLAIR ≈ 0.73、IsoTools ≈ 0.69、bambu ≈ 0.68（spearman 类相关）。
- **SQANTI3 从"锦上添花"变成"不做等于没做 QC"。** 长读长的 novel isoform 里混着大量技术假象：RT-switching、intra-priming（内部 polyA 引发的 3' 截断）、5' 降解。SQANTI3 的 SC（structural category：FSM/ISM/NIC/NNC）分类 + rule-based filter 是目前唯一被广泛接受的过滤层。
- **单细胞/空间长读长成了独立赛道**：Longcell（Nat Commun 2025）、SCOTCH（Nat Commun 2026）、FLAMES、scNanoGPS 等，核心难题是**在高错误率下恢复 cell barcode 与 UMI（unique molecular identifier）**，以及**read truncation 导致的 isoform 归属错误**。**【文献】**

### 0.3 变异 → 剪接效应预测：SpliceAI 仍是基准，但盲区被量化了

- **SpliceAI 与 Pangolin 高度冗余**：两者架构与训练集相似，预测值相关系数 **r = 0.97**。**⇒ 同时跑两个并不构成独立验证。** **【文献】**
- **MPSA（massively parallel splicing assay）benchmark（Genome Biology 2023）**：用 5 个基因 3,616 个变异的实测剪接结果检验 8 个预测器。SpliceAI 与 Pangolin 整体最好，**但外显子内部（exonic）变异仍是明确盲区**——ESE（exonic splicing enhancer）/ ESS（exonic splicing silencer）破坏类变异预测差。**【文献】**
- **SpliceVault 提供的是正交信息，不是又一个打分器**：它基于 ~30 万份公共 RNA-seq 建立经验性 junction 目录，回答的是"**如果这个 splice site 坏了，实际最常发生的是哪几种替代事件**"（top-4 cryptic sites / exon skipping）。**⇒ SpliceAI 回答"会不会坏"，SpliceVault 回答"坏了以后长什么样"。** **【文献】**
- **AbSplice 引入组织特异性**，把变异效应绑定到具体组织的剪接背景上。
- **临床侧**：ACMG PVS1 决策树对剪接类变异的应用已成熟化，**但"预测分数高"永远不能替代 RNA 层验证**（RT-PCR / 靶向 RNA-seq）。

### 0.4 剪接因子突变领域：分子指纹已定，机制走向"统一"

- 三个高频热点突变的**分析指纹已经明确且互不相同**：**【文献】**
  - **SF3B1** → 使用**新生/隐性 3' splice site**（典型偏移在正常 3'SS 上游约 10–30 nt）
  - **SRSF2** → ESE 结合偏好从 **GGNG 变为 CCNG**，改变外显子包含
  - **U2AF1** → 偏好**非共识 3' splice site**（S34F / Q157R 的偏好方向不同）
- **2025 年出现"统一机制"方向的工作**：三类突变虽各有指纹，但**共享一个 retained intron 亚群**；机制指向 SR 蛋白（如 SRSF1）RS 结构域的**低磷酸化**导致功能下降。**【文献，预印本，需谨慎】**
- **AS-derived neoantigen** 已成独立赛道：剪接异常产生的 neojunction 编码的新肽段，作为 mRNA 疫苗 / 过继细胞治疗的靶点来源。

### 0.5 单细胞剪接：从"工具涌现"进入"被 benchmark 收敛"

- 2026 年有了对 **BRIE2、scQuint、Psix、SpliZ、MARVEL、SCASL** 六个方法的系统评测。**【文献】**
- **不变的根本限制**：**10x 3' 端方案在原理上测不了绝大多数 AS 事件**——它只覆盖转录本 3' 端约 100–200 nt。这不是算法能补救的。
- 真正的解法只有两条：**Smart-seq2/3 全长（贵、通量低）** 或 **单细胞长读长**。

---

## §1 概念与坐标系：三种互不可换算的表述

这是全篇的方法学骨架。**工具家族的分野不是"谁的统计更好"，而是"它在哪个坐标系里描述剪接"。**

| 坐标系 | 基本单元 | 代表工具 | 能回答 | 不能回答 |
| :--- | :---: | :---: | :---: | :---: |
| **Event-centric（事件级）** | 预定义的 5 类事件：SE / A5SS / A3SS / MXE / RI | rMATS-turbo、SUPPA2、DEXSeq(exon bin) | "这个外显子被跳过的比例变了多少"（ΔPSI） | 复杂事件（>2 种可能的局部剪接图）；未注释的新事件 |
| **Intron/junction-centric（内含子级）** | intron cluster / LSV（local splicing variation） | LeafCutter、MAJIQ、MntJULiP | 任意复杂度的局部剪接变化；**不依赖完整注释** | 事件类型的直观生物学命名；跨越整条转录本的搭配关系 |
| **Transcript-centric（转录本级）** | 完整 isoform 的相对丰度 | salmon/kallisto + DRIMSeq/DTU、StringTie2、IsoformSwitchAnalyzeR、（长读长全家） | isoform switch、蛋白编码后果、NMD（nonsense-mediated mRNA decay）靶向、结构域得失 | 短读长下 isoform 归属高度依赖注释与统计推断，**新 isoform 不可靠** |

### 1.1 为什么三者不能互相换算

**【判断】这是最容易被忽视、也最容易在报告里出错的一点。**

- **事件级 → 转录本级不可逆推**：一个外显子 PSI 从 0.3 变到 0.7，**不告诉你哪条 isoform 变多了**。同一个 ΔPSI 可以由无数种 isoform 丰度组合产生。
- **转录本级 → 事件级会丢信息**：如果注释里没有那条 isoform，转录本级方法要么把 read 强行分配给最像的已知 isoform（**产生系统性偏倚**），要么直接丢掉。
- **intron-centric 的 LSV / cluster 编号在不同数据集之间不稳定**：LeafCutter 的 cluster 是**从数据本身聚出来的**，换一批样本、换一个过滤阈值，cluster 边界就变。**⇒ 绝不能把 cluster ID 当作跨项目的稳定标识符。**

**实践含义**：报告里如果同时呈现两个坐标系的结果，**必须显式说明它们不是同一件事的两次测量**，不要写成"两个工具都发现了 N 个事件，重叠 M 个"这种暗示可比性的句子——除非你已经把它们映射到了共同的基因组坐标（junction 级）上再比。

### 1.2 PSI 的统计性质——低覆盖下的陷阱

PSI = inclusion / (inclusion + exclusion)，是个**比例**，而比例的方差与分母强相关。

- **分母小的时候 PSI 的方差爆炸**。10 条 read 支持的 PSI = 0.5 和 1000 条 read 支持的 PSI = 0.5，是完全不同的证据强度。
- 这导致一个经典假象：**低表达基因看起来"剪接变化更大"**。任何只按 |ΔPSI| 排序、不看 read 支持数的筛选，都会把低表达基因排到最前面。
- **⇒ 硬性要求：任何 ΔPSI 阈值必须与 read 支持数阈值联合使用。** 常用组合：`|ΔPSI| ≥ 0.1` **且** `每组每样本 inclusion+exclusion reads ≥ 10`（严格些用 20）。
- 单细胞场景下这个问题被放大到极致：scQuint 那条线的工作明确指出，**"单细胞里剪接是二元的（PSI 只有 0 和 1）"这个广为流传的观察，很大程度上是覆盖度不足造成的假象**。**【文献】**

---

## §2 实验设计与测序策略

### 2.1 深度要求：剪接分析比差异表达贵得多

**核心事实**：差异表达（DE）的信号在**基因级 read 总数**上；剪接的信号在**跨 junction 的 read 数**上。而 junction reads 只占总 read 的一小部分（典型 PE150 数据里，跨 junction 的 read 约占比对上转录组 read 的 20–35%，且分布在数十万个 junction 上）。

| 分析目标 | 推荐深度（PE150） | 说明 |
| :--- | :---: | :--- |
| 差异表达 DE | 20–30 M read pairs | 常规够用 |
| **事件级差异剪接（rMATS / LeafCutter）** | **80–120 M read pairs** | 60 M 是绝对下限；低于此低表达基因的事件几乎全被过滤掉 |
| **转录本级 DTU** | **100–150 M read pairs** | isoform 解卷积对深度更敏感 |
| **短读长 de novo isoform 组装** | ≥150 M，**且仍不建议** | **【判断】** 短读长组装新 isoform 在 2026 已无必要——有长读长这个正确工具 |
| **长读长 isoform 定量（PacBio HiFi/Kinnex）** | ≥3 M FLNC（full-length non-concatemer）reads/sample | 5 M 更稳 |
| **长读长 isoform 定量（ONT cDNA）** | ≥15–20 M pass reads/sample | ONT 需更多 read 来抵消截断与错误 |
| **长读长 novel isoform 发现** | ≥5–10 M FLNC | 发现比定量更吃深度 |

### 2.2 建库方式的选择直接决定你能看见什么

| 建库 | 能看见 | 看不见 / 有偏 | 何时必须用 |
| :--- | :---: | :---: | :---: |
| **polyA selection（stranded）** | 成熟 mRNA 的 AS 事件 | **intron retention 被系统性低估**；pre-mRNA、非 polyA 转录本、大部分 lncRNA 丢失 | 常规 AS，预算优先 |
| **rRNA depletion（Ribo-Zero Plus 类）** | 全部上述 + **IR、pre-mRNA、非 polyA、降解样本** | 需要更高深度（rRNA 残留 + 内含子读段占掉份额） | **研究 IR、剪接因子突变、FFPE/降解样本时是必须的** |
| **Nuclear / chromatin-associated RNA-seq** | 共转录剪接动力学 | 复杂度高、需专门实验 | 机制研究 |

**【判断】关键决策点**：**如果项目涉及剪接因子突变（SF3B1/SRSF2/U2AF1/ZRSR2）或任何怀疑 IR 的表型，polyA 建库是错误选择。** 2025 的工作明确指出这三类突变**共享一个 retained intron 亚群**——而 polyA 建库正好把它洗掉。这个决定在测序之前做，做错了无法用分析补救。

### 2.3 其余实验参数

- **读长**：**PE150 是剪接分析的下限**，不要用 PE100 更不要用 SE。原因：junction read 需要在断点两侧各有足够的锚定长度（典型 aligner 要求 ≥6–8 nt，实际要 ≥20 nt 才可靠），读长越短，可用的 junction read 比例掉得越快。
- **链特异性（stranded）**：**必须**。非链特异性数据在重叠基因、反义转录本处会给出错误的 junction 归属。
- **重复数**：
  - rMATS / MAJIQ / LeafCutter 在 **n=3** 时可用，**n=5–6 才谈得上稳健**。
  - **n=1 无重复时：只能做描述性 PSI 展示，不能做差异检验。** 任何"用 SUPPA2 在 n=1 上跑差异"的做法都是错的（它的检验依赖组内 ΔPSI 分布来构建 null）。
- **UMI**：对 AS 分析**收益有限**（AS 的信号来自 junction 结构而非计数精度），除非做超低起始量或需要严格去重的定量。

---

## §3 成本模型：测序 + 分析工时的完整账

> **⚠ 全节标注为【估算】。** 以下数字基于 2026 年中北美 core facility / 服务商公开报价区间，加上我对实际项目工时的推算。**这是量级判断工具，不是报价单。** 各项假设逐条写明，读者可替换成自己的实际成本。

### 3.1 测序成本的构成假设

**短读长（Illumina NovaSeq X 25B, PE150）**

| 项 | 假设值 | 依据 |
| :--- | :---: | :--- |
| 试剂成本 | **≈ $3.2/Gb**（25B 300-cycle 整 flowcell 摊算） | 公开报价 ≈ $24,951 / 7,800 Gb **【文献】** |
| 100 M read pairs PE150 的数据量 | **30 Gb** | 100e6 × 300 bp |
| ⇒ 单样本测序试剂 | **≈ $96** | |
| 建库 polyA stranded（批量 ≥24） | **$60–90** | |
| 建库 rRNA depletion | **$110–150** | |
| QC / 上机人工分摊 | **$20–30** | |
| **⇒ 单样本合计（polyA, 100 M PE）** | **$180–220** | |
| **⇒ 单样本合计（rRNA-depl, 100 M PE）** | **$230–300** | |

**长读长（PacBio Revio + Kinnex full-length RNA）**

| 项 | 假设值 |
| :--- | :---: |
| Revio SMRT Cell | **≈ $1,800** **【文献】** |
| 单 cell FLNC 产量（Kinnex） | **≈ 12–18 M** |
| Kinnex 建库 + barcoding | **$250–400/sample** |
| 4-plex ⇒ 每样本 FLNC | ≈ 3–4.5 M（**达标**） |
| 8-plex ⇒ 每样本 FLNC | ≈ 1.5–2.2 M（**偏薄，仅够发现不够定量**） |
| **⇒ 单样本合计（4-plex）** | **$700–850** |
| **⇒ 单样本合计（8-plex）** | **$475–625** |

**长读长（ONT PromethION, cDNA-PCR barcoding, R10.4.1）**

| 项 | 假设值 |
| :--- | :---: |
| PromethION flow cell | **$800–1,000（24-pack 摊算）～ $1,930（零散购买）** **【文献】** |
| 单 flowcell pass reads（cDNA） | **50–90 M** |
| 建库 + barcode | **$100–150/sample** |
| 4-plex ⇒ 每样本 reads | ≈ 12–22 M（**达标**） |
| **⇒ 单样本合计（4-plex, 24-pack 价）** | **$300–400** |
| **⇒ 单样本合计（4-plex, 零散价）** | **$580–640** |
| direct RNA (RNA004) | 通量约为 cDNA 的 1/4–1/5 ⇒ **每样本成本 3–5×**；换来无 PCR 偏倚 + 修饰信息 |

**【判断】ONT vs PacBio 的选型不是成本问题，是错误模式问题**：ONT 便宜、通量灵活、可做 direct RNA；PacBio HiFi 准确率高、FLNC 定义干净、SQANTI3 过滤后的 novel isoform 更可信。**做 isoform 目录（要发表的注释）用 PacBio；做定量比较、或需要 direct RNA / 修饰信息用 ONT。**

### 3.2 分析工时模型（@ $60/hour）

**关键结构性事实：分析成本里有一大块是"与样本数无关的固定成本"。** 这决定了小项目里分析占比高得离谱。

| 工作项 | 性质 | 短读长 AS 项目工时 | 长读长 isoform 项目工时 |
| :--- | :---: | :---: | :---: |
| 数据核对、样本表、项目搭建 | **固定** | 1.5–2 h | 1.5–2 h |
| QC（fastp + MultiQC）与判读 | 半固定 | 1.5–2 h | 1–1.5 h |
| 比对配置与监控（STAR / minimap2） | **固定** | 1–1.5 h | 1–1.5 h |
| 主分析工具 1（rMATS-turbo / IsoQuant） | **固定** | 1–1.5 h | 2–3 h |
| 主分析工具 2（LeafCutter 或 MAJIQ） | **固定** | 2–3 h（MAJIQ 配置繁琐） | — |
| **SQANTI3 QC + rule filter 调参** | **固定** | — | **4–6 h（长读长最大人工开销）** |
| 转录本级 DTU（salmon+DRIMSeq / IsoformSwitchAnalyzeR） | **固定** | 2–2.5 h | 2.5–3 h |
| 结果整合、跨工具取交集、注释 | 半固定 | 3–4 h | 3–4 h |
| 可视化（sashimi、PSI heatmap、volcano、isoform 结构图） | 半固定 | 3–4 h | 4–5 h |
| 富集 / motif / branchpoint 分析（可选） | 可选 | 2–3 h | 2–3 h |
| **报告撰写与自审** | 半固定 | 4–6 h | 4–6 h |
| **⇒ 人工合计** | | **21–29 h** | **24–33 h** |
| **⇒ 分析成本 @ $60/h** | | **$1,260–1,740** | **$1,440–1,980** |

**计算资源成本**：本地服务器折算现金成本 ≈ $0；若上云，24 样本短读长全流程（STAR + 三个工具）约 $40–90，长读长约 $60–150。**在总账里可忽略，但在时间账里不可忽略**——STAR 比对 24 样本 @16 threads 约 5 h wall，MAJIQ build 2–4 h。

### 3.3 三个典型项目的完整成本

**【估算】** 单位 USD。

| | **场景 A**<br>24 样本短读长 AS | **场景 B**<br>8 样本长读长 isoform | **场景 C**<br>长短互补（8 长 + 24 短） |
| :--- | :---: | :---: | :---: |
| 建库方式 | rRNA-depl, 100 M PE150 | PacBio Kinnex 4-plex | 二者 |
| 测序成本 | 24 × $265 = **$6,360** | 8 × $775 = **$6,200** | **$12,560** |
| 分析工时 | 25 h | 28 h | 40 h |
| 分析成本 @ $60/h | **$1,500** | **$1,680** | **$2,400** |
| 计算成本 | ~$70 | ~$100 | ~$170 |
| **总计** | **≈ $7,930** | **≈ $7,980** | **≈ $15,130** |
| **分析占比** | **19%** | **21%** | **16%** |
| **单样本均摊** | $330 | $998 | — |

**再看小项目——这是最容易低估的情形：**

| | 6 样本短读长 AS（2组×3） | 4 样本长读长 |
| :--- | :---: | :---: |
| 测序成本 | 6 × $265 = **$1,590** | 4 × $775 = **$3,100** |
| 分析工时（固定成本几乎不减） | **19 h** | **24 h** |
| 分析成本 | **$1,140** | **$1,440** |
| **总计** | **≈ $2,730** | **≈ $4,540** |
| **分析占比** | **42%** | **32%** |

### 3.4 从成本模型能读出的三条结论

**【判断】**

1. **长读长的"贵"全部贵在试剂，不贵在分析。** 每样本测序成本是短读长的 3–4×，但分析工时**只多 15–20%**（且多出来的几乎全在 SQANTI3 过滤上）。**⇒ 当样本数少（n ≤ 8）时，长读长的总成本劣势远小于直觉。**
2. **分析工时是强固定成本 ⇒ 小项目的分析占比可达 40%+。** 6 样本项目里分析占 42%，24 样本项目里降到 19%。**⇒ 报价 / 立项时按样本数线性折算分析成本是系统性错误。**
3. **场景 C（长短互补）在每美元信息量上最优，但只有当"注释不可靠"时才值得。** 用 8 个长读长样本建**样本特异的转录本注释**，再用 24 个短读长样本在该注释上做定量——这解决了短读长最大的软肋（依赖 GENCODE 注释，而 GENCODE 对你的细胞类型可能不全）。**⇒ 非模式细胞类型、肿瘤样本、剪接因子突变体（大量 neojunction 不在注释里）时，这个组合是对的。常规模式细胞系不值得。**

---

## §4 短读长方法学：三个家族与它们的统计内核

### 4.1 比对层：STAR 仍是事实标准，但参数不是默认值

剪接分析对比对器的要求与差异表达完全不同——**你关心的是 junction 检出的灵敏度与假阳性率，而不是整体 mapping rate。**

- **STAR** 是主流选择：two-pass 模式会先收集一遍全部样本的 novel junction，再用合并后的 junction 集合重新比对。**这对剪接分析是必要的**，因为一 pass 时低覆盖 junction 会被漏掉。
  - **⚠ 陷阱**：two-pass 的 per-sample 模式（`--twopassMode Basic`）**每个样本用自己的 junction**，会引入**样本间不可比性**——A 样本发现的 junction B 样本没发现，下游 PSI 就有系统偏差。**多样本项目应该用"手工两遍"：第一遍全部样本出 `SJ.out.tab` → 合并过滤 → 第二遍用 `--sjdbFileChrStartEnd` 喂同一份 junction 集合。**
  - 关键参数：`--outSJfilterOverhangMin`、`--alignSJoverhangMin`（默认 5 太松，建议 8）、`--alignSJDBoverhangMin`（建议 3–5）、`--outFilterMismatchNoverReadLmax 0.04`。
  - **rMATS 要求提供 `--readLength` 且假设读长一致**；如果做过 trimming 导致读长不齐，需要 `--variable-read-length`。
- **HISAT2**：内存友好，适合参考基因组质量差 / 内存受限的场景，但 novel junction 灵敏度不如 STAR。
- **⚠ 别用 salmon/kallisto 的比对结果做事件级分析**——它们不产生基因组坐标的 junction。伪比对（selective alignment）只服务于转录本级坐标系。

### 4.2 家族一：事件级（Event-centric）

#### rMATS-turbo

- **统计内核**：分层模型。对每个事件，把 inclusion/exclusion read 计数建模为二项分布，用**似然比检验**比较两组的 PSI；关键在于它显式建模了**组内生物学变异**（用 logit-normal 的 variance 参数），这是它在有重复时表现稳的原因。
- **两套计数口径必须分清**：
  - **JC（junction counts only）**：只用跨 junction 的 read。
  - **JCEC（junction counts + reads on target）**：加上落在目标外显子体内的 read。
- **【判断】默认用 JC。** JCEC 引入了外显子体内的覆盖度，而覆盖度受表达量、GC、3'bias 影响，会把"表达变化"混进"剪接变化"。**只有做 RI（intron retention）时 JCEC 才是必要的**——因为 IR 的信号本来就在内含子体内。
- **输出的五个文件对应五类事件**（`SE.MATS.*`、`A5SS`、`A3SS`、`MXE`、`RI`），**不要把它们的 FDR 混在一起再校正**——rMATS 已在每类内部做了 BH 校正。
- **优势**：重复间变异处理稳健、CPU/内存开销低、可扩展到万级样本。**弱项**：RI 检测的相关性明显低于其它事件类型 **【文献】**；无法处理复杂事件。

#### SUPPA2

- **统计内核**：先从注释生成事件（ioe 文件），用转录本级 TPM（salmon/kallisto）**解析式**地算 PSI，然后**直接在 ΔPSI 上做检验**——用组内所有事件的 (ΔPSI, 平均表达) 联合分布来构建经验 null。
- **⇒ 这是它快得离谱（PSI 24 秒级）的原因，也是它的软肋**：**样本量增大时 FDR 抬头** **【文献】**，因为经验 null 的构建假设"绝大多数事件不变"，样本量大时这个假设的偏差被放大。
- **优势**：秒级、笔记本可跑、可做**时间序列聚类**（`clusterEvents`）。**弱项**：完全依赖注释；PSI 继承了转录本定量的所有偏倚。
- **【判断】用途定位**：**探索性扫描 / 大队列初筛 / 时间序列**，不作为唯一证据。

#### DEXSeq（exon bin 级）

- 把基因切成不相交的 exonic bin，用 **负二项 GLM** 检验"某个 bin 的 read 占该基因总 read 的比例"是否随条件变化——本质是**基因×bin 的交互项**。
- **优势**：统计框架成熟（DESeq2 血统）、能捕捉细微的 exon usage 变化、covariate 处理天然（GLM design matrix）。
- **弱项**：运行慢、内存高；bin 不等于生物学事件，解读需要人工；对 junction 信息利用不足。
- **【判断】** 在需要**复杂实验设计（批次、配对、连续协变量）**时，DEXSeq / DRIMSeq 的 GLM 框架是唯一干净的选择——rMATS 与 LeafCutter 处理协变量都很别扭。

### 4.3 家族二：intron/junction-centric（无需完整注释）

#### LeafCutter

- **核心思想**：完全绕开"事件类型"和"转录本重建"。直接从比对中提取 **split reads** → 按共享 splice site 聚成 **intron cluster** → 检验 cluster 内各 intron 的**相对使用比例**是否随条件变化（Dirichlet-multinomial GLM）。
- **优势**：
  - **不需要注释**——能发现 GENCODE 里没有的 junction，这对肿瘤 / neojunction / 非模式系统是决定性的；
  - **p 值校准好** **【文献】**；
  - **快**（小时级），可扩展到 GTEx 规模，是 **sQTL（splicing quantitative trait locus）** 分析的标准输入格式；
  - 天然处理复杂事件（cluster 内可有任意多个 intron）。
- **弱项**：
  - **对 intron retention 基本无能**（IR 没有 split read）；
  - cluster 的生物学解读需要人工——输出是 "cluster clu_1234 里 intron chr1:100-200 的使用比例降了 0.15"，**不是"外显子 5 被跳过"**；
  - **cluster ID 不稳定**（见 §1.1）。
- **【判断】** LeafCutter 是**最适合做"第二把尺子"的工具**：它与 rMATS 的坐标系正交，重叠部分是高置信信号。

#### MAJIQ / MAJIQ v2

- **核心概念 LSV（local splicing variation）**：以一个 splice site 为中心的所有出边/入边组成一个"局部剪接变化"单元。这比 5 类事件更一般，比整条转录本更局部。
- **独有能力**：**是主流工具里唯一做未注释 intron retention 检测与定量的** **【文献】**。
- **性能**：报告 FDR ≈ 0.3%，RT-qPCR 验证相关性 ≈ 0.97–0.98 **【文献】**。
- **弱项**：**配置繁琐**（需要写 `.ini` build config）、运行时间数小时级、输出（VOILA）学习曲线陡。MOCCASIN 模块用于校正混杂因素。
- **【判断】** 当项目**以剪接为核心科学问题**（而非顺带做的一个分析）时，MAJIQ 值得那 2–3 小时的配置成本。当剪接只是 RNA-seq 项目里的一个附加模块时，rMATS + LeafCutter 的性价比更高。

#### MntJULiP

- 较新的 intron-centric 方法，同时建模 **intron 丰度差异（DSA）** 和 **intron 使用比例差异（DSR）**——这个区分很有用：一个 intron 的绝对使用量下降，可能是因为整个基因表达下降（DSA），也可能是因为剪接偏好改变（DSR）。**多数工具把这两件事混在一起。**
- 速度极快（分钟级，与 LeafCutter 同档）**【文献】**。

#### Whippet

- 基于**剪接图（splice graph）的伪比对**，直接从 FASTQ 出发，笔记本可跑。
- **弱项**：内部的伪比对步骤不可跳过（即使你已有 BAM），且**只能用已注释的 splice site** **【文献】**——这抵消了 intron-centric 家族的主要卖点。**【判断】** 使用价值在 2026 已明显下降。

### 4.4 家族三：转录本级（DTU, differential transcript usage）

**标准组合：salmon/kallisto 定量 → tximport → DRIMSeq 或 DEXSeq → stageR 两阶段校正。**

- **为什么要 stageR**：DTU 有两层问题——"**哪些基因**发生了 isoform usage 改变"（screening）和"**基因内哪条 isoform**"（confirmation）。直接对所有 transcript 做 BH 校正是错的（检验之间强相关）。**stageR 的两阶段过程是这个场景的正确做法，不是可选的精致化。**
- **IsoformSwitchAnalyzeR**：把 DTU 检验与**功能后果注释**整合在一起——预测 ORF（open reading frame）、调用 CPAT/CPC2（编码潜能）、Pfam（结构域得失）、SignalP、IUPred2A（无序区），并判断 isoform switch 是否引入 **PTC（premature termination codon）→ NMD 靶向**。
  - **【判断】这是短读长剪接分析里最被低估的工具。** 它回答的是审稿人和客户真正关心的问题：**"这个剪接变化改变了蛋白吗？"** rMATS 的 ΔPSI 表格回答不了这个。
- **⚠ 短读长 DTU 的根本局限**：isoform 丰度是**统计推断出来的**，不是观测到的。当两条 isoform 只差一个小外显子、或差别在长基因的一端时，EM 解卷积的不确定性极大。**salmon 的 bootstrap / Gibbs 样本（`--numBootstraps 100`）应该开，并把推断不确定性传到下游**（swish / sleuth 的思路），否则 DTU 的 p 值是虚高的。

### 4.5 短读长假阳性的六大来源（清单）

**【判断】** 以下每一条我都在实际项目里见过：

1. **低覆盖 junction** —— 见 §1.2。**必须联合 read 数阈值过滤。**
2. **3' bias / RNA 降解（低 RIN）** —— 降解样本的覆盖度沿转录本不均，直接污染 exon-body 计数（JCEC 口径首当其冲）。**必须先看 RNA 完整性与基因体覆盖曲线（RSeQC `geneBody_coverage`）。若无 RIN 数据，必须在报告里写明未测，不能默认合格。**
3. **pre-mRNA 污染被误判为 intron retention** —— 尤其在核内 RNA 比例高的样本（神经元、肿瘤）。**判据：真 IR 的内含子覆盖是均匀的且有明确的 exon-intron 边界读段；pre-mRNA 污染是全基因组所有内含子的普遍性抬升。看全局 intronic rate，不要单看一个基因。**
4. **multi-mapping 与旁系同源** —— 基因家族（如 HLA、免疫球蛋白、锌指）的 junction 归属不可靠。
5. **批次效应** —— 剪接对文库制备批次**比表达更敏感**（片段化程度直接影响 junction read 比例）。**rMATS 和 LeafCutter 都不方便加协变量 ⇒ 有批次时优先 DEXSeq/DRIMSeq 的 GLM，或 MAJIQ + MOCCASIN。**
6. **注释版本不一致** —— 比对用 GENCODE v44、rMATS 用 v39，会静默产生大量假事件。**同一项目内注释版本必须锁死并写进报告 Methods。**

---

## §5 长读长方法学

### 5.1 为什么长读长改变了问题的性质

短读长做剪接，本质上是**从局部证据推断全局结构**：你看到外显子 2-3 相连，也看到外显子 5-6 相连，但**不知道它们是否在同一条分子上**。这个"搭配问题（phasing）"在短读长下**原理上无解**，只能靠统计假设填补。

长读长直接观测整条分子 ⇒ **搭配关系是观测量而非推断量**。这是质变，不是量变。**⇒ 当科学问题涉及"组合"时（例如：跳过外显子 3 的转录本是否同时使用了远端的替代 3'UTR？某个 neojunction 出现在哪条 isoform 背景上？），长读长是唯一正确的工具。**

### 5.2 流程骨架

```
FASTQ (PacBio HiFi / ONT)
  │
  ├─ [PacBio] skera (Kinnex 去 concatenation) → lima (去 primer/barcode) → isoseq refine (去 polyA) → FLNC reads
  ├─ [ONT]   dorado basecall → pychopper (定向/去 adapter) → 可选 UMI 处理
  │
  ▼
minimap2 -ax splice:hq (PacBio) / -ax splice (ONT)   ← splice-aware 比对，必须加 -uf --secondary=no（依情况）
  │
  ▼
isoform 发现 + 定量：IsoQuant / bambu / StringTie2(-L) / FLAIR / ESPRESSO
  │
  ▼
SQANTI3  ← 结构分类（FSM/ISM/NIC/NNC）+ artifact 标记 + rule-based filter   【不可跳过】
  │
  ▼
差异分析：DTU（DRIMSeq/DEXSeq on isoform counts） / rMATS-long / 自定义 junction 级检验
```

### 5.3 工具选择——LRGASP 的结论直接可用

**【文献】** LRGASP（Nature Methods 2024）与后续 benchmark 的一致结论：

| 场景 | 推荐 | 理由 |
| :--- | :---: | :--- |
| **有注释引导，要精度（少假阳性）** | **IsoQuant 或 bambu** | 二者精度（precision）最高 |
| **有注释引导，要灵敏度（不漏新 isoform）** | **IsoQuant 或 StringTie2** | 二者 sensitivity 最高 |
| **已知转录本的定量** | **IsoQuant** | F1 最高（对比 TALON/FLAIR/bambu/StringTie） |
| **需要 R 生态、需要跨样本一致的 count matrix** | **bambu** | 输出直接是 SummarizedExperiment；context-aware 定量 |
| **de novo（无注释）** | **无可靠推荐** | 所有工具在此模式下假 isoform 大量涌现 **⇒ 非模式物种做长读长转录组，必须接受注释质量是瓶颈** |

**【判断】** IsoQuant 在 LRGASP 中同时占据精度和灵敏度前列，**如果只跑一个工具，跑 IsoQuant**。若项目要进 R/Bioconductor 下游，bambu 的工程体验更好。

### 5.4 SQANTI3：长读长的 QC 层（最大的人工开销，也是最不能省的）

长读长的 novel isoform 里，**技术假象的比例可以超过真实新 isoform**。SQANTI3 的价值在于把它们分门别类地标出来：

| 结构分类 | 含义 | 处理 |
| :--- | :---: | :---: |
| **FSM**（Full Splice Match） | 剪接结构与已知转录本完全一致 | 最可信 |
| **ISM**（Incomplete Splice Match） | 是某条已知转录本的子集 | **高度可疑**——大多是 5' 降解或 RT 未跑完的截断产物 |
| **NIC**（Novel In Catalog） | 新组合，但用的都是已知 splice site | **最有价值的一类**——真正的新剪接搭配 |
| **NNC**（Novel Not in Catalog） | 使用了未注释的 splice site | 需要更强证据（短读长 junction 支持、CAGE、polyA site） |

**必须过滤掉的技术假象**：
- **RT-switching**：逆转录酶模板跳转产生的假 junction。SQANTI3 用断点两侧的直接重复序列特征识别。
- **intra-priming**：oligo-dT 在基因组编码的 poly-A 富集区内部引发 ⇒ 假的 3' 末端。判据：3' 末端下游 20 nt 内 A 含量异常高。
- **非典型 junction motif**：非 GT-AG / GC-AG / AT-AC 的 junction 绝大多数是错误。
- **单一 read 支持的 isoform**：一律不信。

**【判断】** SQANTI3 的 rule filter 需要按项目调参（默认规则偏保守/偏松取决于数据），这是长读长项目里 4–6 小时人工的来源，**这个时间省不掉**。省掉它的直接后果是：报告里出现的"新发现 isoform"里有一半是酶学假象。

### 5.5 长读长的真实门槛：分子数不是 read 数

**【判断】这是长读长项目最常见的期望管理失败点。**

- 一条长读长 read ≈ 一个 cDNA 分子。**3 M FLNC read 意味着你只抽样了 300 万个分子。**
- 对一个表达量中等（比如 TPM = 20）的基因，3 M reads 里大约只有 **60 条** read 落在它上面。若它有 5 条 isoform，**平均每条 12 条 read**——这个精度做不了 ΔPSI = 0.1 的差异检验。
- **⇒ 长读长擅长"发现"与"结构描述"，在当前成本下做"精细定量比较"仍然吃力。** 这正是 §3.4 第 3 条（长短互补）的动机：**长读长定义"有哪些 isoform"，短读长回答"各有多少"。**

### 5.6 direct RNA sequencing（ONT RNA004）

- 唯一能在**原生 RNA 分子**上直接观测的路线 ⇒ 无 PCR 偏倚，且**同时读出 m6A / pseudouridine 等修饰与 poly(A) 尾长**。
- **代价**：通量低（约为 cDNA 的 1/4–1/5）、错误率更高、5' 端截断更严重。
- **【判断】** 2026 年 direct RNA 的定位是**机制研究工具**（剪接与修饰的耦合、共转录剪接），**不是常规 isoform 定量工具**。若项目目标只是 isoform 定量，用 cDNA。

---

## §6 单细胞与空间剪接

### 6.1 先说不能做什么

**10x Genomics 3' 方案在原理上不能做绝大多数 AS 分析。** 它只测转录本 3' 端 100–200 nt。**这不是算法问题，是数据里根本没有那个信息。** 任何声称"用 10x 3' 数据做了全转录组可变剪接分析"的工作，实际做的要么是 3'UTR 上的少数事件（含 APA，alternative polyadenylation），要么是错的。

- 5' 方案同理（只是换了一端）。
- **能做 AS 的单细胞数据只有两类**：**Smart-seq2/3（全长、板式、通量低、成本高）** 与 **单细胞长读长**。

### 6.2 短读长全长（Smart-seq）单细胞剪接工具

2026 年有了对六个主流方法的系统评测 **【文献】**：**BRIE2、scQuint、Psix、SpliZ、MARVEL、SCASL**。

| 工具 | 路线 | 特点 |
| :--- | :---: | :--- |
| **BRIE2** | 贝叶斯，需注释 | 在低覆盖下用先验稳定 PSI 估计；**只处理 SE（skipped exon）事件** |
| **MARVEL** | 需注释，平台化 | R 包，整合了事件检测、PSI 计算、降维、差异检验、通路；**功能最全** |
| **Psix** | 需注释 | 识别**与细胞状态相关**的剪接事件及其共调控模块 |
| **scQuint** | intron-centric | 明确指出并处理**覆盖度依赖的偏倚**（"单细胞剪接是二元的"这一假象的来源） |
| **SpliZ** | 统计量导向 | 定义了单细胞剪接的 z 统计量，适合跨细胞类型比较 |
| **SCASL** | 插补路线 | 针对 dropout 做剪接位点层面的插补 |
| **scASfind** | 索引/挖掘 | 不做差异检验，做**高效模式检索**——"哪些细胞群用了这个 junction" |

**【判断】核心统计难题**：单细胞的 PSI 分母极小（常常个位数 read），**§1.2 的方差问题在这里是主导项而非次要项**。任何单细胞剪接结论都必须先回答："这个差异是剪接变了，还是覆盖度变了？" 实践上：**把细胞按类型 pseudobulk 之后做剪接分析，比在单细胞层面做，结论稳健得多**——除非科学问题本身就是"细胞间剪接异质性"。

### 6.3 单细胞 / 空间长读长

这是 2025–2026 增长最快的方向。核心工程难题**不是剪接分析本身**，而是：
1. **在高错误率下恢复 cell barcode 与 UMI**（16 nt barcode + 10–12 nt UMI，ONT 原始错误率下直接匹配会大量失败）；
2. **read truncation** 导致 isoform 归属错误；
3. **UMI 去重** 时把同一分子的多条 read 正确合并。

代表工具：**FLAMES**、**scNanoGPS**、**Longcell**（Nat Commun 2025，含空间 barcode 支持）、**SCOTCH**（Nat Commun 2026）、**miniQuant**（显式量化 isoform 归属的不确定性）。**【文献】**

**【判断】** 这条路线在 2026 已经可用，但**成本与人工都显著高于 bulk**，且**每样本细胞数受长读长通量限制**（典型只能覆盖数百到数千个细胞的 isoform 级信息）。除非科学问题**必须**要"细胞类型 × isoform"的交叉分辨率，否则 **bulk 长读长 + 细胞类型分选** 是更划算的替代方案。

---

## §7 变异 → 剪接效应预测

这是与 WGS/WES 直接接口的一节。问题形式：**给一个 DNA 变异，它会不会破坏剪接？破坏成什么样？**

### 7.1 主流预测器与它们各自回答的问题

| 工具 | 回答的问题 | 输出 | 关键性质 |
| :--- | :---: | :---: | :--- |
| **SpliceAI** | 这个位置**会不会**成为/失去 splice site | 4 个分数：DL/DG/AL/AG（acceptor/donor loss/gain） | 事实标准；10 kb 上下文的深度 CNN |
| **Pangolin** | 同上（多物种、多组织训练） | 剪接使用率变化 | **与 SpliceAI 的预测相关性 r = 0.97 【文献】** |
| **SpliceVault** | splice site 坏了以后**实际会发生什么** | Top-4 经验性替代事件（cryptic site / exon skipping）及其在 ~30 万公共 RNA-seq 中的出现频率 | **经验目录，不是打分模型 ⇒ 与 SpliceAI 正交** |
| **AbSplice** | 在**特定组织**里会不会异常剪接 | 组织特异性剪接异常概率 | 整合 SpliceAI + MMSplice + 组织特异 splice site 使用 |
| **MMSplice / MTSplice** | 模块化：分别建模 donor/acceptor/exon/intron 的贡献 | ΔlogitPSI | 可解释性较好 |
| **SQUIRLS** | 临床可解释的剪接变异评分 | 分数 + 可视化 | 面向诊断报告 |

### 7.2 三条必须知道的实践结论

**【文献 + 判断】**

1. **SpliceAI 与 Pangolin 不构成互相验证。** r = 0.97 意味着它们几乎总是同意；两者都说"是"并不提高置信度。**若要正交证据，去找 SpliceVault（经验频率）或直接做 RNA 验证。**
2. **外显子内部（exonic）变异是明确盲区。** MPSA benchmark 用 5 个基因 3,616 个变异实测：SpliceAI/Pangolin 整体最好，但**在外显子内部的表现明显下降**。原因很直观——ESE/ESS 这类顺式元件的作用是**上下文依赖的、定量的**，不是"是否存在 splice site"的二元判断。**⇒ 一个 missense 变异 SpliceAI 分数低，不能得出"不影响剪接"的结论。**
3. **阈值不是普适的。** SpliceAI 的常用阈值：0.2（高灵敏，筛查用）/ 0.5（平衡）/ 0.8（高特异，报告用）。**这些阈值的 PPV 随基因、随外显子位置、随人群频率变化**。在临床报告里必须写明用了哪个阈值以及为什么。

### 7.3 与 WGS 项目的接口：怎么找 splice-disrupting variant

一条实际可用的流程：

```
VCF (WGS/WES)
  │
  ├─ 1. 区域过滤：保留 exon ±50 nt 的变异（深内含子变异需单独处理，见下）
  ├─ 2. SpliceAI 打分（`spliceai -D 500`，distance 参数决定报告范围）
  ├─ 3. 阈值筛选（筛查用 0.2，报告用 ≥0.5）
  ├─ 4. 对通过的变异查 SpliceVault：预测的失效 site 在真实数据里最常见的替代事件是什么
  ├─ 5. 后果推断：替代事件是否导致 frameshift → PTC → NMD？还是 in-frame 缺失？
  ├─ 6. 【关键】RNA 层验证：RT-PCR / 靶向 RNA-seq / 患者样本 bulk RNA-seq
  └─ 7. ACMG 分类（PVS1 决策树对剪接变异有专门分支）
```

**⚠ 深内含子变异（deep intronic）**：SpliceAI 能预测**新生 splice site 的产生**（导致 pseudoexon 插入），这是它相对早期工具的重要进步。**但默认只在 exon 附近跑打分会完全错过这类变异。** 若项目目标包括寻找"未解诊断病例的隐藏致病变异"，**必须对全基因（含全部内含子）打分**，代价是计算量和假阳性率都上升。

**【判断】** 在我们做的 WGS 项目里，剪接变异筛查最容易出错的地方是**只报告了预测分数，没有做后果推断（第 5 步）**。分数是中间量，不是结论。客户/审稿人要的是"这个变异导致外显子 7 跳过 → frameshift → PTC → NMD → 蛋白缺失"，不是"SpliceAI DL = 0.87"。

### 7.4 什么时候该直接做 RNA-seq 而不是预测

**【判断】** 当满足以下任一条时，预测的价值低于直接测：
- 变异在外显子内部（盲区，见 7.2.2）；
- 变异位于组织特异表达的基因，而你有那个组织的样本；
- 已有多个候选变异需要排序（RNA-seq 一次性给出所有变异的实际后果）；
- 需要作为临床/发表证据（预测分数在证据等级中低于功能验证）。
- **成本参照（§3）**：一个样本的 rRNA-depletion RNA-seq 约 $265，加分析摊薄后不到 $500。**相对于一次 RT-PCR 验证加上反复的解读争论，这个价格通常是划算的。**

---

## §8 剪接因子突变与疾病：一个高价值的应用场景

### 8.1 三个热点突变的分析指纹

**【文献】** 这三类突变在 MDS / AML / CLL / 葡萄膜黑色素瘤等中高频出现，且**各自有明确、可检验的分子指纹**：

| 突变 | 典型热点 | 分子后果 | **分析上该找什么** |
| :--- | :---: | :--- | :--- |
| **SF3B1** | K700E, K666N, H662Q, R625 | 使用**新生/隐性 3' splice site**，典型位于规范 3'SS **上游约 10–30 nt** | 在 A3SS 事件中富集；**必须用能检出未注释 junction 的工具（LeafCutter / MAJIQ），rMATS 基于注释会漏掉大部分** |
| **SRSF2** | P95H / P95L / P95R | ESE 结合偏好从 **GGNG → CCNG**，改变外显子包含 | SE 事件为主；**做 motif 富集分析**：比较 included vs excluded 外显子的 ESE motif 组成，应观察到 CCNG/GGNG 的方向性差异 |
| **U2AF1** | S34F, S34Y, Q157R, Q157P | 偏好**非共识 3' splice site**；S34 与 Q157 突变的偏好方向**相反**（分别影响 3'SS 的 −3 与 +1 位） | A3SS + SE；**必须按具体氨基酸位置分层，不能把 U2AF1 突变当作一类** |
| **ZRSR2** | 各种失活突变 | **U12 型（minor spliceosome）内含子滞留** | **专门检查 minor intron（U12-type）的 IR**——常规 pipeline 不会单独看这一小类内含子（人类约 700–800 个） |

### 8.2 共享机制与共享事件

**【文献，2025 预印本，需谨慎对待】** 尽管上述指纹各异，2025 年的工作提出这三类突变**共享一个 retained intron 亚群**，机制指向 SR 蛋白（SRSF1 等）RS 结构域的**低磷酸化** ⇒ 功能下降。

**分析含义**：
- **必须用 rRNA-depletion 建库**（见 §2.2）——polyA 建库把 IR 信号系统性洗掉；
- **IR 分析要用专门工具**：**IRFinder-S**（灵敏度高）或 **iREAD**（精度高，报告精度 0.99 但召回仅 0.08–0.11 **【文献】**）；**⇒ 两者的错误模式相反，取交集会太严，建议 IRFinder-S 主跑 + iREAD 作为高置信子集。**
- MAJIQ 是唯一能顺带做未注释 IR 的通用工具。

### 8.3 Neojunction 与 AS-derived neoantigen

**【文献】** 剪接异常产生的新 junction 可以编码正常蛋白组里不存在的肽段 ⇒ 肿瘤特异 neoantigen 来源，用于 mRNA 疫苗与过继细胞治疗。

分析路径：
```
RNA-seq → 无注释依赖的 junction 检出（LeafCutter / MAJIQ / 直接从 STAR SJ.out.tab）
  → 过滤掉在正常组织（GTEx）中出现的 junction   ← 【关键步骤，决定特异性】
  → 翻译成肽段（考虑 frame、PTC/NMD）
  → HLA 结合预测（NetMHCpan 类）
  → 免疫原性排序
```

**【判断】两个最容易出错的地方**：
1. **"正常组织过滤"做得不够狠**。任何在 GTEx 里以低频出现的 junction 都不是真正肿瘤特异的。**必须用大规模正常组织 junction 目录（GTEx / SpliceVault 类资源）做频率过滤，而不是只跟配对正常样本比**——配对正常样本的深度不足以证明"不存在"。
2. **忽略 NMD**。产生 PTC 的 neojunction 转录本会被 NMD 降解 ⇒ **蛋白层可能根本不表达**。RNA 层的高丰度不代表肽段能被呈递。**⇒ 必须做 NMD 预测（PTC 是否在最后一个 exon-exon junction 上游 >50 nt），并在报告中说明这一层不确定性。**

### 8.4 治疗方向（简述）

- **剪接调节小分子**：SF3B1 靶向化合物（pladienolide 衍生物类）——机制上恰好利用了 SF3B1 突变细胞对剪接体抑制的敏感性差异。
- **反义寡核苷酸（ASO）**：nusinersen（SMA，促进 SMN2 外显子 7 包含）是最成功的先例；eteplirsen 类（DMD 外显子跳跃）。**生信角色**：ASO 靶点设计需要精确的 ESE/ESS 图谱与 walk 实验的定量读出。
- **【判断】** 对我们的项目而言，最现实的接口是**给药后的 RNA-seq 读出**：验证目标事件的 ΔPSI 是否达到预期，以及**脱靶剪接改变的全局扫描**——后者常被忽略，但是安全性评估的核心。

---

## §9 常被漏掉的事件类型

| 类型 | 为什么常被漏 | 该用什么 |
| :--- | :---: | :---: |
| **Intron retention (IR)** | polyA 建库洗掉；LeafCutter 原理上看不到；rMATS 的 RI 相关性偏低 **【文献】** | rRNA-depl 建库 + **IRFinder-S / iREAD / MAJIQ** |
| **微外显子（microexon, 3–27 nt）** | 太短，短读长比对时锚定长度不足，被 aligner 直接丢弃 | 专门流程（需调 `--alignSJoverhangMin` 等）；**长读长更可靠**；神经系统研究中尤其重要 |
| **Back-splicing / circRNA** | 常规 pipeline 只找线性 junction，back-spliced junction 被当成噪声丢弃 | CIRCexplorer / CIRI2 / DCC；**必须用 rRNA-depl + RNase R 处理** |
| **可变多聚腺苷酸化（APA）** | 严格说不是剪接，但常与 AS 混为一谈 | DaPars / QAPA / **10x 3' 数据唯一能做的"isoform 级"分析** |
| **U12 型（minor）内含子** | 数量少（~700–800），常规富集分析淹没 | 单独提取 minor intron 列表做靶向分析（ZRSR2 突变时必做） |
| **NMD 耦合的剪接** | 事件级工具不看编码后果 | **IsoformSwitchAnalyzeR** 的 PTC/NMD 判定；长读长直接观测 |

---

## §10 选型：基准测试的共识与决策树

### 10.1 benchmark 的元结论

**【文献 + 判断】** 读完这几年的 benchmark，最该记住的不是排名，而是：

1. **排名随评估口径反转。** 事件级评估中 SUPPA 领先、LeafCutter/DARTS/rMATS 次之；但在**复杂事件**上 MAJIQ 与 LeafCutter 呈相反趋势并占优。**⇒ "哪个工具最好"这个问题本身没有唯一答案。**
2. **模拟数据与真实数据的结论不一致。** 模拟数据按某个生成模型造，天然偏袒假设匹配的工具。**⇒ 优先看有 RT-qPCR 或 MPSA 实测验证的 benchmark。**
3. **工具间重叠低是常态，不是 bug。** 不同坐标系（§1）本来就在描述不同的东西。**⇒ 低重叠不代表某个工具错了，但确实意味着单工具结果的可信度低于直觉。**

### 10.2 决策树

```
Q1: 科学问题涉及"isoform 组合/搭配"吗？（如 neojunction 在哪条 isoform 上）
    是 → 长读长（IsoQuant，+ SQANTI3）。样本多则考虑长短互补（§3.4）
    否 → 继续

Q2: 需要检出未注释的 junction 吗？（肿瘤 / 剪接因子突变 / 非模式系统）
    是 → LeafCutter 或 MAJIQ 为主；rMATS 只作补充
    否 → 继续

Q3: 主要关心 intron retention 吗？
    是 → rRNA-depl 建库 + IRFinder-S（主）/ iREAD（高置信子集）/ MAJIQ
    否 → 继续

Q4: 实验设计复杂吗？（批次、配对、连续协变量）
    是 → DEXSeq / DRIMSeq 的 GLM 框架；或 MAJIQ + MOCCASIN
    否 → 继续

Q5: 需要回答"蛋白层后果是什么"吗？
    是 → salmon → DRIMSeq/stageR → IsoformSwitchAnalyzeR（ORF/domain/NMD）
    否 → 继续

Q6: 只是大队列快速初筛 / 时间序列？
    是 → SUPPA2
    否 → 默认组合：rMATS-turbo + LeafCutter（两个坐标系互证）
```

### 10.3 "两把尺子"策略（本文的核心操作建议）

**【判断】** 我推荐的默认配置：

| 角色 | 工具 | 作用 |
| :--- | :---: | :--- |
| **主尺**（可解释性） | **rMATS-turbo（JC 口径）** | 给出五类事件的 ΔPSI，生物学命名清晰，直接进报告 |
| **副尺**（正交验证） | **LeafCutter** | 不依赖注释、坐标系正交；用它来**验证主尺的发现，并捕捉主尺看不见的复杂/新事件** |
| **后果层** | **IsoformSwitchAnalyzeR** | 回答"改变了蛋白吗" |
| **（可选）深挖层** | **MAJIQ** | 剪接是核心问题时加上；唯一能顺带做未注释 IR |

**怎么"互证"**：把两者的结果**映射到共同的 junction 坐标**（chr:start-end:strand）再比，而不是比事件名或 cluster ID。**报告里应给出：主尺检出数、副尺检出数、junction 级重叠数、以及"仅被副尺检出"的那部分中值得关注的复杂事件。**

**⚠ 不要做的事**：不要为了让数字好看，把两个工具的结果**取并集**当作"共发现 N 个事件"。并集混合了两种不同的假阳性率，且两个坐标系的事件不是同一计数单位。**取交集作为高置信集、分别报告各自总数**，才是诚实的呈现。

---

## §11 Pitfalls 速查表

**【判断】** 按"造成的损害"排序：

| # | 陷阱 | 后果 | 怎么防 |
| :---: | :--- | :---: | :--- |
| 1 | **polyA 建库做 IR / 剪接因子突变研究** | **不可补救**，信号在实验阶段就被洗掉 | 测序前决定：涉及 IR ⇒ rRNA-depletion |
| 2 | **深度不足（<60 M PE）做 AS** | 低表达基因事件全被过滤，结论偏向高表达基因 | 按 §2.1 定深度；已测浅的数据要在报告里写明检出偏倚 |
| 3 | **只按 \|ΔPSI\| 排序，不看 read 支持数** | 榜首全是低表达噪声 | ΔPSI 阈值 **必须**与 read 数阈值联用 |
| 4 | **STAR two-pass 用 per-sample 模式** | 样本间不可比，PSI 系统偏差 | 手工两遍：合并全部样本的 SJ 后统一重比对 |
| 5 | **注释版本在流程内不一致** | 静默产生大量假事件 | 锁死版本并写进 Methods |
| 6 | **把 pre-mRNA 污染当 intron retention** | 结论完全错误 | 看全局 intronic rate，不看单基因 |
| 7 | **n=1 跑差异剪接** | p 值无意义 | n=1 只出描述性 PSI |
| 8 | **长读长跳过 SQANTI3** | "新 isoform" 里混大量 RT-switching / 截断假象 | SQANTI3 分类 + rule filter，人工调参 |
| 9 | **把 SpliceAI 分数当结论写进报告** | 客户/审稿人拿不到可行动信息 | 必须做后果推断（跳过→frameshift→PTC→NMD） |
| 10 | **同时跑 SpliceAI + Pangolin 当作"两个工具验证"** | 虚假的置信度（r=0.97） | 要正交证据去找 SpliceVault 或 RNA 验证 |
| 11 | **neoantigen 分析的正常组织过滤只用配对正常样本** | 假的"肿瘤特异" | 用 GTEx 级别的大规模 junction 频率目录 |
| 12 | **跨项目复用 LeafCutter cluster ID** | 指向错误的事件 | cluster ID 只在单次分析内有效 |
| 13 | **rMATS 五类事件的 FDR 混在一起再校正** | 双重校正，过度保守 | 各类内部已 BH 校正，不要再合并校正 |
| 14 | **10x 3' 数据做"可变剪接分析"** | 数据里没有那个信息 | 只能做 APA / 3'UTR 事件；要 AS 用全长或长读长 |
| 15 | **忽略 RNA 完整性（RIN）** | 3' bias 污染 exon-body 计数 | 先看基因体覆盖曲线；**若无 RIN 数据必须在报告写明"未测"，不得默认合格** |

---

## §12 一条可执行的参考流程（bulk 短读长，28 核 / 56 线程预算）

```bash
# ── 环境：conda run -n regular_bioinfo <cmd>；长任务一律进 tmux ──

# 0) QC + trim              fastp -w 8      （8 线程 × 并行 3 样本 = 24）
# 1) STAR pass-1            --runThreadN 24 （逐样本串行，出 SJ.out.tab）
# 2) 合并过滤 SJ            保留：非 chrM、唯一比对支持 ≥3、非注释 junction 需 ≥5
# 3) STAR pass-2            --runThreadN 24 --sjdbFileChrStartEnd merged_SJ.tab
#                           --quantMode GeneCounts  --outSAMtype BAM SortedByCoordinate
# 4) samtools index         -@ 8
# 5) QC 判读                MultiQC + RSeQC geneBody_coverage  ← 【必看，见 pitfall #15】
#
# ── 主尺 ──
# 6) rMATS-turbo            --nthread 24 --readLength 150 --variable-read-length
#                           --od rmats_out --tmp rmats_tmp  （两组 BAM 列表）
#                           取 JC 口径；过滤 FDR<0.05 & |ΔPSI|≥0.1 & 每样本 IJC+SJC≥10
#
# ── 副尺 ──
# 7) LeafCutter             regtools junctions extract -a 8 -m 50 -M 500000
#                           leafcutter_cluster_regtools.py → differential splicing (R)
#                           过滤 p.adjust<0.05 & |ΔPSI|≥0.1
#
# ── 后果层 ──
# 8) salmon                 -p 16 --validateMappings --numBootstraps 100 --gcBias --seqBias
# 9) IsoformSwitchAnalyzeR  DTU + ORF + Pfam + CPAT + NMD 判定
#
# ── 整合 ──
# 10) 映射到共同 junction 坐标 → 交集/差集统计
# 11) 可视化：ggsashimi（代表事件）、PSI heatmap、ΔPSI volcano、isoform 结构图
# 12) 报告：Methods 必须写明 —— 注释版本、比对器与关键参数、每个工具的阈值、
#           计数口径（JC vs JCEC）、深度与 RIN 情况、两把尺子的重叠统计
```

**线程预算核对**：任一时刻峰值 ≤ 24（STAR）或 8×3=24（fastp）或 16（salmon），**均在 28 核 / 56 线程的持续上限内**，留出余量给 OS 与交互。

---

## §12.1 实现与实证：本文 §12 流程的落地项目（P34）

**双向引用。** 本文 §12 的参考流程由内部方法学项目 **P34** 具体实现并实证检验：

| 项 | 内容 |
| :--- | :---: |
| 项目 | `/home/gao/projects_2026M7/34_exon_splicing_pipeline_dev` |
| 计划文档 | [`docs/P34_research_plan_and_review_0908.md`](/home/gao/projects_2026M7/34_exon_splicing_pipeline_dev/docs/P34_research_plan_and_review_0908.md) |
| 起始日期 | 2026-09-08 |
| 性质 | 内部方法学研究，不对外交付 |

**P34 相对本文的角色分工：**

- **本文 → P34**：提供选型判据（§10.2 决策树、§10.3 两把尺子）、参数取值（§4.1、§12）、
  以及 §11 的 15 条 pitfalls。P34 计划文档 §5 有一张**逐条落实对照表**，说明每条 pitfall
  在该项目里怎么处置、哪些不适用。
- **P34 → 本文**：本文中标 **【判断】** 而缺本机实测支撑的条目，由 P34 产出实测数回填 ——
  具体为**工具间 junction 级重叠率**（对应 §10.1 元结论 3）、**各工具在同一数据上的假阳性本底**
  （交换样本角色的反向对照）、以及**对 ENCODE 官方 rMATS 真值的召回率**。

**P34 的数据配置（供判读其实测数的适用范围）：**

| 数据集 | 用途 | 配置 | 相对本文推荐值的差距 |
| :--- | :---: | :---: | :--- |
| proj19（Lijian Wu, 小鼠 Rell1×TNFa×Tumor） | 开发/跑通 | 8 组 × n=3，中位 66 M pairs，PE150 stranded | 深度仅达 §2.1 的**绝对下限 60 M**，未及推荐区间 80–120 M；且现有 BAM 为 `--twopassMode None`、SJ overhang 阈值偏松，**Phase 1 结果不作科学结论** |
| ENCODE HNRNPC / SRSF1 shRNA KD（K562） | 真值基准 | 各 2 bioreps，PE100 | **PE100 低于 §2.3 的 PE150 下限**，n=2 低于 §2.3 的 n=3 可用线 ⇒ 所测召回率只作管线自身相对刻度，**不可外推到 PE150 / n≥3 的项目** |

**P34 回填的三组实测数（2026-09-09，本机实测，可据以校准本文的【判断】条目）：**

**① 对 ENCODE 官方 rMATS 真值的召回率**（基因级；我们 GRCh38/v45 + 手工两遍 STAR + rMATS 4.4.0
vs ENCODE hg19/V19 + 其自有管线 + rMATS 3.x；两侧同一套阈值 FDR<0.05 & |ΔPSI|≥0.1 & 每样本 IJC+SJC≥10）：

| 靶点 | 我们显著基因 | 真值显著基因 | 交集 | 召回率 |
| :--- | :---: | :---: | :---: | :---: |
| HNRNPC 敲低（K562, n=2） | 2,642 | 1,552 | 1,297 | **83.6%** |
| SRSF1 敲低（K562, n=2） | 2,714 | 1,478 | 1,240 | **83.9%** |

逐事件型召回率的高低顺序在两个独立基准上一致：**SE ~84% > RI ~75% > A3SS/A5SS ~60% > MXE ~57%**。
⚠ 基准数据是 **PE100 且 n=2**，均低于本文 §2.3 的下限，故该召回率**只作管线自身的相对刻度，不可外推**。

**② 工具间重叠（对应 §10.1 元结论 3「工具间重叠低是常态」）** —— 小鼠数据 n=3，TNFα vs 未处理：

| 层次 | 指标 | 实测 |
| :--- | :--- | :---: |
| junction 级 | rMATS 显著 / LeafCutter 显著 / 交集 | 2,667 / 742 / **159** |
| junction 级 | Jaccard（全集分母） | 0.049 |
| junction 级 | **条件一致率**（只在两侧都检验过的 junction 上） | **11.4%** |
| 基因级 | rMATS / LeafCutter / DEXSeq / IsoformSwitchAnalyzeR | 736 / 1,694 / 3,444 / 261 |
| 基因级 | 被 4 条尺子同时命中 / ≥3 条命中 | **37 / 315** |

**⚠ 一条对本文 §10.3 的补充**：算 junction 级重叠时**必须把"未检验"与"检验了但不显著"分开**。
实测 rMATS 显著的 junction 里有 **47.9% LeafCutter 根本没检验**（聚类阶段即被滤掉）。
混在一个 Jaccard 里会把**覆盖差异记成方法学分歧**，系统性低估一致性。

**③ 假阳性本底（本文此前完全没有的一类数）** —— 标签置换穷举反向对照（n=3 vs n=3，9 个置换）：

| 项 | 值 |
| :--- | :---: |
| 置换本底显著事件数 | 最小 166、**中位 188**、最大 221 |
| 真实分组 | 1,031 |
| **信噪比** | **5.48×** |
| 经验 p | 0.100（**= 9 个置换的下限，非"不显著"**） |

⇒ **在 FDR<0.05 & |ΔPSI|≥0.1 & 每样本 IJC+SJC≥10 这套阈值下，纯噪声也能产出约 188 个"显著事件"，
约占报出量的 18%。** 换阈值必须重测。

**⚠ 2026-09-13 补测：这个 18% 是 rMATS 自己的刻度，不是三条路线的通病。**
P34 把**同样 9 种分法**施加到另外两条尺子上（复用同一份计数矩阵，只打乱标签）：

| 路线 | 检验单位 | 置换本底（最小 / 中位 / 最大） | 真实分组 | 信噪比 | 噪声占比 |
| :--- | :---: | :---: | :---: | :---: | :---: |
| rMATS | event | 166 / **188** / 221 | 1,031 | 5.48× | **18.2%** |
| LeafCutter | intron | 0 / **1** / 4 | 742 | 742× | **0.1%** |
| DEXSeq | exon bin | 3 / **18** / 62 | 8,483 | 471× | **0.2%** |

⇒ **rMATS 是三者中最宽松的一条，本底高出约两个量级。**
报显著数时必须报**那条尺子自己的**本底，借用别条会错两个量级。

**⚠ 两条不可略的读法**：
1. **LeafCutter 的近零本底不等于"更准"。** 同一份数据上它只检验 18,872 个 cluster，
   且 rMATS 显著的 junction 有 47.9% 它根本没检验，n=3 又在其官方校准下限 n=4 之外。
   近零本底更可能反映**保守**（少报且少错）。另：仅 `p.adjust<0.05` 时它有 1,931 个显著 cluster，
   加 `|ΔPSI|≥0.10` 后降到 446 —— **效应量阈值承担了大部分筛选，不是统计检验本身**。
2. **DEXSeq 的分母会动，原始计数不可直比。** 其 independent filtering 随 p 值分布自适应，
   P34 实测置换间被检验 bin 数在 **40,848–302,114** 变动（真实分组 254,656）。
   必须按「显著/被检验」比率重算：**471.28× → 377.67×**。
   rMATS（全部为 135,851）与 LeafCutter（全部为 18,872）的分母恒定，不受此影响。
   ⇒ **本文 §12 报告清单里"同时报置换本底"这一条，应补一句"并核对分母是否相同"。**
这类数字**方法间互证拿不到** —— 低重叠无法区分"各自看到不同真信号"与"各自在产生噪声"，
而置换对照给出的是**单条尺子自己的噪声刻度**。建议把"报显著事件数时同时报置换本底"
写进本文 §12 的报告清单。

**④ 一条工具限制（影响本文 §4.3 对 LeafCutter 的推荐）**：`leafcutter-ds` 自身报错原文写明
「we have only carefully checked the calibration of leafcutter p-values down to **n=4 samples per group**」。
⇒ **n=3（我们的常态）与 n=2（ENCODE 类公共数据）都在其官方校准范围之外**，
其 p 值宜作相对排序而非已校准 FDR。另：其 `-i/--min_samples_per_intron`（默认 5）在源码里
被当作**每组样本数**门槛用，n<5 时直接抛 "no groups with enough samples to test"，必须显式改小。

**⑥ 手工两遍 STAR 相对单 pass 的实际收益（对应本文 §4.1 与 pitfall #4 的量化）** ——
P34 用**同一批 reads** 跑了两种比对，其余（注释、rMATS 版本与参数、阈值）完全相同：

| 指标 | nf-core 单 pass（overhang 5/1） | 手工两遍（overhang 8/3） |
| :--- | :---: | :---: |
| 检出事件合计 | 152,708 | 152,024 |
| 显著事件合计 | 1,031 | **1,085（+5.2%）** |
| 显著 junction | 2,667 | 2,798 |
| Jaccard | 0.76 | — |
| **单 pass 结果被两遍复现的比例** | **88.5%** | — |

⇒ 本文 §4.1 说"two-pass 对剪接分析是必要的"，这里给出程度：
**单 pass 并不产出垃圾（88.5% 复现），但约每 8 条判读里有 1 条是比对方法依赖的。**
⇒ 一个值得写进本文的方向性观察：**检出事件总数略降（−684）而显著事件数反升（+54）** ——
严 overhang 滤掉低质量结点，**既降噪又提高检出功效**，不是简单的"更严 = 更少"。
⚠ 口径：P34 的 Phase 3 reads 由 BAM 反解（原始的高置信子集，丢弃 singleton 约 0.04%），
故差异 = 比对参数差异 + 该子集效应。

**⑤ MAJIQ 3.x 需要 license 文件**（实跑报错 `No Majiq License files were found, exiting`），
学术免费但须向 BioCiphers 申请。`--help` 把 `--license` 列为 optional 具有误导性 ——
**"命令行可以不写" ≠ "运行时不需要"**。本文 §4.3 提到 MAJIQ 时宜加此提示。

---

> **⚠ 同步义务**：两份文档任一处的方法学结论变更，必须同步另一处。本文是**上位方法学依据**，
> P34 是**实现与实证**；两者不是同一份信息的两个副本，不构成 single-source-of-truth 冲突。

---

## §13 参考文献

> **⚠ 以下条目基于我截至 2026-05 的知识加本次（2026-09-05）检索整理。年份、卷期与 DOI 请在引用前自行核对。** 标注 †的条目来自本次检索，链接已验证可达；未标注的为我的知识库内容，链接为常见 DOI 形式，**未逐条验证**。

### 综述与 benchmark

1. † Tran et al. **Comprehensive Overview of Computational Tools for Alternative Splicing Analysis.** *WIREs RNA*, 2025. [wires.onlinelibrary.wiley.com](https://wires.onlinelibrary.wiley.com/doi/full/10.1002/wrna.70030) ｜ [PMC12669084](https://pmc.ncbi.nlm.nih.gov/articles/PMC12669084/)
2. † **Tools and tactics for studying alternative splicing.** *Nature Reviews Genetics*, 2026. [nature.com/articles/s41576-026-00952-4](https://www.nature.com/articles/s41576-026-00952-4)（付费墙，未取全文）
3. † Mehmood A et al. **A comprehensive benchmarking of differential splicing tools for RNA-seq analysis at the event level.** *Briefings in Bioinformatics* 24(3):bbad121, 2023. [academic.oup.com](https://academic.oup.com/bib/article/24/3/bbad121/7108868)
4. † Pardo-Palacios FJ et al. **Systematic assessment of long-read RNA-seq methods for transcript identification and quantification (LRGASP).** *Nature Methods*, 2024. [nature.com/articles/s41592-024-02298-3](https://www.nature.com/articles/s41592-024-02298-3)
5. † **A systematic benchmark of Nanopore long-read RNA sequencing for transcript-level analysis in human cell lines.** *Nature Methods*, 2025. [nature.com/articles/s41592-025-02623-4](https://www.nature.com/articles/s41592-025-02623-4)
6. † **LongBench: benchmarking long-read RNA-sequencing technologies.** *bioRxiv*, 2025. [biorxiv.org](https://www.biorxiv.org/content/10.1101/2025.09.11.675724v1.full)
7. † **Comprehensive assessment of alternative splicing analysis methods for single-cell RNA-seq.** *iScience*, 2026. [sciencedirect.com](https://www.sciencedirect.com/science/article/pii/S2589004226014653)
8. † **Bioinformatics frameworks for single-cell long-read sequencing: unlocking isoform-level resolution.** *Briefings in Bioinformatics* 26(6):bbaf655, 2025. [academic.oup.com](https://academic.oup.com/bib/article/26/6/bbaf655/8377152)

### 短读长差异剪接工具

9. Shen S et al. **rMATS: robust and flexible detection of differential alternative splicing.** *PNAS* 111:E5593, 2014.
10. † Wang Y et al. **rMATS-turbo: an efficient and flexible computational tool for alternative splicing analysis of large-scale RNA-seq data.** *Nature Protocols*, 2024. [nature.com/articles/s41596-023-00944-2](https://www.nature.com/articles/s41596-023-00944-2)
11. Trincado JL et al. **SUPPA2: fast, accurate, and uncertainty-aware differential splicing analysis across multiple conditions.** *Genome Biology* 19:40, 2018.
12. Li YI et al. **Annotation-free quantification of RNA splicing using LeafCutter.** *Nature Genetics* 50:151, 2018.
13. Vaquero-Garcia J et al. **A new view of transcriptome complexity and regulation through the lens of local splicing variations (MAJIQ).** *eLife* 5:e11752, 2016.
14. † Vaquero-Garcia J et al. **RNA splicing analysis using heterogeneous and large RNA-seq datasets (MAJIQ v2).** *Nature Communications* 14:1230, 2023. [nature.com/articles/s41467-023-36585-y](https://www.nature.com/articles/s41467-023-36585-y)
15. † **Comprehensive and scalable quantification of splicing differences with MntJULiP.** *Genome Biology* 23:195, 2022. [genomebiology.biomedcentral.com](https://genomebiology.biomedcentral.com/articles/10.1186/s13059-022-02767-y)
16. Sterne-Weiler T et al. **Efficient and accurate quantitative profiling of alternative splicing patterns of any complexity on a laptop (Whippet).** *Molecular Cell* 72:187, 2018.
17. Anders S, Reyes A, Huber W. **Detecting differential usage of exons from RNA-seq data (DEXSeq).** *Genome Research* 22:2008, 2012.
18. Nowicka M, Robinson MD. **DRIMSeq: a Dirichlet-multinomial framework for multivariate count outcomes.** *F1000Research* 5:1356, 2016.
19. Van den Berge K et al. **stageR: a general stage-wise method for controlling the gene-level FDR.** *Genome Biology* 18:151, 2017.
20. Vitting-Seerup K, Sandelin A. **IsoformSwitchAnalyzeR: analysis of changes in genome-wide patterns of alternative splicing and its functional consequences.** *Bioinformatics* 35:4469, 2019.
21. Patro R et al. **Salmon provides fast and bias-aware quantification of transcript expression.** *Nature Methods* 14:417, 2017.
22. Kovaka S et al. **Transcriptome assembly from long-read RNA-seq alignments with StringTie2.** *Genome Biology* 20:278, 2019.
23. Dobin A et al. **STAR: ultrafast universal RNA-seq aligner.** *Bioinformatics* 29:15, 2013.
24. Garrido-Martín D et al. **ggsashimi: sashimi plot revised for browser- and annotation-independent splicing visualization.** *PLoS Computational Biology* 14:e1006360, 2018.

### Intron retention

25. Middleton R et al. **IRFinder: assessing the impact of intron retention on mammalian gene expression.** *Genome Biology* 18:51, 2017.（IRFinder-S 为后续版本）
26. † Li HD et al. **iREAD: a tool for intron retention detection from RNA-seq data.** *BMC Genomics* 21:128, 2020. [PMC7006120](https://pmc.ncbi.nlm.nih.gov/articles/PMC7006120/)

### 长读长

27. † Prjibelski AD et al. **Accurate isoform discovery with IsoQuant using long reads.** *Nature Biotechnology* 41:915, 2023. [nature.com/articles/s41587-022-01565-y](https://www.nature.com/articles/s41587-022-01565-y)
28. † Chen Y et al. **Context-aware transcript quantification from long-read RNA-seq data with bambu.** *Nature Methods* 20:1187, 2023. [PMC10448944](https://pmc.ncbi.nlm.nih.gov/articles/PMC10448944/)
29. Tang AD et al. **Full-length transcript characterization of SF3B1 mutation in CLL reveals downregulation of retained introns (FLAIR).** *Nature Communications* 11:1438, 2020.
30. † **IsoTools: a flexible workflow for long-read transcriptome sequencing analysis.** *Bioinformatics* 39:btad364, 2023. [academic.oup.com](https://academic.oup.com/bioinformatics/article/39/6/btad364/7189737)
31. Pardo-Palacios FJ et al. **SQANTI3: curation of long-read transcriptomes for accurate identification of known and novel isoforms.** *Nature Methods*, 2024.
32. Li H. **Minimap2: pairwise alignment for nucleotide sequences.** *Bioinformatics* 34:3094, 2018.
33. † **Comprehensive assessment of mRNA isoform detection methods for long-read sequencing data.** *Nature Communications* 15:3972, 2024. [nature.com/articles/s41467-024-48117-3](https://www.nature.com/articles/s41467-024-48117-3)

### 单细胞 / 空间剪接

34. † Wen WX et al. **MARVEL: an integrated alternative splicing analysis platform for single-cell RNA sequencing data.** *Nucleic Acids Research* 51:e29, 2023. [academic.oup.com](https://academic.oup.com/nar/article/51/5/e29/6985826)
35. Huang Y, Sanguinetti G. **BRIE2: computational identification of splicing phenotypes from single-cell transcriptomic experiments.** *Genome Biology* 22:251, 2021.
36. Buen Abad Najar CF et al. **Coverage-dependent bias creates the appearance of binary splicing in single cells (scQuint).** *eLife* 9:e54603, 2020.
37. Olivieri JE et al. **SpliZ generalizes 'percent spliced in' to reveal regulated splicing at single-cell resolution.** *Nature Methods* 19:307, 2022.
38. † **Mining alternative splicing patterns in scRNA-seq data using scASfind.** *Genome Biology* 25:184, 2024. [link.springer.com](https://link.springer.com/article/10.1186/s13059-024-03323-6)
39. † **Single cell and spatial alternative splicing analysis with Nanopore long read sequencing (Longcell).** *Nature Communications* 16, 2025. [nature.com/articles/s41467-025-60902-2](https://www.nature.com/articles/s41467-025-60902-2)
40. † **SCOTCH: isoform-level characterization of gene expression through long-read single-cell RNA sequencing.** *Nature Communications*, 2026. [nature.com/articles/s41467-026-72665-5](https://www.nature.com/articles/s41467-026-72665-5)
41. † **Deciphering splicing heterogeneity at single-cell resolution by SCSES.** [PMC12559242](https://pmc.ncbi.nlm.nih.gov/articles/PMC12559242/)
42. Tian L et al. **Comprehensive characterization of single-cell full-length isoforms in human and mouse with long-read sequencing (FLAMES).** *Genome Biology* 22:310, 2021.
43. † **Advances in single-cell long-read sequencing technologies.** *NAR Genomics and Bioinformatics* 6:lqae047, 2024. [academic.oup.com](https://academic.oup.com/nargab/article/6/2/lqae047/7676828)

### 变异 → 剪接预测

44. Jaganathan K et al. **Predicting splicing from primary sequence with deep learning (SpliceAI).** *Cell* 176:535, 2019.
45. Zeng T, Li YI. **Predicting RNA splicing from DNA sequence using Pangolin.** *Genome Biology* 23:103, 2022.
46. Dawes R et al. **SpliceVault predicts the precise nature of variant-associated mis-splicing.** *Nature Genetics* 55:324, 2023.
47. Wagner N et al. **Aberrant splicing prediction across human tissues (AbSplice).** *Nature Genetics* 55:861, 2023.
48. Cheng J et al. **MMSplice: modular modeling improves the predictions of genetic variant effects on splicing.** *Genome Biology* 20:48, 2019.
49. † Smith C, Kitzman JO. **Benchmarking splice variant prediction algorithms using massively parallel splicing assays.** *Genome Biology* 24:294, 2023. [genomebiology.biomedcentral.com](https://genomebiology.biomedcentral.com/articles/10.1186/s13059-023-03144-z)
50. † **Analyzing the performance of deep learning splice prediction algorithms.** *bioRxiv*, 2025. [biorxiv.org](https://www.biorxiv.org/content/10.1101/2025.11.20.689501.full.pdf)
51. † **SpliceAI Lookup.** Broad Institute. [spliceailookup.broadinstitute.org](https://spliceailookup.broadinstitute.org/)

### 剪接因子突变与疾病

52. † Ilagan JO et al. **U2AF1 mutations alter splice site recognition in hematological malignancies.** *Genome Research* 25:14, 2015. [genome.cshlp.org](https://genome.cshlp.org/content/25/1/14)
53. Kim E et al. **SRSF2 mutations contribute to myelodysplasia by mutant-specific effects on exon recognition.** *Cancer Cell* 27:617, 2015.
54. Darman RB et al. **Cancer-associated SF3B1 hotspot mutations induce cryptic 3′ splice site selection through use of a different branch point.** *Cell Reports* 13:1033, 2015.
55. † **Cryptic splicing events in the iron transporter ABCB7 and other key target genes in SF3B1-mutant myelodysplastic syndromes.** [PMC5029572](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5029572/)
56. † **A Unifying Mechanism for Shared Splicing Aberrations in Splicing Factor Mutant Cancers.** *bioRxiv*, 2025. [biorxiv.org](https://www.biorxiv.org/content/10.1101/2025.10.08.679601v1.full)（**预印本，结论需谨慎**）
57. † **SF3B1-mutant models of RNA mis-splicing uncover UBA1 as a therapeutic target in myelodysplastic neoplasms.** *Leukemia*, 2025. [nature.com/articles/s41375-025-02740-1](https://www.nature.com/articles/s41375-025-02740-1)
58. † **Alternative splicing: from tumorigenesis to neoantigen-mediated cancer immunotherapy.** *Biomarker Research*, 2025. [link.springer.com](https://link.springer.com/article/10.1186/s40364-025-00877-w)
59. † **Single-cell mapping of alternative splicing linked to checkpoint immunotherapy response.** *Nucleic Acids Research* 53:gkaf1171, 2025. [academic.oup.com](https://academic.oup.com/nar/article/53/21/gkaf1171/8329108)
60. † **Aberrant splicing and defective mRNA production induced by somatic spliceosome mutations in myelodysplasia.** *Nature Communications* 9:3649, 2018. [nature.com/articles/s41467-018-06063-x](https://www.nature.com/articles/s41467-018-06063-x)

### 成本数据来源

61. † TGen Collaborative Sequencing Center — Sequencing Costs. [tgen.org](https://www.tgen.org/service-centers/collaborative-sequencing-center/sequencing-costs/)
62. † NGI Sweden / SciLifeLab — Price examples. [ngisweden.scilifelab.se](https://ngisweden.scilifelab.se/resources/price-examples/)
63. † UNH Hubbard Center for Genome Studies — Services and Pricing. [hcgs.unh.edu](https://hcgs.unh.edu/services-pricing)

---

## 附：本文的不确定性与残余风险

**【必读】** 按 §0 的可靠性标注约定：

| 内容 | 可靠性 | 说明 |
| :--- | :---: | :--- |
| §0 / §4 / §5 / §7 的工具性能对比 | **较高** | 有 benchmark 文献支持，但**benchmark 之间口径不一致**（§10.1），排名不应绝对化 |
| **§3 全部成本数字** | **【估算】，最低** | 基于公开报价区间推算，**未与任何供应商核实**；建库价格、multiplex 数、flowcell 实际产量在不同机构差异可达 ±50% |
| §3.2 分析工时 | **【估算】** | 基于我对典型项目的推算；**熟练度差异可造成 ±40%**，首次跑某工具的学习成本未计入 |
| §8.2 剪接因子突变的"统一机制" | **低** | **来源为 2025 预印本，未经同行评审**，引用前须核实是否已正式发表 |
| §13 未标 † 的参考文献 | **中** | 来自我的知识库，**卷期页码未逐条验证** |
| 长读长通量与成本（Kinnex FLNC 产量等） | **【估算】** | 平台迭代快，2026 下半年的实际数字可能已优于本文假设 |

**我没有做的检查**：
- 未运行任何工具验证本文的参数建议；
- 未核实 §13 中未标 † 条目的 DOI 与卷期；
- 未与供应商核对任何报价；
- §12 的流程未在真实数据上端到端跑通验证（各步骤单独用过，组合未验证）。

**建议的下一步**（若要把本文用于实际项目）：
1. 用一个已有的 RNA-seq 数据集把 §12 的流程跑通一遍，记录**真实工时**，替换 §3.2 的估算；
2. 向常用测序服务商索取当前实际报价，替换 §3.1；
3. 核实参考文献 #56（预印本）的最新状态。
