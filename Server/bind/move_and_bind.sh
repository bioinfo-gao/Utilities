# 这是一个非常经典的生信服务器存储优化方案。由于参考基因组（尤其是小鼠、人类以及宏基因组数据库）体积庞大且文件碎片多，强烈建议使用 rsync 而不是 cp 或 mv 来进行迁移，这样可以保证数据的完整性，并且支持断点续传。

# 为了保证操作的安全性和持久化，以下是完整的迁移与绑定挂载（Bind Mount）标准操作流程：

# 第一步：开启终端复用与准备目标目录
# 为了防止数据拷贝过程中 SSH 意外断开导致任务失败，请先启动 tmux 会话。


# # 启动一个新的 tmux 会话
# tmux new -s move_refs

# # 在高速 SSD 上创建同名的目标文件夹
# sudo mkdir -p /mnt/ex_8T_SSD/references
# 第二步：使用 rsync 进行安全同步
# 使用 rsync 将原始数据同步到 SSD。请严格注意路径最后的斜杠 /，这在 rsync 中至关重要。


# # -a: 归档模式，保留所有权限、所有者和时间戳信息
# # -v: 显示详细过程
# # -P: 显示进度条并支持断点续传
# sudo rsync -avP /Work_bio/references/ /mnt/ex_8T_SSD/references/
# 注：由于你的目录中包含 Metagenomics 和哺乳动物基因组，这个过程可能会持续较长时间，请耐心等待。

# 第三步：验证数据与重命名原目录
# 同步完成后，先不要急着删除原文件。先将其重命名作为短期备份，同时腾出原来的路径名作为挂载点。


# # 检查 SSD 中的数据是否完整（比对一下大小和文件列表）
ls -lh /mnt/ex_8T_SSD/references/
du -sh /mnt/ex_8T_SSD/references/
du -sh /Work_bio/references/

# # 确认无误后，将原目录重命名为备份目录
sudo mv /Work_bio/references /Work_bio/references_backup

# # 创建一个空的同名目录，作为后续的挂载点（入口）
sudo mkdir /Work_bio/references
# 第四步：执行 Bind Mount
# 现在，我们将 SSD 上的真实数据目录，映射到原先的工作路径上。

# # 执行绑定挂载
sudo mount --bind /mnt/ex_8T_SSD/references /Work_bio/references

# # 验证挂载是否成功（你应该能看到原来的结构了）
ls -l /Work_bio/references
# 第五步：写入 fstab 实现开机自动挂载



# 上述 mount 命令在服务器重启后会失效。为了让这个映射永久生效，需要修改系统的 /etc/fstab 文件。 <<=======================

# 使用你习惯的 vim 打开配置文件：

sudo vim /etc/fstab
# 在文件最末尾添加以下这一行：
/mnt/ex_8T_SSD/references    /Work_bio/references    none    bind    0 0
# (保存并退出 vim：按下 Esc，输入 :wq，然后回车)

# 第六步：最终测试与空间释放
# 最后，验证一下 fstab 语法是否有误，确认无误后就可以删除备份释放空间了。

# # 重新加载所有挂载点，如果不报错说明 fstab 语法正确
sudo mount -a

#  测试你的生信环境或脚本能否正常读取 /Work_bio/references 中的文件

# # 确认一切完美运行后，彻底删除原硬盘上的备份数据以释放空间
sudo rm -rf /Work_bio/references_backup
# 通过这套流程，你的所有生信分析流程、Nextflow 脚本和环境变量都不需要做任何修改，它们会无缝穿过 /Work_bio/references 这个入口，直接享受 8T SSD 带来的高并发读取速度。