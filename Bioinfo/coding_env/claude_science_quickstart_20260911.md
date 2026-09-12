# Claude Science — 启动与调用速查（远程服务器 + 本地浏览器）

**2026-09-11 实测于本机。** 只写「按顺序要敲什么」和「一定会咬人的五条」。
**完整排障表（8 种症状 → 原因 → 处置）不在这里**，在
`~/projects_2026M7/35_Try_of_Claude_Science/docs/P35_operations_runbook_0910.md` ——
**不要把那张表抄到本文**，同一份信息存两处必然漂移。

---

## §0 一句话：它是浏览器应用，没有"命令行提交任务"这回事

`claude-science` 的子命令只有 `serve / open / url / status / logs / stop / update / import / mcp-env-check`。
**`prompt` / `run` / `chat` / `ask` / `exec` / `session` 全部不存在**（2026-09-11 在 0.1.47 实测）。
⇒ **任务只能在浏览器里贴给它**；脚本、cron、agent 都无法代跑。

---

## §1 启动：三步，顺序不能换

```bash
# ① 在【服务器】起 daemon（已经在跑就跳过，用 status 确认）
PATH=$HOME/.local/claude-science-bin:$PATH claude-science status
PATH=$HOME/.local/claude-science-bin:$PATH claude-science serve --no-browser --detached --port 8000

# ② 在【你的笔记本】开隧道 —— 不做这步，浏览器必然 ERR_CONNECTION_REFUSED
ssh -L 8000:127.0.0.1:8000 -L 8001:127.0.0.1:8001 gao@us1

# ③ 在【服务器】取登录链接，粘进笔记本浏览器
PATH=$HOME/.local/claude-science-bin:$PATH claude-science url
```

登录页若卡在 claude.ai 回不来 ⇒ 选 **Paste code instead**。

## §2 调用：贴任务前先把边界写进去

**每个任务的 prompt 都应当自带这四件事**，不要指望 UI 的授权面板兜底：

| 要素 | 写法 |
| :--- | :---: |
| 输入 | 写**绝对路径**，并明说 `Read-only input:` |
| 输出 | `All output goes to <exploration 目录>. Versioned filenames.` |
| 禁止 | `Do not write anything to the input directory.` |
| 格式 | 图一律 `PDF for figures.`；要核对的结果**指定列名**存成 TSV |

**模板**（改路径即可用）：

```
Read-only input:
<绝对路径>

At the start of every step print:
  if (!exists(".step_n")) .step_n <- 0; .step_n <- .step_n + 1; .step_n

Task: <一句话说清要它做什么，以及"用什么手段做"——若要测它的内置能力，
必须明说 not by writing your own plotting/query code>

For anything a lookup returns nothing for, say so explicitly. Do not infer a
value from neighbouring data. "Not found" is a result; a plausible-looking
number is not.

Save your final answers as a TSV with these exact column names: <列名>

Do not write anything to the input directory. All output goes to <输出目录>.
Versioned filenames. PDF for figures.
```

> 那行 `.step_n` 是**持久 kernel 探针**：每步自增，daemon 一重启就归 1，藏不住。
> ⚠ 不要用 `Sys.getpid()` —— 它的沙箱里恒为 2，测不出东西。

## §3 收尾：两件必做

```bash
# ① 确认它没写进任何冻结目录（应当零命中）
find <交付目录> -newermt "$(date +%F)" | head

# ② 看它这次花了多少（单位＝美元，2026-09-11 复算证实）
python3 - <<'PY'
import sqlite3,glob,shutil,os,tempfile
src=glob.glob(os.path.expanduser("~/.claude-science/orgs/*/operon-cli.db"))[0]
d=tempfile.mkdtemp()                       # 连 WAL 复制读副本，不碰活库
for ext in ("","-wal","-shm"):
    if os.path.exists(src+ext): shutil.copy2(src+ext, d+"/operon-cli.db"+ext)
con=sqlite3.connect(f"file:{d}/operon-cli.db?mode=ro",uri=True)
for r in con.execute("""select date(created_at/1000,'unixepoch','localtime') d,
       count(*), sum(input_tokens), sum(output_tokens), round(sum(total_cost),2)
       from frames group by d order by d desc limit 5"""):
    print(f"  {r[0]}  frames={r[1]:<4} in={r[2] or 0:>12,} out={r[3] or 0:>8,} cost=${r[4] or 0}")
PY
```

⚠ **配额与 Claude Code CLI 共用同一个 seat、同一份周配额** —— 花在这里就花不在那里。

---

## §4 一定会咬人的五条

| # | 坑 | 症状 | 对策 |
| :--- | :---: | :---: | :---: |
| 1 | **shim PATH 前缀不能省** | 报 `bwrap too old` | 系统 bubblewrap 是 0.6.1 < 官方要求 0.8.0；`~/.local/claude-science-bin/` 里放的是 conda-forge 0.11.2 软链。**每条命令都加 `PATH=$HOME/.local/claude-science-bin:$PATH`** |
| 2 | **`-L` 必须写 `127.0.0.1`，不能写 `localhost`** | **交互图静默退化成静态快照**，不报错 | 服务器上 8000 同时听 IPv4/IPv6，**8001 只有 IPv4**；`localhost` 可能解析到 `::1` |
| 3 | **登录链接单次有效、约 3 分钟** | 显示已过期 | 重跑 `claude-science url`。**别让别人代测链接 —— 一 `curl` 就消耗掉了** |
| 4 | **daemon 会自己重启** | R/Python 会话里的变量突然不见 | 2026-09-10 一天内 3 次（2 次 kernel 崩 + 1 次自动升级 0.1.41→0.1.47）。⇒ **跨步骤状态一律落盘，不留在会话里** |
| 5 | **升级会搬动内置 skill 目录** | 硬编码路径失效 | 用 `ls -d ~/.claude-science/runtime/*/skills ~/.claude-science/orgs/*/skills` 现查 |

**判断「真在干活」而不只是「进程存在」**：`curl -s -o /dev/null -w '%{http_code}\n' localhost:8000`
返回 **401 是好事** —— 服务在应答，只是要求登录。

---

## §5 什么该给它、什么不该

| 给 | 不给 |
| :--- | :---: |
| 矩阵/变异表已经算出来之后的**探索、出图、查库、写 Methods** | 管线、调度、长任务、交付目录、客户邮件 |
| 已交付、已冻结的数据做**只读**小试 | 任何写权限进交付目录 |
| 剥离过答案的测试输入 | 答案底牌（核对用的真值表） |

⚠ **它那边没有我们的 hook**（破坏性命令闸门、交付物检查、回复自检一条都不生效）。
替代物是 skill：`~/.claude/skills/claude-science-guardrails/`，**每次会话开头让它读一遍**。

⚠ **蛋白序列外发**：AlphaFold2 / Boltz-2 默认把序列发到公共 ColabFold（`api.colabfold.com`）建 MSA，
**从本机直发、不经 Anthropic**。客户未公开序列必须自带 MSA 或关掉该 skill。

---

**相关**：
`~/projects_2026M7/35_Try_of_Claude_Science/docs/P35_operations_runbook_0910.md`（完整排障表）·
`P35_claude_science_one_pager_0911.md`（它是什么、值不值、实测用量）·
`P35_figure_style_vs_ours_0911.md`（它的出图 skill 与我们的取舍）
