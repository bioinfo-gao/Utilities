# 创建全局 gitignore
echo ".gemini/" >> ~/.gitignore_global

# 配置 Git 使用全局 ignore 文件
git config --global core.excludesfile ~/.gitignore_global