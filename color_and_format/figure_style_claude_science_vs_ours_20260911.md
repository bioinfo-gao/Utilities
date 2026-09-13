# Claude Science 的 `figure-style` vs 我们的 `scientific-figure-making`：取舍结论

- **创建日期**：2026-09-11（文件名末尾 YYYYMMDD = 创建日，**永不改名**）
- **出身**：原为 proj35 的 `docs/P35_figure_style_vs_ours_0911.md`，
  2026-09-12 按用户要求转入 `~/Utilities/color_and_format/`，**此处为当前有效版**；
  项目内那份已标注不再更新。**内容逐字未改，只改了本节的路径与链接。**
- **上游**：[`~/Utilities/AI_and_Agent/Claude/Cladue_science/claude_science_full_evaluation_20260912.md`](../AI_and_Agent/Claude/Cladue_science/claude_science_full_evaluation_20260912.md)
  （Claude Science 完整评估，§6.6 末尾指向本文）
- **读的是什么**：`~/.claude-science/runtime/0.1.47-release/skills/figure-style/`
  （`SKILL.md` 336 行 + `kernel.py` 12.5 K，11 个 helper），与
  `~/.claude/skills/scientific-figure-making/SKILL.md`（306 行）逐节对照。
- **证据等级**：**【实测】** 两份正文都读全了；**未做**的是「把我们的 skill 导入它、看实际打不打架」。

---

## §0 结论 —— 不是二选一，两者不在同一层

| | 我们的 `scientific-figure-making` | 它的 `figure-style` |
| :--- | :---: | :---: |
| 自我定位 | **house style + 配色纪律** | 正文原话：**"does not impose a visual house style — frame, font, and palette are parameters"** |
| 给不给具体色值 | **给**，`DEFAULT_A_*` / `DEFAULT_B_*` 全表固化 | **不给**，只给原则（限制色相、threading、CVD、diverging 中心） |
| 语言 | **R + Python 双实现，逐字对齐** | **仅 Python/matplotlib**（`kernel.py`） |
| 门禁形态 | **4 条断言 + 第五条（线压色块）+ PCA 点数** | **§9 render-then-verify**：bbox 几何检查 + 逐 panel 裁图人眼看 |
| 知识来源 | 用户 directive + 本机实测校准（门槛 0.10 / 0.13 都是量出来的） | 通用出版规范 |

**⇒ 取舍结论：配色与断言以我们的为准（它没色值，替代不了）；
它的「数据保真 / 标签经济 / 按数据形状选图 / 渲染后验证」是我们缺的一层，应当吸收。
两者叠加，不是替换。**

---

## §1 它有、我们没有 —— 建议吸收的 6 条

**挑选判据：只列「我们真吃过亏、而它写成了可执行规则」的**。凑数的不列。

| # | 它的规则 | 我们对应吃过的亏 |
| :--- | :---: | :---: |
| 1 | **§1.4 claim-title 必须对轴上每个类别成立**，渲染前逐条验；不成立就限定（"on 3 of 4 pairs"）或降级为描述 | **0910 实测正中这条**：caption 写 "top 40 by adjusted P"，实际画的是 balanced 20/20，**8 个基因不在字面 top40** |
| 2 | **§1.1 被排除的行绝不进入汇总统计**；要么整行不画，要么用空心/斜纹画并在图例里命名 | proj29「`break` 实现"最多取 N 条" = 空间截断而非抽稀」同一家族：**被丢掉的数据没有在图上留痕** |
| 3 | **§1.7 一个 claim 一个数**：同一量在所有 panel / caption / 摘要里只有一个规范值 | 「同一事实出现两处就必须有检查比对」是我们既有规则，但**没写进出图流程** |
| 4 | **§2 标签经济学的上下限**：floor = 每个可见标记都必须能从图内识别；ceiling = 轴与刻度之外的叙述性标注 **> 6 条就算超** | 我们只有"图例不要压住数据"，**没有"标签过多"这一侧的判据** |
| 5 | **§3.3 log 轴上禁止填充柱**（柱长编码的是与任意基线的比值）；**§3.2 断轴缺口内不得画参考线** | 我们的断言里没有这一类**几何/语义错误** |
| 6 | **§9 render-then-verify**：§9.1 用 `get_window_extent` 做 bbox 碰撞检测（文字互压、文字压轴线，排除刻度标签压自己的轴线这一假阳性）；**§9.2 `panel_crops()` 逐 panel 裁图人眼看** | 我们的交付前自查写着"每个 panel 都人眼看过"，但**没有工具**；它把这件事做成了 API |

⚠ **第 6 条它已经在本机实证过一次**：0910 那轮它写的 `figure_qc.R` 就是这套思路，
并**自带 4 个故意做坏的测试图**证明检测器能报真阳性（我独立复跑，4/4 行为与声称一致）。
**这正是我们"自审必须有独立来源互证"那条规则想要的形态。**

## §2 我们有、它没有 —— 一条都不能丢

| # | 我们的规则 | 为什么它替代不了 |
| :--- | :---: | :---: |
| 1 | **配色五级优先级 + 固化色值**（`DEFAULT_A`→`B`→ColorBrewer→手调→黑白灰） | 它明说不给 house style。**没有色值就没有跨项目一致性** |
| 2 | **跨 panel 撞色断言**（语义不同绝不共用配色） | 它的 §4.1 threading 讲的是"同一实体同色"，**没讲"不同实体不得同色"这一反向约束**；而 matplotlib 每个 axes 从 `C0` 重起色环，正是**静默**制造这个错误 |
| 3 | **PCA/scatter 出图后 COUNT 点数** | ggplot2 discrete shape scale 只支持 6 个 level，第 7 个起**静默丢整行**（proj20 实测 37 个样本只画 19 个，已交付后被客户指出）。它的 bbox 检查抓不到"点根本没画" |
| 4 | **R 实现** | 它只有 matplotlib。我们大量图是 ggplot2 |
| 5 | **本机语言坑**：matplotlib 缺中文字形变方框、ggplot2 默认裁掉超出面板的文字（`222,842` 被渲染成 `22,842`，是 correctness bug）、`cairo_pdf` 否则 `—` 变 `-` | 全是本地环境事实，通用 skill 不可能有 |
| 6 | **三条美学硬规**（不用实心深黑图 / 不用黄色文字（判据是色相不是对比度）/ 非必要不用饼图） | 均为用户 directive；它的 §5.5 只管对比度 ≥4.5:1，**黄字对比度够但仍然是黄字** |

## §3 真正冲突的只有一处

| 冲突 | 处置 |
| :--- | :---: |
| 它 **§5.2 全图至多三档字号**（角色映射，不够就改版式别加中间号） vs 我们没有字号规定 | **采纳它的** —— 我们这条是空白，不是分歧 |
| 它 **§4.2 限制色相数、焦点系列要视觉占优** vs 我们 **按级取满 n 个色** | **不冲突**：它管"该用几个色"，我们管"这几个色从哪儿取"。**先用它的问题定数量，再用我们的色表取值** |
| 它 **§6.1 小 n 用抖动散点 + 中位线** vs 我们 **组成/占比默认排序条形图 + 标数字** | **不冲突**：前者是"分类×数值的分布"，后者是"组成/占比"，数据形状不同 |

**⇒ 没有需要二选一的地方。唯一必须写死的是优先级声明**（见 §4）。

---

## §4 落地建议

### 4.1 把它的 6 条吸收进我们的 skill — **✅ 已做（2026-09-12）**

**六条全部进了 `~/.claude/skills/scientific-figure-making/SKILL.md`，但形态分三档**，
下表逐条说清楚 **整合到什么程度 / 怎么整合的 / 为什么不是全部代码化**：

| # | 规则 | 整合形态 | 怎么整合的 | 为什么 |
| :--- | :---: | :---: | :---: | :---: |
| **4** | 标签上限（轴与刻度外 > 6 条叙述性标注即超） | **✅ 代码断言** | `assert_label_ceiling(ax/p, max_annotations=6)`。py 侧数 `ax.texts` 并剔除轴标题/刻度/图例；R 侧从 `ggplot_build()` 里只数 `GeomText/GeomLabel/*Repel` 图层 | 可数即可断言 |
| **5a** | log 轴上不得画填充柱 | **✅ 代码断言** | `assert_no_filled_bars_on_log_axis(ax/p)`。py 侧按柱子宽/高恒定判断数值轴朝向再查 scale；R 侧读 `panel_params` 的 trans 名并处理 `coord_flip` | 图形属性可直接读出 |
| **5b** | 断轴缺口里不得画参考线/标注 | **✅ 代码断言** | `assert_nothing_in_axis_break(ax/p, break_range, axis)` | 缺口范围由调用者显式给出，其余可判 |
| **6a** | 渲染后几何检查（文字互压/压轴线/出画布） | **✅ 代码断言** | `assert_no_text_collisions(fig/p)`。py 用 `get_window_extent`；R 先 `grid.force()` 再用 `current.transform()` 把 grob 角点换算到**设备坐标** | 渲染后 bbox 可比 |
| **6b** | 逐 panel 裁图人眼看 | **⚠ 工具，不是断言** | `panel_crops(fig/p)` 返回每 panel 一个框 | **感知问题没有判据**：低对比度、引线交叉、两系列颜色像，几何检查一条都抓不到 |
| **1** | claim-title 必须对轴上每个类别成立 | **📋 仍是检查清单** | 只写进 SKILL.md 的表格 + 交付前自查勾选项 | **断言需要脚本显式声明"选取规则"**，否则程序无从知道 caption 那句话该对谁成立 |
| **2** | 被排除/截断的数据必须在图上留痕 | **📋 仍是检查清单** | 同上 | **断言需要脚本显式传入"被排除的行"**，属于改出图脚本的传参约定 |
| **3** | 一个 claim 一个数 | **📋 不属于绘图断言** | 同上 | 跨 panel/caption/正文的**跨文件**比对，应归交付前自审脚本 |

**⇒ 计数：6 条规则拆成 8 个可检查项 —— 代码断言 4 项、工具 1 项、检查清单 3 项。**

**验收方式（这一条比整合本身更重要）**：断言写在 `assets/pubfig.{py,R}`，
验收在 `assets/selftest.{py,R}`，**每条都跑两个方向**——干净图必须通过、做坏的图必须报错。
两侧全绿。复跑命令：

```bash
python3 ~/.claude/skills/scientific-figure-making/assets/selftest.py /tmp/st_py
conda run -n regular_bioinfo Rscript ~/.claude/skills/scientific-figure-making/assets/selftest.R /tmp/st_R
```

⚠ **种子错误注入当场抓到我自己写的两个 bug，而且两个都只在"干净图必须通过"那一侧暴露**：

| bug | 方向 | 后果 |
| :--- | :---: | :---: |
| py 侧 | **假阳性** | matplotlib 保留超出视图范围的刻度标签 Text 对象 ⇒ **任何**普通图都报"文字出画布" |
| R 侧 | **假阴性** | `downViewport` 取到的是各 viewport 内的相对英寸、跨 grob 不可比 ⇒ 重叠检测**恒不触发**，静默放行坏图 |

**只验真阳性那一侧，两个 bug 都会溜过去。**

⚠ **R 与 Python 的一处真实差异（已在两边代码与 SKILL.md 注明，不是偷工）**：
`assert_no_text_collisions()` py 侧还查"文字压轴线"，R 侧不查 —— ggplot2 的轴线是 polyline grob、
与刻度标签本来就贴着，逐个配对全是假阳性。那一类交给 `panel_crops()` 的人眼看。

⚠ 吸收注明了来源（Apache-2.0），**未整段抄**：写成我们自己的判据 + 指向本文件。

### 4.2 把我们的 skill 导入 Claude Science 时，必须先声明优先级

否则两套规则在它那边打架（它的 §4 会自己挑色，我们的五级色表就被绕过）。
导入时在我们的 skill 顶部加一句：

> 本 skill 与内置 `figure-style` **叠加**使用：
> **配色取值、跨 panel 撞色、点数断言、R 实现以本 skill 为准**；
> **数据保真（§1）、标签经济（§2）、渲染后验证（§9）以 `figure-style` 为准**。

⚠ **导入走官方 UI**（Settings > Skills > Upload / Import from GitHub），
**不要往 `~/.claude-science/*/skills/` 塞文件** —— 那是应用内部状态，升级会覆盖
（0910 的 0.1.41→0.1.47 自动升级已经实证过路径会变）。

---

## §5 未做的部分（不要当成已验）

| 事项 | 状态 |
| :--- | :---: |
| 把我们的 skill 真导入它、看两套规则实际是否打架 | **未做** |
| 它的 `kernel.py` 11 个 helper 在我们数据上的实际效果 | **未做**（只读了签名，没跑） |
| 吸收后的断言是否真能抓到 §1 那 6 类错误 | **未做** —— 按我们的规矩，**必须用种子错误注入验收**，像它给 `figure_qc.R` 配 4 个故意做坏的用例那样 |
