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

===========================================================================
**一目了然：色卡与全量色表见本 docstring 下方的注释块**（`# ` 开头那一段）。
色表刻意放在**注释**里而不是这个 docstring 里 —— 编辑器的行内颜色预览
（十六进制旁边那个小色块）通常只对注释生效，对长字符串字面量往往不渲染。
R 版的同一张表就在 `##` 注释里，两边保持一致。
===========================================================================
"""

# ===========================================================================
# **一目了然：色卡 PNG —— `palette_levels_swatch.png`（与本文件同目录）**
# ===========================================================================
# 五级 × 每级的每个颜色都画成色块，格内写十六进制与白底对比度，
# 不满足该角色阈值的格子标红 X。**打开那个 PNG 就能用眼睛看全部配色。**
#   重新生成： python palette_priority.py --swatch
#   只打印文字：python palette_priority.py        （或 print_palette_levels()）
#
# **本级不够就自动向下一级取**（只排除肉眼分不清的色，EYE_THRESHOLD = 0.10）：
#   面积 -> fills_by_priority(n) / sample_fills(n)　线状 -> strokes_by_priority(n)
#
# 五级全量色表（与色卡 PNG 同源，都出自本文件下面的常量）：
# **只分两类**：面积(区段/柱子，阈值 1.1-10 不得近黑) · 线状(线条/文字，阈值 >=1.5 无上限)。
# 面积一栏里 │ 左边 = 区段的固定语义映射，右边 = 柱子色序列；同图里这两段必须互不相交。
#
#   第1优先 Default_A  面积  #80B1D3 蓝  #FDB462 橙  #B3DE69 绿 │ #BEBADA  #FB8072  #FFED6F
#                            #FCCDE5  #BC80BD  #CCEBC5
#                      线状  #8E0152 酒红实线  #003C30 深青绿虚线  #0000CD blue3
#                            #8B4500 darkorange4  #9400D3 darkviolet
#
#   第2优先 Default_B  面积  #999999 中灰  #FDB462 橙  #B3DE69 绿 │ #8DD3C7  #FB8072  #FFED6F
#                            #C75C9F  #E9A6A1  #B87542
#                      线状  #E41A1C 正红实线  #1F78B4 亮蓝虚线  #0000CD blue3
#                            #CD5B45 coral3  #32CD32 limegreen
#
#   第3级 ColorBrewer  面积  #8DD3C7  #FFFFB3(X)  #BEBADA  #FB8072  #999999  #FDB462
#                            #B3DE69  #FCCDE5  #D9D9D9  #BC80BD  #CCEBC5  #FFED6F
#                      线状  #000000  #E41A1C  #1F78B4  #006D2C  #8C510A  #762A83
#
#   第4级 手调全彩     面积  #73C6CF  #C75C9F  #E9A6A1  #B87542  #70487E  #6B6B2F
#                      线状  #C71585  #17BECF  #0055E5
#
#   第5级 黑白灰       面积  #ABABAB  #828282  #5A5A5A
#                      线状  #000000  #4D4D4D
#
#   (X) = #FFFFB3 对白底对比度仅 1.04，低于面积阈值 1.1，**永远被自动剔除**。
#   分组底纹 #F2F2F2 两套共用，不属于任何一级；任何取色都要把它当背景色排除。
# ===========================================================================

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
# ============================================================================
# 点的配色 —— 四条基本原则 (user directive 2026-08-09，定稿)
#
# 线与块状图早已讨论清楚；2026-08-09 这一轮专门定"点"。
#
# **大点 vs 小点，判据 = 要不要考虑它的形状和面积：**
#   小点 = 一般不考虑形状与面积的点（默认小圆点）
#   大点 = 反之。**PCA 图一律认定为大点，哪怕没有加形状。**
#
# 1) 同一研究项目内，配色尽量保持一致或相似 —— 尤其**块状图与大点图之间要一致**。
# 2) 线与小点可视度极差 -> 用高饱和、醒目的颜色，**无需**与其他图保持一致。
#    注：用户原话"高亮度"指**醒目/鲜明**，不是 HCL 的高 L —— 白底上高 L = 浅 = 看不见；
#    实际线状族 #8E0152 / #003C30 / #0000CD 都是**暗**色。
# 3) 用户未明确时，块与大点按本文件的五级优先级取色（A -> B -> 3 -> 4 -> 5）。
# 4) 优先级也不明确时，面填充（含块与大点）优先取**饱和度低一些**的颜色。
#
# 原则 4 的实测校准（proj28 PCA_3 八方案逐张判定）—— "低饱和"不是越低越好：
#   Default_A 面积族原版      HCL C 中位 40，对白底 1.19-3.02  -> **不可用（太浅）**
#   Default_A 面积族加深 L-20 HCL C 中位 60，对白底 2.10-6.09  -> 定稿
#   Default_B 面积族(未改)    HCL C 中位 67，对白底 1.19-3.85  -> 好
#   Default_A 线状族          HCL C 中位 87，对白底 4.71-12.43 -> 定稿
#   => 面填充可用带 **C 约 60-70**；C 约 40 那一档实测不可用。
#   => 判别不能只看单色：方案3 与被否的方案1 最低对比度同为 1.19（同一个 #FFED6F），
#      差别在**簇内搭档**（1.19+3.85 vs 1.19+1.40）。**单个浅色不致命，同簇两色都浅才致命。**
#
# 定稿八套配色与实测：../../R/PCA_3/（色卡 + final_palettes.csv）
# ============================================================================

TIER2_FILLS: list[str] = [
    "#73C6CF",  # cyan  #17BECF  S x 0.50
    "#C75C9F",  # magenta #C71585 S x 0.60
    "#E9A6A1",  # pink (= PALETTE red_2)
    "#B87542",  # 深橙 #D95F02 S x 0.65 V x 0.85
    "#70487E",  # 深紫 #7B3294 S x 0.65 V x 0.85
    "#6B6B2F",  # olive
    # 2026-08-09 用户扩池（PCA_2 图8 位3）。**本级唯一的满饱和色**：本级性格是
    # "把亮色降饱和"（上面各条 S x 0.50-0.65），#CD00CD 是满饱和 magenta，属明确例外，
    # 不要据此认为本级可以放亮色。附在**队尾**，贪心取色先取前面各色，
    # 故已冻结的 Default_B 图件不受影响（由 check_default_b_palette_unchanged() 守卫）。
    "#CD00CD",  # magenta3 满饱和（例外）
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
# 第 4 级线条：第 3 位 #0055E5 是用户截图里**顶部标题栏**的蓝（逐像素采样所得，
# 见 R 版同名目录下的 Screenshot 2026-08-06 105131.png）。对白底 6.12，
# 距另两色 0.459/0.282，距第 4 级 6 个填充最小 0.314 —— 各项都过。
TIER2_STROKES: list[str] = ["#C71585", "#17BECF", "#0055E5"]
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
# 线条/文字（**五色，按优先序**）。前两个是 STROKE_COLORS 的正红与亮蓝；
# 第 3-5 个由用户 2026-08-06 指定，取自 NCEAS 配色速查表
# https://www.nceas.ucsb.edu/sites/default/files/2020-04/colorPaletteCheatsheet.pdf
# 的 R 颜色名 blue3 / coral3 / limegreen。
#
# **用 coral3 前必看（实测）**：它距 B 的三个【区段填充】最小 0.258（没问题，接头竖线
# 就画在区段上），但距【柱子填充】#B87542（深橙降饱和）只有 **0.079** —— 低于 0.10
# 撞色门槛。**coral3 的线绝不能画在 #B87542 的柱子上，会直接看不见。**
# 线一般不画在柱子上，所以留它在第 4 位；真要画时
# assert_strokes_visible_over_fills() 会当场拦下，不必靠记忆。
# 另：coral3 与第 1 位正红 #E41A1C 距离 0.198 —— 过门槛但同属红系，同图并用要留意。
# limegreen 对白底 2.12，刚过线条 1.5 门槛，**细线偏弱**；做粗线/标记没问题。
DEFAULT_B_STROKES: list[str] = [
    TIER1_STROKES[1],  # #E41A1C 正红   （J2 实线）
    TIER1_STROKES[2],  # #1F78B4 亮蓝   （J1 虚线）
    "#0000CD",         # blue3
    "#CD5B45",         # coral3     <- 见上面的 #B87542 警告
    "#32CD32",         # limegreen  <- 对白底仅 2.12
]
# 接头的角色映射只取前两个 —— 已冻结的图靠这两个色，扩充第 3-5 位不会动它们。
DEFAULT_B_JUNC_STROKES: dict[str, str] = {
    "J2": DEFAULT_B_STROKES[0],
    "J1": DEFAULT_B_STROKES[1],
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
# 线条/文字（**五色，按优先序**）。前两个是 diverging 色板的深端 —— 深色饱和，
# 正是细线与小字需要的；第 3-5 个由用户 2026-08-06 指定，取自 NCEAS 配色速查表
# https://www.nceas.ucsb.edu/sites/default/files/2020-04/colorPaletteCheatsheet.pdf
# 的 R 颜色名 blue3 / darkorange4 / darkviolet。
#
# 第 3 位 blue3 = 用户说的「截图里 Eclipse 窗口边框那个蓝」—— **这是实测结论，不是近似**：
# 用户把截图存到本目录 `Screenshot 2026-08-06 105131.png`，逐像素采样得到
# 左边框主体 #0221D2、右边框主体 #0044EA、顶部标题栏 #0055E5。
# **blue3 #0000CD 距左边框主体 #0221D2 只有 0.087 —— 低于 0.10 的撞色门槛**，
# 即我们自己的工具判定这两个色不可区分。用户原话「这两个蓝色我分不太清楚」，
# 原因就在这里。既然等价，就用有名字、可复现的 blue3。
# 另：顶部标题栏蓝 #0055E5 是**另一个**蓝（距 blue3 0.229，可区分），用户也喜欢，
# 需要时可追加为第 6 位（对白底 6.12，距 A 全部填充最小 0.340，各项检查都过）。
#
# 五色实测：对白底对比度 9.23 / 12.43 / 11.16 / 7.12 / 6.56（线条门槛 1.5，无上限）；
# 两两最小距离 0.257，优于 STROKE_COLORS 六色的 0.221 基准；无黄色文字。
DEFAULT_A_STROKES: list[str] = [
    brewer("PiYG", 2)[0].upper(),  # #8E0152 酒红   （J2 实线）
    brewer("BrBG", 2)[1].upper(),  # #003C30 深青绿 （J1 虚线）
    "#0000CD",                     # blue3
    "#8B4500",                     # darkorange4
    "#9400D3",                     # darkviolet
]
# 接头的角色映射只取前两个 —— 已冻结的图靠这两个色，扩充第 3-5 位不会动它们。
DEFAULT_A_JUNC_STROKES: dict[str, str] = {
    "J2": DEFAULT_A_STROKES[0],
    "J1": DEFAULT_A_STROKES[1],
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


# ---------------------------------------------------------------------------
# 基本原则：**本级不够就自动向下一级取**（user directive 2026-08-06）
# ---------------------------------------------------------------------------
# 面积色与线状色都适用：当前级取不满 n 个，就自动到下一级继续取，
# **只排除"肉眼分不清"的颜色**，不因为"有点像"就跳过。
#
# "肉眼分不清"这个门槛不是拍的，是本轮实测校准出来的：
#   用户看 blue3 #0000CD 与截图左边框 #0221D2（两者距离 **0.087**）时，
#   原话是「这两个蓝色我分不太清楚」。撞色断言 assert_no_palette_collision()
#   的默认门槛 0.10 正好压在这个经验值之上 —— 所以 EYE_THRESHOLD = 0.10。
#
# **注意这与"并排间距"是两件事，别混：**
#   · EYE_THRESHOLD 0.10 = "算不算重复" —— 跨级下取时的排除标准（本原则）。
#   · min_distance 0.13 = "并排够不够分得开" —— 同一组里 6 根柱子挨在一起时的
#     审美/可读性要求，比"不重复"更严。fills_by_priority() 的默认值就是它。
#     实测：把它放宽到 0.10，已冻结的 Default_B 六个柱子色会全部改变 —— 那是
#     另一个问题（并排可读性），不是本原则要解决的问题。
EYE_THRESHOLD = 0.10

STROKES_BY_LEVEL: dict[str, list[str]] = {
    "A": DEFAULT_A_STROKES,
    "B": DEFAULT_B_STROKES,
    "3": TIER1_STROKES,
    "4": TIER2_STROKES,
    "5": TIER3_STROKES,
}


def strokes_by_priority(n: int, exclude: Iterable[str] = (),
                        min_distance: float = EYE_THRESHOLD,
                        from_levels: Sequence[str] = PRIORITY_LEVELS) -> PaletteResult:
    """按全局优先级挑 n 个**线状色**（线条 / 文字）。

    与 fills_by_priority() 对称，只是候选池换成各级的线状色，且判据换成线状的：
    对白底对比度 >= 1.5（**不设上限** —— 线条越深越好，黑色 21.00 是首选笔画色）。
    逐级 A -> B -> 3 -> 4 -> 5，**本级不够自动下取**，排除标准是"肉眼分不清"
    （EYE_THRESHOLD = 0.10），不是更严的并排间距。

    :param exclude: 必须避开的颜色。**线条要压在色块上时，把那些色块填充放进来** ——
        一根线画在与它同色系的填充上会直接消失，这是 assert_strokes_visible_over_fills()
        要防的那种 bug（实例：J2 正红 #E41A1C 压在 #BD0026 上距离 0.102，线彻底看不见）。
    """
    bad = set(from_levels) - set(PRIORITY_LEVELS)
    if bad:
        raise ValueError(f"未知的优先级: {sorted(bad)}")
    exclude = list(exclude)
    chosen: list[str] = []
    tiers: list[str] = []

    def ok_vs(col, others):
        return all(_rgb_distance(col, o) >= min_distance for o in others)

    for lvl in from_levels:
        for col in STROKES_BY_LEVEL[lvl]:
            if len(chosen) >= n:
                break
            if contrast_vs_white(col) < 1.5:      # 线状阈值；**无上限**，越深越好
                continue
            if col in chosen or not ok_vs(col, exclude) or not ok_vs(col, chosen):
                continue
            chosen.append(col)
            tiers.append(lvl)
        if len(chosen) >= n:
            break
    if len(chosen) < n:
        raise ValueError(
            f"第 {'/'.join(from_levels)} 级的线状色只凑出 {len(chosen)} 个，要 {n} 个。"
            f"颜色不够用时，文字标注直接用黑色 —— 不会出错的兜底。")
    d = min((_rgb_distance(a, b) for a, b in combinations(chosen, 2)), default=None)
    return PaletteResult(chosen, tiers, d)


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
def _levels_table() -> list[tuple[str, list[str], int, list[str]]]:
    """(级别, 面积色, 其中前几个是区段, 线状色) —— 打印与画色卡共用同一份数据。

    **只分两类**（user directive 2026-08-06，取代原来的三分法）：
      1. **面积**：区段 / 柱子 —— 都是有面积的结构，共用填充阈值（对白底 >= 1.1，
         且 <= 10 不得近黑）。取色池代码里它们本来就是合并的一个池（DEFAULT_*_FILLS）。
      2. **线状**：线条 / 文字 —— 都是一两像素宽的笔画，共用线条阈值（>= 1.5，不设上限）。
    原来把"区段/柱子/线条"分三行，暗示三套不同的校验规则，但阈值体系只有两档，
    展示层与断言层对不上。

    **合并后仍保留一个信息**：面积色里**前 n_seg 个是区段的固定语义映射**
    （灰/橙/绿 = 侧翼/HA/人源插入），其余是柱子色序列。同一张图里这两段必须互不相交
    —— 那是 assert_no_palette_collision() 管的**图级**约束，不是颜色本身的属性，
    所以标注在同一行里，而不是拆成两类。
    """
    seg = {"A": DEFAULT_A_SEG_FILLS, "B": DEFAULT_B_SEG_FILLS}
    strokes = {"A": DEFAULT_A_STROKES, "B": DEFAULT_B_STROKES,
               "3": TIER1_STROKES, "4": TIER2_STROKES, "5": TIER3_STROKES}
    out = []
    for t in PRIORITY_LEVELS:
        segs = list(seg[t].values()) if t in seg else []
        out.append((t, segs + list(SAMPLE_FILLS_BY_LEVEL[t]), len(segs), strokes[t]))
    return out


def print_palette_levels() -> None:
    """一屏打印**每一级的全部颜色** —— 想一眼看清有哪些色就跑这个。

    只分两类：面积（区段/柱子）与 线状（线条/文字）—— 见 _levels_table() 的说明。
    """
    def line(cols):
        return "  ".join(f"{c}({contrast_vs_white(c):.2f})" for c in cols)

    print("\n================ 配色优先级全量清单 ================")
    print("规则：永远第一优先 Default_A；B 只在【用户点名】或【A 不够用要补充】时出现。")
    print("分两类：面积(区段/柱子，阈值 1.1-10) · 线状(线条/文字，阈值 >=1.5 无上限)")
    for lvl, fills, n_seg, strokes in _levels_table():
        print(f"\n---- 第 {lvl} 级：{TIER_SOURCE[lvl]} ----")
        tag = f"（前 {n_seg} 个是区段的固定语义映射，其余为柱子序列）" if n_seg else ""
        print(f"  面积 · 区段/柱子 ({len(fills)}){tag}:\n    {line(fills)}")
        print(f"  线状 · 线条/文字 ({len(strokes)}):\n    {line(strokes)}")
    print("\n括号内是对白底 WCAG 对比度。面积需 >= 1.1 且 <= 10（不得近黑）；"
          "线状需 >= 1.5，越深越好、不设上限。")
    print("====================================================")
    _warn_if_swatch_stale()


def _warn_if_swatch_stale() -> None:
    """色卡比源文件旧就提醒 —— 否则常量改了、PNG 还是旧的，那张图就是在骗人。"""
    src = Path(__file__).resolve()
    png = src.parent / "palette_levels_swatch.png"
    if not png.exists():
        print(f"[提示] 还没有色卡：跑 `python {src.name} --swatch` 生成 {png.name}")
    elif png.stat().st_mtime < src.stat().st_mtime:
        print(f"[警告] {png.name} 比 {src.name} 旧 —— 颜色可能已改，"
              f"跑 `python {src.name} --swatch` 刷新")


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

    # (行标题, 颜色, 该角色的下限, 是否受"近黑上限"约束, 区段色个数)
    # **只分两类**：面积（区段/柱子）与 线状（线条/文字）—— 见 _levels_table()。
    # 近黑 >10 只对面积是硬伤（大面积墨块），线状越深越好 —— 黑色 21.00 是首选笔画色。
    rows: list[tuple[str, list[str], float, bool, int]] = []
    for lvl, fills, n_seg, strokes in _levels_table():
        tag = {"A": "第1优先 Default_A", "B": "第2优先 Default_B"}.get(lvl, f"第{lvl}级")
        rows.append((f"{tag}  面积 · 区段/柱子", fills, 1.1, True, n_seg))
        rows.append((f"{tag}  线状 · 线条/文字", strokes, 1.5, False, 0))

    ncol = max(len(c) for _, c, _, _, _ in rows)
    fig, ax = plt.subplots(figsize=(1.35 * ncol + 4.4, 0.82 * len(rows) + 1.6))
    for r, (title, cols, thr, cap_near_black, n_seg) in enumerate(rows):
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
        # 面积行里，前 n_seg 个是区段的固定语义映射 —— 画条竖线把它与柱子序列分开，
        # 提醒"同一张图里这两段必须互不相交"（图级约束，不是颜色本身的属性）。
        if n_seg:
            ax.plot([n_seg - 0.03, n_seg - 0.03], [y - 0.04, y + 0.94],
                    color="#555555", lw=1.2, linestyle=(0, (3, 2)))

    ax.set_xlim(-0.05, ncol)
    ax.set_ylim(-0.05, len(rows))
    ax.axis("off")
    ax.set_title("配色优先级色卡 —— 永远第一优先 Default_A；B 只在【用户点名】或【A 不够用】时补充\n"
                 "格内 = 十六进制 + 白底 WCAG 对比度　红 X = 该角色不可用"
                 "（面积需 ≥1.1 且 ≤10 不得近黑；线状需 ≥1.5，越深越好不设上限）\n"
                 "面积行的竖虚线左侧 = 区段的固定语义映射（侧翼/HA/人源插入），"
                 "右侧 = 柱子色序列；同一张图里这两段必须互不相交",
                 fontsize=10.5, pad=14)
    fig.tight_layout()
    paths = []
    for ext in ("png", "pdf"):
        p = f"{out_stem}.{ext}"
        fig.savefig(p, dpi=200, bbox_inches="tight", facecolor="white")
        paths.append(p)
    plt.close(fig)
    paths.append(save_palette_swatch_html(f"{out_stem}.html", rows))
    return paths


def save_palette_swatch_html(out_path: str | Path, rows=None) -> str:
    """同一份色表再出一个 **HTML** 版 —— 不依赖任何编辑器扩展就能看到颜色。

    为什么需要它：`.py` / `.R` 都是纯文本，`#80B1D3` 在里面只是 7 个字符；
    要在编辑器里显示成色块，必须装颜色预览扩展（如 VS Code 的
    `naumovs.color-highlight`）。**本机两个环境都没装**，所以源码里看不到颜色是正常的。
    HTML 版用浏览器/编辑器预览直接打开就有色块，且十六进制可以选中复制 ——
    PNG 做不到后者。
    """
    if rows is None:
        rows = []
        for lvl, fills, n_seg, strokes in _levels_table():
            tag = {"A": "第1优先 Default_A", "B": "第2优先 Default_B"}.get(lvl, f"第{lvl}级")
            rows.append((f"{tag}　面积 · 区段/柱子", fills, 1.1, True, n_seg))
            rows.append((f"{tag}　线状 · 线条/文字", strokes, 1.5, False, 0))

    def cell(col: str, thr: float, cap: bool, sep: bool) -> str:
        cr = contrast_vs_white(col)
        bad = cr < thr or (cap and cr > 10)
        ink = "#fff" if cr > 4.5 else "#000"
        mark = '<span class="x">X</span>' if bad else ""
        style = "border-left:3px dashed #555;margin-left:10px;padding-left:7px" if sep else ""
        return (f'<td style="{style}"><div class="sw" style="background:{col};color:{ink}">'
                f'{mark}<code>{col}</code><br><small>{cr:.2f}</small></div></td>')

    body = []
    for title, cols, thr, cap, n_seg in rows:
        tds = "".join(cell(c, thr, cap, sep=(n_seg and i == n_seg))
                      for i, c in enumerate(cols))
        body.append(f'<tr><th>{title}</th>{tds}</tr>')

    html = f"""<!doctype html><meta charset="utf-8"><title>配色优先级色卡</title>
<style>
 body{{font-family:"Noto Sans CJK JP",sans-serif;margin:24px;background:#fff;color:#222}}
 h1{{font-size:18px;margin:0 0 4px}} p.sub{{color:#555;font-size:13px;margin:0 0 18px;line-height:1.6}}
 table{{border-collapse:separate;border-spacing:6px 8px}}
 th{{text-align:right;font-weight:normal;font-size:13px;white-space:nowrap;padding-right:6px}}
 .sw{{width:104px;height:52px;border:1px solid #000;border-radius:3px;display:flex;
      flex-direction:column;align-items:center;justify-content:center;position:relative}}
 code{{font-size:11.5px}} small{{font-size:10.5px;opacity:.9}}
 .x{{position:absolute;top:1px;right:5px;color:#B00020;font-weight:bold;font-size:13px;
     text-shadow:0 0 2px #fff}}
</style>
<h1>配色优先级色卡 —— 永远第一优先 Default_A；B 只在【用户点名】或【A 不够用】时补充</h1>
<p class="sub">格内 = 十六进制 + 白底 WCAG 对比度　红 X = 该角色不可用
（面积需 ≥1.1 且 ≤10 不得近黑；线状需 ≥1.5，越深越好不设上限）<br>
面积行的竖虚线左侧 = 区段的固定语义映射（侧翼/HA/人源插入），右侧 = 柱子色序列；
同一张图里这两段必须互不相交<br>
<b>本页与 palette_levels_swatch.png 同源</b>，都出自 palette_priority.py 的常量；
用浏览器或编辑器预览打开即可看到颜色，<b>不需要任何编辑器扩展</b>。</p>
<table>{"".join(body)}</table>
"""
    Path(out_path).write_text(html, encoding="utf-8")
    return str(out_path)


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
