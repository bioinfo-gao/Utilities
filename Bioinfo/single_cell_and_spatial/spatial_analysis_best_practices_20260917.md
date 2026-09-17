# 空间转录组分析最佳实践：让一次分析经得起复核

**建立日期**：2026-09-17
**本文回答什么**：不是"选哪个生态"（那是 `spatial_transcriptomics_R_vs_Python_ecosystem_20260910.md`），
也不是"该做什么动作"（那是 [`/spatial` skill](/home/gao/.claude/skills/spatial/SKILL.md)），
而是——**怎么把一次空间分析做成"半年后自己或别人能复核"的形态**。

> **SSOT 声明**：本文**不复述**生态对比的论证，也**不复述** skill 的判据。
> 三份的分工：**文档讲"为什么选它" → skill 讲"判据与动作" → 本文讲"工程纪律与可验证性"。**
> 三者有冲突时以 skill 为准（它是执行体实际读的那份）。

**本文补的是一个真实缺口**：skill §5 列出的 4 个空间断言**只有 R 实现**
（在 `24_R_advanced.../adv_tut_utils.R`）。**Python 侧此前没有空间专用断言。**
§4 给出可直接复制的 Python 实现，`37_spatial_visium_heart_pilot` 是它的首个使用者。

---

## §0 十条最佳实践（只记这些也够用）

| # | 实践 | 不做的后果 | 在哪一节 |
| :--- | :---: | :---: | :---: |
| **1** | **开工第一件事是写下"观测单位是什么"**，并让它出现在每张图的标题里 | 全文的"细胞类型比例"说法失去定义 | §1.1 |
| **2** | **y 轴方向在读入后立刻断言**，不等到出图才发现 | 组织上下镜像；图、聚类、统计全部"正常" | §3.1 · §4.1 |
| **3** | **`in_tissue` 过滤后立刻记录保留比例**，写进日志而不是只写进脑子 | 组织外背景 spot 参与聚类，产生假的"低表达域" | §3.2 |
| **4** | **每个阶段落一个带前缀与时间戳的 checkpoint**，两类平台前缀不共用 | 拿测序型的中间产物喂成像型的下游，形状碰巧合法 | §2.2 |
| **5** | **SVG 必须与 Moran's I 并排**；只有一种方法可用时，**把这件事写进 Limitations** | 把单一方法的偏好当成生物学 | §3.4 |
| **6** | **去卷积前先断言参考是同组织、基因交集足够、训练基因数 > 0**，产出后断言比例和为 1、无负值 | 给出看似合理的细胞类型构成，而它是凭空的；Tangram 用 0 个基因也能"跑完" | §3.5 · §4.3 · **§4.6** |
| **7** | **域（domain）数量至少扫三个设置**，报告里给稳定性证据 | 把一个超参数的选择当成组织结构 | §3.3 |
| **8** | **每张空间图都要能数出点数**，并与该阶段的 `n_obs` 对得上 | 抽稀/截断静默丢点，图看着正常 | §4.4 |
| **9** | **n=1 或单一条件时，明确写"做不了跨条件统计"**，只给描述与模板 | 拿单样本硬做出一张"显著"的表 | §1.3 · §6 |
| **10** | **交付前跑一遍 §5 的自审清单**，逐条留下可回读的命令 | "跑完了"不等于"对" | §5 |

> **这十条的共同点**：它们防的**全部是不报错的错误**。
> 会报错的问题不需要最佳实践，跑一次就暴露了。

---

## §1 开工前必须钉死的六件事

**这六件事没定就动手，猜错要整条重跑。** 定完写进项目的计划文档，不要只存在对话里。

### 1.1 观测单位是什么（最重要的一件）

| 平台 | 观测单位 | 一句必须写进报告的话 |
| :--- | :---: | :---: |
| Visium | **spot（55 µm，含数个至数十个细胞）** | "spot 不是细胞；去卷积之前不报告细胞类型比例" |
| Visium HD 8/16 µm | **bin** | "bin 是几何划分，不对应细胞边界" |
| Visium HD 2 µm | **不作为观测单位** | "2 µm bin 仅作为细胞重建的输入" |
| Xenium / CosMx / MERFISH | **分割后的细胞** | "细胞边界来自 <厂商/自做> 分割，比例随分割方法变化" |

**操作化**：把它写成一个变量，在每张图的标题里自动带出来。

```python
OBS_UNIT = "spot (Visium 55 µm, not a cell)"
ax.set_title(f"{title}\n[n={adata.n_obs} {OBS_UNIT}]", fontsize=9)
```

这样**任何人打开任何一张图，都不可能把 spot 误读成细胞**——比在报告里写一句声明可靠得多。

### 1.2 六件事清单

| # | 要钉死的 | 谁的决定 | 定不下来会怎样 |
| :--- | :---: | :---: | :---: |
| 1 | 平台与观测单位 | 数据决定 | 整条管线选错 |
| 2 | **解剖学方向**（哪边是上 / 参照结构） | **客户** | y 轴翻转无从验证 |
| 3 | 分组、重复、要对比什么 | **客户** | 做完才发现没有对照 |
| 4 | **有没有同组织的 scRNA 参考** | **客户** | 去卷积做不了 |
| 5 | 参考基因组、bin 尺度、各步方法与参数 | **我方** | —（自己定，写进 Methods） |
| 6 | 交付形态（全量包 / 补充轮） | **客户** | 交付时才发现口径不对 |

### 1.3 先判断"能不能做跨条件统计"

```
样本数 ≥ 2 组 × ≥ 2 生物学重复  →  可以做组间比较
只有一个条件（哪怕多个切片）    →  只能做描述 + 空间结构刻画
只有一张切片                    →  只能给模板与判据
```

**单一条件下不存在"差异"这个问题**，不要用切片之间的差别冒充组间差异——
**那是个体差异 + 批次，不是处理效应。**

---

## §2 项目骨架与检查点纪律

### 2.1 目录

```
37_<name>/
├── scripts/
│   ├── 0_sample_table.csv         ← SSOT：样本/切片清单，所有脚本从这里读
│   ├── _common/spatial_utils.py   ← 断言与工具（软链接指向 canonical，不复制）
│   ├── 1_qc.py  2_cluster.py  ...  ← numbered step scripts，先写后跑
├── output_results/                ← 只放正式产物
│   ├── ckpt_seq_01_raw.h5ad       ← checkpoint，前缀区分平台类型
│   └── figures/*.pdf
├── logs/                          ← 带时间戳，永不覆盖
└── superseded_for_comparison/     ← 修正前的旧版归档
```

### 2.2 Checkpoint 的三条规则

| 规则 | 理由 |
| :--- | :---: |
| **前缀区分平台类型**：`ckpt_seq_*` / `ckpt_img_*` | 两类平台的观测单位不同，混用时形状可能碰巧合法 |
| **编号 = 阶段**，`ckpt_seq_01_raw` → `02_qc` → `03_norm` → … | 任何一步崩了可从上一步恢复，不必重头 |
| **写出时同时落一份 `.json` 元信息**（shape、n_obs、关键统计量） | 读回来能立刻核对；也是跨语言文件桥的校验依据 |

```python
def save_ckpt(adata, stage, outdir, platform="seq"):
    """写 checkpoint 并同时落元信息，便于读回时核对。"""
    p = Path(outdir) / f"ckpt_{platform}_{stage}.h5ad"
    adata.write_h5ad(p)
    meta = {"stage": stage, "n_obs": int(adata.n_obs), "n_vars": int(adata.n_vars),
            "obs_cols": list(adata.obs.columns),
            "X_sum": float(adata.X.sum()), "written": datetime.now().isoformat()}
    p.with_suffix(".json").write_text(json.dumps(meta, indent=2))
    return p
```

### 2.3 永不覆盖

**任何结果目录一律不 `rm -rf`**，包括以"干净重跑"为由。
重跑前先移走旧版到 `superseded_for_comparison/<产物类型>/v<N>_<日期>_<缺陷简述>/`，
**并同时存产生该版本的脚本快照**，使"错在哪"可直接 `diff`。

---

## §3 逐阶段最佳实践

### 3.1 读入与坐标

| 做什么 | 为什么 |
| :--- | :---: |
| 读入后**立刻**打印 `shape`、`obsm['spatial']` 范围、`in_tissue` 分布 | 三个数就能发现绝大多数配准问题 |
| **立刻断言坐标合法性**（唯一值占比、无 NaN） | 坐标大面积重复 = 读错了列或配准失败 |
| **立刻断言 y 轴方向** | 见 §4.1；这是空间转录组最经典的静默错误 |
| 记录 `uns['spatial']` 里有没有图像 | 没有图像 ⇒ 无法目视核对方向，必须在报告里声明 |

> **y 轴的本质**：图像坐标系 y 向下（行号增大 = 往下），绘图坐标系 y 向上。
> `matplotlib` 默认不翻转 ⇒ **不显式处理就得到上下镜像的组织**。
> 镜像之后**图正常、聚类正常、统计正常，只有解剖方向是反的**——
> 而解剖方向恰恰是空间转录组的全部意义所在。

### 3.2 QC：空间感知，不是照搬 scRNA

| 做什么 | 不做什么 |
| :--- | :---: |
| 先按 `in_tissue` 过滤，**记录保留比例**；<20% 要查配准 | 不要跳过这一步直接聚类 |
| 常规指标（counts / genes / mito）**照算** | **不要照搬 scRNA 的 MAD 阈值就算完** |
| **加一项空间局部统计**：把 counts 画在空间上，看有没有整片偏低的区域 | 不要只看直方图——直方图没有空间信息 |
| 低质量区域要判断是**组织破损**还是**真实的低细胞密度结构** | 不要无条件当离群剔除 |

**关键区别**：scRNA 里"离群细胞"大概率是技术问题；
**空间数据里"离群 spot"可能是一个真实的解剖结构**（如心脏的瓣膜、脂肪、血管腔）。
**剔除它等于剔除生物学。**

### 3.3 归一化 / 聚类 / 空间域

| 做什么 | 说明 |
| :--- | :---: |
| 归一化与降维基本同 scRNA | 但要意识到相邻 spot 不独立（空间自相关） |
| **区分"表达聚类"与"空间域"** | 表达聚类 = 只看基因；空间域 = 表达 + 位置。两者不是一回事 |
| **域数量至少扫 3 个设置** | 域的数量是超参数，不是数据告诉你的 |
| 报告里给**稳定性证据**：换设置后主要结构还在吗 | 结构随参数翻转 ⇒ 它是参数的产物不是组织的 |
| 多切片时检查**域能否跨切片复现** | 只在一张切片出现的域，优先怀疑是批次或伪影 |

### 3.4 SVG（空间可变基因）

| 做什么 | 理由 |
| :--- | :---: |
| **Moran's I 必跑**，作为基线 | 14 方法基准里它排第四（0.76 vs 最优 SPARK-X 0.88），复杂方法赢不过它就没有使用理由 |
| 有条件就再跑一个方法并取交集 | 不存在单一最优 SVG 方法 |
| **只有一种方法可用时，把这件事写进 Limitations** | 本机 SpatialDE 不可用（scipy 1.17 移除 `scipy.misc.derivative`），R 侧 SPARK-X/nnSVG 未装 ⇒ 现状就是只有 Moran's I |
| 报告里写明**该方法对哪类模式不敏感** | Moran's I / SPARK-X / nnSVG 对"小区域高表达、其余为零"这类模式准确率都低 |

> **诚实优于全面**：只有一把尺子时，说清"这把尺子量不到什么"，
> 比假装做了多方法互证有价值。

### 3.5 去卷积（仅测序型）

**三个前置断言，缺一不做：**

| # | 断言 | 不满足怎么办 |
| :--- | :---: | :---: |
| 1 | **参考是同组织**（最好同研究、同批次） | **不做去卷积**，别用别的组织凑 |
| 2 | 参考的细胞类型标注可信且粒度合适 | 先修注释 |
| 3 | 参考与空间数据的基因有足够交集 | 交集太小则结果不可信，记录交集数 |

**产出后两个断言**：每个 spot 的比例**和为 1**、**无负值**（§4.3）。

**报告口径**：去卷积给的是**估计比例**，是**模型产物不是观测**。
写法上必须与实测量分开——"estimated proportion"，不能写成"the spot contains X% cardiomyocytes"。

### 3.6 邻域 / 空间互作

- 邻域富集、共定位、配受体分析的输出是**"空间上邻近 + 表达相容"**，
  **不是"确实发生了细胞通讯"** ⇒ 一律写成假说，不写成结论。
- 邻域图的构建方式（k 近邻 vs 半径 vs Delaunay）会改变结果 ⇒ 记录并说明。

---

## §4 Python 空间断言库（可直接复制）

> skill §5 的 4 个断言此前**只有 R 实现**。以下是 Python 版，
> canonical 位置：`37_spatial_visium_heart_pilot/scripts/_common/spatial_utils.py`，
> 其它项目**软链接引用，不复制**。

### 4.1 y 轴方向

```python
def assert_yaxis_orientation(adata, spatial_key="spatial", expect="image_down"):
    """空间转录组最经典的静默错误：y 轴翻转后图正常、聚类正常，只有解剖方向是反的。

    expect="image_down": 图像坐标系，y 增大 = 组织更靠下 ⇒ 绘图时必须 invert_yaxis()
    返回 (ymin, ymax, 建议的 origin 设置)，并在 uns 里留痕供下游图函数读取。
    """
    xy = adata.obsm[spatial_key]
    assert xy.shape[1] >= 2, f"spatial 坐标维度异常: {xy.shape}"
    assert np.isfinite(xy).all(), "spatial 坐标含 NaN/Inf"
    ymin, ymax = float(xy[:, 1].min()), float(xy[:, 1].max())
    adata.uns["_yaxis_convention"] = expect       # 留痕：下游出图函数据此翻转
    return ymin, ymax, expect
```

**配套的出图约定**（这一半同样重要，断言只是留痕）：

```python
def spatial_scatter(adata, color, ax, spatial_key="spatial"):
    xy = adata.obsm[spatial_key]
    ax.scatter(xy[:, 0], xy[:, 1], c=color, s=6, linewidths=0)
    if adata.uns.get("_yaxis_convention") == "image_down":
        ax.invert_yaxis()                          # ← 不加这一行，组织上下镜像
    ax.set_aspect("equal")
```

### 4.2 坐标合法性与 in_tissue

```python
def assert_spatial_coords(adata, spatial_key="spatial", min_unique_frac=0.5):
    """坐标大面积重复 = 读错了列或配准失败。"""
    xy = adata.obsm[spatial_key]
    n_unique = len({tuple(r) for r in xy})
    frac = n_unique / len(xy)
    assert frac >= min_unique_frac, (
        f"坐标唯一值占比仅 {frac:.1%}（{n_unique}/{len(xy)}），疑似读错列或配准失败")
    return frac

def assert_in_tissue_filtered(adata, col="in_tissue", min_keep=0.20):
    """组织外 spot 必须剔除；保留比例过低说明配准或切片有问题。"""
    if col not in adata.obs:
        raise AssertionError(f"缺少 {col} 列，无法确认是否已按组织过滤")
    vals = set(pd.unique(adata.obs[col]))
    assert vals <= {1, True, "1"}, f"{col} 仍含组织外 spot: {vals}"
    return True
```

### 4.3 去卷积比例

```python
def assert_deconv_proportions(mat, tol=1e-4):
    """去卷积输出必须：无负值、每行和为 1。不满足则后续所有比例比较都是错的。"""
    arr = np.asarray(mat, dtype=float)
    assert np.isfinite(arr).all(), "去卷积结果含 NaN/Inf"
    assert (arr >= -tol).all(), f"去卷积结果含负值，最小 {arr.min():.3g}"
    rs = arr.sum(axis=1)
    assert np.allclose(rs, 1.0, atol=1e-3), (
        f"每个 spot 的比例和不为 1：范围 [{rs.min():.4f}, {rs.max():.4f}]")
    return True
```

### 4.4 图上的点数必须可核对

```python
def assert_points_plotted(ax, expected_n):
    """防抽稀/截断静默丢点。'最多取 N 条' 用 break 实现 = 空间截断，不是抽稀。"""
    drawn = sum(c.get_offsets().shape[0] for c in ax.collections)
    assert drawn == expected_n, f"图上 {drawn} 点 ≠ 数据 {expected_n} 点"
    return drawn
```

### 4.5 参考同组织

```python
def assert_reference_same_tissue(sp, ref, tissue_key="tissue", expected=None):
    """去卷积的硬约束在数据不在算法：没有同组织参考就不做。"""
    ref_t = set(pd.unique(ref.obs[tissue_key])) if tissue_key in ref.obs else set()
    assert ref_t, f"参考缺少 {tissue_key} 标注，无法确认是否同组织"
    if expected:
        assert ref_t <= set(expected), f"参考组织 {ref_t} 不在允许范围 {expected}"
    shared = len(set(sp.var_names) & set(ref.var_names))
    assert shared >= 1000, f"空间与参考的基因交集仅 {shared}，去卷积不可信"
    return {"ref_tissue": sorted(ref_t), "shared_genes": shared}
```

### 4.6 🔴 去卷积前的基因标识符对齐（2026-09-17 实地发现，三个坑连环）

`37_spatial_visium_heart_pilot` 第一次跑去卷积时**连续被三件事挡住**，全部是静默的。
这一组是本文档最值钱的一节，因为它们环环相扣，只修前一个还是 0 结果。

| # | 坑 | 表现 | 修法 |
| :--- | :---: | :---: | :---: |
| 1 | **参考用 Ensembl ID，空间用基因符号** | 基因交集 **0** | 用 `ref.var["feature_name"]` 重建 `var_names` |
| 2 | **`.raw` 是一条暗线** | 改了 `.var_names`，`.raw` **不受影响**；而 `sc.tl.rank_genes_groups` 默认 `use_raw=True` ⇒ marker 名单仍是 Ensembl ID | `ref.raw = None` 且显式 `use_raw=False` |
| 3 | **Tangram 在训练基因为 0 时不报错** | 打印一行 INFO `Begin training with 0 genes` 后**正常跑完 300 epoch**，输出均匀的垃圾比例；无异常、无警告、形状合法 | 对训练基因数下硬断言 |

```python
# 1) 标识符对齐（放在任何断言之前）
if len(set(sp.var_names) & set(ref.var_names)) == 0 and "feature_name" in ref.var:
    ref.var["ensembl_id"] = ref.var_names
    ref.var_names = ref.var["feature_name"].astype(str).values
    ref.var_names_make_unique()

# 2) 断掉 .raw 这条暗线
ref.raw = None
sc.pp.normalize_total(ref, target_sum=1e4); sc.pp.log1p(ref)
sc.tl.rank_genes_groups(ref, groupby=CT_KEY, method="wilcoxon", use_raw=False)

# 3) 训练基因数硬断言（Tangram 自己不会拦）
tg.pp_adatas(ad_sc, ad_sp, genes=markers)
n_train = len(ad_sc.uns["training_genes"])
assert n_train >= 100, (
    f"训练基因仅 {n_train} 个，多半是基因标识符没对齐；"
    f"参考 {list(ad_sc.var_names[:3])} vs 空间 {list(ad_sp.var_names[:3])}")
```

> **共同教训**：**"函数没报错"和"函数拿到了数据"是两回事。**
> 凡是"两个对象按名字取交集"的地方，都要把交集大小断言出来——
> 交集为 0 在几乎所有库里都是合法输入。

### 4.7 `sc.concat` 会丢弃不一致的 `.var` 列

逐切片算完 HVG 再 `sc.concat` 合并，**`highly_variable` 列不会存活**
（各切片的值不同，concat 默认丢弃）。下游 `if "highly_variable" in adata.var` 会静默回退到全基因。

```python
merged = sc.concat(pieces, ...)
assert "highly_variable" in merged.var, "HVG 标记未在 concat 后存活，下游会静默回退到全基因"
```

**这次的影响是"更慢但更完整"（无偏基因集），不是错误** —— 但日志里写成"检验 N 个 HVG"就是错的。
**跨 `concat` 的 `.var` 列一律不可假定存活。**

---

## §5 交付前自审清单

**逐条打勾，并留下可回读的命令。** 任何一条答不上来 = 还没做完。

| # | 检查 | 怎么验 |
| :--- | :---: | :---: |
| 1 | 观测单位是否出现在每张图的标题里 | `grep -c "OBS_UNIT" scripts/*.py` 与图目视 |
| 2 | y 轴方向断言是否跑过、结果是什么 | 日志里搜 `_yaxis_convention` |
| 3 | `in_tissue` 保留比例 | 日志里的数字，与 §3.2 阈值比 |
| 4 | 每个 checkpoint 的 `n_obs` 是否单调合理 | 读各 `ckpt_*.json` 对比 |
| 5 | 域数量扫了几个设置、结构是否稳定 | 稳定性图 + 表 |
| 6 | SVG 用了几种方法，Limitations 里写了吗 | 报告 §Limitations |
| 7 | 去卷积参考是否同组织、基因交集多少 | `assert_reference_same_tissue` 的返回值 |
| 8 | 去卷积比例是否和为 1、无负值 | `assert_deconv_proportions` 通过 |
| 9 | 每张图点数与 `n_obs` 对得上吗 | `assert_points_plotted` |
| 10 | **有没有一项用独立来源互证** | 见下 |
| 11 | 图件是否只有 PDF | `ls output_results/figures/` |
| 12 | 同图内语义不同的 panel 是否共用了配色 | 目视 + 配色 dict 检查 |

> **第 10 条是最容易跳过、也最值钱的一条**：
> 至少有一个结论要用**与主线不同的数据或方法**验证一次。
> 例：去卷积算出某域富含 cardiomyocyte ⇒ 用该域 marker 基因的原始表达独立看一眼，
> **而不是再跑一遍去卷积**。同一条流程自证不算互证。

---

## §6 报告口径：观测 vs 模型产物

**必须分开写的三类：**

| 类别 | 例子 | 写法 |
| :--- | :---: | :---: |
| **观测量** | counts、检出基因数、spot 坐标、in_tissue | 直接陈述 |
| **模型产物** | 去卷积比例、域标签、聚类编号、分割出的细胞 | 必须带"estimated / inferred / assigned"，并说明方法 |
| **假说** | 邻域富集推出的细胞互作 | 写成"consistent with"，不写成"demonstrates" |

**必须声明的三件事**（成像型平台尤其）：

1. **分割来源**：厂商 / 自做 / 未做
2. **去卷积参考的来源与是否同组织**
3. **panel 覆盖范围**（成像型）——**"未检出"常常是 panel 里没有这个基因，不是不表达**

**单一条件 / 单样本时**：明确承认做不了跨条件统计，只给描述与模板。
**这不是示弱，是把结论的适用边界说清楚**——比给一张站不住的显著性表有价值得多。

---

## §7 本文不覆盖的

| 问题 | 去哪 |
| :--- | :---: |
| R 还是 Python、各任务谁更强、基准数字 | `spatial_transcriptomics_R_vs_Python_ecosystem_20260910.md` |
| 平台分流、逐任务判据与动作、本机资产 | [`/spatial` skill](/home/gao/.claude/skills/spatial/SKILL.md) |
| 细胞层面的通用规则（QC/注释/pseudobulk/富集） | [`/scrna` skill](/home/gao/.claude/skills/scrna/SKILL.md) |
| 出版级配色与图件规范 | `/scientific-figure-making` skill |
| 报告体例、交付目录命名 | `/report` · `/delivery` skill |

---

## §8 本文的事实来源

| 内容 | 来源 |
| :--- | :---: |
| §4.1–§4.5 断言库的代码 | **本文原创**，已由 `37_spatial_visium_heart_pilot` 实地使用；`assert_reference_same_tissue` 与 `assert_deconv_proportions` **在该项目中真的拦下了错误** |
| §4.6 三连环坑、§4.7 concat 丢 `.var` | **2026-09-17 在 `37_spatial_visium_heart_pilot` 实地踩到并定位**，非文献 |
| SVG 基准数字（Moran's I 0.76 / SPARK-X 0.88，14 方法 × 96 数据集） | 转引自 `spatial_transcriptomics_R_vs_Python_ecosystem_20260910.md` |
| 本机 SpatialDE 不可用、R 空间栈未装、cell2location 因 3 GB 显存不可用 | `/spatial` skill §2.2（2026-09-16 实测） |
| §1–§3 的各条实践 | **我的判断**，依据是 skill 的静默错误清单 + 既往项目的实际失误 |
| §5 自审清单第 10 条（独立来源互证） | 既往项目的实际教训，非本次实测 |
