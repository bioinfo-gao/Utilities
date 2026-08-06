#!/usr/bin/env Rscript
## Targeted-allele junction structure figures —— **Default_A 配色版（第 1 优先）**
##
## 与上一层的 plot_junction_structure.R **同数据、同版式、同文件名**，只差配色块：
##   上一层（Default_B，第 2 优先）：侧翼 = 中灰 #999999，柱子第 1 色 = teal #8DD3C7，接头线 = 正红/亮蓝
##   本版（Default_A，第 1 优先）  ：侧翼 = 淡蓝 #80B1D3，柱子 = 淡紫/珊瑚/黄，接头线 = 酒红/深青绿
## 两版并存、互不覆盖：本版产物写在 Alternative/ 子文件夹里，同名但不同目录。
##
## 用户原话（2026-08-05）：「这个截图里的配色完美，对人类阅读者是好极了。实际上我更加喜欢。」
##
## 配色全部取自 palette_priority.R 的 DEFAULT_A_* 常量（那里是配色总纲），本文件不手写十六进制：
##   · 区段色块 -> **stock** Set3 的蓝/橙/绿（注意：是原版 Set3，不是 set3_with_grey()）
##   · 柱子     -> stock Set3 的淡紫/珊瑚/黄/粉/紫/浅绿（跳过过浅的 #FFFFB3 与撞蓝的 teal）
##   · 接头线条与文字 -> diverging 色板 PiYG / BrBG 的**深端**（深且饱和，细线小字才看得清）
##
## 三条品系（TG_MTTH / TG_RAGH / TG_CD1A）各一张两面板图：
##   上面板 = targeted allele 线性结构（mouse flank / homology arm / human insert）+ 4 个接头位置
##   下面板 = 每个样本在 4 个接头处的跨接头读段数
##
## 样式与配色纪律来自 /scientific-figure-making skill。上下两个面板语义完全不同
## （上=构建体区段，下=样本），因此**色块与色块**必须互不相交；断言在出图前跑，撞色直接 stop()。
##
## 柱子用纯色填充、不加 hatch（颜色本身即区分通道）。
##
## 数据来源（只读，不修改）：项目26 两个已冻结的交付包
##
## **本脚本不改动、不 source 上一层的 plot_junction_structure.R** —— 那份独立冻结。
##
## 用法：
##     conda run -n regular_bioinfo Rscript plot_junction_structure_alt.R [outdir]

suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
  library(ggpattern)
})

source("/home/gao/.claude/skills/scientific-figure-making/assets/pubfig.R")

this_file <- normalizePath(sub("^--file=", "",
  grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
HERE <- dirname(this_file)
## palette_priority.R 是**总纲**，住在上一层目录；本 Alternative/ 只放这一版的代码与产物。
.PP <- file.path(HERE, "palette_priority.R")
if (!file.exists(.PP)) .PP <- file.path(dirname(HERE), "palette_priority.R")
if (!file.exists(.PP)) stop("找不到 palette_priority.R（本目录与上一层都没有）")
source(.PP)

args <- commandArgs(trailingOnly = TRUE)
## 代码与产物同目录：本脚本住在 Alternative/，图也写在 Alternative/，
## 文件名与上一层同名（TG_*_junction_structure.png/.pdf），靠目录区分两套配色。
OUT <- if (length(args)) args[1] else HERE

PROJ <- "/home/gao/projects_2026M7/26_Ellen_MTTH_junction_sequences"
PACKAGES <- file.path(PROJ, c("custom_research_report_supplementary_MTTH_20260804",
                              "custom_research_report_supplementary_RAGH_CD1A_20260804"))

## ---------------------------------------------------------------------------
## 配色 —— 两个面板语义不同，配色族必须不相交
## ---------------------------------------------------------------------------
## ---- 全部颜色取自 palette_priority.R 的 DEFAULT_A_* 常量，本文件不手写十六进制 ----
## 与上一层 DEFAULT 版的唯一差别就在这一段（其余代码逐行相同，可直接 diff）。
##
## 上一层用 set3_with_grey()：把 Set3 的蓝 #80B1D3 换成中灰 #999999，理由是
##   (1) #80B1D3 与 #8DD3C7(teal) 只差 0.096，两者无法分处两个面板，白白损失一色；
##   (2) Set3 唯一的中性色 #D9D9D9 太浅（对比度 1.41），换个能用的中灰更值。
## **本版反其道而行**：用户明确说更喜欢那个蓝（2026-08-05），所以保留 **stock Set3**，
## 代价就是 teal 出局 —— 柱子从淡紫 #BEBADA 起，而不是 teal。这是取舍，不是疏漏。

## 上面板：构建体区段（fill）。蓝=侧翼（中性背景语义）/ 橙=HA / 绿=人源插入。
SEG <- DEFAULT_A_SEG_FILLS
## 上面板：接头类型（line + text）。取 diverging 色板 PiYG / BrBG 的**深端** ——
## 深且饱和，正是细线与小字需要的（色块与文字对饱和度的要求正好相反）。
## 这两个色与三个区段填充离得很远，线穿过色块那一段不会消失。
JUNC <- c("J2: human/mouse junction (sequence-detectable)"   = unname(DEFAULT_A_JUNC_STROKES["J2"]),  # #8E0152 酒红 实线
          "J1: HA/endogenous boundary (seamless by design)"  = unname(DEFAULT_A_JUNC_STROKES["J1"]))  # #003C30 深青绿 虚线
JUNC_LTY <- c("J2: human/mouse junction (sequence-detectable)"  = "solid",
              "J1: HA/endogenous boundary (seamless by design)" = "dashed")
## 下面板：样本（fill）。stock Set3 中与上面板不相交的切片。
## 跳过两个：#FFFFB3（对白底 1.04，连填充阈值 1.1 都不到）与 teal #8DD3C7（撞蓝侧翼 0.096）。
SAMPLE_FILLS <- DEFAULT_A_SAMPLE_FILLS
## 彩色版不用 hatch：颜色本身已是区分通道。
SAMPLE_PATTERN <- rep("none", length(SAMPLE_FILLS))

## --- 出图前的硬断言 ---------------------------------------------------------
assert_visible_on_white(SEG, role = "fill")     # 大色块，配黑边
assert_visible_on_white(JUNC, role = "line")    # 细线，标准阈值
assert_visible_on_white(SAMPLE_FILLS, role = "fill")
assert_fill_not_near_black(SAMPLE_FILLS)        # 禁止大面积近黑实心
assert_fill_not_near_black(SEG)
assert_no_yellow_text(JUNC)                     # J 标签与坐标数字用的就是这两个颜色
## 硬约束是**色块 vs 色块**：上面板 3 个区段填充 与 下面板样本填充必须互不相交。
assert_no_palette_collision(list(
  "top panel FILLS: construct segment" = SEG,
  "bottom panel FILLS: sample"         = SAMPLE_FILLS))
## 接头竖线是从色块中间穿过去的，必须对每个区段色都还看得见
## （撞色断言只管色块 vs 色块，抓不到"线在色块里消失"这种可读性 bug）。
.d_line <- outer(unname(JUNC), unname(SEG), Vectorize(function(a, b) .rgb_distance(a, b)))
if (min(.d_line) < 0.13) {
  stop(sprintf("接头线与区段色最近只有 %.3f —— 线穿过色块那一段会看不见", min(.d_line)))
}

## --- 把这一版的实测数字打出来，便于人工复核 ---------------------------------
cat("\n[Default_A 配色版 —— 第 1 优先] 全部取自 palette_priority.R 的 DEFAULT_A_* 常量\n")
cat(sprintf("  区段 : %s\n", paste(SEG, collapse = " ")))
cat(sprintf("  样本 : %s\n", paste(SAMPLE_FILLS, collapse = " ")))
cat(sprintf("  接头线: %s（酒红实线 / 深青绿虚线，PiYG+BrBG 深端）\n", paste(JUNC, collapse = " ")))
.cross <- outer(unname(SEG), unname(SAMPLE_FILLS), Vectorize(function(a, b) .rgb_distance(a, b)))
.k <- which(.cross == min(.cross), arr.ind = TRUE)[1, ]
cat(sprintf("  区段 vs 样本 最紧: %s vs %s = %.3f（assert 门槛 0.10）\n",
            SEG[.k[1]], SAMPLE_FILLS[.k[2]], min(.cross)))
cat(sprintf("  样本内部最紧: %.3f；接头线 vs 区段 最紧: %.3f\n",
            min(utils::combn(unname(SAMPLE_FILLS), 2, function(q) .rgb_distance(q[1], q[2]))),
            min(.d_line)))

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
         title = paste0("Junction-spanning read support per sample (bar colours = samples; ",
                        "a separate colour family from the segment colours above, to which they are unrelated)"),
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
