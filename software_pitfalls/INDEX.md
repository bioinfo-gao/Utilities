# Software / Environment Pitfalls — Index

跨项目速查表：用某个工具前先扫一眼这里，避免重复踩坑。每个文件只写症状+根因+修复方式，详细的事故
记录/时间线仍在对应的 `reference_*`/`project_*` memory 里，这里不重复全文，只索引+链接。

新增条目时：文件名默认英文，中文更贴切时可以用中文（如未来遇到某工具官方文档就是中文语境）；**但
本目录以及本目录下任何新建子目录，目录名必须永远用英文**（不含中文/特殊字符）。

| 工具/主题 | 文件 | 一句话症状 |
| :--- | :---: | :---: |
| bowtie2 / bowtie2-build | [bowtie2.md](bowtie2.md) | 本机 conda env 里没有能用的现代版本（没装 / 太老不支持 `--threads`），两个项目各踩一次 |
| nf-core/sarek | [sarek.md](sarek.md) | `--use_gatk_spark markduplicates` 净倒退+击穿 alignment cache；CNNScoreVariants 隐藏 CPU 大户内存限流管不住 |
| nf-core/mag | [nfcore_mag.md](nfcore_mag.md) | DASTool 精炼后 final bins 与 QC/分类报告跑在的原始 per-binner bins 命名不同、数量差 ~5.8 倍，不做名字映射会把基因组数报大近 6 倍 |
| Nextflow（现代 nf-core 模板） | [nextflow.md](nextflow.md) | 裸布尔 CLI flag 被新版 Nextflow 变成字符串 → nf-schema 校验全灭，`-profile test` 测不出；自定义 resource config 漏配某个通用 label（如 process_high）→ 该步骤悄悄吃官方默认值，并发被压低、负载虚低 |
| git（`.gitignore`） | [git.md](git.md) | 两个静默失效：① 目录规则写成文件系统绝对路径（而非仓库根相对路径）时永远匹配不到，无任何报错，已跟踪文件还需额外 `git rm --cached`；② 仓库根的宽泛后缀规则（`*.yml`/`*.json`）无差别吃掉子项目**必需**的配置文件（`_quarto.yml` 等），`git status` 不提示，proj22/proj23 两次踩到 |
| fastp | [fastp.md](fastp.md) | 大文件跑到 ~99.5% 卡死且**三次停在同一输入位置**（wchan=futex + `/proc/io` 零变化）⇒ **既不是并发争用**（改串行照卡）**也不是输入损坏**（`gzip -t` 8/8 全通过后第三次仍卡死，2026-08-12 证伪）⇒ **根因在 fastp 1.3.3 自身**；确认输入完整后别再纠缠它——换显式 adapter/cutadapt，或先问这步是否必需（WGS 插入位点分析可不 trim）。⚠ 两个判据陷阱：`ps -o %cpu` 是生命周期均值会误导成"它在忙"；**`/proc/io` 零变化不能单独判卡死**（bwa-mem2 建索引同样零变化但 CPU ticks 满载）—— **ticks 才是"在算 vs 在等"的分界** |
| pysam | [pysam.md](pysam.md) | `count_coverage()` 在**比对黑洞**（着丝粒旁/卫星重复等）永久挂起：实测 `chr2:32.9M` 一个 1.1 kb 窗口里 ≥3,000,000 条读段 ≈ 401,000×，函数逐碱基建 4 条计数数组等于不返回；**不崩不报错不打日志、CPU 满载**，极像"在算大数据"。改用有上界的 `fetch()`（读满 cap 就返回 inf）。定位手段：`faulthandler.dump_traceback_later()`；⚠ 排查时 stdout 块缓冲会误导，必须 `-u` |
| LeafCutter | [leafcutter.md](leafcutter.md) | **别走 GitHub 源码装 R 包**——会连撞五层编译（rstan/DirichletMultinomial/TailRank-oompaBase 不在 CRAN/Makevars 缺 RcppParallel include/Stan 模型编译失败）。**bioconda 有 `leafcutter 2.0.3` 纯 Python 版，一条命令搞定**；根因是"某源没有此包"这种一行命令即可证伪的断言被凭印象写进了计划。另：`leafcutter-ds` 的 `-i` 参数语义与文档不符（源码拿它比**每组样本数**，默认 5 ⇒ n<5 直接抛错），且 p 值**只校准到 n=4** |
| DEXSeq | [dexseq.md](dexseq.md) | 两个静默失败：① 用 `match(rownames(res), rownames(se))` 从别的对象取 bin 计数 ⇒ 行名不是一套 ⇒ 整列 NA ⇒ read 阈值把**全部** bin 滤光，报"0 个显著"而**零报错**（实测真值是 9,301 个）；② `write.table(as.data.frame(DEXSeqResults))` 必崩于 list/matrix 列。配套：`saveRDS(dxd)` 要放在导出**之前**，崩了才能恢复而不重算 |
| decoupler 2.x | [decoupler.md](decoupler.md) | 1.x 的 `dc.get_*`/`dc.run_*` 全部移除，改 `dc.op.*`(资源)/`dc.mt.*`(方法)/`dc.pp.*`，net 统一 `source`/`target`/`weight`、`min_n`→`tmin`、第二个返回值**已是 BH 后的 padj**（再 multipletests 就是二次校正）。三个静默陷阱：① **`seed=0` 让置换检验彻底失效** —— `_ridx` 写的是 `if seed:`，0 是 falsy ⇒ 1000 次置换一次不打乱 ⇒ **NES 恒 ±1、p 恒 1、全不显著**，零报错且长得像"该数据无富集"的生物学结论（1.x 代码里 `seed=0` 极常见，移植必踩；判据=NES 全是 ±1 或 padj 唯一值只有 1）；② ORA 的 **`n_up` 是秩阈值不是个数**（取 top-k 要传 `nvar-k`，docstring 与实现不符），且 `empty=False` 必给、Fisher 改**双尾**故要加 `es>0` 才是富集；③ `dc.mt.*` 遇空 observation **返回新对象**而非原地写，下游按 obs_names 对齐会错位 |
| pertpy 1.0.3 | [pertpy.md](pertpy.md) | 两个静默陷阱：① **Augur 的 label 列必须是 `category` dtype** —— `load()` 只在 dtype=='category' 时才 LabelEncoder 成 0/1，object dtype 原样留字符串且**不报错**，直到 50×N 次子抽样后 sklearn 才抛 `pos_label=1 is not a valid label`（⇒ `np.where()` 造的标签一律包 `pd.Categorical()`）；② **pertpy 1.0.3 × sklearn ≥1.7 不兼容**（`_m_step() got an unexpected keyword argument 'xp'`），文内有不改 site-packages 的转发补丁 + 验证固定成分约束仍生效的办法。另：`labels=`→`pert_key=`；`papalexi_2021()` 的 `gene_target` 等在**顶层 mdata.obs**、不在 `mod['rna'].obs`，取回要 join 按 obs_names 不按位置 |
| squidpy `spatial_autocorr` | [squidpy.md](squidpy.md) | **p 值列在无变异基因上是未初始化内存**：`_p_value_calc` 用 `np.empty` 开数组后按 `z>0` / `z<=0` 两个掩码写入，基因在该切片无变异 ⇒ I=NaN ⇒ z=NaN ⇒ **两个掩码都不覆盖，那些元素永不被写入**。表现分两种、都很坏：拿到脏页 ⇒ `pval_norm=2.0000005`、`pval_norm_fdr_bh=-891.7` 这类**不可能的 p 值**且逐轮不同；拿到零页 ⇒ 全是 `0.0`，**看起来完全正常**，成为"最显著"的一批基因。随后 `multipletests` 对整列做 BH，把污染传给有效基因。proj37 实测 FDR<0.05 计数虚高 **20–40 倍**（15,690 → 710），且该数字曾被写进文档、解释成"检验功效极高"。修法=送检前剔除无变异基因 + `assert I.notna().all()`。判据=扫 `(p<0)|(p>1)`、两轮 diff 同一张表（统计量列相同而 p 值列不同）、搜 `np.empty(`。⚠ 置换 p 值 `pval_sim` 无此问题且 `seed=0` 有效 |
| Tangram | [tangram.md](tangram.md) | **`random_state=0` 等于没给种子** —— `mapping_optimizer.py` 写的是 `if self.random_state:`，0 是 falsy ⇒ `np.random.seed` / `torch.manual_seed` 整段跳过 ⇒ 去卷积**完全不可复现**：proj37 同参数两轮 spot 级比例最大差 **0.29 绝对比例**，零报错，且两轮都通过"和为 1、无负值"的硬断言。**与 decoupler 的 `if seed:` 是同一家族的第二次** ⇒ 见到 `seed`/`random_state` 先去源码搜 `if ` 再决定给不给 0。修法=另给非零种子并自己显式播种、CPU 上固定 `torch.set_num_threads`；⚠ 别把兼做参考下采样的那个种子一起改掉（会毁掉"RCTD 与 Tangram 同一份参考"的前提），拆成两个常量。另：Tangram **没有参考细胞数护栏**，15 个细胞的类型照跑照给比例（RCTD 直接拒绝），跑通 ≠ 可信 |
| joblib × OMP_NUM_THREADS | [joblib_nested_threads.md](joblib_nested_threads.md) | **「限流」被子进程乘出来**：设 `OMP_NUM_THREADS=28` 本意是单进程上限，joblib 起 28 个 loky worker 时每个都继承 28 ⇒ **784 线程、load average 99.5**（proj22 5-2 实测）。更坑的是 joblib 本来会把 worker 内层线程压到 1，**但只在用户没显式设 OMP_NUM_THREADS 时** —— 这行「限流」恰好关掉了它的保护。判据：`load average` 远大于 `n_jobs`，且 worker 的 `nlwp` ≈ OMP_NUM_THREADS。修法：`parallel_config(backend='loky', inner_max_num_threads=1).__enter__()`（**backend 必须显式给**），实测 224→8、784→28 |
| scVelo 0.3.4 / CellRank 2.0.7 × numpy 2 | [scvelo_cellrank_numpy2.md](scvelo_cellrank_numpy2.md) | 四层四个坑（proj22 05 章实测）：① `filter_and_normalize` **删了 `n_top_genes` 且 docstring 骗人——实现里没有 log1p**，不自己补则 PCA 在未取对数数据上做且零报错；② scvelo `leastsq_generalized` 把 (1,) 数组塞标量槽 ⇒ numpy 2 报错、stochastic 模式全废，**打补丁时 `from scvelo.tools import velocity` 拿到的是同名函数不是模块 ⇒ 挂属性等于没打，回读还读得出来（假通过）**，必须走 sys.modules + 查 `co_filename`；③ cellrank 用 `assert_array_equal(x=,y=)`（numpy 2 已改名 actual/desired），且**绘图方法不收 `ax`/`show`** ⇒ 拼不进 subplot；④ **`Lineage` 存不进 h5ad**（anndata 0.12 的 write_basic 不收 `elem=`）⇒ 全算完最后一步丢光，保存前转 ndarray。另：GPCCA 会静默上调 `n_states`（请求 7→实际 8），PETSc `Broken Pipe`/`MPI_Abort` 是噪音不是失败 |
| MAJIQ | [majiq.md](majiq.md) | 安装六层根因链（build isolation → 缺 PEP517 后端 → `cmake.verbose` 被 scikit-build-core≥0.10 拒 → 缺 `setuptools_scm` → pybind11 3.x 不兼容 → numpy 编译期/运行期不一致）；**`--no-build-isolation` 时每个构建期依赖都要自备且一次只报一个**，且**别把 pip 输出接 `tail -N`**（根因行会被截掉）。**3.x 的 CLI 与网上 2.x 教程完全不同**：config 从 .ini 改 TSV，多出 `psi-coverage` 中间步 |
| mosdepth（深度计数口径） | [mosdepth.md](mosdepth.md) | **深度类结论的口径全在这里**：`-F` 默认 1796 = 排除 unmap/secondary/qcfail/**dup**，但 **supplementary(2048) 默认计入**（整合位点/SV 断点处会给断点另一侧多加 1×，需 `-F 3844`）；`-Q` 默认 **0**（MAPQ0 多比对全收）；**"默认去重"只是遵守 `0x400` flag，BAM 没跑过 markdup 就是空操作且零报错** ⇒ 判据是 `samtools view -c -f 1024` 而非"我用了默认参数"；默认做 **mate-overlap 校正**（重叠 = `max(0, 2R−L)`，PE150+insert 250 时该片段 16.7% 碱基被双计，**偏差跟着文库插入片段走、样本间不抵消**）；`-x/--fast-mode` 会**同时**关掉 CIGAR 解析（⇒ intron/deletion 被算成 covered，RNA-seq 灾难）与重叠校正；`-a/--fragment-mode` 是第三种语义（连没测到的 insert 也算 covered），变异证据一律不能用 |
| mosdepth vs `samtools depth` | [mosdepth_vs_samtools_depth.md](mosdepth_vs_samtools_depth.md) | 同 BAM 同区间同 MAPQ，两者深度差可达 19%：mosdepth 默认做 **mate-overlap 校正**（重叠段计一次），samtools depth 不做（计两次），`mosdepth --fast-mode` 关掉校正后两者完全吻合。**危险在于偏差跟着文库插入片段走**，会凭空造出一个长得像真实生物学差异的假差异 —— 分子分母必须同工具同口径 |
| DELLY | [delly.md](delly.md) | v2 把短读 SV 的 `call` 子命令改名为 **`sr`**，旧命令只回一行 "Unrecognized command call" 并非零退出；若调用处写成 `\|\| echo` 就会**静默吞掉**，编排链照常显示 "Step 7 OK" 而零 BCF 产出。退出码 0 ≠ 产物存在，必须补存在性断言 + "产物数==样本数"收尾断言 |
| `find` 与符号链接 | [find_symlink.md](find_symlink.md) | **入口目录本身是软链时 `find` 默认不进去，静默返回空且退出码 0**，与"真的没有"完全无法区分。2026-08-29 实测：对 `/home/gao/projects_2026M7`（→ `/mnt/ex_8T_SSD/...`）连扫三次 work/、sorted.bam、fastq **全空**，而实际有 **2.92 TiB 的 Nextflow work/** 与 25 GiB 冗余 BAM，几乎据此答复"没有可回收的东西"。⚠ 同一目录 `du -sh <link>/*/` 却正常出结果（glob 展开已跟随）⇒ 两个命令给出互相矛盾的答案。修法：真实路径 / 末尾加 `/` / `find -L`（后者会跟随树内所有软链，慎用） |
| awk | [awk.md](awk.md) | pattern 与 `{action}` 之间**换行**会被解析成两条独立规则（pattern 单独 → 默认打印整行；action 单独 → 每行都执行），**过滤条件彻底失效且零报错**，输出格式还完全正常。P29 因此把接头读段数虚报 20–30 倍并据此下了结论 |
| openpyxl / `.xlsx` 富文本 | [openpyxl_xlsx_richtext.md](openpyxl_xlsx_richtext.md) | `cell.value` 把 rich text 拍平、**丢掉每个 run 的字体颜色**；客户若用"把模板句里适用的词染成红色"的方式作答（送样单/注册表极常见），读到的字符串与模板逐字相同 ⇒ 误判成"客户什么都没填"，零报错。必须解 `sharedStrings.xml` 逐 run 读色；附带判据：si 索引靠后的单元格 = 客户编辑过的 |
| `conda run` | [conda_run.md](conda_run.md) | 子进程隔离：进程替换 `<(...)` 失效 + 跨两次 `conda run` 管道 BrokenPipe + 复杂命令替换被搅乱 + **`python - <<EOF` 读不到 stdin：零输出、零报错、exit=0**，会被误读成"检查通过" |
| conda 上建 R 环境 / 无人值守构建 | [conda_r_env_build.md](conda_r_env_build.md) | **`mamba env create` 弹 `Confirm changes: [Y/n]`，无人值守脚本静默停摆**，而 `tail 日志` **看不见**那行 prompt（不带换行、被 `tee` 黏在行尾），只有 `tmux capture-pane` 看得见 —— 实测空等 28 分钟；**yaml 只写 R 包不写它链接的 C 库** ⇒ GitHub 源码编译的包 `configure` 必败（BPCells←libhdf5、magick←Magick++），且**一个缺失 C 库连带打掉一串**（magick→Banksy→SeuratWrappers，5 条 ERROR 实为 2 个根因，数条数会高估规模）；**env 隔离挡得住版本冲突也挡得住共享依赖**（SpatialExperiment 在 `spatial_r` 有、`sc_tut_r` 没有）；**修完 env 必须回填 yaml**，否则下次重建原样再失败一次；**§2f：配方只保证 `library(X)` 能加载、不保证 X 的函数能调用**（`metap` 之于 `FindConservedMarkers`、`scrapper` 之于 SingleR 2.12 —— 逐包 `library()` 验证全绿，跑到第 10 / 12 章才炸，前面的算力全白花）⇒ 验证清单要覆盖「会被调用的东西」而不只是「会被 library 的东西」 |
| conda 版 Quarto | [quarto_conda.md](quarto_conda.md) | **不走 `conda activate` 就找不到 deno**，渲染第 1 章即死：`bin/quarto` 在没有 `QUARTO_DENO` 时回退到官方 tarball 布局 `bin/tools/x86_64/deno`，而 conda 把 deno 装在 `bin/deno`、位置只由激活钩子 `activate.d/quarto.sh` 告知 —— 于是**为躲「同名 env 解析错解释器」而刻意不 activate 的讲究写法，恰好踩这个**。修法=显式重放钩子的 9 个变量；⚠ **`QUARTO_DENO_DOM` 不能照抄钩子**（配方 bug，写的是构建机路径 `/home/conda/feedstock_root/...`），真插件在 `$ENV/lib/deno_dom.so`，抄了会在 HTML 后处理阶段再炸一次 |
| R `download.file` / `options(timeout)` | [r_download_timeout.md](r_download_timeout.md) | **默认 60 秒是总时长上限且不续传** ⇒ 任何 >100 MiB 的参考永远下不完（实测同一 411 MiB 文件三次断在 278/36/38 MiB）。**最坑的是报错指向错方向**：`SeuratData::InstallData()` 超时后报的是 `there is no package called 'bonemarrowref.SeuratData'`，照这句去查会怀疑仓库没这个包。判据=往上翻找 `downloaded length ... != reported length`。修法=`options(timeout = 3600)`，**每个不 source 公共工具的内联 `Rscript -e` 都要各写一遍**；手工补救用 `curl -C -` 续传后本地装 |
| Seurat 5 / SingleR / Azimuth / ProjecTILs | [seurat5_and_refmapping.md](seurat5_and_refmapping.md) | **`ProjecTILs::load.reference.map()` 不带参数拿到的是【小鼠】图谱**（函数体硬编码 `ref_TILAtlas_mouse_v1.rds`），用在人数据上跑得通、不报错、结论错，日志里只有一行文件名 —— proj23 里旁边那句「默认下载 human TIL atlas」的注释存在了 49 天没人怀疑。人类参考必须 `get.reference.maps(collection="human", reference="CD8")` 显式点名，且 **CD8 图谱不覆盖 CD4/NK**，被过滤掉的那部分不能读成「状态谱不重叠」。另三条：**样本名 `_`→`-` 的正向变换不可逆**（`gsub("-","_")` 反解把 `ETV6-RUNX1-1` 变成 `ETV6_RUNX1_1`，6 个样本 3 个静默变 NA，且恰好是全部 CASE 样本）；**`FastMNNIntegration` 在 SeuratWrappers 不在 Seurat**（且在前三种整合方法跑完之后才报）；**attach 一个包不会带出它 Imports 的泛型**（`library(miloR)` 后 `exists("colData")` 仍是 FALSE） |
| R 出 PDF 与中文 | [r_pdf_cjk.md](r_pdf_cjk.md) | **`ggsave()` 默认 pdf 设备不支持 CJK**：每个汉字报一条 `conversion failure ... in 'mbcsToSbcs'`，**图照出、中文标题/图例变成一串点**。致命之处在于**只看网页发现不了** —— knitr 给 HTML 出图用 cairo png（中文正常），只有写交付 PDF 时才走默认 pdf 设备，而「交付只要 PDF」的项目坏的恰好是唯一交出去的那份（proj23 实测 46/46 张中招）。修法=`device = grDevices::cairo_pdf`；判据=`grep -c mbcsToSbcs` 必须为 0 + 转一页 PNG 用眼睛看 |
| conda 同名 env（不同前缀） | [conda_env_duplicate_names.md](conda_env_duplicate_names.md) | 两个不同路径下的 env 恰好同名（如 `DE_R45`）时 `conda run -n <name>` 解析错环境，悄悄换成别的 env 的解释器，缺包报错才暴露；改用绝对路径可执行文件即可 |
| figshare 下载 | [figshare_download.md](figshare_download.md) | `figshare.com/ndownloader/files/<id>` 被 AWS WAF 挡：返回 **`202` + `x-amzn-waf-action: challenge` + `content-length: 0`**，不是 4xx/5xx ⇒ `urllib` **不抛异常**、静默得到 **0 字节**文件，极像网络不稳；换 UA 无效（变 403 挑战页）。改用 `ndownloader.figshare.com/files/<id>` 或 `api.figshare.com/v2/file/download/<id>`（实测 206 真数据）；`api.figshare.com/v2/articles/<id>/files` 还顺带给官方 md5 |
| matplotlib 中文字体 | [matplotlib_cjk_font.md](matplotlib_cjk_font.md) | 默认 `sans-serif`=DejaVu Sans **无 CJK 字形** ⇒ 图内中文静默渲染成**方框**（只在 stderr 留一行 `Glyph … missing from font`，且方框是渲染时就烤进 PNG/PDF 的，只能重跑）。三个反直觉点：① **`font.sans-serif` 列表不做逐字形回退**（中文字体排第二位 = 完全无效、告警还只提第一个字体），**回退只在 `font.family` 写成具体字体名列表时才发生**；② 缺字形告警走 **`warnings` 模块不走 logger**，用 logging handler 抓 ⇒ **恒为 0 的假通过检测器**（检测器必须先证明能报真阳性）；③ 系统装了 ≠ matplotlib 看得到（字体缓存要删）；④ **字体设置写在被 import 的共享模块里时，改文件对已活着的 kernel 完全无效**（`sys.modules` 缓存，只重跑 cell 仍是方框，实测 8 条告警不变）⇒ 修复方在新进程里验证必然通过、用户会话照样坏，**判据是让 setup 把字体名打进环境指纹**。**别抄 `SimHei`**（Linux 没有，找不到时静默回退 DejaVu）；Noto Sans CJK SC 含 U+2212 ⇒ **不需要** `axes.unicode_minus=False` |
| Python stdout 缓冲 / 行尾符 | [python_stdout_and_newlines.md](python_stdout_and_newlines.md) | 两个安静的坑：① `python x.py \| tee log` 时 stdout 变**块缓冲**，日志与 tmux 面板**全空**，进程活着却判断不了死活 ⇒ 一律加 **`-u`**；② `pathlib.read_text()/write_text()` 把 **CRLF 规范化成 LF**，只替换 14 处却产生 23 行 diff，无关变更混进提交 ⇒ 改用 `read_bytes()/write_bytes()`，**判据：替换 N 处就该只有 N 行 diff** |
| harmonypy × scanpy | [harmonypy_scanpy_transpose.md](harmonypy_scanpy_transpose.md) | harmonypy **2.0.0** 把 `Z_corr` 的方向改成 `(cells × PCs)`，scanpy 1.11.5 的 `sce.pp.harmony_integrate` 仍再转置一次 ⇒ 往 `obsm` 写 `(n_PCs, n_cells)` 直接 `ValueError`。两处误导：**日志已打印 `Converged`**（算完了，炸在赋值，别回头调参数）；**anndata 形状报错只打印第 0 轴**，`Value had shape (30,)` 不是一维数组。修调用方别修 site-packages；删 `import ... as sce` 前先 grep `sce.`，`py_compile` 抓不到漏删 |
| torch × Lightning × 驱动 | [torch_lightning_cuda_driver.md](torch_lightning_cuda_driver.md) | **`train(accelerator="cpu")` 拦不住 CUDA 初始化**：崩点在 Lightning 训练前收 RNG 状态那一步（`seed.py:146`，只看 `is_available()` 不看 accelerator）。枢纽是 **`import lightning` 会设 `PYTORCH_NVML_BASED_CUDA_CHECK=1`**，探测改走 NVML ⇒ `is_available()` 由**正确的 False 翻成错误的 True** （驱动 535/CUDA 12.2 配 torch cu130）。**同一台机器上裸 torch 测得 False 不能推断 scvi 进程里也是 False。** 解法 `CUDA_VISIBLE_DEVICES=""`（import 之后设也有效，kernel 不必重启），不是重装 torch |
| tmux self-relaunch | [tmux.md](tmux.md) | `tee` 写日志的目录不存在时静默失败，日志文件永不产生，下游编排器 ~24h 后误报 FAILURE |
| HUMAnN ↔ MetaPhlAn | [humann_metaphlan.md](humann_metaphlan.md) | 版本兼容三连坑：version-check 解析崩 + db 代际不匹配 + 参数名不兼容，需 shim 脚本 |
| Nextflow `work/` 磁盘占用 | [../Server/nextflow_pipeline/磁盘回收_三方案实证对比_projects_2026H1_0729.md](../Server/nextflow_pipeline/磁盘回收_三方案实证对比_projects_2026H1_0729.md) | 磁盘满时压缩几乎无效（5.5T 里 87% 是 BAM/fastq.gz 已压缩格式，整压只省 ~8%）；真正占地方的是 Nextflow `work/`（占 87%，其中 BAM+fastq 的 89% 都在 work 下）。**第一动作永远是删 work/，不是压缩**；用 `reclaim_nextflow_work_dirs.sh`。附带坑：进程存活检测的 grep 太宽会匹配到检测脚本自己的路径 |
| Positron / VS Code（fileWatcher） | [../IDE/Positron/5_high_CPU_rg_and_fileWatcher.md](../IDE/Positron/5_high_CPU_rg_and_fileWatcher.md) | workspace 挂了 references + 家目录后条目数 57 万 > inotify 上限 52 万，fileWatcher 常年吃满一个核；GTDB-Tk 静态 DB 一家占 30 万。另附 `top` 里 `rg` 高 CPU 是什么（ripgrep，正常短命进程） |
| gnomAD / bcftools annotate | [gnomad_af_only_rarity.md](gnomad_af_only_rarity.md) | 用 2017 年 hg19-liftover 的 `af-only-gnomad` 当"是否在 gnomAD"的判据，且把 `absent` 当 `rare` ⇒ **已交付候选名单里约一半是常见多态**；零报错、退出码 0、表格全对 |

## 横向索引：「各自版本都对，组合起来不能用」

本目录已有 **4 条**属于同一类。**它们不合并成一个文件**——文件名是症状检索键，
泛化命名会让第二次踩坑的人查不到。这里只做横向串联。

| 条目 | 组合里是谁改了 | 表现 |
| :--- | :---: | :---: |
| [harmonypy × scanpy](harmonypy_scanpy_transpose.md) | **被包装库**改了面向用户属性的方向约定，wrapper 落后 | 大声报错（`ValueError`），但报错信息指向赋值不指向版本 |
| [torch × Lightning × 驱动](torch_lightning_cuda_driver.md) | **第三方库**改了探测行为（设 `PYTORCH_NVML_BASED_CUDA_CHECK`） | 把**正确的 False 翻成错误的 True**，再在无关的一帧崩掉 |
| [HUMAnN ↔ MetaPhlAn](humann_metaphlan.md) | 两边各自升级，db 代际与参数名脱节 | 三连坑，需 shim |
| [conda 上建 R 环境](conda_r_env_build.md) | yaml 只声明 R 包、不声明它链接的 C 库 | 源码编译 `configure` 必败，且一个缺失 C 库连带打掉一串 |

**共同判据（四条都适用）：**

1. **"两边各自的版本都是对的"不构成"组合能用"。** 包做大版本重写时最常见的破坏性改动就是
   **面向用户的约定**（数据方向、环境变量、默认行为），而下游 wrapper 往往落后半年；
2. **看完整 traceback 的最后几帧，别只看自己写的那一行** —— 关键帧通常在第三方库里；
3. **修调用方，不修 site-packages** —— 后者不可复现，且下次 `mamba update` 就冲掉；
4. **策略变量拦不住第三方库。** "本项目不用 GPU"写成一个给各章读的布尔量是没有约束力的，
   必须落成**进程事实**（环境变量）才拦得住别的库自己去初始化。

> **⚠ 与下面「维护原则」第 3 条的区别**：那条说的是**同一个坑**重复踩到 ⇒ 补记到同一文件；
> 本节说的是**不同的坑属于同一类** ⇒ 各自留文件，只在这里横向串联。**两者不要混。**

维护原则：
- 每条目先在这张表加一行，再建/更新对应文件。
- 一个坑如果已经在某篇 `reference_*` memory 里有详细记录，这里的文件版本保持精简（症状+修复+链接），
  不要把 memory 全文搬过来（single source of truth）。
- 同一个坑被不同项目重复踩到时，在对应文件里补一条"第 N 次踩坑"记录，而不是新开一个文件——这正是
  本目录存在的意义：让第二次踩坑的人先看到第一次的记录。
