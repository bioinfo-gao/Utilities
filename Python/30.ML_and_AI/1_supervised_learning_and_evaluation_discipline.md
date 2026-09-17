# 机器学习（一）：监督学习与评估纪律 —— 怎么做才不会被审稿人打回来

> 建立日期：2026-09-17
> 用途：讲 **scikit-learn 的心智模型** 和 **评估纪律**。本系列三篇里，
> 「怎么算才算数」**只在本篇写一次**，第②③篇直接引用，不重复。
> 本目录另两篇：[②表示学习与深度框架](2_representation_learning_and_dl_frameworks.md) · [③LLM 工程层](3_llm_engineering_layer.md)
> 姊妹目录：`/home/gao/Utilities/Python/20.Notes_by_ZG/`（Python 核心模块、R↔Python 迁移）
> 版本号与"装没装"均为**本机实测**（2026-09-17，绝对解释器路径），见 §9。

---

## §0 结论先行：三条会**不报错地**给出虚高准确率

这三条是本篇的全部价值。其余章节都是它们的展开。

| # | 陷阱 | 症状 | 防法 |
| :--- | :---: | :---: | :---: |
| **1** | **分组泄漏**：同一个 donor / 样本的多个细胞或多个技术重复，**同时出现在 train 和 test** | 准确率 0.95+，换一批样本掉到 0.6 | `GroupKFold(groups=donor)`，**不是** `KFold` |
| **2** | **预处理泄漏**：`StandardScaler` / PCA / HVG 选择在**切分之前**对全量数据 `fit` | 高估几个百分点，看不出来 | 全部塞进 `Pipeline`，让交叉验证在**每一折内部**重新 `fit` |
| **3** | **特征选择泄漏**：先用**全量数据**做差异表达挑 top 基因，再交叉验证 | 随机标签也能做到 0.9 —— 这是生信里最经典的一种 | 特征选择必须写成 Pipeline 的一步，进到折内 |

> **三条是同一件事**：任何"看过测试集"的操作，哪怕只看了一眼分布，都会漏进去。
> **判据很简单：把测试集想象成明天才会到的样本。今天做不到的事，就是泄漏。**

### 🔴 一句话自查

> **交叉验证的每一折，都必须能从"只有训练集"这个状态独立重跑出来。**
> 做不到，那个数字就不能写进报告。

---

## §1 你已经在用 sklearn 了，只是被 scanpy 包住了

很多人以为"我不做机器学习"，但**本机实测**（`sc_tut_main` 的 scanpy 1.11.5 源码）：

| 事实 | 数值 |
| :--- | :---: |
| scanpy 里 `import sklearn` 的处数 | **37 处** |
| `sc.pp.pca` 的实现 | sklearn 的 `decomposition.PCA` / `TruncatedSVD` / `IncrementalPCA` |
| `sc.tl.tsne` 的实现 | sklearn 的 `manifold.TSNE` |
| `sc.tl.rank_genes_groups(method="logreg")` | sklearn 的 `linear_model.LogisticRegression` |
| 近邻图 | sklearn 的 `neighbors.KNeighborsTransformer`（可选路径） |

**⇒ 你不是"要不要开始用 sklearn"，而是"要不要看懂你已经在用的那部分"。**
这也解释了为什么本篇的评估纪律对单细胞同样适用：**降维和聚类也是 sklearn 的 estimator，
它们同样有"在谁身上 fit"的问题。**

> **一个直接的推论**：`sc.pp.pca` 是在**全部细胞**上 fit 的。
> 如果你接下来要训练一个分类器，**这个 PCA 已经看过测试集了** —— 见 §3.2。

---

## §2 sklearn 的心智模型：三个对象，一条铁律

### §2.1 三个对象

| 对象 | 接口 | 例子 | 一句话 |
| :--- | :---: | :---: | :---: |
| **Estimator（估计器）** | `fit` + `predict` | `LogisticRegression` `RandomForestClassifier` | 学一个映射，然后预测 |
| **Transformer（变换器）** | `fit` + `transform` | `StandardScaler` `PCA` `SelectKBest` | 学一组参数，然后改造特征 |
| **Pipeline（管道）** | 同时是上面两者 | `make_pipeline(StandardScaler(), PCA(50), LogisticRegression())` | 把若干步骤**绑成一个 estimator** |

**`fit` 学的东西存在哪？** 存在**属性名以下划线结尾**的地方：
`scaler.mean_`、`pca.components_`、`lr.coef_`。
**没有下划线的是你给的超参数**（`pca.n_components`），**有下划线的是它学到的**（`pca.components_`）。
这个命名约定是 sklearn 唯一需要背的东西。

### §2.2 铁律：`fit` 只在训练集上，`transform` 在两边都做

```python
# ❌ 泄漏：scaler 看过测试集的均值和方差
X_scaled = StandardScaler().fit_transform(X)
X_tr, X_te, y_tr, y_te = train_test_split(X_scaled, y)

# ✅ 正确
X_tr, X_te, y_tr, y_te = train_test_split(X, y)
sc_ = StandardScaler().fit(X_tr)
X_tr, X_te = sc_.transform(X_tr), sc_.transform(X_te)
```

**但手写这个几乎必然会在某处漏掉。** 所以：

### §2.3 🔴 Pipeline 不是"便利写法"，是**防泄漏的工程手段**

```python
from sklearn.pipeline import make_pipeline
from sklearn.model_selection import cross_val_score, GroupKFold

pipe = make_pipeline(
    StandardScaler(),
    SelectKBest(f_classif, k=500),     # 特征选择也必须在管道里
    LogisticRegression(penalty="l2", C=1.0, max_iter=5000),
)
scores = cross_val_score(pipe, X, y, groups=donor,
                         cv=GroupKFold(n_splits=5), scoring="roc_auc")
```

`cross_val_score` 会在**每一折内部**对 `pipe` 重新 `fit` —— 即 scaler 和特征选择
**各折各自重算，只看得到该折的训练部分**。这正是 §0 的第 2、3 条的机械化防法。

> **判据：任何在 `cross_val_score` 之外碰过 `X` 的操作，都要问一次"它看过测试集吗"。**

---

## §3 数据泄漏（data leakage）的五种形态 —— 生信版

这是本篇最承重的一节。**泄漏不报错、不警告，只让数字变好看。**

### §3.1 形态一：分组泄漏（最常见、最致命）

| 场景 | 为什么是泄漏 |
| :--- | :---: |
| **单细胞**：按细胞随机切分，同一个 donor 的细胞同时进 train/test | 模型学到的是"认这个 donor 的批次指纹"，不是"认这个细胞类型" |
| **bulk RNAseq**：同一个体的多个时间点分到两边 | 个体间差异远大于处理效应，模型在认个体 |
| **技术重复 / 多 lane** | 同一文库的两条 lane 分到两边，等于把答案抄给测试集 |

**防法固定**：

| 你的数据 | 用哪个 splitter |
| :--- | :---: |
| 每个样本独立，无分组 | `StratifiedKFold` |
| **有 donor / 个体 / 批次分组**（单细胞几乎总是） | **`GroupKFold(groups=donor)`** |
| 有分组 **且** 类别不平衡 | **`StratifiedGroupKFold`**（sklearn ≥1.0，本机 1.9.0 有） |
| 样本极少（n<20），想用满 | `LeaveOneGroupOut` |

**⚠ 单细胞的特别提醒**：一个 donor 有几千个细胞，`KFold` 会让**每个 donor 的细胞
几乎必然同时出现在两边**。这不是"小概率的坏运气"，是**结构性必然**。
细胞级 train/test split 得到的 0.98 accuracy **没有任何意义** —— 这与
「跨条件比较必须 pseudobulk」是同一个伪重复（pseudoreplication）问题的两种表现。

### §3.2 形态二：预处理泄漏

`StandardScaler`、`PCA`、`SelectKBest`、`SMOTE`、缺失值填补 —— 全部会学参数。
**在切分前 fit 一次 = 泄漏。**

**🔴 单细胞的隐藏版本**：你的特征矩阵往往已经是 `adata.obsm["X_pca"]`，
而那个 PCA 是 `sc.pp.pca` 在**全部细胞**上算的。
**把它直接喂给分类器做 CV，泄漏已经发生在你写第一行 ML 代码之前。**
严格做法是把 PCA 放进 Pipeline 从 counts 开始重算；
若计算上不可行，**必须在报告里写明这一点，并把结果降格为"探索性"**。

### §3.3 形态三：特征选择泄漏（生信最经典）

```
❌ 全部样本跑 DESeq2 → 取 top 200 DEG → 用这 200 个基因做 CV → AUC 0.95
```

这条路**用随机打乱的标签也能做到 0.9 左右** —— 因为 20000 个基因里总有 200 个
能在这 20 个样本上把随机标签分开。文献里叫 **selection bias**。

**✅ 正确**：特征选择是模型的一部分，必须进 Pipeline，在**每折的训练部分内**重新做。
如果特征选择用的是 DESeq2 这类 sklearn 外的工具，就要自己写一个 Transformer 包住它，
或者老老实实用 **nested CV（嵌套交叉验证）**：外层估性能，内层选特征与调参。

### §3.4 形态四：批次与标签共线

批次（batch）与分组（group）完全共线时，**模型学批次就能拿满分**，
而你无法从任何指标上看出来。这不是泄漏的修法问题，**是实验设计问题** ——
只能在报告里如实写"该设计无法区分处理效应与批次效应"。

### §3.5 形态五：标签泄漏

特征里混进了由标签导出的量。单细胞里最常见的形式：
**用 cluster 标签选出的 marker 基因，再去预测 cluster 标签**。
这是循环论证，指标必然接近 1，且**完全没有报错**。

---

## §4 指标：默认的 accuracy 几乎总是错的选择

### §4.1 不平衡下的 accuracy

类别比例 9:1 时，**全部预测多数类 = 90% accuracy**。这个数字毫无信息。

| 指标 | 什么时候用 | 本机实测可用 |
| :--- | :---: | :---: |
| `accuracy` | 类别大致平衡，且两类错误代价相同 | ✅ |
| `balanced_accuracy` | 不平衡；各类召回率的平均 | ✅ |
| `roc_auc` | 排序质量；**不平衡时偏乐观** | ✅ |
| **`average_precision`（PR-AUC）** | **不平衡时的首选**，对正类稀少更敏感 | ✅ |
| **`matthews_corrcoef`（MCC）** | 单个数概括混淆矩阵，**对不平衡最稳健** | ✅ |
| `f1` | 需要 precision/recall 的折中；注意 `average=` | ✅ |

### §4.2 🔴 ROC-AUC 与 PR-AUC 的差别不是风格问题

正类占 1% 时，一个把 100 个负类误判成正类的模型，
**ROC-AUC 几乎不受影响**（因为负类基数大，假阳性率只动了一点点），
**PR-AUC 会断崖下跌**（因为 precision 直接腰斩）。
**当你关心的是"报出来的阳性有多少是真的"，就必须看 PR-AUC。**
生信场景（候选基因筛选、罕见细胞类型识别）几乎都属于后者。

### §4.3 多分类的 `average=` 参数

| 取值 | 含义 | 什么时候 |
| :--- | :---: | :---: |
| `macro` | 各类指标**等权平均** | **默认选它**：小类和大类一样重要（罕见细胞类型） |
| `weighted` | 按各类样本数加权 | 想反映整体表现，但会被大类主导 |
| `micro` | 全局汇总后再算 | 多标签场景 |

**不写 `average=` 而多分类报了一个数，那个数通常是 `weighted`，会掩盖小类的失败。**

---

## §5 p ≫ n：生信的常态，也是最容易自欺的地方

RNAseq 的典型形状是 **20000 个基因 × 20 个样本**。

| 后果 | 说明 |
| :--- | :---: |
| **任何模型都能把训练集分到 100%** | 20000 维空间里 20 个点永远线性可分 —— 这不是模型好，是维度高 |
| **必须正则化** | `LogisticRegression(penalty="l1"/"l2")`、`ElasticNet`；不正则化的结果不用看 |
| **单层 CV 会高估** | 调参也用了同一份数据 ⇒ 用 **nested CV**：外层估性能、内层调参 |
| 🔴 **feature importance 不可信** | 共表达基因之间，重要性是**随机分配**的：同一份数据换个 `random_state`，top 20 基因能换掉一半 |

**关于 feature importance 的正确说法**：
它回答的是"**在这个模型里**，哪些特征被用上了"，
**不回答**"哪些基因在生物学上重要"。后者要靠差异表达 + 通路 + 实验验证。
**报告里不要把 feature importance 写成生物学结论。**

> 想要 p 值和效应量解释 ⇒ 那是 `statsmodels` / DESeq2 的活，不是 sklearn 的。
> 见 `20.Notes_by_ZG/Python_core_modules_for_bioinformatics.md` §4。

---

## §6 树模型与梯度提升：**本机全部未装**

| 包 | 定位 | `regular_bioinfo` | `sc_tut_main` |
| :--- | :---: | :---: | :---: |
| `xgboost` | 梯度提升（gradient boosting），表格数据的常胜军 | ❌ 未装 | ❌ 未装 |
| `lightgbm` | 同上，更快、内存更省 | ❌ 未装 | ❌ 未装 |
| `catboost` | 同上，类别特征处理最省心 | ❌ 未装 | ❌ 未装 |
| `sklearn.ensemble.HistGradientBoostingClassifier` | **sklearn 自带**的 LightGBM 式实现 | ✅ | ✅ |

**⇒ 先用 sklearn 自带的 `HistGradientBoosting*`。** 它和 LightGBM 是同一族算法，
在中小数据上差距很小，**而且不用新装依赖**（装依赖需要先获批准，见全局 §4）。
真的需要 xgboost/lightgbm 时再装，并回填 env yaml
（见 `20.Notes_by_ZG/Python_core_modules_for_bioinformatics.md` §7.2）。

**⚠ 小样本（n<100）上不要上树模型。** 树的方差大，n 小时 CV 结果不稳定；
正则化的线性模型（logistic / elastic net）几乎总是更稳、更好解释、更好写进报告。

---

## §7 类别不平衡：三种手段，优先级固定

| 手段 | 怎么做 | 优先级 |
| :--- | :---: | :---: |
| **调指标** | 换成 PR-AUC / MCC / balanced_accuracy | **① 先做这个** |
| **调权重** | `class_weight="balanced"`（多数 sklearn 分类器都支持） | ② 几乎无副作用 |
| **调阈值** | 不用 0.5，按验证集上的 PR 曲线选 | ③ 常被忘记，但最有效 |
| 重采样（SMOTE 等） | 需要 `imbalanced-learn`（**本机未装**） | ④ 最后才考虑 |

**🔴 重采样必须在 Pipeline 内、折内做。** 先 SMOTE 再切分 = 合成样本的"亲本"
同时进了 train 和 test，是 §3.2 的一个特别隐蔽的变种。

---

## §8 🔴 静默陷阱清单（不报错，只让数字变好看）

按"发现难度"排序，越靠前越难发现。

| # | 陷阱 | 症状 | 防法 |
| :--- | :---: | :---: | :---: |
| 1 | 分组泄漏（同 donor 跨 train/test） | 内部 0.95，外部数据 0.6 | `GroupKFold(groups=)` |
| 2 | 用全量数据选特征再 CV | 随机标签也能 0.9 | 特征选择进 Pipeline |
| 3 | `obsm["X_pca"]` 直接当特征 | PCA 已看过测试集 | PCA 进 Pipeline，或降格为探索性 |
| 4 | 调参和评估用同一份 CV | 高估几个百分点 | nested CV |
| 5 | 不平衡下报 accuracy | 90% 其实是"全猜多数类" | MCC / PR-AUC |
| 6 | 多分类不写 `average=` | 小类的失败被大类掩盖 | 显式 `average="macro"` |
| 7 | feature importance 当生物学结论 | 换 seed 就换一半 | 只当"模型用了啥" |
| 8 | 不设 `random_state` | 结果不可复现，且能"多跑几次挑好的" | 所有含随机性的对象都设 |
| 9 | `train_test_split` 不加 `stratify=y` | 小类可能整类不进测试集 | 分类问题一律加 |
| 10 | 用 `.score()` 而不知道它是什么 | 分类器默认 accuracy、回归器默认 R² | 显式 `scoring=` |

> **第 1–4 条是同一种病**：某个"看过全量数据"的步骤被留在了交叉验证之外。
> **机械化防法只有一个：能进 Pipeline 的全部进 Pipeline。**

---

## §9 本机实测：ML 相关模块矩阵（2026-09-17）

用绝对解释器路径探测（**不要用 `conda run -n`**，本机有 PATH 注入问题，
见 `20.Notes_by_ZG/Python_core_modules_for_bioinformatics.md` §8.1）。

| 模块 | `regular_bioinfo` | `sc_tut_main` | `sc_tut_traj` | `sc_tut_grn` | `sc_tut_spatial` |
| :--- | :---: | :---: | :---: | :---: | :---: |
| scikit-learn | 1.7.2 | **1.9.0** | 1.9.0 | 1.7.2 | 1.9.0 |
| umap-learn | ❌ | 0.5.12 | 0.5.12 | 0.5.12 | 0.5.12 |
| joblib | 1.5.3 | 1.6.0 | 1.6.0 | 1.6.0 | 1.6.0 |
| xgboost / lightgbm / catboost | ❌ | ❌ | ❌ | ❌ | ❌ |
| imbalanced-learn | ❌ | ❌ | ❌ | ❌ | ❌ |
| optuna / shap | ❌ | ❌ | ❌ | ❌ | ❌ |
| statsmodels | ❌ | 0.14.6 | — | — | — |

**复现命令**（本篇全部版本号的来源）：

```bash
for E in /Work_bio/gao/configs/.conda/envs/regular_bioinfo \
         /mnt/ex_8T_SSD/conda_envs/sc_tut_{main,traj,grn,spatial}; do
  echo "--- $(basename $E)"
  $E/bin/python -c "
import importlib.metadata as m
for p in ['scikit-learn','xgboost','lightgbm','catboost','imbalanced-learn',
          'optuna','shap','umap-learn','joblib','statsmodels']:
    try: print(f'  {p:20s} {m.version(p)}')
    except Exception: print(f'  {p:20s} NOT INSTALLED')"
done
```

**⚠ 并行度**：sklearn 的 `n_jobs=-1` 会吃满全部 64 个逻辑核，
**超出本机 28 物理核 / 56 线程的上限**。一律显式写 `n_jobs=28`（或更低），
不要用 `-1`。这条在 `cross_val_score`、`GridSearchCV`、`RandomForest` 上都适用。

---

## §10 选型速查

| 我要做的事 | 用这个 | 不要用 |
| :--- | :---: | :---: |
| 两组比较出 p 值 | `scipy.stats` / DESeq2 | sklearn（它不给 p 值） |
| 带协变量的回归 + 系数解释 | `statsmodels` / DESeq2 | sklearn |
| 用表达谱预测表型（样本少） | `LogisticRegression(penalty="l2")` + `GroupKFold` | 随机森林、深度网络 |
| 表格数据、样本较多（n>1000） | `HistGradientBoostingClassifier` | 先装 xgboost |
| 单细胞降维 | `sc.pp.pca`（就是 sklearn 的 PCA） | 自己实现 |
| 细胞类型分类器 | CellTypist / SingleR（见 `/scrna`） | 自己从零训 |
| 评估一个分类器 | `cross_val_score` + 正确的 splitter + MCC/PR-AUC | 单次 `train_test_split` + accuracy |
| 调参 | `GridSearchCV` 内嵌进 nested CV | 手工试几组挑最好的 |

---

## §11 本篇与其它文档的边界（避免同一件事写两遍）

| 想知道什么 | 去读 |
| :--- | :---: |
| numpy/scipy/pandas/statsmodels 谁管什么 | `20.Notes_by_ZG/Python_core_modules_for_bioinformatics.md` |
| **什么时候值得上神经网络、本机跑得动什么** | 本目录 [②](2_representation_learning_and_dl_frameworks.md) |
| **把 LLM 接进脚本的工程问题** | 本目录 [③](3_llm_engineering_layer.md) |
| **单细胞/空间里 AI 方法可不可信** | `/home/gao/Utilities/Bioinfo/single_cell_and_spatial/AI_in_singlecell_and_spatial_1_methods_20260910.md` |
| 单细胞分析本身的 SOP | `/scrna` skill |
| 差异表达为什么不能用 t 检验 | `20.Notes_by_ZG/Python_core_modules_for_bioinformatics.md` §4.2 |

---

## §12 本文的事实来源

| 类别 | 来源 |
| :--- | :---: |
| 版本号、装没装 | **2026-09-17 本机实测**，命令见 §9 |
| scanpy 用了 sklearn 哪些部分 | **实测**：`grep -rn "from sklearn" $SITE_PACKAGES/scanpy`（37 处） |
| 泄漏的五种形态、指标选型、p≫n | 通用统计学习知识 + 生信场景的对应，**属于我的判断与整理**，不是实测 |
| 28 核 / 56 线程上限 | 本机运维规则 |
