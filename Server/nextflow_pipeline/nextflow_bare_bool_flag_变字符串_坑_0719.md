# Nextflow 裸布尔 CLI flag 被当字符串 → nf-schema 校验全拒（本机 26.04.4）

> 一句话：本机新版 **Nextflow 26.04.4** 上，把布尔参数当**裸 CLI flag**（`--skip_spades` 等）传，
> Nextflow 会赋成**字符串 `"true"`** 而非**布尔 `true`**，被 nf-core 严格 nf-schema 校验逐个拒绝，
> 管线在参数校验期直接 abort（零算力损失但起不来）。**解法：所有参数走 `-params-file`（YAML）**。
> 适用**所有** nf-core 管线：mag / taxprofiler / sarek / rnaseq …
> 首次踩坑：2026-07-19，proj17 Phase 2 MAG 启动。

---

## 现象

`4_run_mag.sh` 用 CLI flag 启动 nf-core/mag 5.4.2，参数校验期 FAIL，`.nextflow.log`：

```
* --skip_spades (true): Value is [string] but should be [boolean]
* --coassemble_group (true): Value is [string] but should be [boolean]
* --skip_concoct (true): Value is [string] but should be [boolean]
* --skip_metabinner (true): Value is [string] but should be [boolean]
* --skip_comebin (true): Value is [string] but should be [boolean]
* --run_checkm2 (true): Value is [string] but should be [boolean]
* --refine_bins_dastool (true): Value is [string] but should be [boolean]
* --checkm2_db (/.../checkm2): '/.../checkm2' is not a file, but a directory
```

**所有裸布尔 flag 同时报 `Value is [string] but should be [boolean]`**，一个 process 没跑就 abort。

## 机制（两因素叠加，缺一不炸）

1. **新版 Nextflow CLI 解析**：`--param value` 一律按字符串收；没有值的裸 flag（`--foo` 后面跟着另一个 `--bar` 或行尾）填入字符串 `"true"`。旧版 Nextflow 会把它 coerce 成布尔 `true`，**新版这里行为变了**。
2. **nf-schema 严格类型校验**：现代 nf-core 模板（mag 5.4.2 等）在启动跑 `validateParameters()`，按 `nextflow_schema.json` 的 `type: boolean` 严格比对，`"true"`(string) ≠ `true`(boolean) → 判错。旧版 nf-schema 宽容 coerce，新版不再。

⚠ **`--flag true`（显式给值）也没用** —— 同样被收成字符串 `"true"`。别指望"补个 true"。

## 为什么阴险

- **版本相关**：同一命令在旧 Nextflow 能跑，换新版才炸，反直觉。
- **冒烟测试测不出**：nf-core `-profile test` 用 params-file / test config，不走 CLI 裸布尔 flag，所以 `-profile test` 全绿、真实项目才咬人（`15_mag_setup` test 通过就是此因）。
- **一次炸一排**：所有布尔参数同时报错，错误墙吓人，实为**同一根因**。

## 解法（可靠）

**把所有 pipeline 参数搬进 `-params-file`（YAML/JSON）** —— YAML 里布尔=真布尔、路径=真字符串，完全绕开 CLI 字符串化，nf-schema 正常通过。也是 nf-core 官方推荐（可复现、可版本化）。

```bash
# ❌ 会炸（本机 26.04.4）
nextflow run nf-core/mag -r 5.4.2 -profile singularity \
    --coassemble_group --skip_spades --run_checkm2 --refine_bins_dastool ...

# ✅ 可靠
nextflow run nf-core/mag -r 5.4.2 -profile singularity \
    -c local_resources.config -params-file params_mag.yaml -work-dir work_mag
```

```yaml
# params_mag.yaml —— 布尔就是布尔，路径就是字符串
coassemble_group: true
skip_spades: true
run_checkm2: true
refine_bins_dastool: true
checkm2_db: /Work_bio/references/Metagenomics/checkm2/uniref100.KO.1.dmnd   # file-path 要文件不要目录!
gtdb_db: /Work_bio/references/Metagenomics/gtdbtk/release226                 # path 可目录
```

等价替代：`-c` config 里写 `params { skip_spades = true }` 块（同样真布尔）。**首选 params-file**。

## 附带的另一个独立 bug（同次暴露）

`--checkm2_db` 的 schema 是 **`format: file-path`** → 必须指 **`.dmnd` 文件**，不是目录。原脚本传了目录 → `is not a file, but a directory`。搬进 params-file 时顺手指到 `uniref100.KO.1.dmnd` 一并修掉。（对照：`gtdb_db` 是 `format: path`，可给目录。传库前先看 schema 的 `format` 是 file-path 还是 path。）

## 通用规约（本机所有 nf-core 管线）

- **本机 Nextflow 26.04.4 上启动 nf-core，一律优先 `-params-file` 传参**（尤其含布尔参数时），别用裸 CLI 布尔 flag。
- 传库路径前查 `nextflow_schema.json` 该参数的 `format`：`file-path` 给文件、`path` 给目录。
- 适用 mag / taxprofiler / sarek / rnaseq 等一切 nf-core 管线。

## 相关

- 首次实例：`17_Daniel_Mendes_gut_metagenomics/scripts/{4_run_mag.sh, params_mag.yaml}`（proj17 Phase 2 MAG）。
- 已固化进 skills：`/tax-assembly-mag`（详）、`/taxnom`、`/wgs`（交叉引用本文）。
- 同目录其它 Nextflow 教训：`resume缓存失效与空转监控_教训_0716.md`、`project14_load_profile_0713.md`。
