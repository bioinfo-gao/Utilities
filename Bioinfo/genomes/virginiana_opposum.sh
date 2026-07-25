# Didelphis_virginiana

# 说的完全正确，北美负鼠（Didelphis virginiana）确实有高质量的参考基因组！需要稍微澄清一个技术细节：在传统的 NCBI RefSeq 数据库中，目前主要收录并维护了短尾负鼠（Monodelphis domestica）的官方 GCF_ 注释版基因组。这也是为什么很多人误以为北美负鼠没有基因组的原因。但实际上，DNA Zoo 联盟（利用 Hi-C 技术专门做染色体级别组装的国际顶尖学术组织）早就为北美负鼠组装出了极高质量的染色体级别参考基因组（版本代号：dv-2k，全长约 3.3 Gb）。既然基因组文件巨大（3.3 Gb）且后续的建库操作极其耗时，我们必须使用规范的流程来下载并生成三种 Index。完整操作流程请在你的服务器终端执行以下完整的命令。所有文件将统一存放在你的标准参考基因组目录中：Bash# 1. 启动 screen 会话 (防止网络断开导致长耗时任务崩溃)
screen -S dv_index_task

# # 2. 激活专属环境
# mamba activate regular_bioinfo

# # 3. 创建并进入专属的北美负鼠工作目录
mkdir -p /Work_bio/references/Didelphis_virginiana/mDidVir1/DNA_Zoo/star_index
cd /Work_bio/references/Didelphis_virginiana/mDidVir1/DNA_Zoo/ll


# # 4. 从 DNA Zoo 下载染色体级别参考基因组 (dv-2k) 并解压
# 手动在浏览器查看路径：
# 你可以先在你的办公电脑浏览器里打开这个页面：https://www.dnazoo.org/assemblies/Didelphis_virginiana
# 在该页面找到 dv-2k 对应的下载按钮，右键点击“复制链接地址”，然后在服务器上使用 wget 粘贴那个新链接。
wget https://dnazoo.s3.wasabisys.com/Didelphis_virginiana__dv-2k-w2rap/dv-2k.fasta.gz

gunzip dv-2k.fasta.gz

# # 5. 构建 Samtools FASTA 索引 (.fai)
samtools faidx dv-2k.fasta

# # 6. 构建 BWA-MEM2 索引 (用于 DNA/ChIP-seq 比对)
# # 注意：这一步非常耗内存和时间，请耐心等待 2h 左右
tmux a

bwa-mem2 index dv-2k.fasta

# # 7. 构建 STAR 索引 (用于 RNA-seq 剪接比对)
# # 注意：DNA Zoo 目前仅提供了纯 Fasta 序列，没有配套的 GTF 注释文件。
# # 这里我们先不加 --sjdbGTFfile 参数，直接构建纯序列库。

# 关于 STAR 构建索引时不加 --sjdbGTFfile 参数，以及并行运行多个索引构建任务，以下是详细的分析和操作建议。
# 一、 不加 --sjdbGTFfile 构建索引的优劣
# 在 STAR 中，如果不提供 GTF 注释文件构建的是“纯基因组索引”（Pure Genome Index）。
# 1. 好处（Pros）：
# 灵活性极高： 既然你目前只有 DNA Zoo 的基因组而没有完善的注释，先跑纯序列索引是唯一的选择。
# 节省内存和时间： 构建过程会更快，占用的磁盘空间也略小。
# 允许“2-Pass”比对： 即使索引里没有 GTF，你依然可以在比对（Mapping）阶段通过参数动态加入由 StringTie 组装出来的新注释。
# 避免错误引导： 如果参考物种（南美负鼠）的注释与北美负鼠差异太大，强行加入可能会导致比对到错误的外显子。
# 2. 坏处（Cons）：
# 剪接位点（Splice Junctions）灵敏度降低： STAR 无法预先知道外显子的位置。对于跨外显子的 reads（Split reads），它完全依赖算法自发寻找剪接位点，这会导致对低表达基因或复杂剪接情况的检测能力下降。
# 比对阶段稍慢： 因为 STAR 需要在比对过程中实时计算可能的剪接路径。
# 建议： 针对你的情况（非模式生物，无原物种注释），先构建纯序列索引是正确且专业的做法。后续你可以运行 STAR 2-Pass mode，让 STAR 在第一轮比对后自动学习剪接位点。

STAR --runThreadN 16 --runMode genomeGenerate --genomeDir ./star_index --genomeFastaFiles dv-2k.fasta

#        /usr/lib/rna-star/bin/STAR-avx2 --runThreadN 16 --runMode genomeGenerate --genomeDir ./star_index --genomeFastaFiles dv-2k.fasta
#         STAR version: 2.7.10a   compiled: 2022-01-16T16:35:44+00:00 <place not set in Debian package>
# Jun 11 18:30:30 ..... started STAR run
# Jun 11 18:30:30 ... starting to generate Genome files

# EXITING because of FATAL PARAMETER ERROR: limitGenomeGenerateRAM=31000000000is too small for your genome
# SOLUTION: please specify --limitGenomeGenerateRAM not less than 356942261173 and make that much RAM available 

# Jun 11 18:30:46 ...... FATAL ERROR, exiting
# (regular_bioinfo) gao@us1:/Work_bio/references/Didelphis_virginiana/mDidVir1


# 这是一个非常典型且令人抓狂的 STAR 报错。 # <<<<<<<<<<<< <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
# 报错原因分析
# STAR 提示需要约 332 GB (356,942,261,173 bytes) 的内存，这对于 3GB 的基因组来说极不寻常。
# 根本原因： 你的 DNA Zoo 基因组文件 dv-2k.fasta 过于破碎（Scaffolds/Contigs 数量太多）。
# STAR 默认的索引算法是为完整染色体设计的。如果基因组包含成千上万个小片段，STAR 会尝试为每个片段建立索引 bin，这会导致内存需求呈指数级爆炸，从而计算出 332GB 这种离谱的数字。


# 解决方案：调整 STAR 的参数
# 你不需要真的去加内存，而是需要通过两个关键参数告诉 STAR “这是一个非常破碎的基因组”。

# 第一步：检查你的基因组有多少条序列（Scaffolds）
# 在调整参数前，先用这个命令确认一下你的序列数量：
grep -c ">" dv-2k.fasta

#  grep -c ">" dv-2k.fasta
# 499601 
# 如果这个数字超过了 10,000 甚至达到几十万，那么必须调整参数。
# 第二步：使用 Vim 编写修正后的启动脚本
# 请使用 Vim 创建一个脚本，加入优化参数。
# code
# Bash
# vim fix_star_index.sh
# 在 Vim 中按下 i 进入插入模式，粘贴以下内容（注意我添加的两个关键参数）：
# code
# Bash
# #!/bin/bash

# # 计算公式建议：genomeChrBinNbits = min(18, log2(GenomeLength / NumberOfReferences))
# # 对于极其破碎的基因组，通常设置为 10 到 12

# STAR --runThreadN 16 \
#      --runMode genomeGenerate \
#      --genomeDir ./star_index \
#      --genomeFastaFiles dv-2k.fasta \
#      --limitGenomeGenerateRAM 64000000000 \
#      --genomeChrBinNbits 12 \
#      --genomeSAindexNbases 12
# 参数解析：
# --limitGenomeGenerateRAM 64000000000：限制 STAR 最多使用 64GB 内存（请根据你服务器的实际内存调整，如果是 128G 就写 128000000000）。
# --genomeChrBinNbits 12：最关键的参数。默认是 18。对于 Scaffolds 极多的基因组，必须降低这个值。调低它会大幅减少内存需求。
# --genomeSAindexNbases 12：辅助降低内存，默认 14，调低到 12。
# 在 Vim 中按 Esc 输入 :wq 保存。
# 第三步：运行修正脚本
# code
# Bash
# bash fix_star_index.sh
# 💡 为什么之前 BWA-MEM2 没有这个问题？
# bwa-mem2 的算法（FM-index）对基因组的连续性不敏感，它只在乎碱基总数。而 STAR 需要在内存中构建巨大的后缀数组映射表，如果片段太多，映射表就会变得无比巨大。
# 总结建议：
# 一定要加 --genomeChrBinNbits 12（甚至 10），否则 300G 内存也救不了这个任务。
# 串行执行： 现在由于内存压力巨大，请务必先跑完 STAR，再跑 bwa-mem2。不要同时开启两个任务，否则系统必崩。
# 检查磁盘空间： 这种破碎基因组产生的索引文件可能会非常多，请确保 ./star_index 所在的分区有足够的空间（至少 100GB）。


vim run_fixed_star.sh

# STAR --runThreadN 16 \
#      --runMode genomeGenerate \ # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  准备索引做基因组
#      --genomeDir ./star_index \
#      --genomeFastaFiles dv-2k.fasta \
#      --limitGenomeGenerateRAM 120000000000 \
#      --genomeChrBinNbits 11 \
#      --genomeSAindexNbases 12

# 参数说明：
# --genomeChrBinNbits 11: 这是解决 50 万条序列报错的最核心参数。
# --limitGenomeGenerateRAM 120000000000: 限制内存使用在 120GB。如果你的服务器只有 32GB 内存，请改成 30000000000。

# 世界也只是用了30几个G 的内存，所以这个索引文件也只占用30G
# Tasks: 873 total,   2 running, 871 sleeping,   0 stopped,   0 zombie
# %Cpu(s):  2.0 us,  0.7 sy,  0.0 ni, 97.2 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
# MiB Mem : 128731.2 total,  53756.0 free,  34203.8 used,  40771.4 buff/cache


# 4. 关于后续比对（Mapping）的警告
# 由于这个索引是针对 50 万个碎片建立的，你后续在使用 STAR 进行比对时，也需要消耗比平常更多的内存。
# 一个重要的建议：
# 如果你发现比对时内存还是不够，或者速度慢得无法接受，建议在建立索引前先对 dv-2k.fasta 进行一次长度过滤。例如，过滤掉所有长度小于 500bp 或 1000bp 的微小 Scaffolds。通常这些碎片对 RNA-seq 差异分析贡献极小，但却极大地拖慢了计算速度。
# 过滤脚本（Vim 编辑）：
# # 一个简单的 awk 过滤（过滤掉小于 1000bp 的序列）

awk 'BEGIN {RS=">";ORS=""} $1 ~ /\S/ {seq=$0; sub(/[^\n]*\n/,"",seq); gsub(/\s+/,"",seq); if (length(seq)>=1000) print ">"$0}' dv-2k.fasta > dv-2k-filtered.fasta

# 总结
# 请立即用 --genomeChrBinNbits 11 重新跑 STAR 索引。
# 只要这个参数改了，那 300GB 的内存需求就会降到 40GB 左右。








# 由于你没有注释，STAR 的比对建议增加以下参数：
# 在比对（Mapping）阶段，使用 --twopassMode Basic。 #=============================<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

STAR --runThreadN 16 \
     --genomeDir ./star_index \
     --readFilesIn read1.fq read2.fq \
     --twopassMode Basic \
     --outSAMtype BAM SortedByCoordinate

# 好处： 这会让 STAR 第一遍扫描发现新的剪接位点，第二遍再利用这些信息重新比对，这能极大地弥补你“索引没加 GTF”的缺陷，对非模式生物尤其重要。
# 总结：
# 不加 GTF 好处是灵活，坏处是剪接检测稍弱。
# 并行看内存，不够 128G 建议串行（用 && 连起来）。
# 比对时开启 twopassMode。     

# # 8. 全部索引建立完成后，安全退出 screen 会话
# exit
# (如果在构建期间想要去处理其他工作，请按 Ctrl + A 然后按 D 将 screen 挂起。随时可以通过 screen -r dv_index_task 恢复查看进度。)各类索引产出文件比对索引工具核心命令预期输出文件/目录主要适用分析场景Samtoolssamtools faidxdv-2k.fasta.fai随机提取目标序列、IGV 可视化参考BWA-MEM2bwa-mem2 indexdv-2k.fasta.bwt.2bit.64 等全基因组 DNA-seq、ChIP-seq 短读长比对STARSTAR --runMode genomeGeneratestar_index/ 目录（含 SA 等）scRNA-seq 或 Bulk RNA-seq 剪接比对Raw Markdown 代码（供你直接复制到 VS Code）：Markdown| 索引工具 | 核心命令 | 预期输出文件/目录 | 主要适用分析场景 |
# | :--- | :--- | :--- | :--- |
# | **Samtools** | `samtools faidx` | `dv-2k.fasta.fai` | 随机提取目标序列、IGV 可视化参考 |
# | **BWA-MEM2** | `bwa-mem2 index` | `dv-2k.fasta.bwt.2bit.64` 等 | 全基因组 DNA-seq、ChIP-seq 短读长比对 |
# | **STAR** | `STAR --runMode genomeGenerate` | `star_index/` 目录（含 `SA` 等） | scRNA-seq 或 Bulk RNA-seq 剪接比对 |
# 💡 关于北美负鼠分析的额外建议目前的瓶颈其实不在于 FASTA 序列，而在于极其缺乏高质量的官方注释文件（GTF/GFF）。如果你后续要做 scRNA-seq 或需要精确定量的 RNA-seq 分析，纯 Fasta 的 STAR 索引可能不足以精准识别跨越内含子的 read。针对这个问题，通常有两种解法：LiftOver 映射： 借用亲缘关系最近的短尾负鼠（Monodelphis domestica）的 GTF，通过序列比对工具强行映射过来。De novo 组装： 直接使用 StringTie 或 Trinity 等工具，结合你手头的深度 RNA-seq 测序数据自己进行一次转录本的组装。如果你的项目中确实缺少 GTF 注释，你会倾向于用哪种策略来推进后续的定量分析？