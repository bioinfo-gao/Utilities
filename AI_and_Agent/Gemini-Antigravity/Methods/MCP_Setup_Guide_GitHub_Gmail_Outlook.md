# Antigravity MCP 配置指南：GitHub、Gmail 与 Outlook (Hotmail/Live) 实战

zorin.gao@gmail.com

本文档详细记录在 Google Antigravity / Gemini 智能体开发环境中，配置并联调 **GitHub**、**Gmail** 与 **Outlook / Hotmail / Live.com** 三大核心 MCP (Model Context Protocol) 服务的完整方法、关键踩坑点及排错方案。

---

## 目录

1. [架构与前置环境准备](#1-架构与前置环境准备)
   - [MCP 配置文件位置](#mcp-配置文件位置)
   - [Node.js 运行时版本适配（关键基础）](#nodejs-运行时版本适配关键基础)
2. [GitHub MCP 配置指南](#2-github-mcp-配置指南)
3. [Gmail MCP 配置指南（Google Cloud OAuth）](#3-gmail-mcp-配置指南google-cloud-oauth)
   - [Google Cloud 项目与 API 开启](#google-cloud-项目与-api-开启)
   - [Google Auth Platform 配置与 403 避坑](#google-auth-platform-配置与-403-避坑)
   - [客户端凭据与一次性网页授权](#客户端凭据与一次性网页授权)
4. [Outlook / Hotmail MCP 配置指南（Microsoft Graph API）](#4-outlook--hotmail-mcp-配置指南microsoft-graph-api)
   - [个人账号与 Azure 租户冲突解决](#个人账号与-azure-租户冲突解决)
   - [Azure App 注册与必要权限配置](#azure-app-注册与必要权限配置)
   - [移动/公共客户端流开启（避坑 AADSTS70002）](#移动公共客户端流开启避坑-aadsts70002)
   - [设备代码流（Device Code Flow）极简授权](#设备代码流device-code-flow极简授权)
5. [完整统一配置文件 `mcp_config.json`](#5-完整统一配置文件-mcp_configjson)
6. [服务状态与功能验证](#6-服务状态与功能验证)

---

## 1. 架构与前置环境准备

### MCP 配置文件位置

在 Antigravity 中，全局 MCP 服务器统一在以下路径进行声明和管理：

```bash
~/.gemini/config/mcp_config.json
```

Language Server 启动时会自动解析该文件中的 `mcpServers` 字典，并通过 Stdio 或 HTTP 方式与对应的 MCP 进程进行 JSON-RPC 通信。

### Node.js 运行时版本适配（关键基础）

现代 MCP SDK（如 `@modelcontextprotocol/sdk`、`@gongrzhe/server-gmail-autoauth-mcp`、`@mcp-z/mcp-outlook`）均要求 **Node.js >= 18.0.0**（推荐 Node 20+）。

> [!WARNING]
> 若系统默认安装的 Node 为旧版本（如 Ubuntu 20.04 默认的 v12.22.9），启动 MCP 时会因不支持可选链语法 `?.` 抛出语法错误：
>
> ```text
> SyntaxError: Unexpected token '.'
> ```

**排查与升级解决方案：**
如果系统中已有 Conda（如 Miniforge）或 NVM 包含高版本 Node.js（如 `v20.20.2`），可通过将新版本的 `node`、`npm`、`npx` 软链接至优先于 `/usr/bin` 的 PATH 目录（例如 `~/.local/bin/`）：

```bash
# 示例：软链接 Conda 环境中的 Node 20 到 ~/.local/bin/
ln -sf /Work_bio/gao/configs/.conda/envs/gemini/bin/node ~/.local/bin/node
ln -sf /Work_bio/gao/configs/.conda/envs/gemini/bin/npm ~/.local/bin/npm
ln -sf /Work_bio/gao/configs/.conda/envs/gemini/bin/npx ~/.local/bin/npx

# 验证版本
node -v   # 应显示 v20.x 或更高
npx -v    # 应显示 10.x 或更高
```

---

## 2. GitHub MCP 配置指南

GitHub MCP 是接入最直接、最标准的服务，采用 Anthropic 官方推荐的 `@modelcontextprotocol/server-github` 包。

### 获取 Personal Access Token (PAT)

1. 登录 GitHub，点击右上角头像 -> **Settings**。
2. 页面左下角进入 **Developer settings** -> **Personal access tokens** -> **Tokens (classic)**。
3. 点击 **Generate new token (classic)**：
   * **Note**：填入名称，如 `Antigravity-MCP`。
   * **Expiration**：选择有效期（如 90 天或根据需求自定义）。
   * **Scopes（权限勾选）**：
     * `repo`（完整读写仓库代码、提交、分支、PR、Issue）
     * `read:org`（查看所属组织信息）
     * `gist`（可选，管理代码片段）
4. 生成并复制 Token（形如 `your_github_token`）。

### 配置片段

```json
"github": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-github"],
  "env": {
    "GITHUB_PERSONAL_ACCESS_TOKEN": "your_github_tokenxxxxxxxxxxxxxxxxxxxxxxxx"
  }
}
```

---

## 3. Gmail MCP 配置指南（Google Cloud OAuth）

选用业界广泛使用的具备自动 OAuth 回调处理能力的 MCP 包：
`@gongrzhe/server-gmail-autoauth-mcp`。

### Google Cloud 项目与 API 开启

1. 登录 [Google Cloud Console](https://console.cloud.google.com/)。
2. 新建或选择一个现有项目（例如 `zorin-project`）。
3. 在左侧菜单进入 **APIs & Services** -> **Library**。
4. 搜索 **Gmail API**，进入详情页并点击 **Enable（启用）**。

### Google Auth Platform 配置与 403 避坑

在新版 Google 控制台中，“OAuth 同意屏幕”已整合并重构为 **Google Auth Platform**：

1. **App Information（应用信息）**：
   * **App name**：如 `Antigravity Gmail`。
   * **User support email**：选择当前 Gmail 邮箱（如 `zorin.gao@gmail.com`）。
   * **Developer contact information**：填写同一 Gmail 邮箱。
2. **Audience（受众类型与测试白名单）**：
   * 个人账号（`@gmail.com`）不属于 Google Workspace 组织，因此无“Internal”选项，系统默认且仅支持 **External**。
   * > [!IMPORTANT]
     > **核心踩坑点（Error 403: access_denied）**：
     > 应用在未发布前处于“Testing”状态。即便你是该 Google Cloud 项目的所有者，Google 也**不会自动将项目创建者加入测试白名单**！若不显式添加，登录授权时必报 403 拒绝访问。
     > **必做操作**：在 Audience 页面向下找到 **Test users（测试用户）**，点击 **+ ADD USERS**，输入自己的 Gmail 邮箱（如 `zorin.gao@gmail.com`）并点击保存。
     >

### 客户端凭据与一次性网页授权

1. 进入左侧 **Clients**（或 Credentials / 凭据）-> 点击 **+ CREATE CLIENT**。
2. **Application type（应用类型）**：务必选择 **Desktop app（桌面应用）**。
3. 创建后，获取 Client ID 与 Client Secret（或直接点击 Download JSON）。
4. 本地建立配置目录并保存凭据文件：

   ```bash
   mkdir -p ~/.gmail-mcp
   ```

   创建文件 `~/.gmail-mcp/gcp-oauth.keys.json`，内容格式如下：
   ```json
   {
     "installed": {
       "client_id": "YOUR_CLIENT_ID.apps.googleusercontent.com",
       "project_id": "your-project",
       "auth_uri": "https://accounts.google.com/o/oauth2/auth",
       "token_uri": "https://oauth2.googleapis.com/token",
       "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
       "client_secret": "YOUR_CLIENT_SECRET",
       "redirect_uris": ["http://localhost"]
     }
   }
   ```
5. **执行首次认证获取 Token**：

   ```bash
   npx -y @gongrzhe/server-gmail-autoauth-mcp auth
   ```

   * 控制台会打印认证 URL（回调地址为 `http://localhost:3000/oauth2callback`）。
   * 在浏览器中打开该 URL，选择你的 Gmail 账号。
   * 遇到“Google haven't verified this app”提示时，点击 **Advanced（高级）** -> **Go to Antigravity Gmail (unsafe)**。
   * 勾选邮件管理权限并点击 **Continue（允许）**。
   * 网页自动回调至本地并提示成功，系统将在 `~/.gmail-mcp/credentials.json` 自动写入持久化访问令牌。

---

## 4. Outlook / Hotmail MCP 配置指南（Microsoft Graph API）

微软于 2024 年 9 月全面禁用了针对个人 Outlook/Hotmail/Live 账户的基础身份验证（Basic Auth / 应用密码），接入必须走基于 Microsoft Graph API 的现代 OAuth 2.0 认证。
我们选用成熟的 `@mcp-z/mcp-outlook` 包。

### 个人账号与 Azure 租户冲突解决

* **常见报错 1（AADSTS90072）**：
  浏览器残留了企业/学校组织租户（如 `Athenomics`）的登录态，输入个人邮箱时，Azure 误以为要在该组织租户内认证而阻断。
* **常见报错 2（租户“Microsoft Services”中不存在）**：
  个人邮箱（`live.com` / `hotmail.com`）本身不带独立的 Azure 云租户目录。
* **最佳解决策略**：
  在 Azure 注册应用仅仅是生成一个连接接口（OAuth Client ID），**不绑定任何邮箱数据**。因此：
  * **推荐方案**：使用任意可正常访问 Azure Portal 的组织账号（如公司/高校账号）登录 [portal.azure.com](https://portal.azure.com)。
  * 创建应用时将受支持账户类型指定为 **跨租户及个人账户**。
  * 后续通过终端授权时，实际登录的是你的个人邮箱（如 `zhen-gao@live.com`），数据完全隔离且具有完全私密性。

### Azure App 注册与必要权限配置

1. 登录 [Azure Portal (portal.azure.com)](https://portal.azure.com/)。
2. 搜索并进入 **App registrations（应用注册）** -> 点击 **➕ New registration（新注册）**：
   * **Name**：如 `Antigravity-Outlook`。
   * **Supported account types（核心受支持类型）**：
     勾选第三项：
     > **Accounts in any organizational directory and personal Microsoft accounts (e.g. Skype, Xbox, Outlook.com)**
     > *(任何组织目录中的账户和个人 Microsoft 账户)*
     >
   * **Redirect URI**：选择平台为 **Mobile and desktop applications**，填入 `http://localhost`。
   * 点击 **Register（注册）**。
3. 复制 Overview 页面中的 **Application (client) ID**。

### 移动/公共客户端流开启（避坑 AADSTS70002）

> [!IMPORTANT]
> 若未开启公共流，使用设备代码流或客户端调用时会抛出如下错误：
>
> ```text
> AADSTS70002: The provided client is not supported for this feature. The client application must be marked as 'mobile.'
> ```

**开启步骤**：

1. 进入该 App 页面左侧菜单的 **Authentication（身份验证）**。
2. 在新版界面中切换到 **“设置” (Settings)** 选项卡（旧版界面拉到页面底部 **“高级设置”**）。
3. 找到 **Allow public client flows（允许公共客户端流）**：
   * 将 `Enable the following mobile and desktop flows` 勾选为 **是 (Yes)**。
4. 点击页面上方的 **Save（保存）**。

### 添加 API 委托权限

1. 进入左侧菜单的 **API permissions（API 权限）**。
2. 点击 **➕ Add a permission** -> 选择 **Microsoft Graph** -> 选择 **Delegated permissions（委托的权限）**。
3. 勾选以下权限并保存：
   * `Mail.ReadWrite`
   * `Mail.Send`
   * `offline_access`
   * `User.Read`

### 设备代码流（Device Code Flow）极简授权

`@mcp-z/mcp-outlook` 支持设备代码流（`--auth=device-code`），无需本地暴露监听端口，非常适合终端环境。

在配置参数中传入：

* `MS_CLIENT_ID`：你的 Azure Application Client ID
* `MS_TENANT_ID`：`common`
* 参数：`--auth=device-code`

**授权操作**：

1. 首次触发调用时，系统会在日志（`~/.mcp-z/logs/mcp-outlook.log`）中输出 9 位验证代码及登录网址：
   ```text
   Please visit: https://login.microsoft.com/device
   And enter code: XXXXXXXXX
   ```
2. 在浏览器中打开 [https://login.microsoft.com/device](https://login.microsoft.com/device)，填入该代码。
3. 登录你的私人账号（如 `zhen-gao@live.com`）并点击允许。
4. 客户端后台将自动接收令牌并保存在 `~/.mcp-z/` 目录下，授权完成。

---

## 5. 完整统一配置文件 `mcp_config.json`

将三大服务整合后，全局配置文件 `~/.gemini/config/mcp_config.json` 内容如下：

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "<YOUR_GITHUB_PERSONAL_ACCESS_TOKEN>"
      }
    },
    "gmail": {
      "command": "npx",
      "args": ["-y", "@gongrzhe/server-gmail-autoauth-mcp"]
    },
    "outlook": {
      "command": "npx",
      "args": ["-y", "@mcp-z/mcp-outlook", "--auth=device-code"],
      "env": {
        "MS_CLIENT_ID": "<YOUR_AZURE_APPLICATION_CLIENT_ID>",
        "MS_TENANT_ID": "common"
      }
    }
  }
}
```

---

## 6. 服务状态与功能验证

可以使用 `@mcp-z/cli` 工具对配置好的全部 MCP 服务进行就绪检查与功能测试：

```bash
# 检查各服务已注入的工具列表
npx -y @mcp-z/cli inspect --config ~/.gemini/config/mcp_config.json --servers github --tools
npx -y @mcp-z/cli inspect --config ~/.gemini/config/mcp_config.json --servers gmail --tools
npx -y @mcp-z/cli inspect --config ~/.gemini/config/mcp_config.json --servers outlook --tools

# 实测 Gmail 连通性（读取邮箱标签）
npx -y @mcp-z/cli call-tool gmail list_email_labels '{}' --config ~/.gemini/config/mcp_config.json

# 实测 Outlook 连通性（读取邮箱分类）
npx -y @mcp-z/cli call-tool outlook categories-list '{}' --config ~/.gemini/config/mcp_config.json
```

### 验证成果指标

* **GitHub**：加载 26 项功能工具（仓库检索、文件提交、分支合并、Issue/PR 管理等）。
* **Gmail**：加载 19 项功能工具（邮件搜索/阅读、草稿起草、标签过滤、附件下载等），实测成功检索全部系统标签。
* **Outlook**：加载 11 项功能工具（全量邮件检索、草稿与发送、分类维护、批量 CSV 导出等），实测成功读取用户邮件分类。
