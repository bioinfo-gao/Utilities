# MAJIQ — 安装的六层根因链 + 3.x CLI 与 2.x 教程完全不同

## 安装（academic 版，pip from bitbucket）

六层报错，每层修一个，逐层显形（2026-09-09 实测，MAJIQ 3.0.23）：

| 层 | 报错 | 修法 |
| :--- | :--- | :---: |
| 1 | `Failed to build wheels for rna_majiq / rna_moccasin / rna_voila` | pip 的 build isolation 会自行装最新 Cython，绕过 env 里钉的 `cython<3` ⇒ 加 `--no-build-isolation` |
| 2 | `BackendUnavailable: Cannot import 'scikit_build_core.build'` | 关掉 isolation 后 PEP 517 后端需自己装 ⇒ `pip install scikit-build-core` |
| 3 | `ERROR: Use build.verbose instead of cmake.verbose for scikit-build-core >= 0.10` | 上游 `moccasin/pyproject.toml` 用了废弃键 ⇒ 钉 `scikit-build-core<0.10` |
| 4 | `ModuleNotFoundError: No module named 'setuptools_scm'` | 同层 2，构建期依赖逐个自备 ⇒ 装 `setuptools_scm` |
| 5 | `pybind11.h: static assertion failed` / `no matching function for call to pybind11::…` | MAJIQ 的 C++ 照 pybind11 **2.x** 写 ⇒ 钉 `pybind11<2.12` |
| 6 | 运行时 `A module compiled using NumPy 1.x cannot be run in NumPy 2.0.1` | pip 把运行时 numpy 升到 2.0.1，与编译期 1.26.4 不符 ⇒ `pip install "numpy<2"` 使两者一致（pip 会警告元数据冲突，可忽略——ABI 才是判据） |

**教训**：`--no-build-isolation` 意味着**每一个构建期依赖都要自己备齐**，且一次只报一个，
必须准备好逐层迭代；同时**不要把 pip 输出接 `tail -N`**，真正的报错行会被截掉
（P34 第一轮就因此丢了根因，白跑一轮）。

**license**：学术使用免费；实测 `--license` 是**可选**参数，不需要 license 文件。
商业实体使用需付费 license —— 这一条要在项目里明确谁来拍板。

## 3.x 的 CLI 与网上 2.x 教程完全不同

```
2.x:  majiq build <gff3> -c config.ini -o out
      majiq deltapsi -grp1 *.majiq -grp2 *.majiq -o out --names A B

3.x:  majiq build <gff3> <experiments.tsv> <output_dir>
      majiq psi-coverage <splicegraph> <psicov_out> <sj...>
      majiq deltapsi -psi1 ... -psi2 ... -n A B --splicegraph SG --output-tsv TSV
```

- 配置从 **`.ini` 改成 TSV**：必需列 `path`，可选列 `group`、`strandness`。
- 多了 `psi-coverage` 这一中间步，`deltapsi` 不再直接吃 `.majiq`。
- 子命令全集：`build / psi-coverage / moccasin / psi / deltapsi / heterogen / cite`。

**⇒ 照 2.x 教程写的脚本在 3.x 上一行都跑不通。动手前先 `majiq <sub> --help`。**

## 相关

- 首次踩坑：P34（2026-09-09）
