
在生物信息学中，QNAME 是 Query Template Name（查询模板名称）或 Query Name（查询序列名称）的缩写。
简单来说，QNAME 就是一条测序 Read（或一对双端测序 Reads）的唯一“身份证号”（ID）。
它贯穿了从下机原始数据（FASTQ）到比对分析（SAM/BAM）的全过程。以下是对 QNAME 的全方位详解：
一、QNAME 出现在哪里？
SAM / BAM 文件中的第一列（Column 1）
SAM 文件的每一行代表一条比对记录，其固定的第一个字段就是 QNAME。
code
Text

# SAM文件示例

QNAME                           FLAG  RNAME  POS      MAPQ  CIGAR ...
A00123:45:H5WYGDSXX:1:1101:1024 99    chr1   10001    60    150M  ...
FASTQ 文件的第一行
在 FASTQ 文件中，以 @ 开头的第一行就是测序 Read 的标识符，其中的主体部分在比对后就会变成 SAM 文件中的 QNAME。
code
Text

# FASTQ示例

@A00123:45:H5WYGDSXX:1:1101:1024 1:N:0:ATCGGA   <-- 这里空格前面的部分即 QNAME
GATCGATCGATCGATC...
+
FFFFFFFFFFFFFFFF...
二、QNAME 的命名规则（以 Illumina 平台为例）
现代测序仪（如 Illumina）生成的 QNAME 并不是随机字符串，而是包含了极高物理信息的编码。
以 Illumina Casava 1.8+ 格式为例：
code
Text
@A00123:45:H5WYGDSXX:1:1101:1024:1000 1:N:0:ATCGGA
通常，空格之前的部分作为标准 QNAME 写入 BAM 文件：
A00123:45:H5WYGDSXX:1:1101:1024:1000
它被冒号 : 分隔为 7 个部分：
A00123：测序仪唯一设备编号（Instrument ID）。
45：测序运行批次编号（Run ID）。
H5WYGDSXX：Flowcell（流动槽）的条形码 ID。
1：Flowcell 上的 Lane（泳道）编号（通常 1-8）。
1101：Tile（磁片/区域）编号（表面拍摄的特定网格）。
1024：该 Read 在该 Tile 上的 X 坐标。
1000：该 Read 在该 Tile 上的 Y 坐标。
为什么这些坐标很重要？
生信分析中（如使用 Picard 进行 MarkDuplicates），软件会利用 QNAME 中的 Lane、Tile、X、Y 坐标来判断两条序列是否不仅序列相同，而且在物理芯片上靠得极近。如果极近，说明是光学重复（Optical Duplicate），而不是生物学上的重复（PCR Duplicate）。
三、QNAME 的核心生物信息学特性

1. 双端测序（Paired-End, PE）共享同一个 QNAME
   这是初学者最容易混淆的地方：一对测序片段（Read 1 和 Read 2）在 SAM/BAM 中拥有完全相同的 QNAME。
   在原始 FASTQ 中，它们可能通过结尾的 /1 和 /2 或者空格后的 1:... 和 2:... 区分。
   在比对后的 BAM 文件中，软件通过 FLAG 列（SAM 的第 2 列）中的二进制位来区分哪一条是 Read 1，哪一条是 Read 2，而它们的 QNAME 是完全一样的。
2. 空格敏感性（Whitespace Truncation）
   根据 SAM 规范，QNAME 中不允许包含空格、换行符或制表符。
   许多生信软件（如 BWA, Bowtie2, samtools）在读取 FASTQ 时，默认将第一个空格后面的所有内容当作注释截断丢弃。
   FASTQ: @Read_001 Comment:Info
   BAM QNAME: Read_001
3. 长度与字符限制
   规范建议 QNAME 长度在 1 到 254 个字符之间（通常是 ASCII 可见字符）。
   尽量避免在 QNAME 中使用中文、特殊标点（除 _、-、: 外），否则容易导致某些下游工具报错崩溃。
   四、QNAME 在下游分析中的关键作用
   按名称排序（Sort by Name）
   默认情况下，BAM 文件是按基因组坐标排序的（Coordinate sort）。
   但某些分析（如双端序列计数 htseq-count，提取未比对的 Reads 重新转为 FASTQ samtools collate/fastq）必须要求成对的 Read 挨在一起，此时需要使用 samtools sort -n 按照 QNAME 排序。
   跨文件追踪与质控（Troubleshooting）
   如果你在 IGV（基因组浏览器）中看到一条极其诡异的比对（比如超大片段插入、异常错配），你可以复制它的 QNAME，直接使用 grep 去原始的 FASTQ 文件中把它搜出来，检查是否是原始测序质量差或测序接头污染。
   去除重复序列（Deduplication）
   如前所述，GATK / Picard 的 MarkDuplicates 工具会解析 QNAME 来区分 PCR 重复和 Optical 重复（需要提供测序仪的像素距离参数）。
   总结（TL;DR）
   属性	详情
   定义	Query (Template) Name，即测序片段的唯一识别码 (Read ID)
   位置	FASTQ 的 @ 标识行；SAM/BAM 文件的第 1 列
   PE 规则	双端测序的 Read 1 和 Read 2 在 BAM 中共享相同的 QNAME
   内含信息	包含仪器、泳道、磁片及芯片物理 X/Y 坐标（用于判定光学重复）
   注意事项	空格会被截断；避免包含特殊字符；samtools sort -n 按其排序
