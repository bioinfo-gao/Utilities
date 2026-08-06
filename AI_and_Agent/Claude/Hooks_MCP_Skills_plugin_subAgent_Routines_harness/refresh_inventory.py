#!/usr/bin/env python3
"""刷新 1_当前能力清单_INVENTORY.md 里**可以从本机配置扫出来的那一半**。

用法：
    python3 refresh_inventory.py            # 就地更新清单
    python3 refresh_inventory.py --print    # 只打印，不写文件

只重写 A 段（`<!-- AUTO:BEGIN -->` 与 `<!-- AUTO:END -->` 之间）。
B 段（内置 skill / 内置 subagent / harness 能力）**扫不出来** —— 那些来自
Claude Code 版本本身、只在会话里对模型可见，必须人工更新，所以放在标记之外，
本脚本一个字都不会碰。

安全：MCP 配置里只取 **服务器名 / 类型 / 命令 / env 的键名**，
**绝不输出任何 env 的值**（那里面是 Gmail app password 之类的凭据）。
"""

import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

HOME = Path.home()
CLAUDE = HOME / ".claude"
DOC = Path(__file__).resolve().parent / "1_当前能力清单_INVENTORY.md"
BEGIN, END = "<!-- AUTO:BEGIN -->", "<!-- AUTO:END -->"


def read_json(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return None


def skill_meta(skill_dir):
    """从 SKILL.md 的 frontmatter 里取 description 与是否仅手动调用。"""
    md = skill_dir / "SKILL.md"
    if not md.exists():
        return "(无 SKILL.md)", False
    text = md.read_text(encoding="utf-8", errors="replace")[:4000]
    m = re.search(r"^description:\s*(.+)$", text, re.M)
    desc = m.group(1).strip().strip('"') if m else ""
    manual = bool(re.search(r"^disable-model-invocation:\s*true", text, re.M))
    return desc, manual


def collect():
    out = []
    w = out.append
    w(f"> 本段由 `refresh_inventory.py` 自动扫描生成，**不要手改** —— "
      f"重新跑一遍脚本即可。扫描时间：{datetime.now():%Y-%m-%d %H:%M}")
    w("")

    # ---- 个人 skills ----
    sk = sorted(p for p in (CLAUDE / "skills").glob("*") if p.is_dir())
    w(f"### A1. 个人 skills（`~/.claude/skills/`）—— {len(sk)} 个")
    w("")
    w("| skill | 触发 | 一句话 |")
    w("| :--- | :---: | :--- |")
    for d in sk:
        desc, manual = skill_meta(d)
        desc = re.sub(r"\s+", " ", desc)[:88]
        w(f"| `/{d.name}` | {'仅手动' if manual else '模型可自动调用'} | {desc} |")
    w("")

    # ---- 插件 ----
    inst = read_json(CLAUDE / "plugins" / "installed_plugins.json") or {}
    mkts = read_json(CLAUDE / "plugins" / "known_marketplaces.json") or {}
    enabled = (read_json(CLAUDE / "settings.json") or {}).get("enabledPlugins", {})
    plugins = inst.get("plugins", {})
    w(f"### A2. 插件（plugin）—— 已装 {len(plugins)} 个；已知市场："
      f"{', '.join(mkts) if isinstance(mkts, dict) else mkts}")
    w("")
    w("| 插件 | 版本 | 启用 | 装在哪 | 带来什么 |")
    w("| :--- | :---: | :---: | :--- | :--- |")
    for name, entries in plugins.items():
        for e in entries:
            root = Path(e.get("installPath", ""))
            brings = []
            n_sk = len(list((root / "skills").glob("*"))) if (root / "skills").is_dir() else 0
            if n_sk:
                brings.append(f"{n_sk} 个 skill")
            if (root / "hooks" / "hooks.json").exists():
                hk = read_json(root / "hooks" / "hooks.json") or {}
                for ev in (hk.get("hooks") or {}):
                    brings.append(f"{ev} hook")
            if (root / "commands").is_dir():
                brings.append(f"{len(list((root / 'commands').glob('*')))} 个命令")
            w(f"| `{name}` | {e.get('version','?')} | "
              f"{'是' if enabled.get(name) else '否'} | `{e.get('scope','?')}` 级 | "
              f"{'、'.join(brings) or '—'} |")
    w("")
    for name, entries in plugins.items():
        for e in entries:
            root = Path(e.get("installPath", ""))
            sks = sorted(p.name for p in (root / "skills").glob("*") if p.is_dir())
            if sks:
                w(f"`{name}` 带的 skill（用 `{name.split('@')[0]}:<名字>` 调用）：")
                w("")
                w("　" + "、".join(f"`{s}`" for s in sks))
                w("")

    # ---- MCP ----
    w("### A3. MCP servers")
    w("")
    w("| 名称 | 类型 | 命令 / 端点 | 需要的 env 键 |")
    w("| :--- | :---: | :--- | :--- |")
    seen = set()
    for path in [HOME / ".claude.json", HOME / ".mcp.json", CLAUDE / "settings.json"]:
        d = read_json(path)
        if not isinstance(d, dict):
            continue
        scopes = [("", d)] + [(f" ({os.path.basename(k.rstrip('/')) or '/'})", v)
                              for k, v in (d.get("projects") or {}).items()
                              if isinstance(v, dict)]
        for tag, obj in scopes:
            for name, cfg in (obj.get("mcpServers") or {}).items():
                key = (name, tag)
                if key in seen:
                    continue
                seen.add(key)
                target = " ".join(
                    x for x in [cfg.get("command") or cfg.get("url", ""),
                                " ".join(cfg.get("args", []))] if x).strip()
                envk = ", ".join(cfg.get("env", {}).keys()) or "—"
                w(f"| `{name}`{tag} | {cfg.get('type','stdio')} | `{target}` | {envk} |")
    if not seen:
        w("| —（未配置） | | | |")
    w("")
    w("**只列 env 的键名，绝不落盘任何值** —— 那里面是凭据。")
    w("")

    # ---- hooks ----
    w("### A4. Hooks")
    w("")
    rows = []
    for f in ["settings.json", "settings.local.json"]:
        d = read_json(CLAUDE / f) or {}
        for ev, lst in (d.get("hooks") or {}).items():
            rows.append((f, ev, json.dumps(lst, ensure_ascii=False)[:70]))
    for name, entries in plugins.items():
        for e in entries:
            hk = read_json(Path(e.get("installPath", "")) / "hooks" / "hooks.json") or {}
            for ev, lst in (hk.get("hooks") or {}).items():
                for item in lst:
                    rows.append((f"plugin {name}", ev,
                                 f"matcher=`{item.get('matcher','*')}`"))
    if rows:
        w("| 来源 | 事件 | 内容 |")
        w("| :--- | :---: | :--- |")
        for r in rows:
            w(f"| {r[0]} | `{r[1]}` | {r[2]} |")
    else:
        w("（无）")
    w("")
    gh = HOME / "Utilities" / ".githooks"
    if gh.is_dir():
        w(f"另有 **git hooks**（与 Claude Code 无关，是 git 自己的）："
          f"`{gh}` -> {', '.join(p.name for p in gh.iterdir())}；"
          f"`Utilities` / `projects_2026M7` / `projects_2026H2` 三个仓库用 "
          f"`core.hooksPath .githooks` 指向**同一份三类拦截 hook**"
          f"（大文件 / 隐藏文件目录 / 密码密钥）—— 规则与处理方式见下方 **C 段**。")
        w("")

    # ---- 用户自定义 subagent / 命令 ----
    ag = CLAUDE / "agents"
    files = sorted(p.name for p in ag.glob("*.md")) if ag.is_dir() else []
    w(f"### A5. 用户自定义 subagent（`~/.claude/agents/*.md`）—— {len(files)} 个")
    w("")
    w("　" + ("、".join(f"`{f}`" for f in files) if files
              else "（无 —— 目前只用内置的几种，见 B2）"))
    w("")
    cmd = CLAUDE / "commands"
    cfiles = sorted(p.name for p in cmd.glob("*")) if cmd.is_dir() else []
    w(f"### A6. 用户自定义 slash 命令（`~/.claude/commands/`）—— {len(cfiles)} 个")
    w("")
    w("　" + ("、".join(f"`{f}`" for f in cfiles) if cfiles
              else "（无 —— 个人能力一律做成 skill，见 [[feedback_personal_skills_standard_format]]）"))
    w("")

    # ---- settings ----
    st = read_json(CLAUDE / "settings.json") or {}
    stl = read_json(CLAUDE / "settings.local.json") or {}
    w("### A7. settings 关键项")
    w("")
    w("| 项 | 值 |")
    w("| :--- | :--- |")
    w(f"| `model` | `{st.get('model','(未设)')}` |")
    w(f"| `theme` | `{st.get('theme','(未设)')}` |")
    w(f"| `permissions.defaultMode` | `{(st.get('permissions') or {}).get('defaultMode','(未设)')}` |")
    w(f"| `skipDangerousModePermissionPrompt` | `{st.get('skipDangerousModePermissionPrompt','(未设)')}` |")
    sl = st.get("statusLine") or {}
    w(f"| `statusLine` | {sl.get('type','—')}: `{sl.get('command','—')}` |")
    na = len((st.get("permissions") or {}).get("allow", []))
    nl = len((stl.get("permissions") or {}).get("allow", []))
    w(f"| 允许规则条数 | settings.json {na} 条 + settings.local.json {nl} 条 |")
    w("")
    return "\n".join(out)


def main():
    block = collect()
    if "--print" in sys.argv:
        print(block)
        return
    if not DOC.exists():
        sys.exit(f"找不到 {DOC} —— 先建清单再刷新")
    text = DOC.read_text(encoding="utf-8")
    if BEGIN not in text or END not in text:
        sys.exit(f"{DOC} 里没有 {BEGIN} / {END} 标记，拒绝改写")
    new = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END),
                 f"{BEGIN}\n\n{block}\n{END}", text, flags=re.S)
    DOC.write_text(new, encoding="utf-8")
    print(f"[OK] 已更新 {DOC} 的 A 段（B 段未动）")


if __name__ == "__main__":
    main()
