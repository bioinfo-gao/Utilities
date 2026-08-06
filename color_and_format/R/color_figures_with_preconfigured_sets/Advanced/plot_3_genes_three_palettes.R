#!/usr/bin/env Rscript
## ===========================================================================
## 高难度验证 —— 三个基因示意图各用**一套不同的配色**
## ===========================================================================
##
## 与 plot_3_genes_combined.R 的差别只有一处：那张图里三个结构面板**共用同一套**
## 区段配色（3 个色块）；这张图给三个面板**各配一套**（3 × 3 = 9 个色块），
## 下面板 6 个样本色保持 2026-08-05 已批准的默认不变。
##
##   一张图里的填充色总数：9（区段）+ 6（样本）= **15 个色块**，两两必须分得开，
##   还要同时避开白底与 J1 分组的浅灰底纹 #F2F2F2。
##   这是目前对配色优先级压力最大的一张图。
##
## ⚠ **这张图故意不满足 `assert_shared_palette()`，是有意为之，不是疏忽。**
##   三个面板的区段语义**是相同的**（mouse flank / homology arm / human insert），
##   按 house style 本应共用一套配色（那正是 plot_3_genes_combined.R 的做法）。
##   本图作为**配色容量实证**刻意反过来做，因此必须付出对应的代价来防止误读：
##     · 每个面板带**自己的图例**，图例标题写明是哪条品系的区段 —— 读者不会跨面板读色；
##     · 三套配色是三个**色相家族**（蓝 / 黄绿 / 橙红），家族间距 >= 0.13，
##       不是"随机 9 个色"，一眼能看出"每个面板一套"而不是"9 个不同的东西"；
##     · 每个家族内部一律 **浅 -> 深 = 侧翼 -> HA -> 人源插入**，三个面板规则一致。
##   **真正给客户的图仍用 plot_3_genes_combined.R 那套共用配色。**
##
## 配色来源仍严格走三级优先级：三个家族全部来自**第 1 级 ColorBrewer**
## （BuPu / YlGn / YlOrRd 的 9-class 版各取 3 个成员），第 2、3 级未动用。
##
## **本脚本不改动、不 source 上一层的 plot_junction_structure.R，也不 source 同目录的
## plot_3_genes_combined.R** —— 只共享上一层的 palette_priority.R（总纲）与只读数据。
##
## 用法：
##     conda run -n regular_bioinfo Rscript plot_3_genes_three_palettes.R [outdir]

suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
  library(RColorBrewer)
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
STEM <- "3_genes_three_palettes_junction_structure"

## 数据来源（只读，不修改）：项目26 两个已冻结的交付包
PROJ <- "/home/gao/projects_2026M7/26_Ellen_MTTH_junction_sequences"
PACKAGES <- file.path(PROJ, c("custom_research_report_supplementary_MTTH_20260804",
                              "custom_research_report_supplementary_RAGH_CD1A_20260804"))

CONTIGS  <- c("TG_MTTH", "TG_RAGH", "TG_CD1A")
SAMPLES  <- c("MTTH_284", "MTTH_412", "MTTH_524", "RAGH_153", "RAGH_273", "CD1A_B125")
JIDS     <- c("J1_5p", "J2_5p", "J2_3p", "J1_3p")
SEG_ROLES <- c("mouse genomic flank", "homology arm (mouse sequence)", "human insert")
SHADE    <- DEFAULT_SHADE

## ---------------------------------------------------------------------------
## 配色
## ---------------------------------------------------------------------------
## 下面板：**沿用已批准的默认**，一个色都不动（新图不重新搜色，见 palette_priority.R）。
SAMPLE_FILLS <- DEFAULT_B_SAMPLE_FILLS

## 上面板：每条品系一个色相家族。索引不是拍脑袋定的 —— 在 9-class 色板里穷举全部 3-子集，
## 要求：白底对比度 1.2-10（不太浅、不近黑）、**家族内**两两 >= 0.13、与 6 个样本色和白底
## >= 0.13；再从通过的家族里挑"最弱环节最大"的三家族组合。
##
## 排除集是**分面板**给的，不是一刀切：J1 分组的浅灰底纹 #F2F2F2 只出现在下面板，
## 柱子压在它上面，所以**柱子**必须避开它（实测最小 0.226）；上面板的区段画在白底上，
## 与底纹从不相邻，因此不受它约束。一刀切会白白废掉 Blues/Greys/PuBu 这几个家族
## （Blues 最浅的 #C6DBEF 距底纹 0.101），把 MTTH 逼进 BuPu —— 那套家族内只有 0.151，
## 出图后肉眼可见 HA 与 human insert 两块紫色分不清。
##
## 结果 Blues / YlGn / YlOrRd：家族间最小 0.184，家族内最小 0.222，是所有可行组合里
## 最弱环节最大的一个（次优 BuPu/YlGn/YlOrRd 家族内只有 0.151）。
SEG_FAMILY_SPEC <- list(
  TG_MTTH = list(palette = "Blues",  idx = c(3, 6, 8)),   # 蓝
  TG_RAGH = list(palette = "YlGn",   idx = c(3, 5, 7)),   # 黄绿
  TG_CD1A = list(palette = "YlOrRd", idx = c(4, 6, 8)))   # 橙红

## 家族内固定 浅 -> 深 = 侧翼 -> HA -> 人源插入：侧翼是中性背景，人源插入是主角。
SEG_FAMILY <- lapply(SEG_FAMILY_SPEC, function(s)
  stats::setNames(toupper(brewer.pal(9, s$palette)[s$idx]), SEG_ROLES))
names(SEG_FAMILY) <- CONTIGS

## 接头线条/文字：三个面板语义相同 -> 三个面板必须共用同一套（这一条仍然遵守）。
##
## 但**不能沿用已批准默认的红/蓝**：那两个色是给"区段用灰/橙/绿"的图配的。这张图把
## 蓝和红分给了 MTTH 与 CD1A 两个家族，红线压在 CD1A 的 #FC4E2A / #BD0026 上距离只有
## 0.146 / 0.102，**线在色块里直接看不见了**（第一版出图实测，肉眼确认）。
## 按 STROKE_COLORS 的优先顺序往下找第一对可用的：
##   黑    —— 不能用：区段边框本来就是黑色，而 J2 恰好落在区段边界上，会和边框混成一条；
##   正红  —— 被 CD1A 家族占了；
##   亮蓝  —— 被 MTTH 家族占了；
##   深绿  —— 被 RAGH 家族占了；
##   咖啡 #8C510A、深紫 #762A83 —— 可用，且两者相距 0.296，与全部 9 个区段色 >= 0.219。
JUNC <- c("J2: human/mouse junction (sequence-detectable)"  = STROKE_COLORS[5],  # 咖啡 实线
          "J1: HA/endogenous boundary (seamless by design)" = STROKE_COLORS[6])  # 深紫 虚线
JUNC_LTY <- c("J2: human/mouse junction (sequence-detectable)"  = "solid",
              "J1: HA/endogenous boundary (seamless by design)" = "dashed")

cat("\n[配色优先级验证] 三套区段配色 —— 全部来自第 1 级 ColorBrewer\n")
for (ct in CONTIGS) {
  cat(sprintf("  %-8s %-7s 9class[%s]  %s\n", ct, SEG_FAMILY_SPEC[[ct]]$palette,
              paste(SEG_FAMILY_SPEC[[ct]]$idx, collapse = ","),
              paste(SEG_FAMILY[[ct]], collapse = " ")))
}
cat(sprintf("  下面板 6 个样本色沿用已批准默认: %s\n", paste(SAMPLE_FILLS, collapse = " ")))
cat("  -> 实际动用的级别: 区段=第1级；样本=已批准默认(第1级3色+第2级3色)；第 3 级未动用\n")

## --- 出图前的硬断言 ---------------------------------------------------------
for (ct in CONTIGS) {
  assert_visible_on_white(SEG_FAMILY[[ct]], role = "fill")
  assert_fill_not_near_black(SEG_FAMILY[[ct]])
}
assert_visible_on_white(SAMPLE_FILLS, role = "fill")
assert_fill_not_near_black(SAMPLE_FILLS)
assert_visible_on_white(JUNC, role = "line")
assert_no_yellow_text(JUNC)
## 15 个色块两两不撞：三个区段家族彼此不撞，且都不撞样本色。
## （这里**不能**用 assert_shared_palette —— 见文件头，本图是有意让三套不同。）
assert_no_palette_collision(c(
  stats::setNames(lapply(CONTIGS, function(ct) unname(SEG_FAMILY[[ct]])),
                  paste0("top panel FILLS: ", CONTIGS, " segments")),
  list("bottom panel FILLS: sample" = SAMPLE_FILLS)))
## 底纹是背景不是数据填充，不进 assert_no_palette_collision；单独查一遍距离。
## **只查柱子** —— 底纹只出现在下面板，柱子压在它上面；上面板的区段画在白底上，
## 与底纹从不相邻（见上文 SEG_FAMILY_SPEC 的说明）。
.all_fills <- c(unlist(SEG_FAMILY, use.names = FALSE), SAMPLE_FILLS)
.d_shade <- vapply(SAMPLE_FILLS, function(x) .rgb_distance(x, SHADE), numeric(1))
if (min(.d_shade) < 0.13) {
  stop(sprintf("柱子填充色 %s 距分组底纹 %s 仅 %.3f —— 柱子会和底纹糊在一起",
               SAMPLE_FILLS[which.min(.d_shade)], SHADE, min(.d_shade)))
}
cat(sprintf("  15 个色块两两最小距离 %.3f；柱子距底纹 %s 最小 %.3f（门槛 0.13）\n",
            min(utils::combn(.all_fills, 2, function(p) .rgb_distance(p[1], p[2]))),
            SHADE, min(.d_shade)))

#' 画在色块**上面**的线条，必须与它压住的每一个填充色分得开。
#'
#' 这和 assert_no_palette_collision() 不是一回事：那条管的是"语义会不会被读混"，
#' 线条与色块属不同角色，本来就不进那条。**本条管的是"还看不看得见"** ——
#' 一根线压在与它同色的色块上会直接消失，而所有既有断言都不会报错。
#' 触发本条的实例：默认的 J2 正红 #E41A1C 压在 CD1A 的 #BD0026 上距离 0.102，
#' 出图后那一段线在色块里彻底看不见（只有肉眼看图才发现，所以补成断言）。
assert_strokes_visible_over_fills <- function(strokes, fills, min_distance = 0.13) {
  for (s in strokes) for (f in fills) {
    d <- .rgb_distance(s, f)
    if (d < min_distance) {
      stop(sprintf(paste0("线条色 %s 压在填充色 %s 上，距离 %.3f < %.2f —— ",
                          "线穿过该色块的那一段会看不见。换一个笔画色（STROKE_COLORS 里按优先序往下找）。"),
                   s, f, d, min_distance))
    }
  }
  invisible(TRUE)
}
## 接头竖线是从色块中间穿过去的，必须对 9 个区段色都可见。
assert_strokes_visible_over_fills(JUNC, unlist(SEG_FAMILY, use.names = FALSE))
cat(sprintf("  接头线 %s 距 9 个区段色最小 %.3f（门槛 0.13）\n",
            paste(JUNC, collapse = "/"),
            min(outer(unname(JUNC), unlist(SEG_FAMILY, use.names = FALSE),
                      Vectorize(function(a, b) .rgb_distance(a, b))))))

NOTE <- paste0(
  "COLOUR SCHEME (deliberate, and different from the companion figure): each structure panel uses its OWN colour family\n",
  "— TG_MTTH blue, TG_RAGH yellow-green, TG_CD1A orange-red. Within every family the order is fixed: light = mouse\n",
  "flank, mid = homology arm, dark = human insert. Read each panel against ITS OWN legend; colours are NOT comparable\n",
  "between panels. Bar colours in the bottom panel are samples and are unrelated to all of the segment colours above.\n\n",
  "The four bar groups are junction CLASSES, not one shared coordinate: each sample carries its own targeted allele, so\n",
  "counts are compared within a class, never between loci. The three structure panels are drawn on INDEPENDENT x scales\n",
  "(254,010 / 38,566 / 185,655 bp) and their widths are therefore not comparable.\n\n",
  "Shaded groups (J1): the homology arm is identical to the endogenous locus, so these reads cannot be assigned to one or\n",
  "the other — the aligner splits them arbitrarily and reports MAPQ 0. J1 counts are therefore NOT a measure of evidence\n",
  "strength and are not comparable with J2 counts. Only J2 reads (MAPQ 60) uniquely identify the targeted allele.")

read_all <- function(rel) {
  do.call(rbind, lapply(file.path(PACKAGES, rel), read.delim,
                        sep = "\t", stringsAsFactors = FALSE, check.names = FALSE))
}

## ---------------------------------------------------------------------------
## 上面板：线性结构 + 接头竖线。每个面板带自己的区段图例（这是防误读的关键）。
## ---------------------------------------------------------------------------
panel_structure <- function(contig, rows) {
  seg  <- SEG_FAMILY[[contig]]
  clen <- rows$contig_len[1]
  rng <- function(s) as.integer(strsplit(s, "-", fixed = TRUE)[[1]])
  ha5 <- rng(rows$ha_5p[1]); ha3 <- rng(rows$ha_3p[1]); ins <- rng(rows$human_insert[1])

  blocks <- data.frame(
    xmin = c(1, ha5[1], ins[1], ha3[1], ha3[2] + 1),
    xmax = c(ha5[1] - 1, ha5[2], ins[2], ha3[2], clen),
    seg  = factor(SEG_ROLES[c(1, 2, 3, 2, 1)], levels = SEG_ROLES))
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
                     colour = type, linetype = type), linewidth = 0.8,
                 show.legend = FALSE) +
    geom_text(data = jl,
              aes(x = pos + dx, y = ytop, label = jid, hjust = hjust, colour = type),
              vjust = -0.3, fontface = "bold", size = 3.2, show.legend = FALSE) +
    ## 位置数字放在色块下方、x 轴之上的空白带里
    geom_text(data = jl,
              aes(x = pos + dx, y = 0.28, label = format(pos, big.mark = ","), colour = type),
              angle = 90, hjust = 1, size = 2.6, show.legend = FALSE) +
    ## 图例标题写死品系名 —— 读者一眼看到"这套颜色只属于这个面板"。
    scale_fill_manual(values = seg, drop = FALSE,
                      name = paste0(contig, " segments\n(this panel only)")) +
    scale_colour_manual(values = JUNC, guide = "none") +
    scale_linetype_manual(values = JUNC_LTY, guide = "none") +
    scale_x_continuous(limits = c(-clen * 0.03, clen * 1.03), expand = c(0, 0)) +
    ## ggplot2 会把超出 panel 的文字**直接裁掉**（matplotlib 默认不裁）：旋转 90° 的 7 位
    ## 坐标（如 222,842）空间不足时会被截成 "22,842" —— 图上出现错误数字，是 correctness
    ## bug 而非排版瑕疵。两道保险：y 下限留出空间 + clip="off" 从结构上杜绝截断。
    scale_y_continuous(limits = c(-0.22, 1.25), expand = c(0, 0)) +
    coord_cartesian(clip = "off") +
    labs(x = "coordinate along the targeted allele (bp)", y = NULL,
         title = sprintf("%s  —  targeted allele structure and junction positions  (%s bp)",
                         contig, format(clen, big.mark = ","))) +
    guides(fill = guide_legend(ncol = 1, order = 1)) +
    theme_pub(font_size = 12) +
    ## 图例贴在**自己这个面板的右侧**：物理位置就是"这套颜色属于谁"的最强提示。
    ## 三个面板结构完全一致（都有标题/x 轴标题/右侧图例），行高才会相同 ——
    ## 某一行多分到高度会让那一条色带画得更粗，读者会以为粗细有含义。
    theme(axis.line.y = element_blank(), axis.ticks.y = element_blank(),
          axis.text.y = element_blank(),
          plot.title = element_text(hjust = 0.5, size = 11),
          legend.position = "right", legend.justification = "center",
          ## lineheight 必须放宽：默认行距下 "TG_MTTH" 的下划线会顶到第二行
          ## "(this panel only)" 的 i 上面，看着像个变音符号。
          legend.title = element_text(size = 9, face = "bold", lineheight = 1.3),
          legend.text = element_text(size = 8.5))
}

## 只画 J1/J2 线条图例的一行（三个面板语义相同 -> 只画一次）。
legend_row <- function() {
  dj <- data.frame(x = 1, type = factor(names(JUNC), levels = names(JUNC)))
  ggplot() +
    geom_segment(data = dj, aes(x = x, xend = x, y = NA_real_, yend = NA_real_,
                                colour = type, linetype = type),
                 linewidth = 0.8, na.rm = TRUE) +
    ## 图例项来自 scale 的 levels，不来自画出来的数据 —— y = NA 保证这一行什么都不画。
    scale_colour_manual(values = JUNC, name = NULL, drop = FALSE) +
    scale_linetype_manual(values = JUNC_LTY, name = NULL, drop = FALSE) +
    guides(colour = guide_legend(nrow = 1), linetype = guide_legend(nrow = 1)) +
    theme_void(base_size = 12) +
    theme(legend.position = "top", legend.box = "horizontal",
          legend.text = element_text(size = 9),
          legend.margin = margin(t = 0, b = 0))
}

## ---------------------------------------------------------------------------
## 下面板：6 个样本合并的跨接头读段数（配色 = 已批准默认，与另一张图完全一致）
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
         title = paste0("Junction-spanning read support per sample, all three targeted alleles combined ",
                        "(bar colours = samples; a fourth colour family, unrelated to any of the three above)"),
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

  tops <- lapply(CONTIGS, function(contig) {
    rows <- coords[coords$contig == contig, ]
    rows <- rows[match(JIDS, rows$junction_id), ]
    panel_structure(contig, rows)
  })
  names(tops) <- CONTIGS
  bot <- panel_support(spanning)

  ## --- 出图后、写盘前的自检 -------------------------------------------------
  ## 1) 从**画出来的图形对象**反查每个面板实际用了哪套颜色（不信任常量被正确引用），
  ##    并确认三套确实**互不相同**（本图的立论就在这一点上）。
  drawn <- lapply(CONTIGS, function(ct) {
    b    <- ggplot_build(tops[[ct]])
    segs <- as.character(b$plot$layers[[1]]$data$seg)
    m    <- stats::setNames(toupper(b$data[[1]]$fill), segs)
    m    <- m[!duplicated(names(m))][SEG_ROLES]
    if (anyNA(m)) stop(sprintf("%s: 上面板缺了区段 %s", ct,
                               paste(SEG_ROLES[is.na(m)], collapse = ", ")))
    m
  })
  names(drawn) <- CONTIGS
  for (i in seq_along(CONTIGS)) {
    if (!identical(unname(drawn[[i]]), unname(toupper(SEG_FAMILY[[CONTIGS[i]]])))) {
      stop(sprintf("%s: 画出来的区段色与分配的不一致", CONTIGS[i]))
    }
  }
  for (p in utils::combn(CONTIGS, 2, simplify = FALSE)) {
    if (length(intersect(drawn[[p[1]]], drawn[[p[2]]]))) {
      stop(sprintf("%s 与 %s 画出了相同的区段色 —— 本图要求三套互不相同", p[1], p[2]))
    }
  }

  ## 2) 语义不同的填充族两两不撞（用**渲染后**的颜色再查一遍）。
  bot_build <- ggplot_build(bot)
  bars <- bot_build$data[[2]]   # 1 = annotate("rect") 底纹, 2 = geom_col, 3 = geom_text
  assert_no_palette_collision(c(
    stats::setNames(lapply(CONTIGS, function(ct) unname(drawn[[ct]])),
                    paste0(CONTIGS, " segments as drawn")),
    list("sample bars as drawn" = toupper(unique(bars$fill)))))

  ## 3) 柱子数 = 样本数 × 接头数；填充色就是已批准的默认 6 色；数值标签一一对应。
  expected <- length(SAMPLES) * length(JIDS)
  if (nrow(bars) != expected) {
    stop(sprintf("期望 %d 根柱子，实际画出 %d 根", expected, nrow(bars)))
  }
  if (!setequal(toupper(unique(bars$fill)), toupper(SAMPLE_FILLS))) {
    stop("柱子实际填充色与已批准的默认 6 色不一致")
  }
  if (nrow(bot_build$data[[3]]) != expected) stop("柱顶数值标签数量与柱子数不符")
  ## 4) 每个上面板必须画出 4 条接头竖线。
  for (ct in CONTIGS) {
    nseg <- nrow(ggplot_build(tops[[ct]])$data[[2]])
    if (nseg != length(JIDS)) {
      stop(sprintf("%s: 期望 %d 条接头竖线，实际 %d 条", ct, length(JIDS), nseg))
    }
  }

  ## --- 组图 -----------------------------------------------------------------
  ## 五行一次排完，不做嵌套 patchwork：`(p1/p2/p3)` 已经是一个 patchwork，
  ## 再 `/ bot` 是往同一层**追加元素**（不是嵌套），此时 heights 必须给满行数。
  fig <- tops[[1]] / tops[[2]] / tops[[3]] / legend_row() / bot +
    plot_layout(heights = c(1, 1, 1, 0.22, 3.1)) +
    plot_annotation(
      title = paste0("Three targeted alleles, one colour family each — structure (top) ",
                     "and junction-spanning read support (bottom)"),
      theme = theme(plot.title = element_text(size = 13, hjust = 0.5,
                                              margin = margin(b = 8))))

  dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
  finalize_figure(fig, file.path(OUT, STEM),
                  formats = c("png", "pdf"), dpi = 300, width = 14, height = 16)
  cat(sprintf("\n[OK] 3 families x 3 segments + 6 samples = %d fills; %d bars -> %s\n",
              length(.all_fills), nrow(bars),
              file.path(normalizePath(OUT), paste0(STEM, ".png/.pdf"))))
}

main()
