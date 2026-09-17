# 机器学习（三）：LLM 工程层 —— 把大语言模型接进脚本，怎么装、怎么控、多少钱

> 建立日期：2026-09-17
> **本篇只讲工程。** "LLM 能不能做细胞类型注释""通路解读可不可信"这类**生物学判定不在这里**，
> 见 `/home/gao/Utilities/Bioinfo/single_cell_and_spatial/AI_in_singlecell_and_spatial_{1,2,3}_*.md` 三篇。
> 本目录另两篇：[①监督学习与评估纪律](1_supervised_learning_and_evaluation_discipline.md) · [②表示学习与深度框架](2_representation_learning_and_dl_frameworks.md)
> **API 形状与模型表来自 `claude-api` 参考（缓存日期 2026-06-24），不是凭记忆写的** —— 这个领域漂移很快，见 §2.4。

---

## §0 结论先行

| # | 结论 | 出处 |
| :--- | :---: | :---: |
| **1** | **默认走云 API，不要本地跑大模型。** 本地模型的正确定位是"隐私/离线/批量便宜"，不是"效果更好" | §4 |
| **2** | **要机器可读的输出，就用 structured outputs，不要在 prompt 里祈祷它输出 JSON** | §3 |
| **3** | **prompt caching 是最大的免费省钱手段**，但它是**前缀匹配**：把稳定内容放前面，变动内容放后面 | §5 |
| **4** | **数 token 用 `messages.count_tokens`，不要用 `tiktoken`** —— 那是另一家的分词器，数出来的值不对 | §6 |
| **5** | **不赶时间的批量任务走 Batch API，成本直接砍一半** | §5.3 |
| **6** | 🔴 **LLM 的错误几乎全部是"HTTP 200 + 内容是错的"** —— 没有异常、没有告警、格式完全合法 | §7 |
| **7** | 本机**一个 LLM SDK 都没装**；唯一存在的 `tiktoken` 是 **MultiQC 带进来的**，与你无关 | §8 |

### 🔴 一句话

> **LLM 调用的失败模式和生信管线完全不同：管线失败会崩，LLM 失败会给你一段
> 语法正确、格式合法、读起来很专业的错误答案。** 所有工程措施都是围绕这一条设计的。

---

## §1 三条路线：先选对形态，再谈代码

| 路线 | 什么时候选 | 代价 |
| :--- | :---: | :---: |
| **① 云 API**（Anthropic / 其它厂商的 SDK） | **默认**。能力最强、不占本地资源、无需运维 | 按 token 计费；数据出本机 |
| **② 本地权重**（transformers / llama.cpp / Ollama） | 数据不能出本机、要离线、要极大批量 | 显存受限（见 §4），效果与云端有明显差距 |
| **③ 托管 agent / Claude Code** | 要"跑一个会用工具的循环"，而不是"问一句答一句" | 见 §9 |

**⚠ 客户数据的判定**：任何要把客户序列、客户表型或未发表数据发出本机的操作，
**都属于对外行为**，按公司规矩只准备、不擅自发送。**需要逐案确认，不要默认可以。**
这一条比任何技术选型都靠前。

---

## §2 云 API：只需要记住的那几件事

### §2.1 模型与价格（来源：`claude-api` 参考，缓存 2026-06-24）

| 模型 | model id | 上下文 | 输入 $/1M token | 输出 $/1M token |
| :--- | :---: | :---: | :---: | :---: |
| Claude Fable 5.1 | `claude-fable-5-1` | 1M | $10.00 | $50.00 |
| **Claude Opus 5** | **`claude-opus-5`** | **1M** | **$5.00** | **$25.00** |
| Claude Sonnet 5 | `claude-sonnet-5` | 1M | $2.00 | $10.00 |
| Claude Haiku 4.5 | `claude-haiku-4-5` | 200K | $1.00 | $5.00 |

**默认用 `claude-opus-5`。** 便宜模型（Sonnet / Haiku）留给
**大批量、低判断力要求**的子任务（比如给一万条记录做粗分类）。
**⚠ model id 就是上表那个字符串，不要自己往后面接日期后缀。**

### §2.2 一个最小调用（Python）

```python
from anthropic import Anthropic          # 本机未装，见 §8

client = Anthropic()                      # 读 ANTHROPIC_API_KEY，或读 ant auth login 的 profile
resp = client.messages.create(
    model="claude-opus-5",
    max_tokens=16000,                     # 非流式的合理默认；别给小了，会被截断
    thinking={"type": "adaptive"},        # 复杂任务默认开
    output_config={"effort": "high"},     # low / medium / high / xhigh / max，默认 high
    messages=[{"role": "user", "content": "..."}],
)
print(resp.content[0].text)
```

**长输入 / 长输出 / 大 `max_tokens` 一律用流式**（`client.messages.stream(...)` +
`.get_final_message()`），否则会撞 HTTP 超时。流式时 `max_tokens` 可以给到 64000 量级。

### §2.3 两个控制旋钮

| 旋钮 | 写法 | 作用 |
| :--- | :---: | :---: |
| **thinking（思考）** | `thinking={"type": "adaptive"}` | 让模型自己决定想多久。复杂任务默认开 |
| **effort（用力程度）** | `output_config={"effort": "..."}` | `low`/`medium`/`high`/`xhigh`/`max`，默认 `high`。**这是第一个该调的省钱旋钮** |

**调 effort 的判据**：常规问答、分类、高并发场景往往 `low`/`medium` 就够；
需要正确性的推理任务用 `high` 起步。**先在真实样本上测，再改默认值**，不要凭感觉全局调。

### §2.4 🔴 这个领域漂移很快，我的记忆不可靠

写 LLM 代码前**必须查当前文档**，不要凭印象。已知的几个漂移点：

| 旧写法（我的记忆里有） | 现在 |
| :--- | :---: |
| `thinking={"type":"enabled", "budget_tokens": N}` | **在当前模型上返回 400**；改用 `{"type":"adaptive"}` |
| `output_format=...` | 已废弃；改用 `output_config={"format": {...}}` |
| assistant 消息 prefill（预填开头） | **当前模型一律 400** |
| `client.beta.files.*` / `client.beta.skills.*` | 已转正：`client.files.*` / `client.skills.*` |

**⇒ 这就是为什么本篇的 API 形状全部标了来源和日期。**

---

## §3 结构化输出：把 LLM 接进流程的唯一可靠方式

**问题**：你想让它返回 `{"cell_type": "...", "confidence": 0.8}`，
但 prompt 里写"请只返回 JSON"**不是保证**——它有时会加一句"当然！这是你要的 JSON："，
于是 `json.loads()` 崩掉；更糟的是它返回了**合法但字段名不同**的 JSON，
`json.loads()` 不崩，**下游静默拿到 `None`**。

**✅ 正确做法**：用 structured outputs 让 API 层面强制 schema。

```python
resp = client.messages.parse(              # 推荐入口：自动按 schema 校验
    model="claude-opus-5",
    max_tokens=4096,
    output_config={"format": {...}},        # JSON schema
    messages=[...],
)
```

给**工具（tool）**加 `strict: true`（写在工具定义的顶层，不是写在 `tool_choice` 里），
并要求 schema 带 `additionalProperties: false` 和 `required`，
就能保证工具入参严格符合 schema。

**⚠ 即使有 schema，值仍然可能是错的。** schema 保证的是**形状**，不是**内容**：
`{"gene": "TP53"}` 和 `{"gene": "TPS3"}` 都合法。**内容层面的校验必须你自己写**——
比如"返回的基因名必须存在于我给的候选列表里"，这正是 `AI_in_singlecell_3` §6 那套
"给定候选集 + 表外出现即判失败"的工程实现。

---

## §4 本地模型：6 GB 显存能跑什么

**定位**：本地模型是为了**隐私、离线、极大批量**，**不是为了效果**。
需要判断力的任务不要指望本地小模型。

| 想做的事 | 6 GB（笔记本 RTX 3060） | 说明 |
| :--- | :---: | :---: |
| 7B 模型 **4-bit 量化推理** | ⚠ 能跑但紧（权重约 4–5 GB） | 上下文一长就爆显存 |
| 1–3B 模型 **QLoRA 微调** | ✅ 甜点区 | 见第②篇 §3.4 |
| **句向量 / embedding**（sentence-transformers 之类） | ✅ 轻松 | 这是本地模型最实用的用途 |
| 13B+ 任何形式 | ❌ | — |

**⇒ 实务建议**：本地只跑 **embedding 模型**（小、快、效果与云端差距不大），
**生成任务走云 API**。这个分工在 6 GB 上最划算。

**⚠ 服务器（GTX 1060）跑不了任何本地模型**——见第②篇 §3.1，torch 在那台机器上是 CPU-only。

---

## §5 省钱：顺序固定，先做免费的

### §5.1 prompt caching（提示词缓存）—— 第一优先

**机制是前缀匹配（prefix match）**：渲染顺序是 `tools` → `system` → `messages`，
**前缀里任何一个字节变了，后面全部失效**。

| 做法 | 说明 |
| :--- | :---: |
| ✅ 稳定内容放最前面 | 固定的 system prompt、固定的工具列表、固定的参考资料 |
| ✅ 变动内容放最后面 | 时间戳、每次不同的问题、每条记录的数据 |
| ❌ system prompt 里放 `datetime.now()` | **每次都miss**，而且完全不报错 |
| ❌ 工具列表顺序不固定（如来自 `set`） | 同上 |

**验证方法（必须做）**：看 `usage.cache_read_input_tokens`。
**重复请求时它如果一直是 0，就说明有个静默的失效源**，去前缀里找。
最多 4 个缓存断点；前缀太短（几百 token 级别）**不会缓存且不报错**。

### §5.2 effort

见 §2.3。**免费手段做完再动它**，因为它会牺牲质量。

### §5.3 Batch API —— 不赶时间就砍一半

```python
batch = client.messages.batches.create(requests=[
    {"custom_id": "sample_01", "params": {...}},
    ...
])
# 轮询 client.messages.batches.retrieve(id).processing_status == "ended"
```

**🔴 结果顺序是任意的，必须按 `custom_id` 对齐，绝不能按位置。**
这条和生信里"合并样本必须按 ID 不按顺序"是同一个错误模式
（参见 `20.Notes_by_ZG/Python_core_modules_for_bioinformatics.md` §9 的 pandas merge 条）。

### §5.4 省钱的优先级

| 顺序 | 手段 | 牺牲质量吗 |
| :--- | :---: | :---: |
| ① | prompt caching | 否 |
| ② | 减少无用输入 token（别把整个文件塞进去） | 否 |
| ③ | Batch API | 否（只牺牲时效） |
| ④ | 降 effort | **是** |
| ⑤ | 换便宜模型 | **是** |

**判据是"每个完成的任务花多少钱"，不是"每次请求花多少钱"** ——
便宜模型如果要来回三轮才做对，并不便宜。

---

## §6 🔴 数 token：不要用 `tiktoken`

```python
n = client.messages.count_tokens(
    model="claude-opus-5",
    messages=[{"role": "user", "content": text}],
).input_tokens
```

**`tiktoken` 是另一家模型的分词器**，用它去估 Claude 的 token 数会系统性偏差。
**本机 `regular_bioinfo` 里确实有 `tiktoken 0.12.0`，但它是 MultiQC 1.33 的依赖**
（MultiQC 自带 AI 摘要功能），**不是给你用的**，更不能拿来数 Claude 的 token。

---

## §7 🔴 静默陷阱清单：LLM 的错误几乎都是 HTTP 200

| # | 陷阱 | 报错？ | 后果 |
| :--- | :---: | :---: | :---: |
| 1 | **幻觉**：编造出格式完美、听起来专业的内容 | **否** | 基因名、通路名、文献引用都可能是编的 |
| 2 | 输出被 `max_tokens` 截断 | **否**（`stop_reason` 会说，但你得去看） | JSON 断在一半，或结论缺了最后一段 |
| 3 | 只读 `content` 不看 `stop_reason` | **否** | 拒答（`refusal`）时 `content` 可能是空的 |
| 4 | prompt cache 静默失效 | **否** | 账单翻几倍，功能完全正常 |
| 5 | 用 `tiktoken` 估算 Claude token | **否** | 预算算错 |
| 6 | 批处理结果按位置对齐 | **否** | 样本与结果错位，**全部结论错但看不出来** |
| 7 | 让 LLM "自己判断有没有把握" | **否** | 自评置信度与实际正确率相关性很弱 |
| 8 | 同一 prompt 多次结果不同就多跑几次挑好的 | **否** | 这是 p-hacking 的 LLM 版 |
| 9 | 把 LLM 输出直接写进报告不留痕 | **否** | 无法追溯哪句是模型说的 |
| 10 | 在 prompt 里塞进不该外发的数据 | **否** | 合规问题，且发出去就收不回 |

> **第 1、7、8 条是同一件事**：**LLM 没有"我不知道"这个默认行为。**
> 工程上唯一的解法是 **§3 的给定候选集 + 表外即失败**，以及
> **把"必须出现什么"写成断言**（与第②篇 §6 的阳性对照断言同一思路）。

**⇒ 铁律**：LLM 的输出在任何文档里**都要标注为模型产物，不是观测**。
因果断言、阴性结论、文献引用**绝不交给它**（见 `AI_in_singlecell_3` §4）。

---

## §8 本机实测（2026-09-17）：LLM 相关包一个都没装

| 包 | `regular_bioinfo` | `sc_tut_main` | 其它三个 env |
| :--- | :---: | :---: | :---: |
| `anthropic`（官方 SDK） | ❌ | ❌ | ❌ |
| `openai` | ❌ | ❌ | ❌ |
| `transformers` | ❌ | ❌ | ❌ |
| `sentence-transformers` | ❌ | ❌ | ❌ |
| `tiktoken` | **0.12.0** | ❌ | ❌ |
| `tokenizers` | **0.23.1** | ❌ | ❌ |

**`tiktoken` / `tokenizers` 的来源已查明：`multiqc 1.33` 的依赖。**
（实测命令：遍历 `importlib.metadata.distributions()` 找 `requires` 里含 `tiktoken` 的包。）

**⇒ 要在脚本里调 LLM，需要先装 `anthropic`** —— 按规矩**装依赖要先获你批准**，
装完要回填 env yaml 并写明原因
（见 `20.Notes_by_ZG/Python_core_modules_for_bioinformatics.md` §7.2）。

---

## §9 单次调用 / 工作流 / agent：先选最简单的那层

| 你的任务 | 用哪层 |
| :--- | :---: |
| 分类、摘要、抽取、问答 | **单次 API 调用** |
| 大批量同类任务 | 单次调用 + **Batch API** |
| 多步流程，但**每一步都是你写死的** | **工作流**：你自己编排，LLM 只做其中的某几步 |
| 需要模型**自己决定调哪个工具、调几次** | agent（SDK 的 tool runner，或托管 agent） |

**⚠ 绝大多数生信场景停在前两层就够了。** agent 的适用条件是
"任务多步且无法事先完全指定"；而"把 20 个样本的富集结果各写一段解读"
**不是** agent 任务，是**批处理任务**。

**与你日常用的 Claude Code 的关系**：Claude Code 是"已经搭好的 agent"，
本篇讲的是"你自己在 Python 脚本里调 API"。两件事，不要混。

---

## §10 本篇与其它文档的边界

| 想知道什么 | 去读 |
| :--- | :---: |
| **LLM 做细胞类型注释靠不靠谱、prompt 怎么写** | `AI_in_singlecell_and_spatial_3_llm_biology_20260910.md` |
| **把 LLM/agent 当分析助手，哪些环节能交** | `AI_in_singlecell_and_spatial_2_agent_workflow_20260910.md` |
| **AI 方法在单细胞里的可信度分级** | `AI_in_singlecell_and_spatial_1_methods_20260910.md` |
| 本地跑模型的显存怎么算 | 本目录 [②](2_representation_learning_and_dl_frameworks.md) §3.4 |
| 评估一个模型/流程的纪律 | 本目录 [①](1_supervised_learning_and_evaluation_discipline.md) |
| 写 Claude API 代码的完整参考 | `claude-api` skill（**每次都读，不要凭记忆**） |

---

## §11 本文的事实来源

| 内容 | 性质 |
| :--- | :---: |
| 模型表、价格、API 形状、参数名、废弃项 | **`claude-api` 参考，缓存日期 2026-06-24** —— 不是我的记忆 |
| 本机各 env 装了什么、`tiktoken` 来自 multiqc | **2026-09-17 本机实测** |
| 6 GB 能跑什么 | **估算**，未在笔记本上实测 |
| 静默陷阱清单、三条路线、省钱优先级 | 我的整理与判断 |

> **⚠ 时效性**：LLM API 是本目录三篇里**过期最快**的一篇。
> 写代码前重新读一次 `claude-api`，不要把本文当成最新事实——本文只是心智模型。
