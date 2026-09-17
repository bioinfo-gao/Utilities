# 从 R 到 Python：统计函数与作图方法的逐条对照

> 建立日期：2026-09-17
> **写作视角：以 R 为母语。** 假设读者 R 熟练、Python 生疏，所以每一条都写成
> 「R 里你惯用的是 X → Python 里对应的是 Y → **哪里看着等价其实不等价**」。
> 关注点不是"两边都能做"，而是**默认值不同 / 语义不同导致的静默错误**——
> 因为 R 用得越熟，越会默认 Python 同名函数是同一件事。
> 姊妹篇：[Python_core_modules_for_bioinformatics.md](Python_core_modules_for_bioinformatics.md)（Python 侧的生态分层）
> 反方向：[Python_to_R_migration.md](Python_to_R_migration.md)（Python→R，**陷阱与本篇几乎不重叠**）· 中立选型：[R_vs_Python_neutral_comparison.md](R_vs_Python_neutral_comparison.md)
> 所有数值均为 **2026-09-17 双语实测**（同一组输入分别跑 R 与 Python），环境与脚本见 §6。

---

## §0 结论：只有一条真陷阱，其余大多能照搬

把 R 的统计函数搬到 Python，**实测下来绝大多数结果逐位一致**。
真正会出错的只有很少几处，但它们**不报错、数值只差百分之几**，正好落在"看不出来"的区间。

### 🔴 三条最危险的（全部实测确认）

| # | 陷阱 | R 的行为 | Python 的行为 | 后果 |
| :--- | :---: | :---: | :---: | :---: |
| **1** | **t 检验默认不同** | `t.test()` 默认 **Welch**（不等方差） | `ttest_ind()` 默认 **Student**（等方差） | 同一组数据 p = 0.0002187 vs 0.0002049，**差 6.7%**，卡在 0.05 边上时结论反转 |
| **2** | **缺失值处理三种行为** | `mean(x)` → **返回 NA**（吵闹） | `np.mean` → `nan`（吵闹）；**`pd.Series.mean()` → 静默丢弃 NA** | pandas 那条**不报错、不警告**，样本量悄悄变小 |
| **3** | **`std` 的自由度** | `sd()` = 样本（ddof=1） | `np.std()` = **总体（ddof=0）**；`pd.Series.std()` = 样本（ddof=1） | numpy 与 pandas **互相不一致**，n 小时差得多（n=6 时差 8.7%） |

**第 1 条是本文最重要的一条。** 它的特殊性在于：
你在 R 里写了十年 `t.test(x, y)`，肌肉记忆告诉你"这就是两样本 t 检验"——
但 R 选择了 Welch 做默认（更稳健），scipy 选择了 Student（教科书默认）。**两边都没错，只是选择不同。**

```python
st.ttest_ind(x, y, equal_var=False)   # ← 这才等于 R 的 t.test(x, y)
```

### ✅ 实测逐位一致、可以放心照搬的

| 项目 | R | Python | 实测 |
| :--- | :---: | :---: | :---: |
| Pearson / Spearman 相关 | `cor()` | `st.pearsonr` / `st.spearmanr` | 0.7747972 / 0.7714286 **完全一致** |
| 分位数 | `quantile()`（type 7） | `np.percentile`（`method='linear'`） | 5.2 / 5.65 / 5.95 **完全一致** |
| Mann–Whitney | `wilcox.test()` | `st.mannwhitneyu()` | 统计量 0，p=0.0021645 **完全一致** |
| Fisher 精确检验 | `fisher.test()` | `st.fisher_exact()` | p=0.03496503 **完全一致** |
| 卡方检验 | `chisq.test()`（`correct=TRUE`） | `st.chi2_contingency()`（`correction=True`） | p=0.05096194 **默认值也一致** |
| BH 多重检验校正 | `p.adjust(method="BH")` | `st.false_discovery_control()` | 10 个值**逐位一致** |
| 线性模型 | `lm(y ~ x + b)` | `smf.ols("y ~ x + b", data=d).fit()` | 系数与 p 值**逐位一致**，连公式写法都一样 |
| 因子水平默认顺序 | `factor()` → 字母序 | `pd.Categorical()` → 字母序 | 都是 Ctrl / KO / Treat |

**这份"一致清单"本身是有用的结论**：它说明迁移成本主要不在统计层，而在
**语言语义层**（§3：索引、矩阵填充顺序）和**作图层**（§4）。

---

## §1 根本差异：为什么 R 里一个函数，Python 里要先选一个包

| | R | Python |
| :--- | :---: | :---: |
| 定位 | **统计语言**——统计是语言本身的一部分 | **通用语言 + 科学库**——统计是外挂 |
| `data.frame` | **内置类型**，`base` 就有 | 要 `import pandas` |
| 公式 `y ~ x` | **一等公民**，是语言的语法对象（`class(y ~ x)` 是 `"formula"`） | 不存在；靠 `statsmodels` 用字符串模拟 |
| 向量化 | 语言默认，`x + 1` 天然按元素 | 要先有 `ndarray`；原生 `list` 的 `+` 是**拼接**不是加法 |
| 统计函数 | `t.test` `lm` `aov` 都在 `stats`（默认加载） | 分散在 `scipy.stats` / `statsmodels` / `sklearn`，**要先判断归谁管** |
| 缺失值 | `NA` 是**语言级**的，每个函数都要面对它（`na.rm=` 到处都是） | `np.nan` 是**浮点数的一个值**；整数数组根本放不下 NA |
| 面向对象 | S3 泛型：`summary()` 对什么都能用 | 方法挂在对象上：`fit.summary()` |

### §1.1 最需要重建的一个习惯

**R 里你先想"用哪个检验"，Python 里你要先想"这归哪个库管"。**

| 你想做 | R | Python 归谁管 |
| :--- | :---: | :---: |
| 两组比较 | `t.test` | `scipy.stats` |
| 线性模型 + 系数解释 | `lm` / `glm` | `statsmodels`（**不是** sklearn） |
| 预测 + 交叉验证 | `caret` / `tidymodels` | `scikit-learn`（**不给 p 值**） |
| 分布函数 `dnorm/pnorm/qnorm/rnorm` | `stats` | `scipy.stats.norm` 的 `.pdf/.cdf/.ppf/.rvs` |
| 描述统计 | `mean/sd/median` | `numpy` 或 `pandas`（**两者默认不同，见 §2.1**） |

### §1.2 分布函数的四字头对照

R 的 `d/p/q/r` 前缀体系在 Python 里变成**同一个分布对象上的四个方法**，映射很干净：

| R | Python | 含义 |
| :--- | :---: | :---: |
| `dnorm(x)` | `norm.pdf(x)` | 密度 |
| `pnorm(q)` | `norm.cdf(q)` | 累积概率 |
| `qnorm(p)` | `norm.ppf(p)` | 分位数（**注意是 `ppf` 不是 `quantile`**） |
| `rnorm(n)` | `norm.rvs(size=n)` | 随机抽样 |
| `dnbinom` 等 | `nbinom.pmf` 等 | 离散分布用 `pmf` 不是 `pdf` |

> **一个小坑**：R 的 `qnorm` 和 Python 的 `ppf` 是同一件事，
> 但 Python 里 `np.quantile` 是**从数据求经验分位数**，两者完全不同。R 的 `quantile()` 对应后者。

---

## §2 统计函数逐条对照（含实测数值）

本节所有数值来自同一组输入：

```
x <- c(5.1, 4.9, 6.2, 5.8, 6.0, 5.5)
y <- c(7.2, 6.8, 7.9, 7.1, 8.3, 7.0)
```

### §2.1 描述统计：numpy 与 pandas 自己就不一致

| 调用 | 结果 | 自由度 |
| :--- | :---: | :---: |
| R `sd(x)` | **0.5115336** | ddof=1（样本） |
| `pd.Series(x).std()` | **0.5115336** | ddof=1 ✅ 与 R 一致 |
| `np.std(x)` | **0.4669642** | **ddof=0（总体）** ❌ |
| `np.std(x, ddof=1)` | 0.5115336 | ✅ |

**同理 `var`**：R `var(x)` = 0.2616667，`np.var(x)` = 0.2180556。

> **为什么 numpy 选 ddof=0**：numpy 的立场是"我只是个数组库，`std` 就是那个数学定义"，
> 推断统计的约定不该由它来替用户假设。pandas 的立场是"我是做数据分析的"，所以跟统计学惯例走。
> **两个包的默认值不同，不是 bug，是定位不同。**
>
> **实务防法**：在 Python 里做描述统计，**统一走 pandas**，不要在 numpy 和 pandas 之间混用。

### §2.2 🔴 t 检验：默认值不同（本文头号陷阱）

| 调用 | t | df | p |
| :--- | :---: | :---: | :---: |
| R `t.test(x, y)`（默认） | -5.676354 | **9.827219** | **0.000218677** |
| R `t.test(x, y, var.equal=TRUE)` | -5.676354 | 10 | 0.000204867 |
| Python `st.ttest_ind(x, y)`（默认） | -5.676354 | **10.0** | **0.000204867** |
| Python `st.ttest_ind(x, y, equal_var=False)` | -5.676354 | 9.827219 | 0.000218677 |

**t 统计量完全相同，差别只在自由度**——Welch 用 Satterthwaite 近似把 df 调小（10 → 9.83），
所以 p 值更大（更保守）。

**这是最难发现的一类错误：**

- 不报错、不警告
- t 值一样，肉眼核对"统计量对得上"会误判为迁移成功
- p 值只差百分之几，只有卡在显著性边界上才暴露
- 而边界附近恰恰是最需要可靠的地方

| 要迁移的 R 代码 | 正确的 Python 写法 |
| :--- | :---: |
| `t.test(x, y)` | `st.ttest_ind(x, y, equal_var=False)` |
| `t.test(x, y, var.equal=TRUE)` | `st.ttest_ind(x, y)` |
| `t.test(x, y, paired=TRUE)` | `st.ttest_rel(x, y)` |
| `t.test(x, mu=0)` | `st.ttest_1samp(x, 0)` |

> **建议：不管哪种情况，都把 `equal_var=` 显式写出来。**
> 依赖默认值是这条陷阱能存在的唯一原因。

### §2.3 非参数检验：实测一致，但注意名字

| R | Python | 实测 |
| :--- | :---: | :---: |
| `wilcox.test(x, y)`（两样本 = Mann–Whitney U） | `st.mannwhitneyu(x, y)` | W=0 / U=0，p=0.0021645 **一致** |
| `wilcox.test(x, y, paired=TRUE)`（配对 = 符号秩） | `st.wilcoxon(x, y)` | — |
| `kruskal.test()` | `st.kruskal()` | — |
| `ks.test()` | `st.ks_2samp()` | — |
| `shapiro.test()` | `st.shapiro()` | — |

**命名陷阱**：R 用一个 `wilcox.test` 加 `paired=` 参数覆盖两种检验；
Python 分成了**两个不同名字的函数**（`mannwhitneyu` / `wilcoxon`）。
**`scipy.stats.wilcoxon` 是配对检验，不是 R 的 `wilcox.test` 默认行为。** 这个名字对应错了会算出完全不同的东西。

### §2.4 相关与分位数：完全一致，可以放心

| 项目 | R | Python | 值 |
| :--- | :---: | :---: | :---: |
| Pearson | `cor(x,y)` | `st.pearsonr(x,y).statistic` | 0.7747972 |
| Spearman | `cor(x,y,method='spearman')` | `st.spearmanr(x,y).statistic` | 0.7714286 |
| 分位数 | `quantile(x, c(.25,.5,.75))` | `np.percentile(x, [25,50,75])` | 5.2 / 5.65 / 5.95 |

**分位数一致是因为默认口径恰好对上**：R 默认 type 7，`np.percentile` 默认 `method='linear'`，两者定义相同。
但 R 有 9 种 type，如果协作方用了 type 6（SAS 口径），就对不上了——需要严格对齐时两边都显式写。

**相关的一个差别**：R 的 `cor()` 可以直接吃矩阵返回**相关矩阵**；
Python 里这个职责在 pandas：`df.corr()`，而 `st.pearsonr` 只吃两个向量。

### §2.5 列联表检验：默认值也一致（少见的好消息）

| 调用 | p |
| :--- | :---: |
| R `fisher.test(m)` | 0.03496503 |
| Python `st.fisher_exact(m).pvalue` | 0.03496503 ✅ |
| R `chisq.test(m)`（默认 `correct=TRUE`） | 0.05096194 |
| Python `st.chi2_contingency(m)`（默认 `correction=True`） | 0.05096194 ✅ |
| R `chisq.test(m, correct=FALSE)` | 0.01342542 |
| Python `st.chi2_contingency(m, correction=False)` | 0.01342542 ✅ |

**两边的 Yates 连续性校正默认值都是"开"**，这一处不用担心。
（顺带注意校正开关的影响有多大：0.051 vs 0.013，**跨越了 0.05**。这与语言无关，是统计选择。）

> ⚠️ **但构造矩阵的方式是陷阱**——见 §3.3，R 的 `matrix()` 按列填充，numpy 按行填充。
> 上面能对上，是因为我在两边**分别**构造了同一个矩阵，不是照抄了同一串数字。

### §2.6 多重检验校正：完全一致

输入 10 个 p 值，BH 校正结果**逐位一致**：

| 方法 | 结果 |
| :--- | :---: |
| R `p.adjust(p, "BH")` | 0.01, 0.04, 0.084, 0.084, 0.084, 0.1, 0.1057143, 0.216, 0.216, 0.216 |
| `st.false_discovery_control(p, method='bh')` | **同上** ✅ |
| `statsmodels.stats.multitest.multipletests(p, method='fdr_bh')[1]` | **同上** ✅ |

**名字对照表**（这是唯一要记的东西）：

| R `p.adjust(method=)` | scipy | statsmodels `multipletests(method=)` |
| :--- | :---: | :---: |
| `"BH"` | `false_discovery_control(method='bh')` | `'fdr_bh'` |
| `"BY"` | `false_discovery_control(method='by')` | `'fdr_by'` |
| `"bonferroni"` | ❌ 无 | `'bonferroni'` |
| `"holm"` | ❌ 无 | `'holm'` |

**scipy 只做 FDR 两种**（BH / BY）；要 Bonferroni 或 Holm 得上 statsmodels。
只做 BH 的话 scipy 就够，不必为此装 statsmodels（`regular_bioinfo` 里 statsmodels 未装）。

### §2.7 🔴 缺失值：三种不同行为，其中一种是静默的

输入 `z = c(1, 2, NA, 4)`：

| 调用 | 结果 | 行为 |
| :--- | :---: | :---: |
| R `mean(z)` | **NA** | **吵闹**：结果本身就是 NA，你必然发现 |
| R `mean(z, na.rm=TRUE)` | 2.333333 | 显式要求才丢弃 |
| `np.mean(z)` | **nan** | **吵闹**：同 R 的默认 |
| `np.nanmean(z)` | 2.3333333 | 显式要求才丢弃 |
| `pd.Series(z).mean()` | **2.3333333** | 🔴 **静默**：`skipna=True` 是默认值 |

**这是 R 用户最容易中招的一条**，因为它和你的直觉正好相反：

> 在 R 里，缺失值会**主动阻断**计算，逼你处理它——这是 R 的设计哲学。
> 在 pandas 里，缺失值被**默认忽略**，计算照常返回一个看起来正常的数。

后果是**样本量悄悄变小而没有任何提示**：
一列 20 个样本里有 3 个 NA，`df.groupby("group").mean()` 返回的是 17 个样本的均值，
报告里却写着 n=20。

**防法（三选一，建议都做）：**

```python
# 1. 算之前先数
assert df["expr"].notna().all(), f"有 {df['expr'].isna().sum()} 个缺失值"

# 2. 要 R 的行为就显式关掉
df["expr"].mean(skipna=False)      # 有 NA 就返回 nan

# 3. 聚合时把有效 n 一起算出来，写进报告
df.groupby("group")["expr"].agg(["mean", "std", "count"])   # count 不含 NA
```

> `count()` 不计 NA，`size()` 计——这一对也值得记住。

### §2.8 线性模型：公式语法几乎可以照抄

**好消息：`statsmodels` 的公式接口和 R 的写法一模一样。** 实测逐位一致：

| | R `lm(y ~ x + b, data=d)` | Python `smf.ols("y ~ x + b", data=d).fit()` |
| :--- | :---: | :---: |
| Intercept | 0.2933333 | 0.2933333 ✅ |
| x | 0.9775 | 0.9775 ✅ |
| b（第二水平） | 0.1375 | 0.1375 ✅ |
| p 值 | 0.4100 / 0.00169 / 0.6861 | **同上** ✅ |

Python 侧把因子水平写作 `b[T.b]`（T = treatment contrast），与 R 的 `bb` 是同一个东西，
默认对比编码（treatment contrast，以第一个水平为基线）**两边相同**。

| R | statsmodels | 备注 |
| :--- | :---: | :---: |
| `lm(y ~ x)` | `smf.ols("y ~ x", d).fit()` | |
| `glm(y ~ x, family=binomial)` | `smf.glm("y ~ x", d, family=sm.families.Binomial()).fit()` | |
| `y ~ x * b`（含交互） | `"y ~ x * b"` | **语法相同** |
| `y ~ x + (1\|subject)`（混合模型） | `smf.mixedlm("y ~ x", d, groups=d["subject"]).fit()` | **语法不同**，lme4 的 `(1\|g)` 写法不通用 |
| `summary(fit)` | `fit.summary()` | 输出排版不同，内容对应 |
| `coef(fit)` / `resid(fit)` | `fit.params` / `fit.resid` | 属性不是函数（无括号） |
| `anova(fit1, fit2)` | `sm.stats.anova_lm(fit1, fit2)` | |

**要注意的一点**：`statsmodels` 的公式引擎（formulaic / patsy）**不支持 R 的全部语法**，
比如 `poly()`、`I()` 的行为有出入，`offset()` 要用参数传。复杂公式迁移后建议**用同一份数据两边各跑一次对系数**。

### §2.9 汇总：能照搬 / 不能照搬

| 类别 | 判定 | 迁移动作 |
| :--- | :---: | :---: |
| 相关、分位数、Fisher、卡方、BH 校正、`lm`/`glm` 公式 | ✅ **可照搬** | 直接换函数名 |
| `wilcox.test` | ✅ 结果一致 | 但要分清 `mannwhitneyu`（非配对）/ `wilcoxon`（配对） |
| `t.test` | 🔴 **不可照搬** | 必须显式 `equal_var=False` |
| `sd` / `var` | 🔴 **不可照搬** | 用 pandas，或显式 `ddof=1` |
| `mean` 遇 NA | 🔴 **不可照搬** | pandas 会静默丢弃，要 assert |
| 混合模型 | ⚠️ 语法不同 | 公式要重写 |
| DESeq2 / edgeR / limma | ⚠️ **建议不迁** | 见 §5 |

---

## §3 语言层的五条语义陷阱

这些与统计无关，但**每一条都会让照抄过来的代码静默算错**。对 R 用户来说，
这一节比 §2 更需要刻意练习，因为它们违反的是十年的肌肉记忆。

### §3.1 索引：1-based 闭区间 vs 0-based 半开区间

| | R | Python |
| :--- | :---: | :---: |
| 第 2 个元素 | `v[2]` → 20 | `v[1]` → 20 |
| 第 2 到第 4 个 | `v[2:4]` → 20 30 40 | `v[1:4]` → 20 30 40 |

**巧合提醒**：`v[2:4]`（R）和 `v[1:4]`（Python）**结果碰巧相同**——
因为 R 是"从 2 到 4 闭区间"，Python 是"从 index 1 到 index 4 前"，两者都取 3 个元素。
**这种巧合很危险**：它让人误以为"只要减一就行"，但只对起点成立，终点不需要减。

> 记法：**Python 的切片写的是"边界"不是"位置"**，`v[1:4]` 读作"从边界 1 切到边界 4"。

### §3.2 🔴 负号索引：意思完全相反

| | R | Python |
| :--- | :---: | :---: |
| `v[-1]` | **20 30 40 50** —— 删掉第 1 个 | **50** —— 倒数第 1 个 |

**这是最危险的一条**，因为两边都合法、都不报错，而且**返回的类型都对**：
R 返回长度 n-1 的向量，Python 返回一个标量。如果下游代码对长度不敏感，错误会一直传下去。

| 意图 | R | Python |
| :--- | :---: | :---: |
| 删掉第 1 个 | `v[-1]` | `v[1:]` 或 `np.delete(v, 0)` |
| 取最后一个 | `v[length(v)]` 或 `tail(v,1)` | `v[-1]` |

### §3.3 🔴 矩阵填充顺序：R 按列，numpy 按行

```r
# R
matrix(1:6, nrow=2)        →   1 3 5
                               2 4 6      （column-major，按列填）
```
```python
# Python
np.arange(1,7).reshape(2,3)  →  1 2 3
                                4 5 6     （row-major / C order，按行填）

np.arange(1,7).reshape(2,3, order='F')  →  1 3 5
                                           2 4 6    ← 这才等于 R
```

**把 R 的 `matrix(c(...), nrow=2)` 直接抄成 `np.array([...]).reshape(2,-1)` 会得到转置错乱的矩阵**，
而且**元素个数对、维度对、不报错**。列联表、距离矩阵、表达量矩阵都会中招。

**防法**：不要抄"一串数 + reshape"，直接**写成嵌套 list**（行优先，所见即所得）：

```python
m = np.array([[8, 1],
              [2, 5]])      # ✅ 一眼看出行列，不依赖填充顺序约定
```

### §3.4 `apply(MARGIN=)` vs `axis=`：两套相反的心智模型

**R 的 `MARGIN` 是"保留哪个维度"，numpy 的 `axis` 是"压掉哪个维度"。**

| 意图 | R | numpy | 结果长度 |
| :--- | :---: | :---: | :---: |
| 每一**行**求和 | `apply(m, 1, sum)` | `m.sum(axis=1)` | nrow |
| 每一**列**求和 | `apply(m, 2, sum)` | `m.sum(axis=0)` | ncol |

注意映射**不是"减一"**：`MARGIN=1 ↔ axis=1`，但 `MARGIN=2 ↔ axis=0`。
看起来矛盾，其实是两个定义的必然结果——二维下"保留行" ⟺ "压掉列"。

> **记法**：numpy 里 `axis=` 指的是**会消失的那个维度**。
> `m.sum(axis=0)` 结果形状是 `(ncol,)`，第 0 维没了。盯住输出形状就不会错。
>
> pandas 更混乱一些：`df.mean(axis=0)` 是"每列的均值"（沿行方向），
> 而 `df.drop(..., axis=0)` 是"删行"。**同一个 `axis=0` 在聚合和删除里读法不同**，
> pandas 为此提供了别名 `axis="index"` / `axis="columns"`，**建议一律用别名**。

### §3.5 取一列会不会降维

| | R | Python |
| :--- | :---: | :---: |
| 取一列（降维） | `d[, 1]` → `integer` 向量 | `d.iloc[:, 0]` → `Series` |
| 保持二维 | `d[, 1, drop=FALSE]` → `data.frame` | `d.iloc[:, [0]]` → `DataFrame` |

行为**一致**（都默认降维），只是"保持二维"的写法不同：
R 用 `drop=FALSE` 参数，Python 用**把索引包成 list**。

---

## §4 作图：从 ggplot2 出发的三条路

对一个 ggplot2 熟练的人，Python 绘图最大的心理落差是：
**matplotlib 没有图形语法（grammar of graphics）**，它是"命令式画图"——
你不是声明"把 x 映射到横轴、按 group 上色"，而是逐条下达绘制指令。

好消息是：**有三条路，其中一条几乎不需要重新学。**

### §4.1 三条路对比

| 路线 | 是什么 | 学习成本 | 本机状态 | 什么时候选 |
| :--- | :---: | :---: | :---: | :---: |
| **plotnine** | **ggplot2 的 Python 移植**，API 几乎逐字对应 | **最低** | `sc_tut_main` **0.15.8 已装**（`regular_bioinfo` 未装） | 想最快出图；脑子里已经是 ggplot2 语法 |
| **seaborn** | 统计图封装，**吃 tidy long-format 数据**这点像 ggplot2 | 中 | 两个环境都有 0.13.2 | 融入 Python 生态（Scanpy 等都返回 matplotlib 对象） |
| **matplotlib** | 底层引擎，命令式 | 高 | 两个环境都有 | 出版级精细排版；前两者最终也要落到它 |

**关键事实（实测）**：`plotnine` 的 `p.draw()` 返回的是 **`matplotlib.figure.Figure`**。
所以**三条路不是三选一**——可以用 plotnine 快速搭骨架，再用 matplotlib 做最后的精修。

### §4.2 plotnine：最短迁移路径（已实测可用）

**实测**：在 `sc_tut_main` 里画了一张带 `facet_wrap` 的箱线图 + 抖动点，
正常渲染并存成 PDF（12,619 字节）。语法与 ggplot2 的差别只有三处：

```python
from plotnine import ggplot, aes, geom_boxplot, geom_jitter, facet_wrap, labs, theme_bw

p = (ggplot(d, aes("g", "v", fill="g"))       # ① aes 里的变量名要加引号
     + geom_boxplot()
     + geom_jitter()
     + facet_wrap("~b")                        # ② facet 公式也是字符串
     + labs(x="Group", y="Expression")
     + theme_bw())
p.save("fig.pdf", width=5, height=3)           # ③ ggsave → p.save
```

| ggplot2 | plotnine | 差别 |
| :--- | :---: | :---: |
| `aes(x = g, y = v)` | `aes("g", "v")` | **变量名要加引号**（Python 没有 R 的非标准求值 NSE） |
| `facet_wrap(~ b)` | `facet_wrap("~b")` | 公式写成字符串 |
| `ggsave("f.pdf", p, width=5)` | `p.save("f.pdf", width=5)` | 方法调用；**`units="in"` 默认与 ggsave 相同** |
| `%+%` / `%>%` | `+` | 加号相同 |
| 其余 geom / scale / theme / coord | **同名同参** | 基本可以逐字抄 |

> **我的判断（非实测）**：plotnine 跟进 ggplot2 新特性有滞后，
> 且社区规模远小于 ggplot2，遇到冷门 `geom` 或 `scale` 可能没有。
> **但对 90% 的日常图（箱线、散点、火山、热图、分面）足够。**
>
> 对你的情况，**plotnine 是我建议的起点**：它把"学新的绘图范式"这件事推迟了，
> 让你可以先把精力放在数据处理的差异上（§3 那五条才是真会算错的地方）。

### §4.3 seaborn：像 ggplot2 的地方与不像的地方

**像的地方——数据组织方式相同。** seaborn 和 ggplot2 一样吃 **tidy long-format**：

```r
# R
ggplot(df, aes(x = group, y = expr, fill = batch)) + geom_boxplot()
```
```python
# Python
sns.boxplot(data=df, x="group", y="expr", hue="batch")
```

`aes(fill=)` ↔ `hue=` 是最直接的对应。**长格式的数据准备习惯可以直接沿用**，
这是 seaborn 相对 matplotlib 的最大优势。

**不像的地方——没有图层叠加，且分成两套 API。**

| ggplot2 概念 | seaborn 对应 | 落差 |
| :--- | :---: | :---: |
| `+ geom_*()` 图层叠加 | 调用多个函数画到同一个 `ax` | 不是声明式叠加，是"往同一个画布上再画一次" |
| `facet_wrap()` | **figure-level** 函数的 `col=` / `row=` | 见下方陷阱 |
| `scale_fill_manual(values=)` | `palette={...}` | 对应良好 |
| `theme_bw()` | `sns.set_theme(style="whitegrid")` | 全局设置，不是图层 |
| `coord_flip()` | 交换 `x=` / `y=` | 无直接对应 |
| `labs()` | `ax.set(xlabel=, ylabel=, title=)` | 回到 matplotlib |

**🔴 seaborn 的两套 API（这是 R 用户最容易踩的坑）：**

| 类型 | 函数 | 相当于 ggplot2 的 | 能否传 `ax=` |
| :--- | :---: | :---: | :---: |
| **figure-level** | `relplot` `catplot` `displot` `lmplot` `pairplot` `clustermap` | 一整张带 facet 的图 | **❌ 不能** |
| **axes-level** | `scatterplot` `lineplot` `boxplot` `violinplot` `heatmap` `histplot` `barplot` | 单个 panel | **✅ 能** |

在 ggplot2 里，`facet_wrap` 只是加一个图层，**分面和拼图是同一套机制**。
在 seaborn 里它们是**互斥的两套**：

```python
fig, axes = plt.subplots(1, 2)
sns.boxplot(data=df, x="g", y="v", ax=axes[0])    # ✅
sns.catplot(data=df, x="g", y="v", ax=axes[1])    # ❌ figure-level，不吃 ax
```

**规则：想自己控制 panel 布局，只用 axes-level 函数。**

### §4.4 seaborn.objects：最接近 ggplot2 的新接口

seaborn 0.12 起提供了 `seaborn.objects`，是真正的图形语法接口（**实测 0.13.2 可导入**）：

```python
import seaborn.objects as so
(so.Plot(df, x="group", y="expr", color="batch")
   .add(so.Dot(), so.Jitter())
   .add(so.Range(), so.Est(errorbar="se"))
   .facet("batch"))
```

`.add()` ≈ `+ geom_*()`，`.facet()` ≈ `facet_wrap()`。

> **我的判断（非实测）**：接口仍在演进，文档与社区示例远少于经典 API，
> **做交付图建议先不用**。想要 ggplot2 手感，**plotnine 目前更成熟**。

### §4.5 matplotlib：设备模型 vs 对象模型

R 的 base graphics 是**设备模型**：`pdf()` 打开设备 → 画 → `dev.off()` 关闭。
matplotlib 是**对象模型**：创建 `Figure` → 在 `Axes` 上画 → `savefig`。

| R base graphics | matplotlib | 备注 |
| :--- | :---: | :---: |
| `pdf("f.pdf"); plot(...); dev.off()` | `fig, ax = plt.subplots(); ax.plot(...); fig.savefig("f.pdf")` | 不需要"关闭设备" |
| `par(mfrow=c(2,2))` | `fig, axes = plt.subplots(2, 2)` | matplotlib 返回**对象数组**，可以直接索引 |
| `plot()` / `points()` / `lines()` | `ax.plot()` / `ax.scatter()` | 都是往同一个 `ax` 上加 |
| `legend()` | `ax.legend()` | |
| `par(mar=)` | `fig.tight_layout()` / `constrained_layout=True` | matplotlib 更自动 |
| 无对应 | **`plt.close(fig)`** | 🔴 **循环出图必须调用**，否则内存持续增长直到 OOM |

**强烈建议只用面向对象接口**（`fig, ax = plt.subplots()`），
不要用 `plt.plot()` 这种状态机接口——后者是模仿 MATLAB 的历史包袱，
在脚本里会产生"画到哪张图上了"的歧义，而 R 用户对这种隐式当前设备的概念反而熟悉，容易掉进去。

### §4.6 保存图片：默认 dpi 差 3 倍

| | 默认值 | 实测 |
| :--- | :---: | :---: |
| R `ggsave()` | **dpi = 300**，`units="in"` | ✅ |
| plotnine `p.save()` | `units="in"`，dpi 跟随 rcParams | ✅ |
| matplotlib `savefig()` | `savefig.dpi = "figure"` → **实际 100** | ✅ |
| matplotlib 默认图幅 | `figure.figsize = [6.4, 4.8]` 英寸 | ✅ |
| matplotlib `savefig.bbox` | **`None`**（不是 `tight`） | ✅ |

**两条实务结论：**

1. **出 PNG 时 matplotlib 默认 100 dpi，只有 ggsave 的三分之一**，看起来会明显糊。
   要么显式 `dpi=300`，要么——更好——**交付一律出 PDF 矢量图，dpi 就无关了**。
2. **`bbox_inches="tight"` 默认是关的**。ggplot2 会自动给标签留白，matplotlib 不会：
   旋转过的轴标签会被**真的裁掉**（PDF 里那部分数据不存在，不是显示问题）。

```python
fig.savefig("fig3.pdf", bbox_inches="tight")    # ← 基本上每次都要加
```

### §4.7 默认配色不同

| | 默认离散配色 |
| :--- | :---: |
| ggplot2 | `hue_pal()`——在 HCL 色环上等间距取色，亮度饱和度恒定 |
| matplotlib / seaborn | `tab10`——十个手工挑选的颜色 |

**所以同一份数据在 R 和 Python 画出来颜色完全不同**，这本身不是问题，
但**同一个项目里两边混着出图，读者会以为颜色有含义**。

**🔴 更要紧的一条（与语言无关，但 matplotlib 特有）**：
matplotlib 的默认色环**每个 `Axes` 独立从头分配**。
ggplot2 因为是"一个 plot 对象统一 scale"，不存在这个问题；
matplotlib 里 panel A 的第一个类别和 panel B 的第一个类别会拿到同一个颜色。

```python
PALETTE = {"Ctrl": "#4C72B0", "Treat": "#DD8452", "KO": "#55A868"}
sns.boxplot(data=df, x="g", y="v", hue="g", palette=PALETTE, ax=ax)   # 每个 panel 同一份映射
```

这相当于 ggplot2 的 `scale_fill_manual(values = c(...))`——
**在 R 里是可选的，在 matplotlib 里近乎必需。**

---

## §5 实务建议：哪些留在 R，哪些换 Python

以你的背景（R 十年、Python 近三年恢复）和当前项目类型，我的建议是**按领域切，不按语言切**：

| 任务 | 建议 | 理由 |
| :--- | :---: | :---: |
| bulk RNAseq 差异表达 | **留在 R**（DESeq2 / edgeR / limma） | 金标准，审稿人认；`pydeseq2` 是重实现，没有必要承担差异风险 |
| 富集分析 | **留在 R**（clusterProfiler） | Python 侧生态零散 |
| 出版级统计图 | **R (ggplot2) 或 plotnine** | 你最快；plotnine 让你不用换脑子 |
| 单细胞 | **换 Python**（Scanpy 生态） | 大数据量下性能与内存优势明显；`AnnData` 是事实标准 |
| 空间转录组 | **按平台分流** | 见 `spatial` skill |
| 序列 / BAM / VCF 处理 | **Python**（`pysam` / `Biopython`） | R 侧对应能力弱 |
| 管线编排、批量文件处理 | **Python** | `pathlib` + `argparse` 比 R 顺手得多 |
| 探索性数据处理 | 都行 | `dplyr` 与 `pandas` 各有胜负；`polars` 的语法其实更像 `dplyr` |

> **一条通用建议**：跨语言搬一段已经跑通的 R 分析时，**不要只对最终结论，要对中间量**。
> §2 的陷阱之所以危险，正是因为终点看起来永远是合理的。
> 实务做法是两边各跑一次，对**系数、自由度、n、p 值**四项——
> 其中 **n** 最容易被 pandas 静默改小（§2.7）。

### §5.1 🔴 单细胞跨语言的头号陷阱

| 生态 | 维度约定 |
| :--- | :---: |
| AnnData / Scanpy（Python） | **细胞 × 基因** |
| Seurat / SingleCellExperiment（R） | **基因 × 细胞** |

**两边是转置关系。** 转置后代码照跑、图照出、所有生物学结论都是错的；
细胞数恰好等于基因数时连报错都没有。跨语言搬数据必须显式转置并 assert 维度。

---

## §6 实测环境与复现

| 侧 | 环境 | 版本 |
| :--- | :---: | :---: |
| R | `/Work_bio/gao/configs/.conda/envs/DE_R45` | R 4.5.2 (2025-10-31)，ggplot2 4.0.2 |
| Python | `/mnt/ex_8T_SSD/conda_envs/sc_tut_main` | Python 3.11.16，numpy 2.4.6，scipy 1.17.1，pandas 2.3.3，statsmodels 0.14.6，matplotlib 3.11.1，seaborn 0.13.2，plotnine 0.15.8 |

### §6.1 ⚠️ 探测时必须用绝对解释器路径

本机 `conda run -n <env>` 存在被 `PATH` 注入绕过的情况（`-n` 与 `-p` 都失效且不报错），
详见姊妹篇 [Python_core_modules_for_bioinformatics.md](Python_core_modules_for_bioinformatics.md) §8.1。
**本文所有 Python 结果均用绝对路径 `/mnt/ex_8T_SSD/conda_envs/sc_tut_main/bin/python` 取得。**

### §6.2 复现

两份对照脚本（同一组输入，分别跑 R 与 Python）内容已完整嵌在 §2 各表中。
最小复现：

```bash
# R 侧
/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript -e '
x <- c(5.1,4.9,6.2,5.8,6.0,5.5); y <- c(7.2,6.8,7.9,7.1,8.3,7.0)
cat("sd =", sd(x), "\n"); print(t.test(x,y))'

# Python 侧（注意绝对路径）
/mnt/ex_8T_SSD/conda_envs/sc_tut_main/bin/python -c "
import numpy as np, scipy.stats as st
x=np.array([5.1,4.9,6.2,5.8,6.0,5.5]); y=np.array([7.2,6.8,7.9,7.1,8.3,7.0])
print('np.std =', np.std(x))
print('default:', st.ttest_ind(x,y))
print('Welch  :', st.ttest_ind(x,y,equal_var=False))"
```

---

## §7 本文的事实来源

| 内容 | 来源 |
| :--- | :---: |
| §2 全部数值（sd/var、t 检验、Wilcoxon、相关、分位数、Fisher、卡方、BH、NA、lm） | **2026-09-17 双语实测**，同一组输入两边各跑一次 |
| §3 全部语义行为（索引、负号、矩阵填充、MARGIN/axis、drop） | **2026-09-17 双语实测** |
| §4.2 plotnine 可渲染带 facet 的 PDF、`p.draw()` 返回 matplotlib Figure | **2026-09-17 实测** |
| §4.6 ggsave / plotnine / matplotlib 的 dpi、units、bbox 默认值 | **2026-09-17 实测**（读 `formals()` 与 `rcParams`） |
| §4.7 ggplot2 用 `hue_pal`、matplotlib 用 `tab10` | 上游文档，**非实测** |
| plotnine 跟进 ggplot2 的滞后程度、`seaborn.objects` 是否适合交付 | **我的判断**，依据是文档与社区示例数量，未做系统比对 |
| §5 的语言选型建议 | **我的判断**，依据是各生态的成熟度与你的项目类型 |
