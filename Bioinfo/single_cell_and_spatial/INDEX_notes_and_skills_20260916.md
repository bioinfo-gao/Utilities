# 单细胞 / 空间：知识层文档 ↔ 可执行 skill 的索引

**建立日期**：2026-09-16
**为什么需要这一份**：本目录已积累 8 份综述/操作层文档，但它们回答的是「**为什么**、**什么变了**、
**选哪个**」；真正动手时需要的是「**照着做什么**、**哪个参数不能用默认**、**哪一步会静默出错**」。
2026-09-16 把后者抽成两个 skill，本文件是两层之间的对照表。

> **分工原则（SSOT）**：**skill 只写判据与动作，并引用本目录的文档作为依据，不复制论证过程。**
> 文档改了结论 ⇒ 改 skill 里对应的那一条判据；**不要让同一段论证在两处各自漂移。**

---

## 1. 两个 skill

| skill | 位置 | 覆盖 |
| :--- | :---: | :---: |
| `/scrna` | [`~/.claude/skills/scrna/SKILL.md`](/home/gao/.claude/skills/scrna/SKILL.md) | 设计门槛 → 环境 → 逐环节 SOP → 静默错误 → 自审 → AI/LLM 纪律 → 交付 |
| `/spatial` | [`~/.claude/skills/spatial/SKILL.md`](/home/gao/.claude/skills/spatial/SKILL.md) | 平台分流 → 生态与本机资产 → QC/域/SVG/去卷积/分割 → 静默错误 → 断言 → 交付 |

两者**都未设** `disable-model-invocation` ⇒ 可被自动调用。
细胞层面的通用规则只写在 `/scrna`，`/spatial` 引用而不复述。

---

## 2. 文档 → skill 的对照

| 本目录文档 | 它回答什么 | 被哪个 skill 的哪一节引用 |
| :--- | :---: | :---: |
| `scRNAseq_landscape_2023_to_2026_and_ecosystem_choice_20260910.md` | 三年变化、生态选型、90 天路线 | `/scrna` §0 §2 §3.3 §3.5 |
| `scRNAseq_refresh_1_data_objects_and_upstream_20260914.md` | raw/filtered、barcode、var、AnnData 七槽位 | `/scrna` §3.1 §4 |
| `spatial_transcriptomics_R_vs_Python_ecosystem_20260910.md` | 空间两类平台、逐任务生态、SVG/去卷积基准 | `/spatial` §1 §2.1 §3.3 §3.4 |
| `R_vs_Python_ecosystem_objective_comparison_20260910.md` | 逐环节包级对比 | `/scrna` §2（背景，未逐条搬入） |
| `R_and_Python_5yr_forecast_and_trainee_curriculum_20260913.md` | 五年预测与新人课程 | 不进 skill（是人的学习路径，不是执行判据） |
| `AI_in_singlecell_and_spatial_1_methods_20260910.md` | AI 赢/没赢的格、四条铁律 | `/scrna` §6；`/spatial` §0-3 §3.6 |
| `AI_in_singlecell_and_spatial_2_agent_workflow_20260910.md` | agent 失败原型与闸门设计 | 不进 skill（是元层，对应全局 CLAUDE.md 与 hooks） |
| `AI_in_singlecell_and_spatial_3_llm_biology_20260910.md` | LLM 注释/通路解读的可信度与规程 | `/scrna` §6 |
| `spatial_analysis_best_practices_20260917.md` | **工程纪律与可验证性**：观测单位的操作化、checkpoint 纪律、Python 空间断言库、12 条交付前自审、报告口径 | `/spatial` §5（Python 侧断言的 canonical 来源；skill 原先只有 R 版） |

---

## 3. 项目资产 → skill 的对照

| 项目 | 状态（2026-09-16 实测） | 在 skill 里的角色 |
| :--- | :---: | :---: |
| [`22_python_based_scRNA_tutorial`](/home/gao/projects_2026M7/22_python_based_scRNA_tutorial/) | 4 个 env 已建成并逐模块验证；`output_results/` 有 **ch1-1/1-1s/1-2/1-3/2-1**（后两个 09-16 新增），`done_stamps` 为 0 ⇒ 交互逐章跑，**2-1 之后尚无产物** | `/scrna` 的**可运行参考实现**与共享断言来源 |
| [`23_R_based_scRNA_tutorial_2026`](/home/gao/projects_2026M7/23_R_based_scRNA_tutorial_2026/) | 20 章写完，**2 个 env 从未建** | `/scrna` 的 R/Seurat 对照写法与 D4/D5/D8/D12/D13 判据来源 |
| [`24_R_advanced_scRNA_and_Spatial_tutorial_2026`](/home/gao/projects_2026M7/24_R_advanced_scRNA_and_Spatial_tutorial_2026/) | 17 章写完，**3 个 env 从未建** | `/spatial` 的空间断言（含 `assert_yaxis_flipped()`）与 D1/D5/D10 判据来源 |
| [`37_spatial_visium_heart_pilot`](/home/gao/projects_2026M7/37_spatial_visium_heart_pilot/) | **2026-09-17 建立并跑完**：Visium 人心 LV control 4 切片 / 11,725 spots，step1–6 全部产出，自审 9 PASS / 3 NOTE / 0 FAIL | `/spatial` 的**首个实地验证**；`scripts/_common/spatial_utils.py` 是 Python 空间断言的 canonical 实现 |

**⚠ 引用这些章节时的口径**：22/23/24 说「已写好可参考」，**不要说「已验证跑通」**。
**37 是例外** —— 它 2026-09-17 端到端跑完并留下了全部日志与产物，可以说「已验证跑通」。
它也是三个静默坑（基因标识符不匹配 / `.raw` 暗线 / Tangram 用 0 个基因照跑）的发现来源，
这三条已回写进 `spatial_analysis_best_practices_20260917.md` §4.6–§4.7。

---

## 4. 本次抽取时做的三个判断（可以反对）

1. **skill 按「细胞 / 空间」切，不按「Python / R」切。** 理由：语言选择是**每一步内部的**决定
   （如 pseudobulk 走 R、注释走 Python），按语言切会把同一条分析链劈成两半。
2. **`/spatial` 里写入了「今天能跑什么」的资产判据**（Python 空间 env 已装、R 空间栈完全未装、
   cell2location 因 3 GB 显存不可用 ⇒ 去卷积走 Tangram）。**方法学最优与本机可执行是两件事，
   skill 必须同时给出，否则会写出跑不动的计划。**
3. **不把「90 天路线 / 新人课程」写进 skill。** 那是给人排期的，不是给执行体照做的。

---

## 5. 已知缺口（写 skill 时暴露出来的，尚未补）

| 缺口 | 影响 |
| :--- | :---: |
| refresh 系列**二/三/四篇未写**（QC→聚类操作层、注释/整合/DE 操作层、空间入场） | skill 里这几节只能给判据，缺"字段具体怎么读"的对照 |
| R 侧 `sc_de_viz` / `spatial_r` env **均未建** | pseudobulk DE 目前只能用 `DE_R45`（有 DESeq2/clusterProfiler，**无 edgeR/limma/ComplexHeatmap/SCE**）；Voyager/nnSVG/RCTD 路线**今天不可执行** |
| proj22 的 27 章**跑到 2-1**（2026-09-16 实测） | 2-1 之后的章节（整合/注释/DE/轨迹/空间）尚未端到端验证 |
