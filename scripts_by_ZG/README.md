# Bulk RNA-seq Analysis Project - Junqiang Ding

## Project Overview
This project contains bulk RNA-seq data for 9 samples (D1-D9) from Junqiang Ding's experiment. The analysis follows the nf-core/rnaseq pipeline v3.21.0 workflow.

## Project Structure
```
01_Junqiang_Ding_0216/
├── 01.fq/                    # Raw sequencing data and download scripts
│   ├── 01.RawData/           # Raw FASTQ files organized by sample
│   ├── create_symlinks.sh    # Script to create R1/R2 symbolic links
│   ├── download_missing_D9.sh # Script to download missing D9 files
│   ├── sync_robust.lftp      # LFTP configuration for robust downloads
│   └── verify.log            # Download verification log
├── samplesheet.csv           # Sample metadata for nf-core/rnaseq pipeline
├── work_pipeline.sh          # Main analysis pipeline script
└── README.md                 # This documentation file
```

## Sample Information
- **Total Samples**: 9 (D1-D9)
- **Sequencing Type**: Paired-end
- **Strandedness**: Reverse
- **File Format**: FASTQ.gz

## Data Download Status
- **Download Date**: February 17, 2026
- **Status**: Mostly complete, D9 R2 files may need re-download
- **Verification**: MD5 checksums available in `01.fq/MD5.txt`

## Analysis Pipeline
This project uses **nf-core/rnaseq v3.21.0** with the following configuration:

### Reference Genome
- Species: To be confirmed (likely Mouse/Mus musculus based on project context)
- Reference files location: `/home/songz/lhn_work/database/02.genome/mouse_reference/`

### Required Files
- **FASTA**: Reference genome sequence
- **GTF**: Gene annotation file
- **rRNA Database**: For ribosomal RNA removal

### Pipeline Configuration
- **Profile**: Docker
- **Mode**: Offline execution
- **Output Directory**: `results_mouse_9` (to be created)

## Usage Instructions

### 1. Fix File Naming (if needed)
```bash
cd 01.fq
bash create_symlinks.sh
```

### 2. Download Missing Files (D9)
```bash
cd 01.fq  
bash download_missing_D9.sh
```

### 3. Verify Data Integrity
```bash
# Check MD5 checksums
md5sum -c MD5.txt
```

### 4. Run Analysis Pipeline
```bash
# Execute the main pipeline script
bash work_pipeline.sh
```

## Quality Control
- **FastQC**: Raw data quality assessment
- **MultiQC**: Aggregated quality reports
- **featureCounts**: Gene-level expression quantification
- **Salmon**: Transcript-level expression quantification

## Expected Output
- **Gene Counts**: `featureCount/gene_counts.txt`
- **FPKM Matrix**: `featureCount/FPKM_matrix.txt`
- **TPM Matrix**: `featureCount/TPM_matrix.txt`
- **Quality Reports**: `multiqc_report.html`

## Troubleshooting
- **Incomplete Downloads**: Use `download_missing_D9.sh` for missing files
- **File Naming Issues**: Run `create_symlinks.sh` to fix path mismatches
- **Pipeline Errors**: Check Nextflow logs in `work/` directory

## References
- **nf-core/rnaseq**: https://nf-co.re/rnaseq
- **Nextflow**: https://www.nextflow.io/
- **Docker**: https://www.docker.com/

---
*Project created on February 18, 2026*
*Based on Li Xiaofei's bulk RNA-seq project configuration*