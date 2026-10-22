---
name: ftp
description: "Use when 用户要给客户开 sFTP 上传/下载通道、查回 sFTP 端口/账号/密码、或确认穿透(bore)隧道是否还活着"
disable-model-invocation: true
---

# /ftp — sFTP 服务就绪 + 客户登录信息

一键确保本机给客户用的 sFTP 通道处于「已就绪」状态，并打印可直接转发给客户的登录信息。
用于：给客户开上传/下载通道、忘了端口/账号/密码时快速查回、确认穿透隧道还活着。

## 背景（本机既有部署，勿重建）

- **穿透方式**：`bore` 系统服务（`/etc/systemd/system/bore.service`，`ExecStart=/usr/local/bin/bore local 22 --to bore.pub`，已 `enable` 开机自启）。
  这比旧文档 `setup_sFTP.sh` 里的 `nohup` 方式更稳，**以 systemd 为准**。
- **SFTP 服务端**：本机 `sshd`，客户被 chroot 锁在 `/srv/external_data/client_sftp`，只能进 `/files` 上传，不能登 shell。
- **公网端口会变**：`bore local 22 --to bore.pub` 没有固定 `--port`，**每次 bore 重启都会随机换端口**。
  因此端口永远**实时**从 `journalctl -u bore | grep 'listening at'` 读，绝不硬编码（当前长期为 `38643`，因服务自 6/11 未重启）。
- **凭据**：账号/密码存在 `/home/gao/projects_2026H2/facilities/FTP/client_credentials.env`（600 权限，非交付内容）。

## 执行步骤（调用本 skill 时照做）

1. **运行就绪脚本**（它会：检查并按需拉起 sshd + bore → 读实时端口 → 读凭据 → 打印登录块）：
   ```bash
   /home/gao/projects_2026H2/facilities/FTP/ftp_ready.sh
   ```
2. **原样把「转发给客户的登录信息」块回给用户**，并明确当前服务状态（sshd / bore / 端口）。
3. **若脚本提示密码未填**（首次使用）：告诉用户去 `client_credentials.env` 把 `CLIENT_PASSWORD`
   改成真实 9 位密码（该文件仅本人可读），填完再调 `/FTP` 即可，以后就不会再忘。
   —— 不要自己编造密码；也不要用 `sudo passwd client_sftp` 重置密码（会让客户已保存的凭据失效），
   除非用户明确要求重置。
4. **若某个服务启动失败**（脚本打了 `❌ FAILED`）：按提示查 `systemctl status ssh` / `systemctl status bore`，
   常见故障对照旧文档 `facilities/FTP/setup_sFTP.sh` 第五阶段（Connection reset / Broken pipe=权限 / Permission denied=没进 /files）。

## 排错速查

| 现象 | 处理 |
|:---|:---:|
| 客户连不上、端口变了 | `journalctl -u bore \| grep 'listening at' \| tail -1` 看当前端口，把新端口发给客户 |
| bore 挂了 | `sudo systemctl restart bore`（会换端口！重启后务必重发端口给客户） |
| 想让端口不再变 | 改 `bore.service` 加 `--port <固定端口>`（bore.pub 端口空闲才行）；属系统改动，先跟用户确认 |
| 看客户有没有在连 | `journalctl -u bore -f`（实时看 new connection） |
| 客户上传到哪了 | `/srv/external_data/client_sftp/files/` |

## 设计思路 / 异地重建

为什么这么搭、有哪些替代穿透方案、以及在另一台无域名无固定 IP 的服务器上从零重建的完整步骤：
见 `facilities/FTP/sFTP_穿透方案_设计与重建指南.md`。
