# # 只删除项目外部的缓存文件夹
# rm -rf /home/songz/gaoz/work/01_Junqiang_Ding_0216
# # 重新创建干净的缓存路径
# mkdir -p /home/songz/gaoz/work/01_Junqiang_Ding_0216


#screen -ls
screen -S rnaseq_project 
#screen -d -r rnaseq_project
chmod +x run_conda.sh
./run_conda.sh
chmod +x run_mamba_rnaseq.sh
screen -wipe # 清除所有screen，避免残余脚本干扰后续步骤 

#的唯一功能是：清理那些已经由于某种原因（比如断电、进程崩溃）**已经死掉（Dead）**但还留在列表里的会话记录。
screen -ls  # 确认没有重名的 Mouse_RNAseq_Mamba 还在跑

screen -X -S 3869527 quit
screen -X -S 2961203 quit
screen -X -S 3096898 quit
screen -S Mouse_RNAseq_Mamba
screen -r Mouse_RNAseq_Mamba
./run_mamba_rnaseq.sh


# 在另一个新开窗口
screen -d Mouse_RNAseq_Mamba
./run_mamba_rnaseq.sh -resume


export NXF_OFFLINE=true
bash run_mamba_rnaseq.sh

# 最后的“终极合体”命令（建议直接复制）
# 为了防止再次因为 VS Code 快捷键不灵或者脚本语法微调导致失败，我们现在用最稳妥的办法：直接运行一行不带注释、参数整齐的命令。

# 请在你的普通终端（不需要先开 screen）直接输入以下这一大段：

screen -S Mouse_RNAseq_Mamba bash -c "./run_mamba_rnaseq.sh; exec bash"

这一行的妙处：

# screen -S ...: 创建一个叫 Mouse_RNAseq_Mamba 的窗口。

# bash -c "...": 告诉 screen 运行你的脚本。

# ; exec bash: 这是关键！ 即使你的脚本报错退出了，这个 screen 窗口也会强制保持开启并留在一个 shell 界面，让你能看清报错，而不会直接 terminating（自杀）

# 实时查看 Nextflow 的运行日志
tail -f .nextflow.log
你应该能看到类似这样的动态：

[01/54] 这种百分比在增长。

看到 submitted > ... FASTQC 或 ... STAR。

只要没有新的红色 ERROR 刷屏，一切就在按计划进行


# 有 pigz (更快): 18 core run ======<<<<<<
pigz D8_R1.fastq
# 如果没有 pigz:
gzip D8_R1.fastq

echo $STY #确认是否在 screen 窗口里，哪一个 session

# 1. 启动或进入会话
# 如果你已经在会话里，请忽略这一步；如果退出了，请执行：
screen -r Mouse_RNAseq_Mamba || screen -S Mouse_RNAseq_Mamba
mamba activate R44_RNA
STAR --version # 2.7.10a 这是兼容版本
cd /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216
bash run_mamba_rnaseq.sh 

# 5. 脱离会话（后台运行）
# 看到进度条正常滚动后，按下：
# Ctrl + A ， 然后单独按 D

top
top -c -u songz

pkill -u songz -f nextflow

screen -r Mouse_RNAseq_Mamba || screen -S Mouse_RNAseq_Mamba