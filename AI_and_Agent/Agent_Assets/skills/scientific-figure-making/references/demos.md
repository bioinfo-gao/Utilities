# 上游真实论文图脚本索引

house style 是从 **[ChenLiu-1996/figures4papers](https://github.com/ChenLiu-1996/figures4papers)**
的 `figure_*` 目录反推出来的，那些脚本就是本 skill 的 canonical demo。
**遇到本 skill 没覆盖的图型，先按下表找最接近的一个打开看**，再用 `pubfig` 的常量和
`finalize_figure` 对齐样式。

每个目录里是 Python 脚本 + `figures/` 下的成图，可直接对照"代码 → 成图"。

| 图型 | 上游目录 | 发表去向 |
|:---|:---|:---|
| 定量对比 bar | [figure_ImmunoStruct](https://github.com/ChenLiu-1996/figures4papers/tree/main/figure_ImmunoStruct) | Nature Machine Intelligence |
| bar 对比 + ablation | [figure_CellSpliceNet](https://github.com/ChenLiu-1996/figures4papers/tree/main/figure_CellSpliceNet) | — |
| 组成占比 bar（category / subcategory 拆分） | [figure_Brainteaser](https://github.com/ChenLiu-1996/figures4papers/tree/main/figure_Brainteaser) | NeurIPS 2025 |
| radar / polar、post-training line 面板 | [figure_VIGIL](https://github.com/ChenLiu-1996/figures4papers/tree/main/figure_VIGIL) | ECCV 2026 |
| 时间趋势线、composition heatmap | [figure_ophthal_review](https://github.com/ChenLiu-1996/figures4papers/tree/main/figure_ophthal_review) | 眼科综述 |
| heatmap、manifold、sweep | [figure_RNAGenScape](https://github.com/ChenLiu-1996/figures4papers/tree/main/figure_RNAGenScape) | — |
| 3D 球体示意、概念图 | [figure_Dispersion](https://github.com/ChenLiu-1996/figures4papers/tree/main/figure_Dispersion) | ICML 2026 |
| 对比 / ablation / trajectory | [figure_Cflows](https://github.com/ChenLiu-1996/figures4papers/tree/main/figure_Cflows) | — |

## 按需求反查

- **radar / polar 对比** → `figure_VIGIL/plot_comparison_radar.py`
- **多面板 line + 专用 legend 面板** → `figure_VIGIL`、`figure_ophthal_review`、`figure_Cflows`
- **散点密集 / 概念示意图** → `figure_Dispersion/plot_illustration.py`、`figure_VIGIL/plot_concept.py`
- **超宽多指标 bar** → `figure_ImmunoStruct/plot_bars.py`（`dpi=600` 的密集面板范例）
- **heatmap** → `figure_RNAGenScape`、`figure_ophthal_review/plot_composition.py`

## 完整获取

```bash
git clone --depth 1 https://github.com/ChenLiu-1996/figures4papers.git   # ~60 MB，含成图 PNG/PDF
```

⚠ 上游脚本**没有**本 skill 的配色断言，其中就有"下面板走默认色环"的写法。
照抄布局与样式没问题，但**跨 panel 配色必须按 [panel-color-discipline.md](panel-color-discipline.md) 自己把断言补上**。

---

## 相关文件

- [../SKILL.md](../SKILL.md) — 何时加载本 skill
- [house-style.md](house-style.md) — 从这些脚本统计出的样式数值
- [api.md](api.md) — `pubfig` 函数签名
