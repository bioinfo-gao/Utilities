#!/usr/bin/env python3
"""guard_destructive_bash.py 的回归测试。

⚠ 为什么必须是【文件】而不是一串 Bash 命令：
闸门检查的是 Bash 命令的**文本**,而测试用例本身就是危险命令 ——
把用例写在命令行里,整条测试命令会被闸门自己拦下(2026-08-30 实测连撞两次)。
用例放进文件后,执行它的命令(`python3 test_guard_destructive_bash.py`)是干净的。

改动闸门后必须跑一遍：
    python3 ~/.claude/hooks/test_guard_destructive_bash.py

⚠ 本测试只证明「闸门逻辑对」,不证明「harness 真的在调它」。后者看调用日志：
    tail ~/.claude/hooks/hook_calls.log
    awk '{print $3}' ~/.claude/hooks/hook_calls.log | sort | uniq -c
四个 tag 都出现过,才说明四个 hook 都活着。装好 ≠ 在跑。
"""
import json, os, subprocess, sys

GUARD = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                     "guard_destructive_bash.py")

# (期望结果, 命令, 这条在测什么)
CASES = [
    # A —— 真调用,不可逆,必须 deny
    ("deny",  "git push --force origin main",            "A 真调用"),
    ("deny",  "git reset --hard origin/main",            "A 真调用"),
    ("deny",  "git clean -fd",                           "A 真调用"),
    ("deny",  "git rebase --abort",                      "A 真调用"),

    # B —— 带全局选项的形式。原版正则匹配不到,是【反向漏洞】：真破坏溜过去
    ("deny",  "git -C /home/gao/.claude rebase --abort",         "B 反向漏洞"),
    ("deny",  "git -C /home/gao/Utilities reset --hard HEAD~1",  "B 反向漏洞"),
    ("deny",  "git --git-dir=/x/.git push -f origin main",       "B 反向漏洞"),

    # C —— 引号内的【提及】,不是调用。原版会误拦,连本文件都写不出来
    ("allow", 'echo "git reset --hard is banned" >> notes.md',   "C 假阳性"),
    ("allow", 'grep -n "git push --force" guard.py',             "C 假阳性"),
    ("allow", 'echo "rm -rf custom_research_report is banned"',  "C 假阳性"),

    # D —— 递归删除命中结果目录/冻结产物
    ("deny",  "rm -rf /home/gao/projects_2026M7/26_x/custom_research_report_20260803",
                                                                 "D 结果目录"),
    ("deny",  "cd /x && rm -rf output_results",                   "D 结果目录"),

    # E —— 不在命令位置但确是真删除。必须一并纳入,否则绕过闸门只需加个 -exec
    ("deny",  'bash -c "rm -rf /home/gao/x/analysis/"',           "E 执行上下文"),
    ("ask",   "find /data -name tmp -exec rm -rf {} \\;",         "E 执行上下文"),
    ("ask",   "ls | xargs rm -rf",                                "E 执行上下文"),

    # F —— 正常工作,不得打扰
    ("allow", "git push",                                         "F 正常"),
    ("allow", "git status --short",                               "F 正常"),
    ("allow", "samtools view -c in.bam",                          "F 正常"),
    ("allow", "rm -rf /tmp/claude-1001/scratch/foo",              "F 正常(scratchpad)"),

    # G —— 非递归 rm：用户的规则是「不删除文件」,不只是「不删除目录」
    ("ask",   "rm /home/gao/one_file.txt",                        "G 单文件"),
    ("allow", "rm -f /tmp/claude-1001/x/tmp.png",                 "G 单文件(scratchpad)"),
]


def decide(cmd):
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": cmd}})
    r = subprocess.run([sys.executable, GUARD], input=payload,
                       capture_output=True, text=True)
    if r.returncode != 0:
        return f"CRASH(rc={r.returncode}) {r.stderr.strip()[:80]}"
    out = r.stdout.strip()
    if not out:
        return "allow"
    return json.loads(out)["hookSpecificOutput"]["permissionDecision"]


def main():
    fails = []
    for want, cmd, why in CASES:
        got = decide(cmd)
        ok = (got == want)
        if not ok:
            fails.append((why, cmd, want, got))
        print(f"  {'PASS' if ok else 'FAIL':4s}  {want:5s} {why:18s} {cmd[:58]}")
    print(f"\n  {len(CASES) - len(fails)}/{len(CASES)} passed")
    for why, cmd, want, got in fails:
        print(f"  FAIL [{why}] {cmd}\n       期望 {want}, 实得 {got}")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
