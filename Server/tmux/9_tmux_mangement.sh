
# list tmux env
tmux list-sessions 2>/dev/null || echo "No tmux sessions found"

# list tmux sessions
for session in $(tmux list-sessions -F '#{session_name}' 2>/dev/null); do echo "=== Session: $session ==="; tmux list-panes -t "$session" -F '#{pane_pid} #{pane_active} #{pane_current_command}' 2>/dev/null; done

# Method 1: Check for Active Processes in Each Session
# list tmux sessions and panes 
for session in $(tmux list-sessions -F '#{session_name}' 2>/dev/null); do 
    echo "=== Session: $session ==="
    tmux list-panes -t "$session" -F '#{pane_pid} #{pane_active} #{pane_current_command}'
done

# Look for any processes that aren't just bash, zsh, or your shell. If you see commands like python, R, samtools, bwa, etc., those sessions have active jobs.

# Method 2: Check CPU/Memory Usage# List all processes in tmux sessions with their resource usage
ps aux | grep -E "(tmux|$(tmux list-panes -F '#{pane_pid}' 2>/dev/null | tr '\n' '|'))" | grep -v grep

# A tmux session is "at rest" when:

# The current command in each pane is just your shell (bash, zsh, etc.)
# No CPU/memory intensive processes are running
# You haven't started any long-running commands that are still executing


# 删除所有 tmux session；是否允许我提升权限直接终止 tmux server 以清空全部 session？
tmux kill-server

# 发现 6 个 tmux session。我现在全部终止，并做一次确认。

# Background terminal finished with tmux kill-server
# tmux server 已终止，我再核对一次当前是否还有残留 session。
# Background terminal finished with tmux ls

# Worked for 10m 46s
# 已清空所有 tmux session。
# 原有的 session 是 6, RNA2, RNA3, RNA4, RNA5, rnaseq，我执行了 tmux kill-server。现在检查结果是 no server running on /tmp/tmux-1001/default，说明已经没有 tmux server 和 session 了