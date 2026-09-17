# 20.Notes_by_ZG —— Python 笔记索引

> 建立日期：2026-09-17
> 用途：这个目录放我自己写的 Python 笔记（概念、生态、选型、踩坑的**成因分析**）。
> 与其它目录的分工：
> - **具体软件的坑** → `/home/gao/Utilities/software_pitfalls/`（一个软件一份，查症状用）
> - **可运行的示例** → `/home/gao/Utilities/Python/10.Plotting/` 等目录的 `.ipynb`
> - **本目录** → 讲"为什么"的长文，读一遍建立心智模型

| 笔记 | 主题 | 日期 |
| :--- | :---: | :---: |
| [Python_core_modules_for_bioinformatics.md](Python_core_modules_for_bioinformatics.md) | 生信里的 Python 通用与核心模块：依赖分层、numpy↔scipy↔statsmodels 的职责边界、matplotlib/seaborn/plotly 的关系、14 条静默陷阱、本机两环境模块矩阵 | 2026-09-17 |
| [R_to_Python_stats_and_plotting.md](R_to_Python_stats_and_plotting.md) | **以 R 为参照系**：统计函数与作图方法的逐条双语实测对照。头号陷阱是 `t.test` 默认 Welch 而 `ttest_ind` 默认 Student；另有 pandas 静默丢 NA、矩阵填充顺序、负号索引、ggplot2→plotnine/seaborn 三条路 | 2026-09-17 |

## 相关但不在本目录的姊妹篇

| 文档 | 路径 |
| :--- | :---: |
| Python 表格类数据结构全景（8 种） | `/home/gao/Utilities/Python/Python_tabular_data_structures.md` |
| R 表格类数据结构全景（5 种） | `/home/gao/Utilities/R/R_tabular_data_structures.md` |
| 软件坑索引 | `/home/gao/Utilities/software_pitfalls/INDEX.md` |
