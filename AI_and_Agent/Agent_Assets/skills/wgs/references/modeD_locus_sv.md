# 模式 D 完整参考 —— 指定位点结构变异 / 断裂-重排研究（clone vs population）

> 本文件由 `wgs/SKILL.md` 的「模式 D 专用流程」拆出（2026-10-29）。D0–D6 为原文搬入（来源 commit `7961b6d`，2026-10-25），另在 D2（竞争性再基因分型的局限）、D4（coherence 判据 ① 不能单用）各补一处；D7 为 P45 2026-10-26/27 审阅轮新增。
> SKILL.md 中只保留决策要点与必做断言；**动手做模式 D 项目前必须读完本文件。**

## 模式 D 专用流程 —— 指定位点结构变异 / 断裂-重排研究（P41 → P44 → P45 实测，2026-10）

> **来源（绝对路径，均为只读参考）**：
> - P41 初报 `/home/gao/projects_2026M7/41_Vedict_18_wgs/`：计划 `docs/P41_research_plan_and_review_1003.md`、参数 `docs/P41_key_operations_and_parameters_log_1003.md`、事故 `docs/P41_incidents_and_pitfalls_1006.md`（I-1…I-9）、背景 `docs/P41_background_dox_EBNA1_breakage_1007.md`；客户已收 2026-10-09 报告。
> - P44 rescue 设计 `/home/gao/projects_2026Q4/44_wgs_advanced_analysis_from_P41_by_cc/`：`docs/P44_research_plan_and_review_1024.md`、`docs/P44-learned-from-P42/P44_learned_from_P42_1025.md`（与 Codex 平行线 P42 的对比）。
> - P45 合并版 `/home/gao/projects_2026Q4/45_Vedita_18_wgs_combined_Advanced/`：`docs/P45_research_plan_and_review_1025.md`、`docs/P45_key_operations_and_parameters_log_1025.md`；交付 `custom_research_report_20261025/` → `20261026/` → **当前 `custom_research_report_20261027/`**（1027 版处于内部审阅阶段、未发送）。1027 审阅轮核查文档（D7 的出处）：`docs/P45_dox_specific_SV_chr4_chr8_verification_1027.md`、`docs/P45_DLD1_lineage_S04_vs_S02_S03_S05_1027.md`、`docs/P45_same_chr11q_homolog_explanation_1027.md`、`docs/P45_coherence_definition_explanation_1027.md`、`docs/P45_figure_reading_guide_Fig1_vs_P42_Fig02_1026.md`（第 3、7.5、13 节）。
>
> 案例：18 样本 ~15–30× PE150（DLD1 / GM12878 / Mutu I / DG75 的 population + 克隆；DLD1 +dox 克隆经 EBNA1 诱导断裂），靶区 chr11:114,604,000–114,625,500。

### D0 — 设计（P41，已交付验证）

| 决定 | 做法 | 为什么 |
| :--- | :---: | :--- |
| 不用 sarek | 自写 `bwa-mem2 mem -K 100000000 -Y` → `samtools sort`（2-way pipe）→ GATK MarkDuplicates（非 Spark，`OPTICAL_DUPLICATE_PIXEL_DISTANCE=2500`，**只标记不删**） | 要 BAM（Manta 吃 CRAM 病态慢）；`-Y` 让 supplementary 用 soft-clip ⇒ **hard-clip = 0，每条 record 的 SEQ 都是完整 read**，rescue 时不用回 FASTQ |
| 不 trim | 不跑 fastp | fastp 大文件死锁；但**代价是 adapter read-through 伪 split**（见 D3），下游必须显式识别 adapter |
| 参考 | GATK analysis set `Homo_sapiens_assembly38.fasta`（含 ALT/decoy/HLA/**chrEBV**） | EBV+ 细胞系的 EBV 读段要有地方放；chrEBV 覆盖顺带当样本身份探针 |
| 完整性断言 | BAM primary 记录数 == bwa 日志 "Processed N reads" 之和 | 防截断静默通过 |
| 样本身份三道断言（不过 exit 2） | EBV 状态与细胞系一致；同系性别一致；克隆与自己 population 的 chr22 基因型一致性 > 任何跨系样本 | FASTQ 编号 ↔ 样本编号常是推断，错位则整个减法作废 |
| 位点可比对性预检（开跑前 1.5 min） | 靶区自相似（minimap2 off-diagonal）、异位同源（asm20）、`seqkit sliding` 150 bp 模拟读段回贴（unique / MAPQ0 / misplaced） | P41 实测：靶区内部重复仅 ~60–86% 一致，模拟读段 **100% 唯一**——"重复区 ⇒ 多重比对淹没"的担心对该区不成立，假阳性主要来自**别处**的比对黑洞。边界：asm20 只抓 ≲5% 分歧的近期拷贝 |

**"不 mask 重复"必须逐 caller 落实到参数**（客户明确要求时；不是一句口号）：
- Manta 靶窗口联合运行：`graphNodeMaxEdgeCount` 10→**1000**、`minScoredVariantSize` 50→20、`--generateEvidenceBam`（默认 10 = 两端节点边数都 >10 的候选边直接跳过 = 自动回避重复区；详见 `software_pitfalls/manta.md`）。全基因组 Manta 保持默认，callRegions = 主染色体 + chrEBV。Manta libexec 要 `python2` ⇒ 脚本内 PATH 垫片指向 manta 环境。
- DELLY：**不用**官方 `human.hg38.excl.tsv`（屏蔽着丝粒/端粒/重复），`-x` 只排 ALT/decoy/HLA；联合基因型只对"窗口内有断点端的位点并集"做。
- 自写证据：MAPQ0、dup 只**分列计数**不丢弃；分级只用 nondup。

### D1 — 证据分级与"不存在"的口径（P41）

- **三路互相独立的证据**：Manta（图+局部组装）、DELLY（PE+SR）、自写读段级证据（split / discordant，caller 无关）。**caller 同意是加分项不是必要条件**——caller 在重复区恰恰最不可靠。
- **分级预先登记、开跑前定**（看结果再改 = p-hacking）：A = (s20≥3 且 pr≥2) 或 (s20≥2 且 caller)；B = snd≥2 或 (pr≥3 且 snd≥1) 或 (snd≥1 且 caller)；C = 任何痕迹，保留并标记。
- **split 按 fragment（QNAME）去重**，否则 R1/R2 跨同一断点算两次；朝外（RF）判据要求反向读段末端 < 正向读段起点（短于读长的片段仍是正常 FR，冒烟里曾造出 55 个假 DUP 簇）；插入片段阈值取 `median±5×MAD` 与 99.9/0.1% 分位数中**较宽者**（只用 MAD 会把正常右尾当 DEL）。
- **"克隆里没有" = 有覆盖却无证据**：跨断点参考 fragment `ref_span ≥ 10` 才可判 absent，否则 `underpowered`。按 Poisson（λ = 0.6×深度×AF）给检出功效表：克隆性事件（AF 0.5/1.0）≥25× 基本都抓得到；population 里 AF<0.1 的亚克隆抓不稳 ⇒ 只能写"低于约 10% AF 检出下限"。
- **阴性对照窗口本底**：100 个与靶区等长、深度 0.8–1.2× 中位数、可比对性相近的常染色体窗口（固定种子），同一套代码跑 ⇒ "无已知生物学的 21.5 kb 里每样本产出多少假 tier A/B"。**窗口数决定最小可达 p = 1/(N+1)**：N=40 永远到不了 0.01，P41 因此增至 100。
  - ⛔ **窗口必须对所有样本都可估计，并排除 IGH/IGK/IGL/TRA/TRB/TRG/TRD**：P41 只按第一个样本（DLD1）选窗，ctrl36 落在 IGH，13 个 B 细胞系样本因 V(D)J 重排窗口内几乎无正常配对 ⇒ 总控 FATAL 停 4 h 53 min（I-6）。替换单个窗口时**不重跑选窗脚本**（随机种子会让其余 99 个全变），只换那一个并在 Methods 写明。
- `universal`（四个细胞系都出现且 ≥75% 样本）= 参考差异/常见多态/系统性比对假象，**标记不删**。
- **深度是独立证据线**：P41 最终主发现来自 chr11q 10 kb 窗口深度（S04/S05 远端 ≈0.50×、近端 1.2–1.5×），而**不是**任何 tier A/B junction。看到图后才追加的分析必须在报告里写明"不在预先登记的 tier 体系内"。

### D2 — 第二轮 read rescue：先定义 data universe（P44 设计，P45 继承）

> 动机：P41 的区域查询只看"落在窗口里的 record"。**BAM 里没有 secondary record（比对没用 `-a`），多重比对只以 `XA` tag 存在**——本属该位点却被放到别处的 read，区域查询永远找不到。

- **抽取窗口 W** = target ±50 kb（第 1 轮 ±5 kb，扩窗改变 data universe ⇒ 开跑前须用户确认，§2A）；目标区 junction = 一端落在 target ±50 bp。
- **Rescue 集合 R** = 以下任一命中的全部 record（dup、MAPQ0、QC-fail 全保留打标签）：(a) record 在 W；(b) mate 在 W；(c) SA 任一段在 W；(d) **XA 任一 hit 在 W**；(e) 双端 unmapped pair 经 W 序列筛选命中。对 R 中每个 QNAME **取回全部 record**。(b)–(d) 只能**全 BAM 流式扫描**（P44：18 个 BAM，6 并发，每样 ~25–32 min，I/O 限速）。XA 是最大来源（每样本 3,920–7,946 pair）。
- **Stage 1 断言**：W 内无 secondary、无 hard-clip、无缺 SEQ——这是 §2A「SEQ 可用性 ≠ 完整性」的实测落地。
- **竞争性再基因分型**（"after rescue"的定义）：每个 junction 建 400+400 bp alt / ref 模板；read-end 跨 junction 每侧 ≥20 bp，且 **AS_alt ≥ AS_genome + 10 且 ≥ AS_ref + 10** 才计 alt（同一 repeat 拷贝能同样解释的 read 不计）；全部样本用同一模板同一规则分型；fragment 为主、read-end 并列。
  - ⚠ **该规则只证明 read 最像 alt 模板，不证明 alt 模板就是它的真实来源**：参考未收录的同源拷贝也能让 read 最像模板。必须再过 D7.6 的"背景细胞系出现 + 共享错配"检查。
- **Secondary 只在 AS ≥ primary AS − 10 时算"竞争 placement"**：rescue 再比对用 `-a` 会产出大量远低于 primary 的局部 hit（S04 W 内 66,300 条），不筛就把噪声当歧义证据。
- **Event grouping**：共享 ≥50% alt read-end 的 junction 合并为一个 event、计数取并集、列出 alternative placements（partner 在端粒重复等多拷贝序列时，同一批 read 能放到 chrX/4/2/10 多个末端）；有 alternative placement 即 Ambiguous。
- **Flank 唯一性**：junction 两侧 100 bp `bwa-mem2 mem -a`，数 AS ≥ best − 10 的 placement。
- **局部组装**只对 ≥2 非 dup fragment 的 cluster：SPAdes `--sc --only-assembler --cov-cutoff off -k 21,33,55`，read 先在 adapter 处截断（≥30 bp）——微小 read 集合下默认 k-mer coverage model 报 exit 64。
- **分级（P44 预注册）**：Well supported（≥3 fragment、≥2 类证据、两侧 flank 唯一、不确定区间 ≤10 bp）/ Limited（≥2 fragment、flank 唯一，但证据不足 Well）/ Ambiguous (repeat) / Weak（1 fragment）/ Not supported after rescue。
- **成果**：P44 找到了 caller 输出里**没有**的两个关键事件——S04 chr11:114,605,216 → (TTAGGG)n 端粒 junction（rescue 前 0 → 后 4 fragment，caller = neither）、S05 376 bp fold-back——两者都落在本样本深度断崖 95% CI 内。平行的候选封闭式分析（P42：从 caller 282 个候选收窄到 C1–C4）两个都漏了。**候选封闭式流程即使后续审计再严，也补不回被排除的证据。**

### D3 — 未 trim 数据的 adapter / poly-G artefact（P44 实测，必做）

- insert 中位 ~160 bp < 150 bp read ⇒ 大量 read 读穿 TruSeq adapter + index + poly-G 尾；**poly-G 尾被比对为 supplementary 到 chr2:32,916,3xx（参考上是纯 poly-G）**。P41 目标区 1,181 个事件里 693 个就是这个"chr2:32.9 Mb 吸附区"。
- 规则：3′ segment 起点 ≥ adapter 起点 − 5 的 split 不计；adapter 在 clip 前 10 bp 内的 3′ clip 不计，更深则只保留 insert 部分（≥20 bp）；segment / clip / discordant mate 的 Shannon entropy < 1.2 bits 判 low-complexity 不计；soft-clip ≥20 bp 才作断点证据。全部计入 filter-impact 表（6 样本试跑删 1,677 条）。
- 复核：`samtools faidx $REF chr2:32916330-32916480`（纯 G）；`samtools view <BAM> chr2:32916340-32916360` 可见 insert + `AGATCGGAAGAGC` + index + polyG。

### D4 — 结论层级与 caller concordance（P45）

- **claim ladder 是 evidence 分级之上的另一列**（`claim_level`，不替换分级）：mapping_observation → repeat_ambiguous_junction → limited_junction_candidate → **well_supported_junction_candidate** → **structurally_coherent**（① chr11 侧断点区间与本样本深度断崖 95% CI 有交集 **且** ② 断崖远端同样本为 LOH：≥90% baseline-het 位点变纯合）→ confirmed（需独立 assay 原始结果；无输入则预期 0，写进 `external_input_status.tsv`，**不当阴性**）。
  - ⚠ 预注册时**每个 evidence 级别都要映射到一个 claim 级别**：P45 v1 漏了 Well supported，2 个 GM12878 共有翼侧 junction 被并入 limited，低估证据强度；补级后 v1 归档。
  - 判据有区分力的实测：S05 chr21 junction 距 S05 断崖 CI ~1 kb ⇒ 不满足 ①；S03 10 bp inversion ⇒ S03 无 LOH，不满足 ②。
  - ⛔ **① 单独使用是空检验**：没有真实断崖的样本，断崖 95% CI 会宽到覆盖整个窗口（P45 基线 S01–S03 的 CI 为 38–49 kb），任何 junction 都"落在 CI 内"（J1635、J1036 在基线样本里通过 ①）。**② 证明断崖真实存在，① 证明 junction 在断崖上**，两者缺一不可。报告里 "coherent" 必须在 §5 定义一次再使用，不得未定义先用。
  - partner 端不明（如接端粒重复）但 chr11 端唯一、且 ①② 同时成立 ⇒ 可从 repeat_ambiguous 升到 coherent（P45 J0922）；chr11 端本身能在重复拷贝间滑动的 ⇒ 连 ① 都做不了，不升级。
- **深度断崖**：200 bp bin，以本样本 chr11:114.40–114.58 Mb 中位数归一再除以基线克隆均值；two-level step + 1,000 block bootstrap 给 95% CI（只抽完整 block，末端截断会让索引长度差 1）。**BAF/LOH**：chr11 联合 `bcftools mpileup -q20 -Q20 --max-depth 1000 | call -mv`，QUAL≥30；BAF 位点 = 基线全部样本 AF 0.25–0.75 且 DP≥10（S04/S05 远端 LOH 0.978/0.980，同一 homolog 保留 99.78%）。
- **4-caller concordance**：Manta、DELLY + GRIDSS（18 样本联合）+ SvABA（DLD1）；主口径两端 ±100 bp + 方向一致，另报最近距离与 ≤50 bp 标志；GRIDSS 单断端（ALT `.`）只记 anchor。**caller 一致 = 同一数据的算法一致，不是独立验证**；这句话在报告 Limitations 写一次即可。
- **P42 的"60× sensitivity gate"不要学**：~15× 数据不可能达到，所有候选"未过 gate"，结论只剩"什么都不能说"。用逐样本检出功效（AF 0.1/0.25/0.5 下 ≥2/≥3 fragment 的 Poisson 概率）替代，让"未检出"读作"在该 AF 以上未检出"。
- **genome-wide 版 clone-specific（客户 A2 要的是全基因组）**：DELLY germline→somatic 流程——合并基线 + 处理样本 discovery sites（`delly merge -y 0 -a 0.05 -v 5`，不预过滤）→ 逐 BAM re-genotype → `delly filter -f somatic` 只打标签不删；逐样本 present = 非参考 GT 且 DV+RV ≥3，absent = alt 0 且 DR+RR ≥10，alt 1–2 = low_support，其余 underpowered。genome-wide SNV/indel：同 chr11 参数按 5 Mb chunk 并行（S01–S10，632 chunk，20 并发约 3 h），**验收 = chr11 记录数与之前单独 chr11 call 完全相同**。

### D5 — 模式 D 专属代码坑（均已实测）

1. ⛔ **pysam 不在 `rec.info` 里暴露 `END`**：`info.get("END", pos)` 永远退回 POS ⇒ 所有 DEL/DUP/INV 变成长度 0 的点事件，caller 第二端永远匹配不上。改用 `rec.stop` 也不够——**DELLY genotyped BCF 的 rlen 写为 1，`rec.stop` = POS**。✅ 从 INFO 原文解析 `END=`。影响：P45 修正后 148 行 Manta/DELLY concordance 升级、G2 的 "with Manta" 计数 6→7。复核：`bcftools view -H -i 'ID=="<id>"' X.bcf | cut -f8 | tr ';' '\n' | grep ^END`。
2. ⛔ **pysam `rec.info.get(k, d)` 对 header 未声明的键抛 `ValueError('Invalid header')`**，不返回默认值。Manta 头里没声明 `CHR2`、DELLY 有 ⇒ 合并多 caller 时只在 Manta 行炸（P41 I-9）。✅ 先判 `k in rec.header.info and k in rec.info`。
3. ⛔ **mosdepth `regions.bed.gz` 列数取决于 `--by`**：整数窗口 → 4 列；带名字的 BED → 5 列。同一脚本里 `split()[3]` 对一类文件对、另一类错（取到窗口名 `w114604099`）。✅ 一律 `split()[-1]` 或 `*_, v`（P41 I-2 / I-9 两个脚本先后因此崩溃；"同类缺陷第二次必须全局 grep"的通用规则见 `project-setup` skill）。
4. **多模式 `grep -o` 会吞并重叠匹配**（引物特异性计数把 1 处计成 0）：每条 query 单独 grep，再用 `samtools faidx` 核对。
5. **bash `local c=$1 o="$O/parts/$c"`**：`$c` 在同一条 `local` 赋值前就被展开 ⇒ 所有分片同名、0 产物。同一条 `local` 里不要引用刚声明的变量。
6. **P41 运行工程事故（I-1…I-9）的通用规则已分别放在**：总控失败告警、`kill -0` 僵尸、心跳、`python -u`、`xargs -r`、日志命名 → `watchdog` skill「自写总控 / 守候脚本的坑」；样本表驱动可追加、冒烟覆盖每个消费者、BAM 随机访问循环默认并行 → `project-setup` skill「Step-script / 总控设计规则」。

### D6 — 模式 D 交付工程（P42/P44 对比后的固定做法）

- **BAM/VCF header 去本机路径并审计**：`@PG CL`、`##commandline` 等含 `/home/` `/mnt/` `/Work_bio` 的行改写（`samtools reheader` / `bcftools reheader`，检查命令用 `--no-PG`/`--no-version` 防止自身再写入路径）；`methods/header_sanitization_audit.tsv` 证明 record 数与 record 流 SHA-256 前后一致。DELLY BCF→VCF 同样出转换审计。
- **机读配套表**：`client_request_coverage.tsv`（客户每个问句 / 每项 deliverable 一行 → 状态 → 证据文件 → 边界）、`external_input_status.tsv`（PCR/FISH 等未提供项及其对解读的影响）、`data_inventory.tsv`（逐文件 bytes/md5/索引）、`key_junction_read_evidence.tsv`（关键事件每条 read end 的 FLAG/坐标/CIGAR/MAPQ/SA/XA/SEQ、模板 AS vs 基因组 AS、dup、query overlap/gap）、`figure_manifest.json`。self-audit 断言：账本行数 = 图中 read 数；表中每个证据文件存在；header 路径 = 0。
- **建议 PCR 就随附引物**：Primer3（flank → junction_overlap 两轮）+ 全基因组逐 query 精确命中计数要求唯一；避开重复单元；端粒 junction 附 STELA 类方案；无法唯一就写"无唯一引物"。
- **客户文字**：不出现内部项目编号（P41/P42…；前一份报告称 "the report dated 2026-10-09"），交付 ID 去内部前缀（`P44J0332` → `J0332`）；限定语只在 §8.3 写全一次；全基因组 BAM 不放进报告包，§9 写明另行传输。
- **复用上一轮产物**：只读复制（不用硬链接），写 `import_manifest.tsv`（源/目标 md5 + 源脚本 md5，并与源项目 git 最新提交比对）；来源脚本快照放 `scripts/<日期>/from_P<NN>/`，改过的版本放本层，可直接 `diff`。

### D7 — P45 审阅轮新增（2026-10-26/27 实测）

#### D7.1 ⛔ caller 给的 SV 类型/大小，写进 Key Findings 前必须三线复核

P45 1026 版 Key Finding 把 DELLY 的 `DEL00003167`（chr4，S05）写成 "888 kb deletion"——**区间深度 1.04×、358 个杂合 SNP 0 个 LOH，并没有丢失**；DELLY 自己的 `RDRATIO=1.007`、`RDCN=2` 早已不支持缺失，只是没被用于分级。同批 chr8 `DUP00005675`（S04，327 kb）复核成立。

| 证据线 | 做法 | 杂合缺失 | 单拷贝获得 | 拷贝数不变 |
| :--- | :---: | :---: | :---: | :---: |
| 深度 | MAPQ≥20、不计 deletion；先除本样本侧翼中位数，再除基线样本均值；区间内逐 bin（25–50 kb）看台阶边界是否与断点吻合 | ≈0.5× | ≈1.5×（clonal 比例 f：(2+f)/2） | ≈1.0× |
| 杂合 SNP 等位比例 | 基线全部杂合（DP≥10、AF 0.3–0.7）的位点，携带者 DP≥15；看中位 \|AF−0.5\| | >0.4（LOH） | ≈0.167（1:2） | ≈0.07 |
| 接头分子 | 接头 fragment 数、断点侧起点是否互不相同（独立分子）、参考跨越 fragment 数；基线样本接头数 | — | — | — |

- 三条信号来自同一批 BAM，但**信号类型彼此独立**；仍不是独立 assay 验证（需 PCR / ddPCR）。
- **DELLY 的 AF 在短插入片段文库里系统性偏低**（只用断点附近 PE+SR；P45 中位 TLEN 140–170 bp，chr8 真实 clonal 获得 AF 仅 0.23），不得据 AF 或 somatic filter 未过就否定事件。
- **insert 短于读长时 PE=0 不能否定事件**：几乎所有证据都以 split read 出现。
- 接头真实 ≠ caller 的类型正确：P45 chr4 是"真实接头 + 远端约 3.4 kb 小片段获得 + 888 kb 原样保留"（年轻 L1 对 L1 的另一接头在短读长中不可见）。报告保留 caller ID 与坐标，类型写成 "rearrangement junction (deletion-type orientation); no copy loss"。
- 未复核的其余事件，在报告里写明"未逐个复核"，不要混在已复核事件里同等表述。
- 参考脚本：`45_.../scripts/20261027/15_verify_top_dox_SV.py`（约 2 min）。

#### D7.2 D0 设计阶段必做：克隆谱系审计（谁和谁是同一亚谱系）

- **做法**（约 10 min，用联合 VCF）：常染色体双等位 SNV，QUAL≥30；要求所有同系样本 DP≥8、无关细胞系全部 0 alt read（排除胚系）；携带 = AF 0.25–0.75，不携带 = 0 alt；统计每种"携带样本组合"的 SNV 数，并看它们在 population 中的 AF。参考脚本 `45_.../scripts/20261027/16_dld1_lineage_snv_sharing.py`。
- **P45 实测**：S02+S03+S05 共享 84,480 个 SNV（population 中约 20% 细胞）；S04 独有 121,783 个（其亚谱系约占 population 10%）；任何含 S04 的共享模式只有 18–617 个 ⇒ **S04 自成一支，基线克隆里没有它的同亚谱系姐妹克隆**。
- **后果**：clone-vs-baseline 减法得到的 "case-specific" 事件，对**基线里有同亚谱系克隆**的处理克隆（S05）可解读为克隆化后新生；对**没有**的（S04）只能写"不能排除早于处理"——亚谱系原有事件在 population 里 AF≈0.05，~16× 下多为 0–1 条 read，会被判为基线 absent。
- 报告：§8.3 Limitations 写一条 sub-lineage；§8.4 建议补同亚谱系的未处理克隆。**这一步应在设计阶段做，不要等审阅时才因"异常的 18 个位点"倒查出来。**

#### D7.3 单向不一致 ≠ 随机误差：先查位点筛选是否造成选择偏倚

- P45：两克隆保留等位不一致的 18 个位点**全部** S04=ref、S05=alt，反向 0 个。随机分型误差应两向各半。根因：BAF 位点只取"基线 S01–S03 都杂合"，S05 亚谱系的体细胞 SNV 能过筛、S04 亚谱系的永远过不了。
- 规则：少量不一致**只朝一个方向**时，不得写"与分型误差同量级、不需解释"（P45 曾这样写，后收回）；先检查筛选条件是否对某组样本不对称。

#### D7.4 "同一条 homolog"检验（可复用方法）

- 在两个克隆**都 LOH** 的位点上，比较两者保留的等位是否相同：同一条 homolog 预期 ≈100%，不同 homolog 预期 ≈0%，没有中间结果 ⇒ 检验无歧义。P45：8,004 个位点 99.78% 一致（逐 2 Mb 均 ≥98.96%）。
- 能说"同一条 homolog"，**不能说父源/母源**（无供体父母基因型）。
- 配套：depth 减半 + ≥90% LOH 才说明"只剩一条"（若 LOH 但 depth 不减半 = copy-neutral LOH，另作解读）。断端不同 + 亚谱系不同 ⇒ 两次丢失独立发生。

#### D7.5 单 fragment junction 是每个样本的内置本底

- P45 Fig1 下层 258 个 junction 中 254 个是 Weak（1 fragment），247 个只出现在一个样本；**没有断崖的样本密度相同**（基线 21–27、GM12878 20–40、+Dox 15–21 个/样本）⇒ tandem repeat 内 read 错位产生的本底。
- 规则：**逐样本报告 ≥1-fragment junction 数作为本底**；单 fragment 的 case-specific 标记不作解读；只有高出本底的（≥2 fragment）才进入讨论。图注写明这一点。

#### D7.6 背景细胞系出现 + 共享错配 ⇒ 来源存疑（警告；分级口径未定）

- P45 J1592（GM12878 克隆 S07，Limited）：支持 read 还出现在 Mutu I、DG75（S11/S15/S17），**4 个细胞系 5 个独立分子在完全相同位置带完全相同的错配**；原始 MAPQ 0、XA 几十处；接头两端都在 Alu / L1 内。⇒ 更像参考未收录的同源拷贝或多态结构，不是克隆特异事件。
- 对照：真实接头（J0922）上 R1/R2 的错配位置互不重合 = 随机测序错误。
- **必做检查**：分级之外，对每个 ≥Limited 的 junction 列出无关背景细胞系中的支持数，并检查不同分子之间是否共享错配；有则在图与表中标注、正文不按克隆事件解读。
- ⚠ **分级是否应计入背景细胞系出现，用户尚未决定**（P45 图上已标注、分级本身未改）。在用户定口径前，按"标注 + 不解读"处理，不擅自改分级。

#### D7.7 测序盲区 ≠ 可比对性问题 ≠ 缺失

- P45 chr11:114,601,509–114,602,941 与 114,632,287–114,632,935：GC 7–8%、`TATATATT…` (TA)n，**MAPQ≥0 也为 0**，18 个样本 / 4 个无关细胞系同时为 0 ⇒ 建库 / 扩增盲区（推断；边界 soft-clip 未查）。
- 判别：MAPQ≥0 有 read、MAPQ≥20 无 ⇒ 可比对性；MAPQ≥0 也无且所有无关细胞系一致 ⇒ 盲区；仅部分样本为 0 ⇒ 才考虑缺失。
- 比值图：分母（对照深度）≤0.05 的 bin 设 NaN 断线，并在图上灰色标注 "AT-rich, no coverage in all samples"；边缘刚过门槛的 bin 不解读。断点定位**不得延伸进盲区**。

#### D7.8 模式 D 图件清单（P45 共 14 个呈现问题，归档 v6–v11）

- 正文对一组样本的每句断言（如 "GM12878 (S06–S10) shows no homozygous segment"），图里必须**每个样本都有 panel**；P45 Fig2 曾只画 S06（其选位点基线，必然无 LOH）。
- 所有样本 ID 带细胞系与 population/clone 号（`S11 Mutu I pop`），表头同理；背景细胞系的出现也要上图。
- 分级计数图中稀有等级（Limited 3、Ambiguous 1）用对数刻度并标编号；"0" 与 underpowered 必须区分（斜线）。
- 多 placement 写 "N alternative placement(s) besides the coordinate shown (N+1 in total)"，不写模糊的 "N equivalent placements"。
- 图例文字必须与数据真实分类一致（P45 Fig3 "mate outside" 实际 mate 多在窗口内）；为 0 的类别不出现在图例里，或明确标 0。
- 图号按 Results 中首次出现的顺序编（构建脚本里用 FIGMAP 映射），不按出图脚本顺序。
