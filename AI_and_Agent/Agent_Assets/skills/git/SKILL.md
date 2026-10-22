---
name: git
description: "Use when 要对本机任一 git 仓库做提交/推送/清理——尤其 commit+push 前必须排除大文件(避免 258G scratch、BAM/work/ 进库或撞 GitHub 100MB 上限)、检查凭据泄露、按本环境约定写 commit,以及判断哪些操作(force-push/history rewrite)必须先 surface"
disable-model-invocation: true
---

# /git — git & GitHub 操作、注意事项与检查清单

> 本 skill 是本机 git 工作流的 **procedure/checklist**,不是 git 教程。核心目标:
> **commit/push 前一定先把大文件排除到 `.gitignore`,不把数据/中间结果/凭据推上 GitHub。**
> 用户已永久授权直接执行各种 git 命令(status/diff/add/rm --cached/commit/branch/push 等),
> 无需每次询问;但 **push 前排除大文件是硬前置条件**(用户 2026-07-18 明确指令)。

---

## 已知仓库(本机)

| 本地路径 | remote | 分支 | 备注 |
| :--- | :---: | :---: | :---: |
| `/home/gao/projects_2026H2` | `git@github.com:bioinfo-gao/GZ_Projects_2026H2.git` | `master` | 旧主项目库,2026-07-21起冻结(不再加新项目),工作树 5.5T,只追踪代码/文档/小结果 |
| `/home/gao/projects_2026M7`（symlink→`/mnt/ex_8T_SSD/projects_2026M7`） | `git@github.com:bioinfo-gao/GZ_Projects_2026M7.git` | `main` | **新主项目库**(2026-07-21起，project 19+ 建于此);独立仓库,不是 H2 的子模块/延续；已装同款 `.githooks/pre-commit` + 照搬 `.gitignore` |
| `/home/gao/.claude` | `git@github.com:bioinfo-gao/claude-code-settings.git` | `master` | **白名单式 .gitignore**(默认全拒),放凭据必须先审 |
| `/home/gao/Python_Tools_Tested` | `git@github.com:bioinfo-gao/Python_Tools_Tested.git` | `main` | 工具库 |
| `/home/gao/Utilities` | `git@github.com:bioinfo-gao/Utilities.git` | `main` | **新 canonical 个人工具/pitfall 笔记库**（2026-07-25 由 3 代旧 Utilities/facilities + 2 个 GitHub 仓库合并而成，见该目录 `MERGE_NOTES.md`）；**private** repo；同款 `.githooks/pre-commit`；`Server/FTP/client_credentials.env` 已 `.gitignore` 排除 |
| **(本机无 clone)** | `git@github.com:bioinfo-gao/R_Omics_DS.git` | `main` | **⚠ 只存在于另一台机器(`ZH_Tailscale`)**,本机 `find` 永远搜不到;2026-09-18 一天在此库产生 23 个 commit —— **数当日总数时必须走 GitHub API 单独查它** |

**所有库统一走 SSH(`git@github.com:...`) 认证——本机无 HTTPS 凭据,HTTPS remote 会推不动。** 若某库 origin 是 `https://github.com/...`,push 会报 `could not read Username for 'https://github.com'`;用 `git remote set-url origin git@github.com:<owner>/<repo>.git` 切 SSH(见陷阱表)。projects_2026H2 曾是 HTTPS,2026-07-18 已切 SSH。

**注意:主目录 `/home/gao` 本身不是 git 仓库**——先 `git rev-parse --show-toplevel` 或按上表定位真正的仓库根,别在错误目录操作。

---

## 🛡️ 系统自动拦截:pre-commit 三类 hook（本 skill 核心目标 — 免手动排查）

**手动逐次排查太痛苦、也会漏。真正的解法是让系统自动检测**——`Utilities` / `projects_2026M7` / `projects_2026H2` 三仓库装了**同一份**版本化 pre-commit hook（三份 md5 必须一致），对用户和 agent 都生效。**2026-08-06 从"仅大文件"扩到三类**:

| # | 查什么 | 判据 |
| :--- | :--- | :--- |
| 1 | **大文件** | 暂存 blob > 10 MB(`LIMIT_MB`) |
| 2 | **隐藏文件/目录** | 路径任一段以 `.` 开头。白名单两类:<br>· git+工程:`.gitignore` `.gitattributes` `.gitmodules` `.gitkeep` `.keep` `.githooks/` `.github/` `.continueignore` `.editorconfig` `.Rprofile` `.Renviron`<br>· **AI agent 配置目录**:`.claude` `.codex` `.gemini` `.kimi` `.qwen` `.qoder` `.deepseek` `.lingma` `.agent` `.agents` `.ovagent` `.ollama` |
| 3 | **密码/密钥** | ① 文件名即凭据(`*.env` `*.pem` `*.key` `id_rsa*` `.netrc`、以及 `auth.json` `credentials` `*-credentials.json` `google_accounts.json` `.claude.json`);② 内容含高置信度密钥(私钥块/`ghp_`/`sk-ant-`/`AKIA`/JWT/`user:pass@host`/`password = "真值"`) |

⚠ **白名单只放行"这一段隐藏名本身",不豁免 ③ 的凭据文件名规则、也不豁免内容扫描** —— agent 目录里的 `.codex/auth.json`、`.gemini/gemini-credentials.json`、`.kimi/credentials`、`.claude/.credentials.json`、`~/.claude.json` 仍会被拦。**配置文件进得去,凭据文件进不去。**

**命中后的动作分两种,刻意不做成一刀切:**

| 情形 | 动作 |
| :--- | :--- |
| **新增文件**(`A`)命中 1/2/3① | **自动**写 `.gitignore` + `git rm --cached` + **放行**;文件仍在磁盘上 |
| **已跟踪文件**(`M`)命中任一类 | **硬拦截** —— 对已入库文件 `git rm --cached` 会记录成删除,等于移出仓库,绝不自动做 |
| **内容**扫到密钥(3②) | **硬拦截**并报 `文件:行号 + 类型 + 掩码值`;该改的是那一行,不是整个文件。**若已推过远端,必须去平台吊销换新** |

```
.githooks/pre-commit          # 单文件 bash + 内联 python3 扫描器;顶部三个开关:
                              #   LIMIT_MB / STRICT_ON_MODIFIED / STRICT_ON_SECRET_CONTENT
git config core.hooksPath .githooks   # 已设;hook 随仓库版本化,clone 后重设一次即可
```
- 被拦时:① 按提示改(挪走密钥行 / `git restore --staged`);② 确知无害 `git commit --no-verify` 放行。
- **其它仓库若也要防护**:拷 `.githooks/pre-commit` 过去 + `git config core.hooksPath .githooks`。
- **详细规则与实测结果**见 `Utilities/AI_and_Agent/Claude/Hooks_MCP_Skills_plugin_subAgent_Routines_harness/1_当前能力清单_INVENTORY.md` **C 段**(改 hook 就同步改那里)。
- hook 是**兜底**,不替代下面的 .gitignore 规则(规则让文件根本不进暂存,更干净)。**新增大数据类型时优先加 .gitignore 模式**(如 `*genefamilies*.tsv` 恒数十 MB)。

## ⚠️ 提交/推送前 MANDATORY:大文件排除检查

**顺序永远是:① 扫大文件 → ② 加 .gitignore → ③ add → ④ 复核暂存区无大文件 → ⑤ commit → ⑥ push。**
跳过 ①②④ 直接 `git add -A && commit && push` 是本 skill 要防的头号事故。**即便如此,pre-commit hook 会在最后一道兜底拦截。**

### ① 扫描"未追踪且未被忽略"的大文件(权威做法)

```bash
cd <repo>
# 列出会被 add 进来、且 >2MB 的未忽略文件(--no-run-if-empty 防空输入陷阱,见下)
git ls-files --others --exclude-standard -z \
  | xargs -0 --no-run-if-empty du -h 2>/dev/null \
  | awk '$1 ~ /G$/ || ($1 ~ /M$/ && $1+0 >= 2)' | sort -rh | head -40
# 空 = 没有大文件待入库
```

同时看已追踪的大文件(历史里已进库的):
```bash
git ls-files -z | xargs -0 du -h 2>/dev/null | sort -rh | head -20
```

### ② 把大/可再生的东西加进 `.gitignore`

**判据——凡是"可再生 / 数据 / 中间结果 / 大二进制"一律 ignore,只追踪代码+文档+小结果表+图。**
常见该 ignore 的目标(很多已在主库 .gitignore,新项目按需补):

- nextflow/nf-core 运行目录:`work/`、`work_*/`、`.nextflow*`、`*/output_results/`
- pipeline 大输出:`humann_out/`、`*.k2d`(kraken2 db)、`*.bowtie2out.txt`、`*_bowtie2_aligned.tsv`、`*.ffn`
- 测序/比对/索引:`*.fastq*`、`*.fq*`、`*.bam`、`*.cram`、`*.bai`、`*.fasta`、`*.fa`、`*.gz`、`*.tbi`
- 大二进制/DB:`*.h5`、`*.h5ad`、`*.rds`(视情况)、`*.db`、`*.sqlite`、`*.zip`、`*.tar.gz`
- 凭据:`*.env`、`client_credentials.env`、`*secret*`、`*credential*`

写规则时优先 **目录级 anchored**(如 `17_Proj/humann_out/`)+ 一条通用兜底(如 `**/humann_out/`),
覆盖当前和未来文件。改完立刻确认生效:
```bash
git check-ignore -v <那个大目录>     # 有输出 = 已被忽略
git status --porcelain                # 大目录应从 ?? 列表消失
```

### ③④ add 后必复核暂存区

```bash
git add -A
git diff --cached --name-only -z | xargs -0 du -h 2>/dev/null | sort -rh | head -10
```
**最大的暂存文件应是 KB~低 MB 级。** 若冒出 >5MB 的意外文件 → 回到 ② 补规则,`git rm --cached <file>` 撤出,再复核。GitHub 硬限:**单文件 100MB 拒收,>50MB 警告**;别指望 push 时才发现。

---

## 敏感文件 / 凭据 hygiene

- commit 前对将入库的文件扫一遍凭据特征,**逐条人工确认命中是不是真密钥**(文档里提到 "app password/token" 这类说明词是误报):
  ```bash
  git diff --cached | grep -Ei 'password|api[_-]?key|secret|token|BEGIN.*PRIVATE KEY'
  ```
- `.claude` 库是 **白名单式**(`*` 全拒 + `!` 逐项放行)——**永远不要删掉开头的 `*` 或加 `!*` 兜底放行**,那是防止把 session transcript / 凭据 / 客户数据推上去的最后一道闸。往里加新目录要显式 `!/path/**`。
- 真凭据不进任何库(FTP creds 放 `/home/gao/Utilities/Server/FTP/client_credentials.env`,在库外)。

---

## Commit 规范(本环境)

- **直接执行,不逐次问**:status/diff/add/`rm --cached`/commit/branch 直接跑。
- **message 极简**:1 行最佳,**最多 3 行**,短语/片段而非成段散文;不写"我为什么这么选"的叙事(那属于对话或项目文档)。
- **必带 trailer**:结尾加
  ```
  Co-Authored-By: <本会话系统提示给出的模型名> <noreply@anthropic.com>
  ```
  模型名取当前会话系统提示里写的那个（如 `Claude Sonnet 5.5`），不套用固定的 Opus 5。
  ⚠ **canonical 来源是 `~/.claude/CLAUDE.md` §7（全局协作规则）**,本处只是镜像。
  模型名换代时**以 CLAUDE.md 为准**;本文件曾停留在 `Opus 4.8` 而 CLAUDE.md 已是 `Opus 5`
  (2026-09-05 发现并修正)——**发现两边不一致时改这里,不要改 CLAUDE.md**。
- **粒度**:相关小改动合并成一个 coherent commit。
- **🔴 硬上限:全机所有仓库合计 每天 ≤ 29 个 commit**(user directive 2026-09-18,「严格」)。
  **不是单库 29,是总数 29** —— 并行会话也算进同一天的总数,动手前先数:
  ```bash
  # ① 本机 5 个仓库
  for r in /home/gao/projects_2026H2 /home/gao/projects_2026M7 /home/gao/.claude \
           /home/gao/Python_Tools_Tested /home/gao/Utilities; do
    printf '%-24s %s\n' "$(basename $r)" "$(git -C $r log --since="$(date +%F) 00:00" --oneline --all | wc -l)"
  done
  ```
  **② 本机数完不等于数完** —— 还要查**本机没有 clone 的仓库**(现已知 `R_Omics_DS`,
  也可能有新的)。本机**没装 `gh`**,走 github MCP:
  - `search_repositories(query="user:bioinfo-gao pushed:>=<今天>")` 列出今天动过的所有库;
  - 对每个库 `list_commits(since="<今天>T00:00:00Z", perPage=100, fields=["sha","commit"])` 数条数。
  **⚠ 时区**:GitHub 返回 UTC,本机是 EDT(UTC-4);按**本机日历日**归日,别直接拿 UTC 日期当天数。

  临近上限就按任务粗批,别一次一存档;**不确定要不要现在提交 ⇒ 不提交**。
- commit 前 `git status` / `git diff --cached` 确认只暂存了预期文件,没扫进无关内容。

---

## 需要先 surface(不擅自做)的操作

这几类是外向/难撤销,执行前简要说明再做(用户已授权普通 push 直接做,但下面这些除外):

- `git push --force` / `--force-with-lease`
- **history rewrite**(`git filter-repo`、`filter-branch`、`rebase` 改已推历史)
- `git reset --hard` 丢弃未保存工作
- 删远端分支 / 大规模 `rm`

### 关于 `.git` 臃肿(history)

主库 `.git` 曾达 13G,但**历史里最大单个对象也只 ~7MB**——臃肿是大量中等文件累积,没有单个巨物可精准摘除。
且本地常与 origin 完全同步(已推),清理需 `git filter-repo` 重写历史 + **force-push 共享远端**(破坏性)。
**不要自作主张瘦身 `.git`**;需要时单独规划并 surface。判断:
```bash
git rev-list --left-right --count origin/<branch>...<branch>   # 0 0 = 已同步
git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize:disk) %(rest)' \
  | awk '/^blob/{print $3,$4}' | sort -rn | head -15           # 看最大历史对象
```

---

## 常见陷阱(踩过的)

| 陷阱 | 真相 / 对策 |
| :--- | :--- |
| `git ls-files --others \| xargs du` 空输入时 `du` 对 `.` 递归,打印整棵 5.5T 树 | 加 `--no-run-if-empty`(或 `xargs -r`);**空输出恰恰说明干净** |
| 以为 `.gitignore` 能忽略已追踪文件 | 不能。已 tracked 的要 `git rm --cached` 才会移出 |
| `work/` 规则匹配不到 `work_taxprofiler/` | `work/` 只匹配同名目录;要 `work_*/` 或写全名 |
| 多行 commit message 偶被权限分类器拦 | 若被拦,换单行 `-m` 重试;先 `git log --oneline -1` 确认是否已提交,别重复 |
| 报 "done" 只因 tmux/命令发出 | push 后必 `git status -sb`(应 `## <branch>...origin/<branch>` 无 ahead)+ 看 push 输出的 `old..new` 确认真推上去了 |
| 在 `/home/gao` 直接跑 git | 那不是仓库;先定位真正 repo 根 |
| push 报 `could not read Username for 'https://github.com'` | origin 是 HTTPS 但本机无 HTTPS 凭据。**切 SSH**:`git remote set-url origin git@github.com:<owner>/<repo>.git` 再 push。commit 本身已成功(本地 ahead),别重 commit,只需修 remote 后 push。先 `git remote -v` 看当前协议 |
| `git remote set-url` 被 auto-mode 分类器拦 | 改 remote 属敏感 config 变更,auto 模式可能拒。**stop 并向用户说明请其授权**(用户授权即可放行);别用推到显式 URL 等方式绕过分类器意图 |

---

## 快速命令参考

```bash
# 定位仓库 & 状态
git -C <repo> rev-parse --show-toplevel
git -C <repo> status -sb

# 提交前大文件扫描(见上,MANDATORY)
git ls-files --others --exclude-standard -z | xargs -0 -r du -h | awk '$1~/G$/||($1~/M$/&&$1+0>=2)' | sort -rh

# 标准提交+推送(排除大文件之后)
git add -A
git diff --cached --name-only -z | xargs -0 -r du -h | sort -rh | head   # 复核
git commit -m "<terse msg>

Co-Authored-By: <当前会话系统提示给出的模型名> <noreply@anthropic.com>"
git push origin <branch>
git status -sb            # 确认已同步
```
