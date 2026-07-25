# 这份文档总结了你在无固定公网 IP 的环境下，为客户设立安全受限 sFTP 服务的全过程。你可以将其保存，以便日后在其他服务器上快速部署。
# 🚀 全能 sFTP 设立与内网穿透部署手册
# 本方案适用于：内网服务器、无公网 IP、需要给外部客户提供安全文件上传通道。
# 第一阶段：服务器内部 sFTP 环境配置
# 这一步确保客户只能通过 sFTP 访问，被锁定在指定目录（Chroot），且无法登录服务器命令行。

# 1. 创建用户组与账号
# # 创建 sFTP 专用组
# sudo groupadd sftp_users

# # 创建用户 (以 client_sftp 为例)，禁止其登录 Shell
# sudo useradd -m -g sftp_users -s /usr/sbin/nologin client_sftp

# # 设置复杂密码
# sudo passwd client_sftp
# 2. 构建受限目录结构（权限是关键！）
# sFTP 的安全机制要求：从根目录到用户主目录的所有父级目录，所有者必须是 root，且权限不能超过 755。
# code
# Bash
# # 1. 创建自定义数据目录
# sudo mkdir -p /srv/external_data/client_sftp/files

# # 2. 设置 Chroot 根目录权限（必须是 root:root）
# sudo chown root:root /srv/external_data/client_sftp
# sudo chmod 755 /srv/external_data/client_sftp

# # 3. 设置用户真正可以上传文件的子目录（属于用户）
# sudo chown client_sftp:sftp_users /srv/external_data/client_sftp/files
# sudo chmod 755 /srv/external_data/client_sftp/files

# # 4. 修正用户的主目录指向（确保与 Chroot 路径一致）
# sudo usermod -d /srv/external_data/client_sftp client_sftp
# 3. 配置 SSH 服务
# 编辑配置文件：sudo nano /etc/ssh/sshd_config
# 在文件末尾添加（或修改）：
# code
# Ssh
# # 针对 sftp_users 组的特定限制
# Match Group sftp_users
#     ChrootDirectory %h
#     ForceCommand internal-sftp
#     AllowTcpForwarding yes
#     X11Forwarding no
#     PasswordAuthentication yes
# 重启 SSH 服务：
# code
# Bash
# sudo systemctl restart ssh
# 第二阶段：内网穿透部署（解决无公网 IP）
# 当服务器处于内网时，通过 Bore 将本地端口映射到公网。
# 1. 安装 Bore 工具
# code
# Bash
# wget https://github.com/ekzhang/bore/releases/download/v0.5.1/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz
# tar -xf bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz
# sudo mv bore /usr/local/bin/
# 2. 后台运行隧道
# 使用 nohup 确保退出终端后服务不中断。
# code
# Bash
# # 将本地 22 端口映射到 bore.pub 服务器
# sudo nohup bore local 22 --to bore.pub > bore.log 2>&1 &
# 3. 获取外网连接端口
# 每次启动时，bore.pub 会分配一个随机端口，通过日志查看：
# code
# Bash
# cat bore.log
# 找到输出中的： listening at bore.pub:XXXXX（记录下这个 XXXXX 端口号）。
# 第三阶段：防火墙与安全设置
# 确保服务器防火墙不会拦截内部转发：
# code
# Bash
# # 允许 SSH 默认端口
# sudo ufw allow 22/tcp

# # 允许本地回环流量
# sudo ufw allow in on lo

# # 重载防火墙
# sudo ufw reload
# 第四阶段：交付给客户的信息
# 将以下格式的信息发送给客户，他们即可通过 WinSCP、FileZilla 等工具连接。
# 配置项	内容
# 协议	SFTP (非 FTP)
# 主机名 (Host)	bore.pub
# 端口号 (Port)	XXXXX (填 bore.log 中看到的数字)
# 用户名	client_sftp
# 密码	你设置的密码
# 目标文件夹	登录后请进入 /files 文件夹上传
# 第五阶段：日常维护与排错
# 1. 监控日志
# 如果客户反馈连不上，第一时间查看 bore 日志看端口是否发生变化：
# code
# Bash
# tail -f bore.log
# 2. 检查 SSH 登录记录
# 查看是否有非法尝试或登录失败的原因：
# code
# Bash
# sudo tail -f /var/log/auth.log
# 3. 常见故障点
# Connection reset: 通常是穿透工具（如 Playit 的 Minecraft 模板）干扰了协议，请确保使用 Bore 或 Ngrok 这种纯 TCP 隧道。
# Broken pipe: 100% 是目录权限问题。请检查 /srv/external_data/client_sftp 是否属于 root:root 且权限是否为 755。
# Permission denied: 检查客户是否尝试直接在根目录写文件，提醒他们必须进入 files 子目录。
# 💡 进阶建议：
# 若要长期给客户提供服务，建议购买一个 $2/年 的廉价域名，并配置 Cloudflare Tunnel (cloudflared)。
# 优点： 域名固定、端口永远是默认的、不需要手动运行 nohup、支持开机自启，是目前最专业且免费的商业级内网穿透方案。
# Model 7:22 PM
# ThinkingThoughts
# Expand to view model thoughts

# chevron_right
# Model 7:51 PM
# ThinkingThoughts
# Expand to view model thoughts

# chevron_right
# 没错，正是如此。因为你使用了 nohup 命令和末尾的 & 符号，这个程序已经与当前的终端会话（Terminal Session）“脱离”了关系。
# 为什么它不会受影响？
# nohup (No Hang Up)：它的作用是让程序忽略 SIGHUP 信号。通常当你关闭终端窗口或断开 SSH 连接时，系统会发送这个信号关闭该窗口下的所有程序。有了 nohup，程序就会无视这个指令，继续运行。
# > bore.log 2>&1：这把程序的输出（包括错误信息）都重定向到了文件中。这样程序就不会因为找不到“显示屏幕”而报错退出。
# &：这把程序放到了系统后台运行。
# 你如何管理这个“看不见”的程序？
# 既然窗口关了，下次你登录时，可以用以下命令来管理它：
# 1. 查看它是否还在跑
# code
# Bash
# ps aux | grep bore
# 如果你看到一行包含 bore local 22 --to bore.pub 的信息，说明它依然稳稳地运行在后台。
# 2. 查看它的实时日志（看看客户有没有连接）
# code
# Bash
# tail -f bore.log
# 3. 彻底关掉它（比如你想换个端口）
# 你需要先找到它的进程号（PID），或者直接用名字杀掉它：
# code
# Bash
# sudo killall bore
# ⚠️ 一个最终的提醒：服务器重启怎么办？
# nohup 虽然能保证你关闭窗口时程序不退，但如果你的服务器由于断电或维护重启了，nohup 里的程序是不会自动启动的。
# 如果你希望服务器重启后，sFTP 穿透自动恢复，最专业的方法是把它写成“系统服务” (systemd service)：
# 创建服务文件：
# sudo nano /etc/systemd/system/bore.service
# 粘贴以下内容（修改你的路径）：
# code
# Ini
# [Unit]
# Description=Bore SFTP Tunnel
# After=network.target

# [Service]
# ExecStart=/usr/local/bin/bore local 22 --to bore.pub
# Restart=always
# User=root

# [Install]
# WantedBy=multi-user.target
# 启用并启动：
# code
# Bash
# sudo systemctl enable bore
# sudo systemctl start bore
# 这样，你就再也不用手动运行命令了，它会像网站一样 24/7 永远在线。
# 现在你可以放心地关掉你的终端窗口，去休息一下了！你的客户随时可以连接。
# Model 7:59 PM
# ThinkingThoughts
# Expand to view model thoughts

# chevron_right
# 非常抱歉，这是我的严重疏忽。我完全记住了：你只使用 Vim，绝对不用 Nano。在之后的任何步骤和文档中，我都会严格执行 vim 指令。
# 为了弥补之前的错误，我用 Vim 的标准流程为你重新梳理一遍将 bore 设置为开机自启系统服务的步骤：
# 使用 Vim 配置 Bore 系统服务
# 创建并编辑服务文件：
# code
# Bash
# sudo vim /etc/systemd/system/bore.service
# 在 Vim 中按下 i 进入插入模式，粘贴以下配置：
# code
# Ini
# [Unit]
# Description=Bore SFTP Tunnel
# After=network.target

# [Service]
# # 确保 ExecStart 指向你 bore 所在的实际路径
# ExecStart=/usr/local/bin/bore local 22 --to bore.pub
# # 失败后自动重启
# Restart=always
# # 延迟 5 秒重启，防止网络未就绪时启动失败
# RestartSec=5
# User=root

# [Install]
# WantedBy=multi-user.target
# 保存并退出：
# 按下 Esc 键，输入 :wq 并回车。
# 激活并启动服务：
# code
# Bash
# # 重新加载系统服务配置
# sudo systemctl daemon-reload

# # 设置开机自启
# sudo systemctl enable bore

# # 立即启动服务
# sudo systemctl start bore
# 查看服务状态（及获取当前端口）：
# code
# Bash
# sudo systemctl status bore
# 你可以在输出的日志部分直接看到分配的端口号。
# 以后如何通过 Vim 修改客户配置？
# 如果你以后需要增加新的 sFTP 用户或修改 SSH 配置：
# code
# Bash
# sudo vim /etc/ssh/sshd_config
# 修改完成后同样是 :wq 退出，然后 sudo systemctl restart ssh。
# 再次向你道歉，以后我会确保所有的命令都符合你的使用习惯。