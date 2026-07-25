gao@us1 $ which R
(base) [12:22:12] [/home/gao]:
gao@us1 $  # means no R installed at all 

# 为了确保在安装 tidyverse 和 janitor 时 R 版本绝不动摇，您必须使用**“强制版本锁死”**安装指令。
# in mamba env base 
mamba install r-tidyverse r-janitor r-base=4.3.3 -c conda-forge --strict-channel-priority -y

# in mamba env  regular_bioinfo 
mamba activate regular_bioinfo 
mamba install r-tidyverse r-janitor r-base=4.5.3 -c conda-forge --strict-channel-priority -y

按下 Ctrl + Shift + P。
输入 Preferences: Open Remote Settings (JSON)

# 仅使用 customBinaries（最简单可靠）


{
    "positron.r.customBinaries": [
        "/Work_bio/gao/miniforge3/bin/R",       // R 4.3.3
        "/Work_bio/gao/configs/.conda/envs/regular_bioinfo/bin/R" // R 4.5.3
    ],
    "positron.r.customRootFolders": []
}

# 重启 Positron 
# upright corner change the R version