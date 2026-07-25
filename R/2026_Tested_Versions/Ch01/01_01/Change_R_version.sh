#  Edit the file  ~/.config/rstudio/rsession.conf 

# select the correct version of R, and comment out the other versions

# 比如我现在想要用R4.3.3
# R4.3.3
rsession-which-r=/home/zhen/miniforge3/envs/seurat_env/bin/R
rsession-ld-library-path=/home/zhen/miniforge3/envs/seurat_env/lib

# R4.5.1
# rsession-which-r=/home/zhen/miniforge3/envs/spatial_R/bin/R
# rsession-ld-library-path=/home/zhen/miniforge3/envs/spatial_R/lib

# 每次修改后重启RStudio Server：
sudo rstudio-server restart