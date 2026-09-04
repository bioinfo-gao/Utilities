# Python 两个安静的 I/O 坑

## 1. stdout 经管道变块缓冲 ⇒ 日志与终端**全空**，看不出死活

```bash
python script.py 2>&1 | tee run.log       # ❌ 输出攒在缓冲区，log 长时间是空的
```

Python 检测到 stdout 不是 tty 时切成**块缓冲**（约 4–8 KB 才 flush）。后果：

- `tail -f run.log` 空白，`tmux capture-pane` 也空白；
- 进程明明活着（`ps` 有、CPU 有），却**完全无法判断在干活还是卡住**；
- 排查者容易转去怀疑网络/磁盘/权限，方向全错。

**修法**：加 `-u`（或 `PYTHONUNBUFFERED=1`）。

```bash
python -u script.py 2>&1 | tee run.log    # ✅ 逐行落盘
```

**凡是 `python ... | tee` 或重定向到日志的长任务，一律加 `-u`。**
2026-09-03 proj22 下载脚本因此白跑一轮：日志空、面板空，误以为脚本没启动。
（同一个坑在 pysam 那条里也出现过 —— 见 [pysam.md](pysam.md)。）

## 2. `pathlib.read_text()` / `write_text()` 会**规范化行尾符**，夹带无关 diff

```python
p.write_text(p.read_text().replace(OLD, NEW))   # ❌ CRLF 文件会被整体改成 LF
```

2026-09-03 proj22 实测：一个 **23 行全 CRLF** 的 CSV，只替换 14 处字符串，
`git diff --stat` 却显示 **23 insertions / 23 deletions** —— 多出的 9 行内容一字未改，
差异全在行尾符。若不追问"14 处替换为什么产生 23 行 diff"，
这个无关变更就混进提交了（违反最小修改原则）。

**修法**：改二进制，不碰编码与行尾符。

```python
b = p.read_bytes()
assert b.count(OLD) == N, "命中数与预期不符"   # 顺带防替换范围失控
p.write_bytes(b.replace(OLD, NEW))
```

**判据：替换 N 处就应该只有 N 行 diff。对不上先查行尾符，别急着提交。**
`file <path>` 或 `grep -c $'\r' <path>` 可确认原文件是不是 CRLF。
