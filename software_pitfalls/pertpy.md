# pertpy 1.0.3 —— 两个静默陷阱 + 一个版本不兼容

**本机实测**：`/mnt/ex_8T_SSD/conda_envs/sc_tut_main`，pertpy 1.0.3 / scikit-learn 1.9.0 /
mudata 随 pertpy 装（2026-09-17，proj22 ch4-4）。

## 1. ⛔ Augur 的 label 列必须是 `category` dtype —— object 会跑 150 次子抽样后才炸

`tools/_augur.py::load()` 第 148 行：**`if final_adata.obs["label"].dtype.name == "category"`**
才走 `LabelEncoder` 编码成 0/1；**object dtype 落到 else 分支，`y_` 原样保留字符串**。
`load()` 不报错、不告警，直到 `predict()` 里 sklearn 算指标时抛
`ValueError: pos_label=1 is not a valid label. It should be one of ['control' 'perturbed']`，
**每个子抽样各抛一次**（默认 50 subsamples × 每个 cell type）。

```python
# 实测同一份数据，只改 dtype
obs["lab_obj"] = np.where(...)                 # → y_ dtype=object,  取值 ['control','perturbed']  ✗
obs["lab_cat"] = pd.Categorical(np.where(...)) # → y_ dtype=int64,   取值 [0, 1]                    ✓
```

⇒ **`np.where()` / `.map()` 造出来的标签一律再包一层 `pd.Categorical()`。**

## 2. ⛔ pertpy 1.0.3 × scikit-learn ≥1.7：`_m_step() got an unexpected keyword argument 'xp'`

sklearn 给 `GaussianMixture._m_step` 加了 Array API 的 `xp` 参数并以 `xp=xp` 调用；
pertpy 的 `MixscapeGaussianMixture._m_step(self, X, log_resp)` 没跟上 ⇒ mixscape 直接崩。
**不改 site-packages 的补法**（函数体照抄 pertpy 1.0.3 原实现，只透传 xp）：

```python
import inspect
from pertpy.tools._mixscape import MixscapeGaussianMixture as _MGM

if "xp" not in inspect.signature(_MGM._m_step).parameters:
    def _m_step_xp(self, X, log_resp, xp=None):
        super(_MGM, self)._m_step(X, log_resp, xp=xp)
        if self.fixed_mean_indices:
            self.means_[self.fixed_mean_indices] = self.fixed_mean_values
        if self.fixed_cov_indices:
            self.covariances_[self.fixed_cov_indices] = self.fixed_cov_values
        return self
    _MGM._m_step = _m_step_xp
```

**验证补丁别只看"跑通了"**：固定成分的均值/协方差约束才是 mixscape 分 KO/NP 的依据。
造两成分数据（μ=0 / μ=5）把成分 0 锁成 (0,1)，拟合后应恰为 `means_[0]=0.000, cov=1.000`
且自由成分 ≈5.0。实测通过。

## 3. `labels=` 已改名 `pert_key=`

`Mixscape.mixscape()` / `Mixscape.lda()` 的 `labels=` 参数在 1.x 改叫 **`pert_key=`**
（与 `perturbation_signature` 统一）。这个报错是显式的 TypeError，不危险，但会一次只报一个 ——
**移植时把全章调用对着 `inspect.signature` 一次核完**，别一个一个撞。

## 4. `pt.data.papalexi_2021()` 的扰动元数据不在 RNA 模态里

返回 MuData（`rna` / `adt` / `hto` / `gdo`）。**`mdata.mod['rna'].obs` 只有 3 个 QC 列**
（`nCount_RNA` / `nFeature_RNA` / `percent.mito`）；`gene_target`、`guide_ID`、`perturbation`、
`replicate` 都在**顶层 `mdata.obs`** 里。顶层 obs 中带 `<mod>:` 前缀的是各模态私有的，
**不带前缀的 10 列才是全局共享的**。取回时用 `join` 按 `obs_names` 对齐，**不要按位置赋值**：

```python
shared = [c for c in mdata.obs.columns if ":" not in c]
adata.obs = adata.obs.join(mdata.obs[shared])
assert adata.obs["gene_target"].notna().all()
```

*建档 2026-09-17，proj22 ch4-4。*
