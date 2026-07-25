cd /home/gao/projects

git sparse-checkout add 2026_Item11_Mingxue_with_2_pairs_samples/

# 由于旧文件夹已经不存在，我们需要告诉 Git 这些文件已被删除
git add -u


git commit -m "Rename2 folder from 2026_Item11_Mingxue to 2026_Item11_Mingxue_with_2_pairs_samples to reflect 2 pairs of samples"


git push origin master


# 重要说明：

# 由于您使用的是 sparse-checkout，确保新的文件夹路径符合您的 sparse-checkout 配置
# Git 会将这个操作识别为文件夹重命名，而不是删除旧文件夹再创建新文件夹，这样可以保持文件的历史记录
# 提交信息中包含了重命名的原因（包含 2 pairs of samples），这有助于其他协作者理解更改的目的
# 请按照这些步骤操作，您的 GitHub 仓库就会正确同步文件夹重命名的更改。