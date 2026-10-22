#!/usr/bin/env python3
"""PreToolUse/Bash —— 不跟随符号链接的递归搜索 ⇒ 假阴性闸门。

存在理由(2026-09-11 proj35 实测)：
    /home/gao/projects_2026M7 -> /mnt/ex_8T_SSD/projects_2026M7
    grep -rl --include='*.md' '本文档的证据等级' /home/gao   → 0 命中
    grep -Rl --include='*.md' '本文档的证据等级' /home/gao/projects_2026M7
                                                            → 命中
`grep -r` 只跟随【命令行上直接给出】的符号链接,树里遇到的一律跳过;`-R` 才全跟随。
`find` 同理：默认 -P 不跟随,要 -L 才跟随(~/Utilities/software_pitfalls/find_symlink.md)。

**为什么必须是 deny 而不是 warn**：这类失败【没有报错、没有非零退出码】,
唯一的表现就是"没找到"—— 和"确实不存在"逐字节一样。当天我据此向用户断言
「这段文字不在 /home/gao 下任何 .md 文件里」,而文件就在那儿。
一个静默的假阴性会直接变成我嘴里的结论,所以要在它发生【之前】拦。

**只在真会出事时才拦**：仅当搜索根下确实存在指向目录的符号链接才 deny。
根下没有符号链接 ⇒ -r 与 -R 结果等价 ⇒ 放行,不打扰正常工作。

**故意不跟随**时的出口：命令里写 `# no-follow-intended`。
显式声明是可以的,静默漏掉不行。

失败时 fail-open(退出 0 不拦),但把异常写进 hooks/hook_errors.log ——
一个静默坏掉的 hook 比没有 hook 更糟,必须留痕。
"""
import json, os, re, shlex, sys, time

LOG = os.path.expanduser("~/.claude/hooks/hook_errors.log")

OPT_OUT = "no-follow-intended"
# 扫描预算 —— hook 必须秒回,宁可漏拦也不能拖住工具调用
MAX_ENTRIES = 4000
TIME_BUDGET = 0.8          # 秒
MAX_DEPTH = 2              # 顶层 + 再下一层,足以覆盖 ~/projects_2026M7 这类布局


def _trace(tag):
    """每次被调用就留一行 —— 「hook 装好了」和「hook 在跑」是两件事,必须能分开验。"""
    try:
        import datetime
        with open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                               "hook_calls.log"), "a") as fh:
            fh.write(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S}  {tag}\n")
    except Exception:
        pass


def segments(cmd):
    """按 ; | && || 换行 拆成独立命令段。管道里的 grep 一样要查。"""
    return [s for s in re.split(r"[;\n]|\|\||&&|\||`|\$\(", cmd) if s.strip()]


# 包在前面的壳,剥掉才看得见真正的命令(`ls | xargs grep -r …` 一样会踩坑)
WRAPPERS = {"xargs", "sudo", "time", "nice", "nohup", "env", "command",
            "timeout", "stdbuf"}


def tokens(seg):
    try:
        toks = shlex.split(seg)
    except ValueError:                      # 引号不配对 —— 放弃这一段,别误判
        return []
    while toks and os.path.basename(toks[0]) in WRAPPERS:
        toks = toks[1:]
        # 壳自己的参数：选项(-I{}),或纯数字(timeout 90 grep …)
        while toks and (toks[0].startswith("-") or toks[0].isdigit()):
            toks = toks[1:]
    return toks


def dir_symlinks(root):
    """root 下(深度 ≤ MAX_DEPTH)指向目录的符号链接。有 ⇒ -r 会静默跳过它们。"""
    found, seen, t0 = [], 0, time.time()
    stack = [(root, 0)]
    while stack:
        cur, depth = stack.pop()
        if depth > MAX_DEPTH or seen > MAX_ENTRIES or time.time() - t0 > TIME_BUDGET:
            break
        try:
            with os.scandir(cur) as it:
                for e in it:
                    seen += 1
                    if seen > MAX_ENTRIES:
                        break
                    name = e.name
                    if name.startswith(".") or name in ("node_modules", "__pycache__"):
                        continue
                    try:
                        if e.is_symlink():
                            if os.path.isdir(e.path):
                                found.append((e.path, os.path.realpath(e.path)))
                        elif e.is_dir(follow_symlinks=False) and depth < MAX_DEPTH:
                            stack.append((e.path, depth + 1))
                    except OSError:
                        continue
        except (OSError, PermissionError):
            continue
    return found


def grep_problem(toks):
    """返回 (需要检查的搜索根, 修好的标志) —— 不是问题就返回 None。"""
    if not toks or os.path.basename(toks[0]) not in ("grep", "egrep", "fgrep", "rgrep"):
        return None
    recursive = follows = False
    for t in toks[1:]:
        if t == "--":
            continue
        if t.startswith("--"):
            if t == "--recursive":
                recursive = True
            elif t == "--dereference-recursive":
                recursive = follows = True
        elif t.startswith("-") and len(t) > 1 and not t[1].isdigit():
            body = t[1:]
            if "R" in body:
                recursive = follows = True
            elif "r" in body:
                recursive = True
    if not recursive or follows:
        return None
    return [t for t in toks[1:] if not t.startswith("-")]


def find_problem(toks):
    if not toks or os.path.basename(toks[0]) != "find":
        return None
    # `-type l` 是【在找符号链接本身】,跟随它等于把要找的东西变没。
    # 这不是出口豁免,是判据本来就不该覆盖的情形。
    for a, b in zip(toks, toks[1:]):
        if a in ("-type", "-xtype") and b == "l":
            return None
    roots, i = [], 1
    while i < len(toks):
        t = toks[i]
        if t in ("-L", "-follow"):
            return None                      # 已经跟随
        if t == "-P":
            return None                      # 显式声明不跟随 —— 明示即可
        if t == "-H":
            i += 1
            continue
        if t.startswith("-"):
            break                            # 开始进入表达式,路径部分结束
        roots.append(t)
        i += 1
    return roots or None


def existing_dirs(cands):
    out = []
    for c in cands or []:
        p = os.path.expanduser(c)
        if os.path.isdir(p) and p not in out:
            out.append(p)
    return out


def out(decision, reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": reason}}, ensure_ascii=False))
    sys.exit(0)


def main():
    _trace("PreToolUse/Bash-search-symlink")
    data = json.load(sys.stdin)
    cmd = (data.get("tool_input") or {}).get("command", "")
    if not cmd or OPT_OUT in cmd:
        sys.exit(0)

    for seg in segments(cmd):
        toks = tokens(seg)
        if not toks:
            continue
        for tool, roots in (("grep", grep_problem(toks)), ("find", find_problem(toks))):
            for root in existing_dirs(roots):
                links = dir_symlinks(root)
                if not links:
                    continue
                shown = "\n".join(f"    {a}  →  {b}" for a, b in links[:6])
                more = f"\n    …另有 {len(links)-6} 个" if len(links) > 6 else ""
                fix = ("把 `-r` 换成 `-R`" if tool == "grep"
                       else "在 `find` 后面加 `-L`(紧跟在 find 之后,路径之前)")
                alt = links[0][0]           # 符号链接【本身】当根是可以的：
                #                            -r/-P 只跳过树里遇到的链接,
                #                            命令行上直接给出的那个仍然跟随。
                out("deny",
                    f"⛔ 已被 hook 拦下：`{tool}` 递归搜索 {root} 但【不跟随符号链接】,"
                    f"下面这些目录会被静默跳过：\n{shown}{more}\n\n"
                    f"这类失败不报错、退出码为 0,表现与「确实不存在」完全一样 —— "
                    f"2026-09-11 就是这样得出「文件不在 /home/gao 下任何 .md 里」"
                    f"这个假阴性的,而文件就在 projects_2026M7 里。\n\n"
                    f"改法：{fix};或把目标那棵树【直接当搜索根】"
                    f"(如 {alt} —— 命令行上直接给出的符号链接是跟随的,"
                    f"被跳过的只是树里遇到的)。\n"
                    f"确属故意不跟随 ⇒ 在命令里加注释 `# {OPT_OUT}` 再跑。")
    sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:                   # fail-open,但留痕
        try:
            with open(LOG, "a") as fh:
                fh.write(f"[guard_search_symlink] {type(e).__name__}: {e}\n")
        except Exception:
            pass
        sys.exit(0)
