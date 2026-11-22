# scDblFinder 1.24.10 × xgboost ≥ 3.4：xgboost 训练报错被静默吞掉

实测：2026-11-22，P47（`p47_r` vs `sc_tut_r` 同一脚本对比）。

- **症状**：没有任何 warning/message；scDblFinder 照常输出分数和判定，阳性对照 recall 看起来还"更好"。
- **根因**：`.xgbtrain()` 调 `xgboost(..., early_stopping_rounds = 2)` 而不给评估集；xgboost 3.4 起报
  `'early_stopping_rounds' requires passing 'eval_set'`。`.scDblscore()` 第 86–91 行用
  `tryCatch({...}, error = function(e) d$score)` 包住训练 ⇒ **报错被吞，分数退回训练前的初始分数**。
- **为什么难发现**：回退分数本身也有区分力（玩具数据上 recall 甚至高于真 xgboost 分数），所以**看阳性对照的
  recall/AUPRC 分辨不出**——我据此一度建议用 3.4.2，是错的。
- **判据**：直接调内部函数看是否报错：
  `scDblFinder:::.xgbtrain(X, y, nrounds = NULL, max_depth = 4)`；脚本见
  `47_Liu_Yuan_scRNA/docs/P47_scRNAseq_best_practices_evidence_1104/check7_scdblfinder_xgbtrain_direct.R`。
- **修复**：conda 环境钉 `r-xgboost<3.4`（实测 3.3.1.1 训练正常）。上游 devel 1.27.9 记录了修复，但在 R 4.5 上与
  celda 装不进同一 env。
- **已知中招环境**：`/mnt/ex_8T_SSD/conda_envs/sc_tut_r`（xgboost 3.4.2.1）。
