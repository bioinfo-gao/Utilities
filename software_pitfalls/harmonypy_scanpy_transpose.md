# harmonypy × scanpy —— `Z_corr` 方向变了，wrapper 还在转置

## 症状：Harmony 明明收敛了，写回 `obsm` 时炸

```
harmonypy - INFO - Converged after 7 iterations
ValueError: Value passed for key 'X_harmony' is of incorrect shape. Values of obsm must
match dimensions ('obs',) of parent. Value had shape (30,) while it should have had (69249,).
----> sce.pp.harmony_integrate(adata, key=..., basis="X_pca", adjusted_basis="X_harmony")
```

2026-09-17 proj22（scRNA tutorial）2-5 章实测，harmonypy **2.0.0** + scanpy **1.11.5**。

## 根因：两边各自自洽，错的是组合

| 组件 | 事实 |
| :--- | :---: |
| harmonypy 2.0.0（C++ 重写版） | `Harmony.Z_corr` 是 property，内部已 `return self._cpp.Z_corr.T`，docstring 明写 `(N x d)` = **cells × PCs**。`Z_orig`/`Z_cos`/`R` 同样加了 `.T` |
| scanpy 1.11.5 | `external/pp/_harmony_integrate.py` 末行仍是 `adata.obsm[adjusted_basis] = harmony_out.Z_corr.T`（按 1.x 的 `(d × N)` 写的） |
| 合起来 | 转置两次 ⇒ 写入 `(n_PCs, n_cells)` ⇒ anndata 拒绝 |

## ⚠ 两处误导性

1. **日志已打印 `Converged`** —— 算法算完了、算对了，炸在**赋值**那一步。别回头调 Harmony 参数。
2. **`Value had shape (30,)` 不是一维数组** —— anndata 校验 `obsm` 时**只打印第 0 轴**
   （它只关心这一轴等不等于 `n_obs`），真实形状是 `(30, 69249)`。

## 修法：绕开 wrapper，自己定向（别改 site-packages）

```python
import harmonypy
ho = harmonypy.run_harmony(adata.obsm["X_pca"], adata.obs, BATCH_KEY,
                           max_iter_harmony=20, random_state=0)
Z = ho.Z_corr
if Z.shape[0] != adata.n_obs:          # harmonypy < 2.0 返回 (PCs × cells)
    Z = Z.T
assert Z.shape == adata.obsm["X_pca"].shape
adata.obsm["X_harmony"] = np.asarray(Z, dtype=np.float32)
```

`run_harmony` 自己会按 `meta_data` 的行数判断输入方向（`data_mat.shape[1] == N` 才不转），
所以**输入**传 `(cells × PCs)` 或 `(PCs × cells)` 都行 —— 只有**输出**需要自己定向。

⚠ 删 `import scanpy.external as sce` 前先 grep `sce.`：同一份脚本里 Scanorama 往往还在用它，
而 `py_compile` **抓不到**这种漏删（名字运行期才解析）。

## 顺带：`sce.pp.scanorama_integrate` 没有同类问题，但要求批次连续

它是 `np.concatenate` 各批次结果，方向没错；但同一批次的细胞在 `obs` 里必须**连续**，
否则抛 `Detected non-contiguous batches` —— **大声失败，不是静默错位**，这里 scanpy 做对了。

## 判据

- 库函数返回值写进 `obsm`/`varm` 形状不对 ⇒ **先看报错发生在"算"还是"写"**（日志里有没有收敛/完成信息）；
- anndata 的形状报错只打印第 0 轴，别按字面当成一维；
- **上下游各自自洽 ≠ 组合能用**：包做大版本重写时，最常见的破坏性改动就是
  **面向用户属性的方向约定**，而上游 wrapper 往往落后半年；
- 修调用方（自己的脚本），**不要**修 site-packages —— 不可复现，且下次 `mamba update` 冲掉。

## 详细排查链

`~/projects_2026M7/22_python_based_scRNA_tutorial/docs/P22_run_and_troubleshooting_log_0903.md` 事件 #8。
