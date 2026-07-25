# 1. 配置 Git 全局身份（必需）
# 配置用户身份（不配置无法提交）
git config --global user.name "ZG_Tailscale"
git config --global user.email "bioinfo.gao@gmail.com"

# 验证配置
git config --global user.name
git config --global user.email
git config --global --list

# 2. 配置 SSH 密钥（用于 GitHub 认证）
# 生成 SSH 密钥（如果还没有）
ssh-keygen -t ed25519 -C "bioinfo.gao@gmail.com" -f ~/.ssh/id_ed25519 -N ""

# 2. 添加到 ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# 3. 复制公钥到 GitHub
cat ~/.ssh/id_ed25519.pub
# 复制输出，到 GitHub -> Settings -> SSH and GPG keys -> New SSH key

# 4. 测试
ssh -T git@github.com
# 看到：Hi username! You've successfully authenticated...

# 4. Sparse Checkout 完整流程
# 创建工作目录
mkdir -p ~/projects && cd ~/projects

# 初始化空仓库
git init GZ_Projects_2026
cd GZ_Projects_2026

# 添加远端
git remote add origin git@github.com:bioinfo-gao/GZ_Projects_2026.git

# 先清理旧配置 （如果之前设置过）
# git config --unset core.sparseCheckoutCone 2>/dev/null || true

# 启用 sparse-checkout
git config core.sparseCheckout true

# 查看已包含的目录列表：
git sparse-checkout list

## 设置为空（什么都不下载）
git sparse-checkout set 

echo ""
echo "完成，当前文件数: $(git ls-files | wc -l)"
echo ""
echo "现在可以添加文件夹了:"
echo "  git sparse-checkout add 2026_Item2_0205_contamination_athenomics"

# show the current sparse-checkout configuration
git sparse-checkout list

# add one 
git sparse-checkout add Utilities

# set the current ones (会覆盖之前的设置，所以如果之前设置了 2026_Item2_0205_contamination_athenomics 就会被覆盖掉)
git sparse-checkout set 2026_Item2_0205_Jitu Utilities

