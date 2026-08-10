# PCA — 全部配色方案的肉眼对照

同一份数据、同一张 PCA，把**全部配色方案各画一遍**并排放，用眼睛决定散点该用哪一族颜色。

## 为什么需要这个目录

配色优先级的两分类只点名了 **面积**（区段·柱子）和 **线状**（线条·文字），
**散点两栏都没写**。PCA 散点归哪一档是个判断题，而且 `min pairwise distance`
这个数值指标**答不了**它 —— 距离够大不等于"在白底上看得清"。
`#FFED6F` 与 `#BEBADA` 的距离完全合规，但两个都是浅色，画成 3 pt 的点就发虚。

**这类事只能看图。** 所以把方案铺开、用真实数据画出来。

## 数据

`pca_coordinates_demo.csv` —— proj28（Xiaokun Yang / mouse DC KO）全 18 样本
cohort overview PCA 的**真实坐标**（不是造的数）。
6 组 = 2 基因型（NTC / KO）× 3 分选亚群（cDC1 / cDC2 / DN）。
随目录附带，与项目解耦，永远可复现。

## 产物

| 文件 | 内容 |
| :--- | :--- |
| `PCA_all_palettes_grid.{pdf,png}` | **先看这张** —— 8 个方案 2 列并排，并排才比得出来 |
| `PCA_<NN>_<scheme>.{pdf,png}` | 单方案大图，带完整图例 |
| `palette_schemes_used.csv` | 每个方案实际取到的 6 个色值 + 它们各来自第几级 |

每张图的副标题写着**取色函数调用**和**实际色值 `#RRGGBB[级别]`** —— 看图时不必回头翻代码。

## 8 个方案

| # | 方案 | 取色入口 |
| :--- | :--- | :--- |
| 01 | Default_A — 面积族 | `sample_fills(6, force_level = "A")` |
| 02 | **Default_A — 线状族** ★ proj28 实际采用 | `strokes_by_priority(6)`（A 满 5 个后自动从 B 补第 6） |
| 03 | Default_B — 面积族 | `sample_fills(6, force_level = "B")` |
| 04 | Default_B — 线状族 | `strokes_by_priority(6, from = c("B","3","4","5"))` |
| 05 | 第 3 级 ColorBrewer Set3（蓝换中灰）面积族 | `fills_by_priority(6, from = "3")` |
| 06 | 第 3 级 STROKE_COLORS 线状族 | `strokes_by_priority(6, from = c("3","4","5"))` |
| 07 | 第 4 级 手调全彩 | `fills_by_priority(6, from = c("4","5"))` |
| 08 | 第 5 级 黑白灰 | `fills_by_priority(6, from = c("5","4","3"))`（第 5 级只有 3 色，必然向下补） |

**色值一律由 `palette_priority.R` 的正式入口取，脚本里不手写任何 hex** ——
手写就等于绕开优先级，两张图并排会对不上。

## 两个约定（看图时别误判）

- **样品名标签一律黑色**，不继承点的颜色。这是 house rule：文字可读性优先于
  "点与其标签同色"。所以这几张图比的是**点**的可分度，不是标签的。
- **形状 ● = NTC，▲ = KO**，只有 2 档，不会触发 ggplot2 默认 shape scale
  超过 6 档静默丢点的那个坑。

## 已踩并已修的坑：R 的 PDF 设备渲染不了中文

R 默认的 `pdf()` 是单字节设备，遇到汉字抛
`conversion failure ... in 'mbcsToSbcs'`（本例首次运行 **253 条**）然后**照常出图** ——
标题里的中文变成空白，文件看着"生成成功"。
**这是 matplotlib「默认字体没有汉字」那个坑的 R 侧同款。**

修法（已写进 `plot_pca_all_palettes.R`）：

1. PDF 走 `cairo_pdf`、PNG 走 `type = "cairo"`；
2. `theme_set(theme_bw(base_family = "Noto Sans CJK SC"))`，patchwork 的
   `plot_annotation(theme = ...)` 里也要显式带 `family`（它不继承 `theme_set`）；
3. **所有出图统一走 `save_fig()`**，它捕获警告并把任何 CJK 转换失败**升级为 `stop()`** ——
   不让"中文变空白"的图再静默产出；
4. 启动时硬断言系统装了该 CJK 字体、R 编译了 cairo 支持。

⚠ `type = "cairo"` **只有 png 设备认**，传给 `cairo_pdf` 会 `unused argument` 直接报错 ——
所以 `save_fig()` 用 `do.call` 按设备拼参数，不能一股脑传。

## 运行

```bash
/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript plot_pca_all_palettes.R
```

## 现状

**只有 R 版。** `color_and_format/` 下其它主题是 R / Python 双实现且要求逐字对齐，
本目录暂未做 Python 镜像 —— 需要的话再补。
