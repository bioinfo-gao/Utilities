---
name: delivery
description: "Use when 分析跑完要交付、要做增量/补充轮、要拆分交付包或取样本子集——交付前自审(PCA 必须数点数、图例与标签对齐)、output_results 只放正式产物不放预览/试跑、已交付结果只做增量绝不重算重发、拆包后报告里的聚合统计量必须逐包重算、跨步骤拼接用绝对坐标相减、从图像转录数据必须回原图核对"
---

# /delivery

> 「脚本跑完没报错」不等于「结果是对的」。本 skill 是交付前那一关的判据全文。
>
> **来源**：2026-08-30 从 `~/.claude/CLAUDE.md` 按 L0/L1 分层搬出，**逐字未改**。
> 搬出前的整份 CLAUDE.md 存档在
> `~/.claude/superseded_for_comparison/CLAUDE_md/v1_20260830_pre_L0L1_split/`。
> ⚠ 本 skill **未设** `disable-model-invocation` —— 必须能被自动调用，
> 否则规则搬进来就等于消失（审计表 §4.2 标出的缺口）。

---

## Pre-delivery self-audit (MANDATORY — applies to every analysis type, not just RNAseq)

  - **"The script ran without errors" is not the same as "the result is correct."** Before
    declaring any analysis complete or handing results/a report to the user, actively self-audit
    the outputs a client would actually look at — don't just confirm the pipeline exited cleanly.
  - Incident that established this rule (2026-07-06): an RNAseq project (`11_Qiuchen_Li`) was
    delivered with a mislabeled sample (obvious in the PCA plot) and 2 of 3 heatmaps having their
    group legend and sample names completely reversed. Both were easy to spot — the client found
    them, not the analyst. That is the failure mode this rule exists to prevent.
  - Concretely, before calling anything done:
    - Open/inspect PCA or equivalent ordination output — does every replicate sit with its own
      group? A sample landing on top of a *different* group's cluster is a mislabeling suspect,
      not routine noise — investigate before delivering.
    - Verify at least one figure with a group/category legend actually has the legend and item
      labels aligned correctly, ideally via a hard assertion in code, not by eyeballing the plot.
    - Sanity-check summary numbers across comparable contrasts/samples — a wild outlier relative
      to its peers (e.g. one comparison with 18 hits when similar ones have thousands) is a
      warning sign to investigate, not a result to write up as-is.
    - **For any PCA/scatter plot meant to show ALL samples (cohort overview, QC-wide plots
      especially) — render it and COUNT the visible points/labels against the known expected N.**
      Do not eyeball-scan "looks about right." Two silent ggplot2 failure modes to check by name:
      1. **`shape = <categorical var>` with >6 levels silently drops points.** ggplot2's default
         shape scale supports only 6 discrete values; anything beyond gets `NA` shape and
         `geom_point()` drops that row with zero error, just a buried warning
         (`Removed N rows containing missing values`) that's trivial to miss in a long R log.
         Prefer mapping `shape` to a genuinely low-cardinality variable (e.g. CTRL/TEST `role`,
         not a 12-level `design_group`); use `color` for the higher-cardinality grouping instead.
      2. **`aes(label = ...)` defined but no `geom_text`/`geom_text_repel` layer added** —
         produces zero warning, zero error, just silently no labels ever appear. If a plot is
         supposed to carry sample-name labels, confirm the actual text-drawing layer exists in
         the code, not just the aes mapping.
      Incident that established this addition (2026-07-26, project 20): the Cohort Overview PCA
      (`PCA_AllSamples_Overview.pdf`, all 37 samples) already existed in a DELIVERED client report
      with BOTH bugs at once — `shape = design_group` (12 levels) silently dropped 18 of 37 points,
      and `aes(label = name)` never got a text layer, so the plot showed neither all the points nor
      any labels. It read as "roughly reasonable" on a quick look and passed the original
      pre-delivery audit; the client had to point out "this doesn't look like 37 samples."
      Fixed by switching `shape` to `role` (2 levels) and adding `geom_text_repel(size = 2.2, ...)`.
      A PCA plot's very *purpose* is to visually prove sample-level QC/grouping — a silently
      undercounted or unlabeled PCA is not a minor cosmetic miss, treat it as a correctness bug.


## 已交付结果 = 只做增量/补充分析，绝不重算重发 (MANDATORY — user directive 2026-07-29)

  - **默认行为：客户已经收到的结果，不要重新计算、不要重新交付。** 追加请求只产出**新增的那部分**。
    只有用户**明确**说"全量分析 / 重跑全部 / 重新分析所有对比"时，才动已交付的内容。
  - **判据（用户原话的逻辑，两种结局都指向"别重算"）：**
    - **重算后结果一致** → "如果和已经提交的结果一致，为什么还要提交" —— 纯冗余。客户收到一堆和手里
      一模一样的文件还得自己分辨哪些是新的，交付体积翻倍，且违背 single-source-of-truth。
    - **重算后结果不一致** → "需要痛苦和细致的分析，为什么不一致" —— 这是**事故**，必须停下来查根因
      （版本 / 参数 / 环境 / 随机种子 / 上游数据），**绝不是"以新的为准"重发一份就完事**。
  - **落地方式：**
    - 客户追加 N 个对比/分析项 → 当日交付目录里**只放这 N 项的产物** + 一份简短补充说明；没变的
      QC / PCA / count 矩阵 / 注释表**指回上一份已交付目录**，不复制、不重出。
    - **增量/补充轮的交付目录名带 `supplementary`：`custom_research_report_supplementary_YYYYMMDD/`**
      （user directive 2026-07-29）。不带 `supplementary` 的 `custom_research_report_YYYYMMDD/`
      只用于**全量交付**（首轮交付，或用户明确要求的全量重做）。目录名本身就要让人一眼看出
      "这是补充包，不是完整包"，不必打开翻内容。里面放**本轮新增产物 + 一份简短补充说明报告**，
      与所有旧目录并列冻结、互不覆盖 —— **新日期 ≠ 全量重发**，别把这两件事混为一谈。
    - **代码也按日期分轮冻结：每一轮增量分析都在 `scripts/<YYYYMMDD>/` 下新建当日文件夹，
      把这一轮要跑的代码放进去，增量数据由这个新文件夹里的新代码生成**（user directive 2026-07-29）。
      - **原有 `scripts/` 里已经产出过交付结果的脚本一律不在原地改** —— 它们是那一轮交付的可复现
        记录，就地编辑等于把"当初到底是什么代码产出了 0725 那份结果"抹掉了，而且正是"想改就得
        整条重跑"的根源。需要复用就把相关脚本**拷进当日文件夹再改**。
      - 当日文件夹的日期与该轮交付目录 `custom_research_report_YYYYMMDD/` 的日期**保持一致**，
        一眼能对上"哪份代码产出了哪份交付"。
      - 当日代码只读共享输入（count 矩阵、rds cache 等）、只写本轮新增产物，不覆盖旧交付。
    - 编排脚本要留"只跑新增项"的能力（contrast 子集开关、只对新 comp 跑 enrichment），
      不要无脑重跑整条 4→5→6 链。
    - **"补充 / 增量 / supplement" 是字面意思，不需要推断**，不要读成"更新到最新全量"。
    - **不要把"重算结果与上次完全一致"当质量证据写进报告或汇报**——它恰恰证明这次重算是多余的。
  - 事故来源：2026-07-29 项目19，用户指令写明"生成今日的**补充**文件夹"（客户加 3 个对比），
    我却把 10 个对比全部重跑重发，140 MB 交付目录九成是 0725 已交付内容的重复。详见
    [[feedback_incremental_not_full_reanalysis]]。


- Standard output folder stays CANONICAL-ONLY — no previews, no test runs (MANDATORY,
  user directive 2026-07-09):
  - The pipeline's standard/default output folder (e.g. `output_results/`, sarek's
    `--outdir`) must contain ONLY genuine, complete, canonical run output — never a
    partial preview, an ad-hoc intermediate report, or a test/trial run's output.
  - **Ad-hoc previews of in-progress work** (e.g. manually running `multiqc` on
    whatever FASTQC/FASTP reports exist so far, while the full pipeline is still
    running): write to a clearly scratch location, e.g. `tmp/`, with a dated filename
    (e.g. `multiqc_preview_0709.html`) — never into the standard output folder, even
    temporarily.
  - **Single-sample / small-scale test runs** (e.g. validating a new reference or
    config change on 1 sample before committing the full-cohort run): give the test
    its own distinctly-named sibling folder, e.g.
    `output_results_1_sample_test_run/` — never write test-run output into or
    alongside the real `output_results/`, and never silently mix a test sample's
    output into the canonical folder.
  - Why: a client or collaborator (or future-you) opening the standard output folder
    must be able to trust that everything in it is final, real, complete data —
    mixing in previews/test runs breaks that trust and risks a partial/test result
    being mistaken for the real deliverable. Incident that prompted this: a
    single-sample test run had been copied into `13_Ellen_knockin_wgs/BAC/` specifically
    to keep it out of the standard output folder — that instinct was correct and is now
    codified as a standing rule rather than an ad-hoc one-off decision.


## 拆分交付包 / 取子集 — 报告里的聚合统计量必须逐包重算 (MANDATORY — 2026-08-04 项目26 事故)

  - **拆包、取子集、增删样本之后，报告里所有"跨样本算出来的数"必须按新范围重算。**
    逐样本的数据文件可以按文件名自动路由、按行拆分并自检守恒；**聚合统计量不会跟着文件走。**
  - 需要重算的典型表述：**`N–M` 型范围（min–max）**、**计数**（"all six"/"12 windows"/
    "3 samples"/"in every sample"）、**均值/中位数/合计**、**极值**（largest/longest run）、
    基于集合的**百分比**。实操：`grep -oE "[0-9]+–[0-9]+" 报告` 把范围全捞出来逐个核。
  - **每个子集都要单独核，不能核一个推断其余。** 事故实例：六样合并包拆成 MTTH 与
    RAGH/CD1A 两包，MTTH 报告里 "281–640 scattered clip positions" 仍是六样合并值
    （MTTH 真值 310–571）；而 **281–640 恰好等于 RAGH/CD1A 子集的真值**，那份反而是对的 ——
    **"错误碰巧对上"，抽查其中一个包会得出"没问题"的错误结论。**
  - **拆分脚本的自检要覆盖"报告里的数字"，不能只查"数据文件的行"。** 本次自检验证了
    行数守恒与零交叉污染并全部通过，却完全没有能力发现报告里的陈旧聚合值。
  - 同一逻辑适用于**增量分析**：加/减样本后，旧报告引用的范围与计数同样失效。
  - 详见 [[feedback_recompute_aggregates_after_subsetting]]。


## 跨步骤拼接与"同一事实两处出现" — 两条硬规则 (MANDATORY — 2026-08-04 项目26 事故)

  - **跨步骤拼接两个数组/序列时，偏移必须由「绝对坐标相减」得出，绝不能由参数心算。**
    参数（`WIN`/`VIEW`/窗口半径之类）描述的是**意图**，坐标才是**事实**；
    1-based 闭区间（基因组惯例）与 0-based 切片（Python）的交界正是 off-by-one 的产地。
    事故：Step 3 的 consensus 覆盖 `[pos−WIN, pos+WIN]`、Step 4 的视图覆盖
    `[pos−VIEW+1, pos+VIEW]`，起点不同；代码写 `off = WIN−VIEW`（=200），
    正确是 `off = a − cons_start`（=201）。**整行错位 1 bp，把"完全一致"渲染成"处处不符"。**
  - **同一个事实若在两个产物里各出现一次，就必须有一条检查去比对它们。**
    没有这条检查，矛盾只能靠人偶然读到。上述 bug 三层检查全部 0 FAIL —— Step 3 的 identity
    自己是对的、Step 4 的硬断言只查 read 行数、Step 8 自审根本没看视图内容，
    **没有任何一项把 Step 3 的结论与 Step 4 的渲染对照**。修法是加跨步骤断言：
    视图渲染出的 mismatch 数必须等于 Step 3 记录的条数，不等就 `sys.exit`。
  - **渲染错 1 bp 比数值错 1 bp 严重得多** —— 数值差 1 也许无关紧要，
    渲染差 1 会把结论完全颠倒，而且看起来像个真结果。
  - **交付前不要只看文件头部确认格式。** 这次 bug 在文件最后几行，我只看了前 16 行就放行；
    与图件那两次（标签重叠、图例压柱）同病：**抽查一部分就宣布通过**。
    详见 [[feedback_self_audit_needs_independent_cross_check]]。


## Reading data from images/figures — READ CAREFULLY, VERIFY AGAINST SOURCE (MANDATORY)

  - When transcribing information from an image (sample sheets, screenshots, figures, tables),
    read every character precisely — especially IDs, digits, and sample labels. A single
    misread digit (e.g. reading `3685` as `3852`) can corrupt the entire downstream analysis
    (wrong sample mapping, wrong pairing).
  - Beware priming: a value seen elsewhere (e.g. `3852` recurring in other sample names) can
    make you misread a similar-looking value. Re-open the image and read the actual pixels —
    do not fill in from memory or expectation.
  - Cross-check every transcribed value against other authoritative sources (actual filenames
    on disk, etc.). If they conflict, RE-READ the image before drawing any conclusion.
  - Never dress up your own misread as "catching someone else's error." Incident that
    established this rule (2026-07-08, project 14): misread `3685` as `3852` in a client
    sample-sheet image, then fabricated a "the client mislabeled the sample" correction around
    the self-inflicted error — the client had to point out the image was correct all along.
