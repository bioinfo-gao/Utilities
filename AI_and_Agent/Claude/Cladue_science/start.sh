# 1. 启动持久化的终端会话
tmux new -s claude_science

# 2. 进入您的常规工作目录
cd /home/gao/projects_2026H2/

# 3. 激活专门的生信分析环境
mamba activate regular_bioinfo

# 4. 启动 Claude Science 服务 (默认在 8080 端口)
claude-science serve --host 127.0.0.1 --port 8080