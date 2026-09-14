# 订阅 vs API balance：什么时候该动那笔 credits

**版本**：2026-09-13 ｜ **作者**：Zhen Gao（与 Claude Opus 5 协作起草）
**定位**：**操作决策文档**。回答一个反复出现的问题 ——
**"暂停订阅、改用 platform.claude.com 的余额跑 Claude Code，划不划算？"**
**不含**：两套计费体系的概念区别（见同目录 [`1_the_2_charging_system.txt`](1_the_2_charging_system.txt)）、
起步期的历史（见 `../Hooks_MCP_Skills_plugin_subAgent_Routines_harness/snapshots/20260616_origin_api_then_subscription.md`）。

**⚠ 同目录的 [`charge.md`](charge.md)（2026-06-18）核心结论已作废** ——
它断言"Claude Code 只能走 API、没有订阅模式"，当天下午就被登录界面证伪。
**以本文与 `1_the_2_charging_system.txt` 为准。**

**标注约定**：
**【实测】** = 本机配置或账单页读到的事实，给了出处；
**【判断】** = 我的推算，可以反对；
**【已过期风险】** = 会随时间变化的数，标了快照日期。

---

## §0 结论先行

**不要为了省钱去暂停订阅换 API。** 按实测强度，**用一天 API ≈ 用一个月订阅**（差 31 倍）。

**那笔余额的正确用途**：留给**订阅覆盖不到的场景** —— Aider、自己写的脚本、SDK 调用。
它到 **2027-06-16** 才过期，不必急着消耗。

## §1 两个账号是分开的，别当成"一个账号两种模式"

| 用途 | 平台 | 账号 |
| :--- | :---: | :---: |
| API credits（余额在这里） | `platform.claude.com` | `zorin.gao` |
| Pro 订阅（Claude Code 日常） | `claude.ai` | `flyhappyflying` |

⇒ 想用那笔 credits 跑 Claude Code，**必须换账号登录**，不是切换模式。
⇒ 两套额度**不能互转、不能合并**（见 `1_the_2_charging_system.txt`）。

## §2 会不会自动烧掉余额？不会【实测】

| 检查项 | 值 | 含义 |
| :--- | :---: | :---: |
| `~/.claude.json › oauthAccount.hasExtraUsageEnabled` | **`False`** | 订阅超额兜底**未开启** |
| 环境变量 `ANTHROPIC_API_KEY` | **未设置** | 没有 key 可供静默回落 |
| 账单页 Auto-reload | **关闭** | 余额见底不会自动续充 |
| 账单页 Monthly spend limit | `$1,000` | 硬上限 |

**⇒ 暂停订阅后 Claude Code 会直接停，不会偷偷去烧 credits。** 切换必须由你手动登录触发。

自查命令：

```bash
python3 -c "import json;a=json.load(open('/home/gao/.claude.json'))['oauthAccount'];\
print({k:a[k] for k in ('organizationType','billingType','hasExtraUsageEnabled')})"
echo "ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:+已设置}${ANTHROPIC_API_KEY:-未设置}"
```

## §3 划不划算：决定性的数【判断，基于 2026-06 实测】

**实测基准**：2026-06-16~18，消耗 **$44.04** credits，产生 **8,252,323** tokens，
折合 **约 2.15 个重度使用日**（两个满负荷日 + 一个 15% 的尾日）。

| | 单价 | 余额 $55.96 能换到 |
| :--- | :---: | :---: |
| **API（按 token）** | **≈ $20.5 / 重度使用日** | **约 2.7 天** |
| **Pro 订阅** | $20 / 月 ≈ $0.67 / 天 | **约 2.8 个月** |

**差 31 倍。**

⚠ **$20.5/日 是上限**：那 $44.04 里混了 6/18 之后 Aider 的用量，无法分离。
真实的 Claude Code 单日成本只会更低，**但量级不变**。

### 3.1 什么情况下换 API 才合理

| 情形 | 判断 |
| :--- | :---: |
| 下月用量剧烈下降（只偶尔问几句，不跑 agentic 长任务） | **可以考虑** |
| 维持现在的用法（管线编排、长会话、多轮 agent） | **绝对不要** |
| 只是想"把余额用掉别浪费" | **不必** —— 还有到 2027-06-16 的时间 |
| 需要 Aider / 脚本 / SDK 调用 | **本来就该走它**，这是余额的正确用途 |

### 3.2 模型是最大的杠杆

$20.5/日 那个数是 **Opus** 的价（本机 `settings.json` 当前 `model: opus`）。
**换小模型能把余额拉长好几倍。** 真要用 API 跑，先改模型再开跑。

## §4 余额快照【已过期风险 —— 快照日 2026-09-13】

| 项 | 值 |
| :--- | :---: |
| 含税实付（2026-06-15） | US$106.25 |
| 到账 credits（税前） | US$100.00 |
| **剩余** | **US$55.96** |
| **到期** | **2027-06-16** |
| 本月已花 | $0.00（重置 Oct 1, 2026 UTC） |

**余额会变，这张表只在快照日成立。** 查当前值：`platform.claude.com` › Billing › Credit balance。

## §5 我不确定 / 需要自行核实的

- **我的模型知识截止 2026-05**，而**登录方式与计费策略正是最容易变的部分**。
  本文关于"能用 Console 账号登录 Claude Code"的机制，依据是
  **2026-06-18 那张登录界面截图**（三个选项：Claude.ai Subscription / Anthropic Console /
  Bedrock, Foundry, or Vertex），**不是从当前官方文档确认的**。
  **真要切换之前，先到 Anthropic 当前文档核一眼。**
- 暂停订阅后账号的**具体行为**（立即停 / 到期末停 / 降级）我没有实测过，未下结论。
- §3 的单价基于**单次、三个月前**的用量，不是持续测量。
