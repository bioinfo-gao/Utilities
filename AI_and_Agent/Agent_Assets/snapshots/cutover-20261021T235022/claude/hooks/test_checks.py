#!/usr/bin/env python3
"""checks/ 四个检查器的回归测试。

    python3 ~/.claude/hooks/test_checks.py

两类用例都要有,缺一不可：
  · **真实产物必须 PASS** —— 否则检查器过严,每次写报告都被拦,最后只会被关掉。
  · **人造缺陷必须被抓到** —— 否则检查器等于没有。
只测后者是最常见的自欺：一个「什么都拦」的检查器也能通过全部缺陷用例。
"""
import os, subprocess, sys, tempfile

HOOKS = os.path.dirname(os.path.abspath(__file__))
CHECKS = os.path.join(HOOKS, "checks")
PROJ = "/home/gao/projects_2026M7"

REAL_REPORT = os.path.join(
    PROJ, "31_Yeji_Park_RPE1_CRISPR_dual_cut_wgs",
    "custom_research_report_20260828", "Dual_Cut_Project_WGS_0828.md")
REAL_EMAIL = os.path.join(
    PROJ, "31_Yeji_Park_RPE1_CRISPR_dual_cut_wgs", "scripts",
    "20260828", "4_email_report_entrypoint_0829.py")

BAD_REPORT = """# Test Report

**Project:** X
**Report Date:** 2026-08-01
**Prepared by:** Someone Else
**Analysis Platform:** Linux HPC server

## 1. Objectives
We recommend at least 30x coverage, and long-read sequencing would help.
## 2. Core Conclusions
Section 8.2 restates the measured findings. See Section 12.4 for detail.
## 3. Key Findings
## 4. Sample Information
## 5. Analysis Rationale and Decision Criteria
## 6. Methods
Run in /home/gao with regular_bioinfo.
## 7. Results
## 8. Conclusions
## 9. Deliverable Files
"""

BAD_EMAIL = '''BODY = """Hi Yeji,

You are right, and the wording was ours to fix. Sorry about that.
The analysis is complete. Please upload the fastq to Dropbox.
We recommend at least 30x depth, or long read sequencing. 谢谢
"""
'''


def run(script, path):
    r = subprocess.run([sys.executable, script, path],
                       capture_output=True, text=True)
    return r.returncode, (r.stdout + r.stderr).strip()


def expect(name, cond, detail=""):
    print(f"  {'PASS' if cond else 'FAIL'}  {name}" + (f"\n        {detail}" if not cond else ""))
    return cond


def main():
    ok = []

    # ── 1. 真实产物必须通过 ────────────────────────────────────────
    if os.path.exists(REAL_REPORT):
        rc, out = run(os.path.join(CHECKS, "check_report.py"), REAL_REPORT)
        ok.append(expect("真实已交付报告 PASS（检查器不过严）", rc == 0, out[:600]))
    else:
        print("  SKIP  真实报告不存在")
    if os.path.exists(REAL_EMAIL):
        rc, out = run(os.path.join(CHECKS, "check_client_email.py"), REAL_EMAIL)
        ok.append(expect("真实客户邮件脚本 PASS（检查器不过严）", rc == 0, out[:600]))
    else:
        print("  SKIP  真实邮件脚本不存在")

    # ── 2. 人造缺陷必须被抓 ────────────────────────────────────────
    with tempfile.TemporaryDirectory() as td:
        d = os.path.join(td, "custom_research_report_20260830")
        os.makedirs(d)
        p = os.path.join(d, "Test_Report_0830.md")
        open(p, "w").write(BAD_REPORT)
        rc, out = run(os.path.join(CHECKS, "check_report.py"), p)
        ok.append(expect("缺陷报告被拦", rc != 0))
        for frag, why in [
                ("long-read", "建议长读长"),
                ("restates the", "简单重复"), ("Section 12.4", "交叉引用失效"),
                ("§8 标题", "§8 必须用全名"), ("Species", "header 缺 Species"),
                ("Tissue / Cell", "header 缺 Tissue"),
                ("签名", "签名缺失"), ("regular_bioinfo", "内部信息泄漏"),
                ("日期不一致", "三处日期"),
        ]:
            ok.append(expect(f"  抓到：{why}", frag in out, out[:400]))
        # 2026-08-30 用户解禁：建议加测序深度是正常的科学建议,不再拦
        # ⚠ 断言要盯【违规标签】,不能盯解释文字里的词 ——
        #    初版写成 `"深度" not in out`,而长读长那条的解释句里就含「深度/读长」,自证失败。
        ok.append(expect("  「建议加深度」已解禁 ⇒ 不再报",
                         "建议加测序深度" not in out and "at least 30x" not in out,
                         out[:400]))

        # §5 允许自由发挥：标题含 Analysis 即可
        for title, should_flag in [("Analysis of the Data", False),
                                   ("Analysis Rationale and Decision Criteria", False),
                                   ("Rationale and Criteria", True)]:
            open(p, "w").write(BAD_REPORT.replace(
                "## 5. Analysis Rationale and Decision Criteria", f"## 5. {title}"))
            _, o = run(os.path.join(CHECKS, "check_report.py"), p)
            flagged = "§5 标题需含" in o
            ok.append(expect(f"  §5 = {title!r} ⇒ {'报' if should_flag else '不报'}",
                             flagged == should_flag, o[:300]))
        open(p, "w").write(BAD_REPORT)

        pe = os.path.join(td, "9_client_email_test.py")
        open(pe, "w").write(BAD_EMAIL)
        rc, out = run(os.path.join(CHECKS, "check_client_email.py"), pe)
        ok.append(expect("缺陷邮件被拦", rc != 0))
        # 2026-08-30 解禁：邮件里建议加深度也不再拦（与 check_report.py 同步）
        ok.append(expect("  邮件里的「建议加深度」已解禁 ⇒ 不再报",
                         "不建议加测序深度" not in out, out[:400]))
        for frag, why in [
                ("you are right", "认错措辞"), ("ours to fix", "认错措辞"),
                ("sorry", "道歉"), ("upload", "提了数据传输"),
                ("dropbox", "提了数据传输"),
                ("long read", "建议长读长"), ("全角", "交付物含中文"),
                ("签名", "签名缺失"), ("点名报告文件", "宣布完成却没给入口"),
        ]:
            ok.append(expect(f"  抓到：{why}", frag in out.lower() or frag in out,
                             out[:400]))

    # ── 3. 回复检查器 ─────────────────────────────────────────────
    sys.path.insert(0, CHECKS)
    import check_reply
    MAIL = "致客户的信仍在草稿箱,尚未发送。"
    PUSH = "两个仓库都已推送。"
    RUN_ = "sarek 正在运行,还在跑第 3 个样本。"

    ok.append(expect("邮件断言 + 一条命令都没跑 ⇒ 报警",
                     bool(check_reply.run(MAIL, []))))
    # ↓ 这条是本次收紧的核心：跑过 Bash,但跑的是无关命令,初版会误判为「有证据」
    ok.append(expect("邮件断言 + 跑的是无关命令(git status) ⇒ 仍报警",
                     bool(check_reply.run(MAIL, ["git status --short"]))))
    ok.append(expect("邮件断言 + 跑了 IMAP 回读 ⇒ 放行",
                     not check_reply.run(MAIL, ["python3 10_check_client_email_state.py"])))
    ok.append(expect("邮件断言 + 跑了 imaplib ⇒ 放行",
                     not check_reply.run(MAIL, ["python3 -c 'import imaplib; ...'"])))

    ok.append(expect("推送断言 + git rev-list ⇒ 放行",
                     not check_reply.run(PUSH, ["git rev-list --count @{u}..HEAD"])))
    ok.append(expect("推送断言 + 只跑了 ls ⇒ 报警",
                     bool(check_reply.run(PUSH, ["ls -l /home/gao"]))))

    ok.append(expect("在跑断言 + tmux capture-pane ⇒ 放行",
                     not check_reply.run(RUN_, ["tmux capture-pane -t s -p"])))
    ok.append(expect("在跑断言 + 只跑了 cat ⇒ 报警",
                     bool(check_reply.run(RUN_, ["cat notes.md"]))))

    # ↓ 0914 同日连拦 2 次皆为误报,收窄后补的回归用例。
    #   前 4 条必须【放行】,后 3 条必须仍【拦】—— 防止修误报时把闸门修废。
    ok.append(expect("误报:「现在跑实测」是跨词边界,不是状态断言 ⇒ 放行",
                     not check_reply.run("现在跑实测 —— 先看 pandas 的核心陷阱", ["ls -la"])))
    ok.append(expect("误报:「我现在跑一下看看」⇒ 放行",
                     not check_reply.run("我现在跑一下看看", ["ls -la"])))
    ok.append(expect("误报:行内代码里的正则字面量不算断言 ⇒ 放行",
                     not check_reply.run("把 `在跑` 收窄成 `(?<!现)在跑`", ["ls -la"])))
    ok.append(expect("误报:代码块里的日志不算断言 ⇒ 放行",
                     not check_reply.run("日志:\n```\nsarek 正在跑\n```", ["ls -la"])))
    ok.append(expect("仍要拦:「那个任务在跑」(前缀不是「现」)",
                     bool(check_reply.run("那个任务在跑", ["ls -la"]))))
    ok.append(expect("仍要拦:「现在跑完了」(走「跑完了」分支)",
                     bool(check_reply.run("现在跑完了", ["ls -la"]))))
    ok.append(expect("仍要拦:句中夹行内代码,断言在代码之外",
                     bool(check_reply.run("任务 `sarek` 正在跑", ["ls -la"]))))

    ok.append(expect("commands=None ⇒ 跳过状态断言(单独跑的场景)",
                     not check_reply.run(MAIL, None)))

    ok.append(expect("表格分隔行格式错 ⇒ 报警",
                     bool(check_reply.run("| a | b |\n| --- | --- |\n| 1 | 2 |", None))))
    ok.append(expect("表格分隔行格式对 ⇒ 放行",
                     not check_reply.run("| a | b |\n| :--- | :---: |\n| 1 | 2 |", None)))
    ok.append(expect("代码块里的横线不误报",
                     not check_reply.run("```\n| --- | --- |\n```", None)))
    ok.append(expect("日文假名 ⇒ 报警",
                     bool(check_reply.run("これはテストです", None))))
    ok.append(expect("纯中文不误报",
                     not check_reply.run("这是一句普通的中文回复,含标点、括号（如此）。", None)))

    # ── 4. 路由：只有【项目树里】的东西才算客户交付物 ──────────────
    sys.path.insert(0, HOOKS)
    import route_post_write as R
    for path, want, why in [
        ("/home/gao/.claude/hooks/guard_inline_email.py", None,
         "基础设施文件名含 email,不得被当成客户邮件（2026-08-30 实测自拦）"),
        ("/home/gao/.claude/hooks/checks/check_client_email.py", None,
         "检查器自己也不能被检查"),
        (f"{PROJ}/31_x/scripts/2_append_client_email.py", "客户邮件", "项目 scripts 里的邮件脚本"),
        (f"{PROJ}/31_x/custom_research_report_20260828/X_0828.md", "客户报告", "项目里的交付报告"),
        ("/home/gao/Utilities/notes/email_tips.md", None, "非项目树"),
    ]:
        got = R.pick_checker(path)[1]
        ok.append(expect(f"路由：{why}", got == want, f"期望 {want}, 实得 {got}"))

    # ── 5. 内联邮件闸门：堵住「不写文件直接用 Bash 起草」这条绕过 ────
    import json as _json
    GUARD = os.path.join(HOOKS, "guard_inline_email.py")

    def probe(cmd):
        r = subprocess.run([sys.executable, GUARD], text=True, capture_output=True,
                           input=_json.dumps({"tool_name": "Bash",
                                              "tool_input": {"command": cmd}}))
        s = r.stdout.strip()
        return "allow" if not s else \
            _json.loads(s)["hookSpecificOutput"]["permissionDecision"]

    BAD_INLINE = ("python3 - <<'EOF'\nimport imaplib\n"
                  'BODY = """Hi,\n\nYou are right, sorry about that. '
                  'Please upload to Dropbox.\n\nZhen Gao, PhD, Athenomics\n"""\n'
                  "m.append('[Gmail]/Drafts', '', None, msg)   # APPEND\nEOF")
    GOOD_INLINE = ("python3 - <<'EOF'\nimport imaplib\n"
                   'BODY = """Hi Yeji,\n\nStart with '
                   'custom_research_report_20260828/Dual_Cut_0828.md.\n\n'
                   'Zhen Gao, PhD, Principal Bioinformatics Scientist, Athenomics\n"""\n'
                   "m.append('[Gmail]/Drafts', '', None, msg)   # APPEND\nEOF")
    ok.append(expect("内联邮件：正文有认错/传输措辞 ⇒ deny", probe(BAD_INLINE) == "deny"))
    ok.append(expect("内联邮件：正文干净 ⇒ allow", probe(GOOD_INLINE) == "allow"))
    ok.append(expect("非邮件命令 ⇒ allow", probe("ls -l /home/gao") == "allow"))
    ok.append(expect("只有 imaplib 没有 APPEND ⇒ 不管",
                     probe("python3 -c 'import imaplib; print(1)'") == "allow"))


    # ── 6. 表格落盘分诊：聊天里给过的表,有没有整行没进文档 ────────────
    # 真实来源：2026-09-13 五年预测文档漏掉「空间大数据工程」一整行,用户发现的。
    import check_table_transfer as ctt

    REAL_DOC = ("/home/gao/Utilities/Bioinfo/single_cell_and_spatial/"
                "R_and_Python_5yr_forecast_and_trainee_curriculum_20260913.md")
    CHAT_TABLE = """| 环节 | 2026 现状 | 2031 预测 | 置信度 |
| :--- | :---: | :---: | :---: |
| 上游 QC / normalization / integration | Python 已明显领先 | Python 压倒性 | 高 |
| 大规模 atlas / out-of-core | h5ad + zarr 是事实标准 | Python 赢定 | 高 |
| 深度学习方法（scVI / foundation model） | 首发几乎都在 Python | R 完全出局 | 高 |
| 细胞注释 | 两边都有 | 被 foundation model 抹平 | 中 |
| pseudobulk 跨条件 DE | DESeq2/edgeR/limma 是原版 | R 仍是默认 | 中 |
| 空间转录组统计 | OSTA 40 章 vs Seurat 2 个 vignette | R 仍有优势 | 中低 |
| 空间大数据工程（Xenium/VisiumHD） | SpatialData 的 lazy loading R 做不到 | Python 赢在工程 | 高 |
| 出版级绘图 | ggplot2 / ComplexHeatmap 更好 | 差距收窄 | 中 |"""

    if os.path.exists(REAL_DOC):
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False,
                                         encoding="utf-8") as fh:
            for ln in open(REAL_DOC, encoding="utf-8"):
                if "空间：大数据体量的读写与可视化" not in ln:
                    fh.write(ln)            # 复原「修复前」那一版
            BEFORE = fh.name
        hit_before = " ".join(ctt.run(CHAT_TABLE, [BEFORE]))
        hit_after = " ".join(ctt.run(CHAT_TABLE, [REAL_DOC]))
        ok.append(expect("表格分诊：真实漏行(Xenium/VisiumHD)必须被点名",
                         "空间大数据工程" in hit_before, hit_before or "(无输出)"))
        ok.append(expect("表格分诊：补上之后该行不再被点名",
                         "空间大数据工程" not in hit_after, hit_after))
        os.unlink(BEFORE)
    else:
        ok.append(expect("表格分诊：真实文档存在", False, f"找不到 {REAL_DOC}"))

    with tempfile.TemporaryDirectory() as td:
        full = os.path.join(td, "full.md")
        open(full, "w", encoding="utf-8").write(
            "# x\n上游 QC / normalization / integration\n大规模 atlas / out-of-core\n"
            "深度学习方法（scVI / foundation model）\n细胞注释\n"
            "pseudobulk 跨条件 DE\n空间转录组统计\n"
            "空间大数据工程（Xenium/VisiumHD）\n出版级绘图\n")
        ok.append(expect("表格分诊：整表都落盘 ⇒ 静默", not ctt.run(CHAT_TABLE, [full])))

        unrel = os.path.join(td, "unrelated.md")
        open(unrel, "w", encoding="utf-8").write("# 完全无关\n讲的是 sFTP 端口配置。\n")
        ok.append(expect("表格分诊：命中率过低视为无关表 ⇒ 不报",
                         not ctt.run(CHAT_TABLE, [unrel])))

        short = "| a | b |\n| :--- | :---: |\n| 甲乙丙 | 1 |\n| 丁戊己 | 2 |"
        ok.append(expect("表格分诊：不足 3 行的表不查", not ctt.run(short, [unrel])))

        fenced = "```\n" + CHAT_TABLE + "\n```"
        ok.append(expect("表格分诊：代码块里的表不算", not ctt.run(fenced, [unrel])))

        ok.append(expect("表格分诊：本轮没写 .md ⇒ 不触发",
                         not ctt.run(CHAT_TABLE, [])))
        ok.append(expect("表格分诊：路径不存在 ⇒ 不崩",
                         not ctt.run(CHAT_TABLE, ["/nonexistent/zzz.md"])))

    print(f"\n  {sum(ok)}/{len(ok)} passed")
    sys.exit(0 if all(ok) else 1)


if __name__ == "__main__":
    main()
