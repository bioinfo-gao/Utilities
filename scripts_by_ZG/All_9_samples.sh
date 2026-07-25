# 1. 进入你指定的正确工作目录
cd /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216

# 2. 激活环境并确保 PATH 包含你刚下载的软件
mamba activate R44_RNA
export PATH="/home/songz/gaoz/software:/home/songz/gaoz/software/qualimap_v2.3:$PATH"

# 3. 运行 Nextflow (严格使用正确的路径和已补齐的工具)
nextflow run /home/songz/gaoz/GZ_Project_2026/rnaseq-3.12.0/main.nf \
    --input ./samplesheet_full.csv \
    --outdir ./results \
    --fasta /home/songz/lhn_work/database/02.genome/mouse_reference/Mus_musculus.fasta \
    --gtf /home/songz/lhn_work/database/02.genome/mouse_reference/Mus_musculus.gtf \
    -work-dir /home/songz/gaoz/work/01_Junqiang_Ding_0216 \
    --aligner star_salmon \
    --max_cpus 16 \
    --max_memory '64.GB' \
    --skip_dupradar \
    --skip_rseqc \
    --skip_biotype_qc \
    --skip_preseq \
    -resume