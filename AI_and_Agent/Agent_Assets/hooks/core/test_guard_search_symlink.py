#!/usr/bin/env python3
"""guard_search_symlink.py 的回归测试。

改动闸门后必须跑一遍：
    python3 ~/.claude/hooks/test_guard_search_symlink.py

用例不依赖 /home/gao 的真实布局 —— 现场在 tmp 下搭一个
「根里含一个指向目录的符号链接」的最小场景,这正是 2026-09-11 那次假阴性的形状：
    <root>/link_tree -> <elsewhere>/real_tree/     (里面有 target.md)
另建一个不含符号链接的根,用来证明【不该拦的不拦】。

⚠ 本测试只证明「闸门逻辑对」,不证明「harness 真的在调它」。后者看调用日志：
    awk '{print $3}' ~/.claude/hooks/hook_calls.log | sort | uniq -c
出现 PreToolUse/Bash-search-symlink 才说明它活着。装好 ≠ 在跑。
"""
import json, os, shutil, subprocess, sys, tempfile

GUARD = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                     "guard_search_symlink.py")


def build():
    base = tempfile.mkdtemp(prefix="guard_symlink_test_")
    real = os.path.join(base, "elsewhere", "real_tree")
    os.makedirs(real)
    open(os.path.join(real, "target.md"), "w").write("需要被找到的一句\n")

    linked = os.path.join(base, "with_link")        # 根下有目录符号链接
    os.makedirs(linked)
    open(os.path.join(linked, "other.md"), "w").write("无关\n")
    os.symlink(real, os.path.join(linked, "link_tree"))

    plain = os.path.join(base, "no_link")           # 根下没有符号链接
    os.makedirs(os.path.join(plain, "sub"))
    open(os.path.join(plain, "sub", "a.md"), "w").write("无关\n")
    return base, linked, plain, real


def run(cmd):
    p = subprocess.run([sys.executable, GUARD],
                       input=json.dumps({"tool_name": "Bash",
                                         "tool_input": {"command": cmd}}),
                       capture_output=True, text=True, timeout=20)
    if not p.stdout.strip():
        return "allow", ""
    d = json.loads(p.stdout)["hookSpecificOutput"]
    return d["permissionDecision"], d["permissionDecisionReason"]


def main():
    base, L, P, real = build()
    try:
        cases = [
            # A —— 真会出事：递归但不跟随,且根下确实有目录符号链接
            ("deny",  f"grep -rl --include='*.md' '需要被找到' {L}",  "A 假阴性"),
            ("deny",  f"grep -rn 'x' {L}",                            "A 假阴性"),
            ("deny",  f"grep --recursive 'x' {L}",                    "A 假阴性(长选项)"),
            ("deny",  f"find {L} -name '*.md'",                       "A 假阴性(find 默认不跟随)"),
            ("deny",  f"ls | xargs grep -r 'x' {L}",                  "A 壳里也要看得见"),
            ("deny",  f"timeout 90 grep -rl 'x' {L}",                 "A 壳里也要看得见"),

            # B —— 已经跟随,或本就不该拦
            ("allow", f"grep -Rl 'x' {L}",                            "B 已 -R"),
            ("allow", f"grep --dereference-recursive 'x' {L}",        "B 已 -R(长选项)"),
            ("allow", f"find -L {L} -name '*.md'",                    "B 已 -L"),
            ("allow", f"find -P {L} -name '*.md'",                    "B 显式不跟随"),
            ("allow", f"grep -rl 'x' {P}",                            "B 根下无符号链接"),
            ("allow", f"find {P} -name '*.md'",                       "B 根下无符号链接"),
            ("allow", f"grep -n 'x' {L}/other.md",                    "B 非递归"),
            ("allow", f"grep -rl 'x' {L}   # no-follow-intended",     "B 显式声明出口"),
            ("allow", f"find {L} -maxdepth 2 -type l",                "B 就是在找符号链接"),
            ("allow", f"find {L} -xtype l",                           "B 就是在找符号链接"),

            # C —— 引号里的【提及】不是调用,不得误拦(guard_destructive 同款教训)
            ("allow", f'echo "grep -r pattern {L} 会漏"',              "C 假阳性"),

            # D —— 与本次事故完全同形的真实命令
            ("deny",  "grep -rl --include='*.md' '本文档的证据等级' /home/gao",
                                                                      "D 复刻 0911 事故"),
            ("allow", "grep -Rl --include='*.md' '本文档的证据等级' /home/gao",
                                                                      "D 修好的写法"),
        ]
        bad = 0
        for want, cmd, why in cases:
            got, reason = run(cmd)
            ok = got == want
            bad += not ok
            short = cmd if len(cmd) < 72 else cmd[:69] + "..."
            print(f"{'✅' if ok else '❌'} [{why}] 期望 {want:5s} 实得 {got:5s}  {short}")
            if not ok and reason:
                print("      ", reason.splitlines()[0])
        print(f"\n{len(cases)-bad}/{len(cases)} 通过")
        return 1 if bad else 0
    finally:
        shutil.rmtree(base, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
