screen -ls | grep -oP '\d+\.Mouse_RNAseq_Mamba' | xargs -r screen -X -S quit
screen -wipe


# songz:~/gaoz$ screen -wipe
# There is a screen on:
#         3884713.rnaseq_project  (02/19/2026 02:16:02 PM)        (Detached)
# 1 Socket in /run/screen/S-songz.

screen -X -S 3884713 quit

screen -S Mouse_RNAseq_Mamba


cd /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216
export NXF_OFFLINE=true
bash run_mamba_rnaseq.sh


screen -r Mouse_RNAseq_Mamba


mamba create --yes --prefix /home/songz/gaoz/work/01_Junqiang_Ding_0216/conda/env-3b5d56f28b7df4af6d1c33dc602a1280 bioconda::star=2.7.10a bioconda::samtools=1.16.1 conda-forge::gawk=5.1.0
mamba create --yes --prefix /home/songz/gaoz/work/01_Junqiang_Ding_0216/conda/env-26bbe61d6cbca5f71da2d7fcef2c52eb bioconda::multiqc=1.14
cd /home/songz/gaoz/GZ_Project_2026/01_Junqiang_Ding_0216
bash run_mamba_rnaseq.sh

mkdir -p /home/songz/gaoz/work/01_Junqiang_Ding_0216/conda/env-3b5d56f28b7df4af6d1c33dc602a1280
mkdir -p /home/songz/gaoz/work/01_Junqiang_Ding_0216/conda/env-26bbe61d6cbca5f71da2d7fcef2c52eb

ln -sf $(which star) /home/songz/gaoz/work/01_Junqiang_Ding_0216/conda/env-3b5d56f28b7df4af6d1c33dc602a1280/bin/star
ln -sf $(which samtools) /home/songz/gaoz/work/01_Junqiang_Ding_0216/conda/env-3b5d56f28b7df4af6d1c33dc602a1280/bin/samtools
ln -sf $(which gawk) /home/songz/gaoz/work/01_Junqiang_Ding_0216/conda/env-3b5d56f28b7df4af6d1c33dc602a1280/bin/gawk
touch /home/songz/gaoz/work/01_Junqiang_Ding_0216/conda/env-3b5d56f28b7df4af6d1c33dc602a1280/conda-meta/history 2>/dev/null || mkdir -p /home/songz/gaoz/work/01_Junqiang_Ding_0216/conda/env-3b5d56f28b7df4af6d1c33dc602a1280/conda-meta && touch /home/songz/gaoz/work/01_Junqiang_Ding_0216/conda/env-3b5d56f28b7df4af6d1c33dc602a1280/conda-meta/history