# scVelo 0.3.4 / CellRank 2.0.7 × numpy 2 + anndata 0.12 —— 四个坑

**2026-09-17 proj22 ch5-2/5-3 实测**，env `sc_tut_traj`：
scvelo 0.3.4 / cellrank 2.0.7 / numpy 2.4.6 / anndata 0.12.19 / scanpy 1.11.5。
**这套组合下 05 章一格都跑不到底**，四个坑分属四个不同的层。

## 1. `filter_and_normalize` 少做两件事，名字和 docstring 都在骗人

0.3.4 里它**只**跑 `filter_genes` + `normalize_per_cell`：

- **`n_top_genes` 参数已删除** —— 传进去落到 `**kwargs` 再转给 `normalize_per_cell`，报
  `TypeError: normalize_per_cell() got an unexpected keyword argument 'n_top_genes'`。
- **docstring 仍写着 "and log transform"，实现里没有 `log1p`** ⇒ 不自己补的话，
  后面 PCA / neighbors 是在**未取对数**的数据上做的，**不报错**。

```python
scv.pp.filter_and_normalize(adata, min_shared_counts=20)
sc.pp.log1p(adata)                                          # 自己补
sc.pp.highly_variable_genes(adata, n_top_genes=2000, subset=True)
```

## 2. ⛔ `leastsq_generalized` 把 (1,) 数组塞进标量槽 —— numpy 2 直接拒绝

`scvelo/tools/optimization.py:184`：`gamma[i] = np.linalg.pinv(A.T.dot(A)).dot(...)`
右侧形状 (1,)。numpy 1.25 起弃用，**numpy 2 抛 `ValueError: setting an array element
with a sequence`** ⇒ `scv.tl.velocity(mode="stochastic")` 整个不可用。

**打补丁时踩到的第二个坑（重要）**：

```python
from scvelo.tools import velocity as _vel     # ❌ 拿到的是**函数**不是模块！
```
`scvelo/tools/__init__.py` 里的 `from .velocity import velocity` **把子模块名遮蔽成同名函数**。
给函数对象挂属性 (`_vel.leastsq_generalized = fixed`) 等于什么都没做，
而**回读时读到的正是自己刚挂上去的那个 ⇒ 假验证通过**。必须：

```python
_vel = sys.modules["scvelo.tools.velocity"]                 # ✓ 真模块
assert isinstance(_vel, types.ModuleType)
assert _vel.__dict__["leastsq_generalized"].__code__.co_filename == "<patch>"
```
**判据：验证补丁不能 getattr 回读，要查模块字典里那个名字的 `co_filename`。**
定位手段：捕获异常后遍历 `tb.tb_frame.f_globals["<名字>"]` —— 哪一帧看到的是原函数一目了然。

## 3. CellRank 2.0.7 的两处 API 已被上游改掉

- `kernels/_velocity_kernel.py:94` 用 `np.testing.assert_array_equal(x=, y=)`，
  **numpy 2 把参数改名成 `actual` / `desired`** ⇒ `TypeError: unexpected keyword 'x'`，
  VelocityKernel 一建就炸。补一个只改参数名的兼容壳即可（断言语义不变）。
- **绘图方法不收 `ax` / `show`**（`plot_spectrum` / `plot_macrostates` /
  `plot_fate_probabilities` / `plot_coarse_T` 都是自己 `plt.subplots()`），
  多余关键字被原样转给 `Axes.scatter` ⇒ `got multiple values for argument 'ax'`。
  它们收 `title`，部分收 `figsize` / `dpi` ⇒ **这些图没法拼进自己的 subplot 网格。**

## 4. ⛔ `Lineage` 对象存不进 h5ad —— 算完几分钟，最后一步全丢

cellrank 注册的写出函数是 `write_basic(f, k, elem=elem.X, ...)`，
anndata 0.12.19 的 `write_basic` 不再收 `elem` 关键字 ⇒
`TypeError: write_basic() got an unexpected keyword argument 'elem'`，
写 `/obsm/macrostates_fwd_memberships` 时中断。**最贵的失败形态：全算完了但存不下来。**

保存前转成 ndarray（列名挪进 `uns`），顺带让 ckpt **不装 cellrank 也能打开**：

```python
for key in list(adata.obsm):
    val = adata.obsm[key]
    if type(val).__name__ in ("Lineage", "LineageView"):
        adata.uns[f"{key}_names"] = [str(n) for n in val.names]
        adata.obsm[key] = np.asarray(val.X)
```
本数据命中 3 个键：`macrostates_fwd_memberships` / `term_states_fwd_memberships` / `lineages_fwd`。

## 5. 两个"看起来像结论"的输出

- **GPCCA 会自动上调 `n_states`**：若该数会劈开一对共轭复特征值就换一个
  （实测请求 7 → 实际 8，禁用集合 `[7,13,16,18]` 只在一条 WARNING 里出现）。
  ⇒ **回读 `len(g.macrostates.cat.categories)`，别把请求值写进日志。**
- **PETSc `Caught signal 13 Broken Pipe` + `MPI_Abort(59)` 是噪音不是失败** ——
  实测其后照常 `Adding adata.obsm['lineages_fwd']` 并跑到章节结束。别被它误导去排查。

*建档 2026-09-17，proj22 ch5-2 / ch5-3。*
