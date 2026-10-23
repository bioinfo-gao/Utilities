---
name: notify
description: "Use when writing ANY script that needs to alert the user (watchdog, monitor, cron job, long-running task) — the 3 established channels on this machine, ready-to-use, so nobody re-derives/re-tests them from scratch"
disable-model-invocation: true
---

# /notify — 从任意脚本向用户发通知的统一入口

> **本 skill 是速查表，不是新实现。** 三条通道全部已经存在、已经实测过——本 skill 的价值就是
> "别再现写一遍"。写任何 watchdog/monitor/cron 脚本前，先看这里。

## 三条通道，分工不同

| 渠道 | 怎么用 | 需要 agent session 在跑？ | 需要用户开着终端？ |
| :--- | :--- | :---: | :---: |
| **tty 广播** | 见下方代码，`ps` 枚举（**不用 `who`**） | 否 | 是 |
| **`wd_sendmail.py`** | 见下方代码，独立 SMTP 凭据 | 否 | 否 |
| **`PushNotification` 工具** | agent 直接调用（桌面/手机推送） | **是** | 否 |

**裸 shell/python 脚本（cron、tmux 里的看门狗等）只能用前两条。`PushNotification` 只有正在跑的
Claude Code session 自己能调**——它适合"我(agent)现在就在，主动想提醒你"的场景，不能替代前两条
在完全无人值守时的作用。三者不要混为一谈，也别指望裸脚本能调到 `PushNotification`。

## 现成代码

**tty 广播**（不依赖任何凭据，只要用户当时开着终端）：

```bash
alert_ttys() {
  local msg="$1"
  for t in $(ps -eo tty -u "$USER" 2>/dev/null | grep -oE 'pts/[0-9]+' | sort -u); do
    [ -w "/dev/$t" ] || continue
    printf '\n⚠️  %s\n' "$msg" > "/dev/$t" 2>/dev/null
  done
}
```

**发邮件（真正覆盖夜间/无人值守）**——直接调用 `/watchdog` skill 自带的 `wd_sendmail.py`，
**不要自己写 SMTP、不要复用 Claude Code 的 Gmail MCP 凭据**（原因见下）：

```bash
WD_SENDMAIL=/home/gao/Utilities/Server/monitoring_alerting/wd_sendmail.py
echo "邮件正文" | "$WD_SENDMAIL" "邮件标题" -
```

- 凭据在 `~/.config/nextflow_watchdog/smtp.env`（chmod 600，不在任何 git repo 里）。
- 实测会同时发到 `zorin.gao@gmail.com` 和 `flyhappyflying@gmail.com`。
- 退出码：0=成功 1=配置缺失 2=发送失败。

## ⚠ 为什么不能复用 `.claude.json` 里 Claude Code 自己的 Gmail MCP 凭据

即使那份凭据这个 session 里已经在用（比如走 IMAP 写邮件草稿），**也不要**把它抄进一个独立的
监控/告警脚本里当 SMTP 凭据用（2026-07-23 亲自踩过这个坑，见
[[reference_notification_channels]]）：

1. 复用 MCP 凭据给裸脚本发信，可能被安全策略拦下（拦得对，那份凭据的用途范围不包括这个）。
2. 让一个无关的 cron 脚本的可靠性跟 `.claude.json` 耦合——那边凭据一轮换，这边静默失效，
   没有任何报错提示。

`wd_sendmail.py` 的凭据是独立的、可以单独吊销、从不接触 `.claude.json`——这才是正确做法。

## 如果是给一整条 pipeline（nextflow/sarek/…）搭监控

**用 `/watchdog` skill，不要只抄这个 skill 的代码片段。** `/watchdog` 是完整的部署 playbook
（监控目标怎么传、下游编排链怎么覆盖、阈值怎么按项目定、启动前 checklist、已知盲区），本 skill
只是它的告警投递层的一个轻量速查入口。磁盘空间这类"整机级、不针对单个 pipeline"的监控（例子：
`facilities/Server/disk_monitor/disk_space_watchdog.sh`）复用这里的两条通道即可，不需要整套
`/watchdog` 的 pipeline 专用规则（`.nextflow.log` 停滞判定、单 task 超时等）。

## 这个 skill 存在的原因

2026-07-23 写磁盘空间看门狗时，现写了一遍 tty 广播 + 内联 Python SMTP（还用错了凭据来源），
事后发现 `/watchdog` 早就有更完整、更规范的实现。用户明确指出："发通知的几个方法应该固化，
比如skill，早就实现了的不应该反复调研。" 这个 skill 就是那次教训的直接产物——下次任何需要
"从脚本里通知用户"的场景，先看这里，别再重新调研一遍。
