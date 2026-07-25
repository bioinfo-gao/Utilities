# VS Code / Positron 的 Workspace（工作区）教程

适用于 VS Code 和 Positron（Positron 是基于 Code-OSS 的衍生 IDE，workspace 机制完全继承自 VS Code）。
本文档解决的核心痛点：**日常想以家目录（Home）为总览浏览所有文件，同时又不想让某个子项目
的 Git/运行环境被"淹没"在家目录的海量文件里**，也不想不小心在家目录误触 `git init`
导致 IDE 把数万个文件当成一个巨型仓库扫描（曾经的真实事故）。

## 1. 单文件夹 vs 工作区（Workspace）的本质区别

- **单文件夹模式（Open Folder）**：一个窗口只认一个"根目录"。左侧 Explorer 面板、
  Source Control（Git）面板、集成终端的默认路径，全部锚定在这一个根目录上。
- **Workspace（多根工作区，Multi-root Workspace）**：一个窗口可以同时挂载
  **多个彼此独立的根目录**（可以来自完全不同的磁盘路径，互不嵌套也没关系）。
  Explorer 面板会把它们并列显示为多个顶层节点；**Source Control 面板会按每个根目录
  各自独立探测 `.git`**——家目录本身没有 `.git` 就不会被追踪，子项目各自的 `.git`
  则各自正常工作，互不干扰、互不合并。

这就是为什么"家目录 + 若干项目子目录"適合用 workspace，而不是直接把家目录整个
`Open Folder` 打开。

## 2. `.code-workspace` 文件——workspace 的真身

保存一个 workspace（`File → Save Workspace As...`）本质上就是生成一个 JSON 文件，
后缀 `.code-workspace`。例如本机的 `/home/gao/gao_workspace_2026H1.code-workspace`：

```jsonc
{
  "folders": [
    { "path": "." },                          // workspace 文件自身所在目录（这里是 /home/gao）
    { "path": "../../Work_bio/references" }   // 相对路径，从 workspace 文件所在目录算起
  ],
  "settings": {
    // 仅对这个 workspace 生效的设置，例如主题色、git 相关设置等
  }
}
```

**关键点：**

- `folders` 数组里每一项就是一个"挂载的根目录"，顺序即 Explorer 面板里从上到下的显示顺序。
- `path` 是**相对于 `.code-workspace` 文件自身所在目录**解析的（不是相对于当前工作目录）。
  - `"."` = workspace 文件所在的目录本身。
  - `".."` = 该目录的父目录。
  - `"../../Work_bio/references"` = 从 workspace 文件所在目录先往上两级，再进入 `Work_bio/references`。
  - 也可以直接写绝对路径，如 `"/mnt/ex_8T_SSD/projects_2026M7"`。
- `settings` 块是**workspace 级别**的设置（会覆盖 User 设置，但低于 folder 级别的
  `.vscode/settings.json`），常见用法：主题色（用颜色区分不同 workspace，一眼认出当前在哪个
  窗口）、`git.ignoreLimitWarning` 之类的仓库相关开关。

## 3. 增删根目录——两种等价方法

### 方法 A：走 UI 菜单（最常用，适合临时增删）

- **新增**：`File → Add Folder to Workspace...` → 选中目标文件夹 → `Add`。
- **保存**：改完必须 `File → Save Workspace As...`（或直接覆盖已有的 `.code-workspace`），
  否则下次重开窗口时改动不会保留。
- **移除**：在 Explorer 面板里右键该根目录节点 → `Remove Folder from Workspace`。
  （这只是把它从 workspace 里摘除，**不会删除磁盘上的任何文件**。）

### 方法 B：直接编辑 `.code-workspace` 的 JSON（适合批量/精确调整）

跟方法 A 完全等价，改完存盘、IDE 重新加载 workspace 即可生效。例如本次实际操作：
`gao_workspace_2026H1.code-workspace` 原本有 5 个根目录（`.`、`projects_2026H1`、
`projects_2026H2`、`../../Work_bio/references`、`..`），只保留 `.` 和 reference 目录，
就是直接把 `folders` 数组里另外 3 项删掉：

```jsonc
// before
"folders": [
  { "path": "." },
  { "path": "projects_2026H1" },
  { "path": "projects_2026H2" },
  { "path": "../../Work_bio/references" },
  { "path": ".." }
]

// after
"folders": [
  { "path": "." },
  { "path": "../../Work_bio/references" }
]
```

两种方法**改的是同一份文件**，UI 操作最终也是在改这个 JSON——用哪种纯粹看个人习惯，
批量整理时直接改 JSON 更快。

## 4. Git 独立性是这个功能真正解决的问题

- 每个根目录会被各自检测是否含有 `.git`：有的话，Source Control 面板会把它单独列出来，
  提交/暂存/分支操作全部只作用于那一个仓库。
- 家目录本身通常没有 `.git`，所以即使把家目录作为其中一个根目录挂进 workspace，
  也完全不会触发"整个家目录被当成一个仓库扫描"的问题——前提是**没有在家目录手滑
  执行过 `git init`**。
- **安全兜底**：为防止哪天真的不小心在家目录 `git init`，建议设置一个全局 `.gitignore`：
  ```bash
  git config --global core.excludesfile ~/.gitignore_global
  ```
  然后在 `~/.gitignore_global` 里预先写入常见的大文件夹排除规则（如 `Downloads/`、
  各类缓存目录），把灾难拦在源头。

## 5. 什么时候该用 workspace，什么时候该用"新窗口"

- **想要"边看家目录全貌、边深入某个项目改代码"**——用本文档的多根 workspace 方法：
  一个窗口内并列挂载家目录 + 各个项目目录。
  - 优点：一个窗口，Explorer 面板一次看全，各项目 Git 互不干扰。
- **只是想临时钻进某个项目专心写代码，不需要同时看家目录**——更简单的做法是在 Explorer
  里右键该项目文件夹 → `Open in New Window`，弹出一个专属该项目的干净新窗口，跟原来
  查看家目录的窗口互不影响、随时可以切回去。
  - 优点：零配置，不需要维护 `.code-workspace` 文件。

两种方法不冲突，可以按场景混用。

## 6. 常见坑

| 坑 | 说明 |
| :--- | :--- |
| 改完 `folders` 不存盘 | UI 方式改动必须 `Save Workspace As...` 覆盖原文件，否则重开窗口后改动丢失；直接改 JSON 则保存文件本身即可，无需额外"Save Workspace"步骤 |
| 以为 `path` 是相对当前终端目录 | 实际上永远是相对 `.code-workspace` **文件自身所在的目录**，跟你在哪个目录下用命令行打开它无关 |
| 家目录不小心 `git init` | 会导致 Positron/VS Code 把家目录当一个巨型仓库扫描，卡顿甚至"数万文件待同步"；务必配合上面第 4 节的全局 `.gitignore_global` 兜底 |
| workspace 级 `settings` 与 global 配置混淆 | `.code-workspace` 里的 `settings` 只在这个 workspace 打开时生效，不要指望它覆盖到其他窗口；真正全局生效的配置（如 `git config --global`）要在用户级配置里写，不要指望塞进某个 workspace 文件里 |

## 参考

- 本机实际配置文件：`/home/gao/gao_workspace_2026H1.code-workspace`
- 更早的、偏对话体的原始笔记（含具体 Positron 操作截图式描述）：
  `Utilities/IDE/Positron/Multiple_root_workspace.ipynb`
