# Python 的「表格类」数据结构全景：到底有几种，各管什么

> 建立日期：2026-09-14
> 用途：回答「Python 里 DataFrame 这类结构一共有几种」，并说清每种的本质、适用场景和静默陷阱。
> 姊妹篇：`/home/gao/Utilities/R/R_tabular_data_structures.md`（R 的五种），§10 是两边的对照表。
> 本文所有数字与行为均为**本机实测**，实测环境见 §13。

---

## §0 直接回答：几种？

**分三层看，日常真正要掌握的只有 3 个。**

| 层 | 结构 | 本机状态 |
| :--- | :---: | :---: |
| **① 日常主力（3 个）** | `pandas.DataFrame` / `numpy.ndarray` / `AnnData` | 全部已装 |
| **② 标准生态（再 5 类）** | numpy structured array、`pyarrow.Table`、`scipy.sparse`、`xarray`、原生 dict/list | 全部已装 |
| **③ 可选第三方（3 类）** | `polars`、`duckdb`、`dask` | **均未装**（PyPI 可获取，见 §9） |

**所以标准答案是：常用 8 类，其中 3 个是主力。**

和 R 最大的体感差别：**R 把这些能力塞进 base 语言**（data.frame / matrix / table 都是内置），
**Python 全部靠第三方库**——语言本身只有 `dict` / `list` / `tuple`。
所以 Python 这边不存在"继承关系图"，只有**生态位分工**。

### 一句话区分

| 结构 | 本质 | 什么时候用 |
| :--- | :---: | :---: |
| `pandas.DataFrame` | **dict of Series**，列式，每列一个 dtype | 默认选择：异构表格、分析、IO |
| `numpy.ndarray` | 连续内存块 + shape，**全表一个 dtype** | 纯数值矩阵、线性代数、传给算法库 |
| structured array | ndarray 但**每列可不同类型**，行式存储 | 读二进制/固定格式记录，少用 |
| `pyarrow.Table` | 列式、**不可变**、跨语言内存格式 | parquet IO、和 R 互通、pandas 后端 |
| `scipy.sparse` | 只存非零元 | 单细胞 counts、任何 90%+ 是零的矩阵 |
| `AnnData` | **矩阵 + 两张 DataFrame 注释**的容器 | 单细胞（Scanpy 生态的唯一货币） |
| `xarray` | **带标签的 N 维数组** | 3 维以上、时空数据、多模态 |
| dict / list | 语言原生 | 小数据、JSON、构造上面这些的原料 |

### 🔴 对做单细胞 / RNAseq 的人最要紧的三条

全文 12 条陷阱在 §12，但**这三条会不报错地产出错误结果**，先记住它们：

| # | 陷阱 | 为什么最危险 | 防法 |
| :--- | :---: | :---: | :---: |
| **1** | **AnnData 与 R 的维度是转置的**：AnnData 是**细胞 × 基因**，Seurat / SingleCellExperiment 是**基因 × 细胞** | 转置后代码照跑、图照出，**所有生物学结论都是错的**；细胞数恰好等于基因数时连报错都没有 | 跨语言搬数据必须转置；见 §6 |
| **2** | **pandas 的 view/copy 不确定**：取列是 view（改原表），布尔/位置切片是 copy（不改） | 比 R `data.table` 的确定引用语义更难推理；实测 `SettingWithCopyWarning` **该警告时也可能不警告** | 要副本就显式 `.copy()`；要改原表用 `df.loc[行,列]=值` 单步赋值；见 §2.3 |
| **3** | **int 列混入 NaN 就变 float64** | counts 静默变浮点，下游要整数的接口拒收，大整数还丢精度 | 用 `dtype="Int64"`（大写 I）；见 §2.1 |

第 1 条是这份文档里唯一一条**跨语言**的陷阱，也是 Python↔R 单细胞互转的头号错误来源。

---

## §1 全景：两个家族 + 一条分界线

和 R 一样，真正的分界线是**同构 vs 异构**：

```
【异构家族 —— 每列可以不同类型】      【同构家族 —— 全表一个 dtype】

   pandas.DataFrame                        numpy.ndarray
   (dict of Series，列式)                  (连续内存 + shape)
          │                                       │
   pyarrow.Table                            scipy.sparse
   (列式，不可变)                            (只存非零元)
          │                                       │
   structured array                          xarray.DataArray
   (行式，罕用)                              (ndarray + 维度标签)

              ↘                           ↙
                    AnnData
         (X = 同构矩阵，obs/var = 异构 DataFrame)
              —— 生信里把两个家族缝在一起的容器
```

**`AnnData` 的设计恰恰是这条分界线的产物**：表达量必须是同构的稀疏矩阵（省内存、能算），
但细胞和基因的注释天然异构（字符串、分类、数值混在一起）。
它把 `X`（矩阵）和 `obs`/`var`（两张 DataFrame）绑在一个对象里并保证维度对齐。

### 一条命令定死身份

```python
type(x), getattr(x, "dtype", None), getattr(x, "shape", None), getattr(x, "dtypes", None)
```

| 对象 | `type()` | 类型信息在哪 | 有行标签吗 |
| :--- | :---: | :---: | :---: |
| DataFrame | `pandas.DataFrame` | `.dtypes`（每列一个） | `.index` |
| Series | `pandas.Series` | `.dtype`（单个） | `.index` |
| ndarray | `numpy.ndarray` | `.dtype`（全表一个） | 无 |
| structured array | `numpy.ndarray` | `.dtype` 是复合类型 | 无 |
| pyarrow.Table | `pyarrow.Table` | `.schema` | 无（只有列） |
| csr_matrix | `scipy.sparse.csr_matrix` | `.dtype` | 无 |
| AnnData | `anndata.AnnData` | `X.dtype` + `obs.dtypes` | `.obs_names` / `.var_names` |
| DataArray | `xarray.DataArray` | `.dtype` | `.coords` |

---

## §2 `pandas.DataFrame` —— 默认选择

### 本质：dict of Series

**DataFrame = 一组共享同一个 `index` 的 Series**，按列存储，**每列自己一个 dtype**。
这和 R 的 data.frame（list of vectors）在概念上一致。

```python
df = pd.DataFrame({"gene": ["A","B","C"], "tpm": [10, 2, 30]})
type(df["tpm"])     # pandas.Series  —— 取一列得到的是 Series
df.dtypes           # {'gene': dtype('O'), 'tpm': dtype('int64')}
df.index            # RangeIndex [0, 1, 2]
df.columns          # Index ['gene', 'tpm']
```

三个核心类型：**`DataFrame`（二维）→ `Series`（一维）→ `Index`（标签）**。
`Index` 是 pandas 相对 R 最大的加强项 —— 见 §2.4。

### §2.1 🔴 头号陷阱：int 列混入 NaN 就变 float64

这是 pandas 最经典的坑，实测：

```python
pd.DataFrame({"n":[1,2,3]})["n"].dtype      # int64
pd.DataFrame({"n":[1,2,None]})["n"].dtype   # float64  ← 值变成 [1.0, 2.0, nan]
```

后果：**counts 变成浮点数**，喂给要求整数的接口（如 DESeq2 风格的工具）会被拒；
大整数还可能丢精度（float64 只能精确表示 2^53 以内的整数）。

**解法：nullable 整数类型**
```python
pd.array([1,2,None], dtype="Int64")   # 注意大写 I —— dtype 保持 Int64，缺失值是 <NA>
```
实测值为 `[1, 2, <NA>]`，dtype 是 `Int64`，不再是 float。

### §2.2 🔴 `.values` / `.to_numpy()` 的类型强制

和 R 的 `as.matrix()` 同一类陷阱，但**行为不同**：

```python
m = pd.DataFrame({"gene":["A","B"], "tpm":[10.5, 2.3]})
m.values.dtype       # dtype('O')  ← object 数组
m.values.sum()       # TypeError
m[["tpm"]].values.dtype   # float64 ← 纯数值子集才正常
```

**和 R 的关键差别**：R 的 `as.matrix()` 把数值**真的变成字符串** `" 2.3"`（还补空格）；
Python 退化成 `object` 数组，**里面的 `10.5` 仍然是 float 对象**，只是容器失去了同构性。
所以 Python 这边 `as.numeric()` 式的抢救不必要，但 `.sum()` 之类的向量化运算会直接 `TypeError`。

**防法一样**：只对纯数值子集取 `.to_numpy()`：
```python
df.select_dtypes("number").to_numpy()
```

### §2.3 🔴 view vs copy —— 比 R 的 data.table 更难预测

R 的 `data.table` 引用语义虽然危险，但**确定**（`:=` 一定改原对象）。
pandas 的麻烦在于**不确定**。实测各操作对原表的影响：

| 操作 | 改到原表了吗 |
| :--- | :---: |
| `df["a"]` 取列后改 | **是**（是 view） |
| `df.loc[:, "a"]` 取列后改 | **是** |
| `df[df.a > 1]` 布尔切片后改 | 否（是 copy） |
| `df.iloc[0:2]` 位置切片后改 | 否 |
| `df.copy()` 后改 | 否 |
| `df.loc[0, "a"] = 99` 直接赋值 | **是**（正确写法） |

**规则：取列是 view，布尔/位置切片是 copy。**

更麻烦的是 `SettingWithCopyWarning` **不可靠** —— 实测在 pandas 2.3.3 下，
`sub = df[df.tpm>1]; sub["tpm"]=0` 这种写法**没有触发警告**，原表也没被改。
警告的有无不能当作判断依据。

**三条保命规则**：
1. 想要独立副本 → 显式 `.copy()`，别赌。
2. 想改原表 → 用 `df.loc[行, 列] = 值` **单步赋值**，不要链式（`df[...][...] = ...`）。
3. 知道自己在哪个 pandas 版本上（见下）。

**⚠ Copy-on-Write 的版本差异**：本机 pandas 2.3.3 实测 `pd.options.mode.copy_on_write` 是 **`False`**。
pandas 官方警告文本明确写着 CoW "will become the default behaviour in pandas 3.0"。
**升到 pandas 3.0 后上表会变**（链式赋值将永远不影响原表）。
现在就想按新语义写，可以主动打开：
```python
pd.options.mode.copy_on_write = True
```

### §2.4 `Index` —— R 的 rownames，但强得多

```python
e = pd.DataFrame({"tpm":[10,2]}, index=pd.Index(["g1","g2"], name="gene"))
e.reset_index()        # index 变成普通列 -> columns = ['gene', 'tpm']
df.set_index("gene")   # 反向
pd.MultiIndex.from_tuples([("A","x"), ("A","y")])   # 多层索引
```

比 R 的 rownames 多出来的能力：**可以有名字、可以多层（MultiIndex）、可以非唯一、
参与自动对齐**。

**自动对齐是把双刃剑**，实测：
```python
s1 = pd.Series([1,2,3],    index=["a","b","c"])
s2 = pd.Series([10,20,30], index=["c","b","a"])   # 顺序【相反】
(s1 + s2).to_dict()    # {'a': 31, 'b': 22, 'c': 13}
```
它按**标签**配对（a 配 a），**不按位置**。R 的向量相加是纯按位置的 ——
**从 R 过来的人最容易在这里出错**：以为在做逐位置运算，实际 pandas 悄悄重排了。
好处是不会错配，坏处是如果你本意就是按位置，得先 `.to_numpy()` 或 `.reset_index(drop=True)`。

**⚠ 和 R 一样的丢失风险**：`to_numpy()` / `.values` **会丢掉 index**，
实测 `e.to_numpy()` 只剩 `(2, 1)` 的数组，`g1`/`g2` 没了。
基因名在 index 里的表，转 numpy 前先 `reset_index()` 或单独存一份 `index`。

### §2.5 dtype 与内存：`category` 不是万能的

很多教程说"字符串列转 `category` 省内存"，**这话只在重复度高时成立**。
20 万行的实测：

| 唯一值个数 | object | category | 结论 |
| :--- | :---: | :---: | :---: |
| 200,000（全唯一） | 12.8 MB | 17.8 MB | **❌ 反而更大** |
| 1,000 | 12.8 MB | 0.5 MB | ✅ 省 96% |
| 24 | 12.8 MB | 0.2 MB | ✅ 省 98% |

**全唯一时更大**，因为 categories 本身要完整存一份、codes 又要再存一份。

**⇒ 实务判断**：样本名、细胞类型、分组标签（重复度高）→ 转 `category` 收益巨大；
**基因 ID、barcode（几乎全唯一）→ 不要转**。

另一条路是 **Arrow 后端的字符串**，实测 20 万个唯一字符串只要 **4.0 MB**（object 13.8 MB）：
```python
pd.array(lst, dtype="string[pyarrow]")
df.convert_dtypes(dtype_backend="pyarrow")
```
对全唯一的基因 ID 列，这是比 category 更对的解法。

### §2.6 `groupby` 的 `observed` —— 对应 R 的「0 计数格」

R 的 `table()` 会把没出现的 factor level 也列成 0，pandas 这边要显式要求：

```python
d.groupby("cond", observed=False).size()   # {'KO':2, 'WT':1, 'Mut':0}  ← 保留空组
d.groupby("cond", observed=True).size()    # {'KO':2, 'WT':1}           ← 默认
d.cond.value_counts()                      # {'KO':2, 'WT':1, 'Mut':0}  ← 保留
```

**pandas 2.x 起 `groupby` 默认 `observed=True`**（不产生空组），但 `value_counts()` 对
categorical **保留** 0 格。两者默认不一致 —— 算比例时分母会差，必须明确自己要哪种。

---

## §3 `numpy.ndarray` —— 同构数值的地基

### 本质

**连续内存块 + `shape` + 一个 `dtype`**。整个数组只能有一种类型。
对应 R 的 `matrix`，但 numpy 原生就是 N 维的（R 的 matrix 恰好 2 维、array 才是 N 维）。

```python
a = np.arange(6).reshape(2, 3)
a.dtype    # int64  —— 全表一个
a.shape    # (2, 3)
```

**没有行列标签**。要标签就得上 pandas 或 xarray。

### 为什么还要用它

1. **线性代数只认 ndarray**：`@`、`np.linalg.svd`、`scipy` 全家
2. **sklearn / torch 等算法库的输入**基本都是 ndarray（或能零拷贝转过去）
3. **向量化运算不经过 pandas 的 dtype 分派**，大矩阵上更快
4. **内存可控**：`float32` 能直接把表达矩阵砍半（pandas 默认 float64）

### structured array 与 recarray（了解即可）

numpy 也能做"每列不同类型"，但是**行式存储**：

```python
sa = np.array([("A",10.5), ("B",2.3)], dtype=[("gene","U10"), ("tpm","f8")])
sa["tpm"]                      # array([10.5, 2.3])
ra = sa.view(np.recarray)      # 之后可以 ra.tpm 属性访问
```

实测小数据上它比 DataFrame 省内存（96 B vs 264 B），
但**行式存储在大表上按列运算会慢**，而且没有 pandas 的任何分析 API。

**⇒ 结论：除非在读固定宽度的二进制记录格式，否则直接用 pandas。**

---

## §4 `pyarrow.Table` —— 列式、不可变、跨语言

```python
t = pa.table({"gene":["A","B"], "tpm":[10.5, 2.3]})
t.schema          # gene: string, tpm: double
t.to_pandas()     # → DataFrame（常可零拷贝）
pa.Table.from_pandas(df)
```

三个特点：**列式**、**不可变（immutable）**、**跨语言**。

不可变意味着**没有原地修改** —— 每次变换产生新 Table。这和 pandas 的 view/copy 泥潭相比
反而是优点：语义完全确定。

**什么时候直接碰它**：

| 场景 | 说明 |
| :--- | :---: |
| parquet / feather 读写 | `pd.read_parquet()` 底层就是它 |
| 和 R 互通 | R 的 `arrow` 包读同一个 parquet，**零转换损失** |
| pandas 的 Arrow 后端 | `df.convert_dtypes(dtype_backend="pyarrow")`，实测 dtype 变成 `int64[pyarrow]` |
| 大字符串列 | 见 §2.5，比 object 省 3 倍 |

**⇒ 多数时候你不直接写 pyarrow 代码，但它在 `read_parquet` 和 Arrow dtype 背后干活。**
和 R 交换大表时，**parquet 是比 CSV 好得多的格式**（保类型、压缩、快）。

---

## §5 `scipy.sparse` —— 单细胞的地基

只存非零元。实测 2000 × 500、95% 为零的矩阵：

| 格式 | 大小 | 擅长 |
| :--- | :---: | :---: |
| dense ndarray | 8.0 MB | —— |
| `csr_matrix` | **0.60 MB** | 按**行**切片（= 按细胞取子集） |
| `csc_matrix` | **0.60 MB** | 按**列**切片（= 按基因取子集） |
| `coo_matrix` | 0.79 MB | 构建和格式转换，**不支持索引** |

省 **92%**。真实 scRNA 数据零值占比 90–95%、矩阵大得多，省下的是**几十 GB 量级**。

**三条实务**：
1. **AnnData 的 `X` 默认就是 `csr`** —— 因为单细胞最常见的操作是按细胞取子集。
2. **要反复按基因切片就转 `csc`**（`X.tocsc()`）。实测 2000 × 5000、95% 为零的矩阵，
   各取 200 次：

   | 切片方向 | csr | csc |
   | :--- | :---: | :---: |
   | 按列（基因） | 0.089 s | **0.007 s（快 12.3×）** |
   | 按行（细胞） | **0.007 s（快 14.7×）** | 0.107 s |

   **选错格式就是一个数量级的差距**，而且不报错、只是慢。
3. 🔴 **绝不对大稀疏矩阵随手 `.toarray()` / `np.asarray()`** —— 瞬间展开成 dense，
   这是单细胞分析里最常见的 OOM 死因。和 R 那边对 `dgCMatrix` 用 `as.matrix()` 是同一个错误。

---

## §6 `AnnData` —— 单细胞的标准容器

Scanpy 生态的唯一货币。**它不是 DataFrame，是一个把矩阵和两张 DataFrame 绑在一起的容器。**

### 结构

```
        var (基因注释, DataFrame)  ← n_var 行
             ┌──────────────┐
  obs        │              │
 (细胞注释,  │      X       │   X: n_obs × n_var 的矩阵(通常 csr 稀疏)
  DataFrame) │              │
  ← n_obs 行 └──────────────┘

  layers["lognorm"]  与 X 同形状的其它矩阵（原始/归一化/scaled）
  obsm["X_pca"]      每个细胞的多维表示 (n_obs × k)
  varm[...]          每个基因的多维表示
  uns[...]           非结构化杂项（参数、配色、图）
```

实测一个 100 细胞 × 50 基因的对象：
`X` 是 `csr_matrix (100, 50)`、`obs` 是 `DataFrame (100, 1)`、`var` 是 `DataFrame (50, 1)`、
`obs_names` = `obs.index` = `['cell0', 'cell1', ...]`、`var_names` = `['ENSG00000', ...]`。

### 🔴 维度顺序与 R 相反

**AnnData 是「细胞 × 基因」（obs × var）；R 的 Seurat / SingleCellExperiment 是「基因 × 细胞」。**

跨语言搬数据时**必须转置**，否则维度能对上但含义全错（而且如果细胞数恰好等于基因数，
连报错都不会有）。这是 Python↔R 单细胞互转的头号错误来源。

### 🔴 view 陷阱

```python
sub = a[a.obs.celltype == "T"]
sub.is_view          # True  ← 不是独立对象
sub.obs["new"] = 1   # 实测触发 ImplicitModificationWarning
```

实测 `a[mask]` 返回的是 **view**（`is_view == True`），在上面写入会触发
`ImplicitModificationWarning`，行为不保证。

**正确做法永远是 `.copy()`**：
```python
sub = a[a.obs.celltype == "T"].copy()   # 实测 is_view == False
```
和 pandas 的 view/copy、R data.table 的引用语义是同一类问题，但 AnnData **会明确警告**，
比 pandas 友好。

### 其它要点

- `obs_names` / `var_names` **应当唯一**：`a.var_names_make_unique()` 是标准预处理步骤
  （同一基因 symbol 出现多次时）
- 磁盘格式是 `.h5ad`（HDF5）或 zarr；`ad.read_h5ad(..., backed="r")` 可以**不全量载入内存**
- 多模态（RNA + ATAC + 蛋白）用 `MuData`（本机 0.3.10 已装），它是 AnnData 的字典容器

---

## §7 `xarray` —— 带标签的 N 维数组

定位很好记：

| | 有维度标签 | 维数 |
| :--- | :---: | :---: |
| numpy | ❌ | N 维 |
| pandas | ✅ | **只有 2 维** |
| **xarray** | ✅ | **N 维** |

```python
da = xr.DataArray(np.random.randn(3,4), dims=("gene","sample"),
                  coords={"gene":["g1","g2","g3"], "sample":list("abcd")})
da.sel(gene="g2", sample="c")      # 按【标签】取值，不是按位置
ds = xr.Dataset({"counts": da, "tpm": da*2})   # 多个共享坐标的数组
```

**什么时候真的需要**：三维以上且每维都要标签 —— 时间序列 × 条件 × 基因、
空间转录组的 (x, y, gene)、批量图像。常规 RNAseq 和单细胞用不上，
**AnnData 已经覆盖了生信里 90% 的多维标注需求**。

本机装的是 2026.7.0，配合 zarr 3.1.6 可以做分块的惰性读取。

---

## §8 语言原生结构

Python 本身**没有**表格类型，只有这些原料：

| 形式 | 例子 | 说明 |
| :--- | :---: | :---: |
| dict of lists | `{"gene":["A","B"], "tpm":[1,2]}` | **列式** — `pd.DataFrame(d)` 直接吃 |
| list of dicts | `[{"gene":"A","tpm":1}, ...]` | **行式** — 逐行累积时用，最后一次性转 DataFrame |
| `csv.DictReader` | 标准库 | 逐行流式读，内存恒定 |
| `namedtuple` / `dataclass` | 结构化的一行 | 少量记录、类型提示友好 |

**性能铁律**：**绝不要在循环里 `pd.concat` 或 `df.loc[len(df)] = ...` 逐行追加** ——
每次都复制整张表，是 O(n²)。

实测仅 3000 行就已经是：

| 写法 | 耗时 |
| :--- | :---: |
| 循环 `pd.concat` | 0.63 s |
| 一次性 `pd.DataFrame(list_of_dicts)` | **0.0015 s（快 422×）** |

3000 行就差 422 倍，几万行时会直接挂死。
**正确做法：先收集成 list of dicts，最后一次性构造 DataFrame。**

---

## §9 本机未装但值得知道的三个

**均未安装**（2026-09-14 实测 `import` 失败）。按规则我没有安装任何依赖，仅记录可获取性：

| 库 | 定位 | PyPI 可获取版本（2026-09-14 查） |
| :--- | :---: | :---: |
| `polars` | Rust 写的 DataFrame，多线程 + 惰性求值，大表上比 pandas 快一个量级 | **1.44.2** |
| `duckdb` | 进程内分析型 SQL 引擎，可直接查 parquet/DataFrame 不用先载入 | **1.5.5** |
| `dask` | 把 pandas/numpy 切块并行化，处理超内存数据 | 未查询 |

**该不该装**：
- **polars** 的定位类似 R 的 `data.table`（快、语义确定、无 index 概念）。
  但**生信生态几乎全部围着 pandas 转**（Scanpy、AnnData、pyDESeq2 都返回 pandas），
  引入 polars 意味着边界上到处转换。除非有明确的性能瓶颈，否则不值得。
- **duckdb** 在"几十 GB 的 parquet 里挑几列几行"这种场景很能打，
  而且**能直接查 pandas DataFrame**，边界成本低，比 polars 更容易增量引入。
- **dask** 只有在数据真的超内存时才需要；本机 28 核 / 大内存的配置下，
  先考虑 chunk 循环或 duckdb。

---

## §10 R ↔ Python 对照表

| R | Python | 差异要点 |
| :--- | :---: | :---: |
| `data.frame` | `pandas.DataFrame` | 概念一致（都是 list/dict of columns） |
| `rownames` | `.index` | pandas 的 index 可命名、可多层、参与自动对齐 |
| `tibble` | *(无直接对应)* | pandas 没有"严格版"，但默认就比 R 的 data.frame 严格：实测 `df["nope"]` → **KeyError**，`df.nope` → **AttributeError**，都不像 R 那样静默返回 NULL |
| `data.table` | `polars`（未装）/ pandas | pandas 的 view/copy **不确定**，比 data.table 的确定引用语义更难推理 |
| `matrix` | `numpy.ndarray` (2D) | numpy 原生 N 维；R 的 matrix 恰好 2 维 |
| `array` | `numpy.ndarray` (ND) | 一致 |
| `table()` | `value_counts()` / `crosstab()` | R 默认保留 0 格；pandas `groupby` 默认不保留（见 §2.6） |
| `Matrix::dgCMatrix` | `scipy.sparse.csr_matrix` | R 的 dgC 是**列压缩**；AnnData 默认用**行压缩** csr（因维度是转置的） |
| `SingleCellExperiment` / `Seurat` | `AnnData` | 🔴 **维度转置**：R 是基因×细胞，AnnData 是细胞×基因 |
| `factor` | `pd.Categorical` | 一致；两边都有"未观测到的 level 要不要保留"的问题 |
| `NA` | `np.nan` / `pd.NA` / `None` | 🔴 Python 有**三种**缺失值，且 `np.nan` 会把 int 列变 float |
| `as.matrix(df)` | `df.to_numpy()` | R 混合类型 → **character**；Python → **object**（值仍是原类型） |
| 管道（`%>%` 与原生管道） | 方法链 `.method().method()` | pandas 用 `.pipe()` 接自定义函数 |
| `apply(m, 1, f)` | `np.apply_along_axis` / `df.apply(axis=1)` | 两边都慢，都应优先向量化 |
| `saveRDS` | `pickle` / `.h5ad` / parquet | 跨语言交换用 **parquet**（表）或 **h5ad**（单细胞） |

---

## §11 互转速查

| 从 → 到 | 命令 | ⚠ 注意 |
| :--- | :---: | :---: |
| dict of lists → DataFrame | `pd.DataFrame(d)` | 最常用的构造方式 |
| list of dicts → DataFrame | `pd.DataFrame(records)` | 逐行累积后一次性转，**别在循环里 concat** |
| DataFrame → ndarray | `df.to_numpy()` | 🔴 混合类型 → object；**丢 index**；先 `select_dtypes("number")` |
| ndarray → DataFrame | `pd.DataFrame(a, index=..., columns=...)` | 不传 index/columns 就只有 0,1,2… |
| DataFrame ↔ pyarrow | `pa.Table.from_pandas(df)` / `t.to_pandas()` | 常可零拷贝 |
| DataFrame → parquet | `df.to_parquet(p)` | **和 R 交换大表的首选**，保类型 |
| dense ↔ sparse | `sp.csr_matrix(a)` / `M.toarray()` | 🔴 `.toarray()` 是单细胞 OOM 头号来源 |
| csr ↔ csc | `M.tocsc()` / `M.tocsr()` | 按基因反复切片就转 csc |
| AnnData → DataFrame | `a.to_df()` | 把 X 转成 dense DataFrame，**大对象会爆内存** |
| AnnData 取子集 | `a[mask].copy()` | 🔴 不加 `.copy()` 得到的是 view |
| AnnData ↔ 磁盘 | `a.write_h5ad(p)` / `ad.read_h5ad(p)` | 超大对象用 `backed="r"` |
| DataFrame → Arrow dtype | `df.convert_dtypes(dtype_backend="pyarrow")` | 字符串列省内存 |
| index ↔ 列 | `df.reset_index()` / `df.set_index("gene")` | 转 numpy 前先把基因名挪出来 |

---

## §12 陷阱总清单（按危险程度排序）

| # | 陷阱 | 后果 | 防法 |
| :--- | :---: | :---: | :---: |
| 1 | AnnData 与 R 的**维度转置** | 细胞/基因搞反，**可能完全不报错** | 记死：AnnData = 细胞 × 基因 |
| 2 | 对大稀疏矩阵 `.toarray()` | **瞬间 OOM** | 保持稀疏；必须 dense 就先取子集 |
| 3 | int 列混入 NaN → float64 | counts 变浮点，下游拒收或丢精度 | `dtype="Int64"`（大写 I） |
| 4 | pandas view/copy **不确定** | 改了原表或没改，**两种都可能** | 显式 `.copy()`；改原表用 `.loc[行,列]=值` 单步 |
| 5 | `a[mask]` 返回 AnnData view | 写入行为不保证 | 永远 `.copy()` |
| 6 | `.to_numpy()` 丢 index + 转 object | 基因名丢失 / 运算 TypeError | 先 `reset_index()`，只转数值列 |
| 7 | 循环里 `pd.concat` 追加行 | **O(n²)**，大表上挂死 | 收集 list of dicts，最后一次性构造 |
| 8 | `groupby` 默认 `observed=True` 而 `value_counts` 保留 0 格 | 两处分母不一致 | 显式写 `observed=` |
| 9 | 全唯一列转 `category` | **内存反而变大**（实测 12.8→17.8 MB） | 只对重复度高的列转；基因 ID 用 arrow string |
| 10 | `SettingWithCopyWarning` 不可靠 | 没警告 ≠ 安全 | 别把警告当判据，按规则 4 写 |
| 11 | pandas 3.0 的 CoW 会改变语义 | 现有链式赋值代码行为变化 | 现在就设 `copy_on_write = True` 验证 |
| 12 | `var_names` 不唯一 | 下游按基因名索引取到多行 | `a.var_names_make_unique()` |

**前 3 条是最危险的** —— 都可能**不报错**地产出错误结果。
第 1 条尤其阴险：维度转置后代码照跑，图照出，只是所有生物学结论都是错的。

---

## §13 实测环境与选型建议

### 实测环境（2026-09-14）

| 项 | 版本 |
| :--- | :---: |
| Python | 3.11.16 |
| pandas | 2.3.3 |
| numpy | 2.4.6 |
| pyarrow | 25.0.1 |
| scipy | 1.17.1 |
| anndata | 0.12.19 |
| scanpy | 1.11.5 |
| mudata | 0.3.10 |
| xarray | 2026.7.0 |
| h5py | 3.16.0 |
| zarr | 3.1.6 |
| conda env | `regular_bioinfo` |
| **未安装** | polars / duckdb / dask / vaex / modin / pyspark |

⚠ 本机 `pd.options.mode.copy_on_write` 实测为 **`False`**（pandas 2.3.3 的默认）。
pandas 3.0 起会变成 `True`，§2.3 的表会随之改变。

本文性能与内存数字来自本机单次运行，仅用于表达**量级差异**，不是严格 benchmark。

### 典型 RNAseq / 单细胞流程里各结构的位置

| 阶段 | 用什么 | 理由 |
| :--- | :---: | :---: |
| 读 counts / 大表 | `pd.read_csv` → DataFrame；大文件用 parquet | 几十 GB 级考虑 duckdb |
| 样本表 / 元数据 | DataFrame，分类列转 `category` | 重复度高，省内存且语义清晰 |
| 表达矩阵运算 | `numpy.ndarray`（必要时 `float32`） | 线性代数只认 ndarray |
| 单细胞全流程 | **`AnnData`**（X 为 `csr`） | Scanpy 生态的唯一货币 |
| 多模态 | `MuData` | AnnData 的字典容器 |
| 和 R 交换表格 | **parquet**（`pyarrow`） | 保类型、压缩、R 的 arrow 包直读 |
| 和 R 交换单细胞 | `.h5ad` + `zellkonverter`/`anndataR` | 🔴 注意转置 |
| 出图 | 转 long 格式 DataFrame | seaborn/plotnine 都要 long |

### 三条选型原则

1. **默认用 pandas**，直到有明确的性能证据再考虑别的。生信生态围着它转，换掉的边界成本很高。
2. **单细胞无条件用 AnnData**，不要自己用 DataFrame 拼细胞注释 + 矩阵 —— 维度对齐是它的核心价值。
3. **性能问题优先改 dtype，而不是换库**：`float64→float32` 砍半、
   object→category（重复度高时）省 96%、object→arrow string 省 70% ——
   这些改动一行代码，收益常常比换 polars 还大。
