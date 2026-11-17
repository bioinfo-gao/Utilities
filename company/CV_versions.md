# 简历版本索引

> 每次针对某个职位改简历：**新建版本，旧版本一律不动、不覆盖、不删除**。
> 文件名：`CV_Zhen_Gao_<公司>_<职位编号>_<YYYYMMDD>.{docx,pdf}`，放在 `company/<公司>/`。
> docx 是可编辑的母版，pdf 用来投递。生成脚本放在同目录的 `cv_build_scripts/`。

| 日期 | 版本文件 | 针对职位 | 基于哪一版 | 主要改动 |
| :--- | :---: | :---: | :---: | :---: |
| 2026-02-15 | `BMS/CV_Zhen Gao_Bioinformatics-Data Science-AI.pdf` | 通用版（用户自己写的原版） | — | — |
| 2026-11-17 | `BMS/CV_Zhen_Gao_BMS_R1608433_20261117.{docx,pdf}` | BMS Principal Scientist, Translational AI Foundations (R1608433) | 2026-02-15 原版 | 新增 Summary 和 Core Expertise（单细胞/spatial 优先）；Athenomics 6 条；各段经历补充要点；发表分成 Selected 6 篇 + Additional 20 篇；删掉 1 条重复，改 1 处拼写 |
| 2026-11-17 | `BMS/CV_Zhen_Gao_BMS_R1608433_20261117_v2.{docx,pdf}` | 同上 | 20261117 版 | Summary 从一大段改成 4 条要点（用户反馈：一大段读起来累）；其余不变。**这是当前有效版** |

## 新做一版的步骤

1. 复制最接近的那一版的 `cv_build_scripts/`（`build_cv.js` 存内容和版式，`pubs.json` 存发表列表）到新公司目录。
2. 修改内容，运行 `node build_cv.js <输出名>.docx`，再用 `soffice --headless --convert-to pdf` 转成 PDF。
   需要 `docx` npm 包：在构建目录里运行 `npm install docx@9`。
3. 在本表加一行。

## 原版里待用户确认的信息（下一版之前先问）

- 用过的 spatial 平台（目前只写了 Visium）；neighborhood / ligand-receptor 分析、深度学习分割、SpatialData 是否用过
- iScience 2025 那篇是否已正式发表；LBH 那篇（Submitted to Cancer Cell, 2021）的现状
- Briefings in Bioinformatics 页码疑似应为 20(6):2224-2235
