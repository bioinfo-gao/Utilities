# ⚠ 2026-09-12 复核：本脚本与实测部署不符，照跑会失败，**保留原样只加本注释**。
#   ① 缺 shim 前缀 PATH=$HOME/.local/claude-science-bin:$PATH ⇒ 会拿到系统 bubblewrap 0.6.1 并拒绝启动
#   ② 端口写的是 8080，而本机部署与全部文档用的是 8000（preview 自动 8001）
#   ③ 路径 projects_2026H2 与当前 projects_2026M7 不一致
#   ④ daemon 本来就常驻，绝大多数时候根本不需要 serve（只需重建 SSH 隧道 + 取一次性登录链接）
#   ⇒ 正确做法见同目录 claude_science_quickstart_20260911.md
#   （要不要删/重写这个文件由用户决定，未经确认不动）

# 1. 启动持久化的终端会话
tmux new -s claude_science

# 2. 进入您的常规工作目录
cd /home/gao/projects_2026H2/

# 3. 激活专门的生信分析环境
mamba activate regular_bioinfo

# 4. 启动 Claude Science 服务 (默认在 8080 端口)
claude-science serve --host 127.0.0.1 --port 8080