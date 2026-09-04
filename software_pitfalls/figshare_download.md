# figshare 下载坑

## `figshare.com/ndownloader/files/<id>` 被 AWS WAF 挡住，**返回 0 字节且不报错**

2026-09-03 proj22（scRNA tutorial）实测。数据清单里写的是这个 URL 形式，脚本用 `urllib` 下载，
每个文件都拿到 **0 字节**，脚本判为"半截文件"重试三次后跳过 —— 表面看像网络不稳。

**真相**（`curl -I` 才看得见）：

```
HTTP/2 202
server: awselb/2.0
x-amzn-waf-action: challenge      <-- 关键
content-length: 0
```

**`202` + `content-length: 0`**，不是 4xx/5xx，所以 `urllib.urlopen()` **不抛异常**、
`resp.read()` 返回空 —— 静默拿到空文件。换浏览器 User-Agent 也没用（变成 `403` + 520 字节挑战页）。

## 修法：换主机名，不要用 `figshare.com/ndownloader`

figshare 的 API 自己给出的下载主机是 **`ndownloader.figshare.com`**，它不走同一套 WAF：

| URL 形式 | 实测结果 |
| :--- | :--- |
| `https://figshare.com/ndownloader/files/<id>` | ❌ `202` + WAF challenge + 0 字节 |
| `https://ndownloader.figshare.com/files/<id>` | ✅ `206`，真实数据 |
| `https://api.figshare.com/v2/file/download/<id>` | ✅ `206`，跳转签名 S3 链接 |

拿到某篇 article 全部文件的正确下载链接：

```bash
curl -sS "https://api.figshare.com/v2/articles/<article_id>/files"
# 返回 JSON，每项含 download_url / size / supplied_md5 / computed_md5
```

这个 API 端点还顺带给出**官方 md5**，可直接用于校验，比自己记录 size 更可靠。

## 判据

- 下载得到 **0 字节但没有异常** ⇒ 先 `curl -sS -I <url>` 看状态码与响应头，
  **不要**先怀疑网络或磁盘。
- 看到 `x-amzn-waf-action: challenge` ⇒ 反爬挑战，换 UA 通常无效，要换端点/主机。
- 相关：proj23 的 genomatics 源同样反爬（那个至今没绕过，别再试）。
