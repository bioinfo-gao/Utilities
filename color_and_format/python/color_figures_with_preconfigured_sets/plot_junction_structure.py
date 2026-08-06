#!/usr/bin/env python3
"""
Targeted-allele junction structure figures — Python / matplotlib reference implementation.

三条品系（TG_MTTH / TG_RAGH / TG_CD1A）各一张两面板图：
  上面板 = targeted allele 线性结构（mouse flank / homology arm / human insert）+ 4 个接头位置
  下面板 = 每个样本在 4 个接头处的跨接头读段数

样式与配色纪律来自 /scientific-figure-making skill
(`~/.claude/skills/scientific-figure-making/`, house style 移植自 ChenLiu-1996/figures4papers)。

**本文件的重点是配色纪律，不是数据**：上下两个面板语义完全不同（上=构建体区段，
下=样本），因此**色块与色块之间**必须使用互不相交的配色。

本版是**全彩 · 预置色板版**：所有颜色都不是手调的，而是直接取自 **ColorBrewer**
（https://r-graph-gallery.com/38-rcolorbrewers-palettes.html）——
  · 色块 → Set3 的 12 个低饱和色，上下面板各取**不相交切片**；
  · 线条与文字 → diverging 色板 PiYG / BrBG 的**深端**。
配色遇到困难时先来这里找方案，不要自己发明调色板。
另两个版本：../grey_figures/（黑白）、../color_figures/（手调全彩）。

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
    brewer,
    finalize_figure,
    set3_with_grey,
    STROKE_COLORS,
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
# ---- 全部颜色取自 ColorBrewer，不手写十六进制 ----
# Set3 的 12 个低饱和色天生就是给**大色块**用的；diverging 色板的**深端**天生就是给
# **细线和文字**用的（文字要深才看得清，色块很弱的饱和度就够——两者需求正好相反）。
# 用 set3_with_grey()：把 Set3 的蓝 #80B1D3 换成中灰 #999999。一次替换解决两件事 ——
#   ① #80B1D3 与 #8DD3C7(青绿) 距离仅 0.096 低于阈值，两者永远无法分处两个面板，白白损失一色；
#   ② Set3 唯一的中性色 #D9D9D9 太浅（对比度 1.41）。一个能用的中灰比第二个冷色更值钱：
#      灰色承担「参照 / 背景 / 其它」，不占用色相位。
# 换完 #8DD3C7 就解放出来了（候选池 7 → 8），两个灰也并存无碍（#999999 vs #D9D9D9 = 0.251）。
# 必须换成**更深**的灰：#BFBFBF 距 Set3 的淡紫 #BEBADA 只有 0.063。
_S3 = set3_with_grey()

# 上面板：构建体区段（fill）。灰=侧翼（中性背景语义）/ 橙=HA / 绿=人源插入。
SEG = {
    "mouse genomic flank": _S3[4],            # #999999 中灰
    "homology arm (mouse sequence)": _S3[5],  # #FDB462 橙
    "human insert": _S3[6],                   # #B3DE69 绿
}
# 上面板：接头类型（line + text）。取 STROKE_COLORS 的**优先顺序**：
#   黑 → 正红 → 亮蓝 → 深绿 → 咖啡 → 深紫，用完再取 diverging 色板两端（第二梯队）。
# 这六个是久经考验的醒目笔画色：两两最小距离 0.221，比任何填充色板都分得开；
# 对白底对比度 4.7–21.0，远高于线条/文字的 1.5 下限。
# 黑色排第一 —— 永不出错且不占色相位，也是颜色不够用时的兜底（本图柱顶数值即黑色）。
# 前提：白/浅底。极少数深底图里换成白色与浅色单色线条，本模块的对比度检查不适用。
JUNC = {
    "J2": STROKE_COLORS[1],   # #E41A1C 正红，实线（真接头，可测）
    "J1": STROKE_COLORS[2],   # #1F78B4 亮蓝，虚线（设计上无缝）
}
# 下面板：样本（fill）。取改造后 Set3 中与上面板不相交的切片，索引是搜出来的不是拍的。
# 注：_S3[1] = #FFFFB3 对白底对比度仅 1.04，连填充阈值 1.1 都不到，是整套唯一被剔除的成员。
SAMPLE_FILLS = [_S3[i] for i in (0, 3, 11, 7, 9, 10)]
# 彩色版不用 hatch：颜色本身已是区分通道。
SAMPLE_HATCH = ["", "", "", "", "", ""]

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
