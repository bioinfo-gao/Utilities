#!/usr/bin/env python3
"""高级验证 —— 三张单基因图合并成一张，把配色优先级压到极限。

**与 R 版 ../../../R/color_figures_with_preconfigured_sets/Advanced/plot_3_genes_combined.R
同数据、同版式、同断言、同配色**，两边必须保持一致。

把上一层目录里 TG_MTTH / TG_RAGH / TG_CD1A 三张图合并：
  上面板 ×3  三条品系各自的 targeted allele 结构示意（三段区段语义**完全相同**）
  下面板 ×1  6 个样本合并显示（MTTH_284/412/524 · RAGH_153/273 · CD1A_B125）

为什么这是"高级"验证：一张图里同时要 **3 个区段色 + 6 个样本色 = 9 个色块**
外加 2 个接头线条色，还必须避开 J1 分组的浅灰底纹。这正好同时压两条相反的纪律：
  · 语义**相同** -> 三个上面板的区段配色必须**完全一致**（共用同一份映射）
  · 语义**不同** -> 区段色 与 样本色 必须**互不相交**  assert_no_palette_collision()

**本脚本不改动、不 import 上一层的 plot_junction_structure.py** —— 那份是三张
单基因图的原始实现，独立冻结；这里只共享上一层的 palette_priority.py（总纲）与只读数据。

用法：
    conda run -n regular_bioinfo python plot_3_genes_combined.py [outdir]
"""

import csv
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Rectangle  # noqa: E402

SKILL = Path("/home/gao/.claude/skills/scientific-figure-making/assets")
sys.path.insert(0, str(SKILL))
from pubfig import (  # noqa: E402
    FigureStyle,
    apply_publication_style,
    assert_fill_not_near_black,
    assert_no_palette_collision,
    assert_no_yellow_text,
    assert_shared_palette,
    assert_visible_on_white,
    finalize_figure,
)

HERE = Path(__file__).resolve().parent
for _cand in (HERE, HERE.parent):
    if (_cand / "palette_priority.py").exists():
        sys.path.insert(0, str(_cand))
        break
else:
    raise SystemExit("找不到 palette_priority.py（本目录与上一层都没有）")
from palette_priority import (  # noqa: E402
    DEFAULT_B_JUNC_STROKES,
    DEFAULT_B_SEG_FILLS,
    DEFAULT_SHADE,
    _rgb_distance,
    fills_by_priority,
    palette_report,
)

OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE
STEM = "3_genes_combined_junction_structure"

PROJ = Path("/home/gao/projects_2026M7/26_Ellen_MTTH_junction_sequences")
PACKAGES = [
    PROJ / "custom_research_report_supplementary_MTTH_20260804",
    PROJ / "custom_research_report_supplementary_RAGH_CD1A_20260804",
]

CONTIGS = ["TG_MTTH", "TG_RAGH", "TG_CD1A"]
SAMPLES = ["MTTH_284", "MTTH_412", "MTTH_524", "RAGH_153", "RAGH_273", "CD1A_B125"]
JIDS = ["J1_5p", "J2_5p", "J2_3p", "J1_3p"]
SHADE = DEFAULT_SHADE

# ---------------------------------------------------------------------------
# 配色 —— 全部由优先级/总纲提供
# ---------------------------------------------------------------------------
# 上面板：构建体区段。语义是手工指定的（灰=中性侧翼 / 橙=HA / 绿=人源插入），
# 三个面板共用同一份映射。
SEG = dict(DEFAULT_B_SEG_FILLS)
JUNC = {
    "J2: human/mouse junction (sequence-detectable)": DEFAULT_B_JUNC_STROKES["J2"],
    "J1: HA/endogenous boundary (seamless by design)": DEFAULT_B_JUNC_STROKES["J1"],
}
# 下面板：6 个样本。避开上面板 3 个区段色 + 浅灰底纹 + 白底。
# from_levels=("3","4","5")：见 plot_6_samples_bar.py 里的同一段说明 —— 这张图属
# Default_B 那批已冻结产物，**新图不要抄这个 from_levels**。
SAMPLE_FILLS = fills_by_priority(
    len(SAMPLES),
    exclude=list(SEG.values()) + [SHADE, "#FFFFFF"],
    from_levels=("3", "4", "5"),
)
palette_report(SAMPLE_FILLS, "bottom panel FILLS: sample (6 个样本)")
print(f"  上面板区段色: {' '.join(SEG.values())}")
_cross = [(a, b, _rgb_distance(a, b)) for a in SEG.values() for b in SAMPLE_FILLS.colors]
_a, _b, _d = min(_cross, key=lambda t: t[2])
print(f"  区段色 vs 样本色 最紧的一对: {_a} vs {_b} = {_d:.3f}（门槛 0.10）")

# --- 出图前的硬断言 ---------------------------------------------------------
assert_visible_on_white(SEG.values(), role="fill")
assert_visible_on_white(JUNC.values(), role="line")
assert_visible_on_white(SAMPLE_FILLS.colors, role="fill")
assert_fill_not_near_black(SEG.values())
assert_fill_not_near_black(SAMPLE_FILLS.colors)
assert_no_yellow_text(JUNC.values())
assert_no_palette_collision({
    "top panel FILLS: construct segment": list(SEG.values()),
    "bottom panel FILLS: sample": SAMPLE_FILLS.colors,
})

NOTE = (
    "Bar colours = samples — a separate colour family from the segment colours in the three panels above, to which they are unrelated.\n"
    "The four groups are junction CLASSES, not one shared coordinate: each sample carries its own targeted allele, so counts are\n"
    "compared within a class, never between loci. The three structure panels are drawn on INDEPENDENT x scales (254,010 / 38,566 /\n"
    "185,655 bp) and their widths are therefore not comparable.\n\n"
    "Shaded groups (J1): the homology arm is identical to the endogenous locus, so these reads cannot be assigned to one or the\n"
    "other — the aligner splits them arbitrarily and reports MAPQ 0. J1 counts are therefore NOT a measure of evidence strength\n"
    "and are not comparable with J2 counts. Only J2 reads (MAPQ 60) uniquely identify the targeted allele."
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


def draw_structure(ax, contig, rows, seg_map, junc_map, show_legend=False,
                   legend_title=None):
    """上面板：线性结构 + 接头竖线。返回画出来的 (区段色映射, 接头竖线条数)。"""
    clen = int(rows[0]["contig_len"])
    ha5 = [int(v) for v in rows[0]["ha_5p"].split("-")]
    ha3 = [int(v) for v in rows[0]["ha_3p"].split("-")]
    ins = [int(v) for v in rows[0]["human_insert"].split("-")]
    roles = list(seg_map)

    blocks = [(1, ha5[0] - 1, roles[0]), (ha5[0], ha5[1], roles[1]),
              (ins[0], ins[1], roles[2]), (ha3[0], ha3[1], roles[1]),
              (ha3[1] + 1, clen, roles[0])]
    drawn = {}
    for x0, x1, role in blocks:
        if x1 < x0:
            continue
        p = ax.add_patch(Rectangle((x0, 0.30), x1 - x0, 0.40,
                                   facecolor=seg_map[role], edgecolor="black",
                                   linewidth=0.8))
        drawn.setdefault(role, matplotlib.colors.to_hex(p.get_facecolor()).upper())

    # J1/J2 在两端相距仅数 kb，在整条 contig 的尺度上标签必然重叠 ——
    # 交替高度 + 外侧标签向外偏移，避免文字糊成一团。
    tier = {"J1_5p": 0, "J2_5p": 1, "J2_3p": 1, "J1_3p": 0}
    halign = {"J1_5p": "right", "J2_5p": "left", "J2_3p": "right", "J1_3p": "left"}
    j2col, j1col = list(junc_map.values())
    n_lines = 0
    for r in rows:
        pos, jid = int(r["junction_pos_contig"]), r["junction_id"]
        is_j2 = jid.startswith("J2")
        col = j2col if is_j2 else j1col
        ytop = [1.02, 0.92][tier[jid]]
        ax.axvline(pos, ymin=0.12, ymax=ytop / 1.18, color=col,
                   linestyle="-" if is_j2 else "--", linewidth=2.0)
        n_lines += 1
        dx = clen * 0.006 * (1 if halign[jid] == "left" else -1)
        ax.text(pos + dx, ytop, jid, ha=halign[jid], va="bottom",
                fontsize=9.5, color=col, fontweight="bold")
        ax.text(pos + dx, 0.28, f"{pos:,}", ha="center", va="top", fontsize=7.5,
                rotation=90, color=col)

    ax.set_xlim(-clen * 0.03, clen * 1.03)
    ax.set_ylim(0, 1.25)
    ax.set_yticks([])
    ax.set_xlabel("coordinate along the targeted allele (bp)")
    ax.set_title(f"{contig}  —  targeted allele structure and junction positions  "
                 f"({clen:,} bp)", pad=8, fontsize=11)
    ax.spines[["left"]].set_visible(False)

    if show_legend:
        handles = [Rectangle((0, 0), 1, 1, facecolor=seg_map[r], edgecolor="black")
                   for r in roles]
        ax.legend(handles, roles, loc="center left", bbox_to_anchor=(1.01, 0.5),
                  fontsize=8.5, frameon=False, title=legend_title,
                  title_fontsize=9)
    return drawn, n_lines


def draw_support(bx, table):
    """下面板：6 个样本合并的跨接头读段数。"""
    for k, jid in enumerate(JIDS):
        if jid.startswith("J1"):
            bx.axvspan(k - 0.5, k + 0.5, color=SHADE, zorder=0)

    width = 0.86 / len(SAMPLES)
    n_bars = n_labels = 0
    drawn = set()
    for i, s in enumerate(SAMPLES):
        vals = [table[(s, j)] for j in JIDS]
        xs = [k + i * width - 0.43 + width / 2 for k in range(len(JIDS))]
        bars = bx.bar(xs, vals, width=width * 0.9, label=s, zorder=2,
                      color=SAMPLE_FILLS[i], edgecolor="black", linewidth=0.8)
        n_bars += len(bars)
        drawn.update(matplotlib.colors.to_hex(b.get_facecolor()).upper() for b in bars)
        for x, v in zip(xs, vals):
            bx.text(x, v, str(v), ha="center", va="bottom", fontsize=8, zorder=3)
            n_labels += 1

    bx.set_xticks(range(len(JIDS)))
    bx.set_xticklabels(JIDS)
    bx.set_xlim(-0.5, len(JIDS) - 0.5)
    bx.set_ylabel("reads spanning junction\n(>=10 bp aligned on both sides)")
    bx.set_title("Junction-spanning read support per sample, all three targeted alleles "
                 "combined (bar colours = samples)", pad=26, loc="left", fontsize=11)
    bx.legend(loc="lower left", bbox_to_anchor=(0, 1.0), ncol=len(SAMPLES),
              fontsize=9, frameon=False)
    bx.text(0.0, -0.13, NOTE, transform=bx.transAxes, fontsize=8,
            va="top", ha="left", color="#333333", linespacing=1.5)
    return n_bars, n_labels, drawn


def main():
    coords, spanning = load()
    missing = set(SAMPLES) - {r["sample"] for r in spanning}
    if missing:
        raise SystemExit(f"交付包里找不到样本: {sorted(missing)}")
    if not set(CONTIGS) <= {r["contig"] for r in coords}:
        raise SystemExit("交付包里找不到全部三条 contig")
    table = {(r["sample"], r["junction_id"]): int(r["n_spanning"])
             for r in spanning if r["sample"] in SAMPLES}

    apply_publication_style(FigureStyle(font_size=12, axes_linewidth=1.8))
    fig, axes = plt.subplots(
        5, 1, figsize=(14, 16),
        gridspec_kw=dict(height_ratios=[1, 1, 1, 0.30, 3.1], hspace=0.95))
    *tops, leg_ax, bx = axes

    drawn_segs = {}
    for ax, contig in zip(tops, CONTIGS):
        rows = [r for r in coords if r["contig"] == contig]
        rows = sorted(rows, key=lambda r: JIDS.index(r["junction_id"]))
        drawn_segs[contig], n_lines = draw_structure(ax, contig, rows, SEG, JUNC)
        # 每个上面板必须画出 4 条接头竖线
        assert n_lines == len(JIDS), f"{contig}: 期望 {len(JIDS)} 条接头竖线，实际 {n_lines}"

    # 三个结构面板语义相同、配色相同 -> 图例只画一次，单独占一行
    leg_ax.axis("off")
    handles = [Rectangle((0, 0), 1, 1, facecolor=c, edgecolor="black") for c in SEG.values()]
    handles += [plt.Line2D([0], [0], color=JUNC[k], lw=2.2,
                           linestyle="-" if k.startswith("J2") else "--") for k in JUNC]
    leg_ax.legend(handles, list(SEG) + list(JUNC), loc="center", ncol=5,
                  fontsize=9, frameon=False)

    n_bars, n_labels, drawn_bar_cols = draw_support(bx, table)

    # --- 出图后、写盘前的自检 -------------------------------------------------
    # 1) 语义相同：三个上面板的 区段名->颜色 映射必须完全一致（从**画出来的**图形反查）
    assert_shared_palette({c: drawn_segs[c] for c in CONTIGS})
    # 2) 语义不同：画出来的区段色 与 画出来的柱子色 互不相交
    assert_no_palette_collision({
        "top panel FILLS as drawn": list(drawn_segs[CONTIGS[0]].values()),
        "bottom panel FILLS as drawn": sorted(drawn_bar_cols),
    })
    # 3) 柱子数 / 标签数 / 填充色
    expected = len(SAMPLES) * len(JIDS)
    assert n_bars == expected, f"期望 {expected} 根柱子，实际画出 {n_bars} 根"
    assert n_labels == expected, "柱顶数值标签数量与柱子数不符"
    assert drawn_bar_cols == {c.upper() for c in SAMPLE_FILLS.colors}, \
        "柱子实际填充色与分配的 6 色不一致（scale 可能静默回退）"

    fig.suptitle("Three targeted alleles side by side — structure (top) and "
                 "junction-spanning read support (bottom)", fontsize=13, y=0.995)
    OUT.mkdir(parents=True, exist_ok=True)
    paths = finalize_figure(fig, OUT / STEM, formats=["png", "pdf"], dpi=300, pad=1.5)
    print(f"\n[OK] {len(CONTIGS)} contigs (top) + {len(SAMPLES)} samples x {len(JIDS)} "
          f"junctions = {n_bars} bars (bottom) -> {paths[0]}")


if __name__ == "__main__":
    main()
