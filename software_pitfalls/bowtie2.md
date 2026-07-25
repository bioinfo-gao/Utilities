# bowtie2 / bowtie2-build 坑

## 本机 conda env 里没有能用的现代 bowtie2-build，别默认能用

**症状**：
- `regular_bioinfo` env：**完全没装** `bowtie2`/`bowtie2-build`。
- `mag_biobakery` env：装了但是 **v2.2.3（2014 年）**，**不支持 `--threads`**，单线程跑一个哺乳
  动物级别基因组（如小鼠 GRCm39 ~2.7 Gb）极慢，实际不可用。

**已踩坑两次**：
- **Project 18（2026-07-21）**：发现 `mag_biobakery` 的 bowtie2 太老后，放弃"独立预建索引"这条路，
  改为让 nf-core/taxprofiler 在**自己的 singularity 容器内现场建索引**（容器内是现代多线程版本），
  只保留 `--hostremoval_reference`，删掉 `--shortread_hostremoval_index`。
- **Project 17（同一天，2026-07-21，同一个坑踩了第二次）**——因为没有一个固定去处能先查到 proj18
  已经踩过——需要建一个**独立于某次 pipeline 之外、可长期复用**的共享 mouse Bowtie2 索引（不能靠
  "让 pipeline 现场建"，那个索引建在 pipeline work 目录里，跑完可能被清理，也不方便被其它项目复用）。
  改用**该 pipeline 实跑时已经缓存下来的 singularity 镜像**（如
  `depot.galaxyproject.org-singularity-bowtie2-2.4.2--py38h1c8e9b9_1.img`，通常在
  `NXF_SINGULARITY_CACHEDIR` 指向的目录，例如 `/Work_bio/gao/configs/.singularity/`）直接跑：
  ```bash
  singularity exec --bind /Work_bio:/Work_bio "$SIF" \
      bowtie2-build --threads 20 "$REF" "$IDXDIR/GRCm39"
  ```
  **结果确认**：tmux 后台跑 ~46 min 构建成功（2026-07-21 23:16 → 2026-07-22 00:02），6 个索引文件
  落盘 `/Work_bio/references/Mus_musculus/GRCm39/mouse_gencode_M35/bowtie2_index/GRCm39.{1,2,3,4,
  rev.1,rev.2}.bt2`，供本项目及后续小鼠项目直接复用（无需再建）。

**规则**：
1. 需要 bowtie2 时，先 `bowtie2-build --version` 确认版本，**不要默认 `regular_bioinfo`/
   `mag_biobakery` 有能用的**——目前两者都不合格（前者没装，后者太老）。
2. 只是**给单个 pipeline 跑一次**、不需要跨项目复用的索引：最简单是**不预建**，直接让 pipeline 在
   自己容器里现场建（project 18 的选择）——省事且版本必然匹配。
3. 需要**独立预建、供多项目长期复用**的索引：用该 pipeline **已缓存的 singularity 镜像**跑
   `singularity exec ... bowtie2-build`，不要临时装/升级某个 conda env 的 bowtie2（会产生版本漂移，
   以后还要重新验证）。

关联：[[reference_conda_run_subprocess_pitfalls]]（另一类 conda env 相关坑）。
Proj18 详情：`project_18_pengpeng_zhou_gut_meta`（memory）。
Proj17 详情：`project_17_daniel_mendes_gut_metagenomics`（memory）。
