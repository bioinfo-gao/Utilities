# 30.ML_and_AI —— 机器学习 / 深度学习 / LLM 笔记索引

> 建立日期：2026-09-17
> 用途：讲"**什么时候该用、怎么用才算数**"的长文，不是 API 手册。
> 与 `../20.Notes_by_ZG/` 的分工：那边讲 **Python 科学栈的职责边界**，这边讲 **学习型方法的纪律与选型**。

## 为什么是这三篇（而不是"普通 ML / 深度学习 / LLM"）

**分篇的依据是「要回答的决策问题」，不是技术代际。** 理由有三：

| 理由 | 说明 |
| :--- | :---: |
| **评估纪律是共享的** | 交叉验证、数据泄漏、指标选型对 sklearn 和 torch **完全一样**。按代际切会让最承重的这部分要么写两遍、要么两边都漏 ⇒ **整块收进①，②③引用** |
| **硬件现实把 DL 的边界画死了** | 服务器对 PyTorch 是 CPU-only（sm_61 不在编译列表）；笔记本 RTX 3060 6GB（sm_86）才是 GPU 工位 ⇒ 这是②的骨架，不是背景介绍 |
| **LLM 的生物学判定已经有三篇了** | `Bioinfo/single_cell_and_spatial/AI_in_singlecell_and_spatial_{1,2,3}` ⇒ 本目录的③**只讲工程**，判定一律指过去，避免同一件事存两份 |

## 该读哪一篇

| 我的处境 | 读这篇 |
| :--- | :---: |
| 要用表达谱预测表型 / 训一个分类器 / 判断别人的准确率可不可信 | **①** |
| 想知道这个任务值不值得上神经网络、我这两台机器能跑到哪 | **②** |
| 要在脚本里调 LLM、关心成本与可靠性 | **③** |

## 笔记

| # | 笔记 | 主题 | 日期 |
| :--- | :---: | :---: | :---: |
| ① | [1_supervised_learning_and_evaluation_discipline.md](1_supervised_learning_and_evaluation_discipline.md) | **监督学习与评估纪律**：sklearn 三对象心智模型、**数据泄漏的五种形态（生信版）**、CV splitter 选型（单细胞必须 `GroupKFold`）、不平衡下的指标、p≫n、10 条静默陷阱 | 2026-09-17 |
| ② | [2_representation_learning_and_dl_frameworks.md](2_representation_learning_and_dl_frameworks.md) | **表示学习与深度框架**：值不值得上 NN 的决策树、torch→lightning→scvi-tools 三层、**两台机器的 GPU 能力矩阵（实测）**、显存估算、embedding 的三种误用、10 条 DL 静默陷阱 | 2026-09-17 |
| ③ | [3_llm_engineering_layer.md](3_llm_engineering_layer.md) | **LLM 工程层**：三条路线、模型与价格表、structured outputs、prompt caching 的前缀匹配、Batch API、**别用 tiktoken 数 Claude token**、10 条静默陷阱 | 2026-09-17 |

## 三篇共用的一条主线

> **学习型方法的失败不会报错。**
> ① sklearn：泄漏了，准确率虚高，代码照跑。
> ② torch：喂错了矩阵，loss 照降，图照出。
> ③ LLM：HTTP 200，格式合法，内容是编的。
>
> **⇒ 三篇给出的防法是同一个：把"什么必须成立"写成断言，跑完显式检查。**
> 判断留在读者脑子里 = 没做。

## 本机硬件速查（2026-09-17 实测）

| | 服务器（本机） | 笔记本（**你口述，未实测**） |
| :--- | :---: | :---: |
| GPU | GTX 1060 3GB, **sm_61** | RTX 3060 **6GB**, sm_86 |
| 在 torch 2.14 的编译架构列表里 | **否** | **是** |
| `torch.cuda.is_available()` | **False**（实测） | 待实测 |
| 结论 | **CPU-only，别折腾 GPU** | **GPU 工位** |
| CPU / RAM | 64 逻辑核（上限 28 核/56 线程）/ 125 GB | — |

填实笔记本那一列的命令见 [②](2_representation_learning_and_dl_frameworks.md) §3.3。

## 相关但不在本目录

| 文档 | 路径 |
| :--- | :---: |
| Python 科学栈的职责边界与静默陷阱 | `../20.Notes_by_ZG/Python_core_modules_for_bioinformatics.md` |
| R↔Python 迁移、中立选型 | `../20.Notes_by_ZG/INDEX.md` |
| **AI 在单细胞与空间中**（方法可信度 / agent 工作流 / LLM 做生物学推断，共 3 篇） | `/home/gao/Utilities/Bioinfo/single_cell_and_spatial/AI_in_singlecell_and_spatial_*.md` |
| 单细胞分析 SOP | `/scrna` skill |
| 软件坑索引 | `/home/gao/Utilities/software_pitfalls/INDEX.md` |
