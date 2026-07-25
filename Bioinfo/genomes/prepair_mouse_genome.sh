# 创建目录
#mkdir -p /Work_bio/references/Homo_sapiens/GRCh38/GENCODE/human_gencode_v45
mkdir -p /Work_bio/references/Mus_musculus/GRCm39/GENCODE_M35
cd /Work_bio/references/Mus_musculus/GRCm39/GENCODE_M35

# 下载基因组 FASTA, 1min
wget https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_mouse/release_M35/GRCm39.primary_assembly.genome.fa.gz

# 下载注释 GTF, 5s
wget https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_mouse/release_M35/gencode.vM35.annotation.gtf.gz

# 官方 MD5
wget https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_mouse/release_M35/MD5SUMS

# 3. 进行 MD5 校验
# 我们只需要校验下载的那两个文件
grep -E "GRCm39.primary_assembly.genome.fa.gz|gencode.vM35.annotation.gtf.gz" MD5SUMS | md5sum -c

# 解压 (Nextflow 脚本通常可以直接识别 .gz，但建议解压以方便检查) # 10s 
gunzip GRCm39.primary_assembly.genome.fa.gz
gunzip gencode.vM35.annotation.gtf.gz

# 1. 检查文件大小 (Sanity Check)
# GRCm39.primary_assembly.genome.fa: 约 2.6 GB - 2.7 GB
# gencode.vM35.annotation.gtf: 约 800 MB - 900 MB
# 解压后的 Mouse GRCm39 Primary Assembly 和 GTF vM35 应该具有以下量级的大小。如果你的文件显著偏小（例如只有几百 MB），说明下载或解压过程中断了。

ls -lh GRCm39.primary_assembly.genome.fa gencode.vM35.annotation.gtf

# 既然已经解压了，官方提供的基于 .gz 压缩包的 MD5 校验确实无法直接使用了（因为压缩算法的版本、参数不同，重新压缩后的 MD5 会完全不同）。
# 没关系，我们可以通过文件大小校验和结构完整性检查来确认文件是否损坏。这是资深生信工程师在解压后的标准操作：

#  检查文件尾部 (确认没有截断)
# 文件下载中断最常见的情况是“只下载了一半”。我们检查文件的最后几行，看是否完整。
tail -n 5 GRCm39.primary_assembly.genome.fa
#检查 GTF：
tail -n 20 gencode.vM35.annotation.gtf


# 进入conda 环境，安装必要的软件或者利用已有环境，并生成索引
mamba activate regular_bioinfo

# samtools faidx GRCh38.primary_assembly.genome.fa # 生成索引 (nf-core 会自动做，但本地生成可加速)
samtools faidx GRCm39.primary_assembly.genome.fa # 生成索引 (mouse 版本)

# samtools faidx 就像是一本书的“目录”：
# 你想看第三章（chr3）在哪里？翻开目录，直接跳到第 200 页。
# 但如果你问：“‘核糖体蛋白’这个词在整本书里出现了多少次，都在哪？” 目录帮不了你。
# STAR 索引就像是这本书的“关键词详查索引”：
# 它记录了书中每一个词（read）出现在哪一页、哪一行。
# 虽然为了做这个索引，要把书拆了重组，索引甚至比书本身还大，但搜索速度极快。

sudo apt install rna-star
# 只要这个命令能跑通而不报错，通常说明 FASTA 和 GTF 结构是完整的

# Exact 1.5 hour

STAR --runMode genomeGenerate \
     --runThreadN 16 \
     --genomeDir ./star_index \
     --genomeFastaFiles GRCm39.primary_assembly.genome.fa \
     --sjdbGTFfile gencode.vM35.annotation.gtf \
     --sjdbOverhang 149    

# STAR 生成索引所需的内存大约是 基因组大小的 10 倍。
# 人类基因组 (3Gb) 
#  建议设置 32GB - 40GB。
# --limitGenomeGenerateRAM 45000000000
# STAR does not support shorthand units like "G" or "GB" f
# --limitGenomeGenerateRAM $((45 * 1024 * 1024 * 1024))

# du -h star_index/
# 26G     star_index/


# 这个命令会生成 STAR 索引，存储在 ./star_index 目录下。索引文件通常比原始 FASTA 大很多（可能达到 10-20 倍），这是正常的。
# 如果输出大部分是 150：请用 --sjdbOverhang 149。     
# 如果你要建一个通用索引（未来可能给不同读长的数据用）：设为 100 是最保险的平衡点。

# 不确定自己的测序长度，可以用这个命令看一眼：
# zcat ch_2B_..._1.fq.gz | head -n 4000 | awk 'NR%4==2 {print length($0)}' | sort | uniq -c

# 如果没有加上 --save_reference 参数，Nextflow 默认不会把生成的 Index 放到你的 --outdir 结果目录里，而是把它“藏”在了复杂的 work/ 文件夹深处。
# 以下是详细的查找方法和逻辑解释：

# 1. 为什么你在结果目录看不到它？
# Nextflow 的设计哲学是“结果目录只放最终结果（如表达量表、QC报告）”。中间过程产生的大型文件（比如 30GB 的 STAR Index）默认只存在于 work/ 目录中。
# 如果你想在结果目录看到它：你必须在命令中加上 --save_reference。
# 如果你没加：它就在 work/ 的某个随机命名的子目录下。

# 2. 如何找到上午生成的“人”的 Index？
# 你可以通过以下两个方法把那个“消失”的人类 Index 找出来：
# 方法 A：使用 Nextflow 日志定位（最科学）
# 在终端输入：

# 不想找了，直接重跑一次，命令里加上 --save_reference 就好了。