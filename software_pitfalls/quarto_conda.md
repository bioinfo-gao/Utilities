# conda 版 Quarto 的坑

> 2026-09-17 proj23（R scRNA 教程，20 章 quarto website）实测。
> 症状是渲染**第 1 章就死**，日志只有一行"No such file or directory"。

---

## §1 不走 `conda activate` 时，quarto 找不到 deno（以及 pandoc/typst/sass）

**症状**：

```
/mnt/ex_8T_SSD/conda_envs/sc_tut_r/bin/quarto: line 208:
  /mnt/ex_8T_SSD/conda_envs/sc_tut_r/bin/tools/x86_64/deno: No such file or directory
```

而 `ls $ENV/bin/deno` **明明存在**（conda 包 `deno-2.4.5`）。

**根因**：`bin/quarto` 是一层 shell 包装，其中：

```bash
if [ "$QUARTO_DENO" == "" ]; then
  export QUARTO_DENO="${SCRIPT_PATH}/tools/${ARCH_DIR}/deno"   # 官方 tarball 的布局
fi
```

conda 包不按官方 tarball 布局装（deno 在 `bin/deno`），而是靠**激活钩子**
`etc/conda/activate.d/quarto.sh` 把位置写进环境变量。**只要不 `conda activate`，钩子就不跑**，
quarto 回退到那个在 conda 包里根本不存在的内置路径。

**谁会踩**：所有为了避开「同名 env 解析错解释器」而刻意用绝对路径 / `conda run` /
手工 `export PATH` 的脚本 —— 也就是写得比较讲究的那些。
（见 [conda_env_duplicate_names.md](conda_env_duplicate_names.md)：避开那个坑的正确做法，制造了这个坑。）

## §2 修法：把激活钩子的内容显式重放，但**不要照抄 `QUARTO_DENO_DOM`**

```bash
ENV=/path/to/env
export PATH="$ENV/bin:$PATH"
export QUARTO_DENO="$ENV/bin/deno"
export QUARTO_DENO_DOM="$ENV/lib/deno_dom.so"     # ⚠ 见下，不要抄钩子里的值
export QUARTO_PANDOC="$ENV/bin/pandoc"
export QUARTO_ESBUILD="$ENV/bin/esbuild"
export QUARTO_TYPST="$ENV/bin/typst"
export QUARTO_DART_SASS="$ENV/bin/sass"
export QUARTO_SHARE_PATH="$ENV/share/quarto"
export QUARTO_CONDA_PREFIX="$ENV"
export DENO_INSTALL_ROOT="$ENV"
export QUARTO_R="$ENV/bin/R"                      # 顺带：指定用哪个 R，别靠 PATH 撞运气
```

**`QUARTO_DENO_DOM` 是 conda-forge 配方自己的 bug**：钩子里写的是**构建机路径**

```
export QUARTO_DENO_DOM=/home/conda/feedstock_root/build_artifacts/quarto_<ts>/_build_env/lib/deno_dom.so
```

本机当然没有。真正的插件在 `$ENV/lib/deno_dom.so`（由 `deno-dom` 包提供，
另一个钩子 `deno_dom.sh` 里的 `DENO_DOM_PLUGIN` 指的就是它）。
而 quarto 的包装脚本是

```bash
if [ "$QUARTO_DENO_DOM" != "" ]; then export DENO_DOM_PLUGIN=$QUARTO_DENO_DOM
else export DENO_DOM_PLUGIN=$QUARTO_BIN_PATH/tools/${ARCH_DIR}/deno_dom/libplugin.so   # 也不存在
fi
```

**两条路都是死的**，所以必须自己给一个对的值。

## §3 判据

装好之后先单独验一次，别等渲染：

```bash
env QUARTO_DENO=$ENV/bin/deno QUARTO_DENO_DOM=$ENV/lib/deno_dom.so \
    QUARTO_PANDOC=$ENV/bin/pandoc QUARTO_SHARE_PATH=$ENV/share/quarto \
    $ENV/bin/quarto --version
# 应当只输出版本号，例如 1.9.38
```

`quarto --version` 能出版本号 = deno 起得来（版本号本身就是 deno 跑出来的）。

## 相关

- [conda_env_duplicate_names.md](conda_env_duplicate_names.md) — 为什么脚本会刻意不用 `conda activate`
- [conda_r_env_build.md](conda_r_env_build.md) — 同一批 env 的其它坑
