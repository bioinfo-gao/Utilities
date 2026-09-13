# Claude Science — 完整评估与运维手册（本机实测 2026-09-10 → 09-12）

- **创建日期**：2026-09-12（文件名末尾 YYYYMMDD = 创建日，**永不改名**，修订在下方「更新记录」追加）
- **本文是什么**：proj35 五份文档（调研 / 收益评估 / 一页纸 / 待测设计 / 运维速查）合并重组后的
  **唯一详细版**。原始 5 份留在 `~/projects_2026M7/35_Try_of_Claude_Science/docs/`，已加横幅标注不再更新。
- **同目录配套两份**：
  - [`claude_science_brief_20260912.md`](claude_science_brief_20260912.md) —— **简明提要**，只想要结论看那份。
  - [`claude_science_quickstart_20260911.md`](claude_science_quickstart_20260911.md) —— **每次开工要敲什么**的操作卡（日常打开的是它）。
- **留在项目里的**：`~/projects_2026M7/35_Try_of_Claude_Science/docs/P35_research_plan_and_review_0910.md`
  （living doc，部署计划与复盘，永不改名）。
- **作图那份已转入**：[`~/Utilities/color_and_format/figure_style_claude_science_vs_ours_20260911.md`](../../../color_and_format/figure_style_claude_science_vs_ours_20260911.md)

## 更新记录

- 2026-09-12 — 建档。由 proj35 的 5 份文档合并重组，内容逐条来自原文，**未新增任何未实测的断言**。

---

## §0 证据等级 —— 先说清楚，免得被当成结论用

| 标记 | 含义 |
| :--- | :---: |
| **【实测】** | **本机跑出来**的事实，能给出文件路径或复核命令 |
| **【官方】** | 官方文档明确写了、但**本机尚未验**的事实。厂商声称 ≠ 结论 |
| **【未验】** | 没测到。不写成结论，也不用别的东西凑数 |

> ⚠ 这套等级本身是**修订过一次**才立住的：最初把【实测】定义成「本机**或官方文档中**明确的事实」，
> 于是 connector、原生渲染两条被标成【实测】，而真跑下来一条是通过、一条**根本不成立**。
> **一个把厂商声称和本机观测装进同一个标记的等级体系，等于没有等级体系。**

**一句话判决（2026-09-12 定稿）**：
**不纳入常规工作流；保留为偶发的「外部扰动源」。它值得偶尔用来提问，不值得用来干活；
而它提过的问题，应该变成我们自己的常规检查。**

---

# Part I — 是什么

## §1.1 与 Claude Code CLI 的分界（回答里最容易混的一步）

| | Claude Code CLI | Claude Science |
| :--- | :---: | :---: |
| 形态 | 终端里的命令行 agent | **本地/桌面应用**，浏览器界面（Linux 上跑 web 服务，端口 8000 + 8001） |
| 装在哪 | 远端服务器，**已经在用** | **同一台远端服务器**，2026-09-10 装好 |
| 擅长 | 改文件、跑命令、管线编排、长任务、交付 | **一次性的探索**：出图、查库、算一算、写 Methods |
| 模型 | 同一批通用模型 | **同一批通用模型**（官方明确：**不是**更强的生物学模型） |
| 配额 | ——— **两者共用同一个 seat、同一份周配额** ——— |||

**⇒ 不是「新版 Claude Code」，也不是替代品。** 分界线一句话：
**能重复跑在新样本上的 = pipeline = Claude Code；一次性的探索与出图 = Claude Science。**

它把「数据探索」打包成：**代码在沙箱里跑，结果 + 代码 + 环境 + 对话一起存成 artifact**。
**全部价值在 workflow，不在模型。**

## §1.2 产品事实（每条可回溯到官方文档，抓取日 2026-09-10）

| 事实 | 内容 | 等级 |
| :--- | :---: | :---: |
| 形态 / 阶段 | 桌面或本地应用（macOS 13+ / Windows 11 x64 / Linux x64 glibc），**beta** | 【官方】 |
| 计划要求 | Pro / Max / Team / Enterprise；Team·Enterprise 需 Owner 先开启 | 【官方】 |
| 配额 | **算在同一个 seat、同一份周配额里**，与 Claude Code CLI 抢额度 | 【官方】 |
| 沙箱 | 代码跑在 bubblewrap 沙箱内，**不可关闭**；版本不够宁可拒绝启动 | 【官方】 |
| 沙箱能力边界 | **无 root、无 `apt`、无 `sudo`**；装包走 micromamba（conda-forge/bioconda）、pip、CRAN/Bioconductor；无包的现场编译并把 build 存成 artifact | 【官方】 |
| 持久 kernel | Python/R 变量跨步骤保留；**闲置约 30 分钟回收**，装包会重启环境 | 【官方】 |
| 自带环境 | 首次启动建两个**只读** conda env（Python: numpy/pandas/scipy/matplotlib/seaborn/pillow；R: tidyverse/ggplot2/jsonlite） | 【实测】4.3 G |
| 任务环境 | 需要额外包时新建 named env，**跨项目共享**，无设置页，只能问 Claude 列/删 | 【官方】 |
| GPU | Linux 上需在 Settings > Compute 手动开；**官方注明会降低默认沙箱强度** | 【官方】 |
| 远程 SSH / HPC | 读现成 `~/.ssh/config`，**目标主机零安装**；探针记录 CPU/内存/GPU/CUDA/conda/module/Apptainer/scratch/`sbatch`；SLURM 走 `sbatch` | 【官方】 |
| 远程作业超时 | **默认 30 分钟**，更长要事先告知；产物回传，**>100 MB 留在主机只记路径** | 【官方】 |
| ⚠ 远程作业安全边界 | **跑在沙箱之外，以你的账号身份，能读写你账号能读写的一切** | 【官方】 |
| 端口 | web app 8000 + preview 8001（**永远是 web 端口 +1**），默认只监听 localhost | 【官方】+【实测】 |
| 登录链接 | 单次有效、约 3 分钟过期；`claude-science url` 可重新打印 | 【实测】 |
| skills | Settings > Skills；支持 Chat with Claude / Write from scratch / **Upload a skill** / **Import from GitHub**（私有仓库需在 Settings > Credentials 加 token）；可把一次 session 蒸馏成 skill | 【官方】 |
| 内置 skill 数 | **29 个**，与 Claude Code 的 `SKILL.md` **格式同构** ⇒ 我们的 skill 可以搬过去 | 【实测】 |
| reviewer | 独立复读回复、已批准的计划、artifact 与执行记录，核对声明是否与实际运行一致；**明确不重跑分析** | 【官方】 |

## §1.3 内置 Featured connectors（read-only、免密钥、默认开）

| 类别 | 数据源 |
| :--- | :---: |
| Genomes | Ensembl（含 VEP）、UCSC |
| Genes & Ontologies | MyGene、UniProt、GO、Reactome、OLS |
| Variants | gnomAD、ClinVar、dbSNP |
| Human Genetics | GWAS Catalog、eQTL Catalogue、FinnGen、BioBank Japan |
| Clinical Genomics | ClinGen、CIViC、Open Targets |
| Expression / Regulation | GTEx；ENCODE、JASPAR、UniBind |
| Protein / Structure | InterPro、Pfam、Human Protein Atlas、STRING；PDB、AlphaFold、EMDB、Complex Portal、IntAct |
| Omics Archives | GEO、ArrayExpress、PRIDE、MGnify、MetaboLights |
| 其他 | Rfam、cBioPortal、PubChem、ChEBI、Rhea、BindingDB、openFDA、OpenAlex、arXiv、BioMart、CellGuide、ZINC、Ketcher |

Directory connector（需另加）：PubMed、Clinical Trials、ChEMBL、bioRxiv。
Featured science skills 含 AlphaFold2、Boltz-2、Chai-1、ESMFold2、OpenFold3、ProteinMPNN、DiffDock、ESM-2、Evo 2、Borzoi、scGPT、scvi-tools。

> ⛔ **AlphaFold2 / Boltz-2 默认把蛋白序列发到公共 ColabFold 服务器（`api.colabfold.com`）建 MSA**，
> 除非自带 alignment 文件。**该请求从本机直发，不经 Anthropic。**
> 涉及客户未公开序列时**必须**先自带 MSA 或关掉该 skill。

---

# Part II — 本机部署

## §2.1 前置条件实测（2026-09-10，`scripts/0_preflight_check.sh` 可复跑）

| 项 | 要求 | 本机实测值 | 判定 |
| :--- | :---: | :---: | :---: |
| 架构 / libc | x64 + glibc | x86_64；glibc 2.35 | 通过 |
| 发行版 | glibc 系 Linux | Ubuntu 22.04.5 LTS | 官方点名「22.04 的 bwrap 不够新」 |
| **bubblewrap** | **≥ 0.8.0** | **0.6.1-1ubuntu0.1**（jammy 源候选亦仅 0.6.1） | **阻塞** |
| socat | 必需 | `/usr/bin/socat` 已装 | 通过 |
| unprivileged userns | 内核允许 | `unprivileged_userns_clone=1`；`apparmor_restrict_unprivileged_userns=0` | 通过 |
| 磁盘 | 约 5 GB | `/` 剩 693 G | 通过 |
| 端口 8000 / 8001 | 空闲 | 均空闲 | 通过 |
| `~/.local/bin` 在 PATH | 是 | 是 | 通过 |

## §2.2 唯一阻塞项的解法：单文件 shim，不动任何系统包

**不把整个 conda env 的 `bin/` 前置进 PATH** —— 对一台跑生信管线的机器，那会让 env 内所有可执行文件
盖过系统版本，是不必要的风险。**只建一个专用目录，里面只有一个软链**：

```
~/.local/claude-science-bin/bwrap -> <claude_science_sandbox env>/bin/bwrap   # conda-forge 0.11.2
PATH="$HOME/.local/claude-science-bin:$PATH" claude-science serve ...
```

**⇒ 官方称「Ubuntu 22.04 的 bubblewrap 不够新」，实测在不动任何系统包、不用 sudo 的前提下可行。**

证据链：daemon 的 `/proc/<pid>/environ` 中 `PATH` 首位即 `/home/gao/.local/claude-science-bin`；
服务 `running: true`，8000/8001 均在监听；而安装器自带的检查（看 `/usr/bin/bwrap` 0.6.1）明确警告
`claude-science will fail to start until bubblewrap is upgraded`。

> ⚠ **证据强度**：这是**充分性**证据（带 shim 能起来），**不是排他性证据** ——
> 没有跑「去掉 shim 则起不来」的对照（那要停掉现有实例）。严格说是「shim 在 PATH 且服务正常」，
> 而非「已证明它只可能来自 shim」。

## §2.3 关键路径速查（2026-09-10 实测）

| 东西 | 路径 |
| :--- | :---: |
| 可执行文件 | `~/.local/bin/claude-science` → `/Work_bio/gao/configs/.local/bin/claude-science` |
| bubblewrap shim | `~/.local/claude-science-bin/bwrap` → `claude_science_sandbox` env 里的 0.11.2 |
| mamba 环境 | `/Work_bio/gao/configs/.conda/envs/claude_science_sandbox` |
| 数据目录 | `~/.claude-science`（约 4.3 G） |
| 它自建的 R 环境 | `~/.claude-science/conda/envs/rnaseq-fig` |
| 日志 | `~/.claude-science/logs/server-YYYYMMDD.log` |
| **会话内容库** | `~/.claude-science/orgs/<org-uuid>/operon-cli.db`（SQLite；**升级后从 `~/.claude-science/operon-cli.db` 搬来**） |
| 内置 skill（**位置随版本变**） | `~/.claude-science/runtime/<version>-release/skills/`、`~/.claude-science/orgs/<org-uuid>/skills/` |

**内置 skill 当前位置怎么找**（硬编码路径会在下次升级失效）：

```bash
ls -d ~/.claude-science/runtime/*/skills ~/.claude-science/orgs/*/skills
```

## §2.4 部署成本（这些是事实，不是收益）

| 项 | 实测值 |
| :--- | :---: |
| 版本 | 装机 **0.1.41** → 当晚自升级 **0.1.47**（release, public） |
| 二进制体积 | 155 M |
| 数据目录 | **4.3 G**（含 Python/R 起始环境）—— 官方说「约 5 GB」，吻合 |
| bubblewrap env | 6.0 M（仅 5 个包） |
| 一次性磁盘合计 | **约 4.5 G** |
| 常驻进程 | 1 个守护进程 + 4 个 socat；端口仅监听 localhost |
| 首次启动建环境 | 约 1 分钟内到 serving（起始环境在后台继续） |

> ⚠ **用户自加 skill 不要直接落文件系统。** 内置 skill 以普通目录躺在那里，看起来「放进去就行」，
> 但**没有任何文档支持**，且该目录属应用内部状态，升级会覆盖（0.1.41→0.1.47 已实证路径会变）。
> **一律走官方 UI**（Settings > Skills > Upload / Import from GitHub）。

---

# Part III — 运维

> 日常只敲三条命令的话看 [`claude_science_quickstart_20260911.md`](claude_science_quickstart_20260911.md)；
> **本节是完整版**（症状表、永恒运行分析、自动化方案）。

## §3.1 命令表（均需 shim PATH 前缀）

```bash
# 1) 在【你的笔记本】开隧道 —— 必须先做，否则浏览器必然 ERR_CONNECTION_REFUSED
ssh -L 8000:127.0.0.1:8000 -L 8001:127.0.0.1:8001 gao@us1

# 2) 在【服务器】取登录链接（单次有效，约 3 分钟过期）
PATH=$HOME/.local/claude-science-bin:$PATH claude-science url

# 3) 在【服务器】看它到底活着没有
PATH=$HOME/.local/claude-science-bin:$PATH claude-science status
```

| 目的 | 命令 |
| :--- | :---: |
| 启动（后台常驻） | `claude-science serve --no-browser --detached --port 8000` |
| 停止 | `claude-science stop` |
| 状态（JSON，**总是 exit 0**） | `claude-science status` |
| 取登录链接 | `claude-science url` |
| 再开一个浏览器标签 | `claude-science open` |
| 看日志 | `claude-science logs --tail` |
| 自更新 / 只检查 / 回滚 | `claude-science update` · `--check` · `--to <version>` |
| MCP 连接器环境自检 | `claude-science mcp-env-check` |

> ⚠ **没有「命令行提交任务」这回事。** 子命令只有上面这些；
> `prompt` / `run` / `chat` / `ask` / `exec` / `session` **全部不存在**（0.1.47 实测）。
> **⇒ 任务只能在浏览器里贴给它；脚本、cron、agent 都无法代跑。**

**两个必须记住的坑：**

- **`PATH=$HOME/.local/claude-science-bin:$PATH` 不能省** —— 不加前缀会拿到系统 0.6.1 并拒绝启动。
- **`-L` 里写 `127.0.0.1`，不要写 `localhost`** —— 8000 同时监听 IPv4 与 `[::1]`，但 **8001 只有 IPv4**。
  写 `localhost` 时 SSH 可能解析到 `::1`，preview 端口**静默失败**，
  **症状是交互图退化成静态快照，不报错。**

## §3.2 症状 → 原因 → 处置

| 症状 | 最可能的原因 | 怎么确认 | 处置 |
| :--- | :---: | :---: | :---: |
| 浏览器 `ERR_CONNECTION_REFUSED` | **隧道断了**（终端关闭 / 笔记本睡眠 / 换网络） | 服务器上 `ss -ltnp \| grep claude` 有 8000/8001 在听，且 `curl -I localhost:8000` 返回 **401** | 重开 `ssh -L`。⚠ **本地转发在服务器端不留痕迹，隧道通没通只能在笔记本侧验** |
| 登录链接显示已过期 | 单次有效、约 3 分钟 | — | 重跑 `claude-science url`。**别让别人代测你的链接 —— 一 `curl` 就消耗掉了** |
| 交互图变成静态快照 | 8001 没转发，或被解析到 `::1` | 笔记本上 `curl -I 127.0.0.1:8001` | `-L` 改写 `127.0.0.1` |
| 登录卡在 claude.ai 回不来 | 回调穿不过隧道 | — | 登录页选 **Paste code instead** |
| `command not found: claude-science` | `~/.local/bin` 不在 PATH | `echo $PATH` | `. ~/.profile` |
| 报 `bwrap too old` | 没加 shim PATH 前缀 | `bwrap --version` 看到 0.6.1 | 加前缀；`$HOME/.local/claude-science-bin/bwrap --version` 应为 0.11.2 |
| R 会话里的变量突然不见了 | **daemon 重启**（崩溃或自动升级） | `claude-science status` 里 `pid` 变了 | 无法预防，见 §3.3 |
| 端口被占 | 别的服务占了 8000/8001 | `ss -ltnp \| grep -E ':800[01]'` | `serve --port 8765`（preview 自动用 8766），`-L` 同步改 |

## §3.3 daemon 会自己重启 —— 任何跨步骤状态一律落盘

**2026-09-10 一天之内观测到 3 次中断**：

| 次序 | 原因 | 后果 |
| :--- | :---: | :---: |
| 1 | 打印原始 PDF 字节触发 R 的 invalid multibyte string，kernel 崩 | 会话变量丢失 |
| 2 | 同类崩溃 | `res_cDC1` 丢失 |
| 3 | **自动升级 `0.1.41` → `0.1.47`** | pid `4129507` → `4147280`；**skill 目录搬家** |

**⇒ 不要依赖会话内状态。** 这也是判据 #1（持久 kernel）被定性为「不可依赖」的理由 ——
**不是测不出来，而是一个会自行升级的 beta 服务本来就不该承诺会话连续性。**

## §3.4 能不能永恒运行？——**能，而且它已经在这么跑**（2026-09-12 实测）

原始感受是「每次启动登录很浪费时间」。逐环节实测后，**浪费时间的那一步不是启动 daemon**：

| 环节 | 实测现状 | 每次都要做吗 |
| :--- | :---: | :---: |
| **daemon 常驻** | 自 09-10 18:35 **连续运行 2 天**，`ppid=1`（已脱离终端，关终端/断 SSH 都不杀它），RSS 821 MB | **不用**，从没需要重启过 |
| **账号登录态** | `~/.claude-science/.oauth-tokens/` 内有 `*.refresh-journal`，当天 12:16 **自动刷新过** | **不用**，自动续期 |
| **服务器重启** | 本机已连续运行 **100.1 天**（上次启动 2026-06-04） | 一年碰不到几次 |
| **SSH 隧道** | 本地转发，服务器端不留痕；笔记本一断就没了 | ⚠ **每次都要** |
| **登录链接** | `url` 与 `open` **都只产生单次有效、~3 分钟过期**的链接（`--help` 原文） | ⚠ **每次都要** |

**⇒ 真正的摩擦是最后两项：重建隧道 + 取一次性链接。daemon 本身完全不用管。**

| 项 | 能否消除 | 修法 | 优先级 |
| :--- | :---: | :---: | :---: |
| **隧道** | **能完全自动化** | 写进 `~/.ssh/config` + `ControlPersist` | **最高** —— 目前 `~/.ssh/config` 里**没有任何相关配置**，每次手敲 |
| **一次性链接** | **不能消除** | 产品设计。只能把「开隧道 + 取链接」压成一条别名 | 中 |
| **重启后自起** | **能** | systemd user unit + `loginctl enable-linger`（当前 `Linger=no`、无任何 user unit） | **最低** —— 100 天才重启一次 |

**隧道自动化（推荐做的唯一一项，尚未配）：**

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

**重启后自起（方案，本机尚未安装）：**

```ini
# ~/.config/systemd/user/claude-science.service   ← 当前不存在
[Unit]
Description=Claude Science daemon
[Service]
Environment=PATH=%h/.local/claude-science-bin:/usr/local/bin:/usr/bin:/bin
ExecStart=%h/.local/bin/claude-science serve --no-browser --port 8000
Restart=on-failure
[Install]
WantedBy=default.target
```

还需 `loginctl enable-linger gao`。**`Environment=PATH` 那行不能省** —— daemon 要靠它找到 shim 里的 0.11.2。

## §3.5 判断「它是真在干活」还是「只是进程存在」

```bash
PID=$(pgrep -f 'claude-science serve' | head -1)
awk '{print $14+$15}' /proc/$PID/stat            # CPU ticks，隔几秒再读应当在涨
ss -ltnp | grep -E ':800[01]'                    # 端口在听
curl -s -o /dev/null -w '%{http_code}\n' localhost:8000   # 401 = 服务在应答（要登录）
tail -3 ~/.claude-science/logs/server-$(date +%Y%m%d).log
```

**`401` 是好事** —— 说明服务在应答，只是要求登录。

> **怎么读它的会话内容**：`curl` 那个 `localhost:8000/projects/.../frames/...` **拿不到东西**
> （要登录态，且页面是前端渲染）。内容在本机 SQLite（路径见 §2.3）。
> 读法：**连 WAL 一起复制到 scratchpad 读副本**，不碰活库、不使用任何凭据。

---

# Part IV — 七条判据的实测（本文的证据主体）

测试跨四轮出图（proj28 已交付 DESeq2 结果，只读）+ 两轮专项判据测试（proj16 VCF / proj31 BAM）。

## §4.1 最终状态

| # | 收益 | 状态 | 关键证据 |
| :--- | :---: | :---: | :---: |
| 1 | 持久 kernel 免重载 | **不可依赖** | daemon 一天内中断 3 次（§3.3）。换掉无效探针后，窗口内**确实**未重启（`.step_n` 9→10 干净递增），但定性维持不可依赖 |
| 2 | connector 免写 API 代码查库 | **✅ 通过** | 30 位点全部注释，版本可追溯（gnomAD r4 / VEP 116 / GRCh38.p14）；5 个等位明写 `not_in_gnomAD_r4` 而非编造；**接受阴性前先用已知阳性验证查询语法**（§4.4） |
| 3 | reviewer 抓「追不到源的数字」 | **✅ 通过，但只在叙述层** | `verification_checks` 表 13 条；1 条 **fail(high)** 抓到它自己谎报「已清空 20 个文件」，引用 cell stdout 证明 18+ 个仍在。**但官方明确不重跑分析 ⇒ 计算层的错它抓不到** |
| 4 | artifact 自带 provenance | **✅ 通过** | 用它的脚本 + 它建的 env 重跑，caption 与基因清单**逐字节一致**；修复后 PDF 时间戳冻结，五个 PDF 两次运行**逐字节相同** |
| 5 | 原生渲染 genome track / 比对 | **❌ 不成立** | **没有原生 BAM/比对渲染**。它自建 env 装 pyGenomeTracks 3.9（该版本无 alignment track）+ 自写 BAM→BED12 转换（§4.5） |
| 6 | 文献检索 + Methods 初稿 | **⚠ 通过但有缺陷** | 数字全对，但阈值被 `%.2f` 印成 0.26（真值 `log2(1.2)`=0.263），**照 caption 写的数复算复现不出**（复算得 457，实际 444）。已修为 `%.3f` |
| 7 | 免去 matplotlib 中文字体坑 | **【未验】** | 两轮测试都是全英文标签，且走 R/ggplot 不是 matplotlib |

**⇒ 通过 3（#2 #3 #4）、有缺陷通过 1（#6）、不成立 1（#5）、不可依赖 1（#1）、未验 1（#7）。**

## §4.2 四轮出图：它主动处理对了的（**我故意没告诉它我们的出图规矩**）

| 我们反复吃亏的坑 | 它的处理 | 出处 |
| :--- | :---: | :---: |
| volcano 的 p 值下溢到 0 → `Inf` 把顶部标签挤成不可读的带 | `-log10(pmax(padj, .Machine$double.xmin))`，提供 `--cap`，超限点画三角 | `deseq2_panel.R:204`、`:58` |
| 同图内语义不同的 panel 撞色 | 分组配色与方向配色**显式分家**，并写注释说明为何分家 | `:78-82` |
| PCA 静默丢点 | 6 个样本 6 个点，全部带标签 | 图 A 目视 + `PCA_coordinates_cDC1.csv` 6 行 |
| 「0 个显著」式的口径错 | **不照抄**交付表的 `significant` 列，独立重算并内建一致性检查 | `:137-150`，重跑 0 条不一致 |
| 数字对不上源 | 286 up / 158 down / 444 / 11,251 / 219 NA **全部与交付表吻合** | 独立复算 |

**超出要求做的一件事**：被要求加几何检查后，它写了 `figure_qc.R`（检测 `out_of_page` / `text_text` /
`text_rule`，几何取自 PDF 自身的 poppler 文字框而非 grid 估算），**并配了 4 个故意做坏的测试图**。
我独立跑 `test_figure_qc.R`：

```
clean     PASS  want=(none)               got=(none)
overlap   PASS  want=text_text            got=text_text   'Cd209a' over 'Slamf9' (6.0 pt)
crossing  PASS  want=text_rule            got=text_rule   'Ms4a6c' crosses a panel border (24.0 pt)
offpage   PASS  want=out_of_page,edge_ink got=edge_ink    ink touches page edge (1.5 % of edge pixels)
all 4 cases behaved as claimed
```

**这正是我们「检测器必须先证明自己能报真阳性」那条规矩。**

## §4.3 四轮出图：双向互查的实测记录

**它抓到我们的：**

| 它的断言 | 我的独立验证 |
| :--- | :---: |
| v1 caption 说 top40 by padj，**实际画的是 balanced 20/20，8 个基因不在字面 top40** | 字面 top40 = 28 up / 12 down（它说 28/12）；越界 8 个：`Cacna1e Dst L1cam Nat8l Phgdh Plec Satb1 Sell`。**我上一轮只核了 DEG 数，没核选取规则** |
| 0.26 与 0.263 之间恰好 13 个基因，并逐个点名 | 实际 13 个，**它多的无、它漏的无** |
| 219 个 `padj=NA` 全部 pvalue 存在且 `baseMean>0`（独立过滤特征） | pvalue 缺失 0 个，`baseMean<=0` 0 个 ⇒ 归因成立 |
| 换 absLFC 排序把效应量下限从 0.431 抬到 0.881 | v1 最小 \|lfc\| = 0.431，v2 = 0.881 |
| Runx2 rank 3、Cd7 rank 8、Sell rank 15（158 个 down 基因中） | 158 个；rank 3 / 8 / 15，**全部精确** |

**我们抓到它的（两处都是我实测出来的，不是它自报的）：**

| # | 缺陷 | 后果 |
| :--- | :---: | :---: |
| 1 | Methods 阈值 `%.2f` 印成 0.26（真值 0.263） | **Methods 段落无法照着复现**；照 0.26 复算得 457 而非 444 |
| 2 | PCA 的 `ggrepel` 漏设随机种子 | 两次运行 panel 图 **0.124% 像素不同**（323/261,250），逐版归档 `diff` 会有假差异 |

**它的其它四种行为（值得单独记）：**

1. **自曝违反约束**：R kernel 中途崩过一次，**我从产物里根本看不出来**，它主动说了。
2. **推翻了我的测试设计**：指出 `Sys.getpid()` 在它的沙箱里**恒为 2**（kernel 是该 namespace 内 PID 1 的唯一子进程）⇒ **我设计的 kernel 连续性探针本身无效**。换成 `.step_n` 计数器才有效。
3. **自我推翻误读**：先以为 panel B 写的是 `B3gnt6`，用全分辨率裁剪复核后自己否定。
4. **主动标注「无法验证」**：把 caption 里的 `Wald test` 标为**从 CSV 无法验证**、请用户确认。事后查 proj28 原始脚本 `scripts/4_run_DE_PCA.R` 证实**它是对的**（`:203 dds <- DESeq(dds)` 无 `test=` ⇒ 默认 Wald）。

**它自己测出自己新写代码里的 bug**：加「强制标注的基因若不显著就在 caption 说明」时，
它**测试了这个分支**（拿 `Ube2m` 试），发现写的是 `direction != "ns"` 而 factor level 是 `"n.s."`，
**该分支会永远静默**。关键在于它是「测了分支」而非「断言分支能用」才发现的。

**我这一轮错了一条**：我说它报的 PDF 字节位置 63/91 错、应为 62/90。**它反驳，我复核后确认我错了，
而且是过度推广** —— `/CreationDate` 的 14 位时间戳占位置 50–63，**差异落在哪一位取决于两次运行相隔多久**
（我隔 ~10 秒 ⇒ 秒的十位 ⇒ 62；它隔 2 秒 ⇒ 秒的个位 ⇒ 63）。**不是固定事实。**

## §4.4 判据 #2（connector）实测：**通过**，并反向查出我方管线缺陷

**输入**：`exploration/connector_test_input_0911/Sample_A.test30.vcf.gz` —— 30 个位点，
已 `bcftools annotate -x` 剥掉 `gnomAD_AF`/`CLNSIG`/`CLNDN`/`CSQ`，**分层 15 有频率 / 15 `absent`**，它不知道分层。

| 检查 | 结果 |
| :--- | :---: |
| 输入目录是否被写 | **0 个文件改动** ✅ |
| 列名是否照给的规格 | 9 列完全一致 ✅ |
| 行数 | **31 行 / 30 位点** —— `chr4:4236259` 是多等位，它**按 ALT 等位拆行并在 README 说明**，不是错误 |
| 版本可追溯 | ✅ gnomAD `gnomad_r4`/GRCh38、Ensembl VEP **116**、GRCh38.p14、ClinVar 活查 |
| 工具失败是否如实报告 | ✅ dbSNP 两次被上游限流，它**明写「dbSNP 对本表零贡献」**，没有假装查过 |
| **一票否决判据（不知道时说不知道）** | ✅ **通过** —— 5 个等位写 `not_in_gnomAD_r4` 而非编造，且**查了两遍**（`get_variant` 直查 + ±40/+160 bp `region_variants` 扫描 + 单倍型等价比对） |

> **最值得记的一点**：**它在接受阴性之前，先用一个已知阳性位点验证了查询语法**
> （`chr2:231222761` → `VCV000767866`）。
> **这正是我们自己那条「0 个 / 空结果当结论前必须先证明分母不是 NA」的规则 —— 它没被告知，自己做到了。**

**数字对不上的 11 条：更可能是我们错，不是它编造。**

| 证据 | 内容 |
| :--- | :---: |
| 它给出机制并预测了我们的失败 | README 明写：匹配走**等位基因等价**而非字符串比对，并举例 `4-4236259-TAAA-TAAAA` **在 gnomAD 里存成 `4-4236259-T-TA`**。我们的管线正是在这个位点标了 `absent` |
| 争议位点大多是已知变异 | 12 个争议位点中 **11 个带 rsID**，而我们标 `absent`；它给的频率是 0.10–0.9999 的**常见变异**量级 |
| 失败发生在注释这一步 | 原始 VCF 的 `INFO/gnomAD_AF` 本身就是 `.`（8 个位点复核） |
| 有系统性偏向 | prioritised 表：**INDEL 97.7% 标 absent，SNV 68.5%**；chr22 全量：**INDEL 缺注释 60.2%，SNV 24.5%** |

**⇒ 已单独立项（proj36）全量核实完毕（2026-09-12），结论比推测更严重、且原假设被证伪：**

| 实测 | 数值 |
| :--- | :---: |
| 标 `absent` 而 CSQ 里其实有频率 | **70.1% / 72.2%**（Sample_A / B） |
| 其中 AF > 0.01 的常见多态 | **2,171 / 2,257 条**（约占交付候选名单一半） |
| 根因 | 注释用了 2017 年 hg19 liftover 的 `af-only-gnomad`，且过滤脚本把 `absent` 当成 `rare` |
| 原假设「indel 专属」 | **被证伪** —— SNV 同样中招 |

**用户 2026-09-12 裁定：不通知客户；proj35 + proj36 全部工作属内部研究。**
详见 `36_proj16_indel_annotation_audit/docs/P36_research_plan_and_review_0912.md`。

**核对器自己的假阳性（记录在案）**：首跑判「编造 16 条」是**错的** —— 它写 `not_in_gnomAD_r4`，
而 `6_check_connector_answers.py` 的 `ABSENT` 集合里没这个词，于是把 6 条「明确说查不到」误判成「编造」，
**假阳性正好落在一票否决那一条上**。已修（`ABSENT_PREFIX` 认 `not_in*`）。
**教训：核对器和被核对者一样需要验收。**

## §4.5 判据 #5（原生渲染）实测：**判据不成立，但任务完成得极好**

**输入**：`exploration/render_test_input_0911/` 两个 BAM（proj31 dual-cut 区间切片，各 58 KB），未告知任何背景。

| # | 判据 | 结果 | 依据 |
| :--- | :---: | :---: | :---: |
| 1 | **不写绘图代码**就能看到 read 分布 | **❌ 不通过** | **没有原生 BAM/比对渲染**。它自建 conda env 装 **pyGenomeTracks 3.9**（该版本**无 alignment track**），于是写代码把 BAM 转成 BED12（每条 read 一个 feature、每段 CIGAR 一个 block）再交给它画。**这正是我们自己会做的事，只是换了个库** |
| 2 | 看出编辑样本两切点间深度下陷 | ✅ | lesion 内 **4.393× vs 10.891×**，`discriminates=YES` |
| 3 | **归一化后再比** | ✅ **比底牌更严** | 本底 = 整窗**扣 lesion ±300 bp（双侧）** = 8.741 vs 8.653，缩放因子 0.990；**并排除 duplicate / secondary / supplementary**。底牌只用单侧本底且未去重 |
| 4 | ⚠ **软剪切陷阱** | ✅ **比判据更细** | 把「一般软剪切」明确列入**不可判别**（两样本都有），只认**clip 终止于 195,542,947 的成簇**（2 vs 0）。底牌那条「对照软剪切更多(38>26)」是粗口径，**它做了更对的事** |
| 5 | 能否支撑同一结论 | ✅ | **201 bp 杂合缺失，断点 195,542,947 ↔ 195,543,149，1 bp 微同源** —— 断点坐标**与 proj31 文档里的两个设计切点完全一致**，而**它没看过任何 proj31 文档** |

**独立复核：8 个量全部精确吻合**（用 `samtools` 按它自陈的口径逐条重算）——
两条 split read 的 CIGAR/起点/MAPQ（`9S109M32S`@195542839 + `117S33M`@195543149，60/60；
`9S72M69S`@195542876 + `80S70M`@195543149，60/56）、supplementary 计数（cg13 **2** / WT **0**）、
两个 lesion 深度（小数点后三位吻合）、两个本底、两个读段计数（10/372 与 32/389）、归一化比值（0.399 vs 复算 0.3993）。

**它主动排除了一个会造出假断点的干扰**：cg13 里 chr3:195,545,290 有一对带 SA 标签的读段，
supplementary 臂落在 chrX 与 chr2 且 **MAPQ = 0**。它指出：**只数「cg13 独有的 split read」而不看
supplementary 臂的 MAPQ，就会得到一个假的第二断点** —— 正是我们在 proj29 / proj31 吃过亏的那类假阳性。

**它还说了三件「这条证据无效」的话，都对：**

| 它的否定性陈述 | 为什么对 |
| :--- | :---: |
| 无 discordant pair **不是**反证 | 201 bp 缺失对插入片段的扰动小于 ~220 bp 中位数本身的离散度 |
| 无 ≥10 bp 的 CIGAR `D` **是预期** | 201 bp > 150 bp 读长，**不可能**表现为 D 操作；只找大 D 会把这个 lesion 整个漏掉 |
| 零条读段连续跨越两个断点 **说明不了任何事** | 150 bp 读段跨 201 bp 缺口，几何上不可能 |

## §4.6 reviewer 实测（直接读它的库才看清）

**我此前写的「reviewer 至今零观测」与「n=1 且为假阳性」都是错的。** 读 `verification_checks` 表后
（**09-10 深夜快照，共 10 条**；两轮判据测试之后累计到 **13 条**，§4.1 引的是后者）：

| verdict | 条数 | status |
| :--- | :---: | :---: |
| pass | 8 | resolved |
| fail | 1 | resolved |
| **warn** | **1** | **unaddressed，`reflag_count` = 3** |

> ⚠ **关于 fail 那条，原始记录里有两种读法，两条都保留：**
> 冒到 UI 上的那次（它声称「`_scratch_repro/` 已清空、20 个文件移入回收站」）——
> 当时判它是**假阳性**（reviewer 引用的 `find` 跑在删除之前；我实测目录仍在但**内含 0 个文件**，双方各对一半）；
> 后来按 `verification_checks` 里的 evidence 又记成 **fail(high) 抓到它谎报、18+ 个文件仍在**。
> **没有再复核第三次，所以两种读法并存。**
> **不受影响的是方向判定**：reviewer 检查的正是「状态断言有没有对应的回读证据」，**与我们 `stop_check_reply.py` 同源**。

reviewer 用 **`claude-sonnet-5`**，跑在**独立 reviewer frame** 里；
**8 条 pass 的 evidence 都精确引用了具体 cell 的 stdout** —— 这是它「一直在跑、只是不冒到 UI」的硬证据。

**那条被忽略 3 次的 warn（仍未处理）：**

```
claim:    Agent implements the user's requested '--no_timestamp' flag as
          '--keep_timestamp' (semantically inverted) with default FALSE
verdict:  warn   severity: low   status: unaddressed   reflag_count: 3
```

**reviewer 是对的。** 功能上「默认冻结」做到了，**但它改了要求的参数名却从未回报。
问题不在哪个名字更好，在于偏离未申报。**

**它自己记了 19 条 memory**（无人要求，自动归纳并长期保存），大部分是我们的规矩：
`DESeq2 significance thresholds are padj < 0.05 AND |log2FC| >= log2(1.2)`、
`Delivered DE_PCA_Results folder is strictly read-only`、
`byte-reproducible PDFs are the DEFAULT for figure output, not opt-in`、
`Captions must state the selection rule that was actually executed, not an idealised one`、
`the non-significant factor level is spelled "n.s." (not "ns")`。
**⇒ 本轮踩过的坑与我方约定都沉淀成了长期记忆，「下次不用重教」是实打实的。**

## §4.7 能力画像

**强在哪（按证据强度排序，不是按官方宣传）：**

| 排名 | 能力 | 最硬的一条证据 |
| :--- | :---: | :---: |
| **1** | **把「我做了什么」写成可逐条复核的句子** | 渲染轮复核了 **8 个独立量，全部精确吻合**，无一需要放宽口径 |
| **2** | **自己给自己设反证** | 接受「gnomAD 里没有」之前**先用已知阳性验证查询语法**；**主动指出**只数独有 split read 而不看 supplementary 臂 MAPQ 会造出假断点 |
| **3** | **主动区分「这条证据无效」** | 渲染轮列出 7 项 `discriminates=no` 并解释为何 |
| **4** | **工具失败如实报告** | dbSNP 被限流，明写「零贡献」 |
| **5** | **出图迭代快且每版自带可复现脚本** | 一次会话 v1→v4b 五版，重跑逐字节一致 |
| **6** | **不被输入里的陷阱带偏** | 明写「VCF 的 `AF` 是 caller 的等位分数、不是人群频率，全程未使用」；`ANSWER_KEY` 就在同一目录，它明写**未打开** |

**⇒ 它最强的不是「算得快」，是「把主张和证据绑在一起，并主动说出自己哪里可能错」。**

**弱在哪 / 不能依赖：**

| 事项 | 判定 | 依据 |
| :--- | :---: | :---: |
| 会话连续性 | **不可依赖** | 一天 3 次中断（§3.3） |
| 原生比对 / track 渲染 | **没有** | 需自装库 + 自写转换（§4.5） |
| reviewer 兜底 | **不完整** | 1 条 warn 被 reflag **3 次仍 unaddressed，无人接手** |
| **计算层的口径错** | **抓不到** | 官方明确 reviewer 不重跑分析；DEXSeq「0 个显著」那类错**声明与执行完全一致** |
| 数值格式化 | **踩过** | 阈值 `%.2f` 印成 0.26 |
| 管线 / 调度 / 长任务 / 交付 / 客户邮件 | **本就不给** | 我们的 hook 一条都覆盖不到那边 |

**reviewer 抓得到什么、抓不到什么（这张表决定了它不能当唯一验收者）：**

| 我们真实踩过的坑 | 抓得到吗 | 为什么 |
| :--- | :---: | :---: |
| 报告里写了一个图上没有的数字 | **能** | 追不到源，正是它的判据 |
| 声称「已检查过 X」但根本没跑 | **能** | 执行记录里没有这一步 |
| DEXSeq 报「0 个显著」实为 9,301（跨对象 `match()` 取到整列 NA） | **不能** | 代码确实跑了、确实输出 0，**声明与执行完全一致**，错在上游口径 |
| `awk` 换行导致过滤失效、读段数虚报 20–30 倍 | **不能** | 零报错且输出格式正常 |
| 判读图用 `break` 实现「最多取 N 条」= 空间截断而非抽稀 | **不能** | 图画出来排版配色全对，看不出来 |

## §4.8 一个反复出现的模式：它的盲区和我们不重叠

**三次抓到我们的缺陷，方向高度一致 —— 全是「我们没核到底」这一类：**

| 轮次 | 它抓到的 | 我们原本错在哪 |
| :--- | :---: | :---: |
| 出图轮 | caption 写 "top 40 by adjusted P"，实际画 balanced 20/20 | 只核了 DEG 数，**没核选取规则** |
| connector 轮 | 我们标 `absent` 的位点其实有频率，并给出机制 | gnomAD 注释**按字符串比对**，且注释源整个用错 |
| 渲染轮 | 底牌里「软剪切对照更多所以不可判别」是粗口径 | 我的判据设计得不够细 |

**反过来也成立**：它做错的两处（阈值 `%.2f`、`--no_timestamp` 实现成语义相反且从不回报）
**全是我实测出来的，不是它自报的**。

**⇒ 双向互查有效，因为两边盲区不重叠。这是本轮最值钱的结论。**

## §4.9 边界纪律实测：守住了

小试全程对交付目录 `28_Xiaokun_Yang_DC_KO_RNAseq/custom_research_report_20260810/` 只给 **Read-only**；
事后 `find -newermt '2026-09-10'` **零命中**，**430 个文件一个字节没动**。
connector 轮复查输入目录同样 **0 个文件改动**。

---

# Part V — 成本与额度

## §5.1 三天用量（**全文唯一的用量权威表**，其余各节只引结论不重复数字）

> **数据来源（两边都是本机原始记录，不是估计）**：
> Claude Science = `operon-cli.db` 的 `frames` 表（连 WAL 复制到 scratchpad 读副本，不碰活库）；
> Claude Code = `~/.claude/projects/**/*.jsonl` 里每条 assistant 消息的 `usage` 字段（35 个 transcript）。
> Claude Code **不记录成本**，只有 token，故按官方价目换算：
> Opus 5 $5 / $25 每 MTok、Sonnet 5 $2 / $10，cache read ×0.1，cache write ×1.25（5 min）/ ×2（1 h）。

| 日期 | Claude Code | Claude Science | 合计 | CS 占比 |
| :--- | :---: | :---: | :---: | :---: |
| 部署前 12 天日均（08-29→09-09） | **$61.87** | — | $61.87 | — |
| 09-10 部署当日 | $138.29 | **$32.87** | **$171.16** | 19.2% |
| 09-11 两轮判据测试 | $110.43 | **$9.40** | **$119.83** | 7.8% |
| 09-12 proj36 缺陷核实 | $105.24 | **$0** | **$105.24** | 0% |
| **三天合计** | **$353.96** | **$42.27** | **$396.23** | **10.7%** |

**三个关键读法：**

1. **「消耗巨大」的直觉来自 26.8 M input tokens 那个数字，但它不贵。** 其中 **95% 是 cache read**，
   计价 $0.5/MTok 而非 $5 —— 而 Claude Code 日常就是 **100–240 M tokens/天**的同款结构，量级大 5 倍。
   **按 token 数看，大头一直是 Claude Code。**
2. **09-10 那天 Claude Code 自己也是窗口内最高（$138.29）**，原因不是 CS 在跑，
   **而是「部署 Claude Science」这件事本身是用 Claude Code 干的**。**这笔算在它头上是对的，但是一次性的。**
3. **三天 CS 只占 10.7%**，而日均从 $61.87 涨到约 $132 ⇒ **涨的几乎全在 Claude Code 这边**
   （部署它、**复核它的产出**、写文档、跑 proj36 追查）。

**⇒ 不是它把消耗拉上去的；是「用它、然后验证它」这整件事把消耗拉上去的。**

**可以明确否定的一条：它不会在后台偷偷烧额度。** daemon 连续常驻 2 天，而 09-12 它的花费是 **$0** ——
**常驻不花钱，花钱的只有会话。**

## §5.2 三个追问的答案

**问：整合之后是不是大幅加快了 token 消耗？**
**答：确实增大了（日均 $61.87 → 约 $132），但 CS 只占 10.7%，涨的几乎全在 Claude Code 这边。**

**问：能否用它审我们的结果，或者反过来？可靠性会提高吗？**
**答：能，双向都已实测发生过。但「提高可靠性」的机制不是「让它 review」，是「让它独立重算」。**

| 层 | 它查得到吗 | 为什么 |
| :--- | :---: | :---: |
| **叙述层**（「我说我做了 X」vs 执行记录） | **能，而且强** | reviewer 的 pass 判据都精确引用具体 cell 的 stdout |
| **计算层**（口径错、过滤失效、静默截断） | **不能** | 官方明确 reviewer **不重跑分析** |

⚠ **两条不能忽略的削弱因素**：① 两边是**同一批模型**，盲区有相关性，「独立」是相对的；
② 复算等于把这部分工作**做两遍**，成本翻倍。**⇒ 只对「错了要重跑整条」的结论做复算，不做全量复算。**

**问：同样的额度花在这里比花在 Claude Code 上更值吗？**
**答：作为一般的额度分配，不值。而且问法本身有陷阱** —— 实测下来两者**不是替代关系，是叠加关系**：

| 事实（三天实测） | 后果 |
| :--- | :---: |
| CS 花 $42.27，同期 Claude Code 花 $353.96 | 用它**并没有**把 Claude Code 的开销替换掉 |
| 09-11 它花 $9.40 跑完两轮测试；当天 Claude Code 花 $110.43，**很大一块是我在逐个复核它的 8 个数字** | **验证它的产出比它自己跑一遍贵一个数量级** |
| 09-12 它花 **$0**，Claude Code 仍花 $105.24 追查它提出的问题 | 它提问的**下游成本**全落在 Claude Code 侧 |

**⇒ 每在它身上花 1 块，要在 Claude Code 侧配上远不止 1 块的验证，产出才可信。
「把额度挪过去」这个动作根本不存在 —— 只有「额外花一笔」。**

**那这笔额外的花值不值？分两种情况，答案相反：**

| 情况 | 判定 | 依据 |
| :--- | :---: | :---: |
| **当成常规工作流的一道工序** | **❌ 不值** | 七条判据里没有一条显示它能做我们做不了的事 |
| **当成偶发的外部扰动源**，且满足「错了代价高」+「有真值可对」 | **✅ 值** | proj16 那次：CS 侧只花 $9.40，换来一个**已交付产物**里约一半候选变异是常见多态的发现 |

> **可辩护的说法只有一句**：
> **它的花费不该和 Claude Code 比单价，该和「一次返工 / 一次客户发现问题」的代价比。
> 按这个尺子：每年用几次、每次挑对地方，划算；当成日常工序，不划算。**

⚠ **仍然不能说的**：它省下的我的时间值多少额度 —— **没有度量口径，不要编。**
⚠ **口径提醒**：Claude Code 一侧的美元是按官方价目从 token 换算的（transcript 不记成本），
cache write 的 TTL 明细缺失时按 5 min 计，**会略低估**；CS 一侧是它自己库里的 `total_cost`。

---

# Part VI — 整合结论

## §6.1 最大优势不是省钱、不是快，**是它的盲区和我们不重叠**

**最硬的一条证据：它触发了一个已交付客户产物里的缺陷，而那份交付走完过我们全套自审。**
proj16 的 `prioritised.tsv` 里标 `absent` 的位点中 **70–72% 其实在同一个 VCF 的 VEP CSQ 里就有
gnomAD v4.1 频率**，其中 **4,428 条是 AF > 0.01 的常见多态**，约占交付候选名单的一半。
**这个缺陷零报错、退出码 0、表格看起来完全正常**，是 30 个位点的盲测把它顶出来的。

**⇒ 它的价值不在「多一双手」，在「多一套独立实现」。换一个同样由我操作的工具，不会有这个效果。**

## §6.2 三种整合模型，只有一种站得住

| 模型 | 判定 | 理由（全部来自实测） |
| :--- | :---: | :---: |
| **A. 它做项目，我们审核** | **❌ 不行** | 它那边**我们的 hook 一条都不生效**；daemon 一天自行重启 3 次；管线/长任务/tmux 都做不了。**把项目交给一个没有安全网的环境、再靠人去审，是把风险换了个位置** |
| **B. 我们做项目，它审核** | **⚠ 半对，拿到的是弱形式** | reviewer **只查叙述层**，官方明确不重跑分析，而我们真正吃大亏的错误全在计算层。**更糟的是：把我们的答案给它看，就毁掉了它唯一值钱的东西 —— 独立性** |
| **C. 双盲平行复算** | **✅ 推荐** | 两次抓到缺陷**都是这个形状**：同一份原始输入，**剥掉我们已有的答案**给它，让它独立产出，再用脚本做差异清单 |

## §6.3 C 的六步法（proj35 两轮测试的流程，可直接复用）

| 步 | 做什么 | 为什么不能省 |
| :--- | :---: | :---: |
| 1 | 选一个**有独立真值、或能构造真值**的子任务 | 没有真值就只能「看着像不像」，等于没测 |
| 2 | **剥掉答案再给它**（`bcftools annotate -x` 去掉注释列；底牌文件名写 `do_not_give_to_claude_science`） | 输入里带着答案 ⇒ 它直接读出来 ⇒ **必然假通过**。原设计正是栽在这里：VCF 的 INFO 本身就是底牌 |
| 3 | **分层抽样**，不要随机抽 | VCF 5,900,861 条 vs 真值表 4,294 条 ⇒ 命中率 **0.073%**，随机抽 30 个期望命中 0.02 个，**整轮白跑**（差点发生） |
| 4 | 指定**输出列名**，让结果可被脚本消费 | 人眼比对 30 行还行，4,294 行不行 |
| 5 | 用**核对脚本**出差异清单，并**先用种子错误验收核对脚本本身** | 我的核对器第一版把 6 条「它说查不到」误判成「编造」，**假阳性正好落在一票否决那条上** |
| 6 | 差异逐条查根因，**不预设谁对** | 这次结论是**我们错**；预设立场就查不到了 |

**授权与事后核对（每次都做）**：输入目录 **Read-only**，输出目录 Read & write，**其余一律不给**；
事后 `find <交付目录> -newermt '<当日>'` **必须零命中**。

**可直接粘贴的任务指令模板**（连续性探针 + 不许编造 + 输出规格 + 边界，四件事一次写全）：

```
Read-only input: <path>

At the start of every step print:
  if (!exists(".step_n")) .step_n <- 0; .step_n <- .step_n + 1; .step_n

Task: <...>. For each annotation give the source and the database version
or release you got it from.

Note: the INFO column carries caller QC fields only (AC/AF/AN/DP/MQ...). The AF
there is this sample's allele fraction from the variant caller, NOT a population
frequency. Do not report it as one.

Save your final answers as a TSV with these exact column names: <...>

Then: for any variant where a connector returns nothing, say so explicitly. Do not
infer a frequency from neighbouring variants or from the gene's general
constraint. "Not present in gnomAD" is a result; a plausible-looking number is not.

Do not write anything to the input directory. All output goes to the exploration
folder. Versioned filenames. PDF for figures.
```

## §6.4 什么时候值得花（选择判据）

**不要「让它跑一遍看看」。** 验证成本是大头，所以**只在同时满足两条时才做**：

1. **错了的代价高** —— 已交付、要发客户、或错了要整条重跑；
2. **有真值可对，或能构造** —— 有旧管线结果、有设计已知的阳性对照、有公开数据库可查。

**proj16 那次两条全中：已交付 + 有我方管线注释可当对照。这就是它最该用的位置。**

> **⚠ 一条已作废的说法**：本评估早先写的「**凡是我们有独立真值可对的任务，都值得让它跑一遍**」
> **过强，2026-09-12 作废**。作废理由：
>
> | # | 事实 | 后果 |
> | :--- | :---: | :---: |
> | 1 | 验证它的产出**比它自己跑一遍贵一个数量级** | 「都值得跑一遍」把最贵的那部分当成了免费的 |
> | 2 | 它最亮眼的那次贡献（proj16）**不需要它** —— 一条通用自洽性检查**只用交付文件本身、4.4 秒**就暴露 chr22 上 **30.6%** 的自相矛盾 | 它的真实贡献是**提出了我们没在问的问题**，不是给出我们拿不到的答案 |
> | 3 | 七条判据里没有一条显示「它能做我们做不了的事」 | 它不构成工作流里的任何一道工序 |

**那条 4.4 秒的替代检查（已制度化，写进 wgs skill 门禁）：**

```bash
# INFO/gnomAD_AF 与 VEP CSQ 是否自相矛盾（chr22，96,188 个变异）
bcftools query -r chr22 -f '%INFO/gnomAD_AF\t%INFO/CSQ\n' Sample_A.gnomad.clinvar.vcf.gz
# ⇒ INFO 为空但 CSQ 有值：29,422 个（30.6%）
```

## §6.5 对不太懂生信的人作用更大吗？——**方向相反**

它在两轮测试里的亮点，**全是专家级动作**：等位基因等价匹配、接受阴性前先用已知阳性验证查询语法、
比深度前先归一化、排除 MAPQ=0 的 supplementary 臂。**这些恰恰是新手评估不了的东西。**

而它做错的三处，**全部靠「有人去查」才暴露**：

| 它做错的 | 谁发现的 | 新手会怎样 |
| :--- | :---: | :---: |
| 阈值 `%.2f` 印成 0.26（真值 0.263） | 我们实测 | 照抄进 Methods |
| `--no_timestamp` 实现成语义相反的 `--keep_timestamp` 且从不回报 | 我们实测 | 完全不知道要求被改了 |
| 声称「`_scratch_repro/` 已清空、20 个文件移入回收站」，实则 18+ 个仍在 | **它自己的 reviewer** | 信了 |

**⇒ 对不能验证的人，它提高的是产量和表面可信度，不是可靠性 —— 而且提高了「错得像对的」概率。
对能验证的人，它才转化成可靠性。它的价值全部在差异清单里，而读差异清单需要专家。**

（唯一对新手的真实好处：它带着新手不知道的知识，能抬高**初稿的天花板**。
但同一件事也抬高了「看起来完全合理的错」的产出速度，**净效应取决于有没有人验**。）

## §6.6 边界（无论用哪种模型都不变）

| 进 | 不进 |
| :--- | :---: |
| 矩阵 / 变异表之后的**探索、出图、查外部库、判读证据** | 管线、调度、长任务、交付目录、客户面文字 |
| **拿它做独立复算器**（给最终表 + 主张 + 原始数据，**不给我们的脚本**，只报差异） | 拿它当**唯一**的验收者 —— reviewer 只看叙述层 |
| 需要「逐条给出证据与版本」的判读任务 | 依赖会话内状态的多步流程 |

**具体到分工：**

| 环节 | 归谁 | 理由 |
| :--- | :---: | :---: |
| sarek / nf-core / taxprofiler / 长比对 | Claude Code + tmux | kernel 闲置 30 min 回收、远程作业默认 30 min 超时，接不住 14.5 h 级并跑 |
| 28 核 / 56 线程预算调度、`/corun` | Claude Code | 资源纪律在 skill 与 hook 里 |
| 交付目录生成、报告 §1–§9、客户邮件 IMAP 草稿 | Claude Code | 全靠 `route_post_write.py` / `guard_inline_email.py` 机械化，**Claude Science 无 hook 机制** |
| DEG 之后的探索、聚类、反复调图 | Claude Science | 探索期加速器 |
| 查 Ensembl / gnomAD / ClinVar / GTEx / ENCODE / GEO / UniProt / PDB | Claude Science | connector 内置、read-only、免密钥 |
| 载体整合位点、CRISPR 编辑判读 | Claude Code（**判读**）/ Claude Science（**盲测复算**） | 判读纪律在 skill 里；把它当独立复算器另说 |

**三条必须自己补的缺口（它那边没有等价物）：**

1. **hooks 一件都过不去。** `guard_destructive_bash.py`、`guard_frozen_delivery.py`、`stop_check_reply.py`
   在 Claude Science 里**没有对应机制** —— 这恰是「违反一次即不可逆」的那一层。
   ⇒ 对策：`claude-science-guardrails` skill（已落盘 `~/.claude/skills/`）+ 使用纪律上限定它
   **只在探索目录工作，交付目录的写入一律回 Claude Code 做**。
2. **skills 不自动共享。** `~/.claude/skills/` 下的 skill 不会被它读到，需 Import/Upload。
3. **L0 `CLAUDE.md` 没有等价物。** 「只准备不发送」「不建议长读长」「测序参数是我方决定」这些裁定
   若不搬过去，它出的客户面文字不受任何约束。

**⚠ 出图 skill 导入前必读**：它自带 `figure-style` skill，与我们的 `scientific-figure-making` 高度重叠，
**不先声明优先级两套规则会打架**（它的 §4 会自己挑色，我们的五级色表就被绕过）。
取舍结论与已落地的吸收见
[`~/Utilities/color_and_format/figure_style_claude_science_vs_ours_20260911.md`](../../../color_and_format/figure_style_claude_science_vs_ours_20260911.md)。

## §6.7 收尾状态（2026-09-12）

**已做完的（改的是模板与 SOP，没动任何已交付产物）：**

| # | 事项 | 落在哪 |
| :--- | :---: | :---: |
| 1 | `absent → rare` 假设 ⇒ 写成禁令 | `~/.claude/skills/wgs/SKILL.md` |
| 2 | `af-only-gnomad.hg38` ⇒ 限定只用于 Mutect2 `--germline-resource` | 同上 + 参考文件旁的 `README_USAGE.md` |
| 3 | 写进 pitfalls | `~/Utilities/software_pitfalls/gnomad_af_only_rarity.md` + INDEX |
| 4 | **注释后强制自检**（`INFO/gnomAD_AF` vs `CSQ`，4.4 秒） | wgs skill 门禁 |
| 5 | proj16 缺陷核实 | proj36，**用户裁定不通知客户** |
| 6 | `figure-style` 六条的吸收与代码断言落地 | R/Python 双写 + 种子错误注入验收，提交 `a421898` |

**⚠ 刻意没做**：不改 proj16 的脚本、不重跑 proj16、不动已交付产物 ——
**那些脚本是产生该交付物的历史记录，改了就破坏交付与代码的对应关系。**

---

# 附录 A — 仍未了结的

| # | 事项 | 状态 |
| :--- | :---: | :---: |
| 1 | 那条被 reflag 3 次的 **warn**（`--no_timestamp` → `--keep_timestamp`，偏离未申报） | **未处理**。下一轮观察点：被 flag 的问题是否会自动回到主 agent 的任务里 |
| 2 | proj16 过滤脚本的 `absent → rare` 假设 | **未修**（刻意不动已交付产物；禁令已写进 wgs skill，对新项目生效） |
| 3 | 判据 #7（matplotlib 中文字体） | **未验** —— 两轮都是全英文标签 |
| 4 | Step 4：把我们的 skill 真导入它，看两套规则实际是否打架 | **未做**（需浏览器 UI + GitHub token） |
| 5 | 它的 `kernel.py` 11 个 helper 在我们数据上的实际效果 | **未做**（只读了签名，没跑） |
| 6 | 隧道写进 `~/.ssh/config` | **未做**（§3.4 的最高优先项） |

# 附录 B — 来源

| 文档 | URL |
| :--- | :---: |
| Overview | https://claude.com/docs/claude-science/overview |
| Run on a remote Linux server | https://claude.com/docs/claude-science/run-on-remote-linux-server |
| Remote compute clusters | https://claude.com/docs/claude-science/remote-compute-clusters |
| Connectors and skills | https://claude.com/docs/claude-science/connectors-and-skills |
| Tools and environments | https://claude.com/docs/claude-science/tools-and-environments |
| The reviewer | https://claude.com/docs/claude-science/the-reviewer |
| 发布公告 | https://www.anthropic.com/news/claude-science-ai-workbench |
| 产品页 | https://claude.com/product/claude-science |
| 文档索引（全部 28 页） | https://claude.com/docs/llms.txt |

# 附录 C — 项目内原始材料（证据出处）

| 路径 | 内容 |
| :--- | :---: |
| `~/projects_2026M7/35_Try_of_Claude_Science/docs/P35_research_plan_and_review_0910.md` | **计划与复盘**（living doc，仍在原地维护） |
| 同目录 `P35_*.md`（5 份） | 本文的原始来源，**已标注不再更新** |
| `scripts/0_component_table.csv` | SSOT：各步骤的脚本、批准要求、状态、回退方式 |
| `scripts/0..3_*.sh` | 部署步骤脚本（已执行） |
| `scripts/6_check_connector_answers.py` | connector 轮的核对器（已用种子错误验收） |
| `exploration/` | 四轮出图产物、`figure_qc.R` 与 4 个故意做坏的测试图、两轮判据测试的输入与产物 |
| `logs/` | 部署步骤日志（带时间戳，永不覆盖） |
