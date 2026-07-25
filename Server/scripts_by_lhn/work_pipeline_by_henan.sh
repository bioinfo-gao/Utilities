#!/usr/bin/sh



path=`pwd`
nextflow run nf-core/rnaseq \
    -r 3.21.0 \
    --input $path/samplesheet.csv \
    --outdir $path/results_mouse_6 \
    --fasta /home/songz/lhn_work/database/02.genome/mouse_reference/Mus_musculus.fasta \
    --gtf /home/songz/lhn_work/database/02.genome/mouse_reference/Mus_musculus.gtf \
    -profile docker \
    -offline  \
    --remove_ribo_rna \
    --ribo_database_manifest /home/songz/lhn_work/database/03.rRNA/local_rrna_manifest.txt \
    --star_index /home/songz/lhn_work/Project_2025/Project_01_bulk_rnaseq_20251021/results_mouse/genome/index/star \
    --salmon_index /home/songz/lhn_work/Project_2025/Project_01_bulk_rnaseq_20251021/results_mouse/genome/index/salmon \
    -with-report report.html \
    -with-trace trace.csv \
    -with-timeline timeline.html \
    -with-dag flowchart.png
#    -resume


#     --save_reference , 第二次分析就可以使用之前的index。

