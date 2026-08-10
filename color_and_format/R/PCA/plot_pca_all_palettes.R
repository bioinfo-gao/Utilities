#!/usr/bin/env Rscript
# =============================================================================
# PCA — 同一份数据、同一张图，把**全部配色方案**各画一遍，供肉眼比较。
#
# 为什么需要这个：配色优先级里的两分类（面积 / 线状）只点名了「区段·柱子」和
# 「线条·文字」，**散点两栏都没写**。PCA 散点该按哪一档取色，是个需要用眼睛
# 确认的判断 —— 数值上的 min pairwise distance 说不出"这组点在白底上看不看得清"。
#
# 数据：proj28（Xiaokun Yang / mouse DC KO）全 18 样本 cohort overview PCA 的**真实坐标**，
#       随目录附带为 `pca_coordinates_demo.csv`，与项目解耦、永远可复现。
#       6 组 = 2 基因型（NTC/KO）× 3 分选亚群（cDC1/cDC2/DN）。
#
# 运行：/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript plot_pca_all_palettes.R
# 产物：本目录下 PCA_<scheme>.{pdf,png} 各一张 + PCA_all_palettes_grid.{pdf,png} 总览
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2); library(ggrepel); library(readr); library(dplyr); library(patchwork)
})

# ---- 中文渲染：必须走 cairo，且必须显式指定 CJK 字体 -------------------------
# R 默认的 pdf() 设备是单字节的，遇到汉字会抛 253 条
# `conversion failure ... in 'mbcsToSbcs'` 然后**照常出图** —— 标题里的中文变成空白，
# 图看着"生成成功"。这是 matplotlib 那个"默认字体没有汉字"陷阱的 R 侧同款。
# 修法：PDF 用 cairo_pdf、PNG 用 cairo 后端，并把 base_family 设成系统里的 CJK 字体。
CJK_FONT <- "Noto Sans CJK SC"
stopifnot("系统缺少 CJK 字体，中文会渲染不出来" =
            any(grepl(CJK_FONT, system("fc-list :lang=zh family", intern = TRUE), fixed = TRUE)))
stopifnot("R 未编译 cairo 支持，无法渲染中文 PDF" = capabilities("cairo"))
theme_set(theme_bw(base_size = 11, base_family = CJK_FONT))

# 出图统一走这里：任何 CJK 转换失败都升级为错误，绝不让"中文变空白"的图静默产出。
save_fig <- function(stem, plot, width, height, dpi = 130) {
  for (dev in c("pdf", "png")) {
    f <- paste0(stem, ".", dev)
    msgs <- character()
    args <- list(filename = f, plot = plot, width = width, height = height,
                 dpi = dpi, limitsize = FALSE)
    # `type = "cairo"` 只有 png 设备认；传给 cairo_pdf 会 "unused argument" 直接报错。
    args$device <- if (dev == "pdf") cairo_pdf else "png"
    if (dev == "png") args$type <- "cairo"
    withCallingHandlers(
      do.call(ggsave, args),
      warning = function(w) {
        msgs <<- c(msgs, conditionMessage(w)); invokeRestart("muffleWarning")
      })
    bad <- grep("mbcsToSbcs|conversion failure|no font could be found",
                msgs, value = TRUE)
    if (length(bad))
      stop(sprintf("%s: 中文渲染失败 %d 处，例：%s", f, length(bad), bad[1]))
  }
}

setwd(dirname(normalizePath(sub("^--file=", "",
  grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1]))))

source("../color_figures_with_preconfigured_sets/palette_priority.R")

d <- read_csv("pca_coordinates_demo.csv", show_col_types = FALSE)
GROUP_LEVELS <- c("NTC_cDC1", "KO_cDC1", "NTC_cDC2", "KO_cDC2", "NTC_DN", "KO_DN")
d$Group    <- factor(d$Group, levels = GROUP_LEVELS)
d$Genotype <- factor(d$Genotype, levels = c("NTC", "KO"))
stopifnot("demo data lost samples" = nrow(d) == 18, !any(is.na(d$Group)))
N <- length(GROUP_LEVELS)

# ---- 取色：每个方案一条，全部走 palette_priority.R 的正式入口 ---------------
# 不在这里手写色值 —— 手写就等于绕开优先级，两张图并排会对不上。
grab <- function(expr) {
  v <- try(eval(expr), silent = TRUE)
  if (inherits(v, "try-error")) return(NULL)
  list(cols = unname(v), tier = attr(v, "tier"))
}

SCHEMES <- list(
  list(id = "01_Default_A_fills",   name = "Default_A — 面积族（柱子/区段色）",
       note = "sample_fills(6, force_level = \"A\")",
       get  = quote(sample_fills(N, force_level = "A"))),
  list(id = "02_Default_A_strokes", name = "Default_A — 线状族（线条/文字色）  ★ proj28 实际采用",
       note = "strokes_by_priority(6)：A 取满 5 个后自动从 B 补第 6 个",
       get  = quote(strokes_by_priority(N))),
  list(id = "03_Default_B_fills",   name = "Default_B — 面积族",
       note = "sample_fills(6, force_level = \"B\")",
       get  = quote(sample_fills(N, force_level = "B"))),
  list(id = "04_Default_B_strokes", name = "Default_B — 线状族",
       note = "strokes_by_priority(6, from = c(\"B\",\"3\",\"4\",\"5\"))",
       get  = quote(strokes_by_priority(N, from = c("B", "3", "4", "5")))),
  list(id = "05_L3_ColorBrewer_fills",   name = "第 3 级 — ColorBrewer Set3（蓝换中灰）面积族",
       note = "fills_by_priority(6, from = \"3\")",
       get  = quote(fills_by_priority(N, from = "3"))),
  list(id = "06_L3_ColorBrewer_strokes", name = "第 3 级 — STROKE_COLORS 线状族",
       note = "strokes_by_priority(6, from = c(\"3\",\"4\",\"5\"))",
       get  = quote(strokes_by_priority(N, from = c("3", "4", "5")))),
  list(id = "07_L4_handtuned_fills",     name = "第 4 级 — 手调全彩",
       note = "fills_by_priority(6, from = c(\"4\",\"5\"))",
       get  = quote(fills_by_priority(N, from = c("4", "5")))),
  list(id = "08_L5_greyscale",           name = "第 5 级 — 黑白灰",
       note = "fills_by_priority(6, from = c(\"5\",\"4\",\"3\"))：第 5 级只有 3 色，必然向下补",
       get  = quote(fills_by_priority(N, from = c("5", "4", "3"))))
)

# ---- 作图 -------------------------------------------------------------------
make_plot <- function(cols, title, subtitle, legend = TRUE) {
  names(cols) <- GROUP_LEVELS
  ggplot(d, aes(PC1, PC2, color = Group, shape = Genotype)) +
    geom_point(size = 3.6) +
    # 标签一律黑色：house rule —— 文字可读性优先于"点与其标签同色"。
    geom_text_repel(aes(label = name), color = "black", size = 2.3,
                    max.overlaps = Inf, box.padding = 0.4,
                    min.segment.length = 0, seed = 42) +
    scale_color_manual(values = cols) +
    scale_shape_manual(values = c(NTC = 16, KO = 17)) +
    labs(x = "PC1: 87% variance", y = "PC2: 11% variance",
         title = title, subtitle = subtitle) +
    theme(plot.title = element_text(size = 10, face = "bold"),
          plot.subtitle = element_text(size = 6.5, colour = "grey25"),
          legend.position = if (legend) "right" else "none",
          legend.key.size = unit(0.8, "lines"),
          legend.title = element_text(size = 8), legend.text = element_text(size = 7))
}

panels <- list(); summary_rows <- list()

for (s in SCHEMES) {
  got <- grab(s$get)
  if (is.null(got) || length(got$cols) < N) {
    cat(sprintf("!! %-26s 取不到 %d 个颜色，跳过\n", s$id, N)); next
  }
  cols <- got$cols[seq_len(N)]
  tier <- if (!is.null(got$tier)) got$tier[seq_len(N)] else rep("?", N)

  # 实际用到的颜色写进副标题 —— 看图时不必回头翻代码对色号
  sub <- paste0(s$note, "\n",
                paste(sprintf("%s[%s]", cols, tier), collapse = "  "))
  cat(sprintf("%-26s %s\n", s$id, paste(cols, collapse = " ")))

  p <- make_plot(cols, s$name, sub)
  save_fig(paste0("PCA_", s$id), p, width = 8, height = 6)

  panels[[s$id]] <- make_plot(cols, s$name, sub, legend = FALSE)
  summary_rows[[s$id]] <- tibble(scheme = s$id, name = s$name,
                                 colors = paste(cols, collapse = " "),
                                 tiers  = paste(tier, collapse = " "))
}

stopifnot("no panel was produced" = length(panels) > 0)

# ---- 总览大图：并排看才比得出来 ---------------------------------------------
grid <- wrap_plots(panels, ncol = 2) +
  plot_annotation(
    title = "PCA — 同一份数据（proj28, 18 样本 / 6 组）在全部配色方案下的效果",
    subtitle = paste("图例已隐藏以节省版面；单张带图例的图见同目录 PCA_<scheme>.pdf。",
                     "\n点的形状：● = NTC，▲ = KO。样品名标签一律黑色（house rule：文字可读性优先）。"),
    theme = theme(plot.title = element_text(face = "bold", size = 14, family = CJK_FONT),
                  plot.subtitle = element_text(size = 9, colour = "grey30", family = CJK_FONT)))
save_fig("PCA_all_palettes_grid", grid, width = 16,
         height = 5.2 * ceiling(length(panels) / 2), dpi = 110)

write_csv(bind_rows(summary_rows), "palette_schemes_used.csv")
cat("\n完成：", length(panels), "个方案，单图 + 总览图 + palette_schemes_used.csv\n")
