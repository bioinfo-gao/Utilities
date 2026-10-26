---
name: project-setup
description: "Use when 新建一个分析项目,或要在项目里写计划文档/step 脚本/样本表——项目文件夹自动连续编号、scripts/0_sample_table.csv 作为 SSOT、research_plan_and_review 的命名与「永不改名」、计划里必须记录每样本与总数据量、numbered step scripts 先写后跑、代码与可见文档同步、symlink 文件名自解释、开跑前先查 software_pitfalls"
---

# /project-setup

> 建项目与写项目内文档/脚本的约定。这些约定决定了别人(和未来的自己)能不能复现这个项目。
>
> **来源**：2026-08-30 从 `~/.claude/CLAUDE.md` 按 L0/L1 分层搬出，**逐字未改**。
> 搬出前的整份 CLAUDE.md 存档在
> `~/.claude/superseded_for_comparison/CLAUDE_md/v1_20260830_pre_L0L1_split/`。
> ⚠ 本 skill **未设** `disable-model-invocation` —— 必须能被自动调用，
> 否则规则搬进来就等于消失（审计表 §4.2 标出的缺口）。

---

## New project folders — AUTO-NUMBERED SEQUENTIAL NAMING (MANDATORY)

  - **Active parent folder (updated 2026-07-21): `/home/gao/projects_2026M7/`** — a symlink to
    `/mnt/ex_8T_SSD/projects_2026M7/` (physically on the 7.3T SSD `/dev/sda1`, same disk as the old
    parent). Project 18 (`18_Pengpeng_Zhou_gut_metagenomics`) was the first project moved here from
    `projects_2026H2/`. **`projects_2026H2/` is retired for NEW projects but stays in place, untouched,
    as the historical archive** — do not create new numbered folders there anymore. Update this note
    again if the active parent changes in the future (e.g. a later `projects_2026M8`/`2027M1`-style
    folder), mirroring how this note itself was updated from the old `projects_2026H2` convention.
  - **`projects_2026M7/` has its OWN separate git repo** (initialized 2026-07-21, independent from
    `projects_2026H2/`'s repo — not a submodule/fork/continuation of it): remote
    `git@github.com:bioinfo-gao/GZ_Projects_2026M7.git`, branch `main`. Same `.gitignore` +
    `.githooks/pre-commit` (>10MB block, `core.hooksPath .githooks`) ported over from the old repo —
    see `/git` skill's known-repos table. Git commands/push follow the same standing authorization
    and large-file-exclusion discipline as the old repo (see git skill).
  - Whenever a NEW analysis project starts — regardless of analysis type (RNAseq,
    WGS, single-cell, taxprofiler, or anything else) — do NOT ask for a folder
    name convention. Instead:
    1. List the existing numbered folders in **both** `projects_2026M7/` (current) and
       `projects_2026H2/` (historical archive) and find the HIGHEST numeric prefix across the two
       (ignore non-numbered folders like `OLD/`, `facilities/`, `General_R_tools/`) — the sequence is
       shared/continuous across both locations, only the physical parent changed.
    2. Create the new folder **under `projects_2026M7/`** with the next integer prefix, followed by an
       underscore and a short descriptive name, e.g. if the last is
       `18_Pengpeng_Zhou_gut_metagenomics`, the next project becomes `19_<name>`.
    3. Use a concise name reflecting the client/subject or analysis, matching the
       existing style (e.g. person name like `13_John_Doe`, or topic like
       `13_mouse_rnaseq`).
  - This numbering is global and continuous across all project types — never
    restart numbering per analysis category. One shared sequence for everything.


## Sample table — standalone CSV in `scripts/`, every project (MANDATORY — user directive 2026-07-24)

  - Every project must have a **standalone sample table**: one row per sample, covering exactly what a
    time-pressed reader needs at a glance — sample ID, group/arm assignment and any other design
    dimensions (cage/day/timepoint/batch/etc.), and per-sample data volume (R1/R2 GiB, raw read pairs, per
    the "Analysis plans MUST record input data sizes" rule below).
  - **Format: CSV**, not only an embedded table inside a narrative `.md` plan — machine-readable, quick to
    open and skim directly.
  - **Location: `scripts/`** (e.g. `scripts/0_sample_table.csv`), not buried in `docs/` or only inline in
    the plan document. Reason (user's own words): "我时间短的话，不看全文的，就快速看样本表" — when short
    on time the user goes straight to the sample table instead of reading the whole plan.
  - This CSV is the **canonical source (SSOT)** for sample/group/design info: other scripts (e.g. a
    `1_build_metadata.R`) should READ this CSV rather than re-hardcoding the same design table inline, and
    a narrative plan doc should reference/link it rather than duplicate it (see the single-source-of-truth
    rule below).
  - When a project reuses another project's samples (e.g. a redesign/rebranch of an existing project),
    generate this table fresh in the new project's own `scripts/` (carrying over the relevant columns)
    rather than leaving the reader to dig through a different project's docs to find it.
  - Applies going forward to every project, all analysis types (RNAseq, WGS, single-cell, shotgun meta,
    etc.) — established in project 21 (`21_Daniel_Mendes_gut_meta_redesign`), first applied there
    retroactively, and to be applied to all new projects from the start.


## Research/analysis plans — NEVER rename, filename = creation date forever (MANDATORY — user directive 2026-07-12)

  - Scope: **internal research/analysis-plan documents only** (`analysis_plan_MMDD.md` and similar
    process/planning `.md`). **Client-facing reports are the OPPOSITE — they MUST be re-dated on
    revision** (see "Re-dating on revision — CLIENT REPORTS ONLY" in the Client/research reports
    section). Do not confuse the two.
  - The `MMDD` in a plan's filename is its **creation date and is immutable**. When you substantively
    edit an existing plan: do **NOT** rename the file, do **NOT** create a new-dated copy, do **NOT**
    delete the original. The user reconstructs the research process/timeline from plan creation dates;
    renaming scrambles it.
  - Record every revision INSIDE the plan instead:
    - Keep the header's creation date unchanged (e.g. `Plan Date（创建）: 2026-07-07`).
    - Maintain an in-document **更新记录 / change-log** block under the header; append one dated line
      per revision (e.g. `- 2026-07-12 — §1 补入每样本文件大小 + 数据集总量`).
  - Incident that established this rule: I re-dated `14_.../analysis_plan_0707.md` → `_0712.md` and
    deleted the original; the user had to revert it because it broke their timeline tracking.


## Research-plan doc — NAME `research_plan_and_review`, PREFIX WITH PROJECT ID (MANDATORY — user directive 2026-07-17)

  - **Applies to NEW projects from 2026-07-17 onward only. Do NOT rename/touch existing
    `analysis_plan_MMDD.md` files in already-started projects** (that would violate the
    "NEVER rename" rule above) — this new convention is for plan docs created from now on.
  - **New canonical name: `research_plan_and_review`, not `analysis_plan`/`plan`.** Reason:
    the plan is repeatedly adjusted DURING and AFTER the run (design → in-run tweaks →
    post-run review), so a bare "plan" understates the file's nature — it is a living
    plan-plus-review record. It stays ONE living document keeping its creation-date filename
    forever and logging revisions inside the file (the "NEVER rename" rule above still governs it).
  - **Filename MUST begin with the project ID** so the owning project is readable from the
    filename alone (many files pile up; the user needs to tell at a glance which project a
    file belongs to). Use `P<NN>` or `Proj_<NN>` as the prefix.
    - **Canonical format: `P<NN>_research_plan_and_review_MMDD.md`** — e.g. for project 16:
      `P16_research_plan_and_review_0717.md`. `MMDD` is still the immutable creation date.
    - Prefer prefixing OTHER internal per-project docs (design/decision notes, key_operations_log,
      etc.) the same way (`P16_...`) when it aids at-a-glance identification.


## Analysis plans MUST record input data sizes (MANDATORY — user directive 2026-07-12)

  - Every analysis plan / analysis-design document (`analysis_plan_MMDD.md` and equivalents)
    MUST record the input data volume, at BOTH granularities:
    1. **Per-sample file size** — a column in the sample table giving each sample's raw
       input size (e.g. per-sample `R1/R2 (GiB)` for paired FASTQ, or the single-file size
       for other data types). Model on `13_Ellen_knockin_wgs/docs/analysis_plan_0708.md` §1
       (the `R1/R2` column, e.g. `26G/26G`).
    2. **Total dataset size** — the summed volume of the whole cohort (e.g. "12 samples,
       gzip FASTQ 合计 462 GiB / `du -shc` 463 G"), stated near the sample table.
  - Get the numbers from the actual files on disk (`ls -l` / `du -shc`), not from memory or
    the client's claim; note the measurement date and source path. These sizes drive disk-space,
    runtime, and thread/queueSize planning, so they belong in the plan, not just in one's head.
  - Apply to ALL analysis types (RNAseq, WGS, single-cell, taxprofiler, …), not just WGS.


- Step scripts before execution — WRITE NUMBERED STEP FILES, REVIEW, THEN RUN (MANDATORY):
  - Once the overall analysis plan is set, do NOT just fire ad-hoc commands. Write the concrete
    per-step work (code/commands) into numbered files in a local `scripts/` subfolder of the
    project (further split into sub-subfolders — e.g. `study_A/`, `study_B/`, with a shared
    `0_common/` — when a project has clearly distinct arms). Number the steps in execution order.
  - After the scripts are written, review them yourself (syntax-check, dry-run where safe) and/or
    present them to the user for review. Only after that review do you actually execute.
  - Purpose: the user can see and trust exactly what will run and reproduce it later; nothing runs
    that isn't written down and inspectable first. Keep the scripts and any notebook/plan in sync
    (see the single-source-of-truth and code-synchronization rules).


- Code synchronization — KEEP VISIBLE FILES IN SYNC (MANDATORY):
  - Any time the actual executed command changes (parameters, structure, tool order,
    thread counts, file paths — anything), the corresponding notebook cell or script
    file the user can see MUST be updated in the SAME response, before moving on.
  - Never run a command that differs from what the notebook/script shows. If they
    diverge even briefly, the user cannot trust or reproduce the analysis.
  - If a pipeline is redesigned mid-run (e.g. switching from 3-way pipe to 3-step),
    update ALL affected notebook cells immediately — description cells, code cells,
    parameter tables — not just the one cell with the command.


- Symlinks — FILENAME ITSELF MUST SELF-DOCUMENT "THIS IS A LINK" (MANDATORY):
  - When creating a symlink (e.g. to share one canonical file across two projects instead
    of duplicating it — see the single-source-of-truth rule above), never leave it named
    identically to the target (e.g. plain `key_operations_log.md`). A terminal's `ls -la`
    shows the `-> target` arrow, but bioinformatics work now happens mostly inside an IDE
    (Positron, VS Code, etc.) whose file browser does NOT visually distinguish a symlink
    from a regular file — so the filename is the only cue a reader gets.
  - **Format (exact template): `sLk_of_<original_filename>_in_<short_tag>`** — e.g. a
    symlink living in project 14 whose canonical original is `key_operations_log.md` in
    project 13 must be named `sLk_of_key_operations_log_in_project13.md`.
    **`<short_tag>` is a short, simple label (like `project13`, `proj13`, or a project
    nickname) — NEVER a full/absolute path.** A full path is far too long and unwieldy to
    put inside a filename; the tag only needs to be specific enough that a reader can
    locate the real file (by searching the projects directory for that name), not a
    literal filesystem address. The name alone must answer both "is this a link?" and
    "roughly where's the real file?" without needing to run `ls -la` or open the file.
  - Also add a short note inside the canonical (target) file's header stating which paths
    symlink to it and reminding future edits to happen in the canonical file, not the link —
    and **update that note whenever the symlink itself is later renamed** (e.g. after the
    numbering fix below), so the pointer never goes stale.
  - **If the symlink's target directory uses numbered filenames** (e.g. `1_foo.sh`,
    `2_bar.sh`, ... a personal notes/tutorial folder numbered by topic order), **prefix the
    `sLk_of_...` filename with the next number in that directory's sequence** (highest
    existing number + 1), same as any other file being added there — the symlink is just
    another entry in that numbered list and should sort with it, not sit unnumbered at the
    end. Example: target dir's highest file is `12.foo.sh` → symlink becomes
    `13_sLk_of_<original>_in_<tag>.md`. Established 2026-07-25 in
    `/home/gao/Utilities/git/git_Advanced/` (`13_sLk_of_git_in_software_pitfalls.md`).
  - Prefer symlinks over hardlinks for anything that will be edited again (see
    `facilities/cmd_tools/软链接_vs_硬链接.md`): most editors save via write-new-file-then-
    rename, which silently desyncs a hardlink (fresh inode) with no error, while a symlink
    (resolved by path at access time) stays correct.


## Step-script / 总控设计规则（P41 实测，2026-10）

> 来源：`/home/gao/projects_2026M7/41_Vedict_18_wgs/docs/P41_incidents_and_pitfalls_1006.md`（I-2、I-3、I-6、I-7、I-9）。
> 运行期的监控与总控失败告警见 `watchdog` skill「自写总控 / 守候脚本的坑」，这里只放**写脚本时**就要定下的设计。

- **总控由样本表驱动，且可追加**（I-3）：总控在启动时 `ls` 一次目录枚举样本是错误的耦合点——Dropbox 渐进同步，P41 开跑时只有 16/18 对，后到的 2 个无法加入，只好用"SIGSTOP 冻结总控 + 守候"临时拼装，结果死锁（I-1）。⇒ 每一步**每轮重新从 `scripts/0_sample_table.csv` 枚举**待处理样本（已完成的靠 `.done` 跳过）；缺样本时要么等齐，要么让总控可追加，不要冻结 + 守候。
- **依赖样本集合的缓存文件名带样本数**：如联合 call 写成 `chr22_joint_n${N}.vcf.gz`，否则新增样本后会静默误用旧缓存。
- **冒烟测试覆盖每个消费脚本、每个样本类别**（I-2、I-6）：P41 冒烟只测了核心证据脚本和命令，解析 mosdepth 输出的 QC 汇总脚本没测 ⇒ 正式跑到第 4 步才崩；冒烟只用了一个细胞系的 BAM ⇒ 只有 B 细胞系才会触发的失败（对照窗口落在 IGH）没被发现。凡是"从第一个/某一个样本挑参数"的步骤（选对照窗口、定阈值），都要验证它**对所有样本**成立。
- **同一类缺陷出现第二次，立刻全局 grep 所有同类消费者**（I-9）：I-2 修了一个脚本的 `split()[3]`，没 grep 其他读同一文件的脚本，8b 又因同一缺陷炸一次，多空转 10 h 50 min。
- **对 N 个独立对象做 I/O / BAM 随机访问的循环，默认写成并行**（I-7）：判据 = 循环体不依赖上一轮 + 每轮 >10 ms。粒度用"对象 × 块"（P41：18 样本 × 200 事件 = 396 任务，`Pool(12)`），避免对象数少于进程数时尾部空转；**先统计不同位点数 / 总次数，重复多就先去重或缓存**（P41 4,266 个事件只有 1,995 个不同位点）；每个 worker 自己打开 BAM（pysam 句柄不能跨进程）。效果：串行 >76 min 未完 → 并行 157 s。
- **计划阶段就估线程和耗时，并且用实测速度**：把"汇总步骤"当轻量而不估它的 BAM 随机访问次数，是 I-7 的起因；用冷缓存下的单次耗时外推会严重失真（估 ~3 h，实测 157 s）——估算只当数量级，首个样本跑完后用实测速度回填计划。


## Cross-project software pitfalls directory — LOCATION + NAMING (MANDATORY — user directive 2026-07-21, relocated 2026-07-25)

  - **Location: `/home/gao/Utilities/software_pitfalls/`** — moved here 2026-07-25 when the user had
    three generations of personal tool/reference folders merged into one canonical `/home/gao/Utilities/`
    (see [[reference_utilities_consolidated_2026H2]]). **All future pitfall reviews/updates go to this
    path.** The old `/home/gao/projects_2026M7/facilities/software_pitfalls/` (previously the canonical
    location, tracked by that project's own git repo) is now a frozen archive — do not update it further.
    **`/home/gao/Utilities/` IS its own git repo** (corrected 2026-08-04 — an earlier note here wrongly
    said it was un-versioned; it was in fact `git init`-ed on 2026-07-25, the same day as the
    consolidation): remote `git@github.com:bioinfo-gao/Utilities.git`, branch `main`,
    `core.hooksPath .githooks` with the same >10 MB `pre-commit` blocker as the projects repos.
    So edits here ARE version-controlled — commit them like any other repo (standing git authorization
    applies; surface `push` before running it). Do NOT suggest `git init` here.
  - **Purpose**: a cross-project, tool-indexed quick-reference for software/environment pitfalls —
    version traps, silent failures, env/PATH quirks, container-vs-conda gotchas, etc. — so a pitfall
    hit once in one project (e.g. bowtie2 2.2.3 too old in `mag_biobakery`) is checked here *before*
    reusing that tool in a later project, instead of being re-discovered from scratch. Incident that
    prompted this: project 18 already found "bowtie2 2.2.3 too old, must build in container" but that
    fact lived only inside `project_18`'s own memory note; project 17 repeated the exact same trap on
    2026-07-21 because there was no dedicated, discoverable place to check first.
  - **`INDEX.md`** at the directory root lists every tool file, one line each, so the whole catalog is
    scannable at a glance; each per-tool file holds the concise pitfall write-up and cross-links back
    to the fuller `reference_*` memory entry where one already exists (don't duplicate full content —
    index + link, consistent with the single-source-of-truth rule below).
  - **Directory names — ALWAYS English (ASCII) only, no exceptions.** This applies repo-wide to any
    NEW directory under this pitfalls tree (and is good practice generally): folder names must stay
    portable across tools/shells/OSes and sort predictably.
  - **File names — prefer English; Chinese is acceptable when it reads more naturally for a specific
    entry** (matching the existing mixed style already used elsewhere in `facilities/`, e.g.
    `软链接_vs_硬链接.md` alongside `STAR_VS_HISAT2.md`). English is the default, not a hard rule, for
    filenames specifically — unlike directory names, which are English-only with no exception.
  - **Check it BEFORE, not just after.** A pitfall recorded but never looked up again is worthless —
    that is literally how the bowtie2 2.2.3 trap got hit twice in one day (proj18 recorded it,
    proj17 didn't check and repeated it hours later). So, as standing practice:
    1. **Before invoking a skill that wraps an external tool/pipeline** (e.g. `/wgs`, `/taxnom`,
       `/tax-assembly-mag`, `/tax-functional-humann`, or any skill that shells out to sarek,
       taxprofiler, mag, bowtie2, HUMAnN, etc.) — skim `INDEX.md` for a row matching that tool before
       running real commands, not just when something breaks.
    2. **Before launching a new project's real pipeline run** (post the "启动语义" gate above, i.e.
       once 自动/全流程 is confirmed) — scan `INDEX.md` for every tool the planned pipeline touches,
       not only the ones you happen to remember having trouble with before. Memory is exactly what
       fails here; the whole point of this directory is to not depend on remembering.
    3. If a step in this check surfaces a relevant entry, apply its fix/workaround up front rather than
       discovering the same failure mode again and writing a near-duplicate memory.
