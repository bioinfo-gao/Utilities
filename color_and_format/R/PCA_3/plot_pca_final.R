#!/usr/bin/env Rscript
# =============================================================================
# PCA_3 — 终版：8 个方案的**定稿配色**，一处汇总。
#
# 三个目录的分工，别混：
#   ../PCA/    把全部配色铺开给眼睛看        （原始对照，冻结）
#   ../PCA_2/  按肉眼评判逐条改，含全部候选与决策留痕（工作过程，冻结）
#   ../PCA_3/  **只放定稿** —— 无候选、无备选、无中间态（本目录）
#
# 配色一律由 palette_priority.R 的正式入口取，再套用已定案的逐位替换；
# 本文件**不手写任何色值**，改了池子这里会自动跟着变。
#
# 数据仍读 ../PCA/pca_coordinates_demo.csv（SSOT，不复制第二份）。
#
# 运行：/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript plot_pca_final.R
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2); library(ggrepel); library(readr); library(dplyr)
  library(patchwork); library(colorspace); library(tibble)
})

setwd(dirname(normalizePath(sub("^--file=", "",
  grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1]))))
source("../color_figures_with_preconfigured_sets/palette_priority.R")

CJK_FONT <- "Noto Sans CJK SC"
stopifnot("缺少 CJK 字体" =
  any(grepl(CJK_FONT, system("fc-list :lang=zh family", intern = TRUE), fixed = TRUE)),
  "R 无 cairo 支持" = capabilities("cairo"))
theme_set(theme_bw(base_size = 11, base_family = CJK_FONT))

# R 默认 pdf() 是单字节设备：遇汉字抛 mbcsToSbcs 警告后**照常出图**，中文变空白。
# 所有出图统一走这里，任何 CJK 转换失败升级为 stop。
save_fig <- function(stem, plot, width, height, dpi = 130) {
  for (dev in c("pdf", "png")) {
    f <- paste0(stem, ".", dev); msgs <- character()
    args <- list(filename = f, plot = plot, width = width, height = height,
                 dpi = dpi, limitsize = FALSE)
    args$device <- if (dev == "pdf") cairo_pdf else "png"
    if (dev == "png") args$type <- "cairo"     # 只有 png 认，传给 cairo_pdf 会报错
    withCallingHandlers(do.call(ggsave, args),
      warning = function(w) { msgs <<- c(msgs, conditionMessage(w)); invokeRestart("muffleWarning") })
    bad <- grep("mbcsToSbcs|conversion failure|no font could be found", msgs, value = TRUE)
    if (length(bad)) stop(sprintf("%s: 中文渲染失败 %d 处，例：%s", f, length(bad), bad[1]))
  }
}

swap <- function(v, i, x) { v[i] <- x; v }
DARK_GREY <- "#4D4D4D"   # 通则：有形状的大点不用纯黑

# ---- 方案 1 的加深：HCL 空间等量降 L，色相逐色不动 --------------------------
darken_by_dL <- function(hex, dL, chroma_boost = 1.25) {
  h <- coords(as(hex2RGB(hex), "polarLUV"))
  L <- max(5, h[1, "L"] - dL)
  colorspace::hex(polarLUV(L = L, C = min(h[1, "C"] * chroma_boost, max_chroma(h[1, "H"], L)),
                           H = h[1, "H"]), fixup = TRUE)
}
A_ORIG <- unname(sample_fills(6, force_level = "A"))
A_DARK <- unname(vapply(A_ORIG, darken_by_dL, "", dL = 20))
stopifnot("加深后色相漂移，已不是原配色" =
  all(pmin(abs(coords(as(hex2RGB(A_DARK), "polarLUV"))[, "H"] -
               coords(as(hex2RGB(A_ORIG), "polarLUV"))[, "H"]),
           360 - abs(coords(as(hex2RGB(A_DARK), "polarLUV"))[, "H"] -
                     coords(as(hex2RGB(A_ORIG), "polarLUV"))[, "H"])) <= 2))

# ---- 八个定稿方案 -----------------------------------------------------------
P1 <- swap(A_DARK, 4, "#17BECF")                                   # 意见1+1b
P2 <- unname(strokes_by_priority(6))                               # 未改
P3 <- unname(sample_fills(6, force_level = "B"))                   # 未改
P4 <- { v <- unname(strokes_by_priority(6, from = c("B","3","4","5")))
        swap(v, which(v == "#000000"), DARK_GREY) }                # 意见4
P5 <- unname(fills_by_priority(6, from = "3"))                     # 未改
P6 <- { v <- unname(strokes_by_priority(6, from = c("3","4","5")))
        swap(swap(v, which(v == "#000000"), DARK_GREY), 4, "#CD5B45") }   # 意见6
P7 <- swap(unname(fills_by_priority(6, from = c("4","5"))), 4, "#0000CD") # 意见7
P8 <- { v <- unname(fills_by_priority(6, from = c("5","4","3")))
        swap(swap(v, 2, "#70487E"), 3, "#CD00CD") }                # 意见8+8b

FINAL <- list(
  list(id = "1_A_fills_dark_cyan", verdict = "定稿（原判：太浅 -> 加深）",
       name = "Default_A 面积族·等量加深 L-20 + 位4 cyan",
       chg  = "色相逐色不变；位4 浊粉 -> #17BECF", cols = P1),
  list(id = "2_A_strokes", verdict = "可（未改）",
       name = "Default_A 线状族", chg = "无", cols = P2),
  list(id = "3_B_fills", verdict = "好（未改）",
       name = "Default_B 面积族", chg = "无", cols = P3),
  list(id = "4_B_strokes", verdict = "好（黑点改深灰）",
       name = "Default_B 线状族", chg = "#000000 -> #4D4D4D", cols = P4),
  list(id = "5_L3_fills", verdict = "好（未改）",
       name = "第3级 ColorBrewer 面积族", chg = "无", cols = P5),
  list(id = "6_L3_strokes", verdict = "定稿（原判：黑点丑 + 右下难分）",
       name = "第3级 线状族", chg = "#000000 -> #4D4D4D；位4 -> #CD5B45 coral3", cols = P6),
  list(id = "7_L4_handtuned", verdict = "定稿（原判：右下难分）",
       name = "第4级 手调全彩", chg = "位4 -> #0000CD blue3", cols = P7),
  list(id = "8_L5_grey", verdict = "定稿（原判：左下难分 + 双灰丑）",
       name = "第5级 黑白灰（级联下取）", chg = "位2 -> #70487E；位3 -> #CD00CD（扩池新增）", cols = P8)
)

# ---- 数据 -------------------------------------------------------------------
d <- read_csv("../PCA/pca_coordinates_demo.csv", show_col_types = FALSE)
GROUP_LEVELS <- c("NTC_cDC1", "KO_cDC1", "NTC_cDC2", "KO_cDC2", "NTC_DN", "KO_DN")
d$Group    <- factor(d$Group, levels = GROUP_LEVELS)
d$Genotype <- factor(d$Genotype, levels = c("NTC", "KO"))
stopifnot("demo data lost samples" = nrow(d) == 18, !any(is.na(d$Group)))
PAIRS <- list(cDC1 = c(1, 2), cDC2 = c(3, 4), DN = c(5, 6))   # 图上真正挤在一起的三对

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
  b <- ggplot_build(p)      # 18 点 18 标签必须都在（proj20 静默丢点的教训）
  stopifnot("点被丢弃" = nrow(b$data[[1]]) == nrow(d),
            "标签被丢弃" = nrow(b$data[[2]]) == nrow(d),
            "颜色/形状为 NA" = !any(is.na(b$data[[1]]$colour)) && !any(is.na(b$data[[1]]$shape)))
  p
}

rows <- list(); panels <- list()
cat(sprintf("%-24s %-7s %-7s %-7s %-8s %s\n", "方案", "cDC1", "cDC2", "DN", "全局min", "对白底"))
for (s in FINAL) {
  cols <- s$cols
  pd <- vapply(PAIRS, function(p) .rgb_distance(cols[p[1]], cols[p[2]]), 0)
  ct <- vapply(cols, contrast_vs_white, 0)
  gm <- min(combn(cols, 2, function(x) .rgb_distance(x[1], x[2])))
  cat(sprintf("%-24s %-7.3f %-7.3f %-7.3f %-8.3f %.2f-%.2f\n",
              substr(s$id, 1, 24), pd[1], pd[2], pd[3], gm, min(ct), max(ct)))
  stopifnot("定稿方案的全局最小色距低于 0.10 肉眼门槛" = gm >= 0.10)

  ttl <- sprintf("方案%s — %s", sub("_.*", "", s$id), s$name)
  sub <- sprintf("%s ｜ 改动：%s\n%s", s$verdict, s$chg, paste(cols, collapse = "  "))
  save_fig(paste0("PCA3_", s$id), make_plot(cols, ttl, sub), width = 8, height = 6)
  panels[[s$id]] <- make_plot(cols, ttl, sub, legend = FALSE)
  rows[[s$id]] <- tibble(scheme = s$id, name = s$name, verdict = s$verdict, change = s$chg,
                         colors = paste(cols, collapse = " "),
                         cDC1 = pd[1], cDC2 = pd[2], DN = pd[3], global_min = gm,
                         contrast_min = min(ct), contrast_max = max(ct))
}

save_fig("PCA3_all_final_grid", wrap_plots(panels, ncol = 2) +
  plot_annotation(title = "PCA_3 — 八个方案的定稿配色",
    subtitle = "● = NTC，▲ = KO。标签一律黑色。副标题内为评判、改动与实际色值。",
    theme = theme(plot.title = element_text(face = "bold", size = 14, family = CJK_FONT),
                  plot.subtitle = element_text(size = 9, colour = "grey30", family = CJK_FONT))),
  width = 16, height = 5.2 * ceiling(length(panels) / 2), dpi = 110)

write_csv(bind_rows(rows), "final_palettes.csv")

# ---- 色卡：挑配色时真正会看的那张 -------------------------------------------
sw <- bind_rows(lapply(seq_along(FINAL), function(i)
  tibble(scheme = sprintf("%d. %s", i, FINAL[[i]]$name),
         ord = i, pos = 1:6, col = FINAL[[i]]$cols)))
sw$scheme <- factor(sw$scheme, levels = rev(unique(sw$scheme[order(sw$ord)])))
p_sw <- ggplot(sw, aes(pos, scheme, fill = col)) +
  geom_tile(colour = "grey30", linewidth = 0.3, width = 0.95, height = 0.8) +
  geom_text(aes(label = col), size = 2.6, family = "mono",
            colour = ifelse(vapply(sw$col, contrast_vs_white, 0) > 3.2, "white", "grey10")) +
  scale_fill_identity() +
  scale_x_continuous(breaks = 1:6,
    labels = c("1 NTC_cDC1", "2 KO_cDC1", "3 NTC_cDC2", "4 KO_cDC2", "5 NTC_DN", "6 KO_DN"),
    position = "top") +
  labs(title = "PCA_3 定稿色卡 — 八个方案 × 六组",
       subtitle = "列 = 组别（同一亚群的 NTC/KO 相邻，它们才是图上真正要分辨的三对）",
       x = NULL, y = NULL) +
  theme_minimal(base_size = 11, base_family = CJK_FONT) +
  theme(panel.grid = element_blank(),
        axis.text.x = element_text(size = 8), axis.text.y = element_text(size = 9),
        plot.title = element_text(face = "bold"),
        plot.subtitle = element_text(size = 8.5, colour = "grey30"))
save_fig("PCA3_palette_swatches", p_sw, width = 12, height = 5.4)

cat("\n完成：8 张定稿图 + 总览 + 色卡 + final_palettes.csv\n")
