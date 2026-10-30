# More_colors 接入说明（2026-10-29）

已逐张查看 Scientific 的4张 JPG、Nature_style 的1张 JPG，以及两份说明。原图和原说明保持不动。这里只把已核对的部分色卡接入现有 R/Python palette_priority，不另建配色引擎。

## 来源与唯一色值文件

新增方案的 canonical 色值在本目录 `palettes.csv`，列为 scheme、kind、position、fill、source；旧 Categorical_7 / Paired_4 仍以 `../figure/palettes.csv` 为唯一来源。两份文件管理不同方案，不复制相同方案。

色值按原图 HEX 标注核对，保留该标注而非 JPG 压缩像素；RGB 与 HEX 冲突时以 HEX 为准。Scientific/3.jpg 的最后两个浅黄/浅蓝是辅助色，未混入红色 sequential。原图深→浅的单色卡已反序为低→高（浅→深）；蓝粉卡保留原顺序，标为 multihue，不声称明度单调或零点居中。

| 入口与名称 | 用途 | 采用边界 |
| :--- | :---: | :---: |
| `select_palette(n, scheme="Nature_3/4/5/9")`，斜线表示4个独立名称 | 3、4、5、9色分类备选 | n 不超过方案容量；先定全项目映射再取子集；没有配对语义 |
| `color_scale("Scientific_Yellow/Red/Purple")`，每个名称分别调用 | 非负丰度、计数、密度、概率 | 浅→深；不用于平级细胞类型；黄色不用作文字或白底细线 |
| `color_scale("Scientific_BluePink")` | 用户明确选择的蓝粉连续色带 | 未验证感知均匀性，不默认用于正负效应或相关性 |
| `color_scale("Nature_Sequential_Purple/Gold/Blue/Red")` | 四类单色连续色标 | 斜线表示四个方案，不是一个可执行名称 |

原 Nature 图含多套2–5色组合、6–9色组合及“20+分类”。当前分类库选择3/4/5色各一组及最后一行9色，连续库收录底部4组；未转录的方案仍是参考素材，不会被自动调用。“20+分类”含大量同族近色，不直接作为20个以上平级细胞类型的默认配色；可先分大类、分面或用文字标签。原图的“Nature 原刊”与“色觉障碍友好”没有附可核实原文或模拟证据，本地名称 Nature 仅表示素材来源/灵感，不表示期刊认证。Scientific 说明中的“黑白也能区分”亦未验证。

## 调用与选型

```python
from palette_priority import select_palette, color_scale
from matplotlib.colors import LinearSegmentedColormap
colors = select_palette(9, scheme="Nature_9")
cmap = LinearSegmentedColormap.from_list("purple", color_scale("Scientific_Purple"))
```

```r
# source 现有 R/color_figures_with_preconfigured_sets/palette_priority.R
colors <- select_palette(9, scheme = "Nature_9")
# ggplot2: scale_fill_gradientn(colours = color_scale("Scientific_Purple"))
```

`color_scale(..., reverse=TRUE)` 是 R 语法，Python 使用 `reverse=True`。continuous API 返回锚点，由绘图库插值；不自动建立 normalization，也不做 stroke 加深。正负 log fold change、相关系数等需要明确零点的量，继续采用现有 diverging 方案及以0为中心的 normalization，不照搬原图用黄/紫单色表达负相关的示例。

原 auto 行为完全保留：≤7个独立类别用 Categorical_7，更多回退旧 Default_A；Paired_4 仍只用于其适配设计。新方案必须显式选择。分类的 fill/stroke 行为与旧入口一致，但不保证任意新颜色都满足可读性门槛；如过浅，选其他方案或改用标签/形状，不能降低检查阈值或静默替换颜色。

同图语义不同的 panel 不因为“统一色系”就复用相同分类色；相同语义跨图保持颜色映射。连续色标的浅色低值可用于热图，不据此允许浅色细线或黄色文字。填充/点/细线的适用性、跨 panel 颜色碰撞、样本点数及视觉检查沿用主 skill。

## 验证范围

运行 `python3 validate_more_colors.py` 会在本目录创建一个带时间戳的新验证目录：比较 R/Python、检查无效调用确实失败、对比修改前 API 输出、导出方案色卡 PDF/PNG 与白底对比度审计。色卡为配色预览，无生物学数据。结果不等同色觉模拟或出版验收。

旧 skill 与实现原样归档于 `/home/gao/Utilities/AI_and_Agent/Agent_Assets/superseded_for_comparison/palette_more_colors/v1_20261029_before_more_colors/`，与当前版并存。
