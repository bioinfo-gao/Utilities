# mosdepth vs `samtools depth` —— 配对重叠区的处理不同，深度差可达 19%

> **机制与全部默认口径参数**（`-F 1796` 位拆解、去重依赖上游 markdup、重叠校正算法、
> `--fragment-mode`、跨工具对照表）见 [mosdepth.md](mosdepth.md)。本文是**实测事故记录**。

**症状**：同一个 BAM、同一段区间、同样 `-Q 20`，两个工具给出不同的平均深度，
且**差异大小随样本变化**，看上去像真实的样本间差异。

实测（P29，2026-08-13，L6 sample，`pDonor:1213-1812` / PuroR）：

| 命令 | 平均深度 |
| :--- | :---: |
| `mosdepth -Q 20 -n -b r.bed` | **8.07** |
| `samtools depth -a -Q 20` | **8.978** |
| `mosdepth -Q 20 -x/--fast-mode` | **8.98** |

**根因**：`mosdepth` **默认做 mate-overlap 校正** —— 一对 read 的重叠段只计一次。
`samtools depth` 不做，重叠段计两次。`mosdepth --fast-mode` 的文档原文就是
"dont look at internal cigar operations or **correct mate overlaps**"，
关掉校正后与 `samtools depth` 完全吻合（8.98 vs 8.978）⇒ 差异 100% 来自这一条。

⚠ **`samtools depth` 并非"做不到"，是默认值相反**：它有 `-s`
（"Do not count overlapping reads within a template"），只是默认关。
`samtools depth -s` 与 `mosdepth`（默认）口径才对齐。
（另：samtools 1.16 起 `samtools depth` **默认已排除 duplicate**，默认 filter-out 与 mosdepth 的 1796 逐位相同。）

MAPQ 阈值**不是**变量：`-Q 0` 与 `-Q 20` 在这个区段给出同样的差异。

**为什么危险 —— 偏差不是随机的，而是跟着文库插入片段走**：
重叠越多偏差越大，而插入片段是**每个文库自己的属性**。P29 四个样本按插入片段分成两组
（L6 363±196 / L13 440±797 vs M24 377±135 / H43 378±126），实测偏差
**L6/L13 11–19% vs M24/H43 4–9%，恰好沿着分组走**。
若分子用一个工具、分母用另一个（或不同步骤混用），会**凭空造出一个跟着文库走的假差异**，
而它长得非常像真实的生物学差异 —— 在拷贝数/整合分析里这是会直接写进报告的那种错。

**修复 / 规矩**：
1. **同一个项目里深度定量只用一个工具，分子分母口径一致**，偏差自相抵消。
   拷贝数这类比值分析尤其如此。
2. 需要逐碱基深度又想保持 mosdepth 口径时，用 `mosdepth -c <contig> <prefix> <bam>`
   取 `per-base.bed.gz`（区间格式）再展开，**不要图省事换成 `samtools depth`**。
   `-c` 限定单条 contig 时非常快（P29 的 40 GB BAM 上 <1 s）。
3. **写一条硬断言把两个来源的同一个数比对起来**。P29 的 Step 17 有一条
   "重算值 vs 上一步的值，容差 2%"，正是它当场拦下了这次事故 ——
   没有它就会把 11–19% 的假差异当结果发出去。

**相关**：[[feedback_self_audit_needs_independent_cross_check]]（同一事实出现两处就必须有检查比对）
