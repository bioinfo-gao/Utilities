# tmux 坑

## self-relaunch 脚本里 `tee` 写日志的目录若还不存在，会静默失败

CLAUDE.md 强制的标准 tmux 启动范式——
```bash
tmux new-session -d -s <name> 'cd /path && command 2>&1 | tee log.txt'
```
——有一个隐藏前提：**`log.txt` 所在目录必须在 `tee` 打开文件那一刻就已存在**。如果脚本把
`mkdir -p logs/` 写在被 `tee` 管道包裹的命令**内部**（比如自 relaunch 脚本先在外层 `tee
scripts/../logs/x.log`，再进子进程才 `mkdir -p logs/`），`tee` 会在目录不存在时打印一行
`tee: ...: No such file or directory` 到 stderr，然后**继续把 stdin 透传到 stdout**（tmux pane 里
看得到正常输出），**但那个日志文件永远不会被创建**——不会重试、不会向调用方报错，pipeline 本身
完全不受影响地继续跑。

**为什么危险**：如果有编排器/看门狗依赖 `grep "DONE_MARKER" log.txt` 判断任务是否完成（proj16/17/18
下游编排脚本的标准模式），这个 `log.txt` 永远是空文件或不存在，编排器的等待循环永远等不到匹配，
最终在 tmux session 退出时误判为"跑丢了"，报 FAILURE——**即使实际任务完全成功**。

proj18（2026-07-21）跑 HUMAnN 时实测踩到；Phase-1 主动核实时才发现日志文件不存在，此时损失可忽略
（~1 分钟）；若没有主动核实，会在 ~24h 后被编排器误报。

**How to apply**：
1. 写自 relaunch 包装脚本时，把 `mkdir -p "$(dirname "$LOGFILE")"` 放在**外层 `tee` 命令之前**执行
   （即在 `tmux new-session -d -s ... '...'` 那一整条命令字符串里，`tee` 之前先 `mkdir -p`），不要
   指望脚本内部（re-invoked child）的 `mkdir` 来兜底——那时 `tee` 早已尝试并放弃打开文件。
2. Phase-1 早期核实（CLAUDE.md 已强制的前 3 分钟检查）时，除了 grep 关键字，**顺手 `ls -la` 一下日志
   文件本身是否存在/在长大**，不要假设"tmux pane 有输出 = 日志文件在正常写"。
3. 万一已经在跑且发现日志缺失，**不必杀会话重启**——用
   `tmux pipe-pane -t <session> -o "cat >> logfile"` 把从此刻起的 pane 输出接进日志文件，不打扰正在
   跑的进程；缺的只是启动那几行，不影响后续的完成标记能否被抓到。
