#!/usr/bin/env python3
"""PreToolUse/Write|Edit —— 冻结交付物的覆盖闸门。

CLAUDE.md：已交付的 custom_research_report_YYYYMMDD/ 及其中每个文件
「untouched, never edited/overwritten/deleted」,是那一轮的冻结记录。
新结果要开新日期目录,不是就地改旧的。

只在【文件已存在】时拦(新建交付文件是正常动作,不拦)。
"""
import json, os, re, sys

LOG = os.path.expanduser("~/.claude/hooks/hook_errors.log")
FROZEN_DIR = re.compile(r"/(custom_research_report[^/]*|superseded_for_comparison)/")


def _trace(tag):
    """每次被调用就留一行 —— 「hook 装好了」和「hook 在跑」是两件事,必须能分开验。"""
    try:
        import datetime, os as _os
        with open(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)),
                                "hook_calls.log"), "a") as fh:
            fh.write(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S}  {tag}\n")
    except Exception:
        pass


def main():
    _trace("PreToolUse/Write-Edit")
    data = json.load(sys.stdin)
    ti = data.get("tool_input") or {}
    path = ti.get("file_path") or ti.get("notebook_path") or ""
    if not path or not FROZEN_DIR.search(path) or not os.path.exists(path):
        sys.exit(0)

    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason":
            f"⚠ 正在覆盖【已存在的冻结交付文件】：\n  {path}\n\n"
            "CLAUDE.md：已交付目录及其中每个文件是那一轮的冻结记录,不编辑、不覆盖、不删除。\n"
            "分清是哪一种情况再继续：\n"
            "  · 新分析产生了新结果 ⇒ 开【新日期】的交付目录,别改这一份\n"
            "  · 交付前复核(未重新分析)⇒ 就地改是对的,但三处日期要一起重打\n"
            "  · 增量/补充轮 ⇒ 目录名要带 supplementary_\n"
            "先确认属于哪一种,再让用户放行。"}}, ensure_ascii=False))
    sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        try:
            open(LOG, "a").write(f"[guard_frozen_delivery] {type(e).__name__}: {e}\n")
        except Exception:
            pass
        sys.exit(0)
