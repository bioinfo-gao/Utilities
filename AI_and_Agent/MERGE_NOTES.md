# Utilities 合并说明（2026-07-25）

> **文档角色：** 本文是整个 `/home/gao/Utilities/` 的合并历史记录，不是当前 Agent 行为规则或
> 客户端配置说明。为避免破坏已知路径，文件暂留在 `AI_and_Agent/`；其范围仍是整个 Utilities 仓库。
> 当前 Agent 配置入口请从 `AGENTS.md` → `Agent_Assets/AGENT_ENDPOINTS_AND_LINKS.md` 开始。
>
> **维护方式：** 历史事实不回写；只有新的合并、退役或核验才在文末追加带日期的条目。

本目录 `/home/gao/Utilities/` 是以下三代 Utilities/facilities 工具库的**合并结果**，
自本次合并起为 **canonical / single source of truth**：以后新增/更新工具笔记只写在这里，
不再更新下面三个旧位置。三个旧位置**均未删除、未修改**，作为历史存档保留：

- `/home/gao/projects_2026H1/Utilities/`  （最早一代，命名为 `Utilities`）
- `/home/gao/projects_2026H2/facilities/` （第二代，改名 `facilities`）
- `/home/gao/projects_2026M7/facilities/` （当前活跃项目父目录下的第三代）

**Git**：本目录自 2026-07-25 起是独立 git 仓库，远端 `git@github.com:bioinfo-gao/Utilities.git`
（**private**），同款 `.githooks/pre-commit` 大文件拦截（>10MB）。`Server/FTP/client_credentials.env`
已在 `.gitignore` 中排除，不进任何 commit。

## 合并逻辑

三代内容本质是**同一个人工具库随时间演进**（改名 Utilities→facilities，父目录也在演进），
多数同名主题文件夹之间是"互补"而非真正冲突（不同时间段积累的不同文件）。合并原则：
1. 同主题文件夹统一到一个新目录名下，按 H1→H2→M7 时间顺序合并（新的不覆盖旧的独有文件）。
2. 内容完全相同的重复文件（如 `color.ipynb`、`0_markdown_font_color.ipynb` 曾同时存在于
   `IDE_Positron/`、`Python.../10.Plotting/`、`color_and_format/` 三处）只保留一份，放在
   `color_and_format/`。
3. 文件名相同但内容不同的（如两份 `merge_counts.R`、多份 `Sample_Registration_Form*.xlsx`、
   两份不同周期的 `working_list.txt`）**全部保留**，用来源后缀消歧，不主观取舍/删除。
4. **例外**：`Python/10.Plotting/3_plotly/datasets/`（~1.1G，克隆的 `dash-sample-apps` 仓库 +
   原始教程数据集）未纳入合并——这是外部教程数据而非个人整理的参考资料，体积过大且无长期
   参考价值。原始完整版仍在 H1 原路径，未受影响；此处留了 `datasets_NOTE.md` 说明。

## 新目录结构 ↔ 旧来源映射

| 新位置 | 旧来源 |
| :--- | :--- |
| `Bioinfo/` | H1:`Bioinfo`,`prepair_genome`,`file_size-sequencing-size` + H2:`bioinfo_technicals/*`,`soft` |
| `R/` | H1:`R_tested_in_R4.5.2` |
| `Python/` | H1:`Python_tested_in_python3.10_and_ipynb`（排除 3_plotly/datasets 大体积教程数据）+ GitHub repo [bioinfo-gao/Python_Omics_DS](https://github.com/bioinfo-gao/Python_Omics_DS) 的 `0A.Local_Remote_setting_and_shortcut`、`0B.Tools_color_and_R_version_in_vsCode_and_Spyder`（原样加入，无冲突）+ 该 repo 的 `10.Plotting`（与已合并的 H1 版本同名文件内容不同，全部保留为 `10.Plotting/_github_repo_variant/` 子目录，同样排除其 datasets 大体积数据） |
| `IDE/Positron`, `IDE/vsCode` | H1:`IDE_Positron`+`IDE_vsCode` + H2:`Positron` |
| `color_and_format/` | H2:`color_and_format`+`markdown`（去重后的 canonical 版本） |
| `git/` | H1:`git_and_github` + H2:`git` + GitHub repo [bioinfo-gao/Linux_and_Cluster_for_Omics](https://github.com/bioinfo-gao/Linux_and_Cluster_for_Omics)'s `git_Advanced`,`git_LFS`,`git_and_WSL_and_sparse` (added 2026-07-25, sparse-checked-out; no filename collisions with existing content) + GitHub repo [bioinfo-gao/Python_Omics_DS](https://github.com/bioinfo-gao/Python_Omics_DS)'s `0C.Remove_the_trouble_some_LFS`（内容与 `git_LFS/0C.Remove_the_trouble_some_LFS` 部分互补，合并入同名文件夹；`remove_troublesome_LFS_Steps.txt` 内容不同，两版本都保留并消歧命名） |
| `AI_and_Agent/` | H2:`AI_and_Agent`（canonical 结构）+ H1:`Agent` 里未被 H2 重构覆盖的散落 notebook → `misc_early_notes/`；H1 的 `Agent/Qoder` 当时判定已被 H2 的 `Qoder_LingMa_Qwen` 完全覆盖，未重复拷贝 —— **2026-09-12 更正：该判定不成立**，`Agent/Qoder/Qoder.ipynb` 里「阿里云账号登录后回不到 Positron，须改用淘宝账号」这段唯一记录并未被覆盖（H2 侧只有一行 42 字节的初步判断），已于当日补入 `Qoder_LingMa_Qwen/longin_use_alibaba.txt` |
| `company/` | H2:`bac` + H2:`AI_and_Agent/Company`（错放位置，已挪出）+ M7:`company`；5 份内容不同的 Sample_Registration_Form 全部保留并消歧命名 |
| `Server/` | H1 一堆零散基础设施文件夹（`server`,`bind_mount`,`conda_docker_siggularity_nextflow_cronwell`,`Advanced_bash`,`Advanced_sudo_bash`,`bash_small_tools`,`scp`,`dropbox`,`scripts_by_lhn`,`Wind_wsl_windows_sub_linux`）+ H2:`Server/*`,`TailScale`,`tmux`,`docker`,`FTP` + M7:`Server/*`（合并为统一的 Server/ 子分类） |
| `software_pitfalls/` | M7:`software_pitfalls`（结构已成熟，原样迁入；**自 2026-07-25 起此处为新 canonical 位置**，M7 原路径冻结存档） |
| `cmd_tools/` | H2:`cmd_tools` |
| `scripts_by_ZG/` | H1:`scripts_by_ZG_BJ_Server` + `scripts_by_ZG_tailscale`（内容几乎相同，仅 `merge_counts.R` 不同，两版本都保留并消歧命名） |
| `work_logs/` | H1/H2 各自的 `working_list.txt`（内容是不同周期的周报，非冲突，全部保留） |
| `save_ipynk_to_html.sh` | H1 根目录散落脚本 |

## 后续新增工具笔记的位置

新的工具/环境笔记、软件坑（pitfall）记录与回顾，一律直接写入/查阅 `/home/gao/Utilities/`
对应子目录（包括 `software_pitfalls/`），**不再**写回或查阅
`projects_2026H1/Utilities`、`projects_2026H2/facilities`、`projects_2026M7/facilities`
三个旧路径——**无例外**（2026-07-25 用户明确确认，`software_pitfalls/` 不再是例外，
`projects_2026M7/facilities/software_pitfalls/` 自此正式冻结为历史存档，CLAUDE.md 中对应
MANDATORY 规则已同步更新为新路径）。

⚠️ ~~注意：`/home/gao/Utilities/` 本身不在任何 git 仓库内，因此这里的更新目前**没有版本控制**
（旧的 `projects_2026M7/facilities/software_pitfalls/` 曾受该项目仓库的 git 跟踪）。如需要保留
修改历史，可考虑单独给 `/home/gao/Utilities/` 做 `git init`。~~
**已失效（2026-07-25 当天即解决）**：本目录已是独立 git 仓库（`git init -b main`，
`.githooks/pre-commit` 拦 >10MB，push 到私有 repo `git@github.com:bioinfo-gao/Utilities.git`），
更新有版本控制。

## 2026-09-12 —— H1 旧路径退役前的内容核验

删除 `/home/gao/projects_2026H1/Utilities/` 之前做了一次**按内容（md5）而非按文件名**的全量核对，
结论与处置：

| 类别 | H1 文件数 | 处置 |
| :--- | :---: | :---: |
| 内容已在本仓库逐字节存在 | 368 | 直接退役 |
| `3_plotly/datasets/`（`plotly/datasets` 上游 repo，~1.1G） | 1185 | 合并时即故意排除；见 `Python/10.Plotting/3_plotly/datasets_NOTE.md`，改为从上游重新 clone |
| `Bioinfo/rRNA_databases_see_Work_bio_reference/` 的 8 个 fasta | 8 | 与 `/Work_bio/references/rRNA_databases/` 逐字节相同 |
| 同目录 `sortmerna_database_manifest.txt` | 1 | `/Work_bio` 版是更新过的路径（H1 版仍指向已废弃的 `projects/2026_Item10_.../scripts/`），以 `/Work_bio` 版为准 |
| `Agent/Qoder/Qoder.ipynb` | 1 | **唯一未被覆盖者**，内容已补入 `AI_and_Agent/Qoder_LingMa_Qwen/longin_use_alibaba.txt` |

另有 1 个 symlink `Bioinfo/Make_Whole_Gene_Set -> /Work_bio/references/Genes/` 随之消失；
指向的目标目录仍在，未做等价链接。

⚠️ `/home/gao/projects_2026H1/` 不是 git 仓库，H1 侧没有任何历史可兜底 —— 这也是先做上述
核验、再删除的原因。
