#!/bin/bash
# 1. 进入项目目录
cd /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216 || exit

# 2. 彻底放弃 -profile conda，直接把我们建好的环境路径“焊死”在 PATH 里
# 这样 Nextflow 找不到命令时，会直接用我们 R44_RNA 里的软件
export PATH="/home/songz/miniforge3/envs/R44_RNA/bin:$PATH"
export NXF_OFFLINE=true

# 核心命令：直接运行本地 rnaseq 目录下的 main.nf 确保不联网
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
    -resume