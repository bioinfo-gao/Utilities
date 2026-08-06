#!/usr/bin/env Rscript
## ===========================================================================
## palette_priority.R —— 全局配色优先级的**可执行实现** (user directive 2026-08-05)
## ===========================================================================
##
## 用户设定的全局优先级（在单张图另有明确指定时，以那个指定为准；本文件只管"没有
## 单独指定时该拿哪一套"）：
##
##   第 1 优先  **Default_A** —— stock Set3 那套（蓝侧翼 / 淡紫珊瑚黄柱子 / 酒红深青绿接头线）
##              user directive 2026-08-05：「这套配色作为 Default_A，作为选择配色的第一优先」
##   第 2 优先  **Default_B** —— 灰侧翼那套（原来的 DEFAULT，2026-08-05 已批准并冻结成图）
##   第 3 优先  ColorBrewer 成熟色板 + 我们的改造
##              https://r-graph-gallery.com/38-rcolorbrewers-palettes.html
##              · 色块 -> set3_with_grey()（Set3 的蓝 #80B1D3 换成中灰 #999999）
##              · 线条/文字 -> STROKE_COLORS 六色，用完再取 diverging 两端
##   第 4 优先  /home/gao/Utilities/color_and_format/python/color_figures/
##              里手工调出来的那套（cyan/magenta 降饱和、深橙深紫降饱和、olive）
##   第 5 优先  /home/gao/Utilities/color_and_format/python/grey_figures/
##              里的黑白灰（#ABABAB -> #828282 -> #5A5A5A，浅到深、止于中灰）
##
## **什么时候用 B —— 只有两种情况**（user directive 2026-08-05，取代之前那条
## "每组 >=4 根柱子就退 B" 的自动降级规则，那是 agent 自己加的判断，已作废）：
##   1. **用户明确说要 B**；
##   2. **A 的颜色不够用**，需要从 B 补充剩下的那几个。
## 除此之外 **永远第一优先用 Default_A**，不因为"柱子多""可分度紧"之类理由自动退。
## （A 的样本色内部最紧 0.127、B 是 0.149，这个数字仍然如实记录在下面，
##   但它只是**参考信息**，不再触发任何自动降级。）
##
## **两个层面用法不同，别混：**
##   · **整张图要一套完整配色** -> 直接用 `DEFAULT_A_*` 常量。
##     要 n 个柱子色而 A 的 6 个不够 -> `sample_fills(n)`：先把 A 的取完，再从 B 补。
##   · **只要 n 个任意填充色** -> `fills_by_priority(n)`，按 A -> B -> 3 -> 4 -> 5 逐级取，
##     并把每个颜色实际来自哪一级**打印出来**。这就是"优先级可验证"的含义：
##     不是写在注释里靠自觉，而是跑一次就看得见。
##
## **想一眼看全每一级都有哪些颜色** -> `print_palette_levels()`。
##
## 依赖 pubfig.R（contrast_vs_white / .rgb_distance / set3_with_grey / STROKE_COLORS）。
## 用法：source() 本文件之前先 source pubfig.R，或直接 source 本文件（它会自己 source）。

if (!exists("set3_with_grey")) {
  source("/home/gao/.claude/skills/scientific-figure-making/assets/pubfig.R")
}

## --- 通用候选池（第 3-5 级）--------------------------------------------------
## 第 1、2 级不是"池"而是两套**完整配色** Default_A / Default_B，定义在本文件下半部分；
## 它们的填充色也会被 `fills_by_priority()` 当作前两级候选池（`DEFAULT_A_FILLS` /
## `DEFAULT_B_FILLS`）。用户点名的淡蓝 `#80B1D3` 就是 Default_A 的侧翼色，不再单列
## 一个"优先色"常量 —— 同一个事实只存一处。
##
## 第 3 级：Set3(改) 的 12 个低饱和色 —— 天生为大色块设计。
TIER1_FILLS <- set3_with_grey()
## 第 4 级：手调全彩（../../python/color_figures/plot_junction_structure.py 里的 SAMPLE_FILLS）。
##          都是"线条色降饱和"得来的填充色，不是随手写的十六进制。
TIER2_FILLS <- c("#73C6CF",  # cyan  #17BECF  S x 0.50
                 "#C75C9F",  # magenta #C71585 S x 0.60
                 "#E9A6A1",  # pink (= PALETTE red_2)
                 "#B87542",  # 深橙 #D95F02 S x 0.65 V x 0.85
                 "#70487E",  # 深紫 #7B3294 S x 0.65 V x 0.85
                 "#6B6B2F")  # olive.
## 第 5 级：黑白灰（../../python/grey_figures/）。浅 -> 深，止于中灰。
TIER3_FILLS <- c("#ABABAB", "#828282", "#5A5A5A")

## 取色结果里每个颜色标注来自哪一级。A/B 是两套完整配色，3/4/5 是通用候选池。
TIER_SOURCE <- c(
  "A" = "Default_A  [stock Set3：蓝侧翼那套，第 1 优先]",
  "B" = "Default_B  [灰侧翼那套，第 2 优先]",
  "3" = "ColorBrewer set3_with_grey()  [r-graph-gallery #38 + 我们的改造]",
  "4" = "手调全彩  [python/color_figures/]",
  "5" = "黑白灰    [python/grey_figures/]")
PRIORITY_LEVELS <- names(TIER_SOURCE)

## 线条/文字的通用优先级同理：先 STROKE_COLORS（黑->正红->亮蓝->深绿->咖啡->深紫），
## 再手调的 magenta/cyan，最后黑与深灰。颜色不够用时文字一律黑色。
## （成套用时直接取 DEFAULT_A_JUNC_STROKES / DEFAULT_B_JUNC_STROKES。）
TIER1_STROKES <- STROKE_COLORS
TIER2_STROKES <- c("#C71585", "#17BECF")
TIER3_STROKES <- c("#000000", "#4D4D4D")

## ---------------------------------------------------------------------------
#' 按全局优先级挑 n 个**填充色**。
#'
#' 逐级取色（A -> B -> 3 -> 4 -> 5），级内按该套/该池自身顺序；
#' 每个候选必须同时满足：
#'   · 白底可读（contrast >= 1.1，填充档阈值）—— 剔掉 Set3 的 #FFFFB3（1.04）
#'   · 不近黑（contrast <= 10）—— 大面积近黑是审美硬伤
#'   · 与 `exclude` 中每一个颜色距离 >= min_distance（语义不同的面板不得撞色）
#'   · 与**已选中**的颜色距离 >= min_distance（六根柱子挨在一起要分得开）
#' 只有当前级取不满 n 个，才向下一级要 —— 这就是"优先级"的全部含义。
#'
#' @param n 需要几个颜色。
#' @param exclude 必须避开的颜色：别的 panel 的色块 + 图上的底纹/背景色。
#'   **底纹一定要放进来**：J1 分组的 #F2F2F2 底纹与 Set3 的 #D9D9D9 只差 0.098，
#'   不排除就会出现"柱子和底纹分不开"的图。
#' @param min_distance 距离下限。0.10 是 assert_no_palette_collision() 的默认门槛；
#'   同一组里并排 6 根柱子要求更高一点，这里默认 0.13。
#' @param from 用哪几级、按什么顺序。**新图一律用默认值**（A -> B -> 3 -> 4 -> 5）。
#'   显式指定只有一个用途：**复现某套配色定下时的候选池**。例如 Default_B 那批已冻结的
#'   图传 `from = c("3", "4", "5")` —— 它们的颜色是在 Default_A 进入优先级之前、
#'   直接从通用池里搜出来的；把 A 放进来会把第 1 色 teal `#8DD3C7` 换成蓝 `#80B1D3`
#'   （两者相距 0.096 无法共存），那是要用户点头的改动，不能在重跑旧脚本时静默发生。
#' @return 字符向量，带属性 `tier`（每色来自哪一级）与 `min_pairwise`。
fills_by_priority <- function(n, exclude = character(0), min_distance = 0.13,
                              from = PRIORITY_LEVELS) {
  bad <- setdiff(from, PRIORITY_LEVELS)
  if (length(bad)) stop(sprintf("未知的优先级: %s（可用: %s）",
                                paste(bad, collapse = ", "),
                                paste(PRIORITY_LEVELS, collapse = ", ")))
  all_pools <- list(A = DEFAULT_A_FILLS, B = DEFAULT_B_FILLS,
                    `3` = TIER1_FILLS, `4` = TIER2_FILLS, `5` = TIER3_FILLS)
  pools <- all_pools[from]                      # 顺序由 `from` 决定，不是固定的
  chosen <- character(0); tiers <- character(0)
  ok_vs <- function(col, others) {
    if (!length(others)) return(TRUE)
    all(vapply(others, function(o) .rgb_distance(col, o), numeric(1)) >= min_distance)
  }
  for (t in names(pools)) {
    for (col in pools[[t]]) {
      if (length(chosen) >= n) break
      cr <- contrast_vs_white(col)
      if (cr < 1.1 || cr > 10) next                     # 太浅 / 近黑
      if (col %in% chosen) next
      if (!ok_vs(col, exclude)) next                    # 撞别的 panel 或底纹
      if (!ok_vs(col, chosen)) next                     # 自己人之间也要分得开
      chosen <- c(chosen, col); tiers <- c(tiers, t)
    }
    if (length(chosen) >= n) break
  }
  if (length(chosen) < n) {
    stop(sprintf(paste0("第 %s 级候选池加起来只凑出 %d 个可用填充色，要 %d 个。",
                        "放宽 min_distance（当前 %.2f）或减少分组，不要自己发明颜色。"),
                 paste(from, collapse = "/"), length(chosen), n, min_distance))
  }
  d <- if (n > 1) min(utils::combn(chosen, 2, function(p) .rgb_distance(p[1], p[2]))) else NA_real_
  structure(chosen, tier = tiers, min_pairwise = d)
}

## ---------------------------------------------------------------------------
## Default_B —— **第 2 优先**：灰侧翼那套 (user directive 2026-08-05)
## ---------------------------------------------------------------------------
## 就是 2026-08-05 那一轮验证图用的颜色，用户看过并明确认可（当时叫 DEFAULT_*，
## 用户后来把 stock Set3 那套定为 Default_A 之后，这套改名 Default_B、降为第 2 优先）。
## 已冻结成图的产物一律沿用它，不要因为 A 升为第 1 优先就去重出旧图。
##
## **什么时候动它 —— 只有两种情况**：用户明确要 B；或 A 的颜色不够用要补充。
## **不存在"因为可分度紧所以自动退到 B"这回事**（那条规则 2026-08-05 已被用户废止）。
## 参考数字：B 的样本色内部最紧 0.149，A 是 0.127。
DEFAULT_B_SEG_FILLS <- c("mouse genomic flank"           = TIER1_FILLS[5],   # #999999 中灰
                         "homology arm (mouse sequence)" = TIER1_FILLS[6],   # #FDB462 橙
                         "human insert"                  = TIER1_FILLS[7])   # #B3DE69 绿
## 6 个样本的柱子色：通用池第 3 级 3 个 + 第 4 级 3 个（第 5 级未动用）。
DEFAULT_B_SAMPLE_FILLS <- c("#8DD3C7",  # 3 级 Set3 teal
                            "#FB8072",  # 3 级 Set3 salmon
                            "#FFED6F",  # 3 级 Set3 yellow
                            "#C75C9F",  # 4 级 magenta 降饱和
                            "#E9A6A1",  # 4 级 pink
                            "#B87542")  # 4 级 深橙降饱和
DEFAULT_B_JUNC_STROKES <- c(J2 = TIER1_STROKES[2],   # #E41A1C 正红，实线
                            J1 = TIER1_STROKES[3])   # #1F78B4 亮蓝，虚线
## 作为候选池时的取色顺序：先柱子色（要 n 个色多半是给 n 个分类上色），再区段色。
DEFAULT_B_FILLS <- unname(c(DEFAULT_B_SAMPLE_FILLS, DEFAULT_B_SEG_FILLS))

## 分组底纹。**两套共用**，不属于 A 或 B —— 任何取色都要把它当"背景色"排除。
DEFAULT_SHADE <- "#F2F2F2"

## ---------------------------------------------------------------------------
## Default_A —— **第 1 优先**：stock Set3 那套 (user directive 2026-08-05)
## ---------------------------------------------------------------------------
## 用户原话：「这个截图里的配色完美，对人类阅读者是好极了。实际上我更加喜欢。」
## 随后明确：「这套配色作为 Default_A，作为选择配色的第一优先。」
## 内容 = `set3_with_grey()` 生效**之前**那一版：区段用 stock Set3 的蓝/橙/绿，
## 柱子用淡紫/珊瑚/黄，接头线用 diverging 色板的深端。
##
## **新图默认从这里取。** 与 Default_B 并存，谁也不覆盖谁：
##   · 产物在 `Alternative/` 子文件夹（该目录名早于本次改名，沿用不动），
##     文件名与第一层同名但互不覆盖；
##   · 第一层与 `Advanced/` 那批已冻结的图仍是 Default_B，**不因 A 升为第 1 优先而重出**。
##
## 用这套要知道的实测数字（都过 assert_no_palette_collision 的 0.10 门槛，
## 但低于并排柱子用的 0.13）：
##   · 蓝侧翼 #80B1D3 vs 淡紫柱 #BEBADA = 0.118
##   · 样本色内部最紧（#BEBADA vs #FCCDE5）= 0.127
## 这两个数字**只是如实记录，不触发任何自动降级**（user directive 2026-08-05：
## 「永远第一优先用 Default_A」）。柱子多到 A 的 6 个不够时，用 `sample_fills(n)`
## 从 B 补后面几个 —— 补充，不是替换。
## 另注意 teal #8DD3C7 不在这套里 —— 它与 #80B1D3 只差 0.096，天然互斥。
.S3_STOCK <- toupper(brewer("Set3"))
DEFAULT_A_SEG_FILLS <- c("mouse genomic flank"           = .S3_STOCK[5],   # #80B1D3 淡蓝
                         "homology arm (mouse sequence)" = .S3_STOCK[6],   # #FDB462 橙
                         "human insert"                  = .S3_STOCK[7])   # #B3DE69 绿
## 柱子：跳过 #FFFFB3（对白底 1.04，太浅）与 teal（撞蓝侧翼），取淡紫/珊瑚/黄，再接粉/紫/浅绿。
DEFAULT_A_SAMPLE_FILLS <- .S3_STOCK[c(3, 4, 12, 8, 10, 11)]
## 接头线条/文字：diverging 色板的**深端** —— 深色饱和，正是细线与小字需要的。
DEFAULT_A_JUNC_STROKES <- c(J2 = brewer("PiYG", 2)[1],   # #8E0152 酒红，实线
                            J1 = brewer("BrBG", 2)[2])   # #003C30 深青绿，虚线
## 作为候选池时的取色顺序：先柱子色，再区段色（同 Default_B）。
DEFAULT_A_FILLS <- unname(c(DEFAULT_A_SAMPLE_FILLS, DEFAULT_A_SEG_FILLS))

## ---------------------------------------------------------------------------
## 角色级取色 + 全量清单
## ---------------------------------------------------------------------------
## 各级"柱子/分类"用的色序。A 排在最前，B 只用来**补 A 之后不够的那几个**。
SAMPLE_FILLS_BY_LEVEL <- list(
  A = unname(DEFAULT_A_SAMPLE_FILLS),
  B = unname(DEFAULT_B_SAMPLE_FILLS),
  `3` = TIER1_FILLS, `4` = TIER2_FILLS, `5` = TIER3_FILLS)

#' 要 n 个**柱子/分类**色：先把 Default_A 的取完，不够再从 Default_B 补，还不够往下走。
#'
#' 这就是用户定的规则的直接实现（2026-08-05）：
#' **永远第一优先 A；B 只在"用户点名"或"A 不够用"时出现。**
#' 与 `fills_by_priority()` 的区别只在候选池 —— 这里用的是两套配色的**柱子色**，
#' 而不是把区段色也算进去，所以出来的颜色是"给分类上色"的那一族。
#'
#' @inheritParams fills_by_priority
#' @param min_distance 默认 **0.10** —— 就是 `assert_no_palette_collision()` 的门槛，
#'   也是 Default_A 这套配色当初被验证时用的那个。**不能在这里用更严的 0.13**：
#'   A 的淡紫柱 #BEBADA 距 A 的蓝侧翼 #80B1D3 是 0.118、距粉 #FCCDE5 是 0.127，
#'   门槛设 0.13 会把 A 自己的一半颜色筛掉、悄悄换成 B 的 —— 那正是用户 2026-08-05
#'   废止的那种自动降级。要更严的可分度，显式传 `min_distance`。
#' @param force_level 只用某一级（例如用户点名要 B 就传 `"B"`）。默认按优先级走。
sample_fills <- function(n, exclude = character(0), min_distance = 0.10,
                         force_level = NULL) {
  levels_used <- if (is.null(force_level)) names(SAMPLE_FILLS_BY_LEVEL) else force_level
  bad <- setdiff(levels_used, names(SAMPLE_FILLS_BY_LEVEL))
  if (length(bad)) stop(sprintf("未知的级别: %s", paste(bad, collapse = ", ")))
  chosen <- character(0); tiers <- character(0)
  ok_vs <- function(col, others) {
    if (!length(others)) return(TRUE)
    all(vapply(others, function(o) .rgb_distance(col, o), numeric(1)) >= min_distance)
  }
  for (t in levels_used) {
    for (col in SAMPLE_FILLS_BY_LEVEL[[t]]) {
      if (length(chosen) >= n) break
      cr <- contrast_vs_white(col)
      if (cr < 1.1 || cr > 10) next
      if (col %in% chosen) next
      if (!ok_vs(col, exclude) || !ok_vs(col, chosen)) next
      chosen <- c(chosen, col); tiers <- c(tiers, t)
    }
    if (length(chosen) >= n) break
  }
  if (length(chosen) < n) {
    stop(sprintf("第 %s 级的柱子色只凑出 %d 个，要 %d 个（min_distance = %.2f）",
                 paste(levels_used, collapse = "/"), length(chosen), n, min_distance))
  }
  d <- if (n > 1) min(utils::combn(chosen, 2, function(p) .rgb_distance(p[1], p[2]))) else NA_real_
  structure(chosen, tier = tiers, min_pairwise = d)
}

#' 一屏打印**每一级的全部颜色** —— 想一眼看清有哪些色就跑这个。
#'
#' @param roles 只看某些角色（"segment" / "sample" / "stroke"），默认全看。
print_palette_levels <- function(roles = c("segment", "sample", "stroke")) {
  line <- function(cols) paste(sprintf("%s(%.2f)", cols,
                                       vapply(cols, contrast_vs_white, numeric(1))),
                               collapse = "  ")
  cat("\n================ 配色优先级全量清单 ================\n")
  cat("规则：永远第一优先 Default_A；B 只在【用户点名】或【A 不够用要补充】时出现。\n")
  for (t in PRIORITY_LEVELS) {
    cat(sprintf("\n---- 第 %s 级：%s ----\n", t, TIER_SOURCE[[t]]))
    if ("segment" %in% roles) {
      seg <- switch(t, A = DEFAULT_A_SEG_FILLS, B = DEFAULT_B_SEG_FILLS, NULL)
      if (!is.null(seg)) {
        cat("  区段/结构 (3):\n")
        for (i in seq_along(seg)) {
          cat(sprintf("    %-32s %s (对比度 %.2f)\n",
                      names(seg)[i], seg[i], contrast_vs_white(seg[i])))
        }
      }
    }
    if ("sample" %in% roles) {
      cat(sprintf("  柱子/分类 (%d):\n    %s\n",
                  length(SAMPLE_FILLS_BY_LEVEL[[t]]),
                  line(SAMPLE_FILLS_BY_LEVEL[[t]])))
    }
    if ("stroke" %in% roles) {
      st <- switch(t, A = DEFAULT_A_JUNC_STROKES, B = DEFAULT_B_JUNC_STROKES,
                   `3` = TIER1_STROKES, `4` = TIER2_STROKES, `5` = TIER3_STROKES)
      cat(sprintf("  线条/文字 (%d):\n    %s\n", length(st), line(unname(st))))
    }
  }
  cat("\n括号内是对白底 WCAG 对比度：填充需 >= 1.1，线条/文字需 >= 1.5，填充不得 > 10（近黑）。\n")
  cat("====================================================\n")
  invisible(TRUE)
}

#' 回归守卫：通用候选池现在是否仍然产出 Default_B 那套已冻结的样本色。
#'
#' source() 本文件时自动跑一次。以后谁改了候选池或门槛，只要会动到已冻结的配色，
#' 这里立刻 stop()，而不是让某张旧图重跑时静悄悄换一套颜色。
#' 真要改，就同时改 DEFAULT_B_SAMPLE_FILLS 并说明理由。
check_default_b_palette_unchanged <- function() {
  ## from = c("3","4","5")：Default_B 的柱子色是在 Default_A 进入优先级**之前**、
  ## 直接从通用池里搜出来的。把 A 放进来会把第 1 色 teal #8DD3C7 换成蓝 #80B1D3
  ## （两者 0.096 无法共存）—— 那是要用户点头的改动。本守卫只负责盯住
  ## **通用池（第 3-5 级）与门槛**有没有被悄悄改动。
  got <- fills_by_priority(length(DEFAULT_B_SAMPLE_FILLS),
                           exclude = c(unname(DEFAULT_B_SEG_FILLS), DEFAULT_SHADE, "#FFFFFF"),
                           from = c("3", "4", "5"))
  if (!identical(unname(toupper(as.character(got))), toupper(DEFAULT_B_SAMPLE_FILLS))) {
    stop(sprintf(paste0("通用候选池产出的样本色已偏离已冻结的 Default_B：\n",
                        "  现在: %s\n  已冻结: %s\n",
                        "候选池或门槛被改动了。要么改回去，要么同时更新 DEFAULT_B_SAMPLE_FILLS。"),
                 paste(got, collapse = " "), paste(DEFAULT_B_SAMPLE_FILLS, collapse = " ")))
  }
  invisible(TRUE)
}

#' 把取色结果打成一张表 —— 这就是"优先级是否生效"的验证输出。
palette_report <- function(cols, label = "fills") {
  tier <- attr(cols, "tier")
  cat(sprintf("\n[配色优先级验证] %s —— 共 %d 色，级内最小两两距离 %.3f\n",
              label, length(cols), attr(cols, "min_pairwise")))
  rep <- data.frame(
    i        = seq_along(cols),
    colour   = cols,
    tier     = tier,
    source   = unname(TIER_SOURCE[as.character(tier)]),
    contrast = round(vapply(cols, contrast_vs_white, numeric(1)), 2),
    row.names = NULL, stringsAsFactors = FALSE)
  print(rep, right = FALSE)
  used <- sort(unique(tier))
  cat(sprintf("  -> 实际动用的级别: %s；第 %s 级未动用\n",
              paste0("第", used, "级", collapse = " + "),
              paste(setdiff(PRIORITY_LEVELS, used), collapse = "/")))
  invisible(rep)
}

## source() 时立刻校验已冻结的 Default_B 没有被后续改动悄悄改掉。
check_default_b_palette_unchanged()
