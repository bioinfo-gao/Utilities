#!/usr/bin/env python3
"""
wd_sendmail.py —— 看门狗自主发信器（不依赖 agent / MCP / 会话）。

为什么需要它（2026-07-16 proj16 事故的最后一块拼图）：
  tmux 里的看门狗是 bash 脚本，【调不了 MCP 工具】——MCP 只有 agent 能调。
  而 agent 只在用户开着 Claude Code 时存在。于是夜里出事 = 无人知晓（11h 无监控事故的根因之一）。
  终端通知（notify_ttys）虽自主，但要求用户开着终端 —— 睡觉时同样送不到。
  => 唯一能真正覆盖夜间的通道 = 脚本自带 SMTP 凭据直接发信。本脚本即此。

凭据：/home/gao/.config/nextflow_watchdog/smtp.env（chmod 600，【必须】在 git repo 之外——
      projects_2026H2 是 repo，凭据放进去迟早被提交）。本文件本身不含任何密码，可安全入库。

用法：
  wd_sendmail.py <subject> <body-file-or-->      # body 用 '-' 表示从 stdin 读
  echo "正文" | wd_sendmail.py "[告警] xxx" -
环境变量可覆盖 WD_MAIL_TO（逗号分隔）。
退出码：0=成功  1=配置缺失  2=发送失败
"""
import os
import smtplib
import ssl
import sys
from email.message import EmailMessage
from email.utils import formatdate

ENV_FILE = os.environ.get(
    "WD_SMTP_ENV", "/home/gao/.config/nextflow_watchdog/smtp.env"
)


def load_env(path):
    cfg = {}
    try:
        with open(path) as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                cfg[k.strip()] = v.strip()
    except OSError as e:
        print(f"[wd_sendmail] 无法读取凭据 {path}: {e}", file=sys.stderr)
        return None
    return cfg


def main():
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 1
    subject, body_arg = sys.argv[1], sys.argv[2]
    body = sys.stdin.read() if body_arg == "-" else open(body_arg).read()

    cfg = load_env(ENV_FILE)
    if not cfg:
        return 1
    for need in ("WD_SMTP_HOST", "WD_SMTP_PORT", "WD_SMTP_USER", "WD_SMTP_PASS"):
        if not cfg.get(need):
            print(f"[wd_sendmail] 凭据缺字段 {need}", file=sys.stderr)
            return 1

    to = os.environ.get("WD_MAIL_TO") or cfg.get("WD_MAIL_TO", "")
    rcpts = [a.strip() for a in to.split(",") if a.strip()]
    if not rcpts:
        print("[wd_sendmail] 未配置收件人 WD_MAIL_TO", file=sys.stderr)
        return 1

    msg = EmailMessage()
    msg["From"] = cfg["WD_SMTP_USER"]
    msg["To"] = ", ".join(rcpts)
    msg["Subject"] = subject
    msg["Date"] = formatdate(localtime=True)
    msg.set_content(body)

    try:
        with smtplib.SMTP(cfg["WD_SMTP_HOST"], int(cfg["WD_SMTP_PORT"]), timeout=30) as s:
            s.ehlo()
            s.starttls(context=ssl.create_default_context())
            s.ehlo()
            s.login(cfg["WD_SMTP_USER"], cfg["WD_SMTP_PASS"])
            s.send_message(msg)
    except Exception as e:
        # 绝不回显密码；只报异常类型与摘要
        print(f"[wd_sendmail] 发送失败: {type(e).__name__}: {e}", file=sys.stderr)
        return 2
    print(f"[wd_sendmail] 已发送 -> {', '.join(rcpts)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
