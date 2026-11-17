---
name: job-application
description: "Use when 用户本人求职——综述/分析某个职位(JD)、定制简历(CV/resume)、写 cover letter、给前同事/前老板/招聘方写 LinkedIn 或邮件、求内推——简历事实母版 CV_master.json 与通用生成器、每版新建绝不覆盖、不编造经历、只准备不发送、按汇报关系定语气、Workday/LinkedIn 抓取技巧"
---

# /job-application

> 用户（Zhen Gao, PhD）本人求职用的材料。**不是客户交付**（客户交付走 `report` skill）。
> 来源：2026-11-16/17 BMS R1608433 职位与 Triveni Bio 联系人两轮实做，规则都是用户当场纠正出来的。

## 0. 文件布局（先看这里）

| 东西 | 路径 | 说明 |
| :--- | :---: | :---: |
| 简历事实母版（SSOT） | `/home/gao/Utilities/company/CV_master.json` | 经历、条目（每条带 `evidence`）、发表、审稿期刊、`pending_questions` |
| 通用生成器 | `/home/gao/Utilities/company/cv_tools/build_cv.js` | `node build_cv.js <master> <version.json> <out.docx>`；未知 id 直接报错 |
| 版本索引 | `/home/gao/Utilities/company/CV_versions.md` | 每版一行：路径、职位、基于哪版、改了什么、哪版是当前有效版 |
| 每个职位的工作文件 | `/home/gao/Utilities/company/<公司>/` | 职位原文、综述、`cv_version_<公司>_<职位号>.json`、cover letter、联系消息 |
| 定稿 PDF | `/home/gao/Utilities/company/CV/` | **用户自己整理的存放处**（2026-11-17 用户把原版和 BMS 定稿移到这里并改了名）。不要擅自移动或改名用户放进去的文件 |
| 原版简历 | `company/CV/CV_Zhen Gao_Bioinformatics-Data Science-AI.pdf` | 用户手写的 Word 导出版，没有 docx |

**事实只写在母版里。** 版本配置只决定选哪些条目、怎么措辞（headline、summary、core expertise 是按职位写的，可以放在版本配置里）。
发现新事实（新经历、发表状态更新、用户补充的平台）⇒ 先改母版并写 `evidence`，再重新生成。

## 1. 流程

1. **抓职位原文并存档**（`<公司>/<公司>_<职位号>_posting_raw_<YYYYMMDD>.json` 或 `.md`）。
   - **Workday** 页面是 JS 渲染的，直接抓拿不到内容 ⇒ 走公开 API：
     `curl -s -H 'Accept: application/json' 'https://<租户>.wd5.myworkdayjobs.com/wday/cxs/<租户>/<站点>/job/<职位路径>'`，
     正文在 `jobPostingInfo.jobDescription`（HTML）。
   - **Lever** 的招聘贴招满后会 404 ⇒ 看到就立即存档。
   - **LinkedIn 个人页**：WebFetch 只拿得到首卡（公司、所在地），**拿不到职位和入职日期** ⇒ 问用户，不要猜。
2. **职位综述**（中文，内部用）：基本信息表、职责、可用资源、画像和 preferred、**与用户的匹配度**（标明哪些是判断、哪些是原文）。
   匹配度必须以**母版和用户简历**为准，**不能只凭记忆里的项目**（2026-11-16 曾把"制药经历 / 病人数据"写成缺口，看到简历后才发现 Biogen PK/PD 和 Miami IBD 队列正好对口）。
3. **定制简历**：
   - 复制最接近的一份 `cv_version_*.json` 到新公司目录，改 headline、summary、core expertise 和条目选择；
   - 生成：`NODE_PATH=<装了 docx@9 的 node_modules> node cv_tools/build_cv.js CV_master.json <公司>/cv_version_….json <out>.docx`，
     再 `soffice --headless --convert-to pdf`（docx 包没装就在 scratchpad 里 `npm install docx@9`，不要装进仓库）；
   - **逐页渲染成 PNG 看一遍**：节标题有没有孤立在页底、职位抬头有没有和条目分开（LibreOffice 不一定按 keepNext 处理 ⇒ 用 `page_break_before`）；
   - 文件名：`CV_Zhen_Gao_<公司>_<职位号>_<YYYYMMDD>[_vN].{docx,pdf}`；在 `CV_versions.md` 加一行并标出当前有效版。
4. **Cover letter**（英文，对外）：第一段直接回应 JD 的核心考点；用具体的、带数字的例子；如果有缺口，就正面承认并说明怎么补。
5. **联系消息**（LinkedIn / 邮件）：见 §3。
6. 本地 `git commit`（常设授权）；**不推送**（简历里有电话和邮箱，推不推由用户决定）。

## 2. 硬规则

- **不编造。** 母版里没有、用户也没说过的经历、平台、年限、职位，一律写 `[方括号]` 并列进 `pending_questions` 去问。
  "用户水平高"不等于"用过某个平台"（例如用户确实精通 spatial，但目前只核实了 Visium）。
- **数字要能追溯。** 每条带数字的条目都要在母版里有 `evidence`；交给用户的时候说明哪些数字没回原始产物复核过。
- **客户项目一律匿名。** 公开数据（ENCODE、公开的 Visium 数据集）可以点名。
- **只准备，不发送。** LinkedIn、邮件、投递一律由用户自己发。邮件要放进 Gmail 草稿箱时，按全局规则走 IMAP APPEND。
- **每一版都新建，旧版不覆盖、不删除**，包括同一天的修改（`_v2`、`_v3`…）。交给用户的时候**写明哪一版是当前有效版**，并提醒 IDE 里开着的可能是旧版。
- **用户的授权**（2026-11-17 原话「我给你永久授权自主修改」）：简历和求职材料可以直接修改、重新生成、提交，不必逐次请示。删除、覆盖、推送仍按全局规则处理。

## 3. 风格（用户逐条纠正过的）

| 规则 | 来源 |
| :--- | :---: |
| 任何一节都**不写成一大段**：Summary 写 3–5 条要点；长列表（例如审稿期刊）排成两栏 | 2026-11-17「一大段读起来很累」 |
| 单细胞和 spatial 放在最前面、写得最具体（用户自述水平远高于一般人） | 2026-11-17 |
| 发表分成 "Selected（与该职位最相关）" 和 "Additional"；**一篇都不能丢**（生成器会自动把未选中的放进 Additional） | BMS 版 |
| 联系人措辞**按真实汇报关系**：对大组负责人（也是用户的老板，只是不是日常直接上级）用 "in your group, working under <直接上级>"，这样最准确 | 2026-11-17：Biogen 时 Baohong Zhang 是约 20 人大组的负责人，Dan Huh 带 7 人；用户每周向 Dan 汇报，每两个月也向 Baohong 汇报一次 |
| 写给前老板、长辈：**以晚辈身份请求帮助**（"I'm writing to ask for your help"），不主动推销（不写 "I would love to help you build the team"），不列能力清单；把请求放宽到"有合适机会就考虑我，没有的话给些建议或帮忙介绍" | 2026-11-17 |
| 写给对方的消息先确认对方的**职位**和**入职时间**，再按这个职位的工作范围措辞 | Triveni v1→v2 |
| LinkedIn 加好友附言 ≤300 字符，交付前用代码数一遍 | — |

## 4. 已知背景（详细事实以母版为准）

- Biogen Translational Data Science（2022–2023）：spatial、PK/PD、剪接、基因治疗；scRNASequest 合著者。
- Miami Sylvester Bioinformatics Core（2016–2021）：肿瘤、免疫、**IBD 病人队列**；PathwaySplice、coMethDMR。
- CWRU AI 药物发现（2015–2016）：BBB 通透性 AI/ML。
- Athenomics（2026-02 至今）：全流程组学分析 + LLM agent 工作流（skills、hooks、decision table）。
- **制药经历和病人数据不是缺口**，不要写成缺口。
- 尚未解决的问题见母版 `pending_questions`，开始新一版之前先看一眼，能问的就问。
