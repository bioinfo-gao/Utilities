cd /home/gao/projects_2026H2
git config http.postBuffer 524288000
git config http.timeout 600
git push origin master
# 首先查看您的提交历史
cd /home/gao/projects_2026H2
git log --oneline -3


# 完美！现在您的 .gitignore 文件已经包含了全面的规则来忽略生物信息学 pipeline 产生的大文件。

# 接下来的步骤
# 由于您已经有了完善的 .gitignore，现在可以安全地清理 Git 历史并重新推送：

# 1. 从 Git 历史中移除已跟踪的大文件

cd /home/gao/projects_2026H2

# 安装 git-filter-repo (如果还没有安装)
pip install git-filter-repo

# 或者使用系统包管理器
# conda install -c conda-forge git-filter-repo

# 清理 Git 历史中的大文件
git filter-repo --force --invert-paths \
  --path output_results/ \
  --path work/ \
  --path results/ \
  --path-glob "*.fastq*" \
  --path-glob "*.bam" \
  --path-glob "*.zip" \
  --path-glob "*.html"

# OR reset to remote

# 保存当前的工作目录状态（但不包括大文件）
cd /home/gao/projects_2026H2

# 创建备份
# cp -r scripts/ /tmp/scripts_backup/
# cp -r Data_Analysis/ /tmp/Data_Analysis_backup/

# # 重置到远程状态
# git reset --hard origin/master

# # 恢复必要的文件
# cp -r /tmp/scripts_backup/* scripts/
# cp -r /tmp/Data_Analysis_backup/* Data_Analysis/

# # 添加新的 .gitignore
# git add .gitignore

# # 只添加必要的小文件（脚本、分析结果等）
# git add scripts/*.R scripts/*.py scripts/*.sh
# git add Data_Analysis/**/*.csv Data_Analysis/**/*.md

# # 提交干净的版本
# git commit -m "Clean repository: remove large pipeline outputs, keep only essential files"

# # 强制推送到远程
# git push origin master --force-with-lease

3. 验证推送大小
在推送前检查推送大小：

git count-objects -vH