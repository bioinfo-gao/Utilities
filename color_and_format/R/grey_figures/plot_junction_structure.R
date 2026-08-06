#!/usr/bin/env Rscript
## Targeted-allele junction structure figures — R / ggplot2 reference implementation.
##
## 与 ../../python/grey_figures/plot_junction_structure.py 同数据、同配色、同布局的 R 版本。
##
## 三条品系（TG_MTTH / TG_RAGH / TG_CD1A）各一张两面板图：
##   上面板 = targeted allele 线性结构（mouse flank / homology arm / human insert）+ 4 个接头位置
##   下面板 = 每个样本在 4 个接头处的跨接头读段数
##
## 样式与配色纪律来自 /scientific-figure-making skill
## (`~/.claude/skills/scientific-figure-making/`, house style 移植自 ChenLiu-1996/figures4papers)。
##
## **本文件的重点是配色纪律**：上下两个面板语义完全不同（上=构建体区段，下=样本），
## 因此使用互不相交的配色族——下面板做成纯灰阶，一眼看出不是上面板的彩色对照。
## ggplot2 在每张 plot 上都从 hue_pal() 重新起色环，撞色是静默发生的，所以三条断言
## 在出图前跑，撞色/低对比度直接 stop()。
##
## 柱子除灰阶外还带 hatch（ggpattern），提供与颜色正交的第二通道，灰度打印仍可区分 ——
## 与 ../../python/grey_figures/plot_junction_structure.py 的 matplotlib hatch 对齐。
##
## 数据来源（只读，不修改）：项目26 两个已冻结的交付包
##
## 用法：
##     conda run -n regular_bioinfo Rscript plot_junction_structure.R [outdir]

suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
  library(ggpattern)
})

source("/home/gao/.claude/skills/scientific-figure-making/assets/pubfig.R")

args <- commandArgs(trailingOnly = TRUE)
this_file <- normalizePath(sub("^--file=", "",
  grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
## 代码与产物同目录：本脚本就住在 grey_figures/ 里，图也写在这里。
## 平行的彩色版在 ../color_figures/，两者只差配色块和下面板标题（可直接 diff 对比）。
OUT <- if (length(args)) args[1] else dirname(this_file)

PROJ <- "/home/gao/projects_2026M7/26_Ellen_MTTH_junction_sequences"
PACKAGES <- file.path(PROJ, c("custom_research_report_supplementary_MTTH_20260804",
                              "custom_research_report_supplementary_RAGH_CD1A_20260804"))

## ---------------------------------------------------------------------------
## 配色 —— 两个面板语义不同，配色族必须不相交
## ---------------------------------------------------------------------------
SEG <- c("mouse genomic flank"            = PALETTE[["blue_main"]],  # #0F4D92
         "homology arm (mouse sequence)"  = PALETTE[["highlight"]],  # #FFD700
         "human insert"                   = PALETTE[["green_3"]])    # #8BCF8B
JUNC <- c("J2: human/mouse junction (sequence-detectable)"   = PALETTE[["magenta"]],  # 实线
          "J1: HA/endogenous boundary (seamless by design)"  = PALETTE[["cyan"]])     # 虚线
JUNC_LTY <- c("J2: human/mouse junction (sequence-detectable)"  = "solid",
              "J1: HA/endogenous boundary (seamless by design)" = "dashed")
## 下面板：样本。刻意用灰阶 + hatch，与上面板五个彩色零交集，
## hatch 提供与颜色正交的第二通道，灰度打印仍可区分。
##
## 灰阶方向是**浅 -> 深**：#ABABAB -> #828282 -> #5A5A5A（最深对白底对比度 6.90）。
## 两端都被实测卡死：
##   深端不用 ink #272727（对比度 14.94）—— 大面积实心近黑柱在论文和 slide 上过重、
##   极不美观，会盖过数据本身；
##   浅端不能再浅 —— J1 分组底纹是 #F2F2F2，#D0D0D0 与它的距离只有 0.133，
##   单样本图（TG_CD1A 只用第一色）里柱子和底纹分不开；#ABABAB 提到 0.278。
SAMPLE_FILLS <- unname(PALETTE[c("grey_pale", "grey_soft", "grey_deep")])  # 浅 -> 深
SAMPLE_PATTERN <- c("none", "stripe", "circle")                    # 对齐 Python 的 "", "///", "..."

## --- 出图前的硬断言 ---------------------------------------------------------
assert_visible_on_white(SEG, role = "fill")     # 大色块，配黑边
assert_visible_on_white(JUNC, role = "line")    # 细线，标准阈值
assert_visible_on_white(SAMPLE_FILLS, role = "fill")
assert_fill_not_near_black(SAMPLE_FILLS)        # 禁止大面积近黑实心
assert_fill_not_near_black(SEG)
## J 标签与坐标数字用的就是 JUNC 这两个颜色（是文字，不是填充）—— 禁止黄色文字。
## 注意 SEG 里的金色 #FFD700 只做填充、从不做字，所以不进这条检查。
assert_no_yellow_text(JUNC)
## 硬约束是**色块 vs 色块**：上面板的 3 个区段填充 与 下面板的样本填充必须互不相交。
## 大面积色块才是会被读成"上下对照"的通道；J1/J2 只是细线+文字标签，不参与这条约束
## （颜色不够用时，下面板文字直接用黑色，如本图的柱顶数值）。
assert_no_palette_collision(list(
  "top panel FILLS: construct segment" = SEG,
  "bottom panel FILLS: sample"         = SAMPLE_FILLS))

JIDS <- c("J1_5p", "J2_5p", "J2_3p", "J1_3p")
NOTE <- paste0(
  "Shaded groups (J1): the homology arm is identical to the endogenous locus, so these reads cannot be assigned to one\n",
  "or the other — the aligner splits them arbitrarily and reports MAPQ 0. J1 counts are therefore NOT a measure of evidence\n",
  "strength and are not comparable with J2 counts. Only J2 reads (MAPQ 60) uniquely identify the targeted allele.")

read_all <- function(rel) {
  do.call(rbind, lapply(file.path(PACKAGES, rel), read.delim,
                        sep = "\t", stringsAsFactors = FALSE, check.names = FALSE))
}

## ---------------------------------------------------------------------------
## 上面板：线性结构 + 接头竖线
## ---------------------------------------------------------------------------
panel_structure <- function(contig, rows) {
  clen <- rows$contig_len[1]
  rng <- function(s) as.integer(strsplit(s, "-", fixed = TRUE)[[1]])
  ha5 <- rng(rows$ha_5p[1]); ha3 <- rng(rows$ha_3p[1]); ins <- rng(rows$human_insert[1])

  blocks <- data.frame(
    xmin = c(1, ha5[1], ins[1], ha3[1], ha3[2] + 1),
    xmax = c(ha5[1] - 1, ha5[2], ins[2], ha3[2], clen),
    seg  = factor(names(SEG)[c(1, 2, 3, 2, 1)], levels = names(SEG)))
  blocks <- blocks[blocks$xmax >= blocks$xmin, ]

  ## J1/J2 在两端相距仅数 kb，在 250 kb 尺度上标签必然重叠 ——
  ## 交替高度 + 外侧标签向外偏移，避免文字糊成一团。
  tier   <- c(J1_5p = 1.02, J2_5p = 0.92, J2_3p = 0.92, J1_3p = 1.02)
  hj     <- c(J1_5p = 1,    J2_5p = 0,    J2_3p = 1,    J1_3p = 0)   # 1=right, 0=left
  jl <- data.frame(
    pos  = rows$junction_pos_contig,
    jid  = rows$junction_id,
    type = factor(ifelse(startsWith(rows$junction_id, "J2"), names(JUNC)[1], names(JUNC)[2]),
                  levels = names(JUNC)),
    stringsAsFactors = FALSE)
  jl$ytop <- tier[jl$jid]
  jl$hjust <- hj[jl$jid]
  ## 标签与坐标数字同向水平偏移，否则接头竖线会从数字中间穿过。
  jl$dx <- clen * 0.006 * ifelse(jl$hjust == 0, 1, -1)

  ggplot() +
    geom_rect(data = blocks,
              aes(xmin = xmin, xmax = xmax, ymin = 0.30, ymax = 0.70, fill = seg),
              colour = "black", linewidth = 0.3) +
    geom_segment(data = jl,
                 aes(x = pos, xend = pos, y = 0.15, yend = ytop,
                     colour = type, linetype = type), linewidth = 0.8) +
    geom_text(data = jl,
              aes(x = pos + dx, y = ytop, label = jid, hjust = hjust, colour = type),
              vjust = -0.3, fontface = "bold", size = 3.4, show.legend = FALSE) +
    ## 位置数字放在色块下方、x 轴之上的空白带里
    geom_text(data = jl,
              aes(x = pos + dx, y = 0.28, label = format(pos, big.mark = ","), colour = type),
              angle = 90, hjust = 1, size = 2.8, show.legend = FALSE) +
    scale_fill_manual(values = SEG, name = NULL) +
    scale_colour_manual(values = JUNC, name = NULL) +
    scale_linetype_manual(values = JUNC_LTY, name = NULL) +
    scale_x_continuous(limits = c(-clen * 0.03, clen * 1.03), expand = c(0, 0)) +
    ## ggplot2 会把超出 panel 的文字**直接裁掉**（matplotlib 默认不裁）：旋转 90° 的 7 位
    ## 坐标（如 222,842）空间不足时会被截成 "22,842" —— 图上出现错误数字，是 correctness
    ## bug 而非排版瑕疵。两道保险：y 下限留出空间 + clip="off" 从结构上杜绝截断。
    scale_y_continuous(limits = c(-0.22, 1.25), expand = c(0, 0)) +
    coord_cartesian(clip = "off") +
    labs(x = paste0(contig, " coordinate (bp)"), y = NULL,
         title = paste0(contig, " — targeted allele structure and junction positions")) +
    guides(fill = guide_legend(order = 1, ncol = 1),
           colour = guide_legend(order = 2, ncol = 1),
           linetype = guide_legend(order = 2, ncol = 1)) +
    theme_pub(font_size = 12) +
    theme(axis.line.y = element_blank(), axis.ticks.y = element_blank(),
          axis.text.y = element_blank(),
          plot.title = element_text(hjust = 0.5, size = 12),
          legend.position = "bottom", legend.box = "horizontal",
          legend.text = element_text(size = 9))
}

## ---------------------------------------------------------------------------
## 下面板：每个样本的跨接头读段数（灰阶）
## ---------------------------------------------------------------------------
panel_support <- function(contig, spanning) {
  d <- spanning[spanning$contig == contig, ]
  d$junction_id <- factor(d$junction_id, levels = JIDS)
  d$sample <- factor(d$sample, levels = sort(unique(d$sample)))
  d$x <- as.integer(d$junction_id)
  n_s <- nlevels(d$sample)

  shade <- data.frame(k = which(startsWith(JIDS, "J1")))
  cols <- stats::setNames(SAMPLE_FILLS[seq_len(n_s)], levels(d$sample))
  pats <- stats::setNames(SAMPLE_PATTERN[seq_len(n_s)], levels(d$sample))

  p <- ggplot(d, aes(x = x, y = n_spanning, fill = sample, pattern = sample)) +
    ## J1 两组铺浅灰底：提示这两组的计数不代表证据强度（见脚注）
    annotate("rect", xmin = shade$k - 0.5, xmax = shade$k + 0.5,
             ymin = -Inf, ymax = Inf, fill = "#F2F2F2") +
    geom_col_pattern(position = position_dodge(width = 0.8), width = 0.72,
                     colour = "black", linewidth = 0.3,
                     pattern_fill = "black", pattern_colour = "black",
                     pattern_density = 0.12, pattern_spacing = 0.018,
                     pattern_size = 0.25, pattern_angle = 45) +
    geom_text(aes(label = n_spanning), position = position_dodge(width = 0.8),
              vjust = -0.4, size = 2.9, colour = "black") +
    scale_pattern_manual(values = pats, name = NULL) +
    scale_fill_manual(values = cols, name = NULL) +
    scale_x_continuous(breaks = seq_along(JIDS), labels = JIDS,
                       limits = c(0.5, length(JIDS) + 0.5), expand = c(0, 0)) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
    labs(x = NULL, y = "reads spanning junction\n(>=10 bp aligned on both sides)",
         title = paste0("Junction-spanning read support per sample (greyscale + hatch = samples; ",
                        "deliberately achromatic, unrelated to the segment colours above)"),
         caption = NOTE) +
    theme_pub(font_size = 12) +
    ## 图例固定在绘图区之外（正上方左对齐）。绝不用 legend.position = "inside"。
    theme(legend.position = "top", legend.justification = "left",
          legend.text = element_text(size = 9),
          plot.title = element_text(size = 11, hjust = 0),
          plot.caption = element_text(hjust = 0, size = 8, colour = "#333333"))

  ## 出图前自检：柱子数必须等于 样本数 × 接头数（静默丢柱直接 stop）。
  bars <- ggplot_build(p)$data[[2]]
  expected <- n_s * length(JIDS)
  if (nrow(bars) != expected) {
    stop(sprintf("%s: 期望 %d 根柱子，实际画出 %d 根", contig, expected, nrow(bars)))
  }
  list(plot = p, n_samples = n_s, n_bars = nrow(bars))
}

## ---------------------------------------------------------------------------
main <- function() {
  coords   <- read_all(file.path("coordinates", "junction_coordinates.tsv"))
  spanning <- read_all(file.path("junction_reads", "spanning_summary.tsv"))
  dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

  for (contig in sort(unique(coords$contig))) {
    rows <- coords[coords$contig == contig, ]
    rows <- rows[match(JIDS, rows$junction_id), ]
    top <- panel_structure(contig, rows)
    bot <- panel_support(contig, spanning)

    fig <- top / bot$plot + plot_layout(heights = c(1, 1.45))
    stem <- paste0(contig, "_junction_structure")
    finalize_figure(fig, file.path(OUT, stem),
                    formats = c("png", "pdf"), dpi = 300, width = 13, height = 8)
    cat(sprintf("  %s: %d samples × %d junctions = %d bars -> %s.png/.pdf\n",
                contig, bot$n_samples, length(JIDS), bot$n_bars, stem))
  }
  cat(sprintf("[OK] %s\n", normalizePath(OUT)))
}

main()
