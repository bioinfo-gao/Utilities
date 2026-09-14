# R 的四种「表格类」数据结构：data.frame / table / data.table / tibble

> 建立日期：2026-09-14
> 用途：分清这四个长得都像表格、但本质完全不同的东西，避免互转时静默出错。
> 本文所有数字与行为均为**本机实测**，实测环境见文末 §8。

---

## §0 TL;DR — 先看这张决策表

| 我要做的事 | 用哪个 |
| :--- | :---: |
| 一般的样本表、注释表、DESeq2 结果表（几千～几万行） | `data.frame` 或 `tibble` |
| 统计某分类变量的频数、做列联表、跑卡方 | `table` |
| 读/写几十万行以上的大表（counts、per-base depth、VCF 转的 TSV） | `data.table`（`fread`/`fwrite`） |
| 大规模 group-by 聚合、interval join | `data.table` |
| 走 tidyverse 管道、要严格的报错而不是静默猜测 | `tibble` |

**一句话区分**：
- `data.frame` = **list of columns**，每列类型可不同 → 通用表格
- `table` = **array of counts**，全部同类型 → 频数/列联表
- `data.table` = data.frame 的**高性能子类**，引用语义
- `tibble` = data.frame 的**严格子类**，行为更可预测

---

## §1 继承关系 —— 谁是谁的子类

```
                    data.frame  (base R)
                    /        \
          data.table          tbl_df (tibble)
       class(dt) 返回              class(tb) 返回
  c("data.table","data.frame")   c("tbl_df","tbl","data.frame")

        table  (base R)  ←── 和上面三个【毫无关系】，它是 array 的子类
```

关键点：**`data.table` 和 `tibble` 都 `inherits(x, "data.frame") == TRUE`**，所以任何接受
data.frame 的函数（包括 DESeq2、limma、ggplot2）都能直接吃它们。
而 `table` **不是** data.frame，传给这些函数会报错或行为诡异。

### 一条命令定死身份

```r
class(x); typeof(x); is.array(x)
```

| 对象 | `class()` | `typeof()` | `is.array()` |
| :--- | :---: | :---: | :---: |
| data.frame | `data.frame` | `list` | FALSE |
| table | `table` | `integer` | **TRUE** |
| data.table | `data.table` `data.frame` | `list` | FALSE |
| tibble | `tbl_df` `tbl` `data.frame` | `list` | FALSE |

---

## §2 `data.frame` — base R 的默认表格

底层是一个 **list**，每个元素是一列（一个等长向量）。列与列之间类型可以不同。
永远是二维的。行有 `rownames`，列有 `colnames`。

```r
df <- data.frame(gene = c("A","B","C"), tpm = c(10, 2, 30))
typeof(df)   # "list"
```

### 需要知道的默认行为

| 行为 | 说明 |
| :--- | :---: |
| `df[, "tpm"]` | **降维成向量**（不是单列表格） |
| `df[, c("gene","tpm")]` | 返回 data.frame |
| `df$tp` | **部分匹配**到 `tpm`，不报错不警告 |
| `df$nope` | 静默返回 `NULL` |
| `stringsAsFactors` | R ≥ 4.0 起默认 `FALSE` |
| 修改列 | 每次 `df$new <- ...` 可能**复制整张表** |

`df[, "col"]` 的降维是经典 bug 源：写函数时如果不确定会取到几列，
必须加 `drop = FALSE` → `df[, cols, drop = FALSE]`。

---

## §3 `table` — 频数表 / 列联表，本质是 array

`table()` 返回的对象**不是** data.frame。它是一条带 `dim` 和 `dimnames` 的
**atomic 整数向量**，内容是**计数**。可以是 1 维、2 维、3 维……任意维。

```r
df <- data.frame(gene = c("A","B","A","A"), cond = c("KO","KO","WT","WT"))
tb  <- table(df$gene, df$cond)
```

实测输出：
```
   
    KO WT
  A  1  2
  B  1  0
```
`typeof(tb)` = `"integer"`，`is.array(tb)` = `TRUE`，`dim(tb)` = `2 2`。

### 与 data.frame 的核心差异

| 维度 | `data.frame` | `table` |
| :--- | :---: | :---: |
| 底层类型 | list of vectors | 带 dim/dimnames 的 atomic array |
| 列类型 | 每列可不同 | 全部同一类型（通常 integer） |
| 维度数 | 永远 2 维 | 1、2、3…… 任意维 |
| 内容语义 | 任意观测数据 | 交叉分类的**频数** |
| 怎么产生 | `data.frame()` `read.csv()` `read.table()` | `table()` `xtabs()` `ftable()` |
| 行列名 | `rownames`/`colnames` | `dimnames`（= 各 factor 的 levels） |
| 典型操作 | `$` `subset()` dplyr `merge()` | `prop.table()` `margin.table()` `addmargins()` `chisq.test()` |
| `apply` | 先内部转 matrix（类型被强制统一） | 原生 array，直接可用 |

### 四个会咬人的点

**1. `read.table()` 返回的是 `data.frame`，不是 `table`。**
名字是历史包袱 —— 这里的 "table" 指「文本表格文件」。实测确认：`class(read.table(...))` = `data.frame`。
这是最常见的误会。

**2. `prop.table()` / `chisq.test()` 不吃 data.frame。**
要算行/列百分比必须先是 table 或 matrix。反过来 dplyr 那一套不吃 table。

**3. 互转会换形状** —— 这是最容易静默出错的地方：
```r
as.data.frame(tb)          # → 【长格式】Var1, Var2, Freq（每个格子一行）
as.data.frame.matrix(tb)   # → 【宽格式】保持原来的矩形
xtabs(Freq ~ Var1 + Var2, data = long_df)   # 长格式 df → table
```
`as.data.frame(tb)` 默认给**长格式**，不是屏幕上看到的那个矩形。实测：2×2 的 table
转出来是 4 行 × 3 列（Var1/Var2/Freq）。想保留矩形必须显式 `as.data.frame.matrix()`。

**4. `table()` 会把没出现的组合列成 0**，而 `dplyr::count()` 默认**不产生**这些零行。
做完全交叉表时这个差别会直接改变结论（分母不同）。
相关：`table(factor)` 保留所有 levels 包括 n=0 的，`droplevels()` 之后就没了。

---

## §4 `data.table` — 大数据下的高性能子类

CRAN 包。提供 data.frame 的**高性能子类**，三个特色：
**`dt[i, j, by]` 三段式语法**、**引用语义（`:=` 原地改不复制）**、**为大数据优化的 C 实现**。

### 实测性能（300 万行 / 72 MB CSV，`setDTthreads(8)`）

| 操作 | base R | dplyr | data.table |
| :--- | :---: | :---: | :---: |
| 读 CSV | `read.csv` 1.87 s | — | `fread` **0.44 s**（4.2×） |
| `gene × samp` 分组求和 | `aggregate` 9.94 s | 2.41 s | **0.11 s**（比 dplyr 快 22×） |

结果 `all.equal` 数值全等，行数一致（479,089 行）。

### 核心语法 `dt[i, j, by]`

一个方括号塞三件事，对应 SQL 的 `WHERE` / `SELECT` / `GROUP BY`：

```r
dt[tpm > 3,                          # i  = 筛行
   .(mean_tpm = mean(tpm), n = .N),  # j  = 算什么
   by = cond]                        # by = 分组
```
对照 dplyr 就是 `filter() %>% group_by() %>% summarise()` 压成一行。

特殊符号：`.N`（当前组行数）、`.SD`（当前组子表）、`.SDcols`（限定哪些列）、
`.I`（行号）、`.GRP`（组序号）。

### ⚠ 最大特色也是最大的坑：引用语义

`:=` 是**原地修改，不产生副本**。这是它快和省内存的根源，也是所有 bug 的来源：

```r
dt2 <- dt          # 这【不是】复制！dt2 和 dt 指向同一块内存
dt2[, tpm := 0]    # 改 dt2 → dt 也被改了（实测确认）
dt3 <- copy(dt)    # 要真副本必须显式 copy()
```

**从 data.frame 换过来的人十有八九栽在这里。** 三条保命规则：

1. 想要独立副本 → **必须** `copy()`，`<-` 不算。
2. 函数内部要改传进来的 dt → 要么文档写明「会修改入参」，要么第一行 `dt <- copy(dt)`。
3. `set*` 开头的函数（`setDT` `setnames` `setorder` `setkey` `setcolorder`）
   **全部原地修改**，并 invisibly 返回对象本身（实测：返回 data.table，**不是 NULL**）。
   所以 `dt <- setorder(dt, x)` 能正常工作，只是**多余**。
   真正的风险是反过来 —— 以为「没赋值就没改」，其实原对象早就变了：
   `setDT(df)` 之后原来那个 `df` 本身已经是 data.table 了。

### 内存的真相

实测 300 万行：`object.size()` 两者都是 **61 MB**。
**`data.table` 并不「存得更小」** —— 省的是**操作过程中的拷贝**。
base R 每次 `df$new <- ...` 都可能复制整张表，`:=` 不会。表越大、操作越多，差距越明显。

### 🔴 默认吃满所有核 —— 必须限流

本机实测 `getDTthreads()` 返回 **32**。按本机 **28 核 / 56 线程**的硬上限，
尤其多管线并跑时，脚本开头务必显式限流：

```r
setDTthreads(8)   # 或写进 ~/.Rprofile
```
否则一个 R 会话就能把 CPU 预算吃穿，而且不容易发现是它干的。

### 其它陷阱

| 陷阱 | 说明 |
| :--- | :---: |
| `fread` 类型猜测基于抽样 | 前面全数字、后面混字符的列（如 `1,2,...,X,MT`）会猜错 → 用 `colClasses=` 显式指定 |
| 和 dplyr 混用 | 直接把 dt 传给 dplyr 动词会按 data.frame 语义**复制**，速度优势归零。要混用请走 `dtplyr` |
| 包内使用 | `.N` `.SD` 裸列名会触发 `R CMD check` 的 "no visible binding" 警告，需 `utils::globalVariables()`。写脚本不受影响 |

### 生信场景下值得用的地方

| 场景 | 为什么 |
| :--- | :---: |
| `fread()` 读大表 | featureCounts/salmon 的 counts、mosdepth 的 per-base bed、VCF 转的 TSV |
| `fwrite()` 写大表 | 并行写，百万行矩阵明显快 |
| `foverlaps()` 区间重叠 | peak × gene、CNV × exon 这类 interval join，不想拖 GenomicRanges 依赖时的轻量替代 |
| 大规模 group-by | 单细胞 pseudobulk 聚合、per-sample per-gene 汇总 |
| 多表 join | `merge()` 或 `dt[other, on=.(key)]`，有 key 时是二分查找 |

---

## §5 `tibble` — tidyverse 的严格版 data.frame

tidyverse 的核心数据结构，也是 data.frame 的子类
（`class()` = `c("tbl_df","tbl","data.frame")`）。

设计哲学一句话：**「Do less, complain more」** ——
少做自作聪明的猜测，多报错多警告。它**不追求速度**，追求的是**行为可预测**。

### 四个关键行为差异（全部实测确认）

**1. `[` 永不降维。**
```r
df[, "tpm"]    # data.frame → numeric 向量（降维了）
tb[, "tpm"]    # tibble     → 还是 tibble（永远保持表格）
tb[["tpm"]]    # 要向量必须用 [[ 或 $
```
这条消灭了 data.frame 里 `drop = FALSE` 那类 bug —— 类型永远可预测。

**2. 不做部分匹配，取不存在的列会警告。**
```r
df$tp     # → 悄悄匹配到 tpm，不报错不警告  ⚠
tb$tp     # → WARNING: Unknown or uninitialised column: `tp`
df$nope   # → 静默 NULL
tb$nope   # → WARNING: Unknown or uninitialised column: `nope`
```
这是 tibble 最大的实用价值：**列名打错会被当场抓住**，而不是下游几百行才发现数值不对。

**3. 🔴 不支持 rownames —— 生信里的头号坑。**
```r
m  <- as.data.frame(matrix(...))          # rownames = 基因名
as_tibble(m)                              # rownames 【被丢弃】，变成 1,2,3...
as_tibble(m, rownames = "gene")           # ✅ 必须显式保住
```
**counts 矩阵、TPM 矩阵、DESeq2 的 `results()` 输出，基因名全在 rownames 里。**
随手 `as_tibble()` 就会静默丢掉基因身份 —— 数据还在、行数不变、不报错，
但你已经不知道哪行是哪个基因了。**这个错误极难在下游发现。**

反向：`tibble::column_to_rownames()` / `rownames_to_column()` 是配套工具。

**4. 回收规则严格：只允许长度 1 的回收。**
```r
data.frame(a = 1:6, b = 1:2)   # base R：悄悄回收成 1,2,1,2,1,2
tibble(a = 1:3, b = 1:2)       # ERROR: Tibble columns must have compatible sizes.
tibble(a = 1:3, b = 1)         # OK —— 长度 1 可以回收
```

### 打印行为

这是日常感受最明显的差别：

```
# A tibble: 3 × 2
  gene    tpm
  <chr> <dbl>
1 A        10
2 B         2
3 C        30
```
默认只打前 10 行、只打屏幕放得下的列，**并且每列标注类型**（`<chr>` `<dbl>` `<int>` `<fct>`）。
data.frame 直接 `print()` 十万行会刷屏。

### 其它

- `tibble()` **按顺序求值**，可以引用刚建的列：`tibble(a = 1:3, b = a * 2)` 合法
- 允许**非语法列名**（带空格、以数字开头），用反引号引用：`` tb$`gene name` ``
- 不自动把字符串转 factor（和现代 data.frame 一致）

---

## §6 互转速查

| 从 → 到 | 命令 | ⚠ 注意 |
| :--- | :---: | :--- |
| data.frame → tibble | `as_tibble(df)` | **rownames 会丢**！用 `as_tibble(df, rownames="gene")` |
| tibble → data.frame | `as.data.frame(tb)` | 无损 |
| tibble → 带 rownames 的 df | `column_to_rownames(tb, "gene")` | 给 DESeq2 等需要 rownames 的函数用 |
| data.frame → data.table | `as.data.table(df)` 或 `setDT(df)` | `setDT()` **原地改**，之后原 df 也变成 dt 了 |
| data.table → data.frame | `setDF(dt)` 或 `as.data.frame(dt)` | `setDF()` 原地改 |
| 向量/因子 → table | `table(x)` | 保留所有 factor levels（含 n=0） |
| table → 长格式 df | `as.data.frame(tb)` | 得到 Var1/Var2/Freq |
| table → 宽格式 df | `as.data.frame.matrix(tb)` | 保持矩形 |
| 长格式 df → table | `xtabs(Freq ~ a + b, data=df)` | |
| table → 比例 | `prop.table(tb, margin)` | `margin=1` 按行，`2` 按列 |

---

## §7 陷阱总清单（按危险程度排序）

| # | 陷阱 | 后果 | 防法 |
| :--- | :--- | :---: | :--- |
| 1 | `as_tibble()` 丢 rownames | **基因名静默丢失**，不报错 | `as_tibble(df, rownames="gene")` |
| 2 | `data.table` 的 `<-` 不复制 | 改副本污染原对象 | 必须 `copy()` |
| 3 | `as.data.frame(table)` 变长格式 | 形状突变，下游 join 全错 | 要矩形用 `as.data.frame.matrix()` |
| 4 | `df[, "col"]` 降维 | 函数里类型不稳定 | `drop = FALSE`，或改用 tibble |
| 5 | `df$tp` 部分匹配到 `tpm` | 取到错误的列，静默 | 用 tibble，或 `df[["tp"]]` |
| 6 | `data.table` 默认吃满 32 线程 | 撑爆 CPU 预算 | `setDTthreads(8)` |
| 7 | `fread` 抽样猜类型 | 染色体列 `X`/`MT` 被判成 NA | `colClasses=` 显式指定 |
| 8 | `table()` 产生 0 计数格 vs `count()` 不产生 | 分母不同 → 比例算错 | 明确要不要零行 |
| 9 | `read.table()` 返回 data.frame 不是 table | 概念混淆 | 记住名字是历史包袱 |
| 10 | `set*()` 原地修改 | 以为「没赋值就没改」，原对象已经变了 | 记住 `setDT(df)` 之后原 `df` 就是 data.table |

---

## §8 实测环境与选型建议

### 实测环境（2026-09-14）

| 项 | 版本 |
| :--- | :---: |
| R | 4.5.2 (2025-10-31) |
| data.table | 1.17.8 |
| tibble | 3.3.1 |
| dplyr | 1.2.0 |
| dtplyr | 1.3.3 |
| conda env | `regular_bioinfo` |

本文所有性能数字来自本机单次运行，仅用于表达**量级差异**，不是严格 benchmark。

### 什么时候不必上 data.table

几千到几万行的表（多数 DESeq2 结果表、样本表、注释表）——
`data.frame` 或 `tibble` 就够。换成 data.table 只会增加一个引用语义的出错面，
**看不到速度收益**。规模没上到几十万行以上，不值得为它改写代码。

### 什么时候不必上 tibble

已经在写纯 base R 的脚本、或要传给只认 rownames 的老包（很多 Bioconductor 对象）时，
data.frame 更省事 —— 反正 rownames 迟早要转回去。

### 实务上的组合

- **读**：大文件一律 `fread()`（返回 data.table，需要的话再 `setDF()`）
- **算**：几十万行以上用 data.table 的 `[i,j,by]`；小表用 dplyr 可读性更好
- **传给 Bioconductor**：转回带 rownames 的 data.frame 或 matrix
- **出图**：ggplot2 三者通吃（table 不行，要先转）
