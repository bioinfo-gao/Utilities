#!/usr/bin/env python3
"""UserPromptSubmit —— 无 path 指代 ⇒ 当场把「当前打开的文档」解析成绝对路径注入。

这是 feedback_search_scope_never_widen 的 4 级机械化。
该错误已犯 4 次(0721 / 0810 / 0827×2)。前几轮的"机械化"都是往 CLAUDE.md 里
再写一段更硬的措辞 —— 那仍然依赖我记得去读那段。本脚本改成:
指代词一出现,路径就【已经在上下文里】,我不需要记得,也没有搜索或提问的余地。

同时把「用户引用了原文 ⇒ 必须先 grep -F 校验」一并注入,
因为 0827 第 5 次证明 <ide_opened_file> 本身可能只是"我刚建的文件被点开过一次"。

2026-09-11 修订(proj35 实测) —— 解析不到时不再直接放行去问用户。根因：
  CLI 发这条提醒的条件是 `if(!e?.filePath || e.text) return []`,
  e = IDE 经 MCP 推来的 selection 状态。Positron 只在【编辑器内发生选区/活动编辑器变化】
  时才推。用户若「文档早就开着 → 直接在面板里粘贴提问,中途没点过正文」,
  该状态自始至终为空 ⇒ 本 hook 无论正则怎么写都解析不到。**这不是 bug,是信息真的没来。**
  ⇒ 所以不能把「解析不到」当成「用户没开文档」,更不能当成「可以去全局搜索」。
  但当时 `~/.claude/ide/*.lock` 里【已经躺着正确的搜索根】
  (workspaceFolders 含 /home/gao/projects_2026M7),没人去读。
  现在改为：解析不到 ⇒ 注入 workspaceFolders + 一条现成的 `grep -RF` 兜底命令。
  ⚠ 必须 -R 不是 -r：projects_2026M7 是符号链接,`grep -r` 不跟随、静默跳过整棵树,
     2026-09-11 当天就是这样得出「文件不存在」这个假阴性的(已由
     guard_search_symlink.py 单独硬拦)。

2026-10-27 修订(P45 实测) —— transcript 里最近一条 "opened the file" 可能早已过期：
  用户后来切到另一份文档却没点进正文,IDE 不再推送,hook 仍指向旧文件。
  旧版只是把「grep 校验」写成给我的指令,0 命中时让我去问用户 —— 用户不满
  ("不指定文件时,问题来自当前打开的文件。你怎么还搞不清？")。
  现在 hook 自己先做校验：用户引用了原文而解析到的文件里没有 ⇒ 在该文件所属项目里
  (向上找到含 docs/ 或 scripts/ 的目录)grep 这段原文,命中的文档直接作为解析结果注入。
"""
import subprocess
import json, os, re, sys, glob

HOOKDIR = os.path.expanduser("~/.claude/hooks")
LOG = os.path.join(HOOKDIR, "hook_errors.log")

REFERENT = re.compile(
    r"(本文|本节|这一节|这个文档|这份文档|该文档|当前文档|当前打开|"
    r"这个文件|该文件|这份文件|这个位置|这一处|这一段|这段|这句|这里|这处)")
# 用户自己给了路径就不必注入
HAS_PATH = re.compile(r"(/[\w.\-]+){2,}")
IDE_TAG = re.compile(r"opened the file (.+?) in the IDE")


def _trace(tag):
    """每次被调用就留一行 —— 「hook 装好了」和「hook 在跑」是两件事,必须能分开验。"""
    try:
        import datetime, os as _os
        with open(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)),
                                "hook_calls.log"), "a") as fh:
            fh.write(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S}  {tag}\n")
    except Exception:
        pass


def last_opened_file(blob, transcript):
    """先看本轮 payload,再回溯 transcript —— 本轮的最新,transcript 的可能过期。"""
    # 只认真实存在的绝对路径：transcript 里也有我自己写的代码/文档引用这句话
    # (2026-10-27 实测：测试代码里的 f"opened the file {stale}" 被当成了 IDE 通知)。
    real = lambda hs: [h.strip() for h in hs if h.strip().startswith("/") and os.path.isfile(h.strip())]
    m = real(IDE_TAG.findall(blob or ""))
    if m:
        return m[-1], "本轮 prompt"
    if transcript and os.path.exists(transcript):
        hits = real(IDE_TAG.findall(open(transcript, errors="replace").read()))
        if hits:
            return hits[-1], "transcript 最近一条"
    return None, None


def workspace_roots():
    """IDE 连着就一定有 lock,里面的 workspaceFolders 就是可信的搜索根。

    这是「解析不到 <ide_opened_file>」时唯一还剩的结构化线索 ——
    比让我去猜、去全局搜、去问用户都强,而且它一直都在,只是以前没人读。
    """
    roots, ide = [], None
    for f in sorted(glob.glob(os.path.expanduser("~/.claude/ide/*.lock")),
                    key=os.path.getmtime, reverse=True):
        try:
            d = json.load(open(f))
        except Exception:
            continue
        ide = ide or d.get("ideName")
        for w in (d.get("workspaceFolders") or []):
            if w not in roots and os.path.isdir(w):
                roots.append(w)
        if roots:
            break
    # 具体的根排前面,$HOME 排最后 —— 实测把 /home/gao 放第一位要跑 2 分钟以上
    # (conda / .positron-server / .claude-science 整棵树都会被走一遍),
    # 而 projects_2026M7 单独跑是秒级。先窄后宽,命中了就不必等宽的。
    home = os.path.expanduser("~")
    roots.sort(key=lambda r: (os.path.normpath(r) == home, -len(r)))
    return roots, ide


# grep 时必须排掉的重量级目录 —— 它们里面永远不会是「用户正在看的文档」
EXCLUDES = (".git", "node_modules", "__pycache__", ".cache", ".conda", "envs",
            ".positron-server", ".claude-science", ".vscode-server", "site-packages")


def quoted_span(prompt):
    """用户是否贴了一段可以直接 grep 的原文 —— 取最长的一行,短行没有判别力。

    ⚠ 表格行不能用作判据：用户粘贴时表格常被输入框重排
    (实测 `| 标记 | 含义 |` 被贴成 `| 标记 |  |`),拿它去 grep 必然 0 命中 ⇒ 假阴性。
    """
    best = ""
    for ln in prompt.splitlines():
        ln = ln.strip().lstrip("#>-*").strip()
        if ln.startswith("|") or "```" in ln:
            continue
        if len(ln) > len(best) and len(ln) >= 12:
            best = ln
    # 切掉用户自己的引导语：「这个写法不合理：<原文>」——引导语不在文件里,
    # 带着它去 grep 必然 0 命中。grep -F 是子串匹配,取短一点只会多命中不会漏。
    for sep in ("：", ":"):
        head, _, tail = best.partition(sep)
        if tail.strip() and len(tail.strip()) >= 12 and len(head) <= 20:
            best = tail.strip()
            break
    return best[:120]


def explicit_quote(prompt):
    """只在用户【明确引用了原文】时返回那段原文,否则返回 ""。

    quoted_span 会把任何 ≥12 字的整句问话都当成候选,用作兜底 grep 无妨;
    但用来【证伪】解析就会出错 —— 「请解释本文第三节怎么读」本身不在文件里,
    拿它判定「解析错了」是假阳性。所以这里只认三种明确的引用形式：
    引号内的文字、短引导语后的冒号尾部、多行粘贴的非首行。
    """
    m = re.findall(r"[“「\"]([^”」\"]{8,})[”」\"]", prompt)
    if m:
        return max(m, key=len).strip()[:120]
    first = prompt.strip().splitlines()[0] if prompt.strip() else ""
    for sep in ("：", ":"):
        head, _, tail = first.partition(sep)
        if tail.strip() and len(tail.strip()) >= 12 and len(head) <= 20:
            return tail.strip()[:120]
    if len(prompt.strip().splitlines()) > 1:
        return quoted_span("\n".join(prompt.strip().splitlines()[1:]))
    return ""


def project_root(path):
    """向上找到第一个含 docs/ 的目录 —— 即项目根;找不到就用文件所在目录。

    先跳出 superseded_for_comparison/：归档版本目录里常有 scripts/ 快照,
    曾被误认作项目根(2026-10-27 实测),于是只在归档目录里搜、找不到报告。
    """
    d = os.path.dirname(os.path.abspath(path))
    if "/superseded_for_comparison/" in d + "/":
        d = d[:(d + "/").index("/superseded_for_comparison/")]
    while d not in ("/", os.path.expanduser("~")):
        if os.path.isdir(os.path.join(d, "docs")):
            return d
        d = os.path.dirname(d)
    return os.path.dirname(os.path.abspath(path))


def relocate(path, span):
    """解析到的文件里没有用户引用的原文 ⇒ 在同一项目里找含这段原文的文档。

    排序：不在 superseded_for_comparison/ 的在前(那是归档旧版),同组按修改时间新→旧。
    返回 (状态, 命中列表)：ok = 原解析成立;moved = 换成命中文档;none = 项目内也没有。
    """
    try:
        if span in open(path, encoding="utf-8", errors="replace").read():
            return "ok", [path]
    except OSError:
        pass
    root = project_root(path)
    ex = [f"--exclude-dir={d}" for d in EXCLUDES]
    try:
        r = subprocess.run(["grep", "-RlF", "--include=*.md", "--include=*.txt", *ex, span, root],
                           capture_output=True, text=True, timeout=8)
        hits = [h for h in r.stdout.splitlines() if h]
    except Exception:
        hits = []
    hits.sort(key=lambda h: ("superseded_for_comparison" in h, -os.path.getmtime(h)))
    return ("moved", hits) if hits else ("none", [])


def main():
    _trace("UserPromptSubmit")
    raw = sys.stdin.read()
    data = json.loads(raw) if raw.strip() else {}
    prompt = data.get("prompt") or ""

    if not REFERENT.search(prompt) or HAS_PATH.search(prompt):
        sys.exit(0)

    transcript = data.get("transcript_path")
    if not transcript:
        cands = sorted(glob.glob(os.path.expanduser(
            "~/.claude/projects/*/*.jsonl")), key=os.path.getmtime)
        transcript = cands[-1] if cands else None

    path, src = last_opened_file(raw, transcript)

    span = explicit_quote(prompt)
    status, hits = ("no_span", [])
    if path and path.startswith("/") and os.path.exists(path) and span:
        status, hits = relocate(path, span)
        if status == "moved":
            stale, path = path, hits[0]
            src = (f"{src}的 {stale} 里没有用户引用的原文,已在同一项目内 grep -F 到该原文"
                   f"(按「非归档优先、修改时间新优先」取第 1 个)")

    if path and path.startswith("/") and os.path.exists(path) and status != "none":
        others = "".join(f"\n      另有命中：{h}" for h in hits[1:6])
        msg = (
            f"【指代解析 · hook 自动注入】用户这句话里有无 path 指代词,"
            f"按 CLAUDE.md「无 path 提问」第 0 步解析为当前打开的文档：\n"
            f"    {path}\n"
            f"    (来源：{src}){others}\n\n"
            f"强制动作,无例外：\n"
            f"1. 回复第一句写出「本文 = `{path}`(当前打开)」,然后【直接动手】。\n"
            f"2. 不许全局搜索,也不许用 AskUserQuestion 问是哪一份 ——"
            f"「我觉得这样解析不合逻辑」不构成例外。\n"
            + (f"3. 原文校验 hook 已做完(grep -F 命中),不必再向用户解释定位过程;"
               f"「另有命中」若与该文件同一行内容相同,直接按解析结果回答。"
               if status in ("ok", "moved") else
               f"3. ⛔ 唯一的前置校验：如果用户在消息里【引用了一段原文】,"
               f"动笔【之前】先跑 grep -F \"<那段原文>\" {path} —— "
               f"0 命中 = 解析被证伪,此时必须向用户要 path,禁令不适用。"
               f"写进去之后再 grep 是我自造的证据,不算数。"))
    else:
        roots, ide = workspace_roots()
        span = span or quoted_span(prompt)
        lines = [
            "【指代解析 · hook 自动注入】用户这句话里有无 path 指代词,"
            + (f"最近一次打开的文件 {path} 及其所在项目里都没有用户引用的原文(可能已过期)。"
               if status == "none" else
               f"但本轮上下文里没有 <ide_opened_file>(解析结果：{path!r})。"),
            "",
            "⚠ 这【不代表用户没打开文档】。CLI 只在 IDE 推来 selection 状态时才发那条提醒;"
            "文档早就开着、用户没点进正文,就永远不会发(2026-09-11 实测)。"
            "**别据此断定文档不存在或没打开。**",
        ]
        if roots:
            lines += ["",
                      f"IDE({ide or '未知'})的 lock 里有 workspaceFolders,这就是搜索根："]
            for r in roots:
                real = os.path.realpath(r)
                lines.append(f"    {r}" +
                             (f"   → {real}(符号链接!)" if real != r else ""))
            lines += ["",
                      "⛔ 向用户要 path 之前,先跑这一条(秒级,只跑一次)："]
            pat = span or "<用户引用的那一行原文>"
            ex = " ".join(f"--exclude-dir={d}" for d in EXCLUDES)
            lines.append("    grep -RF --include='*.md' " + ex + " " +
                         repr(pat) + " " + " ".join(roots))
            lines += [
                "",
                "⚠ 必须 -R 不是 -r：-r 不跟随符号链接,遇到 projects_2026M7 这类根"
                "会【静默跳过整棵树】,给出「文件不存在」的假阴性(2026-09-11 实测)。",
                "命中 ⇒ 那就是当前文档,直接动手,不要再问。",
                "0 命中 ⇒ 才向用户要 path(此时禁令不适用)。",
                "⚠ 若用户贴的是表格行,grep 0 命中不算证伪 —— 粘贴时表格会被重排。",
            ]
        else:
            lines += ["",
                      "且 ~/.claude/ide/*.lock 里没有可用的 workspaceFolders —— "
                      "此时才允许直接向用户要 path。"]
        msg = "\n".join(lines)

    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": msg}}, ensure_ascii=False))
    sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        try:
            open(LOG, "a").write(f"[resolve_current_doc] {type(e).__name__}: {e}\n")
        except Exception:
            pass
        sys.exit(0)
