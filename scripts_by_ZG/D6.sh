nextflow run /home/songz/gaoz/GZ_Project_2026/rnaseq-3.12.0/main.nf \
    --conda /home/songz/miniforge3/envs/R44_RNA \
    --input /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/samplesheet_full.csv \
    --outdir /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216/results \
    --fasta /home/songz/lhn_work/database/02.genome/mouse_reference/Mus_musculus.fasta \
    --gtf /home/songz/lhn_work/database/02.genome/mouse_reference/Mus_musculus.gtf \
    -work-dir /home/songz/gaoz/work/01_Junqiang_Ding_0216 \
    --aligner star_salmon \
    --max_cpus 16 \
    --max_memory '64.GB' \
    -resume \
    --skip_dupradar --skip_rseqc --skip_biotype_qc \
    -with-report D6_final_fix.html
    