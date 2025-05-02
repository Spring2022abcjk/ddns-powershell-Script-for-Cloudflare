# 定义配置文件路径参数
param(
    [string]$CloudflareConfigPath,
    [string]$RecordConfigPath
)

Import-Module -Name PSToml

# 导入配置模块
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. "$ScriptDir\Cloudflare_Config.ps1"

# 获取配置
$Config = Get-CloudflareConfig -CloudflareConfigPath $CloudflareConfigPath -RecordConfigPath $RecordConfigPath -RequireSVCB

if (-not $Config.Success) {
    Write-Error $Config.ErrorMessage
    exit 1
}

# 提取配置值
$ApiToken = $Config.ApiToken
$ZoneID = $Config.ZoneID
$DNSRecordName = $Config.DNSRecordName
$DNSRecordType = $Config.DNSRecordType
$TTL = $Config.TTL

# SVCB 特定配置
$Priority = $Config.SVCB.Priority
$Target = $Config.SVCB.Target
$Port = $Config.SVCB.Port
$ALPN = $Config.SVCB.ALPN
$IPv4Hint = $Config.SVCB.IPv4Hint
$IPv6Hint = $Config.SVCB.IPv6Hint
$ECHConfig = $Config.SVCB.ECHConfig
$Modelist = $Config.SVCB.Modelist
$Params = $Config.SVCB.Params
$Comment = $Config.SVCB.Comment

# 验证必要的 DNS 记录配置
if (-not $DNSRecordName) {
    Write-Error "缺少 DNS 记录名称 (DNSRecordName)，请在配置文件或环境变量中设置。"
    exit 1
}

# 检查 SVCB 记录配置是否完整
if (-not $Priority -or -not $Target) {
    Write-Error "缺少 SVCB 记录的必要配置 (priority, target)，请检查配置文件。"
    exit 1
}

# 检查是否至少配置了 ipv4hint, ipv6hint, port, alpn, echconfig, modelist 或 params 中的一个
if (-not $Port -and -not $ALPN -and -not $IPv4Hint -and -not $IPv6Hint -and -not $ECHConfig -and -not $Modelist -and -not $Params) {
    Write-Error "SVCB 记录至少需要配置 ipv4hint, ipv6hint, port, alpn, echconfig, modelist 或 params 中的一个，建议检查配置文件。"
    exit 1
}

# 针对 target 为 "." 的情况，建议配置 IP 提示
if ($Target -eq ".") {
    if (-not $IPv4Hint -and -not $IPv6Hint) {
        Write-Warning "当 target 为 '.' 时，建议至少配置 ipv4hint 或 ipv6hint 中的一个。"
    }
}

# 针对 _https 服务，建议配置 ALPN
if ($DNSRecordName -like "_https._*") {
    if (-not $ALPN) {
        Write-Warning "对于 _https 服务，建议配置 alpn 参数。"
    }
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
if ($Modelist) {
    $SVCBContentParts += ",modelist=" + $Modelist
}
if ($Params) {
    $SVCBContentParts += "," + ($Params -join ",")
}
$SVCBContent = $SVCBContentParts

# 构建 Cloudflare API 请求的 Headers
$Headers = @{
    "Authorization" = "Bearer $ApiToken"
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
    Write-Error "获取 DNS 记录信息失败: $($_.Exception.Message)。详细信息：$($_.Exception.Response.Content)"
    Write-Host "$DNSRecordIDUrl"
    exit 1
}

# 构建SVCB记录的服务参数字符串
$svcParamStr = ""
$paramList = @()

if ($Port) { $paramList += "port=""$Port""" }
if ($ALPN) { $paramList += "alpn=""$($ALPN -join ',')""" }
if ($IPv4Hint) { $paramList += "ipv4hint=$($IPv4Hint -join ',')" }
if ($IPv6Hint) { $paramList += "ipv6hint=""$($IPv6Hint -join ',')""" }
if ($ECHConfig) { $paramList += "echconfig=$ECHConfig" }
if ($Modelist) { $paramList += "modelist=$Modelist" }

$svcParamStr = $paramList -join " "

# 构建符合Cloudflare API期望的Body
$Body = @{
    type = $DNSRecordType
    name = $DNSRecordName
    ttl = $TTL
    comment = $Comment
    data = @{
        priority = [int]$Priority
        target = $Target
        value = $svcParamStr
    }
} | ConvertTo-Json -Depth 5

# 更新 DNS 记录
$UpdateDNSUrl = "https://api.cloudflare.com/client/v4/zones/$ZoneID/dns_records/$RecordID"
try {
    $UpdateResult = Invoke-RestMethod -Uri $UpdateDNSUrl -Method Put -Headers $Headers -Body $Body
    Write-Host "SVCB 记录 $DNSRecordName 已成功更新为: $SVCBContent"
    # 输出 API 的完整响应
    Write-Host "API 响应:" ($UpdateResult | ConvertTo-Json -Depth 5)
    # 或者，你可以检查特定的属性，例如 $UpdateResult.success
    if ($UpdateResult.success) {
        Write-Host "DNS 记录更新成功。"
    } else {
        Write-Warning "API 返回更新成功的状态为 False，请检查响应信息。"
    }
} catch {
    $errorDetail = $_.ErrorDetails.Message
    if (-not $errorDetail) {
        try { $errorDetail = $_.Exception.Response.Content }
        catch { $errorDetail = "无法获取详细错误信息" }
    }
    
    Write-Error "更新 DNS 记录失败: $($_.Exception.Message)`n详细信息: $errorDetail"
    Write-Host "请求URL: $UpdateDNSUrl"
    Write-Host "请求内容: $Body"
}