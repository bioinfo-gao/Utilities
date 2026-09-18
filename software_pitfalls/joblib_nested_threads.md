# joblib × OMP_NUM_THREADS —— 「线程上限」被子进程乘出来，load 冲到 100

**2026-09-17 proj22 5-2 章实测**：32 核 / 64 线程的机器，`load average 99.52`，
`top` 里 33 个 running task。查下来是 **28 个 loky worker，每个 28 线程 = 784**。

## 机制

设 `OMP_NUM_THREADS=28` 的本意是「单进程别超过 28」。但 joblib 起 N 个子进程时，
**每个子进程都继承这个值**，于是总线程 = `N × 28`。上限变成了乘数。

**最坑的一层**：joblib 本来有保护 —— 用 loky 后端时它会把 worker 的内层线程压到 1。
**但只在用户没有显式设 `OMP_NUM_THREADS` 时才这么做。** 我们为了"限流"设的那行，
恰好把这个保护关掉了。⇒ **好心设上限，结果比不设还糟。**

## 判据（不用猜，直接读 worker 的环境）

```bash
W=$(ps -eo pid,nlwp,cmd | grep loky | grep -v grep | awk '$2>1{print $1}' | head -1)
ps -o comm= -L -p $W | wc -l                      # 这个 worker 的 OS 线程数
tr '\0' '\n' < /proc/$W/environ | grep -E "OMP_|MKL_|OPENBLAS"
```
`nlwp` ≈ `OMP_NUM_THREADS` 且 worker 有好几十个 ⇒ 就是这个病。
**`load average` 远大于 `n_jobs` 是第一信号**（n_jobs=28 却 load≈100）。

## 修法

```python
from joblib import parallel_config
_cfg = parallel_config(backend="loky", inner_max_num_threads=1)
_cfg.__enter__()          # 进程级常开，故意不 __exit__
```

- **`backend=` 必须显式给**，否则 joblib 1.6 抛
  `ValueError: inner_max_num_threads and other constructor parameters are only supported when backend is not None`。
- 只改**默认**后端；库里显式写了 `backend="threading"` 的调用不受影响。
- 放在共用工具模块的 import 期，各章 `from ... import *` 时自动生效。

**实测（同一台机器，8 个 worker）**：

| 设置 | 每 worker 线程 | 合计 |
| :--- | :---: | :---: |
| 只设 `OMP_NUM_THREADS=28` | 28 | **224** |
| 加 `inner_max_num_threads=1` | 1 | **8** |

`n_jobs=28` 时同法实测合计 **28**（原先 784）。

## 一句话

**外层并发 × 内层线程才是真实占用。** 只报"我设了 n_jobs=28"是不够的 ——
`n_jobs` 是进程数，不是线程数。

*建档 2026-09-17，proj22 ch5-2。*
