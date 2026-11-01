---
name: scientific-figure-making
description: "制作科研及客户交付图：matplotlib/ggplot2 的柱状图、箱线图、折线图、heatmap、scatter/PCA、多 panel 与 PDF/SVG 导出；统一 V12 配色、颜色语义和数据/渲染验证。"
disable-model-invocation: true
---

# 科研作图

数据图由可追溯的 R/Python 脚本生成。遵循 [house style](references/house-style.md) 的字号、线宽及导出规范；函数见 [API](references/api.md)，实现为 `assets/pubfig.py`、`assets/pubfig.R`。机制/流程图或外部作图服务另读 [external workflow](references/external-figure-workflow.md)。

## 配色：V12 第一优先

新项目默认 V12；用户指定及已有项目的固定语义映射优先，不自动重绘旧图。

- **唯一色值来源**：`/home/gao/Utilities/color_and_format/top_journals/test/04_selected_three_tones_light_medium_dark_v12.csv`。
- [色卡 PDF](/home/gao/Utilities/color_and_format/top_journals/test/04_selected_three_tones_light_medium_dark_v12.pdf)；[九色系样图](/home/gao/Utilities/color_and_format/top_journals/test/v12_examples/00_overview.pdf)。
- 固定顺序：Coral、Teal（偏 Cyan）、Sky blue、Mint、Purple、Gold、Purple pink、Blue、Neutral。每系浅、中、深三档，不自行重新调色。
- 独立类别优先取各色系中间色，最多 9 类；细线可取对应深色，文字默认黑/深灰。
- 同色系两条件取浅、深；三条件取浅、中、深。色相表示类别、色调表示条件，明确图例。27 个色调不等于 27 个独立类别。
- 配对折线：**浅色实线、中色点划线、深色虚线**，可辅以不同点形；已有明确线型语义时保留语义并提高浅线可读性。跨 panel 映射一致，最终尺寸检查浅线。
- Gold 不作文字；白底避免难辨认的浅黄标记；深色 Neutral 避免大面积填满。文字可统一黑色。
- 连续热图另选 sequential/diverging 色标，不用连续色标表达平级类别。不宣称已经验证色盲或灰度友好。

**R/Python 取色入口**（两边规则必须一致）：
- `/home/gao/Utilities/color_and_format/R/color_figures_with_preconfigured_sets/palette_priority.R`
- `/home/gao/Utilities/color_and_format/python/color_figures_with_preconfigured_sets/palette_priority.py`

`select_palette(n, scheme="auto")`：独立类别 n≤9 默认 V12（fill 中色、stroke 深色）；`relationship="paired"` 时 n 为总颜色数，偶数且≤18，按每系浅、深输出。可显式 `scheme="V12"`。三档直接读取 canonical CSV。超容量沿用既有回退，不自造颜色；同项目不能逐 panel 按类别数重新选色。

旧 `sample_fills` 等入口及显式 Categorical_7、Paired_4、Default_A/B 保持原行为。需要旧项目复现或更多配色时查下方归档；More_colors 见 `/home/gao/Utilities/color_and_format/More_colors/integration.md`。

## 图形与数据检查

- 同图同义的 panel 必须同色；不同语义的填充色必须互不相交。显式指定颜色，不依赖默认色环。用 `assert_shared_palette()`、`assert_no_palette_collision()`；判据见 [panel discipline](references/panel-color-discipline.md)。
- 用 `assert_visible_on_white()`、`assert_fill_not_near_black()`、`assert_no_yellow_text()` 检查对应角色；不要通过静默改写定稿色值掩盖失败。
- 图例固定放绘图区外，禁用 `loc="best"`；箱线图 median 统一黑色。组成默认排序条形图并标数值；非必要不用饼图。
- 标题/caption 的选择规则必须与实际数据逐类别相符；明确 top-N、排除及截断，排除数据不进入统计。图、caption、正文的同一数字必须一致。
- 样本级 PCA/scatter 计数实际绘制点，必须等于应显示样本数；样本 ID 附分组/细胞系信息。零与无法评估分开表达。
- 不在 log 轴画填充柱；断轴缺口不放阈值线或标注。稀有类别必要时改用合适的点图/对数尺度并标数值。
- 叙述性标注默认最多 6 条，所有可区分标记都有图例或标签；图号按 Results 首次出现排序。
- 导出 PDF/SVG 与高分辨率预览；存图后检查文字碰撞、越界、裁切，并逐 panel 查看最终图，不能只看整张缩略图。
- 修图前保存旧图和对应脚本以供对照，不原地丢失历史。

可用检查：`assert_points_drawn`、`assert_label_ceiling`、`assert_no_filled_bars_on_log_axis`、`assert_nothing_in_axis_break`、`assert_no_text_collisions`、`panel_crops`。R 碰撞检查不覆盖文字压轴线，须人工看图；caption/选取规则/跨文件数字不能声称已由这些断言保证。

更改绘图助手的判据时，运行 `assets/selftest.py` 和 `assets/selftest.R`，验证干净图及故意失败的例子；只更改文档不必重跑整套出图。

## 历史文档与图片位置

精简前全文原样归档：
[scientific-figure-making_full.md](superseded_for_comparison/skill/v2_20261031_before_concise_v12/scientific-figure-making_full.md)。包含旧五级优先级、历史依据、示例及旧规则细节；与本文冲突时以本文为准。

原图保留，不代表当前优先级：
- [旧五级优先级色卡](/home/gao/Utilities/color_and_format/R/color_figures_with_preconfigured_sets/palette_levels_swatch.pdf)。
- [Categorical_7 / Paired_4 色卡](/home/gao/Utilities/color_and_format/figure/preview_20261029/new_scheme_swatches.pdf)。
- [旧方案对比样图](/home/gao/Utilities/color_and_format/figure/preview_20261029/scheme_comparison.pdf)。
- V12 接入前 R/Python 入口快照：`/home/gao/Utilities/color_and_format/superseded_for_comparison/palette_priority/v1_20261031_before_v12_priority/`。
