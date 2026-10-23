
```ignore
fasta.sa是生物信息学中比对软件（如 BWA）为基因组 FASTA 参考序列自动生成的“后缀数组（Suffix Array，简称 SA）索引文件”。

文件核心特点

• 非独立文件：它不能单独打开或阅读，必须与原始的 .fasta 文件以及同一批生成的其他索引文件放在同一个目录下。
• 配套索引：当你对一个名为 reference.fasta 的文件运行 bwa index reference.fasta 命令时，BWA 会自动生成以下 5 个配套索引文件：
	1. reference.fasta.amb（记录非 ATGC 的模糊碱基位置）
	2. reference.fasta.ann（记录参考序列的名称和长度等信息）
	3. reference.fasta.bwt（Burrows-Wheeler 变换二进制数据）
	4. reference.fasta.pac（压缩编码后的参考序列）
	5. reference.fasta.sa（后缀数组索引，用于加速比对搜索）

它的作用是什么？

• 加速比对：在进行高通量测序数据（如 NGS 的 FASTQ 文件）与参考基因组比对（Mapping）时，比对软件需要极其快速地在庞大的基因组中查找片段位置。
• 算法依赖：像 bwa mem 或某些结构变异检测工具（如 LUMPY）在运行或回溯时，会强制要求该 .sa 文件存在，如果缺失会导致报错（如 fail to open file ... .sa: No such file or directory）。

能不能删掉？

• 如果你不再需要用 BWA 等软件做比对或找变异，可以删除。
• 如果你还要继续跑比对流程，不能删除；如果误删或丢失，重新运行一次 bwa index <你的fasta文件名> 即可重新生成。
```
