# Manta —— `python2` 不在 PATH 致 chromDepth 反复失败；默认会自动回避重复区

## 1. 症状：`getChromDepth_*_catChromDepth` 失败重试，workflow 不报明显错误

`runWorkflow.py` 日志里只有 `Task ... failed but qualifies for retry`，反复重试，没有 VCF。
真正的原因要看 `<runDir>/workspace/pyflow.data/logs/pyflow_tasks_stderr_log.txt`：

```
/usr/bin/env: 'python2': No such file or directory
```

**根因**：manta 环境（`/Work_bio/gao/configs/.conda/envs/manta`，py2.7）的 `libexec/cat.py` 等辅助脚本
shebang 是 `#!/usr/bin/env python2`，但本机 PATH 上没有 `python2`（环境里只有 `python`）。
`configManta.py` 自己用 `python configManta.py` 显式调用能跑，所以配置阶段不报错，到 workflow 才炸。

**修复**（不改系统、不装包）：符号链接垫片，只放进调用脚本的 PATH：
```bash
mkdir -p refs/py2shim && ln -sfn $MANTA_ENV/bin/python refs/py2shim/python2
export PATH="$PWD/refs/py2shim:$PATH"
$MANTA_ENV/bin/python $MANTA_ENV/bin/configManta.py ...   # 显式解释器
$MANTA_ENV/bin/python <runDir>/runWorkflow.py -m local -j 12 -g 48
```
实测（P41，2026-10-03）：加垫片后 2 个 10× BAM、121 kb 窗口 48 秒跑完。

## 2. 默认参数会“自动回避重复区”（需要保留重复区时必改）

`graphNodeMaxEdgeCount`（默认 10）：候选生成时，**两端节点的边数都高于该值的边直接跳过**
（`manta/share/CHANGELOG.md:148-149`；`lib/python/mantaWorkflow.py:518` 传给 `--max-edge-count`）。
高连通 = 重复/塌缩区，所以这是一种静默的重复区屏蔽，**没有任何日志提示**。
客户要求重复区 unmasked 时：用拷贝出的 ini（`--config`）改 `graphNodeMaxEdgeCount = 1000`，
必要时 `minScoredVariantSize` 50→20。全基因组运行保持默认，两者分开并在 Methods 写明。

## 3. 其他
- Manta 吃 CRAM 病态慢，先转 BAM（见 `sarek.md`）。
- 低深度（~10×）小窗口里 diploidSV / candidateSV 可以是 **0 条记录**，不代表命令有问题；
  也因此“BND 伙伴在 `--region` 下是否被报告”要用真数据确认，别用这类冒烟下结论。
