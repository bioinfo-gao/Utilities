#!/usr/bin/env python3
"""
Targeted-allele junction structure figures — Python / matplotlib reference implementation.

三条品系（TG_MTTH / TG_RAGH / TG_CD1A）各一张两面板图：
  上面板 = targeted allele 线性结构（mouse flank / homology arm / human insert）+ 4 个接头位置
  下面板 = 每个样本在 4 个接头处的跨接头读段数

样式与配色纪律来自 /scientific-figure-making skill
(`~/.claude/skills/scientific-figure-making/`, house style 移植自 ChenLiu-1996/figures4papers)。

**本文件的重点是配色纪律，不是数据**：上下两个面板语义完全不同（上=构建体区段，
下=样本），因此必须使用**互不相交**的配色族。这里更进一步——下面板做成**纯灰阶 + hatch**，
读者一眼就能看出它不是上面板的彩色对照。三条断言在出图前跑，撞色/低对比度直接终止。

数据来源（只读，不修改）：项目26 两个已冻结的交付包
  custom_research_report_supplementary_MTTH_20260804/
  custom_research_report_supplementary_RAGH_CD1A_20260804/

用法：
    conda run -n regular_bioinfo python plot_junction_structure.py [outdir]
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
    finalize_figure,
)

PROJ = Path("/home/gao/projects_2026M7/26_Ellen_MTTH_junction_sequences")
PACKAGES = [
    PROJ / "custom_research_report_supplementary_MTTH_20260804",
    PROJ / "custom_research_report_supplementary_RAGH_CD1A_20260804",
]
# 代码与产物同目录：本脚本就住在 grey_figures/ 里，图也写在这里。
# 平行的彩色版在 ../color_figures/，两者只差配色块和下面板标题（可直接 diff 对比）。
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).parent)

# ---------------------------------------------------------------------------
# 配色 —— 两个面板语义不同，配色族必须不相交
# ---------------------------------------------------------------------------
# 上面板：构建体区段（fill）+ 接头类型（line）
SEG = {
    "mouse genomic flank": PALETTE["blue_main"],   # #0F4D92
    "homology arm (mouse sequence)": PALETTE["highlight"],  # #FFD700
    "human insert": PALETTE["green_3"],            # #8BCF8B
}
JUNC = {
    "J2": PALETTE["magenta"],  # #C71585 真接头，实线
    "J1": PALETTE["cyan"],     # #17BECF 设计上无缝，虚线
}
# 下面板：样本。刻意用**灰阶 + hatch**，与上面板五个彩色零交集，
# 且 hatch 提供与颜色正交的第二通道，灰度打印仍可区分。
#
# 灰阶方向是**浅 → 深**：#ABABAB → #828282 → #5A5A5A（最深对白底对比度 6.90）。
# 两端都被实测卡死：
#   深端不用 ink #272727（对比度 14.94）—— 大面积实心近黑柱在论文和 slide 上过重、
#   极不美观，会盖过数据本身；
#   浅端不能再浅 —— J1 分组底纹是 #F2F2F2，#D0D0D0 与它的距离只有 0.133，
#   单样本图（TG_CD1A 只用第一色）里柱子和底纹分不开；#ABABAB 提到 0.278。
SAMPLE_FILLS = [PALETTE["grey_pale"], PALETTE["grey_soft"], PALETTE["grey_deep"]]  # 浅→深
SAMPLE_HATCH = ["", "///", "..."]

# --- 出图前的硬断言 ---------------------------------------------------------
assert_visible_on_white(SEG.values(), role="fill")      # 大色块，配黑边
assert_visible_on_white(JUNC.values(), role="line")     # 细线，标准阈值
assert_visible_on_white(SAMPLE_FILLS, role="fill")
assert_fill_not_near_black(SAMPLE_FILLS)                # 禁止大面积近黑实心
assert_fill_not_near_black(SEG.values())
# J 标签与坐标数字用的就是 JUNC 这两个颜色（是文字，不是填充）—— 禁止黄色文字。
# 注意 SEG 里的金色 #FFD700 只做填充、从不做字，所以不进这条检查。
assert_no_yellow_text(JUNC.values())
# 硬约束是**色块 vs 色块**：上面板的 3 个区段填充 与 下面板的样本填充必须互不相交。
# 大面积色块才是会被读成"上下对照"的通道；J1/J2 只是细线+文字标签，不参与这条约束
# （颜色不够用时，下面板文字直接用黑色，如本图的柱顶数值）。
assert_no_palette_collision(
    {
        "top panel FILLS: construct segment": list(SEG.values()),
        "bottom panel FILLS: sample": SAMPLE_FILLS,
    }
)

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
            bx.axvspan(k - 0.5, k + 0.5, color="#F2F2F2", zorder=0)

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
                 "(greyscale + hatch = samples; deliberately achromatic, "
                 "unrelated to the segment colours above)", pad=26)
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
