# 创建一个名为 R44_RNA 的大环境（包含所有报错提到的软件）
mamba create -n R44_RNA -y star samtools gawk python=3.9 multiqc salmon cutadapt

mamba activate R44_RNA
# 再次确认，现在应该有输出了
which star
which samtools

screen -S Mouse_RNAseq_Mamba
screen -r Mouse_RNAseq_Mamba
# 激活环境（双重保险）
mamba activate R44_RNA



# 启动你的最终版脚本
bash run_mamba_rnaseq.sh


mamba install -y fastqc trim-galore subread salmon multiqc picard bioconductor-summarizedexperiment

# 确定自己是否在 screen 窗口里
echo $STY #1113953.Mouse_RNAseq_Mamba
# 如果在 screen 里：会显示当前 session 的名字（比如 23456.Mouse_RNAseq_Mamba）。

# 如果不在：返回一行空行。

which fastqc
which trim_galore
which featureCounts

mamba install -y rsem ucsc-genepredtodot psutils
which rsem-prepare-reference