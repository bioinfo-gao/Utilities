#!/usr/bin/env python3
"""palette_priority.py —— 全局配色优先级的**可执行实现**（Python 版）。

**与 R 版 `../../R/color_figures_with_preconfigured_sets/palette_priority.R` 是同一套规则、
同一批颜色、同样的函数名**，两边必须保持一致；改了一边就要改另一边。
（唯一的语法差异：R 的 `from=` 参数在 Python 里叫 `from_levels=` —— `from` 是关键字。）

用户设定的全局优先级（在单张图另有明确指定时，以那个指定为准；本文件只管"没有
单独指定时该拿哪一套"）：

  第 1 优先  **Default_A** —— stock Set3 那套（蓝侧翼 / 淡紫珊瑚黄柱子 / 酒红深青绿接头线）
             user directive 2026-08-05：「这套配色作为 Default_A，作为选择配色的第一优先」
  第 2 优先  **Default_B** —— 灰侧翼那套（原来的 DEFAULT，2026-08-05 已批准并冻结成图）
  第 3 优先  ColorBrewer 成熟色板 + 我们的改造
             https://r-graph-gallery.com/38-rcolorbrewers-palettes.html
             · 色块 -> set3_with_grey()（Set3 的蓝 #80B1D3 换成中灰 #999999）
             · 线条/文字 -> STROKE_COLORS 六色，用完再取 diverging 两端
  第 4 优先  /home/gao/Utilities/color_and_format/python/color_figures/
             里手工调出来的那套（cyan/magenta 降饱和、深橙深紫降饱和、olive）
  第 5 优先  /home/gao/Utilities/color_and_format/python/grey_figures/
             里的黑白灰（#ABABAB -> #828282 -> #5A5A5A，浅到深、止于中灰）

**什么时候用 B —— 只有两种情况**（user directive 2026-08-05，取代之前那条
"每组 >=4 根柱子就退 B" 的自动降级规则，那是 agent 自己加的判断，已作废）：
  1. **用户明确说要 B**；
  2. **A 的颜色不够用**，需要从 B 补充剩下的那几个。
除此之外 **永远第一优先用 Default_A**，不因为"柱子多""可分度紧"之类理由自动退。
（A 的样本色内部最紧 0.127、B 是 0.149，这个数字仍然如实记录在下面，
  但它只是**参考信息**，不再触发任何自动降级。）

**两个层面用法不同，别混：**
  · **整张图要一套完整配色** -> 直接用 `DEFAULT_A_*` 常量。
    要 n 个柱子色而 A 的 6 个不够 -> `sample_fills(n)`：先把 A 的取完，再从 B 补。
  · **只要 n 个任意填充色** -> `fills_by_priority(n)`，按 A -> B -> 3 -> 4 -> 5 逐级取，
    并把每个颜色实际来自哪一级**打印出来**。

**想一眼看全每一级都有哪些颜色**：
    python palette_priority.py            # 打印全量清单
    python palette_priority.py --swatch   # 另存色卡 PNG/PDF，直接用眼睛看
"""

from __future__ import annotations

import sys
from itertools import combinations
from pathlib import Path
from typing import Iterable, NamedTuple, Sequence

SKILL = Path("/home/gao/.claude/skills/scientific-figure-making/assets")
sys.path.insert(0, str(SKILL))
from pubfig import (  # noqa: E402
    STROKE_COLORS,
    _rgb_distance,
    brewer,
    contrast_vs_white,
    set3_with_grey,
)

# ---------------------------------------------------------------------------
# 通用候选池（第 3-5 级）
# ---------------------------------------------------------------------------
# 第 1、2 级不是"池"而是两套**完整配色** Default_A / Default_B，定义在下面；
# 它们的填充色也会被 fills_by_priority() 当作前两级候选池（DEFAULT_A_FILLS /
# DEFAULT_B_FILLS）。用户点名的淡蓝 #80B1D3 就是 Default_A 的侧翼色，不单列
# "优先色"常量 —— 同一个事实只存一处。

# 第 3 级：Set3(改) 的 12 个低饱和色 —— 天生为大色块设计。
TIER1_FILLS: list[str] = set3_with_grey()
# 第 4 级：手调全彩（../color_figures/plot_junction_structure.py 里的 SAMPLE_FILLS）。
#          都是"线条色降饱和"得来的填充色，不是随手写的十六进制。
TIER2_FILLS: list[str] = [
    "#73C6CF",  # cyan  #17BECF  S x 0.50
    "#C75C9F",  # magenta #C71585 S x 0.60
    "#E9A6A1",  # pink (= PALETTE red_2)
    "#B87542",  # 深橙 #D95F02 S x 0.65 V x 0.85
    "#70487E",  # 深紫 #7B3294 S x 0.65 V x 0.85
    "#6B6B2F",  # olive
]
# 第 5 级：黑白灰（../grey_figures/）。浅 -> 深，止于中灰。
TIER3_FILLS: list[str] = ["#ABABAB", "#828282", "#5A5A5A"]

# 取色结果里每个颜色标注来自哪一级。A/B 是两套完整配色，3/4/5 是通用候选池。
TIER_SOURCE: dict[str, str] = {
    "A": "Default_A  [stock Set3：蓝侧翼那套，第 1 优先]",
    "B": "Default_B  [灰侧翼那套，第 2 优先]",
    "3": "ColorBrewer set3_with_grey()  [r-graph-gallery #38 + 我们的改造]",
    "4": "手调全彩  [python/color_figures/]",
    "5": "黑白灰    [python/grey_figures/]",
}
PRIORITY_LEVELS: tuple[str, ...] = tuple(TIER_SOURCE)

# 线条/文字的通用优先级同理：先 STROKE_COLORS（黑->正红->亮蓝->深绿->咖啡->深紫），
# 再手调的 magenta/cyan，最后黑与深灰。颜色不够用时文字一律黑色。
# （成套用时直接取 DEFAULT_A_JUNC_STROKES / DEFAULT_B_JUNC_STROKES。）
TIER1_STROKES: list[str] = list(STROKE_COLORS)
TIER2_STROKES: list[str] = ["#C71585", "#17BECF"]
TIER3_STROKES: list[str] = ["#000000", "#4D4D4D"]

# ---------------------------------------------------------------------------
# Default_B —— **第 2 优先**：灰侧翼那套 (user directive 2026-08-05)
# ---------------------------------------------------------------------------
# 就是 2026-08-05 那一轮验证图用的颜色，用户看过并明确认可（当时叫 DEFAULT_*，
# 用户后来把 stock Set3 那套定为 Default_A 之后，这套改名 Default_B、降为第 2 优先）。
# 已冻结成图的产物一律沿用它，不要因为 A 升为第 1 优先就去重出旧图。
#
# **什么时候动它 —— 只有两种情况**：用户明确要 B；或 A 的颜色不够用要补充。
# **不存在"因为可分度紧所以自动退到 B"这回事**（那条规则 2026-08-05 已被用户废止）。
# 参考数字：B 的样本色内部最紧 0.149，A 是 0.127。
DEFAULT_B_SEG_FILLS: dict[str, str] = {
    "mouse genomic flank": TIER1_FILLS[4],            # #999999 中灰
    "homology arm (mouse sequence)": TIER1_FILLS[5],  # #FDB462 橙
    "human insert": TIER1_FILLS[6],                   # #B3DE69 绿
}
# 6 个样本的柱子色：通用池第 3 级 3 个 + 第 4 级 3 个（第 5 级未动用）。
DEFAULT_B_SAMPLE_FILLS: list[str] = [
    "#8DD3C7",  # 3 级 Set3 teal
    "#FB8072",  # 3 级 Set3 salmon
    "#FFED6F",  # 3 级 Set3 yellow
    "#C75C9F",  # 4 级 magenta 降饱和
    "#E9A6A1",  # 4 级 pink
    "#B87542",  # 4 级 深橙降饱和
]
DEFAULT_B_JUNC_STROKES: dict[str, str] = {
    "J2": TIER1_STROKES[1],  # #E41A1C 正红，实线
    "J1": TIER1_STROKES[2],  # #1F78B4 亮蓝，虚线
}
# 作为候选池时的取色顺序：先柱子色（要 n 个色多半是给 n 个分类上色），再区段色。
DEFAULT_B_FILLS: list[str] = DEFAULT_B_SAMPLE_FILLS + list(DEFAULT_B_SEG_FILLS.values())

# 分组底纹。**两套共用**，不属于 A 或 B —— 任何取色都要把它当"背景色"排除。
DEFAULT_SHADE = "#F2F2F2"

# ---------------------------------------------------------------------------
# Default_A —— **第 1 优先**：stock Set3 那套 (user directive 2026-08-05)
# ---------------------------------------------------------------------------
# 用户原话：「这个截图里的配色完美，对人类阅读者是好极了。实际上我更加喜欢。」
# 随后明确：「这套配色作为 Default_A，作为选择配色的第一优先。」
# 内容 = set3_with_grey() 生效**之前**那一版：区段用 stock Set3 的蓝/橙/绿，
# 柱子用淡紫/珊瑚/黄，接头线用 diverging 色板的深端。
#
# **新图默认从这里取。** 与 Default_B 并存，谁也不覆盖谁：产物在 `Alternative/`
# 子文件夹，文件名与第一层同名但互不覆盖；第一层与 `Advanced/` 那批已冻结的图
# 仍是 Default_B，**不因 A 升为第 1 优先而重出**。
#
# 实测数字（都过 assert_no_palette_collision 的 0.10 门槛，但低于并排柱子用的 0.13）：
#   · 蓝侧翼 #80B1D3 vs 淡紫柱 #BEBADA = 0.118
#   · 样本色内部最紧（#BEBADA vs #FCCDE5）= 0.127
# 这两个数字**只是如实记录，不触发任何自动降级**。柱子多到 A 的 6 个不够时，
# 用 sample_fills(n) 从 B 补后面几个 —— 补充，不是替换。
# 另注意 teal #8DD3C7 不在这套里 —— 它与 #80B1D3 只差 0.096，天然互斥。
_S3_STOCK: list[str] = [c.upper() for c in brewer("Set3")]
DEFAULT_A_SEG_FILLS: dict[str, str] = {
    "mouse genomic flank": _S3_STOCK[4],            # #80B1D3 淡蓝
    "homology arm (mouse sequence)": _S3_STOCK[5],  # #FDB462 橙
    "human insert": _S3_STOCK[6],                   # #B3DE69 绿
}
# 柱子：跳过 #FFFFB3（对白底 1.04，太浅）与 teal（撞蓝侧翼），取淡紫/珊瑚/黄，再接粉/紫/浅绿。
DEFAULT_A_SAMPLE_FILLS: list[str] = [_S3_STOCK[i] for i in (2, 3, 11, 7, 9, 10)]
# 接头线条/文字：diverging 色板的**深端** —— 深色饱和，正是细线与小字需要的。
DEFAULT_A_JUNC_STROKES: dict[str, str] = {
    "J2": brewer("PiYG", 2)[0].upper(),  # #8E0152 酒红，实线
    "J1": brewer("BrBG", 2)[1].upper(),  # #003C30 深青绿，虚线
}
DEFAULT_A_FILLS: list[str] = DEFAULT_A_SAMPLE_FILLS + list(DEFAULT_A_SEG_FILLS.values())


class PaletteResult(NamedTuple):
    """取色结果：颜色 + 每色来自哪一级 + 两两最小距离。"""

    colors: list[str]
    tiers: list[str]
    min_pairwise: float | None

    def __iter__(self):          # 让 `for c in result` 直接拿到颜色
        return iter(self.colors)

    def __len__(self):
        return len(self.colors)

    def __getitem__(self, i):
        return self.colors[i]


def _pick(pools: dict[str, Sequence[str]], levels: Sequence[str], n: int,
          exclude: Iterable[str], min_distance: float) -> PaletteResult:
    """逐级取色的公共实现（fills_by_priority 与 sample_fills 共用）。"""
    exclude = list(exclude)
    chosen: list[str] = []
    tiers: list[str] = []

    def ok_vs(col: str, others: Sequence[str]) -> bool:
        return all(_rgb_distance(col, o) >= min_distance for o in others)

    for lvl in levels:
        for col in pools[lvl]:
            if len(chosen) >= n:
                break
            cr = contrast_vs_white(col)
            if cr < 1.1 or cr > 10:          # 太浅 / 近黑
                continue
            if col in chosen:
                continue
            if not ok_vs(col, exclude):      # 撞别的 panel 或底纹
                continue
            if not ok_vs(col, chosen):       # 自己人之间也要分得开
                continue
            chosen.append(col)
            tiers.append(lvl)
        if len(chosen) >= n:
            break
    if len(chosen) < n:
        raise ValueError(
            f"第 {'/'.join(levels)} 级候选池加起来只凑出 {len(chosen)} 个可用填充色，"
            f"要 {n} 个。放宽 min_distance（当前 {min_distance:.2f}）或减少分组，"
            f"不要自己发明颜色。")
    d = min((_rgb_distance(a, b) for a, b in combinations(chosen, 2)), default=None)
    return PaletteResult(chosen, tiers, d)


def fills_by_priority(n: int, exclude: Iterable[str] = (), min_distance: float = 0.13,
                      from_levels: Sequence[str] = PRIORITY_LEVELS) -> PaletteResult:
    """按全局优先级挑 n 个**填充色**。

    逐级取色（A -> B -> 3 -> 4 -> 5），级内按该套/该池自身顺序；每个候选必须同时满足：
      · 白底可读（contrast >= 1.1，填充档阈值）—— 剔掉 Set3 的 #FFFFB3（1.04）
      · 不近黑（contrast <= 10）—— 大面积近黑是审美硬伤
      · 与 `exclude` 中每一个颜色距离 >= min_distance（语义不同的面板不得撞色）
      · 与**已选中**的颜色距离 >= min_distance（六根柱子挨在一起要分得开）
    只有当前级取不满 n 个，才向下一级要 —— 这就是"优先级"的全部含义。

    :param exclude: 必须避开的颜色：别的 panel 的色块 + 图上的底纹/背景色。
        **底纹一定要放进来**：J1 分组的 #F2F2F2 底纹与 Set3 的 #D9D9D9 只差 0.098，
        不排除就会出现"柱子和底纹分不开"的图。
    :param min_distance: 距离下限。0.10 是 assert_no_palette_collision() 的默认门槛；
        同一组里并排 6 根柱子要求更高一点，这里默认 0.13。
    :param from_levels: 用哪几级、按什么顺序（对应 R 版的 `from=`）。
        **新图一律用默认值**。显式指定只有一个用途：**复现某套配色定下时的候选池**。
        例如 Default_B 那批已冻结的图传 `("3", "4", "5")` —— 它们的颜色是在 Default_A
        进入优先级之前、直接从通用池里搜出来的；把 A 放进来会把第 1 色 teal #8DD3C7
        换成蓝 #80B1D3（两者相距 0.096 无法共存），那是要用户点头的改动，
        不能在重跑旧脚本时静默发生。
    """
    bad = set(from_levels) - set(PRIORITY_LEVELS)
    if bad:
        raise ValueError(f"未知的优先级: {sorted(bad)}（可用: {list(PRIORITY_LEVELS)}）")
    pools = {"A": DEFAULT_A_FILLS, "B": DEFAULT_B_FILLS,
             "3": TIER1_FILLS, "4": TIER2_FILLS, "5": TIER3_FILLS}
    return _pick(pools, list(from_levels), n, exclude, min_distance)


# 各级"柱子/分类"用的色序。A 排在最前，B 只用来**补 A 之后不够的那几个**。
SAMPLE_FILLS_BY_LEVEL: dict[str, list[str]] = {
    "A": DEFAULT_A_SAMPLE_FILLS,
    "B": DEFAULT_B_SAMPLE_FILLS,
    "3": TIER1_FILLS,
    "4": TIER2_FILLS,
    "5": TIER3_FILLS,
}


def sample_fills(n: int, exclude: Iterable[str] = (), min_distance: float = 0.10,
                 force_level: str | None = None) -> PaletteResult:
    """要 n 个**柱子/分类**色：先把 Default_A 的取完，不够再从 Default_B 补，还不够往下走。

    这就是用户定的规则的直接实现（2026-08-05）：
    **永远第一优先 A；B 只在"用户点名"或"A 不够用"时出现。**

    :param min_distance: 默认 **0.10** —— 就是 assert_no_palette_collision() 的门槛，
        也是 Default_A 这套配色当初被验证时用的那个。**不能在这里用更严的 0.13**：
        A 的淡紫柱 #BEBADA 距 A 的蓝侧翼 #80B1D3 是 0.118、距粉 #FCCDE5 是 0.127，
        门槛设 0.13 会把 A 自己的一半颜色筛掉、悄悄换成 B 的 —— 那正是用户 2026-08-05
        废止的那种自动降级。要更严的可分度，显式传 min_distance。
    :param force_level: 只用某一级（例如用户点名要 B 就传 "B"）。默认按优先级走。
    """
    levels = list(PRIORITY_LEVELS) if force_level is None else [force_level]
    bad = set(levels) - set(SAMPLE_FILLS_BY_LEVEL)
    if bad:
        raise ValueError(f"未知的级别: {sorted(bad)}")
    return _pick(SAMPLE_FILLS_BY_LEVEL, levels, n, exclude, min_distance)


def palette_report(res: PaletteResult, label: str = "fills") -> None:
    """把取色结果打成一张表 —— 这就是"优先级是否生效"的验证输出。"""
    mp = "—" if res.min_pairwise is None else f"{res.min_pairwise:.3f}"
    print(f"\n[配色优先级验证] {label} —— 共 {len(res.colors)} 色，级内最小两两距离 {mp}")
    print(f"  {'i':>2}  {'colour':<9} {'级':<3} {'对比度':>6}  来源")
    for i, (c, t) in enumerate(zip(res.colors, res.tiers), 1):
        print(f"  {i:>2}  {c:<9} {t:<3} {contrast_vs_white(c):>6.2f}  {TIER_SOURCE[t]}")
    used = sorted(set(res.tiers), key=PRIORITY_LEVELS.index)
    unused = [t for t in PRIORITY_LEVELS if t not in used]
    print(f"  -> 实际动用的级别: {' + '.join('第' + t + '级' for t in used)}；"
          f"第 {'/'.join(unused) or '—'} 级未动用")


# ---------------------------------------------------------------------------
# 全量清单：打印 + 色卡
# ---------------------------------------------------------------------------
def _levels_table() -> list[tuple[str, dict[str, str] | None, list[str], list[str]]]:
    """(级别, 区段色 or None, 柱子色, 线条色) —— 打印与画色卡共用同一份数据。"""
    seg = {"A": DEFAULT_A_SEG_FILLS, "B": DEFAULT_B_SEG_FILLS}
    strokes = {"A": list(DEFAULT_A_JUNC_STROKES.values()),
               "B": list(DEFAULT_B_JUNC_STROKES.values()),
               "3": TIER1_STROKES, "4": TIER2_STROKES, "5": TIER3_STROKES}
    return [(t, seg.get(t), SAMPLE_FILLS_BY_LEVEL[t], strokes[t]) for t in PRIORITY_LEVELS]


def print_palette_levels() -> None:
    """一屏打印**每一级的全部颜色** —— 想一眼看清有哪些色就跑这个。"""
    def line(cols):
        return "  ".join(f"{c}({contrast_vs_white(c):.2f})" for c in cols)

    print("\n================ 配色优先级全量清单 ================")
    print("规则：永远第一优先 Default_A；B 只在【用户点名】或【A 不够用要补充】时出现。")
    for lvl, seg, samp, strokes in _levels_table():
        print(f"\n---- 第 {lvl} 级：{TIER_SOURCE[lvl]} ----")
        if seg:
            print("  区段/结构 (3):")
            for role, col in seg.items():
                print(f"    {role:<32} {col} (对比度 {contrast_vs_white(col):.2f})")
        print(f"  柱子/分类 ({len(samp)}):\n    {line(samp)}")
        print(f"  线条/文字 ({len(strokes)}):\n    {line(strokes)}")
    print("\n括号内是对白底 WCAG 对比度：填充需 >= 1.1，线条/文字需 >= 1.5，填充不得 > 10（近黑）。")
    print("====================================================")


def save_palette_swatch(out_stem: str | Path | None = None) -> list[str]:
    """把每一级的每个颜色画成**色卡**存盘 —— 数字看不出美丑，这个可以用眼睛看。

    每行一个"级别 × 角色"，格子里写十六进制与白底对比度；
    低于阈值的格子（填充 <1.1、线条 <1.5）在右上角标 ✗，一眼看得出为什么会被自动剔除。
    """
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.patches import Rectangle

    if out_stem is None:
        out_stem = Path(__file__).resolve().parent / "palette_levels_swatch"
    out_stem = Path(out_stem)

    # matplotlib 默认字体没有汉字，中文会渲染成方框。本机有 Noto Sans CJK JP
    # （含完整汉字），显式指定；万一将来这台机器没有，回退到 DejaVu 至少不崩。
    for fam in ("Noto Sans CJK JP", "Noto Serif CJK JP", "DejaVu Sans"):
        if any(f.name == fam for f in matplotlib.font_manager.fontManager.ttflist):
            plt.rcParams["font.sans-serif"] = [fam, "DejaVu Sans"]
            plt.rcParams["axes.unicode_minus"] = False
            break

    # (行标题, 颜色, 该角色的下限, 是否受"近黑上限"约束)
    # **近黑 >10 只对填充是硬伤**（大面积墨块），线条越深越好 —— 黑色 21.00 是首选笔画色。
    rows: list[tuple[str, list[str], float, bool]] = []
    for lvl, seg, samp, strokes in _levels_table():
        tag = {"A": "第1优先 Default_A", "B": "第2优先 Default_B"}.get(lvl, f"第{lvl}级")
        if seg:
            rows.append((f"{tag}  区段/结构（填充）", list(seg.values()), 1.1, True))
        rows.append((f"{tag}  柱子/分类（填充）", list(samp), 1.1, True))
        rows.append((f"{tag}  线条/文字", list(strokes), 1.5, False))

    ncol = max(len(c) for _, c, _, _ in rows)
    fig, ax = plt.subplots(figsize=(1.35 * ncol + 4.4, 0.82 * len(rows) + 1.6))
    for r, (title, cols, thr, cap_near_black) in enumerate(rows):
        y = len(rows) - r - 1
        ax.text(-0.15, y + 0.5, title, ha="right", va="center", fontsize=9.5)
        for c, col in enumerate(cols):
            cr = contrast_vs_white(col)
            ax.add_patch(Rectangle((c, y), 0.94, 0.9, facecolor=col,
                                   edgecolor="black", linewidth=0.6))
            # 深色格子上写黑字看不见 —— 文字颜色随底色明暗切换
            ink = "white" if cr > 4.5 else "black"
            ax.text(c + 0.47, y + 0.60, col, ha="center", va="center",
                    fontsize=7.6, family="monospace", color=ink)
            ax.text(c + 0.47, y + 0.26, f"{cr:.2f}", ha="center", va="center",
                    fontsize=7, color=ink)
            if cr < thr or (cap_near_black and cr > 10):
                # 用 ASCII 的 X，不要 ✗(U+2717) —— CJK 字体里没有该字形，会渲染成方框
                ax.text(c + 0.86, y + 0.78, "X", ha="center", va="center",
                        fontsize=11, color="#B00020", fontweight="bold")
    ax.set_xlim(-0.05, ncol)
    ax.set_ylim(-0.05, len(rows))
    ax.axis("off")
    ax.set_title("配色优先级色卡 —— 永远第一优先 Default_A；B 只在【用户点名】或【A 不够用】时补充\n"
                 "格内 = 十六进制 + 白底 WCAG 对比度　红 X = 该角色不可用"
                 "（填充需 ≥1.1 且 ≤10 不得近黑；线条/文字需 ≥1.5，越深越好不设上限）",
                 fontsize=10.5, pad=14)
    fig.tight_layout()
    paths = []
    for ext in ("png", "pdf"):
        p = f"{out_stem}.{ext}"
        fig.savefig(p, dpi=200, bbox_inches="tight", facecolor="white")
        paths.append(p)
    plt.close(fig)
    return paths


# ---------------------------------------------------------------------------
def check_default_b_palette_unchanged() -> None:
    """回归守卫：通用候选池现在是否仍然产出 Default_B 那套已冻结的样本色。

    import 本模块时自动跑一次。以后谁改了候选池或门槛，只要会动到已冻结的配色，
    这里立刻抛错，而不是让某张旧图重跑时静悄悄换一套颜色。
    真要改，就同时改 DEFAULT_B_SAMPLE_FILLS 并说明理由。
    """
    # from_levels=("3","4","5")：Default_B 的柱子色是在 Default_A 进入优先级**之前**、
    # 直接从通用池里搜出来的。把 A 放进来会把第 1 色 teal 换成蓝（0.096 无法共存）——
    # 那是要用户点头的改动。本守卫只负责盯住**通用池与门槛**有没有被悄悄改动。
    got = fills_by_priority(
        len(DEFAULT_B_SAMPLE_FILLS),
        exclude=list(DEFAULT_B_SEG_FILLS.values()) + [DEFAULT_SHADE, "#FFFFFF"],
        from_levels=("3", "4", "5"))
    if [c.upper() for c in got.colors] != [c.upper() for c in DEFAULT_B_SAMPLE_FILLS]:
        raise AssertionError(
            "通用候选池产出的样本色已偏离已冻结的 Default_B：\n"
            f"  现在  : {got.colors}\n  已冻结: {DEFAULT_B_SAMPLE_FILLS}\n"
            "候选池或门槛被改动了。要么改回去，要么同时更新 DEFAULT_B_SAMPLE_FILLS。")


check_default_b_palette_unchanged()


if __name__ == "__main__":
    print_palette_levels()
    if "--swatch" in sys.argv:
        for p in save_palette_swatch():
            print(f"[OK] 色卡 -> {p}")
