# 起点（t0）：2026-06-18，第一次把 Claude Code 接上付费订阅

**版本**：2026-09-13 补写 ｜ **作者**：Zhen Gao（与 Claude Opus 5 协作起草）
**定位**：为本目录的快照序列补上**原点**。前三份快照（07-09 / 08-06 / 09-13）记录的是
"有了什么"，这一份记录的是**什么都还没有的那一天**，以及**当时的理解错在哪**。
**不含**：Claude Code 的功能教学（见上级 `0_七大原语对比与实战教学.md`）、当前能力（见 `1_当前能力清单_INVENTORY.md`）。

**标注约定**：
**【实测】** = 本机文件的时间戳与内容，路径已给出，可自行核对；
**【判断】** = 我从证据推出的，可以反对；
**【待确认】** = 只有你本人知道的事实，我查不到，留空等你填。

---

## §0 结论先行

**本机能找到的最早 Claude 痕迹是 2026-06-18 下午**【实测】，当天两小时内完成了
"查计费 → 登录 → 记方法"的全过程。**那一天的能力基线是全零**：
0 skill、0 hook、0 MCP、0 插件、0 自定义 subagent —— 这些概念在本机都还不存在。

⚠ **文件时间戳证明的是"那天在做这件事"，不等于"那天付的钱"。**
实际开通订阅的日期见 §4【待确认】。

## §1 那天的时间轴【实测】

| 时刻 | 文件 | 发生了什么 |
| :--- | :---: | :---: |
| 14:15 | [`agent.ipynb`](../../agent.ipynb) | 最早的一个文件，记 agent 概念 |
| 14:30 | [`Charge_and_fee/charge.md`](../../Charge_and_fee/charge.md) | 搞清计费模式 —— **但结论是错的，见 §2** |
| 16:06<br>（落盘 16:17） | [`use_subscription/Screenshot 2026-06-18 160650.png`](../../use_subscription/Screenshot%202026-06-18%20160650.png) | **Claude Code 首次登录界面**（16:06:50 取自文件名＝拍摄时刻；mtime 16:17＝落盘时刻，跑 §5 的证据命令看到的是后者）：`How do you want to log in?` → `Claude.ai Subscription` / `Anthropic Console` / `Bedrock, Foundry, or Vertex` |
| 16:18 | [`3_method.md`](../../3_method.md) | 开始记使用方法 |
| 16:33–16:35 | [`5_best_practice.md`](../../5_best_practice.md)、[`4_best_practice.md`](../../4_best_practice.md) | 记最佳实践 |

## §2 那天的理解里，哪一条后来被推翻了

**这是本文最有复盘价值的一节。**

`charge.md`（14:30）当时的核心断言【实测，原文可查】：

> 核心结论：没有 100 美元的"包月订阅" …… Anthropic 官方开发的代码工具：
> 即 Claude Code CLI 和 Claude Code for VS Code…… 为什么用 API？
> 因为只有 API 模式，才能绕过网页版的限制。

**同一天 16:06 的登录截图直接推翻了它**【实测】：那个界面的第一个选项就是
`Claude.ai Subscription —— Use your Claude Pro, Team, or Enterprise subscription`。
**"Claude Code 只能走 API"这个判断,在写下它 96 分钟后就被产品界面证伪了。**

定稿版在 40 天后的 [`Charge_and_fee/1_the_2_charging_system.txt`](../../Charge_and_fee/1_the_2_charging_system.txt)（07-26）【实测】：

| | 走哪套体系 | 给谁用 |
| :--- | :---: | :---: |
| claude.ai Pro $20/月 | 订阅额度 | **Claude Code CLI 日常使用**，超额开 Usage Credits 兜底 |
| platform.claude.com API balance | 按 token 计费 | Aider 等第三方调用 |

两套账单**不能互转、不能合并、不能共享**。

**⇒ 复盘启示**【判断】：`charge.md` 至今仍原样留在目录里，**没有任何标注说明它的核心结论已作废**。
一份两个月前就被证伪、却还躺在"参考资料"位置的文档，比没有更危险 ——
下次复盘时若照它做决策，会得出"必须用 API key 跑 Claude Code"的错误结论。
**建议在 `charge.md` 顶部加一行作废声明并指向 `1_the_2_charging_system.txt`**（我没擅自改，等你定）。

## §3 t0 的能力基线

| 类别 | 2026-06-18 | 今天 2026-09-13 |
| :--- | :---: | :---: |
| 个人 skill | 0 | 18 |
| 自定义 hook | 0 | 7 |
| MCP server | 0 | 2 |
| 插件 | 0 | 1（superpowers） |
| 自定义 subagent | 0 | 0 |
| CLAUDE.md | 无 | L0 常驻层 + 9 个任务 skill |

## §4 【待确认】只有你知道的

- 实际**付费开通**日期，以及当时开的是哪一档（Pro / Max / Team）：________
- 2026-06-18 之前是否有过试用或网页版使用期：________
- 06-18 之前用的 Continue 插件 / Aider 走 API 的时期，算不算这条时间线的一部分：________

填上之后这份文档就完整了；在此之前，**§0 的"最早痕迹"措辞不要改写成"开通日"**。

## §5 证据清单

```bash
# 自行核对本文引用的全部时间戳（5 个文件 + 1 张截图）
find -L /home/gao/Utilities/AI_and_Agent/Claude -maxdepth 2 -type f \
  -newermt 2026-06-17 ! -newermt 2026-06-19 -printf '%T+  %p\n' | sort
```
