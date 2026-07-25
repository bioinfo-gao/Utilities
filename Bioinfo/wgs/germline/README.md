# bioinfo_technicals / wgs / germline

Germline WGS 结果**解读**的技术/教学参考(不是 pipeline 操作文档,pipeline 见各项目 `scripts/` 与 `/wgs` skill)。
每篇均以某个真实项目为 worked example,数字可回该项目复核。

| 文档 | 讲什么 | worked example |
| :--- | :--- | :---: |
| [HLA分型入门_结合本项目数据_0717.md](HLA分型入门_结合本项目数据_0717.md) | HLA 是什么/命名法/WGS 怎么分型/读懂 T1K 输出(quality 分层、单等位≠纯合、逗号候选串)/单倍型自洽 | proj16 |
| [CNV_scatter图解读回顾_结合本项目数据_0717.md](CNV_scatter图解读回顾_结合本项目数据_0717.md) | 读 CNVkit 全基因组 scatter 图:二倍体基线 vs 技术噪声(看橙点)、**从 chrX/chrY 一眼判性别** | proj16 |

> 相关但在别处:pipeline 提速/resume 缓存/看门狗监控的教训在 `facilities/Server/monitoring_alerting/` 与
> `facilities/Server/nextflow_pipeline/`;`/wgs` skill 收录了 germline+下游的实测教训(conda-run 坑、CRAM 参考 M5、
> queueSize 相位、cnvkit cn 列 bug 等)。
