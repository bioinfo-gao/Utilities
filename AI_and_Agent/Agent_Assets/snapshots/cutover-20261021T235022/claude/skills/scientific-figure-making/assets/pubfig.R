## pubfig.R — publication-style ggplot2 theme + colour-discipline assertions.
##
## R counterpart of pubfig.py. Same palette, same rules, same failure modes:
## ggplot2 restarts its default hue scale on every plot, so two panels that
## encode different variables silently receive the same colours and get read
## as a top-to-bottom comparison.
##
## Assertions stop(); they do not warn.
##
## Usage:  source("<this dir>/pubfig.R")

suppressPackageStartupMessages({
  library(ggplot2)
  library(RColorBrewer)
})

# --------------------------------------------------------------------------
# Palette
# --------------------------------------------------------------------------

PALETTE <- c(
  blue_main      = "#0F4D92",
  blue_secondary = "#3775BA",
  green_1        = "#DDF3DE",
  green_2        = "#AADCA9",
  green_3        = "#8BCF8B",
  red_1          = "#F6CFCB",
  red_2          = "#E9A6A1",
  red_strong     = "#B64342",
  neutral        = "#CFCECE",
  grey_mid       = "#767676",
  grey_dark      = "#4D4D4D",
  ink            = "#272727",
  ## Publication-safe grey ramp for large FILLS (light -> dark). `ink` and
  ## `grey_dark` are for TEXT and LINES only — see assert_fill_not_near_black().
  ## Light end stops at #ABABAB, not lighter: a paler first bar stops being
  ## separable from a white page or a light shaded band behind it.
  grey_pale      = "#ABABAB",
  grey_soft      = "#828282",
  grey_deep      = "#5A5A5A",
  highlight      = "#FFD700",
  teal           = "#42949E",
  violet         = "#9A4D8E",
  magenta        = "#C71585",
  cyan           = "#17BECF"
)

DEFAULT_COLORS <- unname(PALETTE[c("blue_main", "green_3", "red_strong",
                                   "teal", "violet", "neutral")])

## Visually disjoint families. Hand a different family to each panel whose
## colours mean something different from its neighbours'.
## Ordered darkest-first: truncating to the first N keeps the line/point-safe
## colours; pale tail entries are fill-only and need a black edge on white.
PALETTE_FAMILIES <- list(
  cool  = unname(PALETTE[c("blue_main", "blue_secondary", "teal", "cyan")]),
  warm  = unname(PALETTE[c("red_strong", "red_2", "magenta", "highlight")]),
  green = unname(PALETTE[c("green_3", "green_2", "green_1")]),
  ## Grey is the exception to darkest-first: it runs LIGHT -> DARK and stops at a
  ## mid grey. A large solid near-black bar is a publication/presentation no-no.
  grey  = unname(PALETTE[c("grey_pale", "grey_soft", "grey_deep")])
)

# --------------------------------------------------------------------------
# Theme
# --------------------------------------------------------------------------

#' Publication theme: no top/right spines, frameless legend, sans-serif.
#' @param font_size base size (16 default; 24 for large bar panels).
#' @param axes_linewidth spine width (2.5 default; 3 big bars, 2 compact).
theme_pub <- function(font_size = 16, axes_linewidth = 2.5, base_family = "sans") {
  theme_classic(base_size = font_size, base_family = base_family) +
    theme(
      axis.line        = element_line(linewidth = axes_linewidth / 2.5, colour = "black"),
      axis.ticks       = element_line(linewidth = axes_linewidth / 2.5, colour = "black"),
      axis.text        = element_text(colour = "black", size = font_size * 0.9),
      axis.title       = element_text(colour = "black", size = font_size),
      legend.key       = element_blank(),
      legend.background = element_blank(),
      legend.title     = element_text(size = font_size * 0.9),
      legend.text      = element_text(size = font_size * 0.9),
      strip.background = element_blank(),
      strip.text       = element_text(size = font_size, colour = "black"),
      plot.background  = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA)
    )
}

#' Legend outside the panel. ggplot2's default "right" is already outside;
#' this guards against legend.position = "inside", which covers the data.
theme_legend_outside <- function(position = c("top", "right", "bottom", "left")) {
  position <- match.arg(position)
  theme(legend.position = position, legend.justification = "left")
}

# --------------------------------------------------------------------------
# Colour discipline
# --------------------------------------------------------------------------

.norm_hex <- function(colors) {
  tolower(apply(grDevices::col2rgb(colors), 2, function(v)
    grDevices::rgb(v[1], v[2], v[3], maxColorValue = 255)))
}

#' WCAG relative luminance, 0-1.
relative_luminance <- function(color) {
  v <- grDevices::col2rgb(color)[, 1] / 255
  lin <- ifelse(v <= 0.03928, v / 12.92, ((v + 0.055) / 1.055)^2.4)
  sum(c(0.2126, 0.7152, 0.0722) * lin)
}

#' WCAG contrast ratio against a white background (1-21).
contrast_vs_white <- function(color) 1.05 / (relative_luminance(color) + 0.05)

.rgb_distance <- function(a, b) {
  va <- grDevices::col2rgb(a)[, 1] / 255
  vb <- grDevices::col2rgb(b)[, 1] / 255
  sqrt(2 * (va[1] - vb[1])^2 + 4 * (va[2] - vb[2])^2 + 3 * (va[3] - vb[3])^2) / 3
}

#' Panels whose colours mean DIFFERENT things must not share colours.
#'
#' Pass **fills only**. The constraint applies within one role: what a reader
#' compares across panels is filled area (bars, rects, boxes). A thin line or a
#' text label sharing a hue with some bar is a different channel and is not read
#' as "same meaning" — folding line/label colours into the exclusion list burns
#' half the usable hue space for nothing. When hues run short, set label text to
#' black rather than hunting for another hue.
#'
#' @param panels named list: panel label -> character vector of FILL colours.
#'   Include ONLY panels whose colour semantics differ from each other.
#' @param min_distance colours closer than this count as a collision even when
#'   the hex codes differ.
assert_no_palette_collision <- function(panels, min_distance = 0.10) {
  nm <- names(panels)
  if (is.null(nm) || any(nm == "")) stop("panels must be a NAMED list")
  hexes <- lapply(panels, .norm_hex)
  if (length(hexes) < 2L) return(invisible(TRUE))
  for (i in seq_len(length(hexes) - 1L)) {
    for (j in seq(i + 1L, length(hexes))) {
      shared <- intersect(hexes[[i]], hexes[[j]])
      if (length(shared)) {
        stop(sprintf(
          "palette collision: panels '%s' and '%s' encode different variables but share colour(s) %s. Give each panel its own colour family (PALETTE_FAMILIES) and state in each legend what its colours mean.",
          nm[i], nm[j], paste(shared, collapse = ", ")))
      }
      for (a in unique(hexes[[i]])) for (b in unique(hexes[[j]])) {
        d <- .rgb_distance(a, b)
        if (d < min_distance) {
          stop(sprintf(
            "near-collision: panels '%s' and '%s' encode different variables but use visually indistinguishable colours %s vs %s (distance %.3f < %.2f). Pick disjoint colour families.",
            nm[i], nm[j], a, b, d, min_distance))
        }
      }
    }
  }
  invisible(TRUE)
}

#' Panels whose colours mean the SAME thing must map level -> colour identically.
#'
#' @param panels named list: panel label -> NAMED character vector (level -> colour).
assert_shared_palette <- function(panels) {
  if (length(panels) < 2L) return(invisible(TRUE))
  nm <- names(panels)
  ref <- panels[[1]]
  ref_hex <- stats::setNames(.norm_hex(ref), names(ref))
  ref_hex <- ref_hex[order(names(ref_hex))]
  for (k in seq(2L, length(panels))) {
    this <- panels[[k]]
    this_hex <- stats::setNames(.norm_hex(this), names(this))
    this_hex <- this_hex[order(names(this_hex))]
    if (!identical(ref_hex, this_hex)) {
      stop(sprintf(
        "panels '%s' and '%s' encode the same variable but their colour maps differ. Build ONE named vector and pass it to scale_*_manual() in both.",
        nm[1], nm[k]))
    }
  }
  invisible(TRUE)
}

#' Colours used for lines/points/text must survive a white background.
#'
#' Pale yellow (#FFFF33, ColorBrewer Set1's 6th colour) has ~1.07 contrast on
#' white: both the points and any geom_text_repel label inheriting that colour
#' are invisible. Use cyan #17BECF or magenta #C71585 instead.
#'
#' @param role "line" / "point" / "text" (strict) or "fill" (relaxed — pale
#'   fills are fine behind a black bar edge).
assert_visible_on_white <- function(colors, role = "line", min_contrast = 1.5) {
  threshold <- if (identical(role, "fill")) 1.1 else min_contrast
  ratios <- vapply(colors, contrast_vs_white, numeric(1))
  bad <- ratios < threshold
  if (any(bad)) {
    stop(sprintf(
      "colour(s) too pale for role='%s' on white: %s (need contrast >= %.2f). Pale yellow is the usual culprit; swap in cyan #17BECF or magenta #C71585, and force text labels to colour = 'black'.",
      role,
      paste(sprintf("%s (%.2f)", .norm_hex(colors[bad]), ratios[bad]), collapse = ", "),
      threshold))
  }
  invisible(TRUE)
}

## Preferred colours for LINES and TEXT, in priority order. Take them from the
## top; only reach past the end of this list when you have used all six.
##
## These are the battle-tested, unambiguously legible stroke colours — deep
## enough that a one-pixel line or a small label still registers, and spread far
## enough apart in hue that no two are ever confused (minimum pairwise distance
## 0.221, better separated than any fill palette). Contrast on white runs
## 4.7-21.0, all well clear of the 1.5 line/text floor.
##
## Black first: it never fails and costs no hue. It is also the fallback whenever
## colours run short — a black label is never wrong.
##
## ASSUMED BACKGROUND: white or light. That covers the overwhelming majority of
## figures, and every check in this module (contrast_vs_white,
## assert_visible_on_white) is written for it. On the occasional dark background
## the logic mirrors: white and light monochrome strokes take over, and these six
## go unreadable. There is no dark-background checker here — if you build one,
## invert the luminance test rather than reusing these values.
STROKE_COLORS <- c(
  "#000000",  # black       contrast 21.00
  "#E41A1C",  # true red    contrast  4.71
  "#1F78B4",  # bright blue contrast  4.77
  "#006D2C",  # dark green  contrast  6.51
  "#8C510A",  # coffee      contrast  6.37
  "#762A83"   # dark purple contrast  8.64
)

## Second tier for lines/text once STROKE_COLORS is exhausted: the polarised dark
## ends of the diverging ColorBrewer palettes, via brewer("PRGn", 2) etc.
## They overlap tier 1 slightly (#00441B sits 0.087 from #006D2C), so check what
## you already used before drawing from here.
STROKE_COLORS_TIER2_PALETTES <- c("PRGn", "PiYG", "BrBG")

## ColorBrewer palettes worth knowing by name, grouped by the role they suit.
## Browse them at https://r-graph-gallery.com/38-rcolorbrewers-palettes.html
BREWER_ROLES <- list(
  ## Qualitative, low saturation, designed for LARGE FILL AREAS.
  ## Set3 is the workhorse: 12 distinguishable soft colours.
  fill   = c("Set3", "Pastel1", "Pastel2", "Set2"),
  ## Diverging — take the DARK ENDS for lines, strokes and text.
  line   = c("PRGn", "PiYG", "BrBG", "RdBu", "RdYlBu"),
  ## Qualitative, saturated — points, small markers, emphasis.
  marker = c("Dark2", "Set1")
)

#' Set3 with its blue #80B1D3 swapped for a mid grey — the preferred 12-fill set.
#'
#' Two things are wrong with stock Set3 for our purposes, and one swap fixes both:
#'
#' 1. #80B1D3 (blue) and #8DD3C7 (teal) sit 0.096 apart under .rgb_distance,
#'    below the collision threshold — so they can never be split across two
#'    panels, which costs you a colour in practice.
#' 2. Set3's only neutral is #D9D9D9, which is very light (contrast 1.41). A
#'    usable mid grey is worth more than a second cool hue: greys carry
#'    "reference / background / other" without competing for a hue slot.
#'
#' Dropping the blue in favour of #999999 (contrast 2.85, inside Set3's own
#' 1.29-3.02 band, so it reads as a family member) removes the collision AND
#' frees #8DD3C7 for real use. The two greys coexist happily: #999999 vs
#' #D9D9D9 is 0.251 apart. A DARKER grey is required, not a lighter one:
#' #BFBFBF lands 0.063 from Set3's lavender #BEBADA.
#'
#' #FFFFB3 (index 2) is still pale yellow at 1.04 contrast and must be skipped
#' for anything but the largest fills; this helper leaves it in place so indices
#' stay comparable with stock Set3.
set3_with_grey <- function(grey = "#999999") {
  s3 <- brewer("Set3")
  s3[toupper(s3) == "#80B1D3"] <- grey
  toupper(s3)
}

#' Fetch a ColorBrewer palette as hex strings.
#'
#' **When you are stuck choosing colours, go here first** rather than inventing a
#' palette: https://r-graph-gallery.com/38-rcolorbrewers-palettes.html
#' These palettes are perceptually engineered and split cleanly by role — see
#' BREWER_ROLES. Qualitative sets (Set3, Pastel1) are already low-saturation and
#' therefore right for fills; the dark ends of diverging sets (PRGn, PiYG, BrBG)
#' are deep and saturated and therefore right for lines and text.
#'
#' @param name palette name, e.g. "Set3", "PRGn".
#' @param n how many colours; NULL gives the palette's full length.
#' @param skip indices to drop before truncating to n. Set3's index 2 (#FFFFB3)
#'   is pale yellow at 1.04 contrast on white and fails assert_visible_on_white();
#'   index 12 (#FFED6F) is also yellow. (R is 1-based here.)
#'
#' Always run the usual assertions on what comes back — a famous palette is not
#' automatically safe for your particular background and role.
brewer <- function(name, n = NULL, skip = integer(0)) {
  info <- RColorBrewer::brewer.pal.info[name, ]
  full <- RColorBrewer::brewer.pal(info$maxcolors, name)
  if (length(skip)) full <- full[-skip]
  if (is.null(n)) return(toupper(full))
  if (identical(info$category, "qual")) return(toupper(full[seq_len(n)]))
  ## diverging/sequential: sample evenly across the full range so n = 2 gives the ends
  toupper(grDevices::colorRampPalette(full)(n))
}

#' Derive a fill-appropriate version of a line/text colour by desaturating it.
#'
#' **Type and fills have opposite saturation needs.** Text and thin lines are
#' made of strokes a pixel or two wide — they need saturation and depth to
#' register at all. A bar, box or map polygon is a large block: a much weaker
#' saturation reads perfectly clearly, and a fully saturated one shouts over the
#' data. So the same hue should appear *strong* as a line and *soft* as a fill.
#'
#' This also settles the cross-panel question cleanly: a line and a bar sharing
#' one hue at different saturations are obviously the same family without
#' reading as the same variable.
#'
#' @param sat_factor multiply HSV saturation by this (0.4-0.7 is the useful band).
#' @param val_factor multiply HSV value; >1 lightens a dark hue that would
#'   otherwise go muddy when desaturated.
soften_for_fill <- function(color, sat_factor = 0.55, val_factor = 1) {
  hsv <- grDevices::rgb2hsv(grDevices::col2rgb(color))
  grDevices::hsv(hsv["h", ], pmin(1, hsv["s", ] * sat_factor),
                 pmin(1, hsv["v", ] * val_factor))
}

#' Text is never yellow — no matter how dark the yellow is.
#'
#' Contrast alone does not catch this: dark goldenrod #B8860B clears the
#' white-background contrast bar yet still reads as yellow text, which is hard to
#' focus on at any size. The test is on HUE, not lightness: anything in the yellow
#' band (hue 40-75 degrees) is rejected for text. Orange (<40) and yellow-green
#' (>75) are left alone. Yellow is fine as a FILL behind a black edge.
assert_no_yellow_text <- function(colors) {
  hsv <- grDevices::rgb2hsv(grDevices::col2rgb(colors))
  hue <- hsv["h", ] * 360
  sat <- hsv["s", ]
  bad <- hue >= 40 & hue <= 75 & sat > 0.25
  if (any(bad)) {
    stop(sprintf(
      "yellow text colour(s) %s: yellow text is hard to read at any lightness. Use black for labels, or a non-yellow accent. Yellow is fine as a fill behind a black edge, just never as type.",
      paste(sprintf("%s (hue %.0fdeg)", .norm_hex(colors[bad]), hue[bad]), collapse = ", ")))
  }
  invisible(TRUE)
}

#' Composition as a ranked bar chart — the replacement for a pie chart.
#'
#' Readers cannot compare angles: a 26% slice and a 29% slice look the same in a
#' pie. As bars they are unmistakable, and the printed number settles it outright.
#' Sorting descending adds a rank the pie also fails to convey.
#'
#' Use a pie only when a single share is shown against the whole, and print the number.
composition_bar_instead_of_pie <- function(labels, values, color = PALETTE[["blue_main"]],
                                           as_percent = TRUE, sort_desc = TRUE,
                                           horizontal = TRUE, font_size = 16) {
  if (length(labels) != length(values)) {
    stop(sprintf("%d labels for %d values", length(labels), length(values)))
  }
  assert_fill_not_near_black(color)
  v <- as.numeric(values)
  if (as_percent) {
    if (sum(v) <= 0) stop("values must sum to a positive number to show percentages")
    v <- v / sum(v) * 100
  }
  d <- data.frame(label = labels, value = v, stringsAsFactors = FALSE)
  d$label <- factor(d$label, levels = if (sort_desc) d$label[order(d$value)] else rev(d$label))
  lab_fmt <- if (as_percent) sprintf("%.1f%%", d$value) else format(d$value)

  p <- ggplot2::ggplot(d, ggplot2::aes(x = label, y = value)) +
    ggplot2::geom_col(fill = color, colour = "black", linewidth = 0.4, width = 0.7) +
    ggplot2::geom_text(ggplot2::aes(label = lab_fmt), hjust = -0.15,
                       colour = "black", size = font_size / 4) +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, 0.18))) +
    ggplot2::labs(x = NULL, y = if (as_percent) "share (%)" else "value") +
    theme_pub(font_size = font_size)
  if (horizontal) p <- p + ggplot2::coord_flip()
  p
}

#' Large filled areas (bars, boxes, ribbons) must not be near-black.
#'
#' A big solid black or near-black bar is heavy and ugly in a paper figure or on a
#' slide — it dominates the panel and reads as ink rather than data. Use a mid-grey
#' ramp instead (`PALETTE_FAMILIES$grey` runs light -> dark and stops at
#' `grey_deep` #5A5A5A for exactly this reason).
#'
#' This is a near-black guard, not a general darkness cap: a dark *saturated*
#' colour like `blue_main` #0F4D92 (contrast 8.4) stays allowed. Reserve `ink`
#' #272727 and `grey_dark` #4D4D4D for text and thin lines.
assert_fill_not_near_black <- function(colors, max_contrast = 10) {
  ratios <- vapply(colors, contrast_vs_white, numeric(1))
  bad <- ratios > max_contrast
  if (any(bad)) {
    stop(sprintf(
      "near-black fill(s) %s: contrast vs white above %.1f means a large solid area reads as a black blot. Use PALETTE_FAMILIES$grey (light->dark, capped at #5A5A5A); keep 'ink'/'grey_dark' for text and lines.",
      paste(sprintf("%s (%.2f)", .norm_hex(colors[bad]), ratios[bad]), collapse = ", "),
      max_contrast))
  }
  invisible(TRUE)
}

#' Assert a built ggplot actually rendered `expected` points.
#'
#' ggplot2's default discrete shape scale supports only 6 levels; mapping
#' shape to a 12-level variable silently drops every row beyond the 6th with
#' nothing but a buried "Removed N rows" warning. On a PCA meant to show every
#' sample, count the points — never eyeball them.
#'
#' @param p a ggplot object.
#' @param expected expected number of drawn points.
#' @param layer index of the point layer (default 1).
assert_points_drawn <- function(p, expected, layer = 1L) {
  d <- ggplot2::ggplot_build(p)$data[[layer]]
  drawn <- sum(stats::complete.cases(d[, c("x", "y")]) &
                 !is.na(d[["shape"]] %||% 19) &
                 !is.na(d[["colour"]] %||% "black"))
  if (drawn != expected) {
    stop(sprintf(
      "expected %d points, %d were drawn. Check for a discrete scale (shape has only 6 levels) that silently dropped rows, or NA coordinates.",
      expected, drawn))
  }
  invisible(TRUE)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# --------------------------------------------------------------------------
# 2026-09-12 新增三条 —— 自 Claude Science 内置 `figure-style` 吸收（Apache-2.0）
# 与 pubfig.py 逐字对齐：同名函数、同判据、同错误信息要点。改一边必须改另一边。
#
# 为什么是断言而不是检查清单：清单的执行率**不可观测** —— 说"检查过了"和真检查过，
# 产物一模一样；断言不过则图出不来。
# --------------------------------------------------------------------------

#' 标注不得过多（figure-style §2.2）
#'
#' 只数**叙述性标注**（geom_text/geom_label/annotate 画出来的），
#' 轴标题、刻度标签、图例条目属于"下限"，不进预算。
#' 判据方向与 assert_visible_on_white() 相反：那条防太浅看不见，这条防太多糊住图。
assert_label_ceiling <- function(p, max_annotations = 6L) {
  b <- ggplot2::ggplot_build(p)
  n <- 0L
  for (i in seq_along(b$data)) {
    geom <- class(b$plot$layers[[i]]$geom)[1]
    if (geom %in% c("GeomText", "GeomLabel", "GeomTextRepel", "GeomLabelRepel")) {
      lab <- b$data[[i]][["label"]]
      n <- n + sum(!is.na(lab) & nzchar(trimws(as.character(lab))))
    }
  }
  if (n > max_annotations) {
    stop(sprintf(
      "%d narrative annotations on this plot, ceiling is %d (figure-style 2.2). Axis titles / tick labels / legend entries are NOT counted - these are extra callouts. Delete the ones a reader can read off the axis; keep only the headline number.",
      n, max_annotations))
  }
  invisible(TRUE)
}

#' log 轴上不得画填充柱（figure-style §3.3 / §8）
#'
#' 柱长编码"到基线的距离"，而 log 轴没有有意义的零点 —— 柱长于是变成
#' "与一个任意下限的比值"，读者读到的倍数是假的。改用点 + 中位线。
assert_no_filled_bars_on_log_axis <- function(p) {
  b <- ggplot2::ggplot_build(p)
  bar_layers <- vapply(b$plot$layers,
                       function(l) class(l$geom)[1] %in% c("GeomBar", "GeomCol", "GeomRect"),
                       logical(1))
  if (!any(bar_layers)) return(invisible(TRUE))
  trans_x <- b$layout$panel_params[[1]]$x$trans$name %||%
    (b$plot$scales$get_scales("x")$trans$name %||% "identity")
  trans_y <- b$layout$panel_params[[1]]$y$trans$name %||%
    (b$plot$scales$get_scales("y")$trans$name %||% "identity")
  flipped <- inherits(b$plot$coordinates, "CoordFlip")
  value_axis <- if (flipped) "x" else "y"
  value_trans <- if (flipped) trans_x else trans_y
  if (grepl("^log", value_trans)) {
    stop(sprintf(
      "filled bars drawn on a log-scaled %s axis (figure-style 3.3). Bar length encodes ratio to an arbitrary floor there, so the lengths a reader compares are meaningless. Use points + a median tick instead, or put the axis back on a linear scale.",
      value_axis))
  }
  invisible(TRUE)
}

#' 断轴缺口里不得画任何东西（figure-style §3.2 / §8）
#'
#' **缺口没有坐标**：那一段被显式声明为"数值不连续"，往里画一条阈值线，
#' 读者会按缺口两侧的刻度去推它的值，而那个推断必然是错的。
#'
#' @param break_range 长度 2 的向量，缺口的数据坐标区间。
assert_nothing_in_axis_break <- function(p, break_range, axis = "y") {
  lo <- min(break_range); hi <- max(break_range)
  b <- ggplot2::ggplot_build(p)
  offenders <- character(0)
  for (i in seq_along(b$data)) {
    d <- b$data[[i]]
    geom <- class(b$plot$layers[[i]]$geom)[1]
    cols <- if (axis == "y") c("yintercept", "y") else c("xintercept", "x")
    for (cc in cols) {
      if (!cc %in% names(d)) next
      v <- suppressWarnings(as.numeric(d[[cc]]))
      v <- v[!is.na(v)]
      if (!length(v)) next
      # 参考线：整条都在缺口里才算；文字：位置在缺口里就算
      inside <- if (geom %in% c("GeomHline", "GeomVline", "GeomText", "GeomLabel")) {
        v >= lo & v <= hi
      } else rep(FALSE, length(v))
      if (any(inside)) {
        offenders <- c(offenders, sprintf("%s at %s=%g", geom, axis, v[inside][1]))
      }
    }
  }
  if (length(offenders)) {
    stop(sprintf(
      "%d element(s) drawn inside the %s-axis break [%g, %g] (figure-style 3.2): %s. The gap has no coordinate - a reader will interpolate from the ticks on either side and get a wrong value. Move them outside the break, or don't break the axis there.",
      length(offenders), axis, lo, hi, paste(utils::head(offenders, 5), collapse = "; ")))
  }
  invisible(TRUE)
}

#' 渲染后几何检查：可见文字不得互压、不得出画布（figure-style §9.1）
#'
#' ⚠ 与 Python 侧的差异（**这不是偷工，是两个绘图栈的真实区别**）：
#' matplotlib 能拿到每个 Text 的 window extent，所以 py 侧还查"文字压轴线"；
#' ggplot2 要把图先 print 到设备再从 grid 树里取 grob 尺寸，轴线是 polyline grob、
#' 与刻度标签本来就贴着，逐个配对会全是假阳性。**R 侧只查文字互压与出画布**，
#' 压轴线那一类交给 §9.2 的逐 panel 人眼看。
assert_no_text_collisions <- function(p, width = 7, height = 5, res = 150) {
  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp, width = width, height = height, units = "in", res = res)
  on.exit({ if (grDevices::dev.cur() > 1L) grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  grid::grid.newpage()
  grid::grid.draw(ggplot2::ggplotGrob(p))
  grid::grid.force()

  # ⚠ 2026-09-12 实测修补（被 selftest 的"做坏"用例抓出来的**假阴性**）：
  # 原实现用 downViewport + convertX 取坐标，拿到的是**各自 viewport 内**的相对英寸，
  # 不同 panel / 不同 grob 之间根本不可比，于是重叠检测恒不触发 —— 静默放行坏图，
  # 比误报危险得多。现改用 current.transform() 把中心点换算到**设备坐标**再比。
  # ⚠ viewports = TRUE 不能省：默认 FALSE 时返回的 gPath **不带 vpPath 属性**，
  # seekViewport() 必然失败，于是一个 grob 都量不到（实测 5 个全丢）。
  paths <- grid::grid.grep("text", grep = TRUE, global = TRUE, viewports = TRUE)
  boxes <- list(); labels <- character(0); unmeasurable <- 0L
  for (path in paths) {
    gr <- tryCatch(grid::grid.get(path), error = function(e) NULL)
    if (is.null(gr) || is.null(gr$label)) next
    lab <- paste(as.character(gr$label), collapse = " ")
    if (!nzchar(trimws(lab))) next
    ok <- tryCatch({
      vp <- attr(path, "vpPath")
      if (!is.null(vp) && nzchar(as.character(vp))) grid::seekViewport(vp)
      tf <- grid::current.transform()
      # ⚠ grobX/grobY 的 theta 只认方位角；"centre" 会报 invalid 'theta'（实测踩过）。
      x0 <- grid::convertX(grid::grobX(gr, "west"),   "in", valueOnly = TRUE)
      x1 <- grid::convertX(grid::grobX(gr, "east"),   "in", valueOnly = TRUE)
      y0 <- grid::convertY(grid::grobY(gr, "south"),  "in", valueOnly = TRUE)
      y1 <- grid::convertY(grid::grobY(gr, "north"),  "in", valueOnly = TRUE)
      lo <- c(x0, y0, 1) %*% tf
      hi <- c(x1, y1, 1) %*% tf
      dxy <- c(lo[1] / lo[3], lo[2] / lo[3], hi[1] / hi[3], hi[2] / hi[3])
      boxes[[length(boxes) + 1L]] <- c(min(dxy[1], dxy[3]), min(dxy[2], dxy[4]),
                                       max(dxy[1], dxy[3]), max(dxy[2], dxy[4]))
      labels <- c(labels, substr(lab, 1, 14))
      grid::upViewport(0)
      TRUE
    }, error = function(e) { grid::upViewport(0); FALSE })
    if (!isTRUE(ok)) unmeasurable <- unmeasurable + 1L
  }
  # 量不到的不许静默吞掉 —— 那正是假阴性的来源
  if (unmeasurable > 0L && !length(boxes)) {
    stop(sprintf(
      "could not measure any of the %d text grobs - the geometric check did NOT run. Do not treat this as 'clean'.",
      unmeasurable))
  }
  problems <- character(0)
  if (length(boxes) > 1L) {
    for (i in seq_len(length(boxes) - 1L)) for (j in (i + 1L):length(boxes)) {
      a <- boxes[[i]]; b2 <- boxes[[j]]
      if (a[1] < b2[3] && b2[1] < a[3] && a[2] < b2[4] && b2[2] < a[4]) {
        problems <- c(problems, sprintf("text '%s' overlaps '%s'", labels[i], labels[j]))
      }
    }
  }
  for (i in seq_along(boxes)) {
    a <- boxes[[i]]
    if (a[1] < 0 || a[2] < 0 || a[3] > width || a[4] > height) {
      problems <- c(problems, sprintf("text '%s' extends outside the canvas", labels[i]))
    }
  }
  if (length(problems)) {
    problems <- unique(problems)
    stop(sprintf(
      "%d geometric text problem(s) (figure-style 9.1): %s. Move, shorten or stagger the labels and re-save until clean.",
      length(problems), paste(utils::head(problems, 6), collapse = "; ")))
  }
  invisible(TRUE)
}

#' 逐 panel 裁图看（figure-style §9.2）—— 工具，不是断言
#'
#' 几何检查是几何的，不是感知的：低对比度标签、引线交叉、两个系列颜色相近，
#' bbox 一条都抓不到。**这一步没有任何断言能替代。**
#' R 侧返回每个 facet panel 在 gtable 里的行列位置，配合 `ggplot2::ggsave` 后
#' 用外部工具裁图；返回值刻意与 py 侧不同 —— grid 与 matplotlib 的坐标系不同，
#' 强行对齐反而会给出错误的像素框。
panel_crops <- function(p) {
  g <- ggplot2::ggplotGrob(p)
  idx <- grep("^panel", g$layout$name)
  if (!length(idx)) return(list())
  res <- lapply(idx, function(i) list(
    name = g$layout$name[i], t = g$layout$t[i], l = g$layout$l[i],
    b = g$layout$b[i], r = g$layout$r[i]))
  names(res) <- g$layout$name[idx]
  res
}

# --------------------------------------------------------------------------
# Save
# --------------------------------------------------------------------------

#' Save a ggplot to several formats at publication DPI.
#'
#' Uses the **cairo** devices when available. This is not cosmetic: R's default
#' `pdf()`/`png()` devices go through `mbcsToSbcs()` and **silently substitute**
#' non-Latin-1 characters — an em dash becomes "-", a Greek letter becomes a
#' box, with only a buried warning. A title that reads correctly in the R
#' console can therefore ship wrong in the PDF. cairo renders UTF-8 directly.
finalize_figure <- function(plot, out_path, formats = c("pdf", "png"),
                            dpi = 300, width = 8, height = 6, use_cairo = TRUE) {
  supported <- c("pdf", "svg", "eps", "png", "jpg", "jpeg", "tif", "tiff")
  bad <- setdiff(tolower(formats), supported)
  if (length(bad)) stop(sprintf("unsupported format(s): %s", paste(bad, collapse = ", ")))
  cairo_ok <- isTRUE(use_cairo) && isTRUE(capabilities("cairo"))
  stem <- sub("\\.[A-Za-z]+$", "", out_path)
  dir.create(dirname(stem), recursive = TRUE, showWarnings = FALSE)
  paths <- character(0)
  for (fmt in tolower(formats)) {
    path <- paste0(stem, ".", fmt)
    extra <- list()
    if (cairo_ok && fmt == "pdf") extra$device <- grDevices::cairo_pdf
    ## ragg is ggsave's default raster device when installed and already handles
    ## UTF-8 correctly; passing type="cairo" then only produces a warning.
    if (cairo_ok && !requireNamespace("ragg", quietly = TRUE) &&
        fmt %in% c("png", "jpg", "jpeg", "tiff", "tif")) extra$type <- "cairo"
    do.call(ggplot2::ggsave, c(list(filename = path, plot = plot, dpi = dpi,
                                    width = width, height = height,
                                    bg = "white", limitsize = FALSE), extra))
    paths <- c(paths, path)
  }
  invisible(paths)
}
