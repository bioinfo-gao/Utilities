---
name: ftp
description: "Use when 用户要给客户开 sFTP 上传/下载通道、查回 sFTP 端口/账号/密码、或确认穿透(bore)隧道是否还活着"
disable-model-invocation: true
---

# /ftp — sFTP 服务就绪 + 客户登录信息

一键确保本机给客户用的 sFTP 通道处于「已就绪」状态，并打印可直接转发给客户的登录信息。
用于：给客户开上传/下载通道、忘了端口/账号/密码时快速查回、确认穿透隧道还活着。

## 背景（本机既有部署，勿重建）

- **穿透方式**：`bore` 系统服务（`/etc/systemd/system/bore.service`，`ExecStart=/usr/local/bin/bore local 22 --to bore.pub --port 47222`，已 `enable` 开机自启）。
  这比旧文档 `setup_sFTP.sh` 里的 `nohup` 方式更稳，**以 systemd 为准**。
- **SFTP 服务端**：本机 `sshd`，客户被 chroot 锁在 `/srv/external_data/client_sftp`，只能进 `/files` 上传，不能登 shell。
- **公网端口已固定 = `47222`**（2026-10-08 21:54 EDT 起；用户执行 sudo 修改，已核对
  `/etc/systemd/system/bore.service` 的 `ExecStart=/usr/local/bin/bore local 22 --to bore.pub --port 47222`，
  日志 `listening at bore.pub:47222`，`ssh -4 -p 47222` 握手成功）。**给客户的端口直接用 47222**，不用再每次追着发新端口。
  仍要**实时核对**：`journalctl -u bore | grep 'listening at' | tail -1` 应为 `47222`；不是就说明固定失效，见下条风险。
- **固定端口的风险**：47222 是公共中继 bore.pub 上的一个**空闲端口，不是保留给我们的**。bore 断线重连时若被别人占用，
  会报 `port already in use` 并启动失败，systemd 反复重试，期间隧道不通。出现时换一个空闲端口（现测：
  `timeout 6 /usr/local/bin/bore local 22 --to bore.pub --port N`，`30022`、`52022` 当时已被占用），改 `bore.service`，并**重新告知客户**。
- **历史（固定之前，EDT）**：`38643`（6/11 起，已作废）→ `8163`（10-06 21:37，用户手动重启）→ `24279`（10-07 09:53，自动）
  → `21945`（10-08 17:54，自动）→ `51542`（10-08 20:57，自动）→ `47222`（10-08 21:54，固定）。
  **根因**：bore 进程会无故**干净退出（退出码 0）**，systemd `Restart=always` 立即拉起，bore.pub 随机重新分配端口；
  不止机器重启才换，间隔从约 12 小时缩到约 3 小时。日志标志：
  `bore.service: Deactivated successfully` + `Scheduled restart job, restart counter is at N`。
  **没有固定端口的部署（新机器/重建）会重蹈覆辙 —— 一开始就加 `--port`。**
- **⚠ bore 会"静默失效"**（2026-10-06 实测）：`systemctl is-active bore` 显示 `active`，但日志停在 6/13，
  公网 `bore.pub:38643` 实际已 `Connection refused`，客户报 "Connection refused"。**`active` ≠ 隧道通**。
  判据：`ssh -4 -p <端口> -o BatchMode=yes client_sftp@bore.pub true` 应返回 `Permission denied (publickey,password)`
  （握手通、认证被拒 = 隧道正常）；返回 `Connection refused` = 隧道已死，`sudo systemctl restart bore` 后重读端口。
  （`bore.pub` 对本机只解析出 IPv6 时 bash `/dev/tcp` 会报 Network is unreachable，用 `ssh -4` 探测。）
- **给客户发数据 = bind mount，不要拷贝**：`files/` 下每个客户一个子目录，用 **只读 bind mount** 指向真实数据目录，
  **0 字节拷贝、不占盘、客户改不了原始数据**。symlink 在 chroot 里指不出去，**不可用**。
  `/home/gao/Dropbox` 是指向 `/Work_bio/dropbox/Dropbox_Data` 的符号链接，**bind 源必须写真实路径**。
  ```bash
  # <客户目录名> 例 Wei_Qi；需要 sudo（agent 没有 sudo，由用户执行）
  sudo install -d -o gao -g sftp_users -m 755 /srv/external_data/client_sftp/files/<客户目录名>
  sudo mount --bind /Work_bio/dropbox/Dropbox_Data/<客户目录名> /srv/external_data/client_sftp/files/<客户目录名>
  sudo mount -o remount,bind,ro /srv/external_data/client_sftp/files/<客户目录名>
  ```
  验证（agent 可自行跑）：`findmnt -o TARGET,SOURCE,OPTIONS <挂载点>` 应见 `ro`；`touch <挂载点>/x` 应报 `Read-only file system`；
  `md5sum` 抽检一个文件对照项目的 `MD5.csv`。文件需 644 / 目录 755，`client_sftp` 才读得到。
  **重启后挂载会失效**（未写 `/etc/fstab`）；要自动挂载加一行
  `/Work_bio/dropbox/Dropbox_Data/<客户目录名> /srv/external_data/client_sftp/files/<客户目录名> none bind,ro 0 0`（系统改动，先问用户）。
  **撤掉**一个客户：`sudo umount -l <挂载点> && sudo rmdir <挂载点>`（`rmdir` 只删空目录，比 `rm -rf` 安全；**绝不对挂载点 `rm -rf`**，会穿透到源数据）。
- **不要 `rsync` 拷整个数据集到 `files/`**（2026-10-06 差点把 992 GB 拷一遍，被用户当场指出）。
- **凭据**：账号/密码存在 `/home/gao/Utilities/Server/FTP/client_credentials.env`（600 权限，非交付内容）。

- **路径唯一**（user directive 2026-10-07）：FTP 相关脚本、凭据、文档**只有一处**：`/home/gao/Utilities/Server/FTP/`；
  针对某个客户的一次性脚本放其子目录，如 `/home/gao/Utilities/Server/FTP/WeQi/`。**不得**再到 `projects_2026H2/facilities` 等旧位置另放一份。

## 执行步骤（调用本 skill 时照做）

1. **运行就绪脚本**（它会：检查并按需拉起 sshd + bore → 读实时端口 → 读凭据 → 打印登录块）：
   ```bash
   /home/gao/Utilities/Server/FTP/ftp_ready.sh
   ```
2. **原样把「转发给客户的登录信息」块回给用户**，并明确当前服务状态（sshd / bore / 端口）。
3. **若脚本提示密码未填**（首次使用）：告诉用户去 `client_credentials.env` 把 `CLIENT_PASSWORD`
   改成真实 9 位密码（该文件仅本人可读），填完再调 `/FTP` 即可，以后就不会再忘。
   —— 不要自己编造密码；也不要用 `sudo passwd client_sftp` 重置密码（会让客户已保存的凭据失效），
   除非用户明确要求重置。
4. **若某个服务启动失败**（脚本打了 `❌ FAILED`）：按提示查 `systemctl status ssh` / `systemctl status bore`，
   常见故障对照旧文档 `/home/gao/Utilities/Server/FTP/setup_sFTP.sh` 第五阶段（Connection reset / Broken pipe=权限 / Permission denied=没进 /files）。

## 排错速查

| 现象 | 处理 |
|:---|:---:|
| 客户连不上、端口变了 | `journalctl -u bore \| grep 'listening at' \| tail -1` 看当前端口，把新端口发给客户 |
| bore 挂了 / `active` 但 Connection refused | `sudo systemctl restart bore`；已固定端口时仍是 47222，**重启后先核对日志是不是 `listening at bore.pub:47222`**，不是（如 `port already in use`）才需要换端口并重发客户 |
| 失效的 bind mount 残留（如 `Quote_260428002`，源已 deleted） | `sudo umount -l <挂载点> && sudo rmdir <挂载点>` |
| FileZilla 报 `Timeout detected (control connection)` + `You cannot connect to an SFTP server using an FTP protocol` | **客户端协议选错**，不是隧道问题。站点管理器里把协议选成 **SFTP - SSH File Transfer Protocol**（不是 FTP / FTPS）；快速连接栏主机名要写 `sftp://bore.pub` 并填端口，只写 `bore.pub` 默认走 FTP。**写给客户的邮件里要写明这一条**（客户端默认协议是 FTP，不写会超时） |
| 想换固定端口 | 先现测空闲：`timeout 6 /usr/local/bin/bore local 22 --to bore.pub --port N`；再让用户执行 `sudo sed -i 's\|--port 47222\|--port N\|' /etc/systemd/system/bore.service && sudo systemctl daemon-reload && sudo systemctl restart bore`（系统改动，先跟用户确认） |
| 看客户有没有在连 | `journalctl -u bore -f`（实时看 new connection） |
| 客户上传到哪了 | `/srv/external_data/client_sftp/files/` |

## 设计思路 / 异地重建

为什么这么搭、有哪些替代穿透方案、以及在另一台无域名无固定 IP 的服务器上从零重建的完整步骤：
见 `/home/gao/Utilities/Server/FTP/sFTP_穿透方案_设计与重建指南.md`。
