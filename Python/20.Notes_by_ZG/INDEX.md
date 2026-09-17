# 20.Notes_by_ZG —— Python / R 笔记索引

> 建立日期：2026-09-17
> 用途：放我自己写的长篇笔记（概念、生态、选型、踩坑的**成因分析**）。
> 与其它目录的分工：
> - **具体软件的坑** → `/home/gao/Utilities/software_pitfalls/`（一个软件一份，查症状用）
> - **可运行的示例** → `/home/gao/Utilities/Python/10.Plotting/` 等目录的 `.ipynb`
> - **本目录** → 讲"为什么"的长文，读一遍建立心智模型

## 该读哪一篇

| 我的处境 | 读这篇 |
| :--- | :---: |
| 想知道 Python 生信栈里哪个包管什么 | **①** |
| 手上有 R 代码要搬到 Python | **②** |
| 新任务要决定用 R 还是 Python | **③** |
| 手上有 Python 代码要搬到 R，或要读懂别人的 R | **④** |

## 笔记

| # | 笔记 | 主题 | 日期 |
| :--- | :--- | :--- | :---: |
| ① | [Python_core_modules_for_bioinformatics.md](Python_core_modules_for_bioinformatics.md) | 生信里的 Python 通用与核心模块：依赖分层、numpy↔scipy↔statsmodels 的职责边界、matplotlib/seaborn/plotly 的关系、14 条静默陷阱、本机两环境模块矩阵 | 2026-09-17 |
| ② | [R_to_Python_stats_and_plotting.md](R_to_Python_stats_and_plotting.md) | **R → Python**（有方向）：统计函数与作图的逐条双语实测对照。头号陷阱是 `t.test` 默认 Welch 而 `ttest_ind` 默认 Student；另有 pandas 静默丢 NA、矩阵填充顺序、负号索引、ggplot2→plotnine/seaborn 三条路 | 2026-09-17 |
| ③ | [R_vs_Python_neutral_comparison.md](R_vs_Python_neutral_comparison.md) | **中立选型**：5,000,000 行实测基准（结论是"语言间差距 < 语言内选错工具的差距"）、生态与可复现性对比、两边各自的痛点、按任务的决策表、双语共存的文件桥方案 | 2026-09-17 |
| ④ | [Python_to_R_migration.md](Python_to_R_migration.md) | **Python → R**（有方向）：R 的危险不在语法而在"不替你检查"。头号陷阱是向量循环补齐（numpy 报错 / R 静默）、`as.numeric(factor)` 返回编码、`1:0`；含 pandas→data.table 对照与上手路径 | 2026-09-17 |

> ②④ 不是镜像关系：**R→Python 的坑集中在"默认参数不同"，Python→R 的坑集中在"Python 替你做的检查 R 不做"。**

## 全篇共用的两条实测结论

| 结论 | 出处 |
| :--- | :---: |
| 本机 `conda run -n <env>` 会被 PATH 注入绕过（`-n` 与 `-p` 都失效且不报错）⇒ 探测一律用绝对解释器路径 | ① §8.1 |
| 单细胞跨语言：AnnData 是**细胞 × 基因**，Seurat / SingleCellExperiment 是**基因 × 细胞**，转置后零报错但结论全错 | ① §6.1 · ③ §6.2 · ④ §6.2 |

## 相关但不在本目录的姊妹篇

| 文档 | 路径 |
| :--- | :---: |
| **机器学习 / 深度学习 / LLM 三篇**（2026-09-17 新建） | `/home/gao/Utilities/Python/30.ML_and_AI/INDEX.md` |
| Python 表格类数据结构全景（8 种） | `/home/gao/Utilities/Python/Python_tabular_data_structures.md` |
| R 表格类数据结构全景（5 种） | `/home/gao/Utilities/R/R_tabular_data_structures.md` |
| 软件坑索引 | `/home/gao/Utilities/software_pitfalls/INDEX.md` |
