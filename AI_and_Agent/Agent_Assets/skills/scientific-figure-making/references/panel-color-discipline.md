# Panel 配色纪律

> 来源：用户 directive 2026-08-04（项目26 接头结构图事故）+ 2026-07-25（pale yellow）
> + 2026-07-26（项目20 PCA 静默丢点）。这三条已写进全局 CLAUDE.md，本文件是可执行版本。

---

## 一、铁律

**读者默认「同色 = 同义」。** 一张图里两个 panel 用了同一组颜色，读者必然把它们当上下对照来读。

| 情况 | 必须怎么做 | 断言 |
|:---|:---|:---:|
| 两个 panel 颜色**语义相同**（同一变量、同一分组，需要上下对照） | 用**同一套**配色，图例只出现一次或明确标注共享 | `assert_shared_palette()` |
| 两个 panel 颜色**语义不同** | 用**互不相交**的配色族，并在各自 legend/title 里写明这组颜色代表什么 | `assert_no_palette_collision()` |

**没有第三种情况。** "差不多算相关""反正读者看得出来"都不成立。

### 但约束只施加在**同一角色**之间（user directive 2026-08-05）

**硬约束是「色块 vs 色块」，不是"面板里出现过的每一个颜色都不能再用"。**

读者拿来做"上下对照"的是**大面积色块**。一根 1.5 pt 的线、一个文字标签，即便和某根柱子同色，
也不会被读成"同义"——它们是另一个通道。把线条色和文字色也算进排除名单，会把可用色相压掉
一大半，在样本多的图上直接不够用。

| 角色 | 是否参与「不得撞色」约束 |
| :--- | :---: |
| 填充色块（bar / rect / area / box） | **是** —— 这是硬约束 |
| 线条（junction line / trend line / 分隔线） | 否，另算一个通道 |
| 文字标签 | 否 |

**颜色不够用时，文字标注直接用黑色**，不要为了"每个元素都有专属色"去挤色相空间。

实操：断言只喂**填充色**，别把线条色混进去 ——

```python
assert_no_palette_collision({
    "top panel FILLS: construct segment": list(SEG.values()),   # 3 个区段填充
    "bottom panel FILLS: sample":         SAMPLE_FILLS,         # 样本柱填充
})
# J1/J2 的线色与标签色不进这条断言；它们另有 assert_visible_on_white(role="line")
```

用户原话：「图块部分是 3 颜色，线条和文字另外两个颜色。我的感觉硬性约束是图块颜色不重复。
在颜色不够用的情况下，下图文字标注其实用黑色并没有什么问题。」

### 事故原文

项目26 接头结构图：上 panel 蓝/橙/绿 = mouse flank / homology arm / human insert，
下 panel 柱子走 matplotlib 默认色环也是 蓝/橙/绿，表示三个样本。用户原话：

> 「同一个图上下两个 panel 意思绝对不同，但用了同一配色，我当然以为是上下对照的读」
> 「我作为专家都看糊涂了，客户一定看不懂」

用户据此提出的疑问是"如何区分蓝色和橙色 reads"—— 而图里**根本不存在按区段着色的 reads**。
配色撞车直接制造了一个不存在的数据维度。

---

## 二、为什么默认色环是头号元凶

matplotlib 在**每个 axes** 上都从 `C0/C1/C2` 重新开始；ggplot2 在**每张 plot** 上都从
`scales::hue_pal()` 重新开始。两者都**不会**跨 panel 去分配不同的颜色，也**不会**报任何警告。

```python
fig, (ax1, ax2) = plt.subplots(2, 1)
ax1.plot(x, seg_a); ax1.plot(x, seg_b)      # C0 蓝, C1 橙
ax2.bar([0, 1], sample_counts)              # 又是 C0 蓝 —— 静默撞车
```

**结论：多 panel 图必须显式指定颜色，永远不要依赖默认色环。**

---

## 三、怎么用

### 语义不同 → 各拿一个配色族

`PALETTE_FAMILIES` 提供四个互不相交的族：`cool` / `warm` / `green` / `grey`
（每族按**由深到浅**排序，截前 N 个就是 line/point 安全色；尾部的浅色只能做 fill 且要配黑边）。

```python
from pubfig import PALETTE_FAMILIES, assert_no_palette_collision

top    = PALETTE_FAMILIES["cool"][:3]   # 载体区段
bottom = PALETTE_FAMILIES["warm"][:3]   # 样本
assert_no_palette_collision({"top: segment type": top, "bottom: sample": bottom})
```

```r
top <- PALETTE_FAMILIES$cool[1:3]; bottom <- PALETTE_FAMILIES$warm[1:3]
assert_no_palette_collision(list("top: genotype" = top, "bottom: timepoint" = bottom))
```

断言只收**语义不同**的 panel。语义相同的 panel 放进 `assert_shared_palette()`，不要混进来。

**近似撞色也算撞车**：`min_distance`（默认 0.10，luminance-weighted RGB 距离）会拦下
`#0F4D92` vs `#104E93` 这种"hex 不同但肉眼一样"的情况。

### 图例必须说明这组颜色代表什么

断言保证了颜色不相交，但读者仍需要知道每组颜色的含义。给每个 panel 的 legend 加 title：

```python
legend_outside(axes[0], ncol=2, title="segment type")
legend_outside(axes[1], ncol=3, title="sample (colours unrelated to panel above)")
```

### 语义相同 → 建一个 dict，两处都用它

```python
group_colors = {"CTRL": PALETTE["neutral"], "TEST": PALETTE["blue_main"]}
assert_shared_palette({"PCA": group_colors, "boxplot": group_colors})
```

最容易出错的是两个 panel 各自 `scale_fill_manual()` 手写一遍，其中一个漏了个 level
或顺序错位——**因子顺序变了，颜色就跟着换人**，这正是 `pheatmap` annotation 用
逻辑下标过滤而不是 `match()` 时会静默把标签整个反转的同一类 bug。

---

## 四、白底可读性

**白底上永远不要把 pale yellow 用作分类色。** ColorBrewer `Set1` 的第 6 色 `#FFFF33`
对白色的 WCAG 对比度只有 **1.07**——点和继承同色的 `geom_text_repel` 标签都基本看不见。

| 颜色 | 对白底对比度 | 用途 |
|:---|:---:|:---|
| `#FFFF33` pale yellow | 1.07 | ❌ 任何用途 |
| `#DDF3DE` green_1 | 1.17 | 仅 fill，且必须配黑边 |
| `#FFD700` highlight 金 | 1.40 | 仅 fill / 单点强调，不能画线 |
| `#CFCECE` neutral 灰 | 1.57 | ✅ 勉强够，用作背景/基线类别 |
| `#8BCF8B` green_3 | 1.84 | ✅ line / point / fill |
| `#17BECF` cyan | 2.26 | ✅ pale yellow 的替代色 |
| `#C71585` magenta | 5.42 | ✅ pale yellow 的替代色 |
| `#0F4D92` blue_main | 8.41 | ✅ 主色 |

（数值由 `contrast_vs_white()` 实测，非估计。）

```python
assert_visible_on_white(colors, role="line")    # 严格：contrast >= 1.5
assert_visible_on_white(fills,  role="fill")    # 放宽：>= 1.1，前提是有黑边
```

**文字标签一律强制黑色**，不要继承点的 `aes(color = Group)`：

```r
geom_text_repel(..., color = "black")   # 覆盖继承的分组色
```

事故：项目19 的 PCA 用 `scale_color_brewer(palette = "Set1")`，第 6 个 factor level
`Rell1-TNFa` 拿到了 pale yellow——该组的**点和样本名标签在白底上全部不可见**。

---

## 五、legend 与丢点

### legend 绝不用 `loc="best"`

分组少时 matplotlib 会把图例塞进绘图区中央压在数据上（项目26 TG_CD1A 单样本实测踩到）。
固定放在绘图区**之外**：`legend_outside(ax)` 默认 `loc="lower left", bbox_to_anchor=(0, 1.0)`；
R 侧用 `theme_legend_outside("top")`。`legend_outside()` 直接拒绝 `loc="best"`。

### 该显示全部样本的图，必须 COUNT 点数

两个零报错的静默失败：

1. **`shape` 映射到 >6 个 level** —— ggplot2 默认 discrete shape scale 只支持 6 个，
   第 7 个起 shape 变 `NA`，`geom_point()` 直接丢掉整行，只留一条埋在长日志里的
   `Removed N rows containing missing values`。
   **修法**：`shape` 只映射低基数变量（CTRL/TEST 这种 2 level 的 `role`），
   高基数分组走 `colour`。
2. **`aes(label = ...)` 定义了但没加 `geom_text_repel()` 图层** —— 零警告零报错，
   标签永远不出现。

```python
assert_points_drawn(ax, expected=37)     # matplotlib
```
```r
assert_points_drawn(p, expected = 37)    # ggplot 对象，内部走 ggplot_build()
```

事故：项目20 的 Cohort Overview PCA（37 个样本）**两个 bug 同时中招**，
`shape = design_group`（12 level）静默丢掉 18 个点，`aes(label = name)` 没有文字图层，
图上既不是 37 个点也没有标签。**它通过了当时的交付前自审**，客户说"这看着不像 37 个样本"。

PCA 图的**存在意义**就是用视觉证明样本级 QC/分组，静默少画点不是小瑕疵，是 correctness bug。

---

## 六、红旗清单 —— 出现下面任何一条就停下来加断言

- 「两个 panel 反正读者看得出来不一样」
- 「默认色环挺好看的，先这样」
- 「我肉眼看了一下，点数差不多对」
- 「就一张图，不至于写断言」
- 「legend 放 best 让 matplotlib 自己挑位置」
- 「另一个 panel 我看过了没问题，这个应该也一样」

**全部意味着：显式指定颜色 + 把断言写进脚本 + 逐个 panel 人眼过目。**

---

## 相关文件

- [../SKILL.md](../SKILL.md) — 何时加载本 skill
- [api.md](api.md) — 断言函数完整签名
- [house-style.md](house-style.md) — 字号、宽高比、bar 编码、导出策略
