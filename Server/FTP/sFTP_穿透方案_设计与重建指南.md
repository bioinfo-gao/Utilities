# 无公网 IP · 无自购域名下的安全 sFTP 穿透方案 — 设计思路与异地重建指南

> 最后更新：2026-07-09　·　适用场景：内网服务器、无固定公网 IP、无已购买域名，需要给**外部客户**开一条安全的文件上传/下载通道。
> 本文解释「当初为什么这么搭」，列出「还有哪些别的选项及取舍」，并给出「在另一台类似服务器上从零重建」的完整可复制步骤。

---

## 1. 目标与约束

| 维度 | 具体要求 |
| :--- | :---: |
| 使用者 | 外部客户（非技术人员），用 WinSCP / FileZilla 图形界面即可连 |
| 网络环境 | 服务器在内网（NAT 后），**无固定公网 IP**、**无自购域名** |
| 安全 | 客户只能读写指定目录，**不能登录 shell、不能看别的用户/系统文件** |
| 成本 | 尽量零成本，不为此单独买域名或云主机 |
| 可靠 | 服务器重启后能自动恢复，不需要每次手动敲命令 |

这几条约束直接决定了后面每一个技术选择。

---

## 2. 架构总览

```
  客户 (WinSCP)                      公网中转                     你的内网服务器
 ┌────────────┐   SFTP over TCP   ┌───────────────┐   隧道回传   ┌──────────────────────┐
 │ bore.pub   │ ───────────────►  │  bore.pub     │ ──────────► │ bore client (systemd) │
 │ :<随机端口> │                   │ (公共中转服务) │             │        │             │
 └────────────┘                   └───────────────┘             │        ▼ localhost:22 │
                                                                │   sshd + internal-sftp│
                                                                │   chroot 到           │
                                                                │   /srv/external_data/ │
                                                                │     client_sftp/files │
                                                                └──────────────────────┘
```

两层：
- **服务器内部**：标准 `sshd` 的 `internal-sftp` 子系统，用 chroot 把客户锁在一个目录里 —— 这层负责「安全」。
- **公网穿透**：`bore` 把本机 `:22` 映射到公共中转 `bore.pub:<端口>` —— 这层负责「让内网可达」。

两层彼此独立：穿透工具坏了不影响 sFTP 安全模型，反之亦然。

---

## 3. 关键决策与「为什么」

### 3.1 为什么用 sFTP，而不是 FTP / FTPS / 网盘

| 方案 | 为什么**没**选它 / 为什么选 sFTP |
| :--- | :---: |
| 传统 FTP | 明文传输、需要开一堆被动端口、NAT/穿透极不友好 —— 直接排除 |
| FTPS (FTP over TLS) | 要管证书，被动端口范围同样难穿透，客户端配置易错 |
| 云网盘（百度/OneDrive 等） | 受限速/隐私/客户地区可达性影响，且大文件与目录结构不可控 |
| **sFTP（选中）** | 走**单个 TCP 端口（22）**，天然适配单端口隧道穿透；传输加密；复用系统已有 `sshd`，无需额外守护进程；`chroot + internal-sftp` 能做到很强的目录隔离 |

一句话：**sFTP 是「单端口 + 强隔离 + 复用 sshd」的组合，最契合穿透场景。**

### 3.2 为什么客户账号要 chroot + nologin

- `ChrootDirectory %h`：客户登录后被锁在自己的家目录，**看不到宿主机文件系统**。
- `ForceCommand internal-sftp`：强制只走 SFTP 协议，**拿不到 shell**（即使有人尝试 `ssh` 进来也只会得到 sftp）。
- 登录 shell 设为 `/usr/sbin/nologin`：双保险，禁止交互式登录。
- `AllowTcpForwarding no`：禁止客户拿这条连接做端口转发跳板（本机实测值就是 `no`，比「允许」更安全）。

chroot 的硬性要求（踩过坑）：**从根到客户家目录，每一级父目录的属主必须是 `root:root`，权限 ≤ 755。** 家目录本身不能是客户可写的；真正可写的是它下面的子目录（这里是 `files/`）。违反这条 → 客户连上就 `Broken pipe`。

### 3.3 为什么用 bore 做穿透（而不是别的）

在「无域名、无固定 IP、要纯 TCP、要零成本」这组约束下，bore 的优点：
- **纯 TCP 隧道**，协议无关 —— SFTP 这种非 HTTP 流量能干净透传（很多面向 HTTP 的隧道或游戏向工具会破坏 SFTP 握手，导致 `Connection reset`）。
- **零配置、零成本**：官方公共中转 `bore.pub` 免费可用，一条命令即通，不用注册、不用域名。
- **单二进制**，无依赖，适合塞进 systemd 长期跑。

代价（必须知道的取舍）：
- **端口随机**：不加 `--port` 时，`bore.pub` 每次启动随机分配公网端口 → 见 §6。
- **依赖公共中转的可用性/信任**：流量经过第三方 `bore.pub`。虽然 SFTP 本身是端到端加密的（中转看不到明文内容），但**不适合长期承载敏感生产流量**；正式长期用应自建 bore server 或换 Cloudflare Tunnel（见 §4）。
- 无内置带宽保障。

### 3.4 为什么用 systemd 服务，而不是 nohup

最初的草稿用 `nohup bore … &`。问题：**服务器一重启，nohup 起的进程不会自动回来**，客户第二天就连不上了。改成 systemd 服务后：
- `Restart=always` + `RestartSec` → 崩溃自动拉起；
- `enable` → 开机自启，重启后无需人工干预；
- 用 `journalctl -u bore` 统一看日志（不再依赖某个 `bore.log` 文件）。

**这是本方案相对旧文档 `setup_sFTP.sh` 的主要升级，异地重建时直接用 systemd 版本。**

### 3.5 密码 vs 密钥

当前用**密码认证**（`PasswordAuthentication yes`，9 位密码），因为客户多为非技术人员，图形客户端填密码最省事。
- 更安全的做法是**公钥认证**（客户生成密钥、发公钥给你）。若客户能配合、或数据更敏感，优先切公钥并把全局 `PasswordAuthentication` 关掉、仅对该组开放。
- 用密码就务必配 **fail2ban**（见 §7），因为端口一旦公开会有暴力扫描。

---

## 4. 穿透方案横向对比（都满足「无固定 IP」，重点看「是否需要域名/成本/端口是否固定」）

| 方案 | 需自购域名 | 端口/地址是否固定 | 纯TCP(SFTP友好) | 成本 | 适用定位 |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **bore + bore.pub（现方案）** | 否 | 否（每次重启换端口） | 是 | 免费 | 临时/短期给客户开通道，最快上手 |
| bore + **自建 bore server**（自己有台便宜 VPS） | 否（用 VPS 的 IP 即可） | 是（可 `--port` 固定） | 是 | VPS 约 $3–5/月 | 想要固定端口又不想买域名 |
| **Cloudflare Tunnel (cloudflared)** | **是**（需一个域名接入 CF） | 是（域名固定、无需开端口） | SFTP 需 `cloudflared access` 客户端封装，非纯裸TCP | 免费（域名约 $2–10/年） | 长期、专业、要固定入口的首选 |
| **frp**（自建） | 否（用 VPS IP） | 是 | 是 | VPS 费用 | 功能最全，配置略重，多服务复用 |
| **ngrok** | 否（免费给随机域名） | 免费版随机、固定要付费 | TCP 隧道要付费计划 | 免费有限/付费 | 快速演示；SFTP 长期用需付费 |
| **Tailscale / WireGuard**（组网） | 否 | 是（虚拟固定 IP） | 是 | 免费 | 客户**愿意装客户端**时最优、最安全；非技术客户装不动 |
| **反向 SSH 隧道**到一台有公网的机器 | 否（用那台机 IP） | 是 | 是 | 需一台公网机 | 手上正好有公网跳板机时 |
| playit.gg 等游戏向隧道 | 否 | 否 | **否**（易破坏SFTP握手） | 免费 | ❌ 不建议用于 SFTP |

**选型速记：**
- 只是临时给客户传一批数据、越快越好 → **bore + bore.pub（本方案）**。
- 要长期、要固定入口、能接受买个便宜域名 → **Cloudflare Tunnel**。
- 有一台便宜 VPS、想固定端口又不想碰域名 → **自建 bore server / frp**。
- 客户是技术方、愿意装客户端 → **Tailscale**（最安全）。

---

## 5. 从零重建：在另一台服务器上完整搭一套（可复制）

> 前提：目标机是 Debian/Ubuntu 系、已装 `openssh-server`、你有 sudo。全程用 `vim` 编辑配置。
> 下面把「服务器内部 sFTP」和「bore 穿透」分成两段，每条命令都基于本机已验证的真实配置。

### 阶段 A — 服务器内部：受限 sFTP 账号

```bash
# A1. 建专用组 + 客户账号（禁止 shell 登录）
sudo groupadd sftp_users
sudo useradd -m -g sftp_users -s /usr/sbin/nologin client_sftp
sudo passwd client_sftp                     # 设一个强密码（记到 client_credentials.env）

# A2. 建 chroot 目录结构（权限是成败关键）
sudo mkdir -p /srv/external_data/client_sftp/files
# chroot 根：从根到家目录每一级都必须 root:root 且 <=755
sudo chown root:root /srv/external_data/client_sftp
sudo chmod 755      /srv/external_data/client_sftp
# 真正可写的子目录归客户
sudo chown client_sftp:sftp_users /srv/external_data/client_sftp/files
sudo chmod 755                    /srv/external_data/client_sftp/files
# 让账号家目录指向 chroot 根
sudo usermod -d /srv/external_data/client_sftp client_sftp
```

```bash
# A3. 配置 sshd —— 编辑 /etc/ssh/sshd_config
sudo vim /etc/ssh/sshd_config
```
确认存在 SFTP 子系统（默认就有）：
```
Subsystem sftp /usr/lib/openssh/sftp-server
```
在文件**末尾**加上针对该组的限制块（这就是本机实际生效、已验证的配置）：
```
Match Group sftp_users
    ChrootDirectory %h
    ForceCommand internal-sftp
    AllowTcpForwarding no
    PasswordAuthentication yes
```
```bash
# A4. 校验语法并重启
sudo sshd -t && sudo systemctl restart ssh
# 本机自测（应进入 sftp> 且只能看到 /files）
sftp -P 22 client_sftp@127.0.0.1
```

### 阶段 B — 公网穿透：bore（systemd 版）

```bash
# B1. 安装 bore（单二进制）
cd /tmp
wget https://github.com/ekzhang/bore/releases/download/v0.5.1/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz
tar -xf bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz
sudo mv bore /usr/local/bin/ && bore --version
```

```bash
# B2. 写成 systemd 服务（开机自启 + 崩溃自恢复）
sudo vim /etc/systemd/system/bore.service
```
粘贴（与本机一致）：
```ini
[Unit]
Description=Bore SFTP Tunnel
After=network.target

[Service]
ExecStart=/usr/local/bin/bore local 22 --to bore.pub
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
```
> 想要**固定公网端口**（省得每次重发端口给客户），把 ExecStart 改成：
> `ExecStart=/usr/local/bin/bore local 22 --to bore.pub --port 38643`
> （只有当 `bore.pub` 上该端口当时空闲才会成功；不保证长期占得住。要真正稳定应自建 bore server 或用 Cloudflare Tunnel。）

```bash
# B3. 启用并启动
sudo systemctl daemon-reload
sudo systemctl enable --now bore
# B4. 读取当前分配的公网端口（发给客户用这个）
journalctl -u bore --no-pager | grep 'listening at' | tail -1
#   → listening at bore.pub:XXXXX
```

### 阶段 C — 防火墙

```bash
sudo ufw allow 22/tcp        # SSH/SFTP
sudo ufw allow in on lo      # 本地回环（bore 走 localhost:22）
sudo ufw reload
```

### 阶段 D — 交付客户

把 §「本机 /FTP skill 生成的登录块」发给客户即可（协议 SFTP、主机 bore.pub、端口=B4 读到的、用户 client_sftp、密码、进 `/files` 上传）。
本机已有 `/FTP` skill + `ftp_ready.sh` 自动完成 B4 与信息汇总，异地重建后可把这两个文件一并带过去。

---

## 6. 端口漂移问题（本方案最大的坑）与三种稳定化

`bore local 22 --to bore.pub` 不带 `--port` 时，**每次 bore 重启都会随机换公网端口**。表现：某天客户突然连不上，其实是服务器/服务重启后端口变了。

应对，由轻到重：
1. **实时读端口再发**（现状）：`journalctl -u bore | grep 'listening at' | tail -1`。本机 `/FTP` skill 已自动这么做。重启 bore 后务必把新端口重发客户。
2. **请求固定端口**：`--port <n>`（见 §5-B2 注）。半固定，取决于 bore.pub 该端口是否空闲。
3. **换固定入口架构**：自建 bore server（用你 VPS 的 IP + 固定端口）/ frp / **Cloudflare Tunnel（域名固定、最专业）**。长期给客户服务建议走这条。

---

## 7. 安全加固清单

| 项 | 命令 / 做法 | 目的 |
| :--- | :---: | :---: |
| chroot 权限自查 | `namei -l /srv/external_data/client_sftp` 每级应 root:root ≤755 | 防 `Broken pipe`、防越权 |
| fail2ban | `sudo apt install fail2ban`，启用 sshd jail | 密码认证下挡暴力破解 |
| 强密码/改公钥 | 9+ 位随机；敏感数据改公钥并关全局密码认证 | 降低被爆破风险 |
| 定期查登录 | `journalctl -u ssh` / `sudo tail -f /var/log/auth.log` | 发现异常尝试 |
| 只在需要时开隧道 | 传完 `sudo systemctl stop bore` | 缩小暴露窗口 |
| 数据落地隔离 | 客户目录独立分区/配额，勿与业务数据混放 | 防塞满磁盘、防误读 |

---

## 8. 排错速查

| 现象 | 最可能原因 | 处理 |
| :--- | :---: | :---: |
| `Connection reset` | 隧道工具破坏了协议（用了非纯TCP的工具） | 确认用 bore/ngrok 这类纯 TCP 隧道，别用游戏向隧道 |
| `Broken pipe` | chroot 目录权限不对 | 家目录及各级父目录必须 root:root ≤755 |
| `Permission denied`（写文件） | 客户在**根目录**写 | 提醒客户进 `/files` 子目录再上传 |
| 客户突然连不上 | bore 重启换了端口 | `journalctl -u bore \| grep 'listening at' \| tail -1` 取新端口重发 |
| 隧道不在了 | bore 挂了 / 没开机自启 | `sudo systemctl restart bore`；确认 `systemctl is-enabled bore` |
| 忘了账号/密码/端口 | —— | 调 `/FTP`（跑 `ftp_ready.sh`），或看 `client_credentials.env` |

---

## 9. 一句话决策图

```
要给外部客户开安全文件通道
        │
        ├─ 无域名 / 无固定 IP / 只是临时       → bore + bore.pub（本方案，最快）
        ├─ 要长期 + 固定入口 + 能买便宜域名     → Cloudflare Tunnel
        ├─ 有便宜 VPS，想固定端口不想碰域名     → 自建 bore server / frp
        └─ 客户是技术方、愿装客户端            → Tailscale（最安全）
```

---

*相关文件：`ftp_ready.sh`（就绪检查+登录信息生成）、`client_credentials.env`（本地私有凭据，600，勿提交）、`setup_sFTP.sh`（最初手记，nohup 版，已被本文 systemd 版取代）、`/FTP` skill（`~/.claude/commands/FTP.md`）。*
