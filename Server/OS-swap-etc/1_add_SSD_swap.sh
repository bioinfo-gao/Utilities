sudo fallocate -l 64G /mnt/ex_8T_SSD/swapfile

sudo chmod 600 /mnt/ex_8T_SSD/swapfile

sudo mkswap /mnt/ex_8T_SSD/swapfile 

sudo swapon /mnt/ex_8T_SSD/swapfile

swapon --show 
# NAME                    TYPE SIZE   USED PRIO
# /swapfile               file   2G 772.3M   -2
# /mnt/ex_8T_SSD/swapfile file  64G     0B   -3

# 先关掉
sudo swapoff /mnt/ex_8T_SSD/swapfile
# 重新开启并设置高优先级（比如 10，数字越大优先级越高）
sudo swapon -p 10 /mnt/ex_8T_SSD/swapfile

# swapon --show
# NAME                    TYPE SIZE   USED PRIO
# /swapfile               file   2G 772.2M   -2
# /mnt/ex_8T_SSD/swapfile file  64G     0B   10

sudo sysctl vm.swappiness=10

# 想永久生效，需在
# sudo vim /etc/sysctl.conf 末尾添加 vm.swappiness=10

#  每次你需要跑 12 个 WGS 任务前，手动运行一下 
sudo swapon /mnt/ex_8T_SSD/swapfile 即可