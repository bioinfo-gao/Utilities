"""
pubfig — publication-style matplotlib helpers + colour-discipline assertions.

House style ported from https://github.com/ChenLiu-1996/figures4papers
(the `scientific-figure-making` skill + its `figure_*` demo scripts).

Two things this module adds on top of the upstream skill, which only ever
specified the API in prose:

1. An actual, runnable implementation of that API.
2. Hard assertions for the colour rules that silently break figures:
   - two panels whose colours mean DIFFERENT things must not share colours
     (`assert_no_palette_collision`);
   - two panels whose colours mean the SAME thing must share them exactly
     (`assert_shared_palette`);
   - lines/markers/text must survive on a white background
     (`assert_visible_on_white`) — pale yellow is the classic offender;
   - a legend must never land on top of the data (`legend_outside`).

Assertions raise; they do not warn. A figure that would mislead should not be
written to disk at all.

Usage:
    import sys; sys.path.insert(0, "<this dir>")
    from pubfig import *
"""

from __future__ import annotations

import itertools
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Mapping, Sequence

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.colors import to_hex, to_rgb
from matplotlib.ticker import FixedLocator

__all__ = [
    "PALETTE",
    "DEFAULT_COLORS",
    "FigureStyle",
    "apply_publication_style",
    "create_subplots",
    "finalize_figure",
    "make_grouped_bar",
    "annotate_bars",
    "make_trend",
    "make_heatmap",
    "make_scatter",
    "legend_outside",
    "assert_no_palette_collision",
    "assert_shared_palette",
    "assert_visible_on_white",
    "brewer",
    "set3_with_grey",
    "BREWER_ROLES",
    "STROKE_COLORS",
    "STROKE_COLORS_TIER2_PALETTES",
    "soften_for_fill",
    "assert_no_yellow_text",
    "assert_fill_not_near_black",
    "composition_bar_instead_of_pie",
    "assert_points_drawn",
    "relative_luminance",
    "contrast_vs_white",
    # 2026-09-12 自 figure-style 吸收
    "assert_label_ceiling",
    "assert_no_filled_bars_on_log_axis",
    "assert_nothing_in_axis_break",
    "assert_no_text_collisions",
    "panel_crops",
]


# --------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------

#: Semantic palette. Blues = proposed / key method; greens = improvements or
#: positive variants; reds = baselines / contrasts; neutral = background.
PALETTE: dict[str, str] = {
    "blue_main": "#0F4D92",
    "blue_secondary": "#3775BA",
    "green_1": "#DDF3DE",
    "green_2": "#AADCA9",
    "green_3": "#8BCF8B",
    "red_1": "#F6CFCB",
    "red_2": "#E9A6A1",
    "red_strong": "#B64342",
    "neutral": "#CFCECE",
    "grey_mid": "#767676",
    "grey_dark": "#4D4D4D",
    "ink": "#272727",
    # Publication-safe grey ramp for large FILLS (light -> dark). `ink` and
    # `grey_dark` are for TEXT and LINES only — see assert_fill_not_near_black.
    # The light end stops at #ABABAB, not lighter: a paler first bar stops being
    # separable from a white page or a light shaded band behind it.
    "grey_pale": "#ABABAB",
    "grey_soft": "#828282",
    "grey_deep": "#5A5A5A",
    "highlight": "#FFD700",
    "teal": "#42949E",
    "violet": "#9A4D8E",
    "magenta": "#C71585",
    "cyan": "#17BECF",
}

#: Default ordered colours when `colors` is not passed to a plot helper.
DEFAULT_COLORS: list[str] = [
    PALETTE["blue_main"],
    PALETTE["green_3"],
    PALETTE["red_strong"],
    PALETTE["teal"],
    PALETTE["violet"],
    PALETTE["neutral"],
]

#: Palette families that are visually disjoint. Hand one family to each panel
#: whose colours mean something different from its neighbours' colours.
#: Each family is ordered darkest-first, so truncating to the first N keeps the
#: line/marker-safe colours; the pale tail entries are fill-only (they need a
#: black edge to read on white) — `assert_visible_on_white` enforces this.
PALETTE_FAMILIES: dict[str, list[str]] = {
    "cool": [PALETTE["blue_main"], PALETTE["blue_secondary"], PALETTE["teal"], PALETTE["cyan"]],
    "warm": [PALETTE["red_strong"], PALETTE["red_2"], PALETTE["magenta"], PALETTE["highlight"]],
    "green": [PALETTE["green_3"], PALETTE["green_2"], PALETTE["green_1"]],
    # Grey is the exception to darkest-first: it runs LIGHT -> DARK and stops at a
    # mid grey. A large solid near-black bar is a publication/presentation no-no.
    "grey": [PALETTE["grey_pale"], PALETTE["grey_soft"], PALETTE["grey_deep"]],
}


# --------------------------------------------------------------------------
# Style and layout
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class FigureStyle:
    """Typography and spine weights.

    font_size:      16 default; 24 for large bar panels, 15-16 for compact plots.
    axes_linewidth: 2.5 default; 3 for big bars, 2 for compact plots.
    use_tex:        True only when LaTeX is installed and math labels are needed.
    """

    font_size: int = 16
    axes_linewidth: float = 2.5
    use_tex: bool = False
    font_family: tuple[str, ...] = ("Arial", "Helvetica", "DejaVu Sans", "sans-serif")


def apply_publication_style(style: FigureStyle | None = None) -> None:
    """Set rcParams for the house style. Call once before creating figures."""
    style = style or FigureStyle()
    mpl.rcParams.update(
        {
            "font.family": "sans-serif",
            "font.sans-serif": list(style.font_family),
            "font.size": style.font_size,
            "axes.linewidth": style.axes_linewidth,
            "axes.spines.right": False,
            "axes.spines.top": False,
            "axes.titlesize": style.font_size,
            "axes.labelsize": style.font_size,
            "xtick.labelsize": style.font_size * 0.9,
            "ytick.labelsize": style.font_size * 0.9,
            "legend.fontsize": style.font_size * 0.9,
            "legend.frameon": False,
            "text.usetex": style.use_tex,
            "svg.fonttype": "none",  # keep vector text editable
            "pdf.fonttype": 42,  # TrueType, not Type-3
            "ps.fonttype": 42,
            "figure.facecolor": "white",
            "savefig.facecolor": "white",
        }
    )


def create_subplots(nrows: int = 1, ncols: int = 1, figsize=None, **kwargs):
    """Return (fig, axes) with axes always a flattened 1-D ndarray of Axes."""
    fig, axes = plt.subplots(nrows, ncols, figsize=figsize, **kwargs)
    axes = np.atleast_1d(np.asarray(axes)).ravel()
    return fig, axes


_SUPPORTED_FORMATS = {"pdf", "svg", "eps", "png", "jpg", "jpeg", "tif", "tiff"}


def finalize_figure(
    fig,
    out_path,
    formats: Sequence[str] | None = None,
    dpi: int = 300,
    close: bool = True,
    pad: float = 2.0,
    **kwargs,
) -> list[Path]:
    """tight_layout, then save to every requested format. Returns saved paths.

    `pad` is the tight_layout pad (house default 2; use 1 for compact
    multi-panel figures). `out_path` may carry an extension, in which case it
    is used when `formats` is None; otherwise pdf+png are written.
    """
    out_path = Path(out_path)
    if formats is None:
        ext = out_path.suffix.lstrip(".").lower()
        formats = [ext] if ext in _SUPPORTED_FORMATS else ["pdf", "png"]
    bad = [f for f in formats if f.lower() not in _SUPPORTED_FORMATS]
    if bad:
        raise ValueError(f"unsupported format(s): {bad}; supported: {sorted(_SUPPORTED_FORMATS)}")

    fig.tight_layout(pad=pad)
    stem = out_path.with_suffix("")
    stem.parent.mkdir(parents=True, exist_ok=True)

    saved = []
    for fmt in formats:
        path = stem.with_suffix(f".{fmt.lower()}")
        fig.savefig(path, dpi=dpi, bbox_inches="tight", **kwargs)
        saved.append(path)
    if close:
        plt.close(fig)
    return saved


# --------------------------------------------------------------------------
# Colour discipline — the assertions
# --------------------------------------------------------------------------


def _norm(colors: Iterable) -> list[str]:
    return [to_hex(c).lower() for c in colors]


def relative_luminance(color) -> float:
    """WCAG relative luminance in [0, 1]."""

    def lin(c: float) -> float:
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = (lin(v) for v in to_rgb(color))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_vs_white(color) -> float:
    """WCAG contrast ratio of `color` against a white background (1.0 - 21.0)."""
    return 1.05 / (relative_luminance(color) + 0.05)


def _rgb_distance(a, b) -> float:
    """Luminance-weighted RGB distance; ~0 means visually indistinguishable."""
    ar, ag, ab = to_rgb(a)
    br, bg, bb = to_rgb(b)
    return math.sqrt(2 * (ar - br) ** 2 + 4 * (ag - bg) ** 2 + 3 * (ab - bb) ** 2) / 3.0


def assert_no_palette_collision(
    panels: Mapping[str, Iterable],
    min_distance: float = 0.10,
) -> None:
    """Panels whose colours mean DIFFERENT things must not share colours.

    Readers assume same colour == same meaning. Two panels in one figure that
    reuse a colour for unrelated variables are read as a top-to-bottom
    comparison, which is a correctness bug, not a cosmetic one. matplotlib's
    default property cycle restarts at C0 on every Axes, so the collision
    happens silently unless you assert against it.

    Pass **fills only**. The constraint applies within one role: what a reader
    compares across panels is filled area (bars, rects, boxes). A 1.5 pt line or
    a text label that happens to share a hue with some bar is a different
    channel and is not read as "same meaning" — folding line and label colours
    into the exclusion list burns half the usable hue space for nothing. When
    hues run short, set label text to black rather than hunting for another hue.

    Args:
        panels: {panel label: FILL colours used in that panel}. Include ONLY
            panels whose colour semantics differ from each other. Panels that
            share a meaning belong in `assert_shared_palette` instead.
        min_distance: colours closer than this are treated as a collision even
            when the hex codes differ (near-misses mislead just as much).

    Raises:
        AssertionError naming the two panels and the offending colours.
    """
    items = {name: _norm(cols) for name, cols in panels.items()}
    for (name_a, cols_a), (name_b, cols_b) in itertools.combinations(items.items(), 2):
        exact = sorted(set(cols_a) & set(cols_b))
        if exact:
            raise AssertionError(
                f"palette collision: panels '{name_a}' and '{name_b}' encode different "
                f"variables but share colour(s) {exact}. Give each panel its own "
                f"colour family (see PALETTE_FAMILIES) and say in each legend what "
                f"its colours mean."
            )
        near = [
            (a, b, round(_rgb_distance(a, b), 3))
            for a in set(cols_a)
            for b in set(cols_b)
            if _rgb_distance(a, b) < min_distance
        ]
        if near:
            raise AssertionError(
                f"near-collision: panels '{name_a}' and '{name_b}' encode different "
                f"variables but use visually indistinguishable colours {near} "
                f"(distance < {min_distance}). Pick disjoint colour families."
            )


def assert_shared_palette(panels: Mapping[str, Mapping[str, str]]) -> None:
    """Panels whose colours mean the SAME thing must map level -> colour identically.

    Args:
        panels: {panel label: {level name: colour}}. Every panel must carry the
            same levels bound to the same colours.

    Raises:
        AssertionError naming the first panel that disagrees.
    """
    if len(panels) < 2:
        return
    (ref_name, ref_map), *rest = list(panels.items())
    ref = {k: to_hex(v).lower() for k, v in ref_map.items()}
    for name, mapping in rest:
        this = {k: to_hex(v).lower() for k, v in mapping.items()}
        if this != ref:
            missing = sorted(set(ref) - set(this))
            extra = sorted(set(this) - set(ref))
            recoloured = sorted(k for k in set(ref) & set(this) if ref[k] != this[k])
            raise AssertionError(
                f"panels '{ref_name}' and '{name}' encode the same variable but their "
                f"colour maps differ — missing levels {missing}, extra levels {extra}, "
                f"recoloured levels {recoloured}. Build ONE dict and pass it to both."
            )


def assert_visible_on_white(colors: Iterable, role: str = "line", min_contrast: float = 1.5) -> None:
    """Colours used for lines/markers/text must survive a white background.

    Pale yellow (`#FFFF33` and friends) has ~1.07 contrast against white: the
    points AND any text label inheriting that colour are effectively invisible.
    Use cyan `#17BECF` or magenta `#C71585` instead.

    role="fill" relaxes the check (pale fills are fine when the bar carries a
    black edge) but still rejects anything at near-paper luminance.
    """
    threshold = min_contrast if role != "fill" else 1.1
    offenders = [
        (to_hex(c).lower(), round(contrast_vs_white(c), 2))
        for c in colors
        if contrast_vs_white(c) < threshold
    ]
    if offenders:
        raise AssertionError(
            f"colour(s) too pale for role='{role}' on a white background: {offenders} "
            f"(need contrast >= {threshold}). Pale yellow is the usual culprit; "
            f"swap in cyan #17BECF or magenta #C71585, and force text labels to black."
        )


#: Preferred colours for LINES and TEXT, in priority order. Take them from the
#: top; only reach past the end of this list when you have used all six.
#:
#: These are the battle-tested, unambiguously legible stroke colours — deep
#: enough that a one-pixel line or a small label still registers, and spread far
#: enough apart in hue that no two are ever confused (minimum pairwise distance
#: 0.221, better separated than any fill palette). Contrast on white runs
#: 4.7-21.0, all well clear of the 1.5 line/text floor.
#:
#: Black first: it never fails and costs no hue. It is also the fallback whenever
#: colours run short — a black label is never wrong.
#:
#: ASSUMED BACKGROUND: white or light. That covers the overwhelming majority of
#: figures, and every check in this module (`contrast_vs_white`,
#: `assert_visible_on_white`) is written for it. On the occasional dark
#: background the logic mirrors: white and light monochrome strokes take over,
#: and these six go unreadable. There is no dark-background checker here —
#: if you build one, invert the luminance test rather than reusing these values.
STROKE_COLORS: list[str] = [
    "#000000",  # black      contrast 21.00
    "#E41A1C",  # true red   contrast  4.71
    "#1F78B4",  # bright blue contrast 4.77
    "#006D2C",  # dark green contrast  6.51
    "#8C510A",  # coffee     contrast  6.37
    "#762A83",  # dark purple contrast 8.64
]

#: Second tier for lines/text once STROKE_COLORS is exhausted: the polarised dark
#: ends of the diverging ColorBrewer palettes, via brewer("PRGn", 2) etc.
#: They overlap tier 1 slightly (#00441B sits 0.087 from #006D2C), so check what
#: you already used before drawing from here.
STROKE_COLORS_TIER2_PALETTES = ("PRGn", "PiYG", "BrBG")

#: ColorBrewer palettes worth knowing by name, grouped by the role they suit.
#: Browse them at https://r-graph-gallery.com/38-rcolorbrewers-palettes.html
BREWER_ROLES = {
    # Qualitative, low saturation, designed for LARGE FILL AREAS.
    # Set3 is the workhorse: 12 distinguishable soft colours.
    "fill": ("Set3", "Pastel1", "Pastel2", "Set2"),
    # Diverging — take the DARK ENDS for lines, strokes and text.
    "line": ("PRGn", "PiYG", "BrBG", "RdBu", "RdYlBu"),
    # Qualitative, saturated — points, small markers, emphasis.
    "marker": ("Dark2", "Set1"),
}


def set3_with_grey(grey: str = "#999999") -> list[str]:
    """Set3 with its blue #80B1D3 swapped for a mid grey — the preferred 12-fill set.

    Two things are wrong with stock Set3 for our purposes, and one swap fixes both:

    1. #80B1D3 (blue) and #8DD3C7 (teal) sit 0.096 apart under `_rgb_distance`,
       below the collision threshold — so they can never be split across two
       panels, which costs you a colour in practice.
    2. Set3's only neutral is #D9D9D9, which is very light (contrast 1.41). A
       usable mid grey is worth more than a second cool hue: greys carry
       "reference / background / other" without competing for a hue slot.

    Dropping the blue in favour of #999999 (contrast 2.85, inside Set3's own
    1.29-3.02 band, so it reads as a family member) removes the collision AND
    frees #8DD3C7 for real use. The two greys coexist happily: #999999 vs
    #D9D9D9 is 0.251 apart.

    A darker grey is required, not a lighter one: #BFBFBF lands 0.063 from
    Set3's lavender #BEBADA.

    Note that #FFFFB3 (index 1) is still pale yellow at 1.04 contrast and must
    be skipped for anything but the largest fills — this helper leaves it in
    place so indices stay comparable with stock Set3.
    """
    return [grey if c.upper() == "#80B1D3" else c.upper() for c in brewer("Set3")]


def brewer(name: str, n: int | None = None, skip: Iterable[int] = ()) -> list[str]:
    """Fetch a ColorBrewer palette as hex strings.

    **When you are stuck choosing colours, go here first** rather than inventing
    a palette: https://r-graph-gallery.com/38-rcolorbrewers-palettes.html
    These palettes are perceptually engineered, and split cleanly by role —
    see BREWER_ROLES. Qualitative sets (Set3, Pastel1) are already low-saturation
    and therefore right for fills; the dark ends of diverging sets (PRGn, PiYG,
    BrBG) are deep and saturated and therefore right for lines and text.

    Args:
        name: palette name, e.g. "Set3", "PRGn".
        n: how many colours; qualitative palettes return their full set when None,
            continuous/diverging ones are sampled evenly across the full range
            (so n=2 gives you exactly the two dark ends).
        skip: indices to drop from a qualitative palette before truncating to n —
            use it to step over a member that fails a check. Set3's index 1
            (#FFFFB3) is pale yellow at 1.04 contrast on white and will fail
            `assert_visible_on_white`; index 11 (#FFED6F) is also yellow.

    Always run the usual assertions on what comes back — a famous palette is not
    automatically safe for your particular background and role.
    """
    cmap = mpl.colormaps[name]
    if hasattr(cmap, "colors"):  # qualitative: use the discrete entries
        cols = [to_hex(c) for i, c in enumerate(cmap.colors) if i not in set(skip)]
        return cols[:n] if n else cols
    if not n:
        raise ValueError(f"{name} is a continuous palette; pass n")
    if n == 1:
        return [to_hex(cmap(0.5))]
    return [to_hex(cmap(i / (n - 1))) for i in range(n)]


def soften_for_fill(color, sat_factor: float = 0.55, val_factor: float = 1.0) -> str:
    """Derive a fill-appropriate version of a line/text colour by desaturating it.

    **Type and fills have opposite saturation needs.** Text and thin lines are
    made of strokes a pixel or two wide — they need saturation and depth to
    register at all. A bar, box or map polygon is a large block: a much weaker
    saturation reads perfectly clearly, and a fully saturated one shouts over
    the data. So the same hue should appear *strong* as a line and *soft* as a
    fill.

    This also settles the cross-panel question cleanly: a line and a bar sharing
    one hue at different saturations are obviously the same family without
    reading as the same variable.

    Args:
        sat_factor: multiply HSV saturation by this (0.4-0.7 is the useful band).
        val_factor: multiply HSV value; >1 lightens a dark hue that would
            otherwise go muddy when desaturated.

    Returns the hex string; run the usual fill assertions on the result.
    """
    import colorsys

    h, s, v = colorsys.rgb_to_hsv(*to_rgb(color))
    return to_hex(colorsys.hsv_to_rgb(h, s * sat_factor, min(1.0, v * val_factor)))


def assert_no_yellow_text(colors: Iterable) -> None:
    """Text is never yellow — no matter how dark the yellow is.

    Contrast alone does not catch this: dark goldenrod #B8860B clears the
    white-background contrast bar yet still reads as yellow text, which is hard
    to focus on at any size. The test is therefore on HUE, not lightness:
    anything in the yellow band (hue 40-75 degrees) is rejected for text.

    Orange (hue < 40) and yellow-green (hue > 75) are left alone. Yellow is fine
    as a FILL behind a black edge — `highlight` #FFD700 is used exactly that way.
    """
    import colorsys

    offenders = []
    for c in colors:
        r, g, b = to_rgb(c)
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        hue = h * 360
        if 40 <= hue <= 75 and s > 0.25:
            offenders.append((to_hex(c).lower(), f"hue {hue:.0f}deg"))
    if offenders:
        raise AssertionError(
            f"yellow text colour(s) {offenders}: yellow text is hard to read at any "
            f"lightness. Use black for labels, or a non-yellow accent. Yellow is fine "
            f"as a fill behind a black edge, just never as type."
        )


def assert_fill_not_near_black(colors: Iterable, max_contrast: float = 10.0) -> None:
    """Large filled areas (bars, boxes, ribbons, map polygons) must not be near-black.

    A big solid black or near-black bar is heavy and ugly in a paper figure or on a
    slide — it dominates the panel and reads as ink rather than data. Use a mid-grey
    ramp instead (`PALETTE_FAMILIES["grey"]` runs light -> dark and stops at
    `grey_deep` #5A5A5A for exactly this reason).

    This is a near-black guard, not a general darkness cap: a dark *saturated*
    colour like `blue_main` #0F4D92 (contrast 8.4) is fine and stays allowed.
    Reserve `ink` #272727 and `grey_dark` #4D4D4D for text and thin lines, where
    their weight is an asset rather than a blot.
    """
    offenders = [
        (to_hex(c).lower(), round(contrast_vs_white(c), 2))
        for c in colors
        if contrast_vs_white(c) > max_contrast
    ]
    if offenders:
        raise AssertionError(
            f"near-black fill(s) {offenders}: contrast vs white above {max_contrast} "
            f"means a large solid area reads as a black blot. Use "
            f"PALETTE_FAMILIES['grey'] (light->dark, capped at #5A5A5A); keep "
            f"'ink'/'grey_dark' for text and lines."
        )


def legend_outside(ax, *args, loc: str = "lower left", bbox_to_anchor=(0.0, 1.0), **kwargs):
    """Place a legend OUTSIDE the data area. Never use loc='best'.

    With few groups, `loc="best"` drops the legend into the middle of the plot
    and covers the data. Default here anchors it above the axes.
    """
    if loc == "best":
        raise ValueError("loc='best' covers the data; anchor the legend outside the axes")
    return ax.legend(*args, loc=loc, bbox_to_anchor=bbox_to_anchor, **kwargs)


def assert_points_drawn(ax, expected: int) -> None:
    """Assert a scatter/PCA panel actually rendered `expected` points.

    Two silent matplotlib/ggplot failure modes drop points with no error: an
    over-long discrete shape scale, and NaN coordinates. On a QC plot whose
    whole purpose is to show every sample, a silently undercounted panel is a
    correctness bug. Count, do not eyeball.
    """
    drawn = 0
    for coll in ax.collections:
        offsets = np.asarray(coll.get_offsets())
        if offsets.size:
            drawn += int(np.sum(~np.isnan(offsets).any(axis=1)))
    for line in ax.lines:
        if line.get_linestyle() in ("None", "none", ""):
            drawn += int(np.sum(~np.isnan(np.asarray(line.get_ydata(), dtype=float))))
    if drawn != expected:
        raise AssertionError(
            f"expected {expected} points on this axes, {drawn} were drawn. "
            f"Check for NaN coordinates or a discrete scale that silently dropped rows."
        )


# --------------------------------------------------------------------------
# 2026-09-12 新增三条 —— 自 Claude Science 内置 `figure-style` 吸收（Apache-2.0）
#
# 为什么是断言而不是检查清单：清单的执行率**不可观测**——我说"检查过了"和真检查过，
# 产物一模一样；断言不过则图出不来。对照见
# projects_2026M7/35_Try_of_Claude_Science/docs/P35_figure_style_vs_ours_0911.md
# --------------------------------------------------------------------------


def assert_label_ceiling(ax, max_annotations: int = 6) -> None:
    """标注不得过多：轴标签与刻度之外的叙述性文字 > max_annotations 即判超。

    出处：figure-style §2.2。**只数叙述性标注**——轴标题、刻度标签、图例条目
    属于"下限"（不标读者就不知道那是什么），不进预算；超的是柱顶数字、箭头注释、
    括号、callout 这类**作者想多说几句**的东西。

    判据方向要记住：这一条防的是"标签太多把图糊住"，与
    assert_visible_on_white()（防标签太浅看不见）是相反方向的两件事。
    """
    excluded = set()
    for t in list(ax.get_xticklabels(which="both")) + list(ax.get_yticklabels(which="both")):
        excluded.add(id(t))
    for t in (ax.title, ax.xaxis.label, ax.yaxis.label):
        if t is not None:
            excluded.add(id(t))
    leg = ax.get_legend()
    if leg is not None:
        for t in leg.get_texts():
            excluded.add(id(t))
        if leg.get_title() is not None:
            excluded.add(id(leg.get_title()))

    narrative = [
        t for t in ax.texts
        if id(t) not in excluded and t.get_visible() and str(t.get_text()).strip()
    ]
    if len(narrative) > max_annotations:
        sample = ", ".join(repr(str(t.get_text())[:18]) for t in narrative[:6])
        raise AssertionError(
            f"{len(narrative)} narrative annotations on this axes, ceiling is "
            f"{max_annotations} (figure-style §2.2). Axis titles / tick labels / legend "
            f"entries are NOT counted — these are extra callouts. First few: {sample}. "
            f"Delete the ones a reader can read off the axis; keep only the headline number."
        )


def assert_no_filled_bars_on_log_axis(ax) -> None:
    """log 轴上不得画填充柱。

    出处：figure-style §3.3 / §8。柱长编码的是"到基线的距离"，而 log 轴没有
    有意义的零点——柱长于是变成"与一个任意下限的比值"，读者读到的倍数是假的。
    改用点 + 中位线（strip / lollipop）。

    ⚠ 只查**数值轴**是否 log：分类轴不可能是 log，横竖柱都要按各自的数值轴判。
    """
    from matplotlib.patches import Rectangle

    bars = [p for p in ax.patches if isinstance(p, Rectangle) and p.get_visible()]
    if not bars:
        return
    # 柱子贴着哪条基线：宽度恒定 ⇒ 竖柱（数值在 y）；高度恒定 ⇒ 横柱（数值在 x）
    widths = {round(float(b.get_width()), 9) for b in bars}
    heights = {round(float(b.get_height()), 9) for b in bars}
    if len(widths) == 1 and len(heights) > 1:
        value_axis, scale = "y", ax.get_yscale()
    elif len(heights) == 1 and len(widths) > 1:
        value_axis, scale = "x", ax.get_xscale()
    else:                                   # 判不出朝向就两条都查，宁可多报
        for value_axis, scale in (("x", ax.get_xscale()), ("y", ax.get_yscale())):
            if scale == "log":
                break
    if scale == "log":
        raise AssertionError(
            f"{len(bars)} filled bars drawn on a log-scaled {value_axis} axis "
            f"(figure-style §3.3). Bar length encodes ratio to an arbitrary floor there, "
            f"so the lengths a reader compares are meaningless. Use points + a median "
            f"tick (strip_with_median-style) instead, or put the axis back on a linear scale."
        )


def assert_nothing_in_axis_break(ax, break_range, axis: str = "y") -> None:
    """断轴缺口里不得画任何东西——参考线、阈值线、标注都不行。

    出处：figure-style §3.2 / §8。**缺口没有坐标**：那一段被显式声明为"此处的
    数值不连续"，往里画一条 y=threshold 的线，读者会按缺口两侧的刻度去推它的值，
    而那个推断必然是错的。

    :param break_range: (lo, hi) 缺口的数据坐标区间（开区间端点按闭区间处理）。
    """
    lo, hi = float(min(break_range)), float(max(break_range))
    offenders = []

    lines = ax.axhline, ax.axvline          # 仅用于文档；实际遍历 ax.lines
    del lines
    for ln in ax.lines:
        if not ln.get_visible():
            continue
        data = np.asarray(ln.get_ydata() if axis == "y" else ln.get_xdata(), dtype=float)
        data = data[~np.isnan(data)]
        if data.size and np.all((data >= lo) & (data <= hi)):
            offenders.append(("line", float(data[0])))
    for t in ax.texts:
        if not t.get_visible() or not str(t.get_text()).strip():
            continue
        pos = float(t.get_position()[1 if axis == "y" else 0])
        if lo <= pos <= hi:
            offenders.append((f"text {str(t.get_text())[:18]!r}", pos))

    if offenders:
        shown = "; ".join(f"{k} at {axis}={v:g}" for k, v in offenders[:5])
        raise AssertionError(
            f"{len(offenders)} element(s) drawn inside the {axis}-axis break "
            f"[{lo:g}, {hi:g}] (figure-style §3.2): {shown}. The gap has no coordinate — "
            f"a reader will interpolate from the ticks on either side and get a wrong value. "
            f"Move them outside the break, or don't break the axis there."
        )


def assert_no_text_collisions(fig, pad_px: float = 0.0) -> None:
    """渲染后几何检查：可见文字不得互压、不得压轴线、不得出画布。

    出处：figure-style §9.1。**必须在 savefig 之后（或至少 fig.canvas.draw() 之后）
    调用**——在那之前 bounding box 还没有真实尺寸。

    ⚠ 唯一的假阳性来源已排除：**刻度标签压在它自己那根轴线上是正常的**，不算命中。
    不排除这一条，任何一张图都会报错，闸门就会被关掉。
    """
    import matplotlib as mpl

    fig.canvas.draw()
    r = fig.canvas.get_renderer()

    # ⚠ 2026-09-12 实测修补（被 selftest 的干净用例抓出来的假阳性）：
    # matplotlib 会为**超出视图范围**的刻度保留 Text 对象，它们 get_visible() 为真、
    # get_window_extent() 照样返回坐标，但根本不会被画出来。不剔除的话，
    # 任何一张普通图都会报"文字出画布"——闸门当场变成噪音。
    offview = set()
    for ax in fig.axes:
        for axis, lim in ((ax.xaxis, ax.get_xlim()), (ax.yaxis, ax.get_ylim())):
            lo, hi = min(lim), max(lim)
            for tick in list(axis.get_major_ticks()) + list(axis.get_minor_ticks()):
                loc = getattr(tick, "get_loc", lambda: None)()
                if loc is None or not (lo <= float(loc) <= hi):
                    offview.add(id(tick.label1))
                    offview.add(id(tick.label2))

    texts = [
        (t, t.get_window_extent(r)) for t in fig.findobj(mpl.text.Text)
        if str(t.get_text()).strip() and t.get_visible() and id(t) not in offview
    ]
    spines = [
        (s, s.get_window_extent(r)) for ax in fig.axes
        for s in ax.spines.values() if s.get_visible()
    ]
    own_ticklabels = {
        ax: {id(t) for t in ax.get_xticklabels(which="both") + ax.get_yticklabels(which="both")}
        for ax in fig.axes
    }

    def _overlaps(a, b):
        return a.expanded(1, 1).overlaps(b) if pad_px == 0 else \
            a.padded(pad_px).overlaps(b.padded(pad_px))

    problems = []
    for i, (ta, ba) in enumerate(texts):
        for tb, bb in texts[i + 1:]:
            if _overlaps(ba, bb):
                problems.append(
                    f"text {str(ta.get_text())[:14]!r} overlaps {str(tb.get_text())[:14]!r}")
    for t, bt in texts:
        for s, bs in spines:
            if id(t) in own_ticklabels.get(s.axes, ()):
                continue                    # 刻度标签压自己的轴线 —— 正常，不是缺陷
            if _overlaps(bt, bs):
                problems.append(f"text {str(t.get_text())[:14]!r} overlaps a spine")
    for t, bt in texts:
        if not fig.bbox.contains(bt.x0, bt.y0) or not fig.bbox.contains(bt.x1, bt.y1):
            problems.append(f"text {str(t.get_text())[:14]!r} extends outside the canvas")

    if problems:
        uniq = list(dict.fromkeys(problems))
        raise AssertionError(
            f"{len(uniq)} geometric text problem(s) (figure-style §9.1): "
            + "; ".join(uniq[:6])
            + ". Move, shorten or stagger the labels and re-save until clean."
        )


def panel_crops(fig, pad_px: float = 6.0) -> dict:
    """给每个 axes 算出像素裁剪框，供**逐 panel 人眼看**。

    出处：figure-style §9.2。几何检查是几何的，不是感知的——低对比度标签、
    引线交叉、两个系列颜色相近，bbox 一条都抓不到。所以存图后把每个 panel
    单独裁出来看一眼，这一步**没有任何断言能替代**。

    返回 {label: (left, upper, right, lower)}，PIL 裁剪坐标（原点在左上）。
    """
    fig.canvas.draw()
    H = fig.bbox.height
    out = {}
    for i, ax in enumerate(fig.axes):
        b = ax.get_tightbbox(fig.canvas.get_renderer())
        label = ax.get_label() or chr(ord("a") + i)
        out[str(label)] = (
            max(0.0, b.x0 - pad_px), max(0.0, H - b.y1 - pad_px),
            min(fig.bbox.width, b.x1 + pad_px), min(H, H - b.y0 + pad_px),
        )
    return out


# --------------------------------------------------------------------------
# Plot helpers
# --------------------------------------------------------------------------


def make_grouped_bar(
    ax,
    categories: Sequence[str],
    series: Sequence[Sequence[float]],
    labels: Sequence[str],
    ylabel: str = "Value",
    colors: Sequence[str] | None = None,
    annotate: bool = False,
    fmt: str = "{:.2f}",
    edgecolor: str = "black",
    edge_linewidth: float = 1.5,
    hatches: Sequence[str] | None = None,
):
    """Grouped bars, one bar group per series. Returns the last BarContainer.

    `series`: one 1-D array per series, each of len(categories).
    Black edges are on by default so bars stay separable in greyscale print;
    pass `hatches` for a second, colour-independent channel.
    """
    values = [np.asarray(s, dtype=float) for s in series]
    n_cat = len(categories)
    for i, arr in enumerate(values):
        if arr.ndim != 1 or arr.size != n_cat:
            raise ValueError(
                f"series[{i}] has shape {arr.shape}; expected 1-D of length {n_cat}"
            )
    if len(labels) != len(values):
        raise ValueError(f"{len(labels)} labels for {len(values)} series")

    colors = list(colors) if colors is not None else DEFAULT_COLORS[: len(values)]
    if len(colors) < len(values):
        raise ValueError(f"{len(colors)} colours for {len(values)} series")

    x = np.arange(n_cat, dtype=float)
    width = 0.8 / len(values)
    bars = None
    for i, (arr, label) in enumerate(zip(values, labels)):
        offset = (i - (len(values) - 1) / 2) * width
        bars = ax.bar(
            x + offset,
            arr,
            width=width,
            label=label,
            color=colors[i],
            edgecolor=edgecolor,
            linewidth=edge_linewidth,
            hatch=None if hatches is None else hatches[i],
        )
        if annotate:
            annotate_bars(ax, bars, fmt=fmt)

    ax.set_xticks(x)
    ax.set_xticklabels(categories)
    ax.set_ylabel(ylabel)
    return bars


def annotate_bars(ax, bars, fmt: str = "{:.2f}", fontsize: float | None = None, padding: float = 3):
    """Print each bar's value above it."""
    for rect in bars:
        height = rect.get_height()
        ax.annotate(
            fmt.format(height),
            xy=(rect.get_x() + rect.get_width() / 2, height),
            xytext=(0, padding),
            textcoords="offset points",
            ha="center",
            va="bottom",
            fontsize=fontsize,
        )


def make_trend(
    ax,
    x,
    y_series: Sequence[Sequence[float]],
    labels: Sequence[str],
    colors: Sequence[str] | None = None,
    ylabel: str | None = None,
    xlabel: str | None = None,
    show_shadow: bool = True,
    shadow: Sequence[Sequence[float]] | None = None,
    linewidth: float = 2.5,
):
    """Line panel with optional uncertainty band.

    `shadow`: per-series half-width of the band. When None and
    `show_shadow=True`, a 5%-of-value band is drawn as a visual cue only —
    pass real standard errors whenever you have them.
    """
    x = np.asarray(x, dtype=float)
    ys = [np.asarray(y, dtype=float) for y in y_series]
    for i, y in enumerate(ys):
        if y.shape != x.shape:
            raise ValueError(f"y_series[{i}] has shape {y.shape}; expected {x.shape}")
    if len(labels) != len(ys):
        raise ValueError(f"{len(labels)} labels for {len(ys)} series")

    colors = list(colors) if colors is not None else DEFAULT_COLORS[: len(ys)]
    assert_visible_on_white(colors, role="line")

    for i, (y, label) in enumerate(zip(ys, labels)):
        ax.plot(x, y, label=label, color=colors[i], linewidth=linewidth)
        if show_shadow:
            band = np.abs(y) * 0.05 if shadow is None else np.asarray(shadow[i], dtype=float)
            ax.fill_between(x, y - band, y + band, color=colors[i], alpha=0.18, linewidth=0)

    if ylabel:
        ax.set_ylabel(ylabel)
    if xlabel:
        ax.set_xlabel(xlabel)
    return ax


def make_heatmap(
    ax,
    matrix,
    x_labels: Sequence[str] | None = None,
    y_labels: Sequence[str] | None = None,
    cmap: str = "magma",
    cbar_label: str | None = None,
    annotate: bool = False,
    fmt: str = "{:.2f}",
    vmin: float | None = None,
    vmax: float | None = None,
):
    """2-D heatmap with optional colorbar label and cell annotations."""
    m = np.asarray(matrix, dtype=float)
    if m.ndim != 2:
        raise ValueError(f"matrix must be 2-D, got shape {m.shape}")

    im = ax.imshow(m, cmap=cmap, aspect="auto", vmin=vmin, vmax=vmax)
    if x_labels is not None:
        ax.set_xticks(np.arange(m.shape[1]))
        ax.set_xticklabels(x_labels, rotation=45, ha="right")
    if y_labels is not None:
        ax.set_yticks(np.arange(m.shape[0]))
        ax.set_yticklabels(y_labels)
    if annotate:
        mid = (np.nanmax(m) + np.nanmin(m)) / 2
        for i in range(m.shape[0]):
            for j in range(m.shape[1]):
                ax.text(
                    j, i, fmt.format(m[i, j]), ha="center", va="center",
                    color="white" if m[i, j] < mid else "black",
                )
    cbar = ax.figure.colorbar(im, ax=ax)
    if cbar_label:
        cbar.set_label(cbar_label)
    return im


def make_scatter(ax, x, y, label=None, color=None, size: float = 50, alpha: float = 0.7, **kwargs):
    """Single-series scatter. Colour is checked for white-background legibility."""
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    if x.shape != y.shape:
        raise ValueError(f"x{x.shape} and y{y.shape} must match")
    color = color or PALETTE["blue_main"]
    assert_visible_on_white([color], role="marker")
    return ax.scatter(x, y, label=label, color=color, s=size, alpha=alpha, **kwargs)


def composition_bar_instead_of_pie(
    ax,
    labels: Sequence[str],
    values: Sequence[float],
    color=None,
    as_percent: bool = True,
    sort_desc: bool = True,
    fmt: str = "{:.1f}%",
    horizontal: bool = True,
):
    """Draw a composition as a ranked bar chart — the replacement for a pie chart.

    Readers cannot compare angles: a 26% slice and a 29% slice look the same in a
    pie. As bars they are unmistakable, and the printed number settles it outright.
    Sorting descending adds a rank the pie also fails to convey.

    Use a pie only when a single share is being shown against the whole ("38% of
    reads were on-target") and even then print the number.

    Args:
        values: raw counts or percentages; converted to percent when as_percent.
    """
    vals = np.asarray(values, dtype=float)
    if len(labels) != vals.size:
        raise ValueError(f"{len(labels)} labels for {vals.size} values")
    if as_percent:
        total = vals.sum()
        if total <= 0:
            raise ValueError("values must sum to a positive number to show percentages")
        vals = vals / total * 100.0

    order = np.argsort(-vals) if sort_desc else np.arange(vals.size)
    vals = vals[order]
    labs = [labels[i] for i in order]
    color = color or PALETTE["blue_main"]
    assert_fill_not_near_black([color] if isinstance(color, str) else color)

    pos = np.arange(vals.size)
    if horizontal:
        bars = ax.barh(pos, vals, color=color, edgecolor="black", linewidth=1.0)
        ax.set_yticks(pos)
        ax.set_yticklabels(labs)
        ax.invert_yaxis()  # largest at top
        ax.set_xlabel("share (%)" if as_percent else "value")
        for rect, v in zip(bars, vals):
            ax.text(rect.get_width(), rect.get_y() + rect.get_height() / 2,
                    " " + fmt.format(v), va="center", ha="left", fontsize=None)
        ax.set_xlim(0, vals.max() * 1.18)
    else:
        bars = ax.bar(pos, vals, color=color, edgecolor="black", linewidth=1.0)
        ax.set_xticks(pos)
        ax.set_xticklabels(labs)
        ax.set_ylabel("share (%)" if as_percent else "value")
        annotate_bars(ax, bars, fmt=fmt)
        ax.set_ylim(0, vals.max() * 1.18)
    return bars


def tighten_ylim(ax, data, margin_frac: float = 0.15) -> None:
    """Tighten y-limits to the data range so differences are visible.

    Fixed 0-100 limits squash values that all sit in 85-95.
    """
    d = np.asarray(data, dtype=float)
    lo, hi = np.nanmin(d), np.nanmax(d)
    span = (hi - lo) or abs(hi) or 1.0
    ax.set_ylim(lo - margin_frac * span, hi + margin_frac * span)


def fixed_yticks(ax, ticks: Sequence[float]) -> None:
    """Pin y-ticks exactly (house style uses FixedLocator, not auto-ticking)."""
    ax.yaxis.set_major_locator(FixedLocator(list(ticks)))
