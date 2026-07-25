Claude Code 计费模式：订阅制 vs. API 消耗

这是一个非常普遍的误区，让我们彻底理清 Claude Code 的费用结构。

核心结论：没有 100 美元的“包月订阅”

在针对开发者工具（Claude Code CLI 和 VS Code 插件）的层面上，Anthropic 没有提供每月 100 美元的“不限量包月订阅（Unlimited Subscription）”这种商业模式。

您所理解的“100 美元”，其实是您（或您的公司）在 Anthropic Console 中预先充值或设定的 API 消费额度上限。

两种完全不同的计费体系

要消除糊涂，必须将“网页版聊天”和“开发者工具”的计费体系分开看：

1. Claude Pro 网页版订阅 (C端计费)

价格：每月 20 美元。

模式：包月制（Subscription）。

适用范围：仅限在浏览器打开 claude.ai 进行网页聊天。

限制：虽然说是包月，但在高负载时段有使用次数限制（Rate Limits）。

能不能写代码？ 能，但只能在网页聊天框里粘贴代码，无法连接您的 Positron，也无法自动操作您的 Linux 服务器。

2. Claude API 与 Claude Code 工具 (B端/开发者计费)

价格：按使用量计费（Pay-as-you-go）。基于发送和接收的 Token（字符）数量算钱。

模式：充值消耗制（就像给手机充话费）。您的 100 美元就是充进去的“话费余额”。

适用范围：

任何调用了 ANTHROPIC_API_KEY 的第三方软件（比如您之前用的 Continue 插件）。

Anthropic 官方开发的代码工具：即 Claude Code CLI 和 Claude Code for VS Code。

为什么用 API？ 因为只有 API 模式，才能绕过网页版的限制，让大模型“长出手脚”，直接深入您的代码库（/home/gao/projects_2026H2/）去读取文件、执行终端命令（如 mamba activate R44_RNA）。

破除谣言：关于“共享 20 美元订阅”

如果您听说过“Claude Code 可以共享 20 美元的 Pro 订阅”，那是一个误传或者对产品形态的误解。

事实是：您可以在您的 Anthropic 账户中，同时拥有 20 美元的网页版订阅，并为 API 账户充值 100 美元。但这 20 美元绝对无法覆盖 Claude Code（CLI 或 VS Code 插件）在 Positron 中扫描项目、自动修 Bug 所产生的 API 费用。

任何真正在您的服务器后台帮您读写代码的 Agent 操作，消耗的永远是您的 API 余额（那 100 美元）。

为什么您三天花了 41 美元？

因为在 API 计费模式下：

输入（Prompt）和输出（Completion）都要钱。

隐藏的巨大输入：当 Agent 试图理解您的生信项目时，它为了保证代码上下文的连贯，可能会偷偷把整个分析脚本的历史版本、报错日志、甚至未屏蔽的几 MB 的单细胞摘要数据，作为“输入”一股脑发给服务器。

结果：即使它只回了您一句“代码修好了”，背后可能已经向 Anthropic 发送了数十万个 Token 的背景信息。

总结：如何保住剩下的余额？

不要纠结于包月了，在真实的项目开发中，按量计费的 API 是唯一能获得最高权限（操作服务器）的途径。为了让这 100 美元撑满一个月，您必须依靠 .claudeignore 文件来阻断不必要的文件扫描。
# ==========================================================================================================================================================


在服务器端，claude code 作为agent， 是不是有每月100美元的订阅制

2:27 PM

Searched the web, viewed a file
Searched the web, viewed a file
这个问题的答案比较复杂，而且最近（2026年6月15日）刚刚发生了重要变化，让我来详细解释：

Claude Code 服务器端 Agent 的费用结构
不是简单的"$100/月订阅制"
订阅计划（Claude.ai 订阅，不是纯 API）：

Claude Code 订阅有几个档位：Pro $20/月、Max 5x $100/月、Max 20x $200/月、Team Premium $100/人/月（最少5席）。 
UsageBox

⚠️ 2026年6月15日的重大变化
从2026年6月15日起，编程式使用（Agent SDK、claude -p 无头模式等）从共享订阅额度池中分离出来，移到了一个独立的月度 credit 池，按完整 API 费率计费：

Pro：$20/月 credit
Max 5x：$100/月 credit
Max 20x：$200/月 credit
未使用的 credit 不会滚入下月。 
Find Skill.ai

也就是说，$100/月的 Max 5x 订阅包含的服务器端 Agent SDK credit 是 $100，但：

如果超出 credit，行为取决于是否开启了超额使用（extra usage）。开启了则继续按标准 API 费率计费；未开启则 SDK 请求会暂停，直到下个月 credit 刷新。 
Claude Fast

如果用量超过 $200/月怎么办？
如果每月 Agent 用量超过 $200，建议直接走 API（pay-as-you-go）。订阅超额的费用比直接购买 token 更贵，因为还要叠加订阅的固定费用。 
Find Skill.ai

服务器端 API 直接计费（无订阅）
直接走 API 的 token 定价（每百万 token）：Haiku 4.5 输入 $1/输出 $5，Sonnet 4.6 输入 $3/输出 $15，Opus 4.8 输入 $5/输出 $25。 
Morph

总结： "$100/月" 对应的是 Max 5x 订阅，其中包含 $100 的 Agent SDK credit，用完后按 API 费率计费。如果你的服务器端 agent 用量较大（超过 $200/月），更推荐直接使用 API key 按量付费，而不是走订阅计划。