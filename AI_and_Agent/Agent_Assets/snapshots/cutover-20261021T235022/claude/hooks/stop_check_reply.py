#!/usr/bin/env python3
"""Stop —— 我结束回合前,检查【我说的话】。

原名 check_state_claims.py,只查一条(外部状态断言)。现在它是回复层的统一入口,
判据全部落在 checks/check_reply.py 里(那份可以单独跑、单独测)。

为什么这些规则放在 Stop 而不是提问时注入上下文：
    注入是【每轮付费】,检查是【一次性零成本】。每轮都注入就又变回全量常驻了。

目前是 warn（只报警,不拦）。观察误报率后再决定要不要升成 decision=block。
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
LOG = os.path.join(HERE, "hook_errors.log")
sys.path.insert(0, os.path.join(HERE, "checks"))


MAX_BLOCK = 2          # 同一会话连拦几次仍不过就放行,防死循环
STATE = os.path.join(HERE, ".stop_block_state.json")


def _trace(tag):
    try:
        import datetime
        with open(os.path.join(HERE, "hook_calls.log"), "a") as fh:
            fh.write(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S}  {tag}\n")
    except Exception:
        pass


def _blocks(sid, inc=False, reset=False):
    """按 session 记连续拦截次数。检查一旦通过就清零。"""
    try:
        d = json.load(open(STATE)) if os.path.exists(STATE) else {}
    except Exception:
        d = {}
    if reset:
        d.pop(sid, None)
    elif inc:
        d[sid] = d.get(sid, 0) + 1
    try:
        json.dump(d, open(STATE, "w"))
    except Exception:
        pass
    return d.get(sid, 0)


def text_of(msg):
    c = msg.get("content")
    if isinstance(c, str):
        return c
    return "\n".join(b.get("text") or "" for b in (c or [])
                     if isinstance(b, dict) and b.get("type") == "text")


def is_real_user_turn(rec):
    """tool_result 也是 type=user —— 那不是用户回合,必须排除。"""
    if rec.get("type") != "user":
        return False
    c = (rec.get("message") or {}).get("content")
    if isinstance(c, str):
        return True
    return not any(isinstance(b, dict) and b.get("type") == "tool_result"
                   for b in (c or []))


def main():
    _trace("Stop")
    import check_reply

    data = json.load(sys.stdin)
    tp = data.get("transcript_path")
    if not tp or not os.path.exists(tp):
        sys.exit(0)

    recs = []
    for line in open(tp, errors="replace"):
        line = line.strip()
        if line:
            try:
                recs.append(json.loads(line))
            except Exception:
                pass

    # start  = 最后一个真实用户回合之后(check_reply 用,口径不动)
    # start2 = 再往前一个用户回合(check_table_transfer 用)。
    # 为什么必须跨两轮：表往往在【上一轮】回复里 —— 用户看完表才说"写成文档",
    # 文档在下一轮才落盘。只看一轮的话,那张表根本不在窗口内。
    bounds = [i for i in range(len(recs)) if is_real_user_turn(recs[i])]
    start = bounds[-1] + 1 if bounds else 0
    start2 = bounds[-2] + 1 if len(bounds) >= 2 else 0

    # 收【实际跑过的命令文本】,不是「跑没跑过」的布尔 ——
    # 判据要能分辨「跑的是不是这类回读」：说邮件却只跑了 git status 不算证据。
    said, commands = [], []
    for rec in recs[start:]:
        if rec.get("type") != "assistant":
            continue
        msg = rec.get("message") or {}
        said.append(text_of(msg))
        for b in msg.get("content") or []:
            if isinstance(b, dict) and b.get("type") == "tool_use" \
               and b.get("name") in ("Bash", "BashOutput"):
                cmd = (b.get("input") or {}).get("command") or ""
                if cmd:
                    commands.append(cmd)

    said2, md_written = [], []
    for rec in recs[start2:]:
        if rec.get("type") != "assistant":
            continue
        msg = rec.get("message") or {}
        said2.append(text_of(msg))
        for b in msg.get("content") or []:
            if isinstance(b, dict) and b.get("type") == "tool_use" \
               and b.get("name") in ("Write", "Edit", "NotebookEdit"):
                fp = (b.get("input") or {}).get("file_path") or ""
                if fp.lower().endswith(".md"):
                    md_written.append(fp)

    bad = check_reply.run("\n".join(said), commands)

    # 分诊层：词面匹配不上的表格行。**永远只警告** —— 判据是语义的,正则判不了,
    # 拿它 block 会拦住正确的文档(见 check_table_transfer 文件头的实测记录)。
    warns = []
    if md_written:
        try:
            import check_table_transfer
            warns = check_table_transfer.run(said2, md_written)
        except Exception as e:
            open(LOG, "a").write(f"[table_transfer] {type(e).__name__}: {e}\n")
    sid = data.get("session_id") or "default"
    n = _blocks(sid)

    if not bad:
        _blocks(sid, reset=True)         # 通过即清零,下一轮重新有 2 次拦截额度
        if warns:
            print(json.dumps({"systemMessage": "⚠ 逐行确认：\n"
                              + "\n".join(f"  · {w}" for w in warns)},
                             ensure_ascii=False))
        sys.exit(0)

    detail = "\n".join(f"  · {b}" for b in bad)
    if warns:
        detail += "\n  ⚠ 另有逐行确认项(不参与拦截)：\n" \
                  + "\n".join(f"    · {w}" for w in warns)

    # ── 升为 block(user directive 2026-08-30)──────────────────────
    # 但必须有防死循环闸：同一会话连续拦 MAX_BLOCK 次仍不通过就降级为警告,
    # 否则一条我满足不了的判据会把会话卡死 —— 那比漏检严重得多。
    if n < MAX_BLOCK:
        _blocks(sid, inc=True)
        print(json.dumps({
            "decision": "block",
            "reason": f"⛔ 回复自检未通过（第 {n + 1}/{MAX_BLOCK} 次拦截）：\n{detail}\n\n"
                      f"现在就去补：跑那条回读命令,把【命令输出】和结论写在同一次回复里;"
                      f"表格/语言类问题直接改回复。\n"
                      f"确实是误报 ⇒ 说明理由后照常结束(连续 {MAX_BLOCK} 次后自动放行),"
                      f"并把该判据改掉 —— 误报率高的闸门早晚会被关掉。"},
            ensure_ascii=False))
    else:
        print(json.dumps({"systemMessage":
            f"⚠ 回复自检仍有 {len(bad)} 项未过,但已连拦 {n} 次,放行以免卡死：\n{detail}"},
            ensure_ascii=False))
    sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        try:
            open(LOG, "a").write(f"[stop_check_reply] {type(e).__name__}: {e}\n")
        except Exception:
            pass
        sys.exit(0)
