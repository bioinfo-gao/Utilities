# =====================================================
# =====================================================
# 把一个 java code repository merge 进来 ， 合成一个repository

# =====================================================
1 将 Java 仓库添加为临时的远程源（例如 java-remote）：

git remote add java-remote git@github.com:bioinformatics-gao/CASE-BBB-prediction-Java-Weka-code.git

# =====================================================
2 拉取 Java 仓库的历史记录：

git fetch java-remote

# =====================================================
# git switch master

3 使用 Git Read-Tree（推荐，更专业）
将 Java 历史读取到子目录： 使用 git read-tree 命令将 java-remote/master 分支的全部内容加载到当前分支的 java_code/ 目录下：

git read-tree --prefix=java_code/ -u java-remote/master

# --prefix=java_code/: 指定将所有文件放置在这个子目录下。
# -u: 更新工作目录（update the working directory）。

# =====================================================
4 commit 

git commit -m "Merge: Import Java repository history into java_code/ subdirectory"

# =====================================================
5 清理：

git remote remove java-remote

# =====================================================
# =====================================================
# =====================================================
# =====================================================
# =====================================================