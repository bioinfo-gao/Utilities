# HUMAnN ↔ MetaPhlAn 版本兼容坑（三连坑）

**HUMAnN 3.9 ↔ MetaPhlAn 4.2.4 在本机共享 env（`mag_biobakery`）里必踩，不处理会全 FAIL**：

1. **version-check 解析崩溃**——HUMAnN 内部调用 `metaphlan --version` 解析输出来判断兼容性，但
   `mag_biobakery` env 里装的 MetaPhlAn 版本输出格式对不上 HUMAnN 期望的解析规则，直接崩。
   **改**：PATH 前置一个 `metaphlan` shim 脚本，只回一行干净的版本号，绕开 HUMAnN 自己的解析逻辑。

2. **数据库代际不匹配**——装的 metaphlan 默认拉的是 **vJan25** 数据库，但 HUMAnN 3.9 拒绝这个代际，
   需要 **vJun23 db**（`/Work_bio/references/Metagenomics/metaphlan_vJun23`，索引名
   `mpa_vJun23_CHOCOPhlAnSGB_202307`）才能产出 HUMAnN 认的 v3/vJun23 格式 profile。

3. **`--bowtie2out` 参数名不兼容**——HUMAnN 传给 MetaPhlAn 的是 `--bowtie2out`，但目标 MetaPhlAn
   版本认的参数名是 `--mapout`。**改**：shim 脚本里做参数名翻译。

**环境激活方式也是坑**：必须**一次性** `conda activate mag_biobakery`（不能逐条 `conda run -n
mag_biobakery ...`），否则子进程 PATH 会丢失，shim 脚本不生效，重新掉回坑①。

**耗时提醒**：DIAMOND 比对阶段每样本约 ~8h，**没有进度条**，不要因为看起来"卡住"就杀掉——这是正常
耗时,不是 hang。

**全套解法**：见 `/tax-functional-humann` skill + proj17 的黄金参考实现
`17_Daniel_Mendes_gut_metagenomics/scripts/7_run_humann.sh` + `scripts/mpa_shim/`。

关联：[[reference_shotgun_meta_three_routes]]（三条 shotgun metagenomics 路线的总览，含这三连坑的
原始记录）。GTDB-Tk r226（MAG 路线用）实测 tar.gz 141GB / 解压 139GB，同样记在那份 memory 里。
