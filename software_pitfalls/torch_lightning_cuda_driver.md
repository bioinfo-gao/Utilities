# torch × Lightning × 本机驱动 —— 选了 CPU 照样被拖去初始化 CUDA

## 症状：`accelerator="cpu"` 却报驱动太老

```
RuntimeError: The NVIDIA driver on your system is too old (found version 12020).
---> model.train(max_epochs=100, early_stopping=True, accelerator="cpu", ...)
```

2026-09-17 proj22 2-5 章 scVI 训练实测（`sc_tut_main`）。
`found version 12020` 指的是**驱动所支持的 CUDA 版本 12.2**，不是驱动版本号。

## 根因：崩在"收 RNG 状态"，那段代码不看 accelerator

`lightning/fabric/utilities/seed.py:146`：

```python
states["torch.cuda"] = torch.cuda.get_rng_state_all() if torch.cuda.is_available() else []
```

调用链：`model.train()` → `Trainer.fit()` → `_run_stage()` → **`isolate_rng()`**
→ `_collect_rng_states()` → `torch.cuda.get_rng_state_all()` → `_lazy_init()` → `torch._C._cuda_init()` → 炸。

**枢纽是 `is_available()` 为什么会返回 True**（实测）：

| 时点 | `PYTORCH_NVML_BASED_CUDA_CHECK` | `torch.cuda.is_available()` |
| :--- | :---: | :---: |
| 只 `import torch` | 未设置 | **False**（走 `_cuda_getDeviceCount()`，仅 stderr 一行 UserWarning） |
| `import lightning` 之后 | **`1`** | **True**（改走 NVML，NVML 能正常枚举这块卡） |

**`import lightning` 会主动设这个环境变量**（为避免 fork 场景下的 CUDA 初始化问题）。
在"驱动能用、但 torch 构建的 CUDA 版本过高"的机器上，这一改把**正确的 False 变成错误的 True**。

本机错配：GTX 1060 3 GB / 驱动 **535.309.01（≈CUDA 12.2）** vs torch **2.14.0+cu130（为 CUDA 13.0 编译）**。

## 修法：从进程层面屏蔽显卡，别重装 torch

```python
import os
os.environ.setdefault("CUDA_VISIBLE_DEVICES", "")   # 放在任何库 import 之前最稳
```

- **在 torch/scvi 已经 import 之后再设也有效**（只要 CUDA 尚未真正初始化）——
  活着的 Jupyter kernel 不必重启，插一行再重跑那一格即可；
- 用 `setdefault` 以尊重 `export CUDA_VISIBLE_DEVICES=0` 这种显式覆盖；
- 项目里有"全局不用 GPU"的策略变量时，**要把策略落成进程事实**（环境变量），
  否则它只是个给各章读的布尔量，**拦不住任何第三方库自己去初始化 CUDA**。

治本改法是换匹配驱动的 torch 构建（cu126），但要动依赖；本机 3 GB 显存本来也跑不动
scVI/cell2location，所以 proj22 只挡误初始化，不追求能用 GPU。

## 判据

- **`accelerator="cpu"` / `device="cpu"` 只约束"算在哪"，不约束"要不要探测 GPU"** ——
  RNG 状态收集、`pin_memory`、混合精度探测都可能绕过它去碰 CUDA；
- **看完整 traceback 的最后几帧**，别只看自己那一行；本例关键帧在 lightning 里，
  盯着 `model.train(...)` 永远查不出来；
- **`torch.cuda.is_available()` 在不同进程里可以给出不同答案**，取决于有没有库设过
  `PYTORCH_NVML_BASED_CUDA_CHECK`；裸 torch 里测得 False **不能**推断 scvi 进程里也是 False；
- 驱动/构建错配最省事的解法是 `CUDA_VISIBLE_DEVICES=""`，不是重装 torch。

## 详细排查链

`~/projects_2026M7/22_python_based_scRNA_tutorial/docs/P22_run_and_troubleshooting_log_0903.md` 事件 #9。
