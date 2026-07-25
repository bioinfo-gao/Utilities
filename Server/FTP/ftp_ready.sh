#!/usr/bin/env bash
# =============================================================================
# ftp_ready.sh — sFTP 就绪检查 + 客户登录信息生成器
# 由 /FTP skill 调用（也可手动直接运行）。
#
# 作用：
#   1. 确认 sshd（本机 SFTP 服务端）在跑，没跑就拉起。
#   2. 确认 bore 隧道（内网穿透到 bore.pub）在跑，没跑就拉起。
#   3. 从 journald 读取 bore **当前实际分配的公网端口**（bore 每次重启会随机换端口，
#      所以永远以实时读取为准，不要硬编码）。
#   4. 读取客户账号/密码（存在本地 600 权限的 client_credentials.env 里）。
#   5. 打印一段可直接转发给客户的 SFTP 登录信息。
#
# 部署说明（一次性，供本机维护参考，非客户信息）：
#   - bore 系统服务： /etc/systemd/system/bore.service  (ExecStart=bore local 22 --to bore.pub)
#   - chroot 根目录 ： /srv/external_data/client_sftp   (root:root 755)
#   - 客户上传目录 ： /srv/external_data/client_sftp/files
# =============================================================================
set -uo pipefail

FTP_DIR="/home/gao/projects_2026H2/facilities/FTP"
CRED_FILE="${FTP_DIR}/client_credentials.env"
HOST="bore.pub"
USER_SFTP="client_sftp"
UPLOAD_DIR="/files"

say() { printf '%s\n' "$*"; }

# --- 1. 本机 sshd（SFTP 服务端）-------------------------------------------------
if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
  SSHD_STATE="✅ active"
else
  say ">> sshd 未运行，正在启动 ..."
  sudo systemctl start ssh 2>/dev/null || sudo systemctl start sshd
  systemctl is-active --quiet ssh 2>/dev/null && SSHD_STATE="✅ active (刚启动)" || SSHD_STATE="❌ FAILED — 手动检查: systemctl status ssh"
fi

# --- 2. bore 隧道（内网穿透）----------------------------------------------------
if systemctl is-active --quiet bore 2>/dev/null; then
  BORE_STATE="✅ active (已在运行)"
else
  say ">> bore 隧道未运行，正在启动 ..."
  sudo systemctl start bore
  sleep 2
  systemctl is-active --quiet bore && BORE_STATE="✅ active (刚启动)" || BORE_STATE="❌ FAILED — 手动检查: systemctl status bore"
fi

# --- 3. bore 当前公网端口（实时，从 journald 读最后一次 listening 行）-----------
PORT=$(journalctl -u bore --no-pager 2>/dev/null \
        | grep -oE "listening at ${HOST}:[0-9]+" | tail -1 | grep -oE "[0-9]+$")
if [ -z "${PORT}" ]; then
  PORT="(未知 — 排查: journalctl -u bore | grep 'listening at')"
fi

# --- 4. 客户账号 / 密码 ---------------------------------------------------------
PASSWORD="(未设置)"
CRED_NOTE=""
if [ -f "${CRED_FILE}" ]; then
  # shellcheck disable=SC1090
  source "${CRED_FILE}"
  USER_SFTP="${CLIENT_USER:-$USER_SFTP}"
  if [ -n "${CLIENT_PASSWORD:-}" ] && [ "${CLIENT_PASSWORD}" != "PUT_9_DIGIT_PASSWORD_HERE" ]; then
    PASSWORD="${CLIENT_PASSWORD}"
  else
    CRED_NOTE="⚠️  密码尚未填写：编辑 ${CRED_FILE}，把 CLIENT_PASSWORD 改成真实 9 位密码（该文件已是 600 权限，仅本人可读）。"
  fi
else
  CRED_NOTE="⚠️  未找到凭据文件 ${CRED_FILE} — 请创建并填入 CLIENT_PASSWORD。"
fi

# --- 5. 输出 -------------------------------------------------------------------
say ""
say "──────────────── 服务状态 ────────────────"
say "本机 sshd : ${SSHD_STATE}"
say "bore 隧道 : ${BORE_STATE}"
say "公网端口  : ${PORT}"
say ""
say "──────────── 转发给客户的登录信息 ────────────"
say "协议 Protocol : SFTP  （不是 FTP / FTPS）"
say "主机 Host     : ${HOST}"
say "端口 Port     : ${PORT}"
say "用户 Username : ${USER_SFTP}"
say "密码 Password : ${PASSWORD}"
say "上传目录      : 登录后进入 ${UPLOAD_DIR} 文件夹再上传/下载（根目录不可写）"
say "推荐客户端    : WinSCP / FileZilla / Cyberduck"
say "──────────────────────────────────────────"
[ -n "${CRED_NOTE}" ] && { say ""; say "${CRED_NOTE}"; }
say ""
