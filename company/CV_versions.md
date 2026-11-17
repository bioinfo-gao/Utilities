# 简历版本索引

> 每次针对某个职位改简历：**新建版本，旧版本一律不动、不覆盖、不删除**。
> 规则和流程见 `job-application` skill（`Utilities/AI_and_Agent/Agent_Assets/skills/job-application/SKILL.md`）。
> 事实母版：`company/CV_master.json`；生成器：`company/cv_tools/build_cv.js`；每个职位一份 `cv_version_<公司>_<职位号>.json`。
> 定稿 PDF 放在 `company/CV/`（用户自己整理的存放处）。

| 日期 | 版本文件 | 针对职位 | 基于哪一版 | 主要改动 |
| :--- | :---: | :---: | :---: | :---: |
| 2026-02-15 | `CV/CV_Zhen Gao_Bioinformatics-Data Science-AI.pdf` | 通用版（用户自己写的原版） | — | — |
| 2026-11-17 | `BMS/CV_Zhen_Gao_BMS_R1608433_20261117.{docx,pdf}`（v1） | BMS Principal Scientist, Translational AI Foundations (R1608433) | 原版 | 新增 Summary 和 Core Expertise（单细胞/spatial 优先）；Athenomics 6 条；各段经历补充要点；发表分成 Selected 6 篇 + Additional 20 篇；删掉 1 条重复，改 1 处拼写 |
| 2026-11-17 | `BMS/CV_Zhen_Gao_BMS_R1608433_20261117_v2.{docx,pdf}` | 同上 | v1 | Summary 从一大段改成 4 条要点 |
| 2026-11-17 | v3：`BMS/CV_Zhen_Gao_BMS_R1608433_20261117_v3.docx` + **`CV/CV_Zhen_Gao_BMS_R1608433_20261117.pdf`** | 同上 | v2 | 审稿期刊改成两栏。**当前有效版**。⚠ 用户 2026-11-17 把 v3 的 PDF 移到 `CV/` 并去掉了 `_v3` 后缀，所以它和 `BMS/` 里的 v1 PDF 同名但内容不同：**以 `CV/` 里的为准** |

**v3 已可从母版重新生成**：`company/BMS/cv_version_BMS_R1608433.json` + `CV_master.json` 经 `cv_tools/build_cv.js` 生成的 PDF，
与 `CV/` 里的 v3 PDF 用 `pdftotext -layout` 比对**逐字相同**（2026-11-17 实测）。旧的 `BMS/cv_build_scripts/` 是 v1–v3 当初的生成脚本，作为历史保留。

## 新做一版的步骤

1. 复制最接近的一份 `cv_version_*.json` 到新公司目录，修改 headline、summary、core expertise 和条目选择。新事实先写进 `CV_master.json`。
2. `NODE_PATH=<装了 docx@9 的 node_modules> node company/cv_tools/build_cv.js company/CV_master.json <版本配置> <out>.docx`，
   再 `soffice --headless --convert-to pdf`，逐页看一遍。
3. 在本表加一行。

## 待用户确认的信息

见 `CV_master.json` 的 `pending_questions`（唯一的清单）。
