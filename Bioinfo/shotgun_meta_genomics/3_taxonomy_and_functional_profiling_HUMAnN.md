# Shotgun 宏基因组：Taxonomy + Functional Profiling (HUMAnN) 教程

> 定位：assembly-free、reference-based 的 read-level profiling 路线。回答两个正交的问题——
> **"谁在这里"（taxonomy / composition）** 和 **"它们能干什么"（function / metabolic potential）**。
> 与第 2 篇 MAG（assembly-based）互补：MAG 回收 genome，本篇不组装、直接把 reads 打到参考库。
> 本教程的资源/耗时数字来自 project 17（10 个鼠肠道样本，17–27 M read pairs/样本）实测。

---

## 0. 一句话把两件事分清

| | Taxonomy（分类/组成） | Function（功能/代谢潜能） |
| :--- | :--- | :--- |
| 回答 | **谁在**（which taxa，相对丰度） | **能做什么**（哪些 gene family / pathway，丰度多少） |
| 主力工具 | **Kraken2+Bracken**、**MetaPhlAn 4** | **HUMAnN 3** |
| 参考库 | k-mer DB / clade marker genes | ChocoPhlAn（核酸）+ UniRef90（蛋白） |
| 产物 | genus/species 丰度表 → α/β 多样性、差异丰度 | gene families + pathways 丰度表 → 功能差异 |
| 速度 | 快（分钟级/样本） | 慢（**~8 h/样本**，diamond 主导） |

关键直觉：**两个分类样本可以物种组成相近但功能不同**（同属不同株携带不同基因），也可以**物种不同但功能冗余**（不同菌干同一件代谢的事）。所以 taxonomy 和 function 不能互相替代，标准 shotgun 分析两者都做。

---

## 1. Taxonomy：两种互相独立的分类器 + 为什么都跑

### 1.1 Kraken2 + Bracken（k-mer，广撒网）
- **Kraken2**：把每条 read 的 k-mer 比对到一棵带 LCA（lowest common ancestor）标注的 DB 树，给出 read 级分类。快、召回高，但直接的 read 计数在种级是有偏的（reads 会停在高层节点）。
- **Bracken**（Bayesian Reestimation of Abundance）：**必须在 Kraken2 之后跑**，用 DB 自带的 `kmer_distrib` 把 Kraken2 的层级计数重新分配到指定层级（`-l S` 种 / `-l G` 属），得到可用的种/属**相对丰度**。
  - `-r 150` 要匹配你的 read 长度（PE150 → 150）。
  - DB：`Standard-8GB`（capped，够用且省内存）或完整 `Standard`（~100 GB，更全但吃内存）。

### 1.2 MetaPhlAn 4（clade-specific marker genes，保守）
- 只比对到 ~5.1 M 条**物种特异 marker 基因**（不是全基因组），用命中的 marker 覆盖度反推物种相对丰度。
- 特点：**保守、假阳性低**、直接给出 species/SGB 级相对丰度（%），还能出 strain-level（StrainPhlAn）。代价是数据库里没有的新物种它看不到。
- **HUMAnN 会先内部跑一遍 MetaPhlAn** 来决定"哪些物种的 pan-genome 参与后续核酸比对"——所以 MetaPhlAn 是连接 taxonomy 和 function 的枢纽（见 §3）。

### 1.3 为什么两个都跑——交叉验证
- Kraken2/Bracken（广）与 MetaPhlAn（严）**方法完全独立**。两者一致的物种 = 可信；只在一个里高的 = 存疑（DB 假阳性、近缘错分、低丰度噪声），报告里标注而非默默采信。
- 实践：主图/主结论用 MetaPhlAn（保守、单位干净），Kraken2/Bracken 做广度补充和 concordance 图（本项目 `fig5_crosstool_concordance`）。

### 1.4 Taxonomy 下游（组成 → 生态统计）
拿到 species/genus 丰度矩阵（样本 × 物种）后：
- **α 多样性**（组内）：Observed、Shannon、Simpson。样本内丰富度/均匀度。
- **β 多样性**（组间）：Bray-Curtis 距离 → PCoA 排序；**PERMANOVA**（`adonis2`）检验分组是否解释群落结构（报 R² 和 p）。
- **差异丰度**：小样本非参 **Wilcoxon**（或 ALDEx2 / ANCOM-BC / MaAsLin2 更严谨的 compositional 方法）+ **BH/FDR 校正**。⚠ 宏基因组丰度是 compositional data，普通 t-test 在成分数据上有偏，正式项目优先用 CLR 变换或专用方法。

> **nf-core/taxprofiler** 把 fastp 去接头 → 去宿主(Bowtie2) → Kraken2/Bracken + MetaPhlAn + taxpasta 合表 一条龙跑掉，是上面 1.1–1.3 的工程化封装。下游 α/β/差异丰度用 R 自己写（vegan + ggplot2）。

---

## 2. HUMAnN 的核心功能（一句话 + 展开）

**HUMAnN 3 = HMP Unified Metabolic Analysis Network**：从 shotgun reads 直接定量**功能**——
输出「每个 **gene family（UniRef90）** 的丰度」和「每条 **代谢通路（MetaCyc pathway）** 的丰度」，
并且**按物种拆分（stratified）**——即"通路 X 的丰度里，有多少来自 *Akkermansia*、多少来自 *Bacteroides*"。

这就是 HUMAnN 相对于"只做 taxonomy"的核心价值：**功能 × 物种 的二维定量**。典型能回答的问题：
- 两组间哪些**代谢通路**丰度不同（如 SCFA 产生、氨基酸合成、抗性基因）？
- 某条通路的差异是**哪个物种贡献**的（物种替换 vs 单物种基因变化）？
- 把 gene families 重编到 **KO / EC / GO / Pfam / MetaCyc-RXN**，接 KEGG 通路富集。

---

## 3. HUMAnN 内部三步（理解耗时都花在哪）

HUMAnN 对**每个样本**跑一条三阶 tiered search：

```
clean reads (host-removed, 单端拼接)
   │
   ├─ [1] MetaPhlAn taxonomic prescreen      ── 快（分钟级）
   │      决定哪些物种的 pan-genome 进入下一步
   │
   ├─ [2] Nucleotide search: bowtie2 vs ChocoPhlAn  ── 中（~30–50 min/样本）
   │      reads 打到"在场物种"的 pan-genome 核酸库；命中 → 已知物种的已知基因
   │
   └─ [3] Translated search: DIAMOND blastx vs UniRef90 ── 慢（~5–8 h/样本，主导！）
          第 2 步没比上的 reads，翻译成蛋白去撞 UniRef90 全库(~34 GB)
          → 捕捉未知物种/远缘同源的功能
   ↓
  合并 → gene families → 映射 MetaCyc → pathways
```

**耗时全在第 3 步 diamond blastx**：UniRef90 full DB 巨大，diamond 分块处理、**不输出进度百分比**，单样本常 5–8 h。这就是为什么整个 functional profiling 是 taxonomy 的几十倍耗时。

> **提速旋钮**（按需权衡灵敏度）：
> - `--bypass-translated-search`：跳过第 3 步 → 快几十倍，但只保留已知物种基因，**灵敏度大降**（一般不推荐用于正式功能分析）。
> - 用 **UniRef90 EC-filtered**（~0.9 GB）代替 full → 快很多，但只覆盖有 EC 注释的酶。适合只关心酶/KEGG 的项目。
> - `--threads N` 提高 diamond 并行；**多样本并行**比单样本堆线程更划算（见 §5）。
> - `--nucleotide-database` / `--protein-database` 指到本地已下好的 DB，避免联网。

---

## 4. HUMAnN 三张核心输出表 + 单位

每样本产出（`humann -i sample.fq.gz -o out/`）：

| 文件 | 内容 | 单位 | 用途 |
| :--- | :--- | :---: | :--- |
| `*_genefamilies.tsv` | 每个 UniRef90 gene family 丰度，**按物种分层** | **RPK**（reads per kilobase） | 功能定量的原始层 |
| `*_pathabundance.tsv` | 每条 MetaCyc pathway 丰度，按物种分层 | RPK | 通路层，最常用于组间比较 |
| `*_pathcoverage.tsv` | 每条 pathway 的"存在性/完整度"(0–1) | 比例 | 判断通路是否真的存在（补充 abundance） |

**分层格式（stratified）** 长这样：
```
Pathway|g__Akkermansia.s__Akkermansia_muciniphila   12.3
Pathway|g__Bacteroides.s__Bacteroides_uniformis     4.5
Pathway|unclassified                                 2.1
Pathway                                             18.9   ← 该行是所有物种之和（community total）
```
`|` 前是功能，`|` 后是贡献物种；不带 `|` 的行是 community total。

### 4.1 三个必做的后处理

```bash
# (a) 归一化：RPK → CPM 或 relative abundance（消除测序深度差异，才能跨样本比）
humann_renorm_table -i merged_genefamilies.tsv -u cpm -o merged_genefamilies_cpm.tsv
#   -u relab 出相对丰度；-u cpm 出 copies-per-million

# (b) 合并多样本成一张矩阵
humann_join_tables -i out_dir/ -o merged_pathabundance.tsv --file_name pathabundance

# (c) 重编到别的功能本体（KO/EC/GO/Pfam...）以接下游富集
humann_regroup_table -i merged_genefamilies.tsv -g uniref90_ko -o merged_ko.tsv
#   uniref90_ko / uniref90_level4ec / uniref90_go / uniref90_pfam / uniref90_rxn

# (可选) 拆分 stratified / unstratified，多数统计只用 unstratified（community total）
humann_split_stratified_table -i merged_pathabundance_cpm.tsv -o split/
```

### 4.2 下游统计
- 用 **unstratified**（community total）矩阵做组间差异：**MaAsLin2**（HUMAnN 官方搭档，处理 compositional + 协变量）或 Wilcoxon+FDR。
- 发现显著通路后，回 **stratified** 表看**是哪个物种贡献**的差异（物种替换？单物种上调？）——这是 HUMAnN 最有价值的一步。

---

## 5. 实操：从 clean reads 到功能表（含资源/时间预期）

### 5.1 环境与数据库
```bash
mamba activate mag_biobakery          # HUMAnN/MetaPhlAn/diamond/bowtie2 都在这个 env
# DB（一次性下好，几十 GB，指向本地）：
#   ChocoPhlAn (核酸):     humann_databases --download chocophlan full   <dir>
#   UniRef90 full (蛋白):  humann_databases --download uniref  uniref90_diamond <dir>
#   MetaPhlAn markers:     metaphlan --install
# 本机现成路径示例：/Work_bio/references/Metagenomics/humann/uniref/uniref90_201901b_full
```

### 5.2 单样本
```bash
# HUMAnN 吃"单端/已拼接"的一个 fq；PE 数据先把 R1+R2 cat 成一个文件（HUMAnN 不用配对信息）
cat sample_R1.fq.gz sample_R2.fq.gz > sample_merged.fq.gz

humann \
  --input  sample_merged.fq.gz \
  --output humann_out/sample \
  --threads 18 \
  --nucleotide-database /path/chocophlan \
  --protein-database    /path/uniref \
  --remove-temp-output          # 省磁盘；调试时先别加，temp 里有 diamond 中间文件
```

### 5.3 批量并行（本项目实测配比）
**多样本并行 > 单样本堆线程**。本机 56 线程上限，稳态跑法：
```
3 样本并行 × diamond --threads 18 = 54 线程   →  load ~51，刚好压在 56 帽子下
```
- **实测耗时（project 17，17–27 M pairs/样本）**：单样本 nucleotide ~40 min + **diamond ~5–8 h** ≈ **8–9 h/样本**；3 并行滚动 → **吞吐 ~3 样本 / 8.5 h**；10 样本合计 **~24–30 h**。
- diamond 无进度条，判断健康看：进程 CPU 是否贴满（~1600%/进程）、`humann_temp/*/tmp*/diamond-tmp-*` 是否每几分钟出新分块、log 无 error。**别因为它慢/文件暂时不长就杀**（第 3 步分块间输出不增长是正常的）。
- 用 tmux + 一个 for 循环控制并发（维持 3 个在飞），每个 sample DONE 就补下一个。

---

## 6. 常见坑（本项目踩过的 + 通用）

| 坑 | 症状 | 解法 |
| :--- | :--- | :--- |
| **DB 没指本地** | HUMAnN 试图联网下 DB / 报找不到 | 显式 `--nucleotide-database` `--protein-database` |
| **PE 当配对喂** | HUMAnN 不用配对信息 | 先 `cat R1 R2` 成单文件再喂 |
| **diamond 看似卡住** | `diamond_m8` 文件几十分钟不长、CPU 却满 | 正常——分块间不写出；看 `diamond-tmp-*` 在滚动即健康 |
| **磁盘爆** | `humann_temp` 每样本几十 GB | 跑完加 `--remove-temp-output`，或及时清 temp |
| **忘记归一化就比组** | 深度差异被当成生物学差异 | 先 `humann_renorm_table -u cpm/relab` 再统计 |
| **拿 stratified 做检验** | 行数爆炸、多重检验失控 | 统计用 `humann_split_stratified_table` 的 unstratified 表 |
| **taxpasta 报缺 taxdump**（taxprofiler） | `--taxpasta_add_name/rank/lineage` 需 NCBI taxdump | 撤这些 flag，物种名下游从 MetaPhlAn lineage 解析 |
| **Bracken 同名文件冲突**（taxprofiler） | `BRACKEN_COMBINEBRACKENOUTPUTS` input collision | `databases.csv` 里 kraken2/bracken 两行的 `db_name` 唯一化 |
| **UniRef90 full 太慢** | 只关心酶/KEGG 却跑全库 | 换 UniRef90 **EC-filtered**（~0.9 GB）大幅提速 |

---

## 7. 一页速查（cheat sheet）

```bash
# ── Taxonomy（快）──
kraken2 --db k2_standard8gb --paired R1 R2 --report s.kreport --output -
bracken -d k2_standard8gb -i s.kreport -o s.bracken -r 150 -l S     # 种级
metaphlan sample_merged.fq.gz --input_type fastq -o s_metaphlan.txt
# → 合表 → R: vegan(α/β) + adonis2(PERMANOVA) + Wilcoxon/MaAsLin2(差异丰度)

# ── Function（慢，diamond 主导 ~8h/样本）──
cat R1 R2 > merged.fq.gz
humann -i merged.fq.gz -o out/sample --threads 18 \
       --nucleotide-database CHOCO --protein-database UNIREF
humann_join_tables   -i out/ -o merged_path.tsv --file_name pathabundance
humann_renorm_table  -i merged_path.tsv -u cpm -o merged_path_cpm.tsv
humann_regroup_table -i merged_gf.tsv -g uniref90_ko -o merged_ko.tsv
humann_split_stratified_table -i merged_path_cpm.tsv -o split/
# → unstratified 做组间差异 → 回 stratified 看物种贡献
```

---

*工程化封装：taxonomy 用 nf-core/taxprofiler；MAG 用 nf-core/mag（见本目录 2_MAG）。本篇聚焦 read-level profiling 的原理与手动流程，便于理解 pipeline 内部在做什么。*
