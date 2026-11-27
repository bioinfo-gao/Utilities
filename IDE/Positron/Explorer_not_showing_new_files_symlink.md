# Positron Explorer 不显示新文件（软链接 / 大盘目录下）

> 记录于 2026-11-26。适用于 Positron / VS Code remote server 模式。

## 结论

**文件其实已经在磁盘上，是 Explorer 没有刷新。点 Explorer 顶部的刷新按钮（Refresh Explorer）就会显示。**
(2026-11-26 实测：刷新后立即显示。)

## 现象（2026-11-26 实例）

- 目录：`/home/gao/projects_2026Q4/46_park_wgs/custom_research_report_20261127/figures/`
- 23:33 建目录并放入 `Fig3_*.pdf`；23:39 由 Claude Code 在终端里再放入 `Fig5_*.pdf`。
- Explorer 里一直只显示 Fig3 一个文件。
- 用 `ls -la` 看，软链接路径和真实路径都列出两个文件：
  - 软链接路径：`/home/gao/projects_2026Q4/...`
  - 真实路径：`/mnt/ex_8T_SSD/projects_2026Q4/...`

## 为什么（实测事实 + 推断）

**实测事实**
- `/home/gao/projects_2026Q4` 是软链接，指向 `/mnt/ex_8T_SSD/projects_2026Q4/`。
- 工作区文件 `/home/gao/gao_workspace_2026H1.code-workspace` 的 `folders` 有四项：
  `.`（= `/home/gao`）、`../../Work_bio/references`、`projects_2026Q4`、`/`。
- 同一文件的 `files.watcherExclude` 含 `"/mnt/**": true` 与 `"/srv/**": true`。

**推断：两个原因都可能，单独哪一个起作用未验证**
1. **file watcher 不跟随软链接。** VS Code 系编辑器监视目录树时，不进入树里的软链接目录。
   从 `/home/gao` 这个根展开 `projects_2026Q4` 时，变动事件收不到。
2. **`/mnt/**` 被排除在监视之外。** 软链接解析后的真实路径在 `/mnt/` 下。
   如果排除项按真实路径生效，ex_8T_SSD 上所有项目的变动都不会推送到 Explorer。
   同目录下 `working_space/add_root_dir_to_workspace.md` 第 3 步记录过：以 `/` 开头的绝对路径排除项
   当时看起来没生效，所以这一条是否真的起作用也不确定。

结果都一样：Explorer 显示的是**上次展开该目录时读到的内容**，之后由终端、脚本或 Claude Code 新建的文件不会自动出现。
在编辑器里自己新建或保存的文件，Explorer 会直接更新，不受这个问题影响。

## 怎么办

| 情况 | 做法 |
| :--- | :--- |
| 偶尔看一次 | 点 Explorer 顶部刷新按钮，或把该目录折叠再展开 |
| 怀疑文件没生成 | 不要信 Explorer，在终端 `ls -la <目录>` 为准 |
| 长期需要实时显示 | 不建议去掉 `"/mnt/**"` 排除项：大盘文件数极多，会耗尽 inotify 句柄、fileWatcher 吃 CPU（见 `color_shortcut_env_watcher_kernel/5_high_CPU_rg_and_fileWatcher.md`）。手动刷新是代价最小的办法 |

## 相关文件

- `working_space/add_root_dir_to_workspace.md` —— 工作区根目录与排除项设置
- `color_shortcut_env_watcher_kernel/5_high_CPU_rg_and_fileWatcher.md` —— fileWatcher 高 CPU 与 inotify 上限
