# 1. 确保在南美灰负鼠的正确工作目录下
cd /Work_bio/references/Monodelphis_domestica/MonDom5/ncbi_refseq

# 2. 使用 awk 终极清洗：只保留表头注释(^#) 以及第三列是 exon 或 CDS 的特征行
awk -F'\t' '$1 ~ /^#/ || $3 == "exon" || $3 == "CDS"' mDidVir1.annotation.gtf > clean_temp.gtf

# 3. 让 gffread 利用纯净的底层数据，自动重构标准的 GFF3 层级树
gffread clean_temp.gtf -o clean_ref_annotation.gff3

# 4. 成功后，清理临时文件
rm -f clean_temp.gtf

# 5. 再次彻底清理可能因为之前报错产生的垃圾数据库文件（防止 gffutils 继续读取缓存）
rm -f *.db *.db-shm *.db-wal

# 6. 重新执行 Liftoff 映射脚本
bash run_liftoff.sh