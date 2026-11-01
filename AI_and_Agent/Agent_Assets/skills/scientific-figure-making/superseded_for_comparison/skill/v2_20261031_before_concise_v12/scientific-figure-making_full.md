---
name: scientific-figure-making
description: "Use when 要出版级/客户交付级的图: matplotlib 或 ggplot2 的 grouped bar、trend line、heatmap、scatter/PCA、multi-panel 组图、radar，以及 PDF/SVG/高 DPI 导出——house style 来自 ChenLiu-1996/figures4papers，并强制 panel 配色纪律"
disable-model-invocation: true
---

# /scientific-figure-making — 出版级图件 house style + 配色纪律

## 第一优先配色：V12 九色系三色调（用户确认 2026-10-31）

**新项目默认第一优先 V12**，优先于下文 Categorical_7、Paired_4、Nature_9 与旧 Default_A；用户显式指定及既有项目语义映射优先。旧图不自动重绘。

- 色值唯一来源：`/home/gao/Utilities/color_and_format/top_journals/test/04_selected_three_tones_light_medium_dark_v12.csv`；色卡为同目录 `04_selected_three_tones_light_medium_dark_v12.pdf`。禁止从旧版色卡或截图重新取色。
- 顺序：Coral、Teal（偏 Cyan）、Sky blue、Mint、Purple、Gold、Purple pink、Blue、Neutral。同项目固定类别映射，不逐 panel 重新分配。
- 独立类别：每个色系取中间色，最多 9 类；细线可用该色系深色，文字默认黑/深灰。
- 同色系两条件：取浅、深两档；三条件：按浅、中、深。色调表示条件，色相表示类别，图例必须说明。折线浅色实线、中色点划线、深色虚线，可加不同点形。
- R/Python `select_palette(n, scheme="auto")`：独立类别 n≤9 默认 V12（fill 中色、stroke 深色）；paired 偶数 n≤18 默认 V12，按每系浅、深输出。也可显式 `scheme="V12"`。三档直接读 canonical CSV 的 light_hex / medium_hex / dark_hex；不得对已定稿颜色再机械加深。
- 超过上述容量沿用旧回退，不将 27 个色调当成 27 个独立类别。连续热图仍另选色标。Gold 不作文字，Neutral 深色避免大面积铺满。
- 样图：`/home/gao/Utilities/color_and_format/top_journals/test/v12_examples/00_overview.pdf`。未验证色盲或灰度辨识度，不宣称无障碍保证。

下文 2026-10-29 默认选择说明保留作历史/显式旧方案参考；与本节冲突时以本节为准。旧 `sample_fills` 等入口保持原行为。

## 深浅配对折线的线型（用户确认 2026-10-31）

同色系深浅两档用于两种条件的折线对比时，**默认浅色用实线、深色用虚线**。浅色本身在白底上的对比度较低，再用断续线会进一步削弱可见性；不要将浅色与断续线叠加作为默认方案。点形可辅助区分，但不能替代线条可读性。若项目已有明确线型语义，保留其语义并另行提高浅色线的可读性。

同一条件跨 panel 保持线型一致；按最终显示尺寸检查浅色实线是否清楚，仍难辨认时调整浅色明度或线宽。此约定只涉及深浅配对折线，不改动既有配色优先级，也不追溯重绘旧图。

对照样图（同一数据、颜色及版式）：
- 原版（浅色虚线、深色实线）：`/home/gao/Utilities/color_and_format/top_journals/test/03_Cell_reference_trends.pdf`
- 用户认可的新版（浅色实线、深色虚线）：`/home/gao/Utilities/color_and_format/top_journals/test/03_Cell_reference_trends_light_solid_dark_dashed_v2.pdf`

## 2026-10-29 外部作图工作流整合

数据图继续由可追溯的 R/Python 脚本生成。机制示意图、实验/分析流程图可选用外部画布或生成工具；需要这类图、修改既有图件或使用异步远程作图服务时，读 [references/external-figure-workflow.md](references/external-figure-workflow.md)。该参考吸收 FigureLabs 的局部编辑、版本关联与原任务恢复方法，列出实际采用前的验收条件；不要求安装 FigureLabs，不改变现有配色及科学验证要求。

## 2026-10-29 新项目配色入口（用户已批准，优先于下文旧默认规则）

补充图库 `/home/gao/Utilities/color_and_format/More_colors/` 已接入同一 R/Python 入口；需要 Nature 灵感分类色、单色渐变或蓝粉连续色标时，先读该目录 [integration.md](/home/gao/Utilities/color_and_format/More_colors/integration.md)。通过 `select_palette(..., scheme="Nature_9")` 显式选择分类色，`color_scale("Scientific_Purple")` 取连续锚点；连续色标不用于平级类别。新图库不改变 auto 默认，不把未核实的品牌/无障碍宣传当作验证结果。

**箱线图 median 线统一黑色**（用户指示 2026-10-29）：所有配色方案均适用，不继承分组色或绘图库默认橙色。Python 使用 `medianprops={"color":"#000000"}`；R/ggplot2 确保 median 为黑色（若单独映射箱体边框颜色，需显式覆盖 median）。此规则针对 median，不要求所有箱体边框都改黑。

新项目使用现有 R/Python palette_priority 的 `select_palette()`；同项目固定 scheme 与类别映射，不能逐 panel 按类别数重新选择。
- 有配对关系：`relationship="paired"`，n 为颜色总数，偶数且最多 8，使用 Paired_4。
- 独立类别：默认 Categorical_7（最多 7）；显式 Paired_4 时最多 4 类，跨色对取色。
- 超过 7 个独立类别：auto 回退旧 Default_A 级联；不要混入新色池或伪造额外色对。
- `role="fill"` 用原色；`role="stroke"` 为原色 sRGB 通道乘 0.75 后四舍五入，是候选加深版，并非感知均匀变换。
- 文字用黑或深灰；连续热图仍单独选择 sequential/diverging 色标。黄色不做文字。
- 旧项目及旧入口 `sample_fills` 等维持原行为；下文“永远 Default_A”仅适用于旧入口，不覆盖本节。
- 色值唯一来源：`/home/gao/Utilities/color_and_format/figure/palettes.csv`；说明及验证脚本见同目录 README_palette_integration_20261029.md。
- 既有语义、撞色、点数、渲染检查继续适用；新色板不能保证任意多 panel 组合均通过。


house style 移植自 **[ChenLiu-1996/figures4papers](https://github.com/ChenLiu-1996/figures4papers)**
（Yale CS，图件用于 Nature Machine Intelligence / ICML / NeurIPS / ECCV）。
上游只给了 API **规格**、没有实现；本 skill 补上了**可直接跑的 Python 与 R 实现**，
并把配色纪律做成**硬断言**而不是建议。

**不适用**：Plotly / Altair / Bokeh 等交互式 web 图；纯 EDA 探索图（还没有出版/交付目标时
seaborn、`DimPlot()` 直接画就够）；以 3D 或 GIS 为主体；Illustrator / Figma 主导的示意图排版。

---

## 科研作图三条基本美学原则（user directive 2026-08-05）

**先记这三条，其余细节都在其下。**

1. **尽量避免实心深黑图** —— 大面积近黑填充会压过数据本身。→ `assert_fill_not_near_black()`
2. **尽量避免黄色文字** —— 判据是**色相**不是对比度：`#B8860B` 对比度 3.25 够用，但仍是黄字。
   → `assert_no_yellow_text()`。黄色做**填充**（配黑边）可以，做**字**不行。
3. **非必要不用饼图** —— 用户原话「角度 26 度和 29 度很难区分，用条形图，数字 29 比 26 高，
   一目了然」。组成/占比默认画**排序条形图 + 标数字**。→ `composition_bar_instead_of_pie()`

细节与理由见 [references/house-style.md](references/house-style.md) §4a–4b。

**配色遇到困难 → 先去 ColorBrewer 查，不要自己发明调色板**（user directive 2026-08-05）：
https://r-graph-gallery.com/38-rcolorbrewers-palettes.html
色块用 qualitative（`Set3` 12 色低饱和，推荐 `set3_with_grey()`）；
**线条/文字先用 `STROKE_COLORS` 六色 —— 黑 → 正红 → 亮蓝 → 深绿 → 咖啡 → 深紫**
（两两最小距离 0.221，比任何填充色板都分得开），用完再取 diverging（`PRGn` `PiYG` `BrBG`）
的两端深色；**颜色不够用时文字标注一律黑色 —— 不会出错的兜底**。
以上均以**白/浅底**为前提（绝大多数图）；深底时白色与浅色单色线条接管。详见
[references/colorbrewer.md](references/colorbrewer.md)。

### 配色来源的全局优先级 —— 五级，取不满才降级（user directive 2026-08-05）

单张图另有明确颜色指定时以那个为准；**没有指定时按这个顺序拿，不得跳级、不得自己发明调色板**：

**铁律：永远第一优先 `Default_A`。只有两种情况才动 B：① 用户明确说要 B；
② A 的颜色不够用，从 B 补后面几个（补充，不是替换）。**
⚠ 曾经那条"每组 ≥4 根并排柱子退到 B"是 agent 自加的判断，**2026-08-05 已被用户废止** ——
不得因为可分度紧就自动降级。A 样本色内部最紧 0.127、B 是 0.149，只作记录不触发切换。

**全量色表**（`print_palette_levels()` 可打印）：

| 级 | 面积（区段 │ 柱子） | 线状（线条/文字） |
| :--- | :---: | :---: |
| **A**（第一优先） | `#80B1D3` 蓝 · `#FDB462` 橙 · `#B3DE69` 绿 │ `#BEBADA` `#FB8072` `#FFED6F` `#FCCDE5` `#BC80BD` `#CCEBC5` | `#8E0152` 酒红实线 · `#003C30` 深青绿虚线 · `#0000CD` blue3 · `#8B4500` darkorange4 · `#9400D3` darkviolet |
| **B**（仅点名/补充） | `#999999` 灰 · `#FDB462` · `#B3DE69` │ `#8DD3C7` `#FB8072` `#FFED6F` `#C75C9F` `#E9A6A1` `#B87542` | `#E41A1C` 正红 · `#1F78B4` 亮蓝 · `#0000CD` blue3 · `#CD5B45` coral3 · `#32CD32` limegreen |
| 3 ColorBrewer | `#8DD3C7` `#FFFFB3`⚠ `#BEBADA` `#FB8072` `#999999` `#FDB462` `#B3DE69` `#FCCDE5` `#D9D9D9` `#BC80BD` `#CCEBC5` `#FFED6F` | `#000000` `#E41A1C` `#1F78B4` `#006D2C` `#8C510A` `#762A83` |
| 4 手调全彩 | `#73C6CF` `#C75C9F` `#E9A6A1` `#B87542` `#70487E` `#6B6B2F` | `#C71585` `#17BECF` `#0055E5` |
| 5 黑白灰 | `#ABABAB` `#828282` `#5A5A5A` | `#000000` `#4D4D4D` |

**只分两类**（user directive 2026-08-06）：**面积**（区段/柱子，都是有面积的结构，阈值 1.1–10 不得近黑）
与**线状**（线条/文字，都是一两像素的笔画，阈值 ≥1.5 无上限）。原来分"区段/柱子/线条"三类是错的 ——
阈值体系只有两档，取色池代码里区段色与柱子色本来就合并成一个池，展示层分三类与断言层对不上。
面积一栏 │ 左边 = 区段的固定语义映射，右边 = 柱子色序列；**同图里这两段必须互不相交**
（那是 `assert_no_palette_collision()` 管的图级约束，不是颜色本身的属性）。

⚠ `#FFFFB3` 对白底 1.04，低于填充阈值 1.1，**永远被自动剔除**。

### 基本原则：本级不够就**自动向下一级取**（user directive 2026-08-06）

面积色与线状色都适用：当前级取不满 n 个就自动到下一级继续取，**只排除"肉眼分不清"的颜色**，
不因为"有点像"就跳过。入口：`fills_by_priority(n)` / `sample_fills(n)` / **`strokes_by_priority(n)`**
（线状色的级联函数，2026-08-06 新增 —— 此前五套线条常量各自孤立、没有级联）。

**门槛 `EYE_THRESHOLD = 0.10`，是实测校准出来的**：用户看 blue3 `#0000CD` 与截图边框
`#0221D2`（距离 **0.087**）时说「这两个蓝色我分不太清楚」；`assert_no_palette_collision()`
的默认门槛 0.10 正好压在这个经验值之上。

**别与"并排间距"混为一谈 —— 是两件事**：`EYE_THRESHOLD` 0.10 管"算不算重复"（跨级下取的
排除标准）；`min_distance` 0.13 管"并排够不够分得开"（同组 6 根柱子的可读性要求，更严）。
实测：把后者放宽到 0.10，已冻结的 Default_B 六个柱子色会全部改变。

**取色入口**：整套 → `DEFAULT_A_*` 常量；n 个柱子色 → `sample_fills(n)`（A 取完再补 B，
门槛 0.10 = A 集自身验证时的门槛，**不要在这里改严，会把 A 自己的色筛掉**）；
用户点名要 B → `sample_fills(n, force_level = "B")`；任意填充色 → `fills_by_priority(n)`。

**可执行实现**（不靠自觉遵守）：
`/home/gao/Utilities/color_and_format/R/color_figures_with_preconfigured_sets/palette_priority.R`
的 `fills_by_priority(n, exclude=)` 逐级取色，并**打印每个颜色实际来自第几级**；
候选须同时满足白底可读、不近黑、与 `exclude` 及已选色的距离 ≥ 门槛。
**`exclude` 里除了别的 panel 的色块，一定要放图上的底纹/背景色** —— Set3 的 `#D9D9D9`
距浅灰底纹 `#F2F2F2` 仅 0.098，漏掉就会画出"柱子和底纹分不开"的图。
两套完整配色固化为总纲文件里的 `DEFAULT_A_*` / `DEFAULT_B_*`（+ 两套共用的 `DEFAULT_SHADE`）
—— **新图直接引用，不要重新搜色**。`from=` 参数只用于复现某套配色定下时的候选池
（已冻结的 Default_B 图传 `from = c("3","4","5")`）；`source()` 时自动跑
`check_default_b_palette_unchanged()` 盯住通用池与门槛。

**产物分目录、互不覆盖**：Default_B 的图在第一层与 `Advanced/`，**Default_A 的图在
`Alternative/`**（与第一层同名不同目录）。**A 升为第一优先不等于要重出已冻结的旧图。**
验证图在 `Advanced/`：`plot_6_samples_bar.R`（6 样本）、`plot_3_genes_combined.R`（9 个色块）、
`plot_3_genes_three_palettes.R`（15 个色块）。

### R 与 Python **双实现**：两边必须逐字对齐（user directive 2026-08-06）

配色优先级有**两套等价实现**，同一批颜色、同样的函数名、同样的断言。改了一边就要改另一边：

| | R | Python |
| :--- | :---: | :---: |
| 总纲 | `.../R/color_figures_with_preconfigured_sets/palette_priority.R` | `.../python/color_figures_with_preconfigured_sets/palette_priority.py` |
| 目录结构 | `Advanced/`（3 个验证脚本）· `Alternative/`（Default_A 版 6 图） | 同左，逐一对应 |
| 看全部颜色 | `Rscript palette_priority.R --swatch` | `python palette_priority.py --swatch` |

两边都提供：`DEFAULT_A_*` / `DEFAULT_B_*` 常量、`fills_by_priority(n)`、`sample_fills(n)`、
`palette_report()`、`print_palette_levels()`、`save_palette_swatch()`、
以及 import/source 时**自动跑的回归守卫** `check_default_b_palette_unchanged()`。

**四个跨语言差异，都是会咬人的（实测）：**

1. **`from=` 在 Python 里叫 `from_levels=`** —— `from` 是 Python 关键字。
2. **`brewer(name, 9)` 两边不等价。** Python 的 matplotlib 色图是 256 档查找表，
   按 `cmap(i/(n-1))` 采样会落在档位之间 —— Blues 第 6 色出来是 `#4191C6`，
   而 R 的 `RColorBrewer::brewer.pal(9,"Blues")` 原值是 `#4292C6`，差 1 个 RGB 单位。
   肉眼无差，但**两个版本就不再是同一套颜色**。取 canonical k-class 原表要用
   `matplotlib.colormaps[name].resampled(9)`（档位中心）。
   注意 `brewer(name, 2)` 的"取两端"语义是对的，别为此改坏它。
3. **matplotlib 默认字体没有汉字**，中文标题/标签会渲染成方框。显式指定
   `Noto Sans CJK JP`（本机有）。R 侧同理，用 `systemfonts` 探测后传给 `base_family`。
   **⚠ R 出 PDF 还有更狠的一层（2026-09-17 proj23 实测 46/46 张中招）**：
   `ggsave()` 的**默认 `pdf()` 设备根本写不了 CJK**，每个汉字报一条
   `conversion failure ... in 'mbcsToSbcs'`，**中文标题/图例渲染成一串点，图形本体完全正常**。
   致命点是**只看网页发现不了** —— knitr 给 HTML 出图走 cairo png（中文好好的），
   只有写交付 PDF 时才走默认 pdf 设备，**而交付只要 PDF**。
   ⇒ `ggsave(..., device = if (isTRUE(capabilities("cairo"))) grDevices::cairo_pdf else NULL)`；
   验收 `grep -c mbcsToSbcs` 必须为 0，并**转一页 PNG 用眼睛看过**（细节见
   `~/Utilities/software_pitfalls/r_pdf_cjk.md`）。
4. **`✗`(U+2717) 等符号 CJK 字体里没有**，会变方框 —— 标记一律用 ASCII 的 `X`。

**其余单语言坑**（已在两版代码里注释）：ggplot2 默认**裁掉**超出面板的文字（必须
`clip="off"` + 留 y 空间，否则 `222,842` 会被渲染成 `22,842` —— 是 correctness bug）；
R 默认 `pdf()` 会静默把 `—` 换成 `-`（走 `cairo_pdf`）；matplotlib 的 `hatch=` 对应
R 的 `ggpattern::geom_col_pattern()`。

**排除集分面板给，不要一刀切**：底纹色只约束压在它上面的那些填充；画在白底上的色块不受它约束。
一刀切会白白废掉一批可用家族，把配色逼进族内可分度很低的备选。

**第五条断言：画在色块上面的线条必须与它压住的每个填充色分得开**（user directive 2026-08-05
实测补充）。撞色断言只管**色块 vs 色块**，线条属另一角色、本就不进那条 —— 但一根线画在与它
同色系的色块**上面**，穿过色块的那一段会**直接看不见**，而前四条断言一条都抓不到。
实例：J2 正红 `#E41A1C` 压在 `#BD0026` 上距离 0.102，线在色块里彻底消失，只有肉眼看图才发现。
用 `assert_strokes_visible_over_fills()`（见 `Advanced/plot_3_genes_three_palettes.R`），门槛同为 0.13。
**黑色在这里不是万能兜底** —— 色块边框通常就是黑色，线又常落在色块边界上，黑线会和边框混成一条。

## 强制门禁：出图前必须过的四条断言

**前三条是"看起来正常但结论被颠倒"的错误，人眼抽查抓不到；第四条是审美硬伤。都必须写成断言。**
详细判据、反例、话术见 [references/panel-color-discipline.md](references/panel-color-discipline.md)。

| # | 规则 | 断言 |
| :--- | :---: | :---: |
| 1 | 同一张图里**语义不同**的 panel，**色块**配色必须互不相交 | `assert_no_palette_collision()` |
| 2 | 同一张图里**语义相同**的 panel，配色必须完全一致 | `assert_shared_palette()` |
| 3 | 白底上的 line / point / text 颜色必须够深（pale yellow 禁用） | `assert_visible_on_white()` |
| 4 | 大面积填充**不得是黑或近黑**（论文/presentation 大忌，极不美观） | `assert_fill_not_near_black()` |

**为什么必须是断言而不是"注意一下"**：matplotlib 每个 axes 从 `C0` 重新起色环，
ggplot2 每张图从 `hue_pal()` 重新起色环——**第二个 panel 会静默拿到和第一个完全相同的前几个颜色**。
读者默认「同色 = 同义」，于是把两个无关的 panel 读成上下对照。
这不是配色难看，是**直接误导**（2026-08-04 项目26 实际发生：上 panel 蓝/橙/绿 = 载体区段，
下 panel 蓝/橙/绿 = 三个样本，用户原话「我作为专家都看糊涂了，客户一定看不懂」）。

**大面积填充不得近黑**（user directive 2026-08-05）：`ink #272727` 刷成一根大柱子对白底
对比度 14.94，读者先看到的是一团墨而不是数据 —— 用户原话「黑色实心图极其不美观」。
灰阶分组用 `PALETTE_FAMILIES["grey"]`（`#ABABAB`→`#828282`→`#5A5A5A`，**浅到深、止于中灰**）；
`ink`/`grey_dark` 只用于文字和细线。反向推到接近白之前，先确认最浅色和背景底纹分得开。

**约束只施加在同一角色之间**（user directive 2026-08-05）：硬约束是**色块 vs 色块**
（bar / rect / area / box 的填充）。线条色和文字色是另一个通道，**不进这条断言** ——
一根细线和一根柱子同色不会被读成同义，把它们也算进排除名单会白白压掉一半可用色相。
**颜色不够用时，文字标注直接用黑色。** 断言只喂填充色：

```python
assert_no_palette_collision({"top FILLS: segment": seg_fills, "bottom FILLS: sample": sample_fills})
```

**文字与色块对饱和度的要求相反**（user directive 2026-08-05）：文字/细线是一两像素宽的笔画，
**要够饱和够深**；色块是大面积，**很弱的饱和度就看得清清楚楚**，满饱和反而盖过数据。
同一色相 → 线用满饱和、填充用 `soften_for_fill(color, 0.5)`。这也顺带解决了跨面板问题：
同色相不同饱和，是同一色族但绝不会被当成同一个变量。

另外两条同源的硬性要求：
- **legend 绝不用 `loc="best"` / `legend.position="inside"`** —— 分组少时它会把图例压在数据上。
  用 `legend_outside(ax)` / `theme_legend_outside()`。
- **本该显示全部样本的 PCA/scatter，出图后要 COUNT 点数**，不能眼看"差不多对"。
  `assert_points_drawn(ax, n)` —— ggplot2 的 discrete shape scale 只支持 6 个 level，
  第 7 个起**静默丢弃**整行（项目20 实测 37 个样本只画出 19 个，已交付后被客户指出）。

---

## 快速开始

```python
import sys; sys.path.insert(0, "/home/gao/.claude/skills/scientific-figure-making/assets")
from pubfig import *

apply_publication_style(FigureStyle(font_size=24, axes_linewidth=3))   # 大 bar 面板
fig, ax = plt.subplots(figsize=(16, 5))
make_grouped_bar(ax, categories, series, labels, ylabel="Score",
                 colors=[PALETTE["blue_main"], PALETTE["green_3"], PALETTE["red_strong"]],
                 annotate=True)
tighten_ylim(ax, series)          # 别把 85–95 的数据画在 0–100 里
legend_outside(ax, ncol=3)
finalize_figure(fig, "figures/comparison", formats=["png", "pdf"], dpi=300)
```

```r
source("/home/gao/.claude/skills/scientific-figure-making/assets/pubfig.R")

method_colors <- c(Ours = PALETTE[["blue_main"]], Baseline = PALETTE[["red_strong"]])
assert_visible_on_white(method_colors, role = "fill")
p <- ggplot(df, aes(metric, score, fill = method)) +
  geom_col(position = position_dodge(.8), width = .7, colour = "black", linewidth = .5) +
  scale_fill_manual(values = method_colors) +
  theme_pub(font_size = 14) + theme_legend_outside("top")
finalize_figure(p, "figures/comparison", formats = c("png", "pdf"), dpi = 300)
```

两个模块都自带 self-test，改动后先跑一遍：

```bash
conda run -n regular_bioinfo python  assets/selftest.py  /tmp/pubfig_check
conda run -n regular_bioinfo Rscript assets/selftest.R   /tmp/pubfig_check_R
```

---

## 相关文件

| 文件 | 什么时候打开 |
| :--- | :---: |
| [references/panel-color-discipline.md](references/panel-color-discipline.md) | **多 panel 组图、任何配色决策前必读** |
| [references/colorbrewer.md](references/colorbrewer.md) | **选不出颜色时来这里** —— ColorBrewer 按角色取色、已知的坑 |
| [references/house-style.md](references/house-style.md) | 字号/线宽/宽高比/y 轴/bar 编码/导出策略 |
| [references/api.md](references/api.md) | `pubfig.py` / `pubfig.R` 完整函数签名与 `PALETTE` |
| [references/demos.md](references/demos.md) | 上游 `figure_*` 真实论文图脚本索引，按图型查 |
| `assets/selftest.py` / `assets/selftest.R` | 可运行的端到端范例（bar / trend / heatmap / scatter） |

按需打开，不要一次性全部预读。

## 数据保真与渲染后验证（2026-09-11 自 Claude Science 内置 `figure-style` 吸收，Apache-2.0）

> **为什么加这一节**：本 skill 原本**全部重量压在配色上**，而我们真正交付出去的错误
> 有一半不是配色错，是**图画对了、说明写错了**或**数据在图上悄悄少了一块**。
> 内置 `figure-style` 把这一层写成了可执行规则，取舍对照见
> `projects_2026M7/35_Try_of_Claude_Science/docs/P35_figure_style_vs_ours_0911.md`。
> **配色与既有断言仍以本 skill 上文为准，本节是补上缺的一层，不是替换。**

**六条，前三条对应我们真实发生过的事故，优先做。**

| # | 规则 | 判据 / 怎么执行 | 我们踩过的坑 |
| :--- | :---: | :---: | :---: |
| 1 | **标题与 caption 里的每一句断言，必须对轴上每一个类别都成立** | **画完之后**拿出图的那份数据逐类别验一遍；不成立就限定（"on 3 of 4 pairs"）或降级成描述。**不许先写 caption 再画图** | 2026-09-10：caption 写 `top 40 by adjusted P`，实际画的是 balanced 20/20，**8 个基因不在字面 top40**。我上一轮只核了 DEG 数，没核**选取规则** |
| 2 | **被排除 / 被截断的数据绝不进入汇总统计，并且必须在图上留痕** | 要么整行不画，要么用空心或斜纹画出来并在图例里命名。**"取前 N 条"必须在图上写明是取前 N 条** | proj29：判读图用 `break` 实现"最多取 N 条"= **空间截断而非抽稀**，12 张图全部无效，而排版配色全对，看不出来 |
| 3 | **一个量只有一个规范值** | 同一个数字出现在 panel、caption、报告正文里必须完全一致；不一致时**先查是不是算错了**，不要就地改字 | 「同一事实出现两处就必须有检查比对」本来就是我们的规则，但**从没写进出图流程** |
| 4 | **标签的下限与上限** | **下限**：图上每一个视觉上可区分的标记，都必须能**只看图**就认出来（图例或直接标注）。**上限**：轴标签与刻度之外的叙述性标注**超过 6 条就是多了**，删到剩关键的 | 我们只有"图例别压住数据"，**没有"标签过多"这一侧的判据** |
| 5 | **两类几何/语义错误直接禁止** | ① **log 轴上不画填充柱**（柱长编码的是与任意基线的比值，无意义）—— 用点 + 中位线；② **断轴的缺口里不画参考线/阈值线/标注**（缺口没有坐标） | 尚未发生，但属于"画出来就是错的"那一类，先堵上 |
| 6 | **渲染后验证：几何 + 人眼，两道都要** | **① 几何**：存图后用文字/轴线的 bounding box 做碰撞检测（文字互压、文字压轴线、文字出画布）。⚠ 刻度标签压在自己那根轴线上**是正常的，不算命中**，否则全是假阳性。**② 人眼**：把图**逐 panel 裁出来**单独看 —— 低对比度、引线交叉、两个系列颜色像，几何检查一条都抓不到 | 交付前自查里写着"每个 panel 都人眼看过"，但**一直没有工具**；裁图这一步能把它变成可执行动作 |

⚠ **第 6 条已有本机实证**：0910 那轮 Claude Science 写的 `figure_qc.R` 就是这套思路，
**并自带 4 个故意做坏的测试图**证明检测器能报真阳性；我独立复跑，**4/4 行为与声称一致**
（文字互压 6.0 pt、文字压轴线 24.0 pt、页边裁切 1.5%）。

### 已落成代码断言的（2026-09-12，R / Python 双实现，种子错误注入验收通过）

| 条 | 函数（两边同名） | 验收 |
| :--- | :---: | :---: |
| #4 标签上限 | `assert_label_ceiling(ax/p, max_annotations=6)` | 干净图通过 **+** 超限图报错，两个方向都验 |
| #5 log 轴填充柱 | `assert_no_filled_bars_on_log_axis(ax/p)` | 同上 |
| #5 断轴缺口内画东西 | `assert_nothing_in_axis_break(ax/p, break_range, axis)` | 同上 |
| #6 渲染后几何检查 | `assert_no_text_collisions(fig/p)` | 同上 |
| #6 逐 panel 裁图 | `panel_crops(fig/p)` —— **工具不是断言** | 返回每 panel 一个框 |

实现在 `assets/pubfig.py` / `assets/pubfig.R`，验收在 `assets/selftest.{py,R}`。
**改了判据必须两个都跑：**

```bash
python3 ~/.claude/skills/scientific-figure-making/assets/selftest.py /tmp/st_py
conda run -n regular_bioinfo Rscript ~/.claude/skills/scientific-figure-making/assets/selftest.R /tmp/st_R
```

⚠ **种子错误注入当场抓到我自己写的两个 bug** —— 这就是"两个方向都要验"的理由：
**① Python 侧误报**：matplotlib 保留超出视图范围的刻度标签 Text 对象，不剔除则**任何**普通图
都报"文字出画布"，闸门当场变噪音。**② R 侧假阴性**：用 `downViewport` 取到的是各 viewport 内的
相对英寸、跨 grob 不可比，重叠检测**恒不触发**，静默放行坏图。只验真阳性那一侧，两个都会溜过去。

⚠ **仍是检查清单、尚未代码化的**：#1（claim-title 对每类成立）与 #2（排除/截断留痕）——
要它们成为断言，出图脚本必须**显式声明选取规则与被排除行**，属于改脚本约定，第二批做。
#3（一个 claim 一个数）是跨文件比对，属交付前自审脚本，不是绘图断言。**这三条不得声称"已由断言保证"。**

⚠ **R 与 Python 的一处真实差异（不是偷工）**：`assert_no_text_collisions()` py 侧还查"文字压轴线"，
R 侧不查 —— ggplot2 的轴线是 polyline grob、与刻度标签本来就贴着，逐个配对全是假阳性。
那一类交给 `panel_crops()` 的人眼看。

## 交付前自查

- [ ] 三条配色断言写进脚本了（不是只在脑子里检查过）
- [ ] **每一个 panel 都人眼看过**——不能看了一张就推断其余同样正确
      （项目26：TG_MTTH 那张没问题，TG_CD1A 的图例却压在柱子上）
- [ ] 图例/坐标轴文字没有重叠、没有被数据盖住
- [ ] 该显示 N 个样本的图，点数真的是 N
- [ ] **caption/标题里的每句断言，逐类别验过**（上节 #1）
- [ ] **被排除或被截断的数据，在图上留了痕**（上节 #2）
- [ ] **同一个数字在图、caption、正文里一致**（上节 #3）
- [ ] **逐 panel 裁图看过**，不是只看整张缩略图（上节 #6）
- [ ] 修正旧图时，**旧版先归档到 `superseded_for_comparison/` 再覆盖**（见全局规则）
- [ ] **正文对一组样本的每句断言，图里每个样本都有对应 panel/点**（P45 Fig2：正文写 "S06–S10 无 LOH"，图只画了 S06）
- [ ] **样本 ID 一律带分组/细胞系标签**（`S11 Mutu I pop`，不只写 `S11`），表头、图例、read 标签同理
- [ ] 稀有类别在线性刻度下看不见 ⇒ 对数刻度并标数值；"0" 与"无法评估/underpowered"用不同记号区分
- [ ] 图号按正文 Results **首次出现顺序**编，不按出图脚本顺序（P45 曾为 1、3、5、0、4、2）


---

## 从 CLAUDE.md 搬入（2026-08-30，逐字未改）

> 分层重构时核查发现：本 skill 原有内容**并未完整覆盖**这几节（实测 26%–62%），
> 故把 CLAUDE.md 里的原文整块搬来。与上文若有重叠，**以本节为准（更全）**。

## 同一张图内多 panel 的配色 — 语义相同才共用配色，语义不同**绝不**共用 (MANDATORY — user directive 2026-08-04)

  - **读者默认「同色 = 同义」。** 一张图里若两个 panel 用了同一组颜色，读者必然把它们当成
    上下对照来读 —— 如果它们其实语义不同，这就是**直接误导**，比配色难看严重得多。
  - **规则（两条，无例外）：**
    1. 两个 panel 的颜色**语义相同**（同一变量、同一分组，需要上下对照）→ **必须**用同一套配色，
       且图例只出现一次或明确标注共享。
    2. 两个 panel 的颜色**语义不同** → **必须**使用**互不相交**的配色族，并在各自图例/标题里
       写明这一组颜色代表什么（例：`bar colours = samples; unrelated to the segment colours above`）。
  - **默认色环是这个错误的头号来源。** matplotlib / ggplot2 在每个 axes 上都从 C0/C1/C2 重新开始，
    **会静默地**让第二个 panel 拿到和第一个 panel 相同的前几个颜色。**多 panel 图必须显式指定颜色**，
    不能依赖默认色环。
  - **出图后自查（必做）**：把每个 panel 实际用到的颜色列出来，检查两个集合是否相交；
    相交且语义不同 = 必须改。**更好的做法是写成代码里的硬断言**，撞色直接报错不出图 ——
    范例 `26_.../scripts/7_junction_figure.py` 顶部的 `_overlap` 检查。
  - **图例绝不能用 `loc="best"`。** 分组少时它会把图例塞进绘图区中央、压在数据上
    （TG_CD1A 单样本实测踩到）。固定放在**绘图区之外**（如 `loc="lower left",
    bbox_to_anchor=(0, 1.0)` 配合 `set_title(..., pad=...)`）。
  - 事故（2026-08-04，项目26）：接头结构图上面板 蓝/橙/绿 = mouse flank / homology arm /
    human insert，下面板柱子走默认色环也是 蓝/橙/绿 但表示 三个样本。用户原话：
    **「同一个图上下两个 panel 意思绝对不同，但用了同一配色，我当然以为是上下对照的读」
    「我作为专家都看糊涂了，客户一定看不懂」**。用户据此提出的疑问是"如何区分蓝色和橙色 reads"——
    而图里根本不存在按区段着色的 reads。
  - **多 panel 图的每一张都要人眼看过再交付**，不能只看其中一张就推断其余同样正确
    （同一轮里 TG_MTTH 看着没问题，TG_CD1A 的图例却压在柱子上）。


## Plot color palette on white background (MANDATORY — user directive 2026-07-25)

  - **Never use pale/light yellow as a categorical color on a white plot background** — in any
    plotting library/language (ggplot2, matplotlib, base R, etc.). On white, pale yellow (e.g.
    ColorBrewer `Set1`'s 6th color `#FFFF33`, or similar light-yellow swatches) is nearly
    invisible to the naked eye — both the plotted points/bars AND any text label drawn in that
    same color become unreadable. This is a disaster specifically for text labels (e.g.
    `geom_text_repel` inheriting the point's fill/color aesthetic), not just a minor contrast
    nitpick.
  - When a categorical/qualitative color palette would otherwise assign pale yellow (e.g.
    `RColorBrewer`/ggplot2 `scale_color_brewer(palette = "Set1")` for ≥6 groups), replace it with
    an explicit manual palette (`scale_color_manual`) that swaps the offending color for something
    with real contrast on white — **cyan and magenta are good replacements** (e.g. `#17BECF` for
    cyan, `#E7298A` or `#C71585` for magenta). Keep the rest of the qualitative palette (red, blue,
    green, purple, orange, brown, etc.) as-is.
  - If a label's color is inherited from a per-group aesthetic mapping and that group's color is
    still borderline light, **force the label text color to black explicitly** (e.g.
    `geom_text_repel(..., color = "black")`, overriding the inherited `aes(color = Group)`) rather
    than relying on the point/fill color for text — text legibility takes priority over strict
    color-consistency between point and its own label.
  - Incident that established this rule: `19_Lijian_Wu_Rell1_TNFa_Tumor`'s custom PCA plot
    (`4_run_DE_PCA.R`, `scale_color_brewer(palette = "Set1")`) assigned pale yellow to the
    `Rell1-TNFa` group (6th factor level) — both the points and the `geom_text_repel` sample-name
    labels for that group were essentially invisible on the white background.
