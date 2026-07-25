
# 针对你遇到的 Unit bore.service could not be found 报错，以及需要让客户下载特定目录 /home/gao/Dropbox/Quote_260428002 的需求，请按照以下使用 Vim 进行操作的步骤进行修复和配置。
# 第一部分：修复 Bore 服务无法找到的问题
# 报错是因为系统还没识别到这个服务文件。
# 检查文件是否存在：
ls /etc/systemd/system/bore.service
# 如果显示不存在，请重新创建：
sudo vim /etc/systemd/system/bore.service
# 在 Vim 中按下 i 进入插入模式，确保内容如下：

[Unit]
Description=Bore SFTP Tunnel
After=network.target

[Service]
ExecStart=/usr/local/bin/bore local 22 --to bore.pub
Restart=always
User=root

[Install]
WantedBy=multi-user.target

# 按下 Esc，输入 :wq 保存退出。
# 激活服务（关键步骤）：
# # 必须运行此命令让系统重新扫描服务文件
sudo systemctl daemon-reload
sudo systemctl enable bore
sudo systemctl start bore

# 再次查看状态：
sudo systemctl status bore

# 现在应该能看到绿色实心的 active (running)，并在下方日志看到端口号。
# ● bore.service - Bore SFTP Tunnel
#      Loaded: loaded (/etc/systemd/system/bore.service; enabled; vendor preset: enabled)
#      Active: active (running) since Thu 2026-06-11 13:55:40 EDT; 11s ago << ===== GREEN color =============================== HERE !
#    Main PID: 1075738 (bore)
#       Tasks: 65 (limit: 154375)
#      Memory: 4.7M
#         CPU: 18ms
#      CGroup: /system.slice/bore.service
#              └─1075738 /usr/local/bin/bore local 22 --to bore.pub

# Jun 11 13:55:40 us1 systemd[1]: Started Bore SFTP Tunnel.
# Jun 11 13:55:40 us1 bore[1075738]: 2026-06-11T17:55:40.290726Z  INFO bore_cli::client: connected to server remote_port=38643
# Jun 11 13:55:40 us1 bore[1075738]: 2026-06-11T17:55:40.290803Z  INFO bore_cli::client: listening at bore.pub:38643 # <<<<<<<<<<<<<<<<< ===== Port number =========================== HERE !


# 第二部分：让客户访问 Dropbox 目录的数据
# 由于我们之前为 client_sftp 设置了 Chroot (受限监狱)，客户登录后只能看到 /srv/external_data/client_sftp 目录。他无法直接访问你家目录下的 /home/gao/Dropbox/...。
# 为了解决这个问题，我们使用 Linux 的 mount --bind (挂载绑定) 技术。这相当于在客户的文件夹里开一个“传送门”，直接映射到你的 Dropbox 目录，而不需要移动或复制文件。
# 在客户的 files 目录下创建挂载点：
sudo mkdir -p /srv/external_data/client_sftp/files/Quote_260428002
# 执行绑定挂载：
# 将你的实际数据目录挂载到客户能看到的目录上：
sudo mount --bind /home/gao/Dropbox/Quote_260428002 /srv/external_data/client_sftp/files/Quote_260428002
# 修改目录权限（确保客户能读）：
# 由于文件在你的家目录下，客户账号可能没有读取权限：
# 给该目录及其内容添加读取权限
sudo chmod -R 755 /home/gao/Dropbox/Quote_260428002
# 永久生效（防止服务器重启后消失）： ========================================== NO Needed here
# 你需要修改 /etc/fstab 文件。
# code
# Bash
# sudo vim /etc/fstab
# 在文件末尾添加这一行：
# code
# Text
# /home/gao/Dropbox/Quote_260428002 /srv/external_data/client_sftp/files/Quote_260428002 none bind 0 0
# 在 Vim 中按 Esc，输入 :wq 退出。

# 第三部分：验证
# 让客户重新连接 sFTP。
# 进入 files 文件夹。
# 他现在应该能看到一个名为 Quote_260428002 的文件夹。
# 他可以直接下载里面的所有数据。

# 总结
# 通过 systemctl daemon-reload 解决了服务找不到的问题。
# 通过 mount --bind 解决了 Chroot 环境下跨目录访问数据的问题，且保证了数据依然留在你的 Dropbox 目录中同步。
# 如果客户下载时遇到 "Permission denied"，请告诉我，通常只需要再微调一下 Dropbox 文件夹的父级权限即可。

###############################================================================================================
# 要让客户下载，你需要先从服务器上获取 Bore 分配给你的最新端口号，然后将完整的连接信息发给客户。
# 请按照以下步骤操作：
# 第一步：获取当前端口号
# 请在服务器上执行以下命令：
sudo systemctl status bore
# 在输出的日志中（通常是最后几行），寻找类似以下的文字：
listening at bore.pub:38643

# 那个数字（XXXXX）就是客户需要填写的端口号。
# 第二步：发给客户的完整下载指南
# 你可以直接复制并修改以下内容发送给客户：
# 文件下载说明 (sFTP)
# 我们已经为您准备好了数据，请使用以下信息连接服务器进行下载：
# 连接参数：
Protocol: SFTP
Host: bore.pub
Port: 38643
Username: client_sftp
Password: 123456789

# suggest app:
# Windows: WinSCP 或 FileZilla。
# Mac: Cyberduck 或 FileZilla。
# path: files/Quote_260428002/


# Note: click yes for "Unknown Host Key)” message
# 如果连接失败，请检查端口号是否输入正确。
# 第三步：最后的确认 (管理员必看)
# 在发送信息前，请务必在服务器上用 Vim 确认一下挂载是否成功，确保客户进去能看到文件：
# 查看客户目录下是否有文件：
# code
# Bash
# ls -l /srv/external_data/client_sftp/files/Quote_260428002
# 如果你能看到 Dropbox 里的文件列表，说明挂载成功。
# 权限检查（防止客户连上但看不了文件）：
# 由于数据在 /home/gao/ 下，你需要确保 client_sftp 至少有进入路径的权限：
# code
# Bash
# # 确保 gao 的家目录允许外部进入（仅读取权限）
# sudo chmod 755 /home/gao
# sudo chmod 755 /home/gao/Dropbox
# 总结：
# 你现在只需运行 sudo systemctl status bore 拿到那个 5 位数的端口号，填到上面的模板里发给客户，他就可以开始下载了。