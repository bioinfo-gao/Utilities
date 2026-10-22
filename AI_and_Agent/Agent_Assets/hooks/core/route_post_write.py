#!/usr/bin/env python3
"""PostToolUse/Write|Edit —— 按【文件路径】把刚写的文件路由到对应检查器。

为什么判定放在这一层而不是 UserPromptSubmit：
    UserPromptSubmit 只能靠关键词【猜】我要干什么,必然有漏。
    PostToolUse 拿得到 file_path —— **路径是事实,不是猜测**。
    所以权威判定放这里;提问时的注入(如果以后要做)只当"提前提醒",漏了也不致命。

检查不通过时输出 decision=block + reason,失败原因会喂回给我,当轮就能改。
"""
import json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
CHECKS = os.path.join(HERE, "checks")
LOG = os.path.join(HERE, "hook_errors.log")


def _trace(tag):
    try:
        import datetime
        with open(os.path.join(HERE, "hook_calls.log"), "a") as fh:
            fh.write(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S}  {tag}\n")
    except Exception:
        pass


# 只有【项目树里】的东西才可能是客户交付物。
# 少了这一条,`~/.claude/hooks/guard_inline_email.py` 这种基础设施文件会因为
# 文件名含 "email" 被当成客户邮件检查 —— 2026-08-30 实测,路由把自己拦了。
CLIENT_SCOPE = re.compile(r"/projects_20\d{2}[A-Za-z]*\d*/")


def pick_checker(path):
    """返回 (检查器绝对路径, 这类文件叫什么)。认不出就 (None, None)。"""
    ap, base = os.path.abspath(path), os.path.basename(path)
    if not CLIENT_SCOPE.search(ap):
        return None, None
    if re.search(r"/custom_research_report[^/]*/", ap) and base.endswith(".md"):
        return os.path.join(CHECKS, "check_report.py"), "客户报告"
    if base.endswith(".py") and "/scripts/" in ap and \
       re.search(r"(email|client.?reply|reply.?client)", base, re.I):
        return os.path.join(CHECKS, "check_client_email.py"), "客户邮件"
    return None, None


def main():
    _trace("PostToolUse/Write-Edit-route")
    data = json.load(sys.stdin)
    ti = data.get("tool_input") or {}
    tr = data.get("tool_response") or {}
    path = (tr.get("filePath") if isinstance(tr, dict) else None) \
        or ti.get("file_path") or ti.get("notebook_path") or ""
    if not path or not os.path.exists(path):
        sys.exit(0)

    checker, kind = pick_checker(path)
    if not checker or not os.path.exists(checker):
        sys.exit(0)

    r = subprocess.run([sys.executable, checker, path],
                       capture_output=True, text=True, timeout=30)
    if r.returncode == 0:
        sys.exit(0)

    detail = (r.stdout + r.stderr).strip()
    print(json.dumps({
        "decision": "block",
        "reason": f"【{kind}检查未通过】{path}\n{detail}\n\n"
                  f"改完后再写一次即可重跑检查;要手动复核跑：\n"
                  f"  python3 {checker} {path}"}, ensure_ascii=False))
    sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        try:
            open(LOG, "a").write(f"[route_post_write] {type(e).__name__}: {e}\n")
        except Exception:
            pass
        sys.exit(0)
