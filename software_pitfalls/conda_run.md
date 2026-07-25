# conda run 坑

## 子进程隔离导致的两类静默/半静默失败

`conda run -n ENV cmd` 在**独立子进程**里执行 `cmd`，不继承父 shell 的文件描述符。踩过三个坑
（proj16 下游脚本，2026-07-17）：

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

**通用规避**：一段需要 pipe / 进程替换 / 命令替换的逻辑，用**一次** `conda run -n ENV bash -c '整段'`
整体包起来，或者先 `conda activate` 再跑——不要对每条命令单独 `conda run`（每次都是新子进程，隔离
问题会反复出现）。

关联：[[reference_no_unverified_outcome_claims]]（同一事故里也出现了"没验证就写结论"的教训）。
