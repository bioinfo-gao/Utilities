# Claude 的三个界面，以及它们怎么联动（含 Remote Control）

**创建**: 2026-09-03
**为什么重要（user 原话）**: 「这三个界面的联动对我的持续工作至关重要。」
**本机环境**: Claude Code 2.1.251 · 登录 `claude.ai` / `flyhappyflying@gmail.com` · **Pro** 订阅 ·
远程 Linux 服务器 + Positron IDE（SSH remote）

> ## ⛔ 当前决定：Remote Control 已关闭，不要照 §3 直接开起来
>
> **2026-09-03 实测跑通后当即关闭**（user 判定：「这是危险设置」）。
> 关闭动作：`tmux kill-session -t cc_remote`。
> **关闭的核实必须两边都做**（服务端 + 遥控端，两个独立来源互证）：
>
> | 来源 | 检查 | 2026-09-03 结果 |
> | :--- | :---: | :---: |
> | 服务端 | `tmux ls \| grep cc_remote` | 无输出 ✓ |
> | 服务端 | `ps -eo pid,args \| grep remote-control \| grep -v grep` | 无输出 ✓ |
> | **遥控端** | **手机浏览器 `claude.ai/code` 列表里还有没有该名字** | **`gao-server` 已消失 ✓** |
>
> **只查服务端不够**：进程没了不等于外部入口立刻失效（已打开的会话页可能仍在缓存里）。
> **遥控端列表里消失，才是"入口确实关闭"的直接证据。**
>
> **本文保留全部操作细节，是因为"怎么做"和"为什么不做"同样值得记录** ——
> 尝试本身有价值：它把三个界面的联动关系问清楚了（§1、§2），
> 那部分**与是否开启 Remote Control 无关，长期有效**。
>
> **§3 起的内容属于"将来若要重开时的操作手册"，不是当前配置。**
> 重开的前提条件见 §5.1。

---

## 1. 三个界面各装什么 —— 这是全文的核心

**它们是三个不同的产品面，各有各的列表，互相看不见对方的内容。**
搞混这一点会导致「在 App 里翻半天找不到会话」，而那其实是必然找不到。

| 入口 | 装的是什么 | 手机 Claude App 的列表里有吗 |
| :--- | :---: | :---: |
| `claude.ai/new`、`claude.ai/chat/*` | 普通 Claude 对话 | ✅ 有 |
| **`claude.ai/code`** | **Claude Code 会话**（终端 / IDE extension / Remote Control，全部在这） | ❌ **没有** |
| `claude.ai/code/artifacts` | 已发布的 artifacts | ❌ 没有 |

**⚠ 最关键的一条：手机 Claude App 的对话列表 = 第一行那个面。**
Claude Code 的会话在第二个面，**App 的列表里永远不会出现**。
2026-09-03 实测：手机 App 里只有 2 条普通对话，而当时服务器上有 3 个 Claude Code 会话在跑。

## 2. 联动关系（2026-09-03 实测）

| 从哪看 | 能看到什么 |
| :--- | :---: |
| 电脑浏览器 `claude.ai/code` | ✅ 与 Positron extension 里的会话**实时同步** |
| **手机浏览器** `claude.ai/code` | ✅ 与上面同一个列表，能看到 Remote Control 会话 |
| 手机 Claude **App** | ❌ 只有普通对话 |
| 本机 `claude agents --json` | 只列**本机**会话，看不到云端 |

**⇒ 手机上要走浏览器，不要走 App。**
建议在手机浏览器里打开 `claude.ai/code` 后**加到主屏幕**
（Safari 分享→添加到主屏幕；Chrome 菜单→添加到主屏幕），
之后一点即进，等同独立 App，绕开 App 列表这个死胡同。

**⚠ App 已登录 ≠ 手机浏览器已登录**，两套登录状态。浏览器第一次进要单独登一次。

## 3. Remote Control —— 什么时候需要它

**不是**为了"远程可见"。IDE extension 的会话本身就在 `claude.ai/code` 里可见、可同步。
Remote Control 的真正价值是**活得比你的笔记本久**：

| 会话类型 | 关掉 IDE / 断开 SSH 之后 |
| :--- | :---: |
| IDE extension 会话 | **随之结束** —— 出门在外它已经不在了 |
| 终端里裸跑的 `claude` | **随 SSH 断开而死** |
| **tmux + `--remote-control`** | **继续活着**，手机随时接上 |

### 启动方式（必须放 tmux）

```bash
tmux new-session -d -s cc_remote -x 200 -y 50 'claude --remote-control=gao-server'
```

- **`-s cc_remote`** 是 tmux 会话名，**`gao-server`** 是遥控端显示名。
- **必须放 tmux**：遥控会话的进程要一直活着，裸跑在 SSH 里断线即死 —— 与跑长任务同理。
- **`-x 200 -y 50`**：给足宽度，否则 TUI 折行、`capture-pane` 读出来的内容难以判读。

### 启动后会卡在「信任目录」确认

```
Quick safety check: Is this a project you created or one you trust?
 ❯ No, exit
   Yes, I trust this folder
```

**默认光标在 "No, exit"**，不处理就一直卡着、遥控不会激活。非交互确认：

```bash
tmux send-keys -t cc_remote Down; sleep 1; tmux send-keys -t cc_remote Enter
```

### 确认真的激活了

```bash
tmux capture-pane -t cc_remote -p | grep -E "remote-control is active|/rc active"
```

应看到：

```
/remote-control is active · Continue here, on your phone, or at
https://claude.ai/code/session_XXXXXXXXXXXXXXXX
```

那个 URL 可直接在手机/电脑浏览器打开，是最可靠的入口（不依赖任何列表）。

## 4. ⚠ 陷阱：本机会话名 ≠ 遥控显示名（2026-09-03 在此连错两次）

```bash
$ claude agents --json
[{ "pid": 3433475, "name": "gao-dd", "status": "idle" }]   # <- 本机名，自动生成
```

而遥控端（手机/网页）显示的是 **`gao-server`**，即 `--remote-control=` 给的那个名字。

| 名字 | 来源 | 在哪能看到 |
| :--- | :---: | :---: |
| `gao-dd` / `gao-61` / `gao-83` | **自动生成**（主机名前缀 + 随机后缀），不可控 | `claude agents`、`ListAgents` |
| **`gao-server`** | `--remote-control=<name>` 指定 | **手机 / 网页的 `claude.ai/code`** |

**教训**：`claude agents --json` **不能**用来验证遥控名字是否生效 —— 它报告的是另一个东西。
当时据此判定"flag 没生效"并反复重启会话，是白折腾。
**要验证遥控名，只能去 `claude.ai/code` 看。**

## 5. 安全与维护（两条必须盯住的）

| 事项 | 面板提示 | 处理 |
| :--- | :---: | :---: |
| 登录过期 | `⚠ Your login expires in N days · run /login to renew` | **过期后遥控直接断**，而那时人多半在外面。提前在 `tmux attach -t cc_remote` 里跑 `/login` |
| 权限模式 | `⏵⏵ bypass permissions on (shift+tab to cycle)` | **默认是绕过权限的**。遥控会话对服务器有完整权限，手机误触没有第二道闸 |

**权限这条特别要当心**：这台机器上有多个客户的 Dropbox 数据和数 TB 项目盘。
`bypass permissions` + 手机端 = 误发一句话就直接执行。
在真正开始用手机遥控之前，进去按 `Shift+Tab` 切到有闸门的档。
**不要**为了少点几下批准就长期开着 bypass。

tmux 内操作完 `Ctrl+B` 再按 `D` 脱离（不要 `exit`，那会结束会话）。

### 5.1 为什么 2026-09-03 当天就关掉了

跑通之后立刻关闭，理由不是"没跑通"，恰恰相反 —— **是跑通之后才看清风险的形状**：

| 风险要素 | 本机实际情况 |
| :--- | :---: |
| 会话权限 | `⏵⏵ bypass permissions on`，**默认就是绕过权限**，工具调用不再二次确认 |
| 能碰到什么 | 本机全部 —— 7 个客户的 Dropbox 数据、5 TB 项目盘、所有 conda env 与 tmux 任务 |
| 触发面 | 手机。**误触、误发、锁屏口袋里的一次点击**，都直接落到服务器上 |
| 兜底 | **没有**。没有二次确认，没有 dry-run，没有撤销 |
| 账号耦合 | 该入口挂在 Claude 账号后面 ⇒ **账号安全 = 服务器安全** |

**关键判断：便利换来的风险不成比例。** 手机上真正需要的多半只是
"长任务跑完没有、有没有报错"，那属于**只读**需求，用通知渠道就能满足
（本机已有 tty / Gmail SMTP / PushNotification 三条），
**不需要给出一个可写、可执行、无闸门的入口**。

### 5.2 将来若要重开，先满足这三条

1. **权限档不能是 bypass。** 起会话后第一件事按 `Shift+Tab` 切到有闸门的档，
   并**在手机上实际试一次**确认确实会弹确认。
2. **登录不能临期。** 先 `/login` 续到足够长，否则人在外面时遥控会断在最需要它的时候。
3. **想清楚到底要"只读"还是"可写"。** 若只是看状态，先用通知渠道，
   **不要**因为"顺手"就开一个可执行入口。

**另外**：`cc_remote` 这个 tmux 会话名不要复用给别的用途，
以后看到它就知道是遥控入口，便于随时确认它是否意外开着：

```bash
tmux ls | grep cc_remote          # 应无输出
ps -eo pid,args | grep remote-control | grep -v grep   # 应无输出
```

## 6. 验证遥控确实连到本机（而不是云端沙箱）

从手机/网页发一句只有本机才答得出的问题，例如：

```
列出 /mnt/ex_8T_SSD/conda_envs 下的目录
```

返回本机特有的内容 = 真的连到这台服务器。
**这一步值得做** —— `--cloud` 起的会话跑在 Anthropic 云端，看不到本机的 conda env、
数据盘和 tmux 任务；两者在界面上不容易分辨。

| | Remote Control | Cloud session (`--cloud`) |
| :--- | :---: | :---: |
| 会话跑在哪 | **本机** | Anthropic 云端 |
| 能访问本机数据盘 / conda env / tmux | ✅ | ❌ |
| 适合本地生信工作 | ✅ | ❌ |

## 7. 速查清单

```bash
# 起遥控会话（放 tmux）
tmux new-session -d -s cc_remote -x 200 -y 50 'claude --remote-control=gao-server'
tmux send-keys -t cc_remote Down; sleep 1; tmux send-keys -t cc_remote Enter   # 信任目录

# 确认激活 + 拿 URL
tmux capture-pane -t cc_remote -p | grep -oE "https://claude.ai/code/session_[A-Za-z0-9]+"

# 进去维护（续登录 / 改权限档）
tmux attach -t cc_remote      # /login ; Shift+Tab ; 然后 Ctrl+B 再按 D 脱离

# 停掉（并核实真的没了）
tmux kill-session -t cc_remote
tmux ls | grep cc_remote                                # 应无输出
ps -eo pid,args | grep remote-control | grep -v grep    # 应无输出

# 日常巡检：确认没有遥控入口意外开着
claude agents --json | python3 -c "import json,sys;[print(a['name']) for a in json.load(sys.stdin)]"
```

**手机侧一次性设置**：手机浏览器开 `claude.ai/code` → 登同一账号 → 加到主屏幕。
