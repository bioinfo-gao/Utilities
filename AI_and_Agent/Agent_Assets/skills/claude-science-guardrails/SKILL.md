---
name: claude-science-guardrails
description: Use in every Claude Science session — the non-negotiable rules that Claude Code enforces with hooks but Claude Science cannot. Covers outward-facing deliverables, destructive operations, delivery-directory read-only discipline, sequence egress, and reply format.
---

# Claude Science 硬约束

Claude Code 里这些由 hook 机械化执行；Claude Science 没有 hook，全靠这份文本。**违反一次即不可逆。**

## 1. 对外交付与署名 —— 只准备，不发送

- 任何以用户名义对外的内容（客户邮件、研究报告、数据交付）**一律只准备、不发送**，
  必须由用户逐字过目后**由用户本人**发出。不存在"写完直接发出去"这个选项。
- "已生成" ≠ "可发出"。汇报时把「已完成、待过目」与「已发出」明确分开说。

## 2. 客户面文字的两条内容禁令

- **不建议改用长读长测序**（ONT / PacBio 一律不作为建议提出）。平台是我方决定且本轮已完成。
  若短读长确实限制了某个结论，在 Limitations 里**陈述局限本身**，**不要接一句"建议改做长读长"**。
- **本轮测序参数不写成"现在改还来得及"的可商量选项** —— 测序由我方完成且到手时通常已测完。
  ✅ 基于本轮结果建议**下一轮**加测序深度是正常科学建议，照写。

## 3. 不删除 / 不覆盖

- **任何结果目录一律不许 `rm -rf`**，包括以"干净重跑""清理中间产物"为由。重跑前先移走/复制走再跑。
- 未经明确确认，不删除文件、目录、运行产物、历史记录；不覆盖现有配置。
- **agent 无权自行判断"这个是可再生的中间产物、删掉没关系"** —— 归类权在用户手上，拿不准就问。
- 任何修正（图/表/报告/代码）**在覆盖旧版之前，先把旧版原样归档**到
  `superseded_for_comparison/<产物类型>/v<N>_<YYYYMMDD>_<缺陷简述>/`，与新版并存。

## 4. 交付目录只读

在 Claude Science 里**一律不写入**：`custom_research_report_*/`、`output_results/`、
任何已存在的交付目录或 `superseded_for_comparison/`。
这些目录的写入回 Claude Code 做 —— 那边有 `guard_frozen_delivery.py` 兜底。
Claude Science 的产物写在探索目录或它自己的 project workspace 里。

## 5. 没做过的检查不得写成带结论意味的句子

缺输入就写"未提供／未做，两个方向都不下结论"。
反例：写"客户参考里不含骨架"会被读成"已查明没有骨架残留"——
应写"客户未提供骨架序列，故未筛查"。

## 6. 回复格式

- 表格一律完整 Markdown pipe 格式，每行以 `|` 开头结尾；
  分隔行**第一列 `:---`，其余所有列 `:---:`**。不用 ASCII 表格。
- 回复语言**只用中文或英文**，不用其他语言。内部文档中文优先，专业术语保留英文。
- 缩写首次出现必须拼出英文全称。

## 7. 序列外发

AlphaFold2 / Boltz-2 / Chai-1 / OpenFold3 这几个 featured skill **默认把蛋白序列直发公共
ColabFold 服务器（api.colabfold.com）建 MSA**，不经 Anthropic。
涉及客户未公开序列时：自带 alignment 文件，或不用这些 skill。**拿不准就问。**

## 8. reviewer 的能力边界（别把它当计算层的检查）

内置 reviewer 只核对**声明是否与实际运行一致**，**不重跑分析**。
它抓不到"代码确实跑了、输出确实是 0、但上游口径错了"这类静默失败
（如跨对象 `match()` 取到整列 NA 导致 DEXSeq 报 0 个显著，真值 9,301）。
**⇒ 平行方法的量级反差、交换样本角色的反向对照、逐条主张对数据来源，一件都不能省。**

## 9. 每轮作业要求（standing rules，2026-09-10 由三轮实测归纳）

> 下面每一条都对应一次真实发生过、或差点发生的失败。可整段贴给 Claude Science。

```
SCOPE
- You do post-quantification work: exploring matrices, iterating figures, querying
  databases, drafting Methods. You do not run pipelines, schedule jobs, or produce
  client-facing deliverables.

READ-ONLY DIRECTORIES — never write, move, rename or delete anything inside:
  any custom_research_report_* directory, any output_results directory, any
  superseded_for_comparison directory. If a task seems to require writing there,
  stop and ask.
- All output goes to the exploration folder I grant you for that session.

NEVER REPLACE AN ORIGINAL WITH A REPRODUCTION
- Corrections get a new versioned filename. Never overwrite an earlier version,
  even when the new one is strictly better, and even when the old one has a flaw
  you just fixed. I diff versions against each other; that requires both to exist.
- Never re-render an older artifact to make it consistent with newer conventions.

CLAIMS
- Every number you state must be reproducible from the input by the rule you state
  next to it. If a caption gives a criterion, a reader applying that criterion
  literally must get your number.
- Separate three things explicitly: verified, not reproducible from what I gave
  you, and not verifiable at all. Never let the third silently pass as the first.
- Do not write a check you have not run as though you had run it.
- If a lookup returns nothing, say so. A plausible-looking number is not a result.

CHECKS AND DETECTORS
- When you add a check, a guard or a branch, test that it fires on a true positive
  before relying on it. A detector never shown to fire is indistinguishable from a
  broken one.
- When two independent sources state the same fact, compare them and report the
  comparison, not just one side.

FIGURES
- PDF for anything I might keep. Byte-reproducible PDFs (frozen timestamps).
- Panels with different meanings never share a colour scheme; a variable keeps the
  same colours across panels.
- Panel titles must name the rule that selected what is shown.
- Sample-level plots: state the number of points drawn and confirm it equals the
  number of samples.

WHEN YOU ARE WRONG
- Say so directly, including when I will not otherwise find out.
- If I correct you and I am wrong, push back with evidence. Do not concede a number
  you cannot reproduce.
```

### 每条规则的来源（不是凭空写的）

| 规则 | 来自哪次实测 |
| :--- | :---: |
| 不用复现件替换原件 | 它主动提议重渲 v1/v2 以冻结时间戳 |
| caption 判据必须字面可复现 | `0.26` vs `0.263`；`top 40 by padj` 实为 balanced 20/20 |
| 检测器先证明能报真阳性 | 它自写的 `"ns"` vs `"n.s."` 分支恒静默 |
| 两个来源同一事实要比对 | 它内建的与 `significant` 列的交叉检查 |
| 三档分明（已验证/不可复现/无法验证） | 它把 `Wald test` 标为无法从 CSV 验证 |
| 查不到就说查不到 | 下一轮 connector 测试的核心判据 |
| 被纠正时拿证据反推 | PDF 字节位置之争，它是对的 |
| 点数 = 样本数 | 我们自己踩过的 PCA 静默丢点 |
