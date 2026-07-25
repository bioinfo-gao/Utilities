conda config --add channels defaults
conda config --add channels bioconda
conda config --add channels conda-forge # 按照从低到高的顺序添加，最后添加的会排在最顶端：
conda config --set channel_priority strict
conda config --show channels

mamba create -n regular_bioinfo \
    samtools \
    bcftools \
    bwa \
    bedtools \
    fastqc \
    multiqc \
    subread \
    python=3.10

mamba activate regular_bioinfo
# 生成索引 (nf-core 会自动做，但本地生成可加速)
samtools faidx GRCh38.primary_assembly.genome.fa


# 【关键步骤】生成指纹文件，用于后续验证文件是否被篡改
md5sum *.fa *.fai > checksums.md5

mamba install -c bioconda nextflow