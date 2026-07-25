cd /home/gao/projects/2026_Item12_rRNA/scripts
bash 2_command_final_for_rRNA.sh

# 1. 查看当前所有 tmux 会话：
tmux ls
# cho: 1 windows (created Wed Jun 17 01:33:02 2026)
# liftoff: 1 windows (created Fri Jun 12 21:30:35 2026)
# move_refs: 1 windows (created Mon Jun  8 19:16:38 2026)
# rnaseq: 1 windows (created Sat Jun 13 12:52:31 2026)
# star_watcher: 1 windows (created Fri Jun 12 22:59:48 2026)

tmux kill-server                     # Close All Sessions
# tmux kill-session -a                 # Close everything except your current session, 除了最后一个session 
# tmux kill-session -t session_name    # Close a specific session by name

# 2. 连接到 RNA5_rRNA 会话：
tmux attach -t RNA5_rRNA


# 3. 从会话中分离（保持后台运行）：
# 按 Ctrl+B 然后按 D

# 4. 如果需要终止会话：

# 先连接到会话
tmux attach -t RNA5_rRNA
# 然后按 Ctrl+C 终止 Nextflow
# 或者直接杀死会话
tmux kill-session -t RNA5_rRNA


# 查看 Nextflow 进程
ps aux | grep nextflow

# 查看系统资源使用情况
htop

# 我看到 Nextflow 进程正在运行（PID 43816）。现在让我终止它：
# Run in terminal
kill -TERM 43816


# 现在让我确认进程是否已经终止：

# Ran in terminal
# ps aux | grep nextflow | grep -v grep