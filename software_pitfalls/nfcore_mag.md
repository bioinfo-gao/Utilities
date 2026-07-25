# nf-core/mag 坑

## DASTool 去冗余后的 final bin 与 QC/分类报告跑在的原始 per-binner bin，命名不同、数量差 ~5.8 倍

**症状**：nf-core/mag 的 CheckM2/BUSCO/GTDB-Tk 这几步，**跑在原始 per-binner bins 上**——也就是
MetaBAT2、MaxBin2、SemiBin2 三个 binner 各自独立产出的 bin 集合直接拼在一起（同一个基因组会被
不同 binner 各报一次，存在重复），**不是**跑在 DASTool 去冗余、选出"每个基因组簇最佳单一 bin"之后
的那份**才是真正意义上的"最终基因组数"**的 final bins 上。

实测（project 17，2026-07-20）：原始 per-binner bins **1,060 行**（含重复），DASTool 精炼后的
final bins 只有 **184 个**——**相差 5.76 倍**。如果不知道这个结构，直接拿 CheckM2/GTDB-Tk 报告的行数
当"回收了多少个基因组"，会把数字报大近 6 倍。

**命名规则还不一样，不能直接按名字对应**：
- DASTool final bin 命名形如 `XxxRefined-group-XX.NNN[_sub].fa`；
- 原始 per-binner bin 是各 binner 自己的命名规则，其中 **SemiBin2 还多一层转换**：原始产出用
  `_NNN`（下划线），到了 DASTool 的输出里变成 `.NNN`（点号）——同一个 bin 在两处的文件名字符都不同,
  不能简单字符串匹配。

**解法**：project 17 写了 `scripts/15_mag_final_bin_catalog.py`，按 `binner + group + 编号` 做名字
映射（含 SemiBin2 的 `_`→`.` 转换规则），把 184 个 DASTool final bin **逐一**对回其原始
CheckM2/BUSCO/QUAST/GTDB-Tk 记录，**100% 映射成功（0 unmapped）**。任何人复用 nf-core/mag 的输出
做基因组计数/质量分级/分类统计，都应该先做这一步映射，而不是直接读 QC 报告的行数。

**规则**：
1. 报告 nf-core/mag 结果里的"基因组数/MAG 数"之前，先确认自己拿的是 **DASTool 精炼后的 final
   bins**（通常在 `GenomeBinning/DASTool/` 下），而不是 `GenomeBinning/{MetaBAT2,MaxBin2,SemiBin2}/`
   下的原始 per-binner bins 汇总数。
2. 需要给 final bins 配 CheckM2/BUSCO/GTDB-Tk 质量与分类信息时，做名字映射脚本（可复用
   `15_mag_final_bin_catalog.py` 的思路），不要假设文件名能直接对上，SemiBin2 的下划线/点号转换尤其
   容易漏掉。
3. 交付报告/内部文档里如果同时出现两个数字（原始 vs 精炼），务必标清楚各自指什么，避免读者把"原始
   1060 行"误当成"最终基因组数"。

关联：[[reference_shotgun_meta_three_routes]]（MAG 路线总览）。
Proj17 详情：`project_17_daniel_mendes_gut_metagenomics`（memory），完整实现见
`17_Daniel_Mendes_gut_metagenomics/scripts/15_mag_final_bin_catalog.py`。
