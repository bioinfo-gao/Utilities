# conda — 同名 env 存在于两个不同前缀下，`conda run -n <name>` 解析失败

## 症状
`conda run -n DE_R45 Rscript xxx.R` 报错 `there is no package called 'ashr'`（或任何该 env 里
明明装了的包报"找不到"）。`conda run -n DE_R45 which Rscript` 返回的却是另一个环境（如
`regular_bioinfo`）的 Rscript 路径，不是 DE_R45 自己的。

## 根因
`conda env list` 显示同一个 env 名 `DE_R45` 同时存在于两个不同前缀下：
`/Work_bio/gao/configs/.conda/envs/DE_R45` 和 `/home/gao/.conda/envs/DE_R45`（大概率是历史上
在不同 conda 配置/`envs_dirs` 下各建过一次）。`conda run -n <name>` 按名字查找时在这种重名情况
下解析不可靠，观测到的实际后果是命令没有真正激活目标 env，而是落到了 PATH 里另一个先被找到
的环境（本例是 `regular_bioinfo`）——不报错、不警告，只是悄悄用错了解释器，直到脚本里某个该
env 特有的包（这里是 R 包 `ashr`）加载失败才暴露。

## 修复
不要用 `conda run -n <name>` 依赖名字解析；改用该 env 的**绝对路径可执行文件**直接调用，例如：
```bash
/Work_bio/gao/configs/.conda/envs/DE_R45/bin/Rscript script.R
```
项目脚本头部本来就习惯性注释了"运行环境: /path/to/envs/<name>/bin/Rscript"（见
`19_Lijian_Wu_Rell1_TNFa_Tumor/scripts/4_run_DE_PCA.R` 头部），这个约定不是装饰性的——遇到
env 名字疑似有歧义/报错找不到包时，直接照着这行注释的绝对路径跑，而不是想当然用 `conda run -n`。

## 检查是否中招
```bash
conda env list | awk '{print $1}' | sort | uniq -d   # 打印出所有重名的 env
```
若某个项目常用的 env 名出现在结果里，该项目所有 `conda run -n <name>` 调用都应审查是否改用绝对路径。

## 实测记录
- 2026-07-25，project 19 (`19_Lijian_Wu_Rell1_TNFa_Tumor`)：给已交付项目补第7个对比后重跑
  `4_run_DE_PCA.R`，用 `conda run -n DE_R45` 直接报 `Error in library(ashr)`；确认是上述重名
  冲突，改用绝对路径 Rscript 后立即恢复正常。详见 `project_19_lijian_wu_rell1_tnfa_tumor` memory。

参见 [[reference_conda_run_subprocess_pitfalls]]（同为 `conda run` 相关坑，但那篇讲的是子进程
隔离/管道问题，属不同根因，故未合并）。
