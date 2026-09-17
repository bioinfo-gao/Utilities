# 机器学习（二）：表示学习与深度框架 —— 什么时候值得上神经网络，本机跑得动什么

> 建立日期：2026-09-17
> 用途：回答两个问题 ——**①这个任务值不值得上神经网络？②我这两台机器能跑到哪？**
> **评估纪律（交叉验证、数据泄漏、指标选型）不在本篇重复**，见 [①监督学习与评估纪律](1_supervised_learning_and_evaluation_discipline.md)。
> **"单细胞里哪些 AI 方法可信"也不在本篇**，见 `/home/gao/Utilities/Bioinfo/single_cell_and_spatial/AI_in_singlecell_and_spatial_1_methods_20260910.md`。
> 本目录第三篇：[③LLM 工程层](3_llm_engineering_layer.md)
> **服务器数据为 2026-09-17 实测；笔记本数据为你口述、尚未实测**（§3.3 给了一条填表命令）。

---

## §0 结论先行

| # | 结论 | 依据 |
| :--- | :---: | :---: |
| **1** | **多数生信任务不该上神经网络。** 样本量（几十到几百）远达不到 NN 的收益区间，正则化线性模型 + 好的特征几乎总是更稳、更好解释 | §1 决策树 |
| **2** | **服务器（GTX 1060）对 PyTorch 是彻底 CPU-only，且无法通过升级驱动解决** —— torch 2.14 的编译架构列表里**根本没有 sm_61** | §3.1 实测 |
| **3** | **笔记本（RTX 3060 6GB, sm_86）才是你的 GPU 工位**，sm_86 在编译列表内 | §3.2 |
| **4** | 深度学习框架是**三层**：`torch`（张量与自动微分）→ `lightning`（训练循环样板）→ `scvi-tools`（单细胞领域封装）。**大多数时候你只该碰最上层** | §2 |
| **5** | **embedding 是中间产物，不是结论。** 任何"在 UMAP 上看起来靠得近"都不能写成定量结论 | §5 |
| **6** | 🔴 DL 的静默错误比 sklearn 更多，因为**训练照跑、loss 照降、图照出** | §6 |

### 🔴 一句话

> **先用 §1 的决策树问三个问题。三个都答"是"才往下读；否则回第①篇用线性模型，省几天。**

---

## §1 决策树：值不值得上神经网络

```
① 样本量（独立生物学样本，不是细胞数）> 1000 ?
        │否 → 回 ①篇，用正则化线性模型 / HistGradientBoosting
        │是 ↓
② 数据有"结构"可被网络利用吗（序列、图像、图、大规模稀疏计数）?
        │否（就是一张 样本×基因 的表）→ 树模型或线性模型，NN 在表格数据上没有稳定优势
        │是 ↓
③ 已经有现成的领域实现吗（scvi-tools / CellTypist / 预训练模型）?
        │是 → 用它，不要自己搭网络
        │否 → 才考虑自己写 torch
```

**⚠ 第①问最容易被自己骗**：单细胞有 50000 个细胞，但如果只有 6 个 donor，
**统计上的独立样本数是 6，不是 50000**。这与第①篇 §3.1 的分组泄漏是同一件事。

**神经网络在生信里确实赢了的地方**（都是"感知/表示"类，不是"推断"类）：

| 任务 | 为什么 NN 合适 |
| :--- | :---: |
| 单细胞整合与去噪的**表示学习**（scVI/scANVI） | 有显式的概率生成模型，几万细胞量级足够 |
| 图像分割（细胞/细胞核，Cellpose、StarDist） | 图像是 NN 的主场 |
| 蛋白结构与序列（AlphaFold、ESM 系列） | 序列长、模式复杂，且有海量预训练数据 |
| 空间转录组的分割与配准 | 同图像 |

**明确没赢的地方**（写进报告前务必看那份文档）：基础模型零样本嵌入（scGPT/Geneformer）、
扰动效应预测、插补去噪 —— 见 `AI_in_singlecell_and_spatial_1_methods_20260910.md` §3。

---

## §2 框架分层：三层，你通常只该碰最上层

| 层 | 包 | 管什么 | 你该写多少代码 |
| :--- | :---: | :---: | :---: |
| ① 张量与自动微分 | **`torch`** | `Tensor`、`autograd`、`nn.Module`、优化器、设备管理 | 只在自己设计网络时 |
| ② 训练循环样板 | **`lightning`** | 把 train/val loop、checkpoint、early stopping、多卡、混合精度抽走 | 自己训模型时用它，别手写 loop |
| ③ 领域封装 | **`scvi-tools`** | 单细胞的整合/标签迁移/去噪，已经把模型和训练都定义好 | **绝大多数情况只用这层** |

**依赖方向和第①篇一样是单向的**：`scvi-tools` → `lightning` → `torch`。
上层替你做了决定（网络结构、损失函数、默认超参），**这些决定通常比你临时拍的更好**。

**⚠ 自己手写训练循环是本领域最常见的时间黑洞。** 手写 loop 要自己管
`model.train()/eval()`、`optimizer.zero_grad()`、梯度裁剪、checkpoint、early stopping ——
这些正是 §6 静默错误的高发区。**`lightning` 把它们全部机械化了。**

---

## §3 硬件现实：两台机器，结论完全相反

### §3.1 服务器（本机，2026-09-17 实测）：**PyTorch 彻底 CPU-only**

| 检查项 | 实测值 |
| :--- | :---: |
| GPU | NVIDIA GeForce **GTX 1060 3GB**（Pascal） |
| compute capability | **sm_61** |
| 驱动 | 535.309.01 ⇒ 支持到 CUDA **12.2** |
| `sc_tut_main` 的 torch | **2.14.0+cu130**（为 CUDA 13.0 编译） |
| `torch.cuda.is_available()` | **False** |
| `torch.cuda.get_arch_list()` | `['sm_75','sm_80','sm_86','sm_90','sm_100','sm_120']` |
| **sm_61 在编译列表里吗** | **否** |

**这是两个独立的封锁，不是一个：**

| 封锁 | 能不能解决 |
| :--- | :---: |
| 驱动 12.2 < 编译所需的 13.0 | 升级驱动可解 |
| **sm_61 不在 torch 2.14 的编译架构列表里** | **升级驱动也解决不了** —— 要么换 GPU，要么退回旧版 torch（会拖垮整个 env 的依赖组合） |

**⇒ 服务器上的结论是明确的：torch 用 CPU 跑，不要为 GPU 折腾。**
好消息是服务器有 **64 逻辑核 / 125 GB RAM**，
scVI 这类中小模型在几万细胞上 CPU 训练是可接受的（这也是 `/scrna` 一直以来的做法）。

**⚠ 别被 `torch.__version__` 里的 `+cu130` 骗了** —— 它说明**编译时**带了 CUDA，
不说明**运行时**能用。**唯一可信的判据是 `torch.cuda.is_available()`。**

### §3.2 笔记本（RTX 3060 6GB）：**这才是 GPU 工位**

| 项 | 值 | 来源 |
| :--- | :---: | :---: |
| GPU | RTX 3060 Laptop, **6 GB** | **你口述，未实测** |
| compute capability | **sm_86**（Ampere） | 由型号推定 |
| 在 torch 2.14 的编译列表里吗 | **是**（`sm_86` 在列） | 本机实测的列表 |
| 驱动是否够新 | **待确认** | §3.3 命令 |

**⇒ 结论反过来了：笔记本在架构上是被支持的，只要驱动够新就能用 GPU。**
6 GB 显存不小 —— 它足够做你去年做过的那类事（中小规模深度学习、小型语言模型）。

### §3.3 ⚠ 到笔记本上跑一次就能把上表填实

在那台机器的 conda 环境里，**复制粘贴这一整段**：

```bash
nvidia-smi --query-gpu=name,memory.total,driver_version,compute_cap --format=csv
python - <<'EOF'
import torch
print('torch      :', torch.__version__)
print('cuda avail :', torch.cuda.is_available())
print('arch list  :', torch.cuda.get_arch_list())
if torch.cuda.is_available():
    p = torch.cuda.get_device_properties(0)
    print(f'device     : {p.name}  {p.total_memory/1e9:.2f} GB  sm_{p.major}{p.minor}')
    print('sm 在编译列表里吗:', f'sm_{p.major}{p.minor}' in torch.cuda.get_arch_list())
EOF
```

**要看什么**：`cuda avail` 必须是 `True`；`sm_86` 必须出现在 `arch list` 里。
**看完做什么**：把输出贴回来，我把 §3.2 那张表从"口述"改成"实测"并标日期。
`nvidia-smi` 右上角的 `CUDA Version` 必须 **≥ torch build 的 CUDA 主版本**（`+cu130` ⇒ 需要 13.x）。

### §3.4 显存怎么算：一个够用的估算公式

训练时显存 ≈ **参数 + 梯度 + 优化器状态 + 激活值**。

| 部分 | fp32 | 混合精度 (fp16/bf16) + Adam |
| :--- | :---: | :---: |
| 参数 | 4 B/参数 | 2 B |
| 梯度 | 4 B/参数 | 2 B |
| Adam 的两个动量 | 8 B/参数 | 8 B（通常仍是 fp32） |
| **小计** | **16 B/参数** | **约 12 B/参数** |
| 激活值 | **与 batch size 成正比**，常常是大头 | 同 |

**6 GB 的粗略容量**（估算，**未在该机实测**，仅作规划用）：

| 想做的事 | 6 GB 够不够 |
| :--- | :---: |
| scVI / scANVI 训练（几万细胞） | ✅ 绰绰有余，模型本身很小 |
| 中小 CNN 图像分割（Cellpose 之类推理） | ✅ 通常够，注意图块大小 |
| **7B 语言模型 4-bit 量化推理** | ⚠ 约 4–5 GB 权重，**能跑但紧**，上下文一长就爆 |
| 1–3B 模型 **QLoRA 微调** | ✅ 可行，这是 6 GB 的甜点区 |
| 7B 模型全参数微调 | ❌ 差一个数量级（≈112 GB） |
| 任何 13B+ 的训练 | ❌ |

**显存不够时的第一手段永远是"减小 batch size"**，其次才是梯度累积、梯度检查点、量化。

---

## §4 scvi-tools：单细胞里唯一常规使用的深度模型

| 事实 | 值（本机实测） |
| :--- | :---: |
| 版本 | `scvi-tools` **1.3.3**（仅 `sc_tut_main`） |
| 依赖 | `torch` 2.14.0 · `lightning` 2.6.5 · `pyro-ppl` 1.9.1 · `numpyro` 0.19.0 · `jax` 0.6.2 |
| 本机跑在 | **CPU**（§3.1） |

**方法学定位与整合评判标准不在本篇**，见 `/scrna` §3.3（整合必须给两个量化指标并与"不整合"并排比）。

### 🔴 scvi-tools 的头号静默错误：喂错了矩阵

`scvi.model.SCVI.setup_anndata(adata, layer=...)` **必须指向 raw counts**。
喂归一化或 log 变换后的值，**不会报错**，模型照训、loss 照降、UMAP 照出 ——
但它的似然是负二项 / 零膨胀负二项，**前提就是整数计数**，喂了小数结果无意义。

```python
# ✅ 唯一正确的写法
scvi.model.SCVI.setup_anndata(adata, layer="counts", batch_key="sample")
```

这正是 `/scrna` 要求 **`adata.layers["counts"]` 在归一化之前就固化**的原因。

---

## §5 embedding（表示）的正确用法与三种误用

**embedding = 把高维观测压成低维向量。** PCA 是线性版，scVI 的 latent 是非线性版。

| ✅ 正确用法 | 说明 |
| :--- | :---: |
| 作为下游**聚类/近邻图**的输入 | 这是它被设计出来的目的 |
| 作为**批次整合后**的公共坐标系 | scVI 的主要卖点 |
| 作为分类器的输入特征 | **但要注意第①篇 §3.2 的泄漏**：embedding 在全量数据上训过 |

| ❌ 三种误用 | 为什么错 |
| :--- | :---: |
| **从 UMAP 图上读"距离"和"连续性"** | UMAP 不保距离，簇间远近是渲染产物，不是数据性质 |
| 把 latent 维度**当成有生物学含义的轴** | 与 PCA 不同，非线性 latent 的单个维度通常不可解释 |
| 拿 embedding 算基因间相关 / 共表达 | 表示学习会**凭空制造平滑与相关**，与插补去噪的危害同源 |

---

## §6 🔴 深度学习特有的静默陷阱（比 sklearn 多，因为训练总会"成功"）

| # | 陷阱 | 报错？ | 后果 |
| :--- | :---: | :---: | :---: |
| 1 | 推理前忘了 `model.eval()` | **否** | dropout / batchnorm 仍在训练模式，**同一输入每次预测都不同** |
| 2 | 推理时忘了 `torch.no_grad()` | 有时 OOM | 显存暴涨、速度慢数倍 |
| 3 | **early stopping 用了 test set** | **否** | 经典泄漏，见第①篇 §3；必须用独立的 validation set |
| 4 | 模型最后接了 `softmax`，损失又用 `CrossEntropyLoss` | **否** | 双重 softmax，梯度被压扁，模型学得很差但仍在"学" |
| 5 | 不设种子（`torch.manual_seed` + `cudnn.deterministic`） | **否** | 不可复现，且诱导"多跑几次挑好看的" |
| 6 | DataLoader 不 `shuffle=True` | **否** | 按类别排序的数据 ⇒ 每个 batch 只有一类，batchnorm 统计量完全失真 |
| 7 | scvi-tools 喂了归一化后的值 | **否** | 见 §4 |
| 8 | 类别不平衡不设 `pos_weight` / `weight` | **否** | 模型收敛到全预测多数类，loss 看起来很低 |
| 9 | `DataLoader(num_workers=-1)` 或过大 | 有时 | **违反本机 28 核 / 56 线程上限**，与其它任务抢资源 |
| 10 | loss 里累加 tensor 而不 `.item()` / `.detach()` | OOM | 整个计算图被留住，显存线性增长 |

> **第 1、4、6、7 条的共同结构**：**模型永远会训练成功。** loss 会降，曲线会好看，
> 图会画出来。**没有任何一个环节会告诉你"你喂错了东西"。**
> ⇒ 防法只有一个：**阳性对照断言**。先想好"什么必须出现"（见 `/scrna` §5），
> 跑完显式检查它是否成立，不成立就 `raise`。

---

## §7 本机实测：深度学习模块矩阵（2026-09-17）

| 模块 | `regular_bioinfo` | `sc_tut_main` | `sc_tut_spatial` | 其它 |
| :--- | :---: | :---: | :---: | :---: |
| torch | ❌ | **2.14.0+cu130** | 2.14.0 | ❌ |
| lightning / pytorch-lightning | ❌ | 2.6.5 / 2.6.5 | ❌ | ❌ |
| scvi-tools | ❌ | **1.3.3** | ❌ | ❌ |
| pyro-ppl / numpyro | ❌ | 1.9.1 / 0.19.0 | ❌ | ❌ |
| jax | ❌ | 0.6.2 | ❌ | ❌ |
| tensorflow / keras | ❌ | ❌ | ❌ | ❌ |
| transformers | ❌ | ❌ | ❌ | ❌ |
| **GPU 可用** | — | **False** | **False** | — |

**读法**：深度学习能力**只集中在 `sc_tut_main` 一个环境**，且是 CPU。
`sc_tut_spatial` 有 torch 是因为 tangram 的依赖链带进来的，不是为了训练。

---

## §8 选型速查

| 我要做的事 | 用这个 | 在哪台机器 |
| :--- | :---: | :---: |
| 单细胞整合 / 标签迁移 | `scvi-tools`（或先试 Harmony，更快） | 服务器 CPU 够用 |
| 表格数据预测 | **不要用 NN** —— 见第①篇 §6 | 服务器 |
| 图像分割（细胞/核） | Cellpose / StarDist 预训练模型**推理** | 笔记本 GPU 更快 |
| 自己训一个小网络 | `lightning`，不要手写 loop | **笔记本** |
| 微调小型语言模型 | QLoRA + 1–3B 模型 | **笔记本**（6 GB 甜点区） |
| 用大语言模型做事 | 走 API，不要本地跑 | 见 [③](3_llm_engineering_layer.md) |
| 基础模型（scGPT/Geneformer）零样本嵌入 | **不进生产流程** | — |

---

## §9 本篇与其它文档的边界

| 想知道什么 | 去读 |
| :--- | :---: |
| 交叉验证 / 泄漏 / 指标 / 不平衡 | [①监督学习与评估纪律](1_supervised_learning_and_evaluation_discipline.md) |
| LLM 的工程接入 | [③LLM 工程层](3_llm_engineering_layer.md) |
| **单细胞里哪些 AI 方法真有用** | `Bioinfo/single_cell_and_spatial/AI_in_singlecell_and_spatial_1_methods_20260910.md` |
| scVI 在流程里怎么摆、整合怎么评判 | `/scrna` skill §3.3 |
| torch/numpy 的数值底座关系 | `20.Notes_by_ZG/Python_core_modules_for_bioinformatics.md` |

---

## §10 本文的事实来源

| 内容 | 性质 |
| :--- | :---: |
| 服务器 GPU、驱动、arch list、各 env 的包版本 | **2026-09-17 本机实测**（`nvidia-smi` + `torch.cuda.get_arch_list()`） |
| **笔记本 RTX 3060 6GB** | **用户口述，未实测** —— 待 §3.3 的命令回填 |
| sm_86 属于 Ampere、在编译列表内 | 由型号推定 + 本机实测的列表比对 |
| 显存估算公式与 6 GB 容量表 | **估算与判断**，非实测，仅供规划 |
| 决策树、静默陷阱清单 | 我的整理与判断 |
