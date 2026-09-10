# LeafCutter — 安装路线选错会白烧五轮编译

## 症状

按"从 GitHub 源码装 R 包 `davidaknowles/leafcutter`"这条路走，会连撞五层编译问题：

| 层 | 报错 | 根因 |
| :--- | :--- | :---: |
| 1 | `StanHeaders` / `rstantools` / `rstan` 源码编译全部非零退出 | R 从源码编译 Stan 系列极易失败 |
| 2 | `dependencies 'DirichletMultinomial','TailRank' are not available` | 两个包不在已装集合 |
| 3 | TailRank 装不上（依赖 `oompaBase`/`oompaData`） | 这两个**不在 CRAN**（`available.packages()` 可证），OOMPA 自建仓库不可达 |
| 4 | `fatal error: tbb/tbb_stddef.h: No such file or directory` | 头文件其实在 `RcppParallel/include/tbb/` 下；是 leafcutter 老版 `src/Makevars` 缺 RcppParallel include 路径、且 `CXX_STD=CXX14`（StanHeaders 2.32 要 C++17） |
| 5 | `stanExports_bb_glm.o` 仍编译失败 | — |

## 根因不在第 5 层，在第 0 层

**bioconda 有维护版本：`leafcutter 2.0.3`（noarch，纯 Python，pyro-ppl/pytorch 后端）。**

```bash
mamba install -c bioconda -c conda-forge leafcutter
# 得到：leafcutter-cluster / leafcutter-ds / leafcutter-gtf-to-exons
#       leafcutter-bayes / leafcutter-prepare-phenotype
# 不需要编译任何 Stan 模型
```

⇒ **"某个源上没有这个包"是一条一行命令（`mamba search`）就能证伪的事实断言。**
凭印象把它写进计划文档，会据此设计出整条错误的实现路线。

## 用 leafcutter-ds 时的两个必踩点

1. **`-i` 参数的语义与文档不符。** 文档说 `min_samples_per_intron` 是"内含子至少被 n 个样本使用"，
   但 `leafcutter_ds.py:114` 实际拿它跟**每组样本数**比：
   ```python
   num_groups_w_enough_samples_1 = (meta["group"].value_counts() >= args.min_samples_per_intron).sum()
   if num_groups_w_enough_samples_1 < 2: raise ValueError("There are no groups with enough samples to test.")
   ```
   默认值是 **5**，所以任何**每组 < 5 个样本**的项目（n=3 是常态）都会直接抛错。
   ⇒ 必须显式传 `-i = -g = min(n1, n2)`。

2. **p 值校准只做到 n=4。** 工具自己的报错原文：
   "we have only carefully checked the calibration of leafcutter p-values down to n=4 samples per group."
   ⇒ n=3（常见）与 n=2（ENCODE 类公共数据）**都在官方校准范围之外**，
   其 p 值只能作相对排序，不得当作已校准 FDR 引用。

## 相关

- 首次踩坑：P34（exon-based splicing 管线开发，2026-09-09）
- LeafCutter 在方法学中的定位见 `~/Utilities/Bioinfo/splicing/splicing_bioinformatics_review_20260905.md` §4.3、§10.3（"副尺"）
