---
name: report
description: "Use when 要写或修改客户报告、客户邮件、或任何交付给客户的文字——报告 §1–§9 结构与 §2/§8.2 两份、三处日期一致、署名、缩写首次出现给全称并消歧、交付目录命名(全量 vs supplementary)、内部中文/交付全英文的语言与科学术语取舍、以及「除非有实质性错误绝不否定之前的提交」的归因框架"
---

# /report

> 写客户报告/邮件时的完整规则。写文件时 `route_post_write.py` 会自动跑 `checks/check_report.py` 或 `check_client_email.py` 做硬检查,本 skill 是那些检查背后的判据全文。
>
> **来源**：2026-08-30 从 `~/.claude/CLAUDE.md` 按 L0/L1 分层搬出，**逐字未改**。
> 搬出前的整份 CLAUDE.md 存档在
> `~/.claude/superseded_for_comparison/CLAUDE_md/v1_20260830_pre_L0L1_split/`。
> ⚠ 本 skill **未设** `disable-model-invocation` —— 必须能被自动调用，
> 否则规则搬进来就等于消失（审计表 §4.2 标出的缺口）。

---

## 审阅状态 — 客户报告默认在内部审阅阶段 (MANDATORY — user directive 2026-10-26/27)

> 完整规则在共享规则「对外交付与署名」一节（`instructions/SHARED_AGENT_RULES.md`），本节只是写报告时的提醒，判定词以那里为准。

- 任何客户报告/交付包**默认 = 内部审阅中、未发送**。只有用户说 **「审阅完毕」「已审阅」「审阅完成」** 之一才算通过全面审阅。
- 审阅中的报告：照常出新版本（新日期目录、旧版归档），不问是否已发客户。
- 已通过审阅的报告：任何再修改之前先提醒用户"这是已通过审阅、可能即将发出的版本"。

---

- Client/research reports — FORMAT, DELIVERY FOLDER, AND SIGNATURE (MANDATORY):
  - All formal research reports and client deliverables MUST be written in **English**.
  - Every report must be signed: **Zhen Gao, PhD, Principal Bioinformatics Scientist, Athenomics**
  - **Report file name: `<ProjectName>_MMDD.md`** (month + day suffix, no year — keeps names short).
  - Report header: include Report Date, Prepared by, and Analysis Platform (e.g. "Linux HPC server").
    **Do NOT include the internal conda environment name** — it is irrelevant and distracting to clients.
  - **Species + tissue/cell in the header — MANDATORY (user directive 2026-07-15):** every report
    header — BOTH internal research reports AND client-facing reports — must state, up front, the
    **Species** (e.g. `Homo sapiens (GRCh38)` / `Mus musculus (GRCm39)`) and the **Tissue / Cell type**
    of the material (e.g. `PBMC`, `whole blood`, `tumor biopsy`, `CHO-K1 cell line`, `liver`). Surface
    these in the header block so the reader knows what organism and material the results describe before
    reading anything else — do not bury them only in a later Sample Information section. If tissue/cell
    is unknown/unspecified by the client, write `Tissue/Cell: not specified by client` rather than omit.
  - **交付物只写客户「本轮」实际提供的样本元数据 —— 文件名也算 (MANDATORY — user directive 2026-08-09):**
    - 交付物里出现的样本元数据（物种、组织/细胞、细胞系、品系、基因型、处理条件…）**必须是客户在
      本轮实际提供的**。**上一批 / 上一个项目带过来的，或 agent 凭背景知识补的，一律不进交付物。**
    - **涵盖三处，缺一不可**：① 报告 header 字段；② 报告正文的叙述性句子（Objectives / Conclusions
      的措辞）；③ **交付物文件名**。只改正文不改文件名 = 只修了一半。
    - **客户没说时如实写出来，不省略、不替他填**：`Tissue / Cell: not specified by client`（见上条）。
      正文叙述退到客户确实说了的那一层 —— 送样单只写 `Species: Human` 就说 "human cells"，
      **不要升格成具体细胞系**。
    - **出处存进内部 `P<NN>_research_plan_and_review_MMDD.md`**（原文照录 + 出处 + 范围限制），
      那是它该待的地方。**内部项目文件夹名可以保留该信息**（检索线索，非对外陈述）。
    - **Why**：交付物带用户本人签名。把"我们知道／我们推测"的东西写成样本元数据的样子，读者
      无从分辨哪些是客户给的、哪些是我们加的；客户本轮一旦换了材料，整份报告的事实基础就错了。
      这是「没做过的检查不得写成带结论意味的句子」在样本元数据上的具体化。
    - **发现这类问题时要一次查全所有出现位置**（`grep -n` 把该词在正文与文件名里每一处都列出来），
      不要只改被点名的那一处。事故：proj26/27 一轮里报告写成 `MOLM13 acute myeloid leukemia cell
      line`，其中 `MOLM13` 来自客户**上一批**的书面更正、`acute myeloid leukemia` **毫无出处**
      （agent 自补）；第一次只删了疾病标注、留下 `MOLM13`，**同一问题修了两轮才干净**。
  - **New-dated NEW deliverables for new results; OLD ones preserved intact — CLIENT REPORTS &
    RESULT TABLES (MANDATORY, user directive 2026-07-12):** deliverable artifacts — client reports
    (`<ProjectName>_MMDD.md`) and result/data tables — are **immutable historical records once
    produced**, and versioning happens at the **DELIVERY-FOLDER level**:
    - **The OLD delivery folder (`custom_research_report_YYYYMMDD/`) and EVERY file in it stay exactly
      as-is — untouched, never edited/overwritten/deleted.** It is the frozen record of that round.
    - When a **new analysis method / new run produces new results**, create a **NEW delivery folder
      with the NEW date** (`custom_research_report_<newYYYYMMDD>/`) holding the **new data + new report**
      (new `MMDD` in the report filename + new internal date fields). Old folder and new folder coexist,
      distinguished by date.
    - The point is a complete, append-only research trail: each dated folder is frozen as what was
      delivered on that date; new analysis adds a new dated folder beside it.
    - ⚠ Do NOT delete or modify a superseded old report/folder (this reverses the earlier "delete the
      old-dated file" instruction, which was wrong).
    - **⚠ This new-dated-NEW-file behavior is for DELIVERABLES (reports + result tables). It does NOT
      apply to internal research / analysis-plan documents** (`analysis_plan_MMDD.md` etc.) — a plan is
      a single living document that keeps its creation-date filename FOREVER and logs revisions inside
      the file (see the "Research/analysis plans — NEVER rename" rule near the top).
  - **Report section structure (MANDATORY — 2026-08-18 起 §2 改为 Core Conclusions，其余顺延):**
    1. Objectives
    2. **Core Conclusions** — **本报告第一重要的一节**：逐个受试对象（克隆/样本/组）「这结果对你意味着
       什么、该怎么办」，大白话，不带推导。**客户是非专业读者，没有能力通读全文**，所以"所以呢"必须
       出现在打开后第二眼，而不是埋在末尾的 Conclusions 里（proj29 原稿埋在 §7.2，前面隔着五节）。
       导语一句话交代与 §3 的分工，并点名 §8.2（同结论 + 证据出处）、§8.3（数据不能说明什么）、
       §8.4（每个未决问题对应做什么实验）。
    3. Key Findings — 3–5 条大白话要点，**逐主题**列"我们测出了什么"（§2 是逐对象的"该怎么办"，
       两节粒度不同，标题与导语必须让读者一眼分清）。
    4. Sample Information
    5. Analysis Rationale and Decision Criteria (the "why" and decision thresholds for each step)
    6. Methods (key tools + parameters, for reproducibility)
    7. Results (with numeric evidence)
    8. **Conclusions, Limitations and Next Steps** (detailed, tabular) — 含逐对象结论表、**§8.2 Practical reading（§2 的详版，
       每条标出证据在哪一节）**、Limitations、Suggested confirmation
    9. Deliverable Files
    - §8 用全名 **Conclusions, Limitations and Next Steps**，不要只叫 `Conclusions` —— 一份报告里
      同时有 §2 Core Conclusions / §3 Key Findings / §8，三个标题近似会让读者问"哪个才是结论"；
      全名同时说明了 §8 装的是逐对象结论表 + 限制 + 后续实验。
    - **⛔【一篇文档里出现"简单重复"= 不予通过】(MANDATORY — user directive 2026-08-27)：**
      用户原话：「**在一篇文档中，出现简单重复就是不允许通过**」「一篇文档为什么要重复？」
      - **判据只有一个：后出现的那一处，有没有【增量】。**
        **有增量 = 分层**（允许，有时还是强制的）；**没有增量 = 简单重复**（一律删或合并）。
      - **增量的形态**（举例）：多给**数字** / 多给**证据出处与文件名** / 多给**basis 与判据** /
        多给**更细的粒度** / 换一个**必要的读者视角**。
      - **⛔ 连带禁止：把某一节【描述成】另一节的重复。** 路标句必须写它**多给了什么**，
        不得写成 "the same answers / the same ground / repeats / restates / 再说一遍 / 同上"。
        反例（0827 实际写过并被否）："Section 8.1 sets out **the same answers** …;
        Section 8.2 **restates** the measured findings"。
        正例："Section 8.1 sets out **more detail** on each conclusion, together with **the basis**
        each one rests on; Section 8.2 **names the delivered file** behind each finding"。
      - **⚠ 与下一条不冲突**：§2 / §8.2 那一对**不是简单重复** —— §8.2 的增量是
        **每条挂证据出处**。判据仍是"有没有增量"，不是"内容是否相关"。
      - **工程要求**：起草脚本写成**反向断言**（出现即 `sys.exit`），与 banned 词表同一套机制。
        范例 `31_.../scripts/20260827/1_revise_report_0827.py` 末尾的
        `the same (answers|ground|findings)|repeats the|restates the` 检查。
      - **落笔前先 grep**：改完一处这类写法，必须在**本文档内**查全同类
        （范围规则照旧：只在本文档内查全，不扩大到别的文件）。
    - **§2 与 §8.2 是刻意的一简一详两份，两者都必须在**（user directive 2026-08-18）。§2 只给结论，
      §8.2 同样五条但每条挂证据出处。**少任何一份都算回退。**
    - ⚠ **章节整体后移会让正文里所有 `Section N.M` 交叉引用失效，而漏改一处既不报错也不影响渲染**
      —— 客户点过去看到的是另一节。改编号必须同时跑一遍引用可解析性检查
      （范例 `29_.../scripts/39_check_report_sections.py`：引用可解析 + 编号连续 + 两份 Practical
      reading 都在），并同步内部文档里 `报告 §N` 形式的引用。
  - **⛔【基本原则】缩写首次出现注明 full name (MANDATORY — user directive 2026-08-27):**
    用户原话：「**记住，缩写首次出现请注明 full name，这个是极其重要的基本原则**」
    「这个两个字母的缩写永远请注明，否则我极其难猜」；补充口径：
    「**对于有经验的分子生物学家和生物信息学家，其实大多数是知道的，
    但是 `DP` 这样的 2 字母缩写，实在没办法猜**」。
    - **⚠ 真正的判据不是字母数，是【领域术语】还是【某个工具/格式的字段名】：**

      | 类别 | 例 | 内部文档 | 客户交付物 |
      | :--- | :--- | :---: | :---: |
      | **工具/格式的局部字段名**（读者**无法**靠领域知识推出，只能查该工具文档） | `DP` `AD` `GQ` `MQ` `QD` `FS` `SOR` `AF`；FLAG 位名 | **必注，无例外** | **必注** |
      | **领域常识术语**（本领域专家从训练里就知道） | `DNA` `PCR` `DSB` `NHEJ` `HDR` `SNP` `gRNA` `PAM` | 可不展开（展开反成噪声） | **仍要注**（下游读者未必是专家，见下条） |
      | **跨领域强关联、会被读成别的东西** | `AAVS1`（含 "AAV" 但未用 AAV 载体） | **必注 + 消歧** | **必注 + 消歧** |

    - **短 ≠ 判据，但短确实是危险信号**：两三个字母几乎必然跨领域撞车
      （`DP` 被读成 "data points"，实为 read **D**e**P**th）。拿不准时**注**，成本极低。
    - **⚠ 给出全称还不够，还要说明它是哪一种量/口径**：`DP` 全称对了仍会被误用 ——
      它是"去重后 + MAPQ 阈值内 + **未做配对重叠校正**"的读段计数，
      与 mosdepth 默认的可用深度不是同一个数。
    - 下面这一条（跨领域撞车时的额外消歧）是**在此基础上的加强**，不是替代。
  - **缩写首次出现必须消歧 —— 因为报告的读者不止直接客户 (MANDATORY — user directive 2026-08-18):**
    交付物会被**客户的下游读者**看到（他的终端客户、合作方、审稿人）。判据不是"我们的对接人懂不懂"，
    而是**这个缩写在别的领域有没有强关联**；有，就在**首次出现处**用一句话消歧。
    实例：`AAVS1` = 人基因组 safe-harbour 位点（`PPP1R12C` intron 1），名字里的 AAV 只是历史命名；
    做基因编辑的对接人不会误读，**但有 AAV 背景的下游读者第一反应是"用了 AAV 载体"**
    （proj29 实测：用户本人正因熟悉 AAV 而困惑）。这类词首次出现时补一句
    "AAVS1 denotes the human safe-harbour locus in PPP1R12C intron 1; no AAV vector was used —
    the donor was a plasmid and Cas9/gRNA were delivered as RNP." 即可。
    ⚠ **"业内通用"不构成免解释的理由**；**已交付的报告不因此回改**（proj29 0818 维持原样）。
  - **A PCA plot, whenever one is included in the deliverable, must always be interpreted in prose
    in the report — never just reference the filename in a table and move on.** This one is
    mandatory (not optional/case-by-case) because PCA sample separation speaks directly to data
    quality: state variance explained (PC1/PC2 %) and quantify how samples/groups separate (e.g.
    within- vs between-group distance — don't just eyeball the plot).
  - Other plot types (volcano, heatmap, QC plots like Inner Distance/Adapter Content/DupRadar, etc.)
    are interpreted on request/as the user asks about them, not as a standing per-report
    requirement — don't force a written interpretation of every plot into every report.
  - **⛔【告知客户分析完成的邮件，必须点名报告文件作为入口】(MANDATORY — user directive 2026-08-29):**
    用户原话：「**最终告诉客户数据分析已经完成的邮件中永远告诉客户首先看分析报告文档作为入口**」。
    - **写法**：给出**交付目录名 + 报告文件名**，并明说"**先看它**"。例（proj31）：
      `Start with custom_research_report_20260828/Dual_Cut_Project_WGS_0828.md —— it is the
      entry point; every other file in the folder is referenced from Section 9 of that report.`
    - **⚠ 只给文件名与目录名，不写我方本机绝对路径**（`/home/gao/Dropbox/...` 是我们的路径，
      不是客户看到的路径），也**不写传输方式**（"不提数据传输"那条仍然有效，见下）。
    - **为什么是硬性要求**：交付包有几十个文件、多层子目录（proj31 是 51 个文件 / 11 个子目录）。
      **不指入口，客户第一步就卡住**；而报告 §9 本身就是全部文件的索引 ⇒ 指对入口，
      整个包才是可用的。
    - **反例（proj31 实测，2026-08-29 逐封回读 5 封已发邮件）**：**没有一封点名过报告文件**，
      其中 08-29 那封还引用了"Section 8.4"却从未说这是哪份文档的 §8.4 ⇒ 客户无从查起。
    - **工程要求**：邮件起草脚本把"报告文件名出现在正文里"写成**正向硬断言**
      （缺失即 `sys.exit`），与 banned 词表同一套机制。
  - **Delivery folder name: `custom_research_report_YYYYMMDD/`** (e.g. `custom_research_report_20260626`)
    for a **full** delivery — the first delivery, or a full redo the user explicitly asked for.
    **For an incremental/supplementary round, use `custom_research_report_supplementary_YYYYMMDD/`**
    (user directive 2026-07-29) so the folder name alone says "this is an add-on, not the complete
    package" — see the 增量/补充分析 section near the top for what goes inside it.
    The date suffix allows multiple rounds of analysis on the same project to coexist and be
    immediately distinguishable. Never use `delivery/`, `output/`, or an undated name.
  - **交付日期 = 用户审阅完成之日；审阅完成后在「原目录」上就地更新 (MANDATORY — user directive
    2026-08-09)。这是对上面命名规则的增补一步，不是否定它：**
    - **首次生成时标「生成当日」的日期 —— 这是对的，照旧执行。** 报告哪怕晚上 7 点、11 点才生成完，
      首次也照样标生成日。
    - **⚠ 绝不预测用户哪一天审阅。** 用户原话：「不猜测我哪一日审阅。我绝大多数情况都是次日审阅，
      但也可以今晚继续审阅，也可以过几日再审阅。」**不得**因为报告是晚上出的就自作主张标次日，
      **不得**按"通常次日"预填。**审阅期间日期一律不动**（用户还在提问／要求修改都不改）。
    - **只有用户明确说审阅完成了才动日期**，此时把 **三处一起** 改打审阅完成日：
      ① 交付目录名 `custom_research_report_YYYYMMDD/`；② 报告文件名 `<ProjectName>_MMDD.md`；
      ③ 报告正文的 `**Report Date:**`。**三处必须完全一致。**
    - **⚠ 是把原目录 `mv` 改名（就地更新），绝不是新建第二个目录再拷一份。任何时刻项目里只应
      存在一个 `custom_research_report_*` 目录。** 交付脚本若写成"目标目录已存在就 abort"的建新
      逻辑，重打日期时必然造出第二个目录。**事故（2026-08-09 proj27 实际发生）**：日期跨天后
      agent 自行新建 `_20260809/`，与原 `_20260808/` 并存、513 个文件完全相同只差报告一份，
      **用户一直在读旧的那个（未含已做的修正），差点把已知有错的报告审完。**
    - **工程要求**：审阅日必须是交付脚本的**显式参数**（默认今天只是兜底），一条命令三处同时重打；
      手改文件名必然漏掉其中一处。脚本要**自己带着该日期去调报告生成脚本**（日期只有一个来源），
      并**硬校验**：三处日期相等 **且** 交付目录里 `*.md` **有且仅有 1 个**（防旧日期报告残留），
      任一不满足即退出非零。范例：`27_.../scripts/8_build_delivery.sh <YYYY-MM-DD>`。
    - 内部 `Data_Analysis_YYYYMMDD/` 记录**分析实际运行日，不跟着改**；交付脚本必须能处理
      「源目录日期 ≠ 交付日期」（两者绑死会直接 abort，proj27 踩过）。
    - 这一步属**交付前复核、未重新分析** → 「就地修改 + 日期更新」，**不是新开一轮交付**
      （不与上面"新结果→新日期新文件"冲突：那条管**新分析产生新结果**，本条管**同一份结果的审阅定稿**）。
    - **不适用**于内部研究计划文档（`P<NN>_research_plan_and_review_MMDD.md` 的 MMDD 永远是创建日）。
  - **Internal folder structure is MANDATORY — never dump all files flat.** Organise by
    analysis type. Typical layout (adapt to the project):
    ```
    custom_research_report/
    ├── <Report_Name>.md          ← the report itself at the top level
    ├── qc/                       ← fastp HTML/JSON, MultiQC report
    ├── species_strain/           ← flagstat, depth files, mapping stats
    └── transgene/                ← assemblies, BLAST results, FASTA files
    ```
    For other project types, create logically named subfolders (e.g. `alignment/`,
    `variant_calling/`, `expression/`, `assembly/`) that group related files.
  - Copy — do not move — source files into the delivery folder.


## Document language — INTERNAL docs 中文优先 / CLIENT deliverables 全英文 (MANDATORY — user directive 2026-07-15)

  - **Internal research/analysis documents** — `analysis_plan_MMDD.md`, design/decision notes,
    `key_operations_log`, and any process/planning `.md` the client never sees — are written
    **preferentially in Chinese**, BUT **all technical/professional terms stay in their original
    English** for precision: tool names, parameters/flags, file & format names, metrics, algorithm/
    method names, gene/variant/HLA nomenclature, DB names, etc. Never translate a term into Chinese
    if doing so loses precision. Example register: "用 `bwa-mem2` 比对后跑 HaplotypeCaller 做 germline
    SNV/indel calling；gnomAD AF < 0.001 视为 rare variant，叠加 VEP HIGH/MODERATE consequence 判定 functional。"
  - **Client-facing deliverables** — `custom_research_report_*`, client reports, and any result/data
    tables handed to the client — remain **entirely in English** (unchanged from the reports rule
    below). NEVER apply the Chinese-preferred style to anything the client receives.
  - Chat/reply language still follows the existing zh/en-only rule (see `feedback_language_zh_en_only`).

  ### 科学术语的使用 —— 目标是精确，中英取舍只是手段 (MANDATORY — user directive 2026-08-26)

  > **完整版**：`/home/gao/Utilities/AI_and_Agent/General/scientific_terminology_zh_en.md`
  > （含分场合取舍、既定词表、落地断言写法）。**本块是生效副本，两边必须同步。**

  - **每个承重词过两道关**：① **用哪种语言写**（下面的四分法）；② **它在本文里是否只指一件事**。
    **⚠ 轴②与语言无关 —— 中英文都有歧义，换语言不能消除一词多义，只有限定能。**
  - **英文原生歧义在本领域很常见，别以为用了英文就安全**：
    `efficiency`（**等位基因** / **细胞** / **读段**三种分母，本项目三者数值不同）、
    `coverage`（广度 vs 深度）、`read`（read / read pair / alignment record）、
    `significant`（统计显著 vs 数量可观）、`control`、`sensitivity`、`variant`、`expression`。
    中文同理：`显著`、`覆盖度`、`对照`、`效率`、`表达`、`丰度`。
    ⇒ **写这类词必须带限定**（如 `fraction of alleles edited`、`breadth of coverage`）。
  - **⚠ 交付物"全英文"只免掉语言取舍，不免歧义 —— 那里的一词一义要求最高**：
    客户是唯一读者、不共享我方默认背景、且交付物会被转给他的下游读者。
    `copies` 那次事故就发生在**客户邮件**里，同一处歧义当时也躺在尚未发出的报告中。
  - **⚠ 技术术语以【我方口径】为准，不跟客户的不精确说法走**（user directive 2026-08-26：
    「我们是生物信息学家，我们分析数据，**对分析结果负责**。他们是实验生物学家，用词不一定准确」）。
    分两类：**客户给的专有名称**（样本名、项目名、构建体名）**照用不改**；
    **技术术语与定量口径**用我方精确说法并首次出现即定义。
    做法是**"用精确说法 + 一句对照"**，不是纠正对方
    （例：`the deletion is present on one of the two alleles (you referred to this as ~50% efficiency)`）。

  - **用户原话**：「高级读者经常发现中英文的命名往往各有优缺点……**英文世界中出现的很新的词、
    且没有标准中文翻译的词，包括大部分科学术语，尽量用英文原文**。因为对于高级专家，
    在文献中首先看到的是英文，并不需要翻译，**非标准翻译往往还导致误解**。」
  - **判断一个术语该怎么写，先归到这四类之一：**

    | 类别 | 处理 | 用户给的实例 | 为什么 |
    | :--- | :---: | :--- | :--- |
    | **中文明显更好** | **只用中文** | 代数学、特征值、特征向量 | `algebra` 源自阿拉伯语 *al-jabr*、`eigen-` 是未翻译的德语，对英语读者本身就不透明；中文直接说出"以符号代数""特征"，**更透明** |
    | **英文明显更好** | **只用英文** | socket、rational number | `套接字` 是生造；**`有理数` 更糟 —— `rational` 来自 *ratio*（两整数之比），经日译取了 `理 = reason`，于是 `无理数` 读起来像"不讲理的数"，把定义本身遮掉了** |
    | **两者都好、侧重互补** | **中英并存** | 光敏保护基团（caging group） | 中文说清"**是什么**"（光敏、保护性、可切除），英文是**本领域检索与沟通的术语** |
    | **英文新词、无标准中文译名（大部分科学术语属此类）** | **默认只用英文** | reporter、junction、microhomology、provirus、soft-clip、supplementary alignment | 专家在文献里先看到英文、不需要翻译；**自造译名会引入原文没有的歧义** |

  - **⚠ 第二条轴：保留英文原文 ≠ 消除歧义。** 还要问「这个词在本文里是否只有一个所指」。
    **实例（2026-08-26 客户来信）**：我方写 "not in all **copies**"，本意是 allele，
    客户按常识读成 cell —— 单克隆系里单等位缺失恰恰是**每个细胞都带**，
    于是那句话在客户读来等于"有一部分细胞没被编辑"，**与结论自相矛盾**。
    该项目里 `copies` 同时承担 **allele / cell / vector copy number** 三个概念。
    ⇒ **本身一词多义的词，一律写全限定形式，裸用视为错误**；
    这类词发现不了靠自己，**靠读者提问 —— 每一次"这是什么意思"都要回填成词表一行 + 一条断言**。
  - **⚠ 自造译名的两种典型危害**（都实测踩过）：
    1. **引入原文没有的歧义**：把 `junction` 译成「接头」——**测序语境里「接头」通常指 adapter**
       （接头去除 = adapter trimming）⇒ 一个词同时指两个东西。
    2. **译名本身是误读**：`有理数` 那一类，读者按字面理解会得到错误概念。
  - **落地**：内部文档写成**反向断言**（自造译名出现即报错）与**正向断言**
    （该并存的必须并存），范例
    `31_.../scripts/with_client_info_20260825/17_check_internal_doc.py` 的 B2 类。
  - **⚠ 批量替换后必须查重复 artifact**（"载体–基因组接头 junction" → "…junction junction"）
    并在中英相邻处补空格。


## 绝不否定之前的提交 — 除非确有实质性错误 (MANDATORY — user directive 2026-08-04)

  - **用户原话**：「除非有实质性错误，永远不要否定之前的一个提交，这回给我带来无穷无尽的麻烦。
    当然有原则性错误，应该承认和道歉。」
  - **为什么**：一旦在新报告里写"上一份的结论不成立"，客户会顺势质疑那份报告里的**其他所有
    结论**，终端客户会质疑整个项目，随之而来的解释、复核与商务代价**全由用户承担**。
  - **默认口径：新一轮是「延伸/细化」，不是「纠错」。**
  - **判据 —— 什么算实质性错误（坐标与数值必须分开看，user directive 2026-08-04）：**
    - **是**：旧报告把结论**当事实断言**而现证明是错的；**数值错误超出舍入误差**且改变结论或量级。
    - **否**：**坐标差异** —— 版本不同 / 0-based vs 1-based / 参考不同 / 比对口径不同，
      **绝大多数坐标不一致都属于这一类**，新报告里**说明来源与口径**即可，不该说成"上一份算错了"
      （本项目实例：J2_5p 由 36,824 细化为 36,991 是全长比对 vs 局部重比对的口径差；
      HA 注释与 WT-vs-KI 断点差 0–3 bp 是接头歧义区的固有差）。
    - **否**：旧结论**本来就带保留**（"most consistent with"/"suggests"），新数据给出更确定答案；
      旧**数据类型**本就分辨不了该问题而新数据类型能；**旧报告自己就建议做这项后续确认**
      （最明显的一类 —— 那是流程按设计运转，不是缺陷）。
  - **推荐词汇（用户给定）**：**加强证据 / 更强的证据 / 细化分析 / 进一步分析 / 延伸分析 /
    后续分析 / 得出更加确定性的结果 / 强化 / 细化 / 推进一层** —— 总之是**强化、细化、进一步**，
    不是**否定**。
  - **措辞对照**：❌"requires a revised interpretation"→✅"the confirmation recommended earlier
    has now been carried out"；❌"inconsistent with what the earlier report proposed"→
    ✅"resolves it one level further than the earlier data type could"；❌"not the X previously
    proposed"→✅"rather than the X the earlier measurement was equally consistent with"；
    ❌"this changes our recommendation"→✅"this refines the recommended method"；
    ❌"nothing is superseded **except**…"→✅"that report is unchanged **and its findings stand**"。
  - **⚠️ 这条不是让你隐瞒发现。内容照给、一个字不减，改的只是归因框架。**
    新发现该报的全报（数据、结论、对客户决策的影响）。**若确有原则性错误，必须主动承认并道歉**，
    说明影响范围与补救，不得淡化、不得埋在正文深处。与「客户报告不写含糊结论」不冲突：
    那条管"结论要敢下"，本条管"归因别自伤"。
  - 事故：MTTH 报告初稿写成 "requires a revised structural interpretation … inconsistent with …
    proposed in the 2026-07-12 report"。而 0712 原文是 "**most consistent with** … We recommend
    **confirming** structure **before using this founder**" —— 本来就带保留、且明确要求做该确认。
    **根本不存在实质性错误。** 详见 [[feedback_never_repudiate_prior_delivery]]。

  ### 适用范围扩到【一切对外沟通，邮件在内】—— 没有错就别顺便认错 (user directive 2026-08-26)

  - **用户原话**：「以后也这样，这个原则也注定用到 Email 通信中。没有错别顺便认错，
    这是人社交的一个原则，当然有重大错误必须承认。」
  - **本条原先只管"报告 vs 上一份报告"，现在同样管邮件、当面答复、任何对外文字。**
  - **判据不变，是唯一的判据：有没有【实质性错误】**（旧结论被当事实断言而现证明是错的；
    数值错超出舍入误差且改变结论或量级）。**没有 ⇒ 不认错。**
  - **以下一律不是错，不得写成认错**：
    **一词二义**（同一个词被用在两个概念上）、口径/坐标不同、读者按另一种合理读法理解、
    客户提问、客户要求解释、结论被后续数据细化。
  - **框架用"精确化 / 消除歧义 / 进一步说明"**，不用"修正 / 我们弄错了 / 是我方的问题"。
    用户给定的范式措辞：
    > `Thank you very much for your important question, giving us the opportunity to remove`
    > `ambiguity in word meaning, or the use of the same word for different concepts.`
    > `We will remove all ambiguity in the report accordingly.`
  - **⚠ 边界不变**：**确有重大/原则性错误时必须主动承认**，说明影响范围与补救，不得淡化。
    这条禁止的是**没错也认错**，不是禁止认错。
  - **工程要求**：对外文字的起草脚本把 `fix / mistake / error / wrong / misleading /
    sorry / apolog` 写成**反向硬断言**（出现即报错），与 banned 词表同一套机制。
    范例 `31_.../scripts/35_rewrite_client_reply_0826.py`。
  - 事故（2026-08-26 proj31）：客户追问 "not in all copies 是不是有些细胞没被编辑"——
    那是我方用 `copies` 指等位基因、客户读成细胞，**一词二义，不是错**。
    agent 首版回信写成 "You are right, and the wording was ours to fix"，被用户当场否掉。
