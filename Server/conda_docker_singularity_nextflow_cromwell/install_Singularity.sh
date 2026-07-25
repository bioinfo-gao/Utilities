# To install Singularity (now largely succeeded by Apptainer), the recommended method is to install from pre-built packages 
# For Ubuntu/Debian:
# Add the official Apptainer PPA repository: 
# sudo apt update # NEVER run the updata for a administrative user, it may cause unexpected problems. Instead, run the update for a normal user.

sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:apptainer/ppa

# sudo apt update
# Install Apptainer:
sudo apt install -y apptainer

方案一：如果你只想运行整个流程（推荐）你不需要手动 singularity pull 镜像。
只要在运行 Nextflow 时指定 -profile singularity，Nextflow 会自动处理所有镜像下载：


nextflow run nf-core/rnaseq \
    -r 3.14.0 \
    -profile singularity \
    --input samplesheet.csv \
    --outdir /path/to/your/results \
    --fasta /path/to/shared/reference/genomes/Homo_sapiens/GRCh38/GENCODE/v45/GRCh38.primary_assembly.genome.fa \
    --gtf /path/to/shared/reference/genomes/Homo_sapiens/GRCh38/GENCODE/v45/gencode.v45.annotation.gtf \
    --gencode \
    --aligner star_salmon \
    --remove_ribo_rna \
    --save_reference \
    --save_nonrRNA_reads \
    --skip_qc \
    --max_cpus 16 \
    --max_memory '64.GB'