RNAseq 中这句话什么意思


| **Analysis**                    | Higher in SRSF2 | Lower in SRSF2 | All candidates |
| :------------------------------------ | :-------------- | :------------- | :------------- |
| **GO biological process (ORA)** | 80              | 8              | 76             |

这句话是 RNA-seq 差异基因（或差异剪接基因）富集分析表格中的一行数据，表达的是：针对 SRSF2 基因调控的不同候选基因集，使用 GO（Gene Ontology）生物学过程（Biological Process）过表达分析（ORA）所计算出的“显著富集通路/条目（GO Terms）的数量”。



注明： 原表在/home/gao/projects_2026M7/40_NahYoung_Shin_SRSF2_RNAseq_NO_Repeat/Data_Analysis_20261002/NahYoung_Shin_SRSF2_RNAseq_1002.md

### 7.5 Pathway analysis (exploratory)

| Analysis                    | Higher in SRSF2 | Lower in SRSF2 | All candidates |
| :-------------------------- | :-------------: | :------------: | :------------: |
| GO biological process (ORA) |       80       |       8       |       76       |
| GO molecular function (ORA) |       25       |       0       |       14       |
| GO cellular component (ORA) |        5        |       0       |       4       |
| KEGG pathways (ORA)         |       20       |       0       |       8       |

一、 各字段/列名逐一拆解
表头 / 列名	含义解释	对应数值 / 结果
Analysis	分析方法与维度：GO 生物学过程的过表达富集分析（ORA）	GO biological process (ORA)
Higher in SRSF2	在 SRSF2（高表达/突变/处理组）中表达量升高或剪接表达水平更高的候选基因集	80 个显著富集的 GO 通路
Lower in SRSF2	在 SRSF2 组中表达量降低或剪接表达水平更低的候选基因集	8 个显著富集的 GO 通路
All candidates	所有候选基因的总和（即 Higher + Lower 的合并基因集）	76 个显著富集的 GO 通路
原始 Markdown 代码：

Markdown

| 表头 / 列名               | 含义解释                                                                                     | 对应数值 / 结果                   |
| :------------------------ | :------------------------------------------------------------------------------------------- | :-------------------------------- |
| **Analysis**        | 分析方法与维度：GO 生物学过程的过表达富集分析（ORA）                                         | `GO biological process (ORA)`   |
| **Higher in SRSF2** | 在 SRSF2（高表达/突变/处理组）中**表达量升高**或**剪接表达水平更高**的候选基因集 | **80** 个显著富集的 GO 通路 |
| **Lower in SRSF2**  | 在 SRSF2 组中**表达量降低**或**剪接表达水平更低**的候选基因集                    | **8** 个显著富集的 GO 通路  |
| **All candidates**  | **所有候选基因**的总和（即 Higher + Lower 的合并基因集）                               | **76** 个显著富集的 GO 通路 |

二、 生物信息学与生物学意义解读
核心生物学结论：

SRSF2（一种重要的 RNA 剪接因子，Serine/arginine-rich splicing factor 2）的改变，其生物学功能影响绝大部分集中在“表达/剪接升高（Higher in SRSF2）”的基因上（富集到了 80 个通路）。

而“表达/剪接降低（Lower in SRSF2）”的基因几乎没有形成集中的功能模块（仅富集到 8 个通路）。

为什么 All candidates（76 个）比 Higher in SRSF2（80 个）还少？

ORA（Over-Representation Analysis，超几何分布检验） 的计算依赖于“候选基因数 / 背景基因数”的比例。

当把无明显功能集中的“Lower”基因混入“Higher”基因一起分析时，噪声基因增加了候选集基数，导致部分的 p 值或 FDR 被稀释而不再显著（从 80 降到了 76）。这也是生信分析中通常建议将“上调基因”与“下调基因”分开单独做 GO/KEGG 富集的原因。
