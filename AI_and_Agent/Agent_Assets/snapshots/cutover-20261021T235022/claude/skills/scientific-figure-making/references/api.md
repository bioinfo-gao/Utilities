# API — `assets/pubfig.py` / `assets/pubfig.R`

上游 repo **只给了 API 规格、没有实现**（其 `tutorials.md` 原话：
"This repository does not currently ship a tracked shared Python module that defines
`apply_publication_style`, `make_grouped_bar`, or the other helpers directly"）。
本 skill 的 `assets/pubfig.py` 与 `pubfig.R` 是这套规格的可运行实现，
并额外加入了配色断言。两侧 self-test 均已实跑通过。

```python
import sys; sys.path.insert(0, "/home/gao/.claude/skills/scientific-figure-making/assets")
from pubfig import *
```
```r
source("/home/gao/.claude/skills/scientific-figure-making/assets/pubfig.R")
```

---

## 常量

| 名称 | 内容 |
|:---|:---|
| `PALETTE` | 20 色语义字典：`blue_main` `blue_secondary` `green_1/2/3` `red_1/2` `red_strong` `neutral` `grey_mid` `grey_dark` `ink` `grey_pale/soft/deep`（填充安全灰阶） `highlight` `teal` `violet` `magenta` `cyan` |
| `DEFAULT_COLORS` | 未传 `colors` 时的顺序：blue_main, green_3, red_strong, teal, violet, neutral |
| `PALETTE_FAMILIES` | 四个互不相交的族 `cool` / `warm` / `green` / `grey`，**按由深到浅排序**（截前 N 个即 line/point 安全色）。**`grey` 是唯一例外：浅 → 深且止于中灰 `#5A5A5A`**，因为大面积近黑填充在论文/slide 上是大忌 |

`magenta #C71585` 与 `cyan #17BECF` 是上游没有的补充色，用来替换任何会落到 pale yellow 的位置。

---

## 断言（三条门禁 + 两条配套）

| 函数 | 签名 | 触发条件 |
|:---|:---|:---|
| `assert_no_palette_collision` | `(panels: {label: colors}, min_distance=0.10)` | 语义不同的 panel 之间出现相同色，或 RGB 距离 < `min_distance` 的近似色。**只喂填充色**——线条/文字是另一个通道，不参与此约束 |
| `assert_shared_palette` | `(panels: {label: {level: color}})` | 语义相同的 panel 之间 level→color 映射不一致（缺 level / 多 level / 换了色） |
| `assert_visible_on_white` | `(colors, role="line", min_contrast=1.5)` | 对白底 WCAG 对比度低于阈值；`role="fill"` 放宽到 1.1 |
| `assert_fill_not_near_black` | `(colors, max_contrast=10)` | 大面积填充是黑或近黑（`ink #272727` 对比度 14.94）；深饱和色如 `blue_main`(8.41) 仍允许 |
| `assert_no_yellow_text` | `(colors)` | 文字色相落在黄色带 40–75°（饱和度 >0.25）。**按色相判，不按对比度** —— `#B8860B` 对比度 3.25 能过对比度检查，仍是黄字 |
| `assert_points_drawn` | py `(ax, expected)` / R `(p, expected, layer=1)` | 实际绘出的点数 ≠ `expected` |
| `legend_outside` | `(ax, *args, loc="lower left", bbox_to_anchor=(0, 1.0), **kw)` | 传入 `loc="best"` 时直接 `ValueError` |

全部 **raise / stop()，不 warn**——会误导人的图不该被写到磁盘上。

辅助：`relative_luminance(color)`、`contrast_vs_white(color)`（返回 1–21 的 WCAG 对比度）。

**`STROKE_COLORS`** —— 线条/文字的优先色序：黑 `#000000` → 正红 `#E41A1C` → 亮蓝 `#1F78B4`
→ 深绿 `#006D2C` → 咖啡 `#8C510A` → 深紫 `#762A83`。两两最小距离 0.221，对白底对比度 4.7–21.0。
**从上往下取**，用完再取 `STROKE_COLORS_TIER2_PALETTES`（`PRGn`/`PiYG`/`BrBG` 的两端）。
前提为白/浅底；深底时逻辑反转（白色与浅色单色线条），本模块不提供深底检查。

**`brewer(name, n=None, skip=())`** —— 取 ColorBrewer 色板（见 [colorbrewer.md](colorbrewer.md)）。
qualitative 返回离散成员；diverging/sequential 按 n 在全域均匀采样（`n=2` 即两端深色）。
**`set3_with_grey(grey="#999999")`** —— 推荐的 12 色填充集：Set3 把蓝 `#80B1D3` 换成中灰，
既消除它与 `#8DD3C7` 的 0.096 撞色，又补上 Set3 缺的可用中性色。
**`BREWER_ROLES`** —— 按角色（fill / line / marker）分组的色板名清单。

**`soften_for_fill(color, sat_factor=0.55, val_factor=1.0)`** —— 把线条/文字色转成填充色。
文字和细线要够饱和才看得清，大色块很弱的饱和度就够且满饱和会盖过数据，所以**同一色相
做线要强、做填充要软**。`sat_factor` 可用区间 0.4–0.7；`val_factor > 1` 提亮降饱和后发闷的深色。
Python 与 R 同名同结果（实测 `#17BECF` @0.50 两边都是 `#73C6CF`）。

R 侧 legend 用 `theme_legend_outside(position = "top"|"right"|"bottom"|"left")`。

---

## 样式与布局

### `FigureStyle` / `theme_pub`

```python
@dataclass(frozen=True)
class FigureStyle:
    font_size: int = 16                # 大 bar 面板 24；紧凑图 15–16
    axes_linewidth: float = 2.5        # 大 bar 3；紧凑 2
    use_tex: bool = False              # 仅在装了 LaTeX 且需要数学标签时 True
    font_family: tuple = ("Arial", "Helvetica", "DejaVu Sans", "sans-serif")
```

- `apply_publication_style(style=None)` — 设置 rcParams（去上/右 spine、无框 legend、
  `svg.fonttype="none"`、`pdf.fonttype=42`、白底）。**建图之前调用一次。**
- R：`theme_pub(font_size = 16, axes_linewidth = 2.5, base_family = "sans")`，
  作为 ggplot 图层相加。

### `create_subplots(nrows=1, ncols=1, figsize=None, **kwargs)`
返回 `(fig, axes)`，`axes` **恒为一维 ndarray**（单图也是），省掉分支判断。

### `finalize_figure(fig, out_path, formats=None, dpi=300, close=True, pad=2.0, **kw)`
`tight_layout(pad)` 后按 `formats` 逐个保存，自动建父目录，返回 `list[Path]`。
`formats=None` 时取 `out_path` 的扩展名，没有扩展名则默认 `["pdf", "png"]`。
支持 pdf / svg / eps / png / jpg / jpeg / tif / tiff，其余直接报错。

R：`finalize_figure(plot, out_path, formats = c("pdf","png"), dpi = 300, width = 8, height = 6)`。

---

## 绘图函数（Python）

### `make_grouped_bar(ax, categories, series, labels, ylabel="Value", colors=None, annotate=False, fmt="{:.2f}", edgecolor="black", edge_linewidth=1.5, hatches=None)`
分组柱状图，返回最后一个 `BarContainer`。`series` 为每系列一个一维数组，长度必须等于
`len(categories)`（不等直接报错）。**默认带黑边**保证灰度可分；`hatches` 提供与颜色正交的第二通道。

### `annotate_bars(ax, bars, fmt="{:.2f}", fontsize=None, padding=3)`
在每根柱顶标数值。

### `make_trend(ax, x, y_series, labels, colors=None, ylabel=None, xlabel=None, show_shadow=True, shadow=None, linewidth=2.5)`
多曲线 + 可选不确定性带。**内部会对 `colors` 跑 `assert_visible_on_white(role="line")`**。
`shadow` 传真实 SE；不传而 `show_shadow=True` 时画的是 5% 视觉提示带，**不是统计量**，
写进报告前请传真实误差。

### `make_heatmap(ax, matrix, x_labels=None, y_labels=None, cmap="magma", cbar_label=None, annotate=False, fmt="{:.2f}", vmin=None, vmax=None)`
二维热图 + colorbar。`annotate=True` 时按格子明暗自动选黑/白字。

### `make_scatter(ax, x, y, label=None, color=None, size=50, alpha=0.7, **kwargs)`
单系列散点，颜色会过白底可读性断言。

### `composition_bar_instead_of_pie(ax, labels, values, color=None, as_percent=True, sort_desc=True, fmt="{:.1f}%", horizontal=True)`
**饼图的替代实现**：把组成画成**降序排列的条形图并把数值标出来**。
人眼比较长度远强于比较角度 —— 26% 和 29% 的扇形看不出差别，条形加数字则一目了然，
且排序本身给出了饼图给不了的名次信息。R 侧签名为
`composition_bar_instead_of_pie(labels, values, color, as_percent, sort_desc, horizontal, font_size)`，返回 ggplot 对象。

### `tighten_ylim(ax, data, margin_frac=0.15)` / `fixed_yticks(ax, ticks)`
收紧 y 轴到数据范围；用 `FixedLocator` 钉死刻度。

---

## 校验规则

- 所有数值序列转 numpy，检查维度与长度。
- `make_grouped_bar`：每个 series 必须是一维且长度 = `len(categories)`；`labels` 与 `colors`
  数量必须匹配 series 数。
- `make_trend`：每个 series 形状必须等于 `x`。
- `make_heatmap`：`matrix` 必须二维。
- `finalize_figure`：格式白名单外直接 `ValueError`。

## 约定

- 脚本输出统一写到项目的 `figures/` 目录（或用户指定路径），basename 稳定。
- 无头/批处理：`matplotlib.use("Agg")` 要在 `import pyplot` 之前。
- 对比组、panel 数量、颜色语义、分辨率、数据布局中**任何一项没说清且会改变成图结果时，
  先问用户再出图**，不要自己拍板。

---

## 相关文件

- [../SKILL.md](../SKILL.md) — 何时加载本 skill
- [panel-color-discipline.md](panel-color-discipline.md) — 断言背后的规则与事故
- [house-style.md](house-style.md) — 字号/布局/导出的具体数值
- `../assets/selftest.py`、`../assets/selftest.R` — 每个函数的可运行用例
