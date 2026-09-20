mamba create -n gemini nodejs=20 -c conda-forge -y #下载包的来源频道（Channel）叫做 conda-forge, Not mamba-forge

# 2. 激活环境
mamba activate gemini

# 3. 在该环境下安装 CLI (此时不需要 -g，也不需要 sudo)
npm install -g @google/gemini-cli

# 4. 现在可以使用了
gemini --help


echo 'export GEMINI_API_KEY="xxx42l0uw"' >> ~/.bashrc

source ~/.bashrc

gemini -p "解释一下 loxP 序列在 Cre-lox 系统中的方向性原理"
# Both GOOGLE_API_KEY and GEMINI_API_KEY are set. Using GOOGLE_API_KEY.
# Gemini CLI is not running in a trusted directory. To proceed, either use `--skip-trust`,
# set the `GEMINI_CLI_TRUST_WORKSPACE=true` environment variable, or trust this directory in interactive mode. 
# For more details, see https://geminicli.com/docs/cli/trusted-folders/#headless-and-automated-environments

# 这是因为 gemini-cli 有一个安全机制：在非交互模式（使用 -p 参数）下运行时，它默认不信任当前文件夹，以防止 AI 意外读取或操作你的敏感文件。
# 既然你是在自己的服务器上操作，你可以通过以下三种方式解决：

echo 'export GEMINI_CLI_TRUST_WORKSPACE=true' >> ~/.bashrc
source ~/.bashrc
mamba activate gemini
gemini -p "解释一下 loxP 序列在 Cre-lox 系统中的方向性原理"