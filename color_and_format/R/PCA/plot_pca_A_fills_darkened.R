#!/usr/bin/env Rscript
# =============================================================================
# Default_A 面积族「加深版」—— 保留配色，只加深。
#
# 缘起（user directive 2026-08-09，肉眼评判 图1 后）：
#   「图1虽然看不清，但色调很美观，我建议每个颜色都加深之后保留配色。」
#
# 做法：在 **HCL 空间**加深，不在 RGB/HSV 里乘系数。
#   - **色相 H 逐色保持不变** —— 这是"保留配色"的字面含义，也是这套色好看的原因。
#   - 降低亮度 L 到「每个色对白底的对比度都等于同一个目标值」。原版 1.19～3.02
#     深浅不均（淡黄几乎透明、紫却挺实），统一目标顺带把这个不均匀也修掉。
#   - 彩度 C 随 L 下降适当提升，并按该 (H,L) 的 **色域上限** 截断 —— 否则低亮度下
#     保持原 C 会发灰发浑，失掉原配色的味道。
#
# 出 3 档深度供肉眼挑选，不替用户决定哪档合适。
#
# 运行：/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript plot_pca_A_fills_darkened.R
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2); library(ggrepel); library(readr); library(dplyr)
  library(patchwork); library(colorspace)
})

setwd(dirname(normalizePath(sub("^--file=", "",
  grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1]))))
source("../color_figures_with_preconfigured_sets/palette_priority.R")

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
    if (dev == "png") args$type <- "cairo"
    withCallingHandlers(do.call(ggsave, args),
      warning = function(w) { msgs <<- c(msgs, conditionMessage(w)); invokeRestart("muffleWarning") })
    bad <- grep("mbcsToSbcs|conversion failure|no font could be found", msgs, value = TRUE)
    if (length(bad)) stop(sprintf("%s: 中文渲染失败 %d 处，例：%s", f, length(bad), bad[1]))
  }
}

# ---- 加深：保 H，解 L 使对白底对比度 = target，C 提升后按色域截断 -------------
A_ORIG <- c("#BEBADA", "#FB8072", "#FFED6F", "#FCCDE5", "#BC80BD", "#CCEBC5")

darken_keep_hue <- function(hex, target_contrast, chroma_boost = 1.25) {
  hcl <- coords(as(hex2RGB(hex), "polarLUV"))
  H <- hcl[1, "H"]; C0 <- hcl[1, "C"]
  # 对白底对比度随 L 单调递减 -> 二分求 L
  f <- function(L) {
    C <- min(C0 * chroma_boost, max_chroma(H, L))
    contrast_vs_white(hex(polarLUV(L = L, C = C, H = H), fixup = TRUE)) - target_contrast
  }
  lo <- 5; hi <- hcl[1, "L"]
  if (f(hi) > 0) return(hex(polarLUV(L = hi, C = C0, H = H), fixup = TRUE))
  for (i in 1:60) { mid <- (lo + hi) / 2; if (f(mid) > 0) lo <- mid else hi <- mid }
  L <- (lo + hi) / 2
  hex(polarLUV(L = L, C = min(C0 * chroma_boost, max_chroma(H, L)), H = H), fixup = TRUE)
}

TARGETS <- c(`浅加深` = 3.0, `中加深` = 4.5, `深加深` = 6.0)
VARIANTS <- lapply(TARGETS, function(t) vapply(A_ORIG, darken_keep_hue, "", target_contrast = t))

# ---- 数据 -------------------------------------------------------------------
d <- read_csv("pca_coordinates_demo.csv", show_col_types = FALSE)
GROUP_LEVELS <- c("NTC_cDC1", "KO_cDC1", "NTC_cDC2", "KO_cDC2", "NTC_DN", "KO_DN")
d$Group    <- factor(d$Group, levels = GROUP_LEVELS)
d$Genotype <- factor(d$Genotype, levels = c("NTC", "KO"))
stopifnot("demo data lost samples" = nrow(d) == 18, !any(is.na(d$Group)))

# 同一亚群的 NTC/KO 在图上挤在一起 -> 真正要分辨的是 (1,2) (3,4) (5,6) 这三对
pair_idx <- list(cDC1 = c(1, 2), cDC2 = c(3, 4), DN = c(5, 6))
report <- function(cols, label) {
  pd <- vapply(pair_idx, function(p) .rgb_distance(cols[p[1]], cols[p[2]]), 0)
  ct <- vapply(cols, contrast_vs_white, 0)
  gm <- min(combn(cols, 2, function(x) .rgb_distance(x[1], x[2])))
  cat(sprintf("%-8s %s\n         簇内 %s | 全局min %.3f | 对白底 %.2f-%.2f\n",
              label, paste(cols, collapse = " "),
              paste(sprintf("%s=%.3f", names(pd), pd), collapse = " "), gm,
              min(ct), max(ct)))
  tibble(variant = label, colors = paste(cols, collapse = " "),
         cDC1 = pd[1], cDC2 = pd[2], DN = pd[3], global_min = gm,
         contrast_min = min(ct), contrast_max = max(ct))
}

make_plot <- function(cols, title, sub, legend = TRUE) {
  names(cols) <- GROUP_LEVELS
  ggplot(d, aes(PC1, PC2, color = Group, shape = Genotype)) +
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
}

rows <- list(); panels <- list()
rows[["orig"]] <- report(A_ORIG, "原版")
panels[["原版"]] <- make_plot(A_ORIG, "原版 Default_A 面积族（图1）",
  paste(sprintf("%s[%.2f]", A_ORIG, vapply(A_ORIG, contrast_vs_white, 0)), collapse = "  "),
  legend = FALSE)
save_fig("PCA_01rev_A_fills_00_orig", make_plot(A_ORIG, "原版 Default_A 面积族（图1）",
  paste(A_ORIG, collapse = "  ")), width = 8, height = 6)

for (nm in names(VARIANTS)) {
  cols <- unname(VARIANTS[[nm]])
  rows[[nm]] <- report(cols, nm)
  sub <- sprintf("色相逐色不变，加深至对白底对比度 %.1f\n%s",
                 TARGETS[[nm]], paste(cols, collapse = "  "))
  ttl <- sprintf("Default_A 面积族 — %s（目标对比度 %.1f）", nm, TARGETS[[nm]])
  save_fig(paste0("PCA_01rev_A_fills_", which(names(VARIANTS) == nm), "_", TARGETS[[nm]]),
           make_plot(cols, ttl, sub), width = 8, height = 6)
  panels[[nm]] <- make_plot(cols, ttl, sub, legend = FALSE)
}

# 色相必须逐色守住 —— 这是"保留配色"的硬约束，漂了就不是原来那套色了
for (nm in names(VARIANTS)) {
  h0 <- coords(as(hex2RGB(A_ORIG), "polarLUV"))[, "H"]
  h1 <- coords(as(hex2RGB(unname(VARIANTS[[nm]])), "polarLUV"))[, "H"]
  dh <- pmin(abs(h1 - h0), 360 - abs(h1 - h0))
  if (any(dh > 2)) stop(sprintf("%s: 色相漂移 %.1f 度，已不是原配色", nm, max(dh)))
}
cat("\n色相守恒检查：4 个版本全部通过（逐色漂移 <2 度）\n")

grid <- wrap_plots(panels, ncol = 2) +
  plot_annotation(
    title = "Default_A 面积族 — 原版 vs 三档加深（色相不变）",
    subtitle = "● = NTC，▲ = KO。标签一律黑色。各图副标题内为实际色值。",
    theme = theme(plot.title = element_text(face = "bold", size = 14, family = CJK_FONT),
                  plot.subtitle = element_text(size = 9, colour = "grey30", family = CJK_FONT)))
save_fig("PCA_01rev_A_fills_grid", grid, width = 16, height = 10.4, dpi = 110)

write_csv(bind_rows(rows), "A_fills_darkened_variants.csv")
cat("\n完成：原版 + 3 档加深，单图 + 总览 + A_fills_darkened_variants.csv\n")
