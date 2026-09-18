# R 导出 PDF 时中文变成一串点（`mbcsToSbcs` conversion failure）

> 2026-09-17 proj23 实测：46 张交付 PDF **全部**中招，而同一批图在网页里完全正常。
> Python 侧的同类问题见 [matplotlib_cjk_font.md](matplotlib_cjk_font.md)。

---

## §1 症状：图是对的，字没了

```
Warning in grid.Call.graphics(C_text, as.graphicsAnnot(x$label), x$x, x$y, :
  conversion failure on '（这个标签在参考里有多确定）' in 'mbcsToSbcs': for （ (U+FF08)
```

PDF 里图形本体（点、密度、配色、图例框、英文标签）**全部正常**，
中文标题 / 图例名 / 坐标轴名渲染成 `..............` 一串点。

**每个中文字符报一条 warning**，所以一张图能刷出几十条 —— 量大反而容易被当成噪声划走。

## §2 为什么只看网页发现不了（本条最该记住的）

同一份 `.qmd`/`.Rmd` 里，两条出图路径用的是**不同设备**：

| 路径 | 设备 | CJK |
| :--- | :---: | :---: |
| knitr 嵌进 HTML 的图 | **cairo png** | ✅ 正常 |
| `ggsave()` 写交付 PDF | **默认 `pdf()`** | ❌ 变点 |

⇒ **渲染出来的网站看起来完全没问题**，缺陷只存在于交付物里。
而「交付图件一律只要 PDF」的项目，坏的恰好是唯一要交出去的那份。

## §3 修法

```r
dev <- if (isTRUE(capabilities("cairo"))) grDevices::cairo_pdf else NULL
ggplot2::ggsave(f, plot = p, width = w, height = h, dpi = dpi, device = dev)
```

`cairo_pdf` 走 cairo 字体栈，能正常排 CJK 并把字形嵌进 PDF。
先用 `capabilities("cairo")` 判一次（本机为 `TRUE`）；为 FALSE 时退回默认设备并**明确报告**，
不要静默降级 —— 静默降级正是这个坑本身的形态。

其它可行路线（本轮未采用）：`showtext` + `sysfonts::font_add()`；
或 `ragg::agg_png` 出 PNG（但交付要 PDF 时不适用）。

## §4 判据

```bash
# 1) 渲染日志/HTML 里扫一次，正常应为 0
grep -c "mbcsToSbcs" <log 或 _site/**/*.html>

# 2) 眼睛验收：转一页 PNG 直接看（看完即删，交付只留 PDF）
pdftoppm -png -r 80 -f 1 -l 1 figure.pdf /tmp/check && ls /tmp/check*.png
```

**`grep -c` 为 0 才算修好，不能只看"图能打开"。**

## 相关

- [matplotlib_cjk_font.md](matplotlib_cjk_font.md) — Python 侧：缺字形告警走 `warnings` 不走 `logger`，
  用 logging 抓 ⇒ 恒 0 假通过。两条是同一个母题：**中文丢失不会让程序失败。**
- [seurat5_and_refmapping.md](seurat5_and_refmapping.md) — 同一轮实跑里的其它坑
