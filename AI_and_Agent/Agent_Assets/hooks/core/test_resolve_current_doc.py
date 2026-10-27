#!/usr/bin/env python3
"""resolve_current_doc.py 的回归测试。

    python3 ~/.claude/hooks/test_resolve_current_doc.py

2026-10-27 起 hook 自己校验「用户引用的原文是否在解析到的文件里」,不在就到同一项目里找。
两类用例都要有：
  · 过期解析必须被纠正(P45 实测：transcript 最近一条指向归档 txt,原文在 docs/ 的报告里);
  · 解析正确、或用户根本没引用原文时,必须保持原解析 —— 否则每次提问都被改道。
"""
import json, os, subprocess, sys, tempfile

HOOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "resolve_current_doc.py")


def expect(name, cond, detail=""):
    print(f"  {'PASS' if cond else 'FAIL'}  {name}" + (f"\n        {detail}" if not cond else ""))
    return cond


def run(prompt, transcript):
    r = subprocess.run([sys.executable, HOOK], input=json.dumps(
        {"prompt": prompt, "transcript_path": transcript}), capture_output=True, text=True)
    return json.loads(r.stdout)["hookSpecificOutput"]["additionalContext"] if r.stdout.strip() else ""


def main():
    ok = []
    with tempfile.TemporaryDirectory() as td:
        proj = os.path.join(td, "45_test_project")
        os.makedirs(os.path.join(proj, "docs"))
        os.makedirs(os.path.join(proj, "superseded_for_comparison", "v1", "scripts"))  # 归档里的脚本快照不能被当成项目根
        stale = os.path.join(proj, "superseded_for_comparison", "v1", "captions_before.txt")
        report = os.path.join(proj, "docs", "Report_1026_CN.md")
        old = os.path.join(proj, "superseded_for_comparison", "v1", "Report_1025_CN.md")
        line = "| Repeat-ambiguous | 只有 partner 端不明且事件满足一致性（见下几行）时除外 | x |\n"
        open(stale, "w").write("图注旧版,与问题无关。\n")
        open(old, "w").write(line)
        open(report, "w").write("# 报告\n" + line)
        tr = os.path.join(td, "t.jsonl")
        open(tr, "w").write(json.dumps({"x": f"The user opened the file {stale} in the IDE"}) + "\n")

        q = "请解释什么是这里说的一致性：只有 partner 端不明且事件满足一致性（见下几行）时除外"
        out = run(q, tr)
        ok.append(expect("过期解析 + 明确引用 ⇒ 改指项目内含原文的文档", f"    {report}\n" in out, out[:400]))
        ok.append(expect("归档目录里的同名命中排在后面", out.find(report) < out.find(old) and old in out, out[:400]))
        ok.append(expect("改道后不再要求向用户要 path", "必须向用户要 path" not in out, out[:400]))

        out = run("请解释本文第三节的判定标准是怎么定的", tr)
        ok.append(expect("没有引用原文 ⇒ 保持原解析,不改道", f"    {stale}\n" in out, out[:400]))

        open(stale, "a").write("这句在旧文件里确实存在的原文内容\n")
        out = run("这里怎么理解：这句在旧文件里确实存在的原文内容", tr)
        ok.append(expect("引用的原文就在解析文件里 ⇒ 保持原解析", f"    {stale}\n" in out, out[:400]))

        out = run("这里怎么理解：项目里任何文件都不存在的一段原文哦哦", tr)
        ok.append(expect("项目内也找不到 ⇒ 走 workspace 兜底,注明可能过期", "可能已过期" in out, out[:400]))

        open(tr, "a").write(json.dumps({"x": 'code: f"The user opened the file {stale} in the IDE"'}) + "\n")
        out = run("请解释本文第三节的判定标准是怎么定的", tr)
        ok.append(expect("transcript 里的代码字面量 {stale} 不算 IDE 通知", f"    {stale}\n" in out, out[:400]))

        ok.append(expect("没有指代词 ⇒ 不注入", run("帮我看看 P45 的 Fig1", tr) == ""))

    print(f"\n  {sum(ok)}/{len(ok)} passed")
    sys.exit(0 if all(ok) else 1)


if __name__ == "__main__":
    main()
