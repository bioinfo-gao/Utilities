# Positron 高 CPU 排查：`rg` 进程是什么 + fileWatcher 吃满一个核

创建日期：2026-07-26
适用：Positron / VS Code（remote server 模式，本机通过 tailscale 连接）
起因：`top` 里看到一个陌生的 `rg` 进程占 612% CPU

---

## 1. 现象

`top` 里出现这一行：

```
557949 gao  20  0  92596  12376  3376 S 612.2  0.0  0:18.61 rg
```

看起来吓人（612% CPU ≈ 吃了 6 个核），但其实是**正常且短命**的进程。

---

## 2. `rg` 是什么

`rg` = **ripgrep**，一个用 Rust 写的高速全文搜索工具（`grep` 的现代替代品）。它默认**多线程并行**遍历目录树，所以瞬时 %CPU 轻松超过 100%——`top` 里的 %CPU 是"占了几个核 × 100"，612% 就是同时在用约 6 个核。

关键看第二个数字：`TIME+` 只有 `0:18.61`，即累计只消耗了 18.6 秒 CPU 时间。**高 %CPU + 极低 TIME+ = 短时间爆发的任务，不是失控进程。**几秒后自己就退出了（本例中再查 PID 557949 已不存在）。

### 它是谁启动的

本机 PATH 里**没有**独立安装的 `rg`（`which -a rg` 无输出）。系统上唯一的 ripgrep 二进制是 Positron 自带的：

```
/home/gao/.positron-server/bin/<commit-hash>/node_modules/@vscode/ripgrep/bin/rg
```

所以它一定是 **Positron（VS Code 内核）fork 出来的子进程**。触发场景：

- 编辑器里按 `Ctrl+Shift+F` 做全局搜索
- 某个扩展做索引/符号查找
- Claude Code 扩展执行 Grep 工具时调用

**结论：不用管，不用 kill。**搜完自动退出。

---

## 3. 顺带发现的真问题：fileWatcher 持续吃满一个核

查 `rg` 时看到同一时刻 CPU 排名第一的是这个，而且它**不是短命的**：

| 进程 | %CPU | 已运行 | 性质 |
| :--- | :---: | :---: | :---: |
| `bootstrap-fork --type=fileWatcher` | 77–99% | 6 分钟持续 | Positron 文件监视器 |
| `kcserver`（kallichore） | 47–52% | 6 分钟持续 | Positron R kernel supervisor |
| `bootstrap-fork --type=extensionHost` | 14–22% | 6 分钟持续 | 扩展宿主 |

`rg` 和 fileWatcher 是**同一个根因的两面**：workspace 里挂了体量极大的目录，导致全文搜索要扫、文件监视也要盯。

### 根因：workspace 三个 root 的文件总数超过了 inotify 上限

当前 workspace（`/home/gao/gao_workspace_2026H1.code-workspace`）挂了三个 root：

```json
"folders": [
    { "path": "." },                          // = /home/gao 整个家目录
    { "path": "../../Work_bio/references" },  // 参考基因组/数据库
    { "path": "projects_2026M7" }             // → /mnt/ex_8T_SSD/projects_2026M7
]
```

实测各 root 的文件+目录条目数（`find | wc -l`，2026-07-26）：

| Workspace root | 条目数 | 大头在哪 |
| :--- | :---: | :--- |
| `/home/gao`（不跟符号链接） | 196,475 | `.positron-server/` 自己就占 105,385 |
| `/Work_bio/references` | 320,761 | `Metagenomics/gtdbtk/release226/` 占 **307,540** |
| `/mnt/ex_8T_SSD/projects_2026M7` | 54,998 | nextflow `work/` 目录 |
| **合计** | **≈ 572,000** | |

而本机 inotify 上限：

```bash
$ cat /proc/sys/fs/inotify/max_user_watches
524288
```

**572,000 > 524,288** —— 要监视的文件数直接超过了内核允许的 watch 上限。超限后 watcher 会拿到 `ENOSPC` 并不断重试/降级轮询，这就是它稳定烧掉一整个核的原因。

其中最离谱的单一贡献者是 **GTDB-Tk release226 参考数据库，307,540 个文件**——一个下载好就再也不变的静态 DB，占掉了 59% 的 watch 预算，却完全没有被监视的必要。

---

## 4. 修复：排除掉不需要监视/搜索的目录

在 workspace 文件 `/home/gao/gao_workspace_2026H1.code-workspace` 的 `"settings"` 块里加入（或加到 Positron 的 Machine/User `settings.json`，但**推荐放 workspace 文件**，因为这些排除规则是跟这个 workspace 的 root 组合绑定的）：

```json
"settings": {
    "files.watcherExclude": {
        "**/.positron-server/**": true,
        "**/.vscode-server/**": true,
        "**/.cache/**": true,
        "**/.conda/**": true,
        "**/miniforge3/**": true,
        "**/Dropbox/**": true,
        "**/Metagenomics/gtdbtk/**": true,
        "**/Metagenomics/humann/chocophlan/**": true,
        "**/work/**": true,
        "**/.nextflow/**": true,
        "**/output_results/**": true
    },
    "search.exclude": {
        "**/Metagenomics/**": true,
        "**/work/**": true,
        "**/.nextflow/**": true,
        "**/output_results/**": true,
        "**/*.fastq.gz": true,
        "**/*.fq.gz": true,
        "**/*.bam": true,
        "**/*.cram": true,
        "**/*.vcf.gz": true
    },
    "files.exclude": {
        "**/.nextflow/**": true
    }
}
```

三个键的区别（别搞混）：

| 设置 | 作用 | 影响 |
| :--- | :--- | :--- |
| `files.watcherExclude` | 不放进 inotify 监视 | 直接降 fileWatcher 的 CPU/watch 消耗 |
| `search.exclude` | 全局搜索（`Ctrl+Shift+F`）跳过 | 降 `rg` 的耗时和 CPU 峰值 |
| `files.exclude` | 文件浏览器里直接隐藏 | 只影响视觉，不省 CPU |

只加 `files.exclude` **不会**减轻 CPU——隐藏≠不监视。这是常见误解。

### 光排除还不够时：抬高 inotify 上限

排除之后如果条目数仍然逼近上限，可以永久调高（需要 sudo）：

```bash
echo 'fs.inotify.max_user_watches=1048576' | sudo tee /etc/sysctl.d/60-inotify.conf
sudo sysctl --system
cat /proc/sys/fs/inotify/max_user_watches   # 验证变成 1048576
```

代价是内核内存：每个 watch 约 1 KB，100 万个 watch ≈ 1 GB。本机内存充裕，但**优先做排除、其次才抬上限**——监视 30 万个永不改动的 GTDB 文件本身就是纯浪费，抬上限只是把浪费合法化。

### 更彻底的办法：别把 `/Work_bio/references` 挂进 workspace

参考数据库是只读资源，不是要编辑的代码。真需要看的时候单独开窗口，比常年挂在 workspace 里让 watcher 盯着划算得多。

---

## 5. 改完怎么验证

改完 workspace 设置后需要 **Reload Window**（`Ctrl+Shift+P` → `Developer: Reload Window`），然后：

```bash
# 1. 看 fileWatcher 的 CPU 是否降下来（应该从 ~80% 掉到个位数）
ps -eo pid,etime,pcpu,args --sort=-pcpu | head -8

# 2. 确认它跑了几分钟后仍然是低占用（不是刚启动的假象）
#    ELAPSED 列要 > 3 分钟，%CPU 仍然低，才算真的好了
```

判据：`ELAPSED` 超过 3 分钟、`%CPU` 仍在个位数 = 修好了。刚 reload 完的头 1–2 分钟本来就会有一波索引高峰，那不算数。

---

## 6. 通用排查手法（下次看到陌生进程照这个套路走）

```bash
# 1. 这进程还活着吗？谁是它爹？
ps -o pid,ppid,user,etime,pcpu,args -p <PID>

# 2. 按 CPU 排序看全局，重点看 ELAPSED —— 短命的爆发不用管，
#    长时间稳定高占用的才是问题
ps -eo pid,ppid,etime,pcpu,args --sort=-pcpu | head -12

# 3. 二进制到底是哪个？（判断是系统装的还是某个 IDE/扩展自带的）
which -a <cmd>
ls -la /proc/<PID>/exe
```

核心判据一句话：**看 `%CPU` 更要看 `TIME+`/`ELAPSED`。高 %CPU + 低累计时间 = 正常的并行爆发；高 %CPU + 持续数分钟以上 = 真问题。**

---

## 附：相关记录

- 磁盘/inode 相关的既有记录见 memory `reference_ex8tssd_disk_migration_plan`
- 跨项目工具坑速查：`/home/gao/Utilities/software_pitfalls/INDEX.md`
