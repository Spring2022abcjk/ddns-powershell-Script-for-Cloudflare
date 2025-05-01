Import-Module -Name PSToml

# 定义配置文件路径
$ConfigFile = "C:\path\to\your\cloudflare_svcb_config.toml"

# 定义变量存储 API 配置
$APIKey = $null
$AccountID = $null
$ZoneID = $null
$CloudflareEmail = $null

# 定义变量存储 DNS 记录配置
$DNSRecordName = $null
$DNSRecordType = $null
$TTL = $null

# 定义变量存储 SVCB 记录配置
$Priority = $null
$Target = $null
$Port = $null
$ALPN = $null
$IPv4Hint = $null
$IPv6Hint = $null
$ECHConfig = $null
# 注意：移除了 $DoHTarget
# 注意：移除了 $DoHPath
$Modelist = $null
$Params = $null

# 尝试从配置文件读取配置
if (Test-Path -Path $ConfigFile) {
    try {
        $Config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Toml
        if ($Config.cloudflare) {
            $APIKey = $Config.cloudflare.api_key
            $AccountID = $Config.cloudflare.account_id
            $ZoneID = $Config.cloudflare.zone_id
            $CloudflareEmail = $Config.cloudflare.email
            $DNSRecordName = $Config.cloudflare.dns_record_name
            $DNSRecordType = $Config.cloudflare.dns_record_type
            $TTL = $Config.cloudflare.ttl
        } else {
            Write-Warning "配置文件中缺少 [cloudflare] 部分，将尝试读取环境变量。"
        }

        if ($Config.svcb) {
            $Priority = $Config.svcb.priority
            $Target = $Config.svcb.target
            $Port = $Config.svcb.port
            $ALPN = $Config.svcb.alpn
            $IPv4Hint = $Config.svcb.ipv4hint
            $IPv6Hint = $Config.svcb.ipv6hint
            $ECHConfig = $Config.svcb.echconfig
            # 注意：不再读取 dohtarget
            # 注意：不再读取 dohpath
            $Modelist = $Config.svcb.modelist
            $Params = $Config.svcb.params
        } else {
            Write-Warning "配置文件中缺少 [svcb] 部分，将使用默认的 SVCB 配置或尝试从环境变量读取（如果适用）。"
        }

    } catch {
        Write-Warning "读取或解析配置文件失败: $($_.Exception.Message)，将尝试读取环境变量。"
    }
} else {
    Write-Warning "配置文件不存在: $ConfigFile，将尝试读取环境变量。"
}

# 如果从配置文件中没有成功读取到所有必要的 API 配置，则尝试从环境变量中读取
if (-not $APIKey -or -not $AccountID -or -not $ZoneID -or -not $CloudflareEmail) {
    Write-Host "从环境变量中读取 Cloudflare API 配置..."
    $APIKey = $env:CLOUDFLARE_API_KEY
    $AccountID = $env:CLOUDFLARE_ACCOUNT_ID
    $ZoneID = $env:CLOUDFLARE_ZONE_ID
    $CloudflareEmail = $env:CLOUDFLARE_EMAIL

    if (-not $APIKey -or -not $AccountID -or -not $ZoneID -or -not $CloudflareEmail) {
        Write-Error "未找到 Cloudflare API 的相关配置 (配置文件或环境变量中)，请检查配置。"
        exit 1
    }
}

# 从环境变量中读取 DNS 记录配置 (如果配置文件中没有)
if (-not $DNSRecordName) {
    $DNSRecordName = $env:CLOUDFLARE_DNS_RECORD_NAME
    if (-not $DNSRecordName) {
        Write-Error "缺少 DNS 记录名称 (DNSRecordName)，请在配置文件或环境变量中设置。"
        exit 1
    }
}
$DNSRecordType = $DNSRecordType -or "SVCB"
$TTL = $TTL -or 60

# 检查 SVCB 记录配置是否完整 (这里我们假设 priority, target, port 是必需的)
if (-not $Priority -or -not $Target -or -not $Port) {
    Write-Error "缺少 SVCB 记录的必要配置 (priority, target, port)，请检查配置文件。"
    exit 1
}

# 构建 SVCB 记录的 Content 字符串
$SVCBContentParts = "$Priority $Target port=$Port"
if ($ALPN) {
    $SVCBContentParts += ",alpn=""" + ($ALPN -join ",") + """";
}
if ($IPv4Hint) {
    $SVCBContentParts += ",ipv4hint=" + ($IPv4Hint -join ",")
}
if ($IPv6Hint) {
    $SVCBContentParts += ",ipv6hint=""" + ($IPv6Hint -join ",") + """";
}
if ($ECHConfig) {
    $SVCBContentParts += ",echconfig=" + $ECHConfig
}
# 注意：不再包含 dohtarget 的处理
# 注意：不再包含 dohpath 的处理
if ($Modelist) {
    $SVCBContentParts += ",modelist=" + $Modelist
}
if ($Params) {
    $SVCBContentParts += "," + ($Params -join ",")
}
$SVCBContent = $SVCBContentParts

# 构建 Cloudflare API 请求的 Headers
$Headers = @{
    "X-Auth-Email" = $CloudflareEmail
    "X-Auth-Key" = $APIKey
    "Content-Type" = "application/json"
}

# 获取现有的 DNS 记录 ID
$DNSRecordIDUrl = "https://api.cloudflare.com/client/v4/zones/$ZoneID/dns_records?type=$DNSRecordType&name=$DNSRecordName"
try {
    $DNSRecordInfo = Invoke-RestMethod -Uri $DNSRecordIDUrl -Method Get -Headers $Headers
    if (-not $DNSRecordInfo.result -or $DNSRecordInfo.result.Count -eq 0) {
        Write-Error "未找到名称为 '$DNSRecordName' 且类型为 '$DNSRecordType' 的 DNS 记录，请检查配置。"
        exit 1
    }
    $RecordID = $DNSRecordInfo.result[0].id
} catch {
    Write-Error "获取 DNS 记录信息失败: $($_.Exception.Message)"
    exit 1
}

# 构建更新 DNS 记录的 Body
$Body = @{
    type = $DNSRecordType
    name = $DNSRecordName
    content = $SVCBContent
    ttl = $TTL
} | ConvertTo-Json

# 更新 DNS 记录
$UpdateDNSUrl = "https://api.cloudflare.com/client/v4/zones/$ZoneID/dns_records/$RecordID"
try {
    $UpdateResult = Invoke-RestMethod -Uri $UpdateDNSUrl -Method Put -Headers $Headers -Body $Body
    Write-Host "SVCB 记录 $DNSRecordName 已成功更新为: $SVCBContent"
    # 输出 API 的完整响应
    Write-Host "API 响应:" ($UpdateResult | ConvertTo-Json -Depth 5)
    # 或者，你可以检查特定的属性，例如 $UpdateResult.success
    if ($UpdateResult.success) {
        # 可以执行一些成功的后续操作
    } else {
        Write-Warning "API 返回更新成功的状态为 False，请检查响应信息。"
    }
} catch {
    Write-Error "更新 DNS 记录失败: $($_.Exception.Message)"
    # 可以选择输出更详细的错误信息，例如 $_.Exception.Response.Content
}