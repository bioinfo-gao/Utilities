#!/usr/bin/env python3
"""PreToolUse/Bash —— 破坏性命令闸门。

存在理由：CLAUDE.md 里「删除/覆盖前必须先获得用户同意」「永不对结果目录 rm -rf」
是【写给我看的文字】,2026-08-03 proj26 靠它没拦住,24 组产物永久丢失。
本脚本把同一条规则搬到【工具调用发生的那一刻】,不依赖我记得。

失败时 fail-open(退出 0 不拦),但把异常写进 hooks/hook_errors.log ——
一个静默坏掉的 hook 比没有 hook 更糟,必须留痕。

2026-08-30 修订(两处都是实测出来的):
  ① 危险 git 子命令必须落在【命令位置】才算 —— 原先匹配任意位置,
     导致「写一个提到该命令的脚本」也被拦(本文件自己就撞上了)。
  ② `git -C <path> rebase` / `--git-dir=` 这类带全局选项的形式原先【匹配不到】,
     是反向漏洞:真正的破坏性调用溜过去,假的反而被拦。
"""
import json, os, re, sys

LOG = os.path.expanduser("~/.claude/hooks/hook_errors.log")


def _trace(tag):
    """每次被调用就留一行 —— 「hook 装好了」和「hook 在跑」是两件事,必须能分开验。"""
    try:
        import datetime
        with open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                               "hook_calls.log"), "a") as fh:
            fh.write(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S}  {tag}\n")
    except Exception:
        pass


# 命令位置：行首 / 管道或分号之后 / 子 shell 开头。引号里的提及不算。
CMD_POS = r"(?:^|[;&|]\s*|\n\s*|\(\s*|\{\s*)"
# git 与子命令之间允许 -C <path> / --git-dir= / --work-tree= / -c k=v
GIT = r"git(?:\s+(?:-C\s+\S+|--git-dir=\S+|--work-tree=\S+|-c\s+\S+))*\s+"

# 结果目录 / 冻结产物 —— 递归删除命中即 deny,不给 ask 的机会
FROZEN = re.compile(
    r"(custom_research_report|output_results|superseded_for_comparison"
    r"|Data_Analysis_\d|/analysis(/|\s|$)|results?/)", re.I)

# 硬拒:不可逆且从不是正确做法
HARD_DENY = [
    (re.compile(CMD_POS + GIT + r"push\b[^|;&\n]*\s(?:--force\b|--force-with-lease\b|-f\b)"),
     "force-push 会改写远端历史。CLAUDE.md §7/Git 条:必须先说明再执行。"),
    (re.compile(CMD_POS + GIT + r"reset\s+(?:[^|;&\n]*\s)?--hard\b"),
     "reset --hard 丢弃工作区改动,可能包含用户或其他会话的修改。CLAUDE.md §7 明令禁止。"),
    (re.compile(CMD_POS + GIT + r"clean\b[^|;&\n]*-[a-zA-Z]*f"),
     "clean -f 删除未跟踪文件,不可恢复。CLAUDE.md §7 明令禁止。"),
    (re.compile(CMD_POS + GIT + r"(?:rebase|filter-branch|filter-repo)\b"),
     "改写提交历史。CLAUDE.md §7:不修改提交历史。"),
]

# rm 的「执行位置」比 git 宽：除命令位置外,-exec / xargs / sh -c 里的 rm 都是真删除,
# 必须一并拦。但引号里的【提及】(echo / grep / JSON payload)不在其中 —— 那是假阳性来源。
RM_POS = (r"(?:^|[;&|]\s*|\n\s*|\(\s*|\{\s*"
          r"|-exec(?:dir)?\s+|xargs\s+(?:-\S+\s+)*|-c\s+['\"]?)")
RM_RECURSIVE = re.compile(
    RM_POS + r"rm\s+(-[a-zA-Z]*[rR][a-zA-Z]*\s+|-[a-zA-Z]*\s+-[a-zA-Z]*[rR][a-zA-Z]*\s+)")
RM_ANY_POS = re.compile(RM_POS + r"rm\s")
# 这些位置随便删
SAFE_PREFIX = re.compile(r"(^|\s)(/tmp/claude-|/tmp/|\$TMPDIR|~/\.cache/|/dev/shm/)")


def out(decision, reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": reason}}, ensure_ascii=False))
    sys.exit(0)


def main():
    _trace("PreToolUse/Bash")
    data = json.load(sys.stdin)
    cmd = (data.get("tool_input") or {}).get("command", "")
    if not cmd:
        sys.exit(0)

    for pat, why in HARD_DENY:
        if pat.search(cmd):
            out("deny", f"⛔ 已被 hook 拦下：{why}\n"
                        "先向用户说明「要做什么/影响范围/能否回退」,得到答复后再执行。")

    if RM_RECURSIVE.search(cmd):
        if FROZEN.search(cmd):
            out("deny", "⛔ 已被 hook 拦下：递归删除命中【结果目录/冻结产物】"
                        "(custom_research_report / output_results / analysis / "
                        "superseded_for_comparison / Data_Analysis_*)。\n"
                        "CLAUDE.md「原始记录不能丢」：任何结果目录一律不许递归删除,"
                        "包括以「干净重跑」为由。重跑前【先移走/复制走】再跑。\n"
                        "2026-08-03 proj26 就是这样丢掉 24 组不可再生产物的。")
        if not SAFE_PREFIX.search(cmd):
            out("ask", "递归删除,且不在 scratchpad/tmp 下。CLAUDE.md §4:"
                       "未经明确确认不删除文件、目录、用户数据、运行产物。\n"
                       "请向用户确认「删什么/为什么/影响范围/能否回退」。")

    # 非递归 rm —— 用户的规则是「不删除文件」,不只是「不删除目录」
    if RM_ANY_POS.search(cmd) and not SAFE_PREFIX.search(cmd):
        out("ask", "删除文件,且不在 scratchpad/tmp 下。CLAUDE.md §4:"
                   "未经明确确认不删除文件、目录、用户数据、运行产物。")

    sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:      # fail-open,但留痕
        try:
            with open(LOG, "a") as fh:
                fh.write(f"[guard_destructive_bash] {type(e).__name__}: {e}\n")
        except Exception:
            pass
        sys.exit(0)
