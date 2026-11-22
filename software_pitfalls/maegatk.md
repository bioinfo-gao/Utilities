# maegatk 0.2.0（bioconda，p47_allele env）

实测：2026-11-22，P47 在 10x pbmc_1k_v3 的 chrM 上做功能测试。

## 1. 不加 `-so` ⇒ 失败但退出码 0（Ubuntu 上必踩）

- **症状**：日志里 `WorkflowError … configfile …/.internal/parseltongue/snake.scatter.yaml … not present or accessible`；`final/` 只有 `chrM_refAllele.txt`；**`maegatk` 进程退出码 0**。
- **根因**：`cli.py` 不加 `--snake-stdout` 时拼出 `snakemake … &>LOG`，交给 `os.system()`，后者用 `/bin/sh`。Ubuntu 的 `/bin/sh` 是 **dash**，把 `&>` 解析成"`&` 放后台" + "`>` 重定向" ⇒ snakemake 被丢到后台，Python 不等它、继续执行并**清理 `.internal/` 与 `temp/`**，snakemake 起来后找不到自己的 configfile。
- **修复**：**永远加 `-so`**（不必改包源码）。另外必须用 `mamba activate <env>` 后再跑——maegatk 内部调 PATH 上的 `python`，不激活会报 `No module named 'pysam'`。
- **判据**：**不能看退出码**，要断言 `final/` 下产物（`*.coverage.txt.gz` 等）存在且细胞数对得上。
- 排除过的假设：相对路径（改绝对路径照旧失败）、ruamel.yaml 新版移除旧 API（实测 0.16.12，旧 API 可用）。

## 2. 默认值（0.2.0 帮助实测，与网上旧说法不同）

| 参数 | 默认 | 注意 |
| :--- | :---: | :--- |
| `--min-reads` | **1** | 调研阶段检索到的"默认丢弃 <3 reads 的 UMI"与本版本不符 |
| `--NHmax` | 2 | 保留最多 2 处比对的 read ⇒ NUMT 区证据口径直接受影响 |
| `-q` / `-aq` | 0 / 0 | 碱基质量、比对质量默认都不过滤 |

## 3. 速度

4 核约 25 细胞/分钟（单细胞逐个 bwa 重比对到内置 rCRS）。1,200 细胞约 50 分钟。

## 4. ⚠ 在 10x 3′ 数据上，maegatk 的 depth 不是分子数（会把 n 算大）

- **实测**（pbmc_1k_v3 chrM，166 个网格位点）：maegatk depth 与按 (CB, UB) 计的分子数位点间 Spearman 0.994，但数值是后者的 **中位 1.53 倍、最高约 2.4 倍**，且与 secondary 比例无关（不是 NUMT）。
- **根因（位点 12850 实测）**：(CB, UB) = 11,933；**(CB, UB, read 起点) = 27,508 ≈ maegatk 27,450**。10x 3′ 文库同一分子的 read 起点各不相同，maegatk 按"UMI + 起点"分组 ⇒ 一个分子被拆成多个计数单位。
- **影响**：allele fraction 的置信区间若用 maegatk depth 当 n ⇒ n 偏大、区间偏窄、**结论显得过度确定**；位点间权重也会偏向打断更碎的转录本。
- **做法**：主计数用按 (CB, UB) 定义分子的实现（P47 `scripts/5_target_site_audit.py`）；maegatk 只做算法层面对照。脚本：`47_Liu_Yuan_scRNA/pipeline_validation_1122/mt_feasibility/check_molecule_definition.py`。
