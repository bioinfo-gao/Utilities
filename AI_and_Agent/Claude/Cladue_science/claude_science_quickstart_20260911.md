# Claude Science — 启动与调用速查（远程服务器 + 本地浏览器）

**2026-09-11 实测于本机。** 只写「按顺序要敲什么」和「一定会咬人的五条」。
**完整排障表（8 种症状 → 原因 → 处置）不在这里**，在同目录的
[`claude_science_full_evaluation_20260912.md`](claude_science_full_evaluation_20260912.md) **Part III** ——
**不要把那张表抄到本文**，同一份信息存两处必然漂移。
（⚠ 2026-09-12 路径变更：原指向 proj35 的 `P35_operations_runbook_0910.md`，该文已并入上面这份，不再更新。）

---

## §0 一句话：它是浏览器应用，没有"命令行提交任务"这回事

`claude-science` 的子命令只有 `serve / open / url / status / logs / stop / update / import / mcp-env-check`。
**`prompt` / `run` / `chat` / `ask` / `exec` / `session` 全部不存在**（2026-09-11 在 0.1.47 实测）。
⇒ **任务只能在浏览器里贴给它**；脚本、cron、agent 都无法代跑。

---

## §1 启动：顺序不能换

> ### ⚠ 先知道一件事：**daemon 本来就一直在跑，你多半只需要第 ② ③ 步**
>
> 实测（2026-09-12）：daemon 自 09-10 18:35 **连续运行 2 天**，`ppid=1` 已脱离终端 ——
> **关终端、断 SSH 都不会杀它**；账号 token 也**自动续期**（`.oauth-tokens/` 有 refresh journal）。
> 本机服务器已连续运行 **100 天**没重启过。
>
> ⇒ **每次真正要做的只有两件：重建 SSH 隧道 + 取一次性登录链接。**
> 前者可以一次配好永久免手敲（见 §1.1），后者是产品设计（单次有效 ~3 分钟），改不掉。
> ⚠ 唯一会让 daemon 消失的是**服务器重启** —— 本机**没有装 systemd 用户服务、`Linger=no`**，
> 那时要手动 `serve` 一次。完整分析见 [`claude_science_full_evaluation_20260912.md`](claude_science_full_evaluation_20260912.md) §3.4。

```bash
# ① 在【服务器】确认它在不在跑 —— 绝大多数时候已经在跑，直接跳到 ②
claude-science status

# ①b 只有【真的没在跑】时才需要这一条（注意那个 PATH 前缀，理由见下）
PATH=$HOME/.local/claude-science-bin:$PATH claude-science serve --no-browser --detached --port 8000

# ② 在【你的笔记本】开隧道 —— 不做这步，浏览器必然 ERR_CONNECTION_REFUSED
ssh -L 8000:127.0.0.1:8000 -L 8001:127.0.0.1:8001 gao@us1

# ③ 在【服务器】取登录链接，粘进笔记本浏览器
claude-science url
```

登录页若卡在 claude.ai 回不来 ⇒ 选 **Paste code instead**。

### §1.1 把隧道一次配好，别再手敲 `-L`

`~/.ssh/config` 加这一段（**本机目前没有任何相关配置**，所以每次都在手敲）：

```
Host us1
    HostName        <实际地址>
    User            gao
    LocalForward    8000 127.0.0.1:8000
    LocalForward    8001 127.0.0.1:8001
    ControlMaster   auto
    ControlPath     ~/.ssh/cm-%r@%h:%p
    ControlPersist  10m
    ServerAliveInterval 30
```

之后 `ssh us1` 自动带上两个转发。⚠ **目标必须写 `127.0.0.1` 不能写 `localhost`**，理由见 §4 第 2 条。

> ### ⚠ `PATH=...` 前缀只有 `serve` 需要，别的一律不要加（2026-09-11 更正）
>
> 本文初版把前缀加在三行上，是错的 —— 抄来的，没验。实测：
>
> | 命令                                          |    要前缀吗    |                                                                            为什么                                                                            |  |
> | :--- | :---: | :---: | :---: |
> | `serve`                                     |  **要**  | 它启动的 daemon**继承启动时的 PATH 并用一辈子**，之后每个代码沙箱都从那里取 `bwrap`。实测运行中的沙箱进程确实是 `~/.local/claude-science-bin/bwrap` |  |
> | `status` `url` `open` `stop` `logs` | **不要** |                      只是跟**已在跑的 daemon** 通过 socket 说话，根本不碰 bwrap。实测裸跑 `claude-science status` 正常返回 JSON                      |  |
>
> **为什么 `serve` 非要它**：系统 `/usr/bin/bwrap` 是 **0.6.1**，低于官方要求的 0.8.0；
> `~/.local/claude-science-bin/bwrap` 是指向 conda-forge **0.11.2** 的软链，而该目录
> **不在登录 shell 的 PATH 里**（`~/.profile` / `~/.bashrc` 都没写）。不加前缀，daemon 会拿到旧版。
>
> **想彻底免掉这个前缀**：把 shim 目录写进 `~/.profile`（`export PATH="$HOME/.local/claude-science-bin:$PATH"`），
> 之后 `serve` 也不用前缀。⚠ 代价是**所有 shell 的 `bwrap` 都变成 0.11.2** —— 影响面超出 Claude Science，
> **本机尚未采用**。一年也就 `serve` 几次，留着前缀其实更省事。

## §2 授权：粒度是「一个目录」，不是「一棵树」

**三条原则，比 prompt 里怎么写更重要 —— UI 的授权面板是唯一的硬边界，prompt 只是软约束。**

| # |                              原则                              |                                       怎么落地                                       |
| :--- | :---: | :---: |
| 1 |  **要给它的东西，先复制/切片到一个当日新建的专用目录**  |       绝不把项目根、`raw_data/`、交付目录整棵授权出去。切片本身就是一道过滤       |
| 2 |    **输入目录只读，且目录内不得混进「不该给的东西」**    | 答案底牌、凭据、客户原始材料、未剥离的注释 —— 只要在同一个目录里，只读授权照样能看 |
| 3 | **读写只给一个输出目录**：`exploration/<任务名>_MMDD/` | 交付目录、项目根、家目录**一律不给**。事后用 `find <交付目录> -newermt` 复核 |

**命名兜底（重要）**：不能给的文件，**文件名自己就要喊出来** ——
一律叫 `ANSWER_KEY_do_not_give_to_claude_science.<ext>`。
这样即使误授权了整个目录，在文件列表里也是一眼能看见的，而不是藏在第 7 个文件里。

**实例（2026-09-11 两个判据测试的实际授权）**：

| 任务           |                                                                          只读给它                                                                          |     读写给它     |                                        ⛔ 同目录里但绝不能给                                        |
| :--- | :---: | :---: | :---: |
| connector 测试 | `exploration/connector_test_input_0911/Sample_A.test30.vcf.gz`（30 个变异，已 `bcftools annotate -x` 剥掉 `gnomAD_AF`/`CLNSIG`/`CLNDN`/`CSQ`） | `exploration/` | `ANSWER_KEY_do_not_give_to_claude_science.tsv`、`truth_positions.tsv`、`test30_positions.tsv` |
| 原生渲染测试   |                             `exploration/render_test_input_0911/` 两个 BAM（各 58 KB，从 15 GB 全基因组 BAM 切出 6 kb 区间）                             | `exploration/` |                           `ANSWER_KEY_do_not_give_to_claude_science.md`                           |

⚠ **注意第二个例子的做法**：原 BAM 15 GB、含全基因组，直接授权等于把整个客户样本给它。
**切出 6 kb、58 KB 的区间**之后，既够用又把暴露面缩到了最小 —— **这是默认做法，不是特例。**

## §3 调用：贴任务前先把边界写进去

**每个任务的 prompt 都应当自带这四件事**，不要指望 UI 的授权面板兜底：

| 要素 |                                写法                                |
| :--- | :---: |
| 输入 |         写**绝对路径**，并明说 `Read-only input:`         |
| 输出 |  `All output goes to <exploration 目录>. Versioned filenames.`  |
| 禁止 |         `Do not write anything to the input directory.`         |
| 格式 | 图一律`PDF for figures.`；要核对的结果**指定列名**存成 TSV |

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

## §4 收尾：两件必做

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

## §5 一定会咬人的五条

| # |                             坑                             |                    症状                    |                                                                                                       对策                                                                                                       |
| :--- | :---: | :---: | :---: |
| 1 |           **`serve` 少了 shim PATH 前缀**           |     daemon 起不来，报`bwrap too old`     | 系统 bubblewrap 0.6.1 < 官方要求 0.8.0；shim 里是 conda-forge 0.11.2，而 shim 目录不在登录 shell 的 PATH 里。**只有 `serve` 要加前缀**，`status`/`url`/`open`/`stop` 一律不加（见 §1 的更正框） |
| 2 | **`-L` 必须写 `127.0.0.1`，不能写 `localhost`** | **交互图静默退化成静态快照**，不报错 |                                                            服务器上 8000 同时听 IPv4/IPv6，**8001 只有 IPv4**；`localhost` 可能解析到 `::1`                                                            |
| 3 |            **登录链接单次有效、约 3 分钟**            |                 显示已过期                 |                                                                重跑`claude-science url`。**别让别人代测链接 —— 一 `curl` 就消耗掉了**                                                                |
| 4 |                 **daemon 会自己重启**                 |       R/Python 会话里的变量突然不见       |                                               2026-09-10 一天内 3 次（2 次 kernel 崩 + 1 次自动升级 0.1.41→0.1.47）。⇒**跨步骤状态一律落盘，不留在会话里**                                               |
| 5 |             **升级会搬动内置 skill 目录**             |               硬编码路径失效               |                                                               用`ls -d ~/.claude-science/runtime/*/skills ~/.claude-science/orgs/*/skills` 现查                                                               |

**判断「真在干活」而不只是「进程存在」**：`curl -s -o /dev/null -w '%{http_code}\n' localhost:8000`
返回 **401 是好事** —— 服务在应答，只是要求登录。

---

## §6 什么该给它、什么不该

| 给                                                                |                  不给                  |
| :--- | :---: |
| 矩阵/变异表已经算出来之后的**探索、出图、查库、写 Methods** | 管线、调度、长任务、交付目录、客户邮件 |
| 已交付、已冻结的数据做**只读**小试                          |          任何写权限进交付目录          |
| 剥离过答案的测试输入                                              |       答案底牌（核对用的真值表）       |

⚠ **它那边没有我们的 hook**（破坏性命令闸门、交付物检查、回复自检一条都不生效）。
替代物是 skill：`~/.claude/skills/claude-science-guardrails/`，**每次会话开头让它读一遍**。

⚠ **蛋白序列外发**：AlphaFold2 / Boltz-2 默认把序列发到公共 ColabFold（`api.colabfold.com`）建 MSA，
**从本机直发、不经 Anthropic**。客户未公开序列必须自带 MSA 或关掉该 skill。

---

**相关**（均为当前有效版）：
[`claude_science_full_evaluation_20260912.md`](claude_science_full_evaluation_20260912.md)（详细版：完整排障表在 Part III、实测证据在 Part IV、用量在 Part V）·
[`claude_science_brief_20260912.md`](claude_science_brief_20260912.md)（提要：它是什么、值不值、什么时候用）·
[`~/Utilities/color_and_format/figure_style_claude_science_vs_ours_20260911.md`](../../../color_and_format/figure_style_claude_science_vs_ours_20260911.md)（它的出图 skill 与我们的取舍）
