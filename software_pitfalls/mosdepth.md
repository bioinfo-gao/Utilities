# mosdepth —— 深度计数的口径：默认参数、去重、配对重叠校正

> 本文讲**机制与口径参数**（一个碱基位点上到底算了几次观测）。
> **实测事故与具体数字**（P29 上 11–19% 假差异）在
> [mosdepth_vs_samtools_depth.md](mosdepth_vs_samtools_depth.md)，此处不重复。
>
> 版本基准：本机 `regular_bioinfo` 环境，**mosdepth 0.3.14** / **samtools 1.23.1** /
> **bcftools 1.23.1**（2026-08-27 实测 `--help`）。⚠ 下面的默认值**是版本相关的**，
> 换机器/换环境前重跑一次 `--help` 再引用。

---

## 0. 一句话

深度类结论（拷贝数、VAF、断点证据强度）本质上都在回答
**「这个位点我有几次*独立*观测？」**。
「去重」去掉的是**同一个文库分子被 PCR 扩出的多份拷贝**；
「配对重叠校正」去掉的是**同一个分子的两端读到了同一段参考序列**。
两者都不做，depth 就不再是独立观测数，而是被夸大的 n。

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

**相关**：
[mosdepth_vs_samtools_depth.md](mosdepth_vs_samtools_depth.md)（实测事故与数字）·
[pysam.md](pysam.md)（`count_coverage()` 在比对黑洞永久挂起）·
[[feedback_self_audit_needs_independent_cross_check]]（同一事实出现两处就必须有检查比对）
