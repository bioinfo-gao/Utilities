# decoupler 2.x —— API 重组 + 三个静默陷阱

**本机实测版本：decoupler 2.2.0**（`/mnt/ex_8T_SSD/conda_envs/sc_tut_main`，2026-09-17）。
首次触发：proj22 `notebooks/04_conditions/4-3_gene_set_enrichment.py`，
报错 `AttributeError: module 'decoupler' has no attribute 'get_resource'`。

## 1. 扁平 API 全部移除，改成命名空间

`dc.get_*` / `dc.run_*` 一个都不剩，**报错是显式的，不危险**：

| 1.x | 2.x |
| :--- | :---: |
| `dc.get_resource("MSigDB")` + 筛 collection + 去重 + 剥前缀 | `dc.op.hallmark(organism="human")`（已去重、已剥 `HALLMARK_`） |
| `dc.get_collectri(split_complexes=False)` | `dc.op.collectri(remove_complexes=False)` |
| `dc.get_ora_df(df=基因名单, background=...)` | `dc.mt.ora(matrix, net, ...)` —— **入口变了，见 §2** |
| `dc.run_gsea(...)` → `(est, norm_e, pv)` | `dc.mt.gsea(...)` → `(es, padj)`，`times>1` 时 **es 就是 NES** |
| `dc.run_ulm(mat=, source=, target=, weight=)` | `dc.mt.ulm(adata, net, tmin=5)` |
| `dc.get_acts(adata, obsm_key="ulm_estimate")` | `dc.pp.get_obsm(adata, "score_ulm")` |

- net 统一用 **`source` / `target` / `weight`** 三个列名，`source=` / `target=` 参数没了。
- `min_n` → **`tmin`**；结果存在 `obsm["score_<method>"]` 与 `obsm["padj_<method>"]`。
- 第二个返回值**已经是 BH 校正后的 padj**（`mt/_run.py` 里按行 `_fdr_bh_axis1_numba`），
  再套一次 `multipletests` 就是二次校正。

## 2. ⛔ `seed=0` 让置换检验彻底失效 —— 零报错、结果长得像生物学结论

`mt/_gsea.py::_ridx()` 写的是 **`if seed:`** —— **`0` 是 falsy，于是 1000 次置换一次都不打乱**，
null 分布 = 观测值的 1000 份拷贝 ⇒ **NES 恒为 ±1、p 恒为 1、全部不显著**。

```python
# dc.ds.toy() 同一行数据，只换 seed（2.2.0 实测）
seed=0 : NES [ 1.0 ,  1.0 , -1.0 , -1.0 , -1.0 ]   padj 全 1.0
seed=42: NES [ 1.475, 1.265, -1.384, -1.526, -1.51] padj [.081 .157 .157 .118 .118]
```

**函数签名默认 `seed=42`，所以只有"显式传 0"才会中招** —— 而 `seed=0` 正是 1.x 代码里
最常见的写法（1.x 用 `np.random.default_rng(seed)`，0 是合法种子）。**移植时必然踩。**
判据：**NES 全是 ±1.0 或 padj 唯一值只有 1.0 ⇒ 置换没跑。**

## 3. ⛔ `n_up` 是秩阈值，不是个数（ORA）

`mt/_ora.py`：`row = ranks[(row > n_up) | (row < n_bm)]` —— 选中的是 **rank 大于 `n_up`** 的特征，
`rankdata` 升序。**要取 top-k，必须传 `n_up = nvar - k`**（docstring 写的是"数量"，与实现不符）。

2.x 没有"传一个基因名单 + 背景"的入口。等价写法（已与 scipy 双尾 Fisher 逐个对过，
`log_odds_ratio` 与 `padj` 全部 `allclose(atol=1e-6)`）：

```python
mark = pd.DataFrame([[1.0 if g in set(genes) else 0.0 for g in background]],
                    index=[label], columns=background)      # 背景基因名必须唯一
es, padj = dc.mt.ora(mark, net, tmin=5,
                     n_up=len(background) - len(genes),      # ← 秩阈值
                     n_bm=0, n_bg=len(background),
                     empty=False, verbose=False)             # ← 见下
```

- **`empty=False` 必给**：默认 `empty=True` 会把全 0 的背景列丢掉，背景塌缩成名单本身，
  实测直接抛 `ValueError: cannot compute fingerprint of empty set`。
- **Fisher 改双尾**，`es` 是 log odds ratio：**负值是耗竭不是富集**。
  只按 `padj < 0.05` 筛会把耗竭通路数成富集，必须再加 `es > 0`。

## 4. `dc.mt.*` 作用于 AnnData 时可能返回新对象

`mt/_run.py::_return()`：若输入含空 observation，它**返回修好的副本**而不是原地写 obsm。
下游若还按原 `adata.obs_names` 对齐就会错位。加一行断言：

```python
repaired = dc.mt.ulm(tf_input, collectri, tmin=5)
assert repaired is None, "ULM 丢了细胞 —— 下游按 obs_names 对齐会错位"
```

*建档 2026-09-17，proj22。*
