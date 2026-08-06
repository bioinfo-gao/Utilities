#!/usr/bin/env python3
"""Targeted-allele junction structure figures —— **Default_A 配色版（第 1 优先）**。

与上一层的 plot_junction_structure.py **同数据、同版式、同文件名**，只差配色块：
  上一层（Default_B，第 2 优先）：侧翼 = 中灰 #999999，柱子第 1 色 = teal #8DD3C7，接头线 = 正红/亮蓝
  本版（Default_A，第 1 优先）  ：侧翼 = 淡蓝 #80B1D3，柱子 = 淡紫/珊瑚/黄，接头线 = 酒红/深青绿
两版并存、互不覆盖：本版产物写在 Alternative/ 子文件夹里，同名但不同目录。

**与 R 版 ../../../R/color_figures_with_preconfigured_sets/Alternative/plot_junction_structure_alt.R
是同一套配色、同样的断言**，两边必须保持一致。

用户原话（2026-08-05）：「这个截图里的配色完美，对人类阅读者是好极了。实际上我更加喜欢。」
随后定为 Default_A —— **配色选择的第一优先**。

配色全部取自上一层 palette_priority.py 的 DEFAULT_A_* 常量（那里是配色总纲），本文件不手写十六进制：
  · 区段色块 -> **stock** Set3 的蓝/橙/绿（注意：是原版 Set3，不是 set3_with_grey()）
  · 柱子     -> stock Set3 的淡紫/珊瑚/黄/粉/紫/浅绿（跳过过浅的 #FFFFB3 与撞蓝的 teal）
  · 接头线条与文字 -> diverging 色板 PiYG / BrBG 的**深端**（深且饱和，细线小字才看得清）

数据来源（只读，不修改）：项目26 两个已冻结的交付包

**本脚本不改动、不 import 上一层的 plot_junction_structure.py** —— 那份独立冻结。

用法：
    conda run -n regular_bioinfo python plot_junction_structure_alt.py [outdir]
"""


import csv
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # 无头运行：必须在 import pyplot 之前

import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Rectangle  # noqa: E402

SKILL = Path("/home/gao/.claude/skills/scientific-figure-making/assets")
sys.path.insert(0, str(SKILL))
from pubfig import (  # noqa: E402
    PALETTE,
    FigureStyle,
    apply_publication_style,
    assert_fill_not_near_black,
    assert_no_palette_collision,
    assert_no_yellow_text,
    assert_visible_on_white,
    brewer,
    finalize_figure,
    set3_with_grey,
    STROKE_COLORS,
)

# palette_priority.py 是**总纲**，住在上一层目录；本 Alternative/ 只放这一版的代码与产物。
HERE = Path(__file__).resolve().parent
for cand in (HERE, HERE.parent):
    if (cand / "palette_priority.py").exists():
        sys.path.insert(0, str(cand))
        break
else:
    raise SystemExit("找不到 palette_priority.py（本目录与上一层都没有）")
from palette_priority import (  # noqa: E402
    DEFAULT_A_JUNC_STROKES,
    DEFAULT_A_SAMPLE_FILLS,
    DEFAULT_A_SEG_FILLS,
    DEFAULT_SHADE,
    _rgb_distance,
)

PROJ = Path("/home/gao/projects_2026M7/26_Ellen_MTTH_junction_sequences")
PACKAGES = [
    PROJ / "custom_research_report_supplementary_MTTH_20260804",
    PROJ / "custom_research_report_supplementary_RAGH_CD1A_20260804",
]
# 代码与产物同目录：本脚本就住在 color_figures_with_preconfigured_sets/ 里。
# 与 ../color_figures/ 只差配色块（那版手调，本版取自 ColorBrewer），可直接 diff。
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).parent)

# ---------------------------------------------------------------------------
# 配色 —— 两个面板语义不同，配色族必须不相交
# ---------------------------------------------------------------------------
# ---- 全部颜色取自 palette_priority.py 的 DEFAULT_A_* 常量，本文件不手写十六进制 ----
# 与上一层 Default_B 版的唯一差别就在这一段（其余代码逐行相同，可直接 diff）。
#
# 上一层用 set3_with_grey()：把 Set3 的蓝 #80B1D3 换成中灰 #999999，理由是
#   ① #80B1D3 与 #8DD3C7(teal) 只差 0.096，两者无法分处两个面板，白白损失一色；
#   ② Set3 唯一的中性色 #D9D9D9 太浅（对比度 1.41），换个能用的中灰更值。
# **本版反其道而行**：用户明确说更喜欢那个蓝（2026-08-05），所以保留 **stock Set3**，
# 代价就是 teal 出局 —— 柱子从淡紫 #BEBADA 起，而不是 teal。这是取舍，不是疏漏。

# 上面板：构建体区段（fill）。蓝=侧翼（中性背景语义）/ 橙=HA / 绿=人源插入。
SEG = dict(DEFAULT_A_SEG_FILLS)
# 上面板：接头类型（line + text）。取 diverging 色板 PiYG / BrBG 的**深端** ——
# 深且饱和，正是细线与小字需要的（色块与文字对饱和度的要求正好相反）。
JUNC = dict(DEFAULT_A_JUNC_STROKES)
# 下面板：样本（fill）。stock Set3 中与上面板不相交的切片。
# 跳过两个：#FFFFB3（对白底 1.04，连填充阈值 1.1 都不到）与 teal #8DD3C7（撞蓝侧翼 0.096）。
SAMPLE_FILLS = list(DEFAULT_A_SAMPLE_FILLS)
# 彩色版不用 hatch：颜色本身已是区分通道。
SAMPLE_HATCH = ["", "", "", "", "", ""]

# --- 出图前的硬断言 ---------------------------------------------------------
assert_visible_on_white(SEG.values(), role="fill")      # 大色块，配黑边
assert_visible_on_white(JUNC.values(), role="line")     # 细线，标准阈值
assert_visible_on_white(SAMPLE_FILLS, role="fill")
assert_fill_not_near_black(SAMPLE_FILLS)                # 禁止大面积近黑实心
assert_fill_not_near_black(SEG.values())
assert_no_yellow_text(JUNC.values())                    # J 标签与坐标数字用的就是这两个颜色
# 硬约束是**色块 vs 色块**：上面板 3 个区段填充 与 下面板样本填充必须互不相交。
assert_no_palette_collision(
    {
        "top panel FILLS: construct segment": list(SEG.values()),
        "bottom panel FILLS: sample": SAMPLE_FILLS,
    }
)
# 接头竖线是从色块中间穿过去的，必须对每个区段色都还看得见
# （撞色断言只管色块 vs 色块，抓不到"线在色块里消失"这种可读性 bug）。
_d_line = min(_rgb_distance(a, b) for a in JUNC.values() for b in SEG.values())
if _d_line < 0.13:
    raise AssertionError(f"接头线与区段色最近只有 {_d_line:.3f} —— 线穿过色块那一段会看不见")

# --- 把这一版的实测数字打出来，便于人工复核 ---------------------------------
_cross = min(_rgb_distance(a, b) for a in SEG.values() for b in SAMPLE_FILLS)
_intra = min(_rgb_distance(a, b) for i, a in enumerate(SAMPLE_FILLS)
             for b in SAMPLE_FILLS[i + 1:])
print("\n[Default_A 配色版 —— 第 1 优先] 全部取自 palette_priority.py 的 DEFAULT_A_* 常量")
print(f"  区段 : {' '.join(SEG.values())}")
print(f"  样本 : {' '.join(SAMPLE_FILLS)}")
print(f"  接头线: {' '.join(JUNC.values())}（酒红实线 / 深青绿虚线，PiYG+BrBG 深端）")
print(f"  区段 vs 样本 最紧: {_cross:.3f}（assert 门槛 0.10）")
print(f"  样本内部最紧: {_intra:.3f}；接头线 vs 区段 最紧: {_d_line:.3f}")

JIDS = ["J1_5p", "J2_5p", "J2_3p", "J1_3p"]
NOTE = (
    "Shaded groups (J1): the homology arm is identical to the endogenous locus, so these reads cannot be assigned to one\n"
    "or the other — the aligner splits them arbitrarily and reports MAPQ 0. J1 counts are therefore NOT a measure of evidence\n"
    "strength and are not comparable with J2 counts. Only J2 reads (MAPQ 60) uniquely identify the targeted allele."
)


def read_tsv(path):
    with open(path) as fh:
        return list(csv.DictReader(fh, delimiter="\t"))


def load():
    coords, spanning = [], []
    for pkg in PACKAGES:
        coords += read_tsv(pkg / "coordinates" / "junction_coordinates.tsv")
        spanning += read_tsv(pkg / "junction_reads" / "spanning_summary.tsv")
    return coords, spanning


def draw_structure(ax, contig, rows):
    """上面板：线性结构 + 接头竖线。"""
    clen = int(rows[0]["contig_len"])
    ha5 = [int(v) for v in rows[0]["ha_5p"].split("-")]
    ha3 = [int(v) for v in rows[0]["ha_3p"].split("-")]
    ins = [int(v) for v in rows[0]["human_insert"].split("-")]

    blocks = [
        (1, ha5[0] - 1, SEG["mouse genomic flank"]),
        (ha5[0], ha5[1], SEG["homology arm (mouse sequence)"]),
        (ins[0], ins[1], SEG["human insert"]),
        (ha3[0], ha3[1], SEG["homology arm (mouse sequence)"]),
        (ha3[1] + 1, clen, SEG["mouse genomic flank"]),
    ]
    for x0, x1, col in blocks:
        if x1 < x0:
            continue
        ax.add_patch(Rectangle((x0, 0.30), x1 - x0, 0.40, facecolor=col,
                               edgecolor="black", linewidth=0.8))

    # J1/J2 在两端相距仅数 kb，在 250 kb 尺度上标签必然重叠 ——
    # 交替高度 + 外侧标签向外偏移，避免文字糊成一团。
    tier = {"J1_5p": 0, "J2_5p": 1, "J2_3p": 1, "J1_3p": 0}
    halign = {"J1_5p": "right", "J2_5p": "left", "J2_3p": "right", "J1_3p": "left"}
    for r in rows:
        pos = int(r["junction_pos_contig"])
        jid = r["junction_id"]
        is_j2 = jid.startswith("J2")
        col = JUNC["J2"] if is_j2 else JUNC["J1"]
        ytop = [1.02, 0.92][tier[jid]]
        ax.axvline(pos, ymin=0.12, ymax=ytop / 1.18, color=col,
                   linestyle="-" if is_j2 else "--", linewidth=2.0)
        dx = clen * 0.006 * (1 if halign[jid] == "left" else -1)
        ax.text(pos + dx, ytop, jid, ha=halign[jid], va="bottom",
                fontsize=10, color=col, fontweight="bold")
        # 位置数字：放在色块下方、x 轴线之上的空白带里（起点太低会压到轴线），
        # 并与 J 标签同向水平偏移，否则接头竖线会从数字中间穿过。
        ax.text(pos + dx, 0.28, f"{pos:,}", ha="center", va="top", fontsize=8,
                rotation=90, color=col)

    ax.set_xlim(-clen * 0.03, clen * 1.03)
    ax.set_ylim(0, 1.25)
    ax.set_yticks([])
    ax.set_xlabel(f"{contig} coordinate (bp)")
    ax.set_title(f"{contig} — targeted allele structure and junction positions", pad=8)
    ax.spines[["left"]].set_visible(False)

    handles = [Rectangle((0, 0), 1, 1, facecolor=c, edgecolor="black") for c in SEG.values()]
    handles += [
        plt.Line2D([0], [0], color=JUNC["J2"], lw=2.2),
        plt.Line2D([0], [0], color=JUNC["J1"], lw=2.2, linestyle="--"),
    ]
    labels = list(SEG) + [
        "J2: human/mouse junction (sequence-detectable)",
        "J1: HA/endogenous boundary (seamless by design)",
    ]
    # 图例固定在绘图区之外（下方），绝不用 loc="best"。
    ax.legend(handles, labels, loc="upper center", bbox_to_anchor=(0.5, -0.30),
              ncol=2, fontsize=9, frameon=False,
              title="Construct segments and junction types")


def draw_support(bx, contig, spanning):
    """下面板：每个样本的跨接头读段数（灰阶 + hatch）。"""
    samples = sorted({r["sample"] for r in spanning if r["contig"] == contig})

    for k, jid in enumerate(JIDS):        # J1 两组铺浅灰底，提示计数不代表证据强度
        if jid.startswith("J1"):
            bx.axvspan(k - 0.5, k + 0.5, color=DEFAULT_SHADE, zorder=0)

    width = 0.8 / max(1, len(samples))
    n_bars = 0
    for i, s in enumerate(samples):
        vals = [next((int(r["n_spanning"]) for r in spanning
                      if r["sample"] == s and r["junction_id"] == jid), 0) for jid in JIDS]
        xs = [k + i * width - 0.4 + width / 2 for k in range(len(JIDS))]
        bars = bx.bar(xs, vals, width=width * 0.9, label=s, zorder=2,
                      color=SAMPLE_FILLS[i % len(SAMPLE_FILLS)],
                      hatch=SAMPLE_HATCH[i % len(SAMPLE_HATCH)],
                      edgecolor="black", linewidth=0.8)
        n_bars += len(bars)
        for x, v in zip(xs, vals):
            bx.text(x, v, str(v), ha="center", va="bottom", fontsize=8, zorder=3)

    bx.set_xticks(range(len(JIDS)))
    bx.set_xticklabels(JIDS)
    bx.set_xlim(-0.5, len(JIDS) - 0.5)
    bx.set_ylabel("reads spanning junction\n(>=10 bp aligned on both sides)")
    bx.set_title("Junction-spanning read support per sample "
                 "(bar colours = samples; a separate colour family from the "
                 "segment colours above, to which they are unrelated)", pad=26)
    # 图例固定在绘图区正上方、左对齐；不设 title（样本 ID 自明），否则会与面板标题挤在一起。
    bx.legend(loc="lower left", bbox_to_anchor=(0, 1.0), ncol=max(1, len(samples)),
              fontsize=9, frameon=False)
    bx.text(0.0, -0.20, NOTE, transform=bx.transAxes, fontsize=8,
            va="top", ha="left", color="#333333")
    return len(samples), n_bars


def main():
    coords, spanning = load()
    apply_publication_style(FigureStyle(font_size=12, axes_linewidth=1.8))
    OUT.mkdir(parents=True, exist_ok=True)

    for contig in sorted({r["contig"] for r in coords}):
        rows = [r for r in coords if r["contig"] == contig]
        fig, (ax, bx) = plt.subplots(2, 1, figsize=(13, 8),
                                     gridspec_kw=dict(height_ratios=[1, 1.45]))
        draw_structure(ax, contig, rows)
        n_samples, n_bars = draw_support(bx, contig, spanning)

        # 出图前自检：柱子数必须等于 样本数 × 接头数（静默丢柱直接报错）。
        expected = n_samples * len(JIDS)
        assert n_bars == expected, f"{contig}: 期望 {expected} 根柱子，实际画出 {n_bars} 根"

        paths = finalize_figure(fig, OUT / f"{contig}_junction_structure",
                                formats=["png", "pdf"], dpi=300, pad=1.5)
        print(f"  {contig}: {n_samples} samples × {len(JIDS)} junctions = {expected} bars  "
              f"-> {paths[0].name}, {paths[1].name}")

    print(f"[OK] {OUT.resolve()}")


if __name__ == "__main__":
    main()
