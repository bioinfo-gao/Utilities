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
| git（`.gitignore`） | [git.md](git.md) | 两个静默失效：① 目录规则写成文件系统绝对路径（而非仓库根相对路径）时永远匹配不到，无任何报错，已跟踪文件还需额外 `git rm --cached`；② 仓库根的宽泛后缀规则（`*.yml`/`*.json`）无差别吃掉子项目**必需**的配置文件（`_quarto.yml` 等），`git status` 不提示，proj22/proj23 两次踩到 |
| fastp | [fastp.md](fastp.md) | 大文件跑到 ~99.5% 卡死且**三次停在同一输入位置**（wchan=futex + `/proc/io` 零变化）⇒ **既不是并发争用**（改串行照卡）**也不是输入损坏**（`gzip -t` 8/8 全通过后第三次仍卡死，2026-08-12 证伪）⇒ **根因在 fastp 1.3.3 自身**；确认输入完整后别再纠缠它——换显式 adapter/cutadapt，或先问这步是否必需（WGS 插入位点分析可不 trim）。⚠ 两个判据陷阱：`ps -o %cpu` 是生命周期均值会误导成"它在忙"；**`/proc/io` 零变化不能单独判卡死**（bwa-mem2 建索引同样零变化但 CPU ticks 满载）—— **ticks 才是"在算 vs 在等"的分界** |
| mosdepth vs `samtools depth` | [mosdepth_vs_samtools_depth.md](mosdepth_vs_samtools_depth.md) | 同 BAM 同区间同 MAPQ，两者深度差可达 19%：mosdepth 默认做 **mate-overlap 校正**（重叠段计一次），samtools depth 不做（计两次），`mosdepth --fast-mode` 关掉校正后两者完全吻合。**危险在于偏差跟着文库插入片段走**，会凭空造出一个长得像真实生物学差异的假差异 —— 分子分母必须同工具同口径 |
| DELLY | [delly.md](delly.md) | v2 把短读 SV 的 `call` 子命令改名为 **`sr`**，旧命令只回一行 "Unrecognized command call" 并非零退出；若调用处写成 `\|\| echo` 就会**静默吞掉**，编排链照常显示 "Step 7 OK" 而零 BCF 产出。退出码 0 ≠ 产物存在，必须补存在性断言 + "产物数==样本数"收尾断言 |
| awk | [awk.md](awk.md) | pattern 与 `{action}` 之间**换行**会被解析成两条独立规则（pattern 单独 → 默认打印整行；action 单独 → 每行都执行），**过滤条件彻底失效且零报错**，输出格式还完全正常。P29 因此把接头读段数虚报 20–30 倍并据此下了结论 |
| `conda run` | [conda_run.md](conda_run.md) | 子进程隔离：进程替换 `<(...)` 失效 + 跨两次 `conda run` 管道 BrokenPipe + 复杂命令替换被搅乱 |
| conda 同名 env（不同前缀） | [conda_env_duplicate_names.md](conda_env_duplicate_names.md) | 两个不同路径下的 env 恰好同名（如 `DE_R45`）时 `conda run -n <name>` 解析错环境，悄悄换成别的 env 的解释器，缺包报错才暴露；改用绝对路径可执行文件即可 |
| tmux self-relaunch | [tmux.md](tmux.md) | `tee` 写日志的目录不存在时静默失败，日志文件永不产生，下游编排器 ~24h 后误报 FAILURE |
| HUMAnN ↔ MetaPhlAn | [humann_metaphlan.md](humann_metaphlan.md) | 版本兼容三连坑：version-check 解析崩 + db 代际不匹配 + 参数名不兼容，需 shim 脚本 |
| Nextflow `work/` 磁盘占用 | [../Server/nextflow_pipeline/磁盘回收_三方案实证对比_projects_2026H1_0729.md](../Server/nextflow_pipeline/磁盘回收_三方案实证对比_projects_2026H1_0729.md) | 磁盘满时压缩几乎无效（5.5T 里 87% 是 BAM/fastq.gz 已压缩格式，整压只省 ~8%）；真正占地方的是 Nextflow `work/`（占 87%，其中 BAM+fastq 的 89% 都在 work 下）。**第一动作永远是删 work/，不是压缩**；用 `reclaim_nextflow_work_dirs.sh`。附带坑：进程存活检测的 grep 太宽会匹配到检测脚本自己的路径 |
| Positron / VS Code（fileWatcher） | [../IDE/Positron/5_high_CPU_rg_and_fileWatcher.md](../IDE/Positron/5_high_CPU_rg_and_fileWatcher.md) | workspace 挂了 references + 家目录后条目数 57 万 > inotify 上限 52 万，fileWatcher 常年吃满一个核；GTDB-Tk 静态 DB 一家占 30 万。另附 `top` 里 `rg` 高 CPU 是什么（ripgrep，正常短命进程） |

维护原则：
- 每条目先在这张表加一行，再建/更新对应文件。
- 一个坑如果已经在某篇 `reference_*` memory 里有详细记录，这里的文件版本保持精简（症状+修复+链接），
  不要把 memory 全文搬过来（single source of truth）。
- 同一个坑被不同项目重复踩到时，在对应文件里补一条"第 N 次踩坑"记录，而不是新开一个文件——这正是
  本目录存在的意义：让第二次踩坑的人先看到第一次的记录。
