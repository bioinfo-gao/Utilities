# 新配色整合（2026-10-29）

用户已批准加入 Paired_4 与 Categorical_7，并作为新项目的优先候选。

## 唯一色值来源

`palettes.csv` 为两套新方案原始色值的唯一来源，R/Python 都读取它。JPG 保留参考原图，不修改像素或排列。
Paired_4 已将原图最后一色 #8798C9 调到第 4 位，与第 3 位 #A3D8F4 配对；CSV 每相邻两行为一对。
Categorical_7 的橙色按原图 HEX 标注使用 #F07F0F；原说明的 #FF7F0F 是转录差异，不沿用。原图 RGB 数字与 HEX 也不完全一致，本实现明确以 HEX 标注为准。

## 新入口

Python 导入 `python/color_figures_with_preconfigured_sets/palette_priority.py`；R source 对应 R 文件。
两边同名函数，返回普通颜色列表／向量：

```python
select_palette(4)  # 独立类别，auto -> Categorical_7
select_palette(8, relationship="paired")  # 四对；n 是颜色总数
select_palette(4, scheme="Paired_4")  # 四个独立类别，跨对取色
select_palette(4, role="stroke")  # 细线／小点加深版
select_palette(4, scheme="Default_A")  # 显式复现旧方案
```

R 调用参数相同。`relationship` 为 independent/paired，`role` 为 fill/stroke。
项目开始时固定 scheme，建立命名的类别到颜色映射；以后按类别名取子集。不能每张图重新按 n 自动选，否则类别减少时颜色会漂移。
有配对关系：必须偶数且最多 8 色，超过时明确报错，不擅自打散配对。
独立类别：auto 在 1–7 色选择 Categorical_7，更多时整体回退旧 Default_A 级联，不混池。
Paired_4 独立取色顺序：中蓝、浅粉、橙、蓝紫；最多四类。
Categorical_7 独立取色顺序：蓝、红、绿、橙、青、浅红、黄。
这两种新顺序是取色策略，原图顺序仍由 CSV 的 position 保存。

fill 保留原色，用于色块和大点。stroke 将 sRGB 各通道乘 0.75 后四舍五入；这是初版候选加深策略，不是感知均匀变换。文字统一黑／深灰，不用黄色文字。连续热图另选 sequential/diverging，不把分类色表当连续色标。
旧入口 sample_fills/fills_by_priority/strokes_by_priority、旧常量及其五级池完全保留，用于旧项目和结构图。结构图不自动换色。
新方案没有色觉无障碍保证：红粉、绿青、蓝紫仍需结合形状／标签及实际尺寸检查。跨 panel 语义、撞色、点数检查继续执行；不为让新色表通过而降低旧门槛。

## 预览与验证

运行：`python3 /home/gao/Utilities/color_and_format/figure/validate_and_preview_20261029.py`
输出在 `figure/preview_20261029/`：
- scheme_comparison.pdf/png：1 张四行三列对照图，同一套固定种子模拟数据，列为旧 A、Paired_4、Categorical_7；行为散点、箱线、趋势、组成。每个散点 panel 48 点。
- new_scheme_swatches.pdf/png：1 张色卡，含八色四对原序，以及七分类填充／线条版取色顺序。
- contrast_audit.csv：各新色在白底的对比度。
- validation.json：实际测试结果；未做色觉模拟。

预览仅为审美比较，不能作为生物学结果。三列保持同布局和边框，避免把布局差异误判为配色差异。此处箱线图取代表达分布，不改动任何项目数据。统计门槛并不保证美观，也不替代实际尺寸的人眼审阅。
查看上述两张 PDF，判断四类颜色缩小后能否区分、线条是否清晰、两对相近色是否适合你的具体设计；反馈时注明图名、方案名及不满意的颜色／元素即可，下一轮另存版本。

## 原版保存

整合前的两份代码、description.md、作图 skill 原样存于：
`/home/gao/Utilities/color_and_format/superseded_for_comparison/palette_integration/v1_20261029_before_new_schemes/`。
新旧版本并存，不重生成旧图。新项目规范的优先级已同步至 canonical scientific-figure-making skill；通用共享规则未改动。
