# Seurat v5 `IntegrateLayers()`：CCA / RPCA / Harmony / FastMNN / scVI 五种方法的统一接口

> 2026-11-19 · 内部技术笔记

## 结论

"统一接口"指 **Seurat v5 的 `IntegrateLayers()`**。五种整合方法共用同一套调用方式：数据按批次拆成 layers，用 `method =` 选算法，结果统一写成一个新的降维对象（DimReduc）。下游的 `FindNeighbors` / `RunUMAP` / `FindClusters` 只要换一个 `reduction` 名字，所以可以在同一个对象里把五种方法并排比较。

但**接口统一，不等于输入统一，也不等于输出的含义统一**：

- 五种方法读入的数据不同（PCA / normalized data / raw counts）。
- 输出都只是低维 embedding，不是校正后的表达矩阵。**DE、marker、pseudobulk 一律用未校正的 counts。**
- **只按技术批次拆 layer，绝不按 condition 拆。**

## 1. 统一流程

```r
library(Seurat); library(SeuratWrappers)   # FastMNN 和 scVI 的 wrapper 在 SeuratWrappers 里

obj[["RNA"]] <- split(obj[["RNA"]], f = obj$batch)   # 按技术批次拆 layer
obj <- NormalizeData(obj) |> FindVariableFeatures() |> ScaleData() |> RunPCA()

obj <- IntegrateLayers(obj, method = CCAIntegration,     orig.reduction = "pca", new.reduction = "integrated.cca")
obj <- IntegrateLayers(obj, method = RPCAIntegration,    orig.reduction = "pca", new.reduction = "integrated.rpca")
obj <- IntegrateLayers(obj, method = HarmonyIntegration, orig.reduction = "pca", new.reduction = "harmony")
obj <- IntegrateLayers(obj, method = FastMNNIntegration, new.reduction = "integrated.mnn")
obj <- IntegrateLayers(obj, method = scVIIntegration,    new.reduction = "integrated.scvi",
                       conda_env = "<scvi-tools 所在 env 路径>")

for (r in c("integrated.cca","integrated.rpca","harmony","integrated.mnn","integrated.scvi")) {
  obj <- FindNeighbors(obj, reduction = r, dims = 1:30)          # dims 不能超过该 reduction 的实际维数
  obj <- FindClusters(obj, cluster.name = paste0(r, "_clusters"))
  obj <- RunUMAP(obj, reduction = r, dims = 1:30, reduction.name = paste0("umap.", r))
}
obj <- JoinLayers(obj)   # 做 DE/marker 之前必须把 layer 合回去
```

> 上述代码按 Seurat v5 官方 integration vignette 的写法整理，本笔记写作时未在本机实际运行。

## 2. 五种方法分别在做什么

| 方法 | 原理 | 实际读入的数据 | 速度和规模 | 优点 | 主要风险 |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **CCA** | 用典型相关分析（canonical correlation analysis）找批次间共享的相关结构，再以 MNN anchors 做校正 | scale.data / HVG | 慢，数十万细胞时吃力 | 批次差异大时混合能力强 | **过度校正**：会把批次特有的真实群体硬拉到别的群体上 |
| **RPCA** | 把每个批次投影到对方的 PCA 空间里找 anchors（reciprocal PCA） | scale.data / HVG | 比 CCA 快不少 | 保守，适合细胞类型不完全共享的批次 | 批次差异很大时混合不足；`k.anchor` 默认 5，调大会更激进 |
| **Harmony** | 在 PCA embedding 上迭代做软聚类，同时修正各批次的质心 | `pca` | 很快，百万级细胞也能跑 | 简单批次效应下表现好，参数少 | 只改 embedding，不改表达值；`theta` 过大会抹掉生物学差异 |
| **FastMNN** | batchelor 的互为最近邻（mutual nearest neighbors），在自己算的 PCA 空间里逐批合并 | **normalized data**（内部自己做 PCA，不用你的 `pca`） | 中等 | 对细胞类型组成差异比较稳 | 合并顺序会影响结果；需要 SeuratWrappers + batchelor |
| **scVI** | 变分自编码器（variational autoencoder）。批次作为协变量，用负二项（NB）或零膨胀负二项（ZINB）似然对 **raw counts** 建模 | **counts**（不用 normalize/scale/PCA） | CPU 可以跑，GPU 更快；适合大规模、多批次的复杂场景 | scIB 基准里对复杂批次结构表现最稳的一类 | 有随机性，必须固定 seed；跨 R/Python 的环境依赖最脆弱；latent 维数默认偏低 |

参考的公开基准是 Luecken et al. 2022（scIB）：简单批次效应下 Harmony 和 Seurat 系方法表现好；批次多、结构复杂（跨实验室、跨协议）时 scVI/scANVI、Scanorama 更稳。这是文献结论，不是本机实测。

## 3. 统一接口背后的三个不统一

1. **输入不同。** CCA、RPCA、Harmony 吃你给的 `pca` 或 scale.data。FastMNN 从 normalized data 自己算 PCA。scVI 直接读 counts。所以你在 PCA 那一步换 HVG 数或 dims，只影响前三种。五种方法的结果不完全是"同一起点、只换算法"的对照。
2. **输出都是低维 embedding，不是校正后的表达矩阵。** v5 里五种方法都只产出 reduction，只能用来做邻接图、聚类、UMAP 和注释。**DE、marker、pseudobulk 一律用未校正的 counts**，批次作为协变量放进模型（例如 `~ batch + condition`）。
3. **维数和尺度不同。** Harmony 继承 PCA 的维数。scVI 的 latent 一般是 10–30 维，而且各维不按方差排序。所以 `dims = 1:30` 不能照抄到每种方法上，取多少维要看各 reduction 的实际维数。

## 4. 按什么拆 layer：只拆技术批次

- `split(f = ...)` 只能用**技术批次**：测序 lane、文库批、10x 通道、捐献者（donor）这类。
- **不能按 condition 拆。** 处理组与对照组拆开再整合，等于告诉算法"这两组的差异是要去掉的噪声"，处理效应会被部分抹掉，之后再做差异丰度或 DE 都会低估。
- 如果批次和 condition 完全重合（一个批次 = 一个条件），这是设计混杂，任何整合方法都分不开，应该在报告里如实写出这个限制。

## 5. 怎么在五种方法里选

并排跑完之后，看两类指标，两类缺一不可：

| 维度 | 看什么 | 工具和指标 |
| :--- | :---: | :---: |
| 批次混合（batch removal） | 同一细胞类型里，不同批次的细胞是否混在一起 | iLISI、kBET、batch ASW |
| 生物学保留（bio conservation） | 细胞类型是否仍然分得开，已知的批次特有群体是否还在 | cLISI、ARI/NMI（对照注释标签）、已知 marker 的 FeaturePlot |

实操判据：

- **只追求 UMAP 混得最匀，等于选过度校正最严重的方法。** 一定要找一个"应该只在某个批次出现"的群体，看它有没有被并到别的群里。
- 五种方法给出的大类结构一致，分歧只在细分亚群上，说明大类结论稳健，亚群结论要谨慎写。
- 某个群体只在一种方法里出现，大概率是这种方法自身的产物，不要报。

## 6. 本机已知的坑

- **`FastMNNIntegration` 和 `scVIIntegration` 不在 Seurat 本体里，在 SeuratWrappers 里。** proj23 吃过这个亏：三种整合方法全部跑完，才报 `FastMNNIntegration` 不存在。开跑前先 `library(SeuratWrappers)` 并确认 `exists("FastMNNIntegration")`。
- **scVI 必须设 seed，并跑两遍对比结果。** 带随机性的步骤，一轮跑完、断言全过，并不能证明结果是确定的。
- **GPU 只有 3 GB。** 大数据集上的 scVI 默认按 CPU 跑来估计时间。
