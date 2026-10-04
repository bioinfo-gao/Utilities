# IGV 无头自动截图 —— Xvfb 来源选错起不来；`-Djava.awt.headless` 不行

目标：在无显示器的服务器上用 `igv -b batch.txt` 批量 `snapshot`。

## 坑 1：bioconda 的 `xorg-x11-server-xvfb-cos7-x86_64` 起不来
装得上，二进制在 `.../x86_64-conda-linux-gnu/sysroot/usr/bin/Xvfb`（不在 `bin/`），运行报
`error while loading shared libraries: libcrypto.so.10`。系统只有 `libcrypto.so.3`，ABI 不兼容，别拿 symlink 硬凑。
**用 conda-forge 的 `xorg-xvfb-server`**（`mamba install -c conda-forge xorg-xvfb-server`，bin/ 里直接有 `Xvfb`）。
注意 conda-forge 上没有叫 `xorg-xvfb` 的包，名字是 `xorg-xvfb-server`。

## 坑 2：纯 headless 不行
`JAVA_TOOL_OPTIONS=-Djava.awt.headless=true` + 不设 DISPLAY → `java.awt.HeadlessException`，IGV 起不来。必须有（虚拟）X 显示。

## 可用配方（P41 实测，2026-10-03）
```bash
mamba create -n igv_snap -c conda-forge -c bioconda igv xorg-xvfb-server   # 独立 env，不碰分析 env
E=/Work_bio/gao/configs/.conda/envs/igv_snap
$E/bin/Xvfb :97 -screen 0 1800x1400x24 &  sleep 3
printf 'new\ngenome /path/ref.fa\nload x.bam\nsnapshotDirectory /out\ngoto chr11:114604000-114625500\nsnapshot a.png\nexit\n' > b.txt
DISPLAY=:97 $E/bin/igv -b b.txt
```
- `genome` 用本地 FASTA（不联网）；用 `genome hg38` 会去 S3 取注释，离线时日志有 `SEVERE ... FileNotFoundException`（截图仍出，但多余）。
- bioconda 的 igv 要 Java 21，自带；`-Xmx8g` 在 `~/.igv/java_arguments` 可调。
- 脚本末尾 `trap 'kill $XP' EXIT` 清理 Xvfb，避免会话泄漏。
- 退出码 0 ≠ 截图存在：脚本里数 `snapshot` 行数与 png 数是否相等。
