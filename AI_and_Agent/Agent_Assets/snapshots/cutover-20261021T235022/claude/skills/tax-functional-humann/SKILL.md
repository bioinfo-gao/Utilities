---
name: tax-functional-humann
description: "Use when 用户要做 shotgun 宏基因组 functional profiling（功能通路/基因家族丰度、代谢潜能、KO/EC、SCFA/代谢差异）:HUMAnN 3。taxprofiler 不做功能,这条独立于 /taxnom。触发词:HUMAnN/functional/pathway/gene family/MetaCyc/代谢通路/功能差异"
disable-model-invocation: true
---

# /tax-functional-humann — Shotgun 宏基因组 Functional Profiling (HUMAnN 3) Setup Skill

为当前项目搭建**assembly-free 的功能定量**分析代码：从去宿主 reads 直接定量**基因家族（UniRef90 gene families）**与**代谢通路（MetaCyc pathways）**丰度，并**按物种分层（stratified）**——回答"某通路的丰度里哪个物种贡献多少"。用 **HUMAnN 3.9**（`mag_biobakery` 环境原生），非 nextflow pipeline。

HUMAnN 内部三步：**MetaPhlAn 预筛物种 → bowtie2 打 ChocoPhlAn 核酸库 → DIAMOND blastx 打 UniRef90 蛋白库** → gene families → MetaCyc pathways。

> **与 `/taxnom` 的边界（最重要）**：`/taxnom`（nf-core/taxprofiler）**只做物种分类，不含 HUMAnN 模块**，回答"谁在这里、各占多少"。**功能（pathway/gene family 丰度）超出 taxprofiler 范围，必须走本 skill。** 两者互补：先 `/taxnom` 出组成，再本 skill 出功能。
>
> **与 `/tax-assembly-mag` 的边界**：那条是 assembly-based（组装+分箱重建 MAG，genome 级功能注释用 Prokka）。本 skill 是 assembly-free、read-level 的功能定量——快出通路差异、不组装。全套 shotgun 常三者都跑（组成 + 功能 + MAG）。
>
> **关键前提**：HUMAnN 吃的是**去宿主后的 clean reads**。若还没做 QC/去宿主，先走 `/taxnom` 的 taxprofiler（其去宿主 unmapped reads 可直接复用），或单独 fastp+bowtie2 去宿主。

---

## 第一步：信息收集

| 参数 | 确认方式 |
|:---|:---|
| 项目根目录 / 样品表 | 从当前工作目录推断或用户确认 |
| 输入 reads | **已去宿主的 clean reads**；优先复用 taxprofiler 的 `*.unmapped_{1,2}.fastq.gz` |
| 宿主物种 | 若尚未去宿主，Mouse/Human/其他 → 决定去宿主参考 |
| 分组设计 | case-control / 多组 / 配对 → 决定下游差异检验模型 |
| 交付重心 | 通路差异（组间哪些 MetaCyc pathway 变化）/ KO·EC·KEGG 富集 / 物种功能贡献拆分 |
| 数据量（实测）| fastp 实测 read pairs（**勿用 gzip 大小反推**，会低估近一倍）；决定 diamond 耗时 |

---

## 第二步：环境与数据库（本机已就位，指本地勿联网）

```
env:        mag_biobakery          # humann 3.9 / metaphlan 4.2.4 / diamond / bowtie2
ChocoPhlAn: /Work_bio/references/Metagenomics/humann/chocophlan            (核酸, ~16G)
UniRef90:   /Work_bio/references/Metagenomics/humann/uniref                (uniref90_201901b_full.dmnd, ~34G)
MetaPhlAn vJun23 db: /Work_bio/references/Metagenomics/metaphlan_vJun23    (index: mpa_vJun23_CHOCOPhlAnSGB_202307, ~22G)
```

DB 代际必须匹配：本机 HUMAnN 功能库是 **v201901（MetaPhlAn v3 代）**，只认 v3/vJun23 的 taxonomic profile。`humann_config` 已把 nucleotide/protein DB 指到上面路径。

---

## 第三步：⚠ HUMAnN 3.9 ↔ MetaPhlAn 4.2.4 三连坑（本机共享 env 必踩，已有解法）

本机 metaphlan 是 4.2.4、humann 是 3.9，二者不完全兼容，**不处理必全样本 FAIL**。三个坑 + 固定解法：

| 坑 | 症状 | 解法 |
|:---|:---|:---|
| **① version-check 崩** | `CRITICAL ERROR: Can not call software version for metaphlan`；HUMAnN 取 `metaphlan --version` 最后一行第 3 列，但 4.2.4 多打一行 db 提示 → 解析 `int("MetaPhlAn")` 崩 | **PATH 前置一个 `metaphlan` shim**：对 `--version` 只回一行干净版本，其余参数透传真 metaphlan。改共享 env 的 `config.py` 会被别的项目撞，别改。 |
| **② db 代际不匹配** | `taxonomic profile not generated with v3 or vJun23`；装的 metaphlan 默认出 **vJan25** profile 被 HUMAnN 拒；v3 db 已 404 | 用 **vJun23 db**：`--metaphlan-options "--index mpa_vJun23_CHOCOPhlAnSGB_202307 --db_dir /Work_bio/references/Metagenomics/metaphlan_vJun23 --offline"` |
| **③ `--bowtie2out` 改名** | `unrecognized arguments: --bowtie2out`；HUMAnN 3.9 内部调 metaphlan 用旧 flag，4.2.4 已改叫 `--mapout` | **shim 里把 `--bowtie2out` 翻译成 `--mapout`** 再透传 |

另一坑：**必须一次性 `conda activate mag_biobakery` 再跑 humann**（不要用 `conda run -n ... humann` 逐条跑）——否则 humann 调 metaphlan 子进程时 PATH 丢失，回到坑①。shim 参考实现见 `17_Daniel_Mendes_gut_metagenomics/scripts/mpa_shim/metaphlan`。

---

## 第四步：运行（单样本 + 批量 3 并行）——已跑通的黄金脚本

参考 `17_Daniel_Mendes_gut_metagenomics/scripts/7_run_humann.sh`（10 样本实测跑通）。核心：

```bash
#!/usr/bin/env bash
set -uo pipefail
source /Work_bio/gao/miniforge3/etc/profile.d/conda.sh
conda activate mag_biobakery                       # 一次性激活，子进程共享 PATH（坑①）
PROJ=/path/to/project
export PATH="$PROJ/scripts/mpa_shim:$PATH"         # metaphlan version shim（坑①③）
MPA_DB=/Work_bio/references/Metagenomics/metaphlan_vJun23
MPA_IDX=mpa_vJun23_CHOCOPhlAnSGB_202307            # vJun23 → HUMAnN 兼容（坑②）
THREADS=18                                          # 3 并行 × 18 = 54，守 56 上限

# PE 数据：HUMAnN 不用配对信息，R1+R2 cat 成单文件喂
# cat sample_R1.fq.gz sample_R2.fq.gz > sample_merged.fq.gz

run_one(){
  local s=$1
  [ -s "$HOUT/$s/${s}_pathabundance.tsv" ] && { echo "[humann] $s done"; return 0; }  # 幂等/断点续跑
  humann --input "$CLEAN/$s.fastq.gz" --output "$HOUT/$s" --output-basename "$s" \
     --threads $THREADS --remove-temp-output \
     --metaphlan-options "-t rel_ab --index $MPA_IDX --db_dir $MPA_DB --offline --nproc $THREADS" \
     > "$LOG/$s.log" 2>&1 && echo "[humann] DONE $s" || echo "[humann] FAIL $s"
}
export -f run_one; export HOUT CLEAN LOG THREADS MPA_IDX MPA_DB
printf "%s\n" $SAMPLES | xargs -P 3 -I{} bash -c 'run_one "$@"' _ {}   # 滚动 3 并行
```

**在 tmux 里跑**（长任务）；判断"在跑/健康"看 **HUMAnN 内部 `humann_temp/*/<s>.log`（unbuffered）** 和 run_one 的 DONE/FAIL，**别只看 pgrep**（tee 会被 conda/buffer 吞，僵尸 bowtie2/diamond 进程会误导）。

---

## 第五步：合并 + 标准化 + regroup（每次必做）

```bash
for kind in genefamilies pathabundance pathcoverage; do
  humann_join_tables --input "$HOUT" --output "$MERGE/all_${kind}.tsv" \
       --file_name "$kind" --search-subdirectories
done
humann_renorm_table  --input all_genefamilies.tsv  --output all_genefamilies_cpm.tsv  --units cpm   --update-snames
humann_renorm_table  --input all_pathabundance.tsv --output all_pathabundance_relab.tsv --units relab --update-snames
humann_regroup_table --input all_genefamilies_cpm.tsv --groups uniref90_ko        --output all_ko_cpm.tsv
humann_regroup_table --input all_genefamilies_cpm.tsv --groups uniref90_level4ec   --output all_ec_cpm.tsv
humann_split_stratified_table --input all_pathabundance_relab.tsv --output split/   # 拆 stratified/unstratified
```

三张核心输出（每样本）：`*_genefamilies.tsv`（UniRef90，RPK，物种分层）、`*_pathabundance.tsv`（MetaCyc pathway，RPK）、`*_pathcoverage.tsv`（通路存在性 0–1）。regroup 目标：`uniref90_ko / _level4ec / _go / _pfam / _rxn`。

---

## 第六步：下游统计（组间功能差异）

- **必先归一化**（CPM/relab）才能跨样本比——否则测序深度差异被当成生物学差异。
- 组间差异：**MaAsLin2**（HUMAnN 官方搭档，处理 compositional + 协变量 + 随机效应）或小样本 **Wilcoxon + BH/FDR**。统计用 **unstratified**（community total）矩阵，别用 stratified（行数爆炸、多重检验失控）。
- 发现显著通路后**回 stratified 表看物种贡献**（物种替换 vs 单物种上/下调）——这是 HUMAnN 相对纯 taxonomy 的核心增值。
- R 包（MaAsLin2/vegan/ggplot2）装进 **regular_bioinfo**：`conda run` 的 `.libPaths()` 被全局 `R_LIBS`/`.Renviron` 统一指到 regular_bioinfo，下游脚本用它跑。

---

## 交付必给清单（清单驱动，与下面的正确性自查是两回事）

**交付前自查查的是"在的东西对不对"，它在原理上抓不到"该有的东西不在"。**
报告的 §8 文件清单表与交付目录**一起漏掉同一件**产物时，"报告提到的路径都存在"这条检查恒为 PASS。
真实事故（2026-08-18 用户发现）：RNAseq 的 proj27/proj28 **都把 count 与 TPM 矩阵漏在
`output_results/` 里没进交付**，客户拿到的只有我们的判读结果、没有能重算的数据；两个项目各七八项
自审检查全部通过。同一路线上 proj19/20 却交对了 —— **清单没写下来时，交对交错纯看运气。**

所以交付前必须再跑一遍**与项目无关的固定清单**（不是从报告里抽路径，那是闭环）：

| 必给 | 来源（第五步产物） | 说明 |
| :--- | :--- | :--- |
| `all_pathabundance.tsv` + `all_pathabundance_relab.tsv` | `humann_join_tables` / `renorm` | **通路丰度矩阵，客户唯一能重算的东西** |
| `all_genefamilies.tsv` + `all_genefamilies_cpm.tsv` | 同上 | 原始 RPK 与归一化版都给 |
| `all_pathcoverage.tsv` | 同上 | 通路存在性 |
| regroup 表 `all_ko_cpm.tsv` / `all_ec_cpm.tsv`（做了才给） | `humann_regroup_table` | |
| stratified / unstratified 拆分表 `split/` | `humann_split_stratified_table` | 物种贡献拆分是本路线的核心增值 |
| 差异通路检验表（MaAsLin2 / Wilcoxon 结果） | 第六步 | 我们的判读，**不能替代上面的矩阵** |
| 图件 PDF（**逐张人眼看过**） | | 只给 PDF，不给 PNG |

真实教训：`18_Pengpeng_Zhou`（0723 交付）功能部分只给了 `differential_pathways_humann.tsv` 一张
检验结果表，`humann_merged/` 里的 pathabundance / genefamilies_cpm / pathcoverage **一张没进交付**。
客户想换个阈值或挑自己关心的通路，手里没有能算的东西。

**两条通用判据：**
1. **"数据本身"必给，不能只给"我们的判读"。** 客户要能换阈值、换检验、挑自己关心的对象重算 ——
   只给差异检验表 / 汇总表 = 数据没交。
2. 清单里的每一项还必须**出现在报告 §8 的文件清单表里**；两侧对查，才能同时挡住"目录里有但报告
   没说""报告说了但目录里没有"，以及"两边一起没有"。

---

## 资源与耗时（本机实测，project 17：17–27 M pairs/样本）

- 单样本：MetaPhlAn 预筛几分钟 + nucleotide(bowtie2) ~40 min + **DIAMOND translated ~5–8 h（主导！）** ≈ **8–9 h/样本**。
- 并发：**3 样本 × `--threads 18` = 54 线程**（load ~51，守 56 上限）；吞吐 ~3 样本 / 8.5 h；**10 样本 ~24–30 h**。
- **DIAMOND 无进度条**：健康判断 = 进程 CPU 贴满（~1600%/进程）+ `humann_temp/*/tmp*/diamond-tmp-*` 每几分钟出新分块 + log 无 error。**别因为它慢/输出文件暂时不长就杀**（分块间不写出是正常的）。
- 提速旋钮（权衡灵敏度）：`--bypass-translated-search`（跳 diamond，快几十倍但灵敏度大降，不推荐正式用）；UniRef90 **EC-filtered**（~0.9G）代替 full（只覆盖有 EC 注释的酶，适合只要 KEGG/酶的项目）。磁盘紧张加 `--remove-temp-output`（temp 每样本几十 G）。

---

## Common Mistakes

| 坑 | 症状 | 解法 |
|:---|:---|:---|
| PE 当配对喂 | HUMAnN 不用配对信息 | `cat R1 R2` 成单文件再喂 |
| 逐条 `conda run humann` | 回到 metaphlan version 坑 | 一次性 `conda activate` 再跑 |
| 忘归一化就比组 | 深度差异被当生物学差异 | 先 `humann_renorm_table` |
| 拿 stratified 做检验 | 行数爆炸、FDR 失控 | 用 `humann_split_stratified_table` 的 unstratified |
| 只看 pgrep 判进度 | 被 tee buffer/僵尸进程误导 | 看 `humann_temp/*.log` + DONE/FAIL exit code |
| 用 gzip 大小估 read 数 | 低估近一倍、错判达标 | 以 fastp 实测为准 |

---

*worked example：`17_Daniel_Mendes_gut_metagenomics/scripts/7_run_humann.sh` + `scripts/mpa_shim/metaphlan`（10 样本 AL vs IF 实测跑通）。原理教程见 `facilities/bioinfo_technicals/shotgun_meta_gemonics/3_taxonomy_and_functional_profiling_HUMAnN.md`。*
