# superseded_for_comparison —— 被替换的旧版图件，留作并排对照

规则见全局 CLAUDE.md「原始记录不能丢 — 修正前必须归档旧版」：任何修正在覆盖旧版之前，
先把旧版原样归档，与新版并存，这样才能对照"错的"和"对的"判断改动是否真改对了。

---

## v1_20260805_near_black_bars

| 项 | 内容 |
| :--- | :--- |
| **缺陷** | 下面板样本柱用 `ink #272727` 起的**深→浅**灰阶。`#272727` 对白底 WCAG 对比度 **14.94**，本质是黑色；大面积实心近黑柱在论文和 presentation 上极不美观，会压过数据本身。 |
| **来源** | 用户 2026-08-05 指出：「下面的 panel 是用黑色或者接近黑色的深灰色做图，这在发表或者 presentation 的时候是大忌。黑色实心图极其不美观。」 |
| **怎么改的** | 灰阶改为**浅→深**且最深止于中灰：`#D0D0D0` → `#A0A0A0` → `#707070`（最深对比度 4.95）。同时把这条规则做成 skill 里的硬断言 `assert_fill_not_near_black()`，并把 `PALETTE_FAMILIES["grey"]` 重定义为这条安全 ramp。 |
| **为什么没做成"接近白起"** | 用户给了两个方案，第二个是反向从接近白开始。实测否掉了：J1 分组底纹是 `#F2F2F2`，候选最浅色 `#E8E8E8` 与它的距离只有 **0.039**，柱子会直接糊进底纹。故取第一个方案（大幅降低黑度），起点定在 `#D0D0D0`（与底纹距离 0.133）。 |
| **是原始产物吗** | **是**。这些就是当时实际生成的文件，直接 `cp` 过来，不是事后重跑复现的。 |

内容：

```
v1_20260805_near_black_bars/
├── python_figures/   3 图 × (png + pdf)，matplotlib 版
├── R_figures/        3 图 × (png + pdf)，ggplot2 版
└── scripts/          产生上述图的两份脚本快照（.v1_near_black.py / .R）
```

并排对照：

```bash
cd /home/gao/Utilities/color_and_format
# 旧 vs 新，同一张图
xdg-open superseded_for_comparison/v1_20260805_near_black_bars/python_figures/TG_MTTH_junction_structure.png
xdg-open python/grey_figures/TG_MTTH_junction_structure.png
# 代码差异
diff superseded_for_comparison/v1_20260805_near_black_bars/scripts/plot_junction_structure.v1_near_black.py \
     python/plot_junction_structure.py
```
