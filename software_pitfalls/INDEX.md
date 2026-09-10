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
| pysam | [pysam.md](pysam.md) | `count_coverage()` 在**比对黑洞**（着丝粒旁/卫星重复等）永久挂起：实测 `chr2:32.9M` 一个 1.1 kb 窗口里 ≥3,000,000 条读段 ≈ 401,000×，函数逐碱基建 4 条计数数组等于不返回；**不崩不报错不打日志、CPU 满载**，极像"在算大数据"。改用有上界的 `fetch()`（读满 cap 就返回 inf）。定位手段：`faulthandler.dump_traceback_later()`；⚠ 排查时 stdout 块缓冲会误导，必须 `-u` |
| LeafCutter | [leafcutter.md](leafcutter.md) | **别走 GitHub 源码装 R 包**——会连撞五层编译（rstan/DirichletMultinomial/TailRank-oompaBase 不在 CRAN/Makevars 缺 RcppParallel include/Stan 模型编译失败）。**bioconda 有 `leafcutter 2.0.3` 纯 Python 版，一条命令搞定**；根因是"某源没有此包"这种一行命令即可证伪的断言被凭印象写进了计划。另：`leafcutter-ds` 的 `-i` 参数语义与文档不符（源码拿它比**每组样本数**，默认 5 ⇒ n<5 直接抛错），且 p 值**只校准到 n=4** |
| DEXSeq | [dexseq.md](dexseq.md) | 两个静默失败：① 用 `match(rownames(res), rownames(se))` 从别的对象取 bin 计数 ⇒ 行名不是一套 ⇒ 整列 NA ⇒ read 阈值把**全部** bin 滤光，报"0 个显著"而**零报错**（实测真值是 9,301 个）；② `write.table(as.data.frame(DEXSeqResults))` 必崩于 list/matrix 列。配套：`saveRDS(dxd)` 要放在导出**之前**，崩了才能恢复而不重算 |
| MAJIQ | [majiq.md](majiq.md) | 安装六层根因链（build isolation → 缺 PEP517 后端 → `cmake.verbose` 被 scikit-build-core≥0.10 拒 → 缺 `setuptools_scm` → pybind11 3.x 不兼容 → numpy 编译期/运行期不一致）；**`--no-build-isolation` 时每个构建期依赖都要自备且一次只报一个**，且**别把 pip 输出接 `tail -N`**（根因行会被截掉）。**3.x 的 CLI 与网上 2.x 教程完全不同**：config 从 .ini 改 TSV，多出 `psi-coverage` 中间步 |
| mosdepth（深度计数口径） | [mosdepth.md](mosdepth.md) | **深度类结论的口径全在这里**：`-F` 默认 1796 = 排除 unmap/secondary/qcfail/**dup**，但 **supplementary(2048) 默认计入**（整合位点/SV 断点处会给断点另一侧多加 1×，需 `-F 3844`）；`-Q` 默认 **0**（MAPQ0 多比对全收）；**"默认去重"只是遵守 `0x400` flag，BAM 没跑过 markdup 就是空操作且零报错** ⇒ 判据是 `samtools view -c -f 1024` 而非"我用了默认参数"；默认做 **mate-overlap 校正**（重叠 = `max(0, 2R−L)`，PE150+insert 250 时该片段 16.7% 碱基被双计，**偏差跟着文库插入片段走、样本间不抵消**）；`-x/--fast-mode` 会**同时**关掉 CIGAR 解析（⇒ intron/deletion 被算成 covered，RNA-seq 灾难）与重叠校正；`-a/--fragment-mode` 是第三种语义（连没测到的 insert 也算 covered），变异证据一律不能用 |
| mosdepth vs `samtools depth` | [mosdepth_vs_samtools_depth.md](mosdepth_vs_samtools_depth.md) | 同 BAM 同区间同 MAPQ，两者深度差可达 19%：mosdepth 默认做 **mate-overlap 校正**（重叠段计一次），samtools depth 不做（计两次），`mosdepth --fast-mode` 关掉校正后两者完全吻合。**危险在于偏差跟着文库插入片段走**，会凭空造出一个长得像真实生物学差异的假差异 —— 分子分母必须同工具同口径 |
| DELLY | [delly.md](delly.md) | v2 把短读 SV 的 `call` 子命令改名为 **`sr`**，旧命令只回一行 "Unrecognized command call" 并非零退出；若调用处写成 `\|\| echo` 就会**静默吞掉**，编排链照常显示 "Step 7 OK" 而零 BCF 产出。退出码 0 ≠ 产物存在，必须补存在性断言 + "产物数==样本数"收尾断言 |
| `find` 与符号链接 | [find_symlink.md](find_symlink.md) | **入口目录本身是软链时 `find` 默认不进去，静默返回空且退出码 0**，与"真的没有"完全无法区分。2026-08-29 实测：对 `/home/gao/projects_2026M7`（→ `/mnt/ex_8T_SSD/...`）连扫三次 work/、sorted.bam、fastq **全空**，而实际有 **2.92 TiB 的 Nextflow work/** 与 25 GiB 冗余 BAM，几乎据此答复"没有可回收的东西"。⚠ 同一目录 `du -sh <link>/*/` 却正常出结果（glob 展开已跟随）⇒ 两个命令给出互相矛盾的答案。修法：真实路径 / 末尾加 `/` / `find -L`（后者会跟随树内所有软链，慎用） |
| awk | [awk.md](awk.md) | pattern 与 `{action}` 之间**换行**会被解析成两条独立规则（pattern 单独 → 默认打印整行；action 单独 → 每行都执行），**过滤条件彻底失效且零报错**，输出格式还完全正常。P29 因此把接头读段数虚报 20–30 倍并据此下了结论 |
| openpyxl / `.xlsx` 富文本 | [openpyxl_xlsx_richtext.md](openpyxl_xlsx_richtext.md) | `cell.value` 把 rich text 拍平、**丢掉每个 run 的字体颜色**；客户若用"把模板句里适用的词染成红色"的方式作答（送样单/注册表极常见），读到的字符串与模板逐字相同 ⇒ 误判成"客户什么都没填"，零报错。必须解 `sharedStrings.xml` 逐 run 读色；附带判据：si 索引靠后的单元格 = 客户编辑过的 |
| `conda run` | [conda_run.md](conda_run.md) | 子进程隔离：进程替换 `<(...)` 失效 + 跨两次 `conda run` 管道 BrokenPipe + 复杂命令替换被搅乱 + **`python - <<EOF` 读不到 stdin：零输出、零报错、exit=0**，会被误读成"检查通过" |
| conda 同名 env（不同前缀） | [conda_env_duplicate_names.md](conda_env_duplicate_names.md) | 两个不同路径下的 env 恰好同名（如 `DE_R45`）时 `conda run -n <name>` 解析错环境，悄悄换成别的 env 的解释器，缺包报错才暴露；改用绝对路径可执行文件即可 |
| figshare 下载 | [figshare_download.md](figshare_download.md) | `figshare.com/ndownloader/files/<id>` 被 AWS WAF 挡：返回 **`202` + `x-amzn-waf-action: challenge` + `content-length: 0`**，不是 4xx/5xx ⇒ `urllib` **不抛异常**、静默得到 **0 字节**文件，极像网络不稳；换 UA 无效（变 403 挑战页）。改用 `ndownloader.figshare.com/files/<id>` 或 `api.figshare.com/v2/file/download/<id>`（实测 206 真数据）；`api.figshare.com/v2/articles/<id>/files` 还顺带给官方 md5 |
| matplotlib 中文字体 | [matplotlib_cjk_font.md](matplotlib_cjk_font.md) | 默认 `sans-serif`=DejaVu Sans **无 CJK 字形** ⇒ 图内中文静默渲染成**方框**（只在 stderr 留一行 `Glyph … missing from font`，且方框是渲染时就烤进 PNG/PDF 的，只能重跑）。三个反直觉点：① **`font.sans-serif` 列表不做逐字形回退**（中文字体排第二位 = 完全无效、告警还只提第一个字体），**回退只在 `font.family` 写成具体字体名列表时才发生**；② 缺字形告警走 **`warnings` 模块不走 logger**，用 logging handler 抓 ⇒ **恒为 0 的假通过检测器**（检测器必须先证明能报真阳性）；③ 系统装了 ≠ matplotlib 看得到（字体缓存要删）；④ **字体设置写在被 import 的共享模块里时，改文件对已活着的 kernel 完全无效**（`sys.modules` 缓存，只重跑 cell 仍是方框，实测 8 条告警不变）⇒ 修复方在新进程里验证必然通过、用户会话照样坏，**判据是让 setup 把字体名打进环境指纹**。**别抄 `SimHei`**（Linux 没有，找不到时静默回退 DejaVu）；Noto Sans CJK SC 含 U+2212 ⇒ **不需要** `axes.unicode_minus=False` |
| Python stdout 缓冲 / 行尾符 | [python_stdout_and_newlines.md](python_stdout_and_newlines.md) | 两个安静的坑：① `python x.py \| tee log` 时 stdout 变**块缓冲**，日志与 tmux 面板**全空**，进程活着却判断不了死活 ⇒ 一律加 **`-u`**；② `pathlib.read_text()/write_text()` 把 **CRLF 规范化成 LF**，只替换 14 处却产生 23 行 diff，无关变更混进提交 ⇒ 改用 `read_bytes()/write_bytes()`，**判据：替换 N 处就该只有 N 行 diff** |
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
