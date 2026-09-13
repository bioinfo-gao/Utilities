# `af-only-gnomad.hg38` 当"是否存在于 gnomAD"的判据 —— 会把常见多态判成罕见变异

**症状**：罕见变异优先级列表里混进大量**常见多态**（AF 甚至 = 1.0）。
**零报错、退出码 0、表格列名全对、行数合理** —— 看不出任何异常。

## 实测（2026-09-12，proj36 核实 proj16 已交付产物）

proj16 的 `Sample_{A,B}.prioritised.tsv`：

| 指标 | Sample_A | Sample_B |
| :--- | :---: | :---: |
| 标 `gnomAD_AF = absent`（⇒ 判为罕见 ⇒ 进候选名单） | 3,562 | 3,588 |
| └ **其实在同一个 VCF 的 VEP `CSQ` 里就有 gnomAD v4.1 频率** | **2,498（70.1%）** | **2,592（72.2%）** |
| &nbsp;&nbsp;└ 其中 **AF > 0.01 的常见多态** | **2,171** | **2,257** |

**⇒ 交付的候选名单里约一半是常见多态。**

## 根因：两句话各自都对，拼起来就是缺陷

| 出处 | 原文 |
| :--- | :---: |
| 注释脚本 | `bcftools annotate` 用 **`af-only-gnomad.hg38.vcf.gz`** 加 `INFO/gnomAD_AF` |
| 过滤脚本 | `rare = (af != af) or (af < RARE_AF)  # nan -> absent -> rare` |

`/Work_bio/references/Homo_sapiens/GRCh38/annotation/af-only-gnomad.hg38.vcf.gz` 的 header 显示它是
**2017-08 用 GATK 3.7 从 hg19 liftover 来的 Mutect2 germline resource**（gnomAD v2 时代；
`af-only` 本身就是为体细胞 caller 准备的**子集**）。

**它查不到 ≠ gnomAD 里没有。** 而过滤脚本把"查不到"直接等同于"罕见"，于是常见多态一路畅通。

⚠ **同一次 VEP 运行早就拿到了正确答案**：VEP v115.2 的 cache 声明 `gnomADe="v4.1"` `gnomADg="v4.1"`，
`CSQ` 字段里就有 `gnomADe_AF` / `gnomADg_AF`。**数据一直在交付文件里，只是没被用。**

## 四秒就能发现 —— 一条通用自洽性检查

**只用交付文件本身，不需要任何外部工具或网络**：

```bash
bcftools query -r chr22 -f '%INFO/gnomAD_AF\t%INFO/CSQ\n' Sample_A.gnomad.clinvar.vcf.gz \
 | python3 -c '
import sys
n=c=0
for l in sys.stdin:
    p=l.rstrip("\n").split("\t",1)
    if len(p)<2: continue
    n+=1
    f=p[1].split(",")[0].split("|")
    csq=(f[47] if len(f)>47 else "") or (f[57] if len(f)>57 else "")   # gnomADe_AF / gnomADg_AF
    if p[0].strip() in (".","") and csq.strip(): c+=1
print(f"INFO 为空但 CSQ 有值: {c}/{n} ({100*c/n:.1f}%)")'
```

**proj16 实测：chr22 96,188 个变异里 29,422 个（30.6%）自相矛盾，耗时 4.4 秒。**

⚠ CSQ 字段序号**不要硬编码** —— 从该 VCF 自己的 header 读
（`bcftools view -h | grep -o 'Format: [^"]*' | tr '|' '\n' | grep -n 'gnomADe_AF$'`），
VEP 版本变了顺序就变。

## 怎么做才对

| # | 规则 | 理由 |
| :--- | :---: | :---: |
| 1 | **罕见性判据用 VEP CSQ 的 `gnomADe_AF` / `gnomADg_AF`** | VEP 已经用正确版本算好，零额外成本 |
| 2 | 若必须自己 annotate，**用 gnomAD v4 正式 VCF，且先 `bcftools norm -m -any -f <ref>` 左对齐** | 表示法不同就匹配不上（`TAAA>TAAAA` 在 gnomAD 存成 `T>TA`） |
| 3 | **`absent` 不得等同于 `rare`** | 必须区分「查过且确实不在库中」与「没查到/没查」。前者是结果，后者是缺失值 |
| 4 | **`af-only-gnomad.hg38` 只用于 Mutect2 的 germline-resource 参数**，不作任何频率判据 | 它是为那个用途做的子集 |
| 5 | 注释后**必跑上面那条自洽性检查** | 4 秒，能抓到整整一类"零报错但结果全错" |

## 为什么这一类特别危险

`bcftools annotate` 对**匹配不上**不报错、不警告，只是不写值。于是：

- **"该位点本就不在库中"** 和 **"我们没匹配上"** 在输出里**逐字节相同**（都是 `.`）；
- 下游只要把 `.`/`NaN` 当成"罕见"，缺陷就被**放大成结论**；
- 行数、列名、文件大小、退出码全部正常，**交付前自审看不出来**。

**⇒ 与 [[awk.md]]、[[find_symlink.md]] 同一家族：零报错 + 输出格式正常 + 结果全错。**

**相关**：`projects_2026M7/36_proj16_indel_annotation_audit/docs/P36_research_plan_and_review_0912.md`（完整核实过程）·
[awk.md](awk.md) · [find_symlink.md](find_symlink.md)
