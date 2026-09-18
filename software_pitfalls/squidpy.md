# squidpy —— `spatial_autocorr` 的 p 值列在无变异基因上是**未初始化内存**

实测版本：squidpy 1.6.x（`sc_tut_spatial` env，2026-09-17，proj37）。
**症状**：`table = adata.uns["moranI"]` 里出现 `pval_norm = 2.0000005`、`pval_norm_fdr_bh = -891.7`
这类**不可能的 p 值**；同一份输入、同一个 `seed`，**两次运行的 p 值列不一样**，而 `I` 列逐字节相同。
最坏的一种表现是**看起来完全正常**：如果内存恰好是刚映射的零页，这些行全是 `0.0`，
于是它们变成"最显著"的基因，把 FDR 计数放大几十倍。

## 根因

`squidpy/gr/_ppatterns.py`（`_p_value_calc` 内，约 479 行与 523 行两处）：

```python
p_norm = np.empty(score.shape)          # 未初始化
p_norm[z_norm > 0]  = 1 - stats.norm.cdf(z_norm[z_norm > 0])
p_norm[z_norm <= 0] = stats.norm.cdf(z_norm[z_norm <= 0])
if params["two_tailed"]:
    p_norm *= 2.0
```

基因在该切片内**无变异**（全 0 或恒定）⇒ Moran's I = NaN ⇒ `z_norm` = NaN ⇒
`z>0` 和 `z<=0` **两个掩码都是 False** ⇒ **该元素永远不被写入**，保留 `np.empty` 拿到的脏内存。
`p_z_sim` 同理。`*= 2.0` 解释了为什么见到的越界值常常约等于 2。

随后 `_ppatterns.py` 用
```python
_, pvals_adj, _, _ = multipletests(df[pv].values, alpha=0.05, method="fdr_bh")
```
对**整列**做 BH —— 污染就此传给有效基因：BH 是按秩校正的，前面塞进一批 `p=0`
会把真实基因的秩推后、校正值压低。

## 后果（proj37 实测数字）

| | 修复前 | 修复后 |
| :--- | :---: | :---: |
| 送检基因 | 36,601（全部） | 19,264–22,519（该切片内有变异的） |
| `I` = NaN 的行 | 63,558 / 146,404 | **0** |
| p 值落在 [0,1] 之外 | 2,374（仅 control_P1；其余切片当轮恰好拿到零页） | **0** |
| 报告的 FDR<0.05 基因数 | 15,690–18,633 | **419–1,700** |

**虚高 20–40 倍**，而且这个数字曾被写进项目文档，解释成"spot 数多所以检验功效极高"。

## 修复

送检前先剔除无变异基因（这正好就是"I 算得出来"的充要条件）：

```python
X = sub[:, list(genes)].X
if sparse.issparse(X):
    m = np.asarray(X.mean(axis=0)).ravel()
    var = np.asarray(X.multiply(X).mean(axis=0)).ravel() - m ** 2
else:
    var = np.asarray(X).var(axis=0)
genes = [g for g, ok in zip(genes, var > 0) if ok]
sq.gr.spatial_autocorr(sub, mode="moran", genes=genes, n_perms=100, n_jobs=8, seed=0)
assert sub.uns["moranI"]["I"].notna().all()      # ← 配套断言，别只靠记得
```

canonical 实现见 `37_spatial_visium_heart_pilot/scripts/3_svg_moran.py` 的 `testable_genes()`。

## 判据（怎么在别处发现同类问题）

1. **p 值列扫一遍 `(p < 0) | (p > 1)`** —— 一行断言，比读代码快。
2. **两次运行 diff 同一张表**：统计量列相同而 p 值列不同 = p 值路径里有未初始化内存或未播种的随机。
3. 更一般的形状：**`np.empty` + 按掩码分支写入**，只要存在两个掩码都不覆盖的元素（NaN 是最常见的一个），
   那些位置就是脏内存。搜 `np.empty(` 比搜 `NaN` 有效。

## 不相关的一点澄清

squidpy 的**置换** p 值（`pval_sim`）没有这个问题，且 `seed` 处理正确
（`rng = default_rng(None if seed is None else ix + seed)`，`seed=0` 有效，
**与 decoupler / tangram 的 `if seed:` 陷阱不同**，见 [decoupler.md](decoupler.md) / [tangram.md](tangram.md)）。
