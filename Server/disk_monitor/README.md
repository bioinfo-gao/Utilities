# 磁盘空间看门狗

- **创建日期**: 2026-07-23
- **起因**: `ex_8T_SSD`(`/mnt/ex_8T_SSD`,7.3T)夜里被写到 0 字节可用，项目19 的 nextflow 跑到
  "No space left on device" 崩溃，tmux 会话也没了，整整 9.5 小时没人发现（见
  `facilities/Server/disk_migration/` 的应急清理记录）。这个看门狗就是为了不再犯。
- **⚠ 同日更正**：本脚本最初自己现写了 tty广播 + 内联 Python SMTP（复用 `.claude.json` 里
  Claude Code 自己的 Gmail MCP 凭据）——**这是重新发明轮子，而且发明得更差**。`~/.claude/skills/watchdog/`
  早就有一整套经实测标定的方案（`nextflow_watchdog.sh`+`wd_guard.sh`+`wd_sendmail.py`），
  独立 SMTP 凭据（`~/.config/nextflow_watchdog/smtp.env`，专门跟 Claude Code 的 Gmail MCP 凭据
  分开，避免被安全策略拦、避免凭据轮换时静默失效——见 `/watchdog` skill §7 原文），tty 广播用的也是
  同一套 `ps`（不用 `who`）枚举方式。现已改为直接调用现成的 `wd_sendmail.py`，不再自己内联 SMTP。
  **教训：写监控/告警这类基础设施之前，先查 `~/.claude/skills/` 有没有现成方案，别现写。**

## `df -h` 明明还有几百G 差距，怎么可用空间显示 0？（順帶记录的一个技术点）

昨晚崩溃时 `df -h` 显示 `6.9T used / 7.3T total`，看起来还差 ~0.4T，但 `Avail` 那一列却是 **0**。
实测原因：这块盘是 **ext4**，ext4 默认给 root **保留 5% 的块空间**（历史上是防止碎片化、以及保证
root 进程在磁盘"满"时还能写日志救急）。用 `os.statvfs()` 直接量：

```python
import os
st = os.statvfs('/mnt/ex_8T_SSD')
free_root  = st.f_bfree  * st.f_frsize   # root 视角的空闲块
avail_user = st.f_bavail * st.f_frsize   # 普通用户能用的块（df 的 Avail 就是这个）
reserved   = free_root - avail_user      # 差值 = 保留给 root 的部分
```

实测 `reserved ≈ 400.1G`，正好 ≈ 总容量的 5.04%。也就是说 df 那"差的0.4T"**几乎全部落在 root
保留区里**，普通用户（gao）的进程完全用不到，所以 `Avail` 直接显示 0，即使从 root 视角看盘还没
有100%写满。**这不是 bug，是 ext4 的标准设计**——但很容易让人困惑"怎么明明还有空间就写满了"。
`tune2fs -l /dev/sda1` 能看到准确的 reserved-block-count（需要 root 权限，本机当前用户拿不到）。

**同一天验证了第二块盘，证实不是巧合、是本机 ext4 分区的统一默认行为**：`/Work_bio`
（`/dev/sdb1`，9.1T）`df -h` 显示 `7.6T used / 1.1T avail`，表面差值 1.5T，但实测
`reserved ≈ 500.1G`，同样精确等于总容量的 **5.04%**——与 `ex_8T_SSD` 的 5.04% 完全一致。
也就是说本机所有 ext4 分区都遵循这个默认 5% 保留比例，以后碰到"df 算出来的差值对不上"，
先怀疑这个，而不是怀疑数据丢了或者哪里算错。

**看门狗按 `df --output=avail`（即普通用户视角的可用空间）判断阈值，而不是总容量减已用**——
这才是真正决定"我的 nextflow/rsync 进程还能不能继续写"的数字。

## 文件

- `disk_space_watchdog.sh` —— 每次调用做**一次**检查（不是常驻循环），设计成给 cron 定期调用。
  监测 `/mnt/ex_8T_SSD`(阈值200G)、`/Work_bio`(阈值100G)、`/`(阈值50G)——阈值可在脚本里的
  `THRESHOLDS` 关联数组直接改。
- 告警方式（**两条独立通道，都不依赖 agent/Claude session 在跑**）：
  1. **直接写进用户当前所有活跃终端的 tty**（用 `ps -eo tty -u $USER` 枚举，**不用 `who`**——
     `who` 读 utmp 登录记录，IDE（Positron/VS Code）的集成终端不注册 utmp，会漏掉正在用的那个，见
     `nextflow_pipeline/resume缓存失效与空转监控_教训_0716.md` §3.3 的同一个坑）。只有用户当时
     正开着某个终端才能看到。
  2. **`wd_sendmail.py`**（`/home/gao/projects_2026H2/facilities/Server/monitoring_alerting/wd_sendmail.py`）
     ——`/watchdog` skill 自带的独立发信器，凭据在 `~/.config/nextflow_watchdog/smtp.env`
     （chmod 600，不在任何 git repo 里），与 Claude Code 自己的 Gmail MCP 凭据完全分开。
     **真正覆盖夜间/无人值守场景**——不需要用户开着终端，也不需要任何 agent session 在运行。
     实测会同时发到 `zorin.gao@gmail.com` 和 `flyhappyflying@gmail.com` 两个地址。按 mount 加了
     2小时冷却（`EMAIL_COOLDOWN_SEC`，状态存 `.email_cooldown/`），避免同一个问题每15分钟发一封
     邮件轰炸。
  两者都写一份到 `disk_watchdog.log` 留档，但日志本身不是告警——没人盯着看等于没监控。
- **另一个"系统通知"渠道，注意跟上面两条不是一回事**：agent 侧的 `PushNotification` 工具（桌面/手机
  推送）只能由**正在运行的 Claude Code session** 调用，裸的 cron shell 脚本调不了——它适合"我(agent)
  正在场、主动想提醒你"的场景（比如这次盯着磁盘迁移/项目19进度全程都在用这个），**不能替代**本脚本
  自带的这两条通道在完全无人值守时的作用。三条渠道分工不同，不要混为一谈。
- 实测：2026-07-23 手动测试过 tty 广播（成功写到 7 个活跃 pts）和 `wd_sendmail.py` 发信（真实收到，
  同时到两个地址），两条通道都验证过是真的能送达，不是纸面设计。
- **与 `/watchdog` skill 的关系**：`/watchdog` 面向的是单个 pipeline run（nextflow日志停滞/单task过长
  等，规则很具体）；本脚本面向的是更通用的"整机磁盘空间"，两者场景不同、值得分开成独立脚本，但
  **告警投递层（tty广播 + SMTP 发信）复用同一套已验证的机制，不重新发明**。

## 部署

```bash
# crontab 每15分钟跑一次
*/15 * * * * /home/gao/projects_2026M7/facilities/Server/disk_monitor/disk_space_watchdog.sh
```
