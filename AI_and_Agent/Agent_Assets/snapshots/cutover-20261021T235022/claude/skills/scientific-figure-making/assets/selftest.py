#!/usr/bin/env python
"""Self-test for pubfig.py. Doubles as a runnable example.

    python selftest.py [outdir]

Exercises every plot helper (writes real figures) and every assertion in BOTH
directions — the clean case must pass, the broken case must raise.
"""

import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pubfig import *  # noqa: E402
from pubfig import PALETTE_FAMILIES, tighten_ylim  # noqa: E402

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "pubfig_selftest")
FAILS = []


def expect_raises(what, fn):
    try:
        fn()
    except AssertionError as e:
        print(f"  ok   {what} raised: {str(e)[:80]}...")
        return
    except ValueError as e:
        print(f"  ok   {what} raised: {str(e)[:80]}...")
        return
    FAILS.append(what)
    print(f"  FAIL {what} did NOT raise")


def expect_ok(what, fn):
    try:
        fn()
        print(f"  ok   {what}")
    except Exception as e:  # noqa: BLE001
        FAILS.append(f"{what}: {e}")
        print(f"  FAIL {what}: {e}")


print("== colour discipline ==")

# Two panels, different meanings -> must be disjoint.
expect_ok(
    "disjoint families pass",
    lambda: assert_no_palette_collision(
        {
            "top: construct segment": PALETTE_FAMILIES["cool"][:3],
            "bottom: sample": PALETTE_FAMILIES["warm"][:3],
        }
    ),
)
expect_raises(
    "exact collision caught",
    lambda: assert_no_palette_collision(
        {
            "top: construct segment": ["#1f77b4", "#ff7f0e", "#2ca02c"],
            "bottom: sample": ["#1f77b4", "#ff7f0e", "#2ca02c"],  # default cycle reused
        }
    ),
)
expect_raises(
    "near-collision caught",
    lambda: assert_no_palette_collision(
        {"a: region": ["#0F4D92"], "b: timepoint": ["#104E93"]}
    ),
)

# Two panels, same meaning -> must be identical.
shared = {"CTRL": PALETTE["neutral"], "TEST": PALETTE["blue_main"]}
expect_ok(
    "identical maps pass",
    lambda: assert_shared_palette({"panel A": shared, "panel B": dict(shared)}),
)
expect_raises(
    "recoloured level caught",
    lambda: assert_shared_palette(
        {"panel A": shared, "panel B": {"CTRL": PALETTE["neutral"], "TEST": PALETTE["red_strong"]}}
    ),
)

# White-background legibility.
expect_ok("cyan/magenta pass", lambda: assert_visible_on_white([PALETTE["cyan"], PALETTE["magenta"]]))
expect_raises("pale yellow caught", lambda: assert_visible_on_white(["#FFFF33"], role="marker"))
expect_ok("pale fill allowed behind an edge", lambda: assert_visible_on_white([PALETTE["green_2"]], role="fill"))

# Large fills must not be near-black (heavy, ugly blot in print and on slides).
expect_ok("grey ramp passes", lambda: assert_fill_not_near_black(PALETTE_FAMILIES["grey"]))
expect_raises("near-black fill caught", lambda: assert_fill_not_near_black([PALETTE["ink"]]))
expect_ok("dark saturated colour still allowed",
          lambda: assert_fill_not_near_black([PALETTE["blue_main"]]))

# Text is never yellow — the check is on hue, so dark yellows fail too.
expect_raises("pale yellow text caught", lambda: assert_no_yellow_text(["#FFFF33"]))
expect_raises("gold text caught", lambda: assert_no_yellow_text([PALETTE["highlight"]]))
expect_raises("DARK goldenrod text caught (contrast alone would pass)",
              lambda: assert_no_yellow_text(["#B8860B"]))
expect_ok("orange/green/black text allowed",
          lambda: assert_no_yellow_text(["#F58518", PALETTE["green_3"], "#000000"]))
print(f"  contrast_vs_white('#B8860B') = {contrast_vs_white('#B8860B'):.2f} "
      f"(passes contrast, still rejected as yellow)")

print(f"  contrast_vs_white('#FFFF33') = {contrast_vs_white('#FFFF33'):.2f}")
print(f"  contrast_vs_white('{PALETTE['green_3']}') = {contrast_vs_white(PALETTE['green_3']):.2f}")

print("\n== figures ==")
apply_publication_style(FigureStyle(font_size=16, axes_linewidth=2.5))

# 1. Grouped bars, annotated, tightened y-limits.
fig, ax = plt.subplots(figsize=(10, 5))
cats = ["Metric A", "Metric B", "Metric C", "Metric D"]
series = [[0.92, 0.88, 0.85, 0.90], [0.85, 0.82, 0.88, 0.84], [0.78, 0.80, 0.82, 0.79]]
colors = [PALETTE["blue_main"], PALETTE["green_3"], PALETTE["red_strong"]]
make_grouped_bar(ax, cats, series, ["Ours", "Baseline X", "Baseline Y"],
                 ylabel="Score", colors=colors, annotate=True)
tighten_ylim(ax, np.array(series))
legend_outside(ax, ncol=3)
paths = finalize_figure(fig, OUT / "bars", formats=["png"], dpi=150)
print(f"  ok   grouped bar -> {paths[0]}")

# 2. Two-panel figure whose panels mean different things: enforce disjoint colours.
top_colors = PALETTE_FAMILIES["cool"][:2]      # segment type
bottom_colors = PALETTE_FAMILIES["warm"][:3]   # samples
assert_no_palette_collision({"top: segment": top_colors, "bottom: sample": bottom_colors})
fig, axes = create_subplots(2, 1, figsize=(9, 7))
x = np.linspace(0, 10, 60)
make_trend(axes[0], x, [np.sin(x) + 2, np.cos(x) + 2], ["mouse flank", "human insert"],
           colors=top_colors, ylabel="Coverage", xlabel="Position (bp)")
legend_outside(axes[0], ncol=2, title="segment type")
make_grouped_bar(axes[1], ["J1", "J2"], [[10, 12], [8, 14], [11, 9]],
                 ["TG_MTTH", "TG_RAGH", "TG_CD1A"], ylabel="Reads", colors=bottom_colors)
legend_outside(axes[1], ncol=3, title="sample (colours unrelated to panel above)")
paths = finalize_figure(fig, OUT / "two_panel_disjoint", formats=["png"], dpi=150)
print(f"  ok   2-panel disjoint -> {paths[0]}")

# 3. Heatmap.
fig, ax = plt.subplots(figsize=(7, 5))
rng = np.random.default_rng(42)
m = rng.random((5, 5))
m = (m + m.T) / 2
make_heatmap(ax, m, x_labels=[f"F{i+1}" for i in range(5)],
             y_labels=[f"F{i+1}" for i in range(5)], cbar_label="Correlation", annotate=True)
paths = finalize_figure(fig, OUT / "heatmap", formats=["png"], dpi=150)
print(f"  ok   heatmap -> {paths[0]}")

# 4. Scatter + point count assertion (the silent-drop guard).
fig, ax = plt.subplots(figsize=(6, 5))
xs, ys = rng.normal(size=37), rng.normal(size=37)
make_scatter(ax, xs, ys, label="samples", color=PALETTE["blue_main"])
expect_ok("37/37 points drawn", lambda: assert_points_drawn(ax, 37))
expect_raises("undercount caught", lambda: assert_points_drawn(ax, 40))
legend_outside(ax)
paths = finalize_figure(fig, OUT / "scatter", formats=["png"], dpi=150)
print(f"  ok   scatter -> {paths[0]}")

# 5. Composition as a ranked bar, not a pie — 26% vs 29% is unreadable as angles.
fig, ax = plt.subplots(figsize=(7, 4))
composition_bar_instead_of_pie(
    ax, ["mapped", "unmapped", "duplicate", "low MAPQ"], [29, 26, 25, 20])
paths = finalize_figure(fig, OUT / "composition_bar", formats=["png"], dpi=150)
print(f"  ok   composition bar (pie replacement) -> {paths[0]}")

# 6. Guards on misuse.
print("\n== guards ==")
expect_raises("loc='best' rejected", lambda: legend_outside(plt.subplots()[1], loc="best"))
expect_raises("bad format rejected",
              lambda: finalize_figure(plt.subplots()[0], OUT / "x", formats=["gif"]))
expect_raises("series length mismatch",
              lambda: make_grouped_bar(plt.subplots()[1], ["A", "B"], [[1, 2, 3]], ["s"]))
expect_raises("pale line colour rejected in make_trend",
              lambda: make_trend(plt.subplots()[1], [0, 1], [[0, 1]], ["s"], colors=["#FFFF33"]))
plt.close("all")

# 7. 2026-09-12 吸收自 figure-style 的三条 —— 每条都必须两个方向都对：
#    干净的图不许报（否则闸门误报率高，早晚被关掉），做坏的图必须报。
print("\n== figure-style 吸收的三条（种子错误注入）==")

# 7a. 标注上限 §2.2
fig, ax = plt.subplots()
ax.set_title("clean"); ax.set_xlabel("x"); ax.set_ylabel("y")
ax.plot([0, 1], [0, 1], label="s"); legend_outside(ax)
for i in range(4):                                    # 4 条叙述性标注，未超
    ax.text(0.2 + 0.1 * i, 0.5, f"n={i}")
try:
    assert_label_ceiling(ax)
    print("  ok   label ceiling: 4 annotations + axes/ticks/legend pass")
except AssertionError as e:
    FAILS.append("label ceiling false positive"); print(f"  FAIL false positive: {e}")
for i in range(4):                                    # 再加 4 条 ⇒ 8 条，超
    ax.text(0.2 + 0.1 * i, 0.7, f"extra{i}")
expect_raises("label ceiling: 8 annotations", lambda: assert_label_ceiling(ax))
plt.close("all")

# 7b. log 轴填充柱 §3.3
fig, ax = plt.subplots()
ax.bar(["a", "b", "c"], [3, 5, 9])                    # 线性轴上的柱子：正常
try:
    assert_no_filled_bars_on_log_axis(ax)
    print("  ok   bars on a linear axis pass")
except AssertionError as e:
    FAILS.append("log-bar false positive"); print(f"  FAIL false positive: {e}")
ax.set_yscale("log")
expect_raises("filled bars on log axis", lambda: assert_no_filled_bars_on_log_axis(ax))
plt.close("all")

# 7c. 断轴缺口内不得画东西 §3.2
fig, ax = plt.subplots()
ax.plot([0, 1], [1, 2])
ax.axhline(8.0, color="k")                            # 参考线在缺口之外：正常
try:
    assert_nothing_in_axis_break(ax, (3.0, 6.0), axis="y")
    print("  ok   reference line outside the break passes")
except AssertionError as e:
    FAILS.append("axis-break false positive"); print(f"  FAIL false positive: {e}")
ax.axhline(4.5, color="r")                            # 画进缺口里
ax.text(0.5, 5.0, "threshold")
expect_raises("line+text inside the axis break",
              lambda: assert_nothing_in_axis_break(ax, (3.0, 6.0), axis="y"))
plt.close("all")

# 7d. 渲染后几何检查 §9.1 —— 假阳性这一侧比真阳性更重要
fig, ax = plt.subplots(figsize=(6, 4))
ax.plot([0, 1, 2], [1, 3, 2]); ax.set_xlabel("x"); ax.set_ylabel("y")
ax.set_title("clean panel")
fig.tight_layout()
try:
    assert_no_text_collisions(fig)
    print("  ok   clean figure: no collisions (tick labels on their own spine not flagged)")
except AssertionError as e:
    FAILS.append("collision false positive"); print(f"  FAIL false positive: {e}")
ax.text(0.5, 0.5, "AAAAAAAAAAAAAAAAAAAA", transform=ax.transAxes, fontsize=28)
ax.text(0.5, 0.5, "BBBBBBBBBBBBBBBBBBBB", transform=ax.transAxes, fontsize=28)
expect_raises("two texts stacked on the same point",
              lambda: assert_no_text_collisions(fig))

# 7e. panel_crops 只是工具，不是断言 —— 验它返回每个 panel 一个框
fig2, axes = plt.subplots(1, 3, figsize=(9, 3))
for a in axes:
    a.plot([0, 1], [0, 1])
crops = panel_crops(fig2)
if len(crops) == 3 and all(len(v) == 4 and v[2] > v[0] and v[3] > v[1] for v in crops.values()):
    print(f"  ok   panel_crops returned {len(crops)} usable boxes")
else:
    FAILS.append("panel_crops"); print(f"  FAIL panel_crops returned {crops}")
plt.close("all")

print()
if FAILS:
    print(f"SELFTEST FAILED ({len(FAILS)}): " + "; ".join(FAILS))
    sys.exit(1)
print(f"SELFTEST PASSED — figures in {OUT.resolve()}")
