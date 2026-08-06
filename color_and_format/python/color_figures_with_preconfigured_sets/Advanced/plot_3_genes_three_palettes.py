#!/usr/bin/env python3
"""高难度验证 —— 三个基因示意图各用**一套不同的配色**。

**与 R 版 ../../../R/color_figures_with_preconfigured_sets/Advanced/plot_3_genes_three_palettes.R
同数据、同版式、同断言、同配色**，两边必须保持一致。

与 plot_3_genes_combined.py 的差别只有一处：那张图里三个结构面板**共用同一套**
区段配色（3 个色块）；这张图给三个面板**各配一套**（3 × 3 = 9 个色块），
下面板 6 个样本色保持 Default_B 已冻结的那套不变。

  一张图里的填充色总数：9（区段）+ 6（样本）= **15 个色块**，两两必须分得开，
  还要同时避开白底与 J1 分组的浅灰底纹 #F2F2F2。
  这是目前对配色优先级压力最大的一张图。

⚠ **这张图故意让三个语义相同的面板用不同配色，是有意为之，不是疏忽。**
  三个面板的区段语义**是相同的**（mouse flank / homology arm / human insert），
  按 house style 本应共用一套配色（那正是 plot_3_genes_combined.py 的做法）。
  本图作为**配色容量实证**刻意反过来做，因此必须付出对应的代价来防止误读：
    · 每个面板带**自己的图例**，图例标题写明是哪条品系的区段 —— 读者不会跨面板读色；
    · 三套配色是三个**色相家族**（蓝 / 黄绿 / 橙红），家族间距 >= 0.13；
    · 每个家族内部一律 **浅 -> 深 = 侧翼 -> HA -> 人源插入**，三个面板规则一致。
  **真正给客户的图仍用 plot_3_genes_combined.py 那套共用配色。**

用法：
    conda run -n regular_bioinfo python plot_3_genes_three_palettes.py [outdir]
"""

import csv
import sys
from itertools import combinations
from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Rectangle  # noqa: E402

SKILL = Path("/home/gao/.claude/skills/scientific-figure-making/assets")
sys.path.insert(0, str(SKILL))
from pubfig import (  # noqa: E402
    STROKE_COLORS,
    FigureStyle,
    apply_publication_style,
    assert_fill_not_near_black,
    assert_no_palette_collision,
    assert_no_yellow_text,
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
    DEFAULT_B_SAMPLE_FILLS,
    DEFAULT_SHADE,
    _rgb_distance,
)

OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE
STEM = "3_genes_three_palettes_junction_structure"

PROJ = Path("/home/gao/projects_2026M7/26_Ellen_MTTH_junction_sequences")
PACKAGES = [
    PROJ / "custom_research_report_supplementary_MTTH_20260804",
    PROJ / "custom_research_report_supplementary_RAGH_CD1A_20260804",
]

CONTIGS = ["TG_MTTH", "TG_RAGH", "TG_CD1A"]
SAMPLES = ["MTTH_284", "MTTH_412", "MTTH_524", "RAGH_153", "RAGH_273", "CD1A_B125"]
JIDS = ["J1_5p", "J2_5p", "J2_3p", "J1_3p"]
SEG_ROLES = ["mouse genomic flank", "homology arm (mouse sequence)", "human insert"]
SHADE = DEFAULT_SHADE

# ---------------------------------------------------------------------------
# 配色
# ---------------------------------------------------------------------------
# 下面板：沿用 Default_B 已冻结的那套，一个色都不动。
SAMPLE_FILLS = list(DEFAULT_B_SAMPLE_FILLS)

# 上面板：每条品系一个色相家族。索引不是拍脑袋定的 —— 在 9-class 色板里穷举全部 3-子集，
# 要求：白底对比度 1.2-10（不太浅、不近黑）、**家族内**两两 >= 0.13、与 6 个样本色和白底
# >= 0.13；再从通过的家族里挑"最弱环节最大"的三家族组合。
#
# 排除集是**分面板**给的，不是一刀切：J1 分组的浅灰底纹只出现在下面板，柱子压在它上面，
# 所以**柱子**必须避开它；上面板的区段画在白底上，与底纹从不相邻，因此不受它约束。
# 一刀切会白白废掉 Blues/Greys/PuBu 几个家族（Blues 最浅的 #C6DBEF 距底纹 0.101），
# 把 MTTH 逼进 BuPu —— 那套家族内只有 0.151，出图后肉眼可见两块紫色分不清。
#
# 结果 Blues / YlGn / YlOrRd：家族间最小 0.184，家族内最小 0.222。
SEG_FAMILY_SPEC = {
    "TG_MTTH": ("Blues", (2, 5, 7)),    # 蓝     （0-based 索引，R 版是 1-based 的 3,6,8）
    "TG_RAGH": ("YlGn", (2, 4, 6)),     # 黄绿   （R 版 3,5,7）
    "TG_CD1A": ("YlOrRd", (3, 5, 7)),   # 橙红   （R 版 4,6,8）
}


def brewer9(name: str) -> list[str]:
    """取 ColorBrewer 某个 sequential 色板的**canonical 9-class 原表**。

    **不能用 pubfig.brewer(name, 9)**：那个函数对连续色板按 `cmap(i/(n-1))` 采样，
    而 matplotlib 的色图是 256 档查找表，采样点落在档位之间 —— 出来的是
    `#4191C6`，与 R 的 `RColorBrewer::brewer.pal(9, "Blues")` 原值 `#4292C6`
    差 1 个 RGB 单位。肉眼看不出，但**两个语言的版本就不再是同一套颜色**了。
    `cmap.resampled(9)` 取的是 9 档的档位中心，正好复现原表。
    （pubfig.brewer 的 `n=2 取两端` 语义是对的、别处在用，所以不改它。）
    """
    cmap = matplotlib.colormaps[name].resampled(9)
    return [matplotlib.colors.to_hex(cmap(i)).upper() for i in range(9)]


# 家族内固定 浅 -> 深 = 侧翼 -> HA -> 人源插入：侧翼是中性背景，人源插入是主角。
SEG_FAMILY = {
    ct: dict(zip(SEG_ROLES, [brewer9(name)[i] for i in idx]))
    for ct, (name, idx) in SEG_FAMILY_SPEC.items()
}

# 接头线条/文字：三个面板语义相同 -> 三个面板必须共用同一套（这一条仍然遵守）。
# 但**不能沿用 Default_B 的红/蓝**：这张图把蓝和红分给了 MTTH 与 CD1A 两个家族，
# 红线压在 CD1A 的 #FC4E2A / #BD0026 上距离只有 0.146 / 0.102，**线在色块里直接看不见**。
# 按 STROKE_COLORS 的优先顺序往下找第一对可用的：
#   黑   —— 不能用：区段边框本来就是黑色，而 J2 恰好落在区段边界上，会和边框混成一条；
#   正红 —— 被 CD1A 家族占了；亮蓝 —— 被 MTTH 占了；深绿 —— 被 RAGH 占了；
#   咖啡 #8C510A、深紫 #762A83 —— 可用，两者相距 0.296，与全部 9 个区段色 >= 0.219。
JUNC = {
    "J2: human/mouse junction (sequence-detectable)": STROKE_COLORS[4],   # 咖啡 实线
    "J1: HA/endogenous boundary (seamless by design)": STROKE_COLORS[5],  # 深紫 虚线
}

print("\n[配色优先级验证] 三套区段配色 —— 全部来自 ColorBrewer（通用池那一级）")
for ct in CONTIGS:
    name, idx = SEG_FAMILY_SPEC[ct]
    print(f"  {ct:<8} {name:<7} 9class[{','.join(str(i + 1) for i in idx)}]  "
          f"{' '.join(SEG_FAMILY[ct].values())}")
print(f"  下面板 6 个样本色沿用 Default_B: {' '.join(SAMPLE_FILLS)}")

# --- 出图前的硬断言 ---------------------------------------------------------
for ct in CONTIGS:
    assert_visible_on_white(SEG_FAMILY[ct].values(), role="fill")
    assert_fill_not_near_black(SEG_FAMILY[ct].values())
assert_visible_on_white(SAMPLE_FILLS, role="fill")
assert_fill_not_near_black(SAMPLE_FILLS)
assert_visible_on_white(JUNC.values(), role="line")
assert_no_yellow_text(JUNC.values())
# 15 个色块两两不撞：三个区段家族彼此不撞，且都不撞样本色。
# （这里**不能**用 assert_shared_palette —— 见文件头，本图是有意让三套不同。）
assert_no_palette_collision({
    **{f"top panel FILLS: {ct} segments": list(SEG_FAMILY[ct].values()) for ct in CONTIGS},
    "bottom panel FILLS: sample": SAMPLE_FILLS,
})
# 底纹是背景不是数据填充，不进撞色断言；**只查柱子**（底纹只出现在下面板）。
_d_shade = min(_rgb_distance(c, SHADE) for c in SAMPLE_FILLS)
if _d_shade < 0.13:
    raise AssertionError(f"柱子填充色距分组底纹仅 {_d_shade:.3f} —— 柱子会和底纹糊在一起")
_all_fills = [c for ct in CONTIGS for c in SEG_FAMILY[ct].values()] + SAMPLE_FILLS
print(f"  15 个色块两两最小距离 "
      f"{min(_rgb_distance(a, b) for a, b in combinations(_all_fills, 2)):.3f}；"
      f"柱子距底纹最小 {_d_shade:.3f}（门槛 0.13）")


def assert_strokes_visible_over_fills(strokes, fills, min_distance=0.13):
    """画在色块**上面**的线条，必须与它压住的每一个填充色分得开。

    这和 assert_no_palette_collision() 不是一回事：那条管的是"语义会不会被读混"，
    线条与色块属不同角色，本来就不进那条。**本条管的是"还看不看得见"** ——
    一根线压在与它同色的色块上会直接消失，而所有既有断言都不会报错。
    触发本条的实例：Default_B 的 J2 正红 #E41A1C 压在 CD1A 家族的 #BD0026 上距离 0.102，
    出图后那一段线在色块里彻底看不见（只有肉眼看图才发现，所以补成断言）。
    """
    for s in strokes:
        for f in fills:
            d = _rgb_distance(s, f)
            if d < min_distance:
                raise AssertionError(
                    f"线条色 {s} 压在填充色 {f} 上，距离 {d:.3f} < {min_distance:.2f} —— "
                    f"线穿过该色块的那一段会看不见。换一个笔画色"
                    f"（STROKE_COLORS 里按优先序往下找）。")


_seg_all = [c for ct in CONTIGS for c in SEG_FAMILY[ct].values()]
assert_strokes_visible_over_fills(JUNC.values(), _seg_all)
print(f"  接头线 {'/'.join(JUNC.values())} 距 9 个区段色最小 "
      f"{min(_rgb_distance(a, b) for a in JUNC.values() for b in _seg_all):.3f}（门槛 0.13）")

NOTE = (
    "COLOUR SCHEME (deliberate, and different from the companion figure): each structure panel uses its OWN colour family\n"
    "— TG_MTTH blue, TG_RAGH yellow-green, TG_CD1A orange-red. Within every family the order is fixed: light = mouse\n"
    "flank, mid = homology arm, dark = human insert. Read each panel against ITS OWN legend; colours are NOT comparable\n"
    "between panels. Bar colours in the bottom panel are samples and are unrelated to all of the segment colours above.\n\n"
    "The four bar groups are junction CLASSES, not one shared coordinate: each sample carries its own targeted allele, so\n"
    "counts are compared within a class, never between loci. The three structure panels are drawn on INDEPENDENT x scales\n"
    "(254,010 / 38,566 / 185,655 bp) and their widths are therefore not comparable.\n\n"
    "Shaded groups (J1): the homology arm is identical to the endogenous locus, so these reads cannot be assigned to one or\n"
    "the other — the aligner splits them arbitrarily and reports MAPQ 0. J1 counts are therefore NOT a measure of evidence\n"
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
    """上面板：线性结构 + 接头竖线。每个面板带自己的区段图例（防误读的关键）。"""
    seg = SEG_FAMILY[contig]
    clen = int(rows[0]["contig_len"])
    ha5 = [int(v) for v in rows[0]["ha_5p"].split("-")]
    ha3 = [int(v) for v in rows[0]["ha_3p"].split("-")]
    ins = [int(v) for v in rows[0]["human_insert"].split("-")]

    blocks = [(1, ha5[0] - 1, 0), (ha5[0], ha5[1], 1), (ins[0], ins[1], 2),
              (ha3[0], ha3[1], 1), (ha3[1] + 1, clen, 0)]
    drawn = {}
    for x0, x1, ri in blocks:
        if x1 < x0:
            continue
        role = SEG_ROLES[ri]
        p = ax.add_patch(Rectangle((x0, 0.30), x1 - x0, 0.40, facecolor=seg[role],
                                   edgecolor="black", linewidth=0.8))
        drawn.setdefault(role, matplotlib.colors.to_hex(p.get_facecolor()).upper())

    tier = {"J1_5p": 0, "J2_5p": 1, "J2_3p": 1, "J1_3p": 0}
    halign = {"J1_5p": "right", "J2_5p": "left", "J2_3p": "right", "J1_3p": "left"}
    j2col, j1col = list(JUNC.values())
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
    # 图例贴在**自己这个面板的右侧**：物理位置就是"这套颜色属于谁"的最强提示。
    handles = [Rectangle((0, 0), 1, 1, facecolor=seg[r], edgecolor="black") for r in SEG_ROLES]
    ax.legend(handles, SEG_ROLES, loc="center left", bbox_to_anchor=(1.01, 0.5),
              fontsize=8.5, frameon=False,
              title=f"{contig} segments\n(this panel only)", title_fontsize=9)
    return drawn, n_lines


def main():
    coords, spanning = load()
    missing = set(SAMPLES) - {r["sample"] for r in spanning}
    if missing:
        raise SystemExit(f"交付包里找不到样本: {sorted(missing)}")
    table = {(r["sample"], r["junction_id"]): int(r["n_spanning"])
             for r in spanning if r["sample"] in SAMPLES}

    apply_publication_style(FigureStyle(font_size=12, axes_linewidth=1.8))
    fig, axes = plt.subplots(
        5, 1, figsize=(15, 16),
        gridspec_kw=dict(height_ratios=[1, 1, 1, 0.22, 3.1], hspace=0.95))
    *tops, leg_ax, bx = axes

    drawn_segs = {}
    for ax, contig in zip(tops, CONTIGS):
        rows = sorted([r for r in coords if r["contig"] == contig],
                      key=lambda r: JIDS.index(r["junction_id"]))
        drawn_segs[contig], n_lines = draw_structure(ax, contig, rows)
        assert n_lines == len(JIDS), f"{contig}: 期望 {len(JIDS)} 条接头竖线，实际 {n_lines}"

    # 只画 J1/J2 线条图例的一行（三个面板语义相同 -> 只画一次）
    leg_ax.axis("off")
    handles = [plt.Line2D([0], [0], color=JUNC[k], lw=2.2,
                          linestyle="-" if k.startswith("J2") else "--") for k in JUNC]
    leg_ax.legend(handles, list(JUNC), loc="center", ncol=2, fontsize=9, frameon=False)

    # 下面板
    for k, jid in enumerate(JIDS):
        if jid.startswith("J1"):
            bx.axvspan(k - 0.5, k + 0.5, color=SHADE, zorder=0)
    width = 0.86 / len(SAMPLES)
    n_bars = n_labels = 0
    drawn_bar_cols = set()
    for i, s in enumerate(SAMPLES):
        vals = [table[(s, j)] for j in JIDS]
        xs = [k + i * width - 0.43 + width / 2 for k in range(len(JIDS))]
        bars = bx.bar(xs, vals, width=width * 0.9, label=s, zorder=2,
                      color=SAMPLE_FILLS[i], edgecolor="black", linewidth=0.8)
        n_bars += len(bars)
        drawn_bar_cols.update(matplotlib.colors.to_hex(b.get_facecolor()).upper()
                              for b in bars)
        for x, v in zip(xs, vals):
            bx.text(x, v, str(v), ha="center", va="bottom", fontsize=8, zorder=3)
            n_labels += 1
    bx.set_xticks(range(len(JIDS)))
    bx.set_xticklabels(JIDS)
    bx.set_xlim(-0.5, len(JIDS) - 0.5)
    bx.set_ylabel("reads spanning junction\n(>=10 bp aligned on both sides)")
    bx.set_title("Junction-spanning read support per sample, all three targeted alleles "
                 "combined (bar colours = samples; a fourth colour family, unrelated to "
                 "any of the three above)", pad=26, loc="left", fontsize=11)
    bx.legend(loc="lower left", bbox_to_anchor=(0, 1.0), ncol=len(SAMPLES),
              fontsize=9, frameon=False)
    bx.text(0.0, -0.13, NOTE, transform=bx.transAxes, fontsize=8,
            va="top", ha="left", color="#333333", linespacing=1.5)

    # --- 出图后、写盘前的自检 -------------------------------------------------
    # 1) 从**画出来的**图形反查每个面板实际用了哪套颜色，并确认三套确实互不相同
    for ct in CONTIGS:
        assert drawn_segs[ct] == {r: SEG_FAMILY[ct][r] for r in SEG_ROLES}, \
            f"{ct}: 画出来的区段色与分配的不一致"
    for a, b in combinations(CONTIGS, 2):
        overlap = set(drawn_segs[a].values()) & set(drawn_segs[b].values())
        assert not overlap, f"{a} 与 {b} 画出了相同的区段色 {overlap} —— 本图要求三套互不相同"
    # 2) 语义不同的填充族两两不撞（用**渲染后**的颜色再查一遍）
    assert_no_palette_collision({
        **{f"{ct} segments as drawn": list(drawn_segs[ct].values()) for ct in CONTIGS},
        "sample bars as drawn": sorted(drawn_bar_cols),
    })
    # 3) 柱子数 / 标签数 / 填充色
    expected = len(SAMPLES) * len(JIDS)
    assert n_bars == expected, f"期望 {expected} 根柱子，实际画出 {n_bars} 根"
    assert n_labels == expected, "柱顶数值标签数量与柱子数不符"
    assert drawn_bar_cols == {c.upper() for c in SAMPLE_FILLS}, \
        "柱子实际填充色与 Default_B 的 6 色不一致"

    fig.suptitle("Three targeted alleles, one colour family each — structure (top) "
                 "and junction-spanning read support (bottom)", fontsize=13, y=0.995)
    OUT.mkdir(parents=True, exist_ok=True)
    paths = finalize_figure(fig, OUT / STEM, formats=["png", "pdf"], dpi=300, pad=1.5)
    print(f"\n[OK] 3 families x 3 segments + {len(SAMPLES)} samples = "
          f"{len(_all_fills)} fills; {n_bars} bars -> {paths[0]}")


if __name__ == "__main__":
    main()
