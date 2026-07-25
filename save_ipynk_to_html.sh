# 1. 确认当前 Python 环境在 VS Code 右下角（或右上角）查看你当前 Notebook 使用的 Kernel (内核) 名称。
mamba activate qc_env
# Here is mamba activate qc_env

# 确保你在终端中操作的是同一个环境。

# 2. 安装缺失的工具包打开 VS Code 顶部的 Terminal (终端) 菜单，选择 New Terminal (新建终端)，
# 然后根据你的环境管理器输入以下命令：如果你使用 pip (最常见):bash
pip install nbconvert pandoc

# 3. 点击 top "..." (More Actions) -> Export (导出) -> HTML。