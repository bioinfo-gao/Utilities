# 把根目录 `/` 加入 Positron 工作区（multi-root workspace）

> 记录于 2026-11-25。适用于 Positron / VS Code + Remote-SSH。

## 结论

**`File → Add Folder to Workspace...` 加不了 `/`**（实测多次）：远程的 simple file dialog
只能选择某个目录下的子目录，`/` 没有上级目录，所以选不中。
**唯一可靠的办法：直接编辑 `.code-workspace` 文件。**

## 步骤

1. 打开工作区文件。本机当前在用的工作区文件（full path）：

   **`/home/gao/gao_workspace_2026H1.code-workspace`**

   两种打开方式，任选其一：
   - **方式 A**：`Ctrl+Shift+P` → **`Workspaces: Open Workspace Configuration File`**
     （中文界面叫"工作区: 打开工作区配置文件"）。
   - **方式 B（2026-11-25 实际用的这个）**：在 Claude Code 对话面板里，直接点 Claude 回复中
     指向该文件的链接（显示为 `gao_workspace_2026H1.code-workspace`），文件就会在编辑区打开。
     该链接打开的文件 full path = **`/home/gao/gao_workspace_2026H1.code-workspace`**。
     想要这样打开时，让 Claude 给出这个文件的链接即可。

2. 在 `"folders"` 末尾追加一项（**前一项的 `}` 后面要补一个逗号**）：

   ```json
   {
       "path": "/",
       "name": "root"
   }
   ```

   - `path` 可以写绝对路径；其余几项的相对路径是相对 workspace 文件所在目录算的。
   - `name` 是左侧资源管理器里显示的名字，可以不写，但不写时就只显示一个 `/`。

3. ⚠ **2026-11-25 15:45 实测：下面这段以 `/` 开头的绝对路径排除项【没有生效】。**
   加入 `/` 后，Positron 起了 `rg --files`，cwd=`/`，命令行里没有任何 `/proc`、`/mnt`、`/srv` 排除项，
   占用约 1189% CPU 持续 13 min 以上。原因推测：multi-root 下排除 glob 是相对每个根目录匹配的，
   绝对路径写法匹配不到（**推测，尚未验证**）。改成相对写法（如 `"proc/**"`、`"mnt/**"`、`"srv/**"`）
   是否有效，也还没验证。
   **同时**在 `"settings"` 里加上排除项。不加的话，file watcher 和全局搜索会递归扫
   `/proc`、`/sys`、大盘和 Nextflow `work/`，后果是 inotify 句柄被耗尽
   （"unable to watch for file changes"），remote server 的 CPU 也会飙高：

   ```json
   "files.watcherExclude": {
       "/proc/**": true, "/sys/**": true, "/dev/**": true, "/run/**": true,
       "/snap/**": true, "/tmp/**": true, "/var/lib/**": true,
       "/mnt/**": true, "/srv/**": true, "**/work/**": true
   },
   "search.exclude": {
       "/proc/**": true, "/sys/**": true, "/dev/**": true,
       "/mnt/**": true, "/srv/**": true
   },
   "search.followSymlinks": false
   ```

   `search.followSymlinks: false` 的作用：`/home/gao` 下有多个指向大盘的目录符号链接，
   搜索时跟进去会非常慢。
   rg / fileWatcher 高 CPU 的背景见同级目录的 `../color_shortcut_env_watcher_kernel/5_high_CPU_rg_and_fileWatcher.md`。

4. `Ctrl+S` 保存。左侧应该出现 `root` 这个根目录；没出现就
   `Ctrl+Shift+P` → `Developer: Reload Window`。

## 排错

- 出现红色波浪线，或保存后提示 workspace 解析错误 ⇒ 几乎都是**逗号**的问题：
  要么少了，要么多了（JSON 里最后一项后面不能有逗号）。
- 命令行校验：
  `python3 -c "import json;json.load(open('/home/gao/gao_workspace_2026H1.code-workspace'));print('OK')"`
