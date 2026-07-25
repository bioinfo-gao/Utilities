# Shotgun 宏基因组：三条路线的选型与编排总览

> 本目录（`shotgun_meta_gemonics/`）四篇的**入口 / 索引**。回答一个问题：**一个 shotgun 宏基因组项目该跑哪几条路线、什么顺序、谁 gated 在谁后面。**
> 组合不是新分析类型——"全套 shotgun = 组成 + 功能 + MAG"本就是标准全服务交付，只是三条已有路线**按序编排**。

---

## 三条正交路线（一张表看清）

| 路线 | 回答 | 工具 / 管线 | 组装? | 速度 | 对应 skill | 原理篇 |
| :--- | :--- | :--- | :---: | :---: | :--- | :--- |
| **组成 taxonomy** | 谁在这里、各占多少 | nf-core/taxprofiler（Kraken2+Bracken / MetaPhlAn） | 否 | 快（分钟/样本） | `/taxnom` | `1_introduction_and_assembly_or_not` |
| **功能 function** | 它们能干什么（pathway/gene family 丰度、KO/EC） | HUMAnN 3（mag_biobakery 原生） | 否 | 慢（~8h/样本，diamond 主导） | `/tax-functional-humann` | `3_taxonomy_and_functional_profiling_HUMAnN` |
| **基因组 MAG** | 能否拼出基因组草图、它们是谁、编码哪些基因 | nf-core/mag | 是 | 重（GTDB r226 库 ~271GB、组装/分箱耗内存） | `/tax-assembly-mag` | `2_MAG` |

**三者正交、互补，不是二选一**：组成相近可功能不同（株差异），物种不同可功能冗余；MAG 给基因组级证据、抓库里没有的新菌。

---

## 决策：这个项目跑哪几条？（MANDATORY — user directive 2026-07-21）

```
任何 shotgun 宏基因组项目
   └─ Phase 1 assembly-free = 组成 + 功能 → 默认自动做 /taxnom + /tax-functional-humann，
      两者捆绑为 Phase 1 的标准交付，不是"按需附加"。
      **除非用户明确说不做功能（"不要HUMAnN"/"只要taxonomy"这类），否则 HUMAnN 一律跟上。**
      客户送样单里较窄的措辞（如只写"taxonomic profiling"）不构成跳过功能的理由——
      默认判据是"用户（Gao）有没有明确说不做"，不是"客户报价单写了什么"。拿不准就两条都跑，
      而不是回退到只做组成再等着被问。
   └─ Phase 2 assembly-based MAG = 永远不自动跑，等 Gao 看完 Phase 1 数据/结构后明确批准。
      Phase 1 交付完成时必须主动告知 Gao"Phase 2 MAG 已具备条件，等你批准"——不是等他来问。
```

- **组成 + 功能** 是 Phase 1 assembly-free 的标准组合，覆盖绝大多数干预对照类问题（IF vs AL、疾病 vs
  健康…）的主诉求，默认一起跑。
- **MAG** 永远 gated 在人工批准之后，且通常等 Phase 1 出完主交付、机器空出来再放行（组装/GTDB-Tk 比
  HUMAnN 更吃 CPU/RAM，别叠加）。深度判据（per-sample ≥10 Gbp 才稳出高质量 MAG；深度薄如 ~4 Gbp/样本
  → 必须 group co-assembly 提升低丰度菌信号）仍然适用，只是现在触发点是"批准之后"而非"要不要做"的
  前置筛选。

---

## 推荐编排顺序（含 gating）

```
Phase 1  ── /taxnom (taxprofiler)  → QC/去宿主 + Kraken2/Bracken + MetaPhlAn + taxpasta 合表
   │            └─ 去宿主 unmapped reads 直接复用给下一步（别重复去宿主）
   │            └─ 下游 R：α/β 多样性 + 差异丰度 → 出主交付
   │
Phase 1b ── /tax-functional-humann (HUMAnN)  ← 复用 Phase 1 的 clean reads
   │            └─ diamond ~8h/样本、3 并行；功能表 join/renorm/regroup → 补进同一交付
   │            └─ 【默认自动跟上，与 Phase 1 一起构成"Phase 1 assembly-free"完整交付——
   │                不是可选项，除非 Gao 明确说不做】
   │
   ▼  Phase 1 交付完成 → 主动告知 Gao：Phase 2 MAG 已具备条件，等待批准（不是等他来问）
   │
Phase 2  ── /tax-assembly-mag (nf-core/mag)  ← 永远等 Gao 明确批准才跑，不自动触发
                └─ 先备好 GTDB r226（~271GB）；group co-assembly；GTDB 分类 + bin 丰度
```

**资源不叠加原则**：HUMAnN（54 线程满载）跑着时不要同时启 MAG 组装；等 functional 收尾、机器空出再上 MAG。多管线并跑参考 `/corun` playbook。

---

## 关键前提与共用资源

- **去宿主一次、多路复用**：Phase 1 taxprofiler 的 `*.unmapped_{1,2}.fastq.gz` 同时喂 HUMAnN 和 MAG，别各自重复去宿主。
- **数据量以 fastp 实测为准**：gzip 大小反推会低估近一倍（宏基因组高复杂度、压缩率低），直接影响 diamond 耗时和 MAG 深度判断。
- **环境**：taxprofiler/mag 走 nextflow（`mag_biobakery` env 调度 + 容器）；HUMAnN 走 `mag_biobakery` 原生二进制。R 下游包装进 `regular_bioinfo`。
- **worked examples**：`8_taxprofiler_setup`（taxprofiler）、`15_mag_setup`（mag 5.4.2）、`17_Daniel_Mendes_gut_metagenomics`（三条全跑的实战：组成+功能已交付，MAG 二期）。

---

*索引 · 本目录其余三篇是各路线的原理/操作详解；三条路线的可执行 setup 分别是 `/taxnom`、`/tax-functional-humann`、`/tax-assembly-mag`。*
