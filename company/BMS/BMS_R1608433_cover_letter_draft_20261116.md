<!--
内部说明（投递前删除本注释）：
- 草稿，待本人逐字过目；[方括号] 处必须填写或删除。
- 主线 = "区分数据支持的结论与形式完整的输出"（JD 原文核心考点），第二主线 = agentic 经验，
  第三段正面承认 H&E / 临床数据缺口。
- 客户项目全部匿名；proj34/37 用的是公开数据，可提及。
- 数字未逐条回读原始产物，核对路径见 BMS_R1608433_resume_points_20261116.md。
- 约 430 词，一页内。
-->

[Your Name]
[Address] · [Email] · [Phone]

[Date]

Hiring Team, Translational AI Foundations
Informatics and Predictive Sciences, Bristol Myers Squibb
Cambridge Crossing, MA

**Re: Principal Scientist, Translational AI Foundations (R1608433)**

Dear Hiring Team,

Your posting asks for someone who can show whether an agent's output is supported by the data or
merely well-formed. That distinction is what I have spent most of my recent work on, and it is why
I am applying.

As a computational biologist at [Athenomics], I run RNA-seq, single-cell, spatial and WGS analyses
end to end and deliver decision-ready reports to research clients. The failures that cost the most
are the ones that raise no error. In a Visium spatial pilot, every step exited cleanly and every
range check passed. Even so, an independent marker-versus-deconvolution cross-check showed that one
cell type's estimates were uncorrelated with its own markers (ρ = −0.01), because the reference held
only 15 such cells. Running the whole pipeline twice exposed uninitialized-memory p-values in a
widely used spatial-statistics function, which inflated significant-gene counts 20–40-fold, and an
unseeded random state in a deconvolution tool. A position-based ID assignment silently shifted 29%
of output rows while every numeric check still passed. Each of these now has a standing assertion. I
also benchmarked five splicing methods against ENCODE knockdown ground truth and measured each
method's permutation false-positive baseline, which ranged from 0.1% to 18%. That result decided the
role each method plays in the workflow.

For the past several months I have done much of this work through LLM agents. I write each assay's
expert procedure as a specification the agent loads before it works: the approved analysis flow,
the non-default parameters that matter, known failure modes and executable self-audit assertions.
These cover RNA-seq, scRNA-seq, spatial, splicing, WGS and metagenomics. Tool-call hooks with a
regression test suite enforce the rules that must never fail. Every formal analysis starts from a
reviewable decision table that runs from question, to evidence unit, to filters, to permitted
conclusions, and each filter's impact is audited. This closely matches the specification-plus-pass-
criteria model TAIF describes. Building it taught me where agents are reliable and where an expert
must stay in the loop.

My gaps relative to the role are clear. I have not yet worked with H&E whole-slide images or
[early-phase clinical biomarker data]. I would close these first, together with your digital
pathology colleagues and assay experts, because a specification is only as good as the expert
judgment behind it. [If applicable: one sentence on any patient-derived or pharma experience.]

I would welcome the chance to discuss how this approach could support the first spatial and H&E
pilots.

Sincerely,
[Your Name]
