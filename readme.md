# Cloudflare SVCB/HTTPS DNS 记录更新工具

## 概要
使用分离的 TOML 配置文件或环境变量更新 Cloudflare 中的 SVCB 和 HTTPS DNS 记录。

## 描述
此工具包含用于更新和管理 Cloudflare DNS 中的 SVCB（服务绑定）和 HTTPS DNS 记录的脚本。它支持通过分离的 TOML 文件或环境变量进行配置。
脚本处理服务绑定记录参数的构建，如端口、ALPN、IPv4Hint、IPv6Hint、ECHConfig 等，然后使用 Cloudflare 的 API 更新记录。

## 脚本说明

### update_svcb_https.ps1
用于更新 Cloudflare 中的 SVCB 或 HTTPS DNS 记录。

#### 参数
- `CloudflareConfigPath`: 可选。Cloudflare API 配置文件的路径。默认为脚本目录中的 `cloudflare.toml`。
- `RecordConfigPath`: 可选。记录配置文件的路径。默认根据记录类型自动选择。
- `RecordType`: 可选。指定要更新的记录类型，可选值为 "SVCB" 或 "HTTPS"。

### dns_list.ps1
用于列出域名的 DNS 记录。

#### 参数
- `CloudflareConfigPath`: 可选。Cloudflare API 配置文件的路径。默认为脚本目录中的 `cloudflare.toml`。
- `域名`: 要查询的域名。如未提供，脚本会提示输入。

## 要求
- PowerShell 5.1 或更高版本
- PSToml 模块（`Install-Module -Name PSToml`）
- 具有编辑 DNS 记录权限的 Cloudflare API 密钥

## 配置
配置已分离为两个独立的 TOML 文件，便于管理多个记录的同时共用相同的 Cloudflare API 凭据。

### TOML 配置文件结构

#### cloudflare.toml
包含 Cloudflare API 凭据和访问信息。
```toml
# Cloudflare API 配置
[cloudflare]
api_key = "你的_api_密钥"
account_id = "你的_账户_id"
zone_id = "你的_区域_id"
```

#### 记录配置文件
根据记录类型，可以使用不同的配置文件：
- `svcb_record.toml` - SVCB 记录配置
- `https_record.toml` - HTTPS 记录配置
- `service_record.toml` - 通用记录配置

配置示例:
```toml
# DNS 记录基本配置
[record]
dns_record_name = "你的_dns_记录_名称"
dns_record_type = "SVCB"  # 或 "HTTPS"
ttl = 300

# 记录特定配置 - 可以使用 [svcb] 或 [https] 或 [service_params]
[svcb]  # 或 [https]
priority = 1
target = "example.com"
port = 443
alpn = ["h2", "http/1.1"]
ipv4hint = ["192.0.2.1", "192.0.2.2"]
ipv6hint = ["2001:db8::1", "2001:db8::2"]
echconfig = "你的_echconfig_值"
modelist = "你的_modelist_值"
params = ["additional_param1", "additional_param2"]
comment = "此 DNS 记录的注释"
```

### 环境变量
如果配置文件中未找到相应配置，脚本将尝试从环境变量中读取：
- `CLOUDFLARE_API_KEY` - 对应配置文件中的 `api_key`
- `CLOUDFLARE_ACCOUNT_ID` - 对应配置文件中的 `account_id`
- `CLOUDFLARE_ZONE_ID` - 对应配置文件中的 `zone_id`
- `CLOUDFLARE_DNS_RECORD_NAME` - 对应配置文件中的 `dns_record_name`

### 环境变量路径
在配置文件中，您可以通过 `{env:VARIABLE_NAME}` 语法指定从环境变量读取值：
```toml
[cloudflare]
api_key = "{env:CF_API_TOKEN}"  # 将从环境变量 CF_API_TOKEN 读取值
```

## 使用示例

### 更新记录
```powershell
# 使用默认路径的配置文件，自动检测记录类型
.\update_svcb_https.ps1

# 指定更新 HTTPS 类型的记录
.\update_svcb_https.ps1 -RecordType HTTPS

# 指定配置文件路径
.\update_svcb_https.ps1 -CloudflareConfigPath "path\to\cloudflare.toml" -RecordConfigPath "path\to\https_record.toml"
```

### 列出 DNS 记录
```powershell
# 使用默认配置文件并在提示时输入域名
.\dns_list.ps1

# 使用默认配置文件并直接指定域名
.\dns_list.ps1 example.com

# 指定配置文件路径
.\dns_list.ps1 -CloudflareConfigPath "path\to\cloudflare.toml" example.com
```

## 快速入门

1. 安装必要模块：`Install-Module -Name PSToml`
2. 创建配置文件：
   - 复制示例配置创建 `cloudflare.toml`（包含API凭据）
   - 复制示例配置创建记录配置文件（例如 `https_record.toml`）
3. 运行更新脚本：`.\update_svcb_https.ps1 -RecordType HTTPS`
4. 验证记录：`.\dns_list.ps1 你的域名`

## 记录类型说明

### SVCB 记录
SVCB（服务绑定）记录是一种通用的服务发现机制，可用于任何类型的网络服务。

### HTTPS 记录
HTTPS 记录是 SVCB 记录的一种特定形式，专门为 Web 服务优化。浏览器对 HTTPS 记录的支持比通用 SVCB 记录更广泛。

## 注意事项
- Priority 和 Target 是必需的参数
- 至少需要以下参数之一：port、alpn、ipv4hint、ipv6hint、echconfig、modelist 或 params
- 对于 target="."，建议至少配置 ipv4hint 或 ipv6hint
- 对于 HTTPS 记录，建议至少配置 "h2" 或 "http/1.1" 的 ALPN 值
- 对于 _https 服务，建议配置 alpn 参数
- 支持ECH的HTTPS服务应配置echconfig参数
- 分离配置文件可方便管理多个记录配置，同时共用相同的 Cloudflare 凭据
- 脚本会在更新前检查现有记录
- 如果任何 API 调用失败，将显示详细的错误消息