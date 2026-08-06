#!/usr/bin/env Rscript
## ===========================================================================
## 初级验证 —— 全局配色优先级是否生效（6 样本条形图）
## ===========================================================================
##
## 这不是给客户的图，是**配色优先级设置的验证图**：
## 6 个样本（MTTH_284 / MTTH_412 / MTTH_524 / RAGH_153 / RAGH_273 / CD1A_B125）
## × 4 个接头类别，柱子颜色**完全由 palette_priority.R 按优先级自动取**，
## 脚本里不手写一个填充色。跑完看两处即可判断设置有没有生效：
##   1) 终端打印的 [配色优先级验证] 表 —— 每个颜色来自第几级；
##   2) 出来的图 —— 6 根柱子分得开、没有一根和浅灰底纹糊在一起。
##
## 版式沿用本系列 bottom panel：4 组，J1（两侧）铺浅灰底、J2（中间）留白。
##
## **本脚本不改动、不 source 上一层的 plot_junction_structure.R** —— 那份是三张
## 单基因图的原始实现，独立冻结；这里只共享上一层的 palette_priority.R（总纲）与只读数据。
##
## 用法：
##     conda run -n regular_bioinfo Rscript plot_6_samples_bar.R [outdir]

suppressPackageStartupMessages({
  library(ggplot2)
})

source("/home/gao/.claude/skills/scientific-figure-making/assets/pubfig.R")

this_file <- normalizePath(sub("^--file=", "",
  grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
HERE <- dirname(this_file)
## palette_priority.R 是**总纲**，住在上一层目录；本 Advanced/ 文件夹只放验证用的实验代码。
## 两处都找一遍，脚本挪动位置也不会断。
.PP <- file.path(HERE, "palette_priority.R")
if (!file.exists(.PP)) .PP <- file.path(dirname(HERE), "palette_priority.R")
if (!file.exists(.PP)) stop("找不到 palette_priority.R（本目录与上一层都没有）")
source(.PP)

args <- commandArgs(trailingOnly = TRUE)
OUT  <- if (length(args)) args[1] else HERE
STEM <- "6_samples_bar_plots"

## 数据来源（只读，不修改）：项目26 两个已冻结的交付包
PROJ <- "/home/gao/projects_2026M7/26_Ellen_MTTH_junction_sequences"
PACKAGES <- file.path(PROJ, c("custom_research_report_supplementary_MTTH_20260804",
                              "custom_research_report_supplementary_RAGH_CD1A_20260804"))

SAMPLES <- c("MTTH_284", "MTTH_412", "MTTH_524", "RAGH_153", "RAGH_273", "CD1A_B125")
JIDS    <- c("J1_5p", "J2_5p", "J2_3p", "J1_3p")
SHADE   <- "#F2F2F2"   # J1 两组的浅灰底纹；必须作为"背景色"参与排除

## ---------------------------------------------------------------------------
## 配色 —— 全部由优先级自动分配
## ---------------------------------------------------------------------------
## 上面板（本图没画，但同系列图里有）的 3 个区段填充是**预留**给构建体语义的：
## 灰 = 侧翼 / 橙 = homology arm / 绿 = human insert。样本色必须避开它们，
## 否则并到高级验证图里就撞色了。索引取自第 1 级色板，语义是手工指定的。
SEG <- c("mouse genomic flank"           = TIER1_FILLS[5],   # #999999
         "homology arm (mouse sequence)" = TIER1_FILLS[6],   # #FDB462
         "human insert"                  = TIER1_FILLS[7])   # #B3DE69

## from = c("3","4","5")：这张图是 **Default_B** 那批已冻结的产物，配色是在 Default_A
## 升为第 1 优先**之前**、直接从通用池里搜出来的。把 A 放进来会把第 1 根柱子的
## teal #8DD3C7 换成蓝 #80B1D3（两者 0.096 无法共存）—— 那是要用户点头的改动，
## 不能在重跑一遍旧脚本时静默发生。
## **新图不要抄这个 from**，用默认值（A -> B -> 3 -> 4 -> 5）。
## 顺带一提：6 个样本并排，本来也该用 B —— A 的样本色内部只有 0.127，B 是 0.149。
SAMPLE_FILLS <- fills_by_priority(length(SAMPLES),
                                  exclude = c(unname(SEG), SHADE, "#FFFFFF"),
                                  from = c("3", "4", "5"))
palette_report(SAMPLE_FILLS, "bottom panel FILLS: sample (6 个样本)")

## --- 出图前的硬断言 ---------------------------------------------------------
assert_visible_on_white(SAMPLE_FILLS, role = "fill")
assert_fill_not_near_black(SAMPLE_FILLS)
assert_visible_on_white(SEG, role = "fill")
assert_fill_not_near_black(SEG)
## 色块 vs 色块：样本色与预留的区段色互不相交（高级验证图直接依赖这一条）。
assert_no_palette_collision(list(
  "reserved top-panel FILLS: construct segment" = SEG,
  "bottom panel FILLS: sample"                  = SAMPLE_FILLS))

NOTE <- paste0(
  "Bar colours = samples. The four groups are junction CLASSES, not one shared coordinate: each sample carries its own\n",
  "targeted allele (TG_MTTH / TG_RAGH / TG_CD1A), so counts are compared within a class, never between loci.\n\n",
  "Shaded groups (J1): the homology arm is identical to the endogenous locus, so these reads cannot be assigned to one\n",
  "or the other — the aligner splits them arbitrarily and reports MAPQ 0. J1 counts are therefore NOT a measure of evidence\n",
  "strength and are not comparable with J2 counts. Only J2 reads (MAPQ 60) uniquely identify the targeted allele.")

read_all <- function(rel) {
  do.call(rbind, lapply(file.path(PACKAGES, rel), read.delim,
                        sep = "\t", stringsAsFactors = FALSE, check.names = FALSE))
}

## ---------------------------------------------------------------------------
main <- function() {
  d <- read_all(file.path("junction_reads", "spanning_summary.tsv"))

  missing <- setdiff(SAMPLES, unique(d$sample))
  if (length(missing)) stop(sprintf("交付包里找不到样本: %s", paste(missing, collapse = ", ")))
  d <- d[d$sample %in% SAMPLES, ]
  d$sample      <- factor(d$sample, levels = SAMPLES)
  d$junction_id <- factor(d$junction_id, levels = JIDS)
  d$x <- as.integer(d$junction_id)
  ## 每个样本必须在 4 个接头类别上都有一行，否则 dodge 会静默错位。
  tab <- table(d$sample, d$junction_id)
  if (any(tab != 1)) stop("样本 × 接头 不是每格恰好一行，dodge 会错位：\n",
                          paste(capture.output(print(tab)), collapse = "\n"))

  cols <- stats::setNames(SAMPLE_FILLS, SAMPLES)
  shade_k <- which(startsWith(JIDS, "J1"))   # 1 和 4 -> 两侧浅灰，中间留白

  p <- ggplot(d, aes(x = x, y = n_spanning, fill = sample)) +
    annotate("rect", xmin = shade_k - 0.5, xmax = shade_k + 0.5,
             ymin = -Inf, ymax = Inf, fill = SHADE) +
    geom_col(position = position_dodge(width = 0.86), width = 0.78,
             colour = "black", linewidth = 0.3) +
    geom_text(aes(label = n_spanning), position = position_dodge(width = 0.86),
              vjust = -0.45, size = 2.6, colour = "black") +
    ## 6 个样本排成**一行** —— 默认会折成 2 行 3 列、按列往下读，读者容易看错顺序。
    scale_fill_manual(values = cols, name = NULL,
                      guide = guide_legend(nrow = 1)) +
    scale_x_continuous(breaks = seq_along(JIDS), labels = JIDS,
                       limits = c(0.5, length(JIDS) + 0.5), expand = c(0, 0)) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
    labs(x = NULL, y = "reads spanning junction\n(>=10 bp aligned on both sides)",
         title = paste0("Junction-spanning read support — 6 samples across three targeted alleles ",
                        "(bar colours = samples)"),
         caption = NOTE) +
    theme_pub(font_size = 12) +
    ## 图例固定在绘图区之外（正上方左对齐）。绝不用 legend.position = "inside"。
    theme(legend.position = "top", legend.justification = "left",
          legend.text = element_text(size = 9),
          plot.title = element_text(size = 11, hjust = 0),
          plot.caption = element_text(hjust = 0, size = 8, colour = "#333333",
                                      lineheight = 1.2))

  ## 出图前自检：柱子数必须等于 样本数 × 接头数（静默丢柱直接 stop）。
  bars <- ggplot_build(p)$data[[2]]
  expected <- length(SAMPLES) * length(JIDS)
  if (nrow(bars) != expected) {
    stop(sprintf("期望 %d 根柱子，实际画出 %d 根", expected, nrow(bars)))
  }
  ## 画出来的填充色必须就是分配下去的那 6 个（防止 scale 静默回退到默认色环）。
  drawn <- toupper(unique(bars$fill))
  if (!setequal(drawn, toupper(SAMPLE_FILLS))) {
    stop(sprintf("柱子实际填充色 %s 与分配的 %s 不一致",
                 paste(sort(drawn), collapse = ","), paste(sort(toupper(SAMPLE_FILLS)), collapse = ",")))
  }
  ## 数值标签数量同样自检（geom_text 也会静默丢行）。
  if (nrow(ggplot_build(p)$data[[3]]) != expected) {
    stop("柱顶数值标签数量与柱子数不符")
  }

  dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
  finalize_figure(p, file.path(OUT, STEM),
                  formats = c("png", "pdf"), dpi = 300, width = 13, height = 7)
  cat(sprintf("\n[OK] %d samples x %d junctions = %d bars -> %s\n",
              length(SAMPLES), length(JIDS), nrow(bars),
              file.path(normalizePath(OUT), paste0(STEM, ".png/.pdf"))))
}

main()
