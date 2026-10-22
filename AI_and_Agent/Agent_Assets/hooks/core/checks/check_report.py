#!/usr/bin/env python3
"""客户报告检查器 —— 由 PostToolUse 按【文件路径】自动调用,不靠我记得跑。

用法(也可手动跑)：
    python3 ~/.claude/hooks/checks/check_report.py <报告.md>
    退出码 0 = 通过；非 0 = 有问题,逐条打印。

判据全部来自 CLAUDE.md「Client/research reports」一节,格式对准了真实交付物
(31_.../custom_research_report_20260828/Dual_Cut_Project_WGS_0828.md)：
    `## N. Title` 分节、`### N.M Title` 子节、header 用 `**Key:** value`。

⚠ 草稿期不闹：结构类检查只在文档【基本成型】(≥6 个一级分节)后才跑,
   否则我边写边被拦。措辞类检查(banned / 认错 / 简单重复)则一直跑。
"""
import os, re, sys

# ── §1–§9 规定的分节名(CLAUDE.md 2026-08-18 起 §2 = Core Conclusions)────────
REQUIRED = {
    1: "Objectives",
    2: "Core Conclusions",
    3: "Key Findings",
    4: "Sample Information",
    5: "Analysis Rationale and Decision Criteria",
    6: "Methods",
    7: "Results",
    8: "Conclusions, Limitations and Next Steps",
    9: "Deliverable Files",
}
# 上表是【默认名】。这里列出允许自由发挥的分节：标题只要命中该正则即可,
# 不做逐字比对。§5 由用户指定为「含 Analysis 即可」(2026-08-30) ——
# 那一节的措辞常随项目调整,逐字锁死会把正常改写当成缺陷。
FLEXIBLE = {5: re.compile(r"Analysis", re.I)}
# header 里必须出现的字段
HEADER_FIELDS = ["Report Date", "Prepared by", "Analysis Platform",
                 "Species", "Tissue / Cell"]

# 不得出现在客户交付物里的【建议】(CLAUDE.md「公司业务背景」§2)。
# ⚠ 禁的只剩「建议换长读长」。「建议加深度」2026-08-30 已解禁;
#   「陈述实测深度」从来就不该拦 ——
#   Methods 里写 "mean coverage 6.33×" 完全正当。
#   初版按裸数字 "30×" 匹配,把真实报告里的 "3.30×"(EGFP 拷贝数)当成违规拦下,
#   是「真实产物必须 PASS」那条用例抓出来的。判据要对准语义,不是对准 token。
BANNED = [
    (r"\bpcr[- ]free\b", "建库方式是我方的决定,不写给客户"),
    (r"\blong[- ]read\b|\bnanopore\b|\bPacBio\b|\bONT\b", "不建议改用长读长"),
]
# ⚠ 「建议加测序深度」已于 2026-08-30 由用户明确解禁 —— 那是正常的科学建议,
#    而且加测序是我方能承接的下一笔业务。原先的四条正则(at least N× /
#    recommend deeper coverage / increase depth / deeper sequencing)已删除。
#    同日已同步到 CLAUDE.md §2、check_client_email.py 的 BANNED、
#    memory/reference_athenomics_service_scope.md —— 四处口径一致,无残留。
# 「把某节描述成另一节的重复」—— 0827 实际写过并被否
SIMPLE_REPEAT = re.compile(
    r"the same (answers|ground|findings|points)|repeats the|restates the"
    r"|再说一遍|同上", re.I)
# 内部环境名不进客户报告
INTERNAL_LEAK = ["regular_bioinfo", "/home/gao", "mag_biobakery"]


def sections(text):
    """{编号: 标题} —— 只取 `## N. Title`。"""
    return {int(m.group(1)): m.group(2).strip()
            for m in re.finditer(r"^##\s+(\d+)\.\s+(.+?)\s*$", text, re.M)}


def subsections(text):
    return {m.group(1) for m in re.finditer(r"^###\s+(\d+\.\d+)\s", text, re.M)}


def check(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    low = text.lower()
    bad = []
    secs, subs = sections(text), subsections(text)

    # ── 一直跑：措辞类 ──────────────────────────────────────────────
    for pat, why in BANNED:
        m = re.search(pat, text, re.I)
        if m:
            bad.append(f"{why}：{m.group(0)!r} —— 平台/建库是我方的决定且本轮已完成,"
                       f"写出来等于告诉客户我方不清楚自己在卖什么服务。"
                       f"（若短读长确实限制了某个结论,在 Limitations 里【陈述局限本身】,"
                       f"不要接一句「建议改做长读长」。⚠「建议加深度」不在此列,已解禁）")
    for m in SIMPLE_REPEAT.finditer(text):
        bad.append(f"把一节描述成另一节的【简单重复】：{m.group(0)!r} —— "
                   f"路标句必须写它多给了什么(数字/证据出处/basis/更细粒度)")
    for w in INTERNAL_LEAK:
        if w in text:
            bad.append(f"内部信息泄漏到交付物：{w!r}")

    # ── 结构类：只在文档基本成型后跑,免得草稿期被拦 ──────────────────
    if len(secs) < 6:
        return bad, False        # 仍在起草

    for n, title in REQUIRED.items():
        if n not in secs:
            bad.append(f"缺分节 §{n} {title}")
        elif n in FLEXIBLE:
            if not FLEXIBLE[n].search(secs[n]):
                bad.append(f"§{n} 标题需含 {FLEXIBLE[n].pattern!r}（默认名 {title!r}）,"
                           f"实为 {secs[n]!r}")
        elif secs[n].lower() != title.lower():
            bad.append(f"§{n} 标题应为 {title!r},实为 {secs[n]!r}"
                       + ("  ← §8 必须用全名,不能只叫 Conclusions" if n == 8 else ""))
    for need in ("8.1", "8.2"):
        if need not in subs:
            bad.append(f"缺 §{need} —— §2 与 §8.2 是刻意的一简一详两份,少任何一份都算回退")

    # 交叉引用必须指得到实际存在的节
    for m in re.finditer(r"\bSection\s+(\d+(?:\.\d+)?)", text):
        ref = m.group(1)
        ok = (ref in subs) if "." in ref else (int(ref) in secs)
        if not ok:
            bad.append(f"交叉引用 `Section {ref}` 指向不存在的节 —— "
                       f"章节后移会让引用静默失效,客户点过去看到的是另一节")

    for f in HEADER_FIELDS:
        if f"**{f}" not in text:
            bad.append(f"header 缺字段：**{f}:** —— 物种与组织/细胞必须在开头就写明")

    if "Zhen Gao, PhD" not in text or "Athenomics" not in text:
        bad.append("签名缺失：Zhen Gao, PhD, Principal Bioinformatics Scientist, Athenomics")

    # ── 三处日期必须一致(目录名 / 文件名 / 正文 Report Date)──────────
    d_dir = re.search(r"custom_research_report(?:_supplementary)?_(\d{8})",
                      os.path.abspath(path))
    d_file = re.search(r"_(\d{4})\.md$", os.path.basename(path))
    d_body = re.search(r"\*\*Report Date:\*\*\s*(\d{4})-(\d{2})-(\d{2})", text)
    if d_dir and d_file and d_body:
        a = d_dir.group(1)                        # YYYYMMDD
        b = d_file.group(1)                       # MMDD
        c = d_body.group(2) + d_body.group(3)     # MMDD
        if not (a[4:] == b == c):
            bad.append(f"三处日期不一致：目录 {a} / 文件名 {b} / 正文 "
                       f"{d_body.group(1)}-{d_body.group(2)}-{d_body.group(3)}"
                       f" —— 必须完全一致(交付脚本应带同一个日期参数重打三处)")
    return bad, True


def main():
    if len(sys.argv) != 2:
        print(__doc__); sys.exit(2)
    path = sys.argv[1]
    if not os.path.exists(path):
        sys.exit(0)
    bad, complete = check(path)
    if bad:
        stage = "" if complete else "（起草中,只跑了措辞类检查）"
        print(f"报告检查未通过{stage}：{os.path.basename(path)}")
        for b in bad:
            print(f"  · {b}")
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
