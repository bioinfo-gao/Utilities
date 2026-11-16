# BMS R1608433 — 简历要点（草稿，待本人核对）

> **使用说明（内部）**
> - 英文 bullet 可直接粘进简历；每条下方的 `证据` 行是给本人核对用的，**投递前删掉**。
> - 数字均取自项目记录（`~/.claude/projects/-home-gao/memory/` 中 proj34 / proj37 等条目），
>   **未逐条回读原始产物，投递前请按证据路径复核**。
> - `[方括号]` = 我不知道、需本人填写的信息（学位、年限、雇主名称、发表等），**不得留空投出**。
> - **客户项目一律匿名化**：不出现客户姓名、机构、项目编号。proj34/proj37 使用的是公开数据（ENCODE、
>   公开 Visium 心脏数据集），可点名数据来源。

## Headline / Summary

> Computational biologist with [N] years of hands-on RNA-seq, single-cell and spatial transcriptomics
> analysis, who encodes expert analysis SOPs as specifications that LLM agents execute, and builds the
> validation layer that tells a result the data support from one that is merely well-formed.

## A. 证据评估与验证（对应 JD 核心考点 "supported vs merely well-formed"）

- Designed validation layers for analysis pipelines that catch **silent failures** — outputs that pass
  all format and range checks yet are scientifically wrong — using independent cross-checks,
  permutation-based false-positive baselines, swapped-role negative controls and double-run determinism tests.
  - 证据：feedback_self_audit_needs_independent_cross_check / feedback_swapped_negative_control /
    feedback_verify_determinism_by_double_run
- In a Visium spatial pilot, an independent marker-vs-deconvolution cross-check flagged one cell type
  (Spearman ρ = −0.01 vs 0.17–0.39 for others) as unreliable; traced the cause to only 15 reference cells,
  which a second method (RCTD) confirmed by refusing to run.
  - 证据：proj37 `/home/gao/projects_2026M7/37_spatial_visium_heart_pilot`
- Identified two upstream defects in widely used spatial tools by double-running the full pipeline:
  uninitialized-memory p-values in Squidpy spatial autocorrelation (inflating FDR-significant counts
  20–40×) and an unseeded `random_state=0` in Tangram; documented fixes and showed conclusions unchanged.
  - 证据：proj37 §8c；`~/Utilities/software_pitfalls/{squidpy,tangram}.md`
  - ⚠ 若要写"reported upstream"，需先确认是否真的提交了 issue —— 我没有记录显示已提交。
- Caught a position-based ID misassignment that silently shifted 29% of deconvolution rows while every
  numeric sanity check passed; introduced paired "identity-alignment" assertions alongside
  "internal-consistency" assertions as a team standard.
  - 证据：proj37 RCTD 补充轮；`superseded_for_comparison/deconv_rctd/v1_*/`
- Benchmarked five differential-splicing methods against ENCODE shRNA knockdown ground truth and
  per-method permutation null baselines (false-positive background 18.2% for rMATS vs 0.1–0.2% for
  LeafCutter/DEXSeq), establishing each method's role in a production splicing workflow.
  - 证据：proj34 `/home/gao/projects_2026M7/34_exon_splicing_pipeline_dev`

## B. LLM / agentic 分析工作流

- Built an agentic analysis environment (Claude Code; rules shared with Codex and Antigravity) in which
  expert SOPs for RNA-seq, scRNA-seq, spatial, splicing, WGS and metagenomics are written as
  machine-loadable specifications (assay-specific "skills": approved flow, non-default parameters,
  known failure modes, executable self-audit assertions).
  - 证据：`~/.claude/skills/`（rnaseq/scrna/spatial/splicing/wgs/taxnom…）
- Enforced scientific and delivery rules mechanically with tool-call hooks (report/email checks, guards
  against overwriting delivered results, destructive-operation blocks), backed by a 115-case regression
  test suite.
  - 证据：`~/.claude/hooks/`、test_checks.py 等四套（2026-10-27 实测 115 条）
- Required every formal analysis to start from a reviewable decision table (question → evidence unit →
  filter rules → metrics → permitted conclusions) with filter-impact audits — the same structure as an
  expert-signed agent specification.
  - 证据：SHARED_AGENT_RULES.md §2A
- [如有：其他人/团队使用这些 skill 或工作流的证据 —— JD 明确看重 "adopted by others"]

## C. 动手分析深度

- [N]+ years of end-to-end RNA-seq (DESeq2, GSEA/ORA), scRNA-seq (Scanpy/Seurat, pseudobulk DE) and
  WGS (nf-core/sarek) analysis delivered to [academic/biotech] clients as decision-ready reports.
- Spatial transcriptomics: Visium QC with tissue-appropriate thresholds, SVG detection (Moran's I,
  nnSVG — showing the complex method did not beat the baseline, ρ = 0.908), deconvolution (Tangram,
  RCTD), LISA local hotspots; Python (Squidpy/scverse) and R (Voyager/spacexr) stacks.
  - 证据：proj37
- Authored internal best-practice documents and tutorials for scRNA-seq (Python and R) and spatial
  analysis used as the reference for subsequent projects.
  - 证据：proj22/23/24；`~/Utilities/Bioinfo/single_cell_and_spatial/spatial_analysis_best_practices_20260917.md`

## D. 工程与可复现

- Nextflow / nf-core (sarek, rnaseq, taxprofiler, mag) on a shared server: resource-capped concurrent
  pipelines, tmux-based watchdogs with early-failure detection, versioned outputs with archived
  superseded versions for side-by-side comparison; Git-managed code.
- Python and R (10 years R; Python primary since 2026).
  - ⚠ 措辞请本人斟酌：是否要写出"Python 为主自 2026"。

## E. 需本人补齐（JD 看重、我无记录）

| JD 项 | 需要的信息 |
| :--- | :---: |
| 学位 / 年限 | [PhD 领域、年份；相关经验年数] |
| 病人来源转化数据（IHC/cytokine/ctDNA/PK-PD/H&E） | 是否有过任何一类？ |
| 制药 / 早期临床经历 | 有无？ |
| 发表、公开软件、portal | 列表 |
| 培训非工程师 | 是否给客户/同事做过 workshop、教程讲解？ |
| H&E / HALO / QuPath / 深度学习分割 | 有无接触？ |
