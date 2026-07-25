which R
# (base) [12:22:12] [/home/gao]:
# gao@us1 $  # means no R installed at all 

# 为了确保在安装 tidyverse 和 janitor 时 R 版本绝不动摇，您必须使用**“强制版本锁死”**安装指令。
# in mamba env base 
# mamba install r-tidyverse r-janitor r-base=4.3.3 -c conda-forge --strict-channel-priority -y

which R
R --version
#R version 4.3.3 (2024-02-29) -- "Angel Food Cake"

# in mamba env  regular_bioinfo 
mamba activate regular_bioinfo 
# mamba install r-tidyverse r-janitor r-base=4.5.3 -c conda-forge --strict-channel-priority -y
which R
R --version
# R version 4.5.3 (2026-03-11) -- "Reassured Reassurer"

# in mamba env DE_R45 
mamba activate DE_R45 
# mamba install r-tidyverse r-janitor r-base=4.5.3 -c conda-forge --strict-channel-priority -y
which R
R --version
# R version 4.5.3 (2026-03-11) -- "Reassured Reassurer"


R Extension Pack
Yuki Ueda

mamba deactivate

R 

# 以下未成功
# open Command Palette (Ctrl+Shift+P or Cmd+Shift+P).
# Type "Preferences: Open Keyboard Shortcuts (JSON)" and select it.
# # 加在最顶部
# {
#   "key": "ctrl+enter",
#   "command": "runCommands",
#   "args": {
#     "commands": [
#       "r.runSelection",
#       "cursorDown"
#     ]
#   },
#   "when": "editorTextFocus && editorLangId == 'r'"
# }

然后需要安装各种图形设备，具体请参考：rPlot_in_vsCode.R 


# BUT, 您遇到的错误是因为 unigd 包（httpgd 的依赖）需要 zlib 开发库，但 conda 环境中缺少头文件。
# 激活您的 R 环境
conda activate base  # 或您的环境名称

# 安装 zlib 开发库
mamba install -c conda-forge zlib zlib-ng 

# 统一安装，防止版本不兼容 
mamba update r-systemfonts r-textshaping r-httpgd


# 如果仍失败，尝试安装完整的编译工具链
# conda install -c conda-forge r-base compilers

// settings.json
{
  "r.sessionWatcher": true,      // ✅ 必须启用
  "r.plot.useHttpgd": true,      // ✅ 使用 httpgd
  "r.bracketedPaste": true,
  "r.plot.width": 1200,          // 可选：调整图形尺寸
  "r.plot.height": 800
}