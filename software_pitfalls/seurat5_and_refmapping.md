# Seurat 5 与参考映射（SingleR / Azimuth / ProjecTILs）的坑

> 2026-09-17 proj23（人儿童骨髓 B-ALL，6 样本 19,858 cells）首次跑通 20 章教程时实测。
> 本文只收**不报错或报错但指向错方向**的那几个；装包类的坑在
> [conda_r_env_build.md](conda_r_env_build.md) §2f。

---

## §1 ⚠ `ProjecTILs::load.reference.map()` 不带参数拿到的是**小鼠**图谱

**本文最重要的一条 —— 它不报错，跑得通，结论错。**

```r
ref <- ProjecTILs::load.reference.map()     # 下载 ref_TILAtlas_mouse_v1.rds ← 小鼠！
```

函数体里硬编码 `refFileName <- paste0(getwd(), "/ref_TILAtlas_mouse_v1.rds")`。
把它用在**人**的数据上，基因符号大小写都对不上（`CD8A` vs `Cd8a`），
结果要么被 `filter.cells = TRUE` 大面积丢弃、要么映射到无意义的状态，
而**整个过程只在日志里留下一行毫不起眼的文件名**。

proj23 里这句旁边的注释写着"默认下载 human TIL atlas" —— 注释存在了 49 天，
写它的人和读它的人都默认它是真的。**凡是"默认会怎样"的注释都要有一次实跑证据。**

**正确写法 —— 人类参考必须显式点名**：

```r
ProjecTILs::list.reference.maps()   # 先看有哪些
#   human: CD4 / CD8 / DC / MoMac      (sketched_*_human_ref_v*.rds)
#   mouse: TILs / Virus_CD4T / Virus_CD8T

refs <- ProjecTILs::get.reference.maps(collection = "human", reference = "CD8",
                                       directory = "<项目内固定目录>", as.list = TRUE)
ref  <- refs$human$CD8      # 返回结构是 list(collection = list(reference = Seurat))
```

**验收判据（一定要看，别只看它跑通了）**：

```r
head(rownames(ref))                      # 人类应是大写 GNLY / CCL4 / CXCL13
levels(factor(ref$functional.cluster))   # human CD8 应是 CD8.NaiveLike/CM/EM/TEMRA/TPEX/TEX/MAIT
```

**⚠ 别把高过滤率归错因**（2026-09-17 proj23 实测，一次对照实验就能分清）：

| 设置 | 结果 |
| :--- | :--- |
| `filter.cells = TRUE` | 3478 → **70（移除 98%）**，日志打印 `3408 out of 3478 ( 98% ) non-pure cells removed` |
| 同一批细胞的表达层面 | CD8A/B+ **33.2%**、CD4+ **7.1%**、NKG7/GNLY+ 16.0% |
| `filter.cells = FALSE` | 3478 全投影，但 **81% 挤进 CD8.CM** 一个状态 |

⇒ 移除是 ProjecTILs **内部 scGate 纯度门控**干的，**不是**"CD8 图谱不覆盖 CD4/NK"
（覆盖范围解释不了 98%）。归错因会让你去换更宽的图谱，而真问题是这批细胞不像纯 T。

⇒ **关掉过滤不是补救**：投影总把每个细胞派给最近的状态，所以参考不合适时
**不报错、图也画得出来**，特征是**状态坍缩**。
**两条判据要一起看**：① 过滤率；② 最大状态占比（>70% 就该警觉）。②
在过滤率正常时也能抓到问题，比 ① 更通用。

**⚠ CD8 图谱只覆盖 CD8 T 细胞。** 把 CD4 与 NK 一起投进去，它们会被 `filter.cells` 丢掉 ——
这与"TIL 状态谱和你的组织不重叠"是**两个不同的原因**，报告里必须分开说，
否则会把"参考选窄了"误读成"这批细胞状态不匹配"。

## §2 Seurat 5 的样本名 `_` → `-`：正向变换可逆性不对称

`Read10X()` 用 `_` 连接样本前缀与 barcode，所以多样本读入时样本名里的 `_` 要先换成 `-`：

```r
names(datadirs) <- gsub("_", "-", samples$sample_name)   # 正向，没问题
#   PBMMC_1       -> PBMMC-1
#   ETV6-RUNX1_1  -> ETV6-RUNX1-1
```

**反向就不行了** —— 因为你无法从结果里区分"哪个 `-` 是换来的、哪个是名字自带的"：

```r
gsub("-", "_", "ETV6-RUNX1-1")   # "ETV6_RUNX1_1"  ❌ 与样本表对不上 => match() 给 NA
```

proj23 实测：6 个样本里 **3 个 NA，恰好是 3 个 CASE 样本**。
若没有 `stopifnot(!anyNA(idx))`，`samples$sample_group[NA]` 静默给 `NA`，
**一半样本的分组标签变成 NA**，而 UMAP、聚类、出图全部正常。

**修法：不要反解，拿正向变换本身去匹配。**

```r
idx <- match(as.character(seu$orig.ident), names(datadirs))
stopifnot(!anyNA(idx))
```

**推广**：凡是"A 经变换 f 得到 B，之后要从 B 找回 A"的地方，
**保留 f(A) 去比对**，不要写 f⁻¹ —— 只要 f 不是单射，f⁻¹ 就是在猜。

## §3 `IntegrateLayers(method = FastMNNIntegration)` 需要 SeuratWrappers

`CCAIntegration` / `RPCAIntegration` / `HarmonyIntegration` 在 Seurat 本体，
**`FastMNNIntegration` 与 `scVIIntegration` 在 SeuratWrappers**。
不 `library(SeuratWrappers)` 的后果是 `object 'FastMNNIntegration' not found`，
**而且是在前三种方法都跑完之后才报** —— 横评脚本的排列顺序决定了你浪费多少算力。

## §4 attach 一个包不会把它 Imports 的泛型带进搜索路径

实测（proj23 3-2 与 6-1 两章）：

```r
library(Seurat); library(clustree); library(ggplot2); library(patchwork); library(dplyr)
exists("reducedDim")   # FALSE —— 属于 SingleCellExperiment

library(Seurat); library(miloR); library(ggplot2); library(dplyr)
exists("colData")      # FALSE —— 属于 SummarizedExperiment（Milo 是 SCE 子类也没用）
```

直觉容易认为"对象是 SCE 子类，所以取值函数应该能用"，**不成立**。
要么显式 attach，要么写成 `SingleCellExperiment::reducedDim()` / `SummarizedExperiment::colData()`。

## §5 `isOutlier(..., batch=)` 的阈值属性是矩阵，不是向量

```r
o  <- scuttle::isOutlier(x, type = "higher", nmads = 3, batch = sample_id)
th <- attr(o, "thresholds")     # 2 x n样本 矩阵：行 lower/higher，列名 = 样本
v  <- th["higher", ]            # 已经是每样本一个值的具名向量
```

拿它去 `tapply(v, NULL, identity)` 会报 `arguments must have same length`（proj23 原代码如此）。
**并且取值要按名字**，不要假设列顺序与 `levels(factor(batch))` 一致：

```r
stopifnot(setequal(names(v), samples_lv))
data.frame(sample = samples_lv, mt_upper = as.numeric(v[samples_lv]))
```

## §5a `UpdateSeuratObject()` 不把 `Assay` 转成 `Assay5`，却宣称"已是最新"

**症状**（proj23 6-2 章，数据是 SIB 课程的 `proB.rds`，Seurat 4.0.4 存的）：

```
Error in UseMethod():
! no applicable method for 'JoinLayers' applied to an object of class "c('Assay', 'KeyMixin')"
```

而上游明明写了"先更新结构再用"：

```r
if (inherits(proB[["RNA"]], "Assay")) proB <- UpdateSeuratObject(proB)   # ← 不够
```

**根因**：`UpdateSeuratObject()` 只更新 slot 结构与 key，**不改 assay 的类**。
更要命的是它跑完会打印

```
Object representation is consistent with the most current Seurat version
```

**这句话会让人以为对象已经是 v5 语义了**，而 `class(obj[["RNA"]])` 仍是 `Assay`。
于是所有 v5-only 的 API（`JoinLayers()`、多 layer 操作）在几十行之后才炸。

**修法**：显式转换 + 断言。

```r
if (inherits(obj[["RNA"]], "Assay") && !inherits(obj[["RNA"]], "Assay5")) {
  obj <- UpdateSeuratObject(obj)
  obj[["RNA"]] <- as(obj[["RNA"]], "Assay5")
}
stopifnot(inherits(obj[["RNA"]], "Assay5"))
```

实测转换后 `Layers()` 给出 `data, counts, scale.data`，`JoinLayers()` 正常，
`LayerData(layer = "counts")` 拿到 21103 × 3021。

**⚠ 另一条路**：只是要取 counts 的话，`LayerData(obj, assay = "RNA", layer = "counts")`
**对旧 `Assay` 对象同样有效**（实测同样 21103 × 3021）——
即"报错的那一行其实可以不写 `JoinLayers`"。选哪条看你后面还要不要 v5 语义。

---

## §5b `future::plan("multicore")` 与包内部的 BiocParallel fork 撞车

**症状**（proj23 4-3 章 scGate 实测）：

```
Error: BiocParallel errors ... first remote error:
INTERNAL ERROR: Cannot remove from 'multicore-<hash>' registry. MulticoreFuture not registered.
```

**根因**：两个**各自都正确**的并行设置叠在一起。

1. 项目的 `set_parallel()` 统一设了 `future::plan("multicore", workers = 16)`（Seurat 走 future）；
2. `scGate(..., ncores = 8)` 在 `ncores > 1` 时**自己新建 `BiocParallel::MulticoreParam(8)`** 再 fork 一层。

两层 fork 叠加，future 的内部 registry 对不上。**同族问题见
[joblib_nested_threads.md](joblib_nested_threads.md)** —— 那条是线程数被子进程乘出来，
这条是 fork 机制互相踩，母题相同：**「限流/并行」的设置会被下游库再解释一次。**

**修法**：调用期间把 future 切回串行，让 BiocParallel 这一层自己并行：

```r
old_plan <- future::plan("sequential")
on.exit(future::plan(old_plan), add = TRUE)
seu <- scGate(seu, model = models$human$generic$Bcell, ncores = 8)
future::plan(old_plan)
```

实测 19,858 cells 的 B 细胞门控 **1.0 分钟**跑完，无需退到 `ncores = 1`。

**判据**：报错里同时出现 `BiocParallel` 与 `Future`/`multicore-<hash>` 两个词，
就是这一类；不要去调 workers 数量，那不是原因。

### 同族第二条：`future` 计划下 `set.seed()` 不再保证可复现

```
UNRELIABLE VALUE: One of the 'future.apply' iterations ('future_lapply-1') unexpectedly
generated random numbers without declaring so. ... the overall results might be invalid.
```

Seurat 内部调 `future_lapply` 时**没有声明 `future.seed`**，
所以在 `plan("multicore")` 下，`FindClusters()` 这类随机算法的结果**跨次运行不保证一致**，
而 `set.seed()` 给人"已经固定住了"的错觉。proj23 实测：3-2 章刷出 17 条。

**修法不是一刀切关并行**，按各章的耗时结构分别处理（proj23 的实际做法）：

| 章 | 耗时大头 | 处置 |
| :--- | :--- | :---: |
| 3-2 聚类（整章都是随机算法，4 分钟） | 无 | **整章** `future::plan("sequential")` |
| 3-1 整合（四种方法 11 分钟，随机的只有末尾粗聚类） | 整合 | **只包住粗聚类那段**，整合继续并行 |
| 7-1 BPCells（磁盘 I/O 是大头） | I/O | **只包住 sketch 聚类那段** |

**⚠ 两个定位教训**：

1. **警告在哪一章 ≠ 出自哪一段。** 第一次修时想当然改了显式写着 `set.seed()`
   和重抽样的那一段，重跑后**17 条一条没少**；回 HTML 逐条看上文才发现全部来自
   另一段的分辨率扫描循环。
2. **回读计数时要把自己的注释排除掉。** 把警告原文写进注释解释成因之后，
   `grep -c "UNRELIABLE VALUE"` 会把注释也数进去（实测 0 条真警告被报成 1 条）。
   数真警告要用它的固定前缀 `UNRELIABLE VALUE: One of the 'future`。

---

## §6 一条 0 秒算力的预检：静态反查所有函数的来源包

§3/§4 这一类（以及 metap/scrapper 那一类）**全都可以在渲染之前找出来**：
从每个 `.qmd`/`.R` 抽出代码 → `parse()` + `all.names()` 取符号 →
减去 base、本地定义、已 `library()`/`pkg::` 覆盖的 → 剩下的到已装包的
`getNamespaceExports()` 里反查。

两个实现细节（第一版都写错，会让结果完全不可用）：

- **一行多个 `library()` 必须 `gregexpr` 全取**；`gsub(".*library\\((...)\\).*", "\\1", x)`
  的前缀 `.*` 是贪婪的，只会拿到最后一个 ⇒ 把已加载的包全报成缺失，噪声淹没真信号；
- **dplyr 的 NSE 会把列名混进 `all.names()`**（`logFC`、`gene`、`cluster`、`n`），
  它们会被误配到恰好导出同名函数的包上 ⇒ 这一类要人工过滤，不能全信。

完整实现与本轮九个事件的排查链见
`23_R_based_scRNA_tutorial_2026/docs/P23_run_and_troubleshooting_log_0917.md`。

## 相关

- [conda_r_env_build.md](conda_r_env_build.md) §2f — metap / scrapper：`library()` 得了不等于函数能调用
- [r_download_timeout.md](r_download_timeout.md) — Azimuth / ProjecTILs 参考下载全灭的真正原因
- `~/.claude/skills/scrna/SKILL.md` — scRNA 分析的选型与静默错误清单
