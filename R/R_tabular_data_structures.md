# R 的五种「表格类」数据结构：data.frame / table / matrix / data.table / tibble

> 建立日期：2026-09-14（2026-09-14 增补 §4 matrix）
> 用途：分清这五个长得都像表格、但本质完全不同的东西，避免互转时静默出错。
> 本文所有数字与行为均为**本机实测**，实测环境见文末 §9。

---

## §0 TL;DR — 先看这张决策表

| 我要做的事 | 用哪个 |
| :--- | :---: |
| 一般的样本表、注释表、DESeq2 结果表（几千～几万行） | `data.frame` 或 `tibble` |
| 统计某分类变量的频数、做列联表、跑卡方 | `table` |
| **纯数值的表达矩阵**、要做 `%*%`/`prcomp`/`svd`、喂给 Bioconductor | **`matrix`** |
| **单细胞的稀疏 counts**（90%+ 是零） | **`dgCMatrix`**（`Matrix` 包） |
| 读/写几十万行以上的大表（counts、per-base depth、VCF 转的 TSV） | `data.table`（`fread`/`fwrite`） |
| 大规模 group-by 聚合、interval join | `data.table` |
| 走 tidyverse 管道、要严格的报错而不是静默猜测 | `tibble` |

**一句话区分**：
- `data.frame` = **list of columns**，每列类型可不同 → 通用表格
- `table` = **array of counts**，全部同类型 → 频数/列联表
- `matrix` = **一条 atomic vector + `dim`**，全表同类型 → 数值计算 / 表达矩阵
- `data.table` = data.frame 的**高性能子类**，引用语义
- `tibble` = data.frame 的**严格子类**，行为更可预测

**最关键的一刀**：`data.frame`/`data.table`/`tibble` 是 **list**（列可异构）；
`matrix`/`table` 是 **atomic vector + dim**（全表同构）。
跨过这条线的每一次转换都可能发生**静默类型强制**。

---

## §1 继承关系 —— 谁是谁的子类

```
【list 家族 —— 列可以异构】        【atomic + dim 家族 —— 全表同构】

        data.frame (base R)              atomic vector + dim
        /              \                          │
data.table            tbl_df                   array (任意维)
                     (tibble)                  /            \
                                          matrix           table
                                        (恰好 2 维)      (计数语义)

  class(dt) = c("data.table","data.frame")    class(m)  = c("matrix","array")
  class(tb) = c("tbl_df","tbl","data.frame")  class(tb_) = "table"
```

**左边三个**：`inherits(x, "data.frame") == TRUE`，所以任何接受 data.frame 的函数
（包括 DESeq2、limma、ggplot2）都能直接吃它们。

**右边两个**：都**不是** data.frame。它们之间倒是有关系 ——
实测 **2 维的 `table` 满足 `is.matrix() == TRUE`**（反过来 `is.table(matrix)` 是 FALSE）。
这就是为什么 `prop.table()`、`rowSums()` 对 2D table 能用。

**两个家族之间没有继承关系**，互转必须显式调用，而且**每次跨界都是静默类型强制的风险点**。

### 一条命令定死身份

```r
class(x); typeof(x); is.array(x); is.data.frame(x)
```

| 对象 | `class()` | `typeof()` | `is.array()` | `is.data.frame()` |
| :--- | :---: | :---: | :---: | :---: |
| data.frame | `data.frame` | `list` | FALSE | TRUE |
| table (2D) | `table` | `integer` | **TRUE** | FALSE |
| matrix | `matrix` `array` | 元素类型 | **TRUE** | FALSE |
| data.table | `data.table` `data.frame` | `list` | FALSE | TRUE |
| tibble | `tbl_df` `tbl` `data.frame` | `list` | FALSE | TRUE |

`matrix` 的 `typeof()` 取决于内容：`integer` / `double` / `character` / `logical` —— 
**但全表只能有一种**。这一格就是它和 data.frame 最本质的差别。

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

## §4 `matrix` — 同类型的二维 array，数值计算的主场

### 本质

**`matrix` = 一条 atomic vector + 一个 `dim` 属性**。就这么简单 ——
实测 `attributes(m)` 只有 `dim` 和 `dimnames` 两个；把 `dim` 设成 `NULL`，它立刻变回普通向量。

```r
m <- matrix(1:6, nrow = 2, dimnames = list(c("g1","g2"), c("s1","s2","s3")))
typeof(m)      # "integer"  —— 不是 list！
class(m)       # "matrix" "array"   （R ≥ 4.0 起 matrix 同时是 array）
x <- m; dim(x) <- NULL; class(x)    # "integer"，长度 6
```

**所有格子必须同一类型**（logical / integer / double / character / complex 之一）。
这是它和 `data.frame` 的分水岭：data.frame 是 **list of columns**（列可异构），
matrix 是 **一个向量**（全表同构）。

### 和另外四者的关系

```
         atomic vector + dim
                  │
               array  (任意维)
              /      \
         matrix       table
        (恰好2维)     (计数语义)
```

`table` 其实就是**带计数语义的 array**。实测：**2 维的 `table` 满足 `is.matrix() == TRUE`**，
但反过来 `is.table(matrix)` 是 `FALSE`。所以 `prop.table()`、`rowSums()` 这些
对 2D table 能用，本质是因为它就是个 matrix。

**matrix 和 data.frame / data.table / tibble 之间没有继承关系** ——
`is.data.frame(matrix)` 是 `FALSE`，互转都要显式调用。

### 🔴 头号陷阱：`as.matrix()` 对混合类型的静默类型强制

这是本文档里**最容易造成静默错误**的一条，和 tibble 丢 rownames 并列：

```r
df <- data.frame(gene = c("A","B"), tpm = c(10.5, 2.3), n = c(1L, 2L))
mm  <- as.matrix(df)
typeof(mm)   # "character"   ← 数值列全部变成字符串，不报错不警告
```

实测输出：
```
     gene tpm    n
[1,] "A"  "10.5" "1"
[2,] "B"  " 2.3" "2"
```

**注意 `" 2.3"` 前面那个空格** —— 转换时按最宽的值**右对齐补空格**了。后果：

| 操作 | 结果 |
| :--- | :---: |
| `sum(mm[,"tpm"])` | **ERROR**: invalid 'type' (character) |
| `as.numeric(mm[,"tpm"])` | 还能救回来 → `10.5 2.3` |
| `mm[2,"tpm"] == "2.3"` | **FALSE**（因为实际是 `" 2.3"`） |

最后一条最阴 —— 字符串比较静默失败，不报错。

**防法**：只对**纯数值**的子集调 `as.matrix()`：
```r
as.matrix(df[, sapply(df, is.numeric)])    # typeof → "double" ✅
# 或先把基因名挪进 rownames
mat <- as.matrix(column_to_rownames(df, "gene"))
```

### ⚠ 连带陷阱：`apply()` 在 data.frame 上也会触发同样的强制

`apply()` 内部**先把 data.frame 转成 matrix**，所以混合类型的表会整体被转成 character：

```r
mixed <- data.frame(a = c("x","y"), b = c(1, 2))
apply(mixed, 1, class)    # 实测 → 全是 "character"，数值列被吞了
```
按行遍历混合类型的表，应该用 `purrr::pmap()` 或 `for` + `df[i, ]`，不要用 `apply()`。

### 性能与内存的真相

5000 基因 × 200 样本的实测：

| 指标 | matrix | data.frame |
| :--- | :---: | :---: |
| `object.size()` | 4.0 MB | 4.0 MB |
| `rowMeans()` | 0.004 s | 0.008 s（2×） |

**结论和直觉不一样**：纯数值、行多列少时，两者内存**基本相同**，`rowMeans` 也只差 2 倍。
列数拉大后 data.frame 的 overhead 稳定在约 **1.3×**（实测 50 行 × 10 / 1000 / 20000 列
分别是 1.40× / 1.30× / 1.30×），也不是数量级差异。

**所以选 matrix 的理由不是「省内存」，而是**：
1. **矩阵运算只认 matrix** —— `%*%`、`t()`、`solve()`、`svd()`、`prcomp()`
   传 data.frame 直接报错（实测 `df %*% df` → ERROR）
2. **绝大多数 Bioconductor 接口要 matrix** —— DESeq2 的 counts、limma 的 expression matrix
3. **`rowSums`/`colMeans`/`scale`/`apply` 语义干净**，不会有类型强制的意外

### 生信场景的三条实务

**1. DESeq2 的 counts 必须是整数 matrix。**
salmon/kallisto 的 estimated counts 是小数，直接传会被拒：
```r
storage.mode(cm) <- "integer"      # 实测：double → integer，原地改存储模式
# 或 round(cm) 之后再转
```
（`tximport` 走 `DESeqDataSetFromTximport()` 是另一条正规路径，不用手动取整。）

**2. rownames 在 matrix ↔ data.frame 之间是安全的。**
实测 `as.data.frame(m)` 和 `as.matrix(d)` 双向都保留 rownames ——
**只有 `as_tibble()` 会丢**（见 §6）。所以 counts 矩阵在 matrix 和 data.frame 之间来回转不会丢基因名。

**3. 单细胞必须用稀疏矩阵 `dgCMatrix`（`Matrix` 包）。**
实测 2000 × 500、95% 为零的矩阵：

| 存储 | 大小 |
| :--- | :---: |
| dense matrix | 4.0 MB |
| `dgCMatrix` | **0.6 MB**（省 85%） |

真实 scRNA 数据零值占比通常 90–95%，矩阵还大得多，所以省下的是**几十 GB 量级**。
Seurat 的 `@counts`/`@data`、SingleCellExperiment 的 `assay()` 底层都是 `dgCMatrix`。
**不要对它随手 `as.matrix()`** —— 会瞬间展开成 dense 撑爆内存，这是单细胞里最常见的 OOM 原因。

### `[` 同样降维

和 data.frame 一样，`m[, "s1"]` 返回向量而不是矩阵，实测需要 `drop = FALSE` 才保持二维：
```r
m[, "s1"]              # integer 向量，长度 2
m[, "s1", drop=FALSE]  # matrix，dim 2×1
```

---

## §5 `data.table` — 大数据下的高性能子类

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

## §6 `tibble` — tidyverse 的严格版 data.frame

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

## §7 互转速查

| 从 → 到 | 命令 | ⚠ 注意 |
| :--- | :---: | :---: |
| data.frame → tibble | `as_tibble(df)` | **rownames 会丢**！用 `as_tibble(df, rownames="gene")` |
| tibble → data.frame | `as.data.frame(tb)` | 无损 |
| tibble → 带 rownames 的 df | `column_to_rownames(tb, "gene")` | 给 DESeq2 等需要 rownames 的函数用 |
| data.frame → data.table | `as.data.table(df)` 或 `setDT(df)` | `setDT()` **原地改**，之后原 df 也变成 dt 了 |
| data.table → data.frame | `setDF(dt)` 或 `as.data.frame(dt)` | `setDF()` 原地改 |
| **data.frame → matrix** | `as.matrix(df)` | 🔴 **混合类型会全部变 character**！只对纯数值列用：`as.matrix(df[, sapply(df, is.numeric)])` |
| **matrix → data.frame** | `as.data.frame(m)` | 无损，**rownames 保留**（实测） |
| **matrix → tibble** | `as_tibble(m, rownames="gene")` | 不写 `rownames=` 就丢基因名 |
| **matrix 改存储类型** | `storage.mode(m) <- "integer"` | DESeq2 要整数 counts 时用 |
| **matrix → 稀疏** | `Matrix(m, sparse=TRUE)` | 得到 `dgCMatrix`，95% 零时省 85% 内存（实测） |
| **稀疏 → dense** | `as.matrix(sp)` | ⚠ 单细胞里这一步是最常见的 OOM 来源 |
| 向量/因子 → table | `table(x)` | 保留所有 factor levels（含 n=0） |
| table → 长格式 df | `as.data.frame(tb)` | 得到 Var1/Var2/Freq |
| table → 宽格式 df | `as.data.frame.matrix(tb)` | 保持矩形 |
| 长格式 df → table | `xtabs(Freq ~ a + b, data=df)` | |
| table → 比例 | `prop.table(tb, margin)` | `margin=1` 按行，`2` 按列 |

---

## §8 陷阱总清单（按危险程度排序）

| # | 陷阱 | 后果 | 防法 |
| :--- | :---: | :---: | :---: |
| 1 | `as.matrix(混合类型 df)` 全变 character | **数值静默变字符串**，还带右对齐空格 → `sum()` 报错、`==` 比较假 FALSE | 只对纯数值列转：`as.matrix(df[, sapply(df, is.numeric)])` |
| 2 | `as_tibble()` 丢 rownames | **基因名静默丢失**，不报错 | `as_tibble(df, rownames="gene")` |
| 3 | 对 `dgCMatrix` 随手 `as.matrix()` | **瞬间展开成 dense → OOM**，单细胞头号死因 | 保持稀疏；必须 dense 时先 subset |
| 4 | `data.table` 的 `<-` 不复制 | 改副本污染原对象 | 必须 `copy()` |
| 5 | `apply()` 作用于混合类型 df | 内部先转 matrix → 数值列被吞成 character | 用 `purrr::pmap()` 或 `for` + `df[i, ]` |
| 6 | `as.data.frame(table)` 变长格式 | 形状突变，下游 join 全错 | 要矩形用 `as.data.frame.matrix()` |
| 7 | `df[, "col"]` / `m[, "col"]` 降维 | 函数里类型不稳定 | `drop = FALSE`，或改用 tibble |
| 8 | `df$tp` 部分匹配到 `tpm` | 取到错误的列，静默 | 用 tibble，或 `df[["tp"]]` |
| 9 | `data.table` 默认吃满 32 线程 | 撑爆 CPU 预算 | `setDTthreads(8)` |
| 10 | `fread` 抽样猜类型 | 染色体列 `X`/`MT` 被判成 NA | `colClasses=` 显式指定 |
| 11 | DESeq2 收到 double counts | 报错拒绝 | `storage.mode(cm) <- "integer"` |
| 12 | `table()` 产生 0 计数格 vs `count()` 不产生 | 分母不同 → 比例算错 | 明确要不要零行 |
| 13 | `read.table()` 返回 data.frame 不是 table | 概念混淆 | 记住名字是历史包袱 |
| 14 | `set*()` 原地修改 | 以为「没赋值就没改」，原对象已经变了 | 记住 `setDT(df)` 之后原 `df` 就是 data.table |

**前 3 条是静默的** —— 不报错、行数不变、肉眼看不出，往往在下游几百行之后才以「数字不对」的形式暴露。
其余多数会当场报错或警告，危险性低一个量级。

---

## §9 实测环境与选型建议

### 实测环境（2026-09-14）

| 项 | 版本 |
| :--- | :---: |
| R | 4.5.2 (2025-10-31) |
| data.table | 1.17.8 |
| tibble | 3.3.1 |
| dplyr | 1.2.0 |
| dtplyr | 1.3.3 |
| Matrix | 1.7.5 |
| conda env | `regular_bioinfo` |

⚠ `Matrix` 1.7.5 加载时会警告 "package 'Matrix' was built under R version 4.5.3"
（装的版本比当前 R 新），实测功能正常。

本文所有性能数字来自本机单次运行，仅用于表达**量级差异**，不是严格 benchmark。

### 什么时候不必上 data.table

几千到几万行的表（多数 DESeq2 结果表、样本表、注释表）——
`data.frame` 或 `tibble` 就够。换成 data.table 只会增加一个引用语义的出错面，
**看不到速度收益**。规模没上到几十万行以上，不值得为它改写代码。

### 什么时候不必上 tibble

已经在写纯 base R 的脚本、或要传给只认 rownames 的老包（很多 Bioconductor 对象）时，
data.frame 更省事 —— 反正 rownames 迟早要转回去。

### 什么时候不必上 matrix

**如果你不做矩阵运算、也不喂 Bioconductor，就不必特地转 matrix。**
实测它在纯数值场景下相对 data.frame 只省约 1.3× 内存、`rowMeans` 只快 2 倍 ——
不是数量级差异，不值得为此承担 `as.matrix()` 的类型强制风险。
**唯一无可替代的场景是稀疏矩阵**：单细胞数据必须用 `dgCMatrix`，这里省的是几十 GB。

### 实务上的组合

典型 RNAseq 流程里各结构的位置：

| 阶段 | 用什么 | 理由 |
| :--- | :---: | :---: |
| 读 counts / 大表 | `data.table`（`fread`） | 快 4 倍 |
| 样本表 / 元数据 | `data.frame` 或 `tibble` | 小表，要可读性和严格性 |
| 喂给 DESeq2 / limma | **整数 `matrix`** + 带 rownames | 接口硬性要求 |
| DESeq2 结果 | `as.data.frame(results(dds))` | 基因名在 rownames，**别用 `as_tibble()`** |
| 大规模聚合 / pseudobulk | `data.table` 的 `[i,j,by]` | 几十万行以上快一个量级 |
| 单细胞 counts | **`dgCMatrix`** | 省 85%+ 内存 |
| QC 频数统计 | `table()` | 天然做列联表 |
| 出图 | 转成 long 格式 `data.frame`/`tibble` | 见下方说明，`table` 必须先转 |

### ggplot2 到底吃哪几种？（实测修正）

| 输入 | ggplot2 | 说明 |
| :--- | :---: | :---: |
| data.frame / data.table / tibble | ✅ | 原生支持 |
| **带 dimnames 的 matrix** | ✅ | 被 `fortify()` 自动转成 data.frame，列名取自 `colnames` |
| **无 dimnames 的 matrix** | ❌ | `fortify()` 报错 "must be a \<data.frame\>" —— 没有列名就没法建 aes |
| `table` | ❌ | 一律报错，必须先 `as.data.frame()` |

所以"matrix 不能出图"是**不准确**的 —— 有列名就能直接画。
但实务上仍建议**显式转换**：热图/箱线图几乎都要 long 格式，
`as.data.frame(m) |> rownames_to_column("gene") |> pivot_longer(-gene)` 一步到位，
比依赖隐式 `fortify()` 可控。
