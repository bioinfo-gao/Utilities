# Ambient RNA：SoupX / decontX / CellBender，以及为什么不能直接报低表达 marker

> 2026-11-19 · 内部技术笔记

## 结论

解离后的组织样本里，每个液滴都混进了一层游离 mRNA（ambient RNA，常叫 soup）。不校正就去报"某基因在细胞类型 X 里低表达"，这个低表达很可能只是 soup 本底。

**风险最大的是这样一类基因：在某个高丰度或易裂解的细胞类型里高表达，同时被报成其他细胞类型里的低表达 marker。** 在 soup 里本来就几乎没有的真低表达基因，基本不受影响。

本机默认方案是 **SoupX 做主线、decontX 做互证**。本机 GPU 只有 3 GB，CellBender 视为不可用。

## 1. Ambient RNA 从哪来

- 组织解离（酶消化、机械剪切）、死细胞和坏死区会释放游离 mRNA，混在细胞悬液里。
- 10x 每个液滴都会捕获一部分这种游离 mRNA，空液滴也会。所以每个细胞的 counts 等于自身转录本加上一份 soup。
- soup 的成分约等于裂解细胞的加权平均，所以由**高丰度、高表达、易裂解**的细胞类型主导：

| 组织 | soup 里常见的主导基因 | 来源 |
| :--- | :---: | :---: |
| 肝 | ALB、APOA1、APOC3、HP、SERPINA1、TF | 肝细胞体积大、脆，解离时大量裂解（常常细胞本身捕获不到，转录本却留在 soup 里） |
| 胰腺 | PRSS1、CPA1、CELA3A、CTRB2、REG1A、SPINK1 | 腺泡细胞富含消化酶 mRNA，解离时自身酶解 |
| 肿瘤 | 肿瘤细胞的高表达基因、HBB/HBA、IGKC/JCHAIN（浆细胞多时） | 坏死、出血、浆细胞浸润 |
| 几乎所有组织 | HBB/HBA1/HBA2、MT- 基因 | 红细胞裂解；线粒体转录本外泄 |

污染程度的经验范围：PBMC、细胞系通常只有几个百分点；解离组织常见 10–30%，也有更高的。单核测序（snRNA-seq）同样有 ambient，不能当作没有。

## 2. 为什么偏偏会污染"低表达 marker"

一个细胞里，基因 g 被 soup 贡献的 UMI 约等于：

$$
\text{污染 UMI}_g \approx \rho \times N_{\text{UMI, cell}} \times f_{\text{soup},g}
$$

其中 ρ 是该通道的污染比例，$f_{\text{soup},g}$ 是 g 在 soup 中占的份额。

**示意算例**（数字为假设，用来说明量级）：肝样本 ρ = 0.1，一个 T 细胞有 3000 UMI，ALB 占 soup 的 5%。那么这个 T 细胞平均带有 3000 × 0.1 × 0.05 = **15 个 ALB UMI**。这个量超过很多真实转录因子（TF）在单个细胞里的计数。

由此产生几种典型误报：

| 误报形态 | 表现 | 怎么认出是 ambient |
| :--- | :---: | :---: |
| 跨类型低表达 | "肝 T 细胞低表达 ALB"、"胰岛 β 细胞表达 PRSS1" | 该基因在**所有** cluster 都有低水平信号，DotPlot 上每一行都是小点 |
| 伪"双阳性 / 过渡态" | 免疫细胞同时带上皮 marker，被解读成中间状态 | 共表达的恰好是 soup 头部基因；一校正就消失 |
| 伪 DE | 疾病组 soup 成分不同（例如肝细胞裂解更多），soup 基因在**每个细胞类型里都同向显著** | 同一组基因在所有细胞类型里同向变化 ⇒ 典型的 ambient 签名 |
| 注释污染 | 小 cluster 的 top marker 里混入 HBB、ALB、PRSS1 | top marker 与 soup top 基因大面积重叠 |

## 3. 三个工具

| 工具 | 语言 | 原理 | 需要的输入 | 污染估计粒度 | 主要坑 |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **SoupX** | R | 从空液滴估计 soup 谱，再用"该细胞不应表达"的基因估计 ρ，按比例扣除 | **raw（含空液滴）+ filtered 矩阵 + cluster** | 每个通道一个全局 ρ | `autoEstCont` 依赖 cluster 特异基因，样本很均一时会失败或高估；ρ > 0.2 要人工复核 |
| **decontX**（celda） | R | Bayesian 混合模型：每个细胞 = 自身群体的表达 + 来自其他群体的污染 | filtered 矩阵 + cluster；给 `background = raw` 更准 | **每个细胞**一个污染比例 | 默认用数据里其他 cluster 建模污染来源。soup 的主要来源细胞没被捕获时（肝细胞、腺泡细胞常这样），不给 raw background 就估不准；doublet 会混淆估计 |
| **CellBender** | Python | 深度生成模型，同时做 cell calling、去 ambient、去 barcode swapping | raw 矩阵（.h5） | 每个细胞、每个基因 | **实际上必须用 GPU**，CPU 极慢；`--fpr` 控制力度（默认 0.01），调高会删掉真信号 |

### 最小代码

> 以下代码按各工具官方文档的写法整理，本笔记写作时未在本机实际运行。

```r
## SoupX：自动估计
library(SoupX)
sc  <- load10X("sample/outs")                 # 需要 raw_feature_bc_matrix、filtered 和 analysis/ 里的 cluster
sc  <- autoEstCont(sc)
cnt <- adjustCounts(sc, roundToInt = TRUE)    # 取整，方便下游计数模型

## SoupX：用已知不表达基因手动估计（自动估计不可信时）
sc  <- SoupChannel(tod = raw, toc = filtered); sc <- setClusters(sc, clusters)
hb  <- list(HB = c("HBB", "HBA1", "HBA2"))
use <- estimateNonExpressingCells(sc, nonExpressedGeneList = hb)
sc  <- calculateContaminationFraction(sc, hb, useToEst = use)

## decontX：每个细胞的污染比例，作为独立互证
library(celda)
sce <- decontX(sce, background = sce_raw, z = sce$cluster)
summary(sce$decontX_contamination)
```

```bash
# CellBender（需要 GPU）
cellbender remove-background --input raw_feature_bc_matrix.h5 --output cb.h5 \
  --cuda --expected-cells <N> --fpr 0.01
```

## 4. 推荐流程

1. **先看 soup，再决定要不要校正。** 取 UMI < 100 的 barcode（空液滴）汇总，列出 top 20 基因。头部是 ALB、PRSS1、HB、IG 这类基因，就说明污染明显，必须校正。
2. **按 10x 通道逐个校正，在 merge 和整合之前做。** ambient 是每个通道各自的属性，不能合并后统一扣。
3. **SoupX 做主线，decontX 做互证。** 两者给出的污染量级应当接近。差两倍以上，先查 cluster 是否合理、soup 来源细胞是否缺失。
4. **校正力度宁轻勿重。** 过度校正会删掉真实的共享低表达基因。看几个已知真阳性的低表达 marker 在校正后是否还在。
5. **校正后的矩阵用于注释、marker 和作图。** DE 推荐两条路一起看：
   - 主分析用 raw counts 做 pseudobulk（保持计数模型的前提）；
   - 把所有 DE 基因和 soup top 基因列表比对。命中 soup 头部、并且在所有细胞类型里同向变化的基因，单独标成"疑似 ambient"，不作为生物学结论。
   - 要用校正后的矩阵做 pseudobulk，先取整，并注明。

## 5. 报告低表达 marker 前的四道关

一个基因要被报成"细胞类型 X 低表达 marker"，以下四条都要满足：

| 判据 | 通过标准 |
| :--- | :--- |
| 不在 soup 头部 | 不在该通道 soup top 基因里；在的话，必须同时满足下面三条 |
| 校正后仍存在 | SoupX（或 decontX）校正后，信号在 X 中仍明显高于其他 cluster |
| 表达比例高于本底 | X 中表达细胞的比例，显著高于"不该表达"的 cluster 里的比例 |
| 有正交证据（理想情况） | 原位杂交、免疫荧光、流式，或文献里该细胞类型的已知表达 |

达不到这些标准，就在报告里写"信号与 ambient RNA 本底不可区分"，不写"低表达"。

## 6. 本机相关的已知情况

- **本机 GPU 只有 3 GB，CellBender 视为不可用**，小数据集用 CPU 硬跑也要按小时到天来估。所以本机的默认方案是 SoupX + decontX。
- **proj22 的教训：** 自己写的 ρ 估计用"基因自身的表达分位数"去圈背景基因，结果 ρ 恒为 0，而且不报错。原因是选择单位和测量单位用了同一个变量。自写估计之前先确认这一点；更稳妥的做法是直接用 SoupX 或 decontX 的实现。
