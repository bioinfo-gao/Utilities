# conda run 坑

## 子进程隔离导致的几类静默/半静默失败

`conda run -n ENV cmd` 在**独立子进程**里执行 `cmd`，不继承父 shell 的文件描述符。踩过四个坑
（1–3 来自 proj16 下游脚本 2026-07-17；4 来自 proj31 客户表单解析 2026-08-21）：

1. **进程替换 `<(...)` 失效**——
   ```
   conda run bcftools annotate -h <(echo '##INFO=...')
   ```
   报 `Failed to open /dev/fd/63: No such file or directory`。父 shell 建的 `/dev/fd/NN` 到不了
   conda-run 子进程。
   **改**：写真实临时文件：
   ```bash
   HDR=$(mktemp ...); echo ... > "$HDR"; trap 'rm -f "$HDR"' EXIT
   conda run ... -h "$HDR"
   ```

2. **跨两个 `conda run` 的管道 BrokenPipe**——
   ```
   conda run samtools collate -Ou X | conda run samtools fastq ...
   ```
   报 `BrokenPipeError [Errno 32]`，一端先死。
   **改**：中间落盘，别跨进程 pipe：
   ```bash
   conda run samtools collate -o coll.bam X
   conda run samtools fastq ... coll.bam
   ```

3. **命令替换在 `conda run bash -lc '...$(...)...'` 里被搅乱**——复杂的
   `$(dirname $(which x))` 加分号会报错。
   **改**：`source .../conda.sh; conda activate ENV` 之后在普通 shell 里跑，别把这种逻辑塞进
   conda-run 的 `bash -lc`。

4. **`conda run ... python - <<'EOF'` 读不到 stdin —— 退出码 0、零输出、零报错**（proj31，2026-08-21）——
   ```bash
   conda run -n ENV python - <<'PY'
   print("HELLO")
   PY
   # 实测：无任何输出，exit=0
   ```
   `conda run` **不把父 shell 的 stdin 转发给子进程**，`python -` 于是读到空输入，
   相当于执行了一个空程序，**正常退出**。这是本文件里最阴的一个：前三条至少还会报错，
   这一条**什么都不说**。若脚本的判据是"有没有输出可疑内容"，空输出会被读成
   **"检查通过 / 没发现问题"** —— proj31 就是这样差点把客户表单里的三个答案判成"客户没填"。
   **改**：把代码写成真实 `.py` 文件再 `conda run -n ENV python file.py`；
   或用 `python -c '...'`（`-c` 不依赖 stdin，实测正常）。
   **配套判据**：凡是"没有输出 = 没有问题"的检查，脚本必须**先打印一行自证还活着的摘要**
   （如 `print('scanned N cells')`），没有这行就说明脚本压根没跑，而不是没发现问题。

**通用规避**：一段需要 pipe / 进程替换 / 命令替换的逻辑，用**一次** `conda run -n ENV bash -c '整段'`
整体包起来，或者先 `conda activate` 再跑——不要对每条命令单独 `conda run`（每次都是新子进程，隔离
问题会反复出现）。

关联：[[reference_no_unverified_outcome_claims]]（同一事故里也出现了"没验证就写结论"的教训）。
