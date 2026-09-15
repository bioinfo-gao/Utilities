# 单细胞分析 refresh（一）：数据对象与上游产物怎么读

**写给**：离开 scRNA-seq 分析 2–3 年后重新上手的自己。
**日期**：2026-09-14　**事实来源**：本机 `sc_tut_main` 环境 + proj22 的 s4d8 数据实测（见 §8）

> **与同目录其它文档的分工**（不重复，互相引用）：
>
> | 文档 | 回答的问题 |
> | :--- | :---: |
> | `scRNAseq_landscape_2023_to_2026_and_ecosystem_choice_20260910.md` | 三年里**什么变了**、Python/R 怎么选、90 天路线 |
> | `R_vs_Python_ecosystem_objective_comparison_20260910.md` | 逐环节的包级对比 |
> | **本文（refresh 一）** | **上游产物和数据对象具体怎么读**——字段、命名、语义、坑 |
>
> 本文刻意**不**复述"什么变了"，那一层去看 landscape 文档 §0.2 的重新校准清单。

---

## §0 结论先行：八条最容易记错的事

| # | 你可能以为 | 实际 |
| :--- | :---: | :---: |
| 1 | `filtered_feature_bc_matrix` = raw 按 UMI 阈值切一刀 | **不是阈值**，是 EmptyDrops 类统计检验。s4d8 实测：判为细胞的 UMI 低至 **2**，判为空的高达 **31,946**，重叠区间覆盖 99.9% 的细胞（见 §1.1） |
| 2 | 拿到 filtered 就够了，raw 可以删 | raw 是 ambient RNA 校正的**唯一原料**，删了 2-1 章的 soup 校正没法做 |
| 3 | barcode 末尾的 `-1` 是版本号/技术后缀 | 是 **GEM well 编号**（第几个上样通道），单库永远 `-1`，`aggr` 后才出现 `-2`、`-3` |
| 4 | var 表是人类基因的固定清单 | var 来自**跑 CellRanger 时用的参考包**，随 GENCODE 版本和基因组构建变 |
| 5 | gene symbol 可以当唯一键 | symbol **不唯一**（本参考包实测 10 个重复），且会被 HGNC 改名；稳定键是 `gene_ids`（Ensembl ID） |
| 6 | `var_names_make_unique()` 会动数据 | 只改列名索引，X 的数值和列顺序**一概不动**；原地修改、返回 `None` |
| 7 | `adata[mask]` 给的是新对象 | 给的是 **view**（`is_view=True`），要写回必须 `.copy()`，否则触发隐式复制或报警 |
| 8 | X 是普通 numpy 数组 | 是 **`scipy.sparse.csr_matrix`, float32**；raw 密度实测 **0.096%**，filtered **2.89%** |

---

## §1 上游给你的两个矩阵：raw vs filtered

CellRanger（以及 STARsolo / alevin-fry）对每个库输出两个矩阵。**差别只在行（barcode）上，列（基因）完全相同。**

| | raw_feature_bc_matrix | filtered_feature_bc_matrix |
| :--- | :---: | :---: |
| 含什么 barcode | 全部被观察到的 | 判定为「真细胞」的子集 |
| s4d8 实测行数 | 692,666 | 16,934（2.44%） |
| 矩阵密度 | 0.096% | 2.89% |
| 用途 | ambient RNA(soup) 估计、cell calling 复核 | 直接进 QC → 下游 |

**cell calling 不是阈值切分。** 判据是 EmptyDrops 类统计检验：把一个 barcode 的表达谱与 ambient profile 比，**显著不同就判为细胞，即使它 UMI 很低**。后果有两个方向：

- 低 RNA 含量的细胞类型（中性粒细胞、部分成熟红细胞）UMI 低但能被救回来 ⇒ **自己拿 UMI 阈值切 raw 会系统性丢掉整个细胞类型**。
- 反过来，高 UMI 但表达谱与 soup 无异的 barcode 会被判为空液滴。

**验证方法（在自己数据上跑一次就懂）**：比较「被判为细胞的最低 UMI」和「未判为细胞的最高 UMI」——两个区间重叠就证明不是阈值式判定。proj22 的 `notebooks/01_introduction/1-2_raw_data_processing.py` 里有现成代码（knee plot + soup profile）。

> 下面的 §1.1 用 s4d8 的实测数字把以上三段坐实。**两处内容有重叠**（EmptyDrops 机制、
> 那两条 bullet），是刻意保留的双份 —— 由你决定删哪一处，见文末「编辑备注」。

### 1.1 「那阈值到底是多少？」—— 不存在这个阈值

**一句话答案：没有任何一个 UMI 阈值能复现 `filtered`。** CellRanger 内部确实有一个数据自算的
初筛阈值，但**它不是最终边界**。cell calling 是两段式的：

| 阶段 | 做什么 | 有没有阈值 |
| :--- | :---: | :---: |
| ① ordmag 初筛 | 取预期细胞数对应 barcode 的 99 分位 UMI ÷ 10，高于它的直接判为细胞 | **有**，但从数据自算，每个样本都不同 |
| ② EmptyDrops 检验 | 对 ① 以下的 barcode，逐个检验其表达谱是否显著偏离 ambient profile，显著的**救回来** | **没有** —— 判据是统计显著性，不看 UMI |

⇒ **最终边界由 ② 决定，而 ② 根本不看 UMI 高低。** 后果有两个方向：

- 低 RNA 含量的细胞类型（中性粒细胞、部分成熟红细胞）UMI 很低也能被救回 ⇒ **自己切阈值会系统性丢掉整个细胞类型**；
- 反过来，高 UMI 但表达谱与 soup 无异的 barcode 会被判为空液滴。

**s4d8 实测（2026-09-14 实跑，脚本见 §8）**：

| 量 | 实测值 |
| :--- | :---: |
| 判为细胞的 barcode 数 | 16,934 |
| 判为细胞的 UMI：最低 / 中位 / 最高 | **2** / 1,156 / 63,182 |
| **未**判为细胞的最高 UMI | **31,946** |
| 两者的重叠区间 | **[2, 31946]**，内含 281,465 个 barcode |
| 其中判为细胞 / 判为空 | 16,918 / 264,547 |
| knee 点位置 | rank 29,954，UMI 78 |

**两个数字就够了：**

1. **99.9%**（16,918 / 16,934）的细胞落在那个「单看 UMI 无法与空液滴区分」的重叠区间里。
2. 强行按单一阈值切、要切出同样多的 16,934 个 barcode，阈值得定在 **UMI ≥ 308** ——
   结果**误纳 1,148 个、漏掉 1,147 个，错判 ≈ 6.8%**。而且漏掉的那批**系统性偏向低 RNA
   含量的细胞类型，不是随机丢失**。

**补充：低 UMI 的细胞到底有多稀少**（说明上面的最低值 2 是极端个例，不是普遍现象）

| UMI 下限 | 全部 barcode | 其中判为细胞 |
| :--- | :---: | :---: |
| ≥ 1 | 479,413 | 16,934 |
| ≥ 10 | 126,283 | 16,933 |
| ≥ 50 | 64,119 | 16,868 |
| ≥ 100 | 22,359 | 16,630 |
| ≥ 500 | 14,923 | 14,072 |

即 UMI < 10 的细胞只有 **1 个**，< 50 的 66 个，< 100 的 304 个。**极端个例不多，但它们恰恰
就是阈值法必然丢掉的那些。**

**⚠ 一个必须说明的前提**：s4d8 是 **10x Multiome**，cell calling 由 `cellranger-arc` 基于
**RNA + ATAC 联合证据**做出。所以「UMI=2 却判为细胞」里有一部分是**靠 ATAC 证据判定**的，
不能全部记到 EmptyDrops 头上。纯 RNA 文库（`cellranger count`）的重叠区间通常没有这么夸张，
但**重叠本身照样存在** —— 结论（不能用单一阈值复现）不变，量级要看自己的数据。

**两条铁律**：① 不要自己切阈值代替 filtered；② 不要只留 filtered、扔掉 raw。

---

## §2 barcode 名字：`-1` 到底是什么

格式是 **`<16nt 序列>-<GEM well 编号>`**。实测 `AAACAGCCAAGCTTAT-1`，破折号前恰好 16 个碱基。

**为什么需要后缀**：10x 每个通道用的是**同一份 ~737k 条 barcode 白名单**。两个样本各自跑出来的 barcode 序列必然大量重合，同一条 16-mer 在样本 A 和样本 B 里是**完全不同的细胞**。加 well 编号才能保证跨通道唯一。

| 情形 | obs_names 形态 | 注意 |
| :--- | :---: | :---: |
| 单库单通道（s4d8） | 全部 `-1` | 后缀不含任何生物学信息 |
| `cellranger aggr` 合并 3 库 | `-1` / `-2` / `-3` | 顺序由 aggr 的 CSV 决定，**必须留档**，否则事后认不出哪个是哪个样本 |
| anndata `concat(index_unique="-")` | `...-1-0`、`...-1-1` | **后缀会叠加** |

**⚠ 由此产生的两个坑：**

1. 跨样本合并前，`-1` **不是**唯一键。正确做法是显式加样本前缀（`f"{sample}_{bc}"`），不要依赖 concat 自动加的数字后缀——那个后缀的含义取决于传入顺序，换一次顺序就全错。
2. 想从 obs_names 取回 16nt 序列时，**不要写 `bc.split("-")[0]`**——遇到 `...-1-0` 这种双后缀会取错。用 `bc[:16]` 或 `bc.rsplit("-", 1)[0]` 按实际情况定。

---

## §3 var 表不是恒定的：人类基因不变，但注释年年变

`var` 来自跑 CellRanger 时指定的**参考包**（如 `refdata-gex-GRCh38-2020-A`），不是来自任何"标准人类基因清单"。s4d8 实测 4 列：

| 列 | 内容 | 稳定性 |
| :--- | :---: | :---: |
| `gene_ids` | Ensembl ID（`ENSG00000243485`） | **最稳定**，跨版本的正确连接键 |
| `feature_types` | `Gene Expression` / `Peaks` / `Antibody Capture` | 取决于文库类型 |
| `genome` | `GRCh38` | 随参考包变 |
| `interval` | `chr1:29553-30267` | **随基因组构建变，跨构建不可比** |

**会变的五类**：

| 变化来源 | 后果 |
| :--- | :---: |
| GENCODE / 参考包版本 | 收录基因数不同 ⇒ var 行数不同 |
| 基因组构建（GRCh37 / GRCh38 / T2T-CHM13） | `interval` 坐标完全不可比 |
| HGNC 改名、合并、废弃 | symbol 漂移；Ensembl ID 稳定得多（但也会 retire） |
| 文库类型 | multiome / CITE-seq 会混入 `Peaks`、`Antibody Capture` 行 |
| 下游分析本身 | `filter_genes` 删行、HVG 选择加 `highly_variable` 等列——var 一直在被改写 |

**symbol 不唯一是实测事实**：s4d8 用的这版参考包里有 **10 个重复 symbol**（`TBCE`、`LINC01238`、`CYB561D2`、`MATR3`、`LINC01505` …），共 36,601 行。数量不多，但只要不做 `var_names_make_unique()`，后面按基因名取列就会**静默取到其中任意一个**——不报错，取错了也看不出来。

**`var_names_make_unique()` 的确切语义**（实测 anndata 0.12.19）：

```
签名: var_names_make_unique(join='-') -> None      # 原地修改，不返回新对象
规则: 第一次出现的名字原样保留，之后的重复项依次加 -1、-2
例:   ['a','a','b'] → ['a','a-1','b']
范围: 只动 var_names（索引），X 的数值与列顺序不变 —— 是索引去重，不是数据变换
陷阱: 写成 adata = adata.var_names_make_unique() 会把 adata 变成 None
```

**⚠ 人类 10x 参考包的线粒体基因前缀是 `MT-`**（实测 `MT-CO1`），不是 `chrM`、不是 `mt-`（那是小鼠）。QC 时 `adata.var_names.str.startswith("MT-")` 写错大小写会静默得到 0 个线粒体基因、`pct_counts_mt` 全 0——**看起来像"这批数据线粒体污染很低"**，是最典型的静默错误。
写对的话，人类参考包实测 **13 个** `MT-` 基因（线粒体编码的 13 个蛋白基因），这个数字可以直接当断言用：`assert adata.var_names.str.startswith("MT-").sum() == 13`。

**实务上唯一承重的一条**：同一项目的所有样本必须用**同一个参考包**跑。版本不同 ⇒ var 行数不同、symbol 对不上，直接 concat 会静默取交集或产生 NaN 列。必须合并时按 `gene_ids` 取交集，不要按 symbol。

---

## §4 AnnData 对象模型：七个槽位

```
adata
 ├── X          主矩阵 (n_obs × n_vars)，csr_matrix / float32
 ├── obs        行元数据 DataFrame（细胞）—— 索引 = obs_names = barcode
 ├── var        列元数据 DataFrame（基因）—— 索引 = var_names
 ├── layers     同形状的其它矩阵：counts / lognorm / scaled
 ├── obsm       每个细胞的多维表示：X_pca、X_umap、空间坐标 spatial
 ├── varm       每个基因的多维表示：PCs
 ├── uns        杂项：配色、参数、图结构（neighbors）
 └── raw        历史遗留槽位（存 subset 前的全基因矩阵）
```

**刚从 h5 读进来时是"裸"的**：s4d8 实测 `obs` **0 列**、`layers`/`obsm`/`uns` 全空、`.raw` 为 `None`。所有元数据都是你后面一步步算出来加上去的——这也是 `obs.head(10)` 打印出 `Empty DataFrame` 的原因，不是读取失败。

**三条 API 约定（忘了就会踩）**：

| 约定 | 说明 |
| :--- | :---: |
| 多数 `sc.pp.*` 是**原地修改** | 返回 `None`；想要新对象得传 `copy=True` 或自己 `.copy()` |
| 切片返回 **view** | 实测 `adata[:100].is_view == True`；对 view 写入会触发隐式复制或报警，要改就先 `.copy()` |
| X 是**稀疏矩阵** | 切片后仍稀疏，打印前要 `.toarray()`；**绝不要对全矩阵 `.toarray()`**（16,934×36,601 float32 稠密 ≈ 2.5 GB，raw 那个 ≈ 101 GB） |

**`.raw` 建议不要再用**：它是早期为"subset 到 HVG 后还想画全基因"设计的历史槽位，语义容易和 `raw_feature_bc_matrix` 混淆。现在的做法是把 counts 存进 `layers["counts"]`，不动 `.raw`。

---

## §5 拿到新数据的第一件事：一段体检代码

```python
import scanpy as sc, numpy as np

raw  = sc.read_10x_h5("raw_feature_bc_matrix.h5");      raw.var_names_make_unique()
filt = sc.read_10x_h5("filtered_feature_bc_matrix.h5"); filt.var_names_make_unique()

for name, ad in [("raw", raw), ("filt", filt)]:
    print(f"\n===== {name}: {ad.n_obs:,} obs × {ad.n_vars:,} var")
    print("  X:", type(ad.X).__name__, ad.X.dtype,
          f"density={ad.X.nnz/(ad.n_obs*ad.n_vars):.4%}")
    print("  obs 列:", list(ad.obs.columns) or "(空)")
    print("  var 列:", list(ad.var.columns))
    print("  barcode 后缀:", sorted({b.rsplit("-", 1)[-1] for b in ad.obs_names[:50_000]}))
    ft = ad.var["feature_types"].unique().tolist() if "feature_types" in ad.var else "(无此列)"
    print("  feature_types:", ft)
    print("  MT- 基因数:", int(ad.var_names.str.startswith("MT-").sum()))   # 0 = 前缀写错或非人类
```

**四个必看**：① barcode 后缀集合（暴露是不是 aggr 过的）；② `feature_types`（暴露是不是 multiome/CITE-seq）；③ `MT-` 基因数（人类应为 **13**，0 就是前缀写错了）；④ raw/filt 行数比（正常几个百分点）。

**s4d8 上的实际输出**（2026-09-14 实跑本段代码，未改一字）：

| | raw | filt |
| :--- | :---: | :---: |
| 形状 | 692,666 × 36,601 | 16,934 × 36,601 |
| density | 0.0956% | 2.8941% |
| obs 列 | (空) | (空) |
| barcode 后缀 | `['1']` | `['1']` |
| feature_types | `['Gene Expression']` | `['Gene Expression']` |
| MT- 基因数 | 13 | 13 |

注意 `feature_types` 只有 `Gene Expression` 一种：s4d8 虽是 Multiome 样本，但
`sc.read_10x_h5` 默认 `gex_only=True`，ATAC peaks 在读取时就被挡掉了。写成 `False` 会
混进几万个 peak 行，后面 HVG 选出一堆 peak、PCA 变成 RNA/ATAC 混合信号——图照画，但没有意义。

---

## §6 这一层最容易踩的坑，按"是否静默"排序

| 坑 | 会不会报错 | 后果 |
| :--- | :---: | :---: |
| `MT-` 前缀写错大小写 | **不报错** | 线粒体比例全 0，被读成"数据质量很好" |
| 不做 `var_names_make_unique()` 就按名取基因 | **不报错** | 取到重复 symbol 中的任意一个 |
| 跨样本按 symbol 而非 `gene_ids` 合并 | **不报错** | 静默取交集 / NaN 列 |
| `bc.split("-")[0]` 遇上双后缀 | **不报错** | barcode 被截错 |
| 同项目混用不同参考包 | 可能不报错 | 引入与批次效应无法区分的技术变量 |
| `adata = adata.var_names_make_unique()` | 后续报错 | adata 变成 `None` |
| 对全矩阵 `.toarray()` | OOM / 卡死 | raw 稠密化约 101 GB |

---

## §7 本系列后续（尚未写，按需要再定）

| 篇 | 内容 | 状态 |
| :--- | :---: | :---: |
| 一 | 数据对象与上游产物（本文） | **已写** |
| 二 | QC → 归一化 → HVG → PCA/邻域/聚类：每一步的决策点与现在的默认做法 | 未写 |
| 三 | 注释、整合、跨条件 DE（伪重复问题）与 benchmark 结论 | 未写（landscape 文档 §1.1/1.3/1.4 已有结论层，这里补操作层） |
| 四 | 空间转录组入场 | 未写 |

---

## §8 事实来源与核实方式

**环境**（`/mnt/ex_8T_SSD/conda_envs/sc_tut_main`，2026-09-14 实测）：

| 包 | 版本 |
| :--- | :---: |
| scanpy | 1.11.5 |
| anndata | 0.12.19 |
| numpy | 2.4.6 |
| scipy | 1.17.1 |
| pandas | 2.3.3 |
| h5py | 3.16.0 |

**数据**：proj22 的 `s4d8`（10x Multiome，NeurIPS 2021 benchmark 数据集），路径经
`scripts/_common/sc_tut_utils.py: dataset_path()` 解析。

**本文所有数字都是当天实测**（行数、密度、nnz、重复 symbol 数、view 语义、函数签名）。
**唯一未核实的一点**：raw 实测 692,666 个 barcode，低于 10x 白名单常说的 ~737k——
这份数据是 figshare 上的再分发版本，差异原因（上游做过裁剪，还是用的 ARC 白名单）未查证，
不影响本文任何结论。

**§1.1 的数字怎么复核**：脚本 `scratchpad/thresh.py` 的逻辑是——读 raw + filtered，
按 `np.isin(raw.obs_names, filt.obs_names)` 得到 called 掩码，再取 `umi[called].min()`、
`umi[~called & nz].max()`、以及"按 rank 前 16,934 切"的阈值与误判数。
在 `sc_tut_main` 里重跑约 4 分钟（读 raw 矩阵是瓶颈）。

**配套代码（双向引用）**：

| 那边 | 指向本文的哪里 |
| :--- | :---: |
| `~/projects_2026M7/22_python_based_scRNA_tutorial/notebooks/01_introduction/0_companion_reference_docs.md` | 章节 ↔ 小节完整对照表（索引文件） |
| `…/01_introduction/1-2_raw_data_processing.py` 文件头 + 读 raw/filt 那一格 | §1、§1.1、§2、§3 |
| `…/01_introduction/1-3_anndata_and_scanpy.py` 文件头 | §4 |

代码那边写"这一行在干什么"，本文写"为什么是这样、实测是多少"，互不复述。
`1-2` 里有 knee plot、soup profile、头 10 行体检的可运行实现，均带逐行注释。

**本文若改名或移动**，需要同步的只有三处：上表的两个 `.py` 文件头 + 那份索引 md。

---

## 编辑备注（2026-09-15，可删）

2026-09-14 首版写完后按"聊天里那版更集中"重写了 §1.1；**原有文字已全部还原，现为双份**。
下面列出重叠处，供你自行取舍（删掉任一侧文档都仍然完整）：

| 内容 | 位置 A（首版行文） | 位置 B（重写版） | 结论 |
| :--- | :---: | :---: | :---: |
| EmptyDrops 机制一句话 | §1 正文首段（第 44 行） | §1.1 两段式表格第 ② 行 | **两者都留**（用户 2026-09-15 点名 A 段"收获很大"） |
| 两条 bullet（低 RNA 细胞被救回 / 高 UMI 被判空） | §1 正文 | §1.1「⇒ 最终边界由 ② 决定」下方 | 二选一即可 |
| "验证方法"段 | §1 正文末 | §1.1 实测表已直接给出结果 | A 讲方法、B 给结果，可并存 |

**⛔ 第 44 行那段不要删**（"cell calling 不是阈值切分…显著不同就判为细胞，即使它 UMI 很低"）。
它和 §1.1 的表格是互补不是重复：**表格给的是流程（两段式各干什么），这段给的是判据本身
——比的是"表达谱与 ambient profile 的差异"，不是 UMI 大小**。只看表格容易以为 ② 只是个更
复杂的阈值；这句话才点破它换了一个完全不同的判定维度。

**删除时注意**：§1.1 的两段式表格（ordmag / EmptyDrops）是首版没有的内容，
不要连带删掉——"内部确实有一个阈值，但它不是最终边界"这层意思只在那张表里。
