# mosdepth —— 深度计数的口径：默认参数、去重、配对重叠校正

**「去重 + 配对重叠校正（mosdepth 默认）」一句话解释** —— 这是一个**深度口径**说明，
由两个互相独立的校正组成，两个都是 mosdepth **不加任何参数就会做**的事：

- **去重**：丢掉同一个文库分子被 **PCR 扩增**出的多份拷贝。
  mosdepth **只是遵守 BAM 里的 `0x400` flag**（`-F` 默认 1796 含它），**它自己不做 markdup**。
- **配对重叠校正**：一对 PE read 在参考基因组上**重叠的那一段只计一次**
  （`overlap = max(0, 2R − L)`；重叠段来自同一个物理 DNA 分子）。

合起来回答同一个问题：**「这个位点我有几次*独立*观测？」**
两者都不做，depth 就不是独立观测数，而是被夸大的 n —— 拷贝数、VAF、断点证据强度全都建立在它上面。

**⚠ 写在 Methods 里 ≠ 它真的生效了**：BAM 若从未跑过 markdup，"去重"就是空操作、零报错
（判据 `samtools view -c -f 1024`）。展开见 [§0](#0-基本解释去重--配对重叠校正mosdepth-默认这句话说了什么)–[§4](#4-怎么验证这两件事在你的-bam-上真的生效了)。

**参考文档的位置**

| 要找什么 | 在哪 |
| :--- | :--- |
| **本文**（机制、全部默认值、验证命令、跨工具对照） | `/home/gao/Utilities/software_pitfalls/mosdepth.md` · 已在同目录 [`INDEX.md`](INDEX.md) 索引 |
| 实测事故与数字（P29 上 11–19% 假差异） | [`mosdepth_vs_samtools_depth.md`](mosdepth_vs_samtools_depth.md)（同目录） |
| **本机可离线核对的权威出处**（本文每个默认值的来源） | `mosdepth --help` / `man samtools-depth` / `bcftools mpileup` —— 见 [§7.1](#71-本机可离线核对本文所有默认值的实际出处) |
| **上游权威文档**（GitHub README / 论文 / htslib 手册 / SAM 规范） | 见 [§7.2](#72-上游权威文档) |

---

> 本文讲**机制与口径参数**（一个碱基位点上到底算了几次观测）；
> **实测事故与具体数字**放在姊妹篇，此处不重复（两者位置见上表）。
>
> 版本基准：本机 `regular_bioinfo` 环境，**mosdepth 0.3.14** / **samtools 1.23.1** /
> **bcftools 1.23.1**（2026-08-27 实测 `--help`）。⚠ 下面的默认值**是版本相关的**，
> 换机器/换环境前重跑一次 `--help` 再引用。

---

## 0. 基本解释：「去重 + 配对重叠校正（mosdepth 默认）」这句话说了什么

这是一个**深度口径**的说明，出现在 Methods 里表示"我报的这个深度是怎么数出来的"。
它由**两个互相独立的校正**组成，恰好都落在 mosdepth 的默认行为里 ——
所以才写成"（mosdepth 默认）"。

一句话概括：深度类结论（拷贝数、VAF、断点证据强度）本质上都在回答
**「这个位点我有几次*独立*观测？」**，而这两个校正就是在剔除**两种不独立的重复计数**。

| | 去掉的是什么 | 为什么它不是独立观测 | mosdepth 怎么做的 |
| :--- | :--- | :--- | :--- |
| **去重**<br>(deduplication) | 同一个文库分子被 **PCR 扩增**出的多份拷贝 | 它们是**一次**取样的产物，测到几次只反映扩增次数 | **只是遵守 BAM 里的 `0x400` flag**（`-F` 默认含 1024）——**自己不做 markdup**，见 §2 |
| **配对重叠校正**<br>(mate-overlap correction) | 一对 PE read 在参考上**重叠的那一段** | 重叠段来自**同一个物理 DNA 分子**，两条 read 读的是同一份模板 | 缓存先到的 mate，算出参考坐标上的交集，对交集再减一次，**净计 1×**，见 §3 |

**"深度" 这个词裸用即错**，同一个 BAM 至少有四个口径，能差到两倍：

| 口径 | 含义 |
| :--- | :--- |
| 原始产出 | 含 PCR 重复、重叠段计两次 |
| 去重后 | 只做了第一项校正 |
| **去重 + 配对重叠校正** | 两项都做 = **mosdepth 默认** |
| 局部读段计数 | 手工数支持某 junction/indel 的读段（须按读段名去重） |

**两者都不做，depth 就不再是独立观测数，而是被夸大的 n** —— 后面所有基于深度的推断
（拷贝数、VAF、证据强度）用的都是这个被夸大的 n。

⚠ **最容易漏的一点**：这句话写在 Methods 里**不等于它真的生效了**。
"去重"依赖上游有没有跑过 markdup，没跑就是**空操作、零报错、深度看着完全正常**（§2）；
**验证方法见 §4**。

---

## 1. 默认参数速查（mosdepth 0.3.14）

| 参数 | 默认值 | 含义 | 踩坑点 |
| :--- | :---: | :--- | :--- |
| `-F/--flag` | `1796` | 排除 unmap+secondary+qcfail+**dup** | **supplementary(2048) 不排除** |
| `-i/--include-flag` | `0` | 不做正向筛选 | — |
| `-Q/--mapq` | `0` | MAPQ 阈值 | **MAPQ0 多比对 read 全收** |
| `-x/--fast-mode` | 关 | 关掉 CIGAR 解析 + 重叠校正 | help 里的 "recommended" 指**速度**不是精度 |
| `-a/--fragment-mode` | 关 | 整个 fragment 计为 covered | 与默认是**两种语义**，别混 |
| `-l/-u`（frag len） | `-1` | 不按插入片段过滤 | — |
| 碱基质量 | **无此选项** | mosdepth **不做 base-quality 过滤** | 与 `samtools depth -q` 无对应物 |

---

## 2. 「去重」—— mosdepth 只是**遵守 flag**，它自己不做 markdup

`-F 1796` 的位拆解：

| bit | 值 | 含义 | 默认排除？ |
| :--- | :---: | :--- | :---: |
| 0x4 | 4 | unmapped | ✅ |
| 0x100 | 256 | secondary alignment | ✅ |
| 0x200 | 512 | QC fail | ✅ |
| 0x400 | 1024 | **PCR / optical duplicate** | ✅ |
| 0x800 | 2048 | **supplementary alignment** | ❌ **不排除** |

4 + 256 + 512 + 1024 = 1796。**三条要点：**

1. **`0x400` 是上游 `MarkDuplicates` / `samtools markdup` 写进去的。**
   BAM 若从未跑过 markdup，这一位全是 0，"默认去重"就是**空操作** ——
   不报错、不警告、depth 看起来完全正常。
   ⇒ **判据不是"我用了默认参数"，而是 `samtools view -c -f 1024 <bam>` 是不是 0。**
   （这与 P29「未 markdup ⇒ 单片段 PCR 重复被当成 27 个脱靶候选」是同一个根因。）
2. **supplementary 默认计入。** 普通 WGS 平均深度影响很小，但在**载体整合位点 / SV 断点**
   处，一条 split read 的 supplementary 部分会给断点另一侧再加 1×。
   做整合位点拷贝数时通常要显式 `-F 3844`（1796+2048）。
3. **`-Q` 默认 0。** 重复序列区（LTR、rDNA、着丝粒旁、载体与宿主同源段）深度被撑起来。
   深度类结论至少 `-Q 1`，保守 `-Q 20`。

---

## 3. 「配对重叠校正」—— 把 fragment 而不是 read 当成观测单位

### 3.1 问题

PE 测序一个 fragment 出两条 read。当 **insert size L < 2 × read length R** 时两条 read
在参考基因组上重叠：

```
overlap = max(0, 2R − L)
```

重叠段的碱基**来自同一个物理 DNA 分子**，是**一次**观测。
"每条 read 都 +1" 会把它记成 2×。

PE150 下的量级：

| insert size L | overlap | 该 fragment 内被双计的碱基占比 |
| :--- | :---: | :---: |
| 400 bp | 0 | 0% |
| 300 bp | 0 | 0% |
| 250 bp | 50 bp | 50/300 = **16.7%** |
| 200 bp | 100 bp | 100/300 = **33.3%** |
| 150 bp | 150 bp | 150/300 = **50%**（两条完全重合） |

**⚠ 危险在于这不是常数偏移，而是跟着 insert size 分布走的。**
insert size 是**每个文库自己的属性** ⇒ 不同样本、不同建库批次偏差不同 ⇒
**做样本间深度比值时偏差不抵消**，会凭空造出一个长得像真实生物学差异的假差异。
拷贝数分析里这是会直接写进报告的那种错。

### 3.2 mosdepth 怎么做的

底层是**差分数组（difference array）**，不是逐碱基累加：

```
每条 read:   arr[start] += 1 ;  arr[end] -= 1
最后一次 cumulative sum ⇒ 每个位点的 depth
```

在此基础上两层修正：

- **内部 CIGAR 操作**：遇到 `D`(deletion) / `N`(skipped, intron)，在该子区间做反向增减，
  使这些位置**不计为 covered**；`S`(soft-clip) 本就不消耗参考坐标，天然不计。
- **mate overlap 校正**：按 qname 缓存先到达的那条 read 的参考区间；mate 到达时计算两者
  在参考上的**交集**，对交集再施加一次 `−1` 的差分 ⇒ 重叠段净贡献仍为 **1×**。

三个工程后果：

1. **必须 coordinate-sorted BAM**；缓存内存随"当前打开的 pair 数"增长（实际很小）。
   另注：差分数组按染色体分配 int32 ⇒ chr1(248 Mb) ≈ **1 GB** 常驻。
2. **只对同一染色体上的 mate 生效**。discordant pair（mate 在别的 contig）、
   mate 已被 flag 过滤掉、单端 read —— 都没有校正对象，各自按 1× 记。
3. **`-x/--fast-mode` 同时关掉上面两件事**，退化成 "start..end 整段 +1"。
   ⇒ fast-mode 下 **deletion / intron 被当成 covered**，对 RNA-seq 是灾难性的
   （整条 intron 变成有覆盖）。

### 3.3 `-a/--fragment-mode` 是**第三种**口径，别和上面混

`-a` 把**整个 fragment（含两条 read 中间那段根本没测到的 insert）**都算成 covered，
仅限 proper pair。语义是"这段 DNA 被一个分子跨过"，**不是**"这段 DNA 被碱基级读到"。

同一个 PE 片段（L=400, R=150，中间 100 bp 未测）：

| 模式 | 中间 100 bp 的 depth | 语义 |
| :--- | :---: | :--- |
| 默认 | 0 | 碱基级实测覆盖 |
| `--fast-mode` | 0 | 同上（此例无重叠、无 indel） |
| `--fragment-mode` | 1 | 物理片段跨越 |

CNV / 覆盖连续性偶尔用得上；**做变异证据一律不能用**。

---

## 4. 怎么验证这两件事在你的 BAM 上真的生效了

```bash
BAM=/path/to/sample.bam
ENV=regular_bioinfo

# (a) 这份 BAM 到底 markdup 过没有 —— 返回 0 就说明"默认去重"是空操作
conda run -n $ENV samtools view -c -f 1024 "$BAM"

# (b) 重叠校正到底改了多少 —— 默认 vs fast-mode 的 mean depth 差
conda run -n $ENV mosdepth -n -t 4 /tmp/dp_default "$BAM"
conda run -n $ENV mosdepth -n -t 4 -x /tmp/dp_fast "$BAM"
paste /tmp/dp_default.mosdepth.summary.txt /tmp/dp_fast.mosdepth.summary.txt

# (c) insert size 分布 —— 决定了 (b) 的差值"应该"有多大
conda run -n $ENV samtools stats "$BAM" | grep ^SN | grep -E "insert size|average length"
```

`(b)` 的差值 = overlap 校正 + CIGAR 校正合计。DNA-seq 上 CIGAR 项很小，
所以差值基本就是重叠双计的量级，应与 `(c)` 的 insert size 分布对得上
（PE150 + insert 中位数 ~350 ⇒ 差几个百分点；insert 中位数 ~200 ⇒ 差十几个百分点）。
**对不上就说明还有第三个因素**（supplementary 占比高、大量 discordant pair 等），要查清再用。

---

## 5. 跨工具口径对照（**均为 2026-08-27 本机 1.23.1 / 0.3.14 实测 `--help`**）

| 工具 | 默认排除 duplicate | 默认排除 supplementary | 默认 overlap 校正 | 默认 base-quality 过滤 |
| :--- | :---: | :---: | :---: | :---: |
| `mosdepth`（默认） | ✅ `-F 1796` | ❌ | ✅ | 无此功能 |
| `mosdepth -x` | ✅ | ❌ | ❌ | 无此功能 |
| `samtools depth` | ✅ `UNMAP,SECONDARY,QCFAIL,DUP` | ❌ | ❌（**`-s` 可开**） | `-q` 默认 **0** |
| `bcftools mpileup` | ✅ `--ns` 同上 | ❌ | ✅（`-x` 可关） | `-Q` 默认 **1** |

**⚠ 两个容易记反的点：**

- **`samtools depth` 从 1.16 起就默认排除 duplicate 了**（默认 filter-out 与 mosdepth 的
  1796 逐位相同）。更老的版本**没有**这个默认 —— 引用旧笔记/旧脚本前先确认版本。
- **`samtools depth` 有 `-s`（"Do not count overlapping reads within a template"）**，
  只是默认关。所以 mosdepth 与 samtools depth 的差异**不是"一个能做一个不能"，
  而是"默认值相反"** —— `samtools depth -s` 与 `mosdepth`（默认）口径才对齐。

---

## 6. 报告 Methods 里必须落到纸面的东西

同一份 BAM 用不同工具/不同默认值算出的深度**不是谁算错了，是口径不同**。
所以深度类结果的 Methods 必须写全：**工具 + 版本 + `-F` + `-Q` + 是否做重叠校正**。
只写 "depth was calculated with mosdepth" 等于没写 —— 后续任何人重算都对不上。

配套的两条硬规矩（详见姊妹文档）：

1. **同一项目里深度定量只用一个工具，分子分母口径一致**，偏差自相抵消。比值分析尤其如此。
2. **同一个数若有两个来源，就必须有一条断言把它们比对起来**（容差 2% 那种）。
   P29 正是靠这条当场拦下了 11–19% 的假差异。

---

## 7. 参考文档的位置

### 7.1 本机可离线核对（**本文所有默认值的实际出处**）

| 内容 | 命令 | 备注 |
| :--- | :--- | :--- |
| mosdepth 全部选项与默认值 | `conda run -n regular_bioinfo mosdepth --help` | **mosdepth 只随包装了二进制，本机没有 README/man page** ⇒ `--help` 就是唯一的离线权威 |
| `samtools depth` 默认 filter-out 等 | `conda run -n regular_bioinfo man samtools-depth` | man page 本机有（`$CONDA_PREFIX/share/man/man1/`） |
| `bcftools mpileup` 的 `-x` / `--ns` | `conda run -n regular_bioinfo bcftools mpileup` | 无参数即打印完整 help |
| BAM flag 位的含义 | `conda run -n regular_bioinfo samtools flags 1796` | 直接把数字解成名字，省得心算 |

### 7.2 上游权威文档

⚠ **以下三条是记忆中的出处，2026-08-27 这一轮未联网核对**，引用前请自行确认；
本文正文里的每一个默认值都来自 §7.1 的本机实测，不依赖这三条。

- **mosdepth 源码与 README**：`https://github.com/brentp/mosdepth`
  （`--fast-mode` / `--fragment-mode` 的语义、差分数组算法的说明在 README 与源码里）
- **mosdepth 论文**：Pedersen BS & Quinlan AR, *"mosdepth: quick coverage calculation for
  genomes and exomes"*, **Bioinformatics** 2018, 34(5):867–868
- **samtools / bcftools 在线手册**：`https://www.htslib.org/doc/samtools-depth.html` ·
  `https://samtools.github.io/bcftools/bcftools.html#mpileup`；
  **SAM 格式与 flag 定义**：`https://samtools.github.io/hts-specs/SAMv1.pdf`

### 7.3 本目录内的相关文档

- [mosdepth_vs_samtools_depth.md](mosdepth_vs_samtools_depth.md) —— P29 实测 11–19% 假差异的事故记录
- [INDEX.md](INDEX.md) —— 跨项目软件坑总索引，**跑任何新流程前先扫这里**

---

**相关**：
[mosdepth_vs_samtools_depth.md](mosdepth_vs_samtools_depth.md)（实测事故与数字）·
[pysam.md](pysam.md)（`count_coverage()` 在比对黑洞永久挂起）·
[[feedback_self_audit_needs_independent_cross_check]]（同一事实出现两处就必须有检查比对）
