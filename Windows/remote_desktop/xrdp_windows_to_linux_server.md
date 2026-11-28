# 从 Windows 图形化连服务器改文件 —— xrdp 远程桌面

- **建立日期**：2026-11-27
- **实测环境**：Windows 11（`desktop-c8oke65`）→ Ubuntu 22.04.5 服务器（`us1`）
- **解决的问题**：在 Windows 上编辑**服务器上的** Office 文件（`.docx` 等），改完直接存回服务器
- **起因**：P46 要给客户问卷 `.docx` 加一条注，在 Positron/VSCode 里改不了也存不了

## 结论（三句话）

1. **用 Windows 自带的"远程桌面连接"（`mstsc`）连服务器的 xrdp，什么都不用装。**
   连上去是一个完整的 Linux 桌面，服务器上的 LibreOffice 直接打开本地路径的文件，
   **Ctrl+S 天然就是存在服务器上** —— 没有任何"远程文件"中间层。
2. **LibreOffice 的 "Remote Files → SSH" 在 Windows 版不存在**，别在这上面耗时间（见「走过的弯路」）。
3. **xrdp 会话是持久的**：断线不杀会话，重连回到原样，打开的程序还在。

---

## 一、连接参数（实测可用）

| 项 | 值 |
| :--- | :---: |
| Windows 端客户端 | **系统自带**，`Win + R` → `mstsc` |
| 主机（Tailscale，任何网络都通） | `100.101.19.30` |
| 主机（同一局域网） | `192.168.0.83` |
| 端口 | `3389`（默认，不用填） |
| 证书警告 | 选"是"（自签名证书，正常） |
| xrdp 登录框 **Session** | **`Xorg`** |
| username / password | `gao` / 服务器登录密码 |

连上后开终端，例如：

```bash
soffice /path/to/file.docx &
```

⚠ 存 `.docx` 时若弹格式询问，选 **`Use Word 2007-365!`**，别转成 ODF。

## 二、服务器端做过的唯一配置

创建 `~/.xsession`（此前不存在），内容一行：

```sh
exec startxfce4
```

并 `chmod +x ~/.xsession`。

**为什么用 XFCE 而不是默认的 GNOME**：远程响应快得多、带宽省。
**不是必需品** —— 本机 2026-03-15 那次会话没有 `~/.xsession`、用系统默认会话，也跑了 1.5 小时。
**回退**：`rm ~/.xsession` 即恢复默认。

### 这条链为什么成立（排错时按这个顺序查）

```
xrdp-sesman → /etc/xrdp/startwm.sh → exec /etc/X11/Xsession（不带参数）
            → $STARTUP 为空
            → /etc/X11/Xsession.options 含 allow-user-xsession   ← 缺这条则 ~/.xsession 被静默忽略
            → ~/.xsession 存在且可执行
            → exec startxfce4
```

⚠ **`allow-user-xsession` 这一条是 Debian/Ubuntu 的静默陷阱**：没有它，`~/.xsession` 写得再对也不会被采用，
表现是连上去直接进 GNOME（或黑屏），而**任何日志都不会说"我忽略了你的 .xsession"**。

## 三、本次成功会话的实测记录（2026-11-27）

| 项 | 实测值 |
| :--- | :---: |
| TLS 握手 | `23:28:51` TLSv1.3 / `TLS_AES_256_GCM_SHA384`，来自 `100.71.137.123` |
| 登录 | `23:29:24` `login successful for display 10` |
| 会话规格 | `display :10.0`，**3840 × 2560**，bpp 24 |
| 窗口管理器 | `xfce4-session` 已起（证明 `~/.xsession` 生效） |
| 应用 | `soffice.bin` 正常运行，文件保存成功并通过 XSD 校验 |
| 断线 | `23:33:05` `xrdp_sec_recv: xrdp_mcs_recv failed` / `SSL_write: I/O error` |
| 断线后 | **会话存活**，`xfce4-session` 与 `soffice.bin` 继续在跑 |

## 四、会话持久性（很有用，别误以为断线就丢）

`/etc/xrdp/sesman.ini` 的实测设置：

| 参数 | 值 | 含义 |
| :--- | :---: | :---: |
| `KillDisconnected` | `false` | **断线不杀会话** |
| `DisconnectedTimeLimit` | `0` | 不超时回收 |
| `IdleTimeLimit` | `0` | 不因闲置回收 |
| `MaxSessions` | `50` | 够用 |
| `X11DisplayOffset` | `10` | 会话从 `:10` 起（物理屏是 `:0`） |

⇒ **断网、关笔记本、换地点，重连后回到同一个桌面，打开的程序原样还在。**
⇒ 反过来：长期不用的会话要自己退出登录，否则一直占内存。

## 五、⛔ 走过的弯路（这一节才是本文最值钱的部分）

### 5.1 LibreOffice 的 "Remote Files → SSH"：**Windows 版没有这个功能**

**症状**：File → Open Remote... → 新建 SSH 服务，Host/Port/User/Password/Root 全填对、点 OK，
**两个窗格全空、File name 不可输入、Open 灰掉，而且一个错误都不报。**

**判定方法（关键）**：去**服务器**看 `/var/log/auth.log`。
本次实测该 Windows 机今天的全部 sshd 事件只有 6 条 `Accepted publickey ... ED25519`，
**操作 LibreOffice 的那几分钟零记录** ⇒ **客户端压根没打开 socket**。

> **这个判据可以推广**：凡是"客户端连不上"，先看服务端日志有没有收到连接。
> **没有任何记录 = 不是认证、不是防火墙、不是路径 —— 是客户端根本没发。**
> 本次还有一个现成的对照组：同一台 Windows 机、同一个 IP、同一个 22 端口的 Positron 连接
> **此刻正 ESTABLISHED** ⇒ 网络与凭据都没问题，变量只剩 LibreOffice 自己。

**机制（推断）**：LibreOffice 的 SSH 远程文件在 Linux 上是借 **GIO/GVFS**（`sftp://`，Nautilus 用的同一套）实现的；
**Windows 没有 GVFS，这个组件没编进去**。下拉框里的 "SSH" 是写死的 UI 列表项，背后没有后端。

⚠ **"我以前用 LibreOffice 能远程开服务器文件"是真的 —— 那是在 Ubuntu 桌面上**（2019 年前后）。
换到 Windows 后这个功能就不存在了，不是设置丢了。

### 5.2 OnlyOffice 桌面版：**不支持 SSH/SFTP**

它的 "Connect to cloud" 只认 ONLYOFFICE Docs / Nextcloud / ownCloud / Seafile 这类 WebDAV 云盘，
**不认裸 SSH**。想用 OnlyOffice 改服务器文件，必须先把服务器挂成盘符（见 §6）。

### 5.3 在 Positron / VSCode 里直接改 `.docx`：不可能

`.docx` 是二进制 ZIP 包，编辑器要么拒绝显示，要么由预览插件渲染成**只读**视图 ——
只读视图里的 Save 本来就是空操作。**"各处 save 都不 work" 不是设置问题。**

## 六、其它可选路线（本机现状）

| 路线 | 本机状态 | Windows 端成本 | 能用 OnlyOffice/Word 吗 |
| :--- | :---: | :---: | :---: |
| **xrdp 远程桌面** | **已配好可用** | **零安装** | 不能，但服务器上有 LibreOffice 7.3.7.2 |
| **SSHFS-Win 映射盘符** | 服务器端**零改动**（SSH 已通，ED25519 公钥已授权） | WinFsp + SSHFS-Win 两个 msi | **能**，任何编辑器都能 |
| Samba (SMB) | `smbd`/`nmbd` **inactive**，无共享定义 | 零安装 | 能，但要装配 + 开端口（需 sudo） |
| NFS | **inactive**，`/etc/exports` 为空 | 要装客户端 | — |
| WebDAV | apache2/nginx 都 **inactive** | 零安装 | 能，但要装配 |

**SSHFS-Win 的用法**（装 `github.com/winfsp/winfsp` + `github.com/winfsp/sshfs-win` 的 Releases）：
在资源管理器地址栏输

```
\\sshfs.kr\gao@100.101.19.30\mnt\ex_8T_SSD\projects_2026Q4\...
```

| 前缀 | 含义 |
| :--- | :---: |
| `sshfs` | 密码认证，根目录 = 家目录 |
| `sshfs.r` | 密码认证，根目录 = `/` |
| `sshfs.k` | **密钥**认证，根目录 = 家目录 |
| **`sshfs.kr`** | **密钥认证 + 根目录 = `/`** ← 本机推荐 |

⚠ **用 `.r` 系列（根在 `/`）**：`/home/gao/projects_2026Q4` 是指向 `/mnt/ex_8T_SSD/projects_2026Q4` 的
**符号链接**，走家目录那条路径时某些 SFTP 客户端会在链接上出问题。

## 七、排错时看哪些日志（服务器端）

| 日志 | 看什么 |
| :--- | :---: |
| `/var/log/xrdp.log` | TLS 握手、客户端能力协商、`login successful for display N` |
| `/var/log/xrdp-sesman.log` | 会话创建、分辨率、`Starting the default window manager`、会话退出 |
| `~/.xorgxrdp.<display>.log` | X server（xorgxrdp）本身的问题 |
| `~/.xsession-errors` | **窗口管理器/桌面环境的报错落这里**（XFCE 起不来就看它） |
| `/var/log/auth.log` | SSH 侧；**判断"客户端到底有没有连上来"** |

⚠ **容易误读**：用 `/dev/tcp` 或 `nc` 测 3389 端口通不通，会在 `xrdp.log` 里留下一串
`[ITU-T X.224] Connection Sequence: CR-TPDU (Connection Request) failed` —— 那是"只建 TCP 不发 RDP 握手"
的正常结果，**不是故障**。排错前先排除自己造成的噪声。

## 八、安全注记

- xrdp 监听 **`0.0.0.0:3389`（所有接口）**，局域网内任何机器都能看到登录框。
  只想让 Tailscale 能连的话，用 ufw 限制到 `tailscale0` 接口（需 sudo）。
- `sesman.ini` 里 `AllowRootLogin=true`。
- 首次进桌面可能弹 `Authentication required to create managed color device`（xrdp + colord 老毛病）。
  点取消也能用；永久消除需写 `/etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla`（需 sudo）。

## 九、相关文档

| 文档 | 管什么 |
| :--- | :---: |
| `../input_methods/shift_cmd.txt` | Windows 输入法切换 |
| `~/Utilities/Server/` | 服务器端运维 |
| `~/Utilities/software_pitfalls/INDEX.md` | 各软件的坑（本文 §5 属同类，已在此另记一份指针） |
