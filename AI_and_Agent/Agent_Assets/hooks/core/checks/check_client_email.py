#!/usr/bin/env python3
"""客户邮件检查器 —— 由 PostToolUse 按【文件路径】自动调用。

用法：
    python3 ~/.claude/hooks/checks/check_client_email.py <邮件起草脚本.py>

目标：把 proj31 那批 per-project 的 `assert` 收编成一份共享判据。
正文用 `ast` 从脚本里抽(三引号赋给 BODY / TEXT / MSG / REPLY 之类),
比正则稳 —— 脚本改写法也不会漏检。

判据来自 CLAUDE.md：
  · 公司业务背景 §2   —— 不建议长读长（「建议加深度」2026-08-30 已解禁）
  · 不提数据传输       —— Dropbox 会自己同步,写了等于催
  · 绝不否定之前的提交 §扩到邮件 —— **没有错就别顺便认错**
  · 0829 新规           —— 告知分析完成的邮件必须点名报告文件作为入口
  · 对外交付与署名     —— 只准备,不发送
"""
import ast, os, re, sys

BANNED = [
    # ⚠ 「建议加测序深度」已于 2026-08-30 由用户明确解禁 —— 加测序是我方能承接的
    #    下一笔业务,属于正常的科学建议,照写。原先的 ("30x"/"30×") 两条已删除,
    #    check_report.py 的四条深度正则同步删除。
    ("pcr-free", "建库方式是我方的决定,不问客户"),
    ("long-read", "不建议改用长读长"), ("long read", "不建议改用长读长"),
    # 数据传输：Dropbox 自己会同步,提了等于催,而客户不会回
    ("dropbox", "不提数据传输"), ("upload", "不提数据传输"),
    ("fastq", "不提数据传输"), ("data received", "不提数据传输"),
    ("still waiting", "不提数据传输"),
]

# 「没有错就别顺便认错」。只抓【自责/道歉】的说法,不抓 "error rate" 这类正常用词 ——
# 精度优先：宁可漏,也不要因为一个 "sequencing error" 就拦住整封信。
SELF_BLAME = [
    (r"\byou(?:'re| are) right\b",              "客户提问不等于我方有错"),
    (r"\bours to fix\b",                        "一词二义不是错,按精确化处理"),
    (r"\bour (?:error|mistake|fault|oversight)\b", "没有实质性错误就不认错"),
    (r"\bwe (?:were|are) (?:wrong|incorrect|mistaken)\b", "没有实质性错误就不认错"),
    (r"\b(?:sorry|apolog\w+)\b",                "没有实质性错误就不道歉"),
    (r"\bwe (?:should have|failed to)\b",       "没有实质性错误就不自责"),
]

# 这封信在宣布分析完成 ⇒ 必须点名报告文件作为入口
COMPLETION = re.compile(
    r"\b(analysis (?:is )?(?:now )?complete|results are (?:now )?(?:ready|available)"
    r"|deliver(?:ed|y)|the report|final report)\b", re.I)
REPORT_FILE = re.compile(r"\b[\w.-]+_\d{4}\.md\b")

BODY_NAMES = re.compile(r"^(BODY|TEXT|MSG|MESSAGE|REPLY|EMAIL|CONTENT)", re.I)


def extract_bodies(path):
    """从 .py 里抽出候选正文字符串。解析不了就退回全文(宁可多查)。"""
    src = open(path, encoding="utf-8", errors="replace").read()
    try:
        tree = ast.parse(src)
    except SyntaxError:
        return [src], False
    out = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Assign):
            continue
        names = [t.id for t in node.targets if isinstance(t, ast.Name)]
        if not any(BODY_NAMES.match(n) for n in names):
            continue
        v = node.value
        if isinstance(v, ast.Constant) and isinstance(v.value, str):
            out.append(v.value)
        elif isinstance(v, ast.JoinedStr):      # f-string：取字面部分
            out.append("".join(p.value for p in v.values
                               if isinstance(p, ast.Constant)
                               and isinstance(p.value, str)))
    return (out, True) if out else ([src], False)


def check(path):
    bodies, precise = extract_bodies(path)
    src = open(path, encoding="utf-8", errors="replace").read()
    body = "\n".join(bodies)
    low = body.lower()
    bad = []

    # 客户【主动问了】传输方式时，脚本里加 `# transfer-answer-intended` 可豁免 dropbox/upload
    #（user directive 2026-10-13）；其余 banned 词不豁免
    exempt = {"dropbox", "upload"} if "# transfer-answer-intended" in src else set()
    for w, why in BANNED:
        if w in exempt:
            continue
        if w in low:
            bad.append(f"banned 词 {w!r} 出现在正文 —— {why}")

    for pat, why in SELF_BLAME:
        m = re.search(pat, body, re.I)
        if m:
            bad.append(f"认错措辞 {m.group(0)!r} —— {why}。"
                       f"改用「精确化 / 消除歧义 / 进一步说明」的框架")

    # 交付物全英文：正文不得有 CJK / 全角
    cjk = {c for c in body if "一" <= c <= "鿿"
           or "　" <= c <= "〿" or "＀" <= c <= "￯"}
    if cjk:
        bad.append(f"正文含中文/全角字符 {sorted(cjk)[:8]} —— 客户交付物一律全英文")

    if "Zhen Gao" not in body or "Athenomics" not in body:
        bad.append("签名缺失：Zhen Gao, PhD, Principal Bioinformatics Scientist, Athenomics")

    # 宣布完成的信必须给入口
    if COMPLETION.search(body) and not REPORT_FILE.search(body):
        bad.append("这封信在宣布分析完成/交付,但【没有点名报告文件】。"
                   "必须给出「交付目录名 + 报告文件名」并明说先看它 —— "
                   "交付包几十个文件,不指入口客户第一步就卡住(0829 新规)")

    # 只准备,不发送
    if re.search(r"\.(sendmail|send_message)\s*\(", src) or \
       re.search(r"smtplib\.SMTP[^\n]*\n[\s\S]{0,400}?\.send", src):
        bad.append("脚本里有【发送】动作 —— 以用户名义对外的内容一律只准备、不发送,"
                   "只能 IMAP APPEND 进 Drafts,由用户本人逐字过目后发出")

    if not precise:
        bad.append("(提示)没找到 BODY/TEXT/MSG 之类的正文变量,以上是对【整个脚本】"
                   "做的检查,可能有误报 —— 把正文赋给 BODY 变量可提高精度")
    return bad


def main():
    if len(sys.argv) != 2:
        print(__doc__); sys.exit(2)
    path = sys.argv[1]
    if not os.path.exists(path):
        sys.exit(0)
    bad = check(path)
    if bad:
        print(f"客户邮件检查未通过：{os.path.basename(path)}")
        for b in bad:
            print(f"  · {b}")
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
