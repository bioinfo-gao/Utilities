---
name: video2doc
description: "Use when 用户给一个视频链接(B站/YouTube 等)要整理成结构化中文学习文档"
disable-model-invocation: true
---

# /video2doc — 视频/播客 → 结构化学习文档

把一个在线视频(B站 / YouTube 等)的**口播内容**整理成一份结构化的中文学习文档。
适用:教程、实测、讲座类视频,想留成可检索的文字笔记。

流程:**优先取字幕 → 取不到则下音频 + faster-whisper 转录 → 清洗同音错字 → 按视频结构成文**。

---

## 何时用 / 不用

- **用**:用户给一个视频链接,要"整理成文档/笔记/总结含操作步骤"。
- **不用**:只需要标题/简介概括(直接 WebFetch 即可,别转录);或视频本身没有实质口播(纯音乐/演示无解说)。

---

## 环境

- conda 环境 `regular_bioinfo`(已装 `yt-dlp`、`ffmpeg`、`faster-whisper`;缺了就按第 1 步补)。
- 转录**必须在 tmux 里跑**(11 分钟视频 ≈ 13 分钟 CPU 转录),别用 Bash 后台模式。
- 临时文件放 scratchpad,不要污染项目目录。

---

## 第 0 步:先确认能不能直接拿字幕(字幕优先于转录!)

字幕比 ASR 更准更快,永远先试。但注意关键坑:

```bash
conda run -n regular_bioinfo yt-dlp --list-subs "<URL>"
```

| 情况 | 处理 |
| :--- | :--- |
| 列出真实字幕轨(如 `zh-Hans`、`ai-zh`、`en`) | 直接下:`yt-dlp --write-subs --sub-langs "<lang>" --skip-download --convert-subs srt -o sub.%(ext)s "<URL>"`,跳到第 4 步 |
| **只有 `danmaku`(B站)** | B站 AI 字幕**需登录态**才下发。**本机是远程服务器,chrome 未登录 B站**,`--cookies-from-browser chrome` 也只回弹幕 → **字幕这条路走不通,转 whisper**(见下) |
| YouTube 有 `auto`/人工字幕 | 一般能直接下,优先用 |

> ⚠️ 若用户坚持"视频有字幕",解释清楚:他在自己电脑浏览器登录能看到,但**这台服务器没有他的 B站登录 cookie**。要用官方字幕就需他提供 `SESSDATA` cookie;否则 whisper 转录效果通常不比 B站自动字幕差。

---

## 第 1 步:装工具(缺才装,幂等)

```bash
mamba install -n regular_bioinfo -c conda-forge -y yt-dlp ffmpeg
conda run -n regular_bioinfo pip install -q faster-whisper
```

---

## 第 2 步:下音频

```bash
cd <scratchpad>
conda run -n regular_bioinfo yt-dlp -f bestaudio -x --audio-format mp3 \
  -o "audio.%(ext)s" "<URL>"
```

> B站高码率/4K 需大会员,但 `bestaudio` 的普通音质足够转录,无需 cookie。

---

## 第 3 步:转录(faster-whisper,CPU int8,tmux)

**模型/设备选择:**
- 默认 **`medium`**(中文技术内容准确度足够,CPU int8 约 1.2× 实时)。要更准可换 `large-v3`(慢得多)。
- 本机 GPU 仅 GTX 1060 3GB,large 装不下 → **默认走 CPU**,稳。
- `language="zh"`(或按视频语言),`vad_filter=True` 去静音,`cpu_threads=16`。

转录脚本 `transcribe.py`(逐段写盘,便于监控进度):

```python
import time
from faster_whisper import WhisperModel
AUDIO, OUT, MODEL = "audio.mp3", "transcript.txt", "medium"
t0 = time.time()
model = WhisperModel(MODEL, device="cpu", compute_type="int8", cpu_threads=16)
segments, info = model.transcribe(AUDIO, language="zh", beam_size=5, vad_filter=True)
print(f"dur={info.duration:.0f}s", flush=True)
with open(OUT, "w", encoding="utf-8") as f:
    for seg in segments:
        f.write(f"[{seg.start:6.1f}-{seg.end:6.1f}] {seg.text.strip()}\n"); f.flush()
print(f"DONE_TRANSCRIBE in {time.time()-t0:.0f}s", flush=True)
```

启动 + 监控:

```bash
tmux new-session -d -s v2doc "cd <scratchpad> && conda run -n regular_bioinfo python transcribe.py 2>&1 | tee transcribe.log"
```

> ⚠️ **坑:`conda run ... | tee` 会缓冲 stdout,日志在跑完前是空的**——别据此判断卡死。
> **改看输出文件本身**:`tail -n1 transcript.txt` 的时间戳 vs `info.duration`,以及 `pgrep -f transcribe.py`。
> 完成信号:进程退出 且 `transcript.txt` 末段时间戳 ≈ 视频总时长(或 log 出现 `DONE_TRANSCRIBE`)。

---

## 第 4 步:清洗 + 成文

- **ASR 必然把专有名词转成同音错字,务必逐一订正**(结合视频主题/官方文档判断)。本类视频常见:
  Coder/quadr→**Qoder**,加挖→**Java**,Mabatis→**MyBatis**,longbook→**Lombok**,
  navcad→**Navicat**,springboard→**Spring Boot**,type键→**Tab键**,Copiler→**Copilot**,美文→**Maven**。
- 按**视频自身结构**组织文档(背景 → 安装 → 配置 → 各实测 → 价格 → 总评),不要照抄逐句流水账。
- 文档头注明:来源视频(标题/UP/BV号/时长/日期)、"经 whisper 转录清洗"、整理日期。
- 遵守全局表格规范(首列 `:---` 左对齐,其余 `:---:` 居中)。
- **失效信息标注**:促销/活动/价格等时效内容,写明"仅作记录,以官方最新为准"。

---

## 第 5 步:落盘

- AI/agent 类学习内容 → `/home/gao/projects_2026H2/facilities/AI_and_Agent/<按工具的子文件夹>/`
  (见记忆 `feedback-ai-agent-learning-location`)。其他主题放对应项目目录。
- 同时把**原始转录稿**(`*_原始转录.txt`)拷到同目录留档,供日后核对(它与成文文档用途不同:一个是源、一个是成品,不算重复)。

---

## 速查:坑清单

| 坑 | 规避 |
| :--- | :--- |
| B站只回 danmaku,以为没内容 | 是登录墙,不是没内容;走 whisper |
| `conda run \| tee` 日志空 | 监控输出文件,别看 log |
| 用 large 模型爆显存 | 默认 CPU + medium |
| ASR 专有名词错字 | 成文前必须结合主题订正 |
| 转录跑太久占着终端 | 放 tmux,后台 `pgrep` 轮询 |
