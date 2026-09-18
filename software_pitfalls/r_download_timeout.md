# R 的 `options(timeout)` 与 `download.file` 不续传

> 2026-09-17 proj23 实测：两个参考图谱（411 MiB / 473 MiB）**全部下载失败**，
> 而脚本用 `tryCatch` 包着，失败信息混在正常日志里差点被忽略。

---

## §1 默认 60 秒是按「下一个小文本文件」设的

`options("timeout")` 默认 **60**，且它是**整个下载的总时长上限**，不是连接超时。
任何 100 MiB 以上的文件在普通线路上都必然超时：

```
Warning: downloaded length 292257515 != reported length 431292041
Warning: URL '...': Timeout of 60 seconds was reached
Error in download.file(...) : download from '...' failed
```

**`download.file()` 不续传** ⇒ 超时即整包作废，自动重试也从 0 开始，于是**永远下不完**
（实测同一文件三次分别断在 278 MiB / 36 MiB / 38 MiB）。

## §2 谁会在你不知情时调 `download.file`

这类包**在内部**调它，报错信息看起来完全不像"超时"：

| 包 / 函数 | 表面症状 |
| :--- | :--- |
| `SeuratData::InstallData()`（Azimuth 参考） | `there is no package called 'bonemarrowref.SeuratData'` |
| `ProjecTILs::load.reference.map()` / `get.reference.maps()` | `File ... did not pass integrity check!!` |
| `celldex` / `ExperimentHub` 首次取参考 | 取回半截缓存 |

**注意第一行**：超时的真实后果被包装成"没有这个包"，
照着这句去查会走到"是不是仓库没有这个包"的错误方向上。

## §3 修法

```r
options(timeout = 3600)   # 放在 utils / 每个会下载的脚本顶部
```

- 各章统一 `source()` 一份工具文件的项目，**写在工具文件里一次覆盖全部**；
- **不 source 工具文件的脚本（如 bash 里内联的 `Rscript -e`）要各自再写一遍** —— 这是最容易漏的地方。

**手工补救用 `curl -C -` 续传**，不要循环重试 `download.file`：

```bash
curl -fL --retry 5 --retry-all-errors --continue-at - \
     --connect-timeout 30 --speed-time 120 --speed-limit 1024 -o out.tar.gz "$URL"
# 校验：体积要精确匹配，再 gzip -t
[[ "$(stat -c%s out.tar.gz)" == "$EXPECTED" ]] && gzip -t out.tar.gz
# R 包则本地装：install.packages("out.tar.gz", repos = NULL, type = "source")
```

## §4 判据

- 报"没有这个包 / 校验失败"时，**先翻上面几行有没有 `downloaded length ... != reported length`**；
- `getOption("timeout")` 是不是还是 60；
- 磁盘上有没有一个体积明显小于声明值的残留文件。

## 相关

- [figshare_download.md](figshare_download.md) — figshare 的 WAF 会给出 0 字节且不报错（另一种"下载成功但没内容"）
