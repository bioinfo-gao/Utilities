# git — `.gitignore` 绝对路径写成文件系统路径，永远匹配不到

> 本文件是 canonical 原件。软链接：
> `/home/gao/Utilities/git/git_Advanced/13_sLk_of_git_in_software_pitfalls.md`
> （该目录文件按编号排列，链接文件名续接目录内最大编号）。以后修改请改这份原件，不要改那个链接。

## 症状
`.gitignore` 里加了一行看起来正确的规则（例如 `/home/gao/projects_2026M7/20_xxx/*`），但对应
目录/文件依旧出现在 `git status`、`git add -A` 会照常吃进去，规则完全"无效"，没有任何报错提示。

## 根因
`.gitignore` 里以 `/` 开头的路径是**相对仓库根目录（repo root）锚定**，不是文件系统绝对路径。
如果仓库根目录本身不在 `/home/gao/...` 这条路径下（比如仓库物理位置在别处，`/home/gao/...` 只是
指向仓库的一个 symlink），那么 `/home/gao/projects_2026M7/20_xxx/*` 这种写法在 git 眼里是要去
匹配仓库内一个叫 `home/gao/projects_2026M7/20_xxx` 的子路径——这个子路径根本不存在，于是规则
静默失效，git 不会给任何警告。

**额外陷阱**：即使把路径改对了，`.gitignore` 也只对**尚未被 track 的文件**生效。如果某些文件在
规则修好之前就已经被 `git add`/`commit` 过，它们会继续出现在 `git status`（modified 而非
untracked），需要额外 `git rm -r --cached <path>` 把它们从索引移除（不删磁盘文件），之后才会真正
被忽略。

## 修复
1. `.gitignore` 里目录规则统一写成**仓库根相对路径**，不要用绝对文件系统路径：
   ```
   /20_xxx/
   /21_yyy/
   ```
   而不是 `/home/gao/projects_2026M7/20_xxx/*`。
2. 改完先用 `git check-ignore -v <某个应该被忽略的文件>` 验证规则真的命中（会打印匹配到的
   `.gitignore` 行号），不要只看 `git status` 输出为空就当作生效——尤其在规则刚加、目录里还没有
   任何文件时，`git status` 本来就不会显示任何东西，容易造成"看起来生效了"的假象。
3. 如果目录此前已有文件被 track，追加 `git rm -r --cached <path>` 把已跟踪文件移出索引。

## 排查命令
```bash
git rev-parse --show-toplevel        # 确认仓库真实根目录，而不是假设的路径
git check-ignore -v <path>           # 验证某具体文件是否真的被规则命中，命中会打印规则来源
git ls-files <dir>                   # 该目录下当前有哪些文件仍被 track
```

## 实测记录
- 2026-07-25，`projects_2026M7` 仓库：`.gitignore` 里给项目20/21两条目录规则都写成了
  `/home/gao/projects_2026M7/<dir>/*`，但仓库真实根目录是 `/mnt/ex_8T_SSD/projects_2026M7`
  （`/home/gao/projects_2026M7` 只是 symlink）。规则全程无效，项目20的14个文件在此期间被正常
  commit 追踪。改为仓库根相对路径 `/<dir>/` 后 `git check-ignore -v` 验证生效，另用
  `git rm -r --cached` 补救已跟踪文件。详见 `project_19_lijian_wu_rell1_tnfa_tumor` 等相关
  memory 与该仓库 commit `6310656`。
