# DELLY —— v2 把 `call` 改名成 `sr`，旧命令只回一行错误、极易被吞掉

**症状**：脚本里写 `delly call -g ref.fa -o out.bcf in.bam`，日志里只有一行

```
Unrecognized command call
```

进程以非零码退出，**不产出任何 BCF**。若调用处写的是
`... || echo "delly 非零退出，见 log"`，编排脚本会**照常继续、照常写完成标记**，
整条链显示 "Step 7 OK" —— 而这一路证据其实全军覆没。

**实测**：DELLY v2.3.0（P29，2026-08-13，4 个样本全灭，零 BCF，日志各 26 字节）。

**根因**：DELLY v2 重排了子命令。

| 用途 | v0.8 及更早 | **v2.x** |
| :--- | :--- | :--- |
| 短读 SV discovery + genotype | `delly call` | **`delly sr`** |
| 长读 SV discovery | — | `delly lr` |
| CNV | `delly cnv` | `delly cnv` |

`delly --version` / 裸跑 `delly` 会列出当前版本支持的子命令，改脚本前先看一眼。

**修复**：
```bash
delly sr -g "$REF" -o "$OUT/${s}.delly.bcf" "$bam" > "$OUT/${s}.delly.log" 2>&1 \
    || { echo "⛔ [$s] delly sr 非零退出"; exit 1; }
[ -s "$OUT/${s}.delly.bcf" ] || { echo "⛔ [$s] 退出码 0 但 BCF 缺失/为空"; exit 1; }
```

**比版本改名更重要的教训 —— 软失败静默**：
这个坑之所以能一路走到"Step 7 OK"，不是因为改名难查，而是因为
**失败处理写成了 `|| echo`**。规矩两条：
1. 关键步骤失败必须**硬退出**，不允许只打印一句就继续。
2. **退出码 0 ≠ 产物存在** —— 每个关键产物都要一条存在性/非空断言，
   而且编排层还要有一条"产物数 == 样本数"的收尾断言，否则少跑一个样本同样静默通过。

**相关**：[[feedback_watchdog_scope_downstream_blindspot]]（下游编排链软失败静默）、
[[feedback_no_unverified_outcome_claims]]
