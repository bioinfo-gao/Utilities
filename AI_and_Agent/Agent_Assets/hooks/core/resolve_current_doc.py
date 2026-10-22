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
"""
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
    m = IDE_TAG.findall(blob or "")
    if m:
        return m[-1].strip(), "本轮 prompt"
    if transcript and os.path.exists(transcript):
        hits = IDE_TAG.findall(open(transcript, errors="replace").read())
        if hits:
            return hits[-1].strip(), "transcript 最近一条"
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

    if path and path.startswith("/") and os.path.exists(path):
        msg = (
            f"【指代解析 · hook 自动注入】用户这句话里有无 path 指代词,"
            f"按 CLAUDE.md「无 path 提问」第 0 步解析为当前打开的文档：\n"
            f"    {path}\n"
            f"    (来源：{src})\n\n"
            f"强制动作,无例外：\n"
            f"1. 回复第一句写出「本文 = `{path}`(当前打开)」,然后【直接动手】。\n"
            f"2. 不许全局搜索,也不许用 AskUserQuestion 问是哪一份 ——"
            f"「我觉得这样解析不合逻辑」不构成例外。\n"
            f"3. ⛔ 唯一的前置校验：如果用户在消息里【引用了一段原文】,"
            f"动笔【之前】先跑 grep -F \"<那段原文>\" {path} —— "
            f"0 命中 = 解析被证伪,此时必须向用户要 path,禁令不适用。"
            f"写进去之后再 grep 是我自造的证据,不算数。")
    else:
        roots, ide = workspace_roots()
        span = quoted_span(prompt)
        lines = [
            "【指代解析 · hook 自动注入】用户这句话里有无 path 指代词,"
            f"但本轮上下文里没有 <ide_opened_file>(解析结果：{path!r})。",
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
