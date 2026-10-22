#!/usr/bin/env python3
"""PreToolUse/Bash —— 堵上「不写 .py 文件、直接用 Bash 起草邮件」这条绕过路径。

为什么需要它：
    route_post_write.py 靠【文件路径】判定要不要跑邮件检查 —— 路径是事实,很可靠。
    但我如果用 `python3 - <<'EOF' ... imaplib ... APPEND ... EOF` 直接内联起草,
    **根本没有文件产生**,PostToolUse 看不到任何东西,整套检查形同虚设。
    这是那套设计里唯一的真漏洞(不是理论风险 —— 内联起草正是我惯用的写法)。

做法：命令文本里同时出现 imaplib 与 APPEND ⇒ 认定这是在往 Gmail 草稿箱写信,
把命令(优先取 heredoc 里的 Python 正文)交给同一个 check_client_email.py 检查,
不通过就 deny —— 在写进草稿箱【之前】拦下,而不是事后发现。
"""
import json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CHECKER = os.path.join(HERE, "checks", "check_client_email.py")
LOG = os.path.join(HERE, "hook_errors.log")

IS_EMAIL = (re.compile(r"imaplib"), re.compile(r"\bAPPEND\b", re.I))
# python3 - <<'EOF' ... EOF / <<"PYEOF" ... PYEOF
HEREDOC = re.compile(r"<<-?\s*['\"]?(\w+)['\"]?\s*\n(.*?)\n\s*\1\b", re.S)


def _trace(tag):
    try:
        import datetime
        with open(os.path.join(HERE, "hook_calls.log"), "a") as fh:
            fh.write(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S}  {tag}\n")
    except Exception:
        pass


def payload(cmd):
    """优先取 heredoc 里的 Python 正文(ast 解析得动);取不到就退回整条命令。"""
    best = ""
    for m in HEREDOC.finditer(cmd):
        body = m.group(2)
        if "imaplib" in body or "APPEND" in body.upper() or len(body) > len(best):
            best = body if len(body) > len(best) else best
    return best or cmd


def main():
    _trace("PreToolUse/Bash-inline-email")
    data = json.load(sys.stdin)
    cmd = (data.get("tool_input") or {}).get("command", "")
    if not cmd or not all(p.search(cmd) for p in IS_EMAIL):
        sys.exit(0)
    if not os.path.exists(CHECKER):
        sys.exit(0)

    with tempfile.NamedTemporaryFile("w", suffix="_inline_email.py",
                                     delete=False, encoding="utf-8") as fh:
        fh.write(payload(cmd))
        tmp = fh.name
    try:
        r = subprocess.run([sys.executable, CHECKER, tmp],
                           capture_output=True, text=True, timeout=30)
    finally:
        try:
            os.unlink(tmp)
        except OSError:
            pass

    if r.returncode == 0:
        sys.exit(0)

    detail = (r.stdout + r.stderr).strip()
    detail = detail.replace(tmp, "<内联邮件正文>")
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason":
            "⛔ 内联起草的客户邮件未通过检查（在写进 Drafts 之【前】拦下）：\n"
            + detail +
            "\n\n改好正文再跑。要单独复核：把正文存成 .py 后跑\n"
            f"  python3 {CHECKER} <那个文件>"}}, ensure_ascii=False))
    sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        try:
            open(LOG, "a").write(f"[guard_inline_email] {type(e).__name__}: {e}\n")
        except Exception:
            pass
        sys.exit(0)
