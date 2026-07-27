# Software / Environment Pitfalls — Index

跨项目速查表：用某个工具前先扫一眼这里，避免重复踩坑。每个文件只写症状+根因+修复方式，详细的事故
记录/时间线仍在对应的 `reference_*`/`project_*` memory 里，这里不重复全文，只索引+链接。

新增条目时：文件名默认英文，中文更贴切时可以用中文（如未来遇到某工具官方文档就是中文语境）；**但
本目录以及本目录下任何新建子目录，目录名必须永远用英文**（不含中文/特殊字符）。

| 工具/主题 | 文件 | 一句话症状 |
| :--- | :--- | :--- |
| bowtie2 / bowtie2-build | [bowtie2.md](bowtie2.md) | 本机 conda env 里没有能用的现代版本（没装 / 太老不支持 `--threads`），两个项目各踩一次 |
| nf-core/sarek | [sarek.md](sarek.md) | `--use_gatk_spark markduplicates` 净倒退+击穿 alignment cache；CNNScoreVariants 隐藏 CPU 大户内存限流管不住 |
| nf-core/mag | [nfcore_mag.md](nfcore_mag.md) | DASTool 精炼后 final bins 与 QC/分类报告跑在的原始 per-binner bins 命名不同、数量差 ~5.8 倍，不做名字映射会把基因组数报大近 6 倍 |
| Nextflow（现代 nf-core 模板） | [nextflow.md](nextflow.md) | 裸布尔 CLI flag 被新版 Nextflow 变成字符串 → nf-schema 校验全灭，`-profile test` 测不出；自定义 resource config 漏配某个通用 label（如 process_high）→ 该步骤悄悄吃官方默认值，并发被压低、负载虚低 |
| git（`.gitignore`） | [git.md](git.md) | 目录规则写成文件系统绝对路径（而非仓库根相对路径）时永远匹配不到，无任何报错；已跟踪文件还需额外 `git rm --cached` |
| `conda run` | [conda_run.md](conda_run.md) | 子进程隔离：进程替换 `<(...)` 失效 + 跨两次 `conda run` 管道 BrokenPipe + 复杂命令替换被搅乱 |
| conda 同名 env（不同前缀） | [conda_env_duplicate_names.md](conda_env_duplicate_names.md) | 两个不同路径下的 env 恰好同名（如 `DE_R45`）时 `conda run -n <name>` 解析错环境，悄悄换成别的 env 的解释器，缺包报错才暴露；改用绝对路径可执行文件即可 |
| tmux self-relaunch | [tmux.md](tmux.md) | `tee` 写日志的目录不存在时静默失败，日志文件永不产生，下游编排器 ~24h 后误报 FAILURE |
| HUMAnN ↔ MetaPhlAn | [humann_metaphlan.md](humann_metaphlan.md) | 版本兼容三连坑：version-check 解析崩 + db 代际不匹配 + 参数名不兼容，需 shim 脚本 |
| Positron / VS Code（fileWatcher） | [../IDE/Positron/5_high_CPU_rg_and_fileWatcher.md](../IDE/Positron/5_high_CPU_rg_and_fileWatcher.md) | workspace 挂了 references + 家目录后条目数 57 万 > inotify 上限 52 万，fileWatcher 常年吃满一个核；GTDB-Tk 静态 DB 一家占 30 万。另附 `top` 里 `rg` 高 CPU 是什么（ripgrep，正常短命进程） |

维护原则：
- 每条目先在这张表加一行，再建/更新对应文件。
- 一个坑如果已经在某篇 `reference_*` memory 里有详细记录，这里的文件版本保持精简（症状+修复+链接），
  不要把 memory 全文搬过来（single source of truth）。
- 同一个坑被不同项目重复踩到时，在对应文件里补一条"第 N 次踩坑"记录，而不是新开一个文件——这正是
  本目录存在的意义：让第二次踩坑的人先看到第一次的记录。
