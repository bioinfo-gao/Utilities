# 复制所有内容从备份到 SSD（注意结尾的斜杠）
sudo cp -r /home/gao/projects_2026H2_original/. /mnt/ex_8T_SSD/

# 或者  使用 rsync（更可靠，显示进度）
sudo rsync -av --progress /home/gao/projects_2026H2_original/ /mnt/ex_8T_SSD/



# 设置所有权给 gao 用户
sudo chown -R gao:gao /mnt/ex_8T_SSD/

# 设置适当权限  
sudo chmod -R 755 /mnt/ex_8T_SSD/

# 获取 UUID
sudo blkid /dev/sda1

# 编辑 fstab
sudo vim /etc/fstab
# UUID=9b82a71c-294e-4c03-9a5f-dba89d4e52da /mnt/ex_8T_SSD ext4 defaults 0 2

# 测试 fstab
sudo umount /mnt/ex_8T_SSD
sudo mount -a

# 验证
df -h /mnt/ex_8T_SSD


# Bind Mount 配置步骤
# 1. 首先确认数据位置
# 检查 SSD 上是否有 projects_2026H2 目录
ls -la /mnt/ex_8T_SSD/

# 确保原位置是空目录（如果不是，先重命名）
sudo mv /home/gao/projects_2026H2 /home/gao/projects_2026H2_temp

# 创建新的挂载点
sudo mkdir /home/gao/projects_2026H2
sudo chown gao:gao /home/gao/projects_2026H2

# 4. 执行临时 bind mount 测试
# 执行 bind mount
sudo mount --bind /mnt/ex_8T_SSD/projects_2026H2 /home/gao/projects_2026H2

# 验证
ls -la /home/gao/projects_2026H2/
mount | grep projects_2026H2

# 5. 配置永久 bind mount
# 编辑 fstab 使用 vim
sudo vim /etc/fstab
# 在 /etc/fstab 中添加这一行：
# /mnt/ex_8T_SSD/projects_2026H2 /home/gao/projects_2026H2 none bind 0 0

6. 测试配置
# 测试 fstab 配置
sudo umount /home/gao/projects_2026H2
sudo mount -a

# 验证一切正常
ls -la /home/gao/projects_2026H2/
df -h /home/gao/projects_2026H2/ # 测试 fstab 配置

# 在 家目录 ls 的时候，看不到 projects_2026H2 真实位置在SSD上
# 这是完全正常的现象！这正是 bind mount 的设计优势。

# 为什么看不到真实位置？
# Bind Mount 的工作原理
# Bind mount 对应用程序和用户完全透明
# 从文件系统角度看，/home/gao/projects_2026H2 就是 /dev/sda1 上的数据
# ls 命令无法区分这是原始目录还是 bind mount
# 验证数据确实在 SSD 上的方法

# 方法1: 查看挂载信息
mount | grep projects_2026H2
# 输出: /dev/sda1 on /home/gao/projects_2026H2 type ext4

# 方法2: 检查磁盘使用情况
df -h /home/gao/projects_2026H2
# 应该显示 /dev/sda1 的使用情况

# 方法3: 检查 inode 信息
stat /home/gao/projects_2026H2
# Device 字段会显示 sda1 的设备号

# f -h /home/gao/projects_2026H2
# Filesystem      Size  Used Avail Use% Mounted on
# /dev/sda1       7.3T  3.8M  6.9T   1% /home/gao/projects_2026H2
# (regular_bioinfo) [20:41:33] [/home/gao]:
# gao@us1 $ stat /hostat /home/gao/projects_2026H2
#   File: /home/gao/projects_2026H2
#   Size: 4096            Blocks: 8          IO Block: 4096   directory
# Device: 8,1     Inode: 111542273   Links: 6
# Access: (0775/drwxrwxr-x)  Uid: ( 1001/     gao)   Gid: ( 1001/     gao)
# Access: 2026-06-06 20:32:19.316143289 -0400
# Modify: 2026-06-06 20:29:32.473502212 -0400
# Change: 2026-06-06 20:30:25.793390063 -0400