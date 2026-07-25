# 1. 启动终端复用会话，确保后台稳定运行
tmux new -s download_opossum

# 2. 激活你的常规生信环境，以调用相应的索引工具
mamba activate regular_bioinfo

# 3. 安装 ncbi-datasets-cli 工具 (如果之前没有安装过)
mamba install -c conda-forge -c bioconda ncbi-datasets-cli -y

# 3. 创建北美负鼠的标准参考目录并进入
mkdir -p /Work_bio/references/Didelphis_virginiana/mDidVir1/ncbi_refseq
cd /Work_bio/references/Didelphis_virginiana/mDidVir1/ncbi_refseq


# 注意下载的是灰色短尾负鼠 (Monodelphis domestica) ，
# GCF_027887165.1 是灰色短尾负鼠 (Monodelphis domestica) 的基因组，而不是北美负鼠 (Didelphis virginiana)
# 4. 下载最新 Didelphis virginiana 基因组 + 注释（GTF）
datasets download genome taxon 9265 --include genome,gtf,protein,seq-report --filename didelphis_virginiana_genome.zip

# 5. 解压并重命名文件，对齐人类目录中的命名规范
unzip didelphis_virginiana_genome.zip -d didelphis_virginiana

# 进入目录查看
cd didelphis_virginiana/ncbi_dataset/data

# /mnt/ex_8T_SSD/references/Didelphis_virginiana/mDidVir1/ncbi_refseq/didelphis_virginiana/ncbi_dataset/data]:
# gao@us1 $ ll
# total 80
# -rw------- 1 gao gao 36542 Jun  8 21:05 assembly_data_report.jsonl
# -rw------- 1 gao gao  4509 Jun  8 21:15 dataset_catalog.json
# drwxrwxr-x 2 gao gao  4096 Jun  8 21:25 GCA_000002295.1
# drwxrwxr-x 2 gao gao  4096 Jun  8 21:25 GCA_016433145.1
# drwxrwxr-x 2 gao gao  4096 Jun  8 21:25 GCA_027887165.1
# drwxrwxr-x 2 gao gao  4096 Jun  8 21:25 GCA_027887165.2
# drwxrwxr-x 2 gao gao  4096 Jun  8 21:25 GCA_027917375.1
# drwxrwxr-x 2 gao gao  4096 Jun  8 21:25 GCA_904810665.1
# drwxrwxr-x 2 gao gao  4096 Jun  8 21:25 GCF_000002295.2
# drwxrwxr-x 2 gao gao  4096 Jun  8 21:25 GCF_016433145.1
# drwxrwxr-x 2 gao gao  4096 Jun  8 21:25 GCF_027887165.1

# 3. 理解 GCF vs. GCA 的命名玄学
# NCBI 的命名本身就带有强烈的质量导向：
# GCF (RefSeq)：代表 NCBI 参考序列数据库。这是 NCBI 经过审核、清洗、并进行标准化注释的基因组，通常质量最高，被全球科研界视为“标准参考”。
# GCA (GenBank)：代表 提交者的原始提交。可能是某个测序中心直接上传的原始数据，质量参差不齐。
# 首选 GCF_027887165.1 (数字越新通常越好)：
# 如果 GCF_027887165.1 的 BUSCO 分数更高且 Contig N50 更大，请直接使用它。这是因为

# 简单来说：GCF_016433145.1 是经典的“骨架版”，而 GCF_027887165.1 通常是基于更新的测序技术（如长读长测序 PacBio/Oxford Nanopore）得到的“高精度版”。

# 1. 为什么会有多个 GCF 版本？
# NCBI 的 RefSeq 数据库会根据提交的组装质量进行更新。通常：

# GCF_016433145.1：可能是基于较早的 Illumina 短读长数据组装的。

# GCF_027887165.1：极有可能是利用了近年来流行的长读长测序（Long-read sequencing）技术重新进行的组装。

# 2. 如何判断谁更适合你的分析？
# 你可以运行下面这行命令，对比两个版本在报告中的差异：


# /mnt/ex_8T_SSD/references/Didelphis_virginiana/mDidVir1/ncbi_refseq/didelphis_virginiana/ncbi_dataset/data
# # 使用 jq 工具提取关键指标（若未安装，可用 cat 查看 assembly_data_report.jsonl） #jq - commandline JSON processor [version 1.8.1]
# # 查看 GCF_016433145.1 的元数据
# grep "GCF_016433145.1" assembly_data_report.jsonl | jq '.assembly_stats'
# # 查看 GCF_027887165.1 的元数据
# grep "GCF_027887165.1" assembly_data_report.jsonl | jq '.assembly_stats'

# 6.cp and keep the same directory structure as Home genome directory
cd /Work_bio/references/Didelphis_virginiana/mDidVir1/ncbi_refseq/didelphis_virginiana/data

# 6.1. 选取最完整的版本 (GCF_027887165.1) 并提取关键文件
# 注意：NCBI 下载的文件通常在子目录下
cp GCF_027887165.1/*.fna ../../mDidVir1.genome.fa
cp GCF_027887165.1/*.gtf ../../mDidVir1.annotation.gff

# 7. 生成 Samtools 的 faidx 索引 (对应你人类目录里的 .fai 文件)
samtools faidx mDidVir1.genome.fa

# 8. 生成 bwa-mem2 索引 (对应你人类目录里的 .bwt.2bit.64 等文件)
# 注意：该步骤极其消耗内存，请确保服务器处于空闲状态 <<<========== 1h30 min , used 67G memory !
bwa-mem2 index mDidVir1.genome.fa

bwa-mem2 index mDidVir1.genome.fa
Looking to launch executable "/Work_bio/gao/configs/.conda/envs/regular_bioinfo/bin/bwa-mem2.avx2", simd = .avx2
Launching executable "/Work_bio/gao/configs/.conda/envs/regular_bioinfo/bin/bwa-mem2.avx2"
[bwa_index] Pack FASTA... 16.07 sec
* Entering FMI_search
init ticks = 229341528960
ref seq len = 7172333146
binary seq ticks = 151621243260                                                                                                                                           build suffix-array ticks = 9253966856130
ref_seq_len = 7172333146
count = 0, 2222417160, 3586166573, 4949915986, 7172333146
BWT[4597844237] = 4
CP_SHIFT = 6, CP_MASK = 63
sizeof CP_OCC = 64
pos: 896541644, ref_seq_len__: 896541643
max_occ_ind = 112067705
build fm-index ticks = 1447204028640
Total time taken: 3726.3268

# 故 /Work_bio/references/Didelphis_virginiana/mDidVir1/ncbi_refseq/ 被move 到 /Work_bio/references/Monodelphis_domestica/MonDom5/  

# 9. 为下一步的单细胞/转录组比对创建 star_index 空目录
mkdir star_index
# 如果你要接着直接构建 STAR 索引，请根据你的测序读长(如 --sjdbOverhang 149)执行以下命令 

# # 1. 转换为标准 GTF
# gffread mDidVir1.annotation.gff -T -o mDidVir1.annotation.gtf

# # -w-dup: 忽略重复的转录本 ID
# # --E: 对格式不规范的异常行进行丢弃/容错，不直接中断
# gffread mDidVir1.annotation.gff -T -w-dup --E -o mDidVir1.annotation.gtf

# 方案二：使用 agat 工具箱进行标准清洗（最推荐、最稳妥） <<=====================
# 如果 gffread 加上参数后依然报错，说明该 GFF 文件中存在结构性冲突。在处理 NCBI 复杂的 GFF3 时，生信界现在更推崇使用 AGAT (Another GFF Analysis Toolkit)，它能完美修复各种不规范的 GFF 记录并转换为标准的 GTF。

# Bash
# # 1. 安装 AGAT (如果环境中没有的话)
mamba install -c bioconda agat -y 

# 2. 使用 AGAT 的专用脚本进行转换（它会自动识别并修复没有有效 ID 的行）
agat_convert_sp_gff2gtf.pl --gff mDidVir1.annotation.gff -o mDidVir1.annotation.gtf


tmux a 

cd /Work_bio/references/Monodelphis_domestica/MonDom5/ncbi_refseq/
ll -h
mamba activate regular_bioinfo
# 2. 这时就可以完美运行标准的 STAR 命令了（注意：后缀改成了 .gtf）
STAR --runThreadN 16 \
     --runMode genomeGenerate \
     --genomeDir ./star_index \
     --genomeFastaFiles mDidVir1.genome.fa \
     --sjdbGTFfile mDidVir1.annotation.gtf \
     --sjdbOverhang 149


# 注意：这个参数在 STAR 构建索引时的定义是：读长减去 1 (Read Length - 1)


