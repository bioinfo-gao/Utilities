---
name: splicing
description: "Use when 要做可变剪接分析（differential splicing / exon usage / isoform switch）——选型决策树、五条尺子的角色分工、必改的非默认参数、各工具的实测坑，以及三层验证纪律（外部真值召回率 / 置换假阳性本底 / 两层整合）"
---

# /splicing — 可变剪接分析 SOP

**上位方法学依据**：[`~/Utilities/Bioinfo/splicing/splicing_bioinformatics_review_20260905.md`](/home/gao/Utilities/Bioinfo/splicing/splicing_bioinformatics_review_20260905.md)
**参考实现（含全部脚本与实测数）**：`/home/gao/projects_2026M7/34_exon_splicing_pipeline_dev/`

本 skill 是那份综述 §12 流程的可执行版，所有参数都来自 P34 的实测，不是默认值。

---

## 第零步：先确认实验设计能不能做

| 项 | 门槛 | 不满足时 |
| :--- | :---: | :--- |
| 深度 | **80–120 M read pairs**（PE150）；60 M 是绝对下限 | 结论必然偏向高表达基因；低表达基因的阴性结果**不得**写成"无变化" |
| 读长 | **PE150 是下限**，不要 PE100，绝不要 SE | junction read 需两侧各有 ≥20 nt 锚定 |
| 链特异 | **必须** | 非链特异在重叠基因/反义转录本处给出错误 junction 归属 |
| 重复数 | n=3 可用，**n=5–6 才稳健**；n=1 只能出描述性 PSI | n=1 跑差异剪接 = p 值无意义 |
| 建库 | 涉及 **intron retention / 剪接因子突变（SF3B1/SRSF2/U2AF1/ZRSR2）⇒ 必须 rRNA-depletion** | polyA 会把 IR 信号洗掉，**不可补救**，且这个决定在测序前就定死了 |

**建库方式未记录时**：用**全局 intronic rate** 反推（polyA 典型 5–20%，rRNA-depl 30–50%+），
但**推断不等于确认**，必须标注。P34 实测 proj19 中位 12.3% ⇒ 推断 polyA。

---

## 第一步：选型决策树

```
Q1 涉及 isoform 组合/搭配（如 neojunction 在哪条 isoform 上）？
   是 → 长读长（IsoQuant + SQANTI3），不在本 skill 范围
Q2 需要检出未注释 junction（肿瘤/剪接因子突变/非模式系统）？
   是 → LeafCutter 或 MAJIQ 为主，rMATS 作补充
Q3 主要关心 intron retention？
   是 → rRNA-depl 建库 + IRFinder-S / MAJIQ
Q4 实验设计复杂（批次/配对/连续协变量）？
   是 → DEXSeq / DRIMSeq 的 GLM（rMATS 与 LeafCutter 加协变量都很别扭）
Q5 需要回答"改变了蛋白吗"？
   是 → salmon → DRIMSeq/stageR → IsoformSwitchAnalyzeR
否则 → 默认组合：rMATS-turbo（主尺）+ LeafCutter（副尺）
```

## 第二步：五条尺子的角色

| 角色 | 工具 | 粒度 | 说明 |
| :--- | :---: | :---: | :--- |
| **主尺** | rMATS-turbo（**JC 口径**） | 5 类事件 | 生物学命名清晰，直接进报告 |
| **副尺** | LeafCutter | intron cluster，免注释 | 坐标系与主尺正交，用来验证主尺 |
| 复杂设计尺 | DEXSeq + DRIMSeq/stageR | exonic bin | 有协变量时唯一干净的选择 |
| 深挖层 | MAJIQ | LSV | 剪接是核心问题时才值得配置成本 |
| 后果层 | IsoformSwitchAnalyzeR | 转录本 | 回答 ΔPSI 表格答不了的问题 |

---

## 第三步：必改的非默认参数（改一个少一个，都别用默认）

### 比对（STAR）

- **多样本项目必须"手工两遍"**，不要 `--twopassMode Basic`：
  per-sample 模式让每个样本用自己的 junction ⇒ 样本间 PSI 系统偏差。
  ```
  pass-1 逐样本出 SJ.out.tab  →  合并过滤  →  pass-2 全部样本喂同一份 --sjdbFileChrStartEnd
  ```
- 合并过滤判据：`非 chrM && 唯一比对支持>=3 && (已注释 || 唯一支持>=5)`
  ```bash
  awk 'BEGIN{OFS="\t"} $1!="chrM" && $7>=3 && ($6==1 || $7>=5) {print $1,$2,$3,$4}' *.SJ.out.tab | sort -u
  ```
- 关键参数：`--alignSJoverhangMin 8`（默认 5 太松）、`--alignSJDBoverhangMin 3`、
  `--outFilterMismatchNoverReadLmax 0.04`、`--outSJfilterOverhangMin 30 12 12 12`
- ⛔ 别用 salmon/kallisto 的结果做事件级分析 —— 它们不产生基因组坐标的 junction

**手工两遍值多少？P34 用同一批 reads 两种比对各跑一遍量化过：**

| 指标 | nf-core 单 pass（overhang 5/1） | 手工两遍（overhang 8/3） |
| :--- | :---: | :---: |
| 检出事件合计 | 152,708 | 152,024 |
| 显著事件合计 | 1,031 | **1,085（+5.2%）** |
| 显著 junction | 2,667 | 2,798 |
| Jaccard | 0.76 | — |
| **单 pass 结果被两遍复现的比例** | **88.5%** | — |

⇒ **单 pass 不产垃圾，但约每 8 条判读里有 1 条是比对方法依赖的。**
⇒ 方向性值得注意：**检出总数略降、显著数反升** —— 严 overhang 滤掉低质量结点，
   既降噪又提功效。这支持把手工两遍 + 严 overhang 作为**默认**而非可选。
⇒ **复用旧 BAM（如 nf-core 产物）做剪接分析**：可以，但必须在报告写明比对参数不合要求，
   且关键结论应在重比对后复核。

### rMATS

```bash
rmats.py --b1 b1.txt --b2 b2.txt --gtf $GTF -t paired \
  --readLength <名义读长> --variable-read-length \   # 修剪过就必须加
  --libType fr-firststrand \                          # 对应 stranded reverse
  --nthread 24 --od OUT --tmp TMP
```
- **计数口径默认 JC**；只有 RI 用 JCEC（IR 信号本就在内含子体内）
- **五类事件的 FDR 各自校正，绝不合并再校正**（rMATS 已在每类内部做过 BH）
- **三重阈值联用**：`FDR<0.05 && |ΔPSI|>=0.1 && 每样本 IJC+SJC>=10`
  只按 |ΔPSI| 排序，榜首全是低表达噪声

### LeafCutter

```bash
regtools junctions extract -a 8 -m 50 -M 500000 -s RF -o s.junc s.bam
leafcutter-cluster -j juncfiles.txt -m 50 -l 500000 -o TAG -r OUT
leafcutter-ds -p 16 -0 <baseline组> -i <每组样本数> -g <每组样本数> -e exons.gz counts.gz groups.txt
```
- `-s` 取值：**RF = first-strand**（stranded reverse）。若 BAM 由 STAR 以
  `--outSAMstrandField intronMotif` 产出则**没有 XS tag**，XS 模式不可用
- **`-i` 必须显式设成每组样本数**（见下方坑）
- **线程**：`-p N` 起 N 个进程，每个进程的 pytorch 默认再开 ~64 线程 ⇒ 必须
  `export OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 ...`，否则 load 直接冲破上限

---

## 第四步：三层验证纪律（缺一层，结论就没有刻度）

这是本 skill 最重要的部分。**"跑出结果"和"知道结果有多可信"是两件事。**

### ① 外部真值召回率

用有已知真值的公共数据跑同一条管线。ENCODE 的 shRNA-KD RNA-seq 有官方 rMATS 结果
（`output_type = "differential splicing quantifications"` 的 tar 包）。

⚠ **ENCODE 的差异剪接真值是 hg19/GENCODE V19**。若自己比对到 GRCh38，
**junction 坐标不可直接比**，只能做基因级比对（或做 liftOver 并报告转换失败率）。

P34 实测：HNRNPC 敲低 **83.6%**、SRSF1 敲低 **83.9%**（基因级，n=2，PE100）。

### ② 置换假阳性本底（方法间互证拿不到的信息）

n=3 vs n=3 时，3+3 分组共 **C(6,3)/2 = 10 种，穷举**（不是随机抽样，可复现）：
1 种真实 + 9 种置换。对 9 个置换跑**完全相同**的流程与阈值。

**⚠ 本底是"每条尺子自己的"，必须各测各的 —— 借用别条会错两个量级。**
P34 用同一批数据、同样 9 种分法实测三条路线：

| 路线 | 检验单位 | 置换本底中位 | 真实分组 | 信噪比 | 噪声占比 |
| :--- | :---: | :---: | :---: | :---: | :---: |
| rMATS | event | **188** | 1,031 | 5.48× | **18.2%** |
| LeafCutter | intron | **1** | 742 | 742× | **0.1%** |
| DEXSeq | exon bin | **18** | 8,483 | 471× | **0.2%** |

⇒ **rMATS 是三者里最宽松的，本底高出约两个量级**；该阈值下纯噪声也能产出约 18% 的"显著事件"。

⚠ **别把 LeafCutter 的近零本底读成"更准"** —— 它只检验 18,872 个 cluster，
rMATS 显著的 junction 有 47.9% 它根本没检验，n=3 又在其校准下限之外 ⇒ 是**保守**不是**分辨力强**。
（佐证：仅 `p.adjust<0.05` 它有 1,931 个显著 cluster，加 `|ΔPSI|≥0.10` 后降到 446 ——
效应量阈值承担了大部分筛选。）

⚠ **算本底前先核对分母**。DEXSeq 的 independent filtering 随 p 值分布自适应，
P34 实测置换间被检验 bin 数在 **40,848–302,114** 变动 ⇒ 原始计数不可直比，
必须按「显著/被检验」比率重算（471.28× → **377.67×**）。
rMATS（恒 135,851）与 LeafCutter（恒 18,872）分母不变，不受影响。
**复用计数矩阵是对的**：置换的定义就是"同一份计数矩阵只打乱标签"，
故 LeafCutter 复用 `perind_numers.counts.gz`、DEXSeq 复用 `exonbin_SE.rds`，
不重跑 regtools / summarizeOverlaps —— 这不是抄近路，重跑反而引入无关变异。

⚠ **经验 p 的下限是 1/(置换数+1)**。9 个置换时最小 p = 0.100，
这时的 `p=0.100` 意思是"真实分组击败了全部 9 个置换"，**不是"不显著"**。
想要更小的 p 只能加样本数（n=4 有 34 种置换，下限降到 0.029），不是换统计方法。

⚠ 本底随阈值移动，**换阈值必须重测**。

### ③ 两层整合（junction 级 + 基因级），且不取并集

- **按 junction 坐标 `chr:start-end:strand` 比，不比事件名、不比 cluster ID**
  （LeafCutter 的 cluster ID 只在单次分析内有效）
- **坐标偏移要实测定标，不要按理论值硬套**：P34 实测最优偏移是 **(+1, −1)**，
  而理论预期的 (+1, 0) 给出**零重叠** —— 硬套会得出"两工具完全不一致"的假结论。
  做法：枚举 0/±1 几种偏移，取全集重叠数最大的那个，并把证据打印出来
- **分母必须拆开**：LeafCutter 在聚类阶段就滤掉一部分 junction。
  "从未检验"与"检验了但不显著"是两回事，混进一个 Jaccard 会把覆盖差异
  记成方法学分歧。P34 实测 rMATS 显著的 junction 有 **47.9% LeafCutter 根本没检验**
  ⇒ 同时报 Jaccard（全集分母）与**条件一致率**（只在两侧都检验过的上比）
- **基因级另做一层**：基因是四条尺子唯一共有的坐标系。
  报"被 k 条尺子同时命中"的分布，取 **≥3 条命中**作高置信集
- ⛔ **不取并集当"共发现 N 个事件/基因"** —— 并集混合了不同的假阳性率，
  且各尺子的计数单位不同

**为什么一致性比单条尺子的 FDR 更值得信**：它不依赖任何单条尺子的 p 值校准是否可靠。
P34 里 Tnip1 / Birc2 / Il15 被四个互相独立的统计框架同时命中，
这在 LeafCutter 的 p 值本就低于其校准范围（n=3）的情况下尤其重要。

---

## 第五步：各工具的实测坑（详见 `~/Utilities/software_pitfalls/`）

| 工具 | 坑 |
| :--- | :--- |
| **LeafCutter** | ① **装它请用 bioconda 的 `leafcutter 2.0.3`**（纯 Python），别走 GitHub 源码装 R 包——那条路要编译 rstan/Stan 模型，会连撞五层。② `-i/--min_samples_per_intron`（默认 5）在源码里被当作**每组样本数**门槛，n<5 直接抛 "no groups with enough samples to test"。③ p 值**只校准到 n=4**，n=3/n=2 都在校准范围外。④ `-p N` 会导致线程超订，必须钉 `OMP_NUM_THREADS=1` |
| **DEXSeq** | ① 别用 `match(rownames(res), rownames(se))` 从别的对象取 bin 计数——行名不是一套，会整列 NA，把所有 bin 静默滤光，报"0 个显著"而**零报错**。计数就在结果表的 `countData.*` 列里。② `write.table(as.data.frame(DEXSeqResults))` 必崩于 list/matrix 列，只导出原子列。③ **`saveRDS(dxd)` 要放在导出之前**，崩了才能恢复而不重算 |
| **MAJIQ** | ① **3.x 强制要 license 文件**（学术免费但须向 BioCiphers 申请）；`--help` 把 `--license` 列为 optional 具有误导性——"命令行可以不写" ≠ "运行时不需要"。② 3.x 的 CLI 与网上 2.x 教程**完全不同**（config 从 .ini 改 TSV，多出 `psi-coverage` 中间步）。③ pip 安装要 `--no-build-isolation` + 钉 `scikit-build-core<0.10` + `pybind11<2.12` + 编译期/运行期 numpy 一致 |
| **IsoformSwitchAnalyzeR** | ① `importRdata(isoformExonAnnoation=GTF)` **已完成 ORF 标注**，再调 `addORFfromGTF()` 直接报错。② `extractSequence()` 需要 BSgenome，只在跑外部序列工具时才需要，可跳过。③ salmon 未开 `--numBootstraps` 时 DTU 的 p 值虚高 |

---

## 通用纪律

- **conda env 一律用 `mamba create -p <绝对前缀>`，不用 `-n`**（`-n` 按 envs_dirs 顺序解析，可能落错位置）
- **别把诊断输出接 `tail -N`** —— 真正的根因行会被截掉（MAJIQ 第一轮就因此白跑一轮）
- **任何"0 个 / 空结果"在当成结论前，先证明过滤字段不是全 NA**
- **"某源上没有某包"是一行 `mamba search` 就能证伪的断言，不许凭印象写进计划**
- 长任务一律进 tmux；线程总和不超过 **28 核 / 56 线程**
- 退出码 0 ≠ 产物存在，每步收尾补存在性断言
