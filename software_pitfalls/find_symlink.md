# `find` 默认不跟随符号链接 —— 扫描指向别处的项目目录时会**静默返回空**

**症状**：对一个**本身是符号链接**的目录跑 `find`，明明里面有东西，却**一条也不返回**，
**不报错、退出码 0**。看起来像"确实没有"，于是据此下了反向结论。

**实测（2026-08-29，整理磁盘时）**：
`/home/gao/projects_2026M7` 是符号链接 → `/mnt/ex_8T_SSD/projects_2026M7`。

```bash
find /home/gao/projects_2026M7 -type d -name work        # 空
find /home/gao/projects_2026M7 -name "*.sorted.bam"      # 空
find /home/gao/projects_2026M7 -name "*.fastq.gz"        # 空
```

**三次全空**，差点据此答复"没有可回收的东西"。而实际上：

| 实际存在 | 大小 |
| :--- | ---: |
| Nextflow `work/`（6 个项目） | **2.92 TiB** |
| 冗余 `*.sorted.bam`（markdup 已存在） | 25 GiB |

**根因**：`find` 的默认行为是 `-P`（不跟随符号链接）。命令行上给出的路径**本身**是符号链接时，
`find` 只对那个链接本身做匹配（一个 `l` 类型的项），**不会进入它指向的目录**。

## 修法（任选其一，推荐前两个）

```bash
find -L /home/gao/projects_2026M7 ...          # -L：跟随所有符号链接
find /home/gao/projects_2026M7/ ...            # 路径末尾加 /：等价于跟随这一层
find /mnt/ex_8T_SSD/projects_2026M7 ...        # 直接用真实路径（最稳）
realpath /home/gao/projects_2026M7             # 先解析再用
```

⚠ **`-L` 会跟随目录树内部的所有符号链接**，在有大量跨项目软链的树里可能重复遍历甚至成环
（本机 `projects_2026H2` 曾有 1387 条绝对软链）。**只想解决"入口是软链"这一个问题时，
优先用真实路径或末尾加 `/`。**

## 为什么危险：它的失败形态是【假阴性 + 零退出码】

- `du -sh <symlink>/*/` **会**正常给出结果（shell 展开 glob 时已跟随），
  所以 `du` 和 `find` 对同一个目录会给出**互相矛盾**的答案；
- `find` 返回空 + `exit 0`，与"真的没有匹配"**完全无法区分**；
- 用在 `while read` 管道里时更隐蔽 —— 循环体一次都不执行，看不出任何异常。

**⇒ 规矩：对任何可能是符号链接的入口做 `find` 之前，先 `ls -ld <path>` 或 `realpath` 确认；
或者养成对项目根一律用真实路径的习惯。**
**扫描结果为空时，先怀疑扫描本身，再下"不存在"的结论**
（与 [[feedback_falsify_vs_confirm_asymmetry]] 同一类：看不见 ≠ 不存在）。

**相关**：[awk.md](awk.md)（另一个"零报错 + 输出格式正常"的静默失败）·
[../Server/nextflow_pipeline/磁盘回收_三方案实证对比_projects_2026H1_0729.md](../Server/nextflow_pipeline/磁盘回收_三方案实证对比_projects_2026H1_0729.md)（work/ 回收）
