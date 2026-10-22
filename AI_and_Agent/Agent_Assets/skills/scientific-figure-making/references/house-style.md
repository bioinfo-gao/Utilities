# House style — 字号 / 布局 / 编码 / 导出

> 来自 [ChenLiu-1996/figures4papers](https://github.com/ChenLiu-1996/figures4papers)
> 的 `design-theory.md` + `common-patterns.md`。下面括号里的出现次数是**本地 clone 后
> 实际 grep 的**（上游 24 个绘图脚本，commit `fcd46ec`，2026-08-05 核对），
> 与上游文档自述的数字略有出入时以此处为准。`pubfig.py` / `pubfig.R` 已把这些设成默认值。

---

## 1. 排版与线宽

| 项 | 值 |
|:---|:---|
| 字体 | `helvetica`（24 个脚本中 19 个显式设置）；可移植写法用 fallback stack `["Arial", "Helvetica", "DejaVu Sans", "sans-serif"]` |
| 大 bar / comparison 面板 | `font.size = 24`，`axes.linewidth = 3` |
| 论文子图 / 紧凑分析图 | `font.size = 15–16`，`axes.linewidth = 2` |
| spines | `axes.spines.right = False`、`axes.spines.top = False` |
| legend | `frameon = False` |
| LaTeX | `text.usetex = True` 仅在数学标签密集时（6 个脚本），且本机确实装了 LaTeX |
| 矢量文字 | `svg.fonttype = "none"`（SVG 里文字仍可编辑）、`pdf.fonttype = 42`（TrueType，避免 Type-3 被期刊退稿）。上游只有 1 个脚本设了 `svg.fonttype`，本 skill 把它设成默认 |

`apply_publication_style(FigureStyle(font_size=24, axes_linewidth=3))` /
`theme_pub(font_size = 24, axes_linewidth = 3)` 一次设定全部。

## 2. 导出

- **DPI**：标准 `300`（27 处）；**极密的 bar 面板用 `600`**（4 处，全在
  `figure_ImmunoStruct/plot_bars.py`）。
- **收尾**：`fig.tight_layout(pad=2)` 是默认（24 处）；紧凑多面板用 `pad=1`。
- 白底不透明输出；边到边拼图时用 `bbox_inches="tight"` 配显式 `pad_inches`。
- **同时导出 `pdf` + `png`**：pdf 进论文/报告，png 供快速查看与 Markdown 内嵌。
  `finalize_figure(fig, path, formats=["png", "pdf"], dpi=300)` 会自动建父目录。
- 批处理/无头运行：`import matplotlib.pyplot` **之前**先 `matplotlib.use("Agg")`。

## 3. 配色语义

| 色族 | 语义 |
|:---|:---|
| 蓝 `#0F4D92` / `#3775BA` | 提出的方法 / 关键结果 |
| 绿 `#DDF3DE` `#AADCA9` `#8BCF8B` | 改进项 / 正向变体（浅→深可表示递增） |
| 红粉 `#F6CFCB` `#E9A6A1` `#B64342` | baseline / 对照 / 替代方案 |
| 中性灰填充族 `#ABABAB` `#828282` `#5A5A5A` | 参照、背景类别，或需要"无彩色"时的分组 |
| 深灰 `#4D4D4D` / 墨 `#272727` | **只用于文字与细线**，不做大面积填充（见下） |
| 强调 金 `#FFD700`、teal `#42949E`、violet `#9A4D8E` | 单点 callout，不要泛用 |

⚠ 跨 panel 使用前先读 [panel-color-discipline.md](panel-color-discipline.md)——语义不同的 panel
即使都从这张表里取色，也必须取**互不相交**的族。

## 4. 布局

- **超宽画布**：3–4 个 metric 的多指标对比用极宽比例（上游用到 `figsize=(45, 12)`、`(28, 6)`），
  **宽常为高的 3–4 倍**。让读者从左到右当叙事扫过去，避免纵向拥挤。
- **专用 legend 面板**：多曲线/多组时，单独留一个 subplot 只放图例，
  `ax.set_axis_off()` 后把其它轴的 handles/labels 收集过来画在这里。数据面板保持干净。
- **省略 x-tick 标签**：x 轴是"方法"或"条件"且 legend 已经标明时，`ax.set_xticks([])`，
  靠 legend/标题识别。多方法 × 多指标时尤其有效。
- **动态 y 轴**：手动收紧到相关区间（常用 `data.min() - data.std()` 一类），
  突出比较差异而非绝对值。**数据都在 85–95 就别画 0–100**——用 `tighten_ylim(ax, data)`。
- **一致性优先于装饰**：同一行所有 subplot 共享字号、线宽、颜色语义映射。

## 4a. 科研作图三条基本美学原则（user directive 2026-08-05）

用户给定的三条底线，先记住这三条，其余细节都在其下：

| # | 原则 | 落地 |
| :--- | :--- | :--- |
| 1 | **尽量避免实心深黑图** | `assert_fill_not_near_black()`；灰阶用 `PALETTE_FAMILIES["grey"]` |
| 2 | **尽量避免黄色文字** | `assert_no_yellow_text()`（按**色相**判，不是按对比度） |
| 3 | **非必要不用饼图** | `composition_bar_instead_of_pie()` |

**第 3 条的理由（用户原话）**：「角度 26 度和 29 度很难区分，用条形图，数字 29 比 26 高，
一目了然。」人眼比较**长度**远强于比较**角度**——组成/占比默认画**排序条形图并把数字标出来**。
饼图只在展示"单一份额 vs 整体"（如 "38% of reads on-target"）时可用，且仍要标数字。

**第 2 条为什么不能用对比度判**：`#B8860B`（dark goldenrod）对白底对比度 3.25，
`assert_visible_on_white` 会放行，但它仍然是**黄色文字**，任何字号下都难聚焦。
所以判据是色相落在 40–75° 的黄色带（且饱和度 > 0.25）一律拒绝。橙色（<40°）和黄绿（>75°）不管。
⚠ 黄色作**填充**（配黑边）没问题 —— `highlight #FFD700` 正是这么用的；**只是绝不做字**。

## 4a-2. 文字与色块对饱和度的要求**完全相反**（user directive 2026-08-05）

**用户原话：「文字是线构成的，要深一点才能看清楚。而图片是大块面积，很弱的饱和度就看得
清清楚楚了。」**

- **文字 / 细线**：一两像素宽的笔画，**要够饱和、够深**才能在白底上立住。
- **色块**（bar / rect / area / box）：大面积，**很弱的饱和度就足够清晰**；
  满饱和的大色块会盖过数据本身，一整排更是刺眼。

所以**同一个色相，做线条要强、做填充要软**：

```python
from pubfig import soften_for_fill, PALETTE
line_colour = PALETTE["cyan"]                       # #17BECF  满饱和，画线
fill_colour = soften_for_fill(PALETTE["cyan"], 0.50)  # #73C6CF  降饱和，做柱子
```

`soften_for_fill(color, sat_factor=0.55, val_factor=1.0)`（Python 与 R 同名同结果）。
`sat_factor` 的可用区间是 **0.4–0.7**；`val_factor > 1` 用来把降饱和后发闷的深色提亮一档。

**这条顺带把跨面板的问题解干净了**：线用满饱和、柱用低饱和的同一色相，读者一眼看出是同一
色族，又绝不会当成同一个变量 —— 比换一个完全不相干的色相更省色相空间，也更好看。

⚠ **降饱和幅度要算，不能拍。** 降过头会滑向别的浅色：实例中 magenta 降到 `S×0.40` 时
与相邻的 pink `#E9A6A1` 只差 0.098（阈值 0.10），`S×0.60` 才回到 0.203。
每次调完用 `assert_no_palette_collision` 复核。

## 4b. 大面积填充绝不用黑或近黑（user directive 2026-08-05）

**用户原话：「下面的 panel 用黑色或者接近黑色的深灰色做图，这在发表或者 presentation 的时候是
大忌。黑色实心图极其不美观。」**

- 一根大柱子刷成 `#272727`（对白底对比度 14.94）会**压过数据本身**，读者先看到的是一团墨。
- 灰阶分组一律用 `PALETTE_FAMILIES["grey"]` = `#ABABAB` → `#828282` → `#5A5A5A`，
  **浅 → 深，最深止于中灰**（对比度 6.90）。这是唯一一个不按"由深到浅"排的族。
- `ink #272727`、`grey_dark #4D4D4D` 留给**文字和细线** —— 在那里它们的重量是优点。
- 反过来也不能一路推到接近白：**先确认最浅色和背景/底纹分得开**。实例：某图 J1 分组底纹是
  `#F2F2F2`，`#E8E8E8` 与它的距离只有 0.039，柱子会直接糊进底纹里。
- 断言：`assert_fill_not_near_black(colors, max_contrast=10)`。这是**近黑守卫**，不是通用暗度上限
  —— 深饱和色如 `blue_main #0F4D92`（8.41）照常允许。

## 5. Bar 编码

- **数值直接标在柱顶**（`ax.text` / `annotate_bars()`），字号可大到 36pt，
  让读者不靠网格线就能读到精确值。
- **手动刻度**：用 `FixedLocator` 精确控制 y 轴刻度粒度（`fixed_yticks(ax, [...])`）。
- **强边框**：`edgecolor="black"`，`linewidth=1.5–3`，柱子之间界限清晰。
- **Alpha 递进做 ablation**：同一主色（如 `blue_secondary`）配 `alpha` 0.2→1.0
  表示方法的"完整度"。
- **Hatch 通道**：`"/"`, `"\\"`, `"."` 作为与颜色正交的第二编码通道，
  **保证灰度打印仍可区分**。仅靠填充色区分的柱子在灰度下会糊成一片。

## 6. Trend / line 编码

- 每个轴上主曲线**控制在 2–4 条**。
- 线宽 `2–3`，alpha 受控。
- 不确定性用 `fill_between`（`make_trend(..., shadow=se_arrays)`；
  没有真实 SE 时不要让读者以为那条带子是统计量）。
- 网格线尽量不要或极淡，靠刻度和 legend 直读。
- **Polar / radar**：控制系列数量，线宽与标签纪律同 Cartesian。上游范例在 `figure_VIGIL`。

## 7. Scatter / 示意图编码

- 密集几何场景降 alpha、用低饱和填充。
- 重要轨迹/关系用饱和暖色 + 箭头。
- 概念示意图通常去掉坐标轴刻度。

## 8. 复现上游视觉身份的 5 条

1. 极简 spines（去掉上、右）、无框 legend、显式 y 轴范围。
2. Helvetica/Arial 类无衬线，bar 图用大字号。
3. 只从蓝–绿–红–中性这一族里取色，不要引入无关配色。
4. `tight_layout(pad=2)` 收尾，`dpi=300` 导出（密集 bar 面板 `600`）。
5. 色相接近时用 hatch / 边框做 print-safe 区分。

---

## 相关文件

- [../SKILL.md](../SKILL.md) — 何时加载本 skill
- [panel-color-discipline.md](panel-color-discipline.md) — 跨 panel 配色硬规则
- [api.md](api.md) — `pubfig` 函数签名
- [demos.md](demos.md) — 上游真实论文图脚本索引
