tmux new -s rnaseq -> 运行命令 -> Ctrl+B, D 离开
tmux a # -> 重新进入最近的会话
tmux ls # -> 查看正在运行的会话
tmux attach -t rnaseq # -> 重新进入指定会话
tmux kill-session -t rnaseq # -> 关闭指定会话

# 新建会话：
tmux new -s rnaseq 

# 在会话中挂起 (Detach)：按下快捷键：

# Ctrl + B，然后按 D。(此时你可以安全关闭终端或 VS Code，任务会在后台继续运行) <<<==========

# 查看正在运行的会话：
tmux ls
# 0: 1 windows (created Thu Mar 19 10:50:25 2026)
# 你会看到类似 
# 0: 1 windows (created...) 或者 
# bio_work: 1 windows... 的输出。
# 前面的 0 或 bio_work 就是它的名字。

# # 如果名字是 0
# tmux attach -t 0
tmux attach -t rnaseq

# 重新进入最近的对话：简写（进入最近使用的会话）
tmux a

# Ctrl + B, 然后按 D 只是分离（Detach）了会话，它就像把一个正在播放视频的窗口最小化到了后台，任务依然在跑。
# 如果你想彻底关闭该会话并清除它，有以下几种方法：

# 方法 1：在会话内部输入指令（最简单）如果你还在 tmux 窗口里，直接输入：
exit
# 或者按下快捷键：
# Ctrl + D
# 当看到屏幕显示 [exited] 时，这个会话就彻底消失了。

# 方法 2：在会话外部强制杀死（在普通终端操作）如果你已经按了 Ctrl + B, D 回到了普通命令行  <<<==========
# 你可以通过名字来删除它：先查看会话列表（确认名字）：
tmux ls
# 杀死指定会话（假设名字是 0 或你起的 bio_work）：
bashtmux kill-session -t 0


tmux 命令详解与记忆方法
什么是 tmux？
tmux = Terminal Multiplexer（终端复用器）
它允许你在单个终端窗口中创建多个会话、窗口和面板，即使断开 SSH 连接，程序也能在后台继续运行。
核心概念层级（从大到小）
plain
复制
Session（会话） → Window（窗口） → Pane（面板）
   一个工作场景      一个标签页        分屏区域
常用命令速查
1. 会话管理（Session）
表格
命令	作用
tmux	创建新会话
tmux new -s <name>	创建命名会话
tmux ls	列出所有会话
tmux attach -t <name>	重新连接会话
tmux kill-session -t <name>	关闭指定会话
2. 前缀键（Prefix Key）
默认前缀键：Ctrl + b —— 所有 tmux 命令都要先按这个组合
记忆：Before（先按这个，再按其他）
3. 常用快捷键（先按 Ctrl+b，再按以下键）
表格
快捷键	功能	记忆技巧
d	Detach（分离/退出会话，后台运行）	Detach
c	Create window（创建新窗口）	Create
n	Next window（下一个窗口）	Next
p	Previous window（上一个窗口）	Previous
w	Window list（窗口列表）	Window
%	垂直分割（左右分屏）	% 像两个圈竖着
"	水平分割（上下分屏）	" 横着写
o	切换面板	Other
x	关闭当前面板	像"叉掉"
?	显示所有快捷键	帮助 ?
[	进入滚动/复制模式	向上 [
]	粘贴	向下 ]
记忆口诀
plain
复制
创建会话用 new，列出会话用 ls，
连接会话 attach，分离会话按 d。

窗口操作 c 创建，n 下 p 上 w 列表，
分屏记住百分号，垂直左右双引上下。

所有命令先按 b，就像敲门再进门。
实际使用流程示例
bash
复制
# 1. 创建一个命名会话
tmux new -s myproject

# 2. 在 tmux 中运行程序（比如服务器）
python server.py

# 3. 按 Ctrl+b, 再按 d → 分离会话，程序后台运行

# 4. 之后重新连接
tmux attach -t myproject

# 5. 查看有哪些会话
tmux ls
进阶：修改配置文件
创建 ~/.tmux.conf 可以自定义，比如把前缀键改成 Ctrl+a（更符合肌肉记忆）：
bash
复制
# 修改前缀键为 Ctrl+a
set -g prefix C-a
unbind C-b
bind C-a send-prefix
一句话总结
tmux = 让终端像浏览器一样有标签页，还能分屏，断网也不怕程序中断的超级终端工具！