#!/bin/bash
# ============================================================================
# nextflow_watchdog.sh — 事件驱动看门狗，监控 1~N 个在 tmux 里跑的 nextflow 作业。
#
# 设计见 facilities/Server/concurrent_nextflow_resource_lessons_0710.md 与 skill /corun。
# 只监控 + 告警，绝不自行 kill/重启（那是需要判断的运维决策，交给人/agent）。
#
# 用法：
#   nextflow_watchdog.sh <SESSION>:<PROJECT_DIR>:<LOGFILE> [ <SESSION>:<PROJECT_DIR>:<LOGFILE> ... ]
# 例：
#   nextflow_watchdog.sh \
#     ellen_sarek:/home/gao/projects_2026H2/13_Ellen_knockin_wgs:/home/gao/projects_2026H2/13_Ellen_knockin_wgs/logs/sarek_run.log \
#     p14_sarek_A:/home/gao/projects_2026H2/14_geneedit_lats12_wgs:/home/gao/projects_2026H2/14_geneedit_lats12_wgs/logs/sarek_A.log
#
# ⚠ 过夜/无人值守必须这样跑（2026-07-16 proj16 事故教训，见下）：
#   tmux new-session -d -s <proj>_watch \
#     'WD_PERSIST=1 bash .../nextflow_watchdog.sh <sess>:<projdir>:<logfile>'
#
# 环境变量（可选）：
#   WD_LOG           巡检流水日志（默认 /tmp/nextflow_watchdog.log）
#   WD_ALERT_LOG     告警日志（默认 <WD_LOG 同目录>/nextflow_watchdog_ALERTS.log）— 异常与流水分离，一眼可见
#   WD_POLL          巡检间隔秒（默认 180）
#   WD_HEARTBEAT     心跳唤醒轮数（默认 30，即 30*180s=90min）
#   WD_LOW_MEM_MB    低内存阈值 MB（默认 2500，连续 2 次触发）
#   WD_STALE_MIN     .nextflow.log 停滞告警阈值 分钟（默认 45；0=禁用）        ← 2026-07-16 新增
#   WD_LOW_LOAD      load 低于此值视为"没在干活"（默认 10；0=禁用）             ← 2026-07-16 新增
#   WD_LOW_LOAD_MIN  低 load 持续多少【分钟】才告警（默认 240=4h，见下方标定说明）
#   WD_MAX_TASK_H    单个 task 运行超过多少【小时】告警（默认 5；0=禁用）       ← 2026-07-16 新增
#   WD_PERSIST       =1 则告警后**继续巡检不退出**（过夜必须；默认 0=沿用旧的退出语义）
#
# 退出码：10=某 session 结束  11=低内存  12=健康心跳  13=nextflow 本体停滞
#         14=CPU 长期空转     15=单 task 超时
#         （均意在触发上层复检；WD_PERSIST=1 时除 SESSION_END 外均不退出）
#
# ---------------------------------------------------------------------------
# 2026-07-16 新增规则 13/14/15 的由来（proj16 事故，净亏 ~15.4h，其中 6.4h 是空转）：
#   `--use_gatk_spark markduplicates` 触发单线程 GATK4_ESTIMATELIBRARYCOMPLEXITY 空转 6h21m，
#   状态是「tmux 会话活着 + 内存充足 + 单线程磨洋工 + ~53 核空转」——
#   **原有 SESSION_END/LOW_MEM/HEARTBEAT 三条规则一条都不命中**。
#   且 HEARTBEAT 时 exit 12 等上层复检，**夜里没有上层 = 等于没监控**（故有 WD_PERSIST）。
#   教训：绝大多数监控只查"死没死"，而最贵的故障是**「活着但空转」**——它不触发任何传统告警。
#
# ⚠⚠ 规则标定（2026-07-16 15:10 实测修正，第一版两条规则【都标定错了】）：
#   1) **`.nextflow.log` 的 mtime 是【存活心跳】，不是【进度信号】**。实测 proj16 ELC 空转的 6.4h 里，
#      nflog 每小时稳定写 24 行（约每 2.5 min 一次），mtime 【从未】变旧 → **STALLED(45min) 在真停滞时
#      永远不会触发**。故 rule 13 的真实作用域**仅限「nextflow 本体死了/挂了」**，不是「流程没进展」。
#      （第一版误以为它能抓停滞、并在教训文档里错写"看门狗只会记下 nflog+300m"——nflog 根本到不了 +300m。）
#   2) **低 load ≠ 故障**。常规 `GATK4_MARKDUPLICATES` 是近单线程、合法运行 ~3.5h/样本，此时 load 仅 ~4-6。
#      第一版 LOW_CPU 阈值设 30min，会对每个正常 markdup 阶段狼来了 → **告警一旦狼来了就等于没有告警**。
#      故 WD_LOW_LOAD_MIN 默认 240min(4h)，**必须长于最长的合法单线程阶段**（markdup 3.5h）。
#   3) 真正能区分「ELC 空转」与「合法 markdup」的只有 **单 task 已运行时长**（前者 6.4h 无界、后者 ~3.5h 有界）
#      → 新增 rule 15 `LONG_TASK`：扫 work/ 下有 `.command.begin` 但无 `.exitcode` 的 task 目录算已运行时长。
#      这条**直接点名是哪个 task 在磨**，是三条里最有用的。
#   详见 facilities/Server/nextflow_pipeline/resume缓存失效与空转监控_教训_0716.md
# ============================================================================
set -uo pipefail
LOG="${WD_LOG:-/tmp/nextflow_watchdog.log}"
ALERT_LOG="${WD_ALERT_LOG:-$(dirname "$LOG")/nextflow_watchdog_ALERTS.log}"
POLL="${WD_POLL:-180}"
HEARTBEAT_POLLS="${WD_HEARTBEAT:-30}"
LOW_MEM_MB="${WD_LOW_MEM_MB:-2500}"
STALE_MIN="${WD_STALE_MIN:-45}"
LOW_LOAD="${WD_LOW_LOAD:-10}"
LOW_LOAD_MIN="${WD_LOW_LOAD_MIN:-240}"       # 默认 4h：必须长于最长合法单线程阶段(markdup ~3.5h)
MAX_TASK_H="${WD_MAX_TASK_H:-5}"             # 单 task 超 5h 告警：markdup 3.5h 放行, ELC 6.4h 命中
PERSIST="${WD_PERSIST:-0}"
LOW_LOAD_POLLS=$(( LOW_LOAD_MIN * 60 / POLL )); [ "$LOW_LOAD_POLLS" -lt 1 ] && LOW_LOAD_POLLS=1
[ "$#" -ge 1 ] || { echo "用法: $0 <session>:<projdir>:<logfile> [...]"; exit 2; }

classify_end() {  # $1=logfile -> COMPLETED|FAILED
  if tail -n 40 "$1" 2>/dev/null | grep -qiE 'Pipeline completed successfully|resume 后完成|完成（无需 resume）|Succeeded'; then
    echo COMPLETED; else echo FAILED; fi
}
# 定向通知【本脚本运行者自己】的所有终端。刻意不用 wall：wall 会广播给机器上所有用户；
# 这里只写 $USER 自己拥有且可写的 tty（含 IDE 集成终端 / tmux pane），不打扰他人。
#
# ⚠⚠ 必须用 `ps` 枚举，【绝不能用 `who`】（2026-07-16 实测教训）：
#   `who` 读的是 utmp【登录会话】记录 —— **IDE（Positron/VS Code）的集成终端不注册 utmp**，
#   ssh 直连以外的 pty 基本都不在里面。实测本机：ps 见 15 个 pts，who 只见 5 个（全是 tmux pane），
#   **漏掉的 10 个里正好包含用户当时真正在用的 Positron 终端 pts/1** → 告警发不到人眼前，
#   而日志里看起来"已发送 5 个终端"一切正常 —— 又一个「看起来成功的静默失败」。
notify_ttys() {  # $1=事件名 $2=详情
  [ "${WD_TTY:-1}" = "1" ] || return 0
  local t u; u="${USER:-$(id -un)}"
  for t in $(ps -eo tty -u "$u" 2>/dev/null | grep -oE 'pts/[0-9]+' | sort -u); do
    [ -w "/dev/$t" ] || continue
    printf '\n\033[1;41;97m 🚨 nextflow watchdog [%s] \033[0m\n%s\n(详见 %s)\n' "$1" "$2" "$ALERT_LOG" > "/dev/$t" 2>/dev/null || true
  done
  command -v tmux >/dev/null 2>&1 && tmux display-message "🚨 watchdog: $1" 2>/dev/null || true
}
# 自主发信（不依赖 agent/MCP/会话）——唯一能覆盖夜间的渠道。
# 凭据在 ~/.config/nextflow_watchdog/smtp.env（600，git repo 之外）；无凭据时静默跳过。
WD_MAILER="${WD_MAILER:-/home/gao/projects_2026H2/facilities/Server/wd_sendmail.py}"
send_mail_alert() {  # $1=事件名 $2=详情
  [ "${WD_MAIL:-1}" = "1" ] || return 0
  [ -x "$WD_MAILER" ] || return 0
  [ -r "${WD_SMTP_ENV:-/home/gao/.config/nextflow_watchdog/smtp.env}" ] || return 0
  {
    printf '看门狗告警\n\n事件: %s\n时间: %s\n主机: %s\n\n详情:\n%s\n\n' \
      "$1" "$(date '+%F %T')" "$(hostname)" "$2"
    printf '当前负载: %s\n可用内存: %s MB\n\n' "$(awk '{print $1,$2,$3}' /proc/loadavg)" "$(free -m | awk '/^Mem:/{print $7}')"
    printf '巡检流水: %s\n告警日志: %s\n\n' "$LOG" "$ALERT_LOG"
    printf -- '--\n本邮件由服务器脚本自主发出(未经 agent/MCP)。\n'
  } | "$WD_MAILER" "🚨[watchdog] $1 — $(hostname)" - >>"$LOG" 2>&1 || \
      echo "[$(date '+%F %T')] ⚠ 邮件发送失败(见上)" >> "$LOG"
}
alert() {  # $1=事件名 $2=详情 ; 落盘 + 定向终端 + 自主邮件
  local ts; ts=$(date '+%F %T')
  echo "[$ts] 🚨 $1 — $2" | tee -a "$ALERT_LOG" >> "$LOG"
  # ⚠ 投递（2026-07-16）：**只写日志文件的告警 = 日记，不是告警**——没人读就等于没发生。
  #   三条渠道的存活性差异（proj16 实测）：
  #     notify_ttys   : 脚本自主，但要求用户【开着终端】——睡觉时送不到
  #     agent Monitor : 需 agent 会话在线 → 夜里失效
  #     send_mail_alert: **脚本自带 SMTP 凭据，唯一真正覆盖夜间的渠道**
  notify_ttys "$1" "$2"
  send_mail_alert "$1" "$2"
}
# 事件处置：PERSIST=1 时告警后继续；否则沿用旧语义退出触发上层复检
handle() {  # $1=事件名 $2=详情 $3=退出码
  alert "$1" "$2"
  [ "$PERSIST" = "1" ] || exit "$3"
}

low_streak=0; poll=0; stale_alerted=0; load_alerted=0
echo "[$(date '+%F %T')] watchdog 启动: $# 个作业, poll=${POLL}s heartbeat=$((HEARTBEAT_POLLS*POLL/60))min persist=${PERSIST} stale>${STALE_MIN}m low_load<${LOW_LOAD}x${LOW_LOAD_POLLS}" >> "$LOG"
while true; do
  poll=$((poll+1)); ts=$(date '+%F %T')
  avail=$(free -m | awk '/^Mem:/{print $7}'); swap=$(free -m | awk '/^Swap:/{print $3}')
  load=$(awk '{printf "%d", $1}' /proc/loadavg)
  line="[$ts] avail=${avail}MB swap=${swap}MB load=${load}"; ended=""; max_age=0
  for spec in "$@"; do
    sess=${spec%%:*}; rest=${spec#*:}; proj=${rest%%:*}; lf=${rest#*:}
    st=UP; tmux has-session -t "$sess" 2>/dev/null || st=GONE
    nl="$proj/.nextflow.log"
    age=$(( ($(date +%s) - $(stat -c %Y "$nl" 2>/dev/null || echo 0)) / 60 ))
    line="$line | $sess:$st nflog+${age}m"
    [ "$st" = UP ] && [ "$age" -gt "$max_age" ] && max_age=$age
    if [ "$st" = GONE ]; then ended="$ended $sess=$(classify_end "$lf")"; fi
  done
  echo "$line" >> "$LOG"

  # --- 10: 某 session 结束（PERSIST 下也退出——没有可监控对象了） ---
  if [ -n "$ended" ]; then
    case "$ended" in *FAILED*) alert "SESSION_END" "$ended —— 无成功标志，需排查" ;;
                     *) echo "[$ts] EVENT=SESSION_END$ended" >> "$LOG" ;; esac
    exit 10
  fi
  # --- 11: 低内存 ---
  if [ "${avail:-999999}" -lt "$LOW_MEM_MB" ]; then low_mem_streak=$(( ${low_mem_streak:-0} + 1 )); else low_mem_streak=0; fi
  if [ "${low_mem_streak:-0}" -ge 2 ]; then handle "LOW_MEM" "avail=${avail}MB —— OOM 风险" 11; low_mem_streak=0; fi

  # --- 13: 流程停滞（.nextflow.log 无 task 事件）=== 2026-07-16 新增 ---
  if [ "$STALE_MIN" -gt 0 ] && [ "$max_age" -ge "$STALE_MIN" ]; then
    if [ "$stale_alerted" -eq 0 ]; then
      stale_alerted=1
      handle "STALLED" ".nextflow.log 已 ${max_age} 分钟无更新（阈值 ${STALE_MIN}m）—— 疑似单任务卡死/空转，查 tmux capture-pane -t <sess> -p | tail -15" 13
    fi
  else stale_alerted=0; fi

  # --- 14: CPU 空转（会话活着但 load 长期低）=== 2026-07-16 新增 ---
  if [ "$LOW_LOAD" -gt 0 ] && [ "$load" -lt "$LOW_LOAD" ]; then low_streak=$((low_streak+1)); else low_streak=0; load_alerted=0; fi
  if [ "$LOW_LOAD" -gt 0 ] && [ "$low_streak" -ge "$LOW_LOAD_POLLS" ] && [ "$load_alerted" -eq 0 ]; then
    load_alerted=1
    handle "LOW_CPU_UTILIZATION" "load=${load} 已持续 $((low_streak*POLL/60)) 分钟低于 ${LOW_LOAD} —— 会话活着但核在空转（ELC 型单线程阻塞？）。这不是'慢'，是设计出了问题，需人工判断" 14
  fi

  # --- 15: 单 task 运行超时 === 2026-07-16 新增；三条里最有用：直接点名是哪个 task 在磨 ---
  # 判据：work/ 下有 .command.begin 但无 .exitcode = 该 task 仍在跑；用 .command.begin 的 mtime 算已运行时长。
  # 这是唯一能区分「ELC 空转 6.4h(无界)」与「markdup 3.5h(有界、合法)」的信号 —— load 和 nflog 都做不到。
  if [ "$MAX_TASK_H" -gt 0 ]; then
    for spec in "$@"; do
      rest=${spec#*:}; proj=${rest%%:*}
      while IFS= read -r b; do
        d=$(dirname "$b"); [ -f "$d/.exitcode" ] && continue
        th=$(( ($(date +%s) - $(stat -c %Y "$b" 2>/dev/null || date +%s)) / 3600 ))
        if [ "$th" -ge "$MAX_TASK_H" ]; then
          nm=$(grep -m1 -oE '^[[:space:]]*task name:.*' "$d/.command.run" 2>/dev/null | cut -c1-80)
          [ -z "$nm" ] && nm=$(basename "$(dirname "$d")")/$(basename "$d")
          key="longtask_$(basename "$d")"
          if [ ! -f "/tmp/.wd_${key}" ]; then
            touch "/tmp/.wd_${key}"
            handle "LONG_TASK" "task 已运行 ${th}h (阈值 ${MAX_TASK_H}h): ${nm} @ ${d} —— 对照该 process 的预期耗时判断是否异常" 15
          fi
        fi
      done < <(find "$proj/work" -maxdepth 3 -name .command.begin 2>/dev/null)
    done
  fi

  # --- 12: 健康心跳（放最后：真事件优先） ---
  if [ "$poll" -ge "$HEARTBEAT_POLLS" ]; then
    echo "[$ts] EVENT=HEARTBEAT_HEALTHY" >> "$LOG"
    [ "$PERSIST" = "1" ] && poll=0 || exit 12
  fi
  sleep "$POLL"
done
