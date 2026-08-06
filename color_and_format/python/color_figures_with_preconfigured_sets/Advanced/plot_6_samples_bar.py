#!/usr/bin/env python3
"""初级验证 —— 全局配色优先级是否生效（6 样本条形图）。

**与 R 版 ../../../R/color_figures_with_preconfigured_sets/Advanced/plot_6_samples_bar.R
同数据、同版式、同断言、同配色**，两边必须保持一致。

这不是给客户的图，是**配色优先级设置的验证图**：
6 个样本（MTTH_284 / MTTH_412 / MTTH_524 / RAGH_153 / RAGH_273 / CD1A_B125）
× 4 个接头类别，柱子颜色**完全由 palette_priority.py 按优先级自动取**，
脚本里不手写一个填充色。跑完看两处即可判断设置有没有生效：
  1) 终端打印的 [配色优先级验证] 表 —— 每个颜色来自第几级；
  2) 出来的图 —— 6 根柱子分得开、没有一根和浅灰底纹糊在一起。

版式沿用本系列 bottom panel：4 组，J1（两侧）铺浅灰底、J2（中间）留白。

**本脚本不改动、不 import 上一层的 plot_junction_structure.py** —— 那份是三张
单基因图的原始实现，独立冻结；这里只共享上一层的 palette_priority.py（总纲）与只读数据。

用法：
    conda run -n regular_bioinfo python plot_6_samples_bar.py [outdir]
"""

import csv
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # 无头运行：必须在 import pyplot 之前

import matplotlib.pyplot as plt  # noqa: E402

SKILL = Path("/home/gao/.claude/skills/scientific-figure-making/assets")
sys.path.insert(0, str(SKILL))
from pubfig import (  # noqa: E402
    FigureStyle,
    apply_publication_style,
    assert_fill_not_near_black,
    assert_no_palette_collision,
    assert_visible_on_white,
    finalize_figure,
)

# palette_priority.py 是**总纲**，住在上一层目录；本 Advanced/ 只放验证用的实验代码。
HERE = Path(__file__).resolve().parent
for _cand in (HERE, HERE.parent):
    if (_cand / "palette_priority.py").exists():
        sys.path.insert(0, str(_cand))
        break
else:
    raise SystemExit("找不到 palette_priority.py（本目录与上一层都没有）")
from palette_priority import (  # noqa: E402
    DEFAULT_B_SEG_FILLS,
    DEFAULT_SHADE,
    fills_by_priority,
    palette_report,
)

OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE
STEM = "6_samples_bar_plots"

# 数据来源（只读，不修改）：项目26 两个已冻结的交付包
PROJ = Path("/home/gao/projects_2026M7/26_Ellen_MTTH_junction_sequences")
PACKAGES = [
    PROJ / "custom_research_report_supplementary_MTTH_20260804",
    PROJ / "custom_research_report_supplementary_RAGH_CD1A_20260804",
]

SAMPLES = ["MTTH_284", "MTTH_412", "MTTH_524", "RAGH_153", "RAGH_273", "CD1A_B125"]
JIDS = ["J1_5p", "J2_5p", "J2_3p", "J1_3p"]
SHADE = DEFAULT_SHADE   # J1 两组的浅灰底纹；必须作为"背景色"参与排除

# ---------------------------------------------------------------------------
# 配色 —— 全部由优先级自动分配
# ---------------------------------------------------------------------------
# 上面板（本图没画，但同系列图里有）的 3 个区段填充是**预留**给构建体语义的：
# 灰 = 侧翼 / 橙 = homology arm / 绿 = human insert。样本色必须避开它们，
# 否则并到高级验证图里就撞色了。
SEG = dict(DEFAULT_B_SEG_FILLS)

# from_levels=("3","4","5")：这张图是 **Default_B** 那批已冻结的产物，配色是在 Default_A
# 升为第 1 优先**之前**、直接从通用池里搜出来的。把 A 放进来会把第 1 根柱子的
# teal #8DD3C7 换成蓝 #80B1D3（两者 0.096 无法共存）—— 那是要用户点头的改动，
# 不能在重跑一遍旧脚本时静默发生。
# **新图不要抄这个 from_levels**，用默认值（A -> B -> 3 -> 4 -> 5）。
SAMPLE_FILLS = fills_by_priority(
    len(SAMPLES),
    exclude=list(SEG.values()) + [SHADE, "#FFFFFF"],
    from_levels=("3", "4", "5"),
)
palette_report(SAMPLE_FILLS, "bottom panel FILLS: sample (6 个样本)")

# --- 出图前的硬断言 ---------------------------------------------------------
assert_visible_on_white(SAMPLE_FILLS.colors, role="fill")
assert_fill_not_near_black(SAMPLE_FILLS.colors)
assert_visible_on_white(SEG.values(), role="fill")
assert_fill_not_near_black(SEG.values())
# 色块 vs 色块：样本色与预留的区段色互不相交（高级验证图直接依赖这一条）。
assert_no_palette_collision({
    "reserved top-panel FILLS: construct segment": list(SEG.values()),
    "bottom panel FILLS: sample": SAMPLE_FILLS.colors,
})

NOTE = (
    "Bar colours = samples. The four groups are junction CLASSES, not one shared coordinate: each sample carries its own\n"
    "targeted allele (TG_MTTH / TG_RAGH / TG_CD1A), so counts are compared within a class, never between loci.\n\n"
    "Shaded groups (J1): the homology arm is identical to the endogenous locus, so these reads cannot be assigned to one\n"
    "or the other — the aligner splits them arbitrarily and reports MAPQ 0. J1 counts are therefore NOT a measure of evidence\n"
    "strength and are not comparable with J2 counts. Only J2 reads (MAPQ 60) uniquely identify the targeted allele."
)


def read_tsv(path):
    with open(path) as fh:
        return list(csv.DictReader(fh, delimiter="\t"))


def load_spanning():
    rows = []
    for pkg in PACKAGES:
        rows += read_tsv(pkg / "junction_reads" / "spanning_summary.tsv")
    return rows


def main():
    spanning = load_spanning()
    missing = set(SAMPLES) - {r["sample"] for r in spanning}
    if missing:
        raise SystemExit(f"交付包里找不到样本: {sorted(missing)}")

    # 每个样本必须在 4 个接头类别上都有一行，否则分组柱会静默错位。
    table = {(r["sample"], r["junction_id"]): int(r["n_spanning"])
             for r in spanning if r["sample"] in SAMPLES}
    for s in SAMPLES:
        for j in JIDS:
            if (s, j) not in table:
                raise SystemExit(f"样本 × 接头 缺格：{s} / {j}")

    apply_publication_style(FigureStyle(font_size=12, axes_linewidth=1.8))
    fig, bx = plt.subplots(figsize=(13, 7))

    for k, jid in enumerate(JIDS):        # J1 两组（两侧）铺浅灰底，中间留白
        if jid.startswith("J1"):
            bx.axvspan(k - 0.5, k + 0.5, color=SHADE, zorder=0)

    width = 0.86 / len(SAMPLES)
    n_bars = n_labels = 0
    drawn_colors = set()
    for i, s in enumerate(SAMPLES):
        vals = [table[(s, j)] for j in JIDS]
        xs = [k + i * width - 0.43 + width / 2 for k in range(len(JIDS))]
        bars = bx.bar(xs, vals, width=width * 0.9, label=s, zorder=2,
                      color=SAMPLE_FILLS[i], edgecolor="black", linewidth=0.8)
        n_bars += len(bars)
        drawn_colors.update(b.get_facecolor() for b in bars)
        for x, v in zip(xs, vals):
            bx.text(x, v, str(v), ha="center", va="bottom", fontsize=8, zorder=3)
            n_labels += 1

    bx.set_xticks(range(len(JIDS)))
    bx.set_xticklabels(JIDS)
    bx.set_xlim(-0.5, len(JIDS) - 0.5)
    bx.set_ylabel("reads spanning junction\n(>=10 bp aligned on both sides)")
    bx.set_title("Junction-spanning read support — 6 samples across three targeted alleles "
                 "(bar colours = samples)", pad=26, loc="left", fontsize=11)
    # 图例固定在绘图区之外（正上方左对齐）。绝不用 loc="best"。
    # 6 个样本排成**一行** —— 折成两行按列读，读者容易看错顺序。
    bx.legend(loc="lower left", bbox_to_anchor=(0, 1.0), ncol=len(SAMPLES),
              fontsize=9, frameon=False)
    bx.text(0.0, -0.13, NOTE, transform=bx.transAxes, fontsize=8,
            va="top", ha="left", color="#333333", linespacing=1.5)

    # --- 出图前自检 ---------------------------------------------------------
    expected = len(SAMPLES) * len(JIDS)
    assert n_bars == expected, f"期望 {expected} 根柱子，实际画出 {n_bars} 根"
    assert n_labels == expected, "柱顶数值标签数量与柱子数不符"
    # 画出来的填充色必须就是分配下去的那 6 个（防止静默回退到默认色环）。
    want = {matplotlib.colors.to_rgba(c) for c in SAMPLE_FILLS.colors}
    assert drawn_colors == want, f"柱子实际填充色 {drawn_colors} 与分配的 {want} 不一致"

    OUT.mkdir(parents=True, exist_ok=True)
    paths = finalize_figure(fig, OUT / STEM, formats=["png", "pdf"], dpi=300, pad=1.5)
    print(f"\n[OK] {len(SAMPLES)} samples x {len(JIDS)} junctions = {n_bars} bars "
          f"-> {paths[0]}")


if __name__ == "__main__":
    main()
