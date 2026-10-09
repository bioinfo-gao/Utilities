# 一个基因组文件下载以后，需要做三种 index

# 确实，在生信分析中，为了让不同的比对或定量软件快速查找基因组序列，针对同一个参考基因组文件（.fa），我们通常需要构建三种不同架构的索引。

# 这三种索引服务于不同的分析目的：


# 1. samtools faidx 
(索引格式：.fai)
# 用途：实现对 FASTA 文件的随机访问。

# 为什么需要：当你只需要提取基因组中某一条染色体或某个区域（如 chr1:100-200）的序列时，
# 如果没有索引，程序必须从头扫描整个几十 GB 的文件。有了 .fai 文件，samtools 可以瞬间定位并提取数据。

# 命令：

samtools faidx genome.fa

# 2. BWA-MEM2 或 Bowtie2 索引 
(索引格式：.bwt, .pac, .ann, .amb, .sa 等)
# 用途：用于 DNA 序列比对（Read Mapping）。

# 为什么需要：这是为了将测序的 DNA 短序列（Reads）映射到参考基因组上。它基于 FM-index (Burrows-Wheeler Transform) 算法，
# 能将整个基因组压缩并索引，使得在数以亿计的 reads 中进行搜索变得极快。

# 命令（以 bwa-mem2 为例）：

bwa-mem2 index genome.fa

# 3. STAR 索引 
(索引格式：目录结构 star_index/)
# 用途：用于 RNA-Seq 的剪接比对（Splice-aware Alignment）。

# 为什么需要：这是处理 RNA 序列比对的“黄金标准”。与 DNA 比对不同，RNA-Seq 的 reads 跨越内含子（Introns）。STAR 索引不仅包含基因组序列，
# 还必须结合注释文件（GTF/GFF）中的剪接位点信息（Splice Junctions），否则它无法识别并跨越剪接区。

# 命令：

STAR --runMode genomeGenerate --genomeDir ./star_index --genomeFastaFiles genome.fa --sjdbGTFfile annotation.gtf --sjdbOverhang 149

# 总结对照表

# 索引工具	        核心文件/格式	      主要分析场景
# Samtools	        .fai	            序列提取、变异检测(VCF)、区间查询
# BWA/Bowtie2	    .bwt 等二进制索引	 全基因组 DNA 比对、ChIP-Seq
# STAR	star_index/ 目录	            RNA-Seq 剪接比对、表达定量

# 如果你刚才是在重构 .git 环境，记得确保这三种索引文件放在 .gitignore 的排除列表里（或者像我们之前确认的那样，只追踪代码，不要把这些巨大的二进制索引文件传到 GitHub 上）。你的本地服务器硬盘空间很大，这三种索引建议常驻存放在 /Work_bio/references/ 下对应的物种文件夹中，通过绝对路径调用，这样就不会乱了。

# 4
hisat2 索引 also useful 