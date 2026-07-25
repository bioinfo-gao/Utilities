# !/bin/bash
# This script renames the 'git' folder to 'git_and_WSL' in a sparse checkout setup.

# show the current sparse-checkout configuration
git sparse-checkout list

# add the new folder to the sparse-checkout configuration
git sparse-checkout add git_and_WSL

# navigate to the target directory
cd Code/Linux_and_Cluster_for_Omics

# remove the old folder from the sparse-checkout configuration
git mv git git_and_WSL


