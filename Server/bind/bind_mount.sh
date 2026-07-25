# 长期生产级别的配置，bind mount 确实是最佳选择。


# 1. 准备阶段 - 确认和备份 ==========================
# 查看当前目录结构和大小
ls -la /home/gao/projects_2026H2/
du -sh /home/gao/projects_2026H2/

# 确保目标磁盘有足够空间
df -h /mnt/ex_8T_SSD
# 建议先停止所有可能使用该目录的服务或进程
# 比如关闭 VS Code、停止相关脚本等


# 2. 复制数据到目标位置 ==========================
# 创建目标目录
gsudo mkdir -p /mnt/ex_8T_SSD/projects_2026H2
# 使用 rsync 完整复制（保留所有属性）
sudo rsync -avHAX --progress /home/gao/projects_2026H2/ /mnt/ex_8T_SSD/projects_2026H2/
# 验证复制完整性
sudo diff -r /home/gao/projects_2026H2/ /mnt/ex_8T_SSD/projects_2026H2/


# 3. 临时重命名原目录（安全措施） ====================
# 重命名原目录作为备份
sudo mv /home/gao/projects_2026H2 /home/gao/projects_2026H2_original


# 4. 创建新的挂载点目录 ==========================
# 创建空的挂载点目录
sudo mkdir /home/gao/projects_2026H2
# 设置正确的所有权（重要！）
sudo chown gao:gao /home/gao/projects_2026H2


# 5. 执行临时 bind mount 测试 ==========================
# 执行 bind mount
sudo mount --bind /mnt/ex_8T_SSD/projects_2026H2 /home/gao/projects_2026H2
# 验证挂载是否成功
mount | grep projects_2026H2

# 测试文件访问
ls -la /home/gao/projects_2026H2/
cat /home/gao/projects_2026H2/README.md  # 如果存在的话


# 6. 配置永久挂载（关键步骤） ==========================
# 获取源目录的 UUID（更可靠的方式）
df -h /mnt/ex_8T_SSD

# 编辑 fstab 文件
sudo nano /etc/fstab

# 在文件末尾添加以下行：
/mnt/ex_8T_SSD/projects_2026H2 /home/gao/projects_2026H2 none bind 0 0
# fstab 条目说明：
# 第一列：源目录路径
# 第二列：挂载点路径
# 第三列：文件系统类型设为 none
# 第四列：挂载选项设为 bind
# 第五列：dump 选项设为 0
# 第六列：fsck 顺序设为 0

# 7. 测试 fstab 配置 ==========================
# 测试 fstab 配置是否正确（不实际挂载）
sudo mount -a

# 如果没有错误输出，说明配置正确
# 如果有错误，需要修正 /etc/fstab

# 8. 验证重启后自动挂载 ==========================
# 重新挂载所有 fstab 条目
sudo umount /home/gao/projects_2026H2
sudo mount -a

# 再次验证
mount | grep projects_2026H2
ls /home/gao/projects_2026H2/

# 9. 清理备份（确认一切正常后）=
# 如果所有测试都通过，可以删除原始备份
sudo rm -rf /home/gao/projects_2026H2_original


# 故障排除和回滚方案 ========================
# 如果出现问题需要回滚：
# 卸载 bind mount
# sudo umount /home/gao/projects_2026H2

# # 删除挂载点目录
# sudo rmdir /home/gao/projects_2026H2

# # 恢复原始目录
# sudo mv /home/gao/projects_2026H2_original /home/gao/projects_2026H2

# # 从 /etc/fstab 中删除对应的行
# sudo nano /etc/fstab


# 常见问题处理：
# 问题1：mount: /home/gao/projects_2026H2: mount point is not a directory

# 解决：确保挂载点是一个空目录，不是文件或符号链接
# 问题2：Permission denied 错误

# 解决：确保 /mnt/ex_8T_SSD 的权限允许用户访问，并且挂载点目录的所有权正确
# 问题3：fstab 配置错误导致系统无法启动

# 解决：在启动时进入 recovery mode，编辑 /etc/fstab 修复错误
# 验证清单
# ✅ 数据完整复制
# ✅ 临时 bind mount 测试成功
# ✅ fstab 配置正确
# ✅ mount -a 无错误
# ✅ 重启后自动挂载正常
# ✅ 应用程序访问正常

# 按照这些步骤操作，您就能安全地将 projects_2026H2 目录迁移到更快的 SSD 上，并确保系统重启后自动挂载。记住在每一步都要仔细验证结果！