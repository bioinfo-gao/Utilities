# 从 Python 到 R：迁移指南与反向陷阱

> 建立日期：2026-09-17
> **写作视角：以 Python 为母语。** 假设读者当前 Python 顺手、R 生疏或久未使用，
> 所以每条都写成「Python 里你惯用的 X → R 里对应的 Y → **R 会在哪里静默地不按你的预期走**」。
>
> ⚠️ **这不是** [R_to_Python_stats_and_plotting.md](R_to_Python_stats_and_plotting.md) 的镜像。
> 两个方向的陷阱**几乎没有重叠**：R→Python 的坑集中在"默认参数不同"，
> Python→R 的坑集中在**"Python 替你做的安全检查，R 不做"**。
>
> 姊妹篇：[R_vs_Python_neutral_comparison.md](R_vs_Python_neutral_comparison.md)（中立选型）
> 所有行为均为 **2026-09-17 双语实测**，环境见 §9。

---

## §0 结论：R 的危险不在语法，在于它不替你检查

从 Python 转 R，语法差异（`<-`、1-based、`library()`）一天就能适应，**这些都不是问题**——
因为写错了会立刻报错。

真正的问题是：**Python 在很多地方会主动报错阻止你，R 在同样的地方会静默地给出一个"合法"的结果。**

### 🔴 三条最危险的（全部实测确认）

| # | 陷阱 | Python 的行为 | R 的行为 | 为什么最危险 |
| :--- | :---: | :---: | :---: | :---: |
| **1** | **向量长度不匹配** | `np.array([1,2,3,4]) + np.array([10,20])` → **`ValueError` 直接报错** | `c(1,2,3,4) + c(10,20)` → **静默返回 `11 22 13 24`**（短的循环补齐） | 你在 Python 里**依赖形状检查当断言**用了很多年；R 里这层保护不存在 |
| **2** | **因子转数值** | 无对应概念 | `as.numeric(factor(c(10,20,30)))` → **`1 2 3`**（level 编码，不是值） | 返回的是合法数值、不报错、不警告；用它算均值会得到一个看起来正常的错数 |
| **3** | **`1:n` 当 n=0** | `range(0)` → 空，循环不执行 | `1:0` → **`c(1, 0)`，长度 2**，循环**反向跑两次** | 空输入是边界情况，测试时最容易漏；一旦触发，循环体在无效索引上执行 |

**第 1 条是本文最重要的一条。** 它不是"R 多了一个特性"，而是
**你在 Python 里习以为常的一道安全网被拆掉了**：

```r
# 整除时完全静默
c(1,2,3,4) + c(10,20)     # → 11 22 13 24   无任何提示
# 不整除时才警告（仅警告，不是错误，结果照样返回）
c(1,2,3)   + c(10,20)     # → Warning: longer object length is not a multiple...
```

**长度是短的整数倍时连警告都没有**——而这恰恰是最容易发生的情况
（比如把 n=6 的样本向量和 n=3 的分组向量相加）。

### ✅ 好消息：这些比 Python 更安全

| 项目 | Python | R |
| :--- | :---: | :---: |
| 赋值语义 | `b = a; b[0] = 99` → **`a` 也被改了** | `b <- a; b[1] <- 99` → **`a` 不变**（copy-on-modify） |
| 函数内修改参数 | `f(z)` 内改 `z[0]` → **调用方也变** | 函数内改参数 → **调用方不变** |
| 缺失值 | `pd.Series.mean()` **静默丢弃 NA** | `mean(x)` **返回 NA**，逼你显式 `na.rm=TRUE` |

**R 的值语义（copy-on-modify）会消掉 Python 里一整类"意外改到原对象"的 bug。**
唯一的例外是 `data.table` 的 `:=`，见 §2.6。

---

## §1 心智模型：需要重建的五处

### §1.1 一切都是向量，没有标量

```r
length(5)      # 1     ——  5 本身就是长度为 1 的向量
is.vector(5)   # TRUE
```

**推论**：R 里不存在 Python 那种"标量 vs 数组"的区分，
所以也不存在 `np.isscalar()` 这类检查。所有运算天然按元素走，
**而这正是 §0 陷阱 1 的根源**——既然一切都是向量，长度不同就得有个规则，R 选了循环补齐。

### §1.2 泛型函数，不是对象方法

| Python | R |
| :--- | :---: |
| `fit.summary()` | `summary(fit)` |
| `df.head()` | `head(df)` |
| `arr.sum()` | `sum(arr)` |
| `obj.method()`——方法挂在对象上 | `generic(obj)`——**函数根据对象类型分派**（S3） |

**实务影响**：在 Python 里你靠 `obj.<Tab>` 发现能做什么；
R 里要反过来问"哪些泛型函数支持这个类"，用 `methods(class = "lm")`。
**这是探索式学习路径的根本差别**，刚上手时最不适应。

### §1.3 1-based 闭区间

| 意图 | Python | R |
| :--- | :---: | :---: |
| 第 1 个元素 | `v[0]` | `v[1]` |
| 前 3 个 | `v[:3]` | `v[1:3]` |
| 最后一个 | `v[-1]` | `v[length(v)]` 或 `tail(v, 1)` |
| 去掉第 1 个 | `v[1:]` | **`v[-1]`** |

🔴 **`v[-1]` 在两边意思完全相反**：Python 是"倒数第一个"，R 是"删掉第一个"。
两边都合法、都不报错，只是返回长度不同（R 返回 n-1 个，Python 返回 1 个）。

> **R 里没有负数索引"从末尾数"这个概念**，负号一律表示"排除"。
> 想取末尾用 `tail()`，想排除多个用 `v[-c(1,2)]`。

### §1.4 值语义（copy-on-modify）

```r
a <- c(1,2,3)
b <- a
b[1] <- 99
a              # 1 2 3   —— 没被改
```

对应的 Python 行为（**实测**）：

```python
a = [1,2,3]; b = a; b[0] = 99; a        # [99, 2, 3]  ← 被改了
x = np.array([1,2,3]); y = x; y[0] = 99; x   # [99 2 3]  ← 被改了
d = pd.DataFrame({'a':[1,2,3]}); e = d; e.loc[0,'a'] = 99   # d 也变了
```

**所以从 Python 转 R 时，你会发现 `.copy()` 不再需要。**
但反过来要注意：**R 里"在函数内修改传入的对象"是无效的**，
想改必须 `return` 出来再赋值回去。Python 里常用的"传进去就地修改"模式在 R 里不成立。

### §1.5 非标准求值（NSE）：裸变量名

这是 Python 里完全没有的东西。R 的函数可以拿到**参数的表达式本身**而不只是值：

```r
subset(df, expr > 5)                      # expr 是列名，不是变量
df %>% filter(expr > 5) %>% select(gene)  # 同样，裸列名
ggplot(df, aes(x = group, y = expr))      # aes 里也是裸列名
```

Python 里必须写成字符串（`df.query("expr > 5")`）或 lambda。

**代价**：NSE 让交互式分析非常顺手，但**写函数时会反咬你**——
把列名当参数传进函数需要 `{{ }}`（tidyeval）或 `.data[[...]]`：

```r
my_summary <- function(d, col) {
  d %>% group_by({{ col }}) %>% summarise(n = n())   # {{ }} 是必需的
}
```

> **实务建议**：交互和脚本里放心用 NSE；**一旦要封装成函数就切到 `data.table` 或 base R**，
> 它们的语义更可预测。tidyeval 是 R 里学习曲线最陡的一块，且只为解决 NSE 自己造成的问题。

---

## §2 语义对照与静默陷阱

### §2.1 🔴 向量循环补齐（recycling）

**实测**：

| 表达式 | R 的结果 | Python 对应 |
| :--- | :---: | :---: |
| `c(1,2,3,4) + c(10,20)` | **`11 22 13 24`**（静默） | `ValueError: operands could not be broadcast` |
| `c(1,2,3) + c(10,20)` | `11 22 13`（**仅警告**） | 同样 `ValueError` |

**numpy 的广播规则只在某一维为 1 时生效**，其余一律报错；
**R 的循环补齐对任意长度都生效**，整除时静默。

**防法：把长度断言写出来。** 这是 Python 免费给你的，R 里要手动买：

```r
stopifnot(length(x) == length(y))      # 每次做向量运算前
stopifnot(nrow(d) == n_expected)       # 每次 merge/filter 后
```

### §2.2 🔴 `as.numeric(factor)` 返回编码不是值

**实测**：

```r
f <- factor(c(10, 20, 30, 20))
as.numeric(f)                     # 1 2 3 2      ← level 编码
as.numeric(as.character(f))       # 10 20 30 20  ← 正确的值
```

**为什么危险**：结果是合法数值、长度对、不报错。
如果原值恰好是 1..k 的小整数，**甚至可能碰巧相等**，测试通过而生产数据出错。

**什么时候会中招**：从 CSV 读入的数值列被当成因子（R 4.0 之前 `stringsAsFactors=TRUE` 是默认），
或者手工 `factor()` 之后忘了。

> **本机实测**：R 4.5.2 里 `data.frame(x=c("a","b"))$x` 的类是 **`character`**，
> 不再自动转 factor（R 4.0 起改的）。**这个历史大坑已经消失**，
> 但 `read.csv` 之外的旧代码、旧包仍可能显式设 `stringsAsFactors=TRUE`。

**记忆法：`as.numeric(as.character(f))`——中间那步永远不能省。**

### §2.3 🔴 `1:n` 当 n=0

**实测**：

```r
n <- 0
1:n             # 1 0    ← 长度 2，降序！
seq_len(n)      # integer(0)  ← 长度 0，正确
for (i in 1:n) { ... }       # 循环体执行 2 次，i = 1 和 i = 0
```

Python 的 `range(0)` 是空的，**所以你从来不需要想这件事**。

**规则：写循环一律用 `seq_len(n)` 或 `seq_along(x)`，永远不用 `1:n`。**

### §2.4 🔴 `sapply` 的返回类型不确定

**实测**：

| 输入 | `sapply` 返回类型 |
| :--- | :---: |
| 每次返回等长向量 | **matrix** |
| 每次返回不等长 | **list** |
| 空输入 | **list** |

```r
sapply(1:3, function(i) 1:2)     # matrix (2×3)
sapply(1:3, function(i) 1:i)     # list
sapply(integer(0), function(i) i) # list
```

**下游代码按 matrix 写的，遇到空输入或不等长就静默拿到 list**，
然后在几行之后以一个无关的错误崩掉（或者更糟，不崩）。

**防法：用 `vapply`，它强制你声明返回类型和长度：**

```r
vapply(1:3, function(i) sum(1:i), numeric(1))    # 类型不符直接报错
```

`vapply` 相当于给 `sapply` 加了类型注解——**这是 R 里最接近 Python 类型提示的东西**，
而且它是运行时强制的，比类型提示更强。

### §2.5 🔴 `$` 的部分匹配

**实测**：

```r
L <- list(value = 42)
L$val            # 42   ← 只写前缀也能取到，静默
d <- data.frame(value = 42)
d$val            # 42   ← data.frame 同样部分匹配
```

Python 的 `d["val"]` 会直接 `KeyError`。

**后果**：你以为在取一个不存在的列（期望拿到 `NULL` 然后走 else 分支），
实际拿到了另一列的值。**重构改列名时尤其危险**。

**防法：用 `[[ ]]` 并显式关掉部分匹配：**

```r
L[["val"]]                      # NULL   ← [[ ]] 默认精确匹配
d[["value", exact = TRUE]]
options(warnPartialMatchDollar = TRUE)   # 脚本开头打开警告
```

### §2.6 `data.table` 的 `:=` 是 R 里的引用语义例外

**实测**：

```r
g <- function(d) { d[, newcol := 999]; invisible(NULL) }
dt <- data.table(a = 1:3); g(dt)
names(dt)      # "a" "newcol"   ← 调用方被改了!

h <- function(d) { d$newcol <- 999; invisible(NULL) }
df <- data.frame(a = 1:3); h(df)
names(df)      # "a"            ← 没被改
```

**`data.table` 的 `:=` 是按引用修改**，行为和 Python 的可变对象一样。
这是 R 里唯一大规模使用引用语义的地方，也是它性能好的原因之一。

> **对 Python 用户来说这反而是熟悉的**，但要注意**它和 R 的其余部分不一致**：
> 同一份代码里 `data.frame` 是值语义、`data.table` 的 `:=` 是引用语义。
> 想要副本用 `copy(dt)`，**`dt2 <- dt` 不是副本**。

### §2.7 单列会降维

| 意图 | Python | R |
| :--- | :---: | :---: |
| 取一列（降维） | `d.iloc[:, 0]` → Series | `d[, 1]` → 向量 |
| 保持二维 | `d.iloc[:, [0]]` → DataFrame | `d[, 1, drop = FALSE]` → data.frame |
| 取一列（保持二维，简写） | — | **`d[1]`** → data.frame |

**R 的 `d[1]` 和 `d[, 1]` 是两个不同的东西**（单括号一个参数 = 选列，保持 data.frame）。
这个区分 Python 里没有对应物，容易混。

> `tibble` 和 `data.table` **默认不降维**，是 `data.frame` 的历史行为。
> 又一个"三套数据框方言不一致"的例子。

### §2.8 `apply()` 会把 data.frame 转成 matrix

**实测**：

```r
d <- data.frame(num = c(1,2,3), chr = c("a","b","c"))
apply(d, 1, function(row) class(row[["num"]]))
# "character" "character" "character"   ← 数值列变成字符串了!
class(d$num)   # "numeric"              ← 原本是数值
```

**因为 matrix 只能有一个类型**，混合类型的 data.frame 被统一成 `character`。
Python 里 `df.apply(..., axis=1)` 也有类似问题（行变成 object Series），
但 pandas 至少保留了原始 dtype 信息。

**防法：不要对 data.frame 用 `apply`。** 按列处理用 `lapply`/`sapply`/`purrr::map`，
按行处理改成向量化操作或 `data.table` 的 `by = seq_len(.N)`。

### §2.9 `T` / `F` 可以被重新赋值

**实测**：

```r
T <- FALSE
T              # FALSE
```

`TRUE` / `FALSE` 是保留字，**但 `T` / `F` 只是普通变量**（默认值分别是 TRUE / FALSE）。
Python 的 `True` / `False` 是关键字，无法赋值。

**规则：永远写全 `TRUE` / `FALSE`。**（`F` 尤其危险——它常被当成"Fold change"之类的变量名。）

### §2.10 陷阱速查

| # | 陷阱 | Python 会 | R 会 | 防法 |
| :--- | :---: | :---: | :---: | :---: |
| 1 | 向量长度不匹配 | **报错** | **静默补齐** | `stopifnot(length(x)==length(y))` |
| 2 | `as.numeric(factor)` | — | **返回编码** | `as.numeric(as.character(f))` |
| 3 | `1:0` | `range(0)` 为空 | **`c(1,0)`** | `seq_len(n)` / `seq_along(x)` |
| 4 | `sapply` 返回类型 | — | **不确定** | `vapply(..., numeric(1))` |
| 5 | `$` 部分匹配 | `KeyError` | **静默命中** | `[[ ]]` + `warnPartialMatchDollar` |
| 6 | `data.table` `:=` | 引用（同 Python） | **R 里的例外** | 要副本用 `copy(dt)` |
| 7 | `d[, 1]` 降维 | 同样降维 | 降维 | `drop = FALSE` |
| 8 | `apply` 转 matrix | 部分保留 dtype | **统一成 character** | 别对 data.frame 用 `apply` |
| 9 | `T` / `F` 可重赋值 | 关键字，不可 | **可以** | 永远写 `TRUE`/`FALSE` |

---

## §3 数据处理：pandas → dplyr / data.table

R 有**三套互不兼容的数据框方言**，这是 Python 用户最先撞上的困惑：

| 方言 | 定位 | 建议 |
| :--- | :---: | :---: |
| `data.frame`（base） | 内置，历史包袱多（降维、部分匹配） | 只用于接收别的包的输出 |
| `tibble` + `dplyr`（tidyverse） | 可读性最好，管道风格 | **推荐日常使用**；但千万行级慢一个数量级（实测 19×） |
| `data.table` | 性能最好，语法紧凑 | 大数据量、或要写可预测的函数时用 |

### §3.1 对照表

| pandas | dplyr | data.table |
| :--- | :---: | :---: |
| `df[df.x > 5]` | `filter(df, x > 5)` | `dt[x > 5]` |
| `df[["a","b"]]` | `select(df, a, b)` | `dt[, .(a, b)]` |
| `df.assign(z=df.x*2)` | `mutate(df, z = x*2)` | `dt[, z := x*2]`（**按引用**） |
| `df.sort_values("x")` | `arrange(df, x)` | `setorder(dt, x)` |
| `df.groupby("g").agg(...)` | `group_by(df, g) %>% summarise(...)` | `dt[, .(m=mean(v)), by=g]` |
| `pd.merge(a, b, on="k")` | `inner_join(a, b, by="k")` | `a[b, on="k", nomatch=0]` |
| `df.rename(columns={...})` | `rename(df, new = old)` | `setnames(dt, "old", "new")` |
| `pd.melt` / `df.pivot` | `pivot_longer` / `pivot_wider` | `melt` / `dcast` |
| `df.head()` | `head(df)` | `head(dt)` |
| 链式 `.pipe()` / 方法链 | `%>%` 或 `\|>` | `dt[...][...]` |

### §3.2 三处需要注意的语义差异

| 项 | pandas | R |
| :--- | :---: | :---: |
| **索引（index）** | DataFrame 有独立的 index，会参与对齐运算 | **R 的数据框没有 index 概念**，只有行名（很少用） |
| **合并的行数校验** | `validate="one_to_one"` | dplyr 1.1+ 有 `relationship=`；data.table 需手动 `stopifnot` |
| **分组后的结构** | `groupby` 返回中间对象 | dplyr 返回**仍带分组标记的 tibble**——忘记 `ungroup()` 会让后续操作意外按组进行 |

> 🔴 **`ungroup()` 是 dplyr 特有的坑**：`summarise()` 只脱掉最后一层分组，
> 多层分组时残留的分组会让下游的 `mutate` 静默按组计算。
> **习惯：`summarise()` 之后立刻 `ungroup()`。** pandas 没有这个问题（`groupby` 不粘）。

### §3.3 性能（本机实测，5,000,000 行）

| 操作 | pandas | data.table | dplyr |
| :--- | :---: | :---: | :---: |
| 分组聚合（10 万组） | 0.135 s | **0.085 s** | **1.568 s** |
| 读 225 MB CSV | 1.655 s（默认）/ 0.182 s（pyarrow） | **0.171 s**（`fread`） | — |

**结论**：从 pandas 转过来，`data.table` 性能上不会让你失望；
**但如果直接上 dplyr，千万行级会明显变慢**。详见
[R_vs_Python_neutral_comparison.md](R_vs_Python_neutral_comparison.md) §2。

---

## §4 统计：scipy / statsmodels → R stats

**好消息：R 侧几乎全在 base 的 `stats` 包里，不用 import，也不用判断"归哪个库管"。**

### §4.1 对照表

| Python | R | 备注 |
| :--- | :---: | :---: |
| `scipy.stats.ttest_ind(x, y)` | **`t.test(x, y, var.equal=TRUE)`** | 🔴 见 §4.2 |
| `scipy.stats.ttest_rel(x, y)` | `t.test(x, y, paired=TRUE)` | |
| `scipy.stats.mannwhitneyu(x, y)` | `wilcox.test(x, y)` | 实测结果一致 |
| `scipy.stats.wilcoxon(x, y)` | `wilcox.test(x, y, paired=TRUE)` | **名字容易对错** |
| `scipy.stats.fisher_exact(m)` | `fisher.test(m)` | 实测一致 |
| `scipy.stats.chi2_contingency(m)` | `chisq.test(m)` | 默认都开 Yates 校正 |
| `scipy.stats.false_discovery_control(p)` | `p.adjust(p, "BH")` | 实测逐位一致 |
| `statsmodels.formula.api.ols("y ~ x", d).fit()` | `lm(y ~ x, data=d)` | **公式语法相同** |
| `smf.glm(..., family=Binomial())` | `glm(y ~ x, family=binomial, data=d)` | |
| `fit.summary()` | `summary(fit)` | |
| `fit.params` / `fit.resid` | `coef(fit)` / `resid(fit)` | R 是函数，要括号 |
| `scipy.stats.norm.pdf/cdf/ppf/rvs` | `dnorm` / `pnorm` / `qnorm` / `rnorm` | **`ppf` ↔ `qnorm`** |
| `sklearn` | `caret` / `tidymodels` | 生态更薄 |
| 无等价物 | **`emmeans`** | 事后比较 / 估计边际均值，Python 侧没有 |

### §4.2 🔴 反向的 t 检验陷阱

**实测**（同一组数据）：

| 调用 | df | p |
| :--- | :---: | :---: |
| Python `ttest_ind(x, y)`（默认 Student） | 10.0 | 0.000204867 |
| R `t.test(x, y)`（**默认 Welch**） | 9.827 | **0.000218677** |
| R `t.test(x, y, var.equal=TRUE)` | 10.0 | 0.000204867 ✅ |

**从 Python 转过来时的陷阱方向是反的**：
你在 Python 里写惯了 `ttest_ind(x, y)`（等方差），到 R 里写 `t.test(x, y)`
**会悄悄换成 Welch**，p 值变大（更保守）。

> **哪个更该用？** 统计学界的主流意见是 **Welch 应该作为默认**——
> 它在方差相等时几乎无损失，方差不等时明显更稳健。
> **所以 R 的默认值是更好的那个**，这次不需要"改回去"，
> 但你必须**知道结果变了**，不然会以为是数据处理出了问题。

### §4.3 缺失值：R 会挡住你

| 调用 | 结果 |
| :--- | :---: |
| `pd.Series([1,2,None,4]).mean()` | **2.333**（静默丢弃） |
| R `mean(c(1,2,NA,4))` | **NA** |
| R `mean(c(1,2,NA,4), na.rm=TRUE)` | 2.333 |

**从 Python 转过来，你会觉得 R 很烦——到处要写 `na.rm=TRUE`。**
但这是 R 的设计意图：**它把"这里有缺失值"这个事实强行推到你面前**。

相应地，R 的建模函数有 `na.action` 参数控制整行删除（`na.omit` 是默认），
**并且 `lm` 的输出会告诉你删了多少行**——pandas 不会。

---

## §5 作图：matplotlib / seaborn → ggplot2

### §5.1 心智切换：命令式 → 声明式

| | matplotlib | ggplot2 |
| :--- | :---: | :---: |
| 范式 | **命令式**：逐条下达绘制指令 | **声明式**：描述"数据到视觉的映射" |
| 核心 | `Figure` / `Axes` 对象 | `ggplot` 对象 + 图层叠加 |
| 加东西 | `ax.scatter(...)` 再调一次 | `+ geom_point()` |
| 分面 | `plt.subplots(2,2)` 手工排布 | `+ facet_wrap(~ g)` **一行** |
| 配色一致性 | **每个 Axes 独立分配，容易撞色** | **scale 全图统一，天然一致** |

**ggplot2 相对 matplotlib 的两个结构性优势：**

1. **`facet_wrap()` 一行搞定分面**，而且**每个 panel 的 scale 自动统一**。
   matplotlib 要手工建 subplot、手工同步坐标轴范围、手工统一配色。
2. **不存在"多 panel 撞色"问题**——ggplot2 的 scale 是 plot 级别的，
   而 matplotlib 的默认色环是 Axes 级别的。

### §5.2 对照表

| seaborn / matplotlib | ggplot2 |
| :--- | :---: |
| `sns.scatterplot(data=d, x="a", y="b", hue="g")` | `ggplot(d, aes(a, b, color=g)) + geom_point()` |
| `sns.boxplot(...)` | `+ geom_boxplot()` |
| `sns.lineplot(...)` | `+ geom_line()` |
| `sns.histplot(...)` | `+ geom_histogram()` |
| `sns.heatmap(...)` | `+ geom_tile()`（或 `ComplexHeatmap`） |
| `catplot(..., col="g")` / `plt.subplots` | `+ facet_wrap(~ g)` |
| `palette={...}` | `+ scale_color_manual(values = c(...))` |
| `ax.set(xlabel=, ylabel=, title=)` | `+ labs(x=, y=, title=)` |
| `sns.set_theme(style="whitegrid")` | `+ theme_bw()` |
| `ax.set_xscale("log")` | `+ scale_x_log10()` |
| `fig.savefig("f.pdf", bbox_inches="tight")` | `ggsave("f.pdf", width=, height=)` |

### §5.3 两个默认值差异

| | matplotlib | ggplot2 |
| :--- | :---: | :---: |
| 保存 dpi | `savefig.dpi = "figure"` → **实际 100** | `ggsave` 默认 **300** |
| 标签留白 | `bbox_inches` 默认 `None`，**标签会被裁掉** | 自动留白 |

**从 Python 转 R 时这两条都是"变好了"**，不需要额外做什么——
但反过来要记得：回到 matplotlib 时必须显式加 `dpi=300` 和 `bbox_inches="tight"`。

### §5.4 中间路线：plotnine

如果你想**先用 ggplot2 的语法但留在 Python 里**，本机 `sc_tut_main` 已装 `plotnine 0.15.8`（实测可渲染带 facet 的 PDF）。
它能让你在不切语言的情况下先熟悉图形语法，之后转 ggplot2 几乎零成本。详见
[R_to_Python_stats_and_plotting.md](R_to_Python_stats_and_plotting.md) §4.2。

---

## §6 R 特有的、必须专门学的四样东西

Python 里完全没有对应物，绕不过去：

| # | 概念 | 为什么必须学 |
| :--- | :---: | :---: |
| 1 | **公式对象 `y ~ x`** | 它是一等公民，`lm`/`glm`/`ggplot`/`facet`/`aov` 全靠它；`class(y ~ x)` 是 `"formula"` |
| 2 | **factor** | 不只是"分类变量"——**它控制着模型的对比编码和图里的类别顺序**；`levels()` 的顺序就是基线组的选择 |
| 3 | **S3 / S4 泛型** | 看懂 `summary()` 为什么对什么都能用；Bioconductor 大量用 S4（`@` 取 slot 而不是 `$`） |
| 4 | **Bioconductor 对象体系** | `SummarizedExperiment` / `SingleCellExperiment` 是生信 R 的通用货币，相当于 Python 的 `AnnData` |

### §6.1 factor 是最需要花时间的一个

**Python 里 `pd.Categorical` 只影响内存和排序；R 里 factor 影响统计结果。**

```r
# 基线组由 levels 的第一个决定
d$group <- factor(d$group, levels = c("Ctrl", "Treat", "KO"))
lm(y ~ group, d)     # Ctrl 是基线，输出 groupTreat / groupKO 两个系数
```

改变 `levels` 的顺序会**改变模型输出的每一个系数**（虽然模型拟合本身等价）。
Python 的 `statsmodels` 里对应的是 `C(group, Treatment(reference="Ctrl"))`，但**远没有 R 里这么中心**。

同一个 `levels` 顺序**也决定 ggplot2 里 x 轴和图例的顺序**——
这是 R 里"一个设置同时管统计和作图"的典型例子，而 Python 里这是两件事。

### §6.2 SummarizedExperiment ↔ AnnData 的对应

| 概念 | Python（AnnData） | R（SummarizedExperiment） |
| :--- | :---: | :---: |
| 主矩阵 | `adata.X` | `assay(se)` |
| 观测注释 | `adata.obs` | `colData(se)` |
| 特征注释 | `adata.var` | `rowData(se)` |
| **维度约定** | **细胞 × 基因** | **基因 × 细胞** |

🔴 **两边是转置关系。** 转置后代码照跑、图照出、所有生物学结论都是错的；
细胞数恰好等于基因数时连报错都没有。**跨语言搬数据必须显式转置并 assert 维度。**

---

## §7 工程与环境

| 事项 | Python | R |
| :--- | :---: | :---: |
| 安装包 | `pip` / `conda` / `uv` | `install.packages()`（CRAN）/ `BiocManager::install()` |
| 导入 | `import numpy as np`，**有命名空间** | `library(dplyr)`，**默认污染全局**；单次调用用 `pkg::fn()` |
| 环境隔离 | conda env / venv | `renv`（lockfile）；或整个 conda env 装 R |
| 脚本入口 | `python script.py` | `Rscript script.R` |
| CLI 参数 | `argparse`（标准库） | `optparse` / `argparser`（第三方） |
| 测试 | `pytest` | `testthat` |
| 类型检查 | 类型提示 + mypy | 无；**`vapply` 是最接近的运行时强制** |
| 并行 | `joblib` / `multiprocessing` | `parallel` / `future`（更啰嗦） |

### §7.1 🔴 `library()` 会污染全局命名空间

```r
library(dplyr)     # 导出 ~300 个函数到搜索路径
filter(d, x > 5)   # 这是 dplyr::filter 还是 stats::filter?
```

**`dplyr::filter` 会遮蔽 `stats::filter`**，R 会打印一条 masking 消息——
但那条消息在脚本输出里极易被忽略。Python 的 `import numpy as np` 不存在这个问题。

**防法**：关键调用写全 `dplyr::filter(...)`；
脚本开头的 `library()` 顺序会影响谁遮蔽谁，**把最重要的包放最后**。

### §7.2 线程默认值（本机实测）

`data.table` 默认用 **32 线程**——超出"单任务按 28 核 / 56 线程设计"的预算。

```r
data.table::setDTthreads(8)      # 脚本开头就设
```

---

## §8 上手路径建议

| 阶段 | 做什么 | 为什么 |
| :--- | :---: | :---: |
| 第 1 步 | 把 §2.10 的 9 条陷阱**贴在手边** | 它们是唯一会静默算错的东西，其余写错都会报错 |
| 第 2 步 | 养成三个习惯：`seq_len()`、`vapply()`、`stopifnot(length(...))` | 把 Python 免费给你的检查手动买回来 |
| 第 3 步 | 学 **factor**（§6.1） | 它同时影响统计结果和图，绕不过去 |
| 第 4 步 | 数据处理选 **`data.table`** 而不是 dplyr | 语义更可预测（没有 NSE、没有 `ungroup()` 坑），性能也好；对 Python 用户更友好 |
| 第 5 步 | 作图直接学 **ggplot2** | 声明式范式比 matplotlib 好用，学它是净收益 |
| 第 6 步 | 按需学 Bioconductor 对象体系 | 只在真要用 DESeq2 / clusterProfiler 时学 |

> **我的判断**：从 Python 转 R 时，**跳过 tidyverse 直接用 `data.table` + `ggplot2`** 是更顺的路径。
> tidyverse 的 NSE 和管道对 R 原生用户很自然，但对 Python 用户是额外的概念负担，
> 而 `data.table` 的 `dt[i, j, by]` 结构和 pandas 的思维更接近。
> **唯一例外是 ggplot2**——它属于 tidyverse，但没有替代品，也不涉及 NSE 的复杂部分。

---

## §9 实测环境与复现

| 侧 | 路径 | 版本 |
| :--- | :---: | :---: |
| R | `/Work_bio/gao/configs/.conda/envs/DE_R45` | R 4.5.2；data.table 1.17.8；dplyr 1.2.0；ggplot2 4.0.2 |
| Python | `/mnt/ex_8T_SSD/conda_envs/sc_tut_main` | Python 3.11.16；numpy 2.4.6；scipy 1.17.1；pandas 2.3.3；statsmodels 0.14.6 |

### §9.1 ⚠️ 探测时必须用绝对解释器路径

本机 `conda run -n <env>` 存在被 `PATH` 注入绕过的情况（`-n` 与 `-p` 都失效且不报错），
详见 [Python_core_modules_for_bioinformatics.md](Python_core_modules_for_bioinformatics.md) §8.1。

### §9.2 陷阱复现（一条命令跑完 §0 的三条）

```bash
/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript -e '
cat("1) recycling :", c(1,2,3,4) + c(10,20), "  <- 静默补齐\n")
f <- factor(c(10,20,30,20))
cat("2) as.numeric(factor) :", as.numeric(f), "  <- 编码, 不是值\n")
n <- 0
cat("3) 1:0 长度 =", length(1:n), " 内容 =", 1:n, "  <- 循环会跑 2 次\n")'
```

---

## §10 本文的事实来源

| 内容 | 来源 |
| :--- | :---: |
| §0 / §2 全部 R 行为（recycling、factor 编码、`1:0`、`sapply` 类型、`$` 部分匹配、`:=` 引用、`drop`、`apply` 强制转换、`T`/`F` 可重赋值） | **2026-09-17 本机实测** |
| Python 侧对照行为（`ValueError` 广播失败、list/ndarray/DataFrame 的引用语义） | **2026-09-17 本机实测** |
| §3.3 性能数字 | **2026-09-17 实测**，5,000,000 行 × 3 次取 min，详见中立比对篇 §2 |
| §4.2 t 检验两边默认值与 p 值 | **2026-09-17 双语实测** |
| §5.3 dpi 与 bbox 默认值 | **2026-09-17 实测**（`formals(ggsave)` 与 `rcParams`） |
| R 4.5.2 里 `data.frame` 不再自动转 factor | **2026-09-17 实测** |
| `data.table` 默认 32 线程 | **2026-09-17 实测**（`getDTthreads()`） |
| "Welch 应作为默认"是统计学界主流意见 | 文献共识，**非实测** |
| §8 上手路径、"跳过 tidyverse 直接用 data.table" | **我的判断**，非实测 |
| §6 "factor 是最需要花时间的" | **我的判断** |
