#!/usr/bin/env python3
"""回复检查器 —— 由 Stop hook 在我结束回合前调用。

这一层管的是【我说的话】,不是文件。所以只能放在 Stop：那是唯一看得到回复文本的时点。

⚠ 设计取舍：这些规则【不注入】上下文,只在结束时检查。
   注入是每轮付费,检查是一次性零成本 —— 每轮都注入就又变回 122 KB 全量常驻了。

可单独跑(读 stdin,此时跳过状态断言检查)：
    cat reply.txt | python3 ~/.claude/hooks/checks/check_reply.py
"""
import re, sys

# ── 1. 外部状态断言：断言【类别】必须配上【该类别的回读命令】 ──────────
#
# 初版判据是「本回合跑过任意一条 Bash 就算有证据」—— 太松：
# 跑的可能是 `git status`,而我断言的是「邮件还在草稿箱」,两者毫无关系。
# 现在按类别配对：说邮件就得回读 Gmail,说推送就得看 git,说在跑就得看进程/日志。
#
# 每项 = (这类断言叫什么, 断言词, 可接受的回读命令特征, 正确的回读方式)
CLAIM_KINDS = [
    ("邮件是否已发出 / 草稿是否还在",
     r"已发送|已发出|已经发出|发出去了|未发送|尚未发送|还没发|草稿箱|在草稿"
     r"|\bhas been sent\b|\bnot (?:yet )?sent\b",
     r"imaplib|IMAP|\bDrafts\b|Sent[ _]Mail|\[Gmail\]|check_client_email_state|gmail",
     "回读 Gmail 三项同看：Drafts 计数 + Sent 按收件人搜索 + 正文特征串。"
     "只看 Drafts 会把「已发出」误读成「还在起草」（0829 第 5 次就是这样错的）"),

    ("是否已推送 / 已提交",
     r"已推送|推送了|已提交|已 ?commit|\bpushed\b|\bcommitted\b",
     r"git\s+(?:-C\s+\S+\s+)?(?:push|log|status|rev-list|rev-parse|diff)"
     r"|@\{u\}|origin/",
     "跑 `git rev-list --count @{u}..HEAD` 或 `git log @{u}..HEAD` 看实际未推送数"),

    ("任务是否在跑",
     # (?<!现) 排除「现在跑一下 / 现在跑实测」——「现在」+「跑」跨词边界的误报。
     # 「正在跑 / 还在跑 / 仍在跑 / 任务在跑」前面不是「现」,照样拦。
     # 0914 同日连拦 2 次皆为误报后收窄(第 2 次命中的是本行正则字面量本身)。
     r"正在运行|(?<!现)在跑|还在跑|仍在跑|运行中|已跑完|跑完了"
     r"|\bis running\b|\bstill running\b",
     r"tmux|pgrep|\bps\b|capture-pane|\btail\b|/proc/|nextflow\.log|\btop\b|\bjobs\b",
     "进程存在 ≠ 在干活：要看日志里有【新的业务记录】或 CPU ticks 在涨,"
     "而不是只看 tmux 有没有 session"),

    ("是否已交付 / 已归档 / 已清空",
     r"已交付|已归档|已清空|\bdelivered\b",
     r"\bls\b|\bfind\b|\bdu\b|\btree\b|custom_research_report|\bwc\b|\bstat\b",
     "列出实际的目录/文件,别引用文档里写的状态 —— "
     "文档记的是【写下那一刻】的外部状态,此后无人回读"),
]

# ── 2. 语言：只用中文或英文 ─────────────────────────────────────────
# 平假名 / 片假名 / 谚文。CJK 标点(、。「」)是中文正常用字,不算。
KANA = re.compile(r"[ぁ-ゟァ-ヺ가-힯]")

FENCE = re.compile(r"```.*?```", re.S)
INLINE_CODE = re.compile(r"`[^`\n]*`")


def _table_rows(text):
    """markdown 表格的分隔行(| :--- | :---: |)。先去掉代码块,免得误报。"""
    body = FENCE.sub("", text)
    for line in body.split("\n"):
        s = line.strip()
        if s.startswith("|") and s.endswith("|") and set(s) <= set("|:- \t"):
            if "-" in s:
                yield s


def run(text, commands):
    """返回问题清单。

    text     = 本回合我说过的话
    commands = 本回合实际跑过的 Bash 命令(list[str])。传 None 表示跳过状态断言检查。
    """
    bad = []

    if commands is not None:
        # 状态断言只看【散文】,不看代码块和行内代码 —— 展示一条命令/正则/日志
        # 不是在断言外部状态。_table_rows 早就这么剥了,这里此前漏做:
        # 0914 第 2 次拦截命中的正是本文件里被引用的那条正则字面量。
        prose = INLINE_CODE.sub(" ", FENCE.sub(" ", text))
        joined = "\n".join(commands)
        for kind, claim_pat, evid_pat, how in CLAIM_KINDS:
            hits = sorted(set(re.findall(claim_pat, prose)))
            if not hits:
                continue
            if re.search(evid_pat, joined, re.I):
                continue
            ran = "、".join(c.split()[0] for c in commands[:5]) or "（一条都没跑）"
            bad.append(
                f"状态断言未经回读 —— 关于「{kind}」：说了 " +
                "、".join(repr(h) for h in hits[:4]) +
                f",但本回合跑过的命令里没有任何一条是这类回读（跑的是：{ran}）。\n"
                f"    正确做法：{how}\n"
                f"    规则：外部状态的陈述必须与其回读命令的输出【同现于一次回复】;"
                f"拿不出输出就只能写「未核实」,不得给结论,也不得据此给建议。（已重复 5 次）")

    k = sorted(set(KANA.findall(text)))
    if k:
        bad.append(f"回复里出现日文/韩文字符 {k[:8]} —— 回复只用中文或英文")

    for sep in _table_rows(text):
        cells = [c.strip() for c in sep.strip("|").split("|")]
        if not cells:
            continue
        wrong = []
        if not (cells[0].startswith(":") and not cells[0].endswith(":")):
            wrong.append("第 1 列应为 :---（左对齐）")
        for i, c in enumerate(cells[1:], start=2):
            if not (c.startswith(":") and c.endswith(":")):
                wrong.append(f"第 {i} 列应为 :---:（居中）")
        if wrong:
            bad.append("表格分隔行格式不对（" + "；".join(wrong[:3]) +
                       f"）：{sep[:60]}")
    return bad


def main():
    bad = run(sys.stdin.read(), commands=None)   # 单独跑时不查状态断言
    for b in bad:
        print(f"  · {b}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
