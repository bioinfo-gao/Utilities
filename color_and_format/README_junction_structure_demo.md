# Junction structure 图 — Python / R × 黑白 / 全彩 共四套

用 `/scientific-figure-making` skill 重做的项目26 接头结构图，
放在这里作为**配色纪律 + house style 的可复制范例**。**代码与产物同目录**。

| 目录 | 下面板编码 | 用途 |
| :--- | :--- | :--- |
| [python/grey_figures/](python/grey_figures/) | 灰阶 + hatch | 黑白印刷、灰度友好 |
| [python/color_figures/](python/color_figures/) | 全彩（cyan / magenta / pink …） | 当前科研主流，投稿与 slide |
| [R/grey_figures/](R/grey_figures/) | 灰阶 + hatch（ggpattern） | 同上，R 版 |
| [R/color_figures/](R/color_figures/) | 全彩（手调） | 同上，R 版 |
| [R/color_figures_with_preconfigured_sets/](R/color_figures_with_preconfigured_sets/) | 全彩（预置色板：ColorBrewer） | 颜色不手调，全部取自成熟色板 |
| [python/color_figures_with_preconfigured_sets/](python/color_figures_with_preconfigured_sets/) | 同上，**Python 版** | 与 R 版**同一套配色、同样的函数名与断言** |

每个目录里 3 张图 × (png + pdf)，脚本就在同一目录：

```bash
cd python/color_figures && conda run -n regular_bioinfo python  plot_junction_structure.py
cd R/color_figures     && conda run -n regular_bioinfo Rscript plot_junction_structure.R
```

同语言的黑白版与全彩版**只差配色块和下面板标题**，可直接 `diff` 对照。

## 这几份代码想演示什么

**同一张图里语义不同的 panel，色块配色必须互不相交** —— 上面板 = 构建体区段
（mouse flank / homology arm / human insert）；下面板 = 样本。两者毫无关系。
matplotlib 每个 axes、ggplot2 每张 plot 都会从头重新分配默认色环，**撞色是静默发生的**，
因此断言在出图前跑，撞色/低对比度/近黑填充直接终止：

```
assert_no_palette_collision()   语义不同的 panel 之间配色不相交（含近似色）
assert_visible_on_white()       白底 WCAG 对比度（pale yellow 实测 1.07，禁用）
assert_fill_not_near_black()    大面积填充不得近黑（ink #272727 对比度 14.94）
柱数自检                          柱子数 == 样本数 × 接头数，静默丢柱直接报错
```

### 约束只施加在**同一角色**之间

硬约束是**色块 vs 色块**。上面板真正的色块只有 3 个（蓝 `#0F4D92` / 金 `#FFD700` /
绿 `#8BCF8B`）；品红 `#C71585` 和青 `#17BECF` 只是 J1/J2 的**细线和标签**，属另一个通道。
所以全彩版把 cyan 和 magenta 用作柱子填充**不构成撞色** —— 一根细线和一根柱子同色不会被
读成同义。把线条色也算进排除名单，会白白压掉一半可用色相。
**颜色不够用时，文字标注直接用黑色。**

### 两套下面板配色

| 版本 | 色序 | 备注 |
| :--- | :--- | :--- |
| 灰阶 | `#ABABAB` → `#828282` → `#5A5A5A` | 浅→深且止于中灰。不从 `#272727` 起（大面积近黑在论文/slide 上极不美观）；也不推到接近白（J1 底纹 `#F2F2F2` 会吃掉最浅柱，实测 `#E8E8E8` 距底纹仅 0.039）|
| 全彩 | cyan `#17BECF` → magenta `#C71585` → pink `#E9A6A1` → `#B87542` → `#70487E` → olive `#6B6B2F` | 前 3 色两两最小间距 0.389。4/5 号是深橙 `#D95F02`、深紫 `#7B3294` **降饱和**后的版本（S×0.65 V×0.85）——只降到 S×0.55 时橙色与 pink 只差 0.128，四样本以上分不开 |

旧版本（近黑柱 / 过浅柱）留在 [superseded_for_comparison/](superseded_for_comparison/) 供并排对照。

## 配色来源的全局优先级（user directive 2026-08-05）

单张图另有明确颜色指定时以那个为准；没有指定时按下面的顺序取，**取不满才降级**：

| 级 | 区段/结构（3 色） | 柱子/分类 | 线条/文字 |
| :--- | :--- | :--- | :--- |
| **A**（第一优先） | `#80B1D3` 蓝 · `#FDB462` 橙 · `#B3DE69` 绿 | `#BEBADA` `#FB8072` `#FFED6F` `#FCCDE5` `#BC80BD` `#CCEBC5` | `#8E0152` 酒红实线 · `#003C30` 深青绿虚线 |
| **B**（仅点名/补充） | `#999999` 灰 · `#FDB462` · `#B3DE69` | `#8DD3C7` `#FB8072` `#FFED6F` `#C75C9F` `#E9A6A1` `#B87542` | `#E41A1C` 正红 · `#1F78B4` 亮蓝 |
| 3 ColorBrewer | — | `#8DD3C7` `#FFFFB3`⚠ `#BEBADA` `#FB8072` `#999999` `#FDB462` `#B3DE69` `#FCCDE5` `#D9D9D9` `#BC80BD` `#CCEBC5` `#FFED6F` | `#000000` `#E41A1C` `#1F78B4` `#006D2C` `#8C510A` `#762A83` |
| 4 手调全彩 | — | `#73C6CF` `#C75C9F` `#E9A6A1` `#B87542` `#70487E` `#6B6B2F` | `#C71585` `#17BECF` |
| 5 黑白灰 | — | `#ABABAB` `#828282` `#5A5A5A` | `#000000` `#4D4D4D` |

⚠ `#FFFFB3` 对白底 1.04，低于填充阈值 1.1，**永远被自动剔除**。

**铁律：永远第一优先 `Default_A`。只有两种情况才动 B：① 用户明确说要 B；
② A 的颜色不够用，从 B 补后面几个（补充，不是替换）。**
⚠ 曾经那条"每组 ≥4 根并排柱子退到 B"是 agent 自加的判断，**2026-08-05 已被用户废止** ——
不得因为可分度紧就自动降级。A 样本色内部最紧 0.127、B 是 0.149，只作记录不触发切换。

**Default_A 里的淡蓝 `#80B1D3` 就是 stock `Set3` 的第 5 色 —— 也正是 `set3_with_grey()`
换成中灰 `#999999` 的那一个。** 用户看到的是刷新前的旧图；刷新后两端变灰就是这次替换生效。
**代价（当初换掉它的原因）**：它与 teal `#8DD3C7` 只差 **0.096**，低于 0.10 撞色门槛 ——
**二者互斥，用了蓝就没有 teal**。

**已冻结的图不因优先级调整而重出**：`fills_by_priority()` 的 `from=` 参数用于复现某套配色
定下时的候选池（Default_B 那批传 `from = c("3","4","5")`），所以 A 升为第一优先后，
第一层与 `Advanced/` 的 9 张图 MD5 一个字节没变。

### R 与 Python 两套等价实现（2026-08-06 起）

同一套规则有 **R 与 Python 两个实现**，目录结构逐一对应，**改一边就要改另一边**：

```
{R,python}/color_figures_with_preconfigured_sets/
├── palette_priority.{R,py}          ← 总纲（五级优先级 + Default_A/B 常量 + 守卫）
├── palette_levels_swatch.png/.pdf   ← **色卡：每一级的每个颜色，肉眼直接看**
├── plot_junction_structure.{R,py}   ← Default_B 版（第一层，已冻结）
├── Advanced/                        ← 3 个验证脚本（6 样本 / 9 色块 / 15 色块）
└── Alternative/                     ← Default_A 版，与第一层同名的 6 个图
```

看全部颜色：`Rscript palette_priority.R --swatch` 或 `python palette_priority.py --swatch`。

**四个跨语言差异（都实测踩过）**：① R 的 `from=` 在 Python 里叫 `from_levels=`；
② `brewer(name, 9)` 两边**不等价** —— matplotlib 是 256 档查找表，按 `i/(n-1)` 采样会落在档位
之间（Blues 第 6 色 `#4191C6` vs R 原值 `#4292C6`，差 1 个 RGB 单位），取 canonical 原表要用
`colormaps[name].resampled(9)`；③ matplotlib 默认字体**没有汉字**，中文会变方框，须显式指定
`Noto Sans CJK JP`；④ `✗`(U+2717) 在 CJK 字体里没有字形，标记一律用 ASCII 的 `X`。

**总纲**在各自目录的第一层，**验证代码与验证图**在它下面的 `Advanced/` 子文件夹：

| 文件 | 位置 | 作用 |
| :--- | :---: | :--- |
| `palette_priority.R` | 总纲（上层） | 优先级本身 + `DEFAULT_A_*` / `DEFAULT_B_*` 两套配色常量。`fills_by_priority(n, exclude=)` 逐级取色并**打印每色来自哪一级** |
| `plot_6_samples_bar.R` → `6_samples_bar_plots.png/.pdf` | `Advanced/` | 初级验证：6 样本 × 4 接头，24 根柱子 |
| `plot_3_genes_combined.R` → `3_genes_combined_junction_structure.png/.pdf` | `Advanced/` | 高级验证：3 个结构面板 + 合并柱状面板，一张图 9 个色块 |
| `plot_3_genes_three_palettes.R` → `3_genes_three_palettes_junction_structure.png/.pdf` | `Advanced/` | 高难度验证：三个结构面板**各一套家族**，一张图 **15 个色块** |
| `plot_junction_structure_alt.R` → `TG_{MTTH,RAGH,CD1A}_junction_structure.png/.pdf` | `Alternative/` | **Default_A（第 1 优先）版**：与第一层同名的 6 个图，只差配色（见下） |

### `Alternative/` —— **Default_A**（第 1 优先）的产物（user directive 2026-08-05）

用户原话：「这个截图里的配色完美，对人类阅读者是好极了。**实际上我更加喜欢。**」
随后定为 **`Default_A`，配色选择的第一优先**。已固化为 `palette_priority.R` 里的 `DEFAULT_A_*`
常量，产物是与第一层**同名的 6 个文件**，靠目录区分、互不覆盖。
（目录名 `Alternative/` 早于这次 A/B 命名，沿用不动 —— 里面装的是第 1 优先那套。）

| | 第一层（Default_B，第 2 优先） | `Alternative/`（Default_A，第 1 优先） |
| :--- | :---: | :---: |
| 侧翼 | `#999999` 中灰 | **`#80B1D3` 淡蓝** |
| HA / 插入 | `#FDB462` / `#B3DE69` | 同左（未变） |
| 柱子 | teal `#8DD3C7` 起 | **淡紫 `#BEBADA` 起**（teal 撞蓝侧翼 0.096，出局） |
| 接头线 | 正红 / 亮蓝（`STROKE_COLORS`） | **酒红 `#8E0152` / 深青绿 `#003C30`**（PiYG + BrBG 深端） |

实测：区段 vs 样本最紧 0.118（`#80B1D3` vs `#BEBADA`），样本内部最紧 0.127 ——
都过 `assert_no_palette_collision()` 的 0.10 门槛，但**低于我们给并排柱子用的 0.13**，
这两个数字**只作记录，不触发自动降级** —— 永远先用 A（2026-08-05 用户裁定）。
接头线距区段色 0.512，线穿过色块不会消失。

三个验证脚本**不改动、不 source** 上一层的 `plot_junction_structure.R`（三张单基因图的原始实现，
独立冻结），只共享上一层的 `palette_priority.R` 与只读数据。脚本会在**本目录与上一层**两处
查找 `palette_priority.R`，所以整个 `Advanced/` 挪位置也不会断。

**Default_B 的 6 个柱子色是怎么搜出来的**（`Advanced/` 那批图）：从通用池按第 3→4→5 级取，
**3 个来自第 3 级、3 个来自第 4 级，第 5 级未动用**。第 3 级没能全包不是设置失效，而是排除条件
生效了 —— `#D9D9D9`/`#CCEBC5`/`#FCCDE5` 离浅灰底纹 `#F2F2F2` 太近（0.098 / 0.125 / 0.103），
`#BC80BD` 离区段中灰 `#999999` 只有 0.123。这套已固化为 `DEFAULT_B_*`，
`source()` 时由 `check_default_b_palette_unchanged()` 自动守卫，改动会立刻报错而非静默换色。

### 15 色块那张图学到的两件事

1. **排除集要分面板给，不要一刀切。** 底纹 `#F2F2F2` 只出现在下面板、只有柱子压在它上面；
   上面板的区段画在白底上，与它从不相邻。一刀切会废掉 Blues/Greys/PuBu 几个家族
   （Blues 最浅的 `#C6DBEF` 距底纹 0.101），把 MTTH 逼进族内只有 0.151 的 BuPu ——
   出图后肉眼可见 HA 与 human insert 两块紫色分不清。
2. **线条压在色块上会"消失"，而撞色断言一条都抓不到。** 撞色断言只管色块 vs 色块；
   一根线画在与它同色系的色块**上面**，穿过色块那一段直接看不见。实例：J2 正红 `#E41A1C`
   压在 CD1A 家族的 `#BD0026` 上距离仅 0.102，所有断言通过、只有肉眼发现。
   补 `assert_strokes_visible_over_fills()`；注意**黑色不是万能兜底** ——
   区段边框本来就是黑的，而 J2 恰好落在区段边界上，黑线会和边框混成一条。

配套：legend 一律固定在绘图区之外（绝不用 `loc="best"` / `legend.position="inside"`）。

## 两个语言的实现差异

| 项 | Python | R |
| :--- | :---: | :---: |
| hatch 第二通道 | matplotlib 原生 `hatch=` | `ggpattern::geom_col_pattern()` |
| 文字超出绘图区 | 默认**不裁剪** | 默认**直接裁掉** → 必须 `clip="off"` + 留 y 空间 |
| UTF-8 导出 | 无问题 | 默认 `pdf()` 会静默把 `—` 换成 `-`，须走 `cairo_pdf` |

中间两条都是**会在图上产生错误内容**的坑，不是排版问题：R 首版把 `222,842` 渲染成
`22,842`（首位被裁掉），靠人眼看图才发现。

## 数据来源

只读，不修改，来自项目26 两个**已冻结**的交付包：

- `26_Ellen_MTTH_junction_sequences/custom_research_report_supplementary_MTTH_20260804/`
- `26_Ellen_MTTH_junction_sequences/custom_research_report_supplementary_RAGH_CD1A_20260804/`

各取 `coordinates/junction_coordinates.tsv` 与 `junction_reads/spanning_summary.tsv`。
**这里的图不回写交付包**——交付包保持原样冻结。
