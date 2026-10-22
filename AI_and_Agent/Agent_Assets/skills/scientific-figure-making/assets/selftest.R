#!/usr/bin/env Rscript
## Self-test for pubfig.R. Doubles as a runnable example.
##
##     Rscript selftest.R [outdir]
##
## Exercises theme_pub(), finalize_figure() and every assertion in BOTH
## directions — the clean case must pass, the broken case must stop().

args <- commandArgs(trailingOnly = TRUE)
OUT <- if (length(args)) args[1] else "pubfig_selftest_R"

this_file <- normalizePath(sub("^--file=", "",
  grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
source(file.path(dirname(this_file), "pubfig.R"))

FAILS <- character(0)

expect_error <- function(what, expr) {
  res <- tryCatch({ force(expr); NULL }, error = function(e) conditionMessage(e))
  if (is.null(res)) {
    FAILS <<- c(FAILS, what)
    cat(sprintf("  FAIL %s did NOT stop()\n", what))
  } else {
    cat(sprintf("  ok   %s stopped: %.75s...\n", what, res))
  }
}

expect_ok <- function(what, expr) {
  res <- tryCatch({ force(expr); NULL }, error = function(e) conditionMessage(e))
  if (is.null(res)) cat(sprintf("  ok   %s\n", what))
  else { FAILS <<- c(FAILS, paste(what, res)); cat(sprintf("  FAIL %s: %s\n", what, res)) }
}

cat("== colour discipline ==\n")

expect_ok("disjoint families pass", assert_no_palette_collision(list(
  "top: genotype" = PALETTE_FAMILIES$cool[1:3],
  "bottom: timepoint" = PALETTE_FAMILIES$warm[1:3])))

## ggplot2's default hue scale restarts per plot -> identical colours.
default3 <- scales::hue_pal()(3)
expect_error("default hue-scale reuse caught", assert_no_palette_collision(list(
  "top: genotype" = default3, "bottom: timepoint" = default3)))

expect_error("near-collision caught", assert_no_palette_collision(list(
  "a: region" = "#0F4D92", "b: batch" = "#104E93")))

shared <- c(CTRL = unname(PALETTE["neutral"]), TEST = unname(PALETTE["blue_main"]))
expect_ok("identical maps pass",
          assert_shared_palette(list("panel A" = shared, "panel B" = shared)))
expect_error("recoloured level caught", assert_shared_palette(list(
  "panel A" = shared,
  "panel B" = c(CTRL = unname(PALETTE["neutral"]), TEST = unname(PALETTE["red_strong"])))))

expect_ok("cyan/magenta pass",
          assert_visible_on_white(unname(PALETTE[c("cyan", "magenta")])))
## Set1's 6th colour is pale yellow — the exact trap this rule exists for.
expect_error("Set1 pale yellow caught", assert_visible_on_white("#FFFF33", role = "point"))
expect_ok("pale fill allowed behind an edge",
          assert_visible_on_white(unname(PALETTE["green_2"]), role = "fill"))

## Large fills must not be near-black (heavy, ugly blot in print and on slides).
expect_ok("grey ramp passes", assert_fill_not_near_black(PALETTE_FAMILIES$grey))
expect_error("near-black fill caught", assert_fill_not_near_black(unname(PALETTE["ink"])))
expect_ok("dark saturated colour still allowed",
          assert_fill_not_near_black(unname(PALETTE["blue_main"])))

## Text is never yellow — the check is on hue, so dark yellows fail too.
expect_error("pale yellow text caught", assert_no_yellow_text("#FFFF33"))
expect_error("gold text caught", assert_no_yellow_text(unname(PALETTE["highlight"])))
expect_error("DARK goldenrod text caught (contrast alone would pass)",
             assert_no_yellow_text("#B8860B"))
expect_ok("orange/green/black text allowed",
          assert_no_yellow_text(c("#F58518", unname(PALETTE["green_3"]), "#000000")))
cat(sprintf("  contrast_vs_white('#B8860B') = %.2f (passes contrast, still rejected as yellow)\n",
            contrast_vs_white("#B8860B")))
cat(sprintf("  contrast_vs_white('#FFFF33') = %.2f\n", contrast_vs_white("#FFFF33")))

cat("\n== figures ==\n")

df <- data.frame(
  metric = rep(c("Metric A", "Metric B", "Metric C", "Metric D"), each = 3),
  method = rep(c("Ours", "Baseline X", "Baseline Y"), times = 4),
  score  = c(.92, .85, .78, .88, .82, .80, .85, .88, .82, .90, .84, .79)
)
method_colors <- c("Ours" = unname(PALETTE["blue_main"]),
                   "Baseline X" = unname(PALETTE["green_3"]),
                   "Baseline Y" = unname(PALETTE["red_strong"]))
assert_visible_on_white(method_colors, role = "fill")

p_bar <- ggplot(df, aes(metric, score, fill = method)) +
  geom_col(position = position_dodge(width = .8), width = .7,
           colour = "black", linewidth = .5) +
  scale_fill_manual(values = method_colors) +
  coord_cartesian(ylim = c(.75, .95)) +
  labs(x = NULL, y = "Score", fill = NULL) +
  theme_pub(font_size = 14) + theme_legend_outside("top")
expect_ok("grouped bar saved",
          finalize_figure(p_bar, file.path(OUT, "bars"), formats = "png",
                          dpi = 150, width = 8, height = 4))

## Silent point-drop guard: 12 groups mapped to shape drops everything past 6.
set.seed(42)
pca <- data.frame(PC1 = rnorm(12), PC2 = rnorm(12),
                  design_group = factor(paste0("g", 1:12)),
                  role = factor(rep(c("CTRL", "TEST"), 6)))
p_ok <- ggplot(pca, aes(PC1, PC2, colour = design_group, shape = role)) +
  geom_point(size = 3) + theme_pub(font_size = 14)
expect_ok("12/12 points drawn with shape=role (2 levels)", assert_points_drawn(p_ok, 12))

p_bad <- suppressWarnings(ggplot(pca, aes(PC1, PC2, shape = design_group)) +
  geom_point(size = 3) + theme_pub(font_size = 14))
expect_error("shape with 12 levels silently drops points",
             suppressWarnings(assert_points_drawn(p_bad, 12)))

## Composition as a ranked bar, not a pie — 26% vs 29% is unreadable as angles.
p_comp <- composition_bar_instead_of_pie(
  c("mapped", "unmapped", "duplicate", "low MAPQ"), c(29, 26, 25, 20), font_size = 14)
expect_ok("composition bar (pie replacement) saved",
          finalize_figure(p_comp, file.path(OUT, "composition_bar"), formats = "png",
                          dpi = 150, width = 7, height = 4))

cat("\n== guards ==\n")
expect_error("bad format rejected",
             finalize_figure(p_bar, file.path(OUT, "x"), formats = "gif"))

## 2026-09-12 吸收自 figure-style 的三条 —— 每条两个方向都必须对：
## 干净的图不许报（误报率高的闸门早晚被关掉），做坏的图必须报。
cat("\n== figure-style 吸收的三条（种子错误注入）==\n")
suppressPackageStartupMessages(library(ggplot2))
df <- data.frame(x = c("a", "b", "c"), y = c(3, 5, 9))

## a. 标注上限 §2.2
p_ok <- ggplot(df, aes(x, y)) + geom_col() +
  geom_text(aes(label = y), vjust = -0.4)            # 3 条标注，未超
expect_ok("label ceiling: 3 annotations pass", assert_label_ceiling(p_ok))
p_bad <- p_ok + geom_text(aes(label = paste0("n=", y)), vjust = 1.5) +
  geom_text(aes(label = x), vjust = 3)               # 共 9 条，超
expect_error("label ceiling: 9 annotations", assert_label_ceiling(p_bad))

## b. log 轴填充柱 §3.3
expect_ok("bars on a linear axis pass",
          assert_no_filled_bars_on_log_axis(ggplot(df, aes(x, y)) + geom_col()))
expect_error("filled bars on log axis",
             assert_no_filled_bars_on_log_axis(
               ggplot(df, aes(x, y)) + geom_col() + scale_y_log10()))

## c. 断轴缺口内不得画东西 §3.2
p_line_out <- ggplot(df, aes(x, y)) + geom_point() + geom_hline(yintercept = 8)
expect_ok("reference line outside the break passes",
          assert_nothing_in_axis_break(p_line_out, c(3, 6), axis = "y"))
p_line_in <- ggplot(df, aes(x, y)) + geom_point() + geom_hline(yintercept = 4.5)
expect_error("reference line inside the axis break",
             assert_nothing_in_axis_break(p_line_in, c(3, 6), axis = "y"))

## d. 渲染后几何检查 §9.1 —— 假阳性这一侧比真阳性更重要
p_clean <- ggplot(df, aes(x, y)) + geom_col() + theme_pub(font_size = 11) +
  labs(title = "clean panel", x = "sample", y = "value")
expect_ok("clean figure: no text collisions", assert_no_text_collisions(p_clean))
p_collide <- p_clean +
  annotate("text", x = 2, y = 5, label = "AAAAAAAAAAAAAAAAAAAAAAAA", size = 14) +
  annotate("text", x = 2, y = 5, label = "BBBBBBBBBBBBBBBBBBBBBBBB", size = 14)
expect_error("two texts stacked on the same point",
             assert_no_text_collisions(p_collide))

## e. panel_crops 是工具不是断言 —— 验它给出每个 panel 一项
pc <- panel_crops(ggplot(df, aes(x, y)) + geom_col() + facet_wrap(~x))
if (length(pc) == 3L && all(vapply(pc, function(v) all(c("t","l","b","r") %in% names(v)), logical(1)))) {
  cat(sprintf("  ok   panel_crops returned %d panel positions\n", length(pc)))
} else {
  FAILS <- c(FAILS, "panel_crops")
  cat(sprintf("  FAIL panel_crops returned %d entries\n", length(pc)))
}

cat("\n")
if (length(FAILS)) {
  cat(sprintf("SELFTEST FAILED (%d): %s\n", length(FAILS), paste(FAILS, collapse = "; ")))
  quit(status = 1)
}
cat(sprintf("SELFTEST PASSED — figures in %s\n", normalizePath(OUT)))
