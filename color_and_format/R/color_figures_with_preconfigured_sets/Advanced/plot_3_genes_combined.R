#!/usr/bin/env Rscript
## ===========================================================================
## 高级验证 —— 三张单基因图合并成一张，把配色优先级压到极限
## ===========================================================================
##
## 把上一层目录里 TG_MTTH / TG_RAGH / TG_CD1A 三张图合并：
##   上面板 ×3  三条品系各自的 targeted allele 结构示意（三段区段语义**完全相同**）
##   下面板 ×1  6 个样本合并显示（MTTH_284/412/524 · RAGH_153/273 · CD1A_B125）
##
## 为什么这是"高级"验证：一张图里同时要 **3 个区段色 + 6 个样本色 = 9 个色块**
## 外加 2 个接头线条色，还必须避开 J1 分组的浅灰底纹。这正好同时压两条相反的纪律：
##   · 语义**相同** -> 三个上面板的区段配色必须**完全一致**  assert_shared_palette()
##   · 语义**不同** -> 区段色 与 样本色 必须**互不相交**      assert_no_palette_collision()
## 颜色全部来自 palette_priority.R 的优先级阶梯，脚本里不手写填充色。
##
## **本脚本不改动、不 source 上一层的 plot_junction_structure.R** —— 那份是三张
## 单基因图的原始实现，独立冻结；这里只共享上一层的 palette_priority.R（总纲）与只读数据。
##
## 用法：
##     conda run -n regular_bioinfo Rscript plot_3_genes_combined.R [outdir]

suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
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
STEM <- "3_genes_combined_junction_structure"

## 数据来源（只读，不修改）：项目26 两个已冻结的交付包
PROJ <- "/home/gao/projects_2026M7/26_Ellen_MTTH_junction_sequences"
PACKAGES <- file.path(PROJ, c("custom_research_report_supplementary_MTTH_20260804",
                              "custom_research_report_supplementary_RAGH_CD1A_20260804"))

CONTIGS <- c("TG_MTTH", "TG_RAGH", "TG_CD1A")
SAMPLES <- c("MTTH_284", "MTTH_412", "MTTH_524", "RAGH_153", "RAGH_273", "CD1A_B125")
JIDS    <- c("J1_5p", "J2_5p", "J2_3p", "J1_3p")
SHADE   <- "#F2F2F2"   # J1 两组的浅灰底纹；必须作为"背景色"参与排除

## ---------------------------------------------------------------------------
## 配色 —— 全部由优先级自动分配
## ---------------------------------------------------------------------------
## 上面板：构建体区段。语义是手工指定的（灰=中性侧翼 / 橙=HA / 绿=人源插入），
## 但**颜色本身取自第 1 级色板**，三个面板共用同一份映射。
SEG <- c("mouse genomic flank"           = TIER1_FILLS[5],   # #999999 中灰
         "homology arm (mouse sequence)" = TIER1_FILLS[6],   # #FDB462 橙
         "human insert"                  = TIER1_FILLS[7])   # #B3DE69 绿
## 上面板：接头类型（line + text）。线条/文字走 STROKE_COLORS 的优先顺序：
## 黑 -> 正红 -> 亮蓝 -> ...。黑留给柱顶数值，接头线取正红与亮蓝。
JUNC <- c("J2: human/mouse junction (sequence-detectable)"  = TIER1_STROKES[2],  # 正红 实线
          "J1: HA/endogenous boundary (seamless by design)" = TIER1_STROKES[3])  # 亮蓝 虚线
JUNC_LTY <- c("J2: human/mouse junction (sequence-detectable)"  = "solid",
              "J1: HA/endogenous boundary (seamless by design)" = "dashed")
## 下面板：6 个样本。避开上面板 3 个区段色 + 浅灰底纹 + 白底。
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
cat(sprintf("  上面板区段色（第 1 级，手工指定语义）: %s\n", paste(SEG, collapse = " ")))
## 跨族最紧的一对是多少、是哪一对 —— 直接打出来，便于人工复核而不是"应该没问题"。
.cross <- outer(unname(SEG), unname(SAMPLE_FILLS),
                Vectorize(function(a, b) .rgb_distance(a, b)))
.k <- which(.cross == min(.cross), arr.ind = TRUE)[1, ]
cat(sprintf("  区段色 vs 样本色 最紧的一对: %s(%s) vs %s(%s) = %.3f（门槛 0.10）\n",
            SEG[.k[1]], names(SEG)[.k[1]], SAMPLE_FILLS[.k[2]], SAMPLES[.k[2]], min(.cross)))

## --- 出图前的硬断言 ---------------------------------------------------------
assert_visible_on_white(SEG, role = "fill")
assert_visible_on_white(JUNC, role = "line")
assert_visible_on_white(SAMPLE_FILLS, role = "fill")
assert_fill_not_near_black(SEG)
assert_fill_not_near_black(SAMPLE_FILLS)
assert_no_yellow_text(JUNC)        # J 标签与坐标数字用的就是这两个颜色
## 语义不同 -> 色块互不相交（9 个色块两两分得开才画得出这张图）
assert_no_palette_collision(list(
  "top panel FILLS: construct segment" = SEG,
  "bottom panel FILLS: sample"         = SAMPLE_FILLS))

NOTE <- paste0(
  "Bar colours = samples — a separate colour family from the segment colours in the three panels above, to which they are unrelated.\n",
  "The four groups are junction CLASSES, not one shared coordinate: each sample carries its own targeted allele, so counts are\n",
  "compared within a class, never between loci. The three structure panels are drawn on INDEPENDENT x scales (254,010 / 38,566 /\n",
  "185,655 bp) and their widths are therefore not comparable.\n\n",
  "Shaded groups (J1): the homology arm is identical to the endogenous locus, so these reads cannot be assigned to one or the\n",
  "other — the aligner splits them arbitrarily and reports MAPQ 0. J1 counts are therefore NOT a measure of evidence strength\n",
  "and are not comparable with J2 counts. Only J2 reads (MAPQ 60) uniquely identify the targeted allele.")

read_all <- function(rel) {
  do.call(rbind, lapply(file.path(PACKAGES, rel), read.delim,
                        sep = "\t", stringsAsFactors = FALSE, check.names = FALSE))
}

## ---------------------------------------------------------------------------
## 上面板：线性结构 + 接头竖线（三条品系各一个，配色映射完全共用）
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

  ## J1/J2 在两端相距仅数 kb，在整条 contig 的尺度上标签必然重叠 ——
  ## 交替高度 + 外侧标签向外偏移，避免文字糊成一团。
  tier <- c(J1_5p = 1.02, J2_5p = 0.92, J2_3p = 0.92, J1_3p = 1.02)
  hj   <- c(J1_5p = 1,    J2_5p = 0,    J2_3p = 1,    J1_3p = 0)   # 1=right, 0=left
  jl <- data.frame(
    pos  = rows$junction_pos_contig,
    jid  = rows$junction_id,
    type = factor(ifelse(startsWith(rows$junction_id, "J2"), names(JUNC)[1], names(JUNC)[2]),
                  levels = names(JUNC)),
    stringsAsFactors = FALSE)
  jl$ytop  <- tier[jl$jid]
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
              vjust = -0.3, fontface = "bold", size = 3.2, show.legend = FALSE) +
    ## 位置数字放在色块下方、x 轴之上的空白带里
    geom_text(data = jl,
              aes(x = pos + dx, y = 0.28, label = format(pos, big.mark = ","), colour = type),
              angle = 90, hjust = 1, size = 2.6, show.legend = FALSE) +
    scale_fill_manual(values = SEG, name = NULL, drop = FALSE) +
    scale_colour_manual(values = JUNC, name = NULL, drop = FALSE) +
    scale_linetype_manual(values = JUNC_LTY, name = NULL, drop = FALSE) +
    scale_x_continuous(limits = c(-clen * 0.03, clen * 1.03), expand = c(0, 0)) +
    ## ggplot2 会把超出 panel 的文字**直接裁掉**（matplotlib 默认不裁）：旋转 90° 的 7 位
    ## 坐标（如 222,842）空间不足时会被截成 "22,842" —— 图上出现错误数字，是 correctness
    ## bug 而非排版瑕疵。两道保险：y 下限留出空间 + clip="off" 从结构上杜绝截断。
    scale_y_continuous(limits = c(-0.22, 1.25), expand = c(0, 0)) +
    coord_cartesian(clip = "off") +
    labs(x = "coordinate along the targeted allele (bp)", y = NULL,
         title = sprintf("%s  —  targeted allele structure and junction positions  (%s bp)",
                         contig, format(clen, big.mark = ","))) +
    theme_pub(font_size = 12) +
    theme(axis.line.y = element_blank(), axis.ticks.y = element_blank(),
          axis.text.y = element_blank(),
          plot.title = element_text(hjust = 0.5, size = 11),
          ## 三个面板配色**完全相同**，图例只画一次（单独占一行，见 legend_row()）——
          ## 重复三份图例会让读者以为三处颜色各有含义。
          ## 三个面板的**结构必须完全一致**（都带 x 轴标题、都不带图例），否则 patchwork
          ## 给某一行多分的高度会让那一条色带**画得更粗**，读者会以为粗细有含义。
          legend.position = "none")
}

## 只画图例的一行 —— 把图例从三个结构面板里剥出来，三个面板才能等高。
legend_row <- function() {
  d  <- data.frame(x = 1, y = NA_real_, seg = factor(names(SEG), levels = names(SEG)))
  dj <- data.frame(x = 1, type = factor(names(JUNC), levels = names(JUNC)))
  ggplot() +
    geom_rect(data = d, aes(xmin = x, xmax = x, ymin = y, ymax = y, fill = seg),
              colour = "black", linewidth = 0.3, na.rm = TRUE) +
    geom_segment(data = dj, aes(x = x, xend = x, y = NA_real_, yend = NA_real_,
                                colour = type, linetype = type),
                 linewidth = 0.8, na.rm = TRUE) +
    ## 图例项来自 scale 的 levels，不来自画出来的数据 —— y = NA 保证这一行什么都不画，
    ## 只留图例本身（na.rm = TRUE 关掉"移除了 N 行"的噪声警告）。
    scale_fill_manual(values = SEG, name = NULL, drop = FALSE) +
    scale_colour_manual(values = JUNC, name = NULL, drop = FALSE) +
    scale_linetype_manual(values = JUNC_LTY, name = NULL, drop = FALSE) +
    guides(fill = guide_legend(order = 1, nrow = 1),
           colour = guide_legend(order = 2, nrow = 1),
           linetype = guide_legend(order = 2, nrow = 1)) +
    theme_void(base_size = 12) +
    ## 图例贴这一行的**顶部** —— 放 "bottom" 会把 theme_void 的空白 panel 留在上方，
    ## 与上一个结构面板之间凭空多出一大条空白。
    theme(legend.position = "top", legend.box = "horizontal",
          legend.text = element_text(size = 9),
          legend.margin = margin(t = 0, b = 0))
}

## ---------------------------------------------------------------------------
## 下面板：6 个样本合并的跨接头读段数
## ---------------------------------------------------------------------------
panel_support <- function(spanning) {
  d <- spanning[spanning$sample %in% SAMPLES, ]
  d$sample      <- factor(d$sample, levels = SAMPLES)
  d$junction_id <- factor(d$junction_id, levels = JIDS)
  d$x <- as.integer(d$junction_id)
  tab <- table(d$sample, d$junction_id)
  if (any(tab != 1)) stop("样本 × 接头 不是每格恰好一行，dodge 会错位：\n",
                          paste(capture.output(print(tab)), collapse = "\n"))

  cols    <- stats::setNames(SAMPLE_FILLS, SAMPLES)
  shade_k <- which(startsWith(JIDS, "J1"))   # 1 和 4 -> 两侧浅灰，中间留白

  ggplot(d, aes(x = x, y = n_spanning, fill = sample)) +
    annotate("rect", xmin = shade_k - 0.5, xmax = shade_k + 0.5,
             ymin = -Inf, ymax = Inf, fill = SHADE) +
    geom_col(position = position_dodge(width = 0.86), width = 0.78,
             colour = "black", linewidth = 0.3) +
    geom_text(aes(label = n_spanning), position = position_dodge(width = 0.86),
              vjust = -0.45, size = 2.6, colour = "black") +
    scale_fill_manual(values = cols, name = NULL, guide = guide_legend(nrow = 1)) +
    scale_x_continuous(breaks = seq_along(JIDS), labels = JIDS,
                       limits = c(0.5, length(JIDS) + 0.5), expand = c(0, 0)) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
    labs(x = NULL, y = "reads spanning junction\n(>=10 bp aligned on both sides)",
         title = "Junction-spanning read support per sample, all three targeted alleles combined (bar colours = samples)",
         caption = NOTE) +
    theme_pub(font_size = 12) +
    ## 图例固定在绘图区之外（正上方左对齐）。绝不用 legend.position = "inside"。
    theme(legend.position = "top", legend.justification = "left",
          legend.text = element_text(size = 9),
          plot.title = element_text(size = 11, hjust = 0),
          plot.caption = element_text(hjust = 0, size = 8, colour = "#333333",
                                      lineheight = 1.2))
}

## ---------------------------------------------------------------------------
main <- function() {
  coords   <- read_all(file.path("coordinates", "junction_coordinates.tsv"))
  spanning <- read_all(file.path("junction_reads", "spanning_summary.tsv"))

  missing <- setdiff(SAMPLES, unique(spanning$sample))
  if (length(missing)) stop(sprintf("交付包里找不到样本: %s", paste(missing, collapse = ", ")))
  if (!all(CONTIGS %in% coords$contig)) stop("交付包里找不到全部三条 contig")

  tops <- lapply(seq_along(CONTIGS), function(i) {
    contig <- CONTIGS[i]
    rows <- coords[coords$contig == contig, ]
    rows <- rows[match(JIDS, rows$junction_id), ]
    panel_structure(contig, rows)
  })
  bot <- panel_support(spanning)

  ## --- 出图后、写盘前的自检 -------------------------------------------------
  ## 1) 语义相同：三个上面板的 区段名->颜色 映射必须完全一致。
  ##    从**画出来的图形对象**里反查，而不是信任同一个 SEG 常量被三处正确引用。
  seg_maps <- lapply(seq_along(tops), function(i) {
    b    <- ggplot_build(tops[[i]])
    segs <- as.character(b$plot$layers[[1]]$data$seg)   # 每个矩形对应哪个区段
    m    <- stats::setNames(toupper(b$data[[1]]$fill), segs)
    m    <- m[!duplicated(names(m))][names(SEG)]        # 侧翼/HA 各出现两次，去重
    if (anyNA(m)) stop(sprintf("%s: 上面板缺了区段 %s",
                               CONTIGS[i], paste(names(SEG)[is.na(m)], collapse = ", ")))
    m
  })
  names(seg_maps) <- CONTIGS
  assert_shared_palette(seg_maps)

  ## 2) 语义不同：画出来的区段色 与 画出来的柱子色 互不相交。
  bot_build <- ggplot_build(bot)
  bar_layer <- 2L   # 1 = annotate("rect") 底纹, 2 = geom_col, 3 = geom_text
  bars <- bot_build$data[[bar_layer]]
  assert_no_palette_collision(list(
    "top panel FILLS as drawn"    = unname(seg_maps[[1]]),
    "bottom panel FILLS as drawn" = toupper(unique(bars$fill))))

  ## 3) 柱子数 = 样本数 × 接头数；填充色就是分配下去的那 6 个；数值标签一一对应。
  expected <- length(SAMPLES) * length(JIDS)
  if (nrow(bars) != expected) {
    stop(sprintf("期望 %d 根柱子，实际画出 %d 根", expected, nrow(bars)))
  }
  if (!setequal(toupper(unique(bars$fill)), toupper(SAMPLE_FILLS))) {
    stop("柱子实际填充色与分配的 6 色不一致（scale 可能静默回退到默认色环）")
  }
  if (nrow(bot_build$data[[3]]) != expected) stop("柱顶数值标签数量与柱子数不符")
  ## 4) 三个上面板各自画出的接头竖线必须是 4 条。
  for (i in seq_along(tops)) {
    nseg <- nrow(ggplot_build(tops[[i]])$data[[2]])
    if (nseg != length(JIDS)) {
      stop(sprintf("%s: 期望 %d 条接头竖线，实际 %d 条", CONTIGS[i], length(JIDS), nseg))
    }
  }

  ## --- 组图 -----------------------------------------------------------------
  ## 五行一次排完，不做嵌套 patchwork：`(p1/p2/p3)` 已经是一个 patchwork，
  ## 再 `/ bot` 是往同一层**追加元素**（不是嵌套），此时 heights 必须给满行数。
  ## 三个结构面板行高完全相同 -> 三条色带粗细相同；图例单独占第 4 行。
  fig <- tops[[1]] / tops[[2]] / tops[[3]] / legend_row() / bot +
    plot_layout(heights = c(1, 1, 1, 0.30, 3.1)) +
    plot_annotation(
      title = "Three targeted alleles side by side — structure (top) and junction-spanning read support (bottom)",
      theme = theme(plot.title = element_text(size = 13, hjust = 0.5,
                                              margin = margin(b = 8))))

  dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
  finalize_figure(fig, file.path(OUT, STEM),
                  formats = c("png", "pdf"), dpi = 300, width = 14, height = 16)
  cat(sprintf("\n[OK] %d contigs (top) + %d samples x %d junctions = %d bars (bottom) -> %s\n",
              length(CONTIGS), length(SAMPLES), length(JIDS), nrow(bars),
              file.path(normalizePath(OUT), paste0(STEM, ".png/.pdf"))))
}

main()
