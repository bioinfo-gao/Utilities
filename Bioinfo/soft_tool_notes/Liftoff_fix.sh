# Liftoff 报错了：UnboundLocalError: local variable 'feature_db' referenced before assignment。
# 这是一个 Liftoff 的已知 Bug。它通常发生在 Liftoff 尝试通过 gffutils 构建参考注释数据库时失败，导致变量没有被正确赋值就进入了下一步。
# 报错深度分析
# 数据库冲突： Liftoff 在运行时会生成一个临时的 .db 文件。如果之前的运行（即使是失败的）留下了同名文件，会导致冲突。
# GTF/GFF 格式不规范： 南美负鼠的 ncbi_refseq 注释中，如果存在重复的 ID 或者格式不符合 gffutils 的严格要求，会导致数据库构建中断。
# 染色体名称不匹配： 如果参考基因组（Monodelphis）的 Fasta 里的 ID（如 NC_00001）和 GTF 里的第一列不完全一致，也会触发此类错误。
# 解决方案（使用 Vim 修复环境）
# 请按照以下步骤，使用 Vim 调整环境并重新运行 Liftoff：
# 1. 清理所有残留的数据库文件
# Liftoff 失败后往往会留下破损的 SQL 数据库文件。

tmux a 
cd /Work_bio/references/Didelphis_virginiana/mDidVir1/DNA_Zoo/
rm -f *.db

# 2. 检查染色体名称一致性 (关键)
# 请运行以下两个命令，对比输出的前 5 行：
# code
# Bash
# # 查看 Fasta ID
grep ">" /Work_bio/references/Monodelphis_domestica/MonDom5/ncbi_refseq/mDidVir1.genome.fa | head -n 5

# NC_077227.1 Monodelphis domestica isolate mMonDom1 chromosome 1, mMonDom1.pri, whole genome shotgun sequence

# # 查看 GTF 第一列
cut -f 1 /Work_bio/references/Monodelphis_domestica/MonDom5/ncbi_refseq/mDidVir1.annotation.gtf | grep -v "#" | head -n 5


# NC_077230.1
# NC_077230.1


# 好的，数据对齐情况现在非常清晰了：
# Fasta ID: >NC_077227.1 (后面带有长描述)
# GTF 第一列: NC_077230.1 (纯 Accession 号)
# 结论： 两者的核心 ID 是匹配的，但 Fasta 里的长描述可能干扰了某些版本的 pysam 或 liftoff 的解析。此外，UnboundLocalError 在 Liftoff 中 99% 的情况下是由于 GTF 格式中的不规范条目 导致数据库（.db）构建中断。

# 第一步：清理参考文件 (Vim + awk)
# 我们需要把 Fasta 简化，并把 GTF 清洗干净。

cd /Work_bio/references/Monodelphis_domestica/MonDom5/ncbi_refseq/

# 1. 简化 Fasta ID（只保留 NC_... 部分，去掉空格后的描述）
awk '{print $1}' mDidVir1.genome.fa > mDidVir1.simple.fa

# 2. 清洗 GTF（只保留 Liftoff 运行所需的 4 种核心特征，防止格式报错）
awk '$3 ~ /gene|mRNA|exon|CDS/' mDidVir1.annotation.gtf > mDidVir1.cleaned.gtf



# 修改 Liftoff 脚本 (Vim)
# 请进入你的 DNA Zoo 目录并修改脚本：

cd /Work_bio/references/Didelphis_virginiana/mDidVir1/DNA_Zoo/
vim run_liftoff.sh
# 在 Vim 中按 i 插入，修改为以下内容： see file 

# 第三步：在 tmux 中再次启动
# 回到会话： tmux attach -t sftp_work
# 启动脚本： 
bash run_liftoff.sh
# extracting features
# Populating features table and first-order relations: 484000 features

rm -f *.db

vim check_gtf.py

# # 3. 进入你的北美负鼠基因组工作目录
# cd /Work_bio/references/Didelphis_virginiana/mDidVir1/DNA_Zoo/

# 1. 启动全新的会话来执行修复和映射流程
tmux new -s liftoff 
#tmux a 

# 2. 激活我们约定好的新环境
mamba activate regular_bioinfo

# 3. 进入南美灰负鼠 
cd /Work_bio/references/Monodelphis_domestica/MonDom5/ncbi_refseq

# 4 彻底删除上次运行失败残留的损坏数据库文件 (非常重要，否则 Liftoff 会一直报错)
# 4. 清理上次运行失败残留的损坏数据库文件
rm -f *.db *.db-shm *.db-wal

# 2. 过滤 GTF 文件：只保留表头注释行(^#) 和 包含 'gene_id' 的标准基因/转录本/外显子行
grep -E "^#|gene_id" mDidVir1.annotation.gtf > clean_temp.gtf

# 3. 重新运行 gffread
# (这里去掉了 -E 和 -O，让 gffread 自动为你重构最标准的 GFF3 层级 ID，这正是 Liftoff 最喜欢的格式)
gffread clean_temp.gtf -o clean_ref_annotation.gff3

# 6. 使用 vim 编辑你的运行脚本，将里面的注释文件参数修改为刚刚生成的 clean_ref_annotation.gff3
vim run_liftoff.sh
# 全部内容如下：


#!/bin/bash
# 1. 彻底删除之前运行失败留下的数据库残余，否则会一直报错
rm -f *.db
rm -f *.db-shm *.db-wal

# 2. 定义路径（指向刚才清理后的文件）
REF_FA="/Work_bio/references/Monodelphis_domestica/MonDom5/ncbi_refseq/mDidVir1.simple.fa"
REF_GTF="/Work_bio/references/Monodelphis_domestica/MonDom5/ncbi_refseq/clean_ref_annotation.gff3"
TARGET_FA="/Work_bio/references/Didelphis_virginiana/mDidVir1/DNA_Zoo/dv-2k.fasta"

# 3. 运行 Liftoff
# 注意：$TARGET_FA（北美负鼠）在前，$REF_FA（南美负鼠）在后。
liftoff -g $REF_GTF \
	-o Didelphis_v.liftoff.gtf \
	-u unmapped.txt \
	-p 16 \
	-sc 0.85 \
	-flank 0.1 \
	$TARGET_FA \
	$REF_FA



# 7. 重新运行你的 Liftoff 映射脚本
bash run_liftoff.sh


# 4. 使用修正后的脚本重新运行 Liftoff
# 使用 Vim 修改你的 run_liftoff.sh：
# code
# Bash
# vim run_liftoff.sh
# 在 Vim 中将 REF_GTF 指向刚才生成的 cleaned_ref.gtf，并增加两个安全参数：
# code
# Bash
# #!/bin/bash
# TARGET_FA="/Work_bio/references/Didelphis_virginiana/mDidVir1/DNA_Zoo/dv-2k.fasta"
# REF_FA="/Work_bio/references/Monodelphis_domestica/MonDom5/ncbi_refseq/mDidVir1.genome.fa"
# # 使用清理后的 GTF
# REF_GTF="./cleaned_ref.gtf"

# liftoff -g $REF_GTF \
#         -o Didelphis_v.liftoff.gtf \
#         -u unmapped.txt \
#         -p 16 \
#         -sc 0.85 \
#         -flank 0.1 \
#         -copy_counts \
#         $TARGET_FA $REF_FA
# 注：-flank 0.1 增加侧翼序列比对，-copy_counts 有助于处理多拷贝基因。
# 5. 在 tmux 中重新启动
# code
# Bash
# # 确保旧的 db 文件已删干净
# rm -f *.db 

# # 运行
# bash run_liftoff.sh
# 💡 为什么我会建议“清理 GTF”？
# Liftoff 内部使用的 gffutils 库在遇到“没有父节点的子节点”或“重复 ID”时会抛出异常。通过 awk 过滤核心 feature，可以极大地减少数据库构建失败的几率。
# 如果这样做之后还是报同样的 UnboundLocalError：
# 这通常意味着 Liftoff 彻底无法在你的 Fasta 中找到任何 GTF 里提到的染色体。请再次检查第 2 步的名称对比。
# 一旦 Liftoff 成功运行，你会在屏幕上看到 “mapping features” 的进度条，那就说明我们已经跨过了这个 Bug！你的 sFTP (bore.pub:54833) 还在工作吗？如果这一步通了，这就是最值得庆祝的进展。


内存监控： 运行 Liftoff 时，由于它需要同时比对两套基因组，内存占用可能会瞬间冲到 80G+，你的 128G 内存刚好可以完美覆盖。
基因组 ID： Liftoff 运行结束后，记得检查一下 Didelphis_v.liftoff.gtf 的内容，确保基因 ID 是你熟悉的南美负鼠名称。
一切准备就绪，按照脚本顺序运行即可！