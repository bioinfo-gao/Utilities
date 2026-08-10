#!/usr/bin/env Rscript
# =============================================================================
# PCA_2 — 把 2026-08-09 肉眼评判的**全部修改意见**落进代码，重出一组图。
#
# 上一轮（../PCA/）是"把所有配色铺开给眼睛看"；这一轮是"按看的结果改"。
# 逐条对应见 README.md 的意见台账，代码里每处改动都标了它对应第几条。
#
# 数据仍读 ../PCA/pca_coordinates_demo.csv（single source of truth，不复制第二份）。
#
# 运行：/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript plot_pca_revised.R
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2); library(ggrepel); library(readr); library(dplyr)
  library(patchwork); library(colorspace)
})

setwd(dirname(normalizePath(sub("^--file=", "",
  grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1]))))
source("../color_figures_with_preconfigured_sets/palette_priority.R")

# ---- 中文渲染守卫（../PCA/ 那轮踩过：默认 pdf() 是单字节设备，中文变空白仍照常出图）
CJK_FONT <- "Noto Sans CJK SC"
stopifnot("缺少 CJK 字体" =
  any(grepl(CJK_FONT, system("fc-list :lang=zh family", intern = TRUE), fixed = TRUE)),
  "R 无 cairo 支持" = capabilities("cairo"))
theme_set(theme_bw(base_size = 11, base_family = CJK_FONT))

save_fig <- function(stem, plot, width, height, dpi = 130) {
  for (dev in c("pdf", "png")) {
    f <- paste0(stem, ".", dev); msgs <- character()
    args <- list(filename = f, plot = plot, width = width, height = height,
                 dpi = dpi, limitsize = FALSE)
    args$device <- if (dev == "pdf") cairo_pdf else "png"
    if (dev == "png") args$type <- "cairo"   # 只有 png 设备认，传给 cairo_pdf 会报错
    withCallingHandlers(do.call(ggsave, args),
      warning = function(w) { msgs <<- c(msgs, conditionMessage(w)); invokeRestart("muffleWarning") })
    bad <- grep("mbcsToSbcs|conversion failure|no font could be found", msgs, value = TRUE)
    if (length(bad)) stop(sprintf("%s: 中文渲染失败 %d 处，例：%s", f, length(bad), bad[1]))
  }
}

# =============================================================================
# 意见 1 —— 图1「色调很美观，但太浅；每个颜色都加深之后保留配色」
# 在 HCL 空间加深：**色相 H 逐色不动**（这才叫"保留配色"），降 L 到统一目标对比度，
# C 随之提升并按该 (H,L) 的色域上限截断（否则暗下来会发灰发浑）。
# 原版对白底 1.19–3.02 深浅不均，统一目标顺带把不均匀也修掉。
# =============================================================================
A_ORIG <- c("#BEBADA", "#FB8072", "#FFED6F", "#FCCDE5", "#BC80BD", "#CCEBC5")

darken_keep_hue <- function(hex, target_contrast, chroma_boost = 1.25) {
  hcl <- coords(as(hex2RGB(hex), "polarLUV"))
  H <- hcl[1, "H"]; C0 <- hcl[1, "C"]
  f <- function(L) {
    C <- min(C0 * chroma_boost, max_chroma(H, L))
    contrast_vs_white(colorspace::hex(polarLUV(L = L, C = C, H = H), fixup = TRUE)) - target_contrast
  }
  lo <- 5; hi <- hcl[1, "L"]
  if (f(hi) > 0) return(colorspace::hex(polarLUV(L = hi, C = C0, H = H), fixup = TRUE))
  for (i in 1:60) { mid <- (lo + hi) / 2; if (f(mid) > 0) lo <- mid else hi <- mid }
  L <- (lo + hi) / 2
  colorspace::hex(polarLUV(L = L, C = min(C0 * chroma_boost, max_chroma(H, L)), H = H),
                  fixup = TRUE)
}

# 模式二：**等量加深**（每色 L 减同一个 ΔL），保住原有的深浅关系。
# 为什么需要它：原版这套色的可分度有一部分来自**深浅不同**而非色相不同 ——
# 紫系 #BEBADA/#BC80BD/#FCCDE5 色相只差约 35 度，靠 L=76.8/61.5/87.0 拉开。
# 模式一把 L 拉齐（为了修"深浅不均"），恰好把这部分可分度抹掉：加深后
# #9F6585 vs #A759A9 只剩 0.089、#77729A vs #9F6585 只剩 0.094，都低于 0.10 门槛。
# 用户只要求"加深"，"拉齐深浅"是额外动作 —— 所以两种模式并列，由眼睛定。
darken_by_dL <- function(hex, dL, chroma_boost = 1.25) {
  h <- coords(as(hex2RGB(hex), "polarLUV"))
  L <- max(5, h[1, "L"] - dL)
  colorspace::hex(polarLUV(L = L, C = min(h[1, "C"] * chroma_boost, max_chroma(h[1, "H"], L)),
                           H = h[1, "H"]), fixup = TRUE)
}

DARK_TARGETS <- c(`对比度3.0` = 3.0, `对比度4.5` = 4.5, `对比度6.0` = 6.0)
A_DARK <- lapply(DARK_TARGETS, function(t)
  unname(vapply(A_ORIG, darken_keep_hue, "", target_contrast = t)))

swap <- function(v, i, x) { v[i] <- x; v }

DL_STEPS <- c(`等量-20` = 20, `等量-30` = 30, `等量-40` = 40)
A_DL <- lapply(DL_STEPS, function(x)
  unname(vapply(A_ORIG, darken_by_dL, "", dL = x)))

# 意见 1b（user 2026-08-09，看过 CAND_01 之后）：
#   「总体以等量-20 最佳，但右下角 6 个点还是分不清，把其中一组改成 cyan」
# 右下 = cDC2 簇 = 位3 #C6B500(浊金) + 位4 #CC92B1(浊粉)。两者 RGB 距离 0.411 本来很高 ——
# 又一次数值与眼睛不符：加深把淡黄压成橄榄/浊金，与浊粉同属低彩度"闷"色调，
# 与图7 棕 vs 粉是同一种失效模式，而 RGB 距离对这类完全无感。
# 换**位4**（不是位3）：位4 的浊粉本就与 #8984AB / #944195 同属紫系、是全局最挤的一支，
# 换掉它同时解决簇内可分度和全局拥挤 —— 全局最小色距 0.130 -> 0.155。
# cyan 取 #17BECF：CLAUDE.md 点名的标准 cyan，且在 TIER2_STROKES 池内，无需扩池。
CYAN <- "#17BECF"
A_FILLS_DEFAULT <- swap(A_DL[["等量-20"]], 4, CYAN)

# 硬约束：色相漂了就不是"保留配色"了
for (nm in c(names(A_DARK), names(A_DL))) {
  v  <- if (nm %in% names(A_DARK)) A_DARK[[nm]] else A_DL[[nm]]
  h0 <- coords(as(hex2RGB(A_ORIG), "polarLUV"))[, "H"]
  h1 <- coords(as(hex2RGB(v), "polarLUV"))[, "H"]
  dh <- pmin(abs(h1 - h0), 360 - abs(h1 - h0))
  if (any(dh > 2)) stop(sprintf("加深档 %s 色相漂移 %.1f 度", nm, max(dh)))
}
cat("色相守恒：6 个加深档全部通过（逐色漂移 <2 度）\n")

# =============================================================================
# 意见 6 —— 图6「黑色大点不美观，改深灰」+「右下 6 点难分辨，其中一个改暖色」
# 意见 7 —— 图7「右下 6 点难分辨，其中一个改冷色」
# 意见 8 —— 图8「左下 6 点难分辨、两灰不美观，偏深的灰改低饱和彩色」
#
# ⚠ 黑点通则也命中了图4（位6 = KO_DN 是 #000000），但用户判图4「好」时并未点名它。
#    这里**按通则一并换成深灰**，同时保留未改版 `..._04_black_kept` 供对照 —— 见 README 待确认项。
# =============================================================================
DARK_GREY <- "#4D4D4D"        # 替代纯黑；对白底 8.45，仍是重色但不刺眼

# ---- 各方案取色：不改的方案仍走 palette_priority.R 正式入口，绝不手写 hex ----
S02 <- unname(strokes_by_priority(6))                                  # 图2 可，不改
S03 <- unname(sample_fills(6, force_level = "B"))                      # 图3 好，不改
S04_orig <- unname(strokes_by_priority(6, from = c("B", "3", "4", "5")))# 图4 好
S05 <- unname(fills_by_priority(6, from = "3"))                        # 图5 好，不改
S06_orig <- unname(strokes_by_priority(6, from = c("3", "4", "5")))
S07_orig <- unname(fills_by_priority(6, from = c("4", "5")))
S08_orig <- unname(fills_by_priority(6, from = c("5", "4", "3")))

S04 <- swap(S04_orig, which(S04_orig == "#000000"), DARK_GREY)          # 意见6 通则外推
S06 <- swap(swap(S06_orig, which(S06_orig == "#000000"), DARK_GREY),
            4, "#CD5B45")                                              # 意见6：位4 改暖(池内)
S07 <- swap(S07_orig, 4, "#0000CD")                                    # 意见7：位4 改冷(池内)
# 意见8：位2 改低饱和紫（用户选，第4级池内色）
# 意见8b：位3 深灰 #5A5A5A 再改 magenta #C71585（第4级 TIER2_STROKES，池内）——
#   #5A5A5A 正是全局最紧那一对的另一半（vs #70487E = 0.103），换掉后全局最小回到 0.149。
#   用户看 CAND_08b 后选 #CD00CD（比池内 #C71585 更亮），并明确授权扩池 ——
#   #CD00CD 已加入 TIER2_FILLS 队尾（R/Python 双实现同步，冻结守卫 PASS）。
S08 <- swap(swap(S08_orig, 2, "#70487E"), 3, "#CD00CD")

SCHEMES <- list(
  list(id = "01_A_fills_darkened", name = "图1修订 — Default_A 等量加深 L-20 + 位4 改 cyan #17BECF",
       cols = A_FILLS_DEFAULT, note = "意见1+1b：色相不变等量降 L-20；位4 浊粉改 cyan 解右下簇"),
  list(id = "02_A_strokes",        name = "图2 — Default_A 线状族（未改）",
       cols = S02, note = "评判：可"),
  list(id = "03_B_fills",          name = "图3 — Default_B 面积族（未改）",
       cols = S03, note = "评判：好"),
  list(id = "04_B_strokes",        name = "图4修订 — Default_B 线状族（黑→深灰）",
       cols = S04, note = "评判：好；黑点通则外推，见 README 待确认"),
  list(id = "05_L3_fills",         name = "图5 — 第3级 ColorBrewer 面积族（未改）",
       cols = S05, note = "评判：好"),
  list(id = "06_L3_strokes",       name = "图6修订 — 黑→深灰，位4 改暖色 #CD5B45",
       cols = S06, note = "意见6"),
  list(id = "07_L4_handtuned",     name = "图7修订 — 位4 改冷色 #0000CD",
       cols = S07, note = "意见7"),
  list(id = "08_L5_grey",          name = "图8修订 — 位2 改紫 #70487E，位3 改 magenta3 #CD00CD（2026-08-09 扩池新增）",
       cols = S08, note = "意见8")
)

# ---- 数据（SSOT：读上一轮那份，不复制第二份）--------------------------------
d <- read_csv("../PCA/pca_coordinates_demo.csv", show_col_types = FALSE)
GROUP_LEVELS <- c("NTC_cDC1", "KO_cDC1", "NTC_cDC2", "KO_cDC2", "NTC_DN", "KO_DN")
d$Group    <- factor(d$Group, levels = GROUP_LEVELS)
d$Genotype <- factor(d$Genotype, levels = c("NTC", "KO"))
stopifnot("demo data lost samples" = nrow(d) == 18, !any(is.na(d$Group)))

# 图上真正挤在一起、必须分辨的只有同亚群的 NTC/KO 三对
PAIRS <- list(cDC1 = c(1, 2), cDC2 = c(3, 4), DN = c(5, 6))

make_plot <- function(cols, title, sub, legend = TRUE) {
  names(cols) <- GROUP_LEVELS
  p <- ggplot(d, aes(PC1, PC2, color = Group, shape = Genotype)) +
    geom_point(size = 3.6) +
    geom_text_repel(aes(label = name), color = "black", size = 2.3, max.overlaps = Inf,
                    box.padding = 0.4, min.segment.length = 0, seed = 42) +
    scale_color_manual(values = cols) +
    scale_shape_manual(values = c(NTC = 16, KO = 17)) +
    labs(x = "PC1: 87% variance", y = "PC2: 11% variance", title = title, subtitle = sub) +
    theme(plot.title = element_text(size = 10, face = "bold"),
          plot.subtitle = element_text(size = 6.5, colour = "grey25"),
          legend.position = if (legend) "right" else "none",
          legend.key.size = unit(0.8, "lines"),
          legend.title = element_text(size = 8), legend.text = element_text(size = 7))
  # 每张图都自证 18 个点、18 个标签都画出来了（proj20 静默丢点的教训）
  b <- ggplot_build(p)
  stopifnot("点被丢弃" = nrow(b$data[[1]]) == nrow(d),
            "标签被丢弃" = nrow(b$data[[2]]) == nrow(d),
            "有颜色/形状为 NA" = !any(is.na(b$data[[1]]$colour)) && !any(is.na(b$data[[1]]$shape)))
  p
}

metrics <- function(cols) {
  pd <- vapply(PAIRS, function(p) .rgb_distance(cols[p[1]], cols[p[2]]), 0)
  ct <- vapply(cols, contrast_vs_white, 0)
  list(pd = pd, gmin = min(combn(cols, 2, function(x) .rgb_distance(x[1], x[2]))),
       cmin = min(ct), cmax = max(ct))
}

rows <- list(); panels <- list()
cat(sprintf("%-22s %-8s %-8s %-8s %-8s %s\n",
            "方案", "cDC1", "cDC2", "DN", "全局min", "对白底范围"))
for (s in SCHEMES) {
  m <- metrics(s$cols)
  cat(sprintf("%-22s %-8.3f %-8.3f %-8.3f %-8.3f %.2f-%.2f\n", substr(s$id, 1, 22),
              m$pd[1], m$pd[2], m$pd[3], m$gmin, m$cmin, m$cmax))
  sub <- sprintf("%s\n%s", s$note, paste(s$cols, collapse = "  "))
  save_fig(paste0("PCA2_", s$id), make_plot(s$cols, s$name, sub), width = 8, height = 6)
  panels[[s$id]] <- make_plot(s$cols, s$name, sub, legend = FALSE)
  rows[[s$id]] <- tibble(scheme = s$id, name = s$name,
                         colors = paste(s$cols, collapse = " "),
                         cDC1 = m$pd[1], cDC2 = m$pd[2], DN = m$pd[3],
                         global_min = m$gmin, contrast_min = m$cmin, contrast_max = m$cmax)
}

# 图4 未改黑点的对照版（待用户确认通则是否外推到它）
save_fig("PCA2_04_B_strokes_black_kept",
         make_plot(S04_orig, "图4 — Default_B 线状族（保留黑点，对照）",
                   paste(S04_orig, collapse = "  ")), width = 8, height = 6)

grid <- wrap_plots(panels, ncol = 2) +
  plot_annotation(
    title = "PCA_2 — 按 2026-08-09 肉眼评判意见修订后的 8 个方案",
    subtitle = "● = NTC，▲ = KO。标签一律黑色。各图副标题内为实际色值与对应意见编号。",
    theme = theme(plot.title = element_text(face = "bold", size = 14, family = CJK_FONT),
                  plot.subtitle = element_text(size = 9, colour = "grey30", family = CJK_FONT)))
save_fig("PCA2_all_revised_grid", grid, width = 16, height = 5.2 * ceiling(length(panels) / 2),
         dpi = 110)

write_csv(bind_rows(rows), "revised_schemes.csv")

# =============================================================================
# 未定项的候选对照 —— 数值分不出高下的，交给眼睛
# =============================================================================
cand_sheet <- function(sets, titles, subs, stem, ttl) {
  ps <- Map(function(c, t, s) make_plot(c, t, s, legend = FALSE), sets, titles, subs)
  g <- wrap_plots(ps, ncol = 2) +
    plot_annotation(title = ttl,
      theme = theme(plot.title = element_text(face = "bold", size = 13, family = CJK_FONT)))
  save_fig(stem, g, width = 16, height = 5.2 * ceiling(length(ps) / 2), dpi = 110)
}

# 候选 A：图1 加深档位（原版 + 3 档）
gmin <- function(v) min(combn(v, 2, function(x) .rgb_distance(x[1], x[2])))
lab  <- function(v) sprintf("%s\n全局最小色距 %.3f%s", paste(v, collapse = "  "), gmin(v),
                            ifelse(gmin(v) < 0.10, "  << 低于 0.10 门槛", ""))
# 末格放**当前采用版**（等量-20 + 位4 cyan）。此前它只出现在 PCA2_01 与 CAND_01b 里，
# 这张表却停在改动前、文件名又不提示，用户打开这张找不到 cyan —— 谱系要在同一张表里看得全。
cand_sheet(c(list(A_ORIG), unname(A_DL), unname(A_DARK), list(A_FILLS_DEFAULT)),
  c("原版（对白底 1.19-3.02）", names(DL_STEPS), names(DARK_TARGETS),
    "★ 当前采用：等量-20 + 位4 cyan"),
  c(lab(A_ORIG), vapply(A_DL, lab, ""), vapply(A_DARK, lab, ""), lab(A_FILLS_DEFAULT)),
  "CAND_01_A_fills_darkness",
  "图1 加深谱系（末格 = 当前采用）｜等量加深=保深浅层次 拉齐对比度=深浅均匀但紫系挤到一起")

# 候选 B：图6 位4 暖色（池内 vs 新色）
cand_sheet(list(swap(S06, 4, "#CD5B45"), swap(S06, 4, "#E6820E")),
  c("池内 #CD5B45（coral3）", "新色 #E6820E（需扩池）"),
  c(paste(swap(S06, 4, "#CD5B45"), collapse = "  "),
    paste(swap(S06, 4, "#E6820E"), collapse = "  ")),
  "CAND_06_warm", "待定 — 图6 位4 用哪个暖色？")

# 候选 C：图8 位2 低饱和彩色（4 个候选）
c8 <- c("#6E7B8B", "#7D8C6A", "#6B6B2F", "#70487E")
cand_sheet(lapply(c8, function(x) swap(S08_orig, 2, x)),
  c("#6E7B8B 蓝灰（饱和 0.21）", "#7D8C6A 灰绿（0.24）",
    "#6B6B2F 橄榄（0.56）", "#70487E 紫（0.43）"),
  vapply(c8, function(x) paste(swap(S08_orig, 2, x), collapse = "  "), ""),
  "CAND_08_lowsat", "待定 — 图8 位2 用哪个低饱和彩色？")

# 候选 D（意见1b）：cyan 放位3 还是位4，用哪个 cyan
b20 <- A_DL[["等量-20"]]
cy  <- c("#17BECF", "#008B8B")
sets_b <- c(lapply(cy, function(x) swap(b20, 4, x)), lapply(cy, function(x) swap(b20, 3, x)))
ttl_b  <- c(sprintf("位4(KO_cDC2)改 %s", cy), sprintf("位3(NTC_cDC2)改 %s", cy))
sub_b  <- vapply(sets_b, function(v) sprintf("%s\n全局最小色距 %.3f", paste(v, collapse = "  "),
                 min(combn(v, 2, function(x) .rgb_distance(x[1], x[2])))), "")
cand_sheet(sets_b, ttl_b, sub_b, "CAND_01b_cyan",
           "待定 - 等量-20 的右下簇改 cyan：换哪一位、用哪个 cyan？")

# ---- 单点换色的候选，必须放大到"差异处"看 ---------------------------------
# 教训：CAND_06 用两张完整 18 点 PCA 并排，而两版只差 3 个点的颜色（位4，
# 距离 0.167、色相差 17 度）—— 用户第一反应是"两个 panel 区别在哪里"。
# 只改 1 个组的候选，正确的呈现是**色卡 + 该簇放大**，不是整图并排。
zoom_swap <- function(base, pos, options, labels, stem, ttl) {
  sub_lv <- c("cDC1", "cDC2", "DN")[ceiling(pos / 2)]
  dz <- d[d$Subset == sub_lv, ]
  ps <- Map(function(x, lab) {
    cols <- setNames(swap(base, pos, x), GROUP_LEVELS)
    ggplot(dz, aes(PC1, PC2, color = Group, shape = Genotype)) +
      geom_point(size = 9) +
      geom_text_repel(aes(label = name), color = "black", size = 3.4,
                      box.padding = 0.7, min.segment.length = 0, seed = 42) +
      scale_color_manual(values = cols) +
      scale_shape_manual(values = c(NTC = 16, KO = 17)) +
      labs(title = lab, subtitle = sprintf("仅位%d 改变 -> %s", pos, x)) +
      theme(plot.title = element_text(size = 12, face = "bold"),
            plot.subtitle = element_text(size = 9), legend.position = "none")
  }, options, labels)
  g <- wrap_plots(ps, ncol = length(ps)) +
    plot_annotation(title = ttl,
      subtitle = sprintf("只放大 %s 簇（差异所在）。其余 5 色两版完全相同，故不入图。", sub_lv),
      theme = theme(plot.title = element_text(face = "bold", size = 13, family = CJK_FONT),
                    plot.subtitle = element_text(size = 9, colour = "grey30", family = CJK_FONT)))
  save_fig(stem, g, width = 7 * length(ps), height = 6.5, dpi = 130)
}

zoom_swap(S06, 4, c("#CD5B45", "#E6820E"),
          c("池内 #CD5B45 (coral3)", "新色 #E6820E (需扩池)"),
          "CAND_06_warm_zoom", "图6 位4 暖色二选一 - 放大差异处")

zoom_swap(S08_orig, 2, c("#6E7B8B", "#7D8C6A", "#6B6B2F", "#70487E"),
          c("#6E7B8B 蓝灰 (饱和0.21)", "#7D8C6A 灰绿 (0.24)",
            "#6B6B2F 橄榄 (0.56)", "#70487E 紫 (0.43)"),
          "CAND_08_lowsat_zoom", "图8 位2 低饱和彩色四选一 - 放大差异处 (cDC1 簇)")

zoom_swap(S04_orig, 6, c("#000000", "#4D4D4D"),
          c("保留纯黑 #000000 (原判\"好\")", "按通则改深灰 #4D4D4D"),
          "CAND_04_black_zoom", "图4 位6 黑点是否改深灰 - 放大差异处 (DN 簇)")

zoom_swap(swap(S08_orig, 2, "#70487E"), 3,
          c("#5A5A5A", "#C71585", "#CD00CD"),
          c("现状 深灰 #5A5A5A", "magenta #C71585 (池内)", "magenta3 #CD00CD (需扩池)"),
          "CAND_08b_magenta_zoom", "图8 位3 深灰改 magenta - 放大差异处 (cDC2 簇)")

cat("\n完成：修订版 8 图 + 总览 + 3 组候选对照 + revised_schemes.csv\n")
